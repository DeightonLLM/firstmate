#!/usr/bin/env bash
# Detect the agent harness this process tree runs on.
# Usage: fm-harness.sh                  print own harness: claude|codex|opencode|pi|pi-signed|grok|kimi|agy|minimax-code|unknown
#        fm-harness.sh crew             print the effective CREWMATE harness
#                                        (config/crew-harness; "default" resolves to own)
#        fm-harness.sh secondmate       print the harness the PRIMARY uses to launch
#                                        SECONDMATE agents: config/secondmate-harness ->
#                                        config/crew-harness -> own. "default" or absent
#                                        defers to the crew resolution, so an unset
#                                        secondmate-harness behaves exactly as the crew
#                                        harness did before this knob existed.
#        fm-harness.sh secondmate-model    print the optional MODEL token from
#                                        config/secondmate-harness, or empty when absent.
#        fm-harness.sh secondmate-effort   print the optional EFFORT token from
#                                        config/secondmate-harness, or empty when absent.
#        fm-harness.sh verified         print whitespace-separated list of verified harnesses
#        fm-harness.sh verified-json    print JSON array of verified harnesses
#        fm-harness.sh is-verified <h>  exit 0 if <h> is verified, exit 1 otherwise
#
# config/dispatch.json is the ONE dispatch file. It owns the crew harness, the
# secondmate harness/model/effort, the lane ceilings, and the routing rules.
# Every legacy file stays supported as a COMPATIBILITY FALLBACK, consulted
# second and never deleted by this script:
#   dispatch.json .harness            -> config/crew-harness        -> own harness
#   dispatch.json .secondmate.harness  -> config/secondmate-harness  -> crew resolution
#   dispatch.json .secondmate.model    -> config/secondmate-harness model token
#   dispatch.json .secondmate.effort   -> config/secondmate-harness effort token
#   dispatch.json .max_lanes           -> config/dispatch-max-lanes
#   dispatch.json .max_provider_lanes  -> config/dispatch-max-provider-lanes
#   dispatch.json .route               -> config/crew-dispatch.json
#
# Dispatch-config modes (they read config/dispatch.json only, never the
# ambient environment, so a reader can tell "configured" from "detected"):
#        fm-harness.sh dispatch-crew-harness      configured crew harness, empty if unset
#        fm-harness.sh dispatch-route-harness     configured route harness, empty if unset
#        fm-harness.sh dispatch-route-source      config/dispatch.json | config/crew-dispatch.json
#        fm-harness.sh dispatch-route-json        the routing rules JSON, compact, one line
#        fm-harness.sh dispatch-config-valid      exit 0 when config/dispatch.json parses
#        fm-harness.sh dispatch-model             configured model, empty if unset
#        fm-harness.sh dispatch-effort            configured effort, empty if unset
#        fm-harness.sh dispatch-max-lanes         configured live-lane ceiling, empty if unset
#        fm-harness.sh dispatch-max-provider-lanes configured per-provider ceiling, empty if unset
#
# config/secondmate-harness format: a single line "<harness> [<model>] [<effort>]",
# whitespace-separated. A bare "<harness>" (today's format) behaves exactly as before:
# harness only, no model/effort. Only the first non-empty, non-comment line is parsed.
# Model/effort come ONLY from this file - config/crew-harness stays a bare adapter
# name and is never parsed for a model.
# Detection layers: verified environment markers first, then process ancestry.
# Record each newly verified env marker here.
set -u

# Canonical list of verified harnesses. bin/fm-harness.sh is Firstmate's single
# source of truth for verified agent harness adapters. Every other component
# (fm-bootstrap.sh, fm-spawn.sh, etc.) defers to this definition.
VERIFIED_HARNESSES=(claude codex opencode pi pi-signed grok kimi agy minimax-code)

is_verified() {
  local h="${1:-}" v
  for v in "${VERIFIED_HARNESSES[@]}"; do
    [ "$v" = "$h" ] && return 0
  done
  return 1
}

