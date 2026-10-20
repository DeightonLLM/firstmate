#!/usr/bin/env bash
# tests/controller-resource-audit.test.sh - contract tests for the documented
# Controller resource cadence (bin/controller-resource-audit.sh plus the
# systemd units it ships).
#
# Contract source (quoted in data/wo-0006-l3-audit-timer/report.md):
#   - "It samples capacity and disposable-cache candidates every six hours,
#      writes a bounded latest report, and keeps a small event ledger."
#   - "Every six hours: host identity, disk, memory/swap, load, journal size,
#      Docker summary, protected-service status, and the exact approved
#      retention paths."
#   - "At 75% root usage: report CAPACITY_WARN. At 80%: report
#      CAPACITY_REVIEW_REQUIRED. At 85%: report CAPACITY_BLOCK_NEW_PLACEMENT."
#   - "On every run: overwrite resource-audit/latest.md and trim the event
#      ledger; never accumulate a new full snapshot per cycle."
#   - "It never deletes files, stops containers, kills Herdr/Pi/Senpi/lean-ctx,
#      restarts M3, or changes a deployment."
#
# Fully hermetic: every host sample is stubbed through a private fakebin, the
# report directory is a private temp root, and no live systemd, docker, or
# service state is read or touched.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

AUDIT="$ROOT/bin/controller-resource-audit.sh"
SERVICE_UNIT="$ROOT/bin/systemd/controller-resource-audit.service"
TIMER_UNIT="$ROOT/bin/systemd/controller-resource-audit.timer"

# --- the contract surfaces must exist at all --------------------------------

assert_present "$AUDIT" "documented sampler script is absent: $AUDIT"
[ -x "$AUDIT" ] || fail "sampler script is not executable: $AUDIT"
assert_present "$TIMER_UNIT" "documented cadence timer unit is absent: $TIMER_UNIT"
assert_present "$SERVICE_UNIT" "timer's service unit is absent: $SERVICE_UNIT"
pass "the documented sampler, service unit, and timer unit all exist"

# --- the six-hour cadence itself --------------------------------------------
#
# The contract says "every six hours". --next-run is the single owner of that
# boundary math, so these are the cadence assertions.

assert_eq_run() {  # <from ISO> <expected ISO> <label>
  got=$("$AUDIT" --next-run "$1")
  [ "$got" = "$2" ] || fail "$3: from $1 expected $2, got $got"
}

assert_eq_run 2026-10-15T01:00:00Z 2026-10-15T06:00:00Z \
  "01:00Z must schedule the next run at 06:00Z"
assert_eq_run 2026-10-15T06:00:00Z 2026-10-15T12:00:00Z \
  "an exact boundary must schedule the FOLLOWING boundary, not itself"
assert_eq_run 2026-10-15T23:30:00Z 2026-10-16T00:00:00Z \
  "23:30Z must roll over to the next day's 00:00Z boundary"
assert_eq_run 2026-10-15T00:00:00Z 2026-10-15T06:00:00Z \
  "an exact midnight boundary must schedule 06:00Z"
assert_eq_run 2026-12-31T19:00:00Z 2027-01-01T00:00:00Z \
  "the year rollover must land on 00:00Z"
pass "--next-run honours the documented six-hour boundary (00/06/12/18Z)"

# Consecutive boundaries are exactly six hours apart across a full day, which is
# the cadence the contract states rather than an implementation detail.
prev=""
for probe in 2026-10-15T00:00:00Z 2026-10-15T06:00:00Z 2026-10-15T12:00:00Z \
              2026-10-15T18:00:00Z 2026-10-16T00:00:00Z; do
  nxt=$("$AUDIT" --next-run "$probe")
  if [ -n "$prev" ]; then
    gap=$(($(date -u -d "$nxt" +%s) - $(date -u -d "$prev" +%s)))
    [ "$gap" -eq 21600 ] || fail "cadence gap between $prev and $nxt must be 21600s, got ${gap}s"
  fi
  prev=$nxt
