#!/usr/bin/env bash
# tests/fm-lane-ledger-publish.test.sh - the enforcement point for
# "a lane is not real until it is on the board, and the publisher owns that".
#
# THE DEFECT THIS SUITE EXISTS FOR: on 2026-10-24 four lanes were dispatched
# and confirmed running - each with its own state/<id>.meta and
# state/<id>.status - and the machine lane ledger held zero rows matching
# them. The board is GENERATED from that ledger, so the board reported
# "_no active lanes in the ledger_" while four lanes were in flight. The board
# was not wrong about the ledger; the ledger was wrong about reality. Nothing
# in the fleet wrote the ledger: every tool that named ops/lane-ledger.tsv only
# READ it, so the spawn of a lane - a machine-detectable event - never produced
# a row.
#
# Two halves meet here:
#   * bin/fm-lane-ledger-publish.py publishes the ledger: it writes the row
#     for a lane the moment the lane spawns, keeps the claims board in step
#     with the ledger, and republishes the board from the ledger it just wrote.
#   * bin/fm-board-refresh.sh calls the publisher before it builds a board, so
#     a board can never be published from a ledger that under-reports the
#     lanes that are actually running.
#
# The suite drives the publisher through its real interface against a
# purpose-built fixture home, so it asserts the published contract on real
# exit codes and never depends on the live ledger, the live board or the
# live claims board.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PUBLISHER="$ROOT/bin/fm-lane-ledger-publish.py"
REFRESH="$ROOT/bin/fm-board-refresh.sh"
TODO_GATE="$ROOT/bin/fm-todo-gate.sh"
CHECKER="/home/hd2admin/ops/bin/fm-todo-sync.sh"

TMP_ROOT=$(fm_test_tmproot fm-lane-ledger-publish-tests)

HOME_DIR="$TMP_ROOT/home"
BOARD_DIR="$HOME_DIR/data/tracker"
BOARD="$BOARD_DIR/NEXT-BOARD.md"
LEDGER="$HOME_DIR/ops/lane-ledger.tsv"
CLAIMS="$HOME_DIR/ops/LANE-CLAIMS.md"
STATE_DIR="$HOME_DIR/state"

PUBLISH_OUT="$TMP_ROOT/publish.out"
PUBLISH_ERR="$TMP_ROOT/publish.err"
GATE_OUT="$TMP_ROOT/gate.out"
GATE_ERR="$TMP_ROOT/gate.err"

# The fixture is a home: the live backlog, the machine lane ledger, the claims
# board and the published to-do list all live inside it. The publisher is told
# not to inherit a published ledger, so the fixture never sees the real world.
#
# The home starts with one lane that is already DONE - a home with a history
# and nothing in flight. That is the state the defect was measured in: the
# ledger and the claims board agree, and no lane is in flight.
make_fixture() {
  rm -rf "$HOME_DIR"
  mkdir -p "$BOARD_DIR" "$HOME_DIR/ops" "$STATE_DIR"

  cat > "$HOME_DIR/data/backlog.md" <<'BACKLOG'
# Backlog

## In flight
- [ ] board-ledger-demo - Keep the published board in step with the lanes that are running (repo: demo) (kind: ship) (priority: 1) (since: 2026-10-24)
BACKLOG

  cat > "$LEDGER" <<'LEDGER'
# lane-ledger.tsv - the machine truth for "what is happening right now".
#
# columns (TAB separated, no TAB inside a field):
#   lane_id   state     owner   opened   updated   expires   next   artifact   branch
#
lane_id	state	owner	opened	updated	expires	next	artifact	branch
demo-old-lane	DONE	firstmate	2026-10-24T00:00:00Z	2026-10-24T01:00:00Z		closed - the earlier work is landed	data/demo-old-lane/report.md	main
LEDGER

  cat > "$CLAIMS" <<'CLAIMS'
# Lane claims board - who is touching what, right now

## Live claims
| `demo-old-lane` | the fixture home | the earlier work | firstmate (branch `main`) | - | - | **DONE** - closed - the earlier work is landed |
CLAIMS
}

