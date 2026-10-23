#!/usr/bin/env bash
# Shared durable wake queue and portable lock helpers — Hardened Watcher Recovery Edition.
# Resolves Ticket 20261019 Watcher Lock Defect & Controller Supervision Recovery.
#
# LOCK WAIT CONTRACT (lane m3.1f-firstmate-lockdeadline, 2026-10-21).
#
# The Controller ran a 14.32 load average on four cores for over an hour and
# bin/fm-dispatch-guard.sh refused every spawn, so the fleet looked wedged. It
# was not real work. The measured chain was:
#
#   1. The comms receipt lock's reclaim path left a stale "<lock>.steal"
#      pointer behind. The shared scratch shape table in bin/fm-scratch-lib.sh
#      knows "*.lock" and "*.lock.owner.??????" but NOT the steal infix, so
#      fm_purge_scratch REFUSED that pointer and it could never be unlinked.
#   2. A live "<lock>.steal" pointer blocks every claim on the main lock
#      (fm_lock_claim_blocked_by_steal), so no scan could ever take it.
#   3. fm_lock_acquire_wait had no deadline and polled every 0.1s, so every
#      later scan spun on that lock forever.
#   4. Each spin attempt created a lock owner dir it could not remove (the
#      same shape refusal) and ran a dozen "git ls-files" subprocesses through
#      the scratch shape check: 65 process spawns per attempt, ten attempts a
#      second, per stuck process. That was the load average.
#
# THE RULES NOW:
#   * A wait has a DEADLINE. fm_lock_acquire_wait and
#     fm_lock_acquire_wait_bounded return non-zero when the deadline passes.
#     124 is the timeout status, FM_LOCK_HELD_PID names the holder, and
#     FM_LOCK_WAIT_REASON says whether the holder is BUSY (alive, still inside
#     its age budget) or STUCK (alive, past FM_LOCK_MAX_HOLD_S).
#   * A wait does not BUSY-WAIT. It polls on a growing interval, so a
#     contended lock costs a handful of spawns a second, not 650.
#   * A LIVE holder is broken only when it is STUCK: alive AND older than
#     FM_LOCK_MAX_HOLD_S AND the caller opted in with
#     FM_LOCK_BREAK_STUCK_HOLDERS=1. The break reuses the existing steal
#     mutex and re-reads the owner under that mutex, so a lock that changed
#     underneath the breaker is never broken.
#   * Owner directories are RECLAIMED. A release and a successful acquire both
#     sweep the lock's own directory for owner dirs no live lock references.
#     The count stops growing instead of growing by one per attempt.

FM_WAKE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_WAKE_DEFAULT_ROOT="$(cd "$FM_WAKE_LIB_DIR/.." && pwd)"

# The one documented way to purge own-scratch. This library deletes lock owner
# dirs and lock pointers it created itself, so it must unlink them for real:
# plain `rm` on this host is a recoverable-delete shim that MOVES the target
# into ~/.local/share/Trash, which frees zero bytes on a single filesystem.
# Measured 2026-10-21: the trash held 14.1 GB across 20,274 entries while df
# stayed at 97% with 2.8 GB free, and the lock churn below alone accounted for
# roughly 26 new trash entries per minute at idle.
if [ -r "$FM_WAKE_LIB_DIR/fm-scratch-lib.sh" ]; then
  # shellcheck source=bin/fm-scratch-lib.sh
  . "$FM_WAKE_LIB_DIR/fm-scratch-lib.sh"
else
  # A partial checkout (a fixture repo, or a worktree cut from an older
  # base) may not carry bin/fm-scratch-lib.sh. Fall back to exactly the
  # behaviour this file had before the purge helper existed, so a partial
  # checkout is not a regression - it simply does not get the fix.
  fm_purge_scratch() {
    local p
    for p in "$@"; do
      [ -n "$p" ] || continue
      rm -rf -- "$p" 2>/dev/null || true
    done
    return 0
  }
  # The real-rm resolution the shared helper owns. Without it the lock
  # library falls back to plain rm, which still removes the entry from the
  # lock's own directory.
  fm_scratch_real_rm() {
    local candidate resolved
    for candidate in /usr/bin/rm /bin/rm; do
      [ -x "$candidate" ] || continue
      resolved=$(readlink -f "$candidate" 2>/dev/null || printf '%s' "$candidate")
      case "$resolved" in
        */shims/*|*/mavis-trash) continue ;;
      esac
      printf '%s\n' "$resolved"
      return 0
    done
    return 1
  }
fi

FM_ROOT="${FM_ROOT_OVERRIDE:-${FM_ROOT:-$FM_WAKE_DEFAULT_ROOT}}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-${STATE:-$FM_HOME/state}}"
FM_WAKE_QUEUE="${FM_WAKE_QUEUE:-$STATE/.wake-queue}"
FM_WAKE_QUEUE_LOCK="${FM_WAKE_QUEUE_LOCK:-$STATE/.wake-queue.lock}"
FM_LOCK_STALE_AFTER="${FM_LOCK_STALE_AFTER:-2}"

# Lock wait knobs. Every one of these is read at CALL time, not at source
# time, so a test or an operator can change one for a single call.
#
#   FM_LOCK_WAIT_TIMEOUT_S   seconds a wait may spend on a contended lock
#                            (default 120). On expiry the wait returns 124.
#   FM_LOCK_MAX_HOLD_S       age at which a LIVE holder counts as STUCK and
#                            may be broken (default 900). It is a budget for
#                            the whole critical section, so it must stay well
#                            above the longest legitimate one.
#   FM_LOCK_BREAK_STUCK_HOLDERS
#                            "1" lets a wait break a STUCK live holder.
#                            Default "0": a live holder is never broken, so
#                            the existing fail-closed behaviour is unchanged
#                            for every caller that does not opt in.
#   FM_LOCK_POLL_MIN_S       first poll interval after a refused acquire.
#   FM_LOCK_POLL_MAX_S       ceiling for that interval.
#   FM_LOCK_RECLAIM_GRACE_S   age before an unreferenced owner dir may be
#                            reclaimed (default 5).
#   FM_LOCK_RECLAIM_MAX      owner dirs removed per reclamation sweep
#                            (default 64). The sweep runs while the caller
#                            holds the lock, so it must stay bounded; the
#                            backlog drains over successive acquires.
FM_LOCK_RECLAIMED=0

# The status a timed-out wait reports. 124 matches the timeout(1) convention
# that bin/fm-afk-contract.sh already reads.
FM_LOCK_WAIT_TIMEOUT_STATUS=124

fm_lock_default_wait_timeout() {
  local v=${FM_LOCK_WAIT_TIMEOUT_S:-120}
  case "$v" in ''|*[!0-9]*) v=120 ;; esac
  printf '%s\n' "$v"
}

fm_lock_default_max_hold() {
  local v=${FM_LOCK_MAX_HOLD_S:-900}
  case "$v" in ''|*[!0-9]*) v=900 ;; esac
  printf '%s\n' "$v"
}

