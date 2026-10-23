#!/usr/bin/env bash
# tests/fm-todo-gate.test.sh - the enforcement point for
# "the to-do list is generated from machine state, and a lane may not close
# while that list is stale".
#
# Two halves meet here:
#   * bin/build-next-board.py GENERATES the to-do list from the machine lane
#     ledger and records that ledger's digest in the board.
#   * bin/fm-todo-gate.sh refuses a stale list, and bin/fm-lane-closure-gate.sh
#     runs that gate as a precondition of closure.
#
# The suite drives both through their executable interfaces against purpose-built
# fixtures in a temp root, so it asserts the published contract on real exit
# codes and never depends on the live ledger or the live board.
#
# The cases share one fixture on purpose: the ledger moves, the board does not,
# and that is what staleness is. The order of the calls matters.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TODO_GATE="$ROOT/bin/fm-todo-gate.sh"
CLOSURE_GATE="$ROOT/bin/fm-lane-closure-gate.sh"
BUILDER="$ROOT/bin/build-next-board.py"
TMP_ROOT=$(fm_test_tmproot fm-todo-gate-tests)

# The fixture is a home: a programme manifest, a lane artifact, the machine lane
# ledger, the claims board and the published to-do list all live inside it.
HOME_DIR="$TMP_ROOT/home"

make_fixture() {
  mkdir -p "$HOME_DIR/data/core-remediation/lanes/demo" \
           "$HOME_DIR/data/tracker" \
           "$HOME_DIR/ops"

  cat > "$HOME_DIR/data/core-remediation/lanes.json" <<'MANIFEST'
{
  "programme": "test-programme",
  "lanes": [
    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}
  ]
}
MANIFEST

  cat > "$HOME_DIR/data/core-remediation/lanes/demo/report.md" <<'REPORT'
# Lane Report
**Author:** Worker Lane 42
Implemented the change and ran the suite.
VERDICT: PASS - all requirements completed
REPORT

  # The independent checker artifact the checker-before-done gate looks for. It
  # names a different reviewer and records a command and its exit code, so the
  # honest case is honest and not merely well worded.
  cat > "$HOME_DIR/data/core-remediation/lanes/demo/report.checker.md" <<'CHECKER'
# Independent Audit
**Reviewer:** Independent Auditor (Lane w2M:p9)
Re-ran the lane's own suite from a clean checkout:
    $ bash tests/fm-todo-gate.test.sh
    4/4 assertions passed
    exit code 0
VERDICT: CHECK_PASS - the claim reproduces
CHECKER

  write_ledger
  write_claims_board
}

# write_ledger: the machine truth. One ACTIVE lane and one DONE lane.
write_ledger() {
  cat > "$HOME_DIR/ops/lane-ledger.tsv" <<'LEDGER'
# lane-ledger.tsv - the machine truth for "what is happening right now".
#
# columns (TAB separated, no TAB inside a field):
#   lane_id   state     owner   opened   updated   expires   next   artifact   branch
lane_id	state	owner	opened	updated	expires	next	artifact	branch
demo-a	ACTIVE	p1-leadlists	2026-10-20T22:00:00Z	2026-10-20T23:00:00Z	2026-10-21T03:00:00Z	finish the demo lane	data/hd2-takeover/report-demo.md	fm/demo
demo-b	DONE	p1-leadlists	2026-10-20T21:00:00Z	2026-10-20T22:30:00Z		closed - the demo landed	data/hd2-takeover/report-demo-b.md	fm/demo-b
LEDGER
}

# write_claims_board: the human view. It mirrors the ledger, so the only thing
# that can ever make these fixtures drift is a deliberate edit.
write_claims_board() {
  cat > "$HOME_DIR/ops/LANE-CLAIMS.md" <<'CLAIMS'
# Lane claims board

| Lane | Host | Scope | Repo | Claimed | Expires | State |
|---|---|---|---|---|---|---|
| `demo-a` | hd2stack `vmi3238503` | `bin/**` | firstmate | 2026-10-20 22:00 BST | 2026-10-21 03:00 BST | **ACTIVE** — running |
| `demo-b` | hd2stack `vmi3238503` | `bin/**` | firstmate | 2026-10-20 21:00 BST | 2026-10-21 03:00 BST | **DONE** — landed |
CLAIMS
}

