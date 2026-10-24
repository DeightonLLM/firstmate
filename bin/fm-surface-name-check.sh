#!/usr/bin/env bash
# fm-surface-name-check.sh - fail when a LIVE agent surface name does not
# conform to docs/surface-naming-contract.md.
#
# Why this exists: a rule stated in a document is a request. The Captain asked
# for the global naming to be "SET AND ENFORCED TO ALL AGENTS". This is the
# enforcement half: it reads the live Herdr surface (or a snapshot of it) and
# exits non-zero the moment a workspace or a task tab carries a name the
# contract does not allow.
#
# What it checks:
#   1. Every workspace label is a SCOPE (host/home[/role]) with an optional
#      summary. A legacy label ("firstmate", "2ndmate-<id>",
#      "firstmate-afk-daemon-<pid>-<n>-<ts>") is a violation with a known
#      replacement, and is reported with that replacement, not just flagged.
#   2. Every TAB that a lane record points at carries that lane's task tab
#      label "fm-<lane-id>". A tab that no lane record points at is a free
#      human tab and is reported as informational, not as a violation.
#   3. A projection (presentation space) label is the projection grammar.
#   4. A lane of THIS home may not sit in another home's container.
#
# What it never does: close a pane, close a workspace, kill a process, or
# touch any state file. --apply RENAMES a workspace and nothing else.
#
# Usage:
#   bin/fm-surface-name-check.sh [--session <name>] [--home <dir>] [--scope-map <file>]
#   bin/fm-surface-name-check.sh --from-file <snapshot> [--home <dir>]
#   bin/fm-surface-name-check.sh --apply [--session <name>] [--home <dir>] [--scope-map <file>]
#
#   --from-file  check a snapshot instead of the live surface. Each line is
#                "<workspace|tab>\t<id>\t<label>". Used by the test suite and
#                by any surface that cannot be reached from this host.
#   --scope-map  a file of "<workspace_id>\t<scope>" lines that says which
#                scope a workspace belongs to when its own label does not
#                carry one. A scope the operator assigned once.
#   --apply      rename the offending WORKSPACES to their conforming label.
#                Never renames a tab, never closes anything.
#
# Exit status: 0 when every name conforms, 1 when at least one name violates
# the contract, 2 on a usage error, 3 when the surface could not be read.
#
# A workspace whose LANE COUNT could not be read is an unknown state, not a
# violation with a "no lanes" replacement: --apply never renames a workspace
# on a lane count nobody read.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"

# shellcheck source=bin/fm-surface-name-lib.sh
. "$SCRIPT_DIR/fm-surface-name-lib.sh"
# shellcheck source=bin/fm-surface-census-lib.sh
. "$SCRIPT_DIR/fm-surface-census-lib.sh"

SESSION="default"
HOME_ARG=""
FROM_FILE=""
SCOPE_MAP=""
APPLY=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --session) SESSION=${2:-}; shift 2 ;;
    --home) HOME_ARG=${2:-}; shift 2 ;;
    --from-file) FROM_FILE=${2:-}; shift 2 ;;
    --scope-map) SCOPE_MAP=${2:-}; shift 2 ;;
    --apply) APPLY=1; shift ;;
    -h|--help) sed -n '2,50p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "fm-surface-name-check.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$SESSION" ] || { echo "fm-surface-name-check.sh: --session needs a value" >&2; exit 2; }
if [ -n "$HOME_ARG" ]; then
  HOME_ARG=$(CDPATH='' cd -- "$HOME_ARG" 2>/dev/null && pwd -P) || {
    echo "fm-surface-name-check.sh: --home cannot be resolved: $HOME_ARG" >&2; exit 2; }
  STATE="$HOME_ARG/state"
fi
FM_SURFACE_CENSUS_SESSION=$SESSION

HOME_SCOPE=$(fm_surface_name_scope "$HOME_ARG")

# --- evidence ---------------------------------------------------------------

WORKSPACES=""
TABS=""
LANES=""
if [ -n "$FROM_FILE" ]; then
  [ -f "$FROM_FILE" ] || { echo "fm-surface-name-check.sh: --from-file cannot be read: $FROM_FILE" >&2; exit 2; }
  # A snapshot line is "<workspace|tab> TAB <id> TAB <label>". Tabs are
  # accepted because a snapshot is written by hand; the internal rows use the
  # unit separator so empty fields survive.
  while IFS=$'\037' read -r kind id label; do
    [ -n "$kind" ] || continue
    case "$kind" in
      workspace) WORKSPACES="${WORKSPACES}${id}"$'\037'"${label}"$'\n' ;;
      tab) TABS="${TABS}${id}"$'\037'"-"$'\037'"${label}"$'\n' ;;
      *) : ;;
    esac
  done < <(awk -F'\t' 'NF >= 3 { printf "%s\037%s\037%s\n", $1, $2, $3 }' "$FROM_FILE")
