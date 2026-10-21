#!/usr/bin/env bash
# bin/fm-todo-prefix-check.sh - enforce the canonical To-Do prefix and lane-key format.
#
# Canonical board / todo row prefix:
#   [<harness>·<ModelAbbrev> <effort> @<Host>]
# Canonical lane key:
#   <harness>-<model>-<host>-<task>
#
# Authority: docs/todo-prefix-canonical-format.md owns the human-readable
# contract. This script is its machine checker.
#
# Model alias table (ONE place in this script; alias=exact catalog identifier:family):
#   m3.1f   -> minimax/MiniMax-M3.1-Flash   (family minimax)
#   m3.1    -> minimax/MiniMax-M3.1                 (family minimax)
#   luna6   -> openai-codex/gpt-6-luna              (family other)
#   glm5.3f -> zai/glm-5.3-flash                    (family other)
#   gem38f  -> agy/gemini-3.8-flash-medium          (family other)
#   pi      -> minimax/MiniMax-M3.1-Flash   (family other; legacy alias for the Pi session
#                        default model - the same id as m3.1f, so one model id always
#                        derives one alias)
#
# Alternate spellings accepted for those aliases (spelling:canonical alias).
# HD2 writes its abbreviations as G38F and M31, and our own contract writes
# m27-highspeed; the exact catalog identifier still lives only in the table
# above, so these entries never carry a second copy of that knowledge.
#   m31 -> m3.1        m31f -> m3.1f      g38f -> gem38f
#
# Harness tokens: pi codex claude opencode mcode grok kimi agy
# Effort tokens: unknown, the bare codes l m h xh x, and low medium high xhigh max
# Host tokens: any hostname token. This fleet uses brandon, hd2stack, controller, elevate.
#
# The owner role is NOT part of the prefix. It belongs in the task text.
#
# Case policy: a board prefix matches the harness, model alias and host tokens
# case-insensitively, because the cross-surface tracker writes HD2's own worked
# example as [agy·G38F m @HD2]. A lane key is an identifier and stays lowercase
# and canonical.
#
# Exit codes:
#   0  every checked input is valid
#   1  one or more inputs are invalid; the offending input is named on stderr
#   2  usage error, or a fatal --self-check alias gap
#
# Usage:
#   fm-todo-prefix-check.sh "<board row>" ["<board row>" ...]
#   fm-todo-prefix-check.sh --stdin < rows.txt
#   fm-todo-prefix-check.sh --lane-key "<lane-key>"
#   fm-todo-prefix-check.sh --registry <path.tsv>
#   fm-todo-prefix-check.sh --self-check <dispatch-config.json>
#   fm-todo-prefix-check.sh --help
#
# --self-check mode binds the hardcoded alias table to a dispatch config: it
# derives the lane-key alias for every configured MiniMax model id and FAILS
# (exit 2) when a configured MiniMax model has no alias. Aliases with no
# corresponding configured model are reported on stdout as informational
# warnings and never change the exit code. This mirrors the behaviour of
# bin/fm-lane-naming-check.sh --self-check so the two checks cannot contradict.
#
# This check never edits or fixes its input; it only validates and reports.
set -uo pipefail

EXPECTED_PREFIX='[<harness>·<ModelAbbrev> <effort> @<Host>]'
EXPECTED_LANE_KEY='<harness>-<model>-<host>-<task>'

# The alias table lives here and nowhere else.
# Format: alias=exact-catalog-identifier:derivation-family
# The derivation family says whether the alias can be derived from a MiniMax
# model id by the documented rule, which is what the --self-check binding and
# the orphan report use.
_MODEL_ALIAS_TABLE='m3.1f=minimax/MiniMax-M3.1-Flash:minimax m3.1=minimax/MiniMax-M3.1:minimax luna6=openai-codex/gpt-6-luna:other glm5.3f=zai/glm-5.3-flash:other gem38f=agy/gemini-3.8-flash-medium:other pi=minimax/MiniMax-M3.1-Flash:other'

_ALIAS_SPELLINGS='m31:m3.1 m31f:m3.1f g38f:gem38f'

_HARNESS_TOKENS='pi codex claude opencode mcode grok kimi agy'
_EFFORT_TOKENS='unknown low medium high xhigh max l m h xh x'

# A board-row host is a hostname, so uppercase is accepted.
_HOST_PATTERN='^[A-Za-z0-9][A-Za-z0-9.-]*$'
# A lane key is an identifier, so its host and task stay lowercase.
_LANE_HOST_PATTERN='^[a-z0-9][a-z0-9.-]*$'
_LANE_TASK_PATTERN='^[a-z0-9][a-z0-9.-]*$'