fm_lock_break_stuck_holders_enabled() {
  case "${FM_LOCK_BREAK_STUCK_HOLDERS:-0}" in
    1|true|TRUE|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

_FM_UNAME=$(uname 2>/dev/null || echo unknown)
mkdir -p "$STATE"

fm_current_pid() {
  printf '%s\n' "${BASHPID:-$$}"
}

fm_pid_alive() {
  local pid=$1
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$pid" 2>/dev/null
}

fm_pid_identity() {
  local pid=$1 out proc_root stat_line starttime cmdline_hex identity_key
  local -a stat_fields
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
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
    [ -n "$cmdline_hex" ] || return 1
    identity_key=proc-starttime
    [ "$_FM_UNAME" != Linux ] || identity_key=linux-starttime
    printf '%s=%s cmdline-hex=%s\n' "$identity_key" "$starttime" "$cmdline_hex"
    return 0
  fi
  out=$(LC_ALL=C ps -p "$pid" -o lstart= -o command= 2>/dev/null) || return 1
  [ -n "$out" ] || return 1
  printf '%s\n' "$out" | sed 's/^[[:space:]]*//'
}

fm_path_mtime() {
  if [ "$_FM_UNAME" = Darwin ]; then
    stat -f %m "$1" 2>/dev/null
  else
    stat -c %Y "$1" 2>/dev/null
  fi
}

fm_path_age() {
  local path=$1 m
  m=$(fm_path_mtime "$path") || { echo 999999; return; }
  echo $(( $(date +%s) - m ))
}

fm_watcher_lock_matches_pid() {
  local state=$1 watch_path=$2 pid=$3 home=${4:-$FM_HOME} lockdir lock_home lock_path lock_identity current_identity
  lockdir="$state/.watch.lock"
  lock_home=$(cat "$lockdir/fm-home" 2>/dev/null || true)
  lock_path=$(cat "$lockdir/watcher-path" 2>/dev/null || true)
  lock_identity=$(cat "$lockdir/pid-identity" 2>/dev/null || true)
  [ "$lock_home" = "$home" ] || return 1
  [ "$lock_path" = "$watch_path" ] || return 1
  [ -n "$lock_identity" ] || return 1
  current_identity=$(fm_pid_identity "$pid") || return 1
  [ "$current_identity" = "$lock_identity" ]
}

FM_WATCHER_HEALTHY_PID=
fm_watcher_healthy() {
  local state=$1 watch_path=$2 grace=${3:-${FM_GUARD_GRACE:-300}} home=${4:-$FM_HOME} lockdir beat pid age
  FM_WATCHER_HEALTHY_PID=
  lockdir="$state/.watch.lock"
  beat="$state/.last-watcher-beat"
  pid=$(cat "$lockdir/pid" 2>/dev/null || true)
  fm_pid_alive "$pid" || return 1
  fm_watcher_lock_matches_pid "$state" "$watch_path" "$pid" "$home" || return 1
  age=$(fm_path_age "$beat")
  [ "$age" -lt "$grace" ] || return 1
  # shellcheck disable=SC2034  # Read by bin/fm-watch-arm.sh, which sources this library.
  FM_WATCHER_HEALTHY_PID=$pid
  return 0
}

fm_lock_clean_known_files() {
  local lockdir=$1
  # Own-scratch: these are lock-internal files this library wrote.
  # Plain `rm` would move them into the trash instead of unlinking them, so
  # every lock release leaked a "pid" entry into ~/.local/share/Trash. That
  # was the dominant source of the trash flood (26 entries/min at idle).
  #
  # The list must stay complete: an owner dir that still holds a file cannot
  # be removed with rmdir, and the dir then survives the release. That is how
  # a single forgotten name turned into thousands of stranded owner dirs.
  fm_lock_purge_own \
    "$lockdir/pid" \
    "$lockdir/pid-start" \
    "$lockdir/fm-home" \
    "$lockdir/pid-identity" \
    "$lockdir/watcher-path" \
    2>/dev/null || true
}

# --- lock-internal scratch shapes -------------------------------------------
#
# The shared scratch table in bin/fm-scratch-lib.sh is the owner of scratch
# shape recognition, and it knows two lock shapes: a pointer named "*.lock"
# and an owner dir named "*.lock.owner.??????" (plus the files inside one).
#
# It does NOT know the steal infix this library creates: the reclaim pointer
# "<lock>.steal" and its owner dir "<lock>.steal.owner.??????" sit beside the
# main lock, and the shared table refuses both. That refusal is what made the
# Controller's comms lock unbreakable: a stale steal pointer could never be
# unlinked, so it blocked every claim on the main lock forever, and every
# refused attempt leaked another owner dir.
#
# These two helpers close that gap WITHOUT editing the shared library (whose
# file set belongs to another surface). The rule is deliberately narrow: a
# path qualifies only if its name is a lock shape this library creates, and
# an owner dir qualifies only if it is OWNER-PRIVATE (mode 0700). Tracked
# repository content is never 0700, so the owner-private test is what keeps
# tracked material out of reach, and it costs no subprocess. A lock pointer
# qualifies only when it is a symlink, and unlinking a symlink removes the
# pointer, never its target.
fm_lock_scratch_shape_ok() {
  local path=$1 base parent
  [ -n "$path" ] || return 1
  base=${path##*/}
  parent=${path%/*}
  [ -n "$parent" ] || parent=/
  # A lock pointer or a reclaim pointer, at any steal depth. The reclaim
  # mutex chain is .lock.steal -> .lock.steal.steal -> ... , one level per
  # recursion, and the depth is unbounded (24 levels measured on the
  # Controller). The pointer must be a symlink: unlinking a symlink removes
  # the pointer, never its target.
  if fm_lock_pointer_basename_matches "$base"; then
    [ -L "$path" ] && return 0
    return 1
  fi
  # An owner dir, at ANY steal depth. The depth is unbounded: the reclaim
  # mutex of a lock takes the reclaim mutex of that mutex's lock, and each
  # level creates an owner dir of its own. Measured on the Controller on
  # 2026-10-21: 39 distinct depths, the deepest name 252 characters long. A
  # fixed-depth pattern matches a tenth of them and leaves the rest
  # unpurgable - which is how a reclaimed dir stays stranded forever.
  if fm_lock_owner_dir_basename_matches "$base"; then
    fm_lock_owner_private "$path" && return 0
    return 1
  fi
  if fm_lock_owner_dir_basename_matches "${parent##*/}"; then
    return 0
  fi
  # A known lock-internal file inside a lock dir: pid, the identity token,
  # and the few home/path records the other lock families write beside them.
  # The shared scratch library knows these names too (its rule T5), but only
  # for a single ".lock" level; recognising them here keeps the lock's own
  # files on the fork-free path instead of the git-consulting shared one.
  case "$base" in
    pid|pid-start|fm-home|pid-identity|watcher-path)
      case "${parent##*/}" in
        *.lock|*.lock.steal) return 0 ;;
      esac
      ;;
  esac
  # A stray owner link: ln -s aimed at a lock path that was a DIRECTORY
  # creates <lock-path>/<owner-dir-name> instead of the lock pointer. The
  # parent is the lock's own path and the name is an mktemp-shaped owner dir,
  # so this is lock-internal by construction. Without this case every stray
  # link fell through to the shared scratch library, which asks git whether
  # the path is tracked material: two git forks plus several readlinks on the
  # hot path of every failed acquire.
  case "$parent" in
    *.lock|*.lock.steal)
      if fm_lock_owner_dir_basename_matches "$base"; then
        return 0
      fi
      ;;
  esac
  return 1
}

# fm_lock_pointer_basename_matches <name>
# 0 when <name> is a lock pointer or reclaim pointer name at any steal depth.
#
# The name is <lock-basename> + zero or more ".steal" infixes. A
# <lock-basename> is EITHER a root lock ("<prefix>.lock") OR a DERIVED mutex
# of a root lock ("<prefix>.lock.<suffix>", e.g. ".lock.acquire"). The derived
# form is what the fleet actually uses for the session lock's claim mutex, so
# a matcher that knows only the root form cannot see the claim mutex at all.
# A glob cannot express the repetition, so the infixes are peeled off one at a
# time.
fm_lock_pointer_basename_matches() {
  local name=$1 rest seg
  [ -n "$name" ] || return 1
  rest=$name
  while :; do
    case "$rest" in
      *.lock) return 0 ;;
      *.steal) rest=${rest%.steal} ;;
      *.lock.*)
        # A derived mutex of a lock: "<lock-basename>.<suffix>". The suffix is
        # exactly ONE segment, so a second dot is not a mutex name.
        seg=${rest##*.lock.}
        [ -n "$seg" ] || return 1
        case "$seg" in *.*) return 1 ;; esac
        return 0
        ;;
      *) return 1 ;;
    esac
  done
}

# fm_lock_owner_dir_basename_matches <name>
# 0 when <name> is a lock owner dir name at any steal depth.
#
# The name is <lock-basename> + zero or more ".steal" infixes + ".owner." +
# six characters. A <lock-basename> is EITHER a root lock ("<prefix>.lock")
# OR a derived mutex of a root lock ("<prefix>.lock.<suffix>", e.g.
# ".lock.acquire"), because the session lock's claim mutex is named
# ".lock.acquire" and its owner dirs are named after it. A glob cannot
# express the repetition, so the infixes are peeled off one at a time.
fm_lock_owner_dir_basename_matches() {
  local name=$1 rest seg
  [ -n "$name" ] || return 1
  [ "${#name}" -ge 18 ] || return 1
  case "${name:$((${#name} - 13))}" in
    .owner.??????) ;;
    *) return 1 ;;
  esac
  rest=${name:0:$((${#name} - 13))}
  while :; do
    case "$rest" in
      *.lock) return 0 ;;
      *.steal) rest=${rest%.steal} ;;
      *.lock.*)
        # A derived mutex of a lock: "<lock-basename>.<suffix>". The suffix is
        # exactly ONE segment, so a second dot is not a mutex name.
        seg=${rest##*.lock.}
        [ -n "$seg" ] || return 1
        case "$seg" in *.*) return 1 ;; esac
        return 0
        ;;
      *) return 1 ;;
    esac
  done
}

# 0 when the path grants nothing to group or other, 1 otherwise. mktemp makes
# what it creates private (0700 for a directory), and tracked repository
# content is never private, so this is the guard that keeps tracked material
# out of the reclaim path.
fm_lock_owner_private() {
  local path=$1 mode
  mode=$(stat -c '%a' -- "$path" 2>/dev/null) \
    || mode=$(stat -f '%Lp' -- "$path" 2>/dev/null) \
    || return 1
  while [ "${#mode}" -lt 3 ]; do mode="0$mode"; done
  case "${mode: -2}" in
    00) return 0 ;;
  esac
  return 1
}

