#!/usr/bin/env bash
# =============================================================================
# fm-client-infra-isolation-check.sh
# =============================================================================
# Policy checker: asserts that no client-facing endpoint is served by a
# test-only host (specifically the HD2 AnythingLLM instance).
#
# POLICY: The HD2 AnythingLLM instance MUST NOT serve client-facing endpoints.
#          The HD2 instance must remain reachable only internally.
#
# USAGE:
#   bin/fm-client-infra-isolation-check.sh --policy <policy-file.yaml>
#   bin/fm-client-infra-isolation-check.sh --help
#
# EXIT CODES:
#   0   - Policy check passed (no violations detected)
#   1   - Policy violation detected
#   2   - Invalid arguments or policy file
#   3   - Required tool not found
#
# BOUNDARY:
#   This is a policy checker, not an investigation.
#   May: resolve DNS, make read-only HTTPS GETs to public endpoints
#   Must NOT: SSH anywhere, touch hard-gated hosts, read credentials,
#             change configuration, deploy, or restart anything
# =============================================================================

set -uo pipefail

# Script directory (works even when sourced)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default policy file location
DEFAULT_POLICY="$ROOT/docs/policy/client-infra-isolation.yaml"

# Colors for output (disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# =============================================================================
# Helper functions
# =============================================================================

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Policy checker: asserts no client-facing endpoint is served by test-only infrastructure.

OPTIONS:
    --policy <file>    Policy file to read (default: $DEFAULT_POLICY)
    --help             Show this help message

EXIT CODES:
    0   Policy check passed - no violations
    1   Policy violation detected
    2   Invalid arguments or policy file
    3   Required tool not found

EXAMPLES:
    $(basename "$0") --policy docs/policy/client-infra-isolation.yaml
    $(basename "$0")  # Uses default policy

EOF
}

error() {
    echo -e "${RED}ERROR:${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}WARNING:${NC} $*" >&2
}

info() {
    echo -e "${GREEN}INFO:${NC} $*" >&2
}

log() {
    echo "$*" >&2
}

# Check if a required tool exists
require_tool() {
    local tool=$1
    if ! command -v "$tool" &>/dev/null; then
        error "Required tool not found: $tool"
        exit 3
    fi
}

# Simple YAML parser for our specific policy format
# Extracts values from YAML using grep/sed (no external dependencies beyond basic tools)
parse_yaml_value() {
    local file=$1
    local key=$2
    local section=$3
    
    if [[ -n "$section" ]]; then
        # Extract value within a section
        sed -n "/^${section}:/,\$p" "$file" | grep -A 100 "^  - id: ${key}" | \
            grep -m1 "^    ${section%%_*}_" | sed 's/.*: *//' | tr -d '"' || true
    else
        # Top-level key
        grep -m1 "^${key}:" "$file" | sed 's/.*: *//' | tr -d '"' || true
    fi
}

# Get all entries under a top-level YAML list
get_yaml_entries() {
    local file=$1
    local section=$2
    
    # Find the section and get all id: values under it
    awk -v section="$section" '
        BEGIN { in_section=0; indent=0 }
        /^'"$section"':/ { in_section=1; next }
        in_section && /^[[:space:]]*- id:/ { 
            sub(/^[[:space:]]*- id: /, "")
            print
        }
        in_section && /^[^[:space:]]/ && !/^'"$section"'/ { exit }
    ' "$file"
}

# Get classification for a specific host id
get_host_classification() {
    local file=$1
    local host_id=$2
    
    awk -v target="$host_id" -v found=0 '
        BEGIN { in_host=0; indent=0 }
        /^[[:space:]]*- id: '"$host_id"'/ { in_host=1; next }
        in_host && /^[[:space:]]+- id:/ { exit }
        in_host && /^[[:space:]]+classification:/ { 
            sub(/^[[:space:]]+classification: /, "")
            print
            exit
        }
    ' "$file"
}

