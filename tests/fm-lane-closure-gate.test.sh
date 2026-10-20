#!/usr/bin/env bash
# tests/fm-lane-closure-gate.test.sh - the enforcement point for "no artifact means no claim".
# The suite drives the gate through its executable interface against purpose-built
# manifests, so it asserts the published contract and never the gate's source bytes.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

GATE="$ROOT/bin/fm-lane-closure-gate.sh"
TMP_ROOT=$(fm_test_tmproot fm-lane-closure-gate-tests)

# make_case <name>: a home with a programme manifest and a lane output area.
make_case() {
  local name=$1 dir
  dir="$TMP_ROOT/$name"
  mkdir -p "$dir/data/core-remediation/lanes/demo"
  printf '%s\n' "$dir"
}

# write_manifest <dir> <lane-json>
write_manifest() {
  local dir=$1 lane=$2
  cat > "$dir/data/core-remediation/lanes.json" <<MANIFEST
{
  "programme": "test-programme",
  "lanes": [
$lane
  ]
}
MANIFEST
}

run_gate() {
  local dir=$1
  shift
  bash "$GATE" --manifest "$dir/data/core-remediation/lanes.json" "$@" >"$dir/out.txt" 2>"$dir/err.txt"
  printf '%s' "$?"
}

test_closed_lane_without_artifact_is_a_violation() {
  local dir rc
  dir=$(make_case violation)
  write_manifest "$dir" '    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  rc=$(run_gate "$dir")
  expect_code 1 "$rc" "a closed lane with no artifact must fail the gate"
  assert_grep "VIOLATION" "$dir/err.txt" "the violation must be reported on stderr"
  pass "a closed lane with no artifact fails the gate"
}

test_closed_lane_with_verdict_passes() {
  local dir rc
  dir=$(make_case closed)
  write_manifest "$dir" '    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  printf 'VERDICT: CONFIRMED\n\nbody\n' > "$dir/data/core-remediation/lanes/demo/report.md"
  rc=$(run_gate "$dir")
  expect_code 0 "$rc" "a closed lane with a verdict must pass the gate"
  assert_grep "closed" "$dir/out.txt" "the lane must be reported as closed"
  pass "a closed lane with a verdict passes the gate"
}

test_closed_lane_without_a_verdict_is_a_violation() {
  local dir rc
  dir=$(make_case no-verdict)
  write_manifest "$dir" '    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  printf 'just some prose with no verdict line\n' > "$dir/data/core-remediation/lanes/demo/report.md"
  rc=$(run_gate "$dir")
  expect_code 1 "$rc" "a closed lane with no verdict must fail the gate"
  pass "a closed lane with no verdict fails the gate"
}

test_dispatched_lane_without_artifact_is_open_not_a_violation() {
  local dir rc
  dir=$(make_case open)
  write_manifest "$dir" '    {"id": "demo", "status": "dispatched", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  rc=$(run_gate "$dir")
  expect_code 0 "$rc" "a dispatched lane with no artifact is open, not a violation"
  assert_grep "open" "$dir/out.txt" "the lane must be reported as open"
  pass "a dispatched lane with no artifact is open rather than a violation"
}

test_strict_mode_fails_while_a_lane_is_open() {
  local dir rc
  dir=$(make_case strict)
  write_manifest "$dir" '    {"id": "demo", "status": "dispatched", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  rc=$(run_gate "$dir" --strict)
  expect_code 1 "$rc" "strict mode must fail while a lane is open"
  pass "strict mode fails while any lane is open"
}

test_missing_manifest_fails_closed() {
  local dir rc
  dir=$(make_case missing)
  rc=$(run_gate "$dir")
  expect_code 1 "$rc" "a missing manifest must fail the gate rather than pass silently"
  pass "a missing manifest fails the gate"
}

test_unknown_lane_is_rejected() {
  local dir rc
  dir=$(make_case unknown)
  write_manifest "$dir" '    {"id": "demo", "status": "dispatched", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  rc=$(run_gate "$dir" --lane nope)
  expect_code 1 "$rc" "an unknown lane id must fail the gate"
  pass "an unknown lane id is rejected"
}

test_single_lane_selection_is_reported() {
  local dir rc
  dir=$(make_case single)
  write_manifest "$dir" '    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"},
    {"id": "other", "status": "closed", "artifact": "data/core-remediation/lanes/other/report.md", "verdict_prefix": "VERDICT:"}'
  printf 'VERDICT: CONFIRMED\n' > "$dir/data/core-remediation/lanes/demo/report.md"
  rc=$(run_gate "$dir" --lane demo)
  expect_code 0 "$rc" "the selected lane must be checked on its own"
  assert_grep "demo" "$dir/out.txt" "the selected lane must appear in the report"
  pass "a single lane can be selected for its own check"
}

run_tests() {
  test_closed_lane_without_artifact_is_a_violation
  test_closed_lane_with_verdict_passes
  test_closed_lane_without_a_verdict_is_a_violation
  test_dispatched_lane_without_artifact_is_open_not_a_violation
  test_strict_mode_fails_while_a_lane_is_open
  test_missing_manifest_fails_closed
  test_unknown_lane_is_rejected
  test_single_lane_selection_is_reported
}

run_tests
