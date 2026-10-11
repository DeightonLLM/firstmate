#!/usr/bin/env bash
# fm-provider-route-watch.sh — bounded read-only route-observation helper
# for safe AFK handoffs.
#
# Usage:
#   fm-provider-route-watch.sh --state-dir <dir> [--at <unix-seconds>]
#                              [--quota-file <path>]
#
# The helper exists to mark a route change for the next safe handoff without
# interrupting a working run or changing a queue, lease, pane, or live service.
#
# It is deliberately NOT a daemon, NOT a timer, and NOT wired into
# bin/fm-supervise-daemon.sh. Wiring it into the supervisor loop would broaden
# the daemon's narrow classification contract; this helper is meant to be
# invoked explicitly at a handoff checkpoint by the coordinator, the operator,
# or another named tool. The integration boundary is documented at the foot of
# this file and in docs/warehouse/PROVIDER-ROUTING.md.
#
# Per invocation:
#   1. Reads bin/fm-provider-route.sh --at <now> exactly once via
#      FM_PROVIDER_ROUTE_QUOTA_FILE=<quota-file>, so the watch never refreshes
#      credentials, never starts a process, never mutates a queue, never
#      changes a lease, and never touches a Herdr pane.
#   2. Selects the sanitized set of policy/route facts from the route output
#      (ROUTE_POLICY, ROUTE_STATUS, PRIMARY_PROVIDER/MODEL, REVIEW_PROVIDER/
#      MODEL/REASON, and every SCHEDULE_* field). Credentials, headers, JSON
#      contents, and any non-policy field are never recorded.
#   3. Computes a fingerprint = sha256 over the alphabetically-sorted
#      key=value list.
#   4. Compares to the prior fingerprint at
#      <state-dir>/.provider-route-watch.fingerprint. If the prior file is
#      absent (first observation) the helper records the new fingerprint and
#      writes signal NO_PRIOR.
#   5. Writes the new fingerprint and a single-line signal describing what
#      changed:
#        NO_PRIOR            first observation; no prior fingerprint
#        NO_CHANGE           fingerprint identical to prior
#        HANDOFF_PENDING     route ready AND fingerprint changed — caller may
#                             adopt the new route at the next safe handoff
#        DEFER_ACTIVE_RUN    route blocked OR fingerprint changed to blocked —
#                             caller must keep the active run on its current
#                             provider/lease until a safe handoff
#   6. Exits 0 on success; non-zero only on usage errors, missing arguments,
#      unreadable state directory, or unreadable/missing quota file.
#
# Output files (both under --state-dir, never outside it):
#   .provider-route-watch.fingerprint   one-line sha256
#   .provider-route-watch.signal        one-line state classification
#   .provider-route-watch.last-output   sanitized key=value list (kept for
#                                       audit; never contains secrets)
#
# Environment overrides (all optional):
#   FM_PROVIDER_ROUTE_BIN     override the route script (default: $FM_ROOT/bin/fm-provider-route.sh)
#   FM_PROVIDER_ROUTE_TIMEOUT bounded route timeout in seconds (default: 20)
#
# This helper does not call quota-axi, does not refresh credentials, does not
# move queue rows, and does not become a background process. A failed or
# absent quota file yields exit 69 (the same convention fm-provider-route.sh
# uses for quota_snapshot_unreadable).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd -P)}"
ROUTE_BIN="${FM_PROVIDER_ROUTE_BIN:-$FM_ROOT/bin/fm-provider-route.sh}"
TIMEOUT="${FM_PROVIDER_ROUTE_TIMEOUT:-20}"

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
}

