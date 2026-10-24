#!/usr/bin/env bash
# bin/fm-surface-census-lib.sh - one measured census of the live agent
# surface, shared by the visibility view and the naming enforcement check.
#
# Why a lib and not two scripts: the Captain's question ("which surface is
# running what") and the naming rule ("does every live name conform") must be
# answered from the SAME evidence. Two independent readings would let the view
# say a lane is live while the check says its name is fine, or the reverse.
#
# The census is three Herdr reads plus one state read, never a probe per lane:
#   herdr workspace list   -> workspace_id, label, tab_count, pane_count
#   herdr tab list         -> tab_id, workspace_id, label, agent_status
#   herdr pane list        -> pane_id, tab_id, workspace_id, agent, agent_status
#   state/<id>.meta        -> the lane's own record: harness, model, kind, window
#
# A lane is LIVE when its recorded window still resolves to a pane that Herdr
# still lists. A lane whose pane is gone is DEAD, whatever its status log
# says. A lane with no meta at all is UNKNOWN - not dead, not live.
#
# Nothing here writes. Nothing here reads a credential.

# shellcheck shell=bash
[ -n "${FM_SURFACE_CENSUS_LIB_LOADED:-}" ] && return 0
FM_SURFACE_CENSUS_LIB_LOADED=1

FM_SURFACE_CENSUS_SESSION=${FM_SURFACE_CENSUS_SESSION:-default}

# The field separator for every census row is U+001F UNIT SEPARATOR, never a
# tab. A tab is IFS WHITESPACE, so a read with IFS=tab silently collapses
# consecutive separators and every empty field shifts the columns after it to
# the left. A lane with no harness, no model or no workspace is NORMAL, not
# exceptional, so the separator must preserve empty fields.
FM_SURFACE_CENSUS_FS=$'\x1f'

