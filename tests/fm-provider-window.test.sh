#!/usr/bin/env bash
# Deterministic provider-window policy tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
GATE="$ROOT/bin/fm-provider-window.sh"

epoch_for() {
  TZ=Europe/London date -d "$1" +%s
}

field() {
  local key=$1 output=$2
  grep -F "${key}=" <<<"$output" | cut -d= -f2-
}

assert_field() {
  local label=$1 key=$2 expected=$3 output=$4 actual
  actual=$(field "$key" "$output")
  [[ "$actual" == "$expected" ]] || {
    printf 'FAIL %s: %s expected=%s actual=%s\n' "$label" "$key" "$expected" "$actual" >&2
    exit 1
  }
}

out=$("$GATE" glm --at "$(epoch_for '2026-09-16 06:59')")
assert_field "GLM before UK window" SCHEDULE_STATE off_peak "$out"
assert_field "GLM before UK window" SCHEDULE_ALLOWED 1 "$out"

out=$("$GATE" glm --at "$(epoch_for '2026-09-16 07:00')")
assert_field "GLM UK window start" SCHEDULE_STATE peak "$out"
assert_field "GLM UK window start" SCHEDULE_ALLOWED 0 "$out"
assert_field "GLM UK window source" SOURCE_TZ Asia/Singapore "$out"

out=$("$GATE" glm --at "$(epoch_for '2026-09-16 11:00')")
assert_field "GLM UK window end" SCHEDULE_STATE off_peak "$out"

out=$("$GATE" glm --at "$(epoch_for '2026-09-19 08:00')")
assert_field "GLM weekend" SCHEDULE_STATE off_peak "$out"
assert_field "GLM weekend" SCHEDULE_CONFIDENCE published "$out"

out=$("$GATE" minimax --at "$(epoch_for '2026-09-16 08:00')")
assert_field "MiniMax provisional window" SCHEDULE_STATE peak "$out"
assert_field "MiniMax provisional window" SCHEDULE_ALLOWED 0 "$out"
assert_field "MiniMax provisional window" SCHEDULE_CONFIDENCE provisional "$out"

out=$("$GATE" minimax --at "$(epoch_for '2026-09-16 10:30')")
assert_field "MiniMax after provisional window" SCHEDULE_STATE off_peak "$out"
assert_field "MiniMax after provisional window" SCHEDULE_ALLOWED 1 "$out"

out=$("$GATE" agy --at "$(epoch_for '2026-09-16 08:00')")
assert_field "AGY canonical label" PROVIDER agy "$out"
assert_field "AGY no vendor window" SCHEDULE_STATE not_applicable "$out"
assert_field "AGY no vendor window" SCHEDULE_ALLOWED 1 "$out"

if "$GATE" unknown --at "$(epoch_for '2026-09-16 08:00')" >/dev/null 2>&1; then
  echo 'FAIL unknown provider was allowed' >&2
  exit 1
fi

echo 'PASS: GLM exact UK conversion, MiniMax provisional peak, weekend, and always-eligible fallback cases'
