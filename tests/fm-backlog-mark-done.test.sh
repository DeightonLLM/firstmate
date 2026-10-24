#!/usr/bin/env bash
# tests/fm-backlog-mark-done.test.sh - closing one backlog row touches only that row.
#
# The defect this suite exists for: bin/fm-teardown.sh's manual-backend backlog
# updater used one inline awk program that, when the "## In flight" section was
# empty, printed a synthetic "## Done" header instead of the next real header,
# set its in_done flag, and then collected every remaining "- [" row in the
# whole file as a Done entry. The keep-window arithmetic mixed two key spaces
# (line numbers and the task id), so queued rows were deleted outright. This
# suite pins the replacement helper's contract, and the regression that broke
# the queue.
set -u

# shellcheck source=tests/lib.sh disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# The implementation under test. Overridable so the same suite can be run
# against the pre-fix updater to prove it is RED.
IMPL=${FM_BACKLOG_MARK_DONE:-$ROOT/bin/fm-backlog-mark-done.sh}

TMP=$(fm_test_tmproot fm-backlog-mark-done)
trap 'fm_test_cleanup' EXIT INT TERM

mk_backlog() { # <name> ; body on stdin
  local dir="$TMP/$1"
  mkdir -p "$dir"
  cat > "$dir/backlog.md"
  printf '%s' "$dir/backlog.md"
}

run_impl() { # <file> <id> [note] [keep]
  bash "$IMPL" "$@"
}

# --- 1. the regression: an empty In flight section must not delete the queue ---

test_empty_in_flight_keeps_every_queued_row() {
  local file
  file=$(mk_backlog empty-inflight <<'EOF'
## In flight

## Queued
- [ ] alpha-one - First queued item (repo: firstmate)
  alpha body line
- [ ] beta-two - Second queued item (repo: firstmate)
- [x] gamma-three - Already closed item (repo: firstmate)

## P0 tickets routed here
- [ ] delta-four - Routed item (repo: firstmate)

## Done
EOF
)
  local before
  before=$(cat "$file")
  run_impl "$file" some-other-task " - note" 10 >/dev/null 2>&1
  local after
  after=$(cat "$file")
  if [ "$before" != "$after" ]; then
    printf 'the backlog changed even though no row matched:\n--- before ---\n%s\n--- after ---\n%s\n' \
      "$before" "$after" >&2
    fail "an unmatched close must leave the backlog byte-identical"
  fi
  pass "empty In flight with queued rows: an unmatched close changes nothing"
}

test_queued_rows_survive_a_matching_close() {
  local file
  file=$(mk_backlog queued-survive <<'EOF'
## In flight

## Queued
- [ ] alpha-one - First queued item (repo: firstmate)
  alpha body line
- [ ] beta-two - Second queued item (repo: firstmate)
- [x] gamma-three - Already closed item (repo: firstmate)

## Done
EOF
)
  run_impl "$file" beta-two " - closed by test" 10 >/dev/null
  grep -q '^- \[ \] alpha-one - First queued item' "$file" \
    || fail "an unrelated queued row was removed"
  grep -q '^  alpha body line$' "$file" \
    || fail "an unrelated queued row body was removed"
  grep -q '^- \[x\] gamma-three - Already closed item' "$file" \
    || fail "an unrelated closed row was removed"
  grep -q '^- \[x\] beta-two - Second queued item (repo: firstmate) - closed by test$' "$file" \
    || fail "the target row was not closed in place"
  pass "closing a Queued row leaves every other row and body untouched"
}

# --- 2. the In flight -> Done move -------------------------------------------

