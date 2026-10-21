#!/usr/bin/env bash
# fm-capacity-gate.sh - the SINGLE shared owner of the disk-capacity ladder and
# of the dispatch admission decision it drives.
#
# WHY THIS FILE EXISTS.
#
# The Captain's standing order: *"lets reclaim but refuse"* and *"im not wanting
# it to go past 80% really from here on in."* The 80% ceiling is real and landed
# (e552a42): bin/controller-resource-audit.sh carries the ladder vocabulary
# (CAPACITY_BLOCK_NEW_PLACEMENT / CAPACITY_REVIEW_REQUIRED /
# CAPACITY_EARLY_WARNING / CAPACITY_OK).
#
# What was NOT real was the ENFORCEMENT. Nothing in the dispatch path consulted
# the verdict, so the root filesystem sat at 79-80% and the dispatch path never
# noticed. A ceiling that is documented but not enforced is the same failure as
# a fake freedKB.
#
# ONE LADDER, ONE READER, NO THIRD GATE.
#
# This file is that single shared owner. It owns:
#   1. the ladder itself - the thresholds and the verdict tokens, and
#   2. the admission decision - measure, verdict, reclaim, re-measure,
#      re-verdict, then admit or refuse.
#
# bin/controller-resource-audit.sh delegates its `verdict` subcommand here, so
# the repo carries exactly ONE copy of the thresholds. bin/fm-spawn.sh is the
# ONE reader that consults this owner before a fresh placement. Any other
# surface that needs the ladder - for example the read-only placement audit on
# the HD2 host - can call `fm-capacity-gate.sh verdict <percent>` instead of
# copying the thresholds into its own script and drifting from them.
#
# PROJECT CAPACITY IS A DIFFERENT AXIS.
#
# bin/fm-project-capacity-lib.sh gates a project's DECLARED worker capacity
# (config/project-capacity). That is a different axis from disk and stays
# exactly where it is. This file never widens it to mean disk.
#
# THE LADDER (root filesystem usage):
#   >= 80%  CAPACITY_BLOCK_NEW_PLACEMENT  - the Captain's hard ceiling
#   >= 75%  CAPACITY_REVIEW_REQUIRED       - review before placing anything new
#   >= 70%  CAPACITY_EARLY_WARNING         - act while there is still headroom
#   <  70%  CAPACITY_OK
#
# RECLAIM FIRST, THEN REFUSE.
#
# On CAPACITY_BLOCK_NEW_PLACEMENT this gate does not simply refuse. It runs the
# reclaimer (bin/fm-capacity-reclaim.sh --apply, tiers 1-2), re-measures the
# disk, and re-reads the verdict. A disk that came back under the ceiling is
# ADMITTED, and the reclaim is logged with what it actually freed. Only a disk
# that is STILL at or over the ceiling after the reclaim is refused.
#
# FAIL CLOSED ON UNREADABLE EVIDENCE.
#
# A disk that cannot be measured is refused, and the refusal says so. An
# unmeasurable disk must not pass silently - the same contract the load
# ceiling has.
#
# BOUNDED AND SERIALISED.
#
# The reclaim runs under a wall-clock timeout and under an exclusive lock, so a
# dispatch can never hang on it and two concurrent spawns can never both
# reclaim. A dispatch that hangs is worse than a dispatch that refuses.
#
# THE LOCK.
#
# flock with a dedicated lock file is the primary mechanism, on a HOST-level
# path: the reclaim frees root filesystem space, so two HOMES on one host
# contend for the same bytes and a per-home lock would not serialise them. A
# portable mkdir-based lock is the fallback for surfaces without flock (macOS
# has no flock), with stale-holder takeover so a killed holder cannot wedge
# dispatch forever. fm-wake-lib.sh's fm_lock_* helpers are deliberately NOT
# used here: that file is owned by another lane and is being changed now.
#
# Usage:
#   fm-capacity-gate.sh verdict <percent>   print the ladder token for 0-100
#   fm-capacity-gate.sh check               run the admission decision
#   fm-capacity-gate.sh --help
#
# Exit: 0 admitted, 64 refused (with a specific, actionable reason on stderr),
#       2 usage error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- the ladder ---------------------------------------------------------------
# The thresholds live HERE and nowhere else in the repo. bin/controller-resource-audit.sh
# delegates its `verdict` subcommand to this function, so there is one ladder.

