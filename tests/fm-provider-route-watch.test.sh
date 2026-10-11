#!/usr/bin/env bash
# Deterministic tests for the read-only route-observation helper
# bin/fm-provider-route-watch.sh.
#
# This test proves three invariants for the bounded observer contract:
#   1. first observation surfaces NO_PRIOR and writes a sanitized fingerprint
#   2. identical quota snapshots leave the fingerprint and signal untouched
#   3. blocked quotas surface DEFER_ACTIVE_RUN; ready-but-changed snapshots
#      surface HANDOFF_PENDING; the active run is NEVER auto-rerouted (this
#      helper writes a signal file and exits, no daemon, no queue mutation,
#      no lease change).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ROUTE="$ROOT/bin/fm-provider-route.sh"
WATCH="$ROOT/bin/fm-provider-route-watch.sh"

LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-provider-route-watch.XXXXXX")
STATE_DIR="$LAB/state"
QUOTA_DIR="$LAB/quota"
mkdir -p "$STATE_DIR" "$QUOTA_DIR"
trap 'rm -rf "$LAB"' EXIT

FIXTURE_A="$QUOTA_DIR/a.json"
FIXTURE_B="$QUOTA_DIR/b.json"
FIXTURE_C="$QUOTA_DIR/c.json"

# Fixture A: AGY scope=gemini (off-peak UTC 12:55) — ready for agy + minimax
cat > "$FIXTURE_A" <<'JSON'
{"schemaVersion":5,"providers":[
  {"provider":"agy","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"gemini","status":"known","effectivePercentRemaining":90,"selection":{"status":"known"}}]}},
  {"provider":"minimax","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":70,"selection":{"status":"known"}}]}},
  {"provider":"codex","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":55,"selection":{"status":"known"}}]}},
  {"provider":"zai","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":80,"selection":{"status":"known"}}]}}
]}
JSON

# Fixture B: AGY quota semantics unknown — route stays blocked
cat > "$FIXTURE_B" <<'JSON'
{"schemaVersion":5,"providers":[
  {"provider":"agy","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"unknown","effectiveAvailability":[]}},
  {"provider":"minimax","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":70,"selection":{"status":"known"}}]}},
  {"provider":"codex","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":55,"selection":{"status":"known"}}]}}
]}
JSON

# Fixture C: AGY scope=gemini, peak UTC 08:00 — ready for agy + codex review
cat > "$FIXTURE_C" <<'JSON'
{"schemaVersion":5,"providers":[
  {"provider":"agy","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"gemini","status":"known","effectivePercentRemaining":90,"selection":{"status":"known"}}]}},
  {"provider":"minimax","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":70,"selection":{"status":"known"}}]}},
  {"provider":"codex","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":55,"selection":{"status":"known"}}]}},
  {"provider":"zai","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":80,"selection":{"status":"known"}}]}}
]}
JSON

AT_OFFPEAK=$(TZ=UTC date -d '2026-09-16 12:55:00' +%s)
AT_PEAK=$(TZ=UTC date -d '2026-09-16 08:00:00' +%s)

assert_signal() {
  local label=$1 expected=$2 got
  got=$(cat "$STATE_DIR/.provider-route-watch.signal" 2>/dev/null || echo 'absent')
  [[ "$got" == "$expected" ]] || {
    printf 'FAIL %s: expected signal=%s got=%s\n' "$label" "$expected" "$got" >&2
    exit 1
  }
  printf 'ok - %s (signal=%s)\n' "$label" "$got"
}

assert_fp_updated() {
  local label=$1 prior=$2
  local cur
  cur=$(cat "$STATE_DIR/.provider-route-watch.fingerprint" 2>/dev/null || echo '')
  [[ -n "$cur" && "$cur" != "$prior" ]] || {
    printf 'FAIL %s: fingerprint not updated (prior=%s cur=%s)\n' "$label" "$prior" "$cur" >&2
    exit 1
  }
  printf 'ok - %s (fingerprint changed)\n' "$label"
}

assert_fp_unchanged() {
  local label=$1 prior=$2
  local cur
  cur=$(cat "$STATE_DIR/.provider-route-watch.fingerprint" 2>/dev/null || echo '')
  [[ "$cur" == "$prior" ]] || {
    printf 'FAIL %s: fingerprint changed unexpectedly (prior=%s cur=%s)\n' "$label" "$prior" "$cur" >&2
    exit 1
  }
  printf 'ok - %s (fingerprint identical)\n' "$label"
}