verified_json() {
  local json="[" first=1 v
  for v in "${VERIFIED_HARNESSES[@]}"; do
    if [ "$first" = 1 ]; then
      first=0
      json="$json\"$v\""
    else
      json="$json,\"$v\""
    fi
  done
  json="$json]"
  printf '%s\n' "$json"
}

verified_list() {
  printf '%s\n' "${VERIFIED_HARNESSES[*]}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
CONFIG="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"

# ---------------------------------------------------------------------------
# config/dispatch.json - the ONE dispatch file.
#
# This script is the single owner of that file's schema. Every other reader
# (the dispatch guard, the dispatch resolver, bootstrap, the enforcement
# dashboard) asks this script for a value instead of parsing the file again,
# so there is exactly one place where the key names and the legacy fallback
# order are written down.
#
# Every read degrades to the legacy files instead of failing: a missing file, an
# unreadable file, malformed JSON, or a missing jq all print nothing, and the
# caller falls through to config/crew-harness, config/secondmate-harness,
# config/dispatch-max-lanes, config/dispatch-max-provider-lanes, or
# config/crew-dispatch.json exactly as it did before this file existed.
# ---------------------------------------------------------------------------
DISPATCH_CONFIG_NAME="dispatch.json"

# dispatch_config_string <jq-filter>: print one string value from
# config/dispatch.json. Prints nothing when the file is absent, unreadable,
# malformed, when jq is unavailable, or when the filter yields nothing.
dispatch_config_string() {
  local filter=$1 file="$CONFIG/$DISPATCH_CONFIG_NAME" out
  [ -f "$file" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  out=$(jq -r "$filter" "$file" 2>/dev/null) || return 0
  case "$out" in
    ''|null) return 0 ;;
  esac
  printf '%s\n' "$out"
}

# dispatch_config_json <jq-filter>: print one compact JSON value from
# config/dispatch.json. Prints nothing when the file is absent, unreadable,
# malformed, when jq is unavailable, or when the filter yields nothing.
dispatch_config_json() {
  local filter=$1 file="$CONFIG/$DISPATCH_CONFIG_NAME" out
  [ -f "$file" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  out=$(jq -c "$filter" "$file" 2>/dev/null) || return 0
  case "$out" in
    ''|null) return 0 ;;
  esac
  printf '%s\n' "$out"
}

# dispatch_config_is_valid_json: true when config/dispatch.json exists and
# parses. A file that exists but does not parse is a BROKEN configuration, not
# an absent one, and a reader must report it instead of quietly falling through
# to the legacy files.
dispatch_config_is_valid_json() {
  local file="$CONFIG/$DISPATCH_CONFIG_NAME"
  [ -f "$file" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -e . "$file" >/dev/null 2>&1
}

# The lane ceilings accept a JSON number or a decimal string, because the
# legacy files hold a bare number and a captain copying that value across
# should not have to remember which JSON type to use.
dispatch_max_lanes_value() {
  local v
  v=$(dispatch_config_string '
    if (.max_lanes | type) == "number" then (.max_lanes | floor | tostring)
    elif (.max_lanes | type) == "string" and (.max_lanes | test("^[0-9]+$")) then .max_lanes
    else empty end')
  if [ -z "$v" ] && [ -r "$CONFIG/dispatch-max-lanes" ]; then
    v=$(tr -dc '0-9' < "$CONFIG/dispatch-max-lanes" || true)
  fi
  [ -n "$v" ] || return 0
  printf '%s\n' "$v"
}

dispatch_max_provider_lanes_value() {
  local v
  v=$(dispatch_config_string '
    if (.max_provider_lanes | type) == "number" then (.max_provider_lanes | floor | tostring)
    elif (.max_provider_lanes | type) == "string" and (.max_provider_lanes | test("^[0-9]+$")) then .max_provider_lanes
    else empty end')
  if [ -z "$v" ] && [ -r "$CONFIG/dispatch-max-provider-lanes" ]; then
    v=$(tr -dc '0-9' < "$CONFIG/dispatch-max-provider-lanes" || true)
  fi
  [ -n "$v" ] || return 0
  printf '%s\n' "$v"
}

detect_own() {
  # Layer 1: environment markers for verified harnesses.
  # Keep marker detection before ancestry detection as an explicit precedence rule.
  # Only claude, pi, and grok set verified markers of their own; codex, opencode,
  # and kimi are markerless, so a foreign marker retained in a terminal
  # multiplexer's stored environment can silently misidentify one of them before
  # ancestry is consulted. This is a precedence hazard, not evidence that
  # CLAUDECODE inheritance into a kimi child was observed; it was not observed.
  [ "${CLAUDECODE:-}" = "1" ] && { echo claude; return; }
  if [ "${PI_CODING_AGENT:-}" = "true" ]; then
    if [ "${FM_PI_HARNESS:-}" = pi-signed ]; then echo pi-signed; else echo pi; fi
    return
  fi
  # grok sets GROK_AGENT=1 for its child/tool processes (verified, grok 0.2.73).
  # It does NOT set CLAUDECODE despite being Claude-Code-compatible, so this marker
  # is unambiguous when firstmate runs natively on grok.
  [ "${GROK_AGENT:-}" = "1" ] && { echo grok; return; }
  # agy sets ANTIGRAVITY_AGENT=1 for its child/tool processes (verified, agy 1.3.3).
  [ "${ANTIGRAVITY_AGENT:-}" = "1" ] && { echo agy; return; }
  # Layer 2: walk the parent chain and match the command name.
  # Walk depth matches the shared session-lock lib's ancestry walk so one
  # session cannot resolve as a verified harness for the lock while reporting
  # unknown here. A shallow walk silently degrades to unknown once a real
  # session nests past it (tool wrapper -> runtime -> shell -> multiplexer).
  local pid=$$ comm args
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null) || break
    case "$(basename -- "$comm")" in
      *claude*) echo claude; return ;;
      *codex*) echo codex; return ;;
      *opencode*) echo opencode; return ;;
      *grok*) echo grok; return ;;
      minimax-code) echo minimax-code; return ;;
      kimi) echo kimi; return ;;
      pi-signed) echo pi; return ;;
      pi) echo pi; return ;;
      *agy*) echo agy; return ;;
      node*|python*)
        # Bare interpreter: match the harness name in its script path.
        args=$(ps -o args= -p "$pid" 2>/dev/null)
        case "$args" in
          *claude*) echo claude; return ;;
          *codex*) echo codex; return ;;
          *opencode*) echo opencode; return ;;
          *grok*) echo grok; return ;;
          *minimax-code*) echo minimax-code; return ;;
          *" pi "*|*/pi) echo pi; return ;;
          *agy*) echo agy; return ;;
        esac ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -z "$pid" ] || [ "$pid" -le 1 ]; then
      break
    fi
  done
  echo unknown
}

