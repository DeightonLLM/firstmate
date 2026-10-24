#!/usr/bin/env bash
# tests/fm-always-four-foreground-oracle.test.sh - regression tests for the
# three-state foreground-process oracle (F4 of the 2026-10-24 no-mistakes
# review).
#
# The oracle's first guard only proved that foreground_processes is an ARRAY.
# It said nothing about the SHAPE of the entries inside it.  An entry whose
# argv is a STRING (or whose name is not a string) made the matcher's own jq
# fail, and a jq error inside an `if` condition is indistinguishable from
# "no match": the oracle answered "the pane is readable and the harness is NOT
# running" (state 1) for a pane it had not read.
#
# lane_is_active and count_active_worker_tasks act on state 1 ALONE, so
# malformed process data made a LIVE worker look dead - and therefore
# eligible to be killed and replaced.  The honest answer for a shape the
# oracle cannot read is state 2 (unknown), and unknown keeps the lane.
#
# Every assertion marked "regression" FAILS against the pre-fix tree and
# PASSES against the fixed tree.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v jq >/dev/null 2>&1 || { echo "skip: jq not found (required by the foreground oracle)"; exit 0; }

TMP_ROOT=$(fm_test_tmproot fm-always-four-foreground-oracle)
FM_TEST_CLEANUP_DIRS+=("$TMP_ROOT")
trap fm_test_cleanup EXIT

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# Source the script's functions once.  The main dispatch guard prevents the
# daemon loop from running under sourcing.
if [ -z "${FM_TEST_ALWAYS_FOUR_SOURCED:-}" ]; then
  export FM_TEST_ALWAYS_FOUR_SOURCED=1
  # shellcheck source=bin/fm-always-four.sh
  . "$ROOT/bin/fm-always-four.sh"
fi

# --- the herdr stub ----------------------------------------------------------

STUB_DIR="$TMP_ROOT/stub"
mkdir -p "$STUB_DIR"
export HERDR_STUB_DIR="$STUB_DIR"

# make_herdr_stub <dir>: a `herdr` stub that answers `pane process-info` with
# the payload in $HERDR_STUB_DIR/payload.json.
make_herdr_stub() {  # <dir>
  local dir=$1 fb="$1/fakebin"
  mkdir -p "$fb"
  cat > "$fb/herdr" <<'STUB'
#!/usr/bin/env bash
set -u
DIR="${HERDR_STUB_DIR:?}"
case "${1:-} ${2:-}" in
  "pane process-info")
    cat "$DIR/payload.json"
    ;;
  *) : ;;
esac
exit 0
STUB
  chmod +x "$fb/herdr"
  printf '%s\n' "$fb"
}

FB=$(make_herdr_stub "$TMP_ROOT/stubroot")

# oracle_state <payload>: the oracle's answer for one process-info payload.
oracle_state() {  # <payload>
  printf '%s' "$1" > "$STUB_DIR/payload.json"
  PATH="$FB:$PATH" fm_pane_foreground_harness_state herdr default:w99:p1 minimax-code
  printf '%s' "$?"
}

# --- the states ---------------------------------------------------------------

state=$(oracle_state '{"result":{"process_info":{"foreground_processes":[{"name":"minimax-code","argv":["minimax-code","--model","x"]}]}}}')
[ "$state" = 0 ] || fail "a pane running minimax-code must read as running (0), got $state"
pass "the foreground oracle reports a running harness as running"

state=$(oracle_state '{"result":{"process_info":{"foreground_processes":[{"name":"bash","argv":["/bin/bash"]}]}}}')
[ "$state" = 1 ] || fail "a readable pane running another harness must read as dead (1), got $state"
pass "the foreground oracle reports a readable pane without the harness as dead"

state=$(oracle_state '{"result":{"process_info":{"foreground_processes":[]}}}')
[ "$state" = 1 ] || fail "a readable pane with no foreground process must read as dead (1), got $state"
pass "the foreground oracle reports a readable pane with no process as dead"

state=$(oracle_state 'not json at all')
[ "$state" = 2 ] || fail "an unreadable answer must read as unknown (2), got $state"
pass "the foreground oracle reports an unreadable answer as unknown"

# --- the malformed entries ----------------------------------------------------

state=$(oracle_state '{"result":{"process_info":{"foreground_processes":[{"name":"bash","argv":"minimax-code --model x"}]}}}')
[ "$state" = 2 ] \
  || fail "regression: an entry whose argv is a STRING must read as unknown (2), not dead (1), got $state"
pass "the foreground oracle reads a string-valued argv as unknown"

state=$(oracle_state '{"result":{"process_info":{"foreground_processes":[{"name":123,"argv":["minimax-code"]}]}}}')
[ "$state" = 2 ] \
  || fail "regression: an entry whose name is not a string must read as unknown (2), got $state"
pass "the foreground oracle reads a non-string name as unknown"

state=$(oracle_state '{"result":{"process_info":{"foreground_processes":["minimax-code"]}}}')
[ "$state" = 2 ] \
  || fail "regression: an entry that is not an object must read as unknown (2), got $state"
pass "the foreground oracle reads a non-object entry as unknown"

state=$(oracle_state '{"result":{"process_info":{"foreground_processes":[{"name":"minimax-code","argv":["x"]},{"name":"bash","argv":"oops"}]}}}')
[ "$state" = 2 ] \
  || fail "regression: one malformed entry must read as unknown (2), got $state"
pass "the foreground oracle reads a malformed sibling entry as unknown"

# --- the consumer keeps a live lane -------------------------------------------

STATE_DIR="$TMP_ROOT/state"
mkdir -p "$STATE_DIR"
{
  printf 'endpoint_task_id=finished-task\n'
  printf 'window=default:finished-pane\n'
  printf 'backend=herdr\n'
  printf 'harness=codex\n'
} > "$STATE_DIR/lane-001.meta"
printf 'done: finished\n' > "$STATE_DIR/finished-task.status"

if ! (
  FM_STATE_OVERRIDE="$STATE_DIR"
  lane_current_task() { printf 'finished-task'; }
  fm_backend_target_exists() { return 0; }
  fm_backend_capture() { printf 'busy transcript'; }
  fm_busy_classify() { printf 'busy synthetic'; }
  fm_pane_foreground_harness_state() { return 2; }
  lane_is_active lane-001
); then
  fail "regression: a lane whose worker state is UNKNOWN must stay active, not be released"
fi
pass "lane_is_active keeps a lane whose worker state is unknown"

pass "fm-always-four-foreground-oracle: a malformed process answer is unknown, never dead"
