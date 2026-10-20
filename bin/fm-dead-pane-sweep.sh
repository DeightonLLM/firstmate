#!/usr/bin/env bash
# bin/fm-dead-pane-sweep.sh - classify every live herdr pane and alarm on dead ones.
#
# Design contract:
#   - Enumerates live panes from `herdr pane list` (JSON), or from a fixture file
#     via --panes-file for testing.
#   - For each pane, reads pane_id, agent_status, foreground_cwd,
#     terminal_title_stripped, focused, state_labels, and agent.
#   - Joins against this home's state/ records.
#   - Classifies each pane into exactly one of:
#
#     LIVE              - an agent is working, or the pane is the current
#                        primary session (focused, no agent, cwd = FM_HOME)
#     IDLE-BUT-HELD    - a recorded task exists whose work is NOT finished
#                        (status log lacks terminal verb OR verdict/deliverable
#                        not both present)
#     DEAD-REAPABLE    - a recorded task whose deliverable AND verdict both exist,
#                        OR a pane with no owning record AND no running process
#                        (blank buffer, help text, stalled setup banner, resume hint)
#     UNKNOWN-PROVENANCE - cannot be classified — always do-not-touch
#
#   - Exits non-zero when any DEAD-REAPABLE pane exists (real alarm).
#   - NEVER closes, kills, or modifies anything.
#   - NEVER sends ESC to a live agent.
#
# Usage:
#   fm-dead-pane-sweep.sh [--panes-file <fixture.json>] [state-dir]
#
#   --panes-file: read pane list from <fixture.json> instead of calling herdr.
#                 This is the test seam; production use omits this flag.
#   state-dir:    defaults to $FM_HOME/state.
#
# Exit codes:
#   0  no DEAD-REAPABLE panes found
#   1  one or more DEAD-REAPABLE panes found (alarm)
#   2  usage / argument error
#   3  herdr pane list could not be read
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

PANES_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --panes-file)
      [ -n "${2:-}" ] || { echo "error: --panes-file requires a file argument" >&2; exit 2; }
      PANES_FILE=$2; shift 2
      ;;
    --help|-h)
      echo "Usage: fm-dead-pane-sweep.sh [--panes-file <fixture.json>] [state-dir]"
      echo "  --panes-file: read pane list from fixture instead of calling herdr"
      exit 0
      ;;
    -*)
      echo "error: unknown flag: $1" >&2; exit 2
      ;;
    *)
      break
      ;;
  esac
done

STATE_DIR="${1:-${FM_STATE_OVERRIDE:-$FM_HOME/state}}"

[ -d "$STATE_DIR" ] || {
  echo "error: state directory not found: $STATE_DIR" >&2
  exit 2
}

# Source the shared classification library for status verb detection.
# shellcheck source=bin/fm-classify-lib.sh
. "$SCRIPT_DIR/fm-classify-lib.sh"

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

FmDeadPane_err() { echo "fm-dead-pane-sweep: $*" >&2; }

# _json_get <json> <key>: get string value or empty.
_json_get() {
  local json=$1 key=$2
  printf '%s' "$json" | jq -r ".$key // empty" 2>/dev/null || true
}

# _json_bool <json> <key>: true if boolean is true.
_json_bool() {
  local json=$1 key=$2 val
  val=$(printf '%s' "$json" | jq -r ".$key" 2>/dev/null || true)
  [ "$val" = "true" ]
}

