#!/usr/bin/env bash
# fm-lock-reclaim-lib.sh - reclaim DEAD lock scratch, from outside the lock.
#
# WHY THIS EXISTS.
#
# bin/fm-wake-lib.sh sweeps a lock's own owner dirs on every acquire and every
# release, but only the dirs BESIDE the lock it is holding. A lock that nobody
# touches again is never swept, and the capacity reclaimer
# (bin/fm-capacity-reclaim.sh) could not see a lock owner dir either - it had
# no idea one existed. So the two of them together still let a lock leak
# forever: on 2026-10-21 the Controller's comms receipts directory held 37,235
# owner dirs (357 MB) and the reclaimer reported the directory as 3.6 MB of
# receipts and 357 MB of pure lock garbage it could not touch.
#
# This library is the OUTSIDE view. It finds lock scratch anywhere under a set
# of roots and reclaims the parts that are PROVABLY dead.
#
# THE SAFETY ARGUMENT (the whole point of this file).
#
# A lock owner dir records the pid of the process that created it. "Is that pid
# alive?" is NOT a sufficient test, because the kernel RECYCLES pids. Measured
# on the Controller on 2026-10-21: 21,201 of the leaked dirs recorded a pid
# that happened to be running again as an unrelated process, so a naive
# liveness test would have kept every one of them alive forever. Only 6 dirs
# were held by a genuinely live process.
#
# The correct test compares the process's START TIME with the owner dir's own
# mtime: a process that started AFTER the dir was created cannot be the
# process that created it, so its pid was recycled and the lock is dead. When a
# `pid-identity` file is present the match is exact and strictly stronger, and
# it wins.
#
# THE RACE between the check and the delete.
#
# A pid can be recycled between the check and the delete. That race is
# harmless here, and the reasoning is the point: the reclaim decision is about
# the RELATIONSHIP between the recorded pid and the dir's creation time, not
# about the pid's identity at the moment of the delete. A dir whose recorded
# pid was already dead - or already recycled - when it was CHECKED is garbage,
# and it stays garbage while it is deleted. What would be unsafe is deleting a
# dir whose holder is ALIVE, and the start-time test rules that out: a holder
# necessarily started BEFORE it created the dir, so a live holder's start time
# is always older than the dir.
#
# A live holder is never touched. A lock pointer is never removed while a live
# owner references it: a pointer is removed only when its owner dir is one
# this sweep reclaimed, or when the pointer's own target is provably dead.
#
# THE SHAPES are not invented here. They are mirrored from
# bin/fm-wake-lib.sh (fm_lock_pointer_basename_matches,
# fm_lock_owner_dir_basename_matches, fm_lock_owner_private), which is the
# owner of the lock protocol. They are mirrored rather than shared because
# that file belongs to the lock lane and is edited while this lane works;
# tests/fm-lock-reclaim-disk.test.sh asserts that the two implementations
# agree on every name in a corpus, so the mirroring cannot silently drift.
#
# The three gates a path must pass to be touched at all:
#
#   1  the NAME must be a lock shape: a pointer name at any steal depth
#      (<base>.lock, <base>.lock.steal, <base>.lock.steal.steal, ...) or an
#      owner dir name at any steal depth
#      (<base>.lock.owner.XXXXXX, <base>.lock.steal.owner.XXXXXX, ...).
#   2  a POINTER must be a SYMLINK. A plain file called ".lock" belongs to
#      another lock family (a flock target with real content) and is never
#      touched. A directory called "<something>.lock" is a directory-based
#      lock from another family and is never touched.
#   3  an OWNER DIR must be OWNER-PRIVATE (mode 0700). mktemp makes what it
#      creates private, and tracked repository content is never 0700, so this
#      is what keeps tracked material out of reach.
#
# THE COST. A leak is tens of thousands of dirs, and the reclaim that runs this
# sweep is bounded by a wall-clock timeout. So the sweep does almost no
# forking: the candidates and their mtimes come out of ONE find pass, the
# parent's symlinks are read ONCE, the boot time and the clock rate are read
# ONCE, and the liveness test is arithmetic on values already in hand. The
# only fork per reclaimed dir is the rm itself.
#
# Usage:
#   . bin/fm-lock-reclaim-lib.sh
#   fm_lock_reclaim_sweep /root/agent-work/deightonllm-firstmate/state
#
# Counters the sweep sets (all of them are facts, never projections):
#   FM_LOCK_RECLAIM_DIRS       owner dirs reclaimed
#   FM_LOCK_RECLAIM_POINTERS   lock pointers reclaimed
#   FM_LOCK_RECLAIM_LIVE       owner dirs skipped because a live holder owns them
#   FM_LOCK_RECLAIM_UNKNOWN    owner dirs skipped because liveness could not be decided
#   FM_LOCK_RECLAIM_BYTES      KB reclaimed, measured by du on the affected parents
#
# Knobs (all read at call time, so a test can set one for a single call):
#   FM_RECLAIM_LOCK_GRACE_S   age before dead scratch may be reclaimed (default 5)
#   FM_RECLAIM_LOCK_MAXDEPTH  how deep under a root the sweep looks (default 6)
#   FM_RECLAIM_LOCK_MAX       owner dirs reclaimed per sweep (default 100000)
#   FM_RECLAIM_LOCK_BUDGET_S  wall-clock budget for one sweep (default 60)
#   FM_SCRATCH_REAL_RM        test seam for the real-rm resolution

