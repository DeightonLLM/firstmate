#!/usr/bin/env bash
# fm-scratch-lib.sh - the ONE documented way to purge own-scratch in this repo.
#
# WHY THIS FILE EXISTS (2026-10-21, lane m3.1f-firstmate-scratchfix):
#   On this host /root/.minimax/shims/rm shadows /usr/bin/rm on an agent's
#   PATH. It is a MANAGED recoverable-delete shim: it runs
#   `mavis-trash --rm-compatible "$@"`, so every delete becomes a MOVE into
#   ~/.local/share/Trash. That is CORRECT for fleet or user MATERIAL, which
#   must stay recoverable, and the shim is managed by the runtime - it is not
#   ours to edit or remove.
#
#   It is a LEAK for scratch that a program created itself: a temp dir it just
#   made, a test tree it just built, a lock owner dir it just created. Such a
#   tree is regenerable by construction, so there is nothing to recover - and
#   because the trash lives on the SAME filesystem, the move frees ZERO bytes.
#
#   Measured on this host: the trash held 14.1 GB across 20,274 entries while
#   `df` stayed at 97% with 2.8 GB free. Purging it with /usr/bin/rm dropped the
#   filesystem to 78% with 16 GB free in one step.
#
# WHAT THIS HELPER IS
#   A deliberate, guarded REAL UNLINK for own-scratch only. It:
#     1. resolves the real rm by ABSOLUTE path, never by PATH lookup, so the
#        recoverable-delete shim can never intercept it;
#     2. refuses any path that does not look like scratch;
#     3. refuses protected surfaces unconditionally.
#
# WHAT THIS HELPER IS NOT
#   It is NOT a general-purpose delete and it must never become one. Every
#   caller states a path the caller itself created in the same run. Material
#   deletion stays on the recoverable path (plain `rm` on PATH, or mavis-trash
#   directly) and is NOT routed through here.
#
# USAGE
#   . bin/fm-scratch-lib.sh
#   fm_purge_scratch "$scratch_dir" ["$another_scratch" ...]
#
# EXIT STATUS
#   0 when every requested path was purged or was already absent.
#   1 when any path was refused or could not be unlinked (diagnostic on stderr).

# Idempotent guard: several libraries and test helpers source this file, and a
# test may source it directly as well as through tests/lib.sh.
if [ -n "${FM_SCRATCH_LIB_SOURCED:-}" ]; then
  # Sourced again: the functions are already defined. The `return` is for the
  # sourced case and the `exit` for the executed case.
  # shellcheck disable=SC2317
  return 0 2>/dev/null || true
fi
FM_SCRATCH_LIB_SOURCED=1

