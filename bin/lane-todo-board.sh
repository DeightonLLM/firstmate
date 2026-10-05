#!/usr/bin/env bash
# lane-todo-board.sh - one screen that keeps EVERY active lane's To-Do list
# visible at the same time, in the captain-locked `todo-model-board` shape.
#
# Why: the captain watches a single surface to see which model is working what,
# on which surface, and how far each lane has actually got. Per-session trackers
# hide work that another lane owns; this board never hides any active lane.
#
# Data sources - local documented pieces only. No pane screen-scraping (alt-screen
# panes cannot be read programmatically), no process probing, no network, no
# state-changing work outside the explicit --init-lane scaffold:
#   1. state/lanes/<name>.lane registrations. Documented keys: pane=, artifact=,
#      note=. Also honored when present, so a lane can tag itself without
#      touching a crewmate's registration format: model=, surface=, task=.
#   2. state/<task>.status wake-event tails. A lane's task id is the first of
#      task=, the artifact's parent directory, the lane name, or the greatest
#      state/<lane-name>* record that actually exists.
#   3. state/lanes/<name>.todo.md, rendered VERBATIM so markdown checkboxes and
#      any captain-authored structure survive untouched. A lane registered only
#      by its todo file still gets a board row; archived lanes never do.
#   4. Optional enrichment (default on, `--no-meta` disables): state/<task>.meta
#      supplies model=, herdr_session=, and herdr_pane_id= when the lane file
#      does not declare them, so a live lane reads as a real model tag instead of
#      `unknown`. The lane file always wins over the meta record.
#
# Format per lane, honoring the todo-model-board `[model @ surface]` prefix:
#   [<model> @ <surface>·<pane>] <lane-name>
#   <verbatim state/lanes/<name>.todo.md, checkboxes and all>
#     status: <last wake-event line from state/<task>.status>
# Missing parts degrade honestly rather than disappearing: an unknown model or
# surface prints `unknown`, and a lane with no pane key drops the `·<pane>`
# segment instead of printing a dangling separator.
#
# Usage:
#   lane-todo-board.sh                  render the board for this home
#   lane-todo-board.sh --tail N         render with N status lines per lane
#   lane-todo-board.sh --no-meta        do not enrich from state/<task>.meta
#   lane-todo-board.sh --init-lane NAME scaffold state/lanes/NAME.todo.md
#   lane-todo-board.sh --help           print this usage
#
# Home resolution follows the rest of bin/: FM_HOME selects the home, with
# FM_ROOT_OVERRIDE and FM_STATE_OVERRIDE honored, so tests and secondmates can
# point the board at another state directory without touching the real one.
#
# Exit: 0 rendered or scaffolded, 1 usage error, 2 refused (scaffold exists).
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SELF_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
LANE_DIR="$STATE/lanes"
UNKNOWN="unknown"
TAIL_LINES=1
USE_META=1
INIT_LANE=""

usage() {
  cat <<'USAGE'
lane-todo-board.sh - one-screen To-Do board for every active lane.

Usage:
  lane-todo-board.sh                  render the board for this home
  lane-todo-board.sh --tail N         render with N status lines per lane
  lane-todo-board.sh --no-meta        do not enrich from state/<task>.meta
  lane-todo-board.sh --init-lane NAME scaffold state/lanes/NAME.todo.md
  lane-todo-board.sh --help           print this usage

Scaffold exit codes: 0 created, 1 invalid lane name, 2 refused (already exists).
USAGE
}

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

# First value of `key=` in a key=value registration or meta record. Tabs and
# spaces are trimmed; a missing key prints nothing and never fails the render.
record_field() {  # <file> <key>
  local file="$1" key="$2" line value
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "${line#"$key"=}" != "$line" ]; then
      value=$(trim_value "${line#"$key"=}")
      [ -n "$value" ] || return 0
      printf '%s\n' "$value"
      return 0
    fi
  done < "$file"
  return 0
}