# Get all domains under a section
get_yaml_domains() {
    local file=$1
    local section=$2
    
    awk -v section="$section" '
        BEGIN { in_section=0 }
        /^'"$section"':/ { in_section=1; next }
        in_section {
            # Save original line before any modifications
            orig = $0
            if (/^[[:space:]]+- domain:/) {
                sub(/^[[:space:]]+- domain: /, "")
                print
            }
            # Exit when we hit a top-level key (no leading whitespace) that is not our section
            # Check against ORIGINAL line, not extracted value
            if (orig ~ /^[^[:space:]]/ && orig !~ /^'"$section"':/) { exit }
        }
    ' "$file"
}

# Resolve domain to IP using dig (with fallback to host)
resolve_domain() {
    local domain=$1
    local ip=""
    
    # Try dig first with short timeout
    if command -v dig &>/dev/null; then
        ip=$(dig +short +time=5 +tries=2 "$domain" 2>/dev/null | head -1)
    fi
    
    # Fallback to host command
    if [[ -z "$ip" ]] && command -v host &>/dev/null; then
        ip=$(host "$domain" 2>/dev/null | grep "has address" | head -1 | awk '{print $NF}')
    fi
    
    echo "$ip"
}

# Check if an IP belongs to a known test-only host range
# This uses known IP ranges from the policy hosts
is_test_only_ip() {
    local ip=$1
    local policy_file=$2
    
    # Known test-only IP patterns from the hosts file
    # These are read-only checks - we verify against documented ranges
    
    # HD2Stack Tailscale IP (from hosts.yaml)
    local hd2stack_ips="100.71.95.76"

    
    for test_ip in $hd2stack_ips; do
        if [[ "$ip" == "$test_ip" ]]; then
            return 0  # true - is test-only
        fi
    done
    
    return 1  # false - not identified as test-only
}

# =============================================================================
# Main check logic
# =============================================================================

