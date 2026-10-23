#!/usr/bin/env bash
# Dispatch guard - mechanical enforcement of fleet rules at the spawn boundary.
#
# Every rule here exists because a firstmate broke it and the failure was silent.
# Called by bin/fm-spawn.sh BEFORE any backend selection, window creation, or
# state mutation, so a rule violation stops the dispatch instead of degrading
# into firstmate quietly doing the work itself.
#
# Usage: fm-dispatch-guard.sh <harness> <model>
#   harness: the RESOLVED adapter for this spawn (never the raw CLI name)
#   model:   the CONCRETE model slug for THIS spawn, resolved by the caller from
#            every source that can set one: the explicit --model flag, the model
#            token of config/secondmate-harness, and the model carried by a raw
#            launch command. The Sol ban is evaluated against this value alone,
#            so a banned model cannot slip through by arriving from a config
#            file against an adapter other than the one whose name the rule used
#            to be keyed on.
#
# Exit: 0 allow, 64 refuse (with a specific, actionable reason on stderr).
#
# Scope of the two lane ceilings, which are deliberately different:
#   - the live-lane ceiling is HOME-LOCAL and counts this home's own lanes.
#   - the per-provider ceiling binds a CREDENTIAL ACCOUNT and counts that
#     account's lanes across THIS firstmate's registered second-mate homes as
#     well, because one firstmate's homes on one host hold one copy of each
#     credential. Another firstmate's fleet is never counted and never
#     claimed; the registry of our own homes is the only source.
#
# Overrides are deliberately narrow, documented, and logged - never silent:
#   FM_DISPATCH_GUARD_BYPASS=1        skip every bypassable check (logged)
#   FM_DISPATCH_GUARD_LOAD_BYPASS=1   skip only the load ceiling (logged)
#   FM_DISPATCH_GUARD_QUOTA_BYPASS=1  skip only the quota ceiling (logged)
#   FM_DISPATCH_GUARD_ROUTE_BYPASS=1  skip only the configured-route gate (logged);
#                                        it never rescues the Sol ban or the
#                                        retired-slug ban, which have no bypass
#   FM_DISPATCH_GUARD_MAX_LANES=<n>   live-lane ceiling; overrides config/dispatch.json
#                                        .max_lanes and config/dispatch-max-lanes (default 4)
#   FM_DISPATCH_GUARD_MAX_PROVIDER_LANES=<n>  per-provider ceiling; overrides
#                                        config/dispatch.json .max_provider_lanes and
#                                        config/dispatch-max-provider-lanes (default: global ceiling)
#   FM_DISPATCH_GUARD_LANE_BUDGET_S=<n>  wall-clock budget for the lane
#                                        inventory (default 30)
# Test seams (never set in production; they exist so the rules can be proven by
# observed behaviour instead of by reading this file):
#   FM_DISPATCH_GUARD_LOADAVG=<path>   read load from <path>, not /proc/loadavg
set -u

HARNESS="${1:-}"
MODEL="${2:-}"
# Log location must resolve on ANY surface, not just the Controller where the
# operator happens to be root. A hardcoded /root path printed a write failure on
# Brandon Compute (operator hd2admin) on every guard invocation. Resolve the
# user's own config dir, and only fall back to a /tmp path - never /root.
if [ -n "${FM_DISPATCH_GUARD_LOG:-}" ]; then
  LOG="$FM_DISPATCH_GUARD_LOG"
elif [ -n "${XDG_CONFIG_HOME:-}" ]; then
  LOG="${XDG_CONFIG_HOME}/dispatch-guard.log"
elif [ -n "${HOME:-}" ] && [ -w "${HOME}" ]; then
  LOG="${HOME}/.config/dispatch-guard.log"
else
  LOG="${TMPDIR:-/tmp}/fm-dispatch-guard.log"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/fm-backend.sh
. "$SCRIPT_DIR/fm-backend.sh"

log_event() {
  mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
  printf '%s %s harness=%s model=%s\n' \
    "$(date -u +%FT%TZ)" "$1" "${HARNESS:-none}" "${MODEL:-none}" >> "$LOG" 2>/dev/null || true
}

refuse() {
  echo "dispatch-guard: REFUSED - $1" >&2
  log_event "REFUSED reason=\"$1\""
  exit 64
}