# write_sync_checker: a stand-in for the drift checker (ops/bin/fm-todo-sync.sh).
# It reads the board and the ledger from the environment the gate exports and
# refuses when they disagree.
write_sync_checker() {
  cat > "$HOME_DIR/sync-checker.sh" <<'CHECKER'
#!/usr/bin/env bash
board="${FM_TODO_BOARD:-}"
ledger="${FM_TODO_LEDGER:-}"
[ -n "$board" ] && [ -f "$board" ] || { echo "sync: no to-do board"; exit 3; }
[ -n "$ledger" ] && [ -f "$ledger" ] || { echo "sync: no lane ledger"; exit 3; }
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

# regenerate_board: publish the to-do list from the current machine state.
regenerate_board() {
  python3 "$BUILDER" --repo "$HOME_DIR" --out "$HOME_DIR/data/tracker" \
    --ledger "$HOME_DIR/ops/lane-ledger.tsv" >"$HOME_DIR/builder.out" 2>&1
}

run_todo_gate() {
  bash "$TODO_GATE" --board "$HOME_DIR/data/tracker/NEXT-BOARD.md" \
    --ledger "$HOME_DIR/ops/lane-ledger.tsv" "$@" >"$HOME_DIR/gate.out" 2>"$HOME_DIR/gate.err"
  printf '%s' "$?"
}

run_closure_gate() {
  FM_TODO_SYNC_GATE="${FM_TODO_SYNC_GATE:-}" \
    bash "$CLOSURE_GATE" --manifest "$HOME_DIR/data/core-remediation/lanes.json" \
      --todo-gate "$TODO_GATE" \
      --todo-board "$HOME_DIR/data/tracker/NEXT-BOARD.md" \
      --todo-ledger "$HOME_DIR/ops/lane-ledger.tsv" \
      >"$HOME_DIR/closure.out" 2>"$HOME_DIR/closure.err"
  printf '%s' "$?"
}

# (b) A clean list passes: the board was generated from the ledger it names,
# and the drift checker agrees.
test_a_clean_to_do_list_passes() {
  local rc
  regenerate_board
  rc=$(run_todo_gate --sync-gate "$HOME_DIR/sync-checker.sh")
  expect_code 0 "$rc" "a to-do list that matches the ledger must pass the gate"
  assert_grep "the to-do list is current" "$HOME_DIR/gate.out" "the gate must say the list is current"
  pass "a clean to-do list passes the to-do gate"
}

# (a) A stale list is refused. The ledger moved and the board was not
# regenerated, so the digest the board records no longer matches the ledger.
# The blind checker reports no drift, so the refusal can only come from the
# gate's own comparison.
test_a_stale_to_do_list_is_refused() {
  local rc
  printf 'demo-c\tACTIVE\tp1-leadlists\t2026-10-20T23:30:00Z\t2026-10-20T23:30:00Z\t2026-10-21T03:30:00Z\ta new lane appeared\tdata/hd2-takeover/report-demo-c.md\tfm/demo-c\n' \
    >> "$HOME_DIR/ops/lane-ledger.tsv"
  printf '| `demo-c` | hd2stack `vmi3238503` | `bin/**` | firstmate | 2026-10-20 23:30 BST | 2026-10-21 03:30 BST | **ACTIVE** — a new lane appeared |\n' \
    >> "$HOME_DIR/ops/LANE-CLAIMS.md"

  rc=$(run_todo_gate --sync-gate "$HOME_DIR/blind-checker.sh")
  expect_code 1 "$rc" "a stale to-do list must be refused"
  assert_grep "the to-do list is stale" "$HOME_DIR/gate.err" "the refusal must name the staleness"
  pass "a stale to-do list is refused by the to-do gate"
}

# (c) The lane-closure gate refuses to close a lane whose artifact claims PASS
# while the to-do list is stale. A PASS lane closed on a stale list is the exact
# rot this lane exists to stop.
test_the_closure_gate_refuses_a_pass_lane_on_a_stale_list() {
  local rc
  FM_TODO_SYNC_GATE="$HOME_DIR/blind-checker.sh"
  export FM_TODO_SYNC_GATE
  rc=$(run_closure_gate)
  expect_code 1 "$rc" "a PASS lane must not close while the to-do list is stale"
  assert_grep "the to-do list gate refused the lane" "$HOME_DIR/closure.err" \
    "the refusal must name the to-do list gate"
  pass "the lane-closure gate refuses a PASS lane while the to-do list is stale"
}

# (d) The same lane closes once the list is regenerated: the digest is refreshed
# and the drift checker finds no drift.
test_the_closure_gate_closes_the_lane_after_regeneration() {
  local rc
  regenerate_board
  FM_TODO_SYNC_GATE="$HOME_DIR/sync-checker.sh"
  export FM_TODO_SYNC_GATE
  rc=$(run_closure_gate)
  expect_code 0 "$rc" "a PASS lane must close once the to-do list is regenerated"
  assert_grep "closed" "$HOME_DIR/closure.out" "the lane must be reported as closed"
  pass "the lane-closure gate closes the lane once the to-do list is regenerated"
}

make_fixture
write_sync_checker
write_blind_checker

test_a_clean_to_do_list_passes
test_a_stale_to_do_list_is_refused
test_the_closure_gate_refuses_a_pass_lane_on_a_stale_list
test_the_closure_gate_closes_the_lane_after_regeneration
