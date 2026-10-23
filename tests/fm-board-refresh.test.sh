#!/usr/bin/env bash
# tests/fm-board-refresh.test.sh - the enforcement point for
# "the board is rebuilt from the live ledger before the to-do gate judges, and
#  the gate keeps its teeth".
#
# THE DEFECT THIS SUITE EXISTS FOR: the to-do board is GENERATED from the
# machine lane ledger and records that ledger's digest. Every republication of
# the ledger made the board stale, and bin/fm-todo-gate.sh then refused to close
# lanes that were otherwise closed. The refusal was correct; what was missing was
# the step that rebuilds the board from the live ledger.
#
# Two halves meet here:
#   * bin/fm-board-refresh.sh detects the drift and rebuilds the board from the
#     live ledger, and reports the previous and the new digest.
#   * bin/fm-todo-gate.sh STILL refuses a stale board. The refresh does not
#     weaken the gate, it removes the drift the refresh itself would cause.
#
# The suite drives both through their real interfaces against purpose-built
# fixtures in a temp home, so it asserts the published contract on real exit
# codes and never depends on the live ledger or the live board.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REFRESH="$ROOT/bin/fm-board-refresh.sh"
NEXT_BOARD="$ROOT/bin/fm-next-board.sh"
TODO_GATE="$ROOT/bin/fm-todo-gate.sh"
TMP_ROOT=$(fm_test_tmproot fm-board-refresh-tests)

HOME_DIR="$TMP_ROOT/home"
BOARD_DIR="$HOME_DIR/data/tracker"
BOARD="$BOARD_DIR/NEXT-BOARD.md"
LEDGER="$HOME_DIR/ops/lane-ledger.tsv"
CLAIMS="$HOME_DIR/ops/LANE-CLAIMS.md"

REFRESH_OUT="$TMP_ROOT/refresh.out"
REFRESH_ERR="$TMP_ROOT/refresh.err"
GATE_OUT="$TMP_ROOT/gate.out"
GATE_ERR="$TMP_ROOT/gate.err"

# The fixture is a home: the live backlog, the machine lane ledger, the claims
# board and the published to-do list all live inside it.
make_fixture() {
  mkdir -p "$BOARD_DIR" "$HOME_DIR/ops"

  cat > "$HOME_DIR/data/backlog.md" <<'BACKLOG'
# Backlog

## In flight
- [ ] board-refresh-demo - Keep the generated board in step with the machine ledger (repo: demo) (kind: ship) (priority: 1) (since: 2026-10-21)
BACKLOG

  write_ledger "demo-a"
  write_claims_board "demo-a"
  write_sync_checker
  write_blind_checker
}

# write_ledger: the machine truth, with one active lane.
write_ledger() {  # <lane-id>
  cat > "$LEDGER" <<LEDGER
# lane-ledger.tsv - the machine truth for "what is happening right now".
#
# columns (TAB separated, no TAB inside a field):
#   lane_id   state     owner   opened   updated   expires   next   artifact   branch
lane_id	state	owner	opened	updated	expires	next	artifact	branch
$1	ACTIVE	p1-leadlists	2026-10-21T12:00:00Z	2026-10-21T12:00:00Z	2026-10-22T12:00:00Z	keep the board current	data/hd2-takeover/report-$1.md	fm/$1
LEDGER
}

