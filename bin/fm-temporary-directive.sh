#!/usr/bin/env bash
# fm-temporary-directive.sh - record, inspect and clear temporary dispatch directives.
#
# A temporary directive is a dispatch instruction that carries its own expiry.
# It is temporary by construction: the expiry is resolved to an absolute instant
# when the directive is recorded, so the directive stops applying at that instant
# whether or not anyone clears it, and it still expires correctly across a
# restart. An expired directive is reported wherever it would have applied, so a
# stale instruction is never applied silently and never dropped silently.
#
# Usage:
#   fm-temporary-directive.sh set --id <slug> --until <duration|iso8601>
#       --harness <name> [--model <id>] [--effort <level>]
#       --reason "<text>" [--note "<text>"] [--json]
#   fm-temporary-directive.sh clear --id <slug> [--json]
#   fm-temporary-directive.sh list [--json]
#   fm-temporary-directive.sh status [--json]
#   fm-temporary-directive.sh effective [--json]
#   fm-temporary-directive.sh staleness [--json]
#
# The store is one local, gitignored file, $FM_HOME/config/temporary-directives.json
# (FM_CONFIG_OVERRIDE moves the whole config directory). Its shape:
#
#   {
#     "version": 1,
#     "directives": [
#       {
#         "id": "minimax-hold",
#         "reason": "MiniMax 5h window measured at 6% remaining",
#         "note": "optional",
#         "harness": "pi",
#         "model": "openai-codex/gpt-6-luna",
#         "effort": "high",
#         "set_at": "2026-10-21T05:30:00Z",
#         "until": "2026-10-21T11:30:00Z",
#         "cleared_at": null
#       }
#     ]
#   }
#
# A duration given to --until (90m, 6h, 2d, 1w) is resolved to that absolute
# instant when the directive is recorded, so the directive expires on time
# whether or not anything reads it in between. An ISO-8601 instant is used as
# given, in UTC. --reason is required: a temporary directive with no reason is
# a mystery switch, not a temporary directive.
#
# Expiry is enforced by comparison, not by deletion. A directive is live until
# its until instant, expired after it, and cleared once it was cleared. An
# expired directive stays visible in list and status until it is cleared, and it
# never applies again. Among live directives the most recently recorded one
# wins, and it overrides the standing dispatch rules; the standing rules apply
# when no directive is live.
#
# A malformed store is an actionable error, never resolved around: the broken
# input is preserved, the reason is reported, and set and clear refuse to
# write over it.
#
# staleness compares the standing dispatch directive's recorded justification
# (the _mode block of config/crew-dispatch.json) with a current quota-axi
# reading and reports a standing directive whose stated reason no longer
# holds. It never changes the standing directive: a human or the firstmate
# decides. The reading is read-only and never refreshes a credential.
#
# Every subcommand accepts --json for a machine-readable answer.
#
# Exit: 0 success, 1 nothing to clear, 2 usage or configuration error.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-$FM_ROOT}"
CONFIG="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"
STORE="$CONFIG/temporary-directives.json"
CREW_DISPATCH="$CONFIG/crew-dispatch.json"

# A recorded justification that differs from the current reading by at least
# this many percentage points no longer describes the world. The threshold
# keeps ordinary drift from looking like a stale directive while still
# catching a window that recovered or a window that drained.
STALE_THRESHOLD=25

die() {
  printf 'error: %s\n' "$1" >&2
  exit 2
}

usage() {
  awk '
    NR == 1 { next }
    /^#/ { sub(/^# ?/, ""); print; next }
    { exit }
  ' "$0"
}

# ---- time -------------------------------------------------------------------

now_epoch() {
  date -u +%s
}

now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# iso_to_epoch <instant>: epoch seconds for an ISO-8601 instant, GNU date
# first and BSD date second, so the tool runs on every surface the fleet runs.
iso_to_epoch() {
  local iso=$1
  date -u -d "$iso" +%s 2>/dev/null && return 0
  date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$iso" +%s 2>/dev/null && return 0
  date -u -j -f '%Y-%m-%dT%H:%M:%S' "$iso" +%s 2>/dev/null && return 0
  return 1
}

epoch_to_iso() {
  local epoch=$1
  date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  date -u -r "$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  return 1
}

