#!/usr/bin/env bash
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gate="$ROOT/bin/fm-ci-required-gate.sh"

output=$("$gate" lint=success tests=success)
case "$output" in
  *"All required CI jobs passed."*) ;;
  *) echo "FAIL: all-success results did not pass" >&2; exit 1 ;;
esac
printf 'ok - all-success CI results pass\n'

if output=$("$gate" lint=success tests=failure 2>&1); then
  echo "FAIL: a failed test job passed the required gate" >&2
  exit 1
fi
case "$output" in
  *"tests' did not pass (result: failure)"*) ;;
  *) printf 'FAIL: unexpected failure diagnostic: %s\n' "$output" >&2; exit 1 ;;
esac
printf 'ok - a failed test job blocks the required gate\n'

if output=$("$gate" lint=success tests=skipped 2>&1); then
  echo "FAIL: a skipped required job passed the required gate" >&2
  exit 1
fi
case "$output" in
  *"tests' did not pass (result: skipped)"*) ;;
  *) printf 'FAIL: unexpected skipped diagnostic: %s\n' "$output" >&2; exit 1 ;;
esac
printf 'ok - a skipped required job blocks the required gate\n'

if output=$("$gate" 2>&1); then
  echo "FAIL: an empty required-job list passed" >&2
  exit 1
fi
case "$output" in
  *"expected at least one job=result argument"*) ;;
  *) printf 'FAIL: unexpected empty-input diagnostic: %s\n' "$output" >&2; exit 1 ;;
esac
printf 'ok - an empty required-job list is rejected\n'
