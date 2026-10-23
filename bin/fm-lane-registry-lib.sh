#!/usr/bin/env bash
# shellcheck disable=SC2034 # parsed fields are output globals for sourcing callers.
# Shared writer for the fleet's live-lane registry (state/lanes/<name>.lane).
#
# ONE registry, TWO readers that already exist and are not owned here:
#   1. /root/bin/factory-safetynet.sh - a HOST script outside this repo. It
#      counts a live lane from a registration when ALL of these hold: the
#      registration carries a pane= key; its artifact= file does not already
#      contain the literal "VERDICT:"; and its pane is present in the current
#      herdr layout. A registration failing any of those is reported to the
#      safety net log as a STALE REGISTRATION, never as a live lane.
#   2. bin/lane-todo-board.sh and bin/lane-todo-dash.sh - this repo's own fleet
#      board. They read pane=, artifact=, note=, and honour the enrichment keys
#      model=, surface=, task=, host=, compaction_headroom_pct= when present.
#      The lane file always wins over the linked task's meta record.
#
# THE WRITER IS THE MISSING PIECE. The reader above was already correct; the
# registry had exactly one stale hand-written registration and nothing in this
# repo ever wrote it, so the safety net counted zero lanes while two ran.
#
# THE CONTRACT, and the one judgement call in it:
#   pane=     REQUIRED. The herdr pane id of the lane, taken from the task's
#             own recorded herdr_pane_id. Only a herdr pane id (or the host
#             script's ssh:host:pane form) can be resolved against a live
#             layout, so a lane on a backend the host script cannot see is
#             deliberately NOT registered - a registration whose pane is not in
#             the layout is logged as stale, which would be false noise.
#   artifact= The lane's LIVE work list: state/lanes/<name>.todo.md.
#             It is deliberately NOT the lane's report. The host script retires
#             a registration whose artifact already carries "VERDICT:", and a
#             fleet report ends in "VERDICT: PASS" by contract (see the lane
#             report format), so an artifact= pointing at the report would
#             exclude a lane that is still live and not yet reaped - the wrong
#             reason for the exclusion, and the reason it was invisible in the
#             log. The live work list never carries a verdict, so THE LANE
#             BEING GONE is the only reason a registration stops counting.
#   task=     The task id, so the board resolves the lane's status record
#             exactly instead of guessing it from a path.
#   model=    Enrichment: the model tag the board prints.
#   surface=  Enrichment: the session the lane runs in, the same value the
#             board would otherwise derive from the task meta's herdr_session.
#   report=   The lane's deliverable path (data/<id>/report.md). No reader
#             parses it; it is here so the registration still names the
#             deliverable without pointing artifact= at a verdict-carrying file.
#   note=     Free text for a human reading the registry.
#
# A retired lane is excluded by the teardown path REMOVING its registration
# (and archiving it under state/lanes/archived/, which no reader globs into),
# never by the text of its artifact.
#
# This library is a leaf: sourcing it has no side effects, and every function
# takes explicit paths so a test can point it at a throwaway home.

FM_LANE_REGISTRY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# A lane name is one plain path component: no separators, no traversal, no
# leading dash. Anything else is refused rather than sanitised, because a
# silently rewritten name would register one lane under a name the teardown
# path could not derive back from the task id.
fm_lane_registry_valid_name() {
  local name=$1
  case "$name" in
    ''|-*) return 1 ;;
    *[!A-Za-z0-9._-]*) return 1 ;;
    *..*) return 1 ;;
  esac
  return 0
}

fm_lane_registry_lane_dir() {  # <state dir>
  printf '%s\n' "$1/lanes"
}

fm_lane_registry_lane_file() {  # <state dir> <lane>
  printf '%s\n' "$(fm_lane_registry_lane_dir "$1")/$2.lane"
}

fm_lane_registry_todo_file() {  # <state dir> <lane>
  printf '%s\n' "$(fm_lane_registry_lane_dir "$1")/$2.todo.md"
}

# The registration's artifact= value: the lane's live work list, written
# home-relative because the host safety net resolves it against its REPO root,
# which is the primary home's root.
fm_lane_registry_artifact_path() {  # <state dir> <lane>
  printf '%s\n' "state/lanes/$2.todo.md"
}

# A value must stay on one line: a newline would forge a second key in the
# registration and corrupt every reader's first-match-wins parse.
fm_lane_registry_sanitize() {  # <value>
  printf '%s' "$1" | tr '\n' ' ' | tr -d '\r'
}

