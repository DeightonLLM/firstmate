#!/usr/bin/env bash
# Regression test: the personal fleet paths must stay untracked in git.
#
# data/, state/, config/, projects/ and .no-mistakes/ are captain-private and
# gitignored (AGENTS.md section 2, .gitignore lines 1 to 4 and 11).
# The CI invariants job "Personal fleet paths must not be tracked" enforces
# the same contract with `git ls-files -- data state config projects
# .no-mistakes`, and it is RED whenever any of them is tracked.
#
# Tracking these paths is not merely untidy.
# git check-ignore consults the INDEX, and it reports a tracked path as NOT
# ignored, so a tracked personal path defeats the ignore rule that keeps the
# path local.
# A tracked data/ is worse than a tracked config/: every home then receives a
# frozen committed snapshot of the upstream data/ tree instead of a live
# local file, so the second mate home's data/backlog.md stops being the live
# backlog.
#
# This test fails if any path under those five roots is ever tracked again.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# The five captain-private roots, in the order the CI invariants job lists
# them.
PERSONAL_ROOTS=(data state config projects .no-mistakes)

# One scratch root for the whole suite.
# fm_test_tmproot is called outside a command substitution so its cleanup trap
# is installed in this shell and removes the directory on exit. Calling it
# inside $(...) would install the trap in the substitution subshell, which
# exits immediately and deletes the directory before the suite can use it.
fm_test_tmproot fm-personal-paths >/dev/null
TMP_ROOT="${FM_TEST_CLEANUP_DIRS[${#FM_TEST_CLEANUP_DIRS[@]} - 1]}"
[ -d "$TMP_ROOT" ] || fail "could not create the scratch directory"

# No path under any personal root may be tracked in the index.
# This is the same assertion the CI invariants job makes, so a local run and
# the CI job agree on the contract.
test_personal_roots_have_no_tracked_path() {
  local tracked
  tracked=$(git -C "$ROOT" ls-files -- "${PERSONAL_ROOTS[@]}")
  [ -z "$tracked" ] \
    || fail "personal fleet paths must stay untracked, but git tracks these paths:$(printf '\n')$tracked"
  pass "no path under data/ state/ config/ projects/ .no-mistakes/ is tracked in the index"
}

# No path under any personal root may be in the committed tree.
# The index can be clean while a commit still carries the paths, and a fresh
# clone materialises the committed tree, so the committed tree is the check
# that governs what other homes receive.
test_personal_roots_have_no_committed_path() {
  local committed
  committed=$(git -C "$ROOT" ls-tree -r --name-only HEAD -- "${PERSONAL_ROOTS[@]}")
  [ -z "$committed" ] \
    || fail "the committed tree still carries personal fleet paths:$(printf '\n')$committed"
  pass "the committed tree carries no personal fleet path"
}

# The repo root must ignore each personal root, not merely lack tracked
# content. This is the rule git check-ignore consults, and it is what keeps a
# newly created personal file out of the index in the first place.
test_personal_roots_are_gitignored() {
  local root
  for root in "${PERSONAL_ROOTS[@]}"; do
    git -C "$ROOT" check-ignore -q -- "$root/.fm-not-tracked-probe" \
      || fail "$root/ is not gitignored for the repo root"
  done
  pass "data/ state/ config/ projects/ .no-mistakes/ are gitignored for the repo root"
}

# A fresh clone must carry no personal fleet path.
# A clone materialises the committed tree, so this is the end-to-end check
# that proves a new home receives a live local data/ instead of a frozen
# committed snapshot of the upstream data/ tree.
# The clone is made with a checkout on purpose: an unpopulated index reports
# no tracked path and would make the assertion vacuous.
test_a_fresh_clone_carries_no_personal_path() {
  local clone tracked
  clone="$TMP_ROOT/clone"
  git clone --quiet --local "$ROOT" "$clone" 2>/dev/null \
    || fail "could not clone the repo into a scratch directory"
  tracked=$(git -C "$clone" ls-files -- "${PERSONAL_ROOTS[@]}")
  [ -z "$tracked" ] \
    || fail "a fresh clone tracks personal fleet paths:$(printf '\n')$tracked"
  assert_absent "$clone/data" "a fresh clone materialised a data/ directory"
  pass "a fresh clone carries no personal fleet path"
}

# The behavioural consequence, proven on a throwaway index so the real index
# is never touched.
# git check-ignore reports a TRACKED path as NOT ignored, so tracking a
# personal path silently defeats the ignore rule that keeps the path local.
# The throwaway index carries one planted tracked path under data/ and proves
# that check-ignore changes its answer for exactly that path.
test_a_tracked_personal_path_is_reported_as_not_ignored() {
  local index blob probe ignored_rc
  index="$TMP_ROOT/index"
  probe="data/.fm-not-tracked-probe"
  blob=$(git -C "$ROOT" ls-tree HEAD | awk '$2 == "blob" { print $3; exit }')
  [ -n "$blob" ] || fail "could not find a blob in HEAD to plant in the throwaway index"
  GIT_INDEX_FILE="$index" git -C "$ROOT" read-tree HEAD \
    || fail "could not build a throwaway index from HEAD"
  GIT_INDEX_FILE="$index" git -C "$ROOT" update-index --add --cacheinfo "100644,$blob,$probe" \
    || fail "could not plant a tracked path under data/ in the throwaway index"
  # check-ignore exits 0 when the path IS ignored and 1 when it is not.
  GIT_INDEX_FILE="$index" git -C "$ROOT" check-ignore -q -- "$probe"
  ignored_rc=$?
  [ "$ignored_rc" != "0" ] \
    || fail "a tracked path under data/ is still reported as ignored, so tracking would not defeat the ignore rule"
  pass "a tracked path under data/ is reported as not ignored, so tracking defeats the ignore rule"
}

test_personal_roots_have_no_tracked_path
test_personal_roots_have_no_committed_path
test_personal_roots_are_gitignored
test_a_fresh_clone_carries_no_personal_path
test_a_tracked_personal_path_is_reported_as_not_ignored

echo "# all fm-personal-paths-not-tracked tests passed"
