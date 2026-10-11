#!/usr/bin/env bash
# fm-context-preflight.sh — fail-closed validator for the system-context warehouse.
#
# Exit codes (deterministic; do not renumber):
#   0  PASS — every check passed for every record.
#   1  USAGE — bad invocation.
#   2  MISSING_FILE — required warehouse file is absent.
#   3  SCHEMA — YAML record violates schema.
#   4  STALE — record last_verified is older than freshness_days.
#   5  MISSING_SOURCE — record has no usable source pointer.
#   6  MISSING_EVIDENCE — record evidence path does not exist on disk.
#   7  SECRET — secret-like pattern detected in a record.
#   8  CONTRADICTION — record status/sources/evidence contradict (e.g. KNOWN without evidence).
#   9  INDEX — INDEX.md missing or malformed.
#
# Properties:
#   * Pure bash + standard POSIX tools. No network calls. No credential reads.
#   * Deterministic: identical inputs produce identical outputs and exit codes.
#   * Idempotent and read-only. Never mutates the warehouse or repo.

set -u
set -o pipefail

# -- Configuration ----------------------------------------------------------

SCRIPT_NAME="fm-context-preflight"
SCRIPT_VERSION="1.0.0"
REPO_ROOT_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAREHOUSE_DIR_DEFAULT="${REPO_ROOT_DEFAULT}/docs/system-context"

usage() {
    cat <<EOF
${SCRIPT_NAME} v${SCRIPT_VERSION}

Usage: ${SCRIPT_NAME} [--repo-root PATH] [--warehouse-dir PATH] [--today DATE]
                   [--strict] [--quiet]

Validates the system-context warehouse. With no arguments, validates the
default warehouse at <repo-root>/docs/system-context/.

  --repo-root PATH       Repository root (default: ${REPO_ROOT_DEFAULT}).
  --warehouse-dir PATH   Warehouse directory (default: <repo-root>/docs/system-context).
  --today YYYY-MM-DD     Override "today" for deterministic CI runs.
  --strict               Treat warnings as failures (exit non-zero).
  --quiet                Suppress per-record PASS output; only report failures.

Exit codes:
  0 PASS    1 USAGE    2 MISSING_FILE    3 SCHEMA    4 STALE
  5 MISSING_SOURCE    6 MISSING_EVIDENCE    7 SECRET    8 CONTRADICTION    9 INDEX

EOF
}

REPO_ROOT="${REPO_ROOT_DEFAULT}"
WAREHOUSE_DIR=""
TODAY=""
STRICT=0
QUIET=0
WAREHOUSE_DIR_EXPLICIT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo-root)
            REPO_ROOT="$2"
            shift 2
            ;;
        --warehouse-dir)
            WAREHOUSE_DIR="$2"
            WAREHOUSE_DIR_EXPLICIT=1
            shift 2
            ;;
        --today)
            TODAY="$2"
            shift 2
            ;;
        --strict)
            STRICT=1
            shift
            ;;
        --quiet)
            QUIET=1
            shift
            ;;
        -h|--help|help)
            usage
            exit 0
            ;;
        *)
            echo "${SCRIPT_NAME}: unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ "${WAREHOUSE_DIR_EXPLICIT}" -eq 0 ]]; then
    WAREHOUSE_DIR="${REPO_ROOT}/docs/system-context"
fi

if [[ -z "${TODAY}" ]]; then
    TODAY="$(date -u +%Y-%m-%d)"
fi