# --- the real rm ------------------------------------------------------------
#
# Resolved by ABSOLUTE path only. A PATH lookup would find the shim, which is
# the whole defect this file exists to route around. The shim is rejected
# explicitly as well, so a mis-set FM_SCRATCH_REAL_RM cannot reintroduce it.
fm_scratch_real_rm() {
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

# --- protected surfaces -----------------------------------------------------
#
# Refused unconditionally. These are the surfaces whose accidental deletion
# took down hd2.ai and dubzai.co. A guard that runs unattended is the most
# dangerous thing on a host, so this denylist is enforced, not advisory.
fm_scratch_protected_refuse() {
  case "$1" in
    /opt/1panel*|/var/lib/docker*|/root/backups*|/root/backup/*|/srv/*|\
    /etc/letsencrypt*|/root/.secrets*|/opt/core-distro*|/root/core-distro.com*|\
    /root/mattermost-dubzai*|/root/docker-jitsi-meet*|/root/secret-quarantine*|\
    /root/.quarantine*|/var/www/*|/etc/nginx*|/boot*)
      return 0 ;;   # 0 == refused
    *) return 1 ;;
  esac
}

# --- scratch shapes ---------------------------------------------------------
#
# A path is eligible for a real unlink only if it matches one of these. They
# cover exactly what this repo and the host's own tooling create for itself:
#
#   T1  a path inside a system temp root (/tmp, /var/tmp, $TMPDIR). This is
#       the universal scratch convention, so it is accepted wholesale.
#   T2  a lock OWNER DIR: basename matches *.lock.owner.??????
#   T3  a file INSIDE such an owner dir: parent basename matches
#       *.lock.owner.?????? (the pid / fm-home / pid-identity / watcher-path
#       files a lock owner writes)
#   T4  a lock POINTER: a symbolic link whose basename matches *.lock.
#       Unlinking a symlink removes only the pointer, never its target, so
#       this shape cannot destroy material even in principle.
#   T5  a known lock-internal file inside a hidden lock dir: basename is one
#       of pid / fm-home / pid-identity / watcher-path AND the parent
#       basename matches .*.lock (the legacy real-directory lock layout).
#   T6  a mktemp entry DIRECTLY inside a root the caller declared with
#       --root: the basename must look like a mktemp suffix - exactly six
#       characters from [A-Za-z0-9] - or be one of the two explicit scratch
#       names (*.claim, .*.output), and the path must be a direct child of
#       that root.
#
# Two further guards keep that shape away from material:
#   * a mktemp-suffixed entry must be OWNER-PRIVATE (mode 0700 for a
#     directory, 0600 for a file), which is mktemp's own guarantee. Tracked
#     repo content is never private: .agents, .claude, .github and .lavish
#     are all 0755 at the repo root, and every ordinary tracked file is 0644;
#   * the path must not be git-TRACKED material, whatever it is named.
#     The direct-child rule keeps a broad declared root from reaching deep
#     tracked material.
#
# The mktemp suffix is random alnum, so it carries no digit about a third of
# the time (mktemp -d yields suffixes such as "ESyxyF" routinely). An earlier
# version of this rule demanded a digit, which made the cleanup FLAKY: roughly
# one run in three left its scratch behind instead of unlinking it.
#
# Anything else is refused. In particular a repo state file, a fleet home, a
# user worktree and every other live runtime record is refused by default.
fm_scratch_in_temp_root() {
  local path=$1 root
  for root in "${TMPDIR:-}" /tmp /var/tmp; do
    [ -n "$root" ] || continue
    case "$root" in /) continue ;; esac
    case "$path" in
      "$root"/*) return 0 ;;
    esac
  done
  return 1
}

# A basename that a declared scratch root may hold directly. Three shapes:
#   - *.claim      - a procevent claim record;
#   - .*.output    - a procevent staged output;
#   - a mktemp suffix: exactly six characters from [A-Za-z0-9].
#
# The kind is reported in FM_SCRATCH_BASENAME_KIND: "explicit" for the two
# named shapes, "mktemp" for the suffix shape. The owner-private guard is
# applied to the "mktemp" kind only - the two named shapes are recognised by
# name and by the git-tracked guard below.
FM_SCRATCH_BASENAME_KIND=""
fm_scratch_declared_basename() {
  local base=$1 suffix
  FM_SCRATCH_BASENAME_KIND=""
  case "$base" in
    *.claim) FM_SCRATCH_BASENAME_KIND=explicit; return 0 ;;
    .*.output) FM_SCRATCH_BASENAME_KIND=explicit; return 0 ;;
  esac
  case "$base" in
    *.*) suffix=${base##*.} ;;
    *) return 1 ;;
  esac
  case "$suffix" in
    ''|*[!A-Za-z0-9]*) return 1 ;;
  esac
  [ "${#suffix}" -eq 6 ] || return 1
  FM_SCRATCH_BASENAME_KIND=mktemp
  return 0
}

# --- owner-private mode -----------------------------------------------------
#
# mktemp creates what it creates private: 0700 for a directory, 0600 for a
# file. That is the real invariant behind "this entry was made by a program
# for itself", and it is what separates a real mktemp entry from tracked repo
# content such as .agents, .claude, .github and .lavish (all 0755) or an
# ordinary tracked file (0644).
#
# 0 when the entry grants nothing to group or other, 1 otherwise.
fm_scratch_owner_private() {
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

# --- git-tracked material ---------------------------------------------------
#
# A tracked path is never scratch, whatever it is named. This guard refuses a
# path that git can PROVE is tracked. It is consulted for every shape except
# T1: a system temp root is scratch by convention, and a tracked path inside
# one is vanishingly rare.
#
# Being unable to prove trackedness (no git, not a work tree, a broken index)
# is not proof of safety, so the owner-private guard stays mandatory for every
# mktemp-shaped entry.
#
# The resolved work tree is cached per parent directory: the lock churn purges
# repeatedly from the same directory, and the check costs two short-lived
# processes.
FM_SCRATCH_GIT_DIR=""
FM_SCRATCH_GIT_TOP=""

fm_scratch_git_toplevel() {
  local dir=$1 top
  if [ -n "$FM_SCRATCH_GIT_DIR" ] && [ "$FM_SCRATCH_GIT_DIR" = "$dir" ]; then
    [ -n "$FM_SCRATCH_GIT_TOP" ] || return 1
    printf '%s\n' "$FM_SCRATCH_GIT_TOP"
    return 0
  fi
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || top=""
  FM_SCRATCH_GIT_DIR="$dir"
  FM_SCRATCH_GIT_TOP="$top"
  [ -n "$top" ] || return 1
  printf '%s\n' "$top"
  return 0
}

# 0 (refuse) when git can prove the path is tracked material, 1 otherwise.
fm_scratch_git_tracked_refuse() {
  local path=$1 dir top rel out
  command -v git >/dev/null 2>&1 || return 1
  [ -e "$path" ] || return 1
  dir=${path%/*}
  [ -n "$dir" ] || dir=/
  top=$(fm_scratch_git_toplevel "$dir") || return 1
  rel=${path#"$top"/}
  if [ "$rel" = "$path" ]; then
    # The path is spelled differently from the work tree root (a symlinked
    # parent, for instance). git understands an absolute pathspec.
    out=$(git -C "$top" ls-files -- "$path" 2>/dev/null) || out=""
  else
    out=$(git -C "$top" ls-files -- "$rel" 2>/dev/null) || out=""
  fi
  [ -n "$out" ] && return 0
  return 1
}

# fm_scratch_shape_ok <path> <declared-root>...
# The declared roots are the roots passed with --root on this call.
fm_scratch_shape_ok() {
  local path=$1; shift
  local base parent root
  base=${path##*/}
  parent=${path%/*}
  [ -n "$parent" ] || parent=/
  parent=${parent##*/}
  [ -n "$parent" ] || parent=/

  # T1 - inside a system temp root.
  fm_scratch_in_temp_root "$path" && return 0

  # Tracked material is never scratch, whatever it is named. Consulted for
  # every shape below T1.
  fm_scratch_git_tracked_refuse "$path" && return 1

  # T2 - a lock owner dir.
  case "$base" in *.lock.owner.??????) return 0 ;; esac

  # T3 - a file inside a lock owner dir.
  case "$parent" in *.lock.owner.??????) return 0 ;; esac

  # T4 - a lock pointer (symlink). Removing it removes only the pointer.
  if [ -L "$path" ]; then
    case "$base" in *.lock) return 0 ;; esac
  fi

  # T5 - a known lock-internal file inside a hidden lock dir.
  case "$base" in
    pid|fm-home|pid-identity|watcher-path)
      case "$parent" in
        .*.lock) return 0 ;;
      esac
      ;;
  esac

  # T6 - a scratch entry directly inside a declared root.
  fm_scratch_declared_basename "$base" || return 1
  if [ "$FM_SCRATCH_BASENAME_KIND" = "mktemp" ]; then
    # mktemp's own guarantee: the entry is private to its owner. Tracked
    # repo content never is, so this is what protects .agents, .claude,
    # .github and .lavish at the repo root. A path that is already gone is
    # left to the "already absent" handling in fm_purge_scratch.
    if [ -e "$path" ] || [ -L "$path" ]; then
      fm_scratch_owner_private "$path" || return 1
    fi
  fi
  for root in "$@"; do
    [ -n "$root" ] || continue
    case "$root" in /) continue ;; esac
    # Direct child of the declared root only.
    case "$path" in
      "$root"/*)
        case "${path#"$root"/}" in
          */*) continue ;;
        esac
        return 0
        ;;
    esac
  done

  return 1
}

