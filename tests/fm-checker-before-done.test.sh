#!/usr/bin/env bash
# fm-checker-before-done.test.sh — Test Suite for Independent Review Gate (Ticket 0007)
#
# The suite drives the real gate binary at bin/fm-checker-before-done.sh through
# its published interface. The path below is the whole point of this suite:
# when it pointed at tests/ instead of bin/, every assertion failed with exit 127
# and the mechanism was never exercised at all. The suite now refuses to run
# against a gate that is not there, so that class of defect cannot hide again.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SCRIPT="${SCRIPT_DIR}/../bin/fm-checker-before-done.sh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

LAST_OUT=""
LAST_RC=0

pass() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  [PASS] %s\n' "$1"
}

fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  [FAIL] %s\n' "$1" >&2
}

# run_gate <args...>: run the gate and capture its output and exit code.
# LAST_RC is always the exit code of THIS invocation. The earlier suite kept a
# single `rc` variable across assertions and only ever assigned it on failure,
# so an earlier failing assertion poisoned every later success assertion.
run_gate() {
  local rc=0
  LAST_OUT=$(bash "$GATE_SCRIPT" "$@" 2>&1) || rc=$?
  LAST_RC=$rc
}

TMP_DIR=$(mktemp -d "/tmp/fm-checker-test-XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT

printf '=== Running Independent Review Gate Test Suite (Ticket 0007) ===\n'
printf '    gate under test: %s\n' "$GATE_SCRIPT"

# --- Test 0: The gate binary the suite claims to exercise must exist ---------
# A suite that points at the wrong path must fail loudly, not report a wall of
# exit-127 failures that look like a broken gate.
if [[ -f "$GATE_SCRIPT" ]] && [[ -r "$GATE_SCRIPT" ]]; then
  pass "Gate binary exists and is readable at bin/fm-checker-before-done.sh"
else
  fail "Gate binary missing or unreadable: $GATE_SCRIPT"
  printf '==================================================\n'
  printf 'Total assertions: %d | Passed: %d | Failed: %d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
  printf '==================================================\n'
  printf 'VERDICT: TESTS FAILED (gate binary not exercised)\n' >&2
  exit 1
fi

# --- Test 1: Missing Worker Report ---
run_gate "$TMP_DIR/nonexistent.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "Worker report does not exist" <<< "$LAST_OUT"; then
  pass "Non-existent worker report is rejected (exit 1)"
else
  fail "Non-existent worker report should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 2: Worker Report Too Small (< 100 bytes) ---
printf '# Stub report\nVERDICT: PASS\n' > "$TMP_DIR/stub_worker.md"
run_gate "$TMP_DIR/stub_worker.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "empty placeholder" <<< "$LAST_OUT"; then
  pass "Placeholder worker report (< 100 bytes) is rejected (exit 1)"
else
  fail "Placeholder worker report should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 3: Worker Report Lacks Verdict ---
cat <<'EOF' > "$TMP_DIR/no_verdict_worker.md"
# Full Worker Implementation Report
**Author:** Worker Lane A
This report contains lots of text explaining what the worker did over several turns.
The feature was supposedly built and tests were run, but there is no formal closing line.
EOF
run_gate "$TMP_DIR/no_verdict_worker.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q 'lacks mandatory "VERDICT:"' <<< "$LAST_OUT"; then
  pass "Worker report lacking VERDICT declaration is rejected (exit 1)"
else
  fail "Worker report lacking VERDICT should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 4: Worker Report Has Failing Verdict ---
cat <<'EOF' > "$TMP_DIR/failing_worker.md"
# Worker Failure Report
**Author:** Worker Lane A
The worker attempted to implement the feature but encountered an unrecoverable dependency error.
Several libraries were missing and compilation failed.
VERDICT: FAIL — Compilation error in core module
EOF
run_gate "$TMP_DIR/failing_worker.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "Worker verdict is not PASS/DONE" <<< "$LAST_OUT"; then
  pass "Worker report with VERDICT: FAIL is rejected for promotion (exit 1)"
else
  fail "Worker report with FAIL should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 5: Unsupported Worker PASS (No Checker Report) ---
cat <<'EOF' > "$TMP_DIR/worker_valid.md"
# Valid Worker Report
**Author:** Worker Lane 101
The worker has successfully executed Ticket 0045, running all unit tests.
All modifications were made within declared workspace boundaries.
VERDICT: PASS — All requirements completed
EOF
run_gate "$TMP_DIR/worker_valid.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "unsupported self-attestation" <<< "$LAST_OUT"; then
  pass "Unsupported worker PASS without checker report is rejected (exit 1)"
else
  fail "Unsupported worker PASS without checker report should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 6: Self-Certification Rejected (Checker is Same File) ---
run_gate "$TMP_DIR/worker_valid.md" "$TMP_DIR/worker_valid.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "Self-certification is strictly forbidden" <<< "$LAST_OUT"; then
  pass "Self-certification (identical file for worker and checker) is rejected (exit 1)"
else
  fail "Self-certification should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 7: Reviewer Author Matches Worker Author ---
cat <<'EOF' > "$TMP_DIR/worker_author.md"
# Worker Report
**Author:** Subagent-Alpha-42
Implemented feature X and ran test suite. Everything looks green.
VERDICT: PASS — Completed
EOF
cat <<'EOF' > "$TMP_DIR/checker_same_author.md"
# Checker Report
**Reviewer:** Subagent-Alpha-42
I reviewed my own code and ran curl exit 0 tests passing 10/10.
VERDICT: CHECK_PASS — Self review passed
EOF
run_gate "$TMP_DIR/worker_author.md" "$TMP_DIR/checker_same_author.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "matches worker author" <<< "$LAST_OUT"; then
  pass "Checker with matching author identity is rejected (exit 1)"
else
  fail "Checker with matching author should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 8: Checker Report is Placeholder (< 100 bytes) ---
printf '# Checker\nVERDICT: CHECK_PASS\n' > "$TMP_DIR/checker_stub.md"
run_gate "$TMP_DIR/worker_valid.md" "$TMP_DIR/checker_stub.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "empty placeholder" <<< "$LAST_OUT"; then
  pass "Placeholder checker report (< 100 bytes) is rejected (exit 1)"
else
  fail "Placeholder checker report should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 9: Checker Issues REVISION_REQUIRED ---
cat <<'EOF' > "$TMP_DIR/checker_revision.md"
# Independent Verification Audit
**Reviewer:** Independent Auditor GLM-5.3
Inspected worker deliverable in workspace. Found 2 failing assertions in test suite.
Exit code 1 returned by test harness.
VERDICT: REVISION_REQUIRED — Tests 4 and 7 failed on edge case inputs
EOF
run_gate "$TMP_DIR/worker_valid.md" "$TMP_DIR/checker_revision.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "rejected worker claim" <<< "$LAST_OUT"; then
  pass "Checker issuing REVISION_REQUIRED rejects promotion (exit 1)"
else
  fail "Checker REVISION_REQUIRED should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 10: Checker Issues CHECK_FAIL ---
cat <<'EOF' > "$TMP_DIR/checker_fail.md"
# Independent Verification Audit
**Reviewer:** Independent Auditor MiniMax-M3.1
Tested target service on live port. Service returned HTTP 500 internal server error.
VERDICT: CHECK_FAIL — Target endpoint down
EOF
run_gate "$TMP_DIR/worker_valid.md" "$TMP_DIR/checker_fail.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "rejected worker claim" <<< "$LAST_OUT"; then
  pass "Checker issuing CHECK_FAIL rejects promotion (exit 1)"
else
  fail "Checker CHECK_FAIL should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 11: Checker Has No Measurement Evidence (Unsupported Prose) ---
cat <<'EOF' > "$TMP_DIR/checker_no_evidence.md"
# Independent Review Report
**Reviewer:** Independent Auditor Beta
I looked at the code and it looks totally fine to me. The styling is nice and
the implementation seems very reasonable. I think we can go ahead and accept it.
VERDICT: CHECK_PASS — Looks good to me
EOF
run_gate "$TMP_DIR/worker_valid.md" "$TMP_DIR/checker_no_evidence.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "contains only unsupported prose without command/measurement evidence" <<< "$LAST_OUT"; then
  pass "Checker with unsupported prose (no measurement evidence) is rejected (exit 1)"
else
  fail "Checker lacking measurement evidence should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 12: Valid Independent Checker With Evidence Promotes to VERIFIED ---
cat <<'EOF' > "$TMP_DIR/checker_valid.md"
# Independent Audit & Verification Report
**Reviewer:** Independent Checker GLM-5.3 (Lane w2M:p3)
Independently checked worker changes against live system and unit suite:
- Ran automated test suite: exit code 0, 16/16 tests passing.
- Verified live service endpoint: HTTP/2 200, latency 42ms.
- SHA-256 artifact checksum matched baseline.
VERDICT: CHECK_PASS — All 16 assertions verified independently
EOF
run_gate "$TMP_DIR/worker_valid.md" "$TMP_DIR/checker_valid.md"
if [[ "$LAST_RC" -eq 0 ]] && grep -q "PROMOTED TO VERIFIED" <<< "$LAST_OUT"; then
  pass "Valid independent checker with CHECK_PASS promotes to VERIFIED (exit 0)"
else
  fail "Valid independent review should exit 0 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 13: Automatic Sibling Checker Discovery ---
cat <<'EOF' > "$TMP_DIR/task-0099.md"
# Worker Deliverable 0099
**Author:** Worker Gamma
Finished task 0099 with all files committed.
VERDICT: PASS — Ready for audit
EOF
cat <<'EOF' > "$TMP_DIR/task-0099.checker.md"
# Independent Audit for Task 0099
**Reviewer:** Auditor Delta
Ran independent verification: exit code 0, 5/5 assertions verified.
VERDICT: CHECK_PASS — Verified clean
EOF
run_gate "$TMP_DIR/task-0099.md"
if [[ "$LAST_RC" -eq 0 ]] && grep -q "PROMOTED TO VERIFIED" <<< "$LAST_OUT"; then
  pass "Automatic sibling checker discovery (<report>.checker.md) promotes to VERIFIED (exit 0)"
else
  fail "Automatic sibling discovery should exit 0 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 14: Python Hygiene Check ---
# The pattern below is deliberately the only occurrence of it in this file. The
# assertion messages must not spell it out, or the suite matches its own prose
# and reports a violation that does not exist.
if grep -q 'python3[[:space:]]*-c' "$GATE_SCRIPT" "$0"; then
  fail "Scripts must contain zero inline Python one-liner invocations"
else
  pass "Zero inline Python one-liner invocations in gate script and test suite"
fi

# --- Test 15: Checker With No Exit Code Is Refused ---
# A checker artifact that shows a measurement but never records the exit code of
# a check is still a claim, not evidence. It must not promote a worker PASS.
cat <<'EOF' > "$TMP_DIR/checker_no_exit_code.md"
# Independent Review Report
**Reviewer:** Independent Auditor Gamma
I ran the suite and it reported 12/12 tests passing, so everything is fine.
VERDICT: CHECK_PASS — Looks good to me
EOF
run_gate "$TMP_DIR/worker_valid.md" "$TMP_DIR/checker_no_exit_code.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "records no verifiable exit code" <<< "$LAST_OUT"; then
  pass "Checker artifact with no recorded exit code is rejected (exit 1)"
else
  fail "Checker artifact with no exit code should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 16: Checker With An Exit Code But No Re-runnable Command Is Refused ---
# Recording "exit code 0" without the command that produced it is a number, not
# a re-runnable check. It must not promote a worker PASS.
cat <<'EOF' > "$TMP_DIR/checker_exit_code_only.md"
# Independent Review Report
**Reviewer:** Independent Auditor Delta
Everything is green. Exit code 0. Trust me, the work is complete and correct.
VERDICT: CHECK_PASS — All good
EOF
run_gate "$TMP_DIR/worker_valid.md" "$TMP_DIR/checker_exit_code_only.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "no re-runnable command or measurement" <<< "$LAST_OUT"; then
  pass "Checker artifact with an exit code but no re-runnable command is rejected (exit 1)"
else
  fail "Checker artifact with an exit code but no command should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 17: Checker With No Reviewer Identity Is Refused ---
# An artifact that names nobody cannot be shown to be independent.
cat <<'EOF' > "$TMP_DIR/checker_no_identity.md"
# Independent Review Report
I ran the suite:
    $ bash tests/fm-example.test.sh
    exit code 0, 3/3 assertions passed
VERDICT: CHECK_PASS — Verified
EOF
run_gate "$TMP_DIR/worker_valid.md" "$TMP_DIR/checker_no_identity.md"
if [[ "$LAST_RC" -eq 1 ]] && grep -q "declares no reviewer identity" <<< "$LAST_OUT"; then
  pass "Checker artifact with no reviewer identity is rejected (exit 1)"
else
  fail "Checker artifact with no reviewer identity should exit 1 (got rc=$LAST_RC: $LAST_OUT)"
fi

# --- Test 18: A Real Re-runnable Check Is Accepted (GREEN) ---
# The honest counterpart of tests 15-17: a checker artifact that records the
# real command, its real exit code, and its real output is accepted.
cat <<'EOF' > "$TMP_DIR/checker_rerunnable.md"
# Independent Review Report
**Reviewer:** Independent Auditor Epsilon (Lane w2M:p9)
Reproduced the worker's claim from a clean checkout:
    $ bash tests/fm-example.test.sh
    14/14 assertions passed
    exit code 0
VERDICT: CHECK_PASS — The independent re-run reproduced the claim
EOF
run_gate "$TMP_DIR/worker_valid.md" "$TMP_DIR/checker_rerunnable.md"
if [[ "$LAST_RC" -eq 0 ]] && grep -q "PROMOTED TO VERIFIED" <<< "$LAST_OUT"; then
  pass "Checker artifact with a real re-runnable check is accepted (exit 0)"
else
  fail "Checker artifact with a real re-runnable check should exit 0 (got rc=$LAST_RC: $LAST_OUT)"
fi

printf '==================================================\n'
printf 'Total assertions: %d | Passed: %d | Failed: %d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf '==================================================\n'

if [[ "$TESTS_FAILED" -eq 0 ]]; then
  printf 'VERDICT: ALL ASSERTIONS PASSED (%d/%d)\n' "$TESTS_PASSED" "$TESTS_RUN"
  exit 0
else
  printf 'VERDICT: TESTS FAILED (%d failed)\n' "$TESTS_FAILED" >&2
  exit 1
fi
