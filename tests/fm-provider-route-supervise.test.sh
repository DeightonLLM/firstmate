#!/usr/bin/env bash
# tests/fm-provider-route-supervise.test.sh - bounded, hermetic tests for the
# AFK supervisor integration of the existing sanitized provider-route observer
# (bin/fm-provider-route-watch.sh).
#
# Contract being proven (RED -> GREEN -> REFACTOR):
#   1. The supervisor integration helper exists at
#      bin/fm-provider-route-supervise.sh and is executable.
#   2. The function fm_provider_route_supervise_tick is defined after the
#      supervise-daemon library is sourced (it owns the cadence-gated
#      observation).
#   3. One observation = exactly one quota-axi snapshot per due cadence. A
#      second tick inside the cadence window makes zero additional quota-axi
#      calls.
#   4. The helper uses a private bounded temporary file for the snapshot; the
#      temp file is removed before the function returns.
#   5. The helper invokes the existing observer (fm-provider-route-watch.sh)
#      with the temp file as the quota source; the watch's sanitized signal is
#      preserved as a coarse observable state under state/.
#   6. Quota acquisition failure records a coarse observable error in
#      state/.provider-route-supervise-error and does NOT abort the daemon.
#   7. housekeeping() invokes the supervisor tick at the FM_HOUSEKEEPING_TICK
#      cadence, not per wake (no daemon-broadening inside per-wake triage).
#   8. HANDOFF_PENDING and DEFER_ACTIVE_RUN are pure observation signals; the
#      helper does NOT mutate queue rows, leases, panes, or Herdr state.
#
# All tests use a hermetic fakebin so the live quota-axi / jq / npx are never
# invoked. The tests assert behavior that, taken together, proves the helper
# is bounded, deterministic, and read-only against the route side.

set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DAEMON="$ROOT/bin/fm-supervise-daemon.sh"
HELPER="$ROOT/bin/fm-provider-route-supervise.sh"
WATCH="$ROOT/bin/fm-provider-route-watch.sh"

TMP_ROOT=$(fm_test_tmproot fm-supervise-tests)

# Source the daemon's library once so the pure functions become defined; this
# is the same pattern fm-daemon.test.sh uses. The daemon's library-mode guard
# prevents fm_super_main from running under sourcing.
if [ -z "${FM_TEST_DAEMON_SOURCED:-}" ]; then
  export FM_TEST_DAEMON_SOURCED=1
  # shellcheck source=bin/fm-supervise-daemon.sh
  . "$DAEMON"
fi

# --- hermetic fakebin: a counting quota-axi, a real jq wrapper, and a stub
# for whatever the helper / observer may invoke. Every test installs its own
# fakebin and uses PATH="<fakebin>:/usr/bin:/bin" so the live system binaries
# are never reached.
make_supervise_case() {
  local name=$1 dir fakebin quota_calls
  dir="$TMP_ROOT/$name"
  fakebin="$dir/fakebin"
  quota_calls="$dir/quota-axi.calls"
  mkdir -p "$dir/state" "$fakebin"
  echo 0 > "$quota_calls"
  # Counting quota-axi that emits a minimal schema-5 fixture.
  cat > "$fakebin/quota-axi" <<EOF
#!/usr/bin/env bash
n=\$((\$(cat "$quota_calls" 2>/dev/null || echo 0) + 1))
echo \$n > "$quota_calls"
cat <<JSON
{"schemaVersion":5,"providers":[
  {"provider":"agy","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"gemini","status":"known","effectivePercentRemaining":90,"selection":{"status":"known"}}]}},
  {"provider":"minimax","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":70,"selection":{"status":"known"}}]}}
]}
JSON
exit 0
EOF
  chmod +x "$fakebin/quota-axi"
  # Wrap the real jq so the route script can still parse JSON.
  cat > "$fakebin/jq" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/jq "$@"
EOF
  chmod +x "$fakebin/jq"
  printf '%s\n' "$dir"
}

