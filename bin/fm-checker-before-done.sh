#!/usr/bin/env bash
# fm-checker-before-done.sh — Independent Checker-Before-Done Verification Gate
#
# Enforces the Independent Review Discipline (Ticket 0007 & REVIEW-AND-TESTING-GATE-STANDARD.md):
# 1. No worker lane or delegated agent may declare its work VERIFIED via self-attestation.
# 2. An unsupported worker PASS claim remains CLAIMED and is REFUSED promotion to VERIFIED.
# 3. Promotion to VERIFIED requires an independent, read-only checker artifact.
# 4. The checker artifact must:
#    a. Exist, be readable, and exceed the minimum size threshold (>= 100 bytes).
#    b. Have an independent identity (different author, pane, or file from the worker).
#    c. Carry an explicit VERDICT containing CHECK_PASS.
#    d. Record a real exit code AND a re-runnable command or measurement.
#
# Rule (d) is what makes the gate honest. REVIEW-AND-TESTING-GATE-STANDARD.md
# demands "a real command and its real stdout", so a checker artifact counts
# only when it records the exit code of a check AND shows the command or the
# measurement that produced it. Prose, a bare verdict, a lone number, or the
# word "assert" on its own are all refused: they are claims, not evidence.
#
# EXIT CODES:
#   0  = PASS — Independent checker verified; worker claim promoted to VERIFIED.
#   1  = FAILED_VERIFICATION — Unsupported worker PASS, self-certification, or failed review.
#   2  = USAGE_ERROR — Missing required parameters.

set -uo pipefail

MIN_ARTIFACT_SIZE=100

usage() {
  cat >&2 <<EOF
Usage: ${0##*/} [--worker <worker-report>] [--checker <checker-report>]
       ${0##*/} <worker-report> [<checker-report>]

Enforces that a worker PASS claim cannot be promoted to VERIFIED without an
independent checker artifact carrying an explicit CHECK_PASS verdict.
EOF
  exit 2
}

worker_report=""
checker_report=""

# Positional and flag parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --worker)
      worker_report="${2:-}"
      shift 2
      ;;
    --checker)
      checker_report="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    -*)
      printf 'ERROR: Unknown option: %s\n' "$1" >&2
      usage
      ;;
    *)
      if [[ -z "$worker_report" ]]; then
        worker_report="$1"
      elif [[ -z "$checker_report" ]]; then
        checker_report="$1"
      else
        printf 'ERROR: Unexpected argument: %s\n' "$1" >&2
        usage
      fi
      shift
      ;;
  esac
done

if [[ -z "$worker_report" ]]; then
  printf 'FAILED_VERIFICATION: Missing required worker report path.\n' >&2
  usage
fi

# 1. Inspect Worker Report
if [[ ! -f "$worker_report" ]]; then
  printf 'FAILED_VERIFICATION: Worker report does not exist: %s\n' "$worker_report" >&2
  exit 1
fi

if [[ ! -r "$worker_report" ]]; then
  printf 'FAILED_VERIFICATION: Worker report is not readable: %s\n' "$worker_report" >&2
  exit 1
fi

worker_size=$(wc -c < "$worker_report" | tr -d ' ')
if (( worker_size < MIN_ARTIFACT_SIZE )); then
  printf 'FAILED_VERIFICATION: Worker report is an empty placeholder (%d bytes < %d minimum threshold)\n' \
    "$worker_size" "$MIN_ARTIFACT_SIZE" >&2
  exit 1
fi

worker_verdict_line=$(grep -E '^[[:space:]]*(\*\*)?VERDICT:[[:space:]]*' "$worker_report" | head -n 1 || true)
if [[ -z "$worker_verdict_line" ]]; then
  printf 'FAILED_VERIFICATION: Worker report lacks mandatory "VERDICT:" declaration\n' >&2
  exit 1
fi

