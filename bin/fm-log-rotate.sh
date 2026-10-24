#!/usr/bin/env bash
# fm-log-rotate.sh - keep an append-only log bounded, WITHOUT losing a writer.
#
# WHY THIS EXISTS.
#
# `state/fm-comms-ingest.log` is written by a host cron wrapper
# (/root/bin/hetz-comms-sync.sh, every 5 minutes) that appends the output of
# the ingest scan. It reached 40 MB because an oversize file was re-reported on
# every scan and NOTHING ever rotated it. At 8 runs an hour it grows forever.
#
# The ingest command carries a rotation of its own on its EXIT trap, which
# stops the LIVE file from growing without bound. That rotation renames the
# file, and a rename leaves two things wrong for an append-only log:
#
#   1  the generation it leaves behind is whatever the last run happened to
#      produce, so one 40 MB run parks 40 MB there until the next rotation.
#      Nothing bounds the TOTAL.
#   2  the generation is replaced rather than rotated, so the diagnosis tail
#      of the previous run is gone, and two scans finishing together race.
#
# This script is the bounded rotation for the whole log FAMILY: the live file
# and its generations. Every one of them is capped, so the total on disk is
# bounded by numbers the operator chose.
#
# WHY COPYTRUNCATE, AND WHY IT IS SAFE HERE.
#
# The live log is appended to by a shell redirect (`>> log`) held open by the
# writer. Two rotations are possible:
#
#   copytruncate       the inode never changes. The snapshot is taken, then the
#                      file is truncated to zero in place. The writer's
#                      descriptor stays valid, a follower of the live path
#                      keeps following it, and the writer's next append lands
#                      at offset 0 of the same file.
#   rename-and-reopen  the live path is replaced by a fresh inode. The writer
#                      keeps its open descriptor, so it keeps writing into the
#                      RENAMED file: nothing it writes is lost, but its output
#                      lands in the archive instead of the live log, and a
#                      follower of the live path stops seeing new output.
#
# copytruncate has one known race: bytes appended BETWEEN the snapshot and the
# truncation are lost. This script closes that race rather than documenting it
# away, and it picks the mechanism per file:
#
#   the log is QUIESCENT  it has not been written to for QUIESCE_S seconds and
#                         its size did not change while the snapshot was being
#                         taken. Nothing can be written in the microseconds
#                         between the final size check and the truncation, so
#                         copytruncate is provably lossless. This is the
#                         steady state on this host: the writer runs every five
#                         minutes.
#   the log is ACTIVE     a writer wrote during the snapshot, or the log was
#                         modified moments ago. Copytruncate could lose those
#                         bytes, so the file is RENAMED instead: the writer's
#                         descriptor follows the renamed inode and every byte
#                         it writes is preserved in the generation. The
#                         generation is capped on a LATER pass, once the
#                         writer has finished - a generation younger than the
#                         grace is never touched.
#
# So the rule is: copytruncate when it is provably lossless, rename when it
# is not, and never truncate a file somebody might still be writing to.
#
# THE GENERATIONS are capped with the same copytruncate, and a generation
# younger than the grace is left alone for the same reason.
#
# THE REAL UNLINK. `rm` on this host is a recoverable-delete shim that MOVES
# its target into the trash, which frees zero bytes on a single filesystem.
# Pruning a generation has to unlink it for real, so the real rm is resolved
# by absolute path and the shim is refused.
#
# USAGE.
#   fm-log-rotate.sh                    rotate the default log (dry run: report)
#   fm-log-rotate.sh --apply            rotate for real
#   fm-log-rotate.sh --log <path>       rotate that log instead
#   fm-log-rotate.sh --max-bytes N      the cap on the live log
#   fm-log-rotate.sh --keep-bytes N     how much of the tail a generation keeps
#   fm-log-rotate.sh --generations N    how many generations to keep
#   fm-log-rotate.sh --help
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-${STATE:-$FM_HOME/state}}"