lane_field() {  # <lane> <key>
  record_field "$LANE_DIR/$1.lane" "$2"
}

meta_field() {  # <task> <key>
  [ "$USE_META" -eq 1 ] || return 0
  record_field "$STATE/$1.meta" "$2"
}

task_record_exists() {
  [ -f "$STATE/$1.status" ] || [ -f "$STATE/$1.meta" ]
}

# Greatest state/<lane-name>* task id in C order, so a lane registered without a
# task id still finds a decorated task record (lane-x -> lane-x-20261005).
prefix_task() {
  local lane="$1" file base
  for file in "$STATE"/*.status "$STATE"/*.meta; do
    [ -f "$file" ] || continue
    base="${file##*/}"
    case "$base" in
      "$lane"*) printf '%s\n' "${base%%.*}" ;;
    esac
  done | LC_ALL=C sort | tail -n 1
}

resolve_task() {  # <lane> -> task id
  local lane="$1" explicit artifact parent fallback candidate
  explicit=$(lane_field "$lane" task)
  artifact=$(lane_field "$lane" artifact)
  fallback="$lane"
  if [ -n "$artifact" ]; then
    parent="${artifact%/*}"
    if [ "$parent" != "$artifact" ] && [ -n "$parent" ]; then
      fallback="${parent##*/}"
    fi
  fi
  for candidate in "$explicit" "$fallback" "$lane"; do
    [ -n "$candidate" ] || continue
    if task_record_exists "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  candidate=$(prefix_task "$lane")
  if [ -n "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  printf '%s\n' "$fallback"
}

# Every active lane name: the union of registrations and todo files, one row per
# name, C-sorted for a stable board. state/lanes/* globs never descend, so
# archived/ stays out.
lane_names() {
  local file base
  [ -d "$LANE_DIR" ] || return 0
  for file in "$LANE_DIR"/*.lane "$LANE_DIR"/*.todo.md; do
    [ -f "$file" ] || continue
    base="${file##*/}"
    case "$base" in
      *.todo.md) printf '%s\n' "${base%.todo.md}" ;;
      *.lane) printf '%s\n' "${base%.lane}" ;;
    esac
  done | LC_ALL=C sort -u
}

resolve_surface() {  # <lane> <task> <pane>
  local lane="$1" task="$2" pane="$3" surface window rest
  surface=$(lane_field "$lane" surface)
  if [ -z "$surface" ]; then
    surface=$(meta_field "$task" herdr_session)
  fi
  if [ -z "$surface" ]; then
    window=$(meta_field "$task" window)
    if [ -n "$window" ]; then
      surface="${window%%:*}"
    fi
  fi
  if [ -z "$surface" ]; then
    # Only a full session:workspace:pane pane id yields an honest surface; a bare
    # workspace:pane pair does not, so it stays `unknown` instead of inventing one.
    case "$pane" in
      *:*:*)
        rest="${pane#*:}"
        case "$rest" in
          *:*) surface="${pane%%:*}" ;;
        esac
        ;;
    esac
  fi
  [ -n "$surface" ] || surface="$UNKNOWN"
  printf '%s' "$surface"
}

print_status() {  # <task>
  local lines
  lines=$(tail -n "$TAIL_LINES" -- "$STATE/$1.status" 2>/dev/null | grep -v '^[[:space:]]*$')
  if [ -z "$lines" ]; then
    printf '  status: (none)\n'
    return 0
  fi
  printf '%s\n' "$lines" | sed 's/^/  status: /'
}