# ---------------------------------------------------------------------------
# Rule 1: gpt-6.1-sol is banned for spawned workers (captain ruling 2026-10-11).
#
# This rule has NO bypass. The reason it needs enforcing is that
# ~/.codex/config.toml defaults model to Sol, so any codex spawn without an
# explicit --model silently runs it. A bypass here would recreate the exact
# silent failure this guard exists to prevent.
#
# The ban is a property of the MODEL VALUE, never of the adapter carrying it.
# The previous version keyed the empty-model refusal on the harness NAME and
# evaluated the value ban only on a non-empty model, so config/secondmate-harness
# set to e.g. "pi gpt-6.1-sol" arrived here as harness=pi model="" and launched
# the banned model: an unenforced rule that looked enforced. The caller must
# therefore resolve the concrete model before this script runs, and an empty
# model here means "unresolved", which fails closed wherever the adapter has a
# documented Sol default.
# ---------------------------------------------------------------------------

# harness_has_sol_default: adapters whose own configuration defaults to the
# banned model, so an UNRESOLVED model on one of these is a banned-model spawn
# by construction. codex is the only such adapter today (~/.codex/config.toml);
# every other verified adapter runs whatever its own default is, which this
# guard has no evidence is Sol, so refusing there would wedge legal spawns.
harness_has_sol_default() {  # <harness>
  case "$1" in
    codex) return 0 ;;
  esac
  return 1
}

if [ -z "$MODEL" ]; then
  if harness_has_sol_default "$HARNESS"; then
    refuse "no concrete model was resolved for this $HARNESS spawn, and $HARNESS defaults to gpt-6.1-sol (banned, captain ruling 2026-10-11). Pin the concrete model explicitly (--model, bin/fm-harness.sh, or config/secondmate-harness); the Sol ban has no bypass."
  fi
else
  case "$MODEL" in
    *gpt-6.1-sol*)
      refuse "model '$MODEL' contains gpt-6.1-sol, which is banned for spawned workers (captain ruling 2026-10-11). Pick a different model; this ban has no bypass."
      ;;
  esac
fi

# ---------------------------------------------------------------------------
# Rule 1b: the retired MCode preview slug is banned for spawned workers.
#
# minimax/MiniMax-M3.1-Flash-Preview was retired when the catalog id was
# retargeted to minimax/MiniMax-M3.1-Flash. A spawn still naming the retired
# slug resolves to a model the provider no longer serves, so it produces an
# agent that cannot answer.
#
# This ban has NO bypass, for the same reason the Sol ban has none: the
# retired slug sits in config files and old briefs, and a bypass would turn
# the rule into a suggestion exactly where it has to be absolute.
#
# The retired slug is matched as an ID STRING and never by asking a CLI
# whether it resolves, because the MCode CLI ACCEPTS the retired slug and
# exits 0: a probe against the CLI returns success for a model the provider
# no longer serves, so a CLI-shaped check would report the banned slug as
# healthy and let it through. The string comparison is the check.
# ---------------------------------------------------------------------------
case "$MODEL" in
  *MiniMax-M3.1-Flash-Preview*)
    refuse "model '$MODEL' names the retired slug minimax/MiniMax-M3.1-Flash-Preview, which the catalog no longer serves (the live id is minimax/MiniMax-M3.1-Flash). Use the live id; this ban has no bypass."
    ;;
esac

# ---------------------------------------------------------------------------
# Rule 1c: the configured-route gate.
#
# The Captain's standing directive (2026-10-21, stated four times) is that
# the MCode route IS the route. While the home's CONFIGURED route harness is
# minimax-code, a spawn that draws a provider account's quota through an API
# call is refused, because the whole point of the directive is that the free
# MCode route is used instead of an API-drawn lane.
#
# The Pi family was the first instance of that rule and stayed in it. codex
# was NOT, and that gap was live: measured on 2026-10-21, codex with
# openai-codex/gpt-6-luna exited 0 while the configured route was
# minimax-code, so an API-drawn lane could be dispatched onto the free route
# without the guard ever objecting. A rule that names one adapter when the
# directive names a class of routes is a rule that leaks, so the gate is now
# expressed as the class: EVERY API-drawn adapter is refused on the free
# route, and the configured route itself is not.
#
# The rule is conditional on the CONFIGURED route, never on the ambient
# detected harness: a home that configures nothing keeps whatever it had, and
# a home that configures pi keeps its Pi lanes. A blanket ban on every adapter
# would be a different rule and would wedge homes that deliberately route on
# one of them.
#
# The escape hatch is narrow, explicit, and logged: FM_DISPATCH_GUARD_ROUTE_BYPASS=1
# skips THIS check only. It is evaluated before the global bypass block, so
# FM_DISPATCH_GUARD_BYPASS=1 can never rescue a refused spawn, exactly as
# it can never rescue the Sol ban or the retired-slug ban.
# ---------------------------------------------------------------------------