done
pass "every consecutive boundary is exactly 21600s (six hours) apart"

# The shipped timer unit must declare that same cadence, and the sampler must
# verify it rather than a human eyeballing the unit.
check_out=$("$AUDIT" --check-timer-unit "$TIMER_UNIT" 2>&1)
expect_code 0 $? "--check-timer-unit must accept the shipped six-hour timer"
assert_contains "$check_out" "CADENCE_OK" "timer unit cadence verdict missing"
pass "the shipped timer unit declares the documented six-hour cadence"

# A unit that drifted to a shorter interval must be refused loudly: this is the
# failure mode the whole ticket exists to prevent.
DRIFT_ROOT=$(fm_test_tmproot controller-resource-audit-drift)
mkdir -p "$DRIFT_ROOT"
sed 's#^\(OnCalendar=\).*#\1*-*-* *:0/1:00#' "$TIMER_UNIT" > "$DRIFT_ROOT/short.timer"
if "$AUDIT" --check-timer-unit "$DRIFT_ROOT/short.timer" >"$DRIFT_ROOT/out" 2>&1; then
  fail "a one-hourly timer must be refused, not accepted"
fi
assert_contains "$(cat "$DRIFT_ROOT/out")" "CADENCE_DRIFT" \
  "a drifted timer must name the CADENCE_DRIFT verdict"
pass "a timer that drifts off the six-hour cadence is refused with CADENCE_DRIFT"

# --- threshold verdicts -----------------------------------------------------
#
# Contract: 75 -> CAPACITY_WARN, 80 -> CAPACITY_REVIEW_REQUIRED,
# 85 -> CAPACITY_BLOCK_NEW_PLACEMENT.

THRESH_ROOT=$(fm_test_tmproot controller-resource-audit-threshold)
mkdir -p "$THRESH_ROOT"
assert_verdict() {  # <percent> <expected verdict>
  got=$("$AUDIT" --print-verdict --root-used-percent "$1" --report-dir "$THRESH_ROOT/r$1")
  [ "$got" = "$2" ] || fail "${1}% must report $2, got $got"
}
assert_verdict 0 CAPACITY_OK
assert_verdict 74 CAPACITY_OK
assert_verdict 75 CAPACITY_WARN
assert_verdict 79 CAPACITY_WARN
assert_verdict 80 CAPACITY_REVIEW_REQUIRED
assert_verdict 84 CAPACITY_REVIEW_REQUIRED
assert_verdict 85 CAPACITY_BLOCK_NEW_PLACEMENT
assert_verdict 99 CAPACITY_BLOCK_NEW_PLACEMENT
pass "the 75/80/85 percent threshold table reports the documented verdicts"

# A non-numeric percent is a measurement failure, never a silent pass.
if "$AUDIT" --print-verdict --root-used-percent banana --report-dir "$THRESH_ROOT/bad" \
    >"$THRESH_ROOT/bad.out" 2>&1; then
  fail "an unmeasurable root percent must fail, not report a verdict"
fi
assert_contains "$(cat "$THRESH_ROOT/bad.out")" "CAPACITY_UNMEASURABLE" \
  "unmeasurable percent must name CAPACITY_UNMEASURABLE"
pass "an unmeasurable root percent fails loudly with CAPACITY_UNMEASURABLE"

# --- the eight documented samples ------------------------------------------