# Convert a YYYY-MM-DD date to epoch days (UTC).
date_to_epoch_days() {
    local d="$1"
    if [[ ! "${d}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo -1
        return 0
    fi
    # Use Python if available for deterministic TZ-safe math; else date -u.
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import datetime,sys; d=sys.argv[1].split('-'); print((datetime.date(int(d[0]),int(d[1]),int(d[2]))-datetime.date(1970,1,1)).days)" "${d}" 2>/dev/null || echo -1
    else
        # Fallback: rely on GNU date -u -d; this is best-effort and not TZ-safe on some platforms.
        date -u -d "${d}" +%s 2>/dev/null | awk '{print int($1/86400)}' || echo -1
    fi
}

# -- Result tracking -------------------------------------------------------

declare -a FAILURES=()
declare -a WARNINGS=()
RECORD_COUNT=0

fail() {
    local code="$1"; shift
    local target="$1"; shift
    local msg="$1"; shift
    FAILURES+=("${code}|${target}|${msg}")
}

warn() {
    local target="$1"; shift
    local msg="$1"; shift
    WARNINGS+=("${target}|${msg}")
}

# -- Secret patterns (read-only detection; no secret material is read) -----

SECRET_PATTERNS=(
    'sk-[A-Za-z0-9_-]{16,}'                 # OpenAI / generic sk-
    'sk_live_[A-Za-z0-9]{16,}'              # Stripe live
    'sk_test_[A-Za-z0-9]{16,}'              # Stripe test
    'AIza[0-9A-Za-z_-]{35}'                 # Google API key
    'ghp_[A-Za-z0-9]{30,}'                  # GitHub personal token
    'xox[baprs]-[A-Za-z0-9-]{10,}'          # Slack tokens
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'    # PEM private keys
    'AKIA[0-9A-Z]{16}'                      # AWS access key id
    'password[[:space:]]*[:=][[:space:]]*[A-Za-z0-9!@#\$%^&*()_+=\-]{8,}' # explicit password=
    'api[_-]?key[[:space:]]*[:=][[:space:]]*[A-Za-z0-9]{16,}'  # api_key=<long>
    'bearer[[:space:]]+[A-Za-z0-9._-]{20,}'                    # Bearer <long>
)

scan_for_secrets() {
    local target="$1"
    local file="$2"
    local line
    while IFS= read -r line; do
        local pat
        for pat in "${SECRET_PATTERNS[@]}"; do
            if [[ "${line}" =~ ${pat} ]]; then
                fail 7 "${target}" "secret-like pattern matched: ${pat}"
                return 0
            fi
        done
    done < "${file}"
    return 0
}

# -- File presence and UTF-8 checks ----------------------------------------

require_file() {
    local path="$1"
    if [[ ! -f "${path}" ]]; then
        fail 2 "${path}" "required file is missing"
        return 1
    fi
    if ! file -b --mime-encoding "${path}" 2>/dev/null | grep -q 'utf-8\|us-ascii'; then
        # 'file' may not be present; fall back to grep for non-ASCII control bytes.
        if LC_ALL=C grep -q $'\x80' "${path}"; then
            # UTF-8 multi-byte is allowed; only flag non-text control bytes.
            if LC_ALL=C grep -q $'[\x00-\x08\x0b-\x1f\x7f]' "${path}"; then
                fail 3 "${path}" "file is not valid UTF-8 text"
                return 1
            fi
        fi
    fi
    return 0
}

# -- Minimal YAML record extraction ----------------------------------------
#
# Our YAML uses a constrained format: a top-level mapping with a few scalar
# keys and a list of records. Each record is a mapping with scalar keys and
# list values. We avoid full YAML parsing and instead walk line by line.
#
# For each file we extract: top-level keys, and a list of record blocks
# (delimited by '  - id:' or '- id:' at column 0/2). Within each block, we
# extract scalar fields and the special list fields (evidence_paths and
# sources).

# Read a YAML record block as a list of "key: value" lines (plus list items).
# Output is a heredoc-style body. Caller decides how to interpret.

extract_records() {
    local file="$1"
    awk '
        function flush_block(buf,    i, n, line, out, nlines) {
            n = 0
            for (i = 1; i <= length(buf); i++) {
                line = buf[i]
                if (line ~ /^- id:/) {
                    if (n > 0) {
                        print "---RECORD-START---"
                        for (j = 1; j <= n; j++) print buf[j]
                        print "---RECORD-END---"
                    }
                    n = 0
                    buf[1] = line
                    n = 1
                } else if (n > 0) {
                    n += 1
                    buf[n] = line
                }
            }
            if (n > 0) {
                print "---RECORD-START---"
                for (j = 1; j <= n; j++) print buf[j]
                print "---RECORD-END---"
            }
        }
        BEGIN { record_count = 0 }
        {
            line = $0
            # Skip comments and empty lines outside of records.
            if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) {
                next
            }
            if (line ~ /^[[:space:]]*- id:/) {
                if (record_count > 0) print "---RECORD-END---"
                print "---RECORD-START---"
                record_count += 1
                print line
                next
            }
            if (record_count > 0) {
                print line
            }
        }
        END {
            if (record_count > 0) print "---RECORD-END---"
        }
    ' "${file}"
}

# Parse a single record block (passed via stdin). Echo key=value pairs;
# for list keys (evidence_paths, sources), emit multiple lines.
parse_record_block() {
    awk '
        function emit(k, v) {
            print k "::" v
        }
        function trim(s) {
            sub(/^[[:space:]]+/, "", s)
            sub(/[[:space:]]+$/, "", s)
            return s
        }
        /^[[:space:]]*- id:/ {
            # id is captured separately
            line = $0
            sub(/^[[:space:]]*- id:[[:space:]]*/, "", line)
            emit("id", line)
            next
        }
        /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*$/ {
            # key with empty value; treat as empty
            line = $0
            sub(/^[[:space:]]*/, "", line)
            sub(/:[[:space:]]*$/, "", line)
            emit(line, "")
            next
        }
        /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/ {
            line = $0
            sub(/^[[:space:]]*/, "", line)
            colon = index(line, ":")
            key = substr(line, 1, colon - 1)
            rest = substr(line, colon + 1)
            sub(/^[[:space:]]+/, "", rest)
            sub(/[[:space:]]+$/, "", rest)
            # strip surrounding quotes
            gsub(/^["\047]/, "", rest)
            gsub(/["\047]$/, "", rest)
            emit(key, rest)
            next
        }
        /^[[:space:]]*-[[:space:]]+/ {
            # list item belonging to the most recent key
            line = $0
            sub(/^[[:space:]]*-[[:space:]]+/, "", line)
            gsub(/^["\047]/, "", line)
            gsub(/["\047]$/, "", line)
            emit("__list_item__", line)
            next
        }
    '
}

# -- Record validation -----------------------------------------------------

validate_record() {
    local source_file="$1"
    local block="$2"
    local target_prefix="$3"

    # Parse block into key=value lines.
    local lines
    lines="$(printf '%s\n' "${block}" | parse_record_block)"
    local id=""
    local status=""
    local last_verified=""
    local freshness_days=""
    local last_key=""
    local sources_count=0
    local evidence_count=0
    local notes=""
    local notes_present=0
    local line
    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        local key="${line%%::*}"
        local value="${line#*::}"
        case "${key}" in
            id) id="${value}" ;;
            status) status="${value}" ;;
            last_verified) last_verified="${value}" ;;
            freshness_days) freshness_days="${value}" ;;
            notes)
                notes="${value}"
                notes_present=1
                ;;
            __list_item__)
                if [[ "${last_key}" == "sources" ]]; then
                    sources_count=$((sources_count + 1))
                elif [[ "${last_key}" == "evidence_paths" ]]; then
                    evidence_count=$((evidence_count + 1))
                    local path="${value}"
                    case "${path}" in
                        /*|..|../*|*/../*|*/..)
                            fail 3 "${target_prefix}/${id}" "evidence path not allowed (absolute or parent): ${path}"
                            ;;
                        *)
                            if [[ ! -e "${REPO_ROOT}/${path}" ]]; then
                                fail 6 "${target_prefix}/${id}" "evidence path does not exist: ${path}"
                            fi
                            ;;
                    esac
                fi
                ;;
            *)
                last_key="${key}"
                ;;
        esac
    done <<<"${lines}"

    if [[ -z "${id}" ]]; then
        fail 3 "${target_prefix}" "record has no id"
        return 1
    fi

    local target="${target_prefix}/${id}"

    # Required fields
    if [[ -z "${status}" ]]; then
        fail 3 "${target}" "missing status"
    fi
    if [[ -z "${last_verified}" ]]; then
        fail 3 "${target}" "missing last_verified"
    fi
    if [[ -z "${freshness_days}" ]]; then
        fail 3 "${target}" "missing freshness_days"
    fi

    # Status values
    case "${status}" in
        KNOWN|PARTIAL|UNKNOWN|BLOCKED|DELIVERED|EVIDENCED|IN_PROGRESS)
            : ok ;;
        "")
            : already flagged as missing ;;
        *)
            fail 3 "${target}" "invalid status: ${status}"
            ;;
    esac

    # Freshness check
    if [[ -n "${last_verified}" && -n "${freshness_days}" ]]; then
        local lv_epoch today_epoch threshold
        lv_epoch="$(date_to_epoch_days "${last_verified}")"
        today_epoch="$(date_to_epoch_days "${TODAY}")"
        if [[ "${lv_epoch}" -lt 0 || "${today_epoch}" -lt 0 ]]; then
            fail 3 "${target}" "invalid date format"
        else
            threshold=$((lv_epoch + freshness_days))
            if (( today_epoch > threshold )); then
                fail 4 "${target}" "stale: last_verified=${last_verified} freshness_days=${freshness_days} today=${TODAY}"
            fi
        fi
    fi

    # Status / sources / evidence contradiction check.
    if [[ "${status}" == "DELIVERED" || "${status}" == "KNOWN" || "${status}" == "EVIDENCED" ]]; then
        if (( evidence_count == 0 )); then
            fail 8 "${target}" "status=${status} requires at least one evidence_path"
        fi
        if (( sources_count == 0 )); then
            fail 5 "${target}" "status=${status} requires at least one source pointer"
        fi
    fi
    if [[ "${status}" == "BLOCKED" || "${status}" == "UNKNOWN" ]]; then
        if (( sources_count == 0 )); then
            fail 5 "${target}" "status=${status} requires at least one source pointer"
        fi
    fi

    if [[ "${notes_present}" -eq 1 && -z "${notes}" ]]; then
        warn "${target}" "notes present but empty"
    fi

    RECORD_COUNT=$((RECORD_COUNT + 1))
    if [[ "${QUIET}" -eq 0 ]]; then
        echo "  OK  ${target}"
    fi
    return 0
}