usage() {
  printf 'Usage: %s "<board row>" | --stdin | --lane-key <key> | --registry <path> | --self-check <path> | --help\n' "$(basename "$0")"
  printf '\n'
  printf 'Board row prefix:  %s\n' "$EXPECTED_PREFIX"
  printf 'Lane key:          %s\n' "$EXPECTED_LANE_KEY"
  printf '\n'
  printf 'Exit codes: 0 all valid, 1 one or more invalid (offending input named on stderr), 2 usage error.\n'
}

# trim <variable-name>: strip leading and trailing whitespace in place.
trim() {
  local name=$1
  local value=${!name}
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf -v "$name" '%s' "$value"
}

# in_list <needle> <space-separated-list>
in_list() {
  local needle=$1 list=$2 item
  local -a items
  read -r -a items <<< "$list"
  for item in "${items[@]}"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

# canonical_alias <token>: resolve a model token to its canonical alias.
# The token is lowercased and its hyphens are removed, so HD2's G38F and our own
# m27-highspeed both resolve to a canonical alias. Empty output means unknown.
canonical_alias() {
  local token=${1,,}
  token=${token//-/}
  local entry
  local -a entries
  read -r -a entries <<< "$_MODEL_ALIAS_TABLE"
  for entry in "${entries[@]}"; do
    if [ "${entry%%=*}" = "$token" ]; then
      printf '%s\n' "$token"
      return 0
    fi
  done
  local spelling
  local -a spellings
  read -r -a spellings <<< "$_ALIAS_SPELLINGS"
  for spelling in "${spellings[@]}"; do
    if [ "${spelling%%:*}" = "$token" ]; then
      printf '%s\n' "${spelling#*:}"
      return 0
    fi
  done
  return 1
}

# alias_known <alias>: true when the alias is in the canonical alias table.
# Lane keys and the --self-check binding use canonical aliases only.
alias_known() {
  local alias=$1 entry
  local -a entries
  read -r -a entries <<< "$_MODEL_ALIAS_TABLE"
  for entry in "${entries[@]}"; do
    [ "${entry%%=*}" = "$alias" ] && return 0
  done
  return 1
}

# alias_family <alias>: the derivation family of an alias, empty when unknown.
alias_family() {
  local alias=$1 entry
  local -a entries
  read -r -a entries <<< "$_MODEL_ALIAS_TABLE"
  for entry in "${entries[@]}"; do
    if [ "${entry%%=*}" = "$alias" ]; then
      printf '%s\n' "${entry##*:}"
      return 0
    fi
  done
  return 1
}

reject_board_row() {
  local row=$1 reason=$2
  printf 'fm-todo-prefix-check: invalid board row: %s\n' "$row" >&2
  printf '  reason: %s\n' "$reason" >&2
  printf '  expected: %s\n' "$EXPECTED_PREFIX" >&2
}

reject_lane_key() {
  local key=$1 reason=$2
  printf 'fm-todo-prefix-check: invalid lane key: %s\n' "$key" >&2
  printf '  reason: %s\n' "$reason" >&2
  printf '  expected: %s\n' "$EXPECTED_LANE_KEY" >&2
}

# --- board row ---------------------------------------------------------------

# check_board_row <row>: validate one To-Do board row against the canonical prefix.
check_board_row() {
  local row=$1
  trim row
  [ -n "$row" ] || return 0

  local prefix rest
  case "$row" in
    \[*\]*) : ;;
    *)
      reject_board_row "$row" 'the row does not start with a bracketed prefix'
      return 1
      ;;
  esac

  local after_open=${row#*[}
  prefix=${after_open%%]*}
  rest=${row#*]}

  # The owner role is not part of the canonical prefix. Name that legacy form.
  case "$prefix" in
    *'|'*)
      reject_board_row "$row" 'legacy owner-role segment "|" is not part of the canonical prefix; state the owner role in the task text'
      return 1
      ;;
  esac

  local harness model_effort_host
  case "$prefix" in
    *'·'*) : ;;
    *)
      reject_board_row "$row" 'the prefix has no "·" separator between the harness and the model'
      return 1
      ;;
  esac
  harness=${prefix%%·*}
  model_effort_host=${prefix#*·}

  local model_effort host
  case "$model_effort_host" in
    *' @'*) : ;;
    *)
      reject_board_row "$row" 'the prefix has no effort token between the model and the host'
      return 1
      ;;
  esac
  model_effort=${model_effort_host%% @*}
  host=${model_effort_host#* @}

  local model effort
  case "$model_effort" in
    *' '*) : ;;
    *)
      reject_board_row "$row" 'the prefix has no effort token between the model and the host'
      return 1
      ;;
  esac
  model=${model_effort%% *}
  effort=${model_effort#* }

  local lower_harness=${harness,,}
  local canonical_model

  if ! in_list "$lower_harness" "$_HARNESS_TOKENS"; then
    reject_board_row "$row" "unknown harness token \"$harness\""
    return 1
  fi
  canonical_model=$(canonical_alias "$model") || canonical_model=""
  if [ -z "$canonical_model" ]; then
    reject_board_row "$row" "unknown model alias \"$model\""
    return 1
  fi
  if ! in_list "${effort,,}" "$_EFFORT_TOKENS"; then
    reject_board_row "$row" "unknown effort token \"$effort\"; use a measured token or the literal unknown"
    return 1
  fi
  if ! [[ $host =~ $_HOST_PATTERN ]]; then
    reject_board_row "$row" "invalid host token \"$host\"; the host is a hostname where the owner runs"
    return 1
  fi

  case "$rest" in
    '') : ;;
    ' '*) : ;;
    *)
      reject_board_row "$row" 'the task text after the prefix must be separated by a space'
      return 1
      ;;
  esac

  return 0
}

