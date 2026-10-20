#!/usr/bin/env bash
# tests/fm-merge-packet.test.sh - contract tests for the merge packet reporter.
#
# The suite drives bin/fm-merge-packet.sh against purpose-built fixture
# repositories under a temporary root. It asserts the published contract of the
# packet and never the script's source bytes, and it never touches a real
# project checkout.
#
# Covered contract:
#   - a fixture branch and file change produce a packet naming the branch and head
#   - the byte-identical copy invariant reports HOLDS when the copies agree
#   - the byte-identical copy invariant reports BROKEN when they differ
#   - a conflicting pair is reported CONFLICTING with the conflict detail quoted
#   - a non-conflicting pair is reported CLEAN, in both directions
#   - a head that is not on the remote is flagged as not pushed
#   - the rollback section carries an undo command and a verification command
#   - the closing decision section states what one word authorises and what not
#   - the script leaves the fixture repository untouched
#   - --help prints usage and exits 0
#   - a missing repository path is reported with the exact path and exits non-zero
#
# The case functions are invoked indirectly through run_case, which is what
# collects the per-case PASS/FAIL summary the suite has to print. ShellCheck
# cannot follow that indirection, so SC2329 is disabled for this file only.
# shellcheck disable=SC2329
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PACKET="$ROOT/bin/fm-merge-packet.sh"
TMP_ROOT=$(fm_test_tmproot fm-merge-packet-tests)
FIXTURE="$TMP_ROOT/fixture/repo"
ORIGIN="$TMP_ROOT/fixture/origin.git"
# The packet renders branch names inside Markdown backticks.
BT='`'

# --- fixture ---------------------------------------------------------------

# build_fixture: a repository with a base branch, a bare origin, two files that
# must stay byte-identical, a test file, and one branch per case the suite
# needs. Nothing here touches the network or any real project.
build_fixture() {
  mkdir -p "$TMP_ROOT/fixture"
  git init -q "$FIXTURE" || return 1
  git -C "$FIXTURE" config user.name "Firstmate Tests" || return 1
  git -C "$FIXTURE" config user.email "tests@example.invalid" || return 1
  git -C "$FIXTURE" symbolic-ref HEAD refs/heads/main || return 1

  mkdir -p "$FIXTURE/staged-export-test" "$FIXTURE/current-core-distro" "$FIXTURE/tests"
  printf 'line one\nline two\nline three\n' > "$FIXTURE/staged-export-test/leadlists.php"
  cp "$FIXTURE/staged-export-test/leadlists.php" "$FIXTURE/current-core-distro/leadlists.php"
  printf 'the readme\n' > "$FIXTURE/README.md"
  printf '<?php\n// regression for the twin copies\n' > "$FIXTURE/tests/regression_twin.php"
  git -C "$FIXTURE" add -A || return 1
  git -C "$FIXTURE" commit -qm "base commit" || return 1

  # A branch that moves both twin copies the same way, so parity holds.
  git -C "$FIXTURE" checkout -q -b feature-parity-holds || return 1
  printf 'line one\nline two HELD\nline three\n' > "$FIXTURE/staged-export-test/leadlists.php"
  cp "$FIXTURE/staged-export-test/leadlists.php" "$FIXTURE/current-core-distro/leadlists.php"
  git -C "$FIXTURE" add -A || return 1
  git -C "$FIXTURE" commit -qm "feature: move both twin copies together" || return 1

  # A branch that moves one twin copy only, so parity breaks.
  git -C "$FIXTURE" checkout -q -b feature-parity-broken || return 1
  printf 'line one\nline two BROKEN\nline three\n' > "$FIXTURE/staged-export-test/leadlists.php"
  git -C "$FIXTURE" add -A || return 1
  git -C "$FIXTURE" commit -qm "feature: move one twin copy only" || return 1

  # Two branches that change the same line of the same file differently.
  git -C "$FIXTURE" checkout -q -b feature-conflict-a || return 1
  printf 'line one A\nline two\nline three\n' > "$FIXTURE/staged-export-test/leadlists.php"
  git -C "$FIXTURE" add -A || return 1
  git -C "$FIXTURE" commit -qm "feature: conflict side A" || return 1

  git -C "$FIXTURE" checkout -q -b feature-conflict-b main || return 1
  printf 'line one B\nline two\nline three\n' > "$FIXTURE/staged-export-test/leadlists.php"
  git -C "$FIXTURE" add -A || return 1
  git -C "$FIXTURE" commit -qm "feature: conflict side B" || return 1

  # A branch that touches a different file, so it never conflicts.
  git -C "$FIXTURE" checkout -q -b feature-clean main || return 1
  printf 'a separate file\n' > "$FIXTURE/separate.txt"
  git -C "$FIXTURE" add -A || return 1
  git -C "$FIXTURE" commit -qm "feature: change a separate file" || return 1

  # A branch that is on the remote and a branch that is not.
  git -C "$FIXTURE" checkout -q -b feature-pushed main || return 1
  printf 'pushed content\n' > "$FIXTURE/pushed.txt"
  git -C "$FIXTURE" add -A || return 1
  git -C "$FIXTURE" commit -qm "feature: a branch that reaches the remote" || return 1

  git -C "$FIXTURE" checkout -q -b feature-unpushed main || return 1
  printf 'local only content\n' > "$FIXTURE/local-only.txt"
  git -C "$FIXTURE" add -A || return 1
  git -C "$FIXTURE" commit -qm "feature: a branch that never reaches the remote" || return 1

  git init -q --bare "$ORIGIN" || return 1
  git -C "$FIXTURE" remote add origin "file://$ORIGIN" || return 1
  git -C "$FIXTURE" push -q origin main || return 1
  git -C "$FIXTURE" push -q origin feature-pushed || return 1

  git -C "$FIXTURE" checkout -q main || return 1
  return 0
}