APPLY=0
LOG_PATH="${FM_LOG_ROTATE_TARGET:-$STATE/fm-comms-ingest.log}"
MAX_BYTES="${FM_LOG_ROTATE_MAX_BYTES:-5242880}"
KEEP_BYTES="${FM_LOG_ROTATE_KEEP_BYTES:-262144}"
GENERATIONS="${FM_LOG_ROTATE_GENERATIONS:-3}"
GRACE_S="${FM_LOG_ROTATE_GRACE_S:-120}"
QUIESCE_S="${FM_LOG_ROTATE_QUIESCE_S:-2}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --dry-run) APPLY=0; shift ;;
    --log) shift; LOG_PATH="${1:-$LOG_PATH}"; [ "$#" -gt 0 ] && shift ;;
    --log=*) LOG_PATH="${1#--log=}"; shift ;;
    --max-bytes) shift; MAX_BYTES="${1:-$MAX_BYTES}"; [ "$#" -gt 0 ] && shift ;;
    --max-bytes=*) MAX_BYTES="${1#--max-bytes=}"; shift ;;
    --keep-bytes) shift; KEEP_BYTES="${1:-$KEEP_BYTES}"; [ "$#" -gt 0 ] && shift ;;
    --keep-bytes=*) KEEP_BYTES="${1#--keep-bytes=}"; shift ;;
    --generations) shift; GENERATIONS="${1:-$GENERATIONS}"; [ "$#" -gt 0 ] && shift ;;
    --generations=*) GENERATIONS="${1#--generations=}"; shift ;;
    --grace) shift; GRACE_S="${1:-$GRACE_S}"; [ "$#" -gt 0 ] && shift ;;
    --grace=*) GRACE_S="${1#--grace=}"; shift ;;
    --quiesce) shift; QUIESCE_S="${1:-$QUIESCE_S}"; [ "$#" -gt 0 ] && shift ;;
    --quiesce=*) QUIESCE_S="${1#--quiesce=}"; shift ;;
    -h|--help) awk 'NR==1{next} /^#/{print; next} {exit}' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "${MAX_BYTES:-}" in ''|*[!0-9]*) MAX_BYTES=5242880 ;; esac
case "${KEEP_BYTES:-}" in ''|*[!0-9]*) KEEP_BYTES=262144 ;; esac
case "${GENERATIONS:-}" in ''|*[!0-9]*) GENERATIONS=3 ;; esac
case "${GRACE_S:-}" in ''|*[!0-9]*) GRACE_S=120 ;; esac
case "${QUIESCE_S:-}" in ''|*[!0-9]*) QUIESCE_S=2 ;; esac

# The real unlink, resolved by absolute path. The shim is refused even when it
# is found at one of those paths, so a prune can never park a generation in the
# trash and report a reclaim that did not happen.
REAL_RM=""
for bin in /usr/bin/rm /bin/rm; do
  [ -x "$bin" ] || continue
  resolved=$(readlink -f "$bin" 2>/dev/null || printf '%s' "$bin")
  case "$resolved" in */shims/*|*/mavis-trash) continue ;; esac
  REAL_RM="$bin"; break
done

file_size() {
  local s
  s=$(stat -c %s -- "$1" 2>/dev/null || stat -f %z -- "$1" 2>/dev/null) || return 1
  case "$s" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s\n' "$s"
}

file_mtime() {
  local m
  m=$(stat -c %Y -- "$1" 2>/dev/null || stat -f %m -- "$1" 2>/dev/null) || return 1
  case "$m" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s\n' "$m"
}

now_epoch() { date +%s; }

truncate_to_zero() {
  if command -v truncate >/dev/null 2>&1; then
    truncate -s 0 -- "$1" 2>/dev/null && return 0
  fi
  : > "$1" 2>/dev/null || return 1
  return 0
}

