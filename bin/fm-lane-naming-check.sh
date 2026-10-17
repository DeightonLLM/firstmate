#!/usr/bin/env bash
# bin/fm-lane-naming-check.sh - enforce the lane key and To-Do board naming
# convention from AGENT-TODO-PROMPT-STYLE.md.
#
# Lane key format:   <model>-<surface>-<task>  (lowercase, no spaces)
# To-Do board format: [<model> @ <surface>[/<pane>}] <action> — <state>
#
# Registry file format (data/async-lanes.tsv):
#   Comment lines beginning with '#' and blank lines are skipped.
#   Each data row is exactly 7 TAB-separated fields:
#     run_id  lane_key  model  surface  task  state  output
#   The lane_key segments are cross-checked against the separate model and
#   surface columns.
#
# Model aliases:  m2.7h (MiniMax M2.7 Highspeed), m2.7, m3.1f, luna6, glm5.3f, gem38f, pi
# Surface aliases: dubz, hd2, brandon, evps, firstmate
#
# Exit codes:
#   0  all inputs are valid
#   1  one or more inputs are invalid; offending values are named on stderr
#
# Usage:
#   fm-lane-naming-check.sh "<lane-key>"
#   fm-lane-naming-check.sh --stdin < state/<id>.status
#   cat list.txt | fm-lane-naming-check.sh
#   fm-lane-naming-check.sh data/async-lanes.tsv
#
# This check never edits or fixes the input; it only validates and reports.
# It is not yet wired into any launcher, so it cannot block a bad lane by itself.
set -u

# Canonical sets derived from AGENT-TODO-PROMPT-STYLE.md.
# Model aliases:  m2.7h (MiniMax M2.7 Highspeed), m2.7, m3.1f, luna6, glm5.3f, gem38f, pi
# Surface aliases: dubz, hd2, brandon, evps, firstmate

# Build anchored regex patterns (anchored so partial matches are not accepted).
_model_pat='m2\.7h|m2\.7|m3\.1f|luna6|glm5\.3f|gem38f|pi'
_surface_pat='dubz|hd2|brandon|evps|firstmate'

# Lane key: <model>-<surface>-<task>
#   model: one of the canonical aliases (may contain '.' like m2.7)
#   surface: one of the canonical aliases
#   task: any lowercase alphanumeric with hyphens (may include '.')
_lane_key_pat="^($_model_pat)-($_surface_pat)-[a-z0-9.-]+$"

# UUID pattern for run_id field (8-4-4-4-12 hex digits).
_uuid_pat='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

# --- validate a single string (lane key or board line) --------------------

check_one() {
  local input=$1

  # Strip surrounding whitespace for robust comparison.
  input=$(printf '%s' "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Empty line: skip silently.
  [ -n "$input" ] || return 0

  # Try lane-key format: <model>-<surface>-<task>
  if printf '%s\n' "$input" | grep -qE "^($_model_pat)-($_surface_pat)-[a-z0-9.-]+$"; then
    return 0
  fi

  # Try board-line format: [<model> @ <surface>[/<pane>}] <action> — <state>
  # Requires [ at the start, a known model, @, a known surface or surface/pane, ], space.
  if printf '%s\n' "$input" | grep -qE "^\[(($_model_pat)) @ (([[:lower:][:digit:]]+(/[[:lower:][:digit:]]+)?))\] "; then
    return 0
  fi

  # Not a valid lane key or board line.
  printf 'invalid lane key or board line: %s\n' "$input" >&2
  return 1
}

# --- validate a registry file ---------------------------------------------

# extract_segment <key> <pos>: extract the model (pos=1) or surface (pos=2) segment
# from a lane key. Returns empty if the key does not have the expected structure.
extract_segment() {
  local key=$1 pos=$2
  # Split on '-' and return field $pos.
  # Using bash built-in rather than external cut for portability.
  local IFS='-' i segment
  set -- $key
  for i in 1 2 3; do
    segment=$1
    shift
    [ "$i" -eq "$pos" ] && { printf '%s\n' "$segment"; return 0; }
  done
  return 1
}

check_registry_file() {
  local file=$1
  local line_num=0
  local failed=0

  while IFS= read -r line || [ -n "$line" ]; do
    line_num=$((line_num + 1))

    # Strip surrounding whitespace.
    line=$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip comment lines and blank lines.
    [ -n "$line" ] || continue
    case "$line" in
      '#'*) continue ;;
    esac

    # Split on TAB into exactly 7 fields.
    local IFS=$'\t'
    set -f
    set -- $line
    set +f
    local field_count=$#

    if [ "$field_count" -ne 7 ]; then
      printf '%s: line %d: expected 7 TAB fields, found %d: %s\n' \
        "$file" "$line_num" "$field_count" "$line" >&2
      failed=1
      continue
    fi

    local run_id=$1 lane_key=$2 model=$3 surface=$4
    # shellcheck disable=SC2034
    local _task=$5 _state=$6 _output=$7

    # Validate run_id is a UUID.
    if ! printf '%s\n' "$run_id" | grep -qE "$_uuid_pat"; then
      printf '%s: line %d: run_id is not a valid UUID: %s\n' \
        "$file" "$line_num" "$run_id" >&2
      failed=1
    fi

    # Validate lane_key format.
    if ! printf '%s\n' "$lane_key" | grep -qE "$_lane_key_pat"; then
      printf '%s: line %d: lane_key is not valid: %s\n' \
        "$file" "$line_num" "$lane_key" >&2
      failed=1
    else
      # Cross-check: lane_key model segment must match the model column.
      local key_model
      key_model=$(extract_segment "$lane_key" 1) || key_model=""
      if [ -n "$key_model" ] && [ "$key_model" != "$model" ]; then
        printf '%s: line %d: lane_key model segment "%s" disagrees with model column "%s"\n' \
          "$file" "$line_num" "$key_model" "$model" >&2
        failed=1
      fi

      # Cross-check: lane_key surface segment must match the surface column.
      local key_surface
      key_surface=$(extract_segment "$lane_key" 2) || key_surface=""
      if [ -n "$key_surface" ] && [ "$key_surface" != "$surface" ]; then
        printf '%s: line %d: lane_key surface segment "%s" disagrees with surface column "%s"\n' \
          "$file" "$line_num" "$key_surface" "$surface" >&2
        failed=1
      fi
    fi
  done < "$file"

  return "$failed"
}

# --- dispatch --------------------------------------------------------------

if [ $# -eq 1 ] && [ -f "$1" ]; then
  # Single argument is an existing file: treat as registry file.
  check_registry_file "$1"
else
  # Otherwise: check each positional argument as a string, or read stdin.
  if [ $# -gt 0 ]; then
    failed=0
    for arg in "$@"; do
      check_one "$arg" || failed=1
    done
    exit "$failed"
  else
    # Stdin mode: read lines until EOF.
    failed=0
    while IFS= read -r line || [ -n "$line" ]; do
      check_one "$line" || failed=1
    done
    exit "$failed"
  fi
fi
