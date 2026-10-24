#!/usr/bin/env bash
# bin/fm-surface-name-lib.sh - the single owner of the VISIBLE SURFACE NAME
# grammar for every agent container this fleet shows a human.
#
# docs/surface-naming-contract.md owns the RULE. This file owns the exact
# bytes. Every producer of a visible surface name (the Herdr adapter, the
# away-mode launcher, the visibility view, the enforcement check) builds its
# labels here, so the rule cannot drift between the places that write a name
# and the place that checks one.
#
# The problem this exists for: a Captain looking at the Herdr spaces sidebar
# saw "firstmate", "firstmate-afk-daemon-659043-363-1792753227" and
# "2ndmate-mcode-runner". Those strings name an implementation detail, not an
# agent. Nothing on the left said WHICH SURFACE was running the work, WHICH
# lane it was, or whether the thing was even alive.
#
# The grammar (see the contract doc for the prose):
#
#   scope            := host "/" home [ "/" role ]
#   host             := "hetz" | "controller" | "hd2" | "local"
#   home             := "primary" | "2ndmate-" <secondmate-id>
#   role             := lowercase token, e.g. "afk", "older"
#   workspace label  := scope " · " summary
#   summary          := <lane-id>
#                     | "<N> lanes"
#                     | "no lanes"
#                     | "afk-daemon " <nonce>
#   projection label := "└ " scope " · " <lane-id> " · p:" <token>
#   task tab label   := "fm-" <lane-id>
#
# The separator is U+00B7 MIDDLE DOT with one space on each side - the same
# byte sequence the existing Herdr projection labels already use, so the two
# forms read as one scheme.
#
# A scope is the machine-matchable part of a workspace label: it is everything
# before the first separator. The matcher in bin/backends/herdr.sh resolves a
# home's container by SCOPE, never by the whole label, so a container may say
# how many lanes it holds without changing which home owns it.
#
# Legacy labels ("firstmate", "2ndmate-<id>", "firstmate-afk-daemon-...") are
# still recognised by the matcher so a fleet that has not been renamed yet
# keeps working. They are NOT conforming under this rule; bin/fm-surface-name-check.sh
# reports them.

# shellcheck shell=bash
[ -n "${FM_SURFACE_NAME_LIB_LOADED:-}" ] && return 0
FM_SURFACE_NAME_LIB_LOADED=1

# The visible separator: SPACE, U+00B7 MIDDLE DOT, SPACE.
FM_SURFACE_NAME_SEP=' · '

# The projection marker: U+2514 BOX DRAWINGS LIGHT UP AND RIGHT, SPACE.
FM_SURFACE_NAME_PROJECTION_MARK='└ '

# fm_surface_name_host: the machine token for the host this home runs on.
#
# The host table is derived from SURFACE-IDENTITY.md, which is the single
# authority for which machine an alias or hostname names. The mapping is by
# HOSTNAME, never by an inferred identity: an unrecognised host is "local",
# never a guess at one of the named surfaces. FM_SURFACE_HOST overrides it
# explicitly for a home that runs somewhere the table does not know (a lab
# session, a second installation on the same machine).
fm_surface_name_host() {
  if [ -n "${FM_SURFACE_HOST:-}" ]; then
    printf '%s' "$FM_SURFACE_HOST"
    return 0
  fi
  local host
  host=$(hostname 2>/dev/null || printf '')
  case "$host" in
    brandon-compute*) printf 'hetz' ;;
    vmi3196300*)      printf 'controller' ;;
    vmi3238503*)      printf 'hd2' ;;
    *)                printf 'local' ;;
  esac
}

# fm_surface_name_home_id: the secondmate id of a home, or non-zero when the
# home is a PRIMARY home. The marker is the one bin/fm-home-seed.sh writes.
fm_surface_name_home_id() {  # <home-dir>
  local marker="$1/.fm-secondmate-home" id
  [ -f "$marker" ] || return 1
  id=$(tr -d '[:space:]' < "$marker" 2>/dev/null) || return 1
  [ -n "$id" ] || return 1
  printf '%s' "$id"
}

# fm_surface_name_home_scope: the home segment of a scope.
fm_surface_name_home_scope() {  # <home-dir>
  local id
  if id=$(fm_surface_name_home_id "${1:-${FM_HOME:-}}"); then
    printf '2ndmate-%s' "$id"
  else
    printf 'primary'
  fi
}

# fm_surface_name_scope: the scope token for a home, optionally with a role.
#   <host>/<home>            the home's canonical container
#   <host>/<home>/<role>     a container of that home with a stated role
fm_surface_name_scope() {  # <home-dir> [role]
  local home role
  home=$(fm_surface_name_home_scope "${1:-${FM_HOME:-}}")
  role=${2:-}
  if [ -n "$role" ]; then
    printf '%s/%s/%s' "$(fm_surface_name_host)" "$home" "$role"
  else
    printf '%s/%s' "$(fm_surface_name_host)" "$home"
  fi
}