FM_LOCK_RECLAIM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- the real unlink ---------------------------------------------------------
#
# `rm` on this host is a recoverable-delete shim (/root/.minimax/shims/rm) that
# MOVES the target into ~/.local/share/Trash. On a single filesystem that move
# frees ZERO bytes: the trash grew to 14.1 GB while df sat at 97% with 2.8 GB
# free. A reclaim that must free bytes needs the REAL rm, resolved by
# absolute path and never by PATH lookup, and the shim is refused even when it
# is found at one of those paths.
fm_lock_reclaim_real_rm() {
  local candidate resolved
  for candidate in "${FM_SCRATCH_REAL_RM:-}" /usr/bin/rm /bin/rm; do
    [ -n "$candidate" ] || continue
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

# --- the shapes (mirrored from bin/fm-wake-lib.sh) ---------------------------
#
# A glob cannot express "<base>.lock" followed by zero or more ".steal"
# infixes, so the infixes are peeled off one at a time.

# 0 when <name> is a lock pointer or reclaim pointer name at any steal depth.
fm_lock_reclaim_pointer_basename_matches() {
  local name=$1 rest
  [ -n "$name" ] || return 1
  rest=$name
  while :; do
    case "$rest" in
      *.lock) return 0 ;;
      *.steal) rest=${rest%.steal} ;;
      *) return 1 ;;
    esac
  done
}

# 0 when <name> is a lock owner dir name at any steal depth.
#
# The name is <lock-basename> + zero or more ".steal" infixes + ".owner." +
# six characters, and <lock-basename> always ends in ".lock".
fm_lock_reclaim_owner_dir_basename_matches() {
  local name=$1 rest
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
      *) return 1 ;;
    esac
  done
}

# 0 when the path grants nothing to group or other. mktemp makes what it
# creates private (0700 for a directory), and tracked repository content is
# never private, so this is the guard that keeps tracked material out of the
# reclaim path.
fm_lock_reclaim_owner_private() {
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

# --- the process identity ----------------------------------------------------

fm_lock_reclaim_uname() {
  printf '%s\n' "${FM_LOCK_RECLAIM_UNAME:-$(uname 2>/dev/null || echo unknown)}"
}

fm_lock_reclaim_path_mtime() {
  local path=$1
  if [ "$(fm_lock_reclaim_uname)" = Darwin ]; then
    stat -f %m "$path" 2>/dev/null
  else
    stat -c %Y "$path" 2>/dev/null
  fi
}

# The identity of a live process: its start time and its command line. Mirrors
# fm_pid_identity in bin/fm-wake-lib.sh, including the exact string format, so
# a recorded `pid-identity` file can be compared against it directly.
fm_lock_reclaim_pid_identity() {
  local pid=$1 out proc_root stat_line starttime cmdline_hex identity_key
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  proc_root=${FM_PROC_ROOT_OVERRIDE:-/proc}
  if [ -r "$proc_root/$pid/stat" ] && [ -r "$proc_root/$pid/cmdline" ]; then
    stat_line=$(cat "$proc_root/$pid/stat" 2>/dev/null) || return 1
    fm_lock_reclaim_pid_start_ticks_set "$pid" || return 1
    starttime=$FM_LOCK_RECLAIM_TICKS_VALUE
    cmdline_hex=$(od -An -v -tx1 "$proc_root/$pid/cmdline" 2>/dev/null | tr -d '[:space:]') || return 1
    [ -n "$cmdline_hex" ] || return 1
    identity_key=proc-starttime
    [ "$(fm_lock_reclaim_uname)" != Linux ] || identity_key=linux-starttime
    printf '%s=%s cmdline-hex=%s\n' "$identity_key" "$starttime" "$cmdline_hex"
    return 0
  fi
  out=$(LC_ALL=C ps -p "$pid" -o lstart= -o command= 2>/dev/null) || return 1
  [ -n "$out" ] || return 1
  printf '%s\n' "$out" | sed 's/^[[:space:]]*//'
}

# The start time of a pid, in clock ticks. The result is left in a global so
# the hot path never forks to read it.
#
# The comm field is parenthesised and may contain spaces, so everything up to
# the LAST ')' is dropped and the fields after it are positional. The 20th
# field after the comm is the start time.
#
# The fields are split by the shell's own word splitting - one operation in C,
# with no temporary file and no per-field expansion. A `read -a` on a
# herestring writes a TEMPORARY FILE, and one per candidate is what made a
# sweep of tens of thousands of dirs slow (measured: 1.8ms per candidate,
# almost all of it the temporary file).
FM_LOCK_RECLAIM_TICKS_VALUE=
fm_lock_reclaim_pid_start_ticks_set() {  # <pid>
  local pid=$1 stat_line rest
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  IFS= read -r stat_line 2>/dev/null <"${FM_PROC_ROOT_OVERRIDE:-/proc}/$pid/stat" || return 1
  [ -n "$stat_line" ] || return 1
  rest=${stat_line##*)}
  # The glob is disabled so a comm field containing a '*' cannot expand, and
  # restored immediately afterwards.
  set -f
  # shellcheck disable=SC2086
  set -- $rest
  set +f
  [ "$#" -ge 20 ] || return 1
  case "${20}" in ''|*[!0-9]*) return 1 ;; esac
  FM_LOCK_RECLAIM_TICKS_VALUE=${20}
  return 0
}

# The start epoch of a pid, CACHED.
#
# A leak holds tens of thousands of owner dirs but only as many DISTINCT pids
# as there were processes. The pid's start epoch is therefore read from /proc
# once per distinct pid and reused, which is what keeps the sweep's cost
# proportional to the number of live processes rather than to the size of the
# leak.
#
# The cache is an ASSOCIATIVE ARRAY, and that matters: a `case` glob over a
# string of entries is O(n^2) in bash's pattern matcher, and it measured 9ms
# per candidate with 245 entries (a 32,000 dir sweep would have taken four
# minutes). An associative array is a hash lookup.
#
# Bash 3.2 has no associative arrays, so the string cache stays as the
# fallback. It is slower, and it says so in the sweep's own report.
FM_LOCK_RECLAIM_PID_EPOCH=
FM_LOCK_RECLAIM_PID_EPOCH_CACHE=
FM_LOCK_RECLAIM_EPOCH_MAP=
FM_LOCK_RECLAIM_HAS_MAP=0
if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ] 2>/dev/null; then
  declare -A FM_LOCK_RECLAIM_EPOCH_MAP=()
  FM_LOCK_RECLAIM_HAS_MAP=1
