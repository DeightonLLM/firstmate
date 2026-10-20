#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHECK="$ROOT/bin/fm-brief-preflight.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

passed=0
failed=0

assert_pass() {
  local name=$1 brief=$2 output
  if output=$(bash "$CHECK" "$brief" 2>&1); then
    printf 'PASS %s: %s\n' "$name" "$output"
    passed=$((passed + 1))
  else
    printf 'FAIL %s: expected pass, got: %s\n' "$name" "$output"
    failed=$((failed + 1))
  fi
}

assert_fail_contains() {
  local name=$1 brief=$2 expected=$3 output
  if output=$(bash "$CHECK" "$brief" 2>&1); then
    printf 'FAIL %s: expected rejection containing %q, got pass\n' "$name" "$expected"
    failed=$((failed + 1))
  elif [[ $output == *"$expected"* ]]; then
    printf 'PASS %s: rejected with expected diagnostic: %s\n' "$name" "$output"
    passed=$((passed + 1))
  else
    printf 'FAIL %s: wrong rejection; expected %q, got: %s\n' "$name" "$expected" "$output"
    failed=$((failed + 1))
  fi
}

cat > "$TMP/historical-contradiction.md" <<EOF
WRITE BOUNDARY: $TMP/authoring. Read-only everywhere else.
Required report: $TMP/reports/report.md
STRICTLY FORBIDDEN: modifying, updating, appending to or deleting ANY existing file in warehouse/reports/ (including INDEX.md).
EOF

cat > "$TMP/missing-boundary.md" <<EOF
Required report: $TMP/reports/report.md
STRICTLY FORBIDDEN: modifying, updating, appending to or deleting ANY existing file in warehouse/reports/ (including INDEX.md).
EOF

cat > "$TMP/missing-prohibition.md" <<EOF
WRITE BOUNDARY: $TMP/authoring. Read-only everywhere else.
Required report: $TMP/authoring/report.md
EOF

cat > "$TMP/correct.md" <<EOF
WRITE BOUNDARY: $TMP/authoring. Read-only everywhere else.
IN ADDITION AUTHORISED: create ONE new file $TMP/warehouse/reports/BRIEF-PREFLIGHT.md as a byte-identical copy of the report.
Required report: $TMP/authoring/report.md
Copy to $TMP/warehouse/reports/BRIEF-PREFLIGHT.md
STRICTLY FORBIDDEN: modifying, updating, appending to or deleting ANY existing file in warehouse/reports/ (including INDEX.md); any project checkout; any config; any existing record elsewhere.
EOF

assert_fail_contains 'historical contradiction rejected' "$TMP/historical-contradiction.md" 'outside WRITE BOUNDARY'
assert_fail_contains 'missing boundary rejected' "$TMP/missing-boundary.md" 'missing WRITE BOUNDARY'
assert_fail_contains 'missing existing-warehouse prohibition rejected' "$TMP/missing-prohibition.md" 'missing STRICTLY FORBIDDEN prohibition'
assert_pass 'mandated boundary and explicitly authorised copy accepted' "$TMP/correct.md"

printf 'RESULT: %d passed, %d failed, %d total\n' "$passed" "$failed" "$((passed + failed))"
(( failed == 0 ))
