#!/usr/bin/env bash
# tests/fm-watch-supervise-handback.test.sh - the hand-back keeps supervision ON.
#
# THE DEFECT THIS SUITE IS FOR
#   The watcher is one-shot by contract: bin/fm-watch.sh blocks until it has an
#   actionable wake to surface, prints one reason line, and exits. So when
#   bin/fm-watch-supervise.sh hands a captain-relevant wake back to the primary,
#   the cycle that surfaced it is already gone and NOTHING is watching the fleet
#   until the primary starts the next supervisor. On a primary with no native
#   turn-end hook that gap is unbounded, which is how a lane crash went
#   unnoticed for twenty hours on a host whose supervision was already known to
#   be down.
#
#   The hand-back must leave supervision ON: it starts ONE successor watcher
#   cycle, proves it is alive with the arm's own readiness line, and records it
#   so the next supervisor takes that cycle over instead of racing it. A
#   hand-back that cannot leave a live cycle behind is not a clean hand-back:
#   the supervisor says so loudly and exits non-zero.
#
# HERMETIC BY CONSTRUCTION
#   - Every case gets its own FM_HOME and FM_STATE_OVERRIDE under a temp root.
#   - The real bin/fm-watch-arm.sh is NEVER executed: FM_WATCH_SUPERVISE_ARM
#     points at a stub arm that prints a scripted wake reason and holds the
#     cycle open the way a real watcher does. No live watcher, no live watch
#     lock, no live board and no real pane is touched by this suite.
#   - The crew-state reader is stubbed too (FM_CREW_STATE_BIN), so the shared
#     classifier's absorb decision is deterministic and no no-mistakes call is
#     ever made.
#
# THE SCRIPT UNDER TEST IS A SEAM
#   FM_WATCH_SUPERVISE_UNDER_TEST names the bin/fm-watch-supervise.sh this
#   suite drives, and defaults to the one in this repo. That is what lets the
#   SAME suite run against a mechanically extracted OLD copy of the script
#   (git show <ref>:bin/fm-watch-supervise.sh into a temp bin/ directory) to
#   prove the suite is RED before the fix and GREEN after it.
#
# THE FIVE BEHAVIOURS UNDER TEST
#   1. a captain-relevant wake hands back with a LIVE watcher cycle behind it
#   2. the bounded park hands back with a LIVE watcher cycle behind it
#   3. a hand-back that cannot leave a live cycle fails loudly and exits
#      non-zero
#   4. the next supervisor takes the recorded successor over and clears it
#   5. the LIVE incident shape (the crew-silent escalation the primary hit on
#      2026-10-24) hands back with a LIVE watcher cycle behind it
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPERVISE="${FM_WATCH_SUPERVISE_UNDER_TEST:-$ROOT/bin/fm-watch-supervise.sh}"
fail=0
checks=0

say() { printf '%s\n' "$*"; }
ok()  { checks=$((checks + 1)); printf 'ok   %s\n' "$*"; }
bad() { checks=$((checks + 1)); fail=$((fail + 1)); printf 'FAIL %s\n' "$*"; }
fatal() { printf 'FAIL %s\n' "$*"; exit 1; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/fm-watch-supervise-handback.XXXXXX") || fatal "could not create a temp root"

# The successor arm this suite starts is a process THIS suite started, so it is
# this suite's to stop. Every recorded successor is stopped on the way out.
SUCC_PIDS=""
# shellcheck disable=SC2329 # Invoked by the EXIT trap below, not by name.
cleanup() {
  local p
  for p in $SUCC_PIDS; do
    [ -n "$p" ] || continue
    kill -TERM "$p" 2>/dev/null || true
  done
  rm -rf "$TMP" 2>/dev/null || true
}
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
# The arm this suite runs instead of the real bin/fm-watch-arm.sh.
#
#   mode=hold-successor   the first invocation is the supervisor's own cycle
#                         (readiness line, then the scripted wake); every later
#                         invocation is the hand-back successor and HOLDS the
#                         cycle open, the way a real watcher holds a cycle open
#                         while it waits for a wake.
#   mode=fail-successor   the first invocation is the supervisor's own cycle;
#                         the successor invocation fails the way a real arm
#                         fails when no watcher can be kept alive, and never
#                         prints a readiness line.
#
# The readiness line is printed to whichever stdout the caller gave the arm:
# the supervisor's own cycle prints it to the supervisor's stdout, and the
# successor prints it to the supervisor's successor output file.
STUB_ARM="$TMP/stub-arm.sh"
cat > "$STUB_ARM" <<'STUB'
#!/usr/bin/env bash
set -u
counter=${FM_STUB_ARM_COUNTER:?}
mode=${FM_STUB_ARM_MODE:-wake}
# The hand-back successor is started with the arm's own --restart mode: it owns
# a FRESH cycle of its own and is NOT a cycle of the supervisor's loop, so it
# does not consume a fixture line.
if [ "${1:-}" = "--restart" ]; then
  case "$mode" in
    fail-successor)
      # The successor fails the way a real arm fails when no watcher can be
      # kept alive, and it never reports a readiness line.
      printf 'watcher: FAILED - no live watcher with a fresh beacon\n'
      exit 1
      ;;
  esac
  printf 'watcher: started pid=%s (beacon fresh)\n' "$$"
  # The successor holds the cycle open, the way a real watcher holds a cycle
  # open while it waits for a wake.
  sleep "${FM_STUB_ARM_HOLD_SECS:-120}"
  exit 0
