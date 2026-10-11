#!/usr/bin/env bash
# Deterministic provider-route policy tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ROUTE="$ROOT/bin/fm-provider-route.sh"

epoch_for() {
  TZ=UTC date -d "$1" +%s
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

LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-provider-route.XXXXXX")
FIXTURE="$LAB/quota.json"
trap 'rm -rf "$LAB"' EXIT

write_fixture() {
  cat > "$FIXTURE"
}

run_ready() {
  local label=$1 expected_status=$2 at=$3
  shift 3
  local out rc=0
  out=$(FM_PROVIDER_ROUTE_QUOTA_FILE="$FIXTURE" "$ROUTE" --at "$(epoch_for "$at")" 2>"$LAB/route.err") || rc=$?
  [[ "$rc" -eq 0 ]] || {
    printf 'FAIL %s: expected ready exit 0, got %s\n%s\n' "$label" "$rc" "$out" >&2
    cat "$LAB/route.err" >&2
    exit 1
  }
  assert_field "$label" ROUTE_STATUS "$expected_status" "$out"
  for pair in "$@"; do
    assert_field "$label" "${pair%%=*}" "${pair#*=}" "$out"
  done
  printf 'ok - %s\n' "$label"
}

run_blocked() {
  local label=$1 at=$2
  shift 2
  local out rc=0
  out=$(FM_PROVIDER_ROUTE_QUOTA_FILE="$FIXTURE" "$ROUTE" --at "$(epoch_for "$at")" 2>"$LAB/route.err") || rc=$?
  [[ "$rc" -eq 69 ]] || {
    printf 'FAIL %s: expected blocked exit 69, got %s\n%s\n' "$label" "$rc" "$out" >&2
    cat "$LAB/route.err" >&2
    exit 1
  }
  assert_field "$label" ROUTE_STATUS blocked "$out"
  for pair in "$@"; do
    assert_field "$label" "${pair%%=*}" "${pair#*=}" "$out"
  done
  printf 'ok - %s\n' "$label"
}

write_fixture <<'JSON'
{"schemaVersion":5,"providers":[
  {"provider":"agy","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"gemini","status":"known","effectivePercentRemaining":90,"selection":{"status":"known"}}]}},
  {"provider":"minimax","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":70,"selection":{"status":"known"}}]}},
  {"provider":"codex","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":55,"selection":{"status":"known"}}]}},
  {"provider":"zai","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":80,"selection":{"status":"known"}}]}}
]}
JSON

run_ready \
  "Gemini primary with M3 review off peak" \
  ready \
  "2026-09-16 12:55:00" \
  PRIMARY_PROVIDER=agy \
  PRIMARY_MODEL=gemini-3.8-flash-medium \
  REVIEW_PROVIDER=minimax \
  REVIEW_MODEL=minimax-m3 \
  MINIMAX_SCHEDULE_STATE=off_peak \
  GLM_SCHEDULE_STATE=off_peak

cat > "$LAB/quota-axi" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${CALLS:?}"
cat "${FIXTURE:?}"
SH
chmod +x "$LAB/quota-axi"
CALLS="$LAB/quota-axi.calls" FIXTURE="$FIXTURE" QUOTA_AXI_BIN="$LAB/quota-axi" \
  out=$(CALLS="$LAB/quota-axi.calls" FIXTURE="$FIXTURE" QUOTA_AXI_BIN="$LAB/quota-axi" \
    "$ROUTE" --at "$(epoch_for '2026-09-16 12:55:00')") || {
      printf 'FAIL quota-axi single-snapshot invocation\n%s\n' "$out" >&2
      exit 1
    }
[[ "$(wc -l < "$LAB/quota-axi.calls")" -eq 1 ]] || {
  printf 'FAIL quota-axi was not read exactly once\n' >&2
  exit 1
}
[[ "$(cat "$LAB/quota-axi.calls")" == "--no-credential-refresh --json" ]] || {
  printf 'FAIL quota-axi was called with unexpected arguments\n' >&2
  exit 1
}
printf 'ok - quota-axi is one read-only snapshot per decision\n'

write_fixture <<'JSON'
{"schemaVersion":5,"providers":[
  {"provider":"agy","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"gemini","status":"known","effectivePercentRemaining":90,"selection":{"status":"known"}}]}},
  {"provider":"minimax","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":70,"selection":{"status":"known"}}]}},
  {"provider":"codex","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":55,"selection":{"status":"known"}}]}}
]}
JSON

run_ready \
  "Gemini primary with Codex review when both vendor windows peak" \
  ready \
  "2026-09-16 08:00:00" \
  PRIMARY_PROVIDER=agy \
  PRIMARY_MODEL=gemini-3.8-flash-medium \
  REVIEW_PROVIDER=codex \
  REVIEW_MODEL=gpt-5.6-luna \
  MINIMAX_SCHEDULE_STATE=peak \
  GLM_SCHEDULE_STATE=peak