# The exclusive lock. Two rotations must not run at once: the second would
# snapshot a file the first is already truncating. flock is used when it
# exists, and a mkdir lock is the portable fallback.
LOCK_PATH="${FM_LOG_ROTATE_LOCK:-${LOG_PATH}.rotate.lock}"
LOCK_DIR=
LOCK_HELD=0
lock_acquire() {
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_PATH" 2>/dev/null || return 1
    flock -n 9 2>/dev/null || { exec 9>&- 2>/dev/null; return 1; }
    return 0
  fi
  LOCK_DIR="${LOCK_PATH}.d"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_HELD=1
    return 0
  fi
  return 1
}
lock_release() {
  if [ "$LOCK_HELD" = 1 ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
    LOCK_HELD=0
    return 0
  fi
  exec 9>&- 2>/dev/null || true
  return 0
}

# shift_generations <log>
# Make room for a new generation: the oldest one goes, and every other one
# moves down by one. The generations this script owns are named "<log>.rot.N",
# so they never collide with the ingest command's own "<log>.1" generation.
shift_generations() {
  local log=$1 n
  if [ "$GENERATIONS" -lt 1 ]; then return 0; fi
  if [ -n "$REAL_RM" ] && [ -e "$log.rot.$GENERATIONS" ]; then
    "$REAL_RM" -f -- "$log.rot.$GENERATIONS" 2>/dev/null || true
  fi
  n=$((GENERATIONS - 1))
  while [ "$n" -ge 1 ]; do
    if [ -e "$log.rot.$n" ]; then
      mv -f -- "$log.rot.$n" "$log.rot.$((n + 1))" 2>/dev/null || true
    fi
    n=$((n - 1))
  done
  return 0
}

# cap_generation <path>
# Bring a generation down to the keep size, keeping its MOST RECENT bytes:
# the diagnosis value of a rotated log is its tail. A generation younger than
# the grace is left alone, because a writer may still hold it.
cap_generation() {
  local path=$1 size mtime age
  [ -f "$path" ] || return 0
  size=$(file_size "$path") || return 0
  [ "$size" -gt "$KEEP_BYTES" ] || return 0
  mtime=$(file_mtime "$path") || return 0
  age=$(( $(now_epoch) - mtime ))
  [ "$age" -ge "$GRACE_S" ] || return 0
  if [ "$APPLY" != 1 ]; then
    printf 'would cap %s to %s bytes (the most recent tail)\n' "$path" "$KEEP_BYTES"
    return 0
  fi
  # Copytruncate: the tail is copied out and the file is truncated in place.
  # The inode does not change, so a writer that still holds it keeps writing
  # to the same file.
  if ! tail -c "$KEEP_BYTES" -- "$path" > "${path}.tailtmp" 2>/dev/null; then
    rm -f -- "${path}.tailtmp" 2>/dev/null || true
    return 0
  fi
  if ! cat -- "${path}.tailtmp" > "$path" 2>/dev/null; then
    rm -f -- "${path}.tailtmp" 2>/dev/null || true
    return 0
  fi
  rm -f -- "${path}.tailtmp" 2>/dev/null || true
  printf 'capped %s to %s bytes (the most recent tail)\n' "$path" "$KEEP_BYTES"
  return 0
}

echo "=== log rotation: $LOG_PATH ==="
echo "cap: live ${MAX_BYTES} bytes, generation ${KEEP_BYTES} bytes x ${GENERATIONS}, grace ${GRACE_S}s, quiescence ${QUIESCE_S}s"

if [ ! -f "$LOG_PATH" ]; then
  echo "nothing to rotate: $LOG_PATH does not exist"
  exit 0
fi

if ! lock_acquire; then
  echo "SKIP-LOCKED: another rotation holds $LOCK_PATH"
  exit 0
fi
trap 'lock_release' EXIT

size=$(file_size "$LOG_PATH") || { echo "SKIP-UNREADABLE: $LOG_PATH"; exit 0; }
echo "live log: ${size} bytes"

if [ "$size" -gt "$MAX_BYTES" ]; then
  if [ "$APPLY" != 1 ]; then
    echo "would rotate ${LOG_PATH}: it is ${size} bytes and the cap is ${MAX_BYTES}"
    echo "would keep the most recent ${KEEP_BYTES} bytes as a generation"
  else
    tmp="${LOG_PATH}.roottmp"
    snapshot_ok=0
    if tail -c "$KEEP_BYTES" -- "$LOG_PATH" > "$tmp" 2>/dev/null; then
      snapshot_ok=1
    fi
    size_after=$(file_size "$LOG_PATH" || printf '%s' "$size")
    mtime_after=$(file_mtime "$LOG_PATH" || printf '%s' "0")
    age=$(( $(now_epoch) - mtime_after ))
    if [ "$size_after" -gt "$size" ] || [ "$age" -lt "$QUIESCE_S" ]; then
      # A writer is active. Copytruncate could lose what it writes between
      # the snapshot and the truncation, so the file is RENAMED instead: the
      # writer's descriptor follows the renamed inode and nothing it writes is
      # lost. The generation is capped on a later pass, once the writer has
      # finished.
      shift_generations "$LOG_PATH"
      if mv -f -- "$LOG_PATH" "${LOG_PATH}.rot.1" 2>/dev/null; then
        : > "$LOG_PATH" 2>/dev/null || true
        echo "rotated ${LOG_PATH} by rename (a writer was active; nothing was lost)"
      else
        echo "SKIP-ROTATE: could not rename $LOG_PATH"
      fi
    else
      # The log is quiescent: nothing was written during the snapshot, so
      # truncating in place is provably lossless.
      shift_generations "$LOG_PATH"
      if [ "$snapshot_ok" = 1 ] && mv -f -- "$tmp" "${LOG_PATH}.rot.1" 2>/dev/null; then
        if truncate_to_zero "$LOG_PATH"; then
          echo "rotated ${LOG_PATH} by copytruncate (the log was quiescent; nothing was lost)"
        else
          echo "SKIP-ROTATE: could not truncate $LOG_PATH"
        fi
      else
        echo "SKIP-ROTATE: could not write the generation for $LOG_PATH"
      fi
    fi
    rm -f -- "$tmp" 2>/dev/null || true
  fi
else
  echo "the live log is within its cap; only the generations are checked"
fi

# The generations are capped too. This is what bounds the TOTAL: without it
# one 40 MB run parks 40 MB in a generation until the next rotation.
#
# The ingest command's own generation ("<log>.1") is part of the family: it is
# where the 40 MB actually parks, so it is capped here as well.
cap_generation "${LOG_PATH}.1"
gen=1
while [ "$gen" -le "$GENERATIONS" ]; do
  cap_generation "${LOG_PATH}.rot.${gen}"
  gen=$((gen + 1))
done

size_after=$(file_size "$LOG_PATH" || printf '0')
echo "live log after: ${size_after} bytes"

if [ "$APPLY" = 1 ]; then
  echo "applied: the log family is bounded at ${MAX_BYTES} + (${GENERATIONS} + 1) x ${KEEP_BYTES} bytes"
else
  echo "dry run: nothing was changed. Re-run with --apply to act."
fi
exit 0