# --- lane key ----------------------------------------------------------------

# lane_key_model <key>: print the model segment of a canonical lane key.
lane_key_model() {
  local key=$1
  local -a parts
  IFS='-' read -r -a parts <<< "$key"
  printf '%s\n' "${parts[1]-}"
}

# check_lane_key <key>: validate one lane key against the canonical lane-key format.
check_lane_key() {
  local key=$1
  trim key
  [ -n "$key" ] || return 0

  local -a parts
  IFS='-' read -r -a parts <<< "$key"

  if [ "${#parts[@]}" -lt 4 ]; then
    reject_lane_key "$key" "a lane key needs ${EXPECTED_LANE_KEY}; found ${#parts[@]} segment(s)"
    return 1
  fi

  local harness=${parts[0]}
  local model=${parts[1]}
  local host=${parts[2]}
  local task=""
  local i
  for i in "${!parts[@]}"; do
    if [ "$i" -ge 3 ]; then
      if [ -z "$task" ]; then
        task=${parts[$i]}
      else
        task="$task-${parts[$i]}"
      fi
    fi
  done

  if ! in_list "$harness" "$_HARNESS_TOKENS"; then
    reject_lane_key "$key" "missing or unknown harness segment \"$harness\""
    return 1
  fi
  if ! alias_known "$model"; then
    reject_lane_key "$key" "missing or unknown model alias segment \"$model\""
    return 1
  fi
  if ! [[ $host =~ $_LANE_HOST_PATTERN ]]; then
    reject_lane_key "$key" "missing or invalid host segment \"$host\""
    return 1
  fi
  if ! [[ $task =~ $_LANE_TASK_PATTERN ]]; then
    reject_lane_key "$key" "missing or invalid task segment \"$task\""
    return 1
  fi

  return 0
}

# --- registry ----------------------------------------------------------------