build_fixture || fail "cannot build the fixture repository"

# run_packet <outfile> <branch> ...: write a packet and echo the exit code.
run_packet() {
  local out=$1
  shift
  bash "$PACKET" --repo "$FIXTURE" --branch "$@" --out "$out" >"$out.stdout" 2>"$out.stderr"
  printf '%s' "$?"
}

# --- cases -----------------------------------------------------------------

test_help_exits_zero_and_prints_usage() {
  local out rc
  out=$(bash "$PACKET" --help 2>&1)
  rc=$?
  expect_code 0 "$rc" "--help must exit 0"
  assert_contains "$out" "Usage:" "the usage text must be printed"
  assert_contains "$out" "--repo" "the usage text must name the --repo flag"
  assert_contains "$out" "--branch" "the usage text must name the --branch flag"
  assert_contains "$out" "read-only" "the usage text must state that the script is read-only"
}

test_missing_repo_reports_exact_path_and_exits_nonzero() {
  local missing="$TMP_ROOT/nowhere/at/all" out rc
  out=$(bash "$PACKET" --repo "$missing" --branch main --out "$TMP_ROOT/missing.md" 2>&1)
  rc=$?
  [ "$rc" -ne 0 ] || fail "a missing repository path must exit non-zero, got 0"
  assert_contains "$out" "$missing" "the error must name the exact missing path"
}

test_unknown_branch_reports_exact_branch_and_exits_nonzero() {
  local out rc
  out=$(bash "$PACKET" --repo "$FIXTURE" --branch no-such-branch --out "$TMP_ROOT/unknown.md" 2>&1)
  rc=$?
  [ "$rc" -ne 0 ] || fail "an unresolvable branch must exit non-zero, got 0"
  assert_contains "$out" "no-such-branch" "the error must name the unresolvable branch"
}

test_single_branch_packet_names_branch_and_head() {
  local packet="$TMP_ROOT/single.md" rc head
  rc=$(run_packet "$packet" feature-parity-holds)
  expect_code 0 "$rc" "the packet run must succeed"
  assert_grep "feature-parity-holds" "$packet" "the packet must name the branch"
  head=$(git -C "$FIXTURE" rev-parse feature-parity-holds)
  assert_grep "$head" "$packet" "the packet must carry the full head commit"
  assert_grep "${head:0:8}" "$packet" "the packet must carry the short head commit"
}

test_packet_carries_every_required_section() {
  local packet="$TMP_ROOT/sections.md" rc section
  rc=$(run_packet "$packet" feature-parity-holds feature-clean)
  expect_code 0 "$rc" "the packet run must succeed"
  for section in \
    "# Merge packet" \
    "## 1. Summary" \
    "## 2. Method and safety" \
    "## 3. Base branch and merge bases" \
    "## 4. Branch detail" \
    "#### Identity" \
    "#### Diff summary" \
    "#### What it changes, in plain terms" \
    "#### Blast radius" \
    "#### Invariant check" \
    "#### Test evidence" \
    "#### Conflicts" \
    "#### Rollback" \
    "#### Recommendation" \
    "## 5. Proposed merge order" \
    "## 6. The single decision requested"; do
    assert_grep "$section" "$packet" "the packet must carry the section: $section"
  done
}

test_parity_holds_when_the_copies_are_identical() {
  local packet="$TMP_ROOT/parity-holds.md" rc
  rc=$(run_packet "$packet" feature-parity-holds)
  expect_code 0 "$rc" "the packet run must succeed"
  assert_grep "Parity: **HOLDS**" "$packet" "the parity check must report HOLDS"
  assert_grep "staged-export-test/leadlists.php" "$packet" "the packet must name the first copy"
  assert_grep "current-core-distro/leadlists.php" "$packet" "the packet must name the second copy"
  local digest
  digest=$(git -C "$FIXTURE" show feature-parity-holds:staged-export-test/leadlists.php | sha256sum | cut -d' ' -f1)
  assert_grep "$digest" "$packet" "the packet must carry the sha256 of the copy on the branch"
}