# fm_dispatch_guard_api_drawn_adapters: the verified adapters whose spawns
# draw a provider credential's quota through an API call. The free MCode route
# is deliberately not among them: its traffic is covered by the route's own
# allowance, so a lane on it is not a lane on an account's quota.
#
# This list is the RULE and not a measurement. An adapter earns a place here
# by being API-drawn and leaves the list by becoming a free route. An adapter
# that is absent from the list is not refused by this gate, because the guard
# holds no evidence that it draws an account; refusing on a guess would wedge
# a legal spawn.
fm_dispatch_guard_api_drawn_adapters() {
  printf '%s\n' claude codex opencode pi pi-signed grok kimi agy
}

# fm_dispatch_guard_is_api_drawn: does this spawn draw a provider account?
fm_dispatch_guard_is_api_drawn() {  # <harness>
  local candidate
  while IFS= read -r candidate; do
    if [ "$candidate" = "$1" ]; then
      return 0
    fi
  done < <(fm_dispatch_guard_api_drawn_adapters)
  return 1
}

# fm_dispatch_guard_route_harness: the CONFIGURED route harness for this home
# (config/dispatch.json .harness, then config/crew-harness, then the
# secondmate route). Empty when the home configures no route at all.
fm_dispatch_guard_route_harness() {
  local home=${FM_HOME:-}
  [ -n "$home" ] || return 0
  FM_CONFIG_OVERRIDE="$home/config" "$SCRIPT_DIR/fm-harness.sh" dispatch-route-harness 2>/dev/null || true
}

route_harness=$(fm_dispatch_guard_route_harness)
case "$route_harness" in
  minimax-code)
    if fm_dispatch_guard_is_api_drawn "$HARNESS"; then
      if [ "${FM_DISPATCH_GUARD_ROUTE_BYPASS:-0}" = "1" ]; then
        log_event "BYPASS_ROUTE route=${route_harness} harness=${HARNESS}"
      else
        refuse "the configured route for this home is '${route_harness}', the free MCode route (captain directive 2026-10-21), so a spawn on '$HARNESS' is refused: '$HARNESS' draws a provider account's quota through an API call, and the configured route is the one that does not. Spawn on the configured route, or set FM_DISPATCH_GUARD_ROUTE_BYPASS=1 to override this one check (logged)."
      fi
    fi
    ;;
esac

# From here down, every check is bypassable via the global bypass. The Sol ban
# above is deliberately evaluated FIRST so FM_DISPATCH_GUARD_BYPASS can never
# rescue it - an earlier ordering let the bypass return 0 for Sol, which is the
# exact silent failure this guard exists to prevent. The retired-slug ban and
# the configured-route gate sit in the same unbypassable-by-default block for
# the same reason: they are standing captain directives, and a global bypass
# that could erase them would make them unenforceable in practice.
if [ "${FM_DISPATCH_GUARD_BYPASS:-0}" = "1" ]; then
  log_event "BYPASS_ALL"
  exit 0
fi

