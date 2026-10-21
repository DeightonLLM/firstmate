#!/usr/bin/env bash
# tests/fm-watch-supervise.test.sh - behaviour tests for bin/fm-watch-supervise.sh,
# the arm owner that gives the minimax-code primary a continuous, self-owned
# supervision cycle.
#
# HERMETIC BY CONSTRUCTION:
#   - Every run gets its own FM_HOME and FM_STATE_OVERRIDE under a temp root.
#   - The real bin/fm-watch-arm.sh is NEVER executed: FM_WATCH_SUPERVISE_ARM
#     points at a stub arm that prints a scripted wake reason. The live
#     watcher, the live watch lock, the live board and every real pane are
#     therefore untouched by this suite.
#   - The crew-state reader is stubbed too (FM_CREW_STATE_BIN), so the shared
#     classifier's absorb decision is deterministic and no no-mistakes call is
#     ever made.
#
# The six behaviours under test are the ones the lane was opened for:
#   1. a routine wake does not stop the loop and produces no escalation
#   2. a captain-relevant wake does stop the loop and the escalation names it
#   3. the bounded park interval exits with a summary
#   4. a watcher that cannot be kept alive exits non-zero with a loud line
#   5. the script never uses a shell `&` for the watcher
#   6. the loop survives at least three consecutive routine wakes with no
#      operator re-run in between
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPERVISE="$ROOT/bin/fm-watch-supervise.sh"
fail=0
checks=0

