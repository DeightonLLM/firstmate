#!/usr/bin/env bash
# Regression: session start must validate canonical baseline pointers before lock mutation.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/fm-session-baseline-gate.XXXXXX")"
mkdir -p "$TMP_ROOT/home/data" "$TMP_ROOT/home/state" "$TMP_ROOT/missing-baseline"

out="$TMP_ROOT/session.out"
status=0
FM_HOME="$TMP_ROOT/home" FM_ROOT_OVERRIDE="$ROOT" FM_BASELINE_ROOT="$TMP_ROOT/missing-baseline" \
  bash "$ROOT/bin/fm-session-start.sh" >"$out" 2>&1 || status=$?

if [ "$status" -ne 2 ]; then
  printf 'FAIL: missing canonical baseline must exit 2 before session start; got %s\n' "$status" >&2
  printf '%s\n' "$(head -20 "$out")" >&2
  exit 1
fi
if ! grep -q 'BASELINE: FAIL required fresh-agent baseline file is missing' "$out"; then
  printf 'FAIL: missing-baseline diagnostic was not explicit\n' >&2
  exit 1
fi
if [ -e "$TMP_ROOT/home/state/.lock" ]; then
  printf 'FAIL: session lock was created before baseline validation\n' >&2
  exit 1
fi
printf 'PASS: baseline validation fails closed before lock mutation\nTEST_TMP_PRESERVED=%s\n' "$TMP_ROOT"