# fm_lock_resolve_real_rm
# Resolve the real-rm binary once per process and remember it.
#
# The resolution costs a readlink fork, and fm_lock_purge_own runs on the hot
# path of every acquire and release. The answer cannot change under a process
# (it is /usr/bin/rm or /bin/rm, never the recoverable-delete shim), except
# when a test overrides FM_SCRATCH_REAL_RM, so the cache is keyed on that
# override and recomputed when it changes.
#
# It resolves WITHOUT a command substitution on purpose: a substitution runs
# the assignment in a subshell, so the cache would be thrown away on every
# call and every call would fork again.
_FM_LOCK_REAL_RM=
_FM_LOCK_REAL_RM_KEY=
fm_lock_resolve_real_rm() {
  local real key
  key=${FM_SCRATCH_REAL_RM:-}
  if [ -n "$_FM_LOCK_REAL_RM" ] && [ "$_FM_LOCK_REAL_RM_KEY" = "$key" ]; then
    return 0
  fi
  real=$(fm_scratch_real_rm 2>/dev/null) || real=
  [ -n "$real" ] || return 1
  _FM_LOCK_REAL_RM=$real
  _FM_LOCK_REAL_RM_KEY=$key
  return 0
}

# fm_lock_purge_own <path>...
# Real unlink of a lock-internal path. The shared scratch table is tried
# first for the shapes it already knows; the steal shapes fall through to
# the shared library's own real-rm resolution with the narrow lock-shape
# guard above. Either way the target is unlinked for real, never moved into
# the recoverable-delete trash.
fm_lock_purge_own() {
  local path real
  fm_lock_resolve_real_rm || real=
  real=$_FM_LOCK_REAL_RM
  for path in "$@"; do
    [ -n "$path" ] || continue
    # Nothing to remove: do not fork an rm for a path that is already gone.
    [ -e "$path" ] || [ -L "$path" ] || continue
    if fm_lock_scratch_shape_ok "$path"; then
      if [ -z "$real" ]; then
        # No real-rm could be resolved. Delegate to the shared scratch helper:
        # it resolves the real rm by absolute path in a full checkout, and in
        # a partial checkout it falls back to the pre-fix behaviour. A plain
        # rm here would move the entry into the recoverable-delete trash on
        # hosts where rm is a shim, which is the leak this whole path exists
        # to prevent.
        fm_purge_scratch "$path" 2>/dev/null || true
        continue
      fi
      if [ -L "$path" ] || [ ! -d "$path" ]; then
        "$real" -f -- "$path" 2>/dev/null || true
      else
        "$real" -rf -- "$path" 2>/dev/null || true
      fi
      continue
    fi
    fm_purge_scratch "$path" 2>/dev/null || true
  done
  return 0
}

fm_lock_abs_path() {
  local path=$1 dir base
  # Parameter expansion instead of dirname/basename: this runs on every
  # acquire attempt, and a contended lock must not cost a subprocess per
  # path component.
  dir=${path%/*}
  base=${path##*/}
  [ -n "$dir" ] || dir=/
  dir=$(cd "$dir" 2>/dev/null && pwd -P) || return 1
  printf '%s/%s\n' "$dir" "$base"
}

fm_lock_owner_dir() {
  local lockdir=$1 lock_abs
  lock_abs=$(fm_lock_abs_path "$lockdir") || return 1
  mktemp -d "${lock_abs}.owner.XXXXXX" 2>/dev/null
}

fm_lock_prepare_owner() {
  local ownerdir=$1 mypid back ticks
  mypid=${BASHPID:-$$}
  printf '%s\n' "$mypid" > "$ownerdir/pid" 2>/dev/null || return 1
  back=
  IFS= read -r back 2>/dev/null <"$ownerdir/pid" || true
  [ "$back" = "$mypid" ] || return 1
  # Record the PROCESS IDENTITY, not just the pid.
  #
  # A pid alone is not an identity: the kernel recycles pids, so a lock whose
  # holder died long ago can carry a pid that now belongs to an unrelated
  # process. A reader that only asks "is this pid alive?" then sees a live
  # holder and refuses to reclaim the lock - which is exactly how a dead lock
  # becomes a permanent wedge. The start time of the process is stable for
  # its whole life and is never reused, so it identifies the holder exactly.
  ticks=$(fm_pid_start_ticks "$mypid") || ticks=
  [ -n "$ticks" ] || return 0
  printf '%s\n' "$ticks" > "$ownerdir/pid-start" 2>/dev/null || true
  return 0
}

# fm_pid_start_ticks <pid>
# The process start time, in clock ticks since boot, read from
# /proc/<pid>/stat. 0 when it cannot be read.
#
# This is the cheap identity signal: the existing fm_pid_identity also
# hex-dumps the whole cmdline, which costs two more subprocesses, and this
# runs on the hot path of every claim.
fm_pid_start_ticks() {
  local pid=$1 stat_line rest
  local -a fields
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  IFS= read -r stat_line 2>/dev/null <"${FM_PROC_ROOT_OVERRIDE:-/proc}/$pid/stat" || return 1
  [ -n "$stat_line" ] || return 1
  # The comm field is parenthesised and may contain spaces; everything after
  # the LAST ')' is positionally stable.
  rest=${stat_line##*)}
  read -r -a fields <<< "$rest"
  [ "${#fields[@]}" -ge 20 ] || return 1
  case "${fields[19]}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  printf '%s\n' "${fields[19]}"
}

# fm_lock_pid_is_the_holder <pid> <ownerdir>
# 0 when <pid> is still the SAME process that took the lock in <ownerdir>.
#
# Two proofs, in order of strength:
#
#   1. The owner dir carries the holder's start time (written by
#      fm_lock_prepare_owner). It is compared with the pid's current start
#      time. Equal means same process; different means the pid was recycled.
#
#   2. A legacy owner dir has no such token. Then the process start time is
#      compared with the owner dir's own mtime: a process that started AFTER
#      the lock was created cannot be the process that took it, because the
#      holder existed before the lock did. This is the only proof available
#      for the 7,557 owner dirs already stranded on the Controller.
#
# When neither proof can be made (no /proc, no readable token), this returns
# 0 - the pid is treated as the holder - so an unprovable case stays on the
# conservative side.
fm_lock_pid_is_the_holder() {
  local pid=$1 ownerdir=$2 recorded current dir_mtime pid_epoch
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  recorded=
  IFS= read -r recorded 2>/dev/null <"$ownerdir/pid-start" || true
  if [ -n "$recorded" ]; then
    current=$(fm_pid_start_ticks "$pid") || return 1
    [ "$current" = "$recorded" ]
    return $?
  fi
  # Legacy owner dir: fall back to the start-time vs mtime comparison.
  current=$(fm_pid_start_ticks "$pid") || return 1
  dir_mtime=$(fm_path_mtime "$ownerdir" 2>/dev/null) || return 0
  case "$dir_mtime" in ''|*[!0-9]*) return 0 ;; esac
  pid_epoch=$(fm_pid_start_epoch "$pid") || return 0
  case "$pid_epoch" in ''|*[!0-9]*) return 0 ;; esac
  # One clock tick of slack: the two clocks are not aligned, and a process
  # that started in the same second as the claim is not provably recycled.
  [ "$pid_epoch" -gt "$((dir_mtime + 1))" ] && return 1
  return 0
}

# fm_pid_start_epoch <pid>
# The process start time as an epoch second, for comparing against a file
# mtime. Uses the kernel's boot time and the clock tick rate, both read
# without a subprocess per call.
fm_pid_start_epoch() {
  local pid=$1 ticks btime hz
  ticks=$(fm_pid_start_ticks "$pid") || return 1
  btime=$(fm_boot_time_epoch) || return 1
  hz=$(fm_clock_ticks_per_second) || return 1
  printf '%s\n' "$((btime + ticks / hz))"
}

fm_boot_time_epoch() {
  local line
  while IFS= read -r line; do
    case "$line" in
      btime\ *) printf '%s\n' "${line#btime }"; return 0 ;;
    esac
  done <"${FM_PROC_ROOT_OVERRIDE:-/proc}/stat" 2>/dev/null
  return 1
}

_FM_CLOCK_TICKS=
fm_clock_ticks_per_second() {
  local v
  if [ -n "$_FM_CLOCK_TICKS" ]; then
    printf '%s\n' "$_FM_CLOCK_TICKS"
    return 0
  fi
  v=$(getconf CLK_TCK 2>/dev/null) || v=
  case "$v" in ''|*[!0-9]*) v=100 ;; esac
  _FM_CLOCK_TICKS=$v
  printf '%s\n' "$v"
}

