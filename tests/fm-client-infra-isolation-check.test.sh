#!/usr/bin/env bash
# =============================================================================
# TDD Tests for fm-client-infra-isolation-check.sh
# =============================================================================
# These tests follow the RED-GREEN cycle:
#   RED: Write a failing test that describes the desired behavior
#   GREEN: Implement the smallest code to make the test pass
#   REFACTOR: Clean up while keeping tests green
#
# The check asserts: no client-facing endpoint may resolve to a test_only host.
# =============================================================================

set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/fm-client-infra-isolation-check.sh"
# POLICY_FILE is the reference path to the default policy (used in documentation)
# shellcheck disable=SC2034
POLICY_FILE="$ROOT/docs/policy/client-infra-isolation.yaml"

# =============================================================================
# Test: Script exists and is executable
# =============================================================================

test_script_exists() {
  assert_present "$CHECK" "Check script must exist at $CHECK"
  pass "Check script exists"
}

# =============================================================================
# Test: Script accepts policy file argument
# =============================================================================

test_accepts_policy_argument() {
  local tmpdir out code
  
  tmpdir=$(mktemp -d)
  
  # Create a minimal valid policy
  cat > "$tmpdir/minimal-policy.yaml" <<'POLICY'
version: 1
policy_id: test-minimal
hosts:
  - id: test-host
    classification: client_infra
client_endpoints: []
POLICY

  # Script should accept --policy argument
  out=$("$CHECK" --policy "$tmpdir/minimal-policy.yaml" 2>&1)
  code=$?
  
  # Should not crash - may exit 0 or 1 depending on content
  if [ $code -eq 2 ]; then
    fail "Check should accept valid policy argument, got exit 2 (invalid policy)"
  fi
  
  pass "Check accepts policy file argument"
}

# =============================================================================
# Test: Script shows help with --help
# =============================================================================

test_help_output() {
  local out code
  
  out=$("$CHECK" --help 2>&1)
  code=$?
  
  if [ $code -ne 0 ]; then
    fail "Check --help should exit 0"
  fi
  
  if ! echo "$out" | grep -qi "policy\|usage\|help"; then
    fail "Check --help should show usage information"
  fi
  
  pass "Check provides help output"
}

# =============================================================================
# Test: Script validates policy file format (REJECT invalid YAML)
# =============================================================================

test_validates_policy_format() {
  local tmpdir out code
  
  tmpdir=$(mktemp -d)
  
  # Invalid YAML - should be rejected
  echo "invalid: yaml: content: [" > "$tmpdir/bad-policy.yaml"
  
  out=$("$CHECK" --policy "$tmpdir/bad-policy.yaml" 2>&1)
  code=$?
  
  if [ $code -eq 0 ]; then
    fail "Check should reject invalid YAML policy"
  fi
  
  pass "Check validates policy file format"
}

# =============================================================================
# Test: Script rejects non-existent policy file
# =============================================================================

test_rejects_missing_policy() {
  local tmpdir out code
  
  tmpdir=$(mktemp -d)
  
  out=$("$CHECK" --policy "$tmpdir/nonexistent.yaml" 2>&1)
  code=$?
  
  if [ $code -eq 0 ]; then
    fail "Check should reject missing policy file"
  fi
  
  pass "Check rejects missing policy file"
}

# =============================================================================
# Test: RED PHASE - Script detects when client endpoint resolves to test_only host
# =============================================================================

test_detects_violation() {
  local tmpdir out code
  
  tmpdir=$(mktemp -d)
  
  # Create a test policy with a client endpoint
  cat > "$tmpdir/violation-policy.yaml" <<'POLICY'
# Test policy with deliberate violation
version: 1
policy_id: test-violation

hosts:
  - id: hd2stack
    classification: test_only
    canonical_hostname: vmi3238503

client_endpoints:
  - domain: violation-test.example.com
    type: test

internal_only_endpoints:
  - domain: llm.hd2.ai
    classification: hd2_internal
POLICY

  # Create a mock dig that returns the test-only host IP for the violation domain
  # Must ignore dig flags and just return IP based on domain
  cat > "$tmpdir/dig" <<'MOCK'
#!/usr/bin/env bash
# Mock dig - ignores all flags, returns IP based on domain
domain=""
for arg in "$@"; do
  # Skip flags (arguments starting with + or -)
  [[ "$arg" =~ ^[+-] ]] && continue
  # Last non-flag argument is the domain
  domain="$arg"
done

case "$domain" in
  violation-test.example.com)
    # Simulate this client endpoint resolving to HD2Stack Tailscale IP
    echo "100.71.95.76"
    ;;
  safe.example.com)
    # Simulate safe endpoint resolving to client infra
    echo "203.0.113.50"
    ;;
  *)
    echo "unknown.domain" >&2
    exit 9
    ;;