# duration_seconds <value>: seconds for a duration like 90m, 6h, 2d or 1w.
duration_seconds() {
  local value=$1 count unit
  case "$value" in
    ''|*[!0-9smhdw]*) return 1 ;;
  esac
  count=${value%[smhdw]}
  unit=${value#"$count"}
  [ -n "$count" ] || return 1
  [ "$count" -gt 0 ] 2>/dev/null || return 1
  case "$unit" in
    s) printf '%s\n' "$((count))" ;;
    m) printf '%s\n' "$((count * 60))" ;;
    h) printf '%s\n' "$((count * 3600))" ;;
    d) printf '%s\n' "$((count * 86400))" ;;
    w) printf '%s\n' "$((count * 604800))" ;;
    *) return 1 ;;
  esac
}

# fmt_duration <seconds>: a short human duration such as 2d 3h or 45m.
fmt_duration() {
  local seconds=$1
  if [ "$seconds" -lt 0 ]; then seconds=0; fi
  if [ "$seconds" -lt 60 ]; then
    printf '%ds\n' "$seconds"
    return 0
  fi
  local minutes=$((seconds / 60))
  local hours=$((minutes / 60))
  local days=$((hours / 24))
  if [ "$days" -gt 0 ]; then
    printf '%dd %dh\n' "$days" "$((hours % 24))"
  elif [ "$hours" -gt 0 ]; then
    printf '%dh %dm\n' "$hours" "$((minutes % 60))"
  else
    printf '%dm\n' "$minutes"
  fi
}

# ---- store ------------------------------------------------------------------

# The one place that decides whether a store is well formed. A malformed store
# is reported with the reason and never repaired, because repairing it would
# destroy the broken input an operator has to look at.
STORE_VALIDATION_JQ='
def iso: test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");
def slug: test("^[a-z0-9][a-z0-9._-]*$");
if type != "object" then "top-level value must be an object"
elif has("version") and .version != 1 then "unsupported store version: " + (.version | tostring)
elif has("directives") and (.directives | type) != "array" then "directives must be an array"
elif any(.directives[]?; type != "object") then "each directive must be an object"
elif any(.directives[]?; ((.id | type) != "string") or ((.id | length) == 0)) then "each directive needs a non-empty id"
elif any(.directives[]?; ((.id | slug) | not)) then "each directive id must be a lowercase slug"
elif ([.directives[]?.id] | length) != ([.directives[]?.id] | unique | length) then "directive ids must be unique"
elif any(.directives[]?; ((.reason | type) != "string") or ((.reason | length) == 0)) then "each directive needs a non-empty reason"
elif any(.directives[]?; ((.harness | type) != "string") or ((.harness | length) == 0)) then "each directive needs a non-empty harness"
elif any(.directives[]?; has("model") and .model != null and (((.model | type) != "string") or ((.model | length) == 0))) then "a directive model must be a non-empty string when present"
elif any(.directives[]?; has("effort") and .effort != null and (((.effort | type) != "string") or ((.effort | length) == 0))) then "a directive effort must be a non-empty string when present"
elif any(.directives[]?; has("note") and .note != null and ((.note | type) != "string")) then "a directive note must be a string when present"
elif any(.directives[]?; ((.set_at | type) != "string") or ((.set_at | iso) | not)) then "each directive needs an ISO-8601 set_at"
elif any(.directives[]?; ((.until | type) != "string") or ((.until | iso) | not)) then "each directive needs an ISO-8601 until"
elif any(.directives[]?; has("cleared_at") and .cleared_at != null and (((.cleared_at | type) != "string") or ((.cleared_at | iso) | not))) then "a directive cleared_at must be null or an ISO-8601 instant"
else empty end
'

# The one place that decides the state of every directive. A directive is live
# until its until instant, expired after it, and cleared once it was cleared.
# shellcheck disable=SC2016  # jq program text: $now and $d are jq variables.
STATE_JQ='
def decorate($now):
  .directives = [ .directives[]? | . as $d
    | (if $d.cleared_at != null then "cleared"
       elif (($d.until | fromdateiso8601) <= $now) then "expired"
       else "live" end) as $state
    | $d + {state: $state,
            expired_ago_seconds: (if $state == "expired" then ($now - ($d.until | fromdateiso8601)) else null end)} ];
'

# store_error: the reason the store is unusable, or nothing when it is fine.
# The broken input is never repaired, so the reason is what an operator needs.
store_error() {
  local content reason
  if [ ! -e "$STORE" ] && [ ! -L "$STORE" ]; then
    return 0
  fi
  if [ ! -r "$STORE" ]; then
    printf 'temporary directive store is not readable: %s\n' "$STORE"
    return 0
  fi
  if ! content=$(cat "$STORE" 2>/dev/null); then
    printf 'temporary directive store could not be read: %s\n' "$STORE"
    return 0
  fi
  if ! printf '%s' "$content" | jq -e . >/dev/null 2>&1; then
    printf 'temporary directive store is not valid JSON: %s\n' "$STORE"
    return 0
  fi
  reason=$(printf '%s' "$content" | jq -r "$STORE_VALIDATION_JQ" 2>/dev/null)
  if [ -n "$reason" ]; then
    printf 'temporary directive store is malformed: %s - %s\n' "$STORE" "$reason"
  fi
  return 0
}

