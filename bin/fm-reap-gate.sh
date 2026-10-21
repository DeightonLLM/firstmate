#!/usr/bin/env bash
# fm-reap-gate.sh - Mechanical automatic reap gate for finished/dead lanes.
#
# Requirements & Contract:
# 1. Authority: bin/fm-teardown.sh is the ONLY authority for "is it landed".
#    Never re-implement or weaken that test.
# 2. Never --force. Never bypass a teardown refusal.
# 3. Refusal is a correct outcome, not an error. A crew with unlanded work must
#    survive and the refusal must be recorded with its reason.
# 4. Every reap and every refusal is logged in state/reap.log with:
#    timestamp, task ID, decision (REAP, REFUSE), and the evidence/reason.
# 5. Crisp-R boundary: Never reap anything in a Crisp-R-prefixed pane, tab,
#    window, or workspace, and never the Captain's conversation pane.
# 6. Failsafe: If the landed-work test cannot be determined, preserve it.
#    Never assume landed.
# 7. Triggers: Session start (--sweep), and watcher detecting idle/done crew
#    past bounded age threshold (FM_REAP_AGE_THRESHOLD_SECS, default 300s).
#
# Usage:
#   fm-reap-gate.sh <task-id> [state-dir]
#   fm-reap-gate.sh --sweep [state-dir]
#
# Exit codes:
#   0 - Successfully reaped or cleanly refused and preserved
#   2 - Usage error / invalid task id
#
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${2:-${FM_STATE_OVERRIDE:-$FM_HOME/state}}"

# shellcheck source=bin/fm-classify-lib.sh
. "$SCRIPT_DIR/fm-classify-lib.sh"
# shellcheck source=bin/fm-backend.sh
. "$SCRIPT_DIR/fm-backend.sh"

REAP_LOG="${FM_REAP_LOG:-$STATE/reap.log}"
AGE_THRESHOLD=${FM_REAP_AGE_THRESHOLD_SECS:-300}
case "$AGE_THRESHOLD" in ''|*[!0-9]*) AGE_THRESHOLD=300 ;; esac

log_decision() {
  local decision=$1 task=$2 reason=$3
  local ts
  ts=$(date -u +%FT%TZ)
  mkdir -p "$(dirname "$REAP_LOG")"
  printf '%s %s: %s - %s\n' "$ts" "$decision" "$task" "$reason" >> "$REAP_LOG"
}