# -- File-level validation -------------------------------------------------

validate_yaml_file() {
    local file="$1"
    local target_prefix="$2"
    if ! require_file "${file}"; then
        return 1
    fi

    # Secret scan on the raw file (read-only).
    scan_for_secrets "${target_prefix}" "${file}"

    local records
    records="$(extract_records "${file}")"
    if [[ -z "${records}" ]]; then
        warn "${file}" "no records parsed"
        return 0
    fi

    local block=""
    local in_block=0
    while IFS= read -r line; do
        case "${line}" in
            ---RECORD-START---)
                in_block=1
                block=""
                ;;
            ---RECORD-END---)
                if [[ "${in_block}" -eq 1 ]]; then
                    validate_record "${file}" "${block}" "${target_prefix}"
                fi
                in_block=0
                block=""
                ;;
            *)
                if [[ "${in_block}" -eq 1 ]]; then
                    if [[ -z "${block}" ]]; then
                        block="${line}"
                    else
                        block="${block}
${line}"
                    fi
                fi
                ;;
        esac
    done <<<"${records}"
    return 0
}

validate_markdown_index() {
    local index_file="${WAREHOUSE_DIR}/INDEX.md"
    if ! require_file "${index_file}"; then
        fail 9 "${index_file}" "INDEX.md missing"
        return 1
    fi
    # Required headings (best-effort grep; do not fail on phrasing differences,
    # only on absence of section identifiers).
    local required=(
        "Authority and override rules"
        "File map"
        "Tier model"
    )
    local missing=0
    local needle
    for needle in "${required[@]}"; do
        if ! grep -qF "${needle}" "${index_file}"; then
            missing=1
            fail 9 "${index_file}" "INDEX.md missing required section: ${needle}"
        fi
    done
    if [[ "${missing}" -eq 1 ]]; then
        return 1
    fi
    return 0
}

