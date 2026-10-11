#!/usr/bin/env bash
# tests/fm-context-preflight.test.sh — regression tests for fm-context-preflight.sh
#
# Properties:
#   * Pure bash + standard POSIX tools. No network calls.
#   * Self-contained: each test builds a sandbox warehouse under TMPDIR.
#   * Deterministic: uses --today to override date and avoid TZ flakiness.
#   * Tests cover: valid records, stale records, missing sources, missing
#     evidence paths, secret-bearing content, conflicting classifications,
#     schema violations, INDEX absence, and missing files.
#
# Exit codes:
#   0 all tests passed
#   non-zero a test failed (one or more cases did not match expectations)

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PREFLIGHT="${REPO_ROOT}/bin/fm-context-preflight.sh"

if [[ ! -x "${PREFLIGHT}" ]]; then
    echo "FAIL: preflight script not executable: ${PREFLIGHT}" >&2
    exit 2
fi

# -- Test harness ----------------------------------------------------------

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
declare -a FAILURE_DETAILS=()

# Each test creates a sandbox warehouse dir under TMPDIR, then asserts that
# running the preflight returns the expected exit code and (optionally) a
# substring in the output.

TEST_TMP="$(mktemp -d)"
trap 'rm -rf "${TEST_TMP}"' EXIT

# Build a sandbox repo containing a docs/system-context tree and a stub
# AGENTS.md that test cases can reference as evidence.
make_repo() {
    local label="$1"
    local repo="${TEST_TMP}/repo-${label}"
    mkdir -p "${repo}/docs/system-context"
    cat > "${repo}/AGENTS.md" <<'EOF'
# Stub AGENTS.md for fm-context-preflight.test.sh
This stub exists only to satisfy evidence_paths references in test fixtures.
EOF
    echo "${repo}"
}

# Write a minimal INDEX.md that the preflight will accept.
write_index() {
    local repo="$1"
    cat > "${repo}/docs/system-context/INDEX.md" <<'EOF'
# Test Index

## Authority and override rules
Test-only index.

## File map
Test-only map.

## Tier model
Test-only tier model.
EOF
}

# Write hosts.yaml content; $1 = file path, $@ = body lines (already formatted).
write_hosts() {
    local path="$1"; shift
    {
        echo "# Test hosts.yaml"
        echo "version: 1"
        echo "last_verified: 2026-09-15"
        echo "hosts:"
        printf '%s\n' "$@"
    } > "${path}"
}

# Run the preflight and capture stdout, stderr, exit code.
run_preflight() {
    local repo="$1"; shift
    local today="${1:-}"; shift || true
    local extra=()
    if [[ -n "${today}" ]]; then
        extra=(--today "${today}")
    fi
    local out_file="${TEST_TMP}/out.txt"
    local err_file="${TEST_TMP}/err.txt"
    "${PREFLIGHT}" --repo-root "${repo}" --quiet "${extra[@]}" >"${out_file}" 2>"${err_file}"
    local code=$?
    local out
    out="$(cat "${out_file}")"
    echo "${code}|${out}"
}

# assert_exit: $1 = label, $2 = expected code, $3 = actual code, $4 = output
assert_exit() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    local output="$4"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "${expected}" -eq "${actual}" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "  PASS  ${label} (exit=${actual})"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILURE_DETAILS+=("${label}: expected exit=${expected}, got=${actual}")
        echo "  FAIL  ${label}: expected exit=${expected}, got=${actual}" >&2
        echo "    output:" >&2
        echo "${output}" | sed 's/^/      /' >&2
    fi
}

# assert_contains: $1 = label, $2 = needle, $3 = haystack
assert_contains() {
    local label="$1"
    local needle="$2"
    local haystack="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "${haystack}" == *"${needle}"* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "  PASS  ${label}: contains \"${needle}\""
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILURE_DETAILS+=("${label}: output missing \"${needle}\"")
        echo "  FAIL  ${label}: output missing \"${needle}\"" >&2
    fi
}

# -- Case 1: PASS — valid records ------------------------------------------

case_pass_valid() {
    local repo
    repo="$(make_repo pass-valid)"
    write_index "${repo}"

    cat > "${repo}/docs/system-context/hosts.yaml" <<'EOF'
# Valid hosts.yaml
version: 1
last_verified: 2026-09-15
hosts:
  - id: alpha
    provider: local
    alias: ""
    canonical_hostname: alpha
    tailscale_ip: UNKNOWN
    public_ip: UNKNOWN
    role: Test host
    tier: LOCAL
    tenants: []
    evidence_paths:
      - AGENTS.md
    sources:
      - AGENTS.md test entry
    last_verified: 2026-09-15
    freshness_days: 30
    status: KNOWN
    notes: Test entry.
EOF

    cat > "${repo}/docs/system-context/service_catalog.yaml" <<'EOF'
# Valid service_catalog.yaml
version: 1
last_verified: 2026-09-15
services:
  - id: alpha-svc
    platform_owner: deightonllm
    tenant_or_client: alpha
    brand_or_domain: alpha.test
    current_host: alpha
    intended_host: alpha
    runtime: container
    allowed_actions:
      - read
    evidence_paths:
      - AGENTS.md
    sources:
      - AGENTS.md test entry
    last_verified: 2026-09-15
    freshness_days: 30
    status: KNOWN
    notes: Test entry.
EOF

    cat > "${repo}/docs/system-context/prd_traceability.yaml" <<'EOF'
# Valid prd_traceability.yaml
version: 1
last_verified: 2026-09-15
prd_items:
  - id: alpha-prd
    prd_section: Test PRD item
    scope: alpha
    status: EVIDENCED
    blocker: NONE
    evidence_paths:
      - AGENTS.md
    sources:
      - AGENTS.md test entry
    last_verified: 2026-09-15
    freshness_days: 30
    notes: Test entry.
EOF

    local result actual output
    result="$(run_preflight "${repo}" 2026-09-15)"
    actual="${result%%|*}"
    output="${result#*|}"
    assert_exit "case_pass_valid" 0 "${actual}" "${output}"
}

