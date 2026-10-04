#!/usr/bin/env bash
# Fail-closed contract tests for /root/bin/agent-secret-scan.
#
# SECURITY REQUIREMENT UNDER TEST
# A secret scanner must never report "clean" when it did not actually scan.
# If the scan root is missing, unreadable, or cannot be entered, the scanner
# must exit non-zero. Reporting SUCCESS for an unscanned tree is a fail-open
# defect: it converts an unknown state into a clean bill of health.
#
# This suite is hermetic. It builds a throwaway fixture tree under a temp dir
# and points the scanner at it via AGENT_SECRET_BASELINE /
# AGENT_SECRET_FALSE_POSITIVE_MANIFEST overrides and a ROOT argument. It never
# touches the real /root tree, the real baseline, or any real credential.
set -uo pipefail

SCANNER="${SCANNER:-/root/bin/agent-secret-scan}"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT

pass=0
fail=0

ok()   { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# Build an isolated fixture root.
FIX="$WORK/root"
mkdir -p "$FIX/sub"
printf 'hello world\n' > "$FIX/sub/clean.txt"

# Independent baseline for the fixture so it can never collide with the real one.
FB="$WORK/baseline.tsv"
: > "$FB"
chmod 600 "$FB" 2>/dev/null || true

run_scanner() {
  # run_scanner <mode> <root>
  AGENT_SECRET_BASELINE="$FB" \
  AGENT_SECRET_FALSE_POSITIVE_MANIFEST="$WORK/no-such-manifest.tsv" \
    "$SCANNER" "$1" "$2" 2>&1
}

echo "=== agent-secret-scan fail-closed contract ==="
echo "scanner: $SCANNER"
echo

# ---------------------------------------------------------------------------
# Test 1 (the regression): a root that does not exist must NOT report clean.
# Current behaviour returns "SUCCESS ... no obvious leaked secret files found"
# with exit 0 because the failed `cd` makes ripgrep emit no matches, which the
# scanner interprets as "no matches at all -> clean".
# ---------------------------------------------------------------------------
out="$(run_scanner check "$FIX/does-not-exist")"
rc=$?
if printf '%s' "$out" | grep -qi 'SUCCESS'; then
  bad "T1 missing root must not report SUCCESS (got rc=$rc: $(printf '%s' "$out" | head -1))"
else
  ok "T1 missing root does not report SUCCESS (rc=$rc)"
fi

if [ "$rc" -eq 0 ]; then
  bad "T2 missing root must exit non-zero (got rc=0 = fail-open)"
else
  ok "T2 missing root exits non-zero (rc=$rc)"
fi

# ---------------------------------------------------------------------------
# Test 3: a real, reachable, clean tree must still pass.
# This guards against "fixing" the bug by making the scanner always fail.
# ---------------------------------------------------------------------------
out="$(run_scanner check "$FIX")"
rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qi 'SUCCESS'; then
  ok "T3 reachable clean tree still passes (rc=0)"
else
  bad "T3 reachable clean tree should pass; got rc=$rc: $(printf '%s' "$out" | head -1)"
fi

# ---------------------------------------------------------------------------
# Test 4: a reachable tree containing secret-shaped material must be reported.
# Guards against a fix that silently swallows genuine findings.
# ---------------------------------------------------------------------------
# The secret-shaped fixture is assembled at runtime from fragments so that this
# test file itself never contains a literal that the production scanner would
# (correctly) flag as a finding.
LEAK_KEY="ANTHROPIC_AUTH_TOKEN"
LEAK_VAL="sk-$(printf 'abcdefghijklmnopqrstuvwxyz012345')"
printf '%s="%s"\n' "$LEAK_KEY" "$LEAK_VAL" > "$FIX/sub/leak.txt"
unset LEAK_VAL
out="$(run_scanner check "$FIX")"
rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'leak.txt'; then
  ok "T4 reachable leak is still reported (rc=$rc)"
else
  bad "T4 reachable leak must be reported; got rc=$rc: $(printf '%s' "$out" | head -1)"
fi
rm -f "$FIX/sub/leak.txt"

# ---------------------------------------------------------------------------
# Test 5: list mode must also not silently succeed on an unreachable root.
# ---------------------------------------------------------------------------
out="$(run_scanner list "$FIX/does-not-exist")"
rc=$?
if [ "$rc" -eq 0 ]; then
  bad "T5 list mode on missing root must exit non-zero (got rc=0)"
else
  ok "T5 list mode on missing root exits non-zero (rc=$rc)"
fi

echo
echo "=== $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