validate_evidence_paths_exist() {
    # Backwards-compatibility no-op: evidence paths are now validated inside
    # validate_record. This stub remains so callers do not break if they invoke
    # it directly. It deliberately does nothing.
    return 0
}

# -- Main -----------------------------------------------------------------

main() {
    echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
    echo "  repo_root=${REPO_ROOT}"
    echo "  warehouse_dir=${WAREHOUSE_DIR}"
    echo "  today=${TODAY}"

    if [[ ! -d "${WAREHOUSE_DIR}" ]]; then
        fail 2 "${WAREHOUSE_DIR}" "warehouse directory is missing"
    fi

    if [[ -d "${WAREHOUSE_DIR}" ]]; then
        validate_markdown_index

        local files=(
            "hosts.yaml:hosts"
            "service_catalog.yaml:services"
            "prd_traceability.yaml:prd_items"
        )
        local entry
        for entry in "${files[@]}"; do
            local file="${entry%%:*}"
            local prefix="${entry#*:}"
            local path="${WAREHOUSE_DIR}/${file}"
            if [[ -f "${path}" ]]; then
                echo "Validating ${file} ..."
                validate_yaml_file "${path}" "${prefix}"
            else
                fail 2 "${path}" "warehouse file missing"
            fi
        done
    fi

    echo
    echo "Records validated: ${RECORD_COUNT}"

    # Report failures.
    if [[ "${#FAILURES[@]}" -gt 0 ]]; then
        echo
        echo "Failures:"
        local f
        local first=1
        local worst_code=0
        for f in "${FAILURES[@]}"; do
            local code="${f%%|*}"
            local rest="${f#*|}"
            local target="${rest%%|*}"
            local msg="${rest#*|}"
            if [[ "${first}" -eq 1 || "${code}" -lt "${worst_code}" ]] || false; then
                first=0
            fi
            if (( code > worst_code )); then
                worst_code="${code}"
            fi
            echo "  [${code}] ${target}: ${msg}"
        done
        echo
        echo "Worst failure code: ${worst_code}"
        exit "${worst_code}"
    fi

    if [[ "${#WARNINGS[@]}" -gt 0 ]]; then
        echo
        echo "Warnings:"
        local w
        for w in "${WARNINGS[@]}"; do
            local target="${w%%|*}"
            local msg="${w#*|}"
            echo "  ${target}: ${msg}"
        done
        if [[ "${STRICT}" -eq 1 ]]; then
            exit 1
        fi
    fi

    echo "PASS"
    exit 0
}

main "$@"
