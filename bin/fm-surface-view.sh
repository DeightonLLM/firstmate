#!/usr/bin/env bash
# fm-surface-view.sh - ONE command that shows the Captain which surface is
# running which agent, in what state, with what harness and model.
#
# Why this exists: on 2026-10-24 the Captain looked at the Herdr spaces
# sidebar and saw "firstmate", "firstmate-afk-daemon-659043-363-1792753227"
# and "2ndmate-mcode-runner". Nothing there said which surface was running the
# work, which lane it was, whether it was alive, or whether a finished agent
# was still occupying a pane. A finished-but-unclosed agent was invisible.
#
# What it reads (all read-only, no credential is ever read):
#   herdr workspace list / tab list / pane list   the live surface
#   state/<id>.meta                                the lane's own record
#   bin/fm-crew-state.sh <id>                      the house's authoritative
#                                                  CURRENT-STATE reader
#
# bin/fm-fleet-ledger.sh is a WRITE-only appender for the fleet activity
# ledger, and bin/build-next-board.py reads the Core repository's ops lane
# ledger - neither is a census of the Herdr agent surface, so neither is used
# here as one. The current-state verdict comes from bin/fm-crew-state.sh,
# which is the house's single owner of that answer.
#
# STATE is one of:
#   LIVE     the agent is working (herdr says working, or the crew-state
#            reader says working)
#   IDLE     the agent is present and not known to be working
#   BLOCKED  the agent is parked on a gate or reported blocked
#   DONE     the agent reported a terminal completion
#   FAILED   the agent reported a failure
#   UNKNOWN  no state source at all
# A lane whose recorded pane is GONE is printed with a "pane gone" note and is
# counted separately as STALE: it is a finished-but-unclosed agent, and it is
# the thing the Captain asked to see.
#
# Usage:
#   bin/fm-surface-view.sh [--json] [--wide] [--session <name>] [--home <dir>]
#
#   --json    machine-readable output (one object per lane)
#   --wide    print full lane ids instead of the middle-truncated form
#   --session herdr session name (default: default)
#   --home    the firstmate home whose lanes to read (default: FM_HOME)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"

# shellcheck source=bin/fm-surface-name-lib.sh
. "$SCRIPT_DIR/fm-surface-name-lib.sh"
# shellcheck source=bin/fm-surface-census-lib.sh
. "$SCRIPT_DIR/fm-surface-census-lib.sh"

JSON=0
WIDE=0
SESSION="default"
HOME_ARG=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --wide) WIDE=1; shift ;;
    --session) SESSION=${2:-}; shift 2 ;;
    --home) HOME_ARG=${2:-}; shift 2 ;;
    -h|--help) sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "fm-surface-view.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$SESSION" ] || { echo "fm-surface-view.sh: --session needs a value" >&2; exit 2; }
if [ -n "$HOME_ARG" ]; then
  HOME_ARG=$(CDPATH='' cd -- "$HOME_ARG" 2>/dev/null && pwd -P) || {
    echo "fm-surface-view.sh: --home cannot be resolved: $HOME_ARG" >&2; exit 2; }
  STATE="$HOME_ARG/state"
fi
FM_SURFACE_CENSUS_SESSION=$SESSION