# fm_lock_owner_dir_name_matches <name> <base>
# 0 when <name> is a lock owner dir for <base> at ANY steal depth.
#
# An owner dir is named <base> + zero or more ".steal" infixes + ".owner." +
# six characters. The infixes are the recursion of the reclaim mutex: taking
# the reclaim mutex of a lock takes the reclaim mutex of that mutex's lock,
# and each level creates an owner dir of its own.
#
# The depth is NOT bounded. Measured on the Controller on 2026-10-21: 7,557
# stranded owner dirs, of which 782 matched a two-level glob and 6,638 did
# not, in 39 distinct depths, the deepest with a 252-character name. A
# fixed-depth glob therefore reclaims about a tenth of the leak and leaves
# the rest behind forever.
#
# A glob cannot express repetition, so the name is decomposed here instead:
# strip the ".owner.XXXXXX" suffix, then peel ".steal" infixes off the front
# until what is left is the base.
fm_lock_owner_dir_name_matches() {
  local name=$1 base=$2 rest
  [ -n "$name" ] || return 1
  [ -n "$base" ] || return 1
  # ".owner." plus exactly six characters is thirteen characters.
  [ "${#name}" -ge $(( ${#base} + 13 )) ] || return 1
  case "${name:$((${#name} - 13))}" in
    .owner.??????) ;;
    *) return 1 ;;
  esac
  rest=${name:0:$((${#name} - 13))}
  while :; do
    [ "$rest" = "$base" ] && return 0
    case "$rest" in
      *.steal) rest=${rest%.steal} ;;
      *) return 1 ;;
    esac
  done
}

fm_lock_link_owner() {
  local lockdir=$1 owner dir
  owner=$(readlink "$lockdir" 2>/dev/null) || return 1
  [ -n "$owner" ] || return 1
  case "$owner" in
    /*) printf '%s\n' "$owner" ;;
    *)
      dir=${lockdir%/*}
      [ -n "$dir" ] || dir=/
      printf '%s/%s\n' "$dir" "$owner"
      ;;
  esac
}

# Path-normalized symlink pointer check (supports both relative and absolute targets)
fm_lock_points_to_owner() {
  local lockdir=$1 ownerdir=$2 actual dir
  # The fork-free test first. A symlink and the directory it points at ARE
  # the same file, and bash's -ef resolves that without a subprocess. This
  # check runs several times on every acquire attempt, and a contended lock
  # must not cost a readlink fork per call.
  #
  # It is also stricter than comparing the link's target text: a pointer whose
  # owner dir has been reclaimed no longer resolves, so it correctly stops
  # claiming to point at an owner.
  [ -L "$lockdir" ] || return 1
  [ "$lockdir" -ef "$ownerdir" ] && return 0
  # Fall back to comparing the link's target text, for a relative target whose
  # two names do not resolve to the same file.
  actual=$(readlink "$lockdir" 2>/dev/null) || return 1
  dir=${lockdir%/*}
  [ -n "$dir" ] || dir=/
  case "$actual" in
    /*) [ "$actual" = "$ownerdir" ] ;;
    *) [ "$dir/$actual" = "$ownerdir" ] ;;
  esac
}

fm_lock_discard_owner() {
  local ownerdir=$1
  [ -n "$ownerdir" ] || return 0
  fm_lock_clean_known_files "$ownerdir"
  rmdir "$ownerdir" 2>/dev/null || true
}

# fm_lock_owner_dir_present <lockdir>
# 0 when the lock pointer resolves to an owner dir that EXISTS, 1 otherwise.
# A pointer whose owner dir is gone is a dangling pointer: that lock is
# genuinely broken and reclaimable.
#
# KNOWN PRE-EXISTING DEFECT (measured 2026-10-21, lane
# m3.1f-firstmate-lockdeadline, NOT introduced by it): with eight
# contenders on one lock, the primitive can let two holders into the
# critical section at once. The pristine baseline reproduces it (2 of 3
# runs, and it also wedges after 1-3 of 48 rounds). A holder whose owner
# state cannot be read for an instant is displaced as though it were dead.
# Refusing to displace such a holder was tried and REJECTED here: it turns
# the rare double hold into a permanent wedge, which is the far worse
# failure (it blocks every later scan). The defect is reported, not
# papered over; see the lane report.
fm_lock_owner_dir_present() {
  local lockdir=$1 ownerdir
  [ -L "$lockdir" ] || return 1
  ownerdir=$(fm_lock_link_owner "$lockdir" 2>/dev/null || true)
  [ -n "$ownerdir" ] || return 1
  [ -d "$ownerdir" ] || return 1
  return 0
}

# fm_lock_holder_pid <lockdir>
# The pid recorded by the current lock owner, or an empty string when the
# lock records none. A read builtin, not a cat subprocess: this runs on
# every acquire attempt.
#
# The read status is deliberately NOT used to clear the value. A pid file
# whose last line carries no trailing newline still holds a valid pid, and
# discarding it would make a LIVE holder look dead to the next acquirer.
fm_lock_holder_pid() {
  local lockdir=$1 pid=''
  [ -e "$lockdir" ] || [ -L "$lockdir" ] || { printf '\n'; return 0; }
  IFS= read -r pid 2>/dev/null <"$lockdir/pid" || true
  case "$pid" in ''|*[!0-9]*) pid='' ;; esac
  printf '%s\n' "$pid"
}

fm_lock_remove_stray_owner_link() {
  local lockdir=$1 ownerdir=$2 stray
  stray="$lockdir/${ownerdir##*/}"
  if [ -L "$stray" ] && fm_lock_points_to_owner "$stray" "$ownerdir"; then
    # Own-scratch: a stray pointer this library created moments ago.
    fm_lock_purge_own "$stray" 2>/dev/null || true
  fi
}

fm_lock_claim_blocked_by_steal() {
  local lockdir=$1 allowed_steal_owner=${2:-} steal
  steal="$lockdir.steal"
  [ -e "$steal" ] || [ -L "$steal" ] || return 1
  if [ -n "$allowed_steal_owner" ] && fm_lock_points_to_owner "$steal" "$allowed_steal_owner"; then
    return 1
  fi
  return 0
}

fm_lock_claim() {
  local lockdir=$1 ownerdir=$2 allowed_steal_owner=${3:-} mypid back
  mypid=${BASHPID:-$$}
  # VERIFY the pid this owner dir already carries; do not rewrite it.
  #
  # The pointer to this owner dir may already be published, and `> file`
  # truncates before it writes. Rewriting the pid here therefore created a
  # window in which a PUBLISHED lock had no pid at all, and the next
  # acquirer read that as "the holder is dead" and displaced a holder that
  # was still inside the critical section. fm_lock_prepare_owner already
  # wrote and verified the pid before the pointer was published, so the
  # rewrite bought nothing and cost mutual exclusion.
  back=
  IFS= read -r back 2>/dev/null <"$ownerdir/pid" || true
  if [ "$back" != "$mypid" ]; then
    fm_lock_discard_owner "$ownerdir"
    return 1
  fi
  if ! fm_lock_points_to_owner "$lockdir" "$ownerdir"; then
    fm_lock_discard_owner "$ownerdir"
    return 1
  fi
  if fm_lock_claim_blocked_by_steal "$lockdir" "$allowed_steal_owner"; then
    if fm_lock_points_to_owner "$lockdir" "$ownerdir"; then
      # Own-scratch: the lock pointer this library is abandoning.
      fm_lock_purge_own "$lockdir" 2>/dev/null || true
    fi
    fm_lock_discard_owner "$ownerdir"
    return 1
  fi
  return 0
}

# Safe abandoned-lock predicate: tests dead/missing PID AND age past grace period
fm_lock_is_abandoned() {
  local lockdir=$1 grace=${2:-${FM_LOCK_STALE_AFTER:-2}}
  [ "$grace" -lt 2 ] && grace=2
  [ -e "$lockdir" ] || [ -L "$lockdir" ] || return 1

  local pid
  pid=$(fm_lock_holder_pid "$lockdir")
  if fm_pid_alive "$pid"; then
    return 1 # Live owner: NEVER abandoned
  fi
  local age
  age=$(fm_path_age "$lockdir")
  if [ "$age" -lt "$grace" ]; then
    return 1 # Fresh initializing lock: within grace window
  fi

  return 0
}

# fm_lock_holder_is_stuck <lockdir>
# 0 when the lock's holder is ALIVE but the lock has been held longer than
# FM_LOCK_MAX_HOLD_S. A live holder is not automatically a working holder:
# a process that wedges mid-critical-section keeps its pid alive and its lock
# held forever. This is the predicate that separates BUSY from STUCK.
fm_lock_holder_is_stuck() {
  local lockdir=$1 pid age max_hold
  pid=$(fm_lock_holder_pid "$lockdir")
  [ -n "$pid" ] || return 1
  fm_pid_alive "$pid" || return 1
  max_hold=$(fm_lock_default_max_hold)
  age=$(fm_path_age "$lockdir")
  [ "$age" -ge "$max_hold" ]
}

# fm_lock_holder_qualifies_to_break <lockdir> <expected-pid>
# 0 when the holder may be broken: the owner recorded under the lock is
# exactly <expected-pid>, that pid is alive, and the lock is still older than
# the max hold age. The caller runs this UNDER the steal mutex, so a lock
# that changed underneath the breaker (a fresh claim, a different owner) can
# never qualify.
fm_lock_holder_qualifies_to_break() {
  local lockdir=$1 expected_pid=$2 actual_pid age max_hold
  [ -n "$expected_pid" ] || return 1
  actual_pid=$(fm_lock_holder_pid "$lockdir")
  [ "$actual_pid" = "$expected_pid" ] || return 1
  fm_pid_alive "$actual_pid" || return 1
  max_hold=$(fm_lock_default_max_hold)
  age=$(fm_path_age "$lockdir")
  [ "$age" -ge "$max_hold" ] || return 1
  return 0
}

fm_lock_try_create() {
  local lockdir=$1 allowed_steal_owner=${2:-} ownerdir
  FM_LOCK_OWNER_DIR=
  ownerdir=$(fm_lock_owner_dir "$lockdir") || return 1

  if [ -e "$lockdir" ] || [ -L "$lockdir" ]; then
    # Safe reclamation: only reclaim if allowed_steal_owner is set (under steal mutex)
    # OR if confirmed abandoned with grace period >= 5s. Never blind rm -rf!
    if [ -n "$allowed_steal_owner" ] || fm_lock_is_abandoned "$lockdir" 5; then
      local stale_owner
      stale_owner=$(fm_lock_link_owner "$lockdir" 2>/dev/null || true)
      # Own-scratch: an abandoned lock pointer. Unlinked for real, not moved
      # into the trash.
      fm_lock_purge_own "$lockdir" 2>/dev/null || true
      [ -n "$stale_owner" ] && fm_lock_discard_owner "$stale_owner"
    else
      fm_lock_discard_owner "$ownerdir"
      return 1
    fi
  fi

  if ! fm_lock_prepare_owner "$ownerdir"; then
    fm_lock_discard_owner "$ownerdir"
    return 1
  fi
  if ln -s "$ownerdir" "$lockdir" 2>/dev/null && fm_lock_points_to_owner "$lockdir" "$ownerdir"; then
    if fm_lock_claim "$lockdir" "$ownerdir" "$allowed_steal_owner"; then
      FM_LOCK_OWNER_DIR=$ownerdir
      return 0
    fi
    if fm_lock_points_to_owner "$lockdir" "$ownerdir"; then
      # Own-scratch: the lock pointer this library is abandoning.
      fm_lock_purge_own "$lockdir" 2>/dev/null || true
    fi
  else
    fm_lock_remove_stray_owner_link "$lockdir" "$ownerdir"
  fi
  fm_lock_discard_owner "$ownerdir"
  return 1
}

fm_lock_remove_path() {
  local lockdir=$1 ownerdir
  if [ -L "$lockdir" ]; then
    ownerdir=$(fm_lock_link_owner "$lockdir" 2>/dev/null || true)
    # Own-scratch: a lock pointer. Unlinked for real, not moved into the trash.
    fm_lock_purge_own "$lockdir" 2>/dev/null || return 1
    [ -n "$ownerdir" ] && fm_lock_discard_owner "$ownerdir"
    return 0
  fi
  fm_lock_clean_known_files "$lockdir"
  rmdir "$lockdir" 2>/dev/null
}

fm_lock_mid_acquire_is_fresh() {
  local lockdir=$1 pid=$2 mid_acquire_stale
  case "$pid" in
    ''|*[!0-9]*)
      mid_acquire_stale=$FM_LOCK_STALE_AFTER
      [ "$mid_acquire_stale" -lt 2 ] && mid_acquire_stale=2
      [ "$(fm_path_age "$lockdir")" -lt "$mid_acquire_stale" ]
      return
      ;;
  esac
  return 1
}

fm_lock_recheck_stale_owner() {
  local lockdir=$1 expected_owner=$2 expected_pid=$3 allow_break=${4:-0} actual_pid
  if [ -n "$expected_owner" ]; then
    if [ -e "$lockdir" ] || [ -L "$lockdir" ]; then
      fm_lock_points_to_owner "$lockdir" "$expected_owner" || return 1
    fi
  elif [ -e "$lockdir" ] || [ -L "$lockdir" ]; then
    [ -d "$lockdir" ] && [ ! -L "$lockdir" ] || return 1
  fi
  actual_pid=$(fm_lock_holder_pid "$lockdir")
  [ "$actual_pid" = "$expected_pid" ] || return 1
  if fm_pid_alive "$actual_pid"; then
    # A live holder is stale only when it is STUCK: alive, unchanged under
    # the steal mutex, and past the max hold age. The caller passed
    # allow_break only when it opted into breaking a stuck holder.
    if [ "$allow_break" = 1 ] && fm_lock_holder_qualifies_to_break "$lockdir" "$actual_pid"; then
      return 0
    fi
    return 1
  fi
  if fm_lock_mid_acquire_is_fresh "$lockdir" "$actual_pid"; then
    return 1
  fi
  return 0
}

# fm_lock_try_acquire <lockdir> [allow-break]
# Try once to take <lockdir>.
#   allow-break = 1 lets this attempt break a STUCK live holder: one that is
#   alive but has held the lock longer than FM_LOCK_MAX_HOLD_S. It is off by
#   default, so every existing caller keeps its exact current behaviour: a
#   live holder is never displaced.
#
# The break reuses the steal mutex that already serialises reclaimers. Under
# that mutex the owner is re-read and re-checked, so a lock that changed
# underneath the breaker is never broken, and two breakers never race.
fm_lock_try_acquire() {
  local lockdir=$1 allow_break=${2:-0} pid steal cur rc steal_owner primary_owner
  FM_LOCK_HELD_PID=
  FM_LOCK_OWNER_DIR=

  if fm_lock_try_create "$lockdir"; then
    return 0
  fi

  pid=$(fm_lock_holder_pid "$lockdir")
  if fm_pid_alive "$pid"; then
    if [ "$allow_break" != 1 ] || ! fm_lock_holder_qualifies_to_break "$lockdir" "$pid"; then
      FM_LOCK_HELD_PID=$pid
      return 1
    fi
    # Alive but past its age budget: fall through to the steal path, which
    # re-checks the holder under the mutex before displacing it.
  else
    if fm_lock_mid_acquire_is_fresh "$lockdir" "$pid"; then
      FM_LOCK_HELD_PID=$pid
      return 1
    fi
  fi

  steal="$lockdir.steal"
  if ! fm_lock_try_acquire "$steal" "$allow_break"; then
    FM_LOCK_HELD_PID=$(fm_lock_holder_pid "$lockdir")
    FM_LOCK_OWNER_DIR=
    return 1
  fi
  steal_owner=${FM_LOCK_OWNER_DIR:-}

  cur=$(fm_lock_holder_pid "$lockdir")
  if fm_pid_alive "$cur"; then
    if [ "$allow_break" != 1 ] || ! fm_lock_holder_qualifies_to_break "$lockdir" "$cur"; then
      fm_lock_release "$steal"
      FM_LOCK_HELD_PID=$cur
      FM_LOCK_OWNER_DIR=
      return 1
    fi
  else
    if fm_lock_mid_acquire_is_fresh "$lockdir" "$cur"; then
      fm_lock_release "$steal"
      FM_LOCK_HELD_PID=$cur
      FM_LOCK_OWNER_DIR=
      return 1
    fi
  fi
  if ! fm_lock_points_to_owner "$steal" "$steal_owner"; then
    fm_lock_release "$steal"
    FM_LOCK_HELD_PID=$(fm_lock_holder_pid "$lockdir")
    FM_LOCK_OWNER_DIR=
    return 1
  fi

  primary_owner=
  if [ -L "$lockdir" ]; then
    primary_owner=$(fm_lock_link_owner "$lockdir" 2>/dev/null || true)
  fi
  cur=$(fm_lock_holder_pid "$lockdir")
  if ! fm_lock_recheck_stale_owner "$lockdir" "$primary_owner" "$cur" "$allow_break"; then
    fm_lock_release "$steal"
    FM_LOCK_HELD_PID=$(fm_lock_holder_pid "$lockdir")
    FM_LOCK_OWNER_DIR=
    return 1
  fi

  fm_lock_remove_path "$lockdir" || true
  rc=1
  if fm_lock_try_create "$lockdir" "$steal_owner"; then
    rc=0
  fi
  if [ "$rc" -ne 0 ]; then
    FM_LOCK_HELD_PID=$(fm_lock_holder_pid "$lockdir")
    FM_LOCK_OWNER_DIR=
  fi
  fm_lock_release "$steal"
  return "$rc"
}

# fm_lock_reclaim_owner_dirs <lockdir>
# Remove the lock owner dirs beside <lockdir> that no live lock references.
#
# A lock owner dir is scratch by construction: mktemp made it, it holds only
# the lock's own pid file, and it is unreferenced the moment its lock pointer
# goes. Before this sweep existed, every refused acquire attempt left one
# behind: the Controller's comms receipts directory held 4,776 of them and
# grew by one every five minutes, forever. The count is the measurable proof
# of the leak, so the fix has to make it stop growing.
#
# THE CALLER MUST HOLD <lockdir> WHEN IT CALLS THIS. That is the whole
# safety rule. An acquirer creates its owner dir and publishes the lock
# pointer as two separate steps, so a dir that no pointer references can
# still belong to an acquirer that is mid-claim. Deleting that dir leaves
# the published pointer dangling; the next acquirer then reads no pid, sees
# the holder as dead, and displaces a holder that is still inside the
# critical section. Two holders at once.
#
# Holding the lock makes that impossible: while this caller holds it, no
# other process can be mid-claim for it.
#
# A dir whose recorded pid is still alive is skipped as well, so an owner
# that is alive but not currently holding the pointer is never disturbed.
# FM_LOCK_RECLAIMED counts what was removed, which is how a caller observes
# that the sweep is working.
#
# The sweep is bounded and cheap on purpose. It runs while the caller HOLDS the
# lock, so every fork it spends is lock-held latency. Two rules keep that
# bounded:
#
#   - The clock is read ONCE per sweep, not once per candidate.
#   - At most FM_LOCK_RECLAIM_MAX dirs are removed per sweep.
#
# The cap matters because the backlog can be large: the Controller's receipts
# directory held 4,776 owner dirs. One uncapped sweep would have forked
# roughly 19,000 times (stat + date + rm per dir) inside the critical section
# it was trying to free. With the cap, the backlog drains over successive
# acquires and releases instead of in one stall, and the count still falls to
# zero.
fm_lock_reclaim_owner_dirs() {
  local lockdir=$1 dir base live_owner live_steal_owner path pid age grace
  local now m removed max name
  dir=${lockdir%/*}
  [ -n "$dir" ] || dir=/
  base=${lockdir##*/}
  grace=${FM_LOCK_RECLAIM_GRACE_S:-5}
  case "$grace" in ''|*[!0-9]*) grace=5 ;; esac
  max=${FM_LOCK_RECLAIM_MAX:-64}
  case "$max" in ''|*[!0-9]*) max=64 ;; esac
  now=$(date +%s)
  case "$now" in ''|*[!0-9]*) now=0 ;; esac
  removed=0
  live_owner=$(fm_lock_link_owner "$lockdir" 2>/dev/null || true)
  live_steal_owner=$(fm_lock_link_owner "$lockdir.steal" 2>/dev/null || true)
  # ONE glob for the whole directory, then a name test that accepts every
  # steal depth. The depth is unbounded (39 levels measured on the
  # Controller), so a fixed set of level globs reclaims a tenth of the leak
  # and leaves the rest behind. The glob is a shell expansion, so it costs
  # no subprocess however many candidates it yields.
  for path in "$dir/$base"*; do
    [ "$removed" -lt "$max" ] || break
    [ -e "$path" ] || [ -L "$path" ] || continue
    name=${path##*/}
    # A reclaim POINTER that no longer resolves. The reclaim mutex chain is
    # .lock.steal -> .lock.steal.steal -> ... , one level per recursion, and
    # a stale level-1 pointer is exactly what wedged the Controller's comms
    # lock for hours: every claim saw the pointer and refused. A pointer whose
    # target does not exist can be nobody's live claim, so removing it is
    # safe at any depth.
    if [ -L "$path" ] && [ ! -e "$path" ]; then
      fm_lock_pointer_basename_matches "$name" || continue
      [ "$path" = "$live_owner" ] && continue
      [ "$path" = "$live_steal_owner" ] && continue
      # Same grace as an owner dir: a pointer that has only just gone
      # dangling may still be part of a claim in flight.
      m=$(fm_path_mtime "$path" 2>/dev/null) || m=
      case "$m" in ''|*[!0-9]*) continue ;; esac
      age=$((now - m))
      [ "$age" -ge "$grace" ] || continue
      fm_lock_purge_own "$path" 2>/dev/null || continue
      removed=$((removed + 1))
      FM_LOCK_RECLAIMED=$((FM_LOCK_RECLAIMED + 1))
      continue
    fi
    [ -d "$path" ] || continue
    [ "$path" = "$live_owner" ] && continue
    [ "$path" = "$live_steal_owner" ] && continue
    fm_lock_owner_dir_name_matches "$name" "$base" || continue
    # Never reclaim a dir a live process is still using. The liveness test
    # is the IDENTITY test, not a bare pid test: the kernel recycles pids,
    # so a dead lock whose pid was reused by an unrelated process would
    # otherwise read as held and never be reclaimed.
    pid=$(fm_lock_holder_pid "$path")
    if [ -n "$pid" ] && fm_pid_alive "$pid" && fm_lock_pid_is_the_holder "$pid" "$path"; then
      continue
    fi
    # A dir with no pid recorded yet is a claim in its first moments; the
    # grace period covers that window.
    m=$(fm_path_mtime "$path" 2>/dev/null) || m=
    case "$m" in ''|*[!0-9]*) continue ;; esac
    age=$((now - m))
    [ "$age" -ge "$grace" ] || continue
    fm_lock_purge_own "$path" 2>/dev/null || continue
    removed=$((removed + 1))
    FM_LOCK_RECLAIMED=$((FM_LOCK_RECLAIMED + 1))
  done
  return 0
}