# --- Test 1: helper script exists at the supervisor boundary -------------
test_helper_script_exists() {
  [ -e "$HELPER" ] || fail "fm-provider-route-supervise.sh missing at $HELPER"
  [ -x "$HELPER" ] || fail "fm-provider-route-supervise.sh is not executable"
  pass "fm-provider-route-supervise.sh exists and is executable"
}

# --- Test 2: supervisor tick function is defined in the daemon library ---
test_supervise_tick_function_defined() {
  type fm_provider_route_supervise_tick >/dev/null 2>&1 \
    || fail "fm_provider_route_supervise_tick missing from daemon library"
  pass "fm_provider_route_supervise_tick is defined after sourcing fm-supervise-daemon.sh"
}

# --- Test 3: one quota-axi snapshot per due cadence ----------------------
# A first call records exactly one quota call; an immediate second call inside
# the same cadence window records zero additional calls. This proves the
# helper is cadence-gated and cannot amplify into multiple quota acquisitions
# per AFK tick. Cadence is set above the integer-second granularity so the
# window absorbs any plausible wall-clock delta between the two calls.
test_one_snapshot_per_cadence() {
  local dir state fakebin quota_calls
  dir=$(make_supervise_case supervise-one-snapshot)
  state="$dir/state"
  fakebin="$dir/fakebin"
  quota_calls="$dir/quota-axi.calls"

  # Cadence of 60s (well above integer-second granularity); remove any prior
  # cadence marker so the first call is due.
  rm -f "$state/.provider-route-supervise-last-run"
  FM_PROVIDER_ROUTE_SUPERVISE_CADENCE=60 \
    FM_STATE_OVERRIDE="$state" \
    PATH="$fakebin:/usr/bin:/bin" \
    fm_provider_route_supervise_tick "$state" \
    || fail "supervisor tick failed on first call"
  local n1
  n1=$(cat "$quota_calls")
  [ "$n1" -eq 1 ] \
    || fail "first observation should call quota-axi exactly once (got $n1)"

  # Immediate second call inside the cadence window must NOT call quota-axi.
  FM_PROVIDER_ROUTE_SUPERVISE_CADENCE=60 \
    FM_STATE_OVERRIDE="$state" \
    PATH="$fakebin:/usr/bin:/bin" \
    fm_provider_route_supervise_tick "$state" \
    || fail "supervisor tick failed on second call inside cadence"
  local n2
  n2=$(cat "$quota_calls")
  [ "$n2" -eq 1 ] \
    || fail "second tick inside cadence must NOT call quota-axi (got $n2)"
  pass "supervisor tick calls quota-axi exactly once per due cadence"
}

# --- Test 4: helper uses a private bounded temp file and removes it -------
# While the supervisor tick is in flight, the snapshot must live in a private
# bounded temp file. After the tick returns, no such temp file may remain
# under TMPDIR (the helper is responsible for cleanup, not the caller).
test_temp_file_cleaned_up() {
  local dir state fakebin before after
  dir=$(make_supervise_case supervise-temp-cleanup)
  state="$dir/state"
  fakebin="$dir/fakebin"
  rm -f "$state/.provider-route-supervise-last-run"
  before=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'fm-supervise-snap.*' 2>/dev/null | wc -l | tr -d ' ')
  FM_PROVIDER_ROUTE_SUPERVISE_CADENCE=1 \
    FM_STATE_OVERRIDE="$state" \
    PATH="$fakebin:/usr/bin:/bin" \
    fm_provider_route_supervise_tick "$state" \
    || fail "supervisor tick failed during temp-cleanup test"
  after=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'fm-supervise-snap.*' 2>/dev/null | wc -l | tr -d ' ')
  [ "$before" = "$after" ] \
    || fail "private bounded temp file leaked: before=$before after=$after"
  pass "supervisor tick uses a private bounded temp file and removes it"
}

