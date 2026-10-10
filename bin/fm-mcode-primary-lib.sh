#!/usr/bin/env bash
# bin/fm-mcode-primary-lib.sh - MCode primary ownership contracts.
#
# PURPOSE
# MCode (minimax-code) has no native lifecycle events, turn-end hooks, extension
# API, or event push mechanism. This library provides ONLY the ownership machinery
# that CAN be implemented: the lock path, atomic claim, owner verification, release,
# stale detection, and safe reacquisition.
#
# What CANNOT be built (hard limits - no native transport):
#   - Session-start nudge: no hook/event to inject the instruction into
#   - Turn-end guard: no Stop/event hook to call bin/fm-turnend-guard.sh
#   - Semantic busy-state: no agent_start/agent_settled equivalent
#   - Watcher wake: no event source to trigger bin/fm-watch-arm.sh
#   - Pi-style extension: no extension API in mcode v0.6.8
#
# The lock uses the same atomic symlink pattern as bin/fm-wake-lib.sh:
#   state/.mcode-primary.lock  ->  state/.mcode-primary.lock.owner.XXXXXX/
#       owner dir contains: pid, fm-home, pid-identity, timestamp
#
# This is SEPARATE from the home session lock (state/.lock) and the wake queue
# lock (state/.wake-queue.lock). It is specifically the MCode primary ownership
# token, allowing other components to detect when a MCode-firstmate session holds
# the home and is actively processing.
#
# Usage: source this file, then call the public functions below.
# All functions require FM_STATE and FM_HOME to be set in the environment.
set -u

# --- Config ---

# Prefix for the mcode primary lock within FM_STATE.
MCODE_PRIMARY_LOCK_NAME="${MCODE_PRIMARY_LOCK_NAME:-.mcode-primary.lock}"
MCODE_PRIMARY_LOCK_STALE_SECONDS="${MCODE_PRIMARY_LOCK_STALE_SECONDS:-5}"

# --- Helpers ---

die() { echo "fm-mcode-primary: $*" >&2; exit 1; }

# Resolve absolute path of a directory.
abs_path() {
  local dir=$1
  dir=$(cd "$dir" 2>/dev/null && pwd -P) || return 1
  printf '%s\n' "$dir"
}

# Check if PID is alive.
pid_alive() {
  local pid=$1
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$pid" 2>/dev/null
}

# Get process identity (for freshness verification).
proc_identity() {
  local pid=$1 proc_root stat_line starttime cmdline_hex
  local -a stat_fields
  proc_root=${FM_PROC_ROOT_OVERRIDE:-/proc}
  if [ -r "$proc_root/$pid/stat" ] && [ -r "$proc_root/$pid/cmdline" ]; then
    stat_line=$(cat "$proc_root/$pid/stat" 2>/dev/null) || return 1
    read -r -a stat_fields <<< "${stat_line##*)}"
    [ "${#stat_fields[@]}" -ge 20 ] || return 1
    starttime=${stat_fields[19]}
    case "$starttime" in
      ''|*[!0-9]*) return 1 ;;
    esac
    cmdline_hex=$(od -An -v -tx1 "$proc_root/$pid/cmdline" 2>/dev/null | tr -d '[:space:]') || return 1
    printf 'starttime=%s cmdline-hex=%s\n' "$starttime" "$cmdline_hex"
    return 0
  fi
  # Fallback for non-Linux.
  LC_ALL=C ps -p "$pid" -o lstart= -o command= 2>/dev/null | sed 's/^[[:space:]]*//'
}

# Age of a file in seconds.
path_age() {
  local path=$1 mtime now
  case "$(uname 2>/dev/null)" in
    Darwin) mtime=$(stat -f %m "$path" 2>/dev/null) ;;
    *)      mtime=$(stat -c %Y "$path" 2>/dev/null) ;;
  esac
  [ -n "$mtime" ] || { echo 999999; return; }
  now=$(date +%s)
  echo $(( now - mtime ))
}

# --- Public API ---

# fm_mcode_primary_lock_path: print the absolute path to the mcode primary lock dir.
# The lock dir is FM_STATE/.mcode-primary.lock.owner.XXXXXX/
fm_mcode_primary_lock_path() {  # <state-dir>
  local state=$1
  printf '%s/%s\n' "$state" "$MCODE_PRIMARY_LOCK_NAME"
}

