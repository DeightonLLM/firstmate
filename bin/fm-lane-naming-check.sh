#!/usr/bin/env bash
# bin/fm-lane-naming-check.sh - the lane naming entry point.
#
# THIS SCRIPT DELEGATES. It owns no alias table, no pattern and no rule of its
# own. bin/fm-todo-prefix-check.sh is the single owner of the naming
# vocabulary, and docs/todo-prefix-canonical-format.md is the human-readable
# contract. Two copies of the vocabulary is how the three-segment and
# four-segment lane keys drifted apart in the first place, so there is exactly
# one copy now and this entry point forwards to it. The messages it prints are
# the owner's messages, because they name the offending input and the expected
# shape.
#
# Lane key format:   <harness>-<model>-<host>-<task>  (lowercase, no spaces)
# To-Do board row:   [<harness>·<ModelAbbrev> <effort> @<Host>] <action> - <state>
#
# The harness segment is NOT optional: without it a mcode lane and a pi lane
# running the same model are indistinguishable, which is the confusion the
# contract exists to prevent.
#
# Registry file format (data/async-lanes.tsv):
#   Comment lines beginning with '#' and blank lines are skipped.
#   Each data row is exactly 7 TAB-separated fields:
#     run_id  lane_key  model  surface  task  state  output
#   The lane_key segments are cross-checked against the separate model and
#   surface columns, and every run_id must be a UUID unique to one row.
#
# Exit codes:
#   0  all inputs are valid
#   1  one or more inputs are invalid; offending values are named on stderr
#   2  --self-check: missing alias for a configured dispatch model (fatal)
#
# Usage:
#   fm-lane-naming-check.sh "<lane-key>" ["<lane-key>" ...]
#   fm-lane-naming-check.sh --stdin < list.txt
#   fm-lane-naming-check.sh data/async-lanes.tsv
#   fm-lane-naming-check.sh --self-check config/crew-dispatch.json
#
# This check never edits or fixes its input; it only validates and reports.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OWNER="$SELF_DIR/fm-todo-prefix-check.sh"

if [ ! -x "$OWNER" ]; then
  printf 'fm-lane-naming-check: the naming owner is missing or not executable: %s\n' "$OWNER" >&2
  exit 2
fi

# check_one <input>: validate one input through the owner.
# A board row starts with "["; everything else is a lane key.
check_one() {
  local input=$1
  input=$(printf '%s' "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -n "$input" ] || return 0
  case "$input" in
    '['*) bash "$OWNER" "$input" ;;
    *) bash "$OWNER" --lane-key "$input" ;;
  esac
}

# --- dispatch --------------------------------------------------------------

# Handle --self-check before the positional-argument dispatch.
if [ "$#" -ge 2 ] && [ "$1" = "--self-check" ]; then
  dispatch_json="$2"
  if [ ! -f "$dispatch_json" ]; then
    printf 'self-check: not a file: %s\n' "$dispatch_json" >&2
    exit 2
  fi
  bash "$OWNER" --self-check "$dispatch_json"
  exit $?
fi

if [ $# -eq 1 ] && [ -f "$1" ]; then
  # Single argument is an existing file: treat as registry file.
  bash "$OWNER" --registry "$1"
  exit $?
fi

# Otherwise: check each positional argument as a string, or read stdin.
if [ $# -gt 0 ]; then
  failed=0
  for arg in "$@"; do
    check_one "$arg" || failed=1
  done
  exit "$failed"
fi

# Stdin mode: read lines until EOF.
failed=0
while IFS= read -r line || [ -n "$line" ]; do
  check_one "$line" || failed=1
done
exit "$failed"
