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

# fm_surface_census_validates: is this herdr response a READABLE census
# collection?
#
# The census is EVIDENCE about a live surface, so a response that does not
# carry the expected structure is not an empty surface - it is an UNREADABLE
# one, and the two must never read the same. A reader that turned "unreadable"
# into "zero rows" made the visibility view print an all-zero census and the
# naming check print "OK every live workspace and task tab name conforms" for
# a surface it never read: a clean report for a census nobody took.
#
# The gate is therefore: the response must be an object whose "result" is an
# object, whose named collection is an ARRAY, and every element of that
# collection must carry a non-empty string id. Anything else fails, and the
# caller must report that it could not read the surface.
#
# <raw-json> <collection-key> <id-key>
fm_surface_census_validates() {  # <raw-json> <collection-key> <id-key>
  printf '%s' "$1" | jq -e --arg key "$2" --arg idkey "$3" '
    (.result | type == "object")
    and (.result[$key] | type == "array")
    and all(.result[$key][]; (.[$idkey] | type == "string") and (.[$idkey] | length > 0))
  ' >/dev/null 2>&1
}

# fm_surface_census_workspaces: "<workspace_id>\t<label>" per workspace.
fm_surface_census_workspaces() {  # [session]
  local session=${1:-$FM_SURFACE_CENSUS_SESSION} out
  out=$(herdr workspace list --session "$session" 2>/dev/null) || return 1
  fm_surface_census_validates "$out" workspaces workspace_id || return 1
  printf '%s' "$out" | jq -r '
    .result.workspaces[]
    | [.workspace_id, (.label // "")] | join("\u001f")' 2>/dev/null || return 1
}

# fm_surface_census_tabs: "<tab_id>\t<workspace_id>\t<label>" per tab.
fm_surface_census_tabs() {  # [session]
  local session=${1:-$FM_SURFACE_CENSUS_SESSION} out
  out=$(herdr tab list --session "$session" 2>/dev/null) || return 1
  fm_surface_census_validates "$out" tabs tab_id || return 1
  printf '%s' "$out" | jq -r '
    .result.tabs[]
    | [.tab_id, (.workspace_id // ""), (.label // "")] | join("\u001f")' 2>/dev/null || return 1
}

# fm_surface_census_panes: "<pane_id>\t<tab_id>\t<workspace_id>\t<agent>\t<agent_status>" per pane.
fm_surface_census_panes() {  # [session]
  local session=${1:-$FM_SURFACE_CENSUS_SESSION} out
  out=$(herdr pane list --session "$session" 2>/dev/null) || return 1
  fm_surface_census_validates "$out" panes pane_id || return 1
  printf '%s' "$out" | jq -r '
    .result.panes[]
    | [.pane_id, (.tab_id // ""), (.workspace_id // ""), (.agent // ""), (.agent_status // "")] | join("\u001f")' 2>/dev/null || return 1
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
  local panes meta id endpoint window pane ws harness model kind live pane_full tab
  local -a meta_files=()
  local -A seen_endpoint_ids=()
  panes=$(fm_surface_census_panes "$session") || return 1
  for meta in "$state"/*.meta; do
    [ -f "$meta" ] && [ ! -L "$meta" ] || continue
    id=${meta##*/}
    id=${id%.meta}
    case "$id" in ''|.*|*[!A-Za-z0-9._-]*) continue ;; esac
    case "$id" in lane-*) continue ;; esac
    meta_files+=("$meta")
  done
  for meta in "$state"/lane-*.meta; do
    [ -f "$meta" ] && [ ! -L "$meta" ] || continue
    id=${meta##*/}
    id=${id%.meta}
    case "$id" in ''|.*|*[!A-Za-z0-9._-]*) continue ;; esac
    meta_files+=("$meta")
  done
  for meta in "${meta_files[@]}"; do
    id=${meta##*/}
    id=${id%.meta}
    endpoint=$(fm_surface_census_meta_value "$state" "$id" endpoint_task_id) || endpoint=""
    [ -n "$endpoint" ] || endpoint=$id
    [ -z "${seen_endpoint_ids[$endpoint]+seen}" ] || continue
    seen_endpoint_ids[$endpoint]=1
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
      "$endpoint$FM_SURFACE_CENSUS_FS$window$FM_SURFACE_CENSUS_FS$pane_full$FM_SURFACE_CENSUS_FS$ws$FM_SURFACE_CENSUS_FS$harness$FM_SURFACE_CENSUS_FS$model$FM_SURFACE_CENSUS_FS$kind$FM_SURFACE_CENSUS_FS$live$FM_SURFACE_CENSUS_FS$tab"
  done
}

# fm_surface_census_task_tabs_in: the TASK TAB labels a workspace holds.
# A task tab is a tab whose label is "fm-<lane-id>"; any other tab is a free
# human tab (the Captain's own panes) and is not a lane.
#
# An unreadable tab census FAILS: an empty answer here would silently make
# every workspace look like it holds no lanes at all, which is the same
# fail-open census the readers above refuse.
fm_surface_census_task_tabs_in() {  # <workspace-id> [session]
  local ws=$1 session=${2:-$FM_SURFACE_CENSUS_SESSION} tabs
  tabs=$(fm_surface_census_tabs "$session") || return 1
  printf '%s' "$tabs" | awk -F'\037' -v w="$ws" '$2 == w && $3 ~ /^fm-/ { print $3 }'
}