# The lane's live work list. The to-do file's format has exactly one owner -
# bin/lane-todo-board.sh --init-lane, which is also the board's reader for it -
# so the registry asks that owner to create it instead of keeping a second copy
# of the five mandatory items here. The board refuses to overwrite an existing
# file, which is the behaviour wanted here: an existing lane keeps its list.
# 0 when the list exists (created now or already there), 1 when it could not
# be created. A missing list is not fatal for the safety net: the artifact
# check then finds no file, so the registration still counts as live.
fm_lane_registry_ensure_todo() {  # <state dir> <lane>
  local state_dir=$1 lane=$2 board out rc
  fm_lane_registry_valid_name "$lane" || return 1
  [ -f "$(fm_lane_registry_todo_file "$state_dir" "$lane")" ] && return 0
  board="$FM_LANE_REGISTRY_LIB_DIR/lane-todo-board.sh"
  [ -x "$board" ] || return 1
  out=$(FM_STATE_OVERRIDE="$state_dir" bash "$board" --init-lane "$lane" 2>&1)
  rc=$?
  case "$rc" in
    0) return 0 ;;
    2) return 0 ;;  # already scaffolded
  esac
  printf 'fm-lane-registry: could not scaffold the lane work list: %s\n' "$out" >&2
  return 1
}

# Write one registration. Atomic: a reader never sees a half-written file.
fm_lane_registry_write() {  # <state dir> <lane> <pane> <task> <model> <surface> <report> <note>
  local state_dir=$1 lane=$2 pane=$3 task=$4 model=$5 surface=$6 report=$7 note=$8
  local lane_dir file tmp
  fm_lane_registry_valid_name "$lane" || {
    printf 'fm-lane-registry: refusing an unsafe lane name: %s\n' "$lane" >&2
    return 1
  }
  [ -n "$pane" ] || {
    printf 'fm-lane-registry: refusing to register %s without a pane id\n' "$lane" >&2
    return 1
  }
  lane_dir=$(fm_lane_registry_lane_dir "$state_dir")
  mkdir -p "$lane_dir" || return 1
  file="$lane_dir/$lane.lane"
  tmp=$(mktemp "$lane_dir/.${lane}.lane.XXXXXX") || return 1
  {
    printf 'pane=%s\n' "$(fm_lane_registry_sanitize "$pane")"
    printf 'artifact=%s\n' "$(fm_lane_registry_artifact_path "$state_dir" "$lane")"
    printf 'task=%s\n' "$(fm_lane_registry_sanitize "$task")"
    printf 'model=%s\n' "$(fm_lane_registry_sanitize "$model")"
    printf 'surface=%s\n' "$(fm_lane_registry_sanitize "$surface")"
    printf 'report=%s\n' "$(fm_lane_registry_sanitize "$report")"
    printf 'note=%s\n' "$(fm_lane_registry_sanitize "$note")"
  } > "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$file" || { rm -f "$tmp"; return 1; }
  return 0
}

# Retire a lane: the registration AND its live work list leave the active
# directory. Both are archived under state/lanes/archived/, which no reader
# globs into (the board's glob never descends, and neither does the host
# script's), so an archived lane is history, not live work.
# The history is kept because the registry is the fleet's record of what ran:
# a captain asking "which lane owned this pane last week" has no other source.
# 0 when the lane is retired or was already absent, 1 on a write failure.
fm_lane_registry_retire() {  # <state dir> <lane>
  local state_dir=$1 lane=$2 lane_dir stamp file archived
  fm_lane_registry_valid_name "$lane" || {
    printf 'fm-lane-registry: refusing an unsafe lane name: %s\n' "$lane" >&2
    return 1
  }
  lane_dir=$(fm_lane_registry_lane_dir "$state_dir")
  stamp=$(date -u +%Y%m%d-%H%M%S)
  archived="$lane_dir/archived"
  mkdir -p "$archived" || return 1
  file="$lane_dir/$lane.lane"
  if [ -f "$file" ]; then
    mv -f "$file" "$archived/$lane.$stamp.lane" || return 1
  fi
  file="$lane_dir/$lane.todo.md"
  if [ -f "$file" ]; then
    mv -f "$file" "$archived/$lane.$stamp.todo.md" || return 1
  fi
  return 0
}

# The lane a task id owns. The task id IS the lane name, so the spawn path and
# the teardown path derive the same name without a second mapping to drift.
fm_lane_registry_lane_name() {  # <task id>
  local task=$1
  fm_lane_registry_valid_name "$task" || return 1
  printf '%s\n' "$task"
}

# WHICH LANES GET A REGISTRATION. One decision, one owner, so the spawn path
# and its test cannot drift apart.
#   0 = register, 1 = do not register.
# The rules, and why each one exists:
#   - kind=secondmate: NO. A secondmate is a separate home with its own FM_HOME
#     and its own state/lanes/. The safety net reads the PRIMARY home, so a
#     secondmate registered here would count as primary live work - and it would
#     keep the no-live-lanes alarm silent while the primary runs no crewmate
#     lane at all, which is the dead alarm this registry must never create. The
#     secondmate's OWN home registers its own crewmates through the same code.
#   - no pane id: NO. The host reader counts a registration only when its pane
#     is in the current herdr layout; a registration without a resolvable pane
#     is logged as a stale registration, which is false noise, not live work.
#   - the PRIMARY's own session: NO, and that is enforced by the firstmate not
#     spawning itself. The primary is always alive, so a registration for it
#     would make the no-live-lanes alarm incapable of ever firing again.
fm_lane_registry_should_register() {  # <kind> <pane>
  local kind=$1 pane=$2
  [ "$kind" = secondmate ] && return 1
  [ -n "$pane" ] || return 1
  return 0
}

