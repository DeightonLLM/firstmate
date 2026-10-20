#!/usr/bin/env bash
# bin/fm-upstream-drift.test.sh - contract tests for the firstmate upstream drift detector.
#
# Contract under test (owner: docs/upstream-drift.md):
#   - the detector compares a local docs/ tree against an upstream docs/ tree
#   - it reports identical, divergent, missing-locally, and local-only files
#   - it exits 0 with no drift, 1 with drift, and 2 on a usage error
#   - it never writes into the local tree and never touches the network
#
# Every case builds a throwaway local tree and a throwaway upstream tree under a
# temp dir, so the suite never reads the real docs/ tree and never reaches the
# network: a fake curl and a fake gh sit first on PATH and record any attempt.
#
# Every case runs, each case prints a PASS/FAIL line, and the suite exits
# non-zero when any case failed.
#
# shellcheck disable=SC2329 # Every case function is dispatched by name at run time.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTOR="$SELF_DIR/fm-upstream-drift.sh"

TMP_ROOT=""
PASS_COUNT=0
FAIL_COUNT=0
RUN_OUT=""
RUN_RC=0
NETWORK_MARKER=""

# shellcheck disable=SC2329 # Invoked by the EXIT trap below, not by name.
cleanup() {
  if [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf -- "$TMP_ROOT"
  fi
}
trap cleanup EXIT

# --- helpers ---------------------------------------------------------------

# t_fail <reason>: report the detail of a failing case and return non-zero.
# It does not abort the suite, so every case still runs.
t_fail() {
  printf '  detail: %s\n' "$1" >&2
  return 1
}

# expect_exit <expected> <actual> <label>
expect_exit() {
  [ "$2" = "$1" ] || { t_fail "$3: expected exit $1, got $2"; return 1; }
  return 0
}

# expect_contains <output> <needle> <label>
expect_contains() {
  printf '%s\n' "$1" | grep -qF -- "$2" \
    || { t_fail "$3: the output does not contain '$2'"; return 1; }
  return 0
}

# expect_not_contains <output> <needle> <label>
expect_not_contains() {
  printf '%s\n' "$1" | grep -qF -- "$2" \
    && { t_fail "$3: the output unexpectedly contains '$2'"; return 1; }
  return 0
}

# run_detector <args...>: run the detector and capture its output and exit code.
run_detector() {
  RUN_OUT=$(bash "$DETECTOR" "$@" 2>&1)
  RUN_RC=$?
  return 0
}

# make_tree <name>: build an empty local tree and an empty upstream tree.
make_tree() {
  local name=$1 dir
  dir="$TMP_ROOT/$name"
  mkdir -p "$dir/local" "$dir/upstream"
  printf '%s\n' "$dir"
}

# tree_fingerprint <dir>: a portable digest of every file path and content.
tree_fingerprint() {
  local dir=$1 f
  find "$dir" -type f | LC_ALL=C sort | while IFS= read -r f; do
    cksum "$f"
  done
}

# lint_detector: run shellcheck on the detector and fail if it finds issues.
lint_detector() {
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning "$DETECTOR" >/dev/null 2>&1 \
      || { t_fail "shellcheck found issues in $DETECTOR"; return 1; }
  fi
  return 0
}

# --- cases -----------------------------------------------------------------

test_detector_exists_and_is_executable() {
  [ -f "$DETECTOR" ] || { t_fail "$DETECTOR does not exist"; return 1; }
  [ -x "$DETECTOR" ] || { t_fail "$DETECTOR is not executable"; return 1; }
  lint_detector || return 1
  return 0
}

test_identical_trees_report_no_drift() {
  local dir rc
  dir=$(make_tree identical)
  printf 'same body\n' > "$dir/local/a.md"
  printf 'same body\n' > "$dir/upstream/a.md"
  printf 'same body too\n' > "$dir/local/b.md"
  printf 'same body too\n' > "$dir/upstream/b.md"
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/upstream"
  rc=$RUN_RC
  expect_exit 0 "$rc" 'identical trees must report no drift' || return 1
  expect_contains "$RUN_OUT" 'VERDICT: NO-DRIFT' 'the verdict must be NO-DRIFT' || return 1
  expect_contains "$RUN_OUT" 'identical=2' 'both files must be counted as identical' || return 1
  expect_contains "$RUN_OUT" 'divergent=0' 'no file may be counted as divergent' || return 1
  expect_contains "$RUN_OUT" 'missing=0' 'no file may be counted as missing' || return 1
  expect_contains "$RUN_OUT" 'local_only=0' 'no file may be counted as local-only' || return 1
  return 0
}

test_one_file_differing_in_size_is_divergent() {
  local dir rc
  dir=$(make_tree divergent)
  printf 'same body\n' > "$dir/local/a.md"
  printf 'same body\n' > "$dir/upstream/a.md"
  printf 'short local\n' > "$dir/local/b.md"
  printf 'a much longer upstream body\nsecond line\nthird line\n' > "$dir/upstream/b.md"
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/upstream"
  rc=$RUN_RC
  expect_exit 1 "$rc" 'a divergent file must exit 1' || return 1
  expect_contains "$RUN_OUT" 'VERDICT: DRIFT' 'the verdict must be DRIFT' || return 1
  expect_contains "$RUN_OUT" 'kind=upstream-newer' 'a larger upstream file must be upstream-newer' || return 1
  expect_contains "$RUN_OUT" 'divergent=1' 'exactly one file must be divergent' || return 1
  expect_contains "$RUN_OUT" 'identical=1' 'the unchanged file must stay identical' || return 1
  return 0
}

test_smaller_upstream_file_is_upstream_smaller() {
  local dir rc
  dir=$(make_tree smaller)
  printf 'a much longer local body\nsecond line\nthird line\n' > "$dir/local/a.md"
  printf 'short upstream\n' > "$dir/upstream/a.md"
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/upstream"
  rc=$RUN_RC
  expect_exit 1 "$rc" 'a divergent file must exit 1' || return 1
  expect_contains "$RUN_OUT" 'kind=upstream-smaller' 'a smaller upstream file must be upstream-smaller' || return 1
  return 0
}

test_same_size_different_content_is_content_divergent() {
  local dir rc
  dir=$(make_tree samesize)
  printf 'alpha body\n' > "$dir/local/a.md"
  printf 'omega body\n' > "$dir/upstream/a.md"
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/upstream"
  rc=$RUN_RC
  expect_exit 1 "$rc" 'a same-size different file must exit 1' || return 1
  expect_contains "$RUN_OUT" 'kind=content-divergent' 'a same-size different file must be content-divergent' || return 1
  return 0
}

test_upstream_file_missing_locally_is_reported() {
  local dir rc
  dir=$(make_tree missing)
  printf 'present\n' > "$dir/local/a.md"
  printf 'present\n' > "$dir/upstream/a.md"
  printf 'upstream only\n' > "$dir/upstream/only-upstream.md"
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/upstream"
  rc=$RUN_RC
  expect_exit 1 "$rc" 'a missing upstream file must exit 1' || return 1
  expect_contains "$RUN_OUT" 'MISSING-LOCALLY (1)' 'the missing file must be listed' || return 1
  expect_contains "$RUN_OUT" 'docs/only-upstream.md' 'the missing file must be named' || return 1
  expect_contains "$RUN_OUT" 'missing=1' 'exactly one file must be missing' || return 1
  return 0
}

test_local_only_file_is_reported_without_drift() {
  local dir rc
  dir=$(make_tree localonly)
  printf 'present\n' > "$dir/local/a.md"
  printf 'present\n' > "$dir/upstream/a.md"
  printf 'house only\n' > "$dir/local/only-local.md"
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/upstream"
  rc=$RUN_RC
  expect_exit 0 "$rc" 'a local-only house addition must not report drift' || return 1
  expect_contains "$RUN_OUT" 'LOCAL-ONLY (1)' 'the local-only file must be listed' || return 1
  expect_contains "$RUN_OUT" 'docs/only-local.md' 'the local-only file must be named' || return 1
  expect_contains "$RUN_OUT" 'local_only=1' 'exactly one file must be local-only' || return 1
  expect_contains "$RUN_OUT" 'VERDICT: NO-DRIFT' 'the verdict must be NO-DRIFT' || return 1
  return 0
}

test_empty_local_tree_reports_every_upstream_file_missing() {
  local dir rc
  dir=$(make_tree emptylocal)
  printf 'one\n' > "$dir/upstream/a.md"
  printf 'two\n' > "$dir/upstream/b.md"
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/upstream"
  rc=$RUN_RC
  expect_exit 1 "$rc" 'an empty local tree against upstream files must exit 1' || return 1
  expect_contains "$RUN_OUT" 'MISSING-LOCALLY (2)' 'both upstream files must be missing' || return 1
  expect_contains "$RUN_OUT" 'missing=2' 'the missing count must be 2' || return 1
  expect_contains "$RUN_OUT" 'identical=0' 'nothing can be identical' || return 1
  return 0
}

test_empty_upstream_tree_reports_every_local_file_local_only() {
  local dir rc
  dir=$(make_tree emptyupstream)
  printf 'one\n' > "$dir/local/a.md"
  printf 'two\n' > "$dir/local/b.md"
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/upstream"
  rc=$RUN_RC
  expect_exit 0 "$rc" 'an empty upstream tree carries no upstream drift' || return 1
  expect_contains "$RUN_OUT" 'LOCAL-ONLY (2)' 'both local files must be local-only' || return 1
  expect_contains "$RUN_OUT" 'local_only=2' 'the local-only count must be 2' || return 1
  expect_contains "$RUN_OUT" 'upstream_files=0' 'the upstream file count must be 0' || return 1
  return 0
}

test_missing_upstream_dir_is_a_usage_error() {
  local dir rc
  dir=$(make_tree missingdir)
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/absent-upstream"
  rc=$RUN_RC
  expect_exit 2 "$rc" 'a missing upstream directory must exit 2' || return 1
  expect_contains "$RUN_OUT" 'the upstream directory does not exist' 'the failure must name the missing directory' || return 1
  return 0
}

test_missing_local_dir_is_a_usage_error() {
  local dir rc
  dir=$(make_tree missinglocal)
  run_detector --local-dir "$dir/absent-local" --upstream-dir "$dir/upstream"
  rc=$RUN_RC
  expect_exit 2 "$rc" 'a missing local directory must exit 2' || return 1
  expect_contains "$RUN_OUT" 'the local docs directory does not exist' 'the failure must name the missing directory' || return 1
  return 0
}

test_unknown_argument_is_a_usage_error() {
  run_detector --not-a-real-flag
  local rc=$RUN_RC
  expect_exit 2 "$rc" 'an unknown argument must exit 2' || return 1
  expect_contains "$RUN_OUT" 'unknown argument' 'the failure must name the unknown argument' || return 1
  return 0
}

test_help_exits_zero_and_prints_usage() {
  run_detector --help
  local rc=$RUN_RC
  expect_exit 0 "$rc" '--help must exit 0' || return 1
  expect_contains "$RUN_OUT" 'Usage:' '--help must print the usage header' || return 1
  return 0
}

test_quiet_summary_keeps_the_counts_and_drops_the_listing() {
  local dir rc
  dir=$(make_tree quiet)
  printf 'one\n' > "$dir/local/a.md"
  printf 'one\n' > "$dir/upstream/a.md"
  printf 'two\n' > "$dir/upstream/only.md"
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/upstream" --quiet-summary
  rc=$RUN_RC
  expect_exit 1 "$rc" 'a quiet summary must keep the drift exit code' || return 1
  expect_contains "$RUN_OUT" 'SUMMARY:' 'the quiet summary must keep the summary line' || return 1
  expect_contains "$RUN_OUT" 'VERDICT: DRIFT' 'the quiet summary must keep the verdict' || return 1
  expect_not_contains "$RUN_OUT" 'IDENTICAL (' 'the quiet summary must drop the file listing' || return 1
  return 0
}

test_fetch_cap_is_reported_when_it_is_reached() {
  local dir rc
  dir=$(make_tree fetchcap)
  printf 'short local\n' > "$dir/local/a.md"
  printf 'a much longer upstream body\nsecond line\n' > "$dir/upstream/a.md"
  printf 'short local\n' > "$dir/local/b.md"
  printf 'a much longer upstream body\nsecond line\n' > "$dir/upstream/b.md"
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/upstream" --max-fetch 1
  rc=$RUN_RC
  expect_exit 1 "$rc" 'a capped comparison must still report the drift' || return 1
  expect_contains "$RUN_OUT" 'CONTENT-FETCH: used=1 cap=1' 'the content fetch budget must be reported' || return 1
  expect_contains "$RUN_OUT" 'capped_files=1' 'the capped file count must be reported' || return 1
  expect_contains "$RUN_OUT" 'divergent=2' 'the capped file must still be counted as divergent' || return 1
  return 0
}

test_detector_does_not_modify_the_local_tree() {
  local dir before after
  dir=$(make_tree readonly)
  printf 'local body\n' > "$dir/local/a.md"
  printf 'a much longer upstream body\nsecond line\n' > "$dir/upstream/a.md"
  before=$(tree_fingerprint "$dir/local")
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/upstream"
  after=$(tree_fingerprint "$dir/local")
  [ "$before" = "$after" ] \
    || { t_fail 'the detector must not modify the local tree'; return 1; }
  return 0
}

test_detector_never_reaches_the_network_in_local_dir_mode() {
  local dir
  dir=$(make_tree offline)
  printf 'local body\n' > "$dir/local/a.md"
  printf 'a much longer upstream body\nsecond line\n' > "$dir/upstream/a.md"
  run_detector --local-dir "$dir/local" --upstream-dir "$dir/upstream"
  if [ -s "$NETWORK_MARKER" ]; then
    t_fail "the detector reached the network: $(cat "$NETWORK_MARKER")"
    return 1
  fi
  expect_contains "$RUN_OUT" 'mode=local-dir' 'the detector must report the offline mode' || return 1
  return 0
}

test_self_guard_refuses_a_mutating_version_control_command() {
  local dir copy rc
  dir=$(make_tree selfguard)
  copy="$dir/detector-with-a-mutating-command.sh"
  cp "$DETECTOR" "$copy"
  printf '%s\n' '# git commit -am drift' >> "$copy"
  chmod +x "$copy"
  RUN_OUT=$(bash "$copy" --local-dir "$dir/local" --upstream-dir "$dir/upstream" 2>&1)
  rc=$?
  expect_exit 2 "$rc" 'the self-guard must refuse to run' || return 1
  expect_contains "$RUN_OUT" 'self-guard' 'the refusal must name the self-guard' || return 1
  return 0
}

# --- runner ----------------------------------------------------------------

# run_case <name> <function>: run one case and count the result.
run_case() {
  local name=$1
  shift
  printf '# CASE: %s\n' "$name"
  if "$@"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS: %s\n' "$name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL: %s\n' "$name"
  fi
}

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-upstream-drift-tests.XXXXXX") || exit 1

# A fake curl and a fake gh sit first on PATH and record every attempt to reach
# the network, so a regression that reaches out fails the suite instead of
# silently depending on the public GitHub API.
NETWORK_MARKER="$TMP_ROOT/network-attempts.log"
mkdir -p "$TMP_ROOT/fakebin"
for tool in curl gh; do
  cat > "$TMP_ROOT/fakebin/$tool" <<SH
#!/usr/bin/env bash
printf '%s %s\n' "$tool" "\$*" >> "$NETWORK_MARKER"
exit 99
SH
  chmod +x "$TMP_ROOT/fakebin/$tool"
done
export PATH="$TMP_ROOT/fakebin:$PATH"

for _case in \
  test_detector_exists_and_is_executable \
  test_identical_trees_report_no_drift \
  test_one_file_differing_in_size_is_divergent \
  test_smaller_upstream_file_is_upstream_smaller \
  test_same_size_different_content_is_content_divergent \
  test_upstream_file_missing_locally_is_reported \
  test_local_only_file_is_reported_without_drift \
  test_empty_local_tree_reports_every_upstream_file_missing \
  test_empty_upstream_tree_reports_every_local_file_local_only \
  test_missing_upstream_dir_is_a_usage_error \
  test_missing_local_dir_is_a_usage_error \
  test_unknown_argument_is_a_usage_error \
  test_help_exits_zero_and_prints_usage \
  test_quiet_summary_keeps_the_counts_and_drops_the_listing \
  test_fetch_cap_is_reported_when_it_is_reached \
  test_detector_does_not_modify_the_local_tree \
  test_detector_never_reaches_the_network_in_local_dir_mode \
  test_self_guard_refuses_a_mutating_version_control_command; do
  run_case "$_case" "$_case"
done

printf '\n# SUMMARY: total %d, passed %d, failed %d\n' \
  "$((PASS_COUNT + FAIL_COUNT))" "$PASS_COUNT" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -ne 0 ]; then
  printf '# RESULT: FAILED\n'
  exit 1
fi

printf '# RESULT: PASSED\n'
exit 0
