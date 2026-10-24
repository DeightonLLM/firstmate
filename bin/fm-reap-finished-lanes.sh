#!/usr/bin/env bash
# fm-reap-finished-lanes.sh - return a FINISHED lane's treehouse slot to the pool.
#
# WHY THIS EXISTS.
#
# The fleet ceiling is 12 concurrent agents (6 MiniMax + 6 Luna), max 6 per
# provider.  The treehouse pool on this host holds worktree slots against a
# `max_trees` ceiling.  When a lane finishes, its slot is NOT returned
# automatically, so the pool fills up with slots nobody will ever use again and
# `treehouse get` eventually refuses to hand out a worktree - which is exactly
# what stopped the twelfth lane on 2026-10-23.  Nine finished slots were
# reclaimed BY HAND that day.  This script is the thing that does it
# automatically, and it does it safely.
#
# THE SAFETY CONTRACT.  This script is not allowed to guess.  A slot is a
# reclaim candidate only when TWO INDEPENDENT FACTS both hold:
#
#   1. the lane's task log shows a TERMINAL VERB, and
#   2. the pane DEMONSTRABLY no longer runs that lane's worker.
#
# Unknown fails closed.  If either fact cannot be established the slot is NOT
# reclaimed, and the reason is reported.  A lane whose ledger state is BLOCKED,
# or whose log says needs-decision / blocked, is LIVE WORK and is never a
# candidate.  Every reclaim is preserved first - a verified git bundle plus a
# verified tar of the slot's untracked and ignored files - and only then is the
# slot returned.
#
# WHAT IT DELIBERATELY DOES NOT DO.
#   - It never raises a pool ceiling.  The fix is to reclaim, not to enlarge.
#   - It never runs `treehouse prune --yes` on a slot it has not proven safe.
#   - It never kills a process with `pkill -f`, and it never closes a pane.
#     It returns SLOTS.  Closing a pane is a separate act and is out of scope.
#   - It never publishes anything: no push, no board write, no ledger write.
#   - It never uses `treehouse return --force`.  A slot that cannot be made
#     clean without discarding bytes is left alone and reported.
#
# THE TWO FACTS, IN DETAIL.
#
# Fact 1 - the terminal verb.
#   The real terminal lines in this fleet are `done: ...` and
#   `resolved [key=...]: ...`.  The verb is read with the house's own grammar
#   (status_line_verb in bin/fm-classify-lib.sh), which strips an optional
#   ISO-8601 timestamp prefix and an optional `[key=...]` token and returns the
#   LEADING VERB.  An earlier reclaim script stripped the verb off before
#   matching it, so finished lanes looked unfinished; this script matches the
#   verb as it actually appears.
#
# Fact 2 - the pane.
#   The lane's recorded pane is asked whether it still runs that lane's
#   harness.  The oracle has three answers: alive (0), dead (1), unknown (2).
#   Only a positive DEAD answer licenses a reclaim.  This mirrors
#   fm_pane_foreground_harness_state in bin/fm-always-four.sh, which owns the
#   same 0/1/2 contract for the scheduler.
#
# PRESERVATION, BEFORE EVERY RECLAIM.
#   1. `git bundle create --all` for the slot, verified with `git bundle verify`.
#   2. A focused bundle for every branch that holds commits not in the base
#      ref, verified, so rule 5 ("never reclaim a slot whose branch holds
#      unmerged commits unless the bundle that carries them was created and
#      verified first") is satisfied by evidence and not by hope.
#   3. A tar of the slot's untracked + ignored file set, directories included.
#      The tar is VERIFIED by comparing the number of listed paths with the
#      number of archive entries: they MUST match.  This check is built in because `tar -czf out -C dir
#      --null -T list` silently produces an EMPTY archive when `-C` follows
#      `-T`, because tar's options are positional.  `-C` is therefore always
#      given BEFORE `-T`, and the entry-count comparison is a hard gate.
#   4. A binary patch of the slot's tracked modifications.
#   Nothing is deleted.  Untracked and ignored files are MOVED out of the slot
#   into the preservation directory, never removed.
#
# THE DRY RUN WRITES NOTHING.
#   The default mode is a dry run and "dry run" means exactly that: the run
#   creates no file, changes no file and leaves no state behind.  No bundle, no
#   tar, no patch, no file list, no marker, no lock file, no state directory
#   change.  It only READS: the lane records, the task logs, the pool
#   inventory and the slot's git state.
#   What it WOULD preserve is computed and REPORTED - the file count, the
#   archive entry count, the payload bytes, the branches that hold unmerged
#   commits - so the dry run is as useful as the real thing.  A dry run that
#   reports nothing is useless, and a dry run that writes something is a lie.
#   So it computes, and it writes nothing.
#
# USAGE.
#   fm-reap-finished-lanes.sh                    dry run: report, change nothing
#   fm-reap-finished-lanes.sh --apply            reclaim the proven-safe slots
#   fm-reap-finished-lanes.sh --pool <dir>       operate on another pool
#   fm-reap-finished-lanes.sh --json <file>      write the machine report
#   fm-reap-finished-lanes.sh --help
#
# ENVIRONMENT OVERRIDES (all optional; the test suite drives them).
#   FM_REAP_POOL          pool root to operate on
#   FM_REAP_STATE         state directory holding <task>.status and <lane>.meta
#   FM_REAP_LEDGER        the lane ledger TSV
#   FM_REAP_PRESERVE_DIR  where preservation artifacts are written
#   FM_REAP_TREEHOUSE     the treehouse binary
#   FM_REAP_PANE_PROBE    a probe command: 0=alive 1=dead 2=unknown
#   FM_REAP_BASE_REF      the ref "merged" is measured against (origin/main)
#   FM_REAP_MAX_SECONDS   whole-run budget (default 900)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