# 1. First observation: NO_PRIOR, fingerprint written.
out=$("$WATCH" --state-dir "$STATE_DIR" --quota-file "$FIXTURE_A" --at "$AT_OFFPEAK" 2>&1) || {
  printf 'FAIL first observation exit non-zero\n%s\n' "$out" >&2; exit 1; }
printf '%s' "$out" | grep -q '^WATCH_SIGNAL=NO_PRIOR$' || {
  printf 'FAIL first observation expected WATCH_SIGNAL=NO_PRIOR\n%s\n' "$out" >&2; exit 1; }
assert_signal 'first observation records NO_PRIOR' NO_PRIOR
FP1=$(cat "$STATE_DIR/.provider-route-watch.fingerprint")
[[ -n "$FP1" ]] || { printf 'FAIL first observation wrote no fingerprint\n' >&2; exit 1; }
printf 'ok - first observation wrote fingerprint=%s\n' "$FP1"

# 2. Identical snapshot: NO_CHANGE, fingerprint unchanged.
out=$("$WATCH" --state-dir "$STATE_DIR" --quota-file "$FIXTURE_A" --at "$AT_OFFPEAK" 2>&1) || {
  printf 'FAIL identical snapshot exit non-zero\n%s\n' "$out" >&2; exit 1; }
assert_signal 'identical snapshot surfaces NO_CHANGE' NO_CHANGE
assert_fp_unchanged 'identical snapshot leaves fingerprint untouched' "$FP1"

# 3. Blocked quota: DEFER_ACTIVE_RUN, fingerprint updated.
out=$("$WATCH" --state-dir "$STATE_DIR" --quota-file "$FIXTURE_B" --at "$AT_OFFPEAK" 2>&1) || {
  printf 'FAIL blocked snapshot exit non-zero\n%s\n' "$out" >&2; exit 1; }
assert_signal 'blocked quota surfaces DEFER_ACTIVE_RUN' DEFER_ACTIVE_RUN
assert_fp_updated 'blocked quota updates fingerprint' "$FP1"
FP2=$(cat "$STATE_DIR/.provider-route-watch.fingerprint")

# 4. Ready with peak schedule (Codex review instead of MiniMax): HANDOFF_PENDING.
out=$("$WATCH" --state-dir "$STATE_DIR" --quota-file "$FIXTURE_C" --at "$AT_PEAK" 2>&1) || {
  printf 'FAIL peak window exit non-zero\n%s\n' "$out" >&2; exit 1; }
assert_signal 'ready + changed snapshot surfaces HANDOFF_PENDING' HANDOFF_PENDING
assert_fp_updated 'peak schedule updates fingerprint' "$FP2"

# 5. Provider-routing isolation invariants: the helper wrote only the three
#    named files inside STATE_DIR; nothing outside, no daemon, no queue, no
#    lease, no Herdr pane mutation.
expected_files=(.provider-route-watch.fingerprint .provider-route-watch.signal .provider-route-watch.last-output)
for f in "${expected_files[@]}"; do
  [[ -e "$STATE_DIR/$f" ]] || { printf 'FAIL expected file missing: %s\n' "$f" >&2; exit 1; }
done
file_count=$(find "$STATE_DIR" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
expected_count=$(printf '%s\n' "${expected_files[@]}" | sort)
[[ "$file_count" == "$expected_count" ]] || {
  printf 'FAIL unexpected files in STATE_DIR\nfound:\n%s\nexpected:\n%s\n' "$file_count" "$expected_count" >&2; exit 1; }
printf 'ok - STATE_DIR contains exactly the three named observation files\n'

# 6. Usage errors are caught (missing --state-dir / unreadable quota-file).
if "$WATCH" --quota-file "$FIXTURE_A" --at "$AT_OFFPEAK" >/dev/null 2>&1; then
  printf 'FAIL missing --state-dir should exit non-zero\n' >&2; exit 1
fi
if "$WATCH" --state-dir "$STATE_DIR" --quota-file /nonexistent/quota.json --at "$AT_OFFPEAK" >/dev/null 2>&1; then
  printf 'FAIL unreadable --quota-file should exit non-zero\n' >&2; exit 1
fi
printf 'ok - usage errors exit non-zero (missing state-dir, unreadable quota-file)\n'

echo "PASS: provider route observation is bounded, deterministic, and read-only"