# fm_lock_acquire_wait_bounded <lockdir> [timeout-seconds]
# Take <lockdir>, waiting at most <timeout-seconds>. The default deadline is
# FM_LOCK_WAIT_TIMEOUT_S (120s).
#
#   0   the lock was acquired
#   124 the deadline passed while a holder still owned the lock
#   1   the lock could not be acquired for another reason
#
# On refusal FM_LOCK_HELD_PID names the holder and FM_LOCK_WAIT_REASON says
# whether the holder is BUSY (alive and still inside its age budget) or
# STUCK (alive and past FM_LOCK_MAX_HOLD_S). A caller must be able to tell
# "somebody is working" from "somebody will never finish".
#
# The wait polls on a GROWING interval, never at a fixed 0.1s. A contended
# lock must cost a few spawns a second, not 650: the fixed-interval spin was
# what turned one wedged lock into a 14.32 load average on four cores.
fm_lock_acquire_wait_bounded() {
  local lockdir=$1 timeout=${2-}
  local allow_break deadline started now remaining poll_ms max_ms sleep_s
  FM_LOCK_WAIT_REASON=
  FM_LOCK_HELD_PID=

  if [ -z "$timeout" ]; then
    timeout=$(fm_lock_default_wait_timeout)
  else
    case "$timeout" in ''|*[!0-9]*) timeout=$(fm_lock_default_wait_timeout) ;; esac
  fi
  if fm_lock_break_stuck_holders_enabled; then
    allow_break=1
  else
    allow_break=0
  fi

  started=$(date +%s)
  deadline=$((started + timeout))
  poll_ms=50
  max_ms=2000
  case "${FM_LOCK_POLL_MIN_S:-}" in ''|*[!0-9]*) ;; *) poll_ms=$((FM_LOCK_POLL_MIN_S * 1000)) ;; esac
  case "${FM_LOCK_POLL_MAX_S:-}" in ''|*[!0-9]*) ;; *) max_ms=$((FM_LOCK_POLL_MAX_S * 1000)) ;; esac
  [ "$poll_ms" -gt 0 ] || poll_ms=50
  [ "$max_ms" -ge "$poll_ms" ] || max_ms=$poll_ms

  while :; do
    if fm_lock_try_acquire "$lockdir" "$allow_break"; then
      fm_lock_reclaim_owner_dirs "$lockdir"
      return 0
    fi
    now=$(date +%s)
    remaining=$((deadline - now))
    [ "$remaining" -gt 0 ] || break
    sleep_s=$(printf '%d.%03d' $((poll_ms / 1000)) $((poll_ms % 1000)))
    if [ "$poll_ms" -ge "$remaining" ]; then
      sleep_s=$(printf '%d.%03d' $((remaining / 1000)) $((remaining % 1000)))
    fi
    sleep "$sleep_s" 2>/dev/null || sleep 1
    poll_ms=$((poll_ms * 2))
    [ "$poll_ms" -le "$max_ms" ] || poll_ms=$max_ms
  done

  # Deadline reached with the lock still held. Report WHO and WHY so the
  # caller can tell a busy lock from a wedged one.
  FM_LOCK_HELD_PID=$(fm_lock_holder_pid "$lockdir")
  if [ -z "$FM_LOCK_HELD_PID" ]; then
    FM_LOCK_WAIT_REASON=contended
  elif ! fm_pid_alive "$FM_LOCK_HELD_PID"; then
    FM_LOCK_WAIT_REASON=stale
  elif fm_lock_holder_is_stuck "$lockdir"; then
    FM_LOCK_WAIT_REASON=stuck
  else
    FM_LOCK_WAIT_REASON=busy
  fi
  return "$FM_LOCK_WAIT_TIMEOUT_STATUS"
}

