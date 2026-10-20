#!/usr/bin/env bash
# subagent-cap/cap.sh — canonical source of truth for the Herdr subagent cap.
#
# Rules (FIRSTMATE_OP v1 launch-brief; conservative defaults):
#   MAX_SUBAGENT_PANES = 6   (open subagent panes, excluding the Codex coordinator)
#   MAX_TOTAL_PANES    = 7   (includes the Codex coordinator)
#   open pane          = lifecycle in {working, blocked, idle, done}
#   reap allowed       = lifecycle in {done, idle} only (never working/blocked)
#                        MiniMax M3 is an ordinary runtime with no protected review slot
#
# Exit codes:
#   0 = OK / counted / can-spawn
#   1 = generic failure
#   2 = usage error
#   3 = herdr unavailable
#   64 = cap reached (spawn refused); this is the canonical signal for hooks
#
# Sourcing contract:
#   . /root/lib/subagent-cap/cap.sh
#   subagent_cap_constants        # prints "MAX_SUBAGENT_PANES=6 ..."
#   subagent_cap_count_open_subagent [WORKSPACE]
#   subagent_cap_count_open_total    [WORKSPACE]
#   subagent_cap_can_spawn           [WORKSPACE]
#   subagent_cap_assert_can_spawn    [WORKSPACE]   # exit 64 on cap reached
#   subagent_cap_reap_stale          [WORKSPACE]   # close done/idle only
#   subagent_cap_pane_state <PANE_ID>
#
# All functions are read-only except `reap_stale`, which only closes panes
# whose lifecycle is exactly `done` or `idle`. It never touches `working` or
# `blocked`. It is safe to invoke from any supervisor, post-closeout hook, or
# fm-spawn precheck.

set -u