fm_capacity_verdict() {  # <integer 0-100>
  local pct=$1
  case "$pct" in
    ''|*[!0-9]*) return 2 ;;
  esac
  [ "$pct" -le 100 ] || return 2
  if [ "$pct" -ge 80 ]; then
    printf 'CAPACITY_BLOCK_NEW_PLACEMENT\n'
  elif [ "$pct" -ge 75 ]; then
    printf 'CAPACITY_REVIEW_REQUIRED\n'
  elif [ "$pct" -ge 70 ]; then
    printf 'CAPACITY_EARLY_WARNING\n'
  else
    printf 'CAPACITY_OK\n'
  fi
  return 0
}

# --- configuration -------------------------------------------------------------

CAPACITY_DF="${FM_CAPACITY_GATE_DF:-df -P /}"
CAPACITY_RECLAIMER="${FM_CAPACITY_GATE_RECLAIMER:-$SCRIPT_DIR/fm-capacity-reclaim.sh}"
CAPACITY_RECLAIM_TIMEOUT_S="${FM_CAPACITY_GATE_RECLAIM_TIMEOUT_S:-90}"
CAPACITY_LOCK_WAIT_S="${FM_CAPACITY_GATE_LOCK_WAIT_S:-30}"

# The lock is HOST-level on purpose: the reclaim frees root filesystem space,
# so two homes on one host contend for the same bytes.
if [ -n "${FM_CAPACITY_GATE_LOCK:-}" ]; then
  CAPACITY_LOCK_FILE="$FM_CAPACITY_GATE_LOCK"
elif [ -d /var/lock ] && [ -w /var/lock ]; then
  CAPACITY_LOCK_FILE="/var/lock/fm-capacity-gate.lock"
else
  CAPACITY_LOCK_FILE="${TMPDIR:-/tmp}/fm-capacity-gate.lock"
fi

# The log location resolves on ANY surface, not only where the operator happens
# to be root. Mirrors the dispatch guard's resolution.
if [ -n "${FM_CAPACITY_GATE_LOG:-}" ]; then
  CAPACITY_LOG="$FM_CAPACITY_GATE_LOG"
elif [ -n "${XDG_CONFIG_HOME:-}" ]; then
  CAPACITY_LOG="${XDG_CONFIG_HOME}/capacity-gate.log"
elif [ -n "${HOME:-}" ] && [ -w "${HOME}" ]; then
  CAPACITY_LOG="${HOME}/.config/capacity-gate.log"
else
  CAPACITY_LOG="${TMPDIR:-/tmp}/fm-capacity-gate.log"
fi

case "$CAPACITY_RECLAIM_TIMEOUT_S" in
  ''|*[!0-9]*) CAPACITY_RECLAIM_TIMEOUT_S=90 ;;
esac
case "$CAPACITY_LOCK_WAIT_S" in
  ''|*[!0-9]*) CAPACITY_LOCK_WAIT_S=30 ;;
esac

# The REAL rm, resolved by absolute path.
#
# On this host `rm` on PATH is a recoverable-delete shim: it moves its target
# into the trash, and on a single filesystem that FREES NOTHING while reporting
# success. A lock cleanup that went through it would leave the lock in place
# forever - the cleanup would claim to have released the lock while the lock
# was still held, and every later dispatch would wait out the stale-lock
# window for nothing. This is the same "fake freedKB" failure the reclaimer is
# built to avoid, so the gate resolves the real binary the same way and refuses
# the shim even when it is found at one of those paths.
CAPACITY_REAL_RM=""
for _rm in /usr/bin/rm /bin/rm; do
  [ -x "$_rm" ] || continue
  _resolved=$(readlink -f "$_rm" 2>/dev/null || printf '%s' "$_rm")
  case "$_resolved" in */shims/*|*/mavis-trash) continue ;; esac
  CAPACITY_REAL_RM="$_rm"; break
done

capacity_lock_remove() {  # <path>
  [ -n "$CAPACITY_REAL_RM" ] || return 1
  "$CAPACITY_REAL_RM" -rf -- "$1" 2>/dev/null
}