# fm_mcode_primary_lock_owner_dir: create and return a new owner directory.
# The directory is inside the lock dir, with a unique suffix.
fm_mcode_primary_lock_owner_dir() {  # <lock-path>
  local lock=$1 owner_dir
  owner_dir=$(mktemp -d "${lock}.owner.XXXXXX" 2>/dev/null) || return 1
  printf '%s\n' "$owner_dir"
}

# fm_mcode_primary_lock_points_to: check if the lock symlink points to owner_dir.
fm_mcode_primary_lock_points_to() {  # <lock-path> <owner-dir>
  local lock=$1 target=$2 actual
  [ -L "$lock" ] || return 1
  actual=$(readlink "$lock" 2>/dev/null) || return 1
  [ "$actual" = "$target" ]
}

# fm_mcode_primary_lock_current_owner: print the current owner dir if the lock is held.
fm_mcode_primary_lock_current_owner() {  # <lock-path>
  local lock=$1
  [ -L "$lock" ] || return 1
  readlink "$lock" 2>/dev/null
}

# fm_mcode_primary_lock_pid: print the PID recorded in the owner dir.
fm_mcode_primary_lock_pid() {  # <owner-dir>
  local owner=$1
  [ -f "$owner/pid" ] || return 1
  cat "$owner/pid" 2>/dev/null
}

# fm_mcode_primary_lock_record_self: record current process as owner in owner_dir.
fm_mcode_primary_lock_record_self() {  # <owner-dir>
  local owner=$1 my_pid identity
  my_pid=${BASHPID:-$$}
  printf '%s\n' "$my_pid" > "$owner/pid" || return 1
  identity=$(proc_identity "$my_pid") || identity=""
  [ -n "$identity" ] && printf '%s\n' "$identity" > "$owner/pid-identity" 2>/dev/null
  [ -n "$FM_HOME" ] && printf '%s\n' "$FM_HOME" > "$owner/fm-home" 2>/dev/null || true
  printf '%s\n' "$(date +%s)" > "$owner/claimed-at" 2>/dev/null || true
  # Verify what we wrote matches.
  [ "$(cat "$owner/pid")" = "$my_pid" ]
}

# fm_mcode_primary_lock_verify_claim: verify the lock symlink points to owner_dir.
fm_mcode_primary_lock_verify_claim() {  # <lock-path> <owner-dir> -> bool
  local lock=$1 owner=$2
  # Create symlink atomically.
  if ! ln -s "$owner" "$lock" 2>/dev/null; then
    # Lock already exists.
    return 1
  fi
  # Verify it points to our dir.
  fm_mcode_primary_lock_points_to "$lock" "$owner"
}

# fm_mcode_primary_lock_claim: atomically claim the mcode primary lock.
# Returns 0 on success, 1 if lock is already held (by any owner).
fm_mcode_primary_lock_claim() {  # <state-dir> -> bool
  local state=$1 lock_path owner_dir current_owner
  lock_path=$(fm_mcode_primary_lock_path "$state")

  # If lock already exists, check if the owner is alive.
  if [ -L "$lock_path" ]; then
    current_owner=$(fm_mcode_primary_lock_current_owner "$lock_path") || true
    if [ -n "$current_owner" ] && [ -d "$current_owner" ]; then
      local owner_pid
      owner_pid=$(fm_mcode_primary_lock_pid "$current_owner") || owner_pid=""
      if [ -n "$owner_pid" ] && pid_alive "$owner_pid"; then
        return 1  # Lock held by a live process - refuse.
      fi
      # Owner is dead (stale). Remove the stale lock so we can claim.
      rm -f "$lock_path" 2>/dev/null || true
    else
      # Lock symlink exists but owner dir is missing/corrupt. Remove it.
      rm -f "$lock_path" 2>/dev/null || true
    fi
  fi

  # Create a new owner directory.
  owner_dir=$(fm_mcode_primary_lock_owner_dir "$lock_path") || return 1
  mkdir -p "$owner_dir" || { rmdir "$owner_dir" 2>/dev/null; return 1; }

  # Record current process as owner.
  fm_mcode_primary_lock_record_self "$owner_dir" || {
    rmdir "$owner_dir" 2>/dev/null; return 1
  }

  # Atomically create the symlink pointing to our owner dir.
  if ! ln -s "$owner_dir" "$lock_path" 2>/dev/null; then
    # Race: another process claimed between our check and here.
    rmdir "$owner_dir" 2>/dev/null; return 1
  fi

  # Verify the lock now points to our dir.
  fm_mcode_primary_lock_points_to "$lock_path" "$owner_dir" || {
    rm -f "$lock_path" 2>/dev/null; rmdir "$owner_dir" 2>/dev/null; return 1
  }

  return 0
}