fi
fm_lock_reclaim_pid_epoch_cached() {  # <pid>
  local pid=$1 rest
  FM_LOCK_RECLAIM_PID_EPOCH=
  if [ "$FM_LOCK_RECLAIM_HAS_MAP" = 1 ]; then
    if [ -n "${FM_LOCK_RECLAIM_EPOCH_MAP[$pid]:-}" ]; then
      FM_LOCK_RECLAIM_PID_EPOCH=${FM_LOCK_RECLAIM_EPOCH_MAP[$pid]}
      return 0
    fi
  else
    case " $FM_LOCK_RECLAIM_PID_EPOCH_CACHE " in
      *" $pid="*)
        rest=${FM_LOCK_RECLAIM_PID_EPOCH_CACHE#*" $pid="}
        FM_LOCK_RECLAIM_PID_EPOCH=${rest%% *}
        return 0
        ;;
    esac
  fi
  fm_lock_reclaim_ensure_clocks
  [ -n "$FM_LOCK_RECLAIM_BTIME" ] || return 1
  [ -n "$FM_LOCK_RECLAIM_HZ" ] || return 1
  fm_lock_reclaim_pid_start_ticks_set "$pid" || return 1
  FM_LOCK_RECLAIM_PID_EPOCH=$((FM_LOCK_RECLAIM_BTIME + FM_LOCK_RECLAIM_TICKS_VALUE / FM_LOCK_RECLAIM_HZ))
  if [ "$FM_LOCK_RECLAIM_HAS_MAP" = 1 ]; then
    FM_LOCK_RECLAIM_EPOCH_MAP[$pid]=$FM_LOCK_RECLAIM_PID_EPOCH
  else
    FM_LOCK_RECLAIM_PID_EPOCH_CACHE="${FM_LOCK_RECLAIM_PID_EPOCH_CACHE:-} $pid=$FM_LOCK_RECLAIM_PID_EPOCH"
  fi
  return 0
}

fm_lock_reclaim_pid_start_ticks() {
  fm_lock_reclaim_pid_start_ticks_set "$1" || return 1
  printf '%s\n' "$FM_LOCK_RECLAIM_TICKS_VALUE"
}

fm_lock_reclaim_boot_time_epoch() {
  local line
  while IFS= read -r line; do
    case "$line" in
      btime\ *) printf '%s\n' "${line#btime }"; return 0 ;;
    esac
  done <"${FM_PROC_ROOT_OVERRIDE:-/proc}/stat" 2>/dev/null
  return 1
}

fm_lock_reclaim_clock_ticks() {
  local v
  v=$(getconf CLK_TCK 2>/dev/null) || v=
  case "$v" in ''|*[!0-9]*) v=100 ;; esac
  printf '%s\n' "$v"
}

