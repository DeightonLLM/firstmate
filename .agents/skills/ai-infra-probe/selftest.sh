#!/usr/bin/env bash
set -euo pipefail

script="$(cd -- "$(dirname -- "$0")" && pwd)/probe.sh"
tmpdir="$(mktemp -d)"
trap 'rm -f "$tmpdir"/stdout "$tmpdir"/stderr; rmdir "$tmpdir"' EXIT

expect_failure() {
  local label=$1 expected=$2
  shift 2
  local stdout="$tmpdir/stdout" stderr="$tmpdir/stderr"
  local code=0
  "$script" "$@" >"$stdout" 2>"$stderr" || code=$?
  if ((code == 0)); then
    printf 'FAIL: %s unexpectedly exited 0\n' "$label" >&2
    exit 1
  fi
  if ! grep -Fq -- "$expected" "$stderr"; then
    printf 'FAIL: %s did not print expected diagnostic: %s\n' "$label" "$expected" >&2
    cat "$stderr" >&2
    exit 1
  fi
  printf 'PASS: %s exited %d and reported: ' "$label" "$code"
  grep -F -- "$expected" "$stderr" | head -n 1
}

expect_failure 'missing target' '--target is required' --out "$tmpdir/out.json"
expect_failure 'invalid target scheme' 'must be an absolute http(s) URL' --target 'file:///etc/passwd' --out "$tmpdir/out.json"
expect_failure 'unknown argument' 'unknown argument: --surprise' --target 'https://example.invalid' --out "$tmpdir/out.json" --surprise
printf 'PASS: invalid inputs fail loudly; no success report is emitted\n'