# write_lane: the spawn record of a lane. bin/fm-spawn.sh writes state/<id>.meta
# when the lane is created and the lane appends wake events to
# state/<id>.status as it works.
write_lane() {  # <lane-id> [status-note]
  local lane_id=$1 note=${2:-}
  fm_write_meta "$STATE_DIR/$lane_id.meta" \
    "window=default:w1:p1" \
    "endpoint_task_id=$lane_id" \
    "spawned_at=$(date +%s)" \
    "worktree=$HOME_DIR" \
    "project=$HOME_DIR" \
    "harness=minimax-code" \
    "kind=scout" \
    "mode=local-only" \
    "yolo=on"
  if [ -n "$note" ]; then
    printf '%s\n' "$note" > "$STATE_DIR/$lane_id.status"
  fi
}

write_secondmate() {  # <name>
  fm_write_meta "$STATE_DIR/$1.meta" \
    "window=default:w2:p2" \
    "endpoint_task_id=$1" \
    "spawned_at=$(date +%s)" \
    "worktree=$HOME_DIR" \
    "project=$HOME_DIR" \
    "harness=minimax-code" \
    "kind=secondmate" \
    "mode=secondmate" \
    "yolo=off" \
    "home=$HOME_DIR"
}

run_publish() {  # [extra args]
  local rc
  python3 "$PUBLISHER" "$@" --repo "$HOME_DIR" --no-seed > "$PUBLISH_OUT" 2> "$PUBLISH_ERR"
  rc=$?
  return $rc
}

run_next_board() {  # the board builder on its own: it builds the board from
                    # the ledger that is there and publishes nothing else.
  local rc
  bash "$ROOT/bin/fm-next-board.sh" --repo "$HOME_DIR" --out "$BOARD_DIR" \
    --ledger "$LEDGER" > "$PUBLISH_OUT" 2> "$PUBLISH_ERR"
  rc=$?
  return $rc
}

run_refresh() {  # [extra args]
  local rc
  bash "$REFRESH" "$@" --repo "$HOME_DIR" --ledger "$LEDGER" --board "$BOARD" \
    > "$PUBLISH_OUT" 2> "$PUBLISH_ERR"
  rc=$?
  return $rc
}

run_todo_gate() {  # [extra args]
  local rc
  FM_REPO="$HOME_DIR" bash "$TODO_GATE" "$@" --board "$BOARD" --ledger "$LEDGER" \
    > "$GATE_OUT" 2> "$GATE_ERR"
  rc=$?
    return $rc
}

ledger_row() {  # <lane-id>
  grep -a "^$1	" "$LEDGER" 2>/dev/null | head -1
}

claims_row() {  # <lane-id>
  grep -a "^| \`$1\`" "$CLAIMS" 2>/dev/null | head -1
}

# assert_row_present / assert_row_absent: a ledger row is a line of text, not
# a path, so it is asserted on its content.
assert_row_present() {  # <lane-id> <message>
  local row
  row=$(ledger_row "$1")
  [ -n "$row" ] || fail "$2"
}

assert_row_absent() {  # <lane-id> <message>
  local row
  row=$(ledger_row "$1")
  [ -z "$row" ] || fail "$2"
}

# The defect, reproduced: a lane that spawned and is working has no row in the
# machine ledger, so the board that is generated from that ledger does not
# mention it. The board is not lying about the ledger - the ledger is lying
# about reality - and the published board is what the Captain reads.
test_a_spawned_lane_is_missing_from_the_board_without_the_publisher() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"

  # The board builder on its own is the behaviour before the fix: the board is
  # built from the ledger that is already there, and nothing publishes a row
  # for the lane that just spawned. Only pre-existing interfaces are used
  # here, so this control is the defect exactly as it was measured.
  run_next_board
  expect_code 0 $? "the board builder must build a board from the ledger that is there"

  assert_row_absent "demo-lane-a" \
    "without the publisher a spawned lane never gets a ledger row"
  assert_not_contains "$(cat "$BOARD")" "demo-lane-a" \
    "without the publisher a spawned lane never reaches the board"
  assert_contains "$(cat "$BOARD")" "_no active lanes in the ledger_" \
    "without the publisher the board says no lane is in flight"
  pass "the defect reproduces: a spawned lane is absent from the published board"
}