# --- Test 5: helper preserves the watch's sanitized signal as state -------
# After a successful observation, the helper writes a coarse observable
# signal (one of NO_PRIOR / NO_CHANGE / HANDOFF_PENDING / DEFER_ACTIVE_RUN)
# under state/.provider-route-supervise-last-signal. The signal is the
# supervisor's only consumer; no escalation is auto-fired.
test_signal_persisted_as_state() {
  local dir state fakebin signal
  dir=$(make_supervise_case supervise-signal-state)
  state="$dir/state"
  fakebin="$dir/fakebin"
  rm -f "$state/.provider-route-supervise-last-run"
  FM_PROVIDER_ROUTE_SUPERVISE_CADENCE=1 \
    FM_STATE_OVERRIDE="$state" \
    PATH="$fakebin:/usr/bin:/bin" \
    fm_provider_route_supervise_tick "$state" \
    || fail "supervisor tick failed during signal-persist test"
  [ -e "$state/.provider-route-supervise-last-signal" ] \
    || fail "state/.provider-route-supervise-last-signal not written"
  signal=$(awk -F= '/^last_signal=/{print $2; exit}' "$state/.provider-route-supervise-last-signal" 2>/dev/null \
    || cat "$state/.provider-route-supervise-last-signal")
  case "$signal" in
    NO_PRIOR|NO_CHANGE|HANDOFF_PENDING|DEFER_ACTIVE_RUN) ;;
    *) fail "supervisor signal is not a bounded sanitized token: '$signal'" ;;
  esac
  pass "supervisor signal is persisted as one of NO_PRIOR/NO_CHANGE/HANDOFF_PENDING/DEFER_ACTIVE_RUN"
}

# --- Test 6: quota acquisition failure is bounded; daemon stays alive -----
# When quota-axi fails (non-zero exit), the supervisor tick records a coarse
# observable error in state/.provider-route-supervise-error and returns 0.
# The daemon must NEVER abort on quota failure.
test_quota_failure_does_not_abort() {
  local dir state fakebin quota_calls
  dir=$(make_supervise_case supervise-quota-failure)
  state="$dir/state"
  fakebin="$dir/fakebin"
  quota_calls="$dir/quota-axi.calls"
  # Replace quota-axi with one that exits non-zero without writing JSON.
  cat > "$fakebin/quota-axi" <<'EOF'
#!/usr/bin/env bash
echo "fake quota-axi failure" >&2
exit 17
EOF
  chmod +x "$fakebin/quota-axi"
  rm -f "$state/.provider-route-supervise-last-run" \
    "$state/.provider-route-supervise-error"
  local rc
  set +e
  FM_PROVIDER_ROUTE_SUPERVISE_CADENCE=1 \
    FM_STATE_OVERRIDE="$state" \
    PATH="$fakebin:/usr/bin:/bin" \
    fm_provider_route_supervise_tick "$state"
  rc=$?
  set -e
  [ "$rc" -eq 0 ] \
    || fail "supervisor tick must not abort on quota failure (got exit $rc)"
  [ -e "$state/.provider-route-supervise-error" ] \
    || fail "state/.provider-route-supervise-error not written on quota failure"
  # The cadence marker must NOT advance on quota failure (so the next tick can
  # retry without waiting for a full cadence window).
  [ ! -e "$state/.provider-route-supervise-last-run" ] \
    || fail "cadence marker advanced despite quota failure (would suppress next retry)"
  pass "quota failure records a coarse observable error and keeps the daemon alive"
}