test_parity_is_broken_when_the_copies_differ() {
  local packet="$TMP_ROOT/parity-broken.md" rc
  rc=$(run_packet "$packet" feature-parity-broken)
  expect_code 0 "$rc" "the packet run must succeed"
  assert_grep "Parity: **BROKEN**" "$packet" "the parity check must report BROKEN"
  assert_grep "DO NOT MERGE" "$packet" "a broken parity must produce a do not merge recommendation"
}

test_explicit_parity_pair_is_reported() {
  local packet="$TMP_ROOT/parity-explicit.md" rc
  bash "$PACKET" --repo "$FIXTURE" --branch feature-parity-broken \
    --parity "current-core-distro/leadlists.php=staged-export-test/leadlists.php" \
    --out "$packet" >/dev/null 2>&1
  rc=$?
  expect_code 0 "$rc" "the packet run must succeed"
  assert_grep "Parity: **BROKEN**" "$packet" "an explicit parity pair must be reported"
}

test_conflicting_branches_are_reported_conflicting_with_detail() {
  local packet="$TMP_ROOT/conflict.md" rc
  rc=$(run_packet "$packet" feature-conflict-a feature-conflict-b feature-clean)
  expect_code 0 "$rc" "the packet run must succeed"
  assert_grep "Against ${BT}feature-conflict-b${BT}: **CONFLICTING** (rc=1)" "$packet" \
    "the conflicting pair must be reported as CONFLICTING with the return code"
  assert_grep "CONFLICT (content)" "$packet" \
    "the conflict detail must be quoted from the tool output"
  assert_grep "All-branches three-way merge: **CONFLICTING**" "$packet" \
    "the all-branches verdict must be CONFLICTING when a pair conflicts"
}

test_non_conflicting_branches_are_reported_clean_in_both_directions() {
  local packet="$TMP_ROOT/clean.md" rc
  rc=$(run_packet "$packet" feature-conflict-a feature-conflict-b feature-clean)
  expect_code 0 "$rc" "the packet run must succeed"
  assert_grep "Against ${BT}feature-clean${BT}: **CLEAN** (rc=0)" "$packet" \
    "a non-conflicting pair must be reported as CLEAN from the first branch"
  assert_grep "Against ${BT}feature-conflict-b${BT}: **CLEAN** (rc=0)" "$packet" \
    "a non-conflicting pair must be reported as CLEAN from the second branch"
  assert_grep "Against ${BT}feature-conflict-a${BT}: **CLEAN** (rc=0)" "$packet" \
    "the clean branch must be reported as CLEAN against the conflicting branch"
}

test_unpushed_head_is_flagged_and_pushed_head_is_not() {
  local packet="$TMP_ROOT/push.md" rc
  rc=$(run_packet "$packet" feature-pushed feature-unpushed)
  expect_code 0 "$rc" "the packet run must succeed"
  assert_grep "| NOT PUSHED |" "$packet" "a local-only head must be flagged as not pushed"
  assert_grep "| PUSHED |" "$packet" "a head that is on the remote must be reported as pushed"
  assert_grep "is not on the remote" "$packet" "the packet must explain the not-pushed risk"
}

test_rollback_section_carries_undo_and_verification_commands() {
  local packet="$TMP_ROOT/rollback.md" rc
  rc=$(run_packet "$packet" feature-parity-holds)
  expect_code 0 "$rc" "the packet run must succeed"
  assert_grep "git reset --hard HEAD^" "$packet" "the rollback must carry an undo command"
  assert_grep "git revert -m 1 --no-edit HEAD" "$packet" \
    "the rollback must carry an undo command for an already pushed merge"
  assert_grep "git status --porcelain" "$packet" "the rollback must carry a verification command"
  assert_grep "git diff --stat" "$packet" "the rollback must carry a verification command"
}

test_decision_section_states_what_one_word_does_and_does_not_authorise() {
  local packet="$TMP_ROOT/decision.md" rc
  rc=$(run_packet "$packet" feature-parity-holds feature-clean)
  expect_code 0 "$rc" "the packet run must succeed"
  assert_grep "DECISION REQUESTED" "$packet" "the packet must carry a delimited decision section"
  assert_grep "The word **merge** authorises exactly this and nothing else" "$packet" \
    "the decision section must state what one word authorises"
  assert_grep "does NOT authorise" "$packet" \
    "the decision section must state what one word does not authorise"
  assert_grep "Any deployment" "$packet" "the decision section must exclude deploys"
  assert_grep "production database" "$packet" "the decision section must exclude production data changes"
  assert_grep "credential" "$packet" "the decision section must exclude credential rotation"
  assert_grep "another repository" "$packet" "the decision section must exclude other repositories"
  assert_grep "## 6. The single decision requested" "$packet" \
    "the decision section must be the last numbered section"
}