print_board_header() {  # <lane count>
  printf '=== lane todo board ===\n'
  printf 'lanes: %s | generated: %s\n' "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

render_board() {
  local lanes count lane task pane model surface header first=1
  lanes=$(lane_names)
  if [ -z "$lanes" ]; then
    print_board_header 0
    printf '  (no active lanes)\n'
    return 0
  fi
  count=$(printf '%s\n' "$lanes" | wc -l | tr -d '[:space:]')
  print_board_header "${count:-0}"
  while IFS= read -r lane; do
    [ -n "$lane" ] || continue
    task=$(resolve_task "$lane")
    pane=$(lane_field "$lane" pane)
    [ -n "$pane" ] || pane=$(meta_field "$task" herdr_pane_id)
    model=$(lane_field "$lane" model)
    [ -n "$model" ] || model=$(meta_field "$task" model)
    [ -n "$model" ] || model="$UNKNOWN"
    surface=$(resolve_surface "$lane" "$task" "$pane")
    if [ -n "$pane" ]; then
      header="[$model @ $surface·$pane] $lane"
    else
      header="[$model @ $surface] $lane"
    fi
    if [ "$first" -eq 0 ]; then
      printf '\n'
    fi
    first=0
    printf '%s\n' "$header"
    if [ -f "$LANE_DIR/$lane.todo.md" ]; then
      cat -- "$LANE_DIR/$lane.todo.md"
    else
      printf '(no todo file)\n'
    fi
    print_status "$task"
  done <<< "$lanes"
}

# Scaffold the five mandatory tracker items. Fail closed: an existing todo file
# is never overwritten, and a lane name must be a single plain path component.
init_lane() {
  local name="$1" file
  case "$name" in
    ''|-*|*[!A-Za-z0-9._-]*|*..*)
      printf 'lane-todo-board.sh: invalid lane name: %s\n' "$name" >&2
      return 1
      ;;
  esac
  file="$LANE_DIR/$name.todo.md"
  if [ -e "$file" ]; then
    printf 'lane-todo-board.sh: refused, todo file already exists: %s\n' "$file" >&2
    return 2
  fi
  if ! mkdir -p -- "$LANE_DIR"; then
    printf 'lane-todo-board.sh: cannot create lane directory: %s\n' "$LANE_DIR" >&2
    return 1
  fi
  if ! cat > "$file" <<SCAFFOLD
# todo: $name

- [ ] preflight - confirm tools, auth, and target state before changing anything
- [ ] scoped discovery - find the affected files and surfaces, record what is in scope
- [ ] bounded work/evidence - do one bounded piece of work and capture the evidence
- [ ] validation - run the checks that prove the work, and record the result
- [ ] postflight/closeout - reconcile state, record leftovers, and report the outcome
SCAFFOLD
  then
    printf 'lane-todo-board.sh: cannot write scaffold: %s\n' "$file" >&2
    return 1
  fi
  printf 'scaffolded: %s\n' "$file"
  printf 'hint: register state/lanes/%s.lane (pane=, artifact=, note=) so the board can tag the model and surface\n' \
    "$name"
  return 0
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --init-lane)
      if [ "$#" -lt 2 ]; then
        printf 'lane-todo-board.sh: --init-lane needs a lane name\n' >&2
        usage >&2
        exit 1
      fi
      INIT_LANE="$2"
      shift 2
      ;;
    --init-lane=*)
      INIT_LANE="${1#--init-lane=}"
      shift
      ;;
    --tail)
      if [ "$#" -lt 2 ]; then
        printf 'lane-todo-board.sh: --tail needs a line count\n' >&2
        usage >&2
        exit 1
      fi
      TAIL_LINES="$2"
      shift 2
      ;;
    --tail=*)
      TAIL_LINES="${1#--tail=}"
      shift
      ;;
    --no-meta)
      USE_META=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'lane-todo-board.sh: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$TAIL_LINES" in
  ''|*[!0-9]*)
    printf 'lane-todo-board.sh: --tail needs a positive integer, got: %s\n' "$TAIL_LINES" >&2
    exit 1
    ;;
esac
if [ "$TAIL_LINES" -lt 1 ]; then
  printf 'lane-todo-board.sh: --tail needs a positive integer, got: %s\n' "$TAIL_LINES" >&2
  exit 1
fi

if [ -n "$INIT_LANE" ]; then
  init_lane "$INIT_LANE"
  case "$?" in
    0) ;;
    1|2) exit "$?" ;;
  esac
fi

render_board