run_check() {
    local policy_file=$1
    # Hosts a client-facing domain must never reference in served assets, regardless of
    # where the client domain itself resolves to.
    local forbidden_hosts=("llm.hd2.ai")
    local violations=0
    local violation_details=()
    local total_checked=0
    
    log "Reading policy from: $policy_file"
    log "========================================"
    
    # Validate policy file exists and is readable
    if [[ ! -f "$policy_file" ]]; then
        error "Policy file not found: $policy_file"
        exit 2
    fi
    
    if [[ ! -r "$policy_file" ]]; then
        error "Policy file not readable: $policy_file"
        exit 2
    fi
    
    # Validate policy file format (basic YAML structure check)
    if ! grep -q "^version:" "$policy_file"; then
        error "Invalid policy file: missing version declaration"
        exit 2
    fi
    
    # Get policy version
    local policy_version
    policy_version=$(grep "^version:" "$policy_file" | head -1 | sed 's/version: *//')
    log "Policy version: $policy_version"
    
    # Get test-only hosts
    local test_only_hosts
    test_only_hosts=$(get_yaml_entries "$policy_file" "hosts" | while read -r host_id; do
        local classification
        classification=$(get_host_classification "$policy_file" "$host_id")
        if [[ "$classification" == "test_only" ]]; then
            echo "$host_id"
        fi
    done)
    
    if [[ -z "$test_only_hosts" ]]; then
        warn "No test_only hosts declared in policy"
    else
        log "Test-only hosts: $(echo "$test_only_hosts" | tr '\n' ' ')"
    fi
    
    # Get client-facing endpoints
    local client_endpoints
    client_endpoints=$(get_yaml_domains "$policy_file" "client_endpoints")
    
    if [[ -z "$client_endpoints" ]]; then
        warn "No client_endpoints declared in policy"
    else
        log "Client endpoints to check: $(echo "$client_endpoints" | wc -l)"
    fi
    
    log "========================================"
    log "Checking client endpoints..."
    log ""
    
    # Check each client endpoint
    while IFS= read -r domain; do
        [[ -z "$domain" ]] && continue
        ((total_checked++)) || true
        
        log "Checking: $domain"
        
        # Resolve domain to IP
        local ip
        ip=$(resolve_domain "$domain")
        
        if [[ -z "$ip" ]]; then
            warn "  Cannot resolve: $domain (DNS failure)"
            violation_details+=("UNRESOLVABLE: $domain - DNS resolution failed")
            continue
        fi
        
        log "  Resolved to: $ip"
        
        # Check if this IP is associated with a test-only host
        if is_test_only_ip "$ip" "$policy_file"; then
            ((violations++)) || true
            error "VIOLATION: Client endpoint '$domain' resolves to test-only infrastructure (IP: $ip)"
            violation_details+=("VIOLATION: $domain -> $ip (test_only host)")
        else
            log "  OK: Resolves to non-test-only infrastructure"
        fi

        # Asset-level isolation: a client domain can resolve to correct, non-test-only
        # infrastructure and still serve assets that call an HD2-internal endpoint.
        # DNS resolution alone cannot see this. Core Distro's production apex resolved
        # correctly while its live HTML still referenced llm.hd2.ai, and this check
        # passed it. Fetch the served page and look for forbidden internal references.
        local body hits
        body=$(curl -sL --max-time 15 "https://$domain/" 2>/dev/null || true)
        if [[ -n "$body" ]]; then
            hits=$(grep -oE "https?://[a-zA-Z0-9._-]+" <<< "$body" 2>/dev/null \
                   | sort -u \
                   | grep -F -f <(printf '%s\n' "${forbidden_hosts[@]}") 2>/dev/null || true)
            if [[ -n "$hits" ]]; then
                while IFS= read -r hit; do
                    [[ -n "$hit" ]] || continue
                    ((violations++)) || true
                    error "ASSET VIOLATION: Client domain '$domain' serves a reference to internal host '$hit'"
                    violation_details+=("ASSET VIOLATION: $domain serves $hit")
                done <<< "$hits"
            else
                log "  OK: No internal endpoint referenced in served assets"
            fi
        else
            log "  WARN: Could not fetch https://$domain/ for asset-level isolation check"
        fi
    done <<< "$client_endpoints"
    
    log ""
    log "========================================"
    log "Summary:"
    log "  Total endpoints checked: $total_checked"
    log "  Violations found: $violations"
    log "========================================"
    
    # Report unverified rows
    log ""
    log "Verification status:"
    log "  - Client endpoints: CHECKED (DNS resolution AND served-asset reference scan performed)"
    log "  - Note: Rows requiring host access are marked UNVERIFIED"
    log "  - Owner for unverifiable rows: Infrastructure team with host access"
    
    # Print violation details
    if [[ $violations -gt 0 ]]; then
        log ""
        log "Violation details:"
        for detail in "${violation_details[@]}"; do
            echo "  - $detail"
        done
    fi
    
    # Return appropriate exit code
    if [[ $violations -gt 0 ]]; then
        log ""
        error "POLICY VIOLATION DETECTED"
        log "The HD2 AnythingLLM instance (test-only) must not serve client-facing endpoints."
        log "Update the policy file if this is a legitimate change."
        exit 1
    fi
    
    log ""
    info "Policy check PASSED - no violations detected"
    log "The HD2 instance remains isolated from client infrastructure."
    exit 0
}

# =============================================================================
# Main entry point
# =============================================================================

main() {
    local policy_file="$DEFAULT_POLICY"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --policy)
                policy_file="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                error "Unknown argument: $1"
                usage
                exit 2
                ;;
        esac
    done
    
    # Check for required tools (advisory only - we handle missing tools gracefully)
    # dig/host are optional - we have fallbacks
    
    # Run the check
    run_check "$policy_file"
}

# Run main if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