# fm_lock_acquire_wait <lockdir> [timeout-seconds]
# The historical name for the bounded wait. It used to spin forever, which
# is what turned one wedged lock into an unbounded CPU burn; it now returns
# non-zero (124) when the deadline passes, so every caller that ignored the
# status has to handle it.
fm_lock_acquire_wait() {
  local lockdir=$1 timeout=${2-}
  fm_lock_acquire_wait_bounded "$lockdir" "$timeout"
}

fm_lock_release() {
  local lockdir=$1 pid current ownerdir
  current=${BASHPID:-$$}
  if [ -L "$lockdir" ]; then
    ownerdir=$(fm_lock_link_owner "$lockdir" 2>/dev/null || true)
    [ -n "$ownerdir" ] || return 0
    pid=
    IFS= read -r pid 2>/dev/null <"$ownerdir/pid" || true
    [ "$pid" = "$current" ] || return 0
    fm_lock_points_to_owner "$lockdir" "$ownerdir" || return 0
    # Reclaim the orphan owner dirs while this caller still HOLDS the lock.
    # After the pointer is gone another acquirer may start a claim, and a
    # sweep running then could delete the dir that claim is about to
    # publish. See fm_lock_reclaim_owner_dirs.
    fm_lock_reclaim_owner_dirs "$lockdir"
    # Own-scratch: the lock pointer this call is releasing. Unlinked for real;
    # a plain `rm` would relocate it into the recoverable-delete trash, which
    # is where the fleet's per-minute lock churn was piling up.
    fm_lock_purge_own "$lockdir" 2>/dev/null || return 0
    fm_lock_discard_owner "$ownerdir"
    return 0
  fi
  pid=
  IFS= read -r pid 2>/dev/null <"$lockdir/pid" || true
  [ "$pid" = "$current" ] || return 0
  fm_lock_reclaim_owner_dirs "$lockdir"
  fm_lock_remove_path "$lockdir"
}