# ---------------------------------------------------------------------------
# Rule 2: load ceiling. The Controller is coordinator/monitor only, so refuse
# dispatch when the box is saturated. Reads the 1-MINUTE average, not the
# 15-minute one: the original shield read 15-min, and a burst hid behind it
# while 1-min load was 9.53 on 4 cores.
#
# The ceiling is the TRUNCATED 1-minute average against the core count: refuse
# at int(load1) >= cores. Truncation is deliberate and kept from the original
# rule (a 3.99 load on 4 cores is not yet saturation; 4.00 is).
#
# Fail-closed on unreadable evidence: an unreadable or unparseable
# /proc/loadavg, or an unusable core count, refuses. The previous version
# substituted 0 for a failed read, so a host where the load could not be read
# reported "load 0" and passed the ceiling without a word - silently allowing
# exactly the case the rule exists to catch.
# ---------------------------------------------------------------------------
if [ "${FM_DISPATCH_GUARD_LOAD_BYPASS:-0}" != "1" ]; then
  LOADAVG="${FM_DISPATCH_GUARD_LOADAVG:-/proc/loadavg}"
  cores="$(nproc 2>/dev/null || true)"
  raw_load=""
  if [ -r "$LOADAVG" ]; then
    raw_load="$(awk 'NR==1{print $1; exit}' "$LOADAVG" 2>/dev/null || true)"
  fi
  load1="${raw_load%%.*}"
  case "$load1" in ''|*[!0-9]*) load1= ;; esac
  case "$cores" in ''|*[!0-9]*) cores= ;; esac
  [ -n "$cores" ] && [ "$cores" -ge 1 ] || cores=
  if [ -z "$load1" ] || [ -z "$cores" ]; then
    refuse "the 1-minute load could not be read from ${LOADAVG} (got '${raw_load:-nothing}', ${cores:-0} usable cores), so the load ceiling cannot be evaluated. An unreadable load must not pass silently: free capacity or re-read the host, or set FM_DISPATCH_GUARD_LOAD_BYPASS=1 to skip this one check (logged)."
  fi
  if [ "$load1" -ge "$cores" ]; then
    # Logged as what it is. This branch used to log BYPASS_LOAD, which made a
    # genuine refusal indistinguishable in the audit log from an operator
    # override that skipped the check.
    log_event "LOAD_REFUSED load1=${load1} cores=${cores}"
    refuse "1-min load ${load1} >= ${cores} cores; this host is saturated and is coordinator-only. Free capacity first, or dispatch to another surface (brandon-compute is the default execution target)."
  fi
else
  # Log the bypass whenever it is used, not only when load actually tripped it.
  # A bypass that is silent unless it happens to matter is not an auditable bypass.
  log_event "BYPASS_LOAD"
fi

# ---------------------------------------------------------------------------
# Rule 3: live-lane ceiling.
#
# Parallel execution is wanted, but unbounded fan-out on one host is what
# bottlenecked the Controller. Counts ONLY lanes that are still alive.
#
# state/ is append-only history, so a meta merely existing proves nothing -
# counting files permanently refuses all dispatch.
#
# A LANE is one crew's own window/pane, resolved from its meta and judged by
# the repo's single recovery-grade liveness contract (fm_backend_agent_state -
# the same classifier the session-start liveness sweep and fm-crew-state.sh use).
# The previous version asked only whether the tmux SESSION named by the meta
# still existed, which is neither a lane nor a session: several crews share one
# session and one crew's window shares it with unrelated panes, so a crew whose
# window was gone still counted as a live lane and falsely refused dispatch.
#
# Only `dead` and `missing` are proofs of absence, exactly as fm-backend.sh's
# contract states; `ambiguous` and `unreadable` count as live so a transient
# endpoint problem can never silently under-count the cap. Unknown backend
# activity also counts as working. Herdr's native busy-state is the only signal
# that can prove a live lane idle; other backends return unknown and stay counted.
# Idle releases a slot only for this inventory: the next spawn re-reads current
# state, so a lane that resumes working consumes its slot again. A meta with an
# unresolved target is unknown, not absent, and therefore counts against the cap.
#
# Per-lane classification costs a subprocess per meta (~10ms tmux, ~80ms
# herdr), so the inventory runs under a wall-clock budget. An inventory that
# cannot finish cannot prove the ceiling is clear: it refuses, disclosed and
# bypassable, rather than counting a partial fleet.
# ---------------------------------------------------------------------------

# lane_target: print the meta's endpoint target normalised to the form the
# backend classifiers accept. fm-spawn records tmux targets as "session:window",
# which is the contract the classifiers verify against a window inventory; a
# target carrying a third pane component ("session:window:%0" or ".3") names the
# same window, so the pane component is dropped. Normalisation only - the
# verdict still comes from the shared classifier.
lane_target() {  # <backend> <target>
  local backend=$1 target=$2
  case "$backend:$target" in
    tmux:*:*:*)
      printf '%s\n' "$(printf '%s' "$target" | cut -d: -f1,2)"
      ;;
    *)
      printf '%s\n' "$target"
      ;;
  esac
}

