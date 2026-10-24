#!/usr/bin/env bash
# fm-lint-ratchet.sh - the durable ShellCheck ratchet for this repository.
#
# bin/fm-lint.sh owns the lint definition (the file set, the ShellCheck
# config, and the pinned ShellCheck version) and hands the diagnostics it
# collected to this script. This script owns the committed baseline format,
# the comparison, the update, and the report.
#
# The verdict is deliberately narrow:
#
#   exit 0  no drift. Every diagnostic the lint found is already recorded in
#           the baseline, and every baselined diagnostic of a linted file is
#           still present.
#   exit 1  drift. A NEW diagnostic appeared (a file/code count above the
#           baseline) or a baselined diagnostic DISAPPEARED (a file/code count
#           below the baseline, which means the baseline is stale).
#   exit 2  usage or I/O error.
#
# The baseline format is one tab-separated record per (file, ShellCheck code):
#
#   <file>\t<SCxxxx>\t<count>
#
# sorted by file, then by code. The count is per file and per code rather than
# per line, so an unrelated edit above a baselined diagnostic does not churn
# the baseline, while a second diagnostic of the same code in the same file
# still shows up as drift. '#' comment lines carry the metadata and are
# ignored by the comparison.
#
# The ratchet only ratchets DOWN. --update refuses to record any (file, code)
# count above the one already recorded, so the recorded total can never grow;
# a new diagnostic has to be fixed in the source first.
#
# Usage:
#   fm-lint-ratchet.sh --compare <diagnostics> <baseline> [linted-files]
#   fm-lint-ratchet.sh --update  <diagnostics> <baseline> [linted-files]
#   fm-lint-ratchet.sh --count   <baseline>
set -u

SELF="${BASH_SOURCE[0]}"
SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"
ROOT="$(cd "$SELF_DIR/.." && pwd)"

usage() {
  sed -n '2,/^[^#]/{/^[^#]/d;p}' "$SELF" | sed 's/^# \{0,1\}//'
}

die() {
  printf 'fm-lint-ratchet.sh: %s\n' "$1" >&2
  exit 2
}

# Parse a ShellCheck default-format report into one "<file>\t<code>" record
# per diagnostic. Only caret lines carry a diagnostic, so the source line
# echoed above them and the "For more information" trailer are ignored.
fm_ratchet_pairs() {  # <diagnostics-file>
  awk '
    /^In .* line [0-9]+:$/ { file = $2; next }
    /^[[:space:]]*\^/ {
      if (match($0, /SC[0-9]+ \((info|warning|style|error)\):/)) {
        code = substr($0, RSTART, RLENGTH)
        sub(/ .*/, "", code)
        if (file != "") print file "\t" code
      }
    }
  ' "$1"
}

# Aggregate pairs into one "<file>\t<code>\t<count>" record per pair.
fm_ratchet_counts() {  # <pairs-file>
  LC_ALL=C sort "$1" \
    | awk -F'\t' '{ c[$1 "\t" $2]++ } END { for (k in c) print k "\t" c[k] }' \
    | LC_ALL=C sort
}

# Read the committed baseline into "<file>\t<code>\t<count>" records.
fm_ratchet_baseline() {  # <baseline-file>
  awk -F'\t' '
    /^#/ { next }
    NF >= 3 { print $1 "\t" $2 "\t" $3 }
  ' "$1"
}

# Compare the current counts with the baseline. Prints one tagged record per
# drift and a final TOTALS record:
#
#   NEW\t<file>\t<code>\t<delta>\t<baseline-count>
#   MISSING\t<file>\t<code>\t<delta>\t<baseline-count>
#   TOTALS\t<new>\t<missing>\t<current-total>\t<baseline-total>
#
# The third input file lists the files this run linted. A baselined
# diagnostic only counts as missing when its file was linted, so linting one
# file never fails because the other files were not part of the run.
fm_ratchet_compare() {  # <current-counts> <baseline> [linted-files]
  awk -F'\t' -v have_linted="${3:-}" '
    FILENAME == ARGV[1] { cur[$1 "\t" $2] = $3 + 0; next }
    FILENAME == ARGV[2] { base[$1 "\t" $2] = $3 + 0; next }
    FILENAME == ARGV[3] { linted[$1] = 1; next }
    END {
      new_total = 0
      missing_total = 0
      current_total = 0
      baseline_total = 0
      for (k in cur) {
        current_total += cur[k]
        b = (k in base) ? base[k] : 0
        if (cur[k] > b) {
          split(k, parts, "\t")
          printf "NEW\t%s\t%s\t%d\t%d\n", parts[1], parts[2], cur[k] - b, b
          new_total += cur[k] - b
        }
      }
      for (k in base) {
        split(k, parts, "\t")
        if (have_linted && !(parts[1] in linted)) continue
        baseline_total += base[k]
        c = (k in cur) ? cur[k] : 0
        if (c < base[k]) {
          printf "MISSING\t%s\t%s\t%d\t%d\n", parts[1], parts[2], base[k] - c, base[k]
          missing_total += base[k] - c
        }
      }
      printf "TOTALS\t%d\t%d\t%d\t%d\n", new_total, missing_total, current_total, baseline_total
    }
  ' "$1" "$2" ${3:+"$3"}
}

