#!/usr/bin/env bash
# fm-herdr-agent-report.sh - report this session's agent state to Herdr.
#
# Herdr has no built-in adapter for the MCode harness, so an MCode pane has no
# agent label and reports agent_status "unknown", which leaves the pane's
# running/stopped light dark and hides the pane from `herdr agent list`.
# This script is the MCode side of Herdr's documented self-report path: it
# calls `herdr pane report-agent`, and Herdr then shows the agent label and
# state for the pane.
#
# Usage: fm-herdr-agent-report.sh <working|idle|blocked|unknown|session-start|release> [message]
#
# Environment:
#   HERDR_ENV       must be 1, otherwise the script does nothing
#   HERDR_PANE_ID   the pane to report for
#   HERDR_BIN_PATH  the herdr binary to call
#
# MCode runs plugin hooks with a filtered environment: only PATH, HOME, LANG,
# TERM, SHELL, USER, TMPDIR, TEMP, TMP and the Windows equivalents reach the
# hook process. HERDR_ENV, HERDR_PANE_ID and HERDR_BIN_PATH are NOT on that
# allowlist, so a hook invoked by MCode would find no pane and exit without
# reporting. The pane identity still exists in the environment of the MCode
# process that spawned the hook, so this script recovers it by walking up the
# process tree when the variables are missing. When the variables are already
# present the direct call path is unchanged.
#
# The hook payload arrives on stdin and is optional.
# Every failure path exits 0: a slow or broken Herdr must never delay or
# break an agent turn.
set -uo pipefail

VERB="${1:-}"
MESSAGE="${2:-}"

case "$VERB" in
  working | idle | blocked | unknown) ;;
  session-start | release) ;;
  *) exit 0 ;;
esac

# Recover the pane identity from the nearest ancestor process that carries it.
# Only used when the variables are absent, so a direct call keeps its own
# values. Best effort: any failure leaves the variables unset and the script
# exits without reporting, which is the safe direction.
herdr_env_from_ancestor() {
  local pid=$1 depth=0 line
  while [ "$pid" -gt 1 ] && [ "$depth" -lt 8 ]; do
    if [ -r "/proc/$pid/environ" ]; then
      while IFS= read -r line; do
        case "$line" in
          HERDR_ENV=*)
            HERDR_ENV="${line#HERDR_ENV=}"
            ;;
          HERDR_PANE_ID=*)
            HERDR_PANE_ID="${line#HERDR_PANE_ID=}"
            ;;
          HERDR_BIN_PATH=*)
            HERDR_BIN_PATH="${line#HERDR_BIN_PATH=}"
            ;;
        esac
      done < <(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null || true)
      if [ "${HERDR_ENV:-}" = "1" ] && [ -n "${HERDR_PANE_ID:-}" ]; then
        return 0
      fi
    fi
    pid="$(awk '{print $4}' "/proc/$pid/stat" 2>/dev/null || true)"
    case "$pid" in
      '' | *[!0-9]*) return 1 ;;
    esac
    depth=$((depth + 1))
  done
  return 1
}

if [ "${HERDR_ENV:-}" != "1" ] || [ -z "${HERDR_PANE_ID:-}" ]; then
  herdr_env_from_ancestor "$PPID" || true
fi

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
[ -n "${HERDR_BIN_PATH:-}" ] || exit 0
[ -x "${HERDR_BIN_PATH}" ] || exit 0

SOURCE="mcode"
AGENT="mcode"
HERDR_TIMEOUT=2

state_dir() {
  local base
  if [ -n "${FM_HOME:-}" ]; then
    base="$FM_HOME"
  elif [ -n "${XDG_STATE_HOME:-}" ]; then
    base="$XDG_STATE_HOME/firstmate"
  else
    base="$HOME/.local/state/firstmate"
  fi
  printf '%s/state' "$base"
}

# The sequence number must rise with every report from this source, across
# sessions and restarts. A counter file keeps it strictly increasing even when
# two reports land inside the same millisecond.
next_seq() {
  local file="$1" now last
  now="$(date +%s%3N 2>/dev/null || true)"
  case "$now" in
    '' | *[!0-9]*) now=0 ;;
  esac
  last=0
  if [ -f "$file" ]; then
    last="$(cat "$file" 2>/dev/null || true)"
    case "$last" in
      '' | *[!0-9]*) last=0 ;;
    esac
  fi
  if [ "$now" -le "$last" ]; then
    now=$((last + 1))
  fi
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  printf '%s' "$now" >"$file" 2>/dev/null || true
  printf '%s' "$now"
}

# The hook payload is best effort. A session id lets Herdr offer a resume
# command after a Herdr restart, and a missing one only costs that feature.
# A terminal stdin carries no payload and must never be read, or the reporter
# would stall for the whole timeout on every event.
read_payload() {
  local payload
  if [ -t 0 ]; then
    return 0
  fi
  payload="$(timeout 1 cat 2>/dev/null || true)"
  printf '%s' "$payload"
}

payload_session_id() {
  local payload="$1"
  [ -n "$payload" ] || return 0
  printf '%s' "$payload" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)
for key in ("session_id", "sessionId", "conversation_id", "conversationId"):
    value = data.get(key)
    if isinstance(value, str) and value.strip():
        print(value.strip())
        break
' 2>/dev/null || true
}

counter_file() {
  local pane
  pane="$(printf '%s' "$HERDR_PANE_ID" | tr -c 'A-Za-z0-9._-' '_')"
  printf '%s/.herdr-agent-seq-%s' "$(state_dir)" "$pane"
}

run_herdr() {
  timeout "$HERDR_TIMEOUT" "$HERDR_BIN_PATH" "$@" >/dev/null 2>&1 || true
}

payload="$(read_payload)"
session_id="$(payload_session_id "$payload")"
seq="$(next_seq "$(counter_file)")"

case "$VERB" in
  session-start)
    if [ -n "$session_id" ]; then
      run_herdr pane report-agent-session "$HERDR_PANE_ID" \
        --source "$SOURCE" --agent "$AGENT" --seq "$seq" \
        --agent-session-id "$session_id" \
        -- mcode --session "$session_id"
      seq="$(next_seq "$(counter_file)")"
    fi
    run_herdr pane report-agent "$HERDR_PANE_ID" \
      --source "$SOURCE" --agent "$AGENT" --state idle --seq "$seq"
    ;;
  release)
    run_herdr pane release-agent "$HERDR_PANE_ID" \
      --source "$SOURCE" --agent "$AGENT" --seq "$seq"
    ;;
  *)
    args=(
      pane report-agent "$HERDR_PANE_ID"
      --source "$SOURCE" --agent "$AGENT"
      --state "$VERB" --seq "$seq"
    )
    if [ -n "$session_id" ]; then
      args+=(--agent-session-id "$session_id")
    fi
    if [ -n "$MESSAGE" ]; then
      args+=(--message "$MESSAGE")
    fi
    run_herdr "${args[@]}"
    ;;
esac

exit 0
