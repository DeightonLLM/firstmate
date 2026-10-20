#!/usr/bin/env bash
# tests/fm-lane-closure-gate-enforcement.test.sh - the enforcement point for
# "a lane cannot close on a claim the fleet has not verified".
#
# bin/fm-lane-closure-gate.sh carries two preconditions of closure:
#   * checker-before-done: a PASS/DONE/ACCEPTED claim needs an independent
#     checker artifact behind it.
#   * visual correctness: a visual/UI scoped lane needs a real on-disk visual
#     artifact.
# This suite drives the gate through its executable interface against
# purpose-built manifests, so it asserts the published contract.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

GATE="$ROOT/bin/fm-lane-closure-gate.sh"
TMP_ROOT=$(fm_test_tmproot fm-lane-closure-gate-enforcement-tests)

# make_case <name>: a home with a programme manifest and a lane output area.
make_case() {
  local name=$1 dir
  dir="$TMP_ROOT/$name"
  mkdir -p "$dir/data/core-remediation/lanes/demo"
  printf '%s\n' "$dir"
}

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

# write_checker <dir>: an independent checker artifact that really carries a
# re-runnable check, so the honest case is honest and not merely well worded.
write_checker() {
  local dir=$1
  cat > "$dir/data/core-remediation/lanes/demo/report.checker.md" <<'CHECKER'
# Independent Audit
**Reviewer:** Independent Auditor (Lane w2M:p9)
Re-ran the lane's own suite from a clean checkout:
    $ bash tests/fm-lane-closure-gate-enforcement.test.sh
    8/8 assertions passed
    exit code 0
VERDICT: CHECK_PASS - the claim reproduces
CHECKER
}

# write_stub_visual_gate <dir> <exit-code>: a stand-in for the visual-correctness
# gate. The wiring must hold for whatever gate it is pointed at.
write_stub_visual_gate() {
  local dir=$1 code=$2
  cat > "$dir/stub-visual-gate.sh" <<STUB
#!/usr/bin/env bash
echo "VISUAL_CHECK: stub gate"
exit $code
STUB
  chmod +x "$dir/stub-visual-gate.sh"
}

# RED: a PASS claim with no independent checker behind it must not close.
test_pass_claim_without_a_checker_artifact_cannot_close() {
  local dir rc
  dir=$(make_case pass-unsupported)
  write_manifest "$dir" '    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  cat > "$dir/data/core-remediation/lanes/demo/report.md" <<'REPORT'
# Lane Report
**Author:** Worker Lane 42
Implemented the change and ran the suite.
VERDICT: PASS - all requirements completed
REPORT
  rc=$(run_gate "$dir")
  expect_code 1 "$rc" "a PASS claim with no independent checker must fail the gate"
  assert_grep "unsupported PASS claim refused by the checker-before-done gate" "$dir/err.txt" "the refusal must be reported on stderr"
  pass "a PASS claim with no independent checker cannot close the lane"
}

# GREEN: the same lane, with a real independent checker artifact, closes.
test_pass_claim_with_an_independent_checker_can_close() {
  local dir rc
  dir=$(make_case pass-supported)
  write_manifest "$dir" '    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  cat > "$dir/data/core-remediation/lanes/demo/report.md" <<'REPORT'
# Lane Report
**Author:** Worker Lane 42
Implemented the change and ran the suite.
VERDICT: PASS - all requirements completed
REPORT
  write_checker "$dir"
  rc=$(run_gate "$dir")
  expect_code 0 "$rc" "a PASS claim with an independent checker must pass the gate"
  assert_grep "closed" "$dir/out.txt" "the lane must be reported as closed"
  pass "a PASS claim with an independent checker can close the lane"
}

# Fail closed: the checker gate itself being unavailable is never a pass.
test_unavailable_checker_gate_fails_closed() {
  local dir rc
  dir=$(make_case pass-no-gate)
  write_manifest "$dir" '    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  cat > "$dir/data/core-remediation/lanes/demo/report.md" <<'REPORT'
# Lane Report
**Author:** Worker Lane 42
Implemented the change and ran the suite.
VERDICT: PASS - all requirements completed
REPORT
  write_checker "$dir"
  rc=$(run_gate "$dir" --checker-gate "$dir/there-is-no-such-gate")
  expect_code 1 "$rc" "an unavailable checker gate must fail the lane closed"
  assert_grep "checker-before-done gate is unavailable" "$dir/err.txt" "the unavailable gate must be reported"
  pass "an unavailable checker gate fails closed"
}