# Resolve the effective crewmate harness: config/dispatch.json .harness wins,
# then the legacy config/crew-harness (a bare adapter name), then the
# firstmate's own harness. A configured value of "default" means "not
# configured" and defers to the next source, exactly like the legacy file.
resolve_crew() {
  local crew=
  crew=$(dispatch_config_string 'if (.harness | type) == "string" then .harness else empty end')
  if [ -z "$crew" ] || [ "$crew" = "default" ]; then
    [ -f "$CONFIG/crew-harness" ] && crew=$(tr -d '[:space:]' < "$CONFIG/crew-harness" || true)
  fi
  if [ -z "$crew" ] || [ "$crew" = "default" ]; then detect_own; else echo "$crew"; fi
}

# The CONFIGURED crew harness only, with no own-harness fallback. A reader
# that needs to know whether a route was configured at all (the dispatch
# guard's route gate) uses this, never resolve_crew.
dispatch_crew_harness_configured() {
  local crew=
  crew=$(dispatch_config_string 'if (.harness | type) == "string" then .harness else empty end')
  if [ -z "$crew" ] || [ "$crew" = "default" ]; then
    [ -f "$CONFIG/crew-harness" ] && crew=$(tr -d '[:space:]' < "$CONFIG/crew-harness" || true)
  fi
  case "$crew" in
    ''|default) return 0 ;;
  esac
  printf '%s\n' "$crew"
}