fm_surface_name_lane_id_valid() {  # <lane-id>
  case "$1" in
    ''|*[!A-Za-z0-9._-]*) return 1 ;;
  esac
  return 0
}

# fm_surface_name_scope_valid: is this a scope token the rule allows?
fm_surface_name_scope_valid() {  # <scope>
  local scope=$1 host home role rest
  case "$scope" in
    ''|*[!a-z0-9._/-]*) return 1 ;;
  esac
  host=${scope%%/*}
  [ -n "$host" ] && [ "$host" != "$scope" ] || return 1
  rest=${scope#*/}
  home=${rest%%/*}
  [ -n "$home" ] || return 1
  case "$home" in
    primary) ;;
    2ndmate-*)
      [ "${home#2ndmate-}" != "$home" ] || return 1
      [ -n "${home#2ndmate-}" ] || return 1
      ;;
    *) return 1 ;;
  esac
  if [ "$rest" != "$home" ]; then
    role=${rest#*/}
    [ -n "$role" ] || return 1
    case "$role" in *[!a-z0-9._-]*|*/*) return 1 ;; esac
  fi
  return 0
}

# fm_surface_name_workspace_label: the visible name of an agent container.
fm_surface_name_workspace_label() {  # <scope> <summary>
  printf '%s%s%s' "$1" "$FM_SURFACE_NAME_SEP" "$2"
}

# fm_surface_name_lane_summary: the summary for a container that hosts lanes.
#
# One hosted lane reads AS that lane, because a container that hosts exactly
# one crewmate is that crewmate's container and the Captain asked for it to
# read that way. More than one reads as a count of the task tabs the
# container holds. Zero reads as "no lanes".
#
# The count is of TASK TABS, not of historical records: it says what the
# container physically holds right now. WHETHER each of those lanes is alive
# is a separate question, answered by bin/fm-surface-view.sh, which is the
# instrument that distinguishes LIVE, IDLE, BLOCKED and DONE.
fm_surface_name_lane_summary() {  # <task-tab-count> [single-lane-id]
  local count=${1:-0} single=${2:-}
  case "$count" in
    ''|*[!0-9]*) count=0 ;;
  esac
  if [ "$count" -eq 1 ] && fm_surface_name_lane_id_valid "$single"; then
    printf '%s' "$single"
    return 0
  fi
  if [ "$count" -eq 0 ]; then
    printf 'no lanes'
    return 0
  fi
  printf '%s lanes' "$count"
}

# fm_surface_name_projection_label: the visible name of a disposable
# one-lane presentation space. The trailing token stays the last field: the
# session-start cleanup in bin/fm-herdr-session-cleanup.sh discovers these
# spaces by the exact "MARK <anything> SEP p:<22-char-token>" grammar.
fm_surface_name_projection_label() {  # <scope> <lane-label> <token>
  printf '%s%s%s%s%sp:%s' \
    "$FM_SURFACE_NAME_PROJECTION_MARK" \
    "$1" "$FM_SURFACE_NAME_SEP" \
    "$2" "$FM_SURFACE_NAME_SEP" \
    "$3"
}

# fm_surface_name_nonce: a short discriminator for containers that several
# homes or several daemons can share. Eight hex characters; a fallback of the
# launching pid and the current epoch when /dev/urandom is unreadable.
fm_surface_name_nonce() {
  local n=''
  if [ -r /dev/urandom ]; then
    n=$(od -An -N4 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')
  fi
  case "$n" in
    ''|*[!0-9a-f]*) n=$(printf '%04x%04x' "$(( $$ & 0xffff ))" "$(( ${EPOCHSECONDS:-0} & 0xffff ))") ;;
  esac
  printf '%s' "$n"
}

# fm_surface_name_scope_of: the scope field of any visible surface label.
# Everything before the first separator, with a projection marker stripped.
fm_surface_name_scope_of() {  # <label>
  local label=$1
  case "$label" in
    "$FM_SURFACE_NAME_PROJECTION_MARK"*) label=${label#"$FM_SURFACE_NAME_PROJECTION_MARK"} ;;
  esac
  printf '%s' "${label%%"$FM_SURFACE_NAME_SEP"*}"
}

# fm_surface_name_is_projection: is this label a presentation space?
fm_surface_name_is_projection() {  # <label>
  case "$1" in
    "$FM_SURFACE_NAME_PROJECTION_MARK"*) return 0 ;;
    *) return 1 ;;
  esac
}

# fm_surface_name_legacy_scope: the legacy scope token of a legacy label, or
# non-zero when the label is not a legacy home label. Legacy home labels are
# "firstmate" and "2ndmate-<id>" with no separator and no role.
fm_surface_name_legacy_scope() {  # <label>
  case "$1" in
    firstmate) printf 'firstmate'; return 0 ;;
    2ndmate-*)
      case "$1" in */*|*"$FM_SURFACE_NAME_SEP"*) return 1 ;; esac
      printf '%s' "$1"
      return 0
      ;;
    *) return 1 ;;
  esac
}