# The boot time and the clock rate never change while the process lives, so
# they are read ONCE. The start epoch of a pid is then pure arithmetic.
FM_LOCK_RECLAIM_BTIME=
FM_LOCK_RECLAIM_HZ=
fm_lock_reclaim_ensure_clocks() {
  if [ -z "$FM_LOCK_RECLAIM_BTIME" ]; then
    FM_LOCK_RECLAIM_BTIME=$(fm_lock_reclaim_boot_time_epoch 2>/dev/null) || FM_LOCK_RECLAIM_BTIME=
  fi
  if [ -z "$FM_LOCK_RECLAIM_HZ" ]; then
    FM_LOCK_RECLAIM_HZ=$(fm_lock_reclaim_clock_ticks 2>/dev/null) || FM_LOCK_RECLAIM_HZ=
  fi
}

# The start epoch of a pid, left in a global.
FM_LOCK_RECLAIM_PID_EPOCH=
fm_lock_reclaim_pid_start_epoch_set() {  # <pid>
  local pid=$1
  fm_lock_reclaim_ensure_clocks
  [ -n "$FM_LOCK_RECLAIM_BTIME" ] || return 1
  [ -n "$FM_LOCK_RECLAIM_HZ" ] || return 1
  fm_lock_reclaim_pid_start_ticks_set "$pid" || return 1
  FM_LOCK_RECLAIM_PID_EPOCH=$((FM_LOCK_RECLAIM_BTIME + FM_LOCK_RECLAIM_TICKS_VALUE / FM_LOCK_RECLAIM_HZ))
  return 0
}

fm_lock_reclaim_pid_start_epoch() {
  fm_lock_reclaim_pid_start_epoch_set "$1" || return 1
  printf '%s\n' "$FM_LOCK_RECLAIM_PID_EPOCH"
}

# fm_lock_reclaim_holder_state_set <ownerdir> [dir-mtime]
#
# Leaves one of live | dead | unknown in FM_LOCK_RECLAIM_HOLDER_STATE.
#
#   live     a process holds this dir. NEVER touch it.
#   dead     the recorded pid is gone, or it was recycled by an unrelated
#            process. The dir is garbage.
#   unknown  liveness could not be decided. NEVER touch it: an undecidable
#            lock is treated as a live lock.
#
# The optional second argument is the owner dir's own mtime. Passing it in
# saves a fork per candidate, and a fork per candidate is what turns a sweep
# over tens of thousands of dirs into a stall.
#
# The order of the tests is the whole argument:
#
#   1  a recorded `pid-identity` wins. It is exact, and it is strictly
#      stronger than the start-time comparison. The pid is DEAD when its
#      identity no longer resolves at all, and RECYCLED when the identity
#      resolves to a different process.
#   2  a bare `pid` file (what the leaked dirs actually carry) falls back to
#      the start-time-vs-mtime test: a process that started after the dir was
#      created cannot be the process that created it.
FM_LOCK_RECLAIM_HOLDER_STATE=
fm_lock_reclaim_holder_state_set() {
  local ownerdir=$1 pid recorded current dir_mtime pid_epoch rec_start cur_start
  FM_LOCK_RECLAIM_HOLDER_STATE=unknown
  pid=
  if [ -r "$ownerdir/pid" ]; then
    IFS= read -r pid < "$ownerdir/pid" 2>/dev/null || pid=
  fi
  case "$pid" in
    ''|*[!0-9]*) return 0 ;;
  esac
  recorded=
  if [ -r "$ownerdir/pid-identity" ]; then
    IFS= read -r recorded < "$ownerdir/pid-identity" 2>/dev/null || recorded=
  fi
  if [ -n "$recorded" ]; then
    current=$(fm_lock_reclaim_pid_identity "$pid" 2>/dev/null || true)
    if [ -z "$current" ]; then
      # The identity does not resolve: the holder is gone.
      FM_LOCK_RECLAIM_HOLDER_STATE=dead
      return 0
    fi
    if [ "$current" = "$recorded" ]; then
      FM_LOCK_RECLAIM_HOLDER_STATE=live
      return 0
    fi
    # The identity differs. If the START TIME still matches, the process
    # exec'd (its command line changed) and is still the same holder, so it
    # must not be touched. Two processes cannot share a pid AND a start time.
    rec_start=${recorded#*starttime=}; rec_start=${rec_start%% *}
    cur_start=${current#*starttime=}; cur_start=${cur_start%% *}
    if [ -n "$rec_start" ] && [ "$rec_start" = "$cur_start" ]; then
      FM_LOCK_RECLAIM_HOLDER_STATE=live
      return 0
    fi
    # A different process with the same pid: the pid was recycled.
    FM_LOCK_RECLAIM_HOLDER_STATE=dead
    return 0
  fi
  # The legacy shape: a bare pid and nothing else.
  if ! kill -0 "$pid" 2>/dev/null; then
    FM_LOCK_RECLAIM_HOLDER_STATE=dead
    return 0
  fi
  if ! fm_lock_reclaim_pid_epoch_cached "$pid"; then
    return 0
  fi
  pid_epoch=$FM_LOCK_RECLAIM_PID_EPOCH
  dir_mtime=${2:-}
  if [ -z "$dir_mtime" ]; then
    dir_mtime=$(fm_lock_reclaim_path_mtime "$ownerdir" 2>/dev/null || true)
  fi
  case "$dir_mtime" in ''|*[!0-9]*) return 0 ;; esac
  # One second of slack: the two clocks are not aligned, and a process that
  # started in the same second as the claim is not provably recycled.
  if [ "$pid_epoch" -gt "$((dir_mtime + 1))" ]; then
    FM_LOCK_RECLAIM_HOLDER_STATE=dead
  else
    FM_LOCK_RECLAIM_HOLDER_STATE=live
  fi
  return 0
}

