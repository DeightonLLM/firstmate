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

# ledger_row_in / ledger_field_in: the same reads against an explicit ledger,
# for the cases that drive the real teardown in their own sandbox home.
ledger_row_in() {  # <ledger-path> <lane-id>
  awk -F'\t' -v id="$2" '$1 == id { print; exit }' "$1" 2>/dev/null
}

ledger_field_in() {  # <ledger-path> <lane-id> <column-number>
  ledger_row_in "$1" "$2" | awk -F'\t' -v n="$3" '{ print $n }'
}

ledger_field() {  # <lane-id> <column-number>
  ledger_row "$1" | awk -F'\t' -v n="$2" '{ print $n }'
}

claims_row() {  # <lane-id>
  grep -a "^| \`$1\`" "$CLAIMS" 2>/dev/null | head -1
}

# age_lane <lane-id> <seconds>: make the lane look like it spawned <seconds>
# ago. A lane's claim is anchored on when it spawned, so a lane that is only
# seconds old holds a lease that has nothing to renew yet. The exact spawn
# stamp is published in AGE_LANE_SPAWNED_AT so a test can assert on it.
age_lane() {  # <lane-id> <seconds>
  local lane_id=$1 seconds=$2 meta="$STATE_DIR/$1.meta" now
  now=$(date +%s)
  AGE_LANE_SPAWNED_AT=$((now - seconds))
  grep -v '^spawned_at=' "$meta" > "$meta.new"
  printf 'spawned_at=%s\n' "$AGE_LANE_SPAWNED_AT" >> "$meta.new"
  mv "$meta.new" "$meta"
}

# tear_down_lane <lane-id>: the part of a teardown that ends a lane. The
# teardown copies the lane's own state into data/teardown-archives/<id>/<date>/
# and then removes its spawn record, and that removal is the only thing in the
# fleet that unregisters a lane.
tear_down_lane() {  # <lane-id>
  local lane_id=$1
  local archive="$HOME_DIR/data/teardown-archives/$lane_id/20261024"
  mkdir -p "$archive"
  if [ -f "$STATE_DIR/$lane_id.meta" ]; then
    cp -p "$STATE_DIR/$lane_id.meta" "$archive/meta"
  fi
  if [ -f "$STATE_DIR/$lane_id.status" ]; then
    cp -p "$STATE_DIR/$lane_id.status" "$archive/status"
  fi
  rm -f "$STATE_DIR/$lane_id.meta" "$STATE_DIR/$lane_id.status"
}

# write_slot <slot-id> <target-task-id>: the always-four scheduler's record
# of which task a lane slot runs. The slot record survives the task it names.
write_slot() {  # <slot-id> <target-task-id>
  fm_write_meta "$STATE_DIR/$1.meta" \
    "endpoint_task_id=$2" \
    "window=default:w1:p1" \
    "backend=herdr" \
    "herdr_pane_id=w1:p1" \
    "model=minimax/MiniMax-M3.1-Flash" \
    "harness=minimax-code" \
    "worktree=$HOME_DIR" \
    "project=$HOME_DIR"
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

# --------------------------------------------------------------------------
# the real teardown, in a sandbox of its own
# --------------------------------------------------------------------------

# make_teardown_case <name>: a sandbox in which the REAL bin/fm-teardown.sh
# runs to completion. The teardown needs a project clone with an origin, a
# task worktree whose branch is pushed somewhere reachable, and the backend
# mocks it drives. The home is the case directory, so the teardown never
# touches the checkout this suite runs from.
make_teardown_case() {
  local name=$1 case_dir fakebin
  case_dir="$TMP_ROOT/$name"
  fakebin="$case_dir/fakebin"
  mkdir -p "$case_dir/home/state" "$case_dir/home/data/tracker" \
           "$case_dir/home/config" "$case_dir/home/ops" "$fakebin"

  cat > "$fakebin/treehouse" <<'SH'
#!/usr/bin/env bash
# `treehouse return --force <wt>`: succeed silently.
exit 0
SH
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
# every tmux call the teardown makes: succeed silently.
exit 0
SH
  cat > "$fakebin/gh-axi" <<'SH'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "pr list") printf '%s\n' "count: 0 (showing first 0)" "pull_requests[]: []" ; exit 0 ;;
  "pr view") echo "error: pull request not found" >&2 ; exit 1 ;;
