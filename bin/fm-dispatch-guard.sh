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
#   model:   the CONCRETE model slug, already resolved from the harness default
#            when the caller passed no --model. An empty model is treated as a
#            caller error: the Sol ban cannot be enforced against "unknown".
#
# Exit: 0 allow, 64 refuse (with a specific, actionable reason on stderr).
#
# Overrides are deliberately narrow, documented, and logged - never silent:
#   FM_DISPATCH_GUARD_BYPASS=1        skip every bypassable check (logged)
#   FM_DISPATCH_GUARD_LOAD_BYPASS=1   skip only the load ceiling (logged)
#   FM_DISPATCH_GUARD_QUOTA_BYPASS=1  skip only the quota ceiling (logged)
#   FM_DISPATCH_GUARD_MAX_LANES=<n>   live-lane ceiling (default 4)
set -u

HARNESS="${1:-}"
MODEL="${2:-}"
LOG="${FM_DISPATCH_GUARD_LOG:-/root/.config/dispatch-guard.log}"

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
# ---------------------------------------------------------------------------
case "$MODEL" in
  "" )
    # An absent model is only dangerous where a harness silently defaults to
    # Sol. Refusing it everywhere would wedge every harness that legitimately
    # runs its own default, so this is scoped to the harness that owns the risk.
    if [ "$HARNESS" = codex ]; then
      refuse "no --model was given for a codex spawn, and ~/.codex/config.toml defaults model to gpt-6.1-sol. Pin the concrete model explicitly (bin/fm-harness.sh / config/crew-dispatch.json); the Sol ban has no bypass."
    fi
    ;;
  gpt-6.1-sol|*gpt-6.1-sol*)
    refuse "model '$MODEL' is gpt-6.1-sol, which is banned for spawned workers (captain ruling 2026-10-11). Pick a different model; this ban has no bypass."
    ;;
esac

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
# ---------------------------------------------------------------------------
if [ "${FM_DISPATCH_GUARD_LOAD_BYPASS:-0}" != "1" ]; then
  cores="$(nproc 2>/dev/null || echo 1)"
  load1="$(awk '{print int($1)}' /proc/loadavg 2>/dev/null || echo 0)"
  if [ "${load1:-0}" -ge "${cores:-1}" ] 2>/dev/null; then
    log_event "BYPASS_LOAD"
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
# counting files permanently refuses all dispatch. A lane counts only when the
# tmux session named in its meta still exists.
# ---------------------------------------------------------------------------
if [ -n "${FM_HOME:-}" ] && [ -d "${FM_HOME}/state" ]; then
  live_sessions=""
  if command -v tmux >/dev/null 2>&1; then
    live_sessions="$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"
  fi
  if [ -n "$live_sessions" ]; then
    live=0
    for meta in "${FM_HOME}"/state/*.meta; do
      [ -e "$meta" ] || continue
      win="$(grep -m1 '^window=' "$meta" 2>/dev/null | cut -d= -f2-)"
      [ -n "$win" ] || continue
      sess="${win%%:*}"
      [ -n "$sess" ] || continue
      if printf '%s\n' "$live_sessions" | grep -qxF "$sess"; then
        live=$((live + 1))
      fi
    done
    cap="${FM_DISPATCH_GUARD_MAX_LANES:-4}"
    if [ "$live" -ge "$cap" ]; then
      refuse "${live} live crewmate lanes already exist (cap ${cap}). Stop one, or raise FM_DISPATCH_GUARD_MAX_LANES deliberately. Do not fan out on one host."
    fi
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

exit 0