# Ensure standard user local bin is in PATH for herdr lookup across hosts
if [ -n "${HOME:-}" ] && [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# --- Constants --------------------------------------------------------------
MAX_SUBAGENT_PANES=6
MAX_TOTAL_PANES=7
CODEX_COORDINATOR_RESERVED=1
SUBAGENT_CAP_OPEN_STATES='working|blocked|idle|done'
SUBAGENT_CAP_REAP_STATES='done|idle'
SUBAGENT_CAP_VERSION='1.0.0'

# Marker for hooks/validators that need to distinguish a cap-refusal from any
# other failure. Keep this string stable; downstream tests assert on it.
SUBAGENT_CAP_REFUSAL_MARKER='ERR_SUBAGENT_CAP_REACHED'

subagent_cap_constants() {
  printf 'MAX_SUBAGENT_PANES=%s\n' "$MAX_SUBAGENT_PANES"
  printf 'MAX_TOTAL_PANES=%s\n' "$MAX_TOTAL_PANES"
  printf 'CODEX_COORDINATOR_RESERVED=%s\n' "$CODEX_COORDINATOR_RESERVED"
  printf 'OPEN_STATES=%s\n' "$SUBAGENT_CAP_OPEN_STATES"
  printf 'REAP_STATES=%s\n' "$SUBAGENT_CAP_REAP_STATES"
  printf 'VERSION=%s\n' "$SUBAGENT_CAP_VERSION"
}

# --- Internal helpers -------------------------------------------------------

# _subagent_cap_herdr_timeout: bounded so a stuck server cannot hang the cap
# gate. Keep small; this is a precheck, not a long poll.
_subagent_cap_herdr_timeout() { printf '8'; }

# _subagent_cap_pane_list_json [WORKSPACE]
#   Print raw `herdr pane list` JSON to stdout, or empty string on failure.
_subagent_cap_pane_list_json() {
  local ws="${1:-}" to
  to=$(_subagent_cap_herdr_timeout)
  if [ -n "$ws" ]; then
    timeout "${to}s" herdr pane list --workspace "$ws" 2>/dev/null || true
  else
    timeout "${to}s" herdr pane list 2>/dev/null || true
  fi
}

# _subagent_cap_jq_count <JSON> <JQ_FILTER>
#   Returns a single integer (count) using `length` so multi-line pretty-print
#   cannot inflate the result. The caller MUST build a jq expression whose
#   final value is an array; we count its length.
_subagent_cap_jq_count() {
  local payload="$1" filter="$2" raw
  raw=$(printf '%s' "$payload" | jq -r "$filter | length" 2>/dev/null | tail -n 1)
  printf '%s' "${raw:-0}"
}

# --- Public API -------------------------------------------------------------

# subagent_cap_pane_state <PANE_ID>
#   Print the agent_status of a single pane (lowercase). Empty on failure.
subagent_cap_pane_state() {
  local pane_id="${1:-}" to
  [ -n "$pane_id" ] || return 2
  to=$(_subagent_cap_herdr_timeout)
  timeout "${to}s" herdr pane get "$pane_id" 2>/dev/null \
    | jq -r '.result.agent_status // empty' 2>/dev/null \
    | tr '[:upper:]' '[:lower:]'
}

# subagent_cap_count_open_subagent [WORKSPACE]
#   Count non-Codex panes in OPEN_STATES (working|blocked|idle|done).
subagent_cap_count_open_subagent() {
  local payload
  payload=$(_subagent_cap_pane_list_json "${1:-}") || true
  [ -n "$payload" ] || { printf '0'; return 3; }
  _subagent_cap_jq_count "$payload" '
    [.result.panes[]?
     | select((.agent // "") != "codex")
     | select((.agent_status // "") | test("^(working|blocked|idle|done)$"))]
  '
}

# subagent_cap_count_open_total [WORKSPACE]
#   Count ALL panes in OPEN_STATES (including the Codex coordinator pane).
subagent_cap_count_open_total() {
  local payload
  payload=$(_subagent_cap_pane_list_json "${1:-}") || true
  [ -n "$payload" ] || { printf '0'; return 3; }
  _subagent_cap_jq_count "$payload" '
    [.result.panes[]?
     | select((.agent_status // "") | test("^(working|blocked|idle|done)$"))]
  '
}

# subagent_cap_can_spawn [WORKSPACE]
#   Returns 0 if a new subagent may be spawned; 64 if either cap blocks it.
subagent_cap_can_spawn() {
  local sub total
  sub=$(subagent_cap_count_open_subagent "${1:-}" || echo 0)
  total=$(subagent_cap_count_open_total   "${1:-}" || echo 0)
  if [ "$sub" -ge "$MAX_SUBAGENT_PANES" ]; then return 64; fi
  if [ "$total" -ge "$MAX_TOTAL_PANES" ];    then return 64; fi
  return 0
}

# subagent_cap_assert_can_spawn [WORKSPACE]
#   Echo refusal marker + die with 64 if cap blocks. Otherwise return 0.
subagent_cap_assert_can_spawn() {
  local sub total reason ws="${1:-}"
  sub=$(subagent_cap_count_open_subagent "${ws}" || echo 0)
  total=$(subagent_cap_count_open_total   "${ws}" || echo 0)
  if [ "$sub" -ge "$MAX_SUBAGENT_PANES" ]; then
    printf '%s: open_subagent=%s >= MAX_SUBAGENT_PANES=%s\n' \
      "$SUBAGENT_CAP_REFUSAL_MARKER" "$sub" "$MAX_SUBAGENT_PANES" >&2
    return 64
  fi
  if [ "$total" -ge "$MAX_TOTAL_PANES" ]; then
    printf '%s: open_total=%s >= MAX_TOTAL_PANES=%s (incl. Codex)\n' \
      "$SUBAGENT_CAP_REFUSAL_MARKER" "$total" "$MAX_TOTAL_PANES" >&2
    return 64
  fi
  return 0
}

# subagent_cap_reap_stale [WORKSPACE]
#   Close panes whose lifecycle is exactly `done` or `idle`. Never touches
#   `working` or `blocked`. Echoes one line per reaped pane id; the total
#   number of reaped panes is the exit status count (NOT exit code 64).
#   Returns 0 if at least one reap attempt completed; non-zero only on herdr
#   unavailability.
subagent_cap_reap_stale() {
  local ws="${1:-}" payload pane_id state label n=0 fail=0
  local to
  to=$(_subagent_cap_herdr_timeout)
  payload=$(_subagent_cap_pane_list_json "$ws") || true
  [ -n "$payload" ] || return 3

  while IFS=$'\t' read -r pane_id state label; do
    [ -n "$pane_id" ] || continue
    case "$state" in
      done|idle)
        # Resolve close-safe via PATH (so tests can shim it) with an
        # absolute-path fallback for production callers.
        close_bin=$(command -v herdr-pane-close-safe 2>/dev/null || true)
        [ -n "$close_bin" ] || close_bin=/root/bin/herdr-pane-close-safe
        if timeout "${to}s" "$close_bin" "$pane_id" >/dev/null 2>&1; then
          printf 'REAP %s\t%s\n' "$pane_id" "$state"
          n=$((n + 1))
        else
          fail=$((fail + 1))
        fi
        ;;
      *) ;; # working|blocked|unknown — protected
    esac
  done < <(printf '%s' "$payload" \
    | jq -r '.result.panes[]? | [(.pane_id // ""), (.agent_status // ""), (.label // "")] | @tsv' 2>/dev/null)

  printf 'REAP_SUMMARY closed=%s failed=%s\n' "$n" "$fail" >&2
  [ "$fail" -eq 0 ] && return 0 || return 1
}

# If invoked (not sourced), print constants and exit 0.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    constants) subagent_cap_constants ;;
    count-subagent) subagent_cap_count_open_subagent "${2:-}";;
    count-total)   subagent_cap_count_open_total   "${2:-}";;
    can-spawn)
      subagent_cap_can_spawn "${2:-}"; exit $?
      ;;
    assert)
      subagent_cap_assert_can_spawn "${2:-}"; exit $?
      ;;
    reap)
      subagent_cap_reap_stale "${2:-}"
      ;;
    *) printf 'usage: cap.sh {constants|count-subagent|count-total|can-spawn|assert|reap} [WORKSPACE]\n' >&2; exit 2 ;;
  esac
fi
