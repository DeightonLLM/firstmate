#!/usr/bin/env bash
# fm-provider-route.sh - one-snapshot provider decision for new AFK work.
#
# Usage:
#   fm-provider-route.sh [--at <unix-seconds>]
#
# The decision is deliberately small and deterministic:
#   - Gemini 3.8 Medium via the verified AGY provider is the requested primary.
#   - MiniMax M3 is the preferred reviewer outside its provisional soft peak.
#   - Codex is the reviewer during MiniMax peak or whenever M3 quota cannot be
#     proven usable.
#
# quota-axi is read exactly once as data. This command never refreshes a
# credential, starts a process, moves a queue item, or silently falls back to a
# different primary. Unknown quota/auth semantics remain unknown and block the
# decision. A caller may use the emitted facts to make a separately authorized
# spawn decision.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd -P)}"
WINDOW_BIN="${FM_PROVIDER_WINDOW_BIN:-$FM_ROOT/bin/fm-provider-window.sh}"
QUOTA_FILE="${FM_PROVIDER_ROUTE_QUOTA_FILE:-}"
AT_EPOCH=""
TIMEOUT="${FM_PROVIDER_ROUTE_TIMEOUT:-20}"

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --at)
      [[ $# -ge 2 ]] || { printf 'error: --at requires unix seconds\n' >&2; exit 64; }
      AT_EPOCH=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [[ -z "$AT_EPOCH" ]]; then
  AT_EPOCH=$(date +%s)
fi
[[ "$AT_EPOCH" =~ ^[0-9]+$ ]] || {
  printf 'error: --at must be non-negative unix seconds\n' >&2
  exit 64
}

case "$TIMEOUT" in
  ''|*[!0-9]*|0*) TIMEOUT=20 ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  printf 'ROUTE_STATUS=blocked\nBLOCK_REASON=jq_unavailable\n' >&2
  exit 69
fi

run_bounded() {
  local seconds=$1
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$seconds" "$@"
  elif command -v perl >/dev/null 2>&1; then
    perl -e 'my $t = shift; my $pid = fork; die "fork failed" unless defined $pid; if (!$pid) { setpgrp(0, 0); exec @ARGV } local $SIG{ALRM} = sub { kill "TERM", -$pid; select undef, undef, undef, 0.2; kill "KILL", -$pid; exit 124 }; alarm $t; waitpid $pid, 0; exit($? >> 8)' "$seconds" "$@"
  else
    return 125
  fi
}

quota_json=""
if [[ -n "$QUOTA_FILE" ]]; then
  [[ -f "$QUOTA_FILE" && -r "$QUOTA_FILE" ]] || {
    printf 'ROUTE_STATUS=blocked\nBLOCK_REASON=quota_snapshot_unreadable\n' >&2
    exit 69
  }
  quota_json=$(jq -c . "$QUOTA_FILE" 2>/dev/null) || {
    printf 'ROUTE_STATUS=blocked\nBLOCK_REASON=quota_snapshot_invalid_json\n' >&2
    exit 69
  }
else
  quota_cmd=()
  if [[ -n "${QUOTA_AXI_BIN:-}" ]]; then
    command -v "$QUOTA_AXI_BIN" >/dev/null 2>&1 || {
      printf 'ROUTE_STATUS=blocked\nBLOCK_REASON=quota_axi_unavailable\n' >&2
      exit 69
    }
    quota_cmd=("$QUOTA_AXI_BIN")
  elif command -v quota-axi >/dev/null 2>&1; then
    quota_cmd=(quota-axi)
  elif command -v npx >/dev/null 2>&1; then
    quota_cmd=(npx -y quota-axi)
  else
    printf 'ROUTE_STATUS=blocked\nBLOCK_REASON=quota_axi_unavailable\n' >&2
    exit 69
  fi

  quota_json=$(run_bounded "$TIMEOUT" "${quota_cmd[@]}" --no-credential-refresh --json </dev/null 2>/dev/null) || {
    printf 'ROUTE_STATUS=blocked\nBLOCK_REASON=quota_snapshot_failed\n' >&2
    exit 69
  }
fi

[[ -n "$quota_json" ]] || {
  printf 'ROUTE_STATUS=blocked\nBLOCK_REASON=quota_snapshot_empty\n' >&2
  exit 69
}

if ! jq -e 'type == "object" and (.providers | type == "array")' >/dev/null 2>&1 <<<"$quota_json"; then
  printf 'ROUTE_STATUS=blocked\nBLOCK_REASON=quota_snapshot_schema_invalid\n' >&2
  exit 69
fi

jq_value() {
  local expression=$1 provider=$2
  jq -r --arg provider "$provider" "$expression" <<<"$quota_json" 2>/dev/null || printf 'unknown\n'
}

provider_count() {
  jq_value '[.providers[]? | select(.provider == $provider)] | length' "$1"
}

provider_state() {
  jq_value '[.providers[]? | select(.provider == $provider)] | if length == 1 then .[0].state.status // "unknown" else "unknown" end' "$1"
}

provider_stale() {
  jq_value '[.providers[]? | select(.provider == $provider)] | if length == 1 then (if .[0].state.stale == null then "unknown" else (.[0].state.stale | tostring) end) else "unknown" end' "$1"
}

provider_semantics() {
  jq_value '[.providers[]? | select(.provider == $provider)] | if length == 1 then .[0].quotaSemantics.status // "unknown" else "unknown" end' "$1"
}

provider_scope() {
  # Per-provider effectiveAvailability scope as reported by quota-axi. AGY
  # publishes under scope == "gemini"; every other provider continues to use
  # the legacy all_models scope. Anything unrecognised falls back to
  # all_models so unknown vendors keep producing a predictable no-match (and
  # therefore the existing "provider_missing" / unknown decision) instead of
  # silently converting absence into eligibility.
  case "$1" in
    agy) printf '%s' gemini ;;
    *)   printf '%s' all_models ;;
  esac
}