# Check if worker claims PASS
if ! printf '%s' "$worker_verdict_line" | grep -qiE 'VERDICT:[[:space:]]*(PASS|DONE|ACCEPTED)'; then
  printf 'FAILED_VERIFICATION: Worker verdict is not PASS/DONE (%s); promotion to VERIFIED refused.\n' \
    "$(printf '%s' "$worker_verdict_line" | sed -E 's/^[[:space:]]*//')" >&2
  exit 1
fi

# 2. Discover Checker Report if not explicitly specified
if [[ -z "$checker_report" ]]; then
  # Look for standard sibling conventions:
  #   <report>.checker.md
  #   <report_dir>/checker-<basename>
  #   <report_dir>/*checker*.md
  base_dir=$(dirname "$worker_report")
  base_name=$(basename "$worker_report" .md)
  
  if [[ -f "${worker_report%.md}.checker.md" ]]; then
    checker_report="${worker_report%.md}.checker.md"
  elif [[ -f "${base_dir}/checker-${base_name}.md" ]]; then
    checker_report="${base_dir}/checker-${base_name}.md"
  elif [[ -f "${base_dir}/${base_name}-checker.md" ]]; then
    checker_report="${base_dir}/${base_name}-checker.md"
  fi
fi

if [[ -z "$checker_report" ]]; then
  printf 'FAILED_VERIFICATION: Worker PASS is an unsupported self-attestation. No independent checker artifact found.\n' >&2
  printf '                     (Promotion to VERIFIED requires an independent checker artifact with CHECK_PASS)\n' >&2
  exit 1
fi

# 3. Inspect Checker Report Existence and Non-Empty
if [[ ! -f "$checker_report" ]]; then
  printf 'FAILED_VERIFICATION: Independent checker report does not exist: %s\n' "$checker_report" >&2
  exit 1
fi

if [[ ! -r "$checker_report" ]]; then
  printf 'FAILED_VERIFICATION: Independent checker report is not readable: %s\n' "$checker_report" >&2
  exit 1
fi

checker_size=$(wc -c < "$checker_report" | tr -d ' ')
if (( checker_size < MIN_ARTIFACT_SIZE )); then
  printf 'FAILED_VERIFICATION: Independent checker report is an empty placeholder (%d bytes < %d threshold): %s\n' \
    "$checker_size" "$MIN_ARTIFACT_SIZE" "$checker_report" >&2
  exit 1
fi

# 4. Anti-Self-Certification Check (Independence Invariant)
worker_real=$(readlink -f "$worker_report" 2>/dev/null || printf '%s' "$worker_report")
checker_real=$(readlink -f "$checker_report" 2>/dev/null || printf '%s' "$checker_report")

if [[ "$worker_real" == "$checker_real" ]]; then
  printf 'FAILED_VERIFICATION: Checker report is identical to worker report. Self-certification is strictly forbidden.\n' >&2
  exit 1
fi

# Check reviewer/worker identity headers if present
worker_author=$(grep -iE '^[[:space:]]*(\*\*)?(Executor|Author|Worker|Owner|Reviewer_Pane):' "$worker_report" | head -n 1 | sed -E 's/^[^:]+:[[:space:]]*//' | tr -d '*`" ' || true)
checker_author=$(grep -iE '^[[:space:]]*(\*\*)?(Executor|Author|Worker|Owner|Reviewer|Reviewer_Pane):' "$checker_report" | head -n 1 | sed -E 's/^[^:]+:[[:space:]]*//' | tr -d '*`" ' || true)

if [[ -n "$worker_author" && -n "$checker_author" && "$worker_author" == "$checker_author" ]]; then
  printf 'FAILED_VERIFICATION: Checker author (%s) matches worker author (%s). Independent review required.\n' \
    "$checker_author" "$worker_author" >&2
  exit 1
fi

# An independent check must name who did it. Without an identity the artifact
# cannot be shown to come from anyone but the worker, so "independent" would be
# an assertion rather than a fact. This is checked after the mismatch rule
# above, so a declared-but-same author is reported as the more precise fault.
if [[ -z "$checker_author" ]]; then
  printf 'FAILED_VERIFICATION: Independent checker artifact declares no reviewer identity (Reviewer/Author/Executor/Pane). An unidentifiable checker cannot be independent.\n' >&2
  exit 1