# The fix: the publisher writes the ledger row for the lane the moment the
# lane spawns, and republishes the board from the ledger it just wrote.
test_the_publisher_writes_the_ledger_row_at_spawn_time() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"

  run_publish register demo-lane-a
  expect_code 0 $? "the publisher must publish the lane"

  assert_present "$LEDGER" "the publisher must create the machine lane ledger"
  local row
  row=$(ledger_row "demo-lane-a")
  assert_row_present "demo-lane-a" "the publisher must write a ledger row for the spawned lane"
  assert_contains "$row" "ACTIVE" "the row must carry the lane's real state"
  assert_contains "$row" "measuring the thing" \
    "the row must carry the lane's real next action"
  assert_contains "$row" "data/demo-lane-a/report.md" \
    "the row must name the lane's artifact"
  pass "the publisher writes the lane's row at spawn time"
}

# The row alone is not the contract: the PUBLISHED BOARD must count the lane.
test_the_published_board_counts_the_spawned_lane() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"

  run_publish register demo-lane-a
  expect_code 0 $? "the publisher must publish the lane"

  assert_present "$BOARD" "the publisher must publish a board"
  assert_contains "$(cat "$BOARD")" "demo-lane-a" \
    "the published board must carry the spawned lane"
  assert_not_contains "$(cat "$BOARD")" "_no active lanes in the ledger_" \
    "the published board must not say that no lane is in flight"
  pass "the published board counts the lane that spawned"
}

# The ledger and the claims board are the same machine state in two shapes.
# The drift checker refuses when they disagree, so the publisher must leave
# them in agreement.
test_the_ledger_and_the_claims_board_agree() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"

  run_publish register demo-lane-a
  expect_code 0 $? "the publisher must publish the lane"

  local claim
  claim=$(claims_row "demo-lane-a")
  [ -n "$claim" ] || fail "the lane must have a row on the claims board"
  assert_contains "$claim" "**ACTIVE**" "the claims row must carry the lane's real state"

  if [ -x "$CHECKER" ]; then
    local out rc
    out=$("$CHECKER" --ops-dir "$HOME_DIR/ops" --board "$BOARD" 2>&1)
    rc=$?
    assert_contains "$out" "CLEAR" "the drift checker must find no drift: $out"
    expect_code 0 "$rc" "the drift checker must exit 0"
  fi
  pass "the ledger and the claims board agree"
}

# The to-do gate must still accept the board the publisher produced.
test_the_to_do_gate_still_accepts_the_published_board() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"

  run_publish register demo-lane-a
  expect_code 0 $? "the publisher must publish the lane"

  run_todo_gate
  expect_code 0 $? "the to-do gate must accept the published board"
  assert_grep "the to-do list is current" "$GATE_OUT" \
    "the gate must say the list is current"
  pass "the to-do gate still accepts the published board"
}

# The publisher never deletes a row: a row is a record of work that happened.
test_the_publisher_never_deletes_a_row() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"
  run_publish register demo-lane-a
  expect_code 0 $? "the publisher must publish the lane"

  write_lane "demo-lane-b" "working: measuring the other thing"
  run_publish register demo-lane-b
  expect_code 0 $? "the publisher must publish the second lane"

  assert_row_present "demo-lane-a" "the first lane's row must survive"
  assert_row_present "demo-lane-b" "the second lane must have a row"
  pass "the publisher never deletes a row"
}

# A second mate is a standing worker with its own home, not a lane. It must
# never be published as a lane claim.
test_a_second_mate_is_never_published_as_a_lane() {
  make_fixture
  write_secondmate "demo-secondmate"

  run_publish reconcile
  expect_code 0 $? "the publisher must reconcile"

  assert_row_absent "demo-secondmate" \
    "a second mate must never get a lane row"
  assert_not_contains "$(cat "$CLAIMS")" "demo-secondmate" \
    "a second mate must never get a claims row"
  pass "a second mate is never published as a lane"
}