else
  command -v herdr >/dev/null 2>&1 || {
    echo "fm-surface-name-check.sh: the herdr CLI is required (or pass --from-file)" >&2; exit 3; }
  WORKSPACES=$(fm_surface_census_workspaces "$SESSION") || {
    echo "fm-surface-name-check.sh: could not read herdr workspaces in session '$SESSION'" >&2; exit 3; }
  TABS=$(fm_surface_census_tabs "$SESSION") || {
    echo "fm-surface-name-check.sh: could not read herdr tabs in session '$SESSION'" >&2; exit 3; }
  LANES=$(fm_surface_census_lanes "$STATE" "$SESSION") || {
    echo "fm-surface-name-check.sh: could not read herdr panes or lane metadata" >&2; exit 3;
  }
fi

# --- scope resolution -------------------------------------------------------

scope_map_scope() {  # <workspace-id>
  if [ -z "$SCOPE_MAP" ]; then
    # A durable default: the home may record which scope a workspace belongs
    # to once, in its own config, so the mapping survives a reboot and a
    # second operator does not have to rediscover it.
    SCOPE_MAP="$HOME_ARG/config/surface-name-scopes"
    [ -n "$HOME_ARG" ] || SCOPE_MAP="$FM_HOME/config/surface-name-scopes"
  fi
  [ -n "$SCOPE_MAP" ] || return 1
  [ -f "$SCOPE_MAP" ] || return 1
  local id=$1 out
  out=$(awk -F'[\037\t]' -v w="$id" '$1 == w { print $2; exit }' "$SCOPE_MAP" 2>/dev/null) || return 1
  [ -n "$out" ] || return 1
  fm_surface_name_scope_valid "$out" || return 1
  printf '%s' "$out"
}

# legacy_scope_to_scope: a legacy home token becomes a scope's home segment.
legacy_scope_to_scope() {  # <legacy-token>
  case "$1" in
    firstmate) printf 'primary' ;;
    2ndmate-*) [ -n "${1#2ndmate-}" ] || return 1; printf '%s' "$1" ;;
    *) return 1 ;;
  esac
}

# scope_for_label <workspace-id> <label>: the scope a label should have.
scope_for_label() {  # <workspace-id> <label>
  local wsid=$1 label=$2 scope legacy
  scope=$(scope_map_scope "$wsid") && { printf '%s' "$scope"; return 0; }
  scope=$(fm_surface_name_scope_of "$label")
  if fm_surface_name_scope_valid "$scope"; then
    printf '%s' "$scope"
    return 0
  fi
  if legacy=$(fm_surface_name_legacy_scope "$label"); then
    printf '%s/%s' "$(fm_surface_name_host)" "$(legacy_scope_to_scope "$legacy")"
    return 0
  fi
  if legacy=$(fm_surface_name_legacy_afk "$label"); then
    printf '%s/%s/afk' "$(fm_surface_name_host)" "$(legacy_scope_to_scope "$legacy")"
    return 0
  fi
  return 1
}

# nonce_for_label <label>: the discriminator of an away-mode daemon label.
nonce_for_label() {  # <label>
  local label=$1 tail
  case "$label" in
    *afk-daemon*)
      tail=${label##*afk-daemon}
      tail=${tail# }
      tail=${tail#-}
      # A legacy tail is the old "<pid>-<random>-<epoch>" noise, and its pid
      # belonged to the launcher that had already exited. Keep a tail that is
      # already a clean discriminator; otherwise mint a fresh short one.
      case "$tail" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) printf '%s' "$tail"; return 0 ;;
      esac
      fm_surface_name_nonce
      return 0
      ;;
  esac
  return 1
}

# task_tab_lanes <workspace-id>: the lane ids of the task tabs a workspace holds.
#
# The exit status IS the census read's status.  A census that could not be
# read is UNKNOWN, never "this workspace holds no lanes": the count this feeds
# is written into a live workspace label, and "no lanes" on a two-lane
# container is a false statement about the fleet that --apply would persist.
task_tab_lanes() {  # <workspace-id>
  local wsid=$1 tabs tab
  [ -n "$FROM_FILE" ] && return 0
  tabs=$(fm_surface_census_task_tabs_in "$wsid" "$SESSION") || return 1
  printf '%s\n' "$tabs" | while IFS= read -r tab; do
    [ -n "$tab" ] || continue
    fm_surface_name_lane_of_tab "$tab" 2>/dev/null && printf '\n'
  done
}

# target_label <workspace-id> <current-label>
#
# Exit status: 0 = a conforming replacement was printed; 1 = no replacement
# could be computed from the label alone (the scope itself is unknown);
# 2 = the lane census could not be read, so the lane count is UNKNOWN.  A
# replacement is NEVER derived from a failed read: the lane count of a
# workspace that could not be counted is not zero, it is unknown.
target_label() {  # <workspace-id> <current-label>
  local wsid=$1 label=$2 scope lanes count single nonce lane
  scope=$(scope_for_label "$wsid" "$label") || return 1
  case "$scope" in
    */afk)
      nonce=$(nonce_for_label "$label") || nonce="$(fm_surface_name_nonce)"
      printf '%s' "$(fm_surface_name_workspace_label "$scope" "afk-daemon $nonce")"
      return 0
      ;;
  esac
  lanes=$(task_tab_lanes "$wsid") || return 2
  count=$(printf '%s\n' "$lanes" | grep -c '[^[:space:]]' || true)
  single=""
  if [ "$count" -eq 1 ]; then
    single=$(printf '%s\n' "$lanes" | head -1)
  fi
  printf '%s' "$(fm_surface_name_workspace_label "$scope" "$(fm_surface_name_lane_summary "$count" "$single")")"
}

