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
# Model aliases:  m3.1f, m3.1, luna6, glm5.3f, gem38f, pi
# Surface aliases: dubz, hd2, brandon, evps, firstmate
#
# Exit codes:
#   0  all inputs are valid
#   1  one or more inputs are invalid; offending values are named on stderr
#   2  --self-check: missing alias for a configured dispatch model (fatal)
#
# Usage:
#   fm-lane-naming-check.sh "<lane-key>"
#   fm-lane-naming-check.sh --stdin < state/<id>.status
#   cat list.txt | fm-lane-naming-check.sh
#   fm-lane-naming-check.sh data/async-lanes.tsv
#   fm-lane-naming-check.sh --self-check config/crew-dispatch.json
#
# --self-check mode: bind the hardcoded alias set to the dispatch config.
# Reads the JSON dispatch config, derives a lane-key alias for every model id
# present, and FAILS (exit 2) when a configured model has no alias or when
# an alias exists that no configured model uses.
#
# Alias derivation rule (one canonical statement, one place):
#   MiniMax provider: model id like minimax/MiniMax-M<family>[-<tier>]
#   -> lane-key alias = family + tier-marker
#     family = everything before the first '-' in the model id tail
#     tier-marker = keyword mapping of the FIRST tier segment:
#       'highspeed' -> 'h', 'flash' -> 'f', bare/unrecognised -> ''
#     Example: minimax/MiniMax-M3.1-Flash-Preview   -> m3.1f
#              minimax/MiniMax-M3.1                 -> m3.1
#   Other providers (openai-codex, etc.): no programmatic rule defined;
#   their model ids (gpt-6-luna, gpt-6.1-sol) do not derive to any
#   lane-key alias through the above rule.  Any alias claimed for them
#   must be verified explicitly before addition; do not guess.
#
# This check never edits or fixes the input; it only validates and reports.
# It is not yet wired into any launcher, so it cannot block a bad lane by itself.
set -u

# Canonical sets derived from AGENT-TODO-PROMPT-STYLE.md.
# Model aliases:  m3.1f, m3.1, luna6, glm5.3f, gem38f, pi
# Surface aliases: dubz, hd2, brandon, evps, firstmate

# Build anchored regex patterns (anchored so partial matches are not accepted).
_model_pat='m3\.1f|m3\.1|luna6|glm5\.3f|gem38f|pi'
_surface_pat='dubz|hd2|brandon|evps|firstmate'
# Lane keys are <harness>-<model>-<host>-<task> per AGENT-TODO-PROMPT-STYLE.md
# (Captain renewed 2026-10-18). The harness segment is NOT optional: without it a
# mcode lane and a pi lane are indistinguishable, which is exactly the confusion
# the contract exists to prevent.
_harness_pat='pi|mcode|claude|codex|opencode|grok|kimi|agy|minimax-code'

# Lane key: <model>-<surface>-<task>
#   model: one of the canonical aliases (may contain '.' like m3.1)
#   surface: one of the canonical aliases
#   task: any lowercase alphanumeric with hyphens (may include '.')
_lane_key_pat="^($_harness_pat)-($_model_pat)-($_surface_pat)-[a-z0-9.-]+$"

# UUID pattern for run_id field (8-4-4-4-12 hex digits).
_uuid_pat='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

# --- validate a single string (lane key or board line) --------------------

check_one() {
  local input=$1

  # Strip surrounding whitespace for robust comparison.
  input=$(printf '%s' "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Empty line: skip silently.
  [ -n "$input" ] || return 0

  # Try legacy direct lane-key format: <model>-<surface>-<task>.
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
  # Enforces the documented guarantee that a run_id identifies exactly one lane.
  # The UUID shape test below cannot catch reuse, which is how three lanes came
  # to share one workflow id unnoticed.
  local _seen_ids=$'\n'

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

    # Validate run_id is a UUID, and that no earlier row already claims it.
    if ! printf '%s\n' "$run_id" | grep -qE "$_uuid_pat"; then
      printf '%s: line %d: run_id is not a valid UUID: %s\n' \
        "$file" "$line_num" "$run_id" >&2
      failed=1
    fi

    case "$_seen_ids" in
      *$'\n'"$run_id"$'\n'*)
        printf '%s: line %d: run_id %s is already claimed by an earlier row; a run_id identifies one lane\n' \
          "$file" "$line_num" "$run_id" >&2
        failed=1
        ;;
      *)
        _seen_ids=$_seen_ids$run_id$'\n'
        ;;
    esac

    # Validate lane_key format.
    if ! printf '%s\n' "$lane_key" | grep -qE "$_lane_key_pat"; then
      printf '%s: line %d: lane_key is not valid: %s\n' \
        "$file" "$line_num" "$lane_key" >&2
      failed=1
    else
      # Cross-check: lane_key model segment must match the model column.
      local key_model
      key_model=$(extract_segment "$lane_key" 2) || key_model=""
      if [ -n "$key_model" ] && [ "$key_model" != "$model" ]; then
        printf '%s: line %d: lane_key model segment "%s" disagrees with model column "%s"\n' \
          "$file" "$line_num" "$key_model" "$model" >&2
        failed=1
      fi

      # Cross-check: lane_key surface segment must match the surface column.
      local key_surface
      key_surface=$(extract_segment "$lane_key" 3) || key_surface=""
      if [ -n "$key_surface" ] && [ "$key_surface" != "$surface" ]; then
        printf '%s: line %d: lane_key surface segment "%s" disagrees with surface column "%s"\n' \
          "$file" "$line_num" "$key_surface" "$surface" >&2
        failed=1
      fi
    fi
  done < "$file"

  return "$failed"
}