# write_claims_board: the human view of the same machine state.
write_claims_board() {  # <lane-id>
  cat > "$CLAIMS" <<CLAIMS
# Lane claims board

| Lane | Host | Scope | Repo | Claimed | Expires | State |
|---|---|---|---|---|---|---|
| \`$1\` | hd2stack \`vmi3238503\` | \`bin/**\` | firstmate | 2026-10-21 12:00 BST | 2026-10-22 12:00 BST | **ACTIVE** - running |
CLAIMS
}

# write_sync_checker: a stand-in for the drift checker (ops/bin/fm-todo-sync.sh).
# It compares the digest the board records with the digest of the ledger bytes.
write_sync_checker() {
  cat > "$HOME_DIR/sync-checker.sh" <<'CHECKER'
#!/usr/bin/env bash
board=""
ledger=""
while [ $# -gt 0 ]; do
  case "$1" in
    --board) board=$2; shift 2 ;;
    --ledger) ledger=$2; shift 2 ;;
    *) shift ;;
  esac
done
board_digest=$(grep -m1 '^\*\*Ledger digest:\*\* ' "$board" | sed -e 's/^\*\*Ledger digest:\*\*[[:space:]]*//' | tr -d '[:space:]')
ledger_digest="sha256:$(sha256sum "$ledger" | cut -d' ' -f1)"
if [ "$board_digest" != "$ledger_digest" ]; then
  echo "sync: the to-do board is stale ($board_digest != $ledger_digest)"
  exit 1
fi
echo "sync: no drift"
exit 0
CHECKER
  chmod +x "$HOME_DIR/sync-checker.sh"
}

# write_blind_checker: a checker that reports no drift whatever it sees. It
# proves the to-do gate finds the staleness itself instead of inheriting the
# verdict from the checker.
write_blind_checker() {
  cat > "$HOME_DIR/blind-checker.sh" <<'CHECKER'
#!/usr/bin/env bash
echo "sync: blind checker, no drift reported"
exit 0
CHECKER
  chmod +x "$HOME_DIR/blind-checker.sh"
}

board_digest_of() {  # <board>
  grep -m1 '^\*\*Ledger digest:\*\* ' "$1" 2>/dev/null \
    | sed -e 's/^\*\*Ledger digest:\*\*[[:space:]]*//' | tr -d '[:space:]'
}

ledger_digest_of() {  # <ledger>
  printf 'sha256:%s\n' "$(sha256sum "$1" | cut -d' ' -f1)"
}

build_board() {
  bash "$NEXT_BOARD" --repo "$HOME_DIR" --out "$BOARD_DIR" --ledger "$LEDGER" \
    > "$TMP_ROOT/build.out" 2>&1
}

run_refresh() {  # [extra args]
  bash "$REFRESH" --repo "$HOME_DIR" --out "$BOARD_DIR" --ledger "$LEDGER" \
    --board "$BOARD" "$@" > "$REFRESH_OUT" 2> "$REFRESH_ERR"
  printf '%s' "$?"
}

run_todo_gate() {  # [extra args]
  bash "$TODO_GATE" --board "$BOARD" --ledger "$LEDGER" "$@" \
    > "$GATE_OUT" 2> "$GATE_ERR"
  printf '%s' "$?"
}

# The board is generated from the ledger, so it starts in step with it.
test_a_freshly_built_board_is_current() {
  local rc
  build_board
  assert_present "$BOARD" "the board must be published"
  assert_equals "$(ledger_digest_of "$LEDGER")" "$(board_digest_of "$BOARD")" \
    "a freshly built board must record the live ledger digest"

  rc=$(run_refresh --check)
  expect_code 0 "$rc" "a current board must not be reported stale"
  pass "a freshly built board is current with the live ledger"
}

# The ledger is republished and the board is not regenerated: the board is now
# stale, and BOTH the gate and the refresh must say so.
test_a_stale_board_is_detected_and_the_gate_still_refuses_it() {
  local rc
  write_ledger "demo-b"
  write_claims_board "demo-b"
  assert_not_equals "$(ledger_digest_of "$LEDGER")" "$(board_digest_of "$BOARD")" \
    "the ledger must have moved on from the board"

  rc=$(run_refresh --check)
  expect_code 1 "$rc" "a stale board must be detected as stale"
  assert_grep "STALE" "$REFRESH_ERR" "the refresh must say the board is stale"

  # The gate keeps its teeth: a stale board is still a refusal. The blind
  # checker reports no drift, so the refusal can only come from the gate's own
  # comparison of the recorded digest against the live ledger bytes.
  rc=$(run_todo_gate --sync-gate "$HOME_DIR/blind-checker.sh")
  expect_code 1 "$rc" "the to-do gate must still refuse a stale board"
  assert_grep "the to-do list is stale" "$GATE_ERR" "the refusal must name the staleness"
  pass "a stale board is detected as stale and the to-do gate still refuses it"
}

# The refresh rebuilds the board from the live ledger and reports the previous
# and the new digest.
test_the_refresh_rebuilds_the_board_from_the_live_ledger() {
  local rc old_digest new_digest
  old_digest=$(board_digest_of "$BOARD")
  rc=$(run_refresh)
  expect_code 0 "$rc" "the refresh must succeed"
  assert_grep "previous digest $old_digest" "$REFRESH_OUT" \
    "the refresh must print the previous digest"
  new_digest=$(ledger_digest_of "$LEDGER")
  assert_grep "new digest $new_digest" "$REFRESH_OUT" \
    "the refresh must print the new digest"
  pass "the refresh rebuilds the board from the live ledger"
}

# After the refresh the board digest matches the live ledger bytes exactly.
test_after_the_refresh_the_board_matches_the_live_ledger() {
  local rc
  assert_equals "$(ledger_digest_of "$LEDGER")" "$(board_digest_of "$BOARD")" \
    "the refreshed board must record the digest of the live ledger bytes"

  rc=$(run_refresh --check)
  expect_code 0 "$rc" "the refreshed board must not be reported stale"

  rc=$(run_todo_gate --sync-gate "$HOME_DIR/sync-checker.sh")
  expect_code 0 "$rc" "the to-do gate must accept the refreshed board"
  assert_grep "the to-do list is current" "$GATE_OUT" "the gate must say the list is current"
  pass "after the refresh the board digest matches the live ledger bytes"
}

# The refresh is idempotent: a second run finds nothing to do and says so.
test_the_refresh_is_idempotent() {
  local rc
  rc=$(run_refresh)
  expect_code 0 "$rc" "a second refresh must succeed"
  assert_grep "the board is current with the live ledger" "$REFRESH_OUT" \
    "a second refresh must report that the board is already current"
  pass "the refresh is idempotent"
}

# The refresh is wired into the watch cycle, so the board follows the ledger
# instead of decaying between lane cycles.
test_the_watch_cycle_calls_the_refresh() {
  assert_grep "fm-board-refresh.sh" "$ROOT/bin/fm-watch.sh" \
    "the watch cycle must call the board refresh"
  pass "the watch cycle calls the board refresh"
}

make_fixture
test_a_freshly_built_board_is_current
test_a_stale_board_is_detected_and_the_gate_still_refuses_it
test_the_refresh_rebuilds_the_board_from_the_live_ledger
test_after_the_refresh_the_board_matches_the_live_ledger
test_the_refresh_is_idempotent
test_the_watch_cycle_calls_the_refresh