fi

# 5. Checker Verdict Check (Must be CHECK_PASS)
checker_verdict_line=$(grep -E '^[[:space:]]*(\*\*)?VERDICT:[[:space:]]*' "$checker_report" | head -n 1 || true)
if [[ -z "$checker_verdict_line" ]]; then
  printf 'FAILED_VERIFICATION: Independent checker report lacks mandatory "VERDICT:" declaration: %s\n' \
    "$checker_report" >&2
  exit 1
fi

if grep -qiE 'REVISION_REQUIRED|CHECK_FAIL|FAILED|REJECTED' <<< "$checker_verdict_line"; then
  printf 'FAILED_VERIFICATION: Independent checker rejected worker claim (%s): %s\n' \
    "$(printf '%s' "$checker_verdict_line" | sed -E 's/^[[:space:]]*//')" "$checker_report" >&2
  exit 1
fi

if ! grep -qiE 'CHECK_PASS|PASS' <<< "$checker_verdict_line"; then
  printf 'FAILED_VERIFICATION: Independent checker verdict is not CHECK_PASS (%s): %s\n' \
    "$(printf '%s' "$checker_verdict_line" | sed -E 's/^[[:space:]]*//')" "$checker_report" >&2
  exit 1
fi

# 6. Concrete Measurement Evidence Check
# Independent review must cite a real command and its real exit code. Both halves
# are required: the exit code proves the check ran, the command or measurement
# proves what was checked. Neither half alone is evidence.
EXIT_CODE_RE='exit[a-z_ -]*(code|status)?[a-z_ -]*[=:]?[[:space:]]*0([^0-9]|$)'
MEASUREMENT_RE='(^|[[:space:]])\$[[:space:]]|```|[0-9]+/[0-9]+|http/[0-9.]+[[:space:]]+200|status[[:space:]_-]*(code[[:space:]_-]*)?[[:space:]]*200|sha-?256|[0-9a-f]{40,64}'

has_exit_code=0
has_measurement=0
if grep -qiE "$EXIT_CODE_RE" "$checker_report"; then
  has_exit_code=1
fi
if grep -qiE "$MEASUREMENT_RE" "$checker_report"; then
  has_measurement=1
fi

if [[ "$has_exit_code" -eq 0 && "$has_measurement" -eq 0 ]]; then
  printf 'FAILED_VERIFICATION: Independent checker artifact contains only unsupported prose without command/measurement evidence.\n' >&2
  exit 1
fi

if [[ "$has_exit_code" -eq 0 ]]; then
  printf 'FAILED_VERIFICATION: Independent checker artifact records no verifiable exit code (expected an "exit code 0" style record).\n' >&2
  exit 1
fi

if [[ "$has_measurement" -eq 0 ]]; then
  printf 'FAILED_VERIFICATION: Independent checker artifact records an exit code but no re-runnable command or measurement to back it.\n' >&2
  exit 1
fi

# 7. Verification Success
printf 'CHECKER_GATE: PASS — Worker claim successfully corroborated by independent checker.\n'
printf '  Worker Report:  %s (%d bytes)\n' "$worker_report" "$worker_size"
printf '  Worker Verdict: %s\n' "$(printf '%s' "$worker_verdict_line" | sed -E 's/^[[:space:]]*//')"
printf '  Checker Report: %s (%d bytes)\n' "$checker_report" "$checker_size"
printf '  Checker Verdict:%s\n' "$(printf '%s' "$checker_verdict_line" | sed -E 's/^[[:space:]]*//')"
printf '  Checker Identity: %s\n' "$checker_author"
printf '  Evidence: exit code recorded + re-runnable command/measurement present\n'
printf '  Status: PROMOTED TO VERIFIED\n'
exit 0