provider_percent() {
  local provider=$1 scope
  scope=$(provider_scope "$provider")
  jq -r --arg provider "$provider" --arg scope "$scope" \
    '[.providers[]? | select(.provider == $provider) | .quotaSemantics.effectiveAvailability[]? | select(.scope == $scope and .status == "known") | .effectivePercentRemaining] | if length == 1 and (.[0] | type == "number") then .[0] else "unknown" end' \
    <<<"$quota_json" 2>/dev/null || printf 'unknown\n'
}

provider_selection() {
  local provider=$1 scope
  scope=$(provider_scope "$provider")
  jq -r --arg provider "$provider" --arg scope "$scope" \
    '[.providers[]? | select(.provider == $provider) | .quotaSemantics.effectiveAvailability[]? | select(.scope == $scope and .status == "known") | .selection.status // "unknown"] | if length == 1 then .[0] else "unknown" end' \
    <<<"$quota_json" 2>/dev/null || printf 'unknown\n'
}

quota_status() {
  local provider=$1 count state stale semantics percent selection
  count=$(provider_count "$provider")
  [[ "$count" == 1 ]] || { printf 'provider_missing\n'; return; }
  state=$(provider_state "$provider")
  [[ "$state" == fresh ]] || { printf 'provider_%s\n' "$state"; return; }
  stale=$(provider_stale "$provider")
  [[ "$stale" == false ]] || { printf 'provider_stale_%s\n' "$stale"; return; }
  semantics=$(provider_semantics "$provider")
  [[ "$semantics" == known ]] || { printf 'quota_semantics_%s\n' "$semantics"; return; }
  percent=$(provider_percent "$provider")
  [[ "$percent" =~ ^[0-9]+([.][0-9]+)?$ ]] || { printf 'quota_unproven\n'; return; }
  if awk -v value="$percent" 'BEGIN { exit !(value > 0) }'; then
    selection=$(provider_selection "$provider")
    [[ "$selection" == known ]] || { printf 'selection_unproven\n'; return; }
    printf 'eligible\n'
  else
    printf 'quota_exhausted\n'
  fi
}

