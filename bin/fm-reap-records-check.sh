#!/usr/bin/env bash
# bin/fm-reap-records-check.sh - enforce the reap-with-records convention.
#
# Standing rule: when a pane is closed or reaped, its status and meta records
# must be archived together in the same action. A status file with no matching
# .meta is an orphan. Registered secondmates are excluded from the orphan count
# and reported separately as "registered secondmate without live metadata".
#
# This check NEVER deletes or edits any file.
#
# Two modes:
#
#   --scan <state-dir> <secondmates-md>
#     Scans <state-dir> for *.status files. For each, checks whether a matching
#     *.meta exists. Excludes secondmates registered in <secondmates-md>.
#     Exits non-zero if any genuine orphan is found; zero if only registered
#     secondmates are affected.
#
#   --pane-id <pane-id> <state-dir> <secondmates-md>
#     Answers whether a live metadata record for <pane-id> still exists.
#     Exits 0 if <state-dir>/<pane-id>.meta is present; non-zero otherwise.
#     (Does not treat secondmate status as orphan in this mode; the question
#     is "is there a live metadata record?", not "is this pane reaped cleanly?")
#
# Exit codes:
#   0  no genuine orphans (scan); live metadata exists (pane-id)
#   1  one or more genuine orphans (scan); no live metadata (pane-id); error
set -u

# --- parse secondmates.md --------------------------------------------------
#
# Extracts every registered secondmate id from the file. Each entry starts with
# "- <id>" on its own line. Returns one id per line on stdout.

parse_secondmates() {
  local file=$1
  grep -E '^[[:space:]]*-[[:space:]]+[^[:space:]]+' "$file" \
    | sed 's/^[[:space:]]*-[[:space:]]\+//' \
    | sed 's/[[:space:]].*//' \
    | grep -v '^$'
}

# --- is_registered_secondmate <id> <secondmates-md> -----------------------
# Returns 0 if <id> appears as a registered secondmate, 1 otherwise.

is_registered_secondmate() {
  local id=$1 sm_file=$2
  parse_secondmates "$sm_file" | grep -qxF "$id"
}

# --- scan mode --------------------------------------------------------------

do_scan() {
  local state_dir=$1 sm_file=$2
  local has_orphan=0

  # Iterate every *.status file in the state directory.
  for status_file in "$state_dir"/*.status; do
    [ -e "$status_file" ] || continue

    # Extract pane id from filename.
    local id
    id=$(basename "$status_file" .status)

    # Check for matching meta.
    local meta_file="${state_dir}/${id}.meta"

    if [ -f "$meta_file" ]; then
      # Paired: status + meta both present. Clean.
      continue
    fi

    # No meta found. Is this a registered secondmate?
    if is_registered_secondmate "$id" "$sm_file"; then
      printf 'registered secondmate without live metadata: %s.status\n' "$id" >&2
      continue
    fi

    # Genuine orphan.
    printf 'orphan status (no matching meta): %s.status\n' "$id" >&2
    has_orphan=1
  done

  if [ "$has_orphan" -eq 1 ]; then
    return 1
  fi
  return 0
}

# --- pane-id mode -----------------------------------------------------------

do_pane_id() {
  local pane_id=$1 state_dir=$2 sm_file=$3
  local meta_file="${state_dir}/${pane_id}.meta"

  if [ -f "$meta_file" ]; then
    printf 'live metadata present: %s.meta\n' "$pane_id"
    return 0
  fi

  # No meta file.
  if is_registered_secondmate "$pane_id" "$sm_file"; then
    printf 'no live metadata (registered secondmate): %s.meta\n' "$pane_id" >&2
  else
    printf 'no live metadata: %s.meta\n' "$pane_id" >&2
  fi
  return 1
}

# --- dispatch ---------------------------------------------------------------

usage() {
  printf 'Usage:\n' >&2
  printf '  fm-reap-records-check.sh --scan <state-dir> <secondmates-md>\n' >&2
  printf '  fm-reap-records-check.sh --pane-id <pane-id> <state-dir> <secondmates-md>\n' >&2
}

main() {
  if [ $# -lt 1 ]; then
    usage
    exit 1
  fi

  case "$1" in
    --scan)
      if [ $# -ne 3 ]; then
        usage
        exit 1
      fi
      [ -d "$2" ] || { printf 'state directory not found: %s\n' "$2" >&2; exit 1; }
      [ -f "$3" ] || { printf 'secondmates.md not found: %s\n' "$3" >&2; exit 1; }
      do_scan "$2" "$3"
      ;;
    --pane-id)
      if [ $# -ne 4 ]; then
        usage
        exit 1
      fi
      [ -d "$3" ] || { printf 'state directory not found: %s\n' "$3" >&2; exit 1; }
      [ -f "$4" ] || { printf 'secondmates.md not found: %s\n' "$4" >&2; exit 1; }
      do_pane_id "$2" "$3" "$4"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