test_in_flight_row_moves_to_done_with_body() {
  local file
  file=$(mk_backlog inflight-move <<'EOF'
## In flight
- [ ] task-x1 - Do the thing (repo: firstmate)
  the task body
  second body line

## Queued
- [ ] queued-1 - Unrelated (repo: firstmate)

## Done
EOF
)
  run_impl "$file" task-x1 " - https://example.test/pr/1" 10 >/dev/null
  grep -q '^- \[x\] task-x1 - Do the thing (repo: firstmate) - https://example.test/pr/1$' "$file" \
    || fail "the moved row was not closed with its note"
  grep -q '^  the task body$' "$file" || fail "the moved row lost its body"
  grep -q '^  second body line$' "$file" || fail "the moved row lost its second body line"
  grep -q '^- \[ \] queued-1 - Unrelated' "$file" || fail "an unrelated queued row was removed"
  # The row must be under Done, not still under In flight.
  local done_line inflight_line
  done_line=$(grep -n '^## Done$' "$file" | cut -d: -f1)
  inflight_line=$(grep -n 'task-x1' "$file" | cut -d: -f1)
  [ "$inflight_line" -gt "$done_line" ] \
    || fail "the closed row is not in the Done section"
  pass "an In flight row moves into Done with its body and its note"
}

test_bold_key_and_indented_row_are_matched() {
  local file
  file=$(mk_backlog bold-key <<'EOF'
## In flight
 - [ ] **task-x2** - Bold key (repo: firstmate)

## Done
EOF
)
  run_impl "$file" task-x2 " - done" 10 >/dev/null
  grep -q '^ - \[x\] \*\*task-x2\*\* - Bold key (repo: firstmate) - done$' "$file" \
    || fail "the bold-key indented row was not closed"
  pass "a bold key on an indented row is matched and closed"
}

test_missing_done_section_is_created() {
  local file
  file=$(mk_backlog no-done-section <<'EOF'
## In flight
- [ ] task-x3 - No Done section here (repo: firstmate)

## Queued
- [ ] queued-2 - Unrelated (repo: firstmate)
EOF
)
  run_impl "$file" task-x3 " - done" 10 >/dev/null
  grep -q '^## Done$' "$file" || fail "the Done section was not created"
  grep -q '^- \[x\] task-x3 - No Done section here (repo: firstmate) - done$' "$file" \
    || fail "the row was not closed into the new Done section"
  pass "a backlog with no Done section gets one"
}

# --- 3. refusal cases leave the file alone ----------------------------------

test_unmatched_id_leaves_the_file_identical() {
  local file
  file=$(mk_backlog unmatched <<'EOF'
## In flight
- [ ] task-x4 - Present (repo: firstmate)

## Queued
- [ ] queued-3 - Unrelated (repo: firstmate)

## Done
EOF
)
  local before rc=0
  before=$(cat "$file")
  run_impl "$file" no-such-task " - note" 10 >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 3 ] || fail "expected exit 3 for an unmatched id, got $rc"
  [ "$before" = "$(cat "$file")" ] || fail "an unmatched id changed the backlog"
  pass "an unmatched id exits 3 and changes nothing"
}

test_duplicate_key_refuses_and_changes_nothing() {
  local file
  file=$(mk_backlog duplicate <<'EOF'
## In flight
- [ ] task-x5 - First (repo: firstmate)

## Queued
- [ ] task-x5 - Second (repo: firstmate)

## Done
EOF
)
  local before rc=0
  before=$(cat "$file")
  run_impl "$file" task-x5 " - note" 10 >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 4 ] || fail "expected exit 4 for an ambiguous key, got $rc"
  [ "$before" = "$(cat "$file")" ] || fail "an ambiguous key changed the backlog"
  pass "an ambiguous key exits 4 and changes nothing"
}

test_a_longer_key_is_not_matched_by_a_shorter_one() {
  local file
  file=$(mk_backlog prefix-key <<'EOF'
## In flight
- [ ] task-x6-extra - Longer key (repo: firstmate)

## Done
EOF
)
  local rc=0
  run_impl "$file" task-x6 " - note" 10 >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 3 ] || fail "a longer key was matched by a shorter id (exit $rc)"
  grep -q '^- \[ \] task-x6-extra - Longer key' "$file" \
    || fail "a longer key was closed by a shorter id"
  pass "a longer key is never matched by a shorter id"
}

# --- 4. pruning ------------------------------------------------------------