SAMPLE_ROOT=$(fm_test_tmproot controller-resource-audit-samples)
mkdir -p "$SAMPLE_ROOT"
SAMPLE_FAKE=$(fm_fakebin "$SAMPLE_ROOT")
cat > "$SAMPLE_FAKE/df" <<'SH'
#!/usr/bin/env bash
printf 'Filesystem 1024-blocks Used Available Capacity Mounted-on\n'
printf '/dev/vda1 104857600 78643200 26214400  75%% /\n'
SH
cat > "$SAMPLE_FAKE/free" <<'SH'
#!/usr/bin/env bash
printf '               total        used        free      shared  buff/cache   available\n'
printf 'Mem:        16040244     4012344     2123456      123456     9704444     11023456\n'
printf 'Swap:       2097148           0     2097148\n'
SH
cat > "$SAMPLE_FAKE/uname" <<'SH'
#!/usr/bin/env bash
printf 'Linux fixture-host 6.8.0-fixture #1 SMP fixture x86_64 GNU/Linux\n'
SH
cat > "$SAMPLE_FAKE/hostname" <<'SH'
#!/usr/bin/env bash
printf 'fixture-host\n'
SH
cat > "$SAMPLE_FAKE/journalctl" <<'SH'
#!/usr/bin/env bash
printf 'Archived and active journals take up 412M\n'
SH
cat > "$SAMPLE_FAKE/docker" <<'SH'
#!/usr/bin/env bash
printf 'TYPE            TOTAL   ACTIVE   SIZE      RECLAIMABLE\n'
printf 'Images          12      0        4.2GB     3.1GB\n'
SH
cat > "$SAMPLE_FAKE/systemctl" <<'SH'
#!/usr/bin/env bash
printf 'active\n'
SH
cat > "$SAMPLE_FAKE/uptime" <<'SH'
#!/usr/bin/env bash
printf ' 19:22:31 up 41 days,  3:11,  6 users,  load average: 6.15, 5.02, 4.71\n'
SH
chmod +x "$SAMPLE_FAKE"/*

PATH="$SAMPLE_FAKE:$PATH" "$AUDIT" \
  --report-dir "$SAMPLE_ROOT/report" --now 2026-10-15T06:00:00Z >/dev/null \
  || fail "sampler run failed against the stubbed host"
REPORT="$SAMPLE_ROOT/report/latest.md"
assert_present "$REPORT" "the bounded latest.md report was not written"
REPORT_BODY=$(cat "$REPORT")
for section in \
  "host-identity" "disk" "memory-swap" "load" \
  "journal-size" "docker-summary" "protected-services" "approved-retention-paths"; do
  assert_contains "$REPORT_BODY" "$section" "documented sample missing from the report: $section"
done
pass "the report carries all eight documented six-hour samples"

assert_contains "$REPORT_BODY" "75" "the sampled disk percent must appear in the report"
assert_contains "$REPORT_BODY" "CAPACITY_WARN" "the report must carry its threshold verdict"
assert_contains "$REPORT_BODY" "six hours" "the report must state its own cadence"
pass "the report carries the measurement, its verdict, and its cadence"

# Retention candidates are classified, never actioned: everything off the
# documented allowlist must be reported as operator-approval territory.
OFFLIST_ROOT=$(fm_test_tmproot controller-resource-audit-offlist)
mkdir -p "$OFFLIST_ROOT/home/.minimax/keep-me"
printf 'secret transcript material\n' > "$OFFLIST_ROOT/home/.minimax/keep-me/chat.log"
OFFLIST_OUT=$(PATH="$SAMPLE_FAKE:$PATH" "$AUDIT" \
  --report-dir "$OFFLIST_ROOT/report" --now 2026-10-15T06:00:00Z \
  --extra-candidate "$OFFLIST_ROOT/home/.minimax/keep-me" 2>&1) \
  || fail "sampler run failed while classifying an off-allowlist candidate"
assert_contains "$OFFLIST_OUT" "REQUIRES_OPERATOR_APPROVAL" \
  "an off-allowlist candidate must be classified REQUIRES_OPERATOR_APPROVAL"
assert_present "$OFFLIST_ROOT/home/.minimax/keep-me/chat.log" \
  "the audit must never remove a candidate it merely reports"
pass "off-allowlist candidates are classified for operator approval and preserved"

# --- bounded output: overwrite, never accumulate ----------------------------

BOUND_ROOT=$(fm_test_tmproot controller-resource-audit-bounded)
mkdir -p "$BOUND_ROOT"
for cycle in 1 2 3; do
  PATH="$SAMPLE_FAKE:$PATH" "$AUDIT" \
    --report-dir "$BOUND_ROOT/report" \
    --now "2026-10-15T0${cycle}:00:00Z" --ledger-max 2 >/dev/null \
    || fail "sampler run failed on cycle $cycle"
done
REPORT_COUNT=$(find "$BOUND_ROOT/report" -name 'latest*.md' | wc -l | tr -d '[:space:]')
[ "$REPORT_COUNT" = "1" ] \
  || fail "three cycles must leave exactly one latest.md, found $REPORT_COUNT"
LEDGER=$(wc -l < "$BOUND_ROOT/report/events.log" | tr -d '[:space:]')
[ "$LEDGER" = "2" ] || fail "the event ledger must be trimmed to --ledger-max 2, has $LEDGER lines"
pass "each cycle overwrites latest.md and trims the event ledger (no accumulation)"

# --- read-only on the host --------------------------------------------------
#
# The contract forbids deleting, stopping containers, killing agent runtime, or
# changing a deployment. Tripwire shims sit in front of every mutating verb and
# record the attempt instead of performing it.

RO_ROOT=$(fm_test_tmproot controller-resource-audit-readonly)
mkdir -p "$RO_ROOT/real"
RO_FAKE=$(fm_fakebin "$RO_ROOT")
RO_MARKER="$RO_ROOT/tripwire-fired"

# Read-only-only commands are passed straight through to the fixture stubs.
for tool in df free uname hostname journalctl uptime; do
  ln -sf "$SAMPLE_FAKE/$tool" "$RO_FAKE/$tool"
done

# Read-only verbs pass through; any mutating verb records the attempt instead.
for tool in docker systemctl; do
  cat > "$RO_FAKE/$tool" <<'SH'
#!/usr/bin/env bash
for arg in "$@"; do
  case "$arg" in
    stop|kill|killall|rm|rmi|prune|create|restart|reload|enable|disable|mask|pause|unpause)
      printf 'MUTATION ATTEMPT: %s %s\n' "$0" "$*" >>"${AUDIT_TRIPWIRE_MARKER:?}"
      exit 127 ;;
  esac
done
exec "${AUDIT_TRIPWIRE_REAL_DIR:?}/$0" "$@"
SH
  chmod +x "$RO_FAKE/$tool"
done

# Purely destructive commands are always recorded, never performed.
for tool in rm rmdir shred truncate mv dd kill pkill killall shutdown reboot \
            chown chmod; do
  cat > "$RO_FAKE/$tool" <<'SH'
#!/usr/bin/env bash
printf 'MUTATION ATTEMPT: %s %s\n' "$0" "$*" >>"${AUDIT_TRIPWIRE_MARKER:?}"
exit 127
SH
  chmod +x "$RO_FAKE/$tool"
done

AUDIT_TRIPWIRE_MARKER="$RO_MARKER" AUDIT_TRIPWIRE_REAL_DIR="$SAMPLE_FAKE" \
  PATH="$RO_FAKE:$PATH" "$AUDIT" \
  --report-dir "$RO_ROOT/report" --now 2026-10-15T06:00:00Z >/dev/null \
  || fail "sampler run failed under the read-only tripwire"
assert_absent "$RO_MARKER" \
  "the audit attempted a mutating command; see $RO_MARKER"
pass "the audit issues no delete, stop, kill, or deployment-changing command"

# The tripwire is proven live: a deliberately mutating probe must fire it, or
# the absence above would be vacuous.
AUDIT_TRIPWIRE_MARKER="$RO_MARKER" AUDIT_TRIPWIRE_REAL_DIR="$SAMPLE_FAKE" \
  PATH="$RO_FAKE:$PATH" docker system prune -f >/dev/null 2>&1 || true
assert_present "$RO_MARKER" "the read-only tripwire did not fire on a real mutation"
pass "the read-only tripwire demonstrably fires on a mutating command"

echo "# controller-resource-audit.test.sh: all assertions passed"