log_event() {
  mkdir -p "$(dirname "$CAPACITY_LOG")" 2>/dev/null || true
  printf '%s %s\n' "$(date -u +%FT%TZ)" "$1" >> "$CAPACITY_LOG" 2>/dev/null || true
}

refuse() {
  echo "capacity-gate: REFUSED - $1" >&2
  log_event "CAPACITY_REFUSED reason=\"$1\""
  return 64
}

# --- measurement ---------------------------------------------------------------

# fm_capacity_measure_pct: the root filesystem usage as a whole percent.
# Prints nothing and fails when the disk cannot be measured, so an unmeasurable
# disk can never be silently treated as a healthy one.
fm_capacity_measure_pct() {
  local pct
  pct="$($CAPACITY_DF 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')" || pct=
  case "$pct" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$pct" -le 100 ] || return 1
  printf '%s' "$pct"
}

# --- the reclaim ---------------------------------------------------------------

# fm_capacity_run_bounded: run a command with a wall-clock bound.
#
# `timeout` is the primary mechanism, but it is NOT present on stock macOS and
# the gate runs on Brandon Compute. Without a bound the reclaim could wedge the
# dispatch path, and a dispatch that hangs is worse than a dispatch that
# refuses - so the portable fallback is a watchdog that stops the child, not the
# absence of a bound.
#
# Exit 124 means "stopped by the bound", matching timeout(1).
fm_capacity_run_bounded() {  # <seconds> <command...>
  local secs=$1; shift
  local pid watchdog rc outfile
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
    return $?
  fi
  # Portable fallback.
  #
  # The child's output goes to a FILE, not to a pipe. A command substitution
  # waits for every process holding the pipe's write end, so an orphaned
  # grandchild would keep the gate waiting long past the bound - the bound
  # would stop the child and the gate would still hang on the pipe. Writing to
  # a file makes the bound the only thing that decides when the gate returns.
  outfile="$(mktemp "${TMPDIR:-/tmp}/fm-capacity-reclaim.XXXXXX")" || return 1
  "$@" > "$outfile" 2>&1 &
  pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) 2>/dev/null &
  watchdog=$!
  wait "$pid"; rc=$?
  kill "$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  cat "$outfile" 2>/dev/null
  rm -f "$outfile" 2>/dev/null || true
  # 143 is 128+SIGTERM: the watchdog stopped it.
  [ "$rc" -eq 143 ] && return 124
  return "$rc"
}

# fm_capacity_reclaim: run the reclaimer under a wall-clock bound and report
# what it did. Prints a summary; the authoritative "bytes freed" is the df
# delta the gate measures itself, never a number the reclaim claims.
fm_capacity_reclaim() {
  local out rc
  if [ ! -x "$CAPACITY_RECLAIMER" ]; then
    printf 'reclaim-not-run: no executable reclaimer at %s' "$CAPACITY_RECLAIMER"
    return 1
  fi
  out="$(fm_capacity_run_bounded "$CAPACITY_RECLAIM_TIMEOUT_S" "$CAPACITY_RECLAIMER" --apply 2>&1)"
  rc=$?
  if [ "$rc" -eq 124 ]; then
    printf 'reclaim-timed-out: the reclaim exceeded %ss and was stopped' "$CAPACITY_RECLAIM_TIMEOUT_S"
    return 1
  fi
  if [ "$rc" -ne 0 ]; then
    printf 'reclaim-failed: exit %s' "$rc"
    return 1
  fi
  # Keep the reclaimer's own measurement visible without letting it become the
  # authoritative number.
  printf '%s' "$out" | grep -E '^(measured|capacity|tier [12]):' | head -6 | sed 's/^/reclaim: /'
  return 0
}

# --- the critical section ------------------------------------------------------