reap_single_task() {
  local id=$1 state=$2
  local meta="$state/$id.meta"
  local log="$state/$id.status"
  [ -f "$meta" ] || return 0

  # Boundary check: Never reap anything with a Crisp-R prefix in pane, tab, window,
  # workspace, or label, and never the Captain's own session pane.
  local window workspace_id tab_id pane_id backend
  window=$(grep '^window=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  workspace_id=$(grep '^herdr_workspace_id=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  tab_id=$(grep '^herdr_tab_id=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  pane_id=$(grep '^herdr_pane_id=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  backend=$(grep '^backend=' "$meta" 2>/dev/null | cut -d= -f2- || true)

  case "$window" in
    *Crisp-R*|*captain\ session*)
      log_decision "REFUSE" "$id" "Crisp-R protected boundary (window=$window)"
      return 0
      ;;
  esac

  # Live Herdr attributes
  if [ "$backend" = herdr ] && command -v herdr >/dev/null 2>&1; then
    if [ -n "$workspace_id" ]; then
      local ws_label
      ws_label=$(herdr workspace get "$workspace_id" 2>/dev/null | grep -o '"label":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
      if [[ "$ws_label" =~ Crisp-R ]]; then
        log_decision "REFUSE" "$id" "Crisp-R protected workspace ($workspace_id label=$ws_label)"
        return 0
      fi
    fi
    if [ -n "$tab_id" ]; then
      local tab_label
      tab_label=$(herdr tab get "$tab_id" 2>/dev/null | grep -o '"label":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
      if [[ "$tab_label" =~ Crisp-R ]]; then
        log_decision "REFUSE" "$id" "Crisp-R protected tab ($tab_id label=$tab_label)"
        return 0
      fi
    fi
    if [ -n "$pane_id" ]; then
      local pane_info
      pane_info=$(herdr pane get "$pane_id" 2>/dev/null || true)
      if printf '%s\n' "$pane_info" | grep -qi "Crisp-R"; then
        log_decision "REFUSE" "$id" "Crisp-R protected pane ($pane_id)"
        return 0
      fi
    fi
  fi

  # Live tmux attributes
  if [ "$backend" = tmux ] && command -v tmux >/dev/null 2>&1; then
    case "$window" in
      *:*)
        local tmux_sess="${window%%:*}"
        case "$tmux_sess" in
          *Crisp-R*)
            log_decision "REFUSE" "$id" "Crisp-R protected tmux session ($tmux_sess)"
            return 0
            ;;
        esac
        ;;
    esac
  fi

  # Check eligibility:
  # In sweep mode or direct single-task mode, check age if threshold > 0
  if [ "$AGE_THRESHOLD" -gt 0 ]; then
    local now last_activity=0
    now=${FM_REAP_NOW:-$(date +%s)}
    if [ -f "$log" ]; then
      if [ "$(uname)" = Darwin ]; then
        last_activity=$(stat -f %m "$log" 2>/dev/null || echo 0)
      else
        last_activity=$(stat -c %Y "$log" 2>/dev/null || echo 0)
      fi
    else
      if [ "$(uname)" = Darwin ]; then
        last_activity=$(stat -f %m "$meta" 2>/dev/null || echo 0)
      else
        last_activity=$(stat -c %Y "$meta" 2>/dev/null || echo 0)
      fi
    fi
    local age=$(( now - last_activity ))
    if [ "$age" -lt "$AGE_THRESHOLD" ]; then
      # Not old enough to reap automatically yet
      return 0
    fi
  fi

  # Check crew state: the crew must not be working/parked, and it must be
  # provably finished.
  #
  # ORDER MATTERS, twice over.
  #
  # First: the owning reconciler (bin/fm-crew-state.sh) is asked BEFORE the
  # pane, because it is the only authority on current state. The endpoint used
  # to be checked first and alone, which made a FINISHED lane immortal: a crew
  # that finished leaves its pane sitting at a prompt, so the pane reads
  # "alive" forever. Such a lane held a pane, a worktree slot and CPU for as
  # long as the fleet existed, and that is what made every capacity figure
  # wrong. A lane whose own state is terminal is finished, pane or no pane.
  #
  # Second: a terminal reconciler state outranks a live pane, but it does not
  # outrank everything. A crew that says it is working is never reaped, an
  # alive, ambiguous or unverifiable endpoint still refuses a lane with no
  # terminal state of its own, and the landed-work test below still refuses to
  # discard unlanded work. The age threshold above has already held the lane
  # quiet for its grace period.
  local crew_state_raw="" crew_state=""
  local crew_state_bin="${FM_CREW_STATE_BIN:-$SCRIPT_DIR/fm-crew-state.sh}"
  if [ -x "$crew_state_bin" ]; then
    crew_state_raw=$(FM_HOME="$FM_HOME" FM_STATE_OVERRIDE="$state" \
      FM_DATA_OVERRIDE="${FM_DATA_OVERRIDE:-$FM_HOME/data}" \
      FM_CONFIG_OVERRIDE="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}" \
      "$crew_state_bin" "$id" 2>/dev/null || true)
    case "$crew_state_raw" in
      state:\ *)
        crew_state=${crew_state_raw#state: }
        crew_state=${crew_state%% *}
        ;;
    esac
  fi
  if [ "$crew_state" = "working" ]; then
    log_decision "REFUSE" "$id" "crew is currently working (reconciler: $crew_state_raw)"
    return 0
  fi

  # Endpoint state. A dead or missing endpoint proves idleness. An alive
  # endpoint is a refusal only while the crew's own state is not terminal.
  local endpoint_target endpoint_dead=0
  endpoint_target=$(fm_backend_target_of_meta "$meta")
  if [ -n "$backend" ] && [ -n "$endpoint_target" ]; then
    local agent_state
    agent_state=$(fm_backend_agent_state "$backend" "$endpoint_target")
    case "$agent_state" in
      dead|missing)
        endpoint_dead=1
        ;;
      alive)
        if [ "$crew_state" != "done" ]; then
          log_decision "REFUSE" "$id" "endpoint is alive ($agent_state)"
          return 0
        fi
        ;;
      ambiguous|unverified|unreadable|*)
        if [ "$crew_state" != "done" ]; then
          log_decision "REFUSE" "$id" "endpoint state is not definitively dead ($agent_state)"
          return 0
        fi
        ;;
    esac
  elif [ -n "$backend" ] || [ -n "$endpoint_target" ]; then
    log_decision "REFUSE" "$id" "endpoint metadata incomplete (backend=${backend:-none} target=${endpoint_target:-none})"
    return 0
  fi

  # Status evidence. A missing status file only disqualifies while the crew
  # might still be running: a lane with no status file whose endpoint is
  # provably dead is reapable, a lane whose own state is terminal is reapable,
  # and the landed-work test still protects its work.
  if [ ! -f "$log" ] && [ "$endpoint_dead" -ne 1 ] && [ "$crew_state" != "done" ]; then
    log_decision "REFUSE" "$id" "no status evidence; cannot prove the crew is idle"
    return 0
  fi

  # 4. Status log sanity check: last status line verb must not be working
  local last_status=""
  last_status=$(last_status_line "$log" 2>/dev/null || true)
  if [ -n "$last_status" ]; then
    local verb
    verb=$(status_line_verb "$last_status")
    if [ "$verb" = "working" ]; then
      log_decision "REFUSE" "$id" "last status verb is working"
      return 0
    fi
  fi

  # Delegate exclusively to bin/fm-teardown.sh WITHOUT --force
  local teardown="$SCRIPT_DIR/fm-teardown.sh"
  [ -x "$teardown" ] || {
    log_decision "REFUSE" "$id" "teardown script missing or not executable at $teardown"
    return 0
  }

  local teardown_out="" teardown_rc=0
  teardown_out=$(FM_HOME="$FM_HOME" FM_STATE_OVERRIDE="$state" \
    FM_DATA_OVERRIDE="${FM_DATA_OVERRIDE:-$FM_HOME/data}" \
    FM_CONFIG_OVERRIDE="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}" \
    "$teardown" "$id" 2>&1) || teardown_rc=$?

  if [ "$teardown_rc" -eq 0 ]; then
    log_decision "REAP" "$id" "cleanly teared down and verified landed"
  else
    local refusal_line
    refusal_line=$(printf '%s\n' "$teardown_out" | grep -E '^REFUSED:|^error:' | head -1 || true)
    [ -n "$refusal_line" ] || refusal_line=$(printf '%s\n' "$teardown_out" | head -1 || true)
    [ -n "$refusal_line" ] || refusal_line="teardown exited with code $teardown_rc"
    log_decision "REFUSE" "$id" "$refusal_line"
  fi
  return 0
}

ID=${1:-}
[ -n "$ID" ] || { echo "usage: fm-reap-gate.sh <task-id|--sweep> [state-dir]" >&2; exit 2; }

if [ "$ID" = "--sweep" ]; then
  for m in "$STATE"/*.meta; do
    [ -f "$m" ] || continue
    task_id=$(basename "$m" .meta)
    reap_single_task "$task_id" "$STATE"
  done
  exit 0
fi

case "$ID" in */*|.|..) echo "fm-reap-gate.sh: refusing unsafe task id: $ID" >&2; exit 2 ;; esac

reap_single_task "$ID" "$STATE"
exit 0