# Print the first non-empty, non-comment line of config/secondmate-harness
# (leading/trailing whitespace trimmed), or nothing when the file is absent or
# holds only blank/comment lines.
secondmate_line() {
  local line
  [ -f "$CONFIG/secondmate-harness" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] || continue
    case "$line" in
      '#'*) continue ;;
    esac
    printf '%s\n' "$line"
    return 0
  done < "$CONFIG/secondmate-harness"
}

# Print the 1-based whitespace-separated token (1=harness, 2=model, 3=effort) of
# the resolved secondmate_line, or nothing if the line or that field is absent.
secondmate_field() {
  local idx=$1 line
  line=$(secondmate_line)
  [ -n "$line" ] || return 0
  # shellcheck disable=SC2086  # deliberate word-splitting: tokenizing the line into fields
  set -- $line
  case "$idx" in
    1) printf '%s\n' "${1:-}" ;;
    2) printf '%s\n' "${2:-}" ;;
    3) printf '%s\n' "${3:-}" ;;
  esac
}

# The CONFIGURED secondmate harness, from config/dispatch.json
# .secondmate.harness only. Empty when the file is absent or names nothing.
dispatch_secondmate_harness_configured() {
  local sm
  sm=$(dispatch_config_string '
    if ((.secondmate | type) == "object") and ((.secondmate.harness | type) == "string")
    then .secondmate.harness else empty end')
  case "$sm" in
    ''|default) return 0 ;;
  esac
  printf '%s\n' "$sm"
}

# The CONFIGURED route harness: the crew route first, then the secondmate
# route. Empty when neither is configured, so a caller can tell "this home
# has no configured route" from "this home routes on pi".
dispatch_route_harness_configured() {
  local h
  h=$(dispatch_crew_harness_configured)
  if [ -z "$h" ]; then
    h=$(dispatch_secondmate_harness_configured)
    if [ -z "$h" ]; then
      h=$(secondmate_field 1)
      case "$h" in
        ''|default) h='' ;;
      esac
    fi
  fi
  [ -n "$h" ] || return 0
  printf '%s\n' "$h"
}

# Resolve the harness the PRIMARY uses to launch SECONDMATE agents: a fallback
# chain config/dispatch.json .secondmate.harness -> config/secondmate-harness
# -> config/dispatch.json .harness -> config/crew-harness -> own. An absent or
# "default" secondmate harness defers to the crew resolution, so an unset
# secondmate harness behaves exactly as before this knob existed (a secondmate
# launched on the crew harness). config/secondmate-harness is the PRIMARY's own
# setting and is never inherited downstream - secondmates do not spawn secondmates.
resolve_secondmate() {
  local sm
  sm=$(dispatch_secondmate_harness_configured)
  if [ -z "$sm" ]; then sm=$(secondmate_field 1); fi
  if [ -z "$sm" ] || [ "$sm" = "default" ]; then resolve_crew; else echo "$sm"; fi
}

# legacy_secondmate_configured: the legacy config/secondmate-harness file
# names a harness of its own. The model and effort tokens belong to that
# harness, so they are only honoured while it is the configured source.
legacy_secondmate_configured() {
  local sm
  sm=$(secondmate_field 1)
  [ -n "$sm" ] && [ "$sm" != "default" ]
}