command -v herdr >/dev/null 2>&1 || {
  echo "fm-surface-view.sh: the herdr CLI is required for a live surface census" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || {
  echo "fm-surface-view.sh: jq is required" >&2; exit 1; }

# --- evidence ---------------------------------------------------------------

WORKSPACES=$(fm_surface_census_workspaces "$SESSION") || {
  echo "fm-surface-view.sh: could not read herdr workspaces in session '$SESSION'" >&2; exit 1; }
TABS=$(fm_surface_census_tabs "$SESSION") || {
  echo "fm-surface-view.sh: could not read herdr tabs in session '$SESSION'" >&2; exit 1; }
PANES=$(fm_surface_census_panes "$SESSION") || {
  echo "fm-surface-view.sh: could not read herdr panes in session '$SESSION'" >&2; exit 1; }
LANES=$(fm_surface_census_lanes "$STATE" "$SESSION") || {
  echo "fm-surface-view.sh: could not read herdr lane metadata in session '$SESSION'" >&2; exit 1; }

ws_label() {  # <workspace-id>
  printf '%s\n' "$WORKSPACES" | awk -F'\037' -v w="$1" '$1 == w { print $2; exit }'
}
ws_of_pane() {  # <pane-id>
  printf '%s\n' "$PANES" | awk -F'\037' -v p="$1" '$1 == p { print $3; exit }'
}
pane_agent_status() {  # <pane-id>
  printf '%s\n' "$PANES" | awk -F'\037' -v p="$1" '$1 == p { print $5; exit }'
}
tab_id_of_lane() {  # <lane-id> -> the id of the task tab carrying it
  printf '%s\n' "$TABS" | awk -F'\037' -v l="$1" '$3 == "fm-" l { print $1; exit }'
}

# --- state verdict ----------------------------------------------------------

# crew_state_line <lane-id> -> the house's current-state line, or empty.
crew_state_line() {  # <lane-id>
  local out
  out=$(FM_HOME="${HOME_ARG:-$FM_HOME}" FM_STATE_OVERRIDE="$STATE" \
    timeout 20 bash "$SCRIPT_DIR/fm-crew-state.sh" "$1" 2>/dev/null | head -1) || out=""
  printf '%s' "$out"
}

# verdict <lane-id> <herdr-agent-status> <live:yes|no> -> STATE
#
# The crew-state reader is the authority for a TERMINAL verdict (done, failed,
# blocked). Herdr's own pane agent_status is the authority for "is it moving
# right now". A lane whose recorded pane is gone is GONE, never DONE: calling
# it DONE would claim a completion nobody reported, which is the exact
# finished-but-unclosed case the Captain is asking to see.
verdict() {  # <lane-id> <herdr-status> <live>
  local id=$1 herdr_status=$2 live=$3 line verb
  if [ "$live" = no ]; then
    printf 'GONE'
    return 0
  fi
  line=$(crew_state_line "$id")
  verb=""
  case "$line" in
    state:*) verb=${line#state: }; verb=${verb%% *} ;;
  esac
  case "$verb" in
    done) printf 'DONE'; return 0 ;;
    failed) printf 'FAILED'; return 0 ;;
    blocked|parked) printf 'BLOCKED'; return 0 ;;
    working) printf 'LIVE'; return 0 ;;
  esac
  case "$herdr_status" in
    working) printf 'LIVE'; return 0 ;;
    idle) printf 'IDLE'; return 0 ;;
  esac
  printf 'UNKNOWN'
}

# --- build the rows ---------------------------------------------------------

# Each row: workspace_id, workspace_label, scope, lane, tab, pane, harness,
# model, kind, state, live, note
ROWS=""
STATE_COUNT_LIVE=0
STATE_COUNT_IDLE=0
STATE_COUNT_BLOCKED=0
STATE_COUNT_DONE=0
STATE_COUNT_FAILED=0
STATE_COUNT_UNKNOWN=0
STATE_COUNT_GONE=0
STALE_COUNT=0

# The census row carries NINE fields. Reading fewer would fold the trailing
# tab id into the last variable, which silently corrupts every column after
# it. Read all nine, always.
while IFS=$'\037' read -r id window pane ws harness model kind live ltab; do
  [ -n "$id" ] || continue
  wsid=$ws
  [ -n "$wsid" ] || wsid=$(ws_of_pane "$pane")
  label=$(ws_label "$wsid")
  scope=$(fm_surface_name_scope_of "$label")
  [ -n "$scope" ] || scope="unknown"
  tab=${ltab:-}
  [ -n "$tab" ] || tab=$(tab_id_of_lane "$id")
  [ -n "$tab" ] || tab="-"
  herdr_status=$(pane_agent_status "$pane")
  [ -n "$herdr_status" ] || herdr_status="unknown"
  state=$(verdict "$id" "$herdr_status" "$live")
  note=""
  if [ "$live" = no ]; then
    note="pane gone"
    STALE_COUNT=$(( STALE_COUNT + 1 ))
  fi
  case "$state" in
    LIVE) STATE_COUNT_LIVE=$(( STATE_COUNT_LIVE + 1 )) ;;
    IDLE) STATE_COUNT_IDLE=$(( STATE_COUNT_IDLE + 1 )) ;;
    BLOCKED) STATE_COUNT_BLOCKED=$(( STATE_COUNT_BLOCKED + 1 )) ;;
    DONE) STATE_COUNT_DONE=$(( STATE_COUNT_DONE + 1 )) ;;
    FAILED) STATE_COUNT_FAILED=$(( STATE_COUNT_FAILED + 1 )) ;;
    GONE) STATE_COUNT_GONE=$(( STATE_COUNT_GONE + 1 )) ;;
    *) STATE_COUNT_UNKNOWN=$(( STATE_COUNT_UNKNOWN + 1 )) ;;
  esac
  ROWS="${ROWS}${wsid}"$'\037'"${label}"$'\037'"${scope}"$'\037'"${id}"$'\037'"${tab}"$'\037'"${pane}"$'\037'"${harness}"$'\037'"${model}"$'\037'"${kind}"$'\037'"${state}"$'\037'"${live}"$'\037'"${note}"$'\n'
done <<< "$LANES"

# --- output -----------------------------------------------------------------