# fm_surface_census_workspaces: "<workspace_id>\t<label>" per workspace.
fm_surface_census_workspaces() {  # [session]
  local session=${1:-$FM_SURFACE_CENSUS_SESSION} out
  out=$(herdr workspace list --session "$session" 2>/dev/null) || return 1
  printf '%s' "$out" | jq -r '
    (.result.workspaces // [])[]
    | [.workspace_id, (.label // "")] | join("\u001f")' 2>/dev/null
}

# fm_surface_census_tabs: "<tab_id>\t<workspace_id>\t<label>" per tab.
fm_surface_census_tabs() {  # [session]
  local session=${1:-$FM_SURFACE_CENSUS_SESSION} out
  out=$(herdr tab list --session "$session" 2>/dev/null) || return 1
  printf '%s' "$out" | jq -r '
    (.result.tabs // [])[]
    | [.tab_id, (.workspace_id // ""), (.label // "")] | join("\u001f")' 2>/dev/null
}

# fm_surface_census_panes: "<pane_id>\t<tab_id>\t<workspace_id>\t<agent>\t<agent_status>" per pane.
fm_surface_census_panes() {  # [session]
  local session=${1:-$FM_SURFACE_CENSUS_SESSION} out
  out=$(herdr pane list --session "$session" 2>/dev/null) || return 1
  printf '%s' "$out" | jq -r '
    (.result.panes // [])[]
    | [.pane_id, (.tab_id // ""), (.workspace_id // ""), (.agent // ""), (.agent_status // "")] | join("\u001f")' 2>/dev/null
}

# fm_surface_census_meta_value: one field of a lane's own meta record.
fm_surface_census_meta_value() {  # <state-dir> <lane-id> <key>
  local state=$1 id=$2 key=$3 meta="$1/$2.meta"
  [ -f "$meta" ] || return 1
  grep "^$key=" "$meta" 2>/dev/null | tail -1 | cut -d= -f2-
}

# fm_surface_census_lanes: one row per recorded lane of this home.
# "<lane-id>\037<window>\037<pane-id>\037<workspace-id>\037<harness>\037<model>\037<kind>\037<live:yes|no>\037<tab-id>"
# A lane whose recorded pane is gone is reported with live=no: it is a
# finished-but-unclosed agent, which is exactly what the Captain is asking to
# see, so it is reported, never hidden.
fm_surface_census_lanes() {  # [state-dir] [session]
  local state=${1:-${FM_STATE_OVERRIDE:-$FM_HOME/state}}
  local session=${2:-$FM_SURFACE_CENSUS_SESSION}
  local panes meta id window pane ws harness model kind live pane_full tab
  panes=$(fm_surface_census_panes "$session") || panes=""
  for meta in "$state"/*.meta; do
    [ -f "$meta" ] && [ ! -L "$meta" ] || continue
    id=${meta##*/}
    id=${id%.meta}
    case "$id" in ''|.*|*[!A-Za-z0-9._-]*) continue ;; esac
    window=$(fm_surface_census_meta_value "$state" "$id" window) || window=""
    pane=$(printf '%s' "$window" | awk -F: '{print $NF}')
    ws=$(printf '%s' "$window" | awk -F: '{print $(NF-1)}')
    # Herdr's pane list names a pane "<workspace>:<pane>"; the recorded window
    # names it "<session>:<workspace>:<pane>". Compare the FULL pane id.
    pane_full="$pane"
    [ -n "$ws" ] && pane_full="$ws:$pane"
    harness=$(fm_surface_census_meta_value "$state" "$id" harness) || harness=""
    model=$(fm_surface_census_meta_value "$state" "$id" model) || model=""
    kind=$(fm_surface_census_meta_value "$state" "$id" kind) || kind=""
    tab=$(fm_surface_census_meta_value "$state" "$id" herdr_tab_id) || tab=""
    live=no
    if [ -n "$pane_full" ] && printf '%s\n' "$panes" | awk -F'\037' -v p="$pane_full" '$1 == p { found = 1 } END { exit !(found) }'; then
      live=yes
    fi
    printf '%s\n' \
      "$id$FM_SURFACE_CENSUS_FS$window$FM_SURFACE_CENSUS_FS$pane_full$FM_SURFACE_CENSUS_FS$ws$FM_SURFACE_CENSUS_FS$harness$FM_SURFACE_CENSUS_FS$model$FM_SURFACE_CENSUS_FS$kind$FM_SURFACE_CENSUS_FS$live$FM_SURFACE_CENSUS_FS$tab"
  done
}

# fm_surface_census_live_lanes_in: the live lane ids hosted by one workspace.
fm_surface_census_live_lanes_in() {  # <workspace-id> [state-dir] [session]
  local ws=$1 state=${2:-${FM_STATE_OVERRIDE:-$FM_HOME/state}} session=${3:-$FM_SURFACE_CENSUS_SESSION}
  fm_surface_census_lanes "$state" "$session" \
    | awk -F'\037' -v w="$ws" '$4 == w && $8 == "yes" { print $1 }'
}

# fm_surface_census_task_tabs_in: the TASK TAB labels a workspace holds.
# A task tab is a tab whose label is "fm-<lane-id>"; any other tab is a free
# human tab (the Captain's own panes) and is not a lane.
fm_surface_census_task_tabs_in() {  # <workspace-id> [session]
  local ws=$1 session=${2:-$FM_SURFACE_CENSUS_SESSION}
  fm_surface_census_tabs "$session" \
    | awk -F'\037' -v w="$ws" '$2 == w && $3 ~ /^fm-/ { print $3 }'
}

# fm_surface_census_workspace_lane_count: how many task tabs a workspace holds.
fm_surface_census_workspace_lane_count() {  # <workspace-id> [session]
  fm_surface_census_task_tabs_in "$@" | grep -c '[^[:space:]]' || true
}

# fm_surface_census_workspace_live_count: how many live lanes a workspace has.
fm_surface_census_workspace_live_count() {  # <workspace-id> [state-dir] [session]
  fm_surface_census_live_lanes_in "$@" | grep -c '[^[:space:]]' || true
}