# fm_mcode_primary_lock_held_by_self: true if the current process owns the lock.
fm_mcode_primary_lock_held_by_self() {  # <state-dir> -> bool
  local state=$1 lock_path current owner_pid my_pid
  lock_path=$(fm_mcode_primary_lock_path "$state")
  [ -L "$lock_path" ] || return 1
  current=$(fm_mcode_primary_lock_current_owner "$lock_path") || return 1
  [ -d "$current" ] || return 1
  owner_pid=$(fm_mcode_primary_lock_pid "$current") || return 1
  my_pid=${BASHPID:-$$}
  [ "$owner_pid" = "$my_pid" ] || return 1
}

# fm_mcode_primary_lock_stale: true if the lock is held by a dead process.
fm_mcode_primary_lock_stale() {  # <state-dir> -> bool
  local state=$1 lock_path current owner_pid
  lock_path=$(fm_mcode_primary_lock_path "$state")
  [ -L "$lock_path" ] || return 1
  current=$(fm_mcode_primary_lock_current_owner "$lock_path") || return 1
  [ -d "$current" ] || return 1
  owner_pid=$(fm_mcode_primary_lock_pid "$current") || return 1
  pid_alive "$owner_pid" && return 1 || return 0
}

# fm_mcode_primary_lock_release: release the lock ONLY if held by current process.
# Safe to call even if not held.
fm_mcode_primary_lock_release() {  # <state-dir>
  local state=$1 lock_path current owner_pid my_pid
  lock_path=$(fm_mcode_primary_lock_path "$state")
  [ -L "$lock_path" ] || return 0  # Not held, nothing to do.
  current=$(fm_mcode_primary_lock_current_owner "$lock_path") || return 0
  [ -d "$current" ] || { rm -f "$lock_path" 2>/dev/null; return 0; }
  owner_pid=$(fm_mcode_primary_lock_pid "$current") || owner_pid=""
  my_pid=${BASHPID:-$$}
  # Only release if we own it.
  [ "$owner_pid" = "$my_pid" ] || return 0
  # Remove the symlink.
  rm -f "$lock_path" 2>/dev/null || true
  # Clean up the owner dir.
  if [ -d "$current" ]; then
    rm -f "$current/pid" "$current/pid-identity" "$current/fm-home" \
           "$current/claimed-at" 2>/dev/null || true
    rmdir "$current" 2>/dev/null || true
  fi
}

# fm_mcode_primary_lock_try_reacquire: try to claim the lock, stealing from a
# stale owner if needed. Returns 0 on success, 1 if a live owner holds it.
fm_mcode_primary_lock_try_reacquire() {  # <state-dir> -> bool
  local state=$1
  # First try clean claim.
  fm_mcode_primary_lock_claim "$state" && return 0
  # If stale, try to steal.
  if fm_mcode_primary_lock_stale "$state"; then
    local lock_path current
    lock_path=$(fm_mcode_primary_lock_path "$state")
    current=$(fm_mcode_primary_lock_current_owner "$lock_path") || true
    # Remove the stale lock.
    rm -f "$lock_path" 2>/dev/null || true
    if [ -n "$current" ] && [ -d "$current" ]; then
      rm -f "$current/pid" "$current/pid-identity" "$current/fm-home" \
             "$current/claimed-at" 2>/dev/null || true
      rmdir "$current" 2>/dev/null || true
    fi
    # Now try to claim again.
    fm_mcode_primary_lock_claim "$state"
  fi
}