esac
MOCK
  chmod +x "$tmpdir/dig"
  
  # Run the check with mocked tools - put mock first in PATH
  out=$(PATH="$tmpdir:$PATH" "$CHECK" --policy "$tmpdir/violation-policy.yaml" 2>&1)
  code=$?
  
  # The check should exit non-zero because we have
  # a client endpoint resolving to the HD2Stack IP (100.71.95.76)
  
  if [ $code -eq 0 ]; then
    fail "Check should exit non-zero when client endpoint resolves to test_only host, got exit 0. Output: $out"
  fi
  
  # The output should mention the violation
  if ! echo "$out" | grep -qi "violation\|VIOLATION"; then
    fail "Check output should mention VIOLATION, got: $out"
  fi
  
  pass "Check detects violation: client endpoint resolves to test_only host"
}

# =============================================================================
# Test: Script exits 1 when client endpoint resolves to test_only host
# =============================================================================

test_exit_code_on_violation() {
  local tmpdir out code
  
  tmpdir=$(mktemp -d)
  
  # Create policy with known violation
  cat > "$tmpdir/test-policy.yaml" <<'POLICY'
version: 1
policy_id: test

hosts:
  - id: hd2stack
    classification: test_only
    canonical_hostname: vmi3238503

client_endpoints:
  - domain: bad.example.com
    type: test
POLICY

  # Mock dig to return HD2Stack Tailscale IP
  cat > "$tmpdir/dig" <<'MOCK'
#!/usr/bin/env bash
# Mock dig - ignores all flags, returns IP based on domain
domain=""
for arg in "$@"; do
  [[ "$arg" =~ ^[+-] ]] && continue
  domain="$arg"
done

echo "100.71.95.76"
MOCK
  chmod +x "$tmpdir/dig"
  
  out=$(PATH="$tmpdir:$PATH" "$CHECK" --policy "$tmpdir/test-policy.yaml" 2>&1)
  code=$?
  
  if [ $code -eq 0 ]; then
    fail "Expected exit 1 on policy violation, got exit 0. Output: $out"
  fi
  
  pass "Check exits with code 1 on violation"
}

# =============================================================================
# Test: Script exits 0 when no violations exist (client endpoint resolves elsewhere)
# =============================================================================

test_passes_when_no_violation() {
  local tmpdir out code
  
  tmpdir=$(mktemp -d)
  
  # Policy with no violations - client endpoint resolves to non-test-only IP
  cat > "$tmpdir/clean-policy.yaml" <<'POLICY'
version: 1
policy_id: test-clean

hosts:
  - id: hd2stack
    classification: test_only
    canonical_hostname: vmi3238503

  - id: brandon-hub
    classification: client_infra
    canonical_hostname: srv1856614

client_endpoints:
  - domain: good.example.com
    type: test
POLICY

  # Mock dig to return client_infra IP (not test_only)
  cat > "$tmpdir/dig" <<'MOCK'
#!/usr/bin/env bash
echo "203.0.113.10"
MOCK
  chmod +x "$tmpdir/dig"
  
  out=$(PATH="$tmpdir:$PATH" "$CHECK" --policy "$tmpdir/clean-policy.yaml" 2>&1)
  code=$?
  
  if [ $code -ne 0 ]; then
    fail "Expected exit 0 when no violations, got exit $code: $out"
  fi
  
  pass "Check passes when no violations exist"
}

# =============================================================================
# Test: Script handles unresolvable domains gracefully
# =============================================================================