# target_projection_label <current-label>
target_projection_label() {  # <current-label>
  local label=$1 rest scope remainder lane suffix token
  case "$label" in
    "$FM_SURFACE_NAME_PROJECTION_MARK"*) rest=${label#"$FM_SURFACE_NAME_PROJECTION_MARK"} ;;
    *) return 1 ;;
  esac
  scope=${rest%%"$FM_SURFACE_NAME_SEP"*}
  [ "$scope" != "$rest" ] || return 1
  fm_surface_name_scope_valid "$scope" || return 1
  remainder=${rest#"$scope$FM_SURFACE_NAME_SEP"}
  lane=${remainder%%"$FM_SURFACE_NAME_SEP"*}
  [ "$lane" != "$remainder" ] || return 1
  fm_surface_name_lane_id_valid "$lane" || return 1
  suffix=${remainder#"$lane$FM_SURFACE_NAME_SEP"}
  case "$suffix" in p:*) token=${suffix#p:} ;; *) return 1 ;; esac
  [ "${#token}" -eq 22 ] || return 1
  case "$token" in *[!A-Za-z0-9_-]*) return 1 ;; esac
  printf '%s' "$(fm_surface_name_projection_label "$scope" "$lane" "$token")"
}

# --- the check --------------------------------------------------------------

VIOLATIONS=0
INFO=0
UNKNOWN=0
# The computed target label for every offending workspace, so the suggestion
# printed here and the rename --apply performs are the SAME string.
TARGETS=""

report() {  # <id> <label> <reason> <replacement>
  VIOLATIONS=$(( VIOLATIONS + 1 ))
  printf 'surface-name: %s [%s] %s\n' "$1" "$2" "$3"
  if [ -n "${4:-}" ]; then
    printf 'surface-name: %s should read: %s\n' "$1" "$4"
  fi
}

record_target() {  # <workspace-id> <target-label>
  TARGETS="${TARGETS}$1"$'\037'"$2"$'\n'
}

NOTE_SHOWN=0
note() {  # <text>
  INFO=$(( INFO + 1 ))
  NOTE_SHOWN=$(( NOTE_SHOWN + 1 ))
  if [ "$NOTE_SHOWN" -le 10 ]; then
    printf 'surface-name: note: %s\n' "$1"
  elif [ "$NOTE_SHOWN" -eq 11 ]; then
    printf 'surface-name: note: ... and further free human tabs not listed\n'
  fi
}

while IFS=$'\037' read -r wsid label; do
  [ -n "$wsid" ] || continue
  if fm_surface_name_is_projection "$label"; then
    if ! fm_surface_name_projection_conforms "$label"; then
      replacement=$(target_projection_label "$label" || printf '')
      report "workspace $wsid" "$label" "does not match the projection grammar" "$replacement"
      [ -n "$replacement" ] && record_target "$wsid" "$replacement"
    fi
    continue
  fi
  if fm_surface_name_workspace_conforms "$label"; then
    continue
  fi
  replacement=$(target_label "$wsid" "$label")
  target_status=$?
  case "$target_status" in
    0) ;;
    2)
      # The lane count is UNKNOWN: the task tab census could not be read, so
      # the workspace's lane count cannot be computed.  It is reported as an
      # unknown state and NEVER as a violation with a "no lanes" replacement:
      # --apply must not rename a workspace on a count nobody read.
      UNKNOWN=$(( UNKNOWN + 1 ))
      printf 'surface-name: workspace %s [%s] lane count is unknown (the task tab census could not be read); no replacement was computed\n' "$wsid" "$label"
      continue
      ;;
    *) replacement="" ;;
  esac
  report "workspace $wsid" "$label" "does not conform to the surface naming contract" "$replacement"
  [ -n "$replacement" ] && record_target "$wsid" "$replacement"