test_stdin_branch_list_is_accepted() {
  local packet="$TMP_ROOT/stdin.md" rc
  printf 'feature-clean\nfeature-parity-holds\n' \
    | bash "$PACKET" --repo "$FIXTURE" --stdin --out "$packet" >/dev/null 2>&1
  rc=$?
  expect_code 0 "$rc" "the stdin mode must succeed"
  assert_grep "feature-clean" "$packet" "the stdin branch list must reach the packet"
  assert_grep "feature-parity-holds" "$packet" "the stdin branch list must reach the packet"
}

test_the_fixture_repository_is_not_mutated() {
  local before_head before_status before_commits before_objects
  local after_head after_status after_commits after_objects
  before_head=$(git -C "$FIXTURE" rev-parse HEAD)
  before_status=$(git -C "$FIXTURE" status --porcelain)
  before_commits=$(git -C "$FIXTURE" rev-list --all --count)
  before_objects=$(git -C "$FIXTURE" cat-file --batch-all-objects --batch-check='%(objectname)' | wc -l)

  run_packet "$TMP_ROOT/nomutate.md" \
    feature-parity-holds feature-parity-broken feature-conflict-a feature-conflict-b feature-clean >/dev/null

  after_head=$(git -C "$FIXTURE" rev-parse HEAD)
  after_status=$(git -C "$FIXTURE" status --porcelain)
  after_commits=$(git -C "$FIXTURE" rev-list --all --count)
  after_objects=$(git -C "$FIXTURE" cat-file --batch-all-objects --batch-check='%(objectname)' | wc -l)

  [ "$before_head" = "$after_head" ] \
    || fail "the script must not move HEAD: before $before_head, after $after_head"
  [ "$before_status" = "$after_status" ] \
    || fail "the script must not change the working tree status: before [$before_status], after [$after_status]"
  [ "$before_commits" = "$after_commits" ] \
    || fail "the script must not create a commit: before $before_commits, after $after_commits"
  [ "$before_objects" = "$after_objects" ] \
    || fail "the script must not write an object into the repository: before $before_objects, after $after_objects"
}

# --- runner ----------------------------------------------------------------

PASS_COUNT=0
FAIL_COUNT=0
CASE_COUNT=0

run_case() {
  local name=$1
  shift
  local log="$TMP_ROOT/logs/$name.log"
  mkdir -p "$TMP_ROOT/logs"
  CASE_COUNT=$((CASE_COUNT + 1))
  if ( "$@" ) >"$log" 2>&1; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'ok - %s\n' "$name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'not ok - %s\n' "$name"
    sed 's/^/    /' "$log"
  fi
}

run_case help_exits_zero_and_prints_usage test_help_exits_zero_and_prints_usage
run_case missing_repo_reports_exact_path_and_exits_nonzero test_missing_repo_reports_exact_path_and_exits_nonzero
run_case unknown_branch_reports_exact_branch_and_exits_nonzero test_unknown_branch_reports_exact_branch_and_exits_nonzero
run_case single_branch_packet_names_branch_and_head test_single_branch_packet_names_branch_and_head
run_case packet_carries_every_required_section test_packet_carries_every_required_section
run_case parity_holds_when_the_copies_are_identical test_parity_holds_when_the_copies_are_identical
run_case parity_is_broken_when_the_copies_differ test_parity_is_broken_when_the_copies_differ
run_case explicit_parity_pair_is_reported test_explicit_parity_pair_is_reported
run_case conflicting_branches_are_reported_conflicting_with_detail test_conflicting_branches_are_reported_conflicting_with_detail
run_case non_conflicting_branches_are_reported_clean_in_both_directions test_non_conflicting_branches_are_reported_clean_in_both_directions
run_case unpushed_head_is_flagged_and_pushed_head_is_not test_unpushed_head_is_flagged_and_pushed_head_is_not
run_case rollback_section_carries_undo_and_verification_commands test_rollback_section_carries_undo_and_verification_commands
run_case decision_section_states_what_one_word_does_and_does_not_authorise test_decision_section_states_what_one_word_does_and_does_not_authorise
run_case stdin_branch_list_is_accepted test_stdin_branch_list_is_accepted
run_case the_fixture_repository_is_not_mutated test_the_fixture_repository_is_not_mutated

printf '\n%d cases, %d passed, %d failed\n' "$CASE_COUNT" "$PASS_COUNT" "$FAIL_COUNT"

[ "$FAIL_COUNT" -eq 0 ] || exit 1
exit 0