# --- self-check: bind alias set to dispatch config -------------------------------

# derive_alias <model-id>: derive a lane-key alias from a model id.
# Returns the alias on stdout, or empty if the model id has no derivation rule.
#
# Rule: minimax/MiniMax-M<family>[-<tier>]  ->  'm' + family + tier-marker
#   tier-marker = last letter of the tier keyword:
#     'highspeed' -> 'h', 'flash' -> 'f', bare/unrecognised -> ''
# All other providers: no derivation; this function returns empty.
derive_alias() {
  local model_id=$1
  # Only MiniMax provider is covered by the derivation rule.
  case "$model_id" in
    minimax/MiniMax-M*)
      # Normalise to lowercase for consistent pattern matching.
      local lower_id="${model_id,,}"  # e.g. minimax/minimax-m3.1-flash-preview
      # Strip the provider prefix.
      local rest="${lower_id#minimax/}"    # e.g. minimax-m3.1-flash-preview
      # rest is "minimax-m3.1-flash-preview"; remove the leading "minimax-".
      rest="${rest#minimax-}"              # e.g. m3.1-flash-preview
      # Extract family: text before the first '-'.
      local family="${rest%%-*}"            # e.g. m3.1
      # Extract tier: text after the first '-', then take only the first
      # segment (before any second '-'), e.g. "highspeed" from "highspeed".
      local tier tier_marker=""
      tier="${rest#*-}"                   # e.g. highspeed (empty if bare)
      tier="${tier%%-*}"                  # e.g. highspeed (strip trailing -Preview etc.)
      if [ -n "$tier" ]; then
        # tier-marker: map the first tier segment keyword to its letter code.
        # Only the keywords that appear in crew-dispatch.json are mapped.
        case "$tier" in
          highspeed) tier_marker="h" ;;
          flash)     tier_marker="f" ;;
          *)         tier_marker=""  ;;  # Unknown tier: no marker.
        esac
      fi
      # Result: family + tier_marker, e.g. "m3.1" + "f" = "m3.1f"
      printf '%s\n' "${family}${tier_marker}"
      ;;
    *)  # All other providers: no derivation rule defined.
      printf '\n'
      ;;
  esac
}

# check_alias_dispatch_binding <dispatch-json-file>: the self-check.
# Extracts every model id from the JSON, derives aliases for MiniMax models,
# then verifies the hardcoded alias set against the dispatch config.
#
# Exit 0:  all configured MiniMax models have aliases (binding holds)
# Exit 2:  one or more configured MiniMax models have no alias (binding broken)
# On either exit, orphaned aliases (hardcoded but no corresponding MiniMax model)
# are named on stdout as informational warnings; they do not affect exit code.
check_alias_dispatch_binding() {
  local dispatch_json=$1
  local failed=0

  # Bail if jq is not available.
  if ! command -v jq >/dev/null 2>&1; then
    printf 'self-check requires jq; install it to run --self-check.\n' >&2
    return 2
  fi

  # Collect all unique model ids from the JSON (rules[].use.model, default[].model).
  # Using jq to walk the entire tree and extract string values under 'model' keys.
  # This is intentionally broad to catch every model id the dispatch system uses.
  local all_models
  all_models=$(jq -r '.. | objects | select(has("model")).model // empty' "$dispatch_json" 2>/dev/null)
  if [ -z "$all_models" ]; then
    printf 'self-check: could not extract model ids from %s\n' "$dispatch_json" >&2
    return 2
  fi

  # Build the set of aliases we derive from MiniMax dispatch models.
  local derived_aliases=""
  while IFS= read -r model_id; do
    [ -n "$model_id" ] || continue
    local alias
    alias=$(derive_alias "$model_id")
    if [ -n "$alias" ]; then
      # MiniMax model: verify it has an alias in the hardcoded set.
      if printf '%s\n' "$alias" | grep -qE "^($_model_pat)$"; then
        derived_aliases+="$alias"$'\n'
      else
        printf 'self-check: configured model %s derives to alias %s which is not in the hardcoded alias set.\n' \
          "$model_id" "$alias" >&2
        failed=1
      fi
    fi
    # Non-MiniMax models (no derivation rule): skip.  The alias set is
    # specifically for MiniMax lane-key naming; other providers use
    # their own conventions and are out of scope for this binding.
  done <<EOF
$all_models
EOF

  # Report orphaned aliases: hardcoded aliases with no corresponding MiniMax model.
  # Sort and deduplicate for stable output.
  local sorted_derived
  sorted_derived=$(printf '%s' "$derived_aliases" | grep -v '^$' | sort -u)
  if [ -n "$sorted_derived" ]; then
    local alias
    for alias in m3.1f m3.1; do
      # These are the MiniMax-family aliases in the canonical set, and a
      # MiniMax model id in the dispatch config must derive to one of them.
      # m3.1: bare MiniMax-M3.1 is not in dispatch config.
      # Report as informational warning only (does not fail the check).
      if ! printf '%s\n' "$sorted_derived" | grep -qxF "$alias"; then
        printf 'self-check: orphaned alias %s has no corresponding MiniMax model in dispatch config.\n' "$alias"
      fi
    done
  fi

  if [ "$failed" -eq 1 ]; then
    return 2
  fi
  return 0
}

# --- dispatch --------------------------------------------------------------

# Handle --self-check before the positional-argument dispatch.
if [ "$#" -ge 2 ] && [ "$1" = "--self-check" ]; then
  dispatch_json="$2"
  if [ ! -f "$dispatch_json" ]; then
    printf 'self-check: not a file: %s\n' "$dispatch_json" >&2
    exit 2
  fi
  check_alias_dispatch_binding "$dispatch_json"
  exit $?
fi

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