# check_registry <path>: validate a lane registry whose lane_key column must
# satisfy the canonical lane-key format.
# Registry shape (the data/async-lanes.tsv shape):
#   run_id<TAB>lane_key<TAB>model<TAB>surface<TAB>task<TAB>state<TAB>output
# Comment lines beginning with '#' and blank lines are skipped.
# The lane_key model segment must agree with the model column.
# This check does not own run_id identity rules; bin/fm-lane-naming-check.sh does.
check_registry() {
  local file=$1
  if [ ! -f "$file" ]; then
    printf 'fm-todo-prefix-check: registry not found: %s\n' "$file" >&2
    return 2
  fi

  local line_num=0
  local failed=0
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    line_num=$((line_num + 1))
    trim line
    [ -n "$line" ] || continue
    case "$line" in
      '#'*) continue ;;
    esac

    # Count TAB characters to get the exact field count, empty fields included.
    local tabs=${line//[!$'\t']/}
    local field_count=$(( ${#tabs} + 1 ))
    if [ "$field_count" -ne 7 ]; then
      printf '%s: line %d: expected 7 TAB-separated fields, found %d\n' \
        "$file" "$line_num" "$field_count" >&2
      failed=1
      continue
    fi

    local run_id=${line%%$'\t'*}
    local rest=${line#*$'\t'}
    local lane_key=${rest%%$'\t'*}
    local rest2=${rest#*$'\t'}
    local model=${rest2%%$'\t'*}

    if ! check_lane_key "$lane_key"; then
      printf '%s: line %d: lane_key is not canonical (run_id %s)\n' \
        "$file" "$line_num" "$run_id" >&2
      failed=1
      continue
    fi

    local key_model
    key_model=$(lane_key_model "$lane_key")
    if [ "$key_model" != "$model" ]; then
      printf '%s: line %d: lane_key model segment "%s" disagrees with the model column "%s"\n' \
        "$file" "$line_num" "$key_model" "$model" >&2
      failed=1
    fi
  done < "$file"

  return "$failed"
}

# --- self-check --------------------------------------------------------------

# derive_alias <model-id>: derive a lane-key alias from a model id.
# Rule (one canonical statement, mirroring bin/fm-lane-naming-check.sh):
#   minimax/MiniMax-M<family>[-<tier>]  ->  family + tier-marker
#   tier-marker: 'highspeed' -> 'h', 'flash' -> 'f', bare or unrecognised -> ''
#   Examples: minimax/MiniMax-M2.7-highspeed -> m2.7h
#             minimax/MiniMax-M3.1-Flash -> m3.1f
#             minimax/MiniMax-M3.1 -> m3.1
#   Other providers have no derivation rule and yield an empty alias.
derive_alias() {
  local model_id=$1
  case "$model_id" in
    minimax/MiniMax-M*)
      local lower_id=${model_id,,}
      local rest=${lower_id#minimax/}
      rest=${rest#minimax-}
      local family=${rest%%-*}
      local tier=${rest#*-}
      tier=${tier%%-*}
      local tier_marker=""
      case "$tier" in
        highspeed) tier_marker="h" ;;
        flash) tier_marker="f" ;;
        *) tier_marker="" ;;
      esac
      printf '%s\n' "${family}${tier_marker}"
      ;;
    *)
      printf '\n'
      ;;
  esac
}

# check_self_check <dispatch-json>: bind the hardcoded alias table to a dispatch config.
# Exit 0: every configured MiniMax model derives to an alias in the table.
# Exit 2: a configured MiniMax model has no alias, or no model id could be read.
check_self_check() {
  local dispatch_json=$1
  local failed=0

  if ! command -v jq >/dev/null 2>&1; then
    printf 'self-check requires jq; install it to run --self-check.\n' >&2
    return 2
  fi

  local all_models
  all_models=$(jq -r '.. | objects | select(has("model")).model // empty' "$dispatch_json" 2>/dev/null)
  if [ -z "$all_models" ]; then
    printf 'self-check: could not extract model ids from %s\n' "$dispatch_json" >&2
    return 2
  fi

  local derived=""
  local model_id alias
  while IFS= read -r model_id; do
    [ -n "$model_id" ] || continue
    alias=$(derive_alias "$model_id")
    [ -n "$alias" ] || continue
    if alias_known "$alias"; then
      derived="$derived$alias"$'\n'
    else
      printf 'self-check: configured model %s derives to alias %s which is not in the hardcoded alias set.\n' \
        "$model_id" "$alias" >&2
      failed=1
    fi
  done <<EOF
$all_models
EOF

  # Orphan report: an alias that a MiniMax model id could derive, but that no
  # configured model derives. Informational only, never changes the exit code.
  local entry
  local -a entries
  read -r -a entries <<< "$_MODEL_ALIAS_TABLE"
  for entry in "${entries[@]}"; do
    local alias_name=${entry%%=*}
    local family
    family=$(alias_family "$alias_name")
    [ "$family" = "minimax" ] || continue
    if ! printf '%s' "$derived" | grep -qxF "$alias_name"; then
      printf 'self-check: orphaned alias %s has no corresponding MiniMax model in dispatch config.\n' \
        "$alias_name"
    fi
  done

  if [ "$failed" -eq 1 ]; then
    return 2
  fi
  return 0
}

# --- stdin -------------------------------------------------------------------

check_stdin() {
  local failed=0
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    check_board_row "$line" || failed=1
  done
  return "$failed"
}

# --- dispatch ----------------------------------------------------------------

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  --stdin)
    shift
    failed=0
    if [ $# -gt 0 ]; then
      for arg in "$@"; do
        check_board_row "$arg" || failed=1
      done
    fi
    check_stdin || failed=1
    exit "$failed"
    ;;
  --lane-key)
    [ $# -ge 2 ] || { usage >&2; exit 2; }
    check_lane_key "$2"
    exit $?
    ;;
  --registry)
    [ $# -ge 2 ] || { usage >&2; exit 2; }
    check_registry "$2"
    exit $?
    ;;
  --self-check)
    [ $# -ge 2 ] || { usage >&2; exit 2; }
    dispatch_json=$2
    if [ ! -f "$dispatch_json" ]; then
      printf 'self-check: not a file: %s\n' "$dispatch_json" >&2
      exit 2
    fi
    check_self_check "$dispatch_json"
    exit $?
    ;;
  '')
    check_stdin
    exit $?
    ;;
  -*)
    printf 'fm-todo-prefix-check: unknown option: %s\n' "$1" >&2
    usage >&2
    exit 2
    ;;
  *)
    failed=0
    for arg in "$@"; do
      check_board_row "$arg" || failed=1
    done
    exit "$failed"
    ;;
esac