FM_REAP_STATE="${FM_REAP_STATE:-$FM_ROOT/state}"
FM_REAP_LEDGER="${FM_REAP_LEDGER:-$FM_ROOT/ops/lane-ledger.tsv}"
FM_REAP_TREEHOUSE="${FM_REAP_TREEHOUSE:-treehouse}"
FM_REAP_BASE_REF="${FM_REAP_BASE_REF:-origin/main}"
FM_REAP_MAX_SECONDS="${FM_REAP_MAX_SECONDS:-900}"

APPLY=0
JSON_OUT=""
POOL=""

# --- output ------------------------------------------------------------------

say() { printf '%s\n' "$*"; }
note() { printf '  %s\n' "$*"; }

usage() {
  sed -n '2,/^set -uo/p' "$0" | sed -e 's/^# \{0,1\}//' -e '/^set -uo/d'
}

# --- small helpers -----------------------------------------------------------

# The house's own verb grammar owns what a status line's verb is.  Sourcing it
# keeps this script from inventing a second, drifting definition.
if [ -f "$FM_ROOT/bin/fm-classify-lib.sh" ]; then
  # shellcheck source=bin/fm-classify-lib.sh
  . "$FM_ROOT/bin/fm-classify-lib.sh"
fi

fm_reap_verb_of_line() {  # <line> -> leading verb
  local line=$1 stripped v
  [ -n "$line" ] || { printf ''; return; }
  if command -v status_line_verb >/dev/null 2>&1; then
    stripped=$(printf '%s' "$line" \
      | sed -e 's/^\[[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9:]\{8\}Z\] *//' \
            -e 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9:]\{8\}Z: *//')
    status_line_verb "$stripped"
    return
  fi
  v=${line%%:*}
  v=${v%%\[key=*}
  v=${v#"${v%%[![:space:]]*}"}
  v=${v%"${v##*[![:space:]]}"}
  printf '%s' "$v"
}

# The last non-blank line of a status log (the house's own reader).
fm_reap_last_status_line() {  # <file>
  local f=$1
  [ -e "$f" ] || return 0
  grep -v '^[[:space:]]*$' "$f" 2>/dev/null | tail -1
}

# The reclaim-terminal verbs.  `done` and `resolved [key=...]` are the real
# terminal lines in this fleet.  `blocked` and `needs-decision` are LIVE WORK and
# are never terminal for a reclaim.  `failed` is deliberately NOT a reclaim
# verb: a failed lane needs a decision, and unknown fails closed.
fm_reap_is_reclaim_terminal_verb() {  # <verb>
  case "$1" in
    done|resolved) return 0 ;;
  esac
  return 1
}

# The ledger state of a lane, if the ledger knows it.
fm_reap_ledger_state() {  # <lane-id> [task-id]
  local lane=$1 task=${2:-} f="$FM_REAP_LEDGER" state=""
  [ -f "$f" ] || return 0
  state=$(awk -F'\t' -v a="$lane" -v b="$task" \
    '$1 ~ /^lane_id/ {next}
     $1==a || (b!="" && $1==b) { if (s=="") { s=$2 } } END { print s }' "$f" 2>/dev/null)
  printf '%s' "$state"
}

# A report row, tab separated.
fm_reap_row() {  # <kind> <slot> <status> <lane> <verb> <reason>
  printf '%s\t%s\t%s\t%s\t%s\t%s' "$1" "$2" "$3" "$4" "$5" "$6"
}

# The reaper must be safe to run over and over.  Without a marker it would
# preserve - and that means bundle - the same finished lane on every run, and
# a 90 MB bundle per lane per run is not a reaper anybody would keep.  The
# marker says "this lane was already reclaimed", and it only suppresses the
# slot while the slot is FREE again: a slot that has been leased since is
# live work again, and the gates decide that, not the marker.
FM_REAP_MARKER_SUFFIX=".fm-reaped"

fm_reap_marker_path() {  # <task-id>
  printf '%s/%s%s' "$FM_REAP_STATE" "$1" "$FM_REAP_MARKER_SUFFIX"
}

fm_reap_marker_read() {  # <task-id>
  local f
  f=$(fm_reap_marker_path "$1")
  [ -f "$f" ] || return 1
  head -1 "$f" 2>/dev/null
}

fm_reap_marker_write() {  # <task-id> <slot-label> <status>
  local f
  f=$(fm_reap_marker_path "$1")
  printf '%s %s %s\n' "$2" "$3" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$f" 2>/dev/null
}

# --- pane liveness -----------------------------------------------------------

# fm_reap_pane_state <target> <harness> -> 0 alive, 1 dead, 2 unknown.
fm_reap_pane_state() {  # <target> <harness>
  local target=$1 harness=$2 session pane out rc

  if [ -n "${FM_REAP_PANE_PROBE:-}" ]; then
    "$FM_REAP_PANE_PROBE" "$target" "$harness" >/dev/null 2>&1
    rc=$?
    case "$rc" in
      0) return 0 ;;
      1) return 1 ;;
      *) return 2 ;;
    esac
  fi

  session=${target%%:*}
  pane=${target#*:}
  [ "$pane" != "$target" ] || return 2
  [ -n "$session" ] && [ -n "$pane" ] || return 2
  command -v herdr >/dev/null 2>&1 || return 2
  command -v jq >/dev/null 2>&1 || return 2

  out=$(HERDR_SESSION="$session" herdr pane process-info --pane "$pane" --session "$session" 2>/dev/null) || return 2
  printf '%s' "$out" | jq -e '.result.process_info.foreground_processes | type == "array"' >/dev/null 2>&1 || return 2
  if printf '%s' "$out" | jq -e --arg h "$harness" '
        [ (.result.process_info.foreground_processes // [])[]
          | select((( .name // "") | contains($h))
                   or (((.argv // []) | join(" ")) | contains($h))) ] | length > 0
      ' >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

fm_reap_pane_state_name() {
  case "$1" in
    0) printf 'alive' ;;
    1) printf 'dead' ;;
    *) printf 'unknown' ;;
  esac
}

# --- pool helpers ------------------------------------------------------------

fm_reap_pool_from_worktree() {  # <worktree-path> -> pool root
  printf '%s' "$1" | sed -E 's#^(.*)/[0-9]+/[^/]+$#\1#'
}

fm_reap_repo_root_from_worktree() {  # <worktree-path> -> the shared repo root
  local wt=$1 common
  common=$(git -C "$wt" rev-parse --git-common-dir 2>/dev/null) || return 1
  case "$common" in
    /*) : ;;
    *) common="$(cd "$wt" && cd "$(dirname "$common")" && pwd)" ;;
  esac
  [ -d "$common" ] || return 1
  printf '%s' "$(dirname "$common")"
}

# The lane record that owns a slot.  Several records can name the same worktree
# (a dispatcher seat record and the task's own record).  The task's own record
# wins, because that is the one whose task log carries the terminal verb.
# Prints "meta<TAB>task<TAB>window<TAB>harness"; returns 1 when no record names
# the slot.
fm_reap_lane_for_slot() {  # <worktree-path>
  local want=$1 f wt task win har best_meta="" best_task="" best_win="" best_har=""
  for f in "$FM_REAP_STATE"/*.meta; do
    [ -f "$f" ] || continue
    wt=$(grep '^worktree=' "$f" 2>/dev/null | cut -d= -f2-)
    [ "$wt" = "$want" ] || continue
    task=$(grep '^endpoint_task_id=' "$f" 2>/dev/null | cut -d= -f2-)
    win=$(grep '^window=' "$f" 2>/dev/null | cut -d= -f2-)
    har=$(grep '^harness=' "$f" 2>/dev/null | cut -d= -f2-)
    [ -n "$task" ] || task=$(basename "$f" .meta)
    # Prefer the record named after the task itself.
    if [ "$(basename "$f" .meta)" = "$task" ]; then
      best_meta=$f; best_task=$task; best_win=$win; best_har=$har
      break
    fi
    [ -n "$best_meta" ] || { best_meta=$f; best_task=$task; best_win=$win; best_har=$har; }
  done
  [ -n "$best_meta" ] || return 1
  printf '%s\t%s\t%s\t%s' "$best_meta" "$best_task" "$best_win" "$best_har"
}

# Every branch that could hold the lane's unmerged commits: the branch the slot
# has checked out, plus every branch whose name carries the lane's task id (the
# fleet's branch naming is fm/<task-id>).
fm_reap_lane_branches() {  # <worktree> <task-id>
  local wt=$1 task=$2 b
  {
    b=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$b" ] && [ "$b" != "HEAD" ]; then
      printf '%s\n' "$b"
    fi
    if [ -n "$task" ]; then
      git -C "$wt" for-each-ref --format='%(refname:short)' "refs/heads/" 2>/dev/null \
        | grep -F -- "$task" || true
    fi
  } | LC_ALL=C sort -u
}

# --- preservation ------------------------------------------------------------

fm_reap_nul_count() {  # <file> -> number of NUL separators
  tr -cd '\0' < "$1" 2>/dev/null | wc -c | tr -d ' '
}

fm_reap_tar_entries() {  # <archive> -> number of archive entries
  tar -tzf "$1" 2>/dev/null | wc -l | tr -d ' '
}

# Build the NUL-separated list of every path whose bytes must survive: the
# untracked set, the ignored set, and any tracked path that differs from HEAD.
#
# Git does not recurse into an IGNORED DIRECTORY: it reports the directory as
# one entry and stops.  A list built only from git's entries would therefore
# miss every file inside an ignored directory - and, worse, would miss the
# directory itself when the expansion silently produced nothing, so the entry
# count comparison against the archive could not see the omission at all.
#
# So the list CONTAINS every entry git reported (directories included) AND the
# expansion of each ignored directory: the directory, the directories under it,
# and the files under it.  "Every git entry is in the list" is then true by
# construction, and the archive is built with --no-recursion so that one
# listed directory is exactly one archive entry.
# The path list, on stdout, NUL separated.  It is a FUNCTION, not a file, so
# the dry run can compute exactly the list the apply run would archive
# without writing a list file anywhere.
fm_reap_file_list_stream() {  # <worktree>
  local wt=$1 e d
  while IFS= read -r -d '' e; do
    [ -n "$e" ] || continue
    printf '%s\0' "$e"
    if [ -d "$wt/$e" ]; then
      d=$(find "$wt/$e" -mindepth 1 \( -type f -o -type d \) -print0 2>/dev/null | sed -z "s#^$wt/##")
      [ -n "$d" ] && printf '%s' "$d"
    fi
  done < <(
    git -C "$wt" ls-files --others --exclude-standard -z 2>/dev/null
    git -C "$wt" ls-files --others --ignored --exclude-standard -z 2>/dev/null
    git -C "$wt" diff --name-only --diff-filter=d -z HEAD 2>/dev/null
  )
}

fm_reap_build_file_list() {  # <worktree> <out-list>
  local wt=$1 out=$2
  fm_reap_file_list_stream "$wt" \
    | tr '\0' '\n' | LC_ALL=C sort -u | tr '\n' '\0' > "$out" || return 1
  [ -f "$out" ] || return 1
  return 0
}

# fm_reap_preserve <worktree> <label> <task-id> <outdir>
# Prints one "key=value" line per artifact and returns 0 only when EVERY
# artifact verified.
fm_reap_preserve() {  # <worktree> <label> <task-id> <outdir>
  local wt=$1 label=$2 task=$3 outdir=$4
  local bundle="$outdir/slot-${label}.all-refs.bundle"
  local list="$outdir/slot-${label}.filelist"
  local tarf="$outdir/slot-${label}-files.tar.gz"
  local patch="$outdir/slot-${label}.patch"
  local listed entries b ahead fb

  mkdir -p "$outdir" || return 1

  # 1. the full ref snapshot, as the contract names it.
  if ! git -C "$wt" bundle create "$bundle" --all HEAD >/dev/null 2>&1; then
    printf 'bundle=FAILED\n'
    return 1
  fi
  if ! git -C "$wt" bundle verify "$bundle" >/dev/null 2>&1; then
    printf 'bundle=UNVERIFIED\n'
    return 1
  fi
  printf 'bundle=%s bytes=%s sha256=%s verified=ok\n' \
    "$bundle" "$(stat -c %s "$bundle" 2>/dev/null || echo 0)" \
    "$(sha256sum "$bundle" 2>/dev/null | cut -d' ' -f1)"

  # 2. a focused bundle for every branch that holds unmerged commits.  This is
  #    the bundle that rule 5 demands: the one that CARRIES them.
  for b in $(fm_reap_lane_branches "$wt" "$task"); do
    ahead=$(git -C "$wt" rev-list --count "$FM_REAP_BASE_REF..$b" 2>/dev/null)
    case "$ahead" in
      ''|*[!0-9]*) ahead=0 ;;
    esac
    [ "$ahead" -gt 0 ] || continue
    fb="$outdir/slot-${label}-branch-${b//\//-}.bundle"
    if ! git -C "$wt" bundle create "$fb" "$b" "^$FM_REAP_BASE_REF" >/dev/null 2>&1; then
      printf 'branch_bundle=FAILED branch=%s\n' "$b"
      return 1
    fi
    if ! git -C "$wt" bundle verify "$fb" >/dev/null 2>&1; then
      printf 'branch_bundle=UNVERIFIED branch=%s\n' "$b"
      return 1
    fi
    # The bundle must actually carry the branch tip.  ONE awk reads the whole
    # listing and exits on its own: a `grep -q` in the middle of the pipe exits
    # on the first match, the upstream writer then dies of SIGPIPE, and
    # `set -o pipefail` turns that into a FALSE "the branch is not carried".
    if ! git -C "$wt" bundle list-heads "$fb" 2>/dev/null \
         | awk -v r="refs/heads/$b" '$2 == r { found = 1 } END { exit !found }'; then
      printf 'branch_bundle=DOES_NOT_CARRY branch=%s\n' "$b"
      return 1
    fi
    printf 'branch_bundle=%s branch=%s commits_ahead=%s bytes=%s verified=ok\n' \
      "$fb" "$b" "$ahead" "$(stat -c %s "$fb" 2>/dev/null || echo 0)"
  done

  # 3. the tar of the untracked + ignored (+ tracked-modified) file set.
  if ! fm_reap_build_file_list "$wt" "$list"; then
    printf 'filelist=FAILED\n'
    return 1
  fi
  listed=$(fm_reap_nul_count "$list")
  if [ "$listed" -eq 0 ]; then
    printf 'tar=none files=0 reason=no-untracked-or-ignored-files\n'
  else
    # -C MUST precede -T: tar's options are positional, and the other order
    # silently produces an EMPTY archive.
    # --no-recursion: one listed directory is exactly one archive entry, so the
    # entry count can be compared with the listed path count.
    if ! tar -czf "$tarf" -C "$wt" --null --no-recursion -T "$list" 2>/dev/null; then
      printf 'tar=FAILED files=%s\n' "$listed"
      return 1
    fi
    entries=$(fm_reap_tar_entries "$tarf")
    if [ "$entries" != "$listed" ]; then
      printf 'tar=REJECTED files_listed=%s archive_entries=%s reason=count-mismatch\n' \
        "$listed" "$entries"
      return 1
    fi
    printf 'tar=%s files=%s entries=%s bytes=%s sha256=%s verified=ok\n' \
      "$tarf" "$listed" "$entries" "$(stat -c %s "$tarf" 2>/dev/null || echo 0)" \
      "$(sha256sum "$tarf" 2>/dev/null | cut -d' ' -f1)"
  fi

  # 4. the tracked-modification patch.
  if git -C "$wt" diff HEAD --binary > "$patch" 2>/dev/null && [ -s "$patch" ]; then
    printf 'patch=%s bytes=%s sha256=%s\n' \
      "$patch" "$(stat -c %s "$patch" 2>/dev/null || echo 0)" \
      "$(sha256sum "$patch" 2>/dev/null | cut -d' ' -f1)"
  else
    rm -f "$patch"
    printf 'patch=none reason=no-tracked-modifications\n'
  fi

  # The all-refs bundle must carry every branch that holds unmerged commits.
  for b in $(fm_reap_lane_branches "$wt" "$task"); do
    ahead=$(git -C "$wt" rev-list --count "$FM_REAP_BASE_REF..$b" 2>/dev/null)
    case "$ahead" in ''|*[!0-9]*) ahead=0 ;; esac
    [ "$ahead" -gt 0 ] || continue
    # Same one-awk form as above: no early exit, so no SIGPIPE, so no flaky
    # refusal of a reclaim that is perfectly safe.
    if ! git -C "$wt" bundle list-heads "$bundle" 2>/dev/null \
         | awk -v r="refs/heads/$b" '$2 == r { found = 1 } END { exit !found }'; then
      printf 'carried=NO branch=%s\n' "$b"
      return 1
    fi
  done
  return 0
}

# fm_reap_preserve_plan <worktree> <label> <task-id>
# Computes what fm_reap_preserve WOULD preserve, and writes NOTHING.
#
# This is the dry run's half of the preservation contract: the same file set,
# the same branches, the same counts - all read out of the slot's git state,
# with no bundle, no tar, no patch, no file list and no directory created.
# The counts are what the operator needs to decide whether to run for real:
# how many paths would be archived, how many archive entries that would be,
# and how many bytes those paths carry.
fm_reap_preserve_plan() {  # <worktree> <label> <task-id>
  local wt=$1 label=$2 task=$3
  local refs b ahead listed=0 payload=0 patch_bytes e

  refs=$(git -C "$wt" for-each-ref --format='%(refname)' 2>/dev/null | wc -l | tr -d ' ')
  printf 'bundle=WOULD-CREATE refs=%s bytes=unknown sha256=none verified=not-verified (a dry run writes no bundle)\n' \
    "${refs:-0}"

  for b in $(fm_reap_lane_branches "$wt" "$task"); do
    ahead=$(git -C "$wt" rev-list --count "$FM_REAP_BASE_REF..$b" 2>/dev/null)
    case "$ahead" in ''|*[!0-9]*) ahead=0 ;; esac
    [ "$ahead" -gt 0 ] || continue
    printf 'branch_bundle=WOULD-CREATE branch=%s commits_ahead=%s bytes=unknown verified=not-verified (a dry run writes no bundle)\n' \
      "$b" "$ahead"
  done

  # The file set the apply run would archive, computed the same way, so the
  # dry run's counts are the apply run's counts.
  while IFS= read -r -d '' e; do
    [ -n "$e" ] || continue
    listed=$((listed + 1))
    if [ -f "$wt/$e" ]; then
      payload=$((payload + $(stat -c %s "$wt/$e" 2>/dev/null || printf 0)))
    fi
  done < <(fm_reap_file_list_stream "$wt" | tr '\0' '\n' | LC_ALL=C sort -u | tr '\n' '\0')

  if [ "$listed" -eq 0 ]; then
    printf 'tar=WOULD-CREATE files=0 entries=0 bytes=0 reason=no-untracked-or-ignored-files\n'
  else
    printf 'tar=WOULD-CREATE files=%s entries=%s bytes=%s sha256=none verified=not-verified (a dry run writes no archive)\n' \
      "$listed" "$listed" "$payload"
  fi

  patch_bytes=$(git -C "$wt" diff HEAD --binary 2>/dev/null | wc -c | tr -d ' ')
  if [ "${patch_bytes:-0}" -gt 0 ]; then
    printf 'patch=WOULD-CREATE bytes=%s sha256=none (a dry run writes no patch)\n' "$patch_bytes"
  else
    printf 'patch=none reason=no-tracked-modifications\n'
  fi
  return 0
}

# Move the slot's untracked + ignored files out of the slot and restore its
# tracked paths from HEAD, so `treehouse return` does not have to discard
# anything.  Nothing is deleted: the moved files stay in the preservation
# directory.
fm_reap_clean_slot() {  # <worktree> <list> <movedir>
  local wt=$1 list=$2 moved=$3 e
  local -a tracked=()
  mkdir -p "$moved" || return 1
  if [ -f "$list" ]; then
    while IFS= read -r -d '' e; do
      [ -n "$e" ] || continue
      [ -e "$wt/$e" ] || continue
      mkdir -p "$moved/$(dirname "$e")"
      mv "$wt/$e" "$moved/$e" || return 1
    done < "$list"
  fi
  # Restore tracked paths from HEAD.  Their bytes are in the tar and the patch.
  while IFS= read -r -d '' e; do
    [ -n "$e" ] || continue
    tracked+=("$e")
  done < <(git -C "$wt" diff --name-only --diff-filter=d -z HEAD 2>/dev/null)
  if [ "${#tracked[@]}" -gt 0 ]; then
    git -C "$wt" checkout -- "${tracked[@]}" >/dev/null 2>&1 || return 1
  fi
  return 0
}

# --- the pool inventory ------------------------------------------------------

fm_reap_occupied_count() {  # <json>
  python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
print(sum(1 for x in d if x.get("status")!="available"))
' "$1" 2>/dev/null || echo "?"
}

fm_reap_record_count() {  # <json>
  python3 -c '
import json,sys
print(len(json.load(open(sys.argv[1]))))
' "$1" 2>/dev/null || echo "?"
}

fm_reap_ceiling() {  # <pool-root>
  local f="$1/treehouse.toml" v=""
  [ -f "$f" ] || { printf '?'; return; }
  v=$(grep -E '^\s*max_trees\s*=' "$f" 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' ')
  printf '%s' "${v:-?}"
}

# --- main --------------------------------------------------------------------

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --apply) APPLY=1 ;;
      --dry-run) APPLY=0 ;;
      --pool) POOL="${2:-}"; shift ;;
      --json) JSON_OUT="${2:-}"; shift ;;
      --help|-h) usage; exit 0 ;;
      *) printf 'fm-reap-finished-lanes: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
  done

  # A dry run must not write, and git's own index refresh IS a write.  This
  # makes every git command of a dry run read-only, so the slot's git state
  # is left exactly as it was found.
  if [ "$APPLY" != "1" ]; then
    export GIT_OPTIONAL_LOCKS=0
  fi

  command -v "$FM_REAP_TREEHOUSE" >/dev/null 2>&1 || {
    printf 'fm-reap-finished-lanes: FAIL treehouse binary not found: %s\n' "$FM_REAP_TREEHOUSE" >&2
    exit 2
  }

  # ---- the lock.  Two runs never overlap. -------------------------------
  # The lock is the STATE DIRECTORY itself, taken with flock(2) on an open
  # directory descriptor.  A lock FILE would be a file the dry run CREATES in
  # the state directory, and "the dry run writes nothing" has to be true of
  # the state directory too - that is where the markers live.  Locking the
  # directory keeps the exclusion between two runs, and between a dry run and
  # an apply run (they lock the same directory), without writing anything at
  # all.  An explicit FM_REAP_LOCK_FILE still selects a lock FILE, which is
  # what the test suite uses to hold the lock from the outside.
  local lock_target="$FM_REAP_STATE"
  if [ -n "${FM_REAP_LOCK_FILE:-}" ]; then
    lock_target="$FM_REAP_LOCK_FILE"
    mkdir -p "$(dirname "$lock_target")" 2>/dev/null
    exec 9>"$lock_target" || {
      printf 'fm-reap-finished-lanes: FAIL cannot open lock file: %s\n' "$lock_target" >&2
      exit 2
    }
  else
    [ -d "$lock_target" ] || {
      printf 'fm-reap-finished-lanes: FAIL the state directory does not exist: %s\n' "$lock_target" >&2
      exit 2
    }
    exec 9<"$lock_target" || {
      printf 'fm-reap-finished-lanes: FAIL cannot open the state directory for locking: %s\n' "$lock_target" >&2
      exit 2
    }
  fi
  if ! flock -n 9; then
    printf 'fm-reap-finished-lanes: SKIPPED another run holds the lock (%s)\n' "$lock_target"
    exit 3
  fi

  # ---- resolve the pool --------------------------------------------------
  if [ -z "$POOL" ]; then
    local f wt
    for f in "$FM_REAP_STATE"/*.meta; do
      [ -f "$f" ] || continue
      wt=$(grep '^worktree=' "$f" 2>/dev/null | cut -d= -f2-)
      [ -n "$wt" ] || continue
      POOL=$(fm_reap_pool_from_worktree "$wt")
      break
    done
  fi
  [ -n "$POOL" ] || {
    printf 'fm-reap-finished-lanes: FAIL cannot resolve the pool root\n' >&2
    exit 2
  }
  [ -d "$POOL" ] || {
    printf 'fm-reap-finished-lanes: FAIL pool root does not exist: %s\n' "$POOL" >&2
    exit 2
  }

  # ---- the pool inventory ------------------------------------------------
  local first_slot="" d c
  for d in "$POOL"/*/; do
    [ -d "$d" ] || continue
    for c in "$d"*/; do
      [ -d "$c" ] && { first_slot="${c%/}"; break; }
    done
    [ -n "$first_slot" ] && break
  done
  [ -n "$first_slot" ] || {
    printf 'fm-reap-finished-lanes: FAIL pool has no worktree slots: %s\n' "$POOL" >&2
    exit 2
  }
  local repo_root
  repo_root=$(fm_reap_repo_root_from_worktree "$first_slot") || {
    printf 'fm-reap-finished-lanes: FAIL cannot resolve the repo root for %s\n' "$POOL" >&2
    exit 2
  }

  local status_json
  status_json=$(mktemp) || exit 2
  ( cd "$repo_root" && "$FM_REAP_TREEHOUSE" status --json ) > "$status_json" 2>/dev/null
  if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$status_json" 2>/dev/null; then
    printf 'fm-reap-finished-lanes: FAIL cannot read the pool inventory\n' >&2
    exit 2
  fi

  local records_before occupied_before ceiling
  records_before=$(fm_reap_record_count "$status_json")
  occupied_before=$(fm_reap_occupied_count "$status_json")
  ceiling=$(fm_reap_ceiling "$POOL")

  say "fm-reap-finished-lanes: pool=$POOL"
  say "  records_before=$records_before ceiling=$ceiling occupied_before=$occupied_before mode=$([ "$APPLY" = 1 ] && echo apply || echo dry-run)"

  local started
  started=$(date +%s)

  local stamp
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  local preserve_dir="${FM_REAP_PRESERVE_DIR:-$FM_ROOT/data/fm-reap-finished-lanes/$stamp}"
  # The preservation directory belongs to the APPLY path.  A dry run must not
  # create it, not even empty.
  if [ "$APPLY" = "1" ]; then
    mkdir -p "$preserve_dir" 2>/dev/null
  fi

  # ---- the candidate scan -------------------------------------------------
  local reclaimed=0 skipped=0 candidates=0
  local -a report_rows=()
  local path name status lease_id lease_holder label meta task win har
  local verb lane_state pane_state slog lastline pres out rc left list moved
  local meta_f

  while IFS=$'\t' read -r name path status lease_id lease_holder; do
    [ -n "$path" ] || continue

    # The run is bounded.  When the budget is spent the scan stops rather than
    # running on: a reaper that overruns is a reaper nobody can reason about.
    if [ $(( $(date +%s) - started )) -gt "$FM_REAP_MAX_SECONDS" ]; then
      skipped=$((skipped + 1))
      report_rows+=("$(fm_reap_row SKIP "$name" "$status" - - "the run budget of ${FM_REAP_MAX_SECONDS}s is spent: the scan stopped here")")
      break
    fi

    # A slot with no lane record naming it cannot be classified.  Unknown fails
    # closed: it is reported and left alone.
    if ! meta_f=$(fm_reap_lane_for_slot "$path" 2>/dev/null); then
      meta_f=""
    fi
    if [ -z "$meta_f" ]; then
      skipped=$((skipped + 1))
      report_rows+=("$(fm_reap_row SKIP "$name" "$status" - - "no lane record names this slot (unknown: fail closed)")")
      continue
    fi
    IFS=$'\t' read -r meta task win har <<< "$meta_f"

    # Already reclaimed?  Only while the slot is free again: a slot leased
    # since is live work again, and the marker must not speak for it.
    local marker
    if marker=$(fm_reap_marker_read "$task" 2>/dev/null) && [ "$status" = "available" ]; then
      skipped=$((skipped + 1))
      report_rows+=("$(fm_reap_row SKIP "$name" "$status" "$task" - "already reclaimed by this reaper ($marker)")")
      continue
    fi

    # ---- Fact 1: the terminal verb. ------------------------------------
    slog="$FM_REAP_STATE/$task.status"
    if [ ! -f "$slog" ]; then
      skipped=$((skipped + 1))
      report_rows+=("$(fm_reap_row SKIP "$name" "$status" "$task" - "no task log for the lane (unknown: fail closed)")")
      continue
    fi
    lastline=$(fm_reap_last_status_line "$slog")
    verb=$(fm_reap_verb_of_line "$lastline")
    # The terminal set is {done, resolved}.  `blocked` and `needs-decision` are
    # therefore LIVE WORK and can never qualify - that is the rule 3 exclusion,
    # enforced HERE by the one gate that decides terminality.  A separate
    # blocked-only gate would be a second, redundant path to the same answer,
    # and a redundant guard is a guard nobody has to keep true.
    if ! fm_reap_is_reclaim_terminal_verb "$verb"; then
      local why="the last status line is not a terminal verb"
      if [ "$verb" = "blocked" ] || [ "$verb" = "needs-decision" ]; then
        why="the status says live work: never a reclaim candidate"
      fi
      skipped=$((skipped + 1))
      report_rows+=("$(fm_reap_row SKIP "$name" "$status" "$task" "${verb:-none}" "$why")")
      continue
    fi

    # The ledger's own state.  BLOCKED is live work and is never a candidate.
    lane_state=$(fm_reap_ledger_state "$(basename "$meta" .meta)" "$task")
    if [ "$lane_state" = "BLOCKED" ]; then
      skipped=$((skipped + 1))
      report_rows+=("$(fm_reap_row SKIP "$name" "$status" "$task" "$verb" "ledger state is BLOCKED: live work, never a reclaim candidate")")
      continue
    fi

    # ---- Fact 2: the pane no longer runs the lane's worker. --------------
    fm_reap_pane_state "$win" "$har"
    pane_state=$?
    if [ "$pane_state" != "1" ]; then
      skipped=$((skipped + 1))
      report_rows+=("$(fm_reap_row SKIP "$name" "$status" "$task" "$verb" "pane $win is $(fm_reap_pane_state_name "$pane_state"): not provably free")")
      continue
    fi

    candidates=$((candidates + 1))

    # ---- preserve, then reclaim ------------------------------------------
    label=$(printf '%s' "$path" | sed -E "s#^$POOL/##; s#/[^/]+\$##; s#/#-#g")

    # The dry run WRITES NOTHING.  It does not preserve, it does not clean
    # the slot, it does not return the slot and it does not write a marker.
    # It computes what it WOULD preserve and reports that, so the dry run
    # is worth reading.
    if [ "$APPLY" != "1" ]; then
      if ! pres=$(fm_reap_preserve_plan "$path" "$label" "$task" 2>&1); then
        skipped=$((skipped + 1))
        report_rows+=("$(fm_reap_row SKIP "$name" "$status" "$task" "$verb" "the preservation plan failed: $(printf '%s' "$pres" | tr '\n' ';')")")
        continue
      fi
      skipped=$((skipped + 1))
      report_rows+=("$(fm_reap_row CANDIDATE "$name" "$status" "$task" "$verb" "would preserve, not returned (dry run: nothing was written)")")
      note "CANDIDATE slot=$name lane=$task verb=$verb"
      printf '%s\n' "$pres" | sed 's/^/    /'
      continue
    fi

    # ---- the apply path: preserve FIRST, then reclaim --------------------
    if ! pres=$(fm_reap_preserve "$path" "$label" "$task" "$preserve_dir" 2>&1); then
      skipped=$((skipped + 1))
      report_rows+=("$(fm_reap_row SKIP "$name" "$status" "$task" "$verb" "preservation failed: $(printf '%s' "$pres" | tr '\n' ';')")")
      continue
    fi

    # Make the slot clean without discarding anything that is not preserved.
    list="$preserve_dir/slot-${label}.filelist"
    moved="$preserve_dir/moved/slot-${label}"
    if ! fm_reap_clean_slot "$path" "$list" "$moved"; then
      skipped=$((skipped + 1))
      report_rows+=("$(fm_reap_row SKIP "$name" "$status" "$task" "$verb" "could not make the slot clean without discarding bytes")")
      continue
    fi
    left=$(git -C "$path" status --porcelain 2>/dev/null | head -5)
    if [ -n "$left" ]; then
      skipped=$((skipped + 1))
      report_rows+=("$(fm_reap_row SKIP "$name" "$status" "$task" "$verb" "slot is still dirty after preservation: $(printf '%s' "$left" | tr '\n' ';')")")
      continue
    fi

    # Return the slot.  Never --force.  Pinned to the lease we observed so a
    # slot leased by somebody else in the meantime is not released.
    if [ -n "$lease_id" ]; then
      out=$(cd "$repo_root" && "$FM_REAP_TREEHOUSE" return --if-lease-id "$lease_id" "$path" 2>&1)
      rc=$?
    elif [ -n "$lease_holder" ]; then
      out=$(cd "$repo_root" && "$FM_REAP_TREEHOUSE" return --if-lease-holder "$lease_holder" "$path" 2>&1)
      rc=$?
    else
      out=$(cd "$repo_root" && "$FM_REAP_TREEHOUSE" return "$path" 2>&1)
      rc=$?
    fi
    if [ "$rc" -ne 0 ]; then
      skipped=$((skipped + 1))
      report_rows+=("$(fm_reap_row SKIP "$name" "$status" "$task" "$verb" "treehouse return refused (rc=$rc): $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)")")
      continue
    fi
    reclaimed=$((reclaimed + 1))
    fm_reap_marker_write "$task" "$label" "$status"
    report_rows+=("$(fm_reap_row RECLAIM "$name" "$status" "$task" "$verb" "returned: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)")")
    note "RECLAIMED slot=$name lane=$task verb=$verb"
    printf '%s\n' "$pres" | sed 's/^/    /'
  done < <(python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
for x in d:
    print("\t".join([str(x.get("name","")), str(x.get("path","")),
                      str(x.get("status","")), str(x.get("lease_id","")),
                      str(x.get("lease_holder",""))]))
' "$status_json")

  # ---- the report --------------------------------------------------------
  local row
  for row in ${report_rows[@]+"${report_rows[@]}"}; do
    printf '%s\n' "$row" | awk -F'\t' '{printf "  %-10s slot=%-6s %-9s lane=%-46s verb=%-10s %s\n", $1, $2, $3, $4, $5, $6}'
  done

  local status_after
  status_after=$(mktemp) || exit 2
  ( cd "$repo_root" && "$FM_REAP_TREEHOUSE" status --json ) > "$status_after" 2>/dev/null
  local records_after occupied_after
  records_after=$(fm_reap_record_count "$status_after")
  occupied_after=$(fm_reap_occupied_count "$status_after")

  say "  candidates=$candidates reclaimed=$reclaimed skipped=$skipped"
  say "  records_after=$records_after ceiling=$ceiling occupied_after=$occupied_after"
  if [ "$APPLY" = "1" ]; then
    say "  preserve_dir=$preserve_dir"
  else
    say "  preserve_dir=$preserve_dir (dry run: not created)"
  fi

  if [ -n "$JSON_OUT" ]; then
    {
      printf '{\n'
      printf '  "pool": "%s",\n' "$POOL"
      printf '  "ceiling": "%s",\n' "$ceiling"
      printf '  "records_before": "%s",\n' "$records_before"
      printf '  "records_after": "%s",\n' "$records_after"
      printf '  "occupied_before": "%s",\n' "$occupied_before"
      printf '  "occupied_after": "%s",\n' "$occupied_after"
      printf '  "candidates": %s,\n' "$candidates"
      printf '  "reclaimed": %s,\n' "$reclaimed"
      printf '  "skipped": %s,\n' "$skipped"
      printf '  "mode": "%s",\n' "$([ "$APPLY" = 1 ] && echo apply || echo dry-run)"
      printf '  "preserve_dir": "%s",\n' "$preserve_dir"
      printf '  "rows": [\n'
      local first=1
      for row in ${report_rows[@]+"${report_rows[@]}"}; do
        [ $first -eq 1 ] || printf ',\n'
        first=0
        printf '    "%s"' "$(printf '%s' "$row" | tr '\t' '|' | sed 's/"/\\"/g')"
      done
      printf '\n  ]\n}\n'
    } > "$JSON_OUT"
    say "  json=$JSON_OUT"
  fi

  rm -f "$status_json" "$status_after"
  return 0
}

main "$@"
