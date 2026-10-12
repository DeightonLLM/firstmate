#!/usr/bin/env bash
# Behavior tests for bin/fm-coord-drift-check.sh.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-coord-drift-check)
mkdir -p "$TMP_ROOT"

test_canonical_coordinates_pass() {
  local out_file rc=0
  out_file="$TMP_ROOT/canonical_pass.out"
  "$ROOT/bin/fm-coord-drift-check.sh" > "$out_file" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || fail "canonical coordinates failed with exit code $rc: $(cat "$out_file")"
  assert_grep "COORD OK: core-distro.com -> 66.29.153.174" "$out_file" "core-distro.com COORD OK missing"
  assert_grep "COORD OK: data.core-distro.com -> 66.29.153.174" "$out_file" "data.core-distro.com COORD OK missing"
  assert_grep "COORD OK: agents.core-distro.com -> 161.97.120.4" "$out_file" "agents.core-distro.com COORD OK missing"
  assert_grep "PASS: all checked coordinates verified" "$out_file" "PASS summary missing"
  pass "fm-coord-drift-check.sh: canonical core-distro coordinates pass"
}

test_coordinate_drift_fails_loudly() {
  local out_file rc=0
  out_file="$TMP_ROOT/drift_fail.out"
  "$ROOT/bin/fm-coord-drift-check.sh" "core-distro.com" "192.0.2.99" > "$out_file" 2>&1 || rc=$?
  [ "$rc" -eq 1 ] || fail "expected exit 1 on drift, got $rc: $(cat "$out_file")"
  assert_grep "COORD DRIFT: recorded 192.0.2.99, live 66.29.153.174" "$out_file" "drift report missing or incorrect"
  assert_grep "FAIL: 1 coordinate(s) drifted or unresolvable" "$out_file" "failure summary missing"
  pass "fm-coord-drift-check.sh: drift detection fails loudly with recorded and live IP"
}

test_unresolvable_host_treated_as_unknown() {
  local out_file rc=0
  out_file="$TMP_ROOT/unknown_fail.out"
  "$ROOT/bin/fm-coord-drift-check.sh" "unresolvable-test.core-distro-fake.invalid" "66.29.153.174" > "$out_file" 2>&1 || rc=$?
  [ "$rc" -eq 1 ] || fail "expected exit 1 on unresolvable host, got $rc: $(cat "$out_file")"
  assert_grep "COORD UNKNOWN: host unresolvable-test.core-distro-fake.invalid" "$out_file" "unknown host report missing"
  pass "fm-coord-drift-check.sh: unresolvable host reported as COORD UNKNOWN and fails"
}

test_file_input_verifies_coordinates() {
  local coord_file out_file rc=0
  coord_file="$TMP_ROOT/coords.tsv"
  out_file="$TMP_ROOT/file_pass.out"
  cat > "$coord_file" <<'EOF'
# Test coordinates
core-distro.com 66.29.153.174
data.core-distro.com 66.29.153.174
EOF
  "$ROOT/bin/fm-coord-drift-check.sh" --file "$coord_file" > "$out_file" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || fail "file input failed with exit code $rc: $(cat "$out_file")"
  assert_grep "COORD OK: core-distro.com -> 66.29.153.174" "$out_file" "file host 1 failed"
  assert_grep "COORD OK: data.core-distro.com -> 66.29.153.174" "$out_file" "file host 2 failed"
  pass "fm-coord-drift-check.sh: file input verified"
}

test_canonical_coordinates_pass
test_coordinate_drift_fails_loudly
test_unresolvable_host_treated_as_unknown
test_file_input_verifies_coordinates