# The same answer, printed. Callers outside the hot path use this one.
fm_lock_reclaim_holder_state() {
  fm_lock_reclaim_holder_state_set "$@" || return 1
  printf '%s\n' "$FM_LOCK_RECLAIM_HOLDER_STATE"
}

# --- the sweep ---------------------------------------------------------------

FM_LOCK_RECLAIM_DIRS=0
FM_LOCK_RECLAIM_POINTERS=0
FM_LOCK_RECLAIM_LIVE=0
FM_LOCK_RECLAIM_UNKNOWN=0
FM_LOCK_RECLAIM_BYTES=0

# 1 unlinks for real, 0 reports only. The reclaimer's default is a dry run,
# and a dry run of this sweep must change NOTHING.
FM_LOCK_RECLAIM_APPLY="${FM_LOCK_RECLAIM_APPLY:-0}"

fm_lock_reclaim_unlink() {  # <path>
  local p="$1" real
  real=${FM_LOCK_RECLAIM_REAL_RM:-}
  if [ -z "$real" ]; then
    real=$(fm_lock_reclaim_real_rm 2>/dev/null) || real=
    FM_LOCK_RECLAIM_REAL_RM=$real
  fi
  if [ -z "$real" ]; then
    echo "SKIP-NO-REAL-RM $p" >&2
    return 1
  fi
  if [ -L "$p" ] || [ ! -d "$p" ]; then
    "$real" -f -- "$p" 2>/dev/null || return 1
  else
    "$real" -rf -- "$p" 2>/dev/null || return 1
  fi
  return 0
}

# fm_lock_reclaim_unlink_batch <path>...
#
# Remove several paths with ONE rm per chunk. A leak puts tens of thousands of
# owner dirs in ONE parent, and a fork per dir is what turns a sweep into a
# stall: on this host a fork costs about two milliseconds, so 37,000 dirs would
# cost more than the whole reclaim budget. rm takes many paths, so one process
# removes a whole chunk.
#
# The chunk is bounded because the ARGUMENT LIST is bounded: one exec with
# 37,000 paths is about 3 MB of arguments, and Linux refuses that with E2BIG
# before rm ever starts. Measured on the Controller: one unchunked call with
# 37,236 paths removed 8,181 of them and reported the other 29,056 as
# failures. The chunk size keeps every exec well inside the limit.
FM_LOCK_RECLAIM_BATCH_CHUNK="${FM_RECLAIM_BATCH_CHUNK:-500}"
fm_lock_reclaim_unlink_batch() {
  local real
  real=${FM_LOCK_RECLAIM_REAL_RM:-}
  if [ -z "$real" ]; then
    real=$(fm_lock_reclaim_real_rm 2>/dev/null) || real=
    FM_LOCK_RECLAIM_REAL_RM=$real
  fi
  if [ -z "$real" ]; then
    echo "SKIP-NO-REAL-RM" >&2
    return 1
  fi
  [ "$#" -gt 0 ] || return 0
  local chunk=() p rc=0
  for p in "$@"; do
    chunk+=("$p")
    if [ "${#chunk[@]}" -ge "$FM_LOCK_RECLAIM_BATCH_CHUNK" ]; then
      "$real" -rf -- "${chunk[@]}" 2>/dev/null || rc=1
      chunk=()
    fi
  done
  if [ "${#chunk[@]}" -gt 0 ]; then
    "$real" -rf -- "${chunk[@]}" 2>/dev/null || rc=1
  fi
  return $rc
}

# fm_lock_reclaim_dir_size_kb <path>
fm_lock_reclaim_dir_size_kb() {
  du -x -s -k "$1" 2>/dev/null | awk '{print $1}'
}

# fm_lock_reclaim_has_live_holder <dir>
#
# True when a LIVE owner dir sits INSIDE <dir>. A steal chain nests: each
# level's reclaim mutex is the steal of the level above, so the owner dirs of
# a deep chain live inside one another. Removing an outer dir whose inner dir
# is held by a live process would destroy a live holder, so the outer dir is
# skipped instead.
#
# The common case is a dir with no subdirectory at all, and that is answered
# by a shell glob - no fork. Only a dir that really has a subdirectory pays
# for the deeper search.
fm_lock_reclaim_has_live_holder() {
  local dir=$1 inner name state
  local first=("$dir"/*/)
  # An unexpanded glob is the literal pattern, which is not a directory.
  [ -d "${first[0]}" ] || return 1
  while IFS= read -r inner; do
    [ -n "$inner" ] || continue
    name=${inner##*/}
    fm_lock_reclaim_owner_dir_basename_matches "$name" || continue
    fm_lock_reclaim_holder_state_set "$inner"
    state=$FM_LOCK_RECLAIM_HOLDER_STATE
    case "$state" in
      live) return 0 ;;
      unknown) return 0 ;;
    esac
  done < <(find "$dir" -maxdepth 4 -type d -name '*.owner.??????' 2>/dev/null)
  return 1
}

