#!/usr/bin/env bash
# tests/fm-dead-pane-sweep.test.sh - TDD tests for fm-dead-pane-sweep.
#
# Test seam: --panes-file <fixture.json> reads the pane list from a file
# instead of calling herdr. Each fixture is written by the test itself using
# synthetic JSON — no herdr dependency in tests.
#
# Classifications:
#   LIVE              - working agent OR focused primary session
#   IDLE-BUT-HELD  - recorded task, work NOT finished
#   DEAD-REAPABLE  - recorded task with verdict+deliverable, OR unowned
#                     pane with strong dead signal (blank buffer, resume hint,
#                     stalled setup banner)
#   UNKNOWN-PROVENANCE - cannot be classified
#
# Exit: non-zero when any DEAD-REAPABLE pane exists.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$SCRIPT_DIR"
TD="${TMPDIR:-/tmp}/fm-dead-pane-sweep.$$"
mkdir -p "$TD"
trap 'rm -rf "$TD"' EXIT

PASS=0; FAIL=0; SKIP=0
ok()  { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# make_fixture <name> <pane-json> [...]: write a panes fixture JSON to $TD/<name>.json
# and return the path. Each arg is one compact pane object.
make_fixture() {
  local name=$1; shift
  local out="$TD/$name.json"
  printf '{"id":"cli:pane:list","result":{"panes":[' > "$out"
  local first=true p
  for p in "$@"; do
    $first && first=false || printf ',' >> "$out"
    printf '%s' "$p" >> "$out"
  done
  printf '],"type":"pane_list"}}' >> "$out"
  printf '%s' "$out"
}

# build_meta <statedir> <id> <window> [extra...]
build_meta() {
  mkdir -p "$1"
  {
    echo "window=$3"
    echo "endpoint_task_id=$2"
    echo "kind=task"
    shift 3; for l in "$@"; do echo "$l"; done
  } > "$1/$2.meta"
}

# build_status <statedir> <id> [lines...]
build_status() {
  mkdir -p "$1"
  for l in "${@:2}"; do printf '%s\n' "$l"; done > "$1/$1.status"
  printf '%s\n' "${@:2}" > "$1/$2.status"
}

# build_status <statedir> <id> [lines...]
build_status() {
  local dir=$1 id=$2; shift 2
  mkdir -p "$dir"
  for l in "$@"; do printf '%s\n' "$l"; done > "$dir/$id.status"
}

# build_verdict <statedir> <id>
build_verdict() { mkdir -p "$1"; : > "$1/$2.verdict"; }

# build_deliverable <statedir> <id>
build_deliverable() { mkdir -p "$1"; : > "$1/$2.deliverable"; }

# run_sweep <statedir> <fixture-json-path>: invoke script, set SWEEP_OUT and SWEEP_RC.
run_sweep() {
  local sd=$1 fix=$2
  local out rc
  out=$(FM_HOME="$sd" bash "$SCRIPT_DIR/bin/fm-dead-pane-sweep.sh" --panes-file "$fix" "$sd" 2>&1)
  rc=$?
  SWEEP_RC=$rc; SWEEP_OUT=$out
}

# classify <pane_id>: extract classification from last run.
classify() {
  printf '%s\n' "$SWEEP_OUT" | grep "^$1 " | tail -1 | awk '{print $2}'
}

# assert_class <pane> <expected> <desc>
assert_class() {
  local got=$(classify "$1")
  if [ "$got" = "$2" ]; then
    ok "$3"
  else
    bad "$3 (got '$got', want '$2')"
  fi
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_script_exists() {
  [ -x "$SCRIPT_DIR/bin/fm-dead-pane-sweep.sh" ] \
    || { bad "script missing or not executable"; return 1; }
  ok "script exists and is executable"
}

test_live_working_agent() {
  local sd="$TD/t1" fix
  mkdir -p "$sd"
  fix=$(make_fixture t1 \
    '{"pane_id":"w1:p1","agent_status":"working","agent":"pi","cwd":"/home/fm","foreground_cwd":"/home/fm","terminal_title_stripped":"test","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:p1 LIVE "working agent -> LIVE"
}

test_live_primary_session() {
  local sd="$TD/t2" fix
  mkdir -p "$sd"
  # cwd must match FM_HOME (=sd) for the primary-session LIVE check.
  fix=$(make_fixture t2 \
    "{\"pane_id\":\"w1:p3\",\"agent_status\":\"unknown\",\"agent\":\"\",\"cwd\":\"$sd\",\"foreground_cwd\":\"$sd\",\"terminal_title_stripped\":\"primary\",\"focused\":true}")
  run_sweep "$sd" "$fix"
  assert_class w1:p3 LIVE "focused primary session -> LIVE"
}

test_idle_but_held_unfinished() {
  local sd="$TD/t3" fix
  mkdir -p "$sd"
  build_meta "$sd" task-abc w1:p5
  build_status "$sd" task-abc "working: doing something"
  fix=$(make_fixture t3 \
    '{"pane_id":"w1:p5","agent_status":"idle","agent":"pi","cwd":"/tmp/work","foreground_cwd":"/tmp/work","terminal_title_stripped":"worker","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:p5 IDLE-BUT-HELD "recorded task unfinished -> IDLE-BUT-HELD"
}

test_dead_reapable_finished_with_verdict_and_deliverable() {
  local sd="$TD/t4" fix
  mkdir -p "$sd"
  build_meta "$sd" task-done w1:p7
  build_status "$sd" task-done "done: done"
  build_verdict "$sd" task-done
  build_deliverable "$sd" task-done
  fix=$(make_fixture t4 \
    '{"pane_id":"w1:p7","agent_status":"idle","agent":"pi","cwd":"/tmp/w","foreground_cwd":"/tmp/w","terminal_title_stripped":"done-task","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:p7 DEAD-REAPABLE "finished+verdict+deliverable -> DEAD-REAPABLE"
  [ "$SWEEP_RC" -ne 0 ] || { bad "DEAD-REAPABLE must exit non-zero"; return 1; }
  ok "DEAD-REAPABLE exit non-zero"
}

test_dead_reapable_unowned_blank_buffer() {
  local sd="$TD/t5" fix
  mkdir -p "$sd"
  fix=$(make_fixture t5 \
    '{"pane_id":"w1:p9","agent_status":"idle","agent":"","cwd":"/","foreground_cwd":"/","terminal_title_stripped":"bash","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:p9 DEAD-REAPABLE "unowned blank buffer -> DEAD-REAPABLE"
  [ "$SWEEP_RC" -ne 0 ] || { bad "DEAD-REAPABLE blank must exit non-zero"; return 1; }
  ok "DEAD-REAPABLE blank exit non-zero"
}

test_unknown_provenance_unclassifiable() {
  local sd="$TD/t6" fix
  mkdir -p "$sd"
  fix=$(make_fixture t6 \
    '{"pane_id":"w1:pZ","agent_status":"unknown","agent":"","cwd":"/home/other","foreground_cwd":"/home/other","terminal_title_stripped":"some-session","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:pZ UNKNOWN-PROVENANCE "unclassifiable pane -> UNKNOWN-PROVENANCE"
  [ "$SWEEP_RC" -eq 0 ] || { bad "UNKNOWN-PROVENANCE only should exit 0 (rc=$SWEEP_RC)"; return 1; }
  ok "UNKNOWN-PROVENANCE exit zero"
}

test_dead_reapable_resume_hint() {
  local sd="$TD/t7" fix
  mkdir -p "$sd"
  fix=$(make_fixture t7 \
    '{"pane_id":"w1:pR","agent_status":"unknown","agent":"","cwd":"/home/fm","foreground_cwd":"/home/fm","terminal_title_stripped":"Pi · Luna · w1:pR","focused":false,"state_labels":{"idle":"Continue where you left off?","done":"Continue where you left off?"}}')
  run_sweep "$sd" "$fix"
  assert_class w1:pR DEAD-REAPABLE "resume hint -> DEAD-REAPABLE"
}

test_idle_but_held_done_no_verdict() {
  local sd="$TD/t8" fix
  mkdir -p "$sd"
  build_meta "$sd" task-no-v w1:pV
  build_status "$sd" task-no-v "done: output written"
  fix=$(make_fixture t8 \
    '{"pane_id":"w1:pV","agent_status":"idle","agent":"pi","cwd":"/tmp/w","foreground_cwd":"/tmp/w","terminal_title_stripped":"no-verdict","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:pV IDLE-BUT-HELD "done without verdict -> IDLE-BUT-HELD (NOT DEAD-REAPABLE)"
}

test_no_panes_exit_zero() {
  local sd="$TD/t9" fix
  mkdir -p "$sd"
  fix=$(make_fixture t9)
  run_sweep "$sd" "$fix"
  [ "$SWEEP_RC" -eq 0 ] || { bad "no panes should exit 0 (rc=$SWEEP_RC)"; return 1; }
  [ -z "$SWEEP_OUT" ] || { bad "no panes should produce no output"; return 1; }
  ok "no panes: exit 0, no output"
}

test_mixed_exit_nonzero_on_dead_reapable() {
  local sd="$TD/t10" fix
  mkdir -p "$sd"
  build_meta "$sd" task-held w1:pHeld
  build_status "$sd" task-held "working: still going"
  build_meta "$sd" task-dead w1:pDead
  build_status "$sd" task-dead "done: done"
  build_verdict "$sd" task-dead
  build_deliverable "$sd" task-dead
  fix=$(make_fixture t10 \
    '{"pane_id":"w1:pLive","agent_status":"working","agent":"pi","cwd":"/home/fm","foreground_cwd":"/home/fm","terminal_title_stripped":"live","focused":false}' \
    '{"pane_id":"w1:pHeld","agent_status":"idle","agent":"pi","cwd":"/tmp/w","foreground_cwd":"/tmp/w","terminal_title_stripped":"held","focused":false}' \
    '{"pane_id":"w1:pDead","agent_status":"idle","agent":"pi","cwd":"/tmp/d","foreground_cwd":"/tmp/d","terminal_title_stripped":"dead","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:pLive LIVE "working -> LIVE"
  assert_class w1:pHeld IDLE-BUT-HELD "unfinished -> IDLE-BUT-HELD"
  assert_class w1:pDead DEAD-REAPABLE "finished+verdict+deliverable -> DEAD-REAPABLE"
  [ "$SWEEP_RC" -ne 0 ] || { bad "mixed with DEAD-REAPABLE must exit non-zero"; return 1; }
  ok "mixed: exit non-zero on DEAD-REAPABLE"
}

test_dead_reapable_stalled_setup_banner() {
  local sd="$TD/t11" fix
  mkdir -p "$sd"
  fix=$(make_fixture t11 \
    '{"pane_id":"w1:pS","agent_status":"idle","agent":"","cwd":"/","foreground_cwd":"/","terminal_title_stripped":"Welcome to Pi! Getting started...","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:pS DEAD-REAPABLE "stalled setup banner -> DEAD-REAPABLE"
}

test_idle_but_held_failed_no_verdict() {
  local sd="$TD/t12" fix
  mkdir -p "$sd"
  build_meta "$sd" task-term w1:pTerm
  build_status "$sd" task-term "failed: broken"
  fix=$(make_fixture t12 \
    '{"pane_id":"w1:pTerm","agent_status":"idle","agent":"pi","cwd":"/tmp/w","foreground_cwd":"/tmp/w","terminal_title_stripped":"failed-task","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:pTerm IDLE-BUT-HELD "failed without verdict -> IDLE-BUT-HELD"
}

test_dead_reapable_unowned_root_cwd() {
  local sd="$TD/t13" fix
  mkdir -p "$sd"
  fix=$(make_fixture t13 \
    '{"pane_id":"w1:pR","agent_status":"idle","agent":"","cwd":"/root","foreground_cwd":"/root","terminal_title_stripped":"bash","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:pR DEAD-REAPABLE "cwd=/root idle -> DEAD-REAPABLE"
}

test_dead_reapable_multiple_still_exit_nonzero_once() {
  local sd="$TD/t14" fix
  mkdir -p "$sd"
  for i in 1 2 3; do
    build_verdict "$sd" "orphan-$i"
    build_deliverable "$sd" "orphan-$i"
  done
  fix=$(make_fixture t14 \
    '{"pane_id":"w1:pD1","agent_status":"idle","agent":"","cwd":"/","foreground_cwd":"/","terminal_title_stripped":"bash","focused":false}' \
    '{"pane_id":"w1:pD2","agent_status":"idle","agent":"","cwd":"/","foreground_cwd":"/","terminal_title_stripped":"bash","focused":false}' \
    '{"pane_id":"w1:pD3","agent_status":"idle","agent":"","cwd":"/","foreground_cwd":"/","terminal_title_stripped":"bash","focused":false}')
  run_sweep "$sd" "$fix"
  [ "$SWEEP_RC" -ne 0 ] || { bad "multiple DEAD-REAPABLE must exit non-zero"; return 1; }
  for i in 1 2 3; do
    assert_class "w1:pD$i" DEAD-REAPABLE "pane w1:pD$i -> DEAD-REAPABLE"
  done
  ok "multiple DEAD-REAPABLE: all classified, exit non-zero once"
}

test_live_unowned_working() {
  local sd="$TD/t15" fix
  mkdir -p "$sd"
  fix=$(make_fixture t15 \
    '{"pane_id":"w1:pW","agent_status":"working","agent":"pi","cwd":"/home/other","foreground_cwd":"/home/other","terminal_title_stripped":"task","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:pW LIVE "unowned working agent -> LIVE"
}

test_idle_but_held_owned_unknown_no_verdict() {
  local sd="$TD/t16" fix
  mkdir -p "$sd"
  build_meta "$sd" task-u w1:pU
  build_status "$sd" task-u "working: waiting"
  fix=$(make_fixture t16 \
    '{"pane_id":"w1:pU","agent_status":"unknown","agent":"","cwd":"/home/fm","foreground_cwd":"/home/fm","terminal_title_stripped":"unknown","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:pU IDLE-BUT-HELD "owned unknown without verdict -> IDLE-BUT-HELD"
}

test_idle_but_held_done_verdict_no_deliverable() {
  local sd="$TD/t17" fix
  mkdir -p "$sd"
  build_meta "$sd" task-nd w1:pND
  build_status "$sd" task-nd "done: done"
  build_verdict "$sd" task-nd
  # Deliberately NO deliverable.
  fix=$(make_fixture t17 \
    '{"pane_id":"w1:pND","agent_status":"idle","agent":"pi","cwd":"/tmp/w","foreground_cwd":"/tmp/w","terminal_title_stripped":"no-del","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:pND IDLE-BUT-HELD "done+verdict no deliverable -> IDLE-BUT-HELD"
  [ "$SWEEP_RC" -eq 0 ] || { bad "IDLE-BUT-HELD only should exit 0 (rc=$SWEEP_RC)"; return 1; }
  ok "IDLE-BUT-HELD exit zero"
}

test_dead_reapable_empty_cwd() {
  local sd="$TD/t18" fix
  mkdir -p "$sd"
  fix=$(make_fixture t18 \
    '{"pane_id":"w1:pE","agent_status":"idle","agent":"","cwd":"","foreground_cwd":"","terminal_title_stripped":"","focused":false}')
  run_sweep "$sd" "$fix"
  assert_class w1:pE DEAD-REAPABLE "empty cwd + idle -> DEAD-REAPABLE"
}

test_shellcheck() {
  if ! command -v shellcheck >/dev/null 2>&1; then
    SKIP=$((SKIP + 1)); printf 'SKIP  shellcheck not installed\n'; return 0
  fi
  local out
  out=$(shellcheck -S warning "$SCRIPT_DIR/bin/fm-dead-pane-sweep.sh" 2>&1)
  [ -z "$out" ] || { bad "shellcheck: $out"; return 1; }
  ok "shellcheck passes"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

for _t in \
  test_script_exists \
  test_live_working_agent \
  test_live_primary_session \
  test_idle_but_held_unfinished \
  test_dead_reapable_finished_with_verdict_and_deliverable \
  test_dead_reapable_unowned_blank_buffer \
  test_unknown_provenance_unclassifiable \
  test_dead_reapable_resume_hint \
  test_idle_but_held_done_no_verdict \
  test_no_panes_exit_zero \
  test_mixed_exit_nonzero_on_dead_reapable \
  test_dead_reapable_stalled_setup_banner \
  test_idle_but_held_failed_no_verdict \
  test_dead_reapable_unowned_root_cwd \
  test_dead_reapable_multiple_still_exit_nonzero_once \
  test_live_unowned_working \
  test_idle_but_held_owned_unknown_no_verdict \
  test_idle_but_held_done_verdict_no_deliverable \
  test_dead_reapable_empty_cwd \
  test_shellcheck; do
  echo "# RUN: $_t"
  "$_t" || echo "FAIL: $_t"
done

echo
printf 'PASS=%d FAIL=%d SKIP=%d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -gt 0 ] && exit 1
echo "ALL TESTS PASSED"