# RED: a visual-scoped lane whose visual gate refuses must not close.
test_visual_gate_refusal_is_a_violation() {
  local dir rc
  dir=$(make_case visual-refused)
  write_manifest "$dir" '    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  cat > "$dir/data/core-remediation/lanes/demo/report.md" <<'REPORT'
# Lane Report
**Author:** Worker Lane 42
Area: Frontend
Rebuilt the dashboard.
VERDICT: CONFIRMED - dashboard rebuilt
REPORT
  write_stub_visual_gate "$dir" 1
  rc=$(run_gate "$dir" --visual-gate "$dir/stub-visual-gate.sh")
  expect_code 1 "$rc" "a visual gate refusal must fail the lane closed"
  assert_grep "visual correctness gate refused the lane" "$dir/err.txt" "the refusal must be reported"
  pass "a visual gate refusal cannot close the lane"
}

# GREEN: the same lane closes when the visual gate passes it.
test_visual_gate_pass_lets_the_lane_close() {
  local dir rc
  dir=$(make_case visual-passed)
  write_manifest "$dir" '    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  cat > "$dir/data/core-remediation/lanes/demo/report.md" <<'REPORT'
# Lane Report
**Author:** Worker Lane 42
Area: Frontend
Rebuilt the dashboard.
VERDICT: CONFIRMED - dashboard rebuilt
REPORT
  write_stub_visual_gate "$dir" 0
  rc=$(run_gate "$dir" --visual-gate "$dir/stub-visual-gate.sh")
  expect_code 0 "$rc" "a visual gate pass must let the lane close"
  pass "a visual gate pass lets the lane close"
}

# Fail closed: a visual-scoped lane may not close while the gate is missing.
test_visual_scope_lane_without_the_visual_gate_fails_closed() {
  local dir rc
  dir=$(make_case visual-no-gate)
  write_manifest "$dir" '    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  cat > "$dir/data/core-remediation/lanes/demo/report.md" <<'REPORT'
# Lane Report
**Author:** Worker Lane 42
Area: Frontend
Rebuilt the dashboard.
VERDICT: CONFIRMED - dashboard rebuilt
REPORT
  rc=$(run_gate "$dir" --visual-gate "$dir/there-is-no-such-gate")
  expect_code 1 "$rc" "a visual-scope lane must not close while the visual gate is unavailable"
  assert_grep "visual-scope lane cannot close" "$dir/err.txt" "the unavailable gate must be reported"
  pass "a visual-scope lane fails closed when the visual gate is unavailable"
}

# Regression: a lane that does not claim PASS keeps closing the way it did.
test_non_pass_verdict_lane_still_closes() {
  local dir rc
  dir=$(make_case confirmed)
  write_manifest "$dir" '    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  printf 'VERDICT: CONFIRMED\n\nbody\n' > "$dir/data/core-remediation/lanes/demo/report.md"
  rc=$(run_gate "$dir")
  expect_code 0 "$rc" "a non-PASS verdict lane must still close"
  pass "a non-PASS verdict lane still closes"
}

# End to end with the real visual-correctness gate: a lane that claims a
# screenshot it never captured must not close. Skipped where the gate binary
# is not installed on this host.
test_real_visual_gate_refuses_a_dangling_screenshot() {
  local dir rc real_gate=""
  for candidate in "${FM_VISUAL_GATE:-}" /root/bin/check-visual-correctness "$ROOT/bin/check-visual-correctness"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      real_gate="$candidate"
      break
    fi
  done
  if [ -z "$real_gate" ]; then
    printf 'ok - real visual gate end-to-end case skipped (no gate binary on this host)\n'
    return 0
  fi
  dir=$(make_case visual-real)
  write_manifest "$dir" '    {"id": "demo", "status": "closed", "artifact": "data/core-remediation/lanes/demo/report.md", "verdict_prefix": "VERDICT:"}'
  cat > "$dir/data/core-remediation/lanes/demo/report.md" <<'REPORT'
# Lane Report
**Author:** Worker Lane 42
Area: Frontend
Rebuilt the dashboard.
![dashboard](./evidence/never-captured.png)
VERDICT: CONFIRMED - dashboard rebuilt
REPORT
  rc=$(run_gate "$dir" --visual-gate "$real_gate")
  expect_code 1 "$rc" "a lane claiming a screenshot it never captured must not close"
  pass "the real visual gate refuses a lane with a dangling screenshot"
}

test_pass_claim_without_a_checker_artifact_cannot_close
test_pass_claim_with_an_independent_checker_can_close
test_unavailable_checker_gate_fails_closed
test_visual_gate_refusal_is_a_violation
test_visual_gate_pass_lets_the_lane_close
test_visual_scope_lane_without_the_visual_gate_fails_closed
test_non_pass_verdict_lane_still_closes
test_real_visual_gate_refuses_a_dangling_screenshot