fi
n=$(cat "$counter" 2>/dev/null || printf '0')
n=$((n + 1))
printf '%s\n' "$n" > "$counter"
printf 'watcher: started pid=%s (beacon fresh)\n' "$$"
case "$mode" in
  fail-successor)
    printf '%s\n' "${FM_STUB_ARM_REASON:?}"
    exit 0
    ;;
  hold-successor)
    sleep "${FM_STUB_ARM_CYCLE_DELAY:-0}"
    printf '%s\n' "${FM_STUB_ARM_REASON:?}"
    exit 0
    ;;
  *)
    printf '%s\n' "${FM_STUB_ARM_REASON:?}"
    exit 0
    ;;
esac
STUB
chmod +x "$STUB_ARM"

# --- the stub crew-state reader ----------------------------------------------
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
new_home() {  # <name> -> exports HOME_DIR, STATE_DIR, COUNTER, OUT
  CASE=$((CASE + 1))
  HOME_DIR="$TMP/case-$CASE"
  STATE_DIR="$HOME_DIR/state"
  mkdir -p "$STATE_DIR" "$HOME_DIR/config"
  COUNTER="$HOME_DIR/counter"
  OUT="$HOME_DIR/out"
  : > "$COUNTER"
  export FM_HOME="$HOME_DIR"
  export FM_STATE_OVERRIDE="$STATE_DIR"
  export FM_CONFIG_OVERRIDE="$HOME_DIR/config"
  export FM_STUB_ARM_COUNTER="$COUNTER"
  export FM_CREW_STATE_BIN="$STUB_CREW"
  export FM_WATCH_SUPERVISE_CYCLE_GAP_SECS=0
  export FM_WATCH_SUPERVISE_PARK_SECS=60
  export FM_WATCH_SUPERVISE_ARM_ATTEMPTS=1
  export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
  export FM_STUB_CREW_VERDICT='state: working · source: run-step · stub'
}

# A routine wake: a no-verb status on a crew the classifier proves is working.
routine_status() {  # <task>
  printf 'working: lane %s is still running\n' "$1" > "$STATE_DIR/$1.status"
}

# A captain-relevant wake: a terminal verb on the crew's status.
terminal_status() {  # <task>
  printf 'done: lane %s shipped the fix\n' "$1" > "$STATE_DIR/$1.status"
}

# The successor a hand-back left, as "pid<TAB>identity".
# These are resolved per case, because STATE_DIR is per case.
recorded_successor_pid() {
  local pid='' record="$STATE_DIR/.watch-supervise-successor"
  [ -f "$record" ] || return 1
  IFS="$(printf '\t')" read -r pid _ < "$record" 2>/dev/null || true
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s\n' "$pid"
}

pid_alive() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ -d "/proc/$1" ]
}

# ============================================================================
# 1. A captain-relevant wake hands back with a LIVE watcher cycle behind it.
# ============================================================================
new_home
export FM_STUB_ARM_MODE=hold-successor
export FM_STUB_ARM_HOLD_SECS=120
terminal_status lane2
export FM_STUB_ARM_REASON="signal: $STATE_DIR/lane2.status"

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?

if [ "$rc" -eq 0 ]; then
  ok "hand-back: the supervisor exits 0 after handing the wake back"
else
  bad "hand-back: expected exit 0, got $rc"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'ESCALATION' "$OUT" 2>/dev/null; then
  ok "hand-back: an escalation was printed"
else
  bad "hand-back: no escalation was printed"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'supervision is handed back to the primary with a live watcher cycle' "$OUT" 2>/dev/null; then
  ok "hand-back: the hand-back says it left a live watcher cycle behind"
else
  bad "hand-back: the hand-back does not claim a live watcher cycle"
  sed 's/^/       /' "$OUT"
fi

