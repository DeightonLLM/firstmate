#!/usr/bin/env bash
# Acquire or inspect the per-home firstmate session lock.
# Writes the harness (agent) process PID found by walking the shell's ancestry,
# which lives as long as the firstmate session - unlike the transient subshell
# PID of any one tool call, which is dead moments after it is written.
# Usage: fm-lock.sh           acquire; exit 1 unless ownership is verified
#        fm-lock.sh status    print holder and liveness; always exits 0
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
LOCK="$STATE/.lock"
mkdir -p "$STATE" 2>/dev/null || {
  echo "error: cannot create session-lock state directory $STATE; operate read-only until resolved" >&2
  exit 1
}

# Harness identity (FM_HARNESS_RE, ancestry walk, holder liveness) is owned by
# the shared session-lock lib so the Claude Stop auto-arm applies the exact
# same identity contract.
# shellcheck source=bin/fm-session-lock-lib.sh
. "$SCRIPT_DIR/fm-session-lock-lib.sh"

if [ "${1:-}" = "status" ]; then
  if [ ! -f "$LOCK" ]; then echo "lock: free"; exit 0; fi
  old=$(cat "$LOCK" 2>/dev/null) || {
    echo "lock: unreadable"
    exit 0
  }
  if fm_harness_pid_alive "$old"; then echo "lock: held by live harness pid $old"; else echo "lock: stale (pid $old dead or not a harness)"; fi
  exit 0
fi

me=$(fm_harness_ancestry_pid) || { echo "error: cannot locate harness process in ancestry" >&2; exit 1; }
probe=$(mktemp "$STATE/.lock-write.XXXXXX" 2>/dev/null) || {
  echo "error: cannot write session lock; operate read-only until resolved" >&2
  exit 1
}
rm -f "$probe" 2>/dev/null || {
  echo "error: cannot clean session-lock publication probe; operate read-only until resolved" >&2
  exit 1
}
# shellcheck source=bin/fm-wake-lib.sh
. "$SCRIPT_DIR/fm-wake-lib.sh"
# The claim lock MUST be named so its basename ends in ".lock".
#
# Every lock-shape matcher in the fleet requires exactly that:
# fm_lock_pointer_basename_matches and fm_lock_owner_dir_basename_matches in
# bin/fm-wake-lib.sh, and the mirrored pair in bin/fm-lock-reclaim-lib.sh. A
# name that does not end in ".lock" is invisible to all of them, which has
# two consequences:
#
#   1. fm_lock_release cannot unlink it. fm_lock_purge_own refuses a path
#      whose shape it does not recognise, so the pointer SURVIVES its own
#      release. The owner dir survives too: fm_lock_discard_owner cleans the
#      lock-internal files it recognises, and the files inside a ".lock.acquire"
#      owner dir are not lock-internal under those rules, so the dir never
#      empties and its rmdir fails.
#   2. Nothing can reclaim it afterwards. The scratch purge, the owner-dir
#      discard and the dead-lock reclaimer all skip a name that is not a lock
#      shape, so the leftover pointer and owner dir stay forever and the
#      wedge re-forms after every session.
#
# Measured on 2026-10-24 with a take/release of the claim lock under a home
# state/ directory: the pre-fix name left the pointer AND one owner dir
# behind, and the same lock under this name leaves nothing.
#
# The name also stays distinct from the session lock itself, which is
# "$STATE/.lock" and is a plain file, not a lock pointer.
CLAIM_LOCK="$STATE/.acquire.lock"
CLAIM_LOCK_HELD=0
release_claim_lock() {
  if [ "$CLAIM_LOCK_HELD" -eq 1 ]; then
    fm_lock_release "$CLAIM_LOCK"
    CLAIM_LOCK_HELD=0
  fi
}
trap release_claim_lock EXIT
trap 'exit 1' HUP INT TERM
if ! fm_lock_acquire_wait "$CLAIM_LOCK"; then
  echo "error: could not take the claim lock $CLAIM_LOCK (holder pid ${FM_LOCK_HELD_PID:-unknown}); operate read-only until resolved" >&2
  exit 1
fi
CLAIM_LOCK_HELD=1

if [ -e "$LOCK" ] || [ -L "$LOCK" ]; then
  if [ ! -f "$LOCK" ] || [ -L "$LOCK" ]; then
    echo "error: session lock is not a regular file; operate read-only until resolved" >&2
    exit 1
  fi
  old=$(cat "$LOCK" 2>/dev/null) || {
    echo "error: session lock is unreadable; operate read-only until resolved" >&2
    exit 1
  }
  if [ "$old" != "$me" ] && fm_harness_pid_alive "$old"; then
    echo "error: another live firstmate session holds the lock (pid $old); operate read-only until resolved" >&2
    exit 1
  fi
fi
if ! { printf '%s\n' "$me" > "$LOCK"; } 2>/dev/null; then
  echo "error: cannot write session lock; operate read-only until resolved" >&2
  exit 1
fi
written=$(cat "$LOCK" 2>/dev/null) || {
  echo "error: cannot verify session lock ownership; operate read-only until resolved" >&2
  exit 1
}
if [ ! -f "$LOCK" ] || [ -L "$LOCK" ] || [ "$written" != "$me" ]; then
  echo "error: session lock ownership verification failed; operate read-only until resolved" >&2
  exit 1
fi
release_claim_lock
echo "lock acquired: harness pid $me"