if [ "$JSON" = 1 ]; then
  printf '{\n  "session": %s,\n  "generated": %s,\n  "summary": {"live": %s, "idle": %s, "blocked": %s, "done": %s, "failed": %s, "gone": %s, "unknown": %s},\n  "lanes": [\n' \
    "$(printf '%s' "$SESSION" | jq -R .)" \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ' | jq -R .)" \
    "$STATE_COUNT_LIVE" "$STATE_COUNT_IDLE" "$STATE_COUNT_BLOCKED" \
    "$STATE_COUNT_DONE" "$STATE_COUNT_FAILED" "$STATE_COUNT_GONE" "$STATE_COUNT_UNKNOWN"
  first=1
  while IFS=$'\037' read -r wsid label scope id tab pane harness model kind state live note; do
    [ -n "$id" ] || continue
    [ "$first" = 1 ] || printf ',\n'
    first=0
    jq -cn --arg ws "$wsid" --arg wslabel "$label" --arg scope "$scope" \
      --arg lane "$id" --arg tab "$tab" --arg pane "$pane" --arg harness "$harness" \
      --arg model "$model" --arg kind "$kind" --arg state "$state" \
      --arg live "$live" --arg note "$note" \
      '{workspace: $ws, workspace_label: $wslabel, surface: $scope, lane: $lane,
        tab: $tab, pane: $pane, harness: $harness, model: $model, kind: $kind,
        state: $state, live: ($live == "yes"), note: (if $note == "" then null else $note end)}'
  done <<< "$ROWS"
  printf '\n  ]\n}\n'
  exit 0
fi

trunc_mid() {  # <text> <width>
  local text=$1 width=$2
  if [ "$WIDE" = 1 ] || [ "${#text}" -le "$width" ]; then
    printf '%s' "$text"
    return 0
  fi
  local keep=$(( width - 1 ))
  local head=$(( keep / 3 ))
  local tail=$(( keep - head ))
  printf '%s…%s' "${text:0:$head}" "${text: -$tail}"
}

trunc_tail() {  # <text> <width>
  local text=$1 width=$2
  if [ "$WIDE" = 1 ] || [ "${#text}" -le "$width" ]; then
    printf '%s' "$text"
    return 0
  fi
  printf '…%s' "${text: -$(( width - 1 ))}"
}

printf '=== SURFACE VIEW === session=%s home=%s generated=%s\n' \
  "$SESSION" "${HOME_ARG:-${FM_HOME}}" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf 'LIVE %s | IDLE %s | BLOCKED %s | DONE %s | FAILED %s | GONE %s | UNKNOWN %s\n' \
  "$STATE_COUNT_LIVE" "$STATE_COUNT_IDLE" "$STATE_COUNT_BLOCKED" \
  "$STATE_COUNT_DONE" "$STATE_COUNT_FAILED" "$STATE_COUNT_GONE" "$STATE_COUNT_UNKNOWN"
printf '\n'

# Sort the rows FIRST (surface, then workspace, then lane) so the grouped
# output below is a stable read. Grouping a sorted stream and then sorting
# the rendered text would scramble the headers.
SORTED_ROWS=$(printf '%s' "$ROWS" | LC_ALL=C sort -t$'\037' -k3,3 -k1,1 -k4,4)

CURRENT_SCOPE=""
CURRENT_WS=""
while IFS=$'\037' read -r wsid label scope id tab pane harness model kind state live note; do
  [ -n "$id" ] || continue
  if [ "$scope" != "$CURRENT_SCOPE" ]; then
    CURRENT_SCOPE=$scope
    CURRENT_WS=""
    printf -- '-- surface %s --\n' "$CURRENT_SCOPE"
    printf '%-8s %-46s %-12s %-12s %-14s %-26s %s\n' \
      STATE LANE TAB PANE HARNESS MODEL NOTE
  fi
  if [ "$wsid" != "$CURRENT_WS" ]; then
    CURRENT_WS=$wsid
    printf '   workspace %s [%s]\n' "$label" "$wsid"
  fi
  printf '%-8s %-46s %-12s %-12s %-14s %-26s %s\n' \
    "$state" \
    "$(trunc_mid "$id" 46)" \
    "$(trunc_mid "$tab" 12)" \
    "$(trunc_mid "$pane" 12)" \
    "$(trunc_mid "$harness" 14)" \
    "$(trunc_tail "$model" 26)" \
    "$note"
done <<< "$SORTED_ROWS"

# Containers with no recorded lane are still surface the Captain can see.
printf '\n-- containers with no recorded lane --\n'
EMPTY_LISTED=0
while IFS=$'\037' read -r wsid label; do
  [ -n "$wsid" ] || continue
  if printf '%s\n' "$ROWS" | awk -F'\037' -v w="$wsid" '$1 == w { found = 1 } END { exit !(found) }'; then
    continue
  fi
  EMPTY_LISTED=1
  printf '   %-52s [%s]\n' "$label" "$wsid"
done <<< "$WORKSPACES"
[ "$EMPTY_LISTED" = 1 ] || printf '   (none)\n'
exit 0
