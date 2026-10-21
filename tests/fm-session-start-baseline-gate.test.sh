#!/usr/bin/env bash
# Regression: session start must validate canonical baseline pointers before lock mutation.
#
# The gate has two halves and both are asserted here, on whatever host runs
# this suite: a missing required baseline file must abort the session start
# before anything mutates, and a healthy home must not be blocked by the gate.
# The candidate homes are built under a temporary directory and HOME is pinned,
# so the result never depends on the account-home policy tree of the machine
# running the test.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/fm-session-baseline-gate.XXXXXX")"
mkdir -p "$TMP_ROOT/home/data" "$TMP_ROOT/home/state" "$TMP_ROOT/missing-baseline"

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

out="$TMP_ROOT/session.out"
status=0
HOME="$TMP_ROOT/home" FM_HOME="$TMP_ROOT/home" FM_ROOT_OVERRIDE="$ROOT" \
  FM_BASELINE_ROOT="$TMP_ROOT/missing-baseline" \
  bash "$ROOT/bin/fm-session-start.sh" >"$out" 2>&1 || status=$?

if [ "$status" -ne 2 ]; then
  printf 'FAIL: missing canonical baseline must exit 2 before session start; got %s\n' "$status" >&2
  printf '%s\n' "$(head -20 "$out")" >&2
  exit 1
fi
pass 'missing canonical baseline exits 2 before session start'

if ! grep -q 'BASELINE: FAIL required fresh-agent baseline file is missing' "$out"; then
  printf 'FAIL: missing-baseline diagnostic was not explicit\n' >&2
  exit 1
fi
pass 'missing-baseline diagnostic is explicit'

if ! grep -q "required fresh-agent baseline file is missing: $TMP_ROOT/missing-baseline/docs/system-context/INDEX.md" "$out"; then
  printf 'FAIL: missing-baseline diagnostic did not name the missing file\n' >&2
  printf '%s\n' "$(head -20 "$out")" >&2
  exit 1
fi
pass 'missing-baseline diagnostic names the missing file'

if [ -e "$TMP_ROOT/home/state/.lock" ]; then
  printf 'FAIL: session lock was created before baseline validation\n' >&2
  exit 1
fi
pass 'session lock was not created before baseline validation'

if [ -n "$(ls -A "$TMP_ROOT/home/state" 2>/dev/null)" ]; then
  printf 'FAIL: session start mutated state before baseline validation\n' >&2
  ls -A "$TMP_ROOT/home/state" >&2
  exit 1
fi
pass 'session start mutated no state before baseline validation'

# The gate must not be a false blocker: on a healthy home the baseline
# manifest is emitted and every pointer it names is readable right now.
manifest_out="$TMP_ROOT/manifest.out"
manifest_status=0
HOME="$TMP_ROOT/home" FM_HOME="$TMP_ROOT/home" FM_ROOT_OVERRIDE="$ROOT" \
  FM_BASELINE_ROOT="$ROOT" \
  bash "$ROOT/bin/fm-session-start.sh" --baseline-manifest >"$manifest_out" 2>&1 || manifest_status=$?
if [ "$manifest_status" -ne 0 ]; then
  printf 'FAIL: baseline manifest on a healthy home must succeed; got %s\n' "$manifest_status" >&2
  printf '%s\n' "$(head -20 "$manifest_out")" >&2
  exit 1
fi
pass 'baseline manifest succeeds on a healthy home'

if ! grep -q 'Baseline manifest: fresh-agent-baseline/v1' "$manifest_out"; then
  printf 'FAIL: baseline manifest version line is missing\n' >&2
  exit 1
fi
pass 'baseline manifest carries the manifest version'

while IFS= read -r pointer; do
  [ -n "$pointer" ] || continue
  path=${pointer%% *}
  if [ ! -f "$path" ] || [ ! -r "$path" ]; then
    printf 'FAIL: baseline manifest names a pointer that is not a readable file: %s\n' "$path" >&2
    exit 1
  fi
done <<EOF
$(printf '%s\n' "$manifest_out" | sed -n 's/^\(policy\|project-policy\|routing\|bounded\|lean-ctx\|warehouse\)=\([^ ]*\) .*/\2/p')
EOF
pass 'every pointer the baseline manifest names is a readable file'

printf 'PASS: baseline validation fails closed before lock mutation\nTEST_TMP_PRESERVED=%s\n' "$TMP_ROOT"