succ_pid=$(recorded_successor_pid || true)
if [ -n "$succ_pid" ]; then
  SUCC_PIDS="$SUCC_PIDS $succ_pid"
  if pid_alive "$succ_pid"; then
    ok "hand-back: a watcher cycle is STILL ALIVE after the hand-back (pid $succ_pid)"
  else
    bad "hand-back: the recorded successor (pid $succ_pid) is not alive - supervision was left off"
  fi
  if grep -qE '^watcher: (started|attached) ' "$STATE_DIR/.watch-supervise-successor.out" 2>/dev/null; then
    ok "hand-back: the successor was proven live by the arm's own readiness line"
  else
    bad "hand-back: the successor never reported a readiness line"
    sed 's/^/       /' "$STATE_DIR/.watch-supervise-successor.out" 2>/dev/null
  fi
else
  bad "hand-back: no successor cycle was left behind - supervision was left off across the hand-back"
  sed 's/^/       /' "$OUT"
fi

# ============================================================================
# 2. The bounded park hands back with a LIVE watcher cycle behind it.
# ============================================================================
new_home
export FM_STUB_ARM_MODE=hold-successor
export FM_STUB_ARM_HOLD_SECS=120
# The park bound is a test PARAMETER: it decides how long the loop runs. The
# first cycle outlives it, so the park fires on the first cycle boundary.
export FM_WATCH_SUPERVISE_PARK_SECS=1
export FM_STUB_ARM_CYCLE_DELAY=1.5
routine_status lane1
export FM_STUB_ARM_REASON="signal: $STATE_DIR/lane1.status"

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?

if [ "$rc" -eq 0 ]; then
  ok "park hand-back: the supervisor exits 0 when the park bound is reached"
else
  bad "park hand-back: expected exit 0, got $rc"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'PARKED after' "$OUT" 2>/dev/null; then
  ok "park hand-back: the park exit is announced"
else
  bad "park hand-back: no park exit was announced"
  sed 's/^/       /' "$OUT"
fi

succ_pid=$(recorded_successor_pid || true)
if [ -n "$succ_pid" ]; then
  SUCC_PIDS="$SUCC_PIDS $succ_pid"
  if pid_alive "$succ_pid"; then
    ok "park hand-back: a watcher cycle is STILL ALIVE after the park (pid $succ_pid)"
  else
    bad "park hand-back: the recorded successor (pid $succ_pid) is not alive - supervision was left off"
  fi
else
  bad "park hand-back: no successor cycle was left behind - supervision was left off across the park"
  sed 's/^/       /' "$OUT"
fi

# ============================================================================
# 3. A hand-back that cannot leave a live cycle fails loudly and exits
#    non-zero. A hand-back that leaves no watcher is NOT a clean hand-back.
# ============================================================================
new_home
export FM_STUB_ARM_MODE=fail-successor
terminal_status lane2
export FM_STUB_ARM_REASON="signal: $STATE_DIR/lane2.status"

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?

if [ "$rc" -ne 0 ]; then
  ok "failed hand-back: the supervisor exits non-zero ($rc)"
else
  bad "failed hand-back: expected a non-zero exit, got 0 - a hand-back with no watcher claimed to be clean"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'supervise: FAILED' "$OUT" 2>/dev/null; then
  ok "failed hand-back: the failure is loud"
else
  bad "failed hand-back: no loud failure line was printed"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'supervision is DOWN' "$OUT" 2>/dev/null; then
  ok "failed hand-back: the failure says supervision is down"
else
  bad "failed hand-back: the failure does not say supervision is down"
  sed 's/^/       /' "$OUT"
fi

# ============================================================================
# 4. The next supervisor takes the recorded successor over: the recorded arm is
#    retired and the record is cleared, so the next cycle FORKS the watcher it
#    owns and can read its reason when the cycle closes.
# ============================================================================
new_home
export FM_STUB_ARM_MODE=hold-successor
export FM_STUB_ARM_HOLD_SECS=120
terminal_status lane2
export FM_STUB_ARM_REASON="signal: $STATE_DIR/lane2.status"

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
first_succ=$(recorded_successor_pid || true)
if [ -n "$first_succ" ]; then
  SUCC_PIDS="$SUCC_PIDS $first_succ"
fi

if [ -n "$first_succ" ]; then
  # The next supervisor starts in the same home and takes the cycle over.
  : > "$COUNTER"
  run_bounded 30 "$SUPERVISE" > "$OUT.2" 2>&1
  second_succ=$(recorded_successor_pid || true)
  if [ -n "$second_succ" ]; then
    SUCC_PIDS="$SUCC_PIDS $second_succ"
  fi
  if ! pid_alive "$first_succ"; then
    ok "take-over: the next supervisor retired the successor the hand-back left (pid $first_succ)"
  else
    bad "take-over: the successor the hand-back left is still running (pid $first_succ) - two owners race for one cycle"
  fi
  if [ -z "$second_succ" ] || [ "$second_succ" != "$first_succ" ]; then
    ok "take-over: the next supervisor owns a cycle of its own"
  else
    bad "take-over: the next supervisor reused the retired successor"
  fi