say() { printf '%s\n' "$*"; }
ok()  { checks=$((checks + 1)); printf 'ok   %s\n' "$*"; }
bad() { checks=$((checks + 1)); fail=$((fail + 1)); printf 'FAIL %s\n' "$*"; }
fatal() { printf 'FAIL %s\n' "$*"; exit 1; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/fm-watch-supervise.XXXXXX") || fatal "could not create a temp root"
cleanup() { rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT

# A portable bounded runner: timeout, gtimeout, or perl's alarm.
run_bounded() {  # <seconds> <cmd...>
  local secs=$1; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
  fi
}

[ -x "$SUPERVISE" ] || fatal "missing or non-executable $SUPERVISE"

# --- the stub arm ------------------------------------------------------------
# It prints the arm's readiness line, then the next scripted wake reason, then
# exits 0. When the fixture runs out it repeats its last line, so a bounded
# park test can keep producing routine wakes.
STUB_ARM="$TMP/stub-arm.sh"
cat > "$STUB_ARM" <<'STUB'
#!/usr/bin/env bash
set -u
fixture=${FM_STUB_ARM_FIXTURE:?}
counter=${FM_STUB_ARM_COUNTER:?}
n=$(cat "$counter" 2>/dev/null || printf '0')
n=$((n + 1))
printf '%s\n' "$n" > "$counter"
printf 'watcher: started pid=%s (beacon fresh)\n' "$$"
last=$(sed -n "${n}p" "$fixture")
if [ -z "$last" ]; then
  last=$(sed -n '$p' "$fixture")
fi
[ -n "$last" ] || exit 0
printf '%s\n' "$last"
sleep "${FM_STUB_ARM_DELAY:-0}"
exit 0
STUB
chmod +x "$STUB_ARM"

# A stub arm that fails the way a real arm fails when no watcher is alive.
STUB_ARM_FAIL="$TMP/stub-arm-fail.sh"
cat > "$STUB_ARM_FAIL" <<'STUB'
#!/usr/bin/env bash
set -u
counter=${FM_STUB_ARM_COUNTER:?}
n=$(cat "$counter" 2>/dev/null || printf '0')
n=$((n + 1))
printf '%s\n' "$n" > "$counter"
printf 'watcher: FAILED - no live watcher with a fresh beacon\n'
exit 1
STUB
chmod +x "$STUB_ARM_FAIL"

# A stub arm that prints the readiness line and then HOLDS the cycle open, the
# way a real watcher holds a cycle open while it waits for a wake. It exists to
# prove that the readiness line reaches the caller while the cycle is still
# running, instead of sitting in a stdio buffer until the cycle closes.
STUB_ARM_HOLD="$TMP/stub-arm-hold.sh"
cat > "$STUB_ARM_HOLD" <<'STUB'
#!/usr/bin/env bash
set -u
counter=${FM_STUB_ARM_COUNTER:?}
n=$(cat "$counter" 2>/dev/null || printf '0')
n=$((n + 1))
printf '%s\n' "$n" > "$counter"
printf 'watcher: started pid=%s (beacon fresh)\n' "$$"
sleep "${FM_STUB_ARM_HOLD_SECS:-30}"
printf 'signal: %s\n' "${FM_STUB_ARM_HOLD_REASON:-signal: held}"
exit 0
STUB
chmod +x "$STUB_ARM_HOLD"

# --- the stub crew-state reader ----------------------------------------------
# The shared classifier reads one "state: <s> source: <src> ..." line per crew.
STUB_CREW="$TMP/stub-crew-state.sh"
cat > "$STUB_CREW" <<'STUB'
#!/usr/bin/env bash
set -u
verdict=${FM_STUB_CREW_VERDICT:?}
printf '%s\n' "$verdict"
exit 0
STUB
chmod +x "$STUB_CREW"

# --- one isolated home per case ----------------------------------------------
CASE=0
new_home() {  # <name> -> exports HOME_DIR, STATE_DIR, FIXTURE, COUNTER, OUT
  CASE=$((CASE + 1))
  HOME_DIR="$TMP/case-$CASE"
  STATE_DIR="$HOME_DIR/state"
  mkdir -p "$STATE_DIR" "$HOME_DIR/config"
  FIXTURE="$TMP/case-$CASE.fixture"
  COUNTER="$TMP/case-$CASE.counter"
  OUT="$TMP/case-$CASE.out"
  : > "$FIXTURE"
  : > "$COUNTER"
  export FM_HOME="$HOME_DIR"
  export FM_STATE_OVERRIDE="$STATE_DIR"
  export FM_CONFIG_OVERRIDE="$HOME_DIR/config"
  export FM_STUB_ARM_FIXTURE="$FIXTURE"
  export FM_STUB_ARM_COUNTER="$COUNTER"
  export FM_CREW_STATE_BIN="$STUB_CREW"
  export FM_WATCH_SUPERVISE_CYCLE_GAP_SECS=0
  export FM_WATCH_SUPERVISE_PARK_SECS=60
  export FM_WATCH_SUPERVISE_ARM_ATTEMPTS=1
}

# A routine wake: a no-verb status on a crew the classifier proves is working.
routine_status() {  # <task>
  printf 'working: lane %s is still running\n' "$1" > "$STATE_DIR/$1.status"
}

# A captain-relevant wake: a terminal verb on the crew's status.
terminal_status() {  # <task>
  printf 'done: lane %s shipped the fix\n' "$1" > "$STATE_DIR/$1.status"
}

# The script's CODE, with comments removed: the textual proofs below are about
# what the script DOES, not about what its header says about itself.
code_lines() {  # <file>
  sed -e 's/[[:space:]]*#.*$//' "$1" | grep -v '^[[:space:]]*$'
}

# ============================================================================
# 1 + 6. A routine wake does not stop the loop, produces no escalation, and the
#         loop survives at least three consecutive routine wakes with no
#         operator re-run in between.
# ============================================================================
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
export FM_STUB_CREW_VERDICT='state: working · source: run-step · stub'
export FM_STUB_ARM_DELAY=0.2
export FM_WATCH_SUPERVISE_PARK_SECS=3
routine_status lane1
{
  printf 'signal: %s\n' "$STATE_DIR/lane1.status"
  printf 'signal: %s\n' "$STATE_DIR/lane1.status"
  printf 'signal: %s\n' "$STATE_DIR/lane1.status"
} > "$FIXTURE"

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?
runs=$(cat "$COUNTER" 2>/dev/null || printf '0')
absorbed=$(grep -c 'routine wake absorbed' "$OUT" 2>/dev/null || printf '0')

if [ "$rc" -eq 0 ]; then
  ok "routine wakes: the supervisor ends on its own park bound with exit 0"
else
  bad "routine wakes: expected exit 0, got $rc"
  sed 's/^/       /' "$OUT"
fi

if [ "$absorbed" -ge 3 ]; then
  ok "routine wakes: at least three consecutive routine wakes were absorbed ($absorbed)"
else
  bad "routine wakes: expected at least 3 absorbed routine wakes, got $absorbed"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'ESCALATION' "$OUT" 2>/dev/null; then
  bad "routine wakes: a routine wake must not produce an escalation"
  sed 's/^/       /' "$OUT"
else
  ok "routine wakes: no escalation was produced"
fi

if [ "$runs" -ge 4 ]; then
  ok "the loop re-armed itself: the arm ran $runs times inside ONE supervisor run"
else
  bad "the loop did not survive three consecutive routine wakes: arm ran $runs time(s)"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'watcher: started pid=' "$OUT" 2>/dev/null; then
  ok "the arm's readiness line is relayed as soon as the watcher is verified"
else
  bad "the arm's readiness line was never relayed"
  sed 's/^/       /' "$OUT"
fi

# The supervisor must have kept its own state inside the temporary home. The
# supervisor lock is released on exit, so the log is the durable witness.
if [ -f "$STATE_DIR/.watch-supervise.log" ]; then
  ok "the supervisor kept its state inside the temporary home (the live home was untouched)"
else
  bad "the supervisor did not keep its state inside the temporary home"
  ls -la "$STATE_DIR" | sed 's/^/       /'
fi

# Nothing this suite ran may have written into the live home's state dir.
live_state="$ROOT/state"
if [ -d "$live_state" ] && ls "$live_state"/.watch-supervise* >/dev/null 2>&1; then
  bad "the supervisor wrote an artifact into the live home's state directory"
  ls -la "$live_state"/.watch-supervise* | sed 's/^/       /'
else
  ok "no supervisor artifact was written into the live home's state directory"
fi

# ============================================================================
# 2. A captain-relevant wake stops the loop and the escalation names it.
# ============================================================================
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
export FM_STUB_CREW_VERDICT='state: working · source: run-step · stub'
routine_status lane1
terminal_status lane2
{
  printf 'signal: %s\n' "$STATE_DIR/lane1.status"
  printf 'signal: %s\n' "$STATE_DIR/lane2.status"
  printf 'signal: %s\n' "$STATE_DIR/lane2.status"
} > "$FIXTURE"

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?
runs=$(cat "$COUNTER" 2>/dev/null || printf '0')

if [ "$rc" -eq 0 ]; then
  ok "captain-relevant wake: the supervisor exits 0 after handing the wake back"
else
  bad "captain-relevant wake: expected exit 0, got $rc"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'ESCALATION' "$OUT" 2>/dev/null; then
  ok "captain-relevant wake: an escalation was printed"
else
  bad "captain-relevant wake: no escalation was printed"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'done: lane lane2 shipped the fix' "$OUT" 2>/dev/null; then
  ok "captain-relevant wake: the escalation names the wake"
else
  bad "captain-relevant wake: the escalation does not name the wake"
  sed 's/^/       /' "$OUT"
fi

if [ "$runs" -eq 2 ]; then
  ok "captain-relevant wake: the loop stopped on the escalation (arm ran $runs times)"
else
  bad "captain-relevant wake: the loop did not stop on the escalation (arm ran $runs times)"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'routine wake absorbed (signal: '"$STATE_DIR"'/lane1.status)' "$OUT" 2>/dev/null; then
  ok "captain-relevant wake: the routine wake before it was absorbed, not escalated"
else
  bad "captain-relevant wake: the preceding routine wake was not absorbed"
  sed 's/^/       /' "$OUT"
fi

# ============================================================================
# 3. The bounded park interval exits with a compact summary.
# ============================================================================
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
export FM_STUB_CREW_VERDICT='state: working · source: run-step · stub'
export FM_WATCH_SUPERVISE_PARK_SECS=2
export FM_STUB_ARM_DELAY=0.2
routine_status lane1
printf 'signal: %s\n' "$STATE_DIR/lane1.status" > "$FIXTURE"

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?
runs=$(cat "$COUNTER" 2>/dev/null || printf '0')

if [ "$rc" -eq 0 ]; then
  ok "park interval: the supervisor exits 0 when the park bound is reached"
else
  bad "park interval: expected exit 0, got $rc"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'PARKED after' "$OUT" 2>/dev/null; then
  ok "park interval: the park exit is announced"
else
  bad "park interval: no park exit was announced"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'summary cycles=' "$OUT" 2>/dev/null; then
  ok "park interval: the park exit carries a compact summary"
else
  bad "park interval: the park exit carries no summary"
  sed 's/^/       /' "$OUT"
fi

if [ "$runs" -ge 2 ]; then
  ok "park interval: the supervisor kept the cycle alive across the park window (arm ran $runs times)"
else
  bad "park interval: the supervisor did not keep the cycle alive (arm ran $runs time(s))"
  sed 's/^/       /' "$OUT"
fi

# ============================================================================
# 4. A watcher that cannot be kept alive produces a non-zero exit and a loud
#    line.
# ============================================================================
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM_FAIL"
export FM_WATCH_SUPERVISE_ARM_ATTEMPTS=2
export FM_STUB_ARM_DELAY=0
export FM_STUB_CREW_VERDICT='state: stopped · source: none · stub'

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?
runs=$(cat "$COUNTER" 2>/dev/null || printf '0')

if [ "$rc" -ne 0 ]; then
  ok "failed watcher: the supervisor exits non-zero ($rc)"
else
  bad "failed watcher: expected a non-zero exit, got 0"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'supervise: FAILED' "$OUT" 2>/dev/null; then
  ok "failed watcher: the failure is loud"
else
  bad "failed watcher: no loud failure line was printed"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'supervision is DOWN' "$OUT" 2>/dev/null; then
  ok "failed watcher: the failure says supervision is down"
else
  bad "failed watcher: the failure does not say supervision is down"
  sed 's/^/       /' "$OUT"
fi

if [ "$runs" -eq 2 ]; then
  ok "failed watcher: the arm was retried within the attempt budget (arm ran $runs times)"
else
  bad "failed watcher: expected 2 attempts, the arm ran $runs time(s)"
  sed 's/^/       /' "$OUT"
fi

# ============================================================================
# 5. The script never uses a shell `&` for the watcher.
#    The proof is textual and mechanical: after every file-descriptor
#    duplication (2>&1 and friends) is removed, no `&` remains anywhere in the
#    script, and the script never names the watcher itself - the watcher is
#    launched only by bin/fm-watch-arm.sh, as that arm's own tracked child.
# ============================================================================
stripped=$(code_lines "$SUPERVISE" | sed -E 's/&>>/>/g; s/[0-9]*>&[0-9-]//g; s/&&//g; s/&>//g')
if printf '%s\n' "$stripped" | grep -q '&'; then
  bad "the script uses a shell '&' somewhere"
  printf '%s\n' "$stripped" | grep -n '&' | sed 's/^/       /'
else
  ok "the script contains no shell '&' at all (no backgrounded child, least of all the watcher)"
fi

if code_lines "$SUPERVISE" | grep -q 'fm-watch\.sh'; then
  bad "the script references the watcher directly"
  code_lines "$SUPERVISE" | grep -n 'fm-watch\.sh' | sed 's/^/       /'
else
  ok "the script never launches the watcher: only bin/fm-watch-arm.sh does"
fi

if code_lines "$SUPERVISE" | grep -q 'fm-watch-arm\.sh'; then
  ok "the script owns the cycle through bin/fm-watch-arm.sh"
else
  bad "the script does not run bin/fm-watch-arm.sh"
fi

if code_lines "$SUPERVISE" | grep -Eq '(^|[^0-9&])&[[:space:]]*$'; then
  bad "the script backgrounds a command with a trailing '&'"
  code_lines "$SUPERVISE" | grep -En '(^|[^0-9&])&[[:space:]]*$' | sed 's/^/       /'
else
  ok "the script backgrounds no command"
fi

# ============================================================================
# 7. The readiness line is delivered WHILE the cycle is still running.
#    The arm's "watcher: started ..." line must reach the caller the moment it
#    is printed, so a caller waiting for readiness sees it immediately. A
#    block-buffered pipe would hold the line until the cycle closed, which is
#    exactly the failure this check exists to catch: the supervisor is killed
#    mid-cycle here, so anything still buffered is lost.
# ============================================================================
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM_HOLD"
export FM_STUB_ARM_HOLD_SECS=30
export FM_STUB_CREW_VERDICT='state: working · source: run-step · stub'
routine_status lane1
printf 'signal: %s\n' "$STATE_DIR/lane1.status" > "$FIXTURE"

run_bounded 3 "$SUPERVISE" > "$OUT" 2>&1
rc=$?
if grep -q 'watcher: started pid=' "$OUT" 2>/dev/null; then
  ok "readiness: the arm's readiness line reached the caller while the cycle was still open"
else
  bad "readiness: the readiness line never reached the caller (it was buffered until the cycle closed)"
  sed 's/^/       /' "$OUT"
fi
if [ "$rc" -ne 0 ]; then
  ok "readiness: the supervisor was still inside the cycle when the bounded runner stopped it"
else
  bad "readiness: expected the bounded runner to stop the supervisor, got exit $rc"
fi

# ============================================================================
# House-style checks on the new script itself.
# ============================================================================
if bash -n "$SUPERVISE" 2>/dev/null; then
  ok "bash -n is clean"
else
  bad "bash -n failed"
fi

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S error "$SUPERVISE" >/dev/null 2>&1; then
    ok "shellcheck reports no errors"
  else
    bad "shellcheck reported errors"
    shellcheck -S error "$SUPERVISE" 2>&1 | head -20 | sed 's/^/       /'
  fi
fi

for needle in 'WHAT IT DOES' 'WHAT IT NEVER DOES' 'OUTPUT LINES' 'EXIT STATUS'; do
  if grep -q "$needle" "$SUPERVISE"; then
    ok "the header documents '$needle'"
  else
    bad "the header does not document '$needle'"
  fi
done

say ""
if [ "$fail" -eq 0 ]; then
  say "ALL TESTS PASSED ($checks checks)"; exit 0
fi
say "$fail of $checks CHECK(S) FAILED"; exit 1