done <<< "$WORKSPACES"

# Tabs: the tab a lane record names must carry that lane's task tab label.
# A tab no lane record names is a free human tab (the Captain's own panes),
# which is reported as a note and never as a violation.
if [ -n "$LANES" ]; then
  while IFS=$'\037' read -r lid _ _ _ _ _ _ _ ltab; do
    [ -n "$lid" ] || continue
    [ -n "$ltab" ] || continue
    label=$(printf '%s\n' "$TABS" | awk -F'\037' -v t="$ltab" '$1 == t { print $3; exit }')
    [ -n "$label" ] || continue
    if [ "$label" = "fm-$lid" ]; then
      continue
    fi
    report "tab $ltab" "$label" "does not carry the task tab label of its lane" "fm-$lid"
  done <<< "$LANES"
  while IFS=$'\037' read -r tabid wsid label; do
    [ -n "$tabid" ] || continue
    if printf '%s\n' "$LANES" | awk -F'\037' -v t="$tabid" '$9 == t { found = 1 } END { exit !(found) }'; then
      continue
    fi
    note "tab $tabid [$label] is not a recorded task tab"
  done <<< "$TABS"
else
  # No lane records at all (a snapshot): every tab is judged by the task tab
  # grammar on its own, because there is nothing to associate it with.
  while IFS=$'\037' read -r tabid wsid label; do
    [ -n "$tabid" ] || continue
    fm_surface_name_tab_conforms "$label" && continue
    report "tab $tabid" "$label" "is not a task tab label (fm-<lane-id>)" ""
  done <<< "$TABS"
fi

# A lane of THIS home may not sit inside another home's container.
while IFS=$'\037' read -r id _ pane ws _ _ kind _; do
  [ -n "$id" ] || continue
  [ -n "$ws" ] || continue
  # A secondmate lane is RECORDED in the primary home's state on purpose: the
  # primary is the only dispatch authority and its secondmate launch is
  # recorded here. Its container belongs to that secondmate's home by design,
  # so the cross-home rule does not apply to it.
  [ "$kind" = secondmate ] && continue
  label=$(printf '%s\n' "$WORKSPACES" | awk -F'\037' -v w="$ws" '$1 == w { print $2; exit }')
  [ -n "$label" ] || continue
  scope=$(scope_for_label "$ws" "$label") || continue
  case "$scope" in
    "$HOME_SCOPE"|"$HOME_SCOPE/"*) : ;;
    *) report "lane $id" "$label" "sits in another home's container" "" ;;
  esac
done <<< "$LANES"

if [ "$VIOLATIONS" -eq 0 ] && [ "$UNKNOWN" -eq 0 ]; then
  printf 'surface-name: OK every live workspace and task tab name conforms\n'
  exit 0
fi

if [ "$VIOLATIONS" -eq 0 ]; then
  # Nothing was wrong with the names that could be read, but at least one
  # workspace could not be checked at all: the surface could not be read, so
  # this is a read failure (3), never a clean report.
  printf 'surface-name: %s workspace(s) could not be checked: the task tab census could not be read\n' "$UNKNOWN"
  exit 3
fi

if [ "$UNKNOWN" -gt 0 ]; then
  printf 'surface-name: %s violation(s), %s note(s), %s unknown lane count(s)\n' "$VIOLATIONS" "$INFO" "$UNKNOWN"
else
  printf 'surface-name: %s violation(s), %s note(s)\n' "$VIOLATIONS" "$INFO"
fi

if [ "$APPLY" = 1 ] && [ -z "$FROM_FILE" ]; then
  command -v herdr >/dev/null 2>&1 || {
    echo "fm-surface-name-check.sh: --apply needs the herdr CLI" >&2; exit 3; }
  printf 'surface-name: applying workspace renames (renames only; nothing is closed)\n'
  while IFS=$'\037' read -r wsid new_label; do
    [ -n "$wsid" ] || continue
    [ -n "$new_label" ] || continue
    if herdr workspace rename "$wsid" "$new_label" --session "$SESSION" >/dev/null 2>&1; then
      printf 'surface-name: renamed %s -> %s\n' "$wsid" "$new_label"
    else
      printf 'surface-name: FAILED to rename %s -> %s\n' "$wsid" "$new_label" >&2
      VIOLATIONS=$(( VIOLATIONS + 1 ))
    fi
  done <<< "$TARGETS"
fi

exit 1