# fm_dispatch_guard_lane_classify: classify one recorded lane as absent, idle,
# or working. Only a positive native idle verdict releases capacity; every
# unknown/unreadable verdict counts as working.
fm_dispatch_guard_lane_classify() {  # <backend> <target>
  local backend=$1 target=$2 presence activity
  presence=$(fm_backend_agent_state "$backend" "$target")
  case "$presence" in
    dead|missing) printf 'absent'; return 0 ;;
  esac
  activity=$(fm_backend_busy_state "$backend" "$target")
  if [ "$activity" = idle ]; then
    printf 'idle'
  elif [ "$presence" = unverified ]; then
    printf 'unverified'
  else
    printf 'working'
  fi
}

# fm_dispatch_guard_lane_cap: resolve the live-lane ceiling. Precedence:
# FM_DISPATCH_GUARD_MAX_LANES, then the home-local gitignored
# config/dispatch.json .max_lanes knob (the ONE dispatch file, same
# LOCAL-settings family as config/calm and config/backend), then the legacy
# config/dispatch-max-lanes knob, then 4. A ceiling that only applied when
# firstmate remembered to export an env var was never an enforced setting.
#
# The config read is written out inline on purpose: this function is
# extracted and exercised on its own by tests/fm-dispatch-guard-max-lanes.test.sh,
# so it must not depend on a helper defined elsewhere in this file.
fm_dispatch_guard_lane_cap() {
  local cap="${FM_DISPATCH_GUARD_MAX_LANES:-}"
  if [ -z "$cap" ] && [ -n "${FM_HOME:-}" ] && [ -r "${FM_HOME}/config/dispatch.json" ]; then
    cap=$(jq -r '
      if (.max_lanes | type) == "number" then (.max_lanes | floor | tostring)
      elif (.max_lanes | type) == "string" and (.max_lanes | test("^[0-9]+$")) then .max_lanes
      else empty end' "${FM_HOME}/config/dispatch.json" 2>/dev/null || true)
  fi
  if [ -z "$cap" ] && [ -n "${FM_HOME:-}" ] && [ -r "${FM_HOME}/config/dispatch-max-lanes" ]; then
    cap=$(tr -dc '0-9' < "${FM_HOME}/config/dispatch-max-lanes")
  fi
  case "$cap" in ''|*[!0-9]*) cap=4 ;; esac
  printf '%s' "$cap"
}