schedule_field() {
  local provider=$1 key=$2 result value
  [[ -x "$WINDOW_BIN" ]] || { printf 'unknown\n'; return; }
  result=$("$WINDOW_BIN" "$provider" --at "$AT_EPOCH" 2>/dev/null) || {
    printf 'unknown\n'
    return
  }
  value=$(grep -F "${key}=" <<<"$result" | cut -d= -f2- | head -n 1 || true)
  printf '%s\n' "${value:-unknown}"
}

agy_quota=$(quota_status agy)
minimax_quota=$(quota_status minimax)
glm_quota=$(quota_status zai)
codex_quota=$(quota_status codex)

agy_schedule=$(schedule_field agy SCHEDULE_STATE)
agy_allowed=$(schedule_field agy SCHEDULE_ALLOWED)
minimax_schedule=$(schedule_field minimax SCHEDULE_STATE)
minimax_allowed=$(schedule_field minimax SCHEDULE_ALLOWED)
glm_schedule=$(schedule_field glm SCHEDULE_STATE)
glm_allowed=$(schedule_field glm SCHEDULE_ALLOWED)
codex_schedule=$(schedule_field codex SCHEDULE_STATE)
codex_allowed=$(schedule_field codex SCHEDULE_ALLOWED)

printf 'ROUTE_POLICY=gemini-primary-v1\n'
printf 'EVALUATED_AT=%s\n' "$(TZ=UTC date -d "@$AT_EPOCH" '+%Y-%m-%dT%H:%M:%SZ')"
printf 'AGY_QUOTA_STATUS=%s\n' "$agy_quota"
printf 'AGY_SCHEDULE_STATE=%s\n' "$agy_schedule"
printf 'AGY_SCHEDULE_ALLOWED=%s\n' "$agy_allowed"
printf 'MINIMAX_QUOTA_STATUS=%s\n' "$minimax_quota"
printf 'MINIMAX_SCHEDULE_STATE=%s\n' "$minimax_schedule"
printf 'MINIMAX_SCHEDULE_ALLOWED=%s\n' "$minimax_allowed"
printf 'GLM_QUOTA_STATUS=%s\n' "$glm_quota"
printf 'GLM_SCHEDULE_STATE=%s\n' "$glm_schedule"
printf 'GLM_SCHEDULE_ALLOWED=%s\n' "$glm_allowed"
printf 'CODEX_QUOTA_STATUS=%s\n' "$codex_quota"
printf 'CODEX_SCHEDULE_STATE=%s\n' "$codex_schedule"
printf 'CODEX_SCHEDULE_ALLOWED=%s\n' "$codex_allowed"

if [[ "$agy_quota" != eligible ]]; then
  printf 'ROUTE_STATUS=blocked\n'
  printf 'BLOCK_REASON=agy_quota_unproven\n'
  exit 69
fi
if [[ "$agy_allowed" != 1 ]]; then
  printf 'ROUTE_STATUS=blocked\n'
  printf 'BLOCK_REASON=agy_schedule_%s\n' "$agy_schedule"
  exit 69
fi

primary_provider=agy
primary_model=gemini-3.8-flash-medium
review_provider=""
review_model=""
review_reason=""
if [[ "$minimax_quota" == eligible && "$minimax_allowed" == 1 ]]; then
  review_provider=minimax
  review_model=minimax-m3
  review_reason=minimax_off_peak
elif [[ "$codex_quota" == eligible && "$codex_allowed" == 1 ]]; then
  review_provider=codex
  review_model=gpt-5.6-luna
  if [[ "$minimax_schedule" == peak ]]; then
    review_reason=minimax_peak
  else
    review_reason=minimax_quota_unproven
  fi
else
  printf 'ROUTE_STATUS=blocked\n'
  printf 'BLOCK_REASON=review_unavailable\n'
  exit 69
fi

printf 'ROUTE_STATUS=ready\n'
printf 'PRIMARY_PROVIDER=%s\n' "$primary_provider"
printf 'PRIMARY_MODEL=%s\n' "$primary_model"
printf 'REVIEW_PROVIDER=%s\n' "$review_provider"
printf 'REVIEW_MODEL=%s\n' "$review_model"
printf 'REVIEW_REASON=%s\n' "$review_reason"