# Print the optional model token for the secondmate route:
# config/dispatch.json .secondmate.model -> the legacy file's model token ->
# nothing. The legacy token is only read while the legacy file names a
# harness, so a model never arrives without the harness it belongs to.
resolve_secondmate_model() {
  local sm model
  sm=$(dispatch_secondmate_harness_configured)
  if [ -n "$sm" ]; then
    model=$(dispatch_config_string '
      if ((.secondmate | type) == "object") and ((.secondmate.model | type) == "string")
      then .secondmate.model else empty end')
    if [ -z "$model" ] && legacy_secondmate_configured; then
      model=$(secondmate_field 2)
    fi
    [ -n "$model" ] && printf '%s\n' "$model"
    return 0
  fi
  legacy_secondmate_configured || return 0
  secondmate_field 2
}

# Print the optional effort token for the secondmate route, the same way.
resolve_secondmate_effort() {
  local sm effort
  sm=$(dispatch_secondmate_harness_configured)
  if [ -n "$sm" ]; then
    effort=$(dispatch_config_string '
      if ((.secondmate | type) == "object") and ((.secondmate.effort | type) == "string")
      then .secondmate.effort else empty end')
    if [ -z "$effort" ] && legacy_secondmate_configured; then
      effort=$(secondmate_field 3)
    fi
    [ -n "$effort" ] && printf '%s\n' "$effort"
    return 0
  fi
  legacy_secondmate_configured || return 0
  secondmate_field 3
}

# The routing rules live in config/dispatch.json under "route", and the legacy
# config/crew-dispatch.json stays the fallback. The SOURCE is decided first so
# a reader can report which file it validated, and the CONTENT is only read
# from the one file that owns it: the legacy file is never re-serialised, so a
# malformed or unreadable legacy file still fails with its own actionable
# message instead of degrading into "no rules".
dispatch_route_source() {
  local src
  if [ -f "$CONFIG/$DISPATCH_CONFIG_NAME" ]; then
    if ! dispatch_config_is_valid_json; then
      # The one file is broken. Name it as the source so the reader reports it
      # instead of silently routing on a different ruleset.
      printf '%s\n' "config/dispatch.json"
      return 0
    fi
    src=$(dispatch_config_string '
      if (.route | type) == "object" then "config/dispatch.json" else empty end')
    if [ -n "$src" ]; then printf '%s\n' "$src"; return 0; fi
  fi
  if [ -e "$CONFIG/crew-dispatch.json" ] || [ -L "$CONFIG/crew-dispatch.json" ]; then
    printf '%s\n' "config/crew-dispatch.json"
    return 0
  fi
  return 0
}

# The routing rules JSON, compact, on one line. Only meaningful when the
# source is config/dispatch.json; the legacy file is read by path.
dispatch_route_json() {
  dispatch_config_json 'if (.route | type) == "object" then .route else empty end'
}

case "${1:-}" in
  crew) resolve_crew ;;
  secondmate) resolve_secondmate ;;
  secondmate-model) resolve_secondmate_model ;;
  secondmate-effort) resolve_secondmate_effort ;;
  dispatch-crew-harness) dispatch_crew_harness_configured ;;
  dispatch-route-harness) dispatch_route_harness_configured ;;
  dispatch-route-source) dispatch_route_source ;;
  dispatch-route-json) dispatch_route_json ;;
  dispatch-config-valid) dispatch_config_is_valid_json ;;
  dispatch-model) dispatch_config_string 'if (.model | type) == "string" then .model else empty end' ;;
  dispatch-effort) dispatch_config_string 'if (.effort | type) == "string" then .effort else empty end' ;;
  dispatch-max-lanes) dispatch_max_lanes_value ;;
  dispatch-max-provider-lanes) dispatch_max_provider_lanes_value ;;
  verified) verified_list ;;
  verified-json) verified_json ;;
  is-verified) is_verified "${2:-}" ;;
  *) detect_own ;;
esac