# --- Restored durable wake-queue API (from fm-wake-lib.sh.bak-20261019_041115, lines 393-641) ---
fm_wake_clean_field() {
  LC_ALL=C tr '\t\r\n' '   '
}

fm_wake_append() {
  local kind=$1 key=$2 payload=$3 clean_key clean_payload epoch seq seq_file status
  case "$kind" in
    signal|stale|gate|check|heartbeat) ;;
    *) printf 'fm_wake_append: invalid wake kind: %s\n' "$kind" >&2; return 2 ;;
  esac

  clean_key=$(printf '%s' "$key" | fm_wake_clean_field)
  clean_payload=$(printf '%s' "$payload" | fm_wake_clean_field)
  epoch=$(date +%s)
  seq_file="$STATE/.wake-queue.seq"
  status=0

  # The queue lock is bounded and can now fail. Fail CLOSED: a wake that
  # cannot be appended under the lock is not appended at all. Writing
  # half-guarded into the queue would let a reader observe a torn record,
  # and a caller that ignored this status would believe a wake was queued
  # when it was not.
  if ! fm_lock_acquire_wait "$FM_WAKE_QUEUE_LOCK"; then
    printf 'fm_wake_append: could not take the wake queue lock (%s; holder pid %s); the wake was not queued\n' \
      "${FM_LOCK_WAIT_REASON:-contended}" "${FM_LOCK_HELD_PID:-unknown}" >&2
    return 1
  fi
  seq=$(cat "$seq_file" 2>/dev/null || echo 0)
  case "$seq" in
    ''|*[!0-9]*) seq=0 ;;
  esac
  seq=$((seq + 1))
  printf '%s\n' "$seq" > "$seq_file" || status=$?
  if [ "$status" -eq 0 ]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "$seq" "$kind" "$clean_key" "$clean_payload" >> "$FM_WAKE_QUEUE" || status=$?
  fi
  fm_lock_release "$FM_WAKE_QUEUE_LOCK"
  return "$status"
}

# fm_wake_queued_keys <kind>
# Print the distinct keys currently queued for <kind>, oldest first. Read under
# the append lock so a concurrent append is never observed half-written. The
# durable queue stays the authority: a key appears here exactly while a record
# for it is queued and unconsumed, and disappears when a drain consumes it.
fm_wake_queued_keys() {
  local kind=$1
  case "$kind" in
    signal|stale|gate|check|heartbeat) ;;
    *) printf 'fm_wake_queued_keys: invalid wake kind: %s\n' "$kind" >&2; return 2 ;;
  esac
  # A bounded read that cannot take the lock reports nothing rather than
  # reading a queue that another writer may be appending to right now.
  fm_lock_acquire_wait "$FM_WAKE_QUEUE_LOCK" || return 1
  fm_wake_queued_keys_locked "$kind"
  fm_lock_release "$FM_WAKE_QUEUE_LOCK"
}

fm_wake_queued_keys_locked() {
  local kind=$1
  awk -F '\t' -v kind="$kind" 'NF >= 5 && $3 == kind && !seen[$4]++ { print $4 }' \
    "$FM_WAKE_QUEUE" 2>/dev/null || true
}

fm_wake_restore_queue() {
  local drained=$1 restore
  restore="$STATE/.wake-queue.restore.$(fm_current_pid)"
  if [ -e "$FM_WAKE_QUEUE" ]; then
    cat "$drained" "$FM_WAKE_QUEUE" > "$restore" && mv "$restore" "$FM_WAKE_QUEUE"
  else
    mv "$drained" "$FM_WAKE_QUEUE"
  fi
}

fm_wake_print_deduped() {
  local file=$1
  awk -F '\t' '
    NF >= 5 {
      dedupe = $3 SUBSEP $4
      if ($3 == "heartbeat") {
        dedupe = "heartbeat"
      }
      if (!(dedupe in seen)) {
        order[++count] = dedupe
        seen[dedupe] = 1
      }
      line[dedupe] = $0
    }
    END {
      for (i = 1; i <= count; i++) {
        print line[order[i]]
      }
    }
  ' "$file"
}

# Map one structurally valid signal key to its home-local status filename.
# Queue payload text is intentionally ignored: it is display data, not a path
# authority. The caller still verifies the resulting regular file immediately
# before its bounded read.
FM_WAKE_STATUS_KEY=
FM_WAKE_STATUS_HISTORICAL=false
fm_wake_status_key_map() {  # <queue-key>
  local key=$1 id
  FM_WAKE_STATUS_KEY=
  FM_WAKE_STATUS_HISTORICAL=false
  case "$key" in
    *.status)
      id=${key%.status}
      ;;
    *.turn-ended)
      id=${key%.turn-ended}
      FM_WAKE_STATUS_HISTORICAL=true
      ;;
    *)
      return 1
      ;;
  esac
  case "$id" in
    ''|.*|*[!A-Za-z0-9._-]*) return 1 ;;
  esac
  [ "${#id}" -le 64 ] || return 1
  FM_WAKE_STATUS_KEY="$id.status"
}

fm_wake_annotation_manifest() {  # <deduped-raw-rows>
  local rows=$1 epoch seq kind key payload
  while IFS=$(printf '\t') read -r epoch seq kind key payload; do
    [ "$kind" = signal ] || continue
    fm_wake_status_key_map "$key" || continue
    if [ "$FM_WAKE_STATUS_HISTORICAL" = true ]; then
      printf '%s\thistorical\n' "$FM_WAKE_STATUS_KEY"
    else
      printf '%s\tdirect\n' "$FM_WAKE_STATUS_KEY"
    fi
  done <<EOF
$rows
EOF
}