# fm_surface_name_legacy_home_label: the legacy home label of a scope, used
# only so a fleet that has not been renamed yet still resolves to the same
# container. "hetz/primary" -> "firstmate", "hetz/2ndmate-<id>" ->
# "2ndmate-<id>". Empty when the scope has no legacy equivalent.
fm_surface_name_legacy_home_label() {  # <scope>
  case "$1" in
    */primary) printf 'firstmate'; return 0 ;;
    */2ndmate-*) printf '%s' "${1##*/}"; return 0 ;;
    *) return 1 ;;
  esac
}

# fm_surface_name_legacy_afk: the legacy scope token of a legacy away-mode
# daemon label ("firstmate-afk-daemon-<pid>-<n>-<ts>").
fm_surface_name_legacy_afk() {  # <label>
  case "$1" in
    firstmate-afk-daemon-*|2ndmate-*-afk-daemon-*)
      printf '%s' "${1%%-afk-daemon-*}"
      return 0
      ;;
    *) return 1 ;;
  esac
}

# fm_surface_name_workspace_conforms: does this workspace label satisfy the
# rule? A scope alone is conforming (a container that has not been summarised
# yet); a scope plus a summary is conforming when the summary is one of the
# allowed forms.
fm_surface_name_workspace_conforms() {  # <label>
  local label=$1 scope summary
  [ -n "$label" ] || return 1
  if fm_surface_name_is_projection "$label"; then
    fm_surface_name_projection_conforms "$label"
    return $?
  fi
  scope=$(fm_surface_name_scope_of "$label")
  fm_surface_name_scope_valid "$scope" || return 1
  case "$label" in
    *"$FM_SURFACE_NAME_SEP"*)
      summary=${label#*"$FM_SURFACE_NAME_SEP"}
      fm_surface_name_summary_conforms "$summary" || return 1
      ;;
    *)
      # scope alone: conforming, but unsummaryed
      ;;
  esac
  return 0
}

fm_surface_name_summary_conforms() {  # <summary>
  local summary=$1
  if fm_surface_name_lane_id_valid "$summary"; then
    return 0
  fi
  [[ "$summary" =~ ^[0-9]+\ lanes$ ]] && return 0
  case "$summary" in
    "no lanes"|"afk-daemon "[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
      return 0
      ;;
  esac
  return 1
}

# fm_surface_name_projection_conforms: does this presentation-space label
# satisfy the rule? "MARK <scope> SEP <lane> SEP p:<22-char-token>"
fm_surface_name_projection_conforms() {  # <label>
  local label=$1 rest scope remainder lane suffix token
  case "$label" in
    "$FM_SURFACE_NAME_PROJECTION_MARK"*) ;;
    *) return 1 ;;
  esac
  rest=${label#"$FM_SURFACE_NAME_PROJECTION_MARK"}
  scope=${rest%%"$FM_SURFACE_NAME_SEP"*}
  [ "$scope" != "$rest" ] || return 1
  fm_surface_name_scope_valid "$scope" || return 1
  remainder=${rest#"$scope$FM_SURFACE_NAME_SEP"}
  lane=${remainder%%"$FM_SURFACE_NAME_SEP"*}
  [ "$lane" != "$remainder" ] || return 1
  fm_surface_name_lane_id_valid "$lane" || return 1
  suffix=${remainder#"$lane$FM_SURFACE_NAME_SEP"}
  case "$suffix" in
    p:*) token=${suffix#p:} ;;
    *) return 1 ;;
  esac
  [ "${#token}" -eq 22 ] || return 1
  case "$token" in *[!A-Za-z0-9_-]*) return 1 ;; esac
  return 0
}

# fm_surface_name_tab_conforms: does this task tab label satisfy the rule?
# A task tab label is "fm-<lane-id>". The tab label is the LANE identity and
# is the string bin/backends/herdr.sh matches for recovery and orphan
# discovery, so it is deliberately NOT decorated with the scope: the scope
# lives on the workspace that contains the tab.
fm_surface_name_tab_conforms() {  # <label>
  local label=$1
  case "$label" in
    fm-*) : ;;
    *) return 1 ;;
  esac
  local lane=${label#fm-}
  [ -n "$lane" ] || return 1
  fm_surface_name_lane_id_valid "$lane"
}

# fm_surface_name_lane_of_tab: the lane id a task tab label names.
fm_surface_name_lane_of_tab() {  # <tab-label>
  case "$1" in
    fm-*) printf '%s' "${1#fm-}" ;;
    *) return 1 ;;
  esac
}
