#!/usr/bin/env bash
# Restore and refresh a controller-owned coordinate lease without widening it.
#
# A lease marker is the durable campaign binding. This wrapper may adopt one
# marker after a session/pane restart, but only when its original canonical task
# file still exists unchanged and its original campaign deadline is still live.
# It delegates the actual ledger write to herdr-coordinate-lease-ensure; this
# script never extracts coordinates or creates a task file.
set -u

LEASE_BIN="${FM_COORDINATE_LEASE_BIN:-/root/bin/herdr-coordinate-lease-ensure}"
CAMPAIGN_DIR="${HERDR_CAMPAIGN_STATE_DIR:-/tmp/herdr-campaign-state}"
AGENT="${FM_COORDINATE_AGENT:-${AGY_INTENT_GUARD_AGENT:-antigravity}}"
AGENT="${AGENT//[^A-Za-z0-9_-]/_}"
PANE="${FM_COORDINATE_PANE_ID:-${HERDR_PANE_ID:-}}"
TASK_OVERRIDE="${FM_COORDINATE_TASK_FILE:-}"
MODE="refresh"

usage() {
  printf 'usage: %s [--restore|--refresh]\n' "${0##*/}"
  printf 'Restore or refresh one existing marker-bound coordinate lease.\n'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --restore) MODE=restore; shift ;;
    --refresh) MODE=refresh; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'error: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

# Non-Herdr sessions have no controller pane to bind, so this hook is inert.
[ -n "$PANE" ] || exit 0
[ -x "$LEASE_BIN" ] || exit 0
[ -d "$CAMPAIGN_DIR" ] || exit 0

field() {
  local key=$1 file=$2
  sed -n "s/^${key}://p" "$file" 2>/dev/null | head -n 1
}

canonical() {
  realpath -m -- "$1" 2>/dev/null || printf '%s\n' "$1"
}

pane_key="${PANE//[^A-Za-z0-9_.:-]/_}"
current_marker="$CAMPAIGN_DIR/$pane_key.$AGENT"
candidate=""
candidate_count=0

# Prefer the current pane's marker. If a pane was recreated, find exactly one
# previous marker for this agent; ambiguity is a safe stop, not a guess.
if [ -r "$current_marker" ]; then
  candidate="$current_marker"
else
  while IFS= read -r marker; do
    [ -r "$marker" ] || continue
    marker_agent="${marker##*.}"
    [ "$marker_agent" = "$AGENT" ] || continue
    candidate="$marker"
    candidate_count=$((candidate_count + 1))
  done < <(find "$CAMPAIGN_DIR" -maxdepth 1 -type f -name "*.$AGENT" -print 2>/dev/null)
  [ "$candidate_count" -eq 1 ] || {
    [ "$candidate_count" -eq 0 ] || printf 'coordinate lease: refusing ambiguous prior markers for agent=%s\n' "$AGENT" >&2
    exit 69
  }
fi

task_file="$(field task_file "$candidate")"
task_sha="$(field task_sha "$candidate")"
campaign_expires="$(field expires "$candidate")"
marker_pane="$(field pane "$candidate")"
ttl="$(field ttl "$candidate")"
artifact="$(field artifact "$candidate")"
model="$(field model "$candidate")"

case "$task_file" in /*) ;; *) printf 'coordinate lease: marker has no absolute canonical task file\n' >&2; exit 69 ;; esac
[ -f "$task_file" ] || { printf 'coordinate lease: canonical task file is missing: %s\n' "$task_file" >&2; exit 69; }
[[ "$task_sha" =~ ^[[:xdigit:]]{64}$ ]] || { printf 'coordinate lease: marker task hash is invalid\n' >&2; exit 69; }
[[ "$campaign_expires" =~ ^[0-9]+$ ]] || { printf 'coordinate lease: marker campaign deadline is invalid\n' >&2; exit 69; }
[[ "$ttl" =~ ^[0-9]+$ ]] && [ "$ttl" -ge 1 ] && [ "$ttl" -le 3600 ] || {
  printf 'coordinate lease: marker TTL is invalid\n' >&2
  exit 69
}

if [ -n "$TASK_OVERRIDE" ] && [ "$(canonical "$TASK_OVERRIDE")" != "$(canonical "$task_file")" ]; then
  printf 'coordinate lease: supplied task file differs from the original canonical task file\n' >&2
  exit 69
fi

current_sha="$(sha256sum -- "$task_file" 2>/dev/null | awk '{print $1}')"
[ "$current_sha" = "$task_sha" ] || {
  printf 'coordinate lease: canonical task file changed; refusing renewal\n' >&2
  exit 69
}

now="$(date +%s)"
remaining=$((campaign_expires - now))
[ "$remaining" -ge 60 ] || {
  printf 'coordinate lease: original campaign deadline has expired or is too close to renew\n' >&2
  exit 69
}
[ "$remaining" -le 604800 ] || remaining=604800

# A current marker can use the bridge's normal refresh path. A marker from a
# prior pane must be registered against the current pane, while preserving the
# original campaign deadline and task-bound metadata.
if [ "$marker_pane" = "$PANE" ] && [ "$MODE" = refresh ]; then
  HERDR_CAMPAIGN_STATE_DIR="$CAMPAIGN_DIR" \
    "$LEASE_BIN" --pane "$PANE" --agent "$AGENT" || exit $?
  exit 0
fi

args=(--pane "$PANE" --agent "$AGENT" --register-task "$task_file" --ttl "$ttl" --campaign-seconds "$remaining")
[ "$artifact" = '<none>' ] || [ -z "$artifact" ] || args+=(--artifact "$artifact")
[ -z "$model" ] || args+=(--model "$model")
if ! HERDR_OPERATOR_APPROVED=1 HERDR_CAMPAIGN_STATE_DIR="$CAMPAIGN_DIR" \
  "$LEASE_BIN" "${args[@]}"; then
  printf 'coordinate lease: controller restoration failed\n' >&2
  exit 69
fi