fm_ratchet_print_report() {  # <comparison-body>
  local kind file code delta base
  while IFS=$'\t' read -r kind file code delta base; do
    case "$kind" in
      NEW)
        printf 'fm-lint-ratchet.sh: NEW diagnostic not in the baseline: %s %s (+%s, baseline %s)\n' \
          "$file" "$code" "$delta" "$base"
        ;;
      MISSING)
        printf 'fm-lint-ratchet.sh: baselined diagnostic no longer present: %s %s (-%s, baseline %s)\n' \
          "$file" "$code" "$delta" "$base"
        ;;
    esac
  done <<EOF
$1
EOF
}

MODE=
DIAGNOSTICS=
BASELINE=
LINTED=

if [ "$#" -ge 1 ]; then
  case "$1" in
    --compare|--update|--count)
      MODE=$1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'fm-lint-ratchet.sh: unknown mode: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
fi

if [ -z "$MODE" ]; then
  printf 'fm-lint-ratchet.sh: a mode is required (--compare, --update, --count).\n' >&2
  usage >&2
  exit 2
fi

if [ "$MODE" = "--count" ]; then
  [ "$#" -ge 1 ] || die "--count needs a baseline path."
  BASELINE=$1
  [ -f "$BASELINE" ] || die "baseline not found: $BASELINE"
  fm_ratchet_baseline "$BASELINE" | awk -F'\t' '{ total += $3 } END { printf "%d\n", total + 0 }'
  exit 0
fi

[ "$#" -ge 2 ] || die "$MODE needs a diagnostics file and a baseline path."
DIAGNOSTICS=$1
BASELINE=$2
LINTED=${3:-}
[ -f "$DIAGNOSTICS" ] || die "diagnostics file not found: $DIAGNOSTICS"

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/fm-lint-ratchet.XXXXXX") || die "could not create a work directory."
# shellcheck disable=SC2329 # Registered by the EXIT trap below.
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

PAIRS="$WORK_DIR/pairs"
COUNTS="$WORK_DIR/counts"
fm_ratchet_pairs "$DIAGNOSTICS" > "$PAIRS"
fm_ratchet_counts "$PAIRS" > "$COUNTS"

CURRENT_TOTAL=$(awk -F'\t' '{ total += $3 } END { printf "%d\n", total + 0 }' "$COUNTS")