else
  bad "take-over: there was no successor to take over - the hand-back left supervision off"
  sed 's/^/       /' "$OUT"
fi

# ============================================================================
# 5. THE LIVE SHAPE. The primary armed bin/fm-watch-supervise.sh twice on
#    2026-10-24 and both times the supervisor started a watcher, surfaced a
#    captain-relevant wake, printed the hand-back line and EXITED, leaving the
#    home with no supervisor and no watcher. Both wakes were the crew-silent
#    shape: "crew-silent: <lane> silent <N>s past the <G>s first-report grace;
#    never reported" against a lane that was healthy and mid-task.
#
#    This case drives that exact reason line, so the repro is the incident and
#    not a paraphrase of it.
# ============================================================================
new_home
export FM_STUB_ARM_MODE=hold-successor
export FM_STUB_ARM_HOLD_SECS=120
LIVE_LANE=mcode-m3.1f-controller-watchliveness
LIVE_WINDOW="firstmate:$LIVE_LANE"
export FM_STUB_ARM_REASON="stale: $LIVE_WINDOW (crew-silent: $LIVE_LANE silent 305s past the 300s first-report grace; never reported (window $LIVE_WINDOW))"

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?

if [ "$rc" -eq 0 ]; then
  ok "live crew-silent wake: the supervisor exits 0 after handing the wake back"
else
  bad "live crew-silent wake: expected exit 0, got $rc"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'ESCALATION' "$OUT" 2>/dev/null \
   && grep -q 'crew-silent' "$OUT" 2>/dev/null; then
  ok "live crew-silent wake: the escalation names the crew-silent breach"
else
  bad "live crew-silent wake: the escalation does not name the crew-silent breach"
  sed 's/^/       /' "$OUT"
fi

succ_pid=$(recorded_successor_pid || true)
if [ -n "$succ_pid" ]; then
  SUCC_PIDS="$SUCC_PIDS $succ_pid"
  if pid_alive "$succ_pid"; then
    ok "live crew-silent wake: a watcher cycle is STILL ALIVE after the hand-back (pid $succ_pid)"
  else
    bad "live crew-silent wake: the recorded successor (pid $succ_pid) is not alive - supervision was left off"
  fi
else
  bad "live crew-silent wake: no successor cycle was left behind - the home was left blind"
  sed 's/^/       /' "$OUT"
fi

# ============================================================================
# House-style checks on the script under test.
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

for needle in 'WHAT IT DOES' 'WHAT IT NEVER DOES' 'OUTPUT LINES' 'EXIT STATUS' \
               'THE HAND-BACK LEAVES SUPERVISION ON' 'RESTARTING THE SUPERVISOR'; do
  if grep -q "$needle" "$SUPERVISE"; then
    ok "the header documents '$needle'"
  else
    bad "the header does not document '$needle'"
  fi
done

# The script must never launch the watcher itself: bin/fm-watch-arm.sh remains
# the only thing that launches a watcher.
code_lines() {  # <file>
  sed -e 's/[[:space:]]*#.*$//' "$1" | grep -v '^[[:space:]]*$'
}
if code_lines "$SUPERVISE" | grep -q 'fm-watch\.sh'; then
  bad "the script references the watcher directly"
  code_lines "$SUPERVISE" | grep -n 'fm-watch\.sh' | sed 's/^/       /'
else
  ok "the script never launches the watcher: only bin/fm-watch-arm.sh does"
fi

# The ONLY backgrounded child is the hand-back successor ARM, and it is started
# in a process group of its own so the harness's teardown cannot reach it.
# shellcheck disable=SC2016 # A literal, not an expansion: the arm's own source text.
ARM_LITERAL='$ARM'
bg_lines=$(code_lines "$SUPERVISE" | sed -E 's/&>>/>/g; s/[0-9]*>&[0-9-]//g; s/&&//g; s/&>//g' \
  | grep -E '(^|[^0-9&])&[[:space:]]*$' || true)
if [ -z "$bg_lines" ]; then
  bad "the script backgrounds nothing - a hand-back cannot leave a survivor behind"
elif printf '%s\n' "$bg_lines" | grep -qvF "$ARM_LITERAL"; then
  bad "the script backgrounds something other than the arm"
  printf '%s\n' "$bg_lines" | sed 's/^/       /'
else
  ok "the only backgrounded child is the successor arm"
fi

if code_lines "$SUPERVISE" | grep -q 'set -m'; then
  ok "the successor is started with job control, so it gets a process group of its own"
else
  bad "the successor is not given a process group of its own - a group teardown would take it down"
fi

say ""
if [ "$fail" -eq 0 ]; then
  say "ALL TESTS PASSED ($checks checks)"; exit 0
fi
say "$fail of $checks CHECK(S) FAILED"; exit 1