write_fixture <<'JSON'
{"schemaVersion":5,"providers":[
  {"provider":"agy","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"unknown","effectiveAvailability":[]}},
  {"provider":"minimax","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":70,"selection":{"status":"known"}}]}},
  {"provider":"codex","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":55,"selection":{"status":"known"}}]}}
]}
JSON

run_blocked \
  "Unknown Gemini quota does not silently route" \
  "2026-09-16 12:55:00" \
  BLOCK_REASON=agy_quota_unproven

# --- regression for provider-specific AGY scope and exact Gemini model ID ---
# The verified quota-axi shape reports AGY's effective availability under
# scope == "gemini" (not "all_models"); the verified model ID is
# "gemini-3.8-flash-medium"; and a missing MiniMax entry must remain the
# "provider_missing" decision, never silently converted into healthy quota.
# These three narrow tests cover each invariant independently.

write_fixture <<'JSON'
{"schemaVersion":5,"providers":[
  {"provider":"agy","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"gemini","status":"known","effectivePercentRemaining":85,"selection":{"status":"known"}}]}},
  {"provider":"codex","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":60,"selection":{"status":"known"}}]}},
  {"provider":"zai","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":80,"selection":{"status":"known"}}]}}
]}
JSON

# RED 1: AGY scope == "gemini" yields an eligible AGY route. Currently the
# implementation only matches scope == "all_models", so this is blocked with
# BLOCK_REASON=agy_quota_unproven against the unfixed source.
run_ready \
  "AGY quota scope gemini routes eligible (no minimax in quota-axi)" \
  ready \
  "2026-09-16 12:55:00" \
  PRIMARY_PROVIDER=agy \
  PRIMARY_MODEL=gemini-3.8-flash-medium \
  REVIEW_PROVIDER=codex \
  REVIEW_MODEL=gpt-5.6-luna \
  MINIMAX_QUOTA_STATUS=provider_missing

write_fixture <<'JSON'
{"schemaVersion":5,"providers":[
  {"provider":"agy","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":90,"selection":{"status":"known"}}]}},
  {"provider":"minimax","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":70,"selection":{"status":"known"}}]}},
  {"provider":"codex","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":55,"selection":{"status":"known"}}]}},
  {"provider":"zai","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":80,"selection":{"status":"known"}}]}}
]}
JSON

# RED 2: the verified Gemini model ID is the exact token gemini-3.8-flash-medium.
# Currently the implementation emits "gemini-3.8-medium" (missing the "flash-"
# segment), so this assertion fails against the unfixed source.
write_fixture <<'JSON'
{"schemaVersion":5,"providers":[
  {"provider":"agy","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"gemini","status":"known","effectivePercentRemaining":90,"selection":{"status":"known"}}]}},
  {"provider":"minimax","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":70,"selection":{"status":"known"}}]}},
  {"provider":"codex","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":55,"selection":{"status":"known"}}]}},
  {"provider":"zai","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":80,"selection":{"status":"known"}}]}}
]}
JSON

run_ready \
  "Primary model emits verified gemini-3.8-flash-medium ID" \
  ready \
  "2026-09-16 12:55:00" \
  PRIMARY_PROVIDER=agy \
  PRIMARY_MODEL=gemini-3.8-flash-medium

write_fixture <<'JSON'
{"schemaVersion":5,"providers":[
  {"provider":"agy","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"gemini","status":"known","effectivePercentRemaining":85,"selection":{"status":"known"}}]}},
  {"provider":"codex","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":60,"selection":{"status":"known"}}]}},
  {"provider":"zai","state":{"status":"fresh","stale":false},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":80,"selection":{"status":"known"}}]}}
]}
JSON

# RED 3 (regression guard): when MiniMax is absent from the quota-axi
# snapshot, the decision must surface provider_missing for MiniMax, never
# silently convert the absence into eligible / healthy quota or use it as a
# reviewer. This invariant already holds in the current implementation;
# the test exists to prevent an over-eager GREEN fix from regressing it.
run_ready \
  "Missing MiniMax surfaces provider_missing and does not promote reviewer" \
  ready \
  "2026-09-16 12:55:00" \
  PRIMARY_PROVIDER=agy \
  PRIMARY_MODEL=gemini-3.8-flash-medium \
  REVIEW_PROVIDER=codex \
  REVIEW_MODEL=gpt-5.6-luna \
  MINIMAX_QUOTA_STATUS=provider_missing \
  MINIMAX_SCHEDULE_STATE=off_peak \
  MINIMAX_SCHEDULE_ALLOWED=1

echo "PASS: provider route schedule/quota policy cases"