# The board publisher calls the ledger publisher before it builds a board, so
# a board can never be published from a ledger that under-reports the lanes
# that are running.
test_the_board_publisher_publishes_the_ledger_before_it_builds_the_board() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"

  run_refresh
  expect_code 0 $? "the board publisher must succeed"

  assert_row_present "demo-lane-a" \
    "the board publisher must publish the ledger before it builds the board"
  assert_contains "$(cat "$BOARD")" "demo-lane-a" \
    "the board the board publisher built must carry the lane that is running"
  pass "the board publisher publishes the ledger before it builds the board"
}

# The catch-up: a lane that spawned while the publisher was down still lands
# on the board.
test_the_publisher_catches_up_a_lane_that_spawned_while_it_was_down() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"

  run_publish reconcile
  expect_code 0 $? "the publisher must reconcile"

  assert_row_present "demo-lane-a" \
    "the publisher must catch up the lane that spawned"
  assert_contains "$(cat "$BOARD")" "demo-lane-a" \
    "the caught-up lane must reach the board"
  pass "the publisher catches up a lane that spawned while it was down"
}

# The spawn event, observed: the publisher waits for a lane to spawn and
# publishes it without anyone naming the lane. This is the path that works
# with a spawn path the publisher may not modify.
test_the_publisher_publishes_a_lane_that_spawns_while_it_watches() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"

  # The watcher starts with the lanes that are already running.
  python3 "$PUBLISHER" watch --repo "$HOME_DIR" --no-seed --timeout 20 \
    > "$PUBLISH_OUT" 2> "$PUBLISH_ERR" &
  local watcher=$!
  sleep 1

  # A lane spawns while the watcher is running.
  write_lane "demo-lane-b" "working: measuring the other thing"

  local waited=0
  while [ "$waited" -lt 25 ]; do
    if grep -aq "^demo-lane-b	" "$LEDGER" 2>/dev/null; then break; fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$watcher"
  local rc=$?

  expect_code 0 "$rc" "the watcher must succeed when a lane spawns"
  assert_row_present "demo-lane-b" "the watcher must publish the lane that spawned"
  assert_contains "$(cat "$BOARD")" "demo-lane-b" \
    "the lane that spawned while the watcher ran must reach the board"
  pass "the publisher publishes a lane that spawns while it watches"
}

# Closing a lane moves its claim to DONE and empties the expiry. The row is
# never deleted: a row is a record of work that happened.
test_closing_a_lane_keeps_the_row_and_frees_the_scope() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"
  run_publish register demo-lane-a
  expect_code 0 $? "the publisher must publish the lane"

  run_publish close demo-lane-a
  expect_code 0 $? "the publisher must close the lane"

  local row
  row=$(ledger_row "demo-lane-a")
  assert_contains "$row" "DONE" "the closed lane's row must say DONE"
  assert_contains "$row" "data/demo-lane-a/report.md" \
    "closing a lane must not delete its row"
  assert_contains "$(claims_row "demo-lane-a")" "**DONE**" \
    "the claims row must say DONE too"
  pass "closing a lane keeps the row and frees the scope"
}

make_fixture
test_a_spawned_lane_is_missing_from_the_board_without_the_publisher
test_the_publisher_writes_the_ledger_row_at_spawn_time
test_the_published_board_counts_the_spawned_lane
test_the_ledger_and_the_claims_board_agree
test_the_to_do_gate_still_accepts_the_published_board
test_the_publisher_never_deletes_a_row
test_a_second_mate_is_never_published_as_a_lane
test_the_board_publisher_publishes_the_ledger_before_it_builds_the_board
test_the_publisher_catches_up_a_lane_that_spawned_while_it_was_down
test_the_publisher_publishes_a_lane_that_spawns_while_it_watches
test_closing_a_lane_keeps_the_row_and_frees_the_scope