FM_WAKE_EVENT_LINE=
FM_WAKE_EVENT_TRUNCATED=false
fm_wake_latest_event() {  # <validated-status-path> <tail-byte-cap>
  local path=$1 tail_bytes=$2 result size chunk record line_number
  FM_WAKE_EVENT_LINE=
  FM_WAKE_EVENT_TRUNCATED=false
  result=$(perl -MFcntl=:DEFAULT -e '
    my ($path, $limit) = @ARGV;
    sysopen(my $file, $path, O_RDONLY | O_NOFOLLOW) or exit 1;
    my @stat = stat $file or exit 1;
    exit 1 unless -f _;
    my $size = $stat[7];
    exit 1 unless $size =~ /\A\d+\z/;
    my $start = $size > $limit ? $size - $limit : 0;
    seek($file, $start, 0) or exit 1;
    printf "%s\t", $size or exit 1;
    my $remaining = $size - $start;
    while ($remaining > 0) {
      my $read = read($file, my $buffer, $remaining);
      exit 1 unless defined $read;
      last unless $read;
      print $buffer or exit 1;
      $remaining -= $read;
    }
  ' "$path" "$tail_bytes" 2>/dev/null) || return 1
  size=${result%%$'\t'*}
  chunk=${result#*$'\t'}
  case "$size" in ''|*[!0-9]*) return 1 ;; esac
  [ -n "$chunk" ] || return 1
  record=$(printf '%s' "$chunk" | LC_ALL=C awk '
    /[^[:space:]]/ { line = $0; line_number = NR }
    END { if (line_number) printf "%d\t%s", line_number, line }
  ') || return 1
  [ -n "$record" ] || return 1
  line_number=${record%%	*}
  FM_WAKE_EVENT_LINE=${record#*	}
  FM_WAKE_EVENT_LINE=$(printf '%s' "$FM_WAKE_EVENT_LINE" | LC_ALL=C tr '\t\r' '  ')
  if [ "$size" -gt "$tail_bytes" ] && [ "$line_number" -eq 1 ]; then
    FM_WAKE_EVENT_TRUNCATED=true
  fi
}

# Print supplemental drain-time context only after the caller has committed the
# raw queue consumption and released the append lock. The limits are constants,
# so status-file volume cannot turn a drain into an unbounded context read.
fm_wake_print_annotations() {  # <deduped-raw-rows>
  local rows=$1 manifest status_key mode path prefix line suffix keep bytes
  local output='' used=0 omitted=0 read_omitted=0 annotation_marker marker_reserve=192
  local tail_bytes=8192 item_bytes=2048 global_bytes=8192 read_cap=8 reads=0
  local LC_ALL=C

  manifest=$(fm_wake_annotation_manifest "$rows" | awk -F '\t' '
    {
      key = $1
      if (!(key in seen)) {
        order[++count] = key
        seen[key] = 1
        mode[key] = $2
      } else if ($2 == "direct") {
        mode[key] = "direct"
      }
    }
    END {
      for (i = 1; i <= count; i++) print order[i] "\t" mode[order[i]]
    }
  ') || return 0

  # Test-only latency seam for proving that queue appends remain independent of
  # a slow best-effort annotation phase.
  case "${FM_WAKE_ENRICH_TEST_DELAY:-0}" in
    0) ;;
    ''|*[!0-9]*) ;;
    *) sleep "$FM_WAKE_ENRICH_TEST_DELAY" ;;
  esac

  while IFS=$(printf '\t') read -r status_key mode; do
    [ -n "$status_key" ] || continue
    if [ "$reads" -ge "$read_cap" ]; then
      read_omitted=$((read_omitted + 1))
      continue
    fi
    reads=$((reads + 1))
    path="$STATE/$status_key"
    fm_wake_latest_event "$path" "$tail_bytes" || continue
    prefix="wake annotation: latest wake-EVENT observed at drain, not current state"
    if [ "$mode" = historical ]; then
      prefix="$prefix; historical / not necessarily the triggering event"
    fi
    line="$prefix: $status_key: $FM_WAKE_EVENT_LINE"
    suffix=''
    [ "$FM_WAKE_EVENT_TRUNCATED" = false ] || suffix=' [truncated]'
    line="$line$suffix"
    if [ $(( ${#line} + 1 )) -gt "$item_bytes" ]; then
      suffix=' [truncated]'
      keep=$((item_bytes - ${#suffix} - 1))
      line="${line:0:$keep}$suffix"
    fi
    bytes=$(( ${#line} + 1 ))
    if [ $((used + bytes + marker_reserve)) -gt "$global_bytes" ]; then
      omitted=$((omitted + 1))
      continue
    fi
    output="$output$line
"
    used=$((used + bytes))
  done <<EOF
$manifest
EOF

  printf '%s' "$output"
  if [ "$omitted" -gt 0 ]; then
    annotation_marker="wake annotation: $omitted annotations omitted (global enrichment byte cap)"
    printf '%s\n' "$annotation_marker"
  fi
  if [ "$read_omitted" -gt 0 ]; then
    annotation_marker="wake annotation: $read_omitted annotations omitted (enrichment read cap)"
    printf '%s\n' "$annotation_marker"
  fi
  return 0
}

# Resolve the machine-local root Firstmate home for a home in the local
# secondmate tree. A remote parent ends the walk: it is the root of this
# machine's local tree, whose descendants are the only homes visible here.
fm_firstmate_root_home() {
  local home=${1:-$FM_HOME} marker parent seen="|" depth=0
  home=$(CDPATH='' cd -- "$home" 2>/dev/null && pwd -P) || return 1
  while [ -e "$home/.fm-secondmate-parent" ] || [ -L "$home/.fm-secondmate-parent" ]; do
    marker="$home/.fm-secondmate-parent"
    if ! command -v fm_secondmate_parent_record_parse >/dev/null 2>&1; then
      # shellcheck source=bin/fm-secondmate-parent-lib.sh
      . "$FM_WAKE_LIB_DIR/fm-secondmate-parent-lib.sh"
    fi
    fm_secondmate_parent_record_parse "$marker" || return 1
    case "$FM_SECONDMATE_PARENT_ROUTE" in
      local) ;;
      remote) break ;;
      *) return 1 ;;
    esac
    parent=$(CDPATH='' cd -- "$FM_SECONDMATE_PARENT_HOME" 2>/dev/null && pwd -P) || return 1
    case "$seen" in *"|$parent|"*) return 1 ;; esac
    seen="$seen$home|"
    home=$parent
    depth=$((depth + 1))
    [ "$depth" -le 64 ] || return 1
  done
  printf '%s\n' "$home"
}

# Enumerate every local Firstmate state directory that shares machine-local
# resources with the current home. Remote homes are naturally excluded because
# a remote parent ends the root walk and only local registry paths are followed.
FM_LOCAL_FIRSTMATE_STATES=()
FM_LOCAL_FIRSTMATE_ERROR=
fm_local_firstmate_state_dirs() {  # <first-state>
  local first=$1 root home reg line child known existing i=0
  local -a homes
  FM_LOCAL_FIRSTMATE_STATES=("$first")
  FM_LOCAL_FIRSTMATE_ERROR=
  root=$(fm_firstmate_root_home "$FM_HOME") || {
    FM_LOCAL_FIRSTMATE_ERROR="cannot resolve the root Firstmate home"
    return 1
  }
  if ! command -v secondmate_registry_parse_line >/dev/null 2>&1; then
    # shellcheck source=bin/fm-secondmate-registry-lib.sh
    . "$FM_WAKE_LIB_DIR/fm-secondmate-registry-lib.sh"
  fi
  homes=("$root")
  while [ "$i" -lt "${#homes[@]}" ]; do
    home=${homes[$i]}
    i=$((i + 1))
    known=0
    for existing in "${FM_LOCAL_FIRSTMATE_STATES[@]}"; do
      if [ "$existing" = "$home/state" ] || [ "$existing" -ef "$home/state" ]; then
        known=1
      fi
    done
    [ "$known" = 1 ] || FM_LOCAL_FIRSTMATE_STATES+=("$home/state")
    reg="$home/data/secondmates.md"
    [ ! -e "$reg" ] && [ ! -L "$reg" ] && continue
    [ -f "$reg" ] && [ ! -L "$reg" ] || {
      FM_LOCAL_FIRSTMATE_ERROR="local Firstmate registry is unsafe at $reg"
      return 1
    }
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "- "*)
          secondmate_registry_parse_line "$line" || {
            FM_LOCAL_FIRSTMATE_ERROR="malformed local Firstmate registry entry in $reg"
            return 1
          }
          child=$([ -d "$SECONDMATE_REGISTRY_HOME" ] &&
            CDPATH='' cd -- "$SECONDMATE_REGISTRY_HOME" 2>/dev/null && pwd -P) || {
            # This sourced-library diagnostic is read by fm-spawn.sh.
            # shellcheck disable=SC2034
            FM_LOCAL_FIRSTMATE_ERROR="registered local Firstmate home is unavailable: $SECONDMATE_REGISTRY_HOME"
            return 1
          }
          known=0
          for existing in "${homes[@]}"; do
            [ "$existing" != "$child" ] || known=1
          done
          [ "$known" = 1 ] || homes+=("$child")
          ;;
      esac
    done < "$reg"
  done
}

# Return the shared lock path for one project identity. Clones with the same
# origin share a lock; a local-only project falls back to its own worktree root.
fm_treehouse_project_lock_path() {  # <project-dir>
  local project=$1 root origin identity hash top
  [ -d "$project" ] || return 1
  root=$(fm_firstmate_root_home "$FM_HOME") || return 1
  origin=$(git -C "$project" remote get-url origin 2>/dev/null || true)
  if [ -n "$origin" ]; then
    case "$origin" in
      /*) [ ! -d "$origin" ] || origin=$(CDPATH='' cd -- "$origin" 2>/dev/null && pwd -P) || return 1 ;;
      *://*|*:* ) ;;
      *) [ ! -d "$project/$origin" ] || origin=$(CDPATH='' cd -- "$project/$origin" 2>/dev/null && pwd -P) || return 1 ;;
    esac
    identity=$origin
  else
    top=$(git -C "$project" rev-parse --show-toplevel 2>/dev/null) || return 1
    top=$(CDPATH='' cd -- "$top" 2>/dev/null && pwd -P) || return 1
    identity=$top
  fi
  hash=$(printf '%s' "$identity" | git hash-object --stdin 2>/dev/null) || return 1
  [ -d "$root/state" ] || return 1
  printf '%s/.treehouse-project-%s.lock\n' "$root/state" "$hash"
}