# _find_task_for_pane <pane_id>: find task whose window= or herdr_pane_id=
# in state/*.meta matches. Prints task id or returns 1.
_find_task_for_pane() {
  local pane_id=$1
  for meta in "$STATE_DIR"/*.meta; do
    [ -e "$meta" ] || continue
    grep -qE "^window=$pane_id$" "$meta" 2>/dev/null || \
    grep -qE "^herdr_pane_id=$pane_id$" "$meta" 2>/dev/null || continue
    basename "$meta" .meta
    return 0
  done
  return 1
}

# _has_verdict_and_deliverable <task-id>: true if both exist.
_has_verdict_and_deliverable() {
  local id=$1
  [ -f "$STATE_DIR/$id.verdict" ] && [ -f "$STATE_DIR/$id.deliverable" ]
}

# ---------------------------------------------------------------------------
# Classification helpers
# ---------------------------------------------------------------------------

# _is_dead_shell_signal <json>: strong dead signal on unowned pane.
_is_dead_shell_signal() {
  local json=$1
  local title cwd agent_status state_labels

  title=$(_json_get "$json" "terminal_title_stripped")
  cwd=$(_json_get "$json" "foreground_cwd")
  agent_status=$(_json_get "$json" "agent_status")
  state_labels=$(_json_get "$json" "state_labels")

  [ "$agent_status" = "idle" ] || return 1

  # Must be at a shell home (root-level directory = blank buffer).
  case "$cwd" in
    /|/root|"") ;;
    *) return 1 ;;
  esac

  # Resume hint in state_labels: "Continue" / "Resume" / "left off" (case-insensitive).
  case "$state_labels" in
    *ontinue*|*esume*|*left\ off*) return 0 ;;
  esac
  case "$state_labels" in
    *[Cc]ontinue*|*[Rr]esume*) return 0 ;;
  esac

  # Setup/welcome banner in title.
  case "$title" in
    *[Ww]elcome*|*[Gg]etting\ [Ss]tarted*|*[Ss]etup*) return 0 ;;
  esac

  # Blank buffer: idle at a shell home with no resume hint or banner.
  return 0
}

# _classify_owned_pane <task-id> <pane-json>: classify pane with a record.
_classify_owned_pane() {
  local task_id=$1 json=$2 agent_status
  agent_status=$(_json_get "$json" "agent_status")

  # LIVE: agent is working.
  [ "$agent_status" = "working" ] && { printf LIVE; return; }

  # DEAD-REAPABLE: verdict AND deliverable both present.
  _has_verdict_and_deliverable "$task_id" && { printf DEAD-REAPABLE; return; }

  # IDLE-BUT-HELD: record exists but work not done.
  printf IDLE-BUT-HELD
}

# _classify_unowned_pane <pane-json>: classify pane with no record.
_classify_unowned_pane() {
  local json=$1
  local agent_status cwd

  agent_status=$(_json_get "$json" "agent_status")
  cwd=$(_json_get "$json" "foreground_cwd")

  # LIVE: working agent even without a record.
  [ "$agent_status" = "working" ] && { printf LIVE; return; }

  # LIVE: focused primary session (focused, no agent, unknown status, cwd = FM_HOME).
  if _json_bool "$json" "focused" \
     && [ "$agent_status" = "unknown" ] \
     && [ -z "$(_json_get "$json" "agent")" ]; then
    local fm_home_canonical pane_canonical
    fm_home_canonical=$(cd "$FM_HOME" 2>/dev/null && pwd -P) || fm_home_canonical="$FM_HOME"
    pane_canonical=$(printf '%s' "$cwd" | sed 's:/*$::')
    [ "$fm_home_canonical" = "$pane_canonical" ] && { printf LIVE; return; }
  fi

  # DEAD-REAPABLE: resume hint in state_labels — strong dead signal regardless
  # of agent_status (Luna panes show "Continue where you left off?" even when
  # the agent has exited and status is unknown).
  local state_labels
  state_labels=$(_json_get "$json" "state_labels")
  if [ -n "$state_labels" ]; then
    case "$state_labels" in
      *ontinue*|*esume*|*left\ off*) printf DEAD-REAPABLE; return ;;
    esac
    case "$state_labels" in
      *[Cc]ontinue*|*[Rr]esume*) printf DEAD-REAPABLE; return ;;
    esac
  fi

  # DEAD-REAPABLE: strong dead shell signal (idle + blank buffer).
  _is_dead_shell_signal "$json" && { printf DEAD-REAPABLE; return; }

  # UNKNOWN-PROVENANCE: cannot classify.
  printf UNKNOWN-PROVENANCE
}

# _classify_pane <pane-json>: classify one pane. Prints:
#   "<pane_id> <class> <evidence>"
_classify_pane() {
  local json=$1 pane_id task_id cls agent_status cwd title

  pane_id=$(_json_get "$json" "pane_id")
  [ -z "$pane_id" ] && return

  task_id=$(_find_task_for_pane "$pane_id") || task_id=""
  if [ -n "$task_id" ]; then
    cls=$(_classify_owned_pane "$task_id" "$json")
  else
    cls=$(_classify_unowned_pane "$json")
  fi

  agent_status=$(_json_get "$json" "agent_status")
  cwd=$(_json_get "$json" "foreground_cwd")
  title=$(_json_get "$json" "terminal_title_stripped")

  local evidence="status=$agent_status"
  [ -n "$cwd" ]    && evidence="$evidence cwd=$cwd"
  [ -n "$task_id" ] && evidence="$evidence task=$task_id"
  [ -n "$title" ]  && evidence="$evidence title=$title"

  printf '%s %s %s\n' "$pane_id" "$cls" "$evidence"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  local pane_list panes_json count line cls rc=0

  # Read pane list.
  if [ -n "$PANES_FILE" ]; then
    [ -f "$PANES_FILE" ] || { FmDeadPane_err "panes file not found: $PANES_FILE"; exit 3; }
    pane_list=$(cat "$PANES_FILE") || { FmDeadPane_err "could not read panes file: $PANES_FILE"; exit 3; }
  else
    pane_list=$(herdr pane list 2>&1) || {
      FmDeadPane_err "herdr pane list failed: $pane_list"; exit 3
    }
  fi

  panes_json=$(printf '%s' "$pane_list" | jq '.result.panes' 2>/dev/null) || {
    FmDeadPane_err "could not parse pane list JSON"; exit 3
  }

  count=$(printf '%s' "$panes_json" | jq 'length' 2>/dev/null) || count=0
  [ "$count" -eq 0 ] && return 0

  # Classify each pane.
  while IFS= read -r pane_json; do
    [ -z "$pane_json" ] && continue
    line=$(_classify_pane "$pane_json")
    [ -z "$line" ] && continue
    printf '%s\n' "$line"

    cls=$(printf '%s' "$line" | awk '{print $2}')
    [ "$cls" = "DEAD-REAPABLE" ] && rc=1
  done < <(printf '%s' "$panes_json" | jq -c '.[]' 2>/dev/null)

  return $rc
}

main