# Resolve the provider from the recorded model's provider prefix where present,
# otherwise use the recorded harness as the provider identity.
#
# This is the PROVIDER ATTRIBUTION: it answers "which provider is this lane
# on?". The ceiling binds a CREDENTIAL ACCOUNT, which is a different question,
# and the answer is fm_dispatch_guard_account_of_meta below.
fm_dispatch_guard_provider_of_meta() {  # <meta-file>
  local harness model
  harness="$(sed -n 's/^harness=//p' "$1" | head -n 1)"
  model="$(sed -n 's/^model=//p' "$1" | head -n 1)"
  case "$model" in
    */*) printf '%s' "${model%%/*}" ;;
    *) printf '%s' "${harness:-unknown}" ;;
  esac
}

# ---------------------------------------------------------------------------
# The CREDENTIAL ACCOUNT a lane spends from.
#
# The per-provider ceiling binds one credential account and not a provider name
# (docs/configuration.md, "The per-provider ceiling binds a credential
# account"), and the provider attribution above answers a different question:
# "which provider is this lane on?". The two answers are not the same string
# for one account, so the fleet's lanes on the MiniMax credential were counted
# in three buckets:
#
#   model=minimax/MiniMax-M3.1-Flash   -> provider "minimax"
#   model=MiniMax-M3.1-Flash          -> provider "minimax-code" (harness)
#   harness=pi, model=MiniMax-M2.7    -> provider "pi"          (harness)
#
# Every one of those draws the same MiniMax credential, so a ceiling on that
# credential was enforced against one bucket and ignored in the other two, and
# the account's real occupancy was never the number the ceiling saw. The
# account identity below folds the spellings of one account onto one key, so
# the ceiling counts the account's lanes once, wherever they are recorded.
#
# The account is resolved from the lane's MODEL first, because the model names
# the pool it draws from, and from the recorded adapter only when the model
# names no pool of its own. It never asks a CLI whether a model resolves: the
# MCode CLI accepts the retired slug and exits 0, so a CLI-shaped probe
# reports a dead model as a live one.
# ---------------------------------------------------------------------------

# fm_dispatch_guard_account_of_prefix: the credential account a provider
# PREFIX names. Some prefixes are credential-store aliases of one account.
fm_dispatch_guard_account_of_prefix() {  # <provider-prefix>
  case "${1:-}" in
    openai-codex|codex-home) printf 'codex' ;;
    *) printf '%s' "${1:-}" ;;
  esac
}

# fm_dispatch_guard_account_of_model: the credential account a model NAME
# belongs to, for models recorded without a provider prefix. Prints nothing
# and fails when the name belongs to no known account.
fm_dispatch_guard_account_of_model() {  # <model>
  local m
  m="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  case "$m" in
    minimax*)                printf 'minimax' ;;
    gpt-*|o1-*|o3-*|codex-*) printf 'codex' ;;
    claude-*|anthropic-*)    printf 'claude' ;;
    gemini-*)                printf 'agy' ;;
    glm-*|zai-*)             printf 'zai' ;;
    kimi-*|moonshot*)        printf 'kimi' ;;
    grok-*)                  printf 'grok' ;;
    *) return 1 ;;
  esac
}

# fm_dispatch_guard_account_of_harness: the credential account an ADAPTER
# spends from when the model names no account of its own.
fm_dispatch_guard_account_of_harness() {  # <harness>
  case "${1:-}" in
    minimax-code)   printf 'minimax' ;;
    codex|opencode) printf 'codex' ;;
    claude)         printf 'claude' ;;
    pi|pi-signed)   printf 'pi' ;;
    grok)           printf 'grok' ;;
    kimi)           printf 'kimi' ;;
    agy)            printf 'agy' ;;
    *) return 1 ;;
  esac
}

# fm_dispatch_guard_account_of_meta: the credential account a recorded lane
# draws from. The provider attribution stays the provider attribution and the
# account stays the account: this function only falls back on it, for a lane
# whose model and adapter name no account at all, so that an unknown lane
# occupies a slot instead of slipping past the ceiling.
fm_dispatch_guard_account_of_meta() {  # <meta-file>
  local harness model account
  harness="$(sed -n 's/^harness=//p' "$1" | head -n 1)"
  model="$(sed -n 's/^model=//p' "$1" | head -n 1)"
  case "$model" in
    */*)
      account="$(fm_dispatch_guard_account_of_prefix "${model%%/*}")"
      ;;
    *)
      account="$(fm_dispatch_guard_account_of_model "$model" 2>/dev/null || true)"
      [ -n "$account" ] || account="$(fm_dispatch_guard_account_of_harness "$harness" 2>/dev/null || true)"
      ;;
  esac
  [ -n "$account" ] || account="$(fm_dispatch_guard_provider_of_meta "$1")"
  [ -n "$account" ] || account="unknown"
  printf '%s' "$account"
}

# fm_dispatch_guard_fleet_homes: the homes whose lanes spend from THIS
# firstmate's credential accounts.
#
# One firstmate's homes on one host hold ONE copy of each credential, so a
# lane running in a registered second-mate home is a lane on our account and
# the per-account ceiling has to count it. Counting only this home's own
# state/*.meta left the ceiling binding one bucket of an account that the
# fleet was spending across several of its homes.
#
# The registry is this home's own data/secondmates.md, whose entries carry
# their home path in a trailer of the form
#   (home: <path>; scope: ...; projects: ...; added <date>)
#
# Only the homes THIS firstmate registered are counted. Another firstmate's
# fleet is not ours to count and its lanes are not ours to claim, so this
# registry is the only source and no foreign endpoint namespace is swept.
fm_dispatch_guard_fleet_homes() {
  local registry entry
  [ -n "${FM_HOME:-}" ] || return 0
  printf '%s\n' "$FM_HOME"
  registry="${FM_HOME}/data/secondmates.md"
  [ -r "$registry" ] || return 0
  local -A seen=()
  seen["$FM_HOME"]=1
  while IFS= read -r entry || [ -n "$entry" ]; do
    case "$entry" in
      *"(home: "*) : ;;
      *) continue ;;
    esac
    entry="${entry#*\(home: }"
    entry="${entry%%;*}"
    entry="${entry#"${entry%%[![:space:]]*}"}"
    entry="${entry%"${entry##*[![:space:]]}"}"
    [ -n "$entry" ] || continue
    [ -n "${seen[$entry]:-}" ] && continue
    seen["$entry"]=1
    [ -d "$entry/state" ] || continue
    printf '%s\n' "$entry"
  done < "$registry"
}

fm_dispatch_guard_provider_cap() {
  local cap="${FM_DISPATCH_GUARD_MAX_PROVIDER_LANES:-}"
  if [ -z "$cap" ] && [ -n "${FM_HOME:-}" ] && [ -r "${FM_HOME}/config/dispatch.json" ]; then
    cap=$(jq -r '
      if (.max_provider_lanes | type) == "number" then (.max_provider_lanes | floor | tostring)
      elif (.max_provider_lanes | type) == "string" and (.max_provider_lanes | test("^[0-9]+$")) then .max_provider_lanes
      else empty end' "${FM_HOME}/config/dispatch.json" 2>/dev/null || true)
  fi
  if [ -z "$cap" ] && [ -n "${FM_HOME:-}" ] && [ -r "${FM_HOME}/config/dispatch-max-provider-lanes" ]; then
    cap=$(tr -dc '0-9' < "${FM_HOME}/config/dispatch-max-provider-lanes")
  fi
  case "$cap" in ''|*[!0-9]*) cap="$(fm_dispatch_guard_lane_cap)" ;; esac
  printf '%s' "$cap"
}

if [ -n "${FM_HOME:-}" ] && [ -d "${FM_HOME}/state" ]; then
  budget="${FM_DISPATCH_GUARD_LANE_BUDGET_S:-30}"
  case "$budget" in ''|*[!0-9]*) budget=30 ;; esac
  started=$SECONDS
  live=0
  idle=0
  incomplete=0
  declare -A provider_live=()
  declare -A provider_idle=()
  # The KEY of these arrays is the CREDENTIAL ACCOUNT the lane spends from,
  # not a provider name: the ceiling binds an account, and one account is
  # recorded under several provider spellings. See
  # fm_dispatch_guard_account_of_meta.
  #
  # The live-lane ceiling is HOME-LOCAL: it counts this home's own lanes. The
  # per-account ceiling counts the account's lanes across this firstmate's
  # registered homes, because one firstmate's homes hold one copy of each
  # credential. So the walk covers every registered home, and only this
  # home's own lanes feed the home-local live-lane ceiling.
  while IFS= read -r home; do
    [ -n "$home" ] || continue
    [ -d "$home/state" ] || continue
    for meta in "$home"/state/*.meta; do
      [ -e "$meta" ] || continue
      backend="$(fm_backend_of_meta "$meta")"
      raw_target="$(fm_backend_target_of_meta "$meta")"
      target="$(lane_target "$backend" "$raw_target")"
      provider="$(fm_dispatch_guard_account_of_meta "$meta")"
      if [ -z "$target" ]; then
        # A meta with no resolvable endpoint is unknown and must not free a slot.
        log_event "LANE_UNRESOLVED meta=$(basename "$meta") home=$(basename "$home")"
        provider_live["$provider"]=$(( ${provider_live["$provider"]:-0} + 1 ))
        if [ "$home" = "$FM_HOME" ]; then
          live=$((live + 1))
        fi
        continue
      fi
      if [ $((SECONDS - started)) -ge "$budget" ]; then
        incomplete=1
        break 2
      fi
      case "$(fm_dispatch_guard_lane_classify "$backend" "$target")" in
        absent) : ;;                             # proven gone
        idle)
          provider_idle["$provider"]=$(( ${provider_idle["$provider"]:-0} + 1 ))
          if [ "$home" = "$FM_HOME" ]; then idle=$((idle + 1)); fi ;;
        unverified)
          log_event "LANE_UNVERIFIED meta=$(basename "$meta") backend=${backend}"
          provider_live["$provider"]=$(( ${provider_live["$provider"]:-0} + 1 ))
          if [ "$home" = "$FM_HOME" ]; then live=$((live + 1)); fi ;;
        *)
          provider_live["$provider"]=$(( ${provider_live["$provider"]:-0} + 1 ))
          if [ "$home" = "$FM_HOME" ]; then live=$((live + 1)); fi ;; # working, ambiguous, or unknown
      esac
    done
  done < <(fm_dispatch_guard_fleet_homes)
  if [ "$incomplete" = 1 ]; then
    refuse "the live-lane inventory did not finish within ${budget}s (${live} lanes probed so far), so the ceiling cannot be proven clear. Free a lane, raise FM_DISPATCH_GUARD_LANE_BUDGET_S deliberately, or set FM_DISPATCH_GUARD_BYPASS=1 (logged)."
  fi
  # Live-lane ceiling (home-local).
  cap=$(fm_dispatch_guard_lane_cap)
  if [ "$live" -ge "$cap" ]; then
    refuse "${live} working or unknown crewmate lanes and ${idle} idle lanes exist, counted per window/pane rather than per session (cap ${cap}). Stop one, or raise FM_DISPATCH_GUARD_MAX_LANES deliberately. Do not fan out on one host."
  fi
  # Per-account ceiling. The count is FLEET-WIDE over this firstmate's
  # registered homes, because the account is shared by every one of them: a
  # lane in a registered second-mate home is a lane on our account, so it
  # occupies our account's slot even though the lane itself is not ours.
  provider_cap="$(fm_dispatch_guard_provider_cap)"
  for provider in "${!provider_live[@]}"; do
    if [ "${provider_live[$provider]}" -ge "$provider_cap" ]; then
      refuse "${provider_live[$provider]} working or unknown lanes occupy credential account '${provider}' across this home and the registered second-mate homes of this firstmate (cap ${provider_cap}); stop one or raise FM_DISPATCH_GUARD_MAX_PROVIDER_LANES deliberately."
    fi
  done
fi

# ---------------------------------------------------------------------------
# Rule 4: quota ceiling. Refuse when the provider backing this spawn is
# exhausted, so a dead window cannot silently produce a fleet of instantly
# failing agents.
#
# Uses the most constrained window for that provider (the minimum
# percentRemaining across its windows), which is the binding constraint.
# Only enforced when quota-axi is available and returns parseable evidence;
# unknown data is disclosed uncertainty, never a block - a missing parser must
# fail open here so a quota bug can never wedge the whole fleet shut.
# ---------------------------------------------------------------------------
if command -v quota-axi >/dev/null 2>&1 \
   && command -v jq >/dev/null 2>&1 \
   && [ "${FM_DISPATCH_GUARD_QUOTA_BYPASS:-0}" != "1" ]; then
  case "$HARNESS" in
    codex)  want=codex ;;
    claude) want=claude ;;
    agy)    want=agy ;;
    pi|pi-signed)
      case "$MODEL" in *minimax*) want=minimax ;; *) want="" ;; esac
      ;;
    grok)   want=grok ;;
    kimi)   want=kimi ;;
    *)      want="" ;;
  esac
  if [ -n "$want" ]; then
    # Scope the quota check to the window family this spawn actually uses.
    # Taking the provider-wide minimum wrongly refuses a Gemini spawn because
    # AGY's UNUSED claude_gpt window hit 0% - found by independent review, and a
    # live over-refusal that would have wedged Gemini at the worst moment.
    scope=""
    if [ "$want" = agy ]; then
      case "$MODEL" in
        *gemini*) scope=gemini ;;
        *claude*) scope=claude_gpt ;;
      esac
    fi
    cache="$(mktemp "${TMPDIR:-/tmp}/fm-guard-quota.XXXXXX")"
    if timeout 90 quota-axi --json --max-age 60s > "$cache" 2>/dev/null; then
      if [ -n "$scope" ]; then
        pct="$(jq -r --arg p "$want" --arg s "$scope" '
          [ .providers[]? | select(.provider == $p) | .windows[]?
            | select((.id // "") | test($s)) | .percentRemaining ]
          | map(select(. != null)) | if length == 0 then "unknown" else min end
        ' "$cache" 2>/dev/null)"
      else
        pct="$(jq -r --arg p "$want" '
          [ .providers[]? | select(.provider == $p) | .windows[]?.percentRemaining ]
          | map(select(. != null)) | if length == 0 then "unknown" else min end
        ' "$cache" 2>/dev/null)"
      fi
      if [ -n "${pct:-}" ] && [ "$pct" != "unknown" ] && [ "${pct%%.*}" -le 0 ] 2>/dev/null; then
        rm -f "$cache"
        if [ -n "$scope" ]; then
          refuse "provider '${want}' ${scope} quota is exhausted (most constrained ${scope} window at ${pct}%). Check quota BEFORE dispatching; a dead provider produces only failing agents."
        else
          refuse "provider '${want}' quota is exhausted (most constrained window at ${pct}%). Check quota BEFORE dispatching; a dead provider produces only failing agents."
        fi
      fi
    fi
    rm -f "$cache"
  fi
fi

# Every invocation is recorded, allowed ones included: an audit log that only
# holds refusals cannot answer "what did the guard actually see?", which is the
# question that caught a config-derived model never reaching this script.
log_event "ALLOW"
exit 0