# fm_capacity_critical_section: the lock, the reclaim and the re-measure, run
# in a SUBSHELL.
#
# The subshell is not decoration. Holding a lock needs a file descriptor that
# stays open for the whole critical section, and `exec` applies its
# redirections PERMANENTLY to the shell that runs it. An `exec ... 2>/dev/null`
# in the parent would silence the parent's stderr for the rest of the run -
# which turns the refusal message into a SILENT refusal. That is fail-open, and
# it is exactly the failure this gate exists to prevent. The subshell keeps
# that blast radius inside itself.
#
# Prints "<pct>|<verdict>|<summary>" on stdout.
# Exit 0 = the section ran, 75 = the lock could not be acquired in time,
# Exit 4 = the disk could not be measured.
fm_capacity_critical_section() {
  (
    local pct verdict summary lockdir pid
    if command -v flock >/dev/null 2>&1; then
      { exec 9>>"$CAPACITY_LOCK_FILE"; } 2>/dev/null || exit 75
      flock -w "$CAPACITY_LOCK_WAIT_S" 9 || exit 75
    else
      # Portable fallback: an atomic mkdir is the lock. A holder that died must
      # not wedge dispatch forever, so a lock whose recorded pid is gone and
      # whose directory is older than the wait is taken over.
      #
      # The age check uses `find -mmin`, not `stat -c %Y`: BSD stat (macOS) has
      # no -c flag, so a stat-based age check would silently never fire on
      # Brandon Compute and a killed holder would wedge the dispatch forever.
      lockdir="${CAPACITY_LOCK_FILE}.d"
      while :; do
        if mkdir "$lockdir" 2>/dev/null; then
          printf '%s\n' "$$" > "$lockdir/pid" 2>/dev/null || true
          # Release the mkdir lock when this subshell ends, however it ends. A
          # lock left behind would make the next dispatch wait out the full
          # stale-lock window for nothing. The path is expanded HERE, not at
          # trap time: `lockdir` is a function-local, so it is already unset
          # when the EXIT trap runs and "$lockdir" would expand to nothing.
          trap 'capacity_lock_remove '"$lockdir"' || true' EXIT
          break
        fi
        pid="$(cat "$lockdir/pid" 2>/dev/null || true)"
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
          if find "$lockdir" -maxdepth 0 -mmin "+$CAPACITY_LOCK_WAIT_S" -print -quit 2>/dev/null | grep -q .; then
            capacity_lock_remove "$lockdir" || true
            continue
          fi
        fi
        if ! find "$lockdir" -maxdepth 0 -mmin "+$CAPACITY_LOCK_WAIT_S" -print -quit 2>/dev/null | grep -q .; then
          exit 75
        fi
        sleep 1
      done
    fi

    if ! pct="$(fm_capacity_measure_pct)"; then exit 4; fi
    if ! verdict="$(fm_capacity_verdict "$pct")"; then exit 4; fi

    if [ "$verdict" = "CAPACITY_BLOCK_NEW_PLACEMENT" ]; then
      summary="$(fm_capacity_reclaim)"
      # Re-measure. The reclaim's own claim is never trusted: this gate
      # measures the disk itself.
      if ! pct="$(fm_capacity_measure_pct)"; then exit 4; fi
      if ! verdict="$(fm_capacity_verdict "$pct")"; then exit 4; fi
    else
      summary="no reclaim was needed: the disk came back under the ceiling while waiting for the reclaim lock"
    fi

    # Flatten the summary onto one line and strip the field separator, so the
    # parent can carry it in one field.
    summary="$(printf '%s' "$summary" | tr '\n|' '; ')"
    printf '%s|%s|%s\n' "$pct" "$verdict" "$summary"
    exit 0
  )
}

# --- the admission decision ----------------------------------------------------