if [ "$MODE" = "--update" ]; then
  # The baseline may only lose diagnostics, never gain one. The same comparison
  # the gate uses proves that: a single new (file, code) count above the
  # recorded one refuses the update, so a new diagnostic has to be fixed in
  # the source before it can ever be recorded.
  if [ -f "$BASELINE" ]; then
    fm_ratchet_baseline "$BASELINE" > "$WORK_DIR/baseline"
    UPDATE_COMPARISON=$(fm_ratchet_compare "$COUNTS" "$WORK_DIR/baseline" ${LINTED:+"$LINTED"})
    UPDATE_NEW=$(printf '%s\n' "$UPDATE_COMPARISON" | awk -F'\t' '$1 == "TOTALS" { print $2 }')
    if [ "$UPDATE_NEW" -gt 0 ]; then
      UPDATE_BODY=$(printf '%s\n' "$UPDATE_COMPARISON" | grep -v '^TOTALS')
      fm_ratchet_print_report "$UPDATE_BODY"
      printf 'fm-lint-ratchet.sh: refusing to record %s new diagnostics; fix them in the source first.\n' \
        "$UPDATE_NEW" >&2
      exit 1
    fi
  fi
  # A diagnostic in a file git does not track is a local-only file; recording
  # it would put a baseline entry in the commit that the clean CI checkout
  # cannot reproduce.
  if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$ROOT" ls-files > "$WORK_DIR/tracked"
    UNTRACKED=$(cut -f1 "$COUNTS" | LC_ALL=C sort -u | while IFS= read -r file; do
      [ -n "$file" ] || continue
      if ! grep -Fxq -- "$file" "$WORK_DIR/tracked"; then
        printf '%s\n' "$file"
      fi
    done)
    if [ -n "$UNTRACKED" ]; then
      printf 'fm-lint-ratchet.sh: refusing to record diagnostics in files git does not track:\n' >&2
      printf '%s\n' "$UNTRACKED" >&2
      exit 1
    fi
  fi
  FILE_COUNT=$(cut -f1 "$COUNTS" | LC_ALL=C sort -u | grep -c . || true)
  TMP_BASELINE="$BASELINE.tmp.$$"
  {
    printf '# fm-lint-baseline.tsv - the committed ShellCheck baseline for this repository.\n'
    printf '#\n'
    printf '# One record per (file, ShellCheck code): <file>\t<SCxxxx>\t<count>, sorted by\n'
    printf '# file then code. bin/fm-lint.sh collects the diagnostics; bin/fm-lint-ratchet.sh\n'
    printf '# owns this format, the comparison, and the update.\n'
    printf '#\n'
    printf '# Recorded: %s diagnostics across %s files.\n' "$CURRENT_TOTAL" "$FILE_COUNT"
    printf '#\n'
    printf '# The ratchet only ratchets down: bin/fm-lint.sh --update-baseline refuses to\n'
    printf '# record a new diagnostic, so this count can never grow. A new diagnostic has\n'
    printf '# to be fixed in the source first.\n'
    cat "$COUNTS"
  } > "$TMP_BASELINE" || die "could not write $TMP_BASELINE"
  mv -f "$TMP_BASELINE" "$BASELINE" || die "could not replace $BASELINE"
  printf 'fm-lint-ratchet.sh: baseline updated: %s diagnostics across %s files recorded in %s.\n' \
    "$CURRENT_TOTAL" "$FILE_COUNT" "$BASELINE"
  exit 0
fi

# --compare
if [ ! -f "$BASELINE" ]; then
  printf 'fm-lint-ratchet.sh: baseline not found: %s\n' "$BASELINE" >&2
  printf 'fm-lint-ratchet.sh: create it with: bin/fm-lint.sh --update-baseline\n' >&2
  exit 2
fi

BASELINE_COUNTS="$WORK_DIR/baseline"
fm_ratchet_baseline "$BASELINE" > "$BASELINE_COUNTS"

COMPARISON=$(fm_ratchet_compare "$COUNTS" "$BASELINE_COUNTS" ${LINTED:+"$LINTED"})
NEW_TOTAL=$(printf '%s\n' "$COMPARISON" | awk -F'\t' '$1 == "TOTALS" { print $2 }')
MISSING_TOTAL=$(printf '%s\n' "$COMPARISON" | awk -F'\t' '$1 == "TOTALS" { print $3 }')
BASELINE_TOTAL=$(printf '%s\n' "$COMPARISON" | awk -F'\t' '$1 == "TOTALS" { print $5 }')

if [ "$NEW_TOTAL" -gt 0 ] || [ "$MISSING_TOTAL" -gt 0 ]; then
  REPORT_BODY=$(printf '%s\n' "$COMPARISON" | grep -v '^TOTALS')
  fm_ratchet_print_report "$REPORT_BODY"
  printf 'fm-lint-ratchet.sh: ratchet FAILED: %s new, %s missing, %s known diagnostics, baseline %s.\n' \
    "$NEW_TOTAL" "$MISSING_TOTAL" "$CURRENT_TOTAL" "$BASELINE" >&2
  printf 'fm-lint-ratchet.sh: fix the source, then run: bin/fm-lint.sh --update-baseline\n' >&2
  exit 1
fi

printf 'fm-lint-ratchet.sh: ratchet OK: %s known diagnostics match the baseline (%s recorded).\n' \
  "$CURRENT_TOTAL" "$BASELINE_TOTAL"
exit 0