# -- Case 2: STALE — last_verified too old ---------------------------------

case_stale() {
    local repo
    repo="$(make_repo stale)"
    write_index "${repo}"

    cat > "${repo}/docs/system-context/hosts.yaml" <<'EOF'
version: 1
last_verified: 2025-01-01
hosts:
  - id: old
    provider: local
    alias: ""
    canonical_hostname: old
    tailscale_ip: UNKNOWN
    public_ip: UNKNOWN
    role: Stale test
    tier: LOCAL
    tenants: []
    evidence_paths:
      - AGENTS.md
    sources:
      - AGENTS.md test entry
    last_verified: 2025-01-01
    freshness_days: 30
    status: KNOWN
    notes: Stale record.
EOF

    # Empty other files so they are not the failing target.
    cat > "${repo}/docs/system-context/service_catalog.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
services: []
EOF
    cat > "${repo}/docs/system-context/prd_traceability.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
prd_items: []
EOF

    local result actual output
    result="$(run_preflight "${repo}" 2026-09-15)"
    actual="${result%%|*}"
    output="${result#*|}"
    assert_exit "case_stale" 4 "${actual}" "${output}"
    assert_contains "case_stale" "stale" "${output}"
}

# -- Case 3: MISSING_SOURCE — KNOWN with no sources -----------------------

case_missing_source() {
    local repo
    repo="$(make_repo missing-source)"
    write_index "${repo}"

    cat > "${repo}/docs/system-context/hosts.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
hosts:
  - id: source-missing
    provider: local
    alias: ""
    canonical_hostname: source-missing
    tailscale_ip: UNKNOWN
    public_ip: UNKNOWN
    role: Source-missing test
    tier: LOCAL
    tenants: []
    evidence_paths:
      - AGENTS.md
    sources: []
    last_verified: 2026-09-15
    freshness_days: 30
    status: KNOWN
    notes: KNOWN with no source.
EOF

    cat > "${repo}/docs/system-context/service_catalog.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
services: []
EOF
    cat > "${repo}/docs/system-context/prd_traceability.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
prd_items: []
EOF

    local result actual output
    result="$(run_preflight "${repo}" 2026-09-15)"
    actual="${result%%|*}"
    output="${result#*|}"
    assert_exit "case_missing_source" 5 "${actual}" "${output}"
}

# -- Case 4: MISSING_EVIDENCE — path does not exist on disk ----------------

case_missing_evidence() {
    local repo
    repo="$(make_repo missing-evidence)"
    write_index "${repo}"

    cat > "${repo}/docs/system-context/hosts.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
hosts:
  - id: ev-missing
    provider: local
    alias: ""
    canonical_hostname: ev-missing
    tailscale_ip: UNKNOWN
    public_ip: UNKNOWN
    role: Evidence-missing test
    tier: LOCAL
    tenants: []
    evidence_paths:
      - data/does-not-exist/file.md
    sources:
      - test source
    last_verified: 2026-09-15
    freshness_days: 30
    status: KNOWN
    notes: KNOWN with missing evidence path.
EOF

    cat > "${repo}/docs/system-context/service_catalog.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
services: []
EOF
    cat > "${repo}/docs/system-context/prd_traceability.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
prd_items: []
EOF

    local result actual output
    result="$(run_preflight "${repo}" 2026-09-15)"
    actual="${result%%|*}"
    output="${result#*|}"
    assert_exit "case_missing_evidence" 6 "${actual}" "${output}"
    assert_contains "case_missing_evidence" "does-not-exist" "${output}"
}

# -- Case 5: SECRET — secret-like pattern in a record ---------------------

