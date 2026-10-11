#!/usr/bin/env bash
# tests/herdr-secret-input-guard.test.sh — test suite for herdr-secret-input-guard
# Follows tests/lib.sh conventions.
set -euo pipefail

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

GUARD="${HERDR_GUARD_BIN:-/root/bin/herdr-secret-input-guard}"

# (a) A pointer-language prompt returns exit 0 (ALLOW)
# Test 1: string contains "credentials.json path"
if printf '%s\n' "credentials.json path" | "$GUARD" >/dev/null 2>&1; then
  pass "pointer-language prompt 'credentials.json path' allowed (exit 0)"
else
  rc=$?
  fail "expected exit 0 for 'credentials.json path', got $rc"
fi

# Test 2: realistic pointer prompt with credentials.json name/path
if printf '%s\n' "Use credentials.json path /root/.config/gcloud/credentials.json in herdr pane" | "$GUARD" >/dev/null 2>&1; then
  pass "pointer-language prompt with credentials.json file path allowed (exit 0)"
else
  rc=$?
  fail "expected exit 0 for credentials.json pointer prompt, got $rc"
fi

# (b) A real-secret-like input returns exit 78 (BLOCK; guard's refuse code)
# Real secret values: synthetic JWT structure
# Pattern: eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}
fake_jwt="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIn0.SIGSIGSIGSIGSIGSIGSIG"
rc=0
printf '%s\n' "$fake_jwt" | "$GUARD" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 78 ] || [ "$rc" -eq 2 ]; then
  pass "JWT token structure blocked (exit $rc)"
else
  fail "expected exit 78/2 for JWT secret, got $rc"
fi

# Direct credential collection request into prompt/pane
rc=0
printf '%s\n' "enter password into prompt" | "$GUARD" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 78 ] || [ "$rc" -eq 2 ]; then
  pass "interactive credential collection blocked (exit $rc)"
else
  fail "expected exit 78/2 for collection command, got $rc"
fi