# --- Test 7: housekeeping invokes the supervisor tick ------------------
# AFK housekeeping must call fm_provider_route_supervise_tick. Otherwise the
# helper is dead code and the integration promise is broken.
test_housekeeping_invokes_supervise_tick() {
  local dir state fakebin
  dir=$(make_supervise_case supervise-housekeeping-wiring)
  state="$dir/state"
  fakebin="$dir/fakebin"
  rm -f "$state/.provider-route-supervise-last-run"
  # Mark the housekeeping cadence marker as stale so housekeeping actually runs.
  echo $(( $(date +%s) - 999 )) > "$state/.subsuper-last-housekeep"
  FM_PROVIDER_ROUTE_SUPERVISE_CADENCE=1 \
    FM_STATE_OVERRIDE="$state" \
    PATH="$fakebin:/usr/bin:/bin" \
    housekeeping "$state" \
    || fail "housekeeping failed"
  [ -e "$state/.provider-route-supervise-last-run" ] \
    || fail "housekeeping did not call fm_provider_route_supervise_tick"
  pass "housekeeping invokes fm_provider_route_supervise_tick when due"
}

# --- Test 8: HANDOFF_PENDING/DEFER_ACTIVE_RUN are alerts only (no mutation)
# After an observation surfaces any bounded signal (NO_PRIOR / NO_CHANGE /
# HANDOFF_PENDING / DEFER_ACTIVE_RUN), every file the supervisor tick
# created in <state>/ must match the bounded naming convention. Anything
# else (queue, lease, pane, run-id, escalation buffer) is a regression. The
# signal is a passive recorder.
test_signal_does_not_mutate_queue_or_pane() {
  local dir state fakebin
  dir=$(make_supervise_case supervise-no-mutation)
  state="$dir/state"
  fakebin="$dir/fakebin"
  rm -f "$state/.provider-route-supervise-last-run"
  FM_PROVIDER_ROUTE_SUPERVISE_CADENCE=1 \
    FM_STATE_OVERRIDE="$state" \
    PATH="$fakebin:/usr/bin:/bin" \
    fm_provider_route_supervise_tick "$state" \
    || fail "supervisor tick failed during no-mutation test"

  # Every file in <state>/ after the tick must match a bounded naming
  # convention owned by the supervise helper or the existing watch / daemon.
  local f ok=1 unexpected=()
  while IFS= read -r f; do
    case "$f" in
      .provider-route-supervise-*) ;;
      .provider-route-watch.*) ;;
      *) printf '  unexpected file: %s\n' "$f" >&2; ok=0 ;;
    esac
  done < <(find "$state" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort)
  [ "$ok" = 1 ] \
    || fail "supervisor tick created files outside the bounded naming convention"

  # No escalation buffer write should happen for a passive observation.
  [ ! -s "$state/.subsuper-escalations" ] \
    || fail "supervisor tick wrote to .subsuper-escalations (must be passive)"

  # No queue, lease, pane, or Herdr-state file should exist in <state>/.
  for forbidden in .queue .lease .pane .herdr; do
    [ ! -e "$state/$forbidden" ] \
      || fail "supervisor tick created forbidden file: $forbidden"
  done

  pass "supervisor signal is passive: no queue, lease, pane, or escalation mutation"
}

# --- Test runner ---------------------------------------------------------
# Each test is wrapped in a subshell so a `fail` (exit 1) inside one test
# does not abort the others; the runner collects every RED signature and the
# script exits non-zero if any test failed.
FAILED=0
run_test() {
  local fn=$1
  printf -- '--- %s\n' "$fn"
  if ( "$fn" ); then
    :
  else
    printf '   -> %s FAILED\n' "$fn"
    FAILED=1
  fi
}

run_test test_helper_script_exists
run_test test_supervise_tick_function_defined
run_test test_one_snapshot_per_cadence
run_test test_temp_file_cleaned_up
run_test test_signal_persisted_as_state
run_test test_quota_failure_does_not_abort
run_test test_housekeeping_invokes_supervise_tick
run_test test_signal_does_not_mutate_queue_or_pane

if [ "$FAILED" -ne 0 ]; then
  echo "RED: AFK provider-route supervision is NOT yet wired (expected before GREEN)" >&2
  exit 1
fi
echo "PASS: AFK provider-route supervision is bounded, deterministic, and read-only"