# fm_capacity_gate_check: the ONE decision. Returns 0 to admit, 64 to refuse.
fm_capacity_gate_check() {
  local pct verdict out pct2 verdict2 summary rest rc

  # The bypass is narrow: it skips THIS check only, and it is always logged and
  # always printed, so it can never be a silent path.
  if [ "${FM_CAPACITY_GATE_BYPASS:-0}" = "1" ] || [ "${FM_DISPATCH_GUARD_CAPACITY_BYPASS:-0}" = "1" ]; then
    log_event "BYPASS_CAPACITY"
    echo "capacity-gate: BYPASS - the disk capacity ceiling was skipped for this placement (FM_CAPACITY_GATE_BYPASS=1)" >&2
    return 0
  fi

  if ! pct="$(fm_capacity_measure_pct)"; then
    refuse "the root filesystem usage could not be measured, so the 80% capacity ceiling cannot be evaluated. An unmeasurable disk must not pass silently: free space or re-read the host, or set FM_CAPACITY_GATE_BYPASS=1 to skip this one check (logged)."
    return 64
  fi
  if ! verdict="$(fm_capacity_verdict "$pct")"; then
    refuse "the root filesystem usage read as an unusable value ('${pct}'), so the capacity ceiling cannot be evaluated."
    return 64
  fi

  if [ "$verdict" != "CAPACITY_BLOCK_NEW_PLACEMENT" ]; then
    log_event "CAPACITY_ALLOW pct=${pct} verdict=${verdict}"
    return 0
  fi

  # At the ceiling. Reclaim first, then decide again.
  log_event "CAPACITY_BLOCKED pct=${pct} verdict=${verdict} action=reclaim"
  echo "capacity-gate: the root filesystem is at ${pct}% (CAPACITY_BLOCK_NEW_PLACEMENT). Reclaiming before deciding." >&2

  out="$(fm_capacity_critical_section)"
  rc=$?
  case "$rc" in
    0)
      pct2="${out%%|*}"
      rest="${out#*|}"
      verdict2="${rest%%|*}"
      summary="${rest#*|}"
      ;;
    75)
      # Another reclaim holds the lock. Do not reclaim concurrently; re-measure
      # and let the outcome decide.
      summary="reclaim-skipped: another reclaim held the lock for longer than ${CAPACITY_LOCK_WAIT_S}s"
      log_event "CAPACITY_LOCK_BUSY wait=${CAPACITY_LOCK_WAIT_S}"
      echo "capacity-gate: ${summary}" >&2
      if ! pct2="$(fm_capacity_measure_pct)"; then
        refuse "the root filesystem usage could not be measured while another reclaim held the lock, so the capacity ceiling cannot be evaluated."
        return 64
      fi
      if ! verdict2="$(fm_capacity_verdict "$pct2")"; then
        refuse "the root filesystem usage read as an unusable value ('${pct2}'), so the capacity ceiling cannot be evaluated."
        return 64
      fi
      ;;
    4)
      refuse "the root filesystem usage could not be measured around the reclaim, so the capacity ceiling cannot be evaluated."
      return 64
      ;;
    *)
      summary="reclaim-section-failed: exit ${rc}"
      if ! pct2="$(fm_capacity_measure_pct)"; then
        refuse "the root filesystem usage could not be measured after the reclaim section failed, so the capacity ceiling cannot be evaluated."
        return 64
      fi
      if ! verdict2="$(fm_capacity_verdict "$pct2")"; then
        refuse "the root filesystem usage read as an unusable value ('${pct2}'), so the capacity ceiling cannot be evaluated."
        return 64
      fi
      ;;
  esac

  if [ "$verdict2" != "CAPACITY_BLOCK_NEW_PLACEMENT" ]; then
    log_event "CAPACITY_ALLOW pct=${pct2} verdict=${verdict2} reason=reclaimed"
    echo "capacity-gate: the root filesystem is back at ${pct2}% (${verdict2}); admitting the placement." >&2
    return 0
  fi

  log_event "CAPACITY_REFUSED_AFTER_RECLAIM pct=${pct2} verdict=${verdict2}"
  refuse "the root filesystem is still at ${pct2}% after the reclaim (CAPACITY_BLOCK_NEW_PLACEMENT), so the placement is refused. What the reclaim did: ${summary:-no reclaim was run}. The reclaim only clears regenerable caches and build litter and the merged worktree pool; the remaining bytes are archive-class material that is cold but valuable and is reported, never deleted. Move the archive material off this filesystem, or free space by hand, then dispatch again."
  return 64
}

# --- entry ---------------------------------------------------------------------

usage() {
  sed -n '2,60p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  verdict)
    [ "$#" -ge 2 ] || { echo "usage: fm-capacity-gate.sh verdict <percent 0-100>" >&2; exit 2; }
    out="$(fm_capacity_verdict "$2")" || { echo "fm-capacity-gate.sh: verdict needs a percent 0-100, got '$2'" >&2; exit 2; }
    printf '%s\n' "$out"
    exit 0
    ;;
  check)
    fm_capacity_gate_check
    exit $?
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  "")
    echo "usage: fm-capacity-gate.sh {verdict <percent> | check}" >&2
    exit 2
    ;;
  *)
    echo "usage: fm-capacity-gate.sh {verdict <percent> | check}" >&2
    exit 2
    ;;
esac