# --- the purge --------------------------------------------------------------
#
# fm_purge_scratch [--root <dir>]... <path>...
#
# Real unlink of own-scratch. Refuses anything that is not scratch-shaped or
# that lands on a protected surface, and says so on stderr rather than
# silently doing nothing.
#
# --root declares a directory the caller knows to be a scratch root. It only
# widens rule T6 (a mktemp entry directly inside that root); it never widens
# the protected-surface denylist and never bypasses the shape rules.
fm_purge_scratch() {
  local rc=0 path real
  local -a roots=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --root)
        shift
        if [ "$#" -gt 0 ]; then
          roots+=("$1")
          shift
        fi
        ;;
      --root=*)
        roots+=("${1#--root=}")
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done
  if [ "$#" -eq 0 ]; then
    return 0
  fi
  if ! real=$(fm_scratch_real_rm); then
    printf 'fm_purge_scratch: no real rm binary available (looked for /usr/bin/rm, /bin/rm)\n' >&2
    return 1
  fi
  for path in "$@"; do
    [ -n "$path" ] || continue

    # An absolute path with at least two components, no trailing slash and no
    # '..' component. This closes the classic foot-guns before any rm runs.
    case "$path" in
      /*) ;;
      *)
        printf 'fm_purge_scratch: refusing non-absolute path: %s\n' "$path" >&2
        rc=1; continue ;;
    esac
    case "$path" in
      */)
        printf 'fm_purge_scratch: refusing path with a trailing slash: %s\n' "$path" >&2
        rc=1; continue ;;
    esac
    case "/$path/" in
      */../*)
        printf 'fm_purge_scratch: refusing path with a .. component: %s\n' "$path" >&2
        rc=1; continue ;;
    esac
    # At least two path components: refuse /, /tmp and any other top level.
    case "${path#/}" in
      */*) ;;
      *)
        printf 'fm_purge_scratch: refusing a top-level path: %s\n' "$path" >&2
        rc=1; continue ;;
    esac

    if fm_scratch_protected_refuse "$path"; then
      printf 'fm_purge_scratch: refusing protected surface: %s\n' "$path" >&2
      rc=1; continue
    fi

    if ! fm_scratch_shape_ok "$path" ${roots[@]+"${roots[@]}"}; then
      printf 'fm_purge_scratch: refusing non-scratch path: %s\n' "$path" >&2
      rc=1; continue
    fi

    # Already gone is success, not an error.
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
      continue
    fi

    # A symlink is unlinked, never followed: `rm -f` on a symlink removes the
    # pointer only, whatever it points at.
    if [ -L "$path" ] || [ ! -d "$path" ]; then
      if ! "$real" -f -- "$path"; then
        printf 'fm_purge_scratch: failed to unlink: %s\n' "$path" >&2
        rc=1
      fi
    else
      if ! "$real" -rf -- "$path"; then
        printf 'fm_purge_scratch: failed to purge: %s\n' "$path" >&2
        rc=1
      fi
    fi
  done
  return "$rc"
}