STATE_DIR=""
AT_EPOCH=""
QUOTA_FILE="${FM_PROVIDER_ROUTE_QUOTA_FILE:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-dir)
      [[ $# -ge 2 ]] || { printf 'error: --state-dir requires a directory\n' >&2; exit 64; }
      STATE_DIR=$2
      shift 2
      ;;
    --quota-file)
      [[ $# -ge 2 ]] || { printf 'error: --quota-file requires a file path\n' >&2; exit 64; }
      QUOTA_FILE=$2
      shift 2
      ;;
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

[[ -n "$STATE_DIR" ]] || { printf 'error: --state-dir is required\n' >&2; usage >&2; exit 64; }
[[ -d "$STATE_DIR" && -w "$STATE_DIR" ]] || {
  printf 'error: --state-dir is missing or not writable: %s\n' "$STATE_DIR" >&2; exit 64; }

case "$TIMEOUT" in
  ''|*[!0-9]*|0*) TIMEOUT=20 ;;
esac

if [[ -z "$AT_EPOCH" ]]; then
  AT_EPOCH=$(date +%s)
fi
[[ "$AT_EPOCH" =~ ^[0-9]+$ ]] || {
  printf 'error: --at must be non-negative unix seconds\n' >&2; exit 64; }

[[ -n "$QUOTA_FILE" ]] || {
  printf 'error: --quota-file (or FM_PROVIDER_ROUTE_QUOTA_FILE) is required for a deterministic observation\n' >&2; exit 64; }
[[ -f "$QUOTA_FILE" && -r "$QUOTA_FILE" ]] || {
  printf 'error: --quota-file is missing or unreadable: %s\n' "$QUOTA_FILE" >&2; exit 64; }

[[ -x "$ROUTE_BIN" ]] || {
  printf 'error: route binary is not executable: %s\n' "$ROUTE_BIN" >&2; exit 64; }

ROUTE_OUTPUT=$(FM_PROVIDER_ROUTE_QUOTA_FILE="$QUOTA_FILE" FM_PROVIDER_ROUTE_TIMEOUT="$TIMEOUT" \
  "$ROUTE_BIN" --at "$AT_EPOCH" 2>/dev/null) || ROUTE_RC=$?
ROUTE_RC=${ROUTE_RC:-0}
if [[ "$ROUTE_RC" -ne 0 ]]; then
  # Distinguish a blocked-route decision (the route script emits ROUTE_STATUS=blocked
  # on stdout and exits 69) from a real quota-snapshot error (jq_unavailable,
  # quota_snapshot_unreadable, schema_invalid, etc., which only emit on stderr).
  # A blocked decision IS a valid observation; the watcher must still record
  # the sanitized fingerprint and surface DEFER_ACTIVE_RUN.
  if ! grep -q '^ROUTE_STATUS=' <<<"$ROUTE_OUTPUT"; then
    printf 'error: route binary produced no ROUTE_STATUS line; rc=%d quota=%s\n' \
      "$ROUTE_RC" "$QUOTA_FILE" >&2
    exit 69
  fi
fi

# Sanitized extraction: only these route fields are recorded. Anything else
# (raw quota JSON, secret headers, tokens) is dropped before the fingerprint is
# computed.
SANITIZED_KEYS=(
  ROUTE_POLICY ROUTE_STATUS
  PRIMARY_PROVIDER PRIMARY_MODEL
  REVIEW_PROVIDER REVIEW_MODEL REVIEW_REASON
  AGY_QUOTA_STATUS AGY_SCHEDULE_STATE AGY_SCHEDULE_ALLOWED
  MINIMAX_QUOTA_STATUS MINIMAX_SCHEDULE_STATE MINIMAX_SCHEDULE_ALLOWED
  GLM_QUOTA_STATUS GLM_SCHEDULE_STATE GLM_SCHEDULE_ALLOWED
  CODEX_QUOTA_STATUS CODEX_SCHEDULE_STATE CODEX_SCHEDULE_ALLOWED
  BLOCK_REASON
)

sanitized_pairs=()
while IFS= read -r key; do
  value=$(grep -F "${key}=" <<<"$ROUTE_OUTPUT" | head -n1 | cut -d= -f2- || true)
  [[ -n "$value" ]] && sanitized_pairs+=("${key}=${value}")
done < <(printf '%s\n' "${SANITIZED_KEYS[@]}" | sort)

# Stable, leak-free fingerprint over the sanitized pairs only.
FINGERPRINT=$(printf '%s\n' "${sanitized_pairs[@]}" | sha256sum | awk '{print $1}')
ROUTE_STATUS_VALUE=$(grep -F 'ROUTE_STATUS=' <<<"$ROUTE_OUTPUT" | head -n1 | cut -d= -f2- || true)
[[ -n "$ROUTE_STATUS_VALUE" ]] || ROUTE_STATUS_VALUE=unknown

PRIOR_FP_FILE="$STATE_DIR/.provider-route-watch.fingerprint"
SIGNAL_FILE="$STATE_DIR/.provider-route-watch.signal"
LAST_OUTPUT_FILE="$STATE_DIR/.provider-route-watch.last-output"

PRIOR_FINGERPRINT=""
if [[ -r "$PRIOR_FP_FILE" ]]; then
  PRIOR_FINGERPRINT=$(cat "$PRIOR_FP_FILE" 2>/dev/null || true)
fi

SIGNAL="DEFER_ACTIVE_RUN"
if [[ -z "$PRIOR_FINGERPRINT" ]]; then
  SIGNAL="NO_PRIOR"
elif [[ "$PRIOR_FINGERPRINT" == "$FINGERPRINT" ]]; then
  SIGNAL="NO_CHANGE"
elif [[ "$ROUTE_STATUS_VALUE" == "ready" ]]; then
  SIGNAL="HANDOFF_PENDING"
else
  SIGNAL="DEFER_ACTIVE_RUN"
fi

printf '%s\n' "$FINGERPRINT" > "$PRIOR_FP_FILE"
printf '%s\n' "$SIGNAL" > "$SIGNAL_FILE"
printf '%s\n' "${sanitized_pairs[@]}" > "$LAST_OUTPUT_FILE"

printf 'WATCH_STATE_DIR=%s\n' "$STATE_DIR"
printf 'WATCH_FINGERPRINT=%s\n' "$FINGERPRINT"
printf 'WATCH_SIGNAL=%s\n' "$SIGNAL"
printf 'WATCH_ROUTE_STATUS=%s\n' "$ROUTE_STATUS_VALUE"
printf 'WATCH_AT=%s\n' "$(TZ=UTC date -d "@$AT_EPOCH" '+%Y-%m-%dT%H:%M:%SZ')"

# Integration boundary (documented, NOT enforced by code):
#   - This helper is invoked explicitly at a safe handoff point by the
#     coordinator, the operator, or a named tool. It does not run on a timer,
#     does not live inside fm-supervise-daemon.sh, and does not subscribe to
#     fm-watch.sh wakes.
#   - A working task keeps its run/lease/provider on the route that was active
#     when its lane was started; the signal emitted here is read by the
#     consumer at the next safe handoff, never by a daemon reroute hook.
#   - The default state-dir for an active coordination loop is
#     $FM_HOME/state; that path is the operator's choice, not a hard-coded one
#     inside this helper.
exit 0