esac
exit 0
SH
  cat > "$fakebin/gh" <<'SH'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "pr view") echo "error: pull request not found" >&2 ; exit 1 ;;
esac
exit 0
SH
  chmod +x "$fakebin/treehouse" "$fakebin/tmux" "$fakebin/gh-axi" "$fakebin/gh"

  # A bare origin with one commit, a clone of it as the project, and a task
  # worktree on a branch of its own.
  git init -q --bare "$case_dir/origin.git"
  git -C "$case_dir/origin.git" symbolic-ref HEAD refs/heads/main
  git clone -q "$case_dir/origin.git" "$case_dir/_seed" 2>/dev/null
  git -C "$case_dir/_seed" -c user.email=t@t -c user.name=t \
    commit -q --allow-empty -m "origin baseline"
  git -C "$case_dir/_seed" push -q origin main
  rm -rf "$case_dir/_seed"
  git clone -q "$case_dir/origin.git" "$case_dir/project"
  git -C "$case_dir/project" remote set-head origin main 2>/dev/null || true
  git -C "$case_dir/project" worktree add -q -b fm/task-x1 "$case_dir/wt" main

  # A fork the task branch is pushed to: the landed-work check accepts
  # local-only work that is reachable from a remote.
  git init -q --bare "$case_dir/fork.git"
  git -C "$case_dir/project" remote add fork "$case_dir/fork.git"
  git -C "$case_dir/wt" -c user.email=t@t -c user.name=t \
    commit -q --allow-empty -m "the work"
  git -C "$case_dir/wt" push -q fork fm/task-x1

  # A fresh watcher beacon so fm-guard stays quiet.
  touch "$case_dir/home/state/.last-watcher-beat"
  printf '%s\n' "$case_dir"
}

# write_teardown_meta <case_dir>: the spawn record of the lane to tear down.
write_teardown_meta() {
  local case_dir=$1
  fm_write_meta "$case_dir/home/state/task-x1.meta" \
    "window=firstmate:fm-task-x1" \
    "endpoint_task_id=task-x1" \
    "spawned_at=$(date +%s)" \
    "worktree=$case_dir/wt" \
    "project=$case_dir/project" \
    "harness=minimax-code" \
    "kind=ship" \
    "mode=local-only" \
    "yolo=on"
}

# run_teardown_in <case_dir> [extra args...]: the real teardown, against the
# sandbox home. FM_HOME is the sandbox, so the ledger the teardown closes is
# the sandbox ledger and never the checkout this suite runs from.
run_teardown_in() {
  local case_dir=$1; shift
  FM_ROOT_OVERRIDE="$ROOT" \
  FM_HOME="$case_dir/home" \
  PATH="$case_dir/fakebin:$PATH" \
    "$ROOT/bin/fm-teardown.sh" task-x1 "$@"
}