case_secret() {
    local repo
    repo="$(make_repo secret)"
    write_index "${repo}"

    cat > "${repo}/docs/system-context/hosts.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
hosts:
  - id: leaky
    provider: local
    alias: ""
    canonical_hostname: leaky
    tailscale_ip: UNKNOWN
    public_ip: UNKNOWN
    role: Secret leak test
    tier: LOCAL
    tenants: []
    evidence_paths:
      - AGENTS.md
    sources:
      - test source
    last_verified: 2026-09-15
    freshness_days: 30
    status: KNOWN
    notes: bearer placeholderaaaaaaaaaaaaaaaaaaaaaaaaaa
EOF

    cat > "${repo}/docs/system-context/service_catalog.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
services: []
EOF
    cat > "${repo}/docs/system-context/prd_traceability.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
prd_items: []
EOF

    local result actual output
    result="$(run_preflight "${repo}" 2026-09-15)"
    actual="${result%%|*}"
    output="${result#*|}"
    assert_exit "case_secret" 7 "${actual}" "${output}"
    assert_contains "case_secret" "secret-like pattern matched" "${output}"
}

# -- Case 6: CONTRADICTION — KNOWN status, no evidence --------------------

case_contradiction() {
    local repo
    repo="$(make_repo contradiction)"
    write_index "${repo}"

    cat > "${repo}/docs/system-context/hosts.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
hosts:
  - id: claimy
    provider: local
    alias: ""
    canonical_hostname: claimy
    tailscale_ip: UNKNOWN
    public_ip: UNKNOWN
    role: Contradiction test
    tier: LOCAL
    tenants: []
    evidence_paths: []
    sources:
      - test source
    last_verified: 2026-09-15
    freshness_days: 30
    status: KNOWN
    notes: KNOWN status without evidence path.
EOF

    cat > "${repo}/docs/system-context/service_catalog.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
services: []
EOF
    cat > "${repo}/docs/system-context/prd_traceability.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
prd_items: []
EOF

    local result actual output
    result="$(run_preflight "${repo}" 2026-09-15)"
    actual="${result%%|*}"
    output="${result#*|}"
    assert_exit "case_contradiction" 8 "${actual}" "${output}"
}

# -- Case 7: SCHEMA — invalid status ---------------------------------------

case_schema() {
    local repo
    repo="$(make_repo schema)"
    write_index "${repo}"

    cat > "${repo}/docs/system-context/hosts.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
hosts:
  - id: bad-status
    provider: local
    alias: ""
    canonical_hostname: bad-status
    tailscale_ip: UNKNOWN
    public_ip: UNKNOWN
    role: Schema test
    tier: LOCAL
    tenants: []
    evidence_paths:
      - AGENTS.md
    sources:
      - test source
    last_verified: 2026-09-15
    freshness_days: 30
    status: MAYBE
    notes: Invalid status value.
EOF

    cat > "${repo}/docs/system-context/service_catalog.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
services: []
EOF
    cat > "${repo}/docs/system-context/prd_traceability.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
prd_items: []
EOF

    local result actual output
    result="$(run_preflight "${repo}" 2026-09-15)"
    actual="${result%%|*}"
    output="${result#*|}"
    assert_exit "case_schema" 3 "${actual}" "${output}"
}

# -- Case 8: INDEX missing --------------------------------------------------

case_index_missing() {
    local repo
    repo="$(make_repo index-missing)"
    # Intentionally do NOT write INDEX.md.
    mkdir -p "${repo}/docs/system-context"

    cat > "${repo}/docs/system-context/hosts.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
hosts: []
EOF
    cat > "${repo}/docs/system-context/service_catalog.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
services: []
EOF
    cat > "${repo}/docs/system-context/prd_traceability.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
prd_items: []
EOF

    local result actual output
    result="$(run_preflight "${repo}" 2026-09-15)"
    actual="${result%%|*}"
    output="${result#*|}"
    assert_exit "case_index_missing" 9 "${actual}" "${output}"
}

# -- Case 9: MISSING_FILE — required YAML absent --------------------------

case_missing_file() {
    local repo
    repo="$(make_repo missing-file)"
    write_index "${repo}"

    # Only create one of the three required YAML files.
    cat > "${repo}/docs/system-context/hosts.yaml" <<'EOF'
version: 1
last_verified: 2026-09-15
hosts: []
EOF

    local result actual output
    result="$(run_preflight "${repo}" 2026-09-15)"
    actual="${result%%|*}"
    output="${result#*|}"
    assert_exit "case_missing_file" 2 "${actual}" "${output}"
}

# -- Case 10: PASS against the canonical warehouse --------------------------

case_canonical_warehouse() {
    local result actual output
    result="$(run_preflight "${REPO_ROOT}" 2026-09-15)"
    actual="${result%%|*}"
    output="${result#*|}"
    assert_exit "case_canonical_warehouse" 0 "${actual}" "${output}"
}

# -- Main -----------------------------------------------------------------

echo "Running fm-context-preflight regression tests..."
echo

case_pass_valid
case_stale
case_missing_source
case_missing_evidence
case_secret
case_contradiction
case_schema
case_index_missing
case_missing_file
case_canonical_warehouse

echo
echo "Tests run: ${TESTS_RUN}"
echo "Tests passed: ${TESTS_PASSED}"
echo "Tests failed: ${TESTS_FAILED}"

if [[ "${TESTS_FAILED}" -gt 0 ]]; then
    echo
    echo "Failure details:"
    for f in "${FAILURE_DETAILS[@]}"; do
        echo "  ${f}"
    done
    exit 1
fi

echo "ALL TESTS PASSED"
exit 0
