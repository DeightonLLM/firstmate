#!/usr/bin/env bash
# Deterministic operator override for new Luna worker dispatches.
#
# quota-axi is read once as data only. This helper never routes through quota-
# axi, refreshes credentials, or chooses among providers. It only parses the
# Codex five-hour window and emits a bounded override for fm-spawn.
set -euo pipefail

existing_worker=0
if [[ "${1:-}" == "--existing-worker" ]]; then
  existing_worker=1
  shift
fi
requested_model="${1:-}"
requested_effort="${2:-}"

if [[ -z "$requested_model" ]]; then
  printf 'LUNA_QUOTA_GATE: REFUSED: requested model is required\n' >&2
  exit 64
fi

if ((existing_worker)); then
  printf 'LUNA_QUOTA_GATE: PASS existing-worker unchanged\nMODEL=%s\nEFFORT=%s\n' "$requested_model" "$requested_effort"
  exit 0
fi

quota_cmd=()
if [[ -n "${QUOTA_AXI_BIN:-}" ]]; then
  if ! command -v "$QUOTA_AXI_BIN" >/dev/null 2>&1; then
    printf 'LUNA_QUOTA_GATE: BLOCKED: quota-axi unavailable\n' >&2
    exit 69
  fi
  quota_cmd=("$QUOTA_AXI_BIN")
elif command -v quota-axi >/dev/null 2>&1; then
  quota_cmd=(quota-axi)
elif command -v npx >/dev/null 2>&1; then
  quota_cmd=(npx -y quota-axi)
else
  printf 'LUNA_QUOTA_GATE: BLOCKED: quota-axi unavailable\n' >&2
  exit 69
fi

quota_args=(--json)
if [[ "${quota_cmd[0]}" == "npx" || "${quota_cmd[0]}" == "quota-axi" ]]; then
  quota_args=(--no-credential-refresh --json)
fi

quota_json="$("${quota_cmd[@]}" "${quota_args[@]}" </dev/null 2>/dev/null)" || {
  printf 'LUNA_QUOTA_GATE: BLOCKED: quota-axi --json failed\n' >&2
  exit 69
}
[[ -n "$quota_json" ]] || {
  printf 'LUNA_QUOTA_GATE: BLOCKED: quota-axi returned empty data\n' >&2
  exit 69
}

if ! command -v jq >/dev/null 2>&1; then
  printf 'LUNA_QUOTA_GATE: BLOCKED: jq unavailable for quota parsing\n' >&2
  exit 69
fi

window_count="$(jq -r '[.providers[]? | select(.provider == "codex") | .windows[]? | select((.id == "five_hour") or ((.label // "") | test("5-hour"; "i"))) | .percentRemaining] | length' <<<"$quota_json" 2>/dev/null || printf '0')"
remaining="$(jq -r '[.providers[]? | select(.provider == "codex") | .windows[]? | select((.id == "five_hour") or ((.label // "") | test("5-hour"; "i"))) | .percentRemaining] | if length == 1 then .[0] else empty end' <<<"$quota_json" 2>/dev/null || true)"

if [[ "$window_count" != 1 || ! "$remaining" =~ ^([0-9]+([.][0-9]+)?)$ ]]; then
  printf 'LUNA_QUOTA_GATE: BLOCKED: malformed or unavailable Codex five-hour window\n' >&2
  exit 69
fi

if awk -v r="$remaining" 'BEGIN { exit !(r <= 15) }'; then
  printf 'LUNA_QUOTA_GATE: ROUTE quota_codex_five_hour_percent=%s threshold=15 model=gpt-5.6-luna reasoning_effort=max\n' "$remaining"
  printf 'MODEL=gpt-5.6-luna\nEFFORT=max\n'
else
  printf 'LUNA_QUOTA_GATE: PASS quota_codex_five_hour_percent=%s threshold=15\n' "$remaining"
  printf 'MODEL=%s\nEFFORT=%s\n' "$requested_model" "$requested_effort"
fi