test_done_prune_keeps_open_rows_and_archives_closed_rows() {
  local file
  file=$(mk_backlog prune <<'EOF'
## In flight

## Queued
- [ ] open-1 - Still open (repo: firstmate)

## Done
- [x] old-1 (done 2026-09-01) - Oldest closed row (repo: firstmate)
  old-1 body
- [x] old-2 (done 2026-09-02) - Second closed row (repo: firstmate)
- [x] old-3 (done 2026-09-03) - Third closed row (repo: firstmate)
- [ ] parked-open - An open row parked in Done (repo: firstmate)
- [x] new-1 (done 2026-10-01) - Newest closed row (repo: firstmate)
EOF
)
  local archive="$TMP/prune/done-archive.md"
  run_impl "$file" new-1 " - closed" 2 >/dev/null
  grep -q '^- \[x\] new-1 (done 2026-10-01) - Newest closed row (repo: firstmate) - closed$' "$file" \
    || fail "the target row was not closed"
  grep -q '^- \[ \] parked-open - An open row parked in Done' "$file" \
    || fail "an open row inside Done was pruned"
  grep -q '^- \[ \] open-1 - Still open' "$file" \
    || fail "a queued row was pruned"
  [ "$(grep -c '^- \[x\]' "$file")" -eq 2 ] \
    || fail "Done did not keep exactly the 2 most recent closed rows"
  grep -q 'old-1' "$file" && fail "the oldest closed row was not pruned"
  [ -f "$archive" ] || fail "the pruned rows were not archived"
  grep -q 'old-1' "$archive" || fail "the archive does not hold the pruned row"
  grep -q 'old-1 body' "$archive" || fail "the archive does not hold the pruned row body"
  pass "Done keeps the most recent closed rows, keeps open rows, and archives the rest"
}

test_prune_refuses_when_the_archive_cannot_be_written() {
  local file
  file=$(mk_backlog prune-refuse <<'EOF'
## In flight

## Done
- [x] old-1 (done 2026-09-01) - Older closed row (repo: firstmate)
- [x] old-2 (done 2026-09-02) - Newer closed row (repo: firstmate)
EOF
)
  local before
  before=$(cat "$file")
  FM_BACKLOG_ARCHIVE="/proc/definitely/not/writable/archive.md" \
    run_impl "$file" old-2 " - closed" 1 >/dev/null 2>&1 || true
  [ "$before" = "$(cat "$file")" ] \
    || fail "the backlog changed even though the archive could not be written"
  pass "a prune that cannot be archived leaves the backlog unchanged"
}

# --- 5. idempotency --------------------------------------------------------

test_running_twice_does_not_duplicate_or_re_note() {
  local file
  file=$(mk_backlog idempotent <<'EOF'
## In flight
- [ ] task-x7 - Idempotent close (repo: firstmate)

## Done
EOF
)
  run_impl "$file" task-x7 " - done once" 10 >/dev/null
  local first
  first=$(cat "$file")
  run_impl "$file" task-x7 " - done once" 10 >/dev/null
  [ "$first" = "$(cat "$file")" ] || fail "a second close changed the backlog"
  [ "$(grep -c 'task-x7' "$file")" -eq 1 ] || fail "the row was duplicated"
  pass "closing the same row twice is a no-op the second time"
}

# --- 6. the teardown must use the helper -----------------------------------

test_teardown_uses_the_helper_and_not_the_old_awk() {
  grep -q 'fm-backlog-mark-done.sh' "$ROOT/bin/fm-teardown.sh" \
    || fail "fm-teardown.sh does not call the backlog helper"
  if grep -q 'done_items\[id\]' "$ROOT/bin/fm-teardown.sh"; then
    fail "fm-teardown.sh still contains the old inline backlog updater"
  fi
  pass "fm-teardown.sh calls the helper and no longer carries the old updater"
}

test_empty_in_flight_keeps_every_queued_row
test_queued_rows_survive_a_matching_close
test_in_flight_row_moves_to_done_with_body
test_bold_key_and_indented_row_are_matched
test_missing_done_section_is_created
test_unmatched_id_leaves_the_file_identical
test_duplicate_key_refuses_and_changes_nothing
test_a_longer_key_is_not_matched_by_a_shorter_one
test_done_prune_keeps_open_rows_and_archives_closed_rows
test_prune_refuses_when_the_archive_cannot_be_written
test_running_twice_does_not_duplicate_or_re_note
test_teardown_uses_the_helper_and_not_the_old_awk

echo "ALL TESTS PASSED"
