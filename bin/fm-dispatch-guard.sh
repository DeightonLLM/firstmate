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
# Overrides are deliberately narrow, documented, and logged - never silent:
#   FM_DISPATCH_GUARD_BYPASS=1        skip every bypassable check (logged)
#   FM_DISPATCH_GUARD_LOAD_BYPASS=1   skip only the load ceiling (logged)
#   FM_DISPATCH_GUARD_QUOTA_BYPASS=1  skip only the quota ceiling (logged)
#   FM_DISPATCH_GUARD_MAX_LANES=<n>   live-lane ceiling (default 4)
#   FM_DISPATCH_GUARD_LANE_BUDGET_S=<n>  wall-clock budget for the lane
#                                        inventory (default 30)
# Test seams (never set in production; they exist so the rules can be proven by
# observed behaviour instead of by reading this file):
#   FM_DISPATCH_GUARD_LOADAVG=<path>   read load from <path>, not /proc/loadavg
set -u

HARNESS="${1:-}"
MODEL="${2:-}"
LOG="${FM_DISPATCH_GUARD_LOG:-/root/.config/dispatch-guard.log}"

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

# From here down, every check is bypassable via the global bypass. The Sol ban
# above is deliberately evaluated FIRST so FM_DISPATCH_GUARD_BYPASS can never
# rescue it - an earlier ordering let the bypass return 0 for Sol, which is the
# exact silent failure this guard exists to prevent.
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
# endpoint problem can never silently under-count the cap. A lane the classifier
# cannot place at all (`unverified`) is disclosed in the log rather than counted,
# because counting unplaceable history forever is the wedge this rule must not
# recreate.
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

if [ -n "${FM_HOME:-}" ] && [ -d "${FM_HOME}/state" ]; then
  budget="${FM_DISPATCH_GUARD_LANE_BUDGET_S:-30}"
  case "$budget" in ''|*[!0-9]*) budget=30 ;; esac
  started=$SECONDS
  live=0
  incomplete=0
  for meta in "${FM_HOME}"/state/*.meta; do
    [ -e "$meta" ] || continue
    backend="$(fm_backend_of_meta "$meta")"
    raw_target="$(fm_backend_target_of_meta "$meta")"
    target="$(lane_target "$backend" "$raw_target")"
    if [ -z "$target" ]; then
      # A meta with no resolvable endpoint is not a lane this guard can place.
      # Disclosed rather than silently dropped.
      log_event "LANE_UNRESOLVED meta=$(basename "$meta")"
      continue
    fi
    if [ $((SECONDS - started)) -ge "$budget" ]; then
      incomplete=1
      break
    fi
    case "$(fm_backend_agent_state "$backend" "$target")" in
      dead|missing) : ;;                       # proven gone
      unverified) log_event "LANE_UNVERIFIED meta=$(basename "$meta") backend=${backend}" ;;
      *) live=$((live + 1)) ;;                 # alive, ambiguous, or unreadable
    esac
  done
  if [ "$incomplete" = 1 ]; then
    refuse "the live-lane inventory did not finish within ${budget}s (${live} lanes probed so far), so the ceiling cannot be proven clear. Free a lane, raise FM_DISPATCH_GUARD_LANE_BUDGET_S deliberately, or set FM_DISPATCH_GUARD_BYPASS=1 (logged)."
  fi
  cap="${FM_DISPATCH_GUARD_MAX_LANES:-4}"
  if [ "$live" -ge "$cap" ]; then
    refuse "${live} live crewmate lanes already exist, counted per window/pane rather than per session (cap ${cap}). Stop one, or raise FM_DISPATCH_GUARD_MAX_LANES deliberately. Do not fan out on one host."
  fi
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
    cache="$(mktemp "${TMPDIR:-/tmp}/fm-guard-quota.XXXXXX")"
    if timeout 90 quota-axi --json --max-age 60s > "$cache" 2>/dev/null; then
      pct="$(jq -r --arg p "$want" '
        [ .providers[]? | select(.provider == $p) | .windows[]?.percentRemaining ]
        | map(select(. != null)) | if length == 0 then "unknown" else min end
      ' "$cache" 2>/dev/null)"
      if [ -n "${pct:-}" ] && [ "$pct" != "unknown" ] && [ "${pct%%.*}" -le 0 ] 2>/dev/null; then
        rm -f "$cache"
        refuse "provider '${want}' quota is exhausted (most constrained window at ${pct}%). Check quota BEFORE dispatching; a dead provider produces only failing agents."
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