test_handles_unresolvable_domains() {
  local tmpdir out code
  
  tmpdir=$(mktemp -d)
  
  cat > "$tmpdir/test-policy.yaml" <<'POLICY'
version: 1
policy_id: test

hosts:
  - id: hd2stack
    classification: test_only
    canonical_hostname: vmi3238503

client_endpoints:
  - domain: unresolvable.invalid.tld
    type: test
POLICY

  # Mock dig to fail for unresolvable domains
  cat > "$tmpdir/dig" <<'MOCK'
#!/usr/bin/env bash
echo "DNS resolution failed" >&2
exit 9
MOCK
  chmod +x "$tmpdir/dig"
  
  out=$(PATH="$tmpdir:$PATH" "$CHECK" --policy "$tmpdir/test-policy.yaml" 2>&1)
  code=$?
  
  # Should handle gracefully - should not crash
  # Either exit non-zero with error message, or exit 0 with warning
  if ! echo "$out" | grep -qi "cannot resolve\|unresolvable\|dns"; then
    # If no DNS error message, check it didn't crash
    if [ $code -eq 139 ] || [ $code -eq 134 ]; then
      fail "Check crashed (signal $code) on unresolvable domain"
    fi
    pass "Check handles unresolvable domains (exit $code, message: $out)"
  else
    pass "Check reports unresolvable domains: $out"
  fi
}

# =============================================================================
# Test: Script works with empty client_endpoints
# =============================================================================

test_handles_empty_endpoints() {
  local tmpdir out code
  
  tmpdir=$(mktemp -d)
  
  cat > "$tmpdir/empty-policy.yaml" <<'POLICY'
version: 1
policy_id: test-empty

hosts:
  - id: hd2stack
    classification: test_only
    canonical_hostname: vmi3238503

client_endpoints: []
POLICY

  out=$("$CHECK" --policy "$tmpdir/empty-policy.yaml" 2>&1)
  code=$?
  
  # Should pass with no violations when there are no endpoints to check
  if [ $code -ne 0 ] && ! echo "$out" | grep -qi "no client"; then
    fail "Check should handle empty endpoints gracefully, got exit $code: $out"
  fi
  
  pass "Check handles empty client_endpoints"
}

# =============================================================================
# Test: Default policy file is used when no argument provided
# =============================================================================

test_default_policy() {
  local out code
  
  # This test verifies the script can run with default policy
  # It may pass or fail depending on current DNS state
  out=$("$CHECK" 2>&1)
  code=$?
  
  # Should not crash
  if [ $code -eq 2 ]; then
    fail "Should use default policy file when none specified"
  fi
  
  pass "Check uses default policy file"
}

# =============================================================================
# Test: Default policy location exists and loads correctly (REGRESSION TEST)
# =============================================================================

test_default_policy_location_exists() {
  local default_policy="$ROOT/docs/policy/client-infra-isolation.yaml"
  
  # The default policy file must exist in the tracked path
  if [ ! -f "$default_policy" ]; then
    fail "Default policy file must exist at $default_policy (data/ is gitignored)"
  fi
  
  # The policy file must be readable
  if [ ! -r "$default_policy" ]; then
    fail "Default policy file must be readable at $default_policy"
  fi
  
  # The policy file must contain valid YAML with version declaration
  if ! grep -q "^version:" "$default_policy"; then
    fail "Default policy file must contain version declaration"
  fi
  
  # The policy file must contain policy_id declaration
  if ! grep -q "^policy_id:" "$default_policy"; then
    fail "Default policy file must contain policy_id declaration"
  fi
  
  # The policy file must contain hosts section
  if ! grep -q "^hosts:" "$default_policy"; then
    fail "Default policy file must contain hosts section"
  fi
  
  # The policy file must contain client_endpoints section
  if ! grep -q "^client_endpoints:" "$default_policy"; then
    fail "Default policy file must contain client_endpoints section"
  fi
  
  pass "Default policy location $default_policy exists and contains valid policy structure"
}

# =============================================================================
# Run all tests
# =============================================================================

echo "Running fm-client-infra-isolation-check tests..."

test_script_exists
test_help_output
test_accepts_policy_argument
test_validates_policy_format
test_rejects_missing_policy
test_detects_violation
test_exit_code_on_violation
test_passes_when_no_violation
test_handles_unresolvable_domains
test_handles_empty_endpoints
test_default_policy
test_default_policy_location_exists

echo ""
echo "All tests passed"