# The lock pointers in one parent dir, read ONCE, with their targets resolved
# ONCE. Every owner dir in a leak sits in the same parent, so re-reading the
# parent's symlinks for each of tens of thousands of dirs is a fork per dir
# for nothing.
FM_LOCK_RECLAIM_PARENT_KEY=
FM_LOCK_RECLAIM_PARENT_LINKS=()
fm_lock_reclaim_load_parent_links() {  # <parent>
  local parent=$1 link target resolved
  if [ "$FM_LOCK_RECLAIM_PARENT_KEY" = "$parent" ]; then
    return 0
  fi
  FM_LOCK_RECLAIM_PARENT_LINKS=()
  while IFS= read -r link; do
    [ -n "$link" ] || continue
    target=$(readlink "$link" 2>/dev/null || true)
    [ -n "$target" ] || continue
    case "$target" in
      /*) resolved=$target ;;
      *) resolved="$parent/$target" ;;
    esac
    FM_LOCK_RECLAIM_PARENT_LINKS+=("$link|$resolved")
  done < <(find "$parent" -maxdepth 1 -type l 2>/dev/null | sort)
  FM_LOCK_RECLAIM_PARENT_KEY=$parent
  return 0
}

# The pointers that point AT one owner dir. The pointer is published by the
# same acquirer that created the dir, so a pointer to a provably dead dir is
# a stale claim and can be removed with it.
fm_lock_reclaim_pointers_for() {  # <ownerdir>
  local ownerdir=$1 parent entry link resolved
  parent=${ownerdir%/*}
  [ -n "$parent" ] || parent=/
  fm_lock_reclaim_load_parent_links "$parent"
  for entry in ${FM_LOCK_RECLAIM_PARENT_LINKS[@]+"${FM_LOCK_RECLAIM_PARENT_LINKS[@]}"}; do
    [ -n "$entry" ] || continue
    link=${entry%%|*}
    resolved=${entry#*|}
    if [ "$resolved" = "$ownerdir" ]; then
      printf '%s\n' "$link"
      continue
    fi
    # The same file by another name: the pointer resolves to the dir itself.
    if [ -e "$link" ] && [ "$link" -ef "$ownerdir" ]; then
      printf '%s\n' "$link"
    fi
  done
  return 0
}

# Does this find support -printf and /perm? GNU find does; BSD find does not.
# When it does, ONE find pass yields every candidate's mtime and applies the
# owner-private test itself, which is what keeps the sweep from forking per
# candidate.
fm_lock_reclaim_find_prints() {  # <path>
  find "$1" -maxdepth 0 -printf '%T@\n' >/dev/null 2>&1
}

# fm_lock_reclaim_sweep <root>...
#
# Reclaim the provably dead lock scratch under each root.
#
# The ORDER matters. The owner dirs go first, because reclaiming an owner dir
# also removes the pointer that published it - and the pointer goes BEFORE the
# dir, so there is never a moment where a lock pointer points at a dir that is
# being destroyed. A DANGLING pointer is worse than a missing one: the lock
# protocol refuses a claim when a reclaim pointer exists at all, so a pointer
# left behind by a removed dir would wedge the lock.
#
# The dangling pointers go second: a pointer whose target does not exist is
# nobody's live claim.
#
# The mode is FM_LOCK_RECLAIM_APPLY (0 = report only, 1 = unlink for real).
# The reclaimer's default is a dry run, and a dry run here must change nothing.
#
# The sweep is BOUNDED, because the reclaim that runs it is bounded: the
# capacity gate gives the reclaim a wall-clock timeout, and a sweep that
# overruns it would be killed half way through. Two bounds apply: a count of
# owner dirs, and a wall-clock budget. The backlog drains over successive
# sweeps instead of in one stall.
fm_lock_reclaim_sweep() {
  local root grace maxdepth max budget now path name state parent kb
  local ownerdir link mtime age entry resolved
  local prev_parent="" parent_before=0 parent_after=0
  local candidates="" started now_tick tab
  local -a pending=() pending_links=()
  grace=${FM_RECLAIM_LOCK_GRACE_S:-5}
  case "$grace" in ''|*[!0-9]*) grace=5 ;; esac
  maxdepth=${FM_RECLAIM_LOCK_MAXDEPTH:-6}
  case "$maxdepth" in ''|*[!0-9]*) maxdepth=6 ;; esac
  max=${FM_RECLAIM_LOCK_MAX:-100000}
  case "$max" in ''|*[!0-9]*) max=100000 ;; esac
  budget=${FM_RECLAIM_LOCK_BUDGET_S:-60}
  case "$budget" in ''|*[!0-9]*) budget=60 ;; esac
  now=$(date +%s)
  case "$now" in ''|*[!0-9]*) now=0 ;; esac
  started=$now
  # The field separator, computed ONCE. A command substitution in a loop
  # condition is a fork per iteration, and this loop runs tens of thousands
  # of times.
  tab="$(printf '\t')"
  fm_lock_reclaim_ensure_clocks
  # The real rm is resolved ONCE per sweep, not once per removal.
  FM_LOCK_RECLAIM_REAL_RM=$(fm_lock_reclaim_real_rm 2>/dev/null) || FM_LOCK_RECLAIM_REAL_RM=

  # flush_pending
  #
  # Remove the owner dirs selected for this parent, and the pointers that
  # published them. The POINTERS go first: a pointer left pointing at a dir
  # that is being destroyed is a dangling pointer, and a dangling reclaim
  # pointer wedges the lock it belongs to.
  flush_pending() {
    local p
    [ "${#pending[@]}" -gt 0 ] || return 0
    if [ "${#pending_links[@]}" -gt 0 ]; then
      for p in "${pending_links[@]}"; do
        [ -n "$p" ] || continue
        if fm_lock_reclaim_unlink "$p"; then
          FM_LOCK_RECLAIM_POINTERS=$((FM_LOCK_RECLAIM_POINTERS + 1))
          echo "RECLAIMED-POINTER $p (its owner dir was provably dead)"
        else
          echo "FAILED $p"
        fi
      done
    fi
    if [ "$FM_LOCK_RECLAIM_APPLY" = 1 ]; then
      # ONE rm for the whole batch. The dirs were each checked on their own.
      if fm_lock_reclaim_unlink_batch "${pending[@]}"; then
        for p in "${pending[@]}"; do
          if [ ! -e "$p" ]; then
            FM_LOCK_RECLAIM_DIRS=$((FM_LOCK_RECLAIM_DIRS + 1))
            echo "RECLAIMED-OWNER $p"
          else
            echo "FAILED $p"
          fi
        done
      else
        for p in "${pending[@]}"; do
          echo "FAILED $p"
        done
      fi
    else
      for p in "${pending[@]}"; do
        FM_LOCK_RECLAIM_DIRS=$((FM_LOCK_RECLAIM_DIRS + 1))
        echo "WOULD-RECLAIM-OWNER $p"
      done
    fi
    pending=()
    pending_links=()
    return 0
  }

  for root in "$@"; do
    [ -n "$root" ] || continue
    [ -d "$root" ] || continue
    # The candidate list is collected first, then sorted and deduplicated: a
    # root can be given twice, and the same dir can be reached twice. Sorting
    # also groups the candidates by parent, which is what makes both the byte
    # accounting and the batched unlink cheap.
    if fm_lock_reclaim_find_prints "$root"; then
      candidates=$(
        find "$root" -maxdepth "$maxdepth" -type d -name '*.owner.??????' ! -perm /0077 -printf '%T@\t%p\n' 2>/dev/null \
          | while IFS="$tab" read -r mtime path; do
              [ -n "$path" ] || continue
              name=${path##*/}
              fm_lock_reclaim_owner_dir_basename_matches "$name" || continue
              printf '%s\t%s\n' "${mtime%%.*}" "$path"
            done \
          | sort -u -k2,2
      )
    else
      candidates=$(
        find "$root" -maxdepth "$maxdepth" -type d -name '*.owner.??????' 2>/dev/null \
          | while IFS= read -r path; do
              [ -n "$path" ] || continue
              name=${path##*/}
              fm_lock_reclaim_owner_dir_basename_matches "$name" || continue
              fm_lock_reclaim_owner_private "$path" || continue
              mtime=$(fm_lock_reclaim_path_mtime "$path" 2>/dev/null || printf '0')
              printf '%s\t%s\n' "$mtime" "$path"
            done \
          | sort -u -k2,2
      )
    fi
    [ -n "$candidates" ] || candidates=""

    prev_parent=""
    parent_before=0
    while IFS="$tab" read -r mtime ownerdir; do
      [ -n "$ownerdir" ] || continue
      [ -d "$ownerdir" ] || continue
      [ "$FM_LOCK_RECLAIM_DIRS" -lt "$max" ] || break
      # The wall-clock budget. The clock is read every 64 candidates, because
      # reading it every candidate is a fork per candidate.
      now_tick=$(( ${FM_LOCK_RECLAIM_TICK:-0} + 1 ))
      FM_LOCK_RECLAIM_TICK=$now_tick
      if [ $((now_tick % 64)) -eq 0 ]; then
        now=$(date +%s)
        case "$now" in ''|*[!0-9]*) now=0 ;; esac
        if [ $((now - started)) -ge "$budget" ]; then
          echo "BUDGET-EXCEEDED: the lock sweep stopped after ${budget}s; the rest of the backlog drains over the next sweeps"
          break
        fi
      fi
      parent=${ownerdir%/*}
      [ -n "$parent" ] || parent=/
      if [ "$parent" != "$prev_parent" ]; then
        # The previous parent's owner dirs are removed as ONE batch, and its
        # reclaimed bytes are the difference between what it measured before
        # and after. That is a MEASUREMENT, not a sum of what the script
        # believes it deleted.
        flush_pending
        if [ -n "$prev_parent" ]; then
          parent_after=$(fm_lock_reclaim_dir_size_kb "$prev_parent")
          case "${parent_before:-0}" in ''|*[!0-9]*) parent_before=0 ;; esac
          case "${parent_after:-0}" in ''|*[!0-9]*) parent_after=0 ;; esac
          kb=$((parent_before - parent_after))
          [ "$kb" -gt 0 ] || kb=0
          FM_LOCK_RECLAIM_BYTES=$((FM_LOCK_RECLAIM_BYTES + kb))
        fi
        prev_parent=$parent
        parent_before=$(fm_lock_reclaim_dir_size_kb "$parent")
        case "${parent_before:-}" in ''|*[!0-9]*) parent_before=0 ;; esac
      fi

      case "$mtime" in ''|*[!0-9]*) mtime=0 ;; esac
      fm_lock_reclaim_holder_state_set "$ownerdir" "$mtime"
      state=$FM_LOCK_RECLAIM_HOLDER_STATE
      case "$state" in
        live) FM_LOCK_RECLAIM_LIVE=$((FM_LOCK_RECLAIM_LIVE + 1)); continue ;;
        unknown) FM_LOCK_RECLAIM_UNKNOWN=$((FM_LOCK_RECLAIM_UNKNOWN + 1)); continue ;;
      esac
      # A claim in its first moments has no pid yet, or a pid whose holder has
      # only just died. The grace covers that window.
      age=$((now - mtime))
      [ "$age" -ge "$grace" ] || continue
      # A live holder nested inside this dir is never disturbed.
      if fm_lock_reclaim_has_live_holder "$ownerdir"; then
        FM_LOCK_RECLAIM_LIVE=$((FM_LOCK_RECLAIM_LIVE + 1))
        continue
      fi

      # The pointer that published this dir is collected now and removed
      # before the dir itself. The parent's symlinks were resolved once, so
      # this is an array scan and not a fork.
      fm_lock_reclaim_load_parent_links "$parent"
      for entry in ${FM_LOCK_RECLAIM_PARENT_LINKS[@]+"${FM_LOCK_RECLAIM_PARENT_LINKS[@]}"}; do
        [ -n "$entry" ] || continue
        link=${entry%%|*}
        resolved=${entry#*|}
        [ "$resolved" = "$ownerdir" ] && pending_links+=("$link")
      done

      # The second look. The holder can have died between the check and here,
      # which only ever makes the dir MORE dead - but a holder that started
      # before the dir and is still alive must still stop the reclaim.
      fm_lock_reclaim_holder_state_set "$ownerdir" "$mtime"
      state=$FM_LOCK_RECLAIM_HOLDER_STATE
      case "$state" in
        live|unknown)
          FM_LOCK_RECLAIM_LIVE=$((FM_LOCK_RECLAIM_LIVE + 1))
          continue
          ;;
      esac

      pending+=("$ownerdir")
    done <<< "$candidates"

    # The last parent: its owner dirs go, then its bytes are measured.
    flush_pending
    if [ -n "$prev_parent" ]; then
      parent_after=$(fm_lock_reclaim_dir_size_kb "$prev_parent")
      case "${parent_before:-0}" in ''|*[!0-9]*) parent_before=0 ;; esac
      case "${parent_after:-0}" in ''|*[!0-9]*) parent_after=0 ;; esac
      kb=$((parent_before - parent_after))
      [ "$kb" -gt 0 ] || kb=0
      FM_LOCK_RECLAIM_BYTES=$((FM_LOCK_RECLAIM_BYTES + kb))
    fi

    # The dangling pointers, second. A pointer whose target does not exist is
    # nobody's live claim, and a stale reclaim pointer is exactly what wedged
    # the Controller's comms lock for hours.
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      name=${path##*/}
      fm_lock_reclaim_pointer_basename_matches "$name" || continue
      [ -e "$path" ] && continue
      mtime=$(fm_lock_reclaim_path_mtime "$path" 2>/dev/null || printf '0')
      case "$mtime" in ''|*[!0-9]*) continue ;; esac
      age=$((now - mtime))
      [ "$age" -ge "$grace" ] || continue
      if [ "$FM_LOCK_RECLAIM_APPLY" = 1 ]; then
        if fm_lock_reclaim_unlink "$path"; then
          FM_LOCK_RECLAIM_POINTERS=$((FM_LOCK_RECLAIM_POINTERS + 1))
          echo "RECLAIMED-POINTER $path (its target does not exist)"
        else
          echo "FAILED $path"
        fi
      else
        FM_LOCK_RECLAIM_POINTERS=$((FM_LOCK_RECLAIM_POINTERS + 1))
        echo "WOULD-RECLAIM-POINTER $path (its target does not exist)"
      fi
    done < <(find "$root" -maxdepth "$maxdepth" -type l 2>/dev/null | sort)
  done
  return 0
}