# read_store: the store JSON on stdout, or a reason on stderr with exit 2.
read_store() {
  local error
  error=$(store_error)
  if [ -n "$error" ]; then
    printf '%s\n' "$error" >&2
    return 2
  fi
  if [ ! -e "$STORE" ] && [ ! -L "$STORE" ]; then
    printf '{"version":1,"directives":[]}\n'
    return 0
  fi
  cat "$STORE"
}

# write_store <json>: replace the store atomically, so a reader never sees a
# half-written file and a failed write never truncates the old one.
write_store() {
  local json=$1 dir tmp
  dir=$(dirname "$STORE")
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir" || {
      printf 'error: could not create the config directory: %s\n' "$dir" >&2
      return 2
    }
  fi
  tmp=$(mktemp "$dir/.temporary-directives.XXXXXX") || {
    printf 'error: could not create a temporary file in %s\n' "$dir" >&2
    return 2
  }
  if ! printf '%s\n' "$json" > "$tmp"; then
    rm -f "$tmp"
    printf 'error: could not write the temporary directive store\n' >&2
    return 2
  fi
  chmod 644 "$tmp" 2>/dev/null || true
  if ! mv -f "$tmp" "$STORE"; then
    rm -f "$tmp"
    printf 'error: could not replace the temporary directive store: %s\n' "$STORE" >&2
    return 2
  fi
  return 0
}

# ---- standing directive staleness -------------------------------------------

# The claim grammar read out of a standing directive's recorded justification.
# A claim is a percentage attached to a named window: "MiniMax 5h window
# measured at 6% remaining" and "Codex measured 96% five_hour / 99% weekly"
# both name the provider, the window and the number. A percentage with no
# named window is not a claim, because checking it would mean guessing which
# window the number described.
# shellcheck disable=SC2016  # jq program text: $sentence, $alias and friends are jq variables.
CLAIM_JQ='
def canon_scope:
  if . == null then null
  elif (. == "5h" or . == "five_hour" or . == "five-hour" or . == "five hour") then "five_hour"
  elif (. == "7d" or . == "weekly" or . == "week" or . == "7-day" or . == "7 day") then "weekly"
  elif (. == "daily" or . == "day" or . == "24h") then "daily"
  elif (. == "monthly" or . == "month" or . == "30d") then "monthly"
  else null end;
def provider_aliases: [
  ["minimax","minimax"], ["openai-codex","codex"], ["codex","codex"],
  ["zai","zai"], ["glm","zai"], ["agy","agy"], ["gemini","agy"],
  ["claude","claude"], ["grok","grok"], ["kimi","kimi"], ["muse","muse"],
  ["deepseek","deepseek"], ["mimo","mimo"], ["copilot","copilot"],
  ["cursor","cursor"], ["openrouter","openrouter"], ["alibaba","alibaba"]
];
def provider_of($sentence):
  ( [ provider_aliases[] | . as $alias
      | select($sentence | ascii_downcase | test("(^|[^a-z0-9])" + $alias[0] + "([^a-z0-9]|$)"))
      | $alias[1] ] )
  | (if length == 0 then null else .[0] end);
def window_match($id; $token):
  ($token | canon_scope) as $wanted
  | if $wanted == null then false
    else ( ($id | ascii_downcase) == ($token | ascii_downcase) )
      or ( [ ($id | ascii_downcase | split(":"))[] | canon_scope ]
           | map(select(. != null)) | index($wanted) ) != null
    end;
def claims($contract):
  [ $contract
    | split(". ")
    | map(select(length > 0))
    | .[]
    | . as $sentence
    | provider_of($sentence) as $provider
    | if $provider == null then empty
      else
        ( [ $sentence | scan("([A-Za-z0-9][A-Za-z0-9_-]{0,19})[ ]+(?:window[ ]+)?measured[ ]+at[ ]+([0-9]{1,3})%") ] ) as $pre
        | ( [ $sentence | scan("([0-9]{1,3})%[ ]*([A-Za-z][A-Za-z0-9_-]{0,19})") ] ) as $post
        | ( $pre | map(select((.[0] | canon_scope) != null))
                 | map({scope_token: .[0], scope: (.[0] | canon_scope), claimed: (.[1] | tonumber), text: $sentence}) ) as $pre_claims
        | ( $post | map(select((.[1] | canon_scope) != null))
                 | map({scope_token: .[1], scope: (.[1] | canon_scope), claimed: (.[0] | tonumber), text: $sentence}) ) as $post_claims
        | ( ($pre_claims + $post_claims) | unique_by([.scope, .claimed])[] | . + {provider: $provider} )
      end
  ];