# make_failing_publisher_root <case_dir>: a firstmate root whose bin/ is the
# real bin/ except that the lane ledger publisher always fails. The teardown
# finds the publisher through FM_ROOT, so this is how a test makes the
# publisher fail without touching the checkout the suite runs from.
make_failing_publisher_root() {
  local case_dir=$1 entry name
  mkdir -p "$case_dir/fakeroot/bin"
  for entry in "$ROOT"/bin/*; do
    name=$(basename "$entry")
    if [ "$name" = "fm-lane-ledger-publish.py" ]; then
      cat > "$case_dir/fakeroot/bin/$name" <<'PY'
#!/usr/bin/env python3
import sys
print("lane-ledger-publish: FAIL the ledger could not be written", file=sys.stderr)
sys.exit(1)
PY
      chmod +x "$case_dir/fakeroot/bin/$name"
    else
      ln -sfn "$entry" "$case_dir/fakeroot/bin/$name"
    fi
  done
}

# run_teardown_in_with_root <case_dir> <root> [extra args...]: the real
# teardown, with FM_ROOT pointed at a different root.
run_teardown_in_with_root() {
  local case_dir=$1 root=$2; shift 2
  FM_ROOT_OVERRIDE="$root" \
  FM_HOME="$case_dir/home" \
  PATH="$case_dir/fakebin:$PATH" \
    "$ROOT/bin/fm-teardown.sh" task-x1 "$@"
}

# --------------------------------------------------------------------------
# the regressions
# --------------------------------------------------------------------------

# DEFECT 1: reconcile never closed a row for a lane that has ended. Four lanes
# were torn down on 2026-10-24 and the ledger still carried all four as
# ACTIVE: there was no code path that moved a row to DONE.
test_reconcile_closes_the_row_of_a_lane_that_has_ended() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"
  run_publish register demo-lane-a
  expect_code 0 $? "the publisher must publish the lane"

  # The lane is torn down: its spawn record is removed and its state is
  # archived, exactly as bin/fm-teardown.sh does.
  tear_down_lane "demo-lane-a"

  run_publish reconcile
  expect_code 0 $? "the publisher must reconcile"

  local row
  row=$(ledger_row "demo-lane-a")
  assert_contains "$row" "DONE" "the ended lane's row must say DONE"
  assert_equals "" "$(ledger_field "demo-lane-a" 6)" \
    "the ended lane's row must have an empty expiry"
  assert_contains "$row" "closed - the lane finished" \
    "the ended lane's row must carry the closed note"
  assert_contains "$(claims_row "demo-lane-a")" "**DONE**" \
    "the claims row must say DONE too"
  pass "reconcile closes the row of a lane that has ended"
}

# A lane that is still alive keeps its claim. The drift checker reads a
# lapsed ACTIVE claim as a violation, so the lease of a live lane is renewed.
test_reconcile_renews_the_claim_of_a_lane_that_is_still_alive() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"
  # The lane is old enough that its lease has something to renew.
  age_lane "demo-lane-a" 600
  run_publish register demo-lane-a
  expect_code 0 $? "the publisher must publish the lane"

  local before
  before=$(ledger_field "demo-lane-a" 6)

  run_publish reconcile
  expect_code 0 $? "the publisher must reconcile"

  local row after
  row=$(ledger_row "demo-lane-a")
  assert_contains "$row" "ACTIVE" "a lane that is still alive must keep its row ACTIVE"
  after=$(ledger_field "demo-lane-a" 6)
  assert_not_equals "$before" "$after" \
    "the claim of a lane that is still alive must be renewed"
  assert_contains "$row" "measuring the thing" \
    "the renewed row must carry the lane's real next action"
  pass "reconcile renews the claim of a lane that is still alive"
}

# A lane that is still alive is never closed, even when its own claim has
# lapsed: the close needs positive evidence that the lane ENDED. A lane that
# still HAS its spawn record is renewed, not withdrawn.
test_reconcile_never_closes_the_row_of_a_lane_that_is_still_registered() {
  make_fixture
  write_lane "demo-lane-a" "working: measuring the thing"
  # The lane is alive but its claim has lapsed: the record is still there.
  age_lane "demo-lane-a" 100000
  run_publish register demo-lane-a
  expect_code 0 $? "the publisher must publish the lane"
  local before
  before=$(ledger_field "demo-lane-a" 6)

  run_publish reconcile
  expect_code 0 $? "the publisher must reconcile"

  assert_contains "$(ledger_row "demo-lane-a")" "ACTIVE" \
    "a lane that is still registered must never be closed"
  assert_not_equals "$before" "$(ledger_field "demo-lane-a" 6)" \
    "the lapsed claim of a lane that is still registered must be renewed"
  pass "reconcile never closes the row of a lane that is still registered"
}

# DEFECT 2: a stale alias slot published a closed task as ACTIVE. The
# always-four scheduler keeps state/lane-<N>.meta naming the task a slot runs,
# and that record survives the task. Five closed tasks were published that way
# on 2026-10-24.
test_a_slot_naming_a_task_that_is_gone_publishes_no_row() {
  make_fixture
  # The slot still names the task, but the task's own spawn record is gone:
  # the task was torn down and the slot was never refilled.
  write_slot "lane-001" "demo-closed-task"

  run_publish reconcile
  expect_code 0 $? "the publisher must reconcile"

  assert_row_absent "demo-closed-task" \
    "a slot whose target task has no spawn record of its own must never publish a row"
  assert_not_contains "$(cat "$CLAIMS")" "demo-closed-task" \
    "a slot whose target task has no spawn record of its own must never publish a claim"
  pass "a slot naming a task that is gone publishes no row"
}

# A slot that names a task that IS registered is that task's lane: the slot
# and the task are one lane, not two, and the row carries the LANE's real
# identity and spawn time rather than the slot's.
#
# The lane has posted no wake event of its own, and the slot log holds the
# scheduler's note for it. The task log is read first and the slot log is the
# fallback, exactly as bin/fm-always-four.sh resolves a lane's log.
test_a_slot_naming_a_live_task_publishes_that_task_once() {
  make_fixture
  write_lane "demo-lane-a"
  age_lane "demo-lane-a" 600
  write_slot "lane-001" "demo-lane-a"
  printf '%s\n' "working: the slot knows this lane is working" \
    > "$STATE_DIR/lane-001.status"

  run_publish reconcile
  expect_code 0 $? "the publisher must reconcile"

  local row
  row=$(ledger_row "demo-lane-a")
  assert_contains "$row" "ACTIVE" "the slot's task must be published as ACTIVE"
  assert_equals "1" "$(grep -ac "^demo-lane-a	" "$LEDGER" 2>/dev/null || echo 0)" \
    "the slot and the task must publish ONE row, not two"
  local expected_opened
  expected_opened=$(date -u -d "@$AGE_LANE_SPAWNED_AT" +%Y-%m-%dT%H:%M:%SZ)
  assert_equals "$expected_opened" "$(ledger_field "demo-lane-a" 4)" \
    "the row must carry the lane's real spawn time, not the slot's"
  assert_contains "$row" "the slot knows this lane is working" \
    "the slot log must be the fallback for a lane that has no task log yet"
  pass "a slot naming a live task publishes that task once"
}

# DEFECT 3: a teardown left the ledger claiming work was live. The teardown
# and the withdrawal of the claim are one operation.
test_a_teardown_closes_the_row_of_the_lane_it_tore_down() {
  local case_dir rc
  case_dir=$(make_teardown_case teardown-closes-row)
  write_teardown_meta "$case_dir"

  # The lane holds a claim on the machine lane ledger.
  python3 "$PUBLISHER" register task-x1 --repo "$case_dir/home" --no-seed \
    --no-refresh >/dev/null 2>&1
  local ledger="$case_dir/home/ops/lane-ledger.tsv"
  assert_contains "$(ledger_row_in "$ledger" task-x1)" "ACTIVE" \
    "the lane must hold a claim before the teardown"

  set +e
  run_teardown_in "$case_dir" > "$case_dir/stdout" 2> "$case_dir/stderr"
  rc=$?
  set -e

  expect_code 0 "$rc" "the teardown must succeed (stderr: $(cat "$case_dir/stderr"))"

  local row
  row=$(ledger_row_in "$ledger" task-x1)
  assert_contains "$row" "DONE" "the teardown must close the lane's ledger row"
  assert_equals "" "$(ledger_field_in "$ledger" task-x1 6)" \
    "the teardown must empty the closed lane's expiry"
  pass "a teardown closes the row of the lane it tore down"
}

# A failed ledger close must never block a legitimate teardown: the crew is
# already gone and the worktree is already returned. The failure is loud.
test_a_teardown_still_succeeds_when_the_ledger_close_fails() {
  local case_dir rc
  case_dir=$(make_teardown_case teardown-ledger-failure)
  write_teardown_meta "$case_dir"
  make_failing_publisher_root "$case_dir"

  python3 "$PUBLISHER" register task-x1 --repo "$case_dir/home" --no-seed \
    --no-refresh >/dev/null 2>&1

  set +e
  run_teardown_in_with_root "$case_dir" "$case_dir/fakeroot" \
    > "$case_dir/stdout" 2> "$case_dir/stderr"
  rc=$?
  set -e

  expect_code 0 "$rc" "a failed ledger close must never block a legitimate teardown"
  assert_contains "$(cat "$case_dir/stderr")" "lane ledger close" \
    "a failed ledger close must be reported loudly"
  assert_absent "$case_dir/home/state/task-x1.meta" \
    "the teardown must still have removed the lane's spawn record"
  pass "a teardown still succeeds when the ledger close fails, and says so loudly"
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
test_reconcile_closes_the_row_of_a_lane_that_has_ended
test_reconcile_renews_the_claim_of_a_lane_that_is_still_alive
test_reconcile_never_closes_the_row_of_a_lane_that_is_still_registered
test_a_slot_naming_a_task_that_is_gone_publishes_no_row
test_a_slot_naming_a_live_task_publishes_that_task_once
test_a_teardown_closes_the_row_of_the_lane_it_tore_down
test_a_teardown_still_succeeds_when_the_ledger_close_fails