def current_reading($quota; $provider; $scope; $token):
  ( [ ($quota.providers // [])[] | select(.provider == $provider) ] ) as $rows
  | if ($rows | length) == 0 then {verdict: "provider_absent"}
    else
      ( $rows[0] ) as $row
      | ( [ ($row.windows // [])[]
            | select(.percentRemaining != null)
            | select(window_match(.id; $token))
            | {pct: .percentRemaining, window: .id} ] ) as $windows
      | if ($windows | length) > 0 then {verdict: "measured", current: $windows[0].pct, window: $windows[0].window}
        else
          ( [ ($row.quotaSemantics.effectiveAvailability // [])[]
                | select(.effectivePercentRemaining != null)
                | select(.scope == $scope or window_match(.scope; $token))
                | {pct: .effectivePercentRemaining, window: .scope} ] ) as $scopes
          | if ($scopes | length) > 0 then {verdict: "measured", current: $scopes[0].pct, window: $scopes[0].window}
            else {verdict: "unmeasured"} end
        end
    end;
def evaluate($quota; $claims; $threshold):
  [ $claims[] | . as $claim
    | current_reading($quota; $claim.provider; $claim.scope; $claim.scope_token) as $reading
    | if $reading.verdict == "measured" then
        ($reading.current - $claim.claimed) as $delta
        | (if $delta < 0 then -$delta else $delta end) as $distance
        | $claim + {current: $reading.current, window: $reading.window, delta: $delta,
                    direction: (if $delta > 0 then "recovered" elif $delta < 0 then "depleted" else "unchanged" end),
                    verdict: (if $distance >= $threshold then "stale" else "holds" end)}
      else $claim + {current: null, window: null, delta: null, direction: null, verdict: $reading.verdict}
      end ];
'

# read_quota: the current quota snapshot on stdout, or a reason on stderr.
# The reading is read-only and never refreshes a credential.
read_quota() {
  local snapshot
  if ! command -v quota-axi >/dev/null 2>&1; then
    printf 'quota-axi is not installed\n' >&2
    return 1
  fi
  if ! snapshot=$(quota-axi --json --no-credential-refresh 2>/dev/null); then
    printf 'quota-axi --json --no-credential-refresh failed\n' >&2
    return 1
  fi
  if ! printf '%s' "$snapshot" | jq -e . >/dev/null 2>&1; then
    printf 'quota-axi --json returned an invalid snapshot\n' >&2
    return 1
  fi
  printf '%s' "$snapshot"
  return 0
}

# staleness_json: the standing-directive staleness report as JSON. It reads
# the standing config and a current quota reading, and it never writes to
# either one.
staleness_json() {
  local standing_file="$CREW_DISPATCH" contract active quota quota_error evaluated warning
  if [ ! -r "$standing_file" ]; then
    jq -n --arg checked_at "$(now_iso)" '{
      ok: true, action: "staleness", checked_at: $checked_at,
      standing: null, claims: [], stale: false, warning: null,
      reading: {available: false, reason: "no standing dispatch config at the configured path"}
    }'
    return 0
  fi
  if ! contract=$(jq -r '._mode.contract // ""' "$standing_file" 2>/dev/null); then
    jq -n --arg checked_at "$(now_iso)" '{
      ok: true, action: "staleness", checked_at: $checked_at,
      standing: null, claims: [], stale: false, warning: null,
      reading: {available: false, reason: "the standing dispatch config is not valid JSON"}
    }'
    return 0
  fi
  active=$(jq -r '._mode.active // ""' "$standing_file" 2>/dev/null)
  if [ -z "$contract" ]; then
    jq -n --arg checked_at "$(now_iso)" --arg file "$standing_file" --arg active "$active" '{
      ok: true, action: "staleness", checked_at: $checked_at,
      standing: {file: $file, active: $active, contract: null},
      claims: [], stale: false, warning: null,
      reading: {available: false, reason: "the standing dispatch directive records no justification to check"}
    }'
    return 0
  fi
  if ! quota=$(read_quota 2>/dev/null); then
    quota_error=$(read_quota 2>&1 >/dev/null || true)
    jq -n --arg checked_at "$(now_iso)" --arg file "$standing_file" --arg active "$active" \
      --arg contract "$contract" --arg reason "${quota_error:-the current quota reading is unavailable}" '{
      ok: true, action: "staleness", checked_at: $checked_at,
      standing: {file: $file, active: $active, contract: $contract},
      claims: [], stale: false, warning: null,
      reading: {available: false, reason: $reason}
    }'
    return 0
  fi
  evaluated=$(jq -n --argjson quota "$quota" --arg threshold "$STALE_THRESHOLD" --arg contract "$contract" "$CLAIM_JQ"'
    claims($contract) as $claims
    | evaluate($quota; $claims; ($threshold | tonumber)) as $evaluated
    | $evaluated
  ') || die "the standing-directive claim check failed"
  warning=$(jq -rn --argjson evaluated "$evaluated" --arg file "$standing_file" --arg active "$active" '
    def line($c):
      "dispatch-stale: standing directive " + $file + " _mode \"" + $active + "\" claims \""
      + $c.text + "\" (" + $c.provider + " " + $c.scope + " " + ($c.claimed | tostring) + "%) - now "
      + ($c.current | tostring) + "% (" + ($c.window // "unknown window") + ", " + $c.direction
      + ") - re-measure quota-axi and update or replace the standing directive";
    [ $evaluated[] | select(.verdict == "stale") | line(.) ] | join("; ")
  ')
  jq -n --arg checked_at "$(now_iso)" --arg file "$standing_file" --arg active "$active" \
    --arg contract "$contract" --argjson evaluated "$evaluated" --arg warning "$warning" '{
      ok: true, action: "staleness", checked_at: $checked_at,
      standing: {file: $file, active: $active, contract: $contract},
      claims: $evaluated,
      stale: (([$evaluated[] | select(.verdict == "stale")] | length) > 0),
      warning: (if $warning == "" then null else $warning end),
      reading: {available: true, source: "quota-axi --json --no-credential-refresh"}
    }' || die "the standing-directive staleness report could not be rendered"
  return 0
}

# ---- rendering --------------------------------------------------------------

# profile_flags <directive-json>: the concrete spawn flags a directive carries.
profile_flags() {
  jq -r '
    "--harness " + (.harness // "")
    + (if ((.model // "") | length) > 0 then " --model " + .model else "" end)
    + (if ((.effort // "") | length) > 0 then " --effort " + .effort else "" end)
  ' <<<"$1"
}

render_list() {
  local directives=$1
  if [ "$(jq -r 'length' <<<"$directives")" = "0" ]; then
    printf 'temporary-directive:\n  count: 0\n'
    return 0
  fi
  printf 'temporary-directive:\n'
  jq -r '.[] |
    "  id: " + .id,
    "  reason: " + (.reason // "-"),
    "  note: " + ((.note // "-")),
    "  overrides: " + ("--harness " + (.harness // "") +
      (if ((.model // "") | length) > 0 then " --model " + .model else "" end) +
      (if ((.effort // "") | length) > 0 then " --effort " + .effort else "" end)),
    "  state: " + (.state + (if .state == "expired" then " " + ((.expired_ago_seconds | tostring) + "s ago") else "" end)),
    "  set_at: " + (.set_at // "-"),
    "  until: " + (.until // "-"),
    (if .cleared_at != null then "  cleared_at: " + .cleared_at else empty end)
  ' <<<"$directives"
  return 0
}

# ---- subcommands ------------------------------------------------------------

cmd_set() {
  local id='' until='' harness='' model='' effort='' reason='' note='' json=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --id) [ $# -ge 2 ] || die "--id needs a value"; id=$2; shift 2 ;;
      --until) [ $# -ge 2 ] || die "--until needs a value"; until=$2; shift 2 ;;
      --harness) [ $# -ge 2 ] || die "--harness needs a value"; harness=$2; shift 2 ;;
      --model) [ $# -ge 2 ] || die "--model needs a value"; model=$2; shift 2 ;;
      --effort) [ $# -ge 2 ] || die "--effort needs a value"; effort=$2; shift 2 ;;
      --reason) [ $# -ge 2 ] || die "--reason needs a value"; reason=$2; shift 2 ;;
      --note) [ $# -ge 2 ] || die "--note needs a value"; note=$2; shift 2 ;;
      --json) json=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown flag for set: $1" ;;
    esac
  done
  [ -n "$id" ] || die "set needs --id <slug>"
  [ -n "$until" ] || die "set needs --until <duration|iso8601>"
  [ -n "$harness" ] || die "set needs --harness <name>"
  [ -n "$reason" ] || die "set needs --reason \"<text>\": a temporary directive with no reason is a mystery switch"
  case "$id" in
    [a-z0-9]*) ;;
    *) die "--id must be a lowercase slug: $id" ;;
  esac
  case "$id" in
    *[!a-z0-9._-]*) die "--id must be a lowercase slug: $id" ;;
  esac

  local now until_epoch until_iso expires_in
  now=$(now_epoch)
  if duration_seconds "$until" >/dev/null 2>&1; then
    expires_in=$(duration_seconds "$until") || die "--until is not a usable duration: $until"
    until_epoch=$((now + expires_in))
  else
    if ! until_epoch=$(iso_to_epoch "$until"); then
      die "--until is neither a duration (90m, 6h, 2d, 1w) nor an ISO-8601 instant: $until"
    fi
    expires_in=$((until_epoch - now))
  fi
  if [ "$until_epoch" -le "$now" ]; then
    die "--until is already in the past: $until"
  fi
  until_iso=$(epoch_to_iso "$until_epoch") || die "could not format the expiry instant: $until"
  local set_at
  set_at=$(now_iso)

  local store
  store=$(read_store) || exit 2
  local replaced=false
  if [ "$(jq -r --arg id "$id" '[.directives[]? | select(.id == $id)] | length' <<<"$store")" != "0" ]; then
    replaced=true
  fi

  local directive
  directive=$(jq -n --arg id "$id" --arg reason "$reason" --arg note "$note" \
    --arg harness "$harness" --arg model "$model" --arg effort "$effort" \
    --arg set_at "$set_at" --arg until "$until_iso" '{
      id: $id,
      reason: $reason,
      note: (if $note == "" then null else $note end),
      harness: $harness,
      model: (if $model == "" then null else $model end),
      effort: (if $effort == "" then null else $effort end),
      set_at: $set_at,
      until: $until,
      cleared_at: null
    }')
  local updated
  updated=$(jq --argjson directive "$directive" '
    .version = 1
    | .directives = [ (.directives // [])[] | select(.id != $directive.id) ] + [$directive]
  ' <<<"$store") || die "could not build the directive store"
  write_store "$updated" || exit 2

  local flags
  flags=$(profile_flags "$directive")
  if [ "$json" = "1" ]; then
    jq -n --argjson directive "$directive" --argjson replaced "$replaced" --argjson expires_in "$expires_in" '{
      ok: true, action: "set",
      id: $directive.id, reason: $directive.reason, note: $directive.note,
      harness: $directive.harness, model: $directive.model, effort: $directive.effort,
      set_at: $directive.set_at, until: $directive.until,
      expires_in_seconds: $expires_in, replaced: $replaced
    }'
    return 0
  fi
  printf 'temporary-directive:\n'
  printf '  set: %s\n' "$id"
  printf '  reason: %s\n' "$reason"
  if [ -n "$note" ]; then printf '  note: %s\n' "$note"; fi
  printf '  overrides: %s\n' "$flags"
  printf '  until: %s (in %s)\n' "$until_iso" "$(fmt_duration "$expires_in")"
  if [ "$replaced" = "true" ]; then
    printf '  replaced: the previous directive with this id was replaced\n'
  fi
  return 0
}

cmd_clear() {
  local id='' json=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --id) [ $# -ge 2 ] || die "--id needs a value"; id=$2; shift 2 ;;
      --json) json=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown flag for clear: $1" ;;
    esac
  done
  [ -n "$id" ] || die "clear needs --id <slug>"

  local store
  store=$(read_store) || exit 2
  local existing
  existing=$(jq -c --arg id "$id" '[.directives[]? | select(.id == $id)] | .[0] // empty' <<<"$store")
  if [ -z "$existing" ]; then
    if [ "$json" = "1" ]; then
      jq -n --arg id "$id" '{ok: false, action: "clear", id: $id, cleared: false, state: "absent", reason: "no temporary directive with that id"}'
    else
      printf 'temporary-directive:\n'
      printf '  absent: no temporary directive with id %s\n' "$id"
    fi
    exit 1
  fi
  local cleared_at
  cleared_at=$(now_iso)
  if [ "$(jq -r '.cleared_at // ""' <<<"$existing")" != "" ]; then
    if [ "$json" = "1" ]; then
      jq -n --argjson directive "$existing" '{ok: true, action: "clear", id: $directive.id, cleared: false, state: "cleared", cleared_at: $directive.cleared_at, reason: "the directive was already cleared"}'
    else
      printf 'temporary-directive:\n'
      printf '  already cleared: %s (at %s)\n' "$id" "$(jq -r '.cleared_at' <<<"$existing")"
    fi
    return 0
  fi
  local updated
  updated=$(jq --arg id "$id" --arg cleared_at "$cleared_at" '
    .version = 1
    | .directives = [ (.directives // [])[] | if .id == $id then . + {cleared_at: $cleared_at} else . end ]
  ' <<<"$store") || die "could not build the directive store"
  write_store "$updated" || exit 2
  if [ "$json" = "1" ]; then
    jq -n --arg id "$id" --arg cleared_at "$cleared_at" --argjson directive "$existing" '{
      ok: true, action: "clear", id: $id, cleared: true, state: "cleared", cleared_at: $cleared_at,
      until: $directive.until
    }'
    return 0
  fi
  printf 'temporary-directive:\n'
  printf '  cleared: %s (was due to expire at %s)\n' "$id" "$(jq -r '.until' <<<"$existing")"
  return 0
}

cmd_list() {
  local json=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown flag for list: $1" ;;
    esac
  done
  local store directives
  store=$(read_store) || exit 2
  directives=$(jq --argjson now "$(now_epoch)" "$STATE_JQ"'
    decorate($now) | .directives
  ' <<<"$store") || die "could not read the directive store"
  if [ "$json" = "1" ]; then
    jq -n --argjson directives "$directives" '{ok: true, action: "list", count: ($directives | length), directives: $directives}'
    return 0
  fi
  render_list "$directives"
  return 0
}

# effective_json: the effective dispatch decision right now, without a quota
# reading. The resolver uses it, so the check stays cheap enough for a
# dispatch intake.
effective_json() {
  local error store directives live expired cleared
  error=$(store_error)
  if [ -n "$error" ]; then
    jq -n --arg error "$error" '{ok: false, action: "effective", error: $error}'
    return 2
  fi
  store=$(read_store) || exit 2
  directives=$(jq --argjson now "$(now_epoch)" "$STATE_JQ"'
    decorate($now) | .directives
  ' <<<"$store") || die "could not read the directive store"
  live=$(jq -c '[.[] | select(.state == "live")] | sort_by([.set_at, .id]) | last // null' <<<"$directives")
  expired=$(jq -c '[.[] | select(.state == "expired")]' <<<"$directives")
  cleared=$(jq -c '[.[] | select(.state == "cleared")]' <<<"$directives")
  jq -n --argjson live "$live" --argjson expired "$expired" --argjson cleared "$cleared" '{
    ok: true, action: "effective", live: $live, expired: $expired, cleared: $cleared
  }'
  return 0
}

cmd_effective() {
  local json=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown flag for effective: $1" ;;
    esac
  done
  local output rc=0
  output=$(effective_json) || rc=$?
  if [ "$json" = "1" ]; then
    printf '%s\n' "$output"
    exit "$rc"
  fi
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$output" | jq -r '.error // "the temporary directive store is unusable"' >&2
    exit "$rc"
  fi
  local live
  live=$(jq -r '.live.id // ""' <<<"$output")
  if [ -n "$live" ]; then
    printf 'temporary-directive:\n'
    printf '  status: live\n'
    printf '  effective: %s\n' "$(jq -r '.live | "--harness " + (.harness // "") + (if ((.model // "") | length) > 0 then " --model " + .model else "" end) + (if ((.effort // "") | length) > 0 then " --effort " + .effort else "" end)' <<<"$output")"
    printf '  source: temporary directive %s (until %s)\n' "$live" "$(jq -r '.live.until' <<<"$output")"
  else
    printf 'temporary-directive:\n'
    printf '  status: standing\n'
    printf '  effective: the standing dispatch rules\n'
  fi
  jq -r '.expired[]? | "  expired: " + .id + " (expired " + .until + ", " + ((.expired_ago_seconds | tostring) + "s ago") + ") - ignored"' <<<"$output"
  return 0
}

cmd_status() {
  local json=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown flag for status: $1" ;;
    esac
  done
  local output staleness rc=0
  output=$(effective_json) || rc=$?
  if [ "$rc" -ne 0 ]; then
    if [ "$json" = "1" ]; then
      printf '%s\n' "$output"
    else
      printf '%s\n' "$output" | jq -r '.error // "the temporary directive store is unusable"' >&2
    fi
    exit "$rc"
  fi
  staleness=$(staleness_json) || die "the standing-directive staleness check failed"
  local live standing_active standing_file
  live=$(jq -r '.live.id // ""' <<<"$output")
  standing_file=$(jq -r '.standing.file // ""' <<<"$staleness")
  standing_active=$(jq -r '.standing.active // ""' <<<"$staleness")
  if [ "$json" = "1" ]; then
    jq -n --argjson effective "$output" --argjson staleness "$staleness" '{
      ok: true, action: "status",
      status: (if $effective.live != null then "live" else "standing" end),
      effective: (if $effective.live != null then
                    ("--harness " + ($effective.live.harness // "") +
                     (if (($effective.live.model // "") | length) > 0 then " --model " + $effective.live.model else "" end) +
                     (if (($effective.live.effort // "") | length) > 0 then " --effort " + $effective.live.effort else "" end))
                  else "the standing dispatch rules" end),
      source: (if $effective.live != null then $effective.live.id else "standing rules" end),
      live: $effective.live, expired: $effective.expired, cleared: $effective.cleared,
      standing: $staleness.standing, standing_check: {
        stale: $staleness.stale, warning: $staleness.warning,
        claims: $staleness.claims, reading: $staleness.reading, checked_at: $staleness.checked_at
      }
    }'
    return 0
  fi
  printf 'temporary-directive:\n'
  if [ -n "$live" ]; then
    printf '  status: live\n'
    printf '  effective: %s\n' "$(jq -r '.live | "--harness " + (.harness // "") + (if ((.model // "") | length) > 0 then " --model " + .model else "" end) + (if ((.effort // "") | length) > 0 then " --effort " + .effort else "" end)' <<<"$output")"
    printf '  source: temporary directive %s (until %s)\n' "$live" "$(jq -r '.live.until' <<<"$output")"
  else
    printf '  status: standing\n'
    printf '  effective: the standing dispatch rules\n'
    printf '  source: standing rules\n'
  fi
  if [ -n "$standing_file" ]; then
    printf '  standing: %s _mode "%s"\n' "$standing_file" "$standing_active"
  fi
  jq -r '.expired[]? | "  expired: " + .id + " (expired " + .until + ", " + ((.expired_ago_seconds | tostring) + "s ago") + ") - ignored"' <<<"$output"
  jq -r '.cleared[]? | "  cleared: " + .id + " (cleared " + (.cleared_at // "-") + ")"' <<<"$output"
  local check
  check=$(jq -r 'if .stale then "stale" elif (.reading.available | not) then "unavailable" else "current" end' <<<"$staleness")
  printf '  standing-check: %s\n' "$check"
  jq -r '.claims[]? | "  claim: " + .provider + " " + .scope + " claimed " + (.claimed | tostring) + "% - now " + (if .current == null then "unmeasured" else ((.current | tostring) + "%") end) + (if .window then " (" + .window + ")" else "" end) + (if .direction then ", " + .direction else "" end)' <<<"$staleness"
  jq -r 'if .warning then "  warning: " + .warning else empty end' <<<"$staleness"
  jq -r 'if (.reading.available | not) then "  reading: unavailable - " + .reading.reason else empty end' <<<"$staleness"
  return 0
}

cmd_staleness() {
  local json=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown flag for staleness: $1" ;;
    esac
  done
  local report
  report=$(staleness_json) || die "the standing-directive staleness check failed"
  if [ "$json" = "1" ]; then
    printf '%s\n' "$report"
    return 0
  fi
  printf 'temporary-directive:\n'
  jq -r 'if .standing == null then "  standing: none recorded" else "  standing: " + .standing.file + " _mode \"" + (.standing.active // "") + "\"" end' <<<"$report"
  jq -r 'if .reading.available then "  reading: " + .reading.source else "  reading: unavailable - " + .reading.reason end' <<<"$report"
  jq -r '.claims[]? | "  claim: " + .provider + " " + .scope + " claimed " + (.claimed | tostring) + "% - now " + (if .current == null then "unmeasured" else ((.current | tostring) + "%") end) + (if .window then " (" + .window + ")" else "" end) + (if .direction then ", " + .direction else "" end) + " - " + .verdict' <<<"$report"
  jq -r 'if .warning then "  warning: " + .warning else empty end' <<<"$report"
  return 0
}

main() {
  local command=''
  if [ $# -gt 0 ]; then
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -*) die "unknown flag: $1" ;;
      *) command=$1; shift ;;
    esac
  fi
  case "$command" in
    ''|help) usage; exit 0 ;;
    set) cmd_set "$@" ;;
    clear) cmd_clear "$@" ;;
    list) cmd_list "$@" ;;
    status) cmd_status "$@" ;;
    effective) cmd_effective "$@" ;;
    staleness) cmd_staleness "$@" ;;
    *) die "unknown subcommand: $command" ;;
  esac
}

main "$@"
