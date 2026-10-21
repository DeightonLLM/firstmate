#!/usr/bin/env bash
# fm-capacity-reclaim.sh - reclaim REAL disk space, so the 80% ceiling can be real.
#
# WHY THIS EXISTS.
#
# The Captain's standing order: *"lets reclaim but refuse"* and *"im not wanting it to go past 80% really
# from here on in."* A ceiling that refuses work without first trying to free space makes the fleet do the
# work by hand, and the work is always the same: deleting the same litter, in the same order, every time.
#
# The thing this script exists to fix is HONESTY ABOUT BYTES.
#
# `rm` on this host is a managed recoverable-delete shim (/root/.minimax/shims/rm) that MOVES the target
# into ~/.local/share/Trash. On a single filesystem that move frees ZERO bytes: the trash grew to 14.1 GB
# while df sat at 97% with 2.8 GB free, and a guard that reported "freedKB=340864" had freed nothing.
# So this script unlinks with the REAL rm, resolved by absolute path and never by PATH lookup, and it
# measures the filesystem BEFORE and AFTER. The number it reports is bytes the filesystem actually gave
# back - never a sum of what it believes it deleted.
#
# Every class here is REGENERABLE by definition. Work that is not landed, not leased and not recoverable
# is never in any tier: unlanded work is protected by the reap gate and the teardown's landed-work test,
# and leased worktree slots are protected by treehouse's own lease state.
#
# TIERS.
#   1  caches and build litter - always regenerable, safe by construction.
#      1b DEAD LOCK SCRATCH - the owner dirs and reclaim pointers of locks
#         nobody holds any more. A provably dead lock owner dir is pure
#         garbage, so this is safe-and-automatic like the rest of tier 1.
#      1c BOUNDED LOGS - an append-only log that grew past its cap is
#         ROTATED (the recent tail kept, the rest rotated out), never
#         truncated blind.
#   2  the worktree pool - delegated to `treehouse prune`, which refuses leased slots and slots with
#      uncommitted changes, and only removes a slot whose HEAD is already merged.
#   3  agent session transcripts - regenerable logs, but they are also the fleet's audit trail, so they
#      are age-gated hard and are NOT applied unless asked for by name.
#   4  archive-class inventory - cold but VALUABLE (old SaaS installs, migrations, release snapshots,
#      documents). These are never deleted here. They are measured and reported, because archival means
#      moving them OFF this filesystem, and only the Captain knows where they belong.
#
# TIER 1b: WHY THE DEAD LOCK SCRATCH BELONGS IN THE SAFE SET.
#
# A lock owner dir is scratch by construction: mktemp made it, it holds only
# the lock's own pid file, and it is unreferenced the moment its pointer goes.
# The reclaim is SAFE-and-automatic because the safety is a PROOF rather than
# a heuristic: the dir is reclaimed only when its recorded pid is provably not
# the process that created it. The test compares the process's start time with
# the owner dir's own mtime, because the kernel RECYCLES pids - a naive "is
# the pid alive?" test kept 21,201 dead dirs alive on this host, because their
# pids happened to be running again as unrelated processes. When the dir
# carries a `pid-identity` file the match is exact, and that stronger test
# wins. A live holder is NEVER touched, and a lock pointer is removed only
# when its owner dir is one this sweep reclaimed or when its own target is
# provably dead.
#
# TIER 1c: WHY THE LOG IS ROTATED AND NOT DELETED.
#
# The comms ingest log reached 40 MB because an oversize file was re-reported
# on every scan and nothing ever rotated it. The log is the fleet's record of
# what the remote host said, so it is rotated rather than deleted: the most
# recent tail is kept for diagnosis and the rest is rotated out. The rotation
# is copytruncate, and it falls back to a rename when a writer was active
# during the snapshot, so an in-flight writer never loses output.
#
# USAGE.
#   fm-capacity-reclaim.sh                 dry run: report every tier, change nothing (the default)
#   fm-capacity-reclaim.sh --apply         apply tiers 1 and 2 for real
#   fm-capacity-reclaim.sh --apply --tier 3   also apply the age-gated transcript tier
#   fm-capacity-reclaim.sh --inventory     print the archive-class inventory only
#   fm-capacity-reclaim.sh --help
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"

# The lock scratch sweep and the log rotation need the same roots: a lock
# owner dir lives beside the lock it belongs to, and the locks live in a
# home's state/ directory.
#
# The list is EXPLICIT, because this script's whole philosophy is explicit
# lists rather than wildcards: a wildcard over the host could reach a
# directory another surface owns. FM_RECLAIM_STATE_ROOTS replaces it with a
# colon-separated list.
FM_RECLAIM_CONTROLLER_STATE="${FM_RECLAIM_CONTROLLER_STATE:-/root/agent-work/deightonllm-firstmate/state}"

reclaim_state_roots() {
  if [ -n "${FM_RECLAIM_STATE_ROOTS:-}" ]; then
    printf '%s\n' "$FM_RECLAIM_STATE_ROOTS" | tr ':' '\n'
    return 0
  fi
  printf '%s\n' "$FM_RECLAIM_CONTROLLER_STATE"
  printf '%s\n' "$FM_HOME/state"
}


APPLY=0
TIER=2
INVENTORY_ONLY=0
# A while/shift loop, not `for arg in "$@"`. A `for` loop over "$@" keeps
# iterating over the ORIGINAL positional parameters, so a `shift` inside it
# cannot consume the value that follows an option: `--tier 3` visited "3" as
# the next argument and died with "unknown argument: 3". The documented
# `--apply --tier 3` form had never worked.
while [ "$#" -gt 0 ]; do
  arg="$1"
  case "$arg" in
    --apply) APPLY=1; shift ;;
    --dry-run) APPLY=0; shift ;;
    --tier) shift; TIER="${1:-2}"; [ "$#" -gt 0 ] && shift ;;
    --tier=*) TIER="${arg#--tier=}"; shift ;;
    --inventory) INVENTORY_ONLY=1; shift ;;
    -h|--help) awk 'NR==1{next} /^#/{print; next} {exit}' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# The tier groups this run executes. The knob exists so ONE tier can be
# exercised on its own: an operator who wants only the lock sweep, and a test
# that must not touch the host's real caches. Empty means the default: the
# safe-and-automatic set (1, 1b, 1c, 2), plus 3 when --tier 3 asked for it.
RECLAIM_TIERS="${FM_RECLAIM_TIERS:-1,1b,1c,2}"
if [ "$TIER" -ge 3 ] && [ -z "${FM_RECLAIM_TIERS:-}" ]; then
  RECLAIM_TIERS="1,1b,1c,2,3"
fi

tier_enabled() {  # <tier-group>
  case ",$RECLAIM_TIERS," in
    *",$1,"*) return 0 ;;
  esac
  return 1
}

# A malformed tier must be an actionable error, not a silently defaulted one:
# "the operator asked for tier 3 and got tier 2" is exactly the kind of quiet
# downgrade this repo treats as a defect.
case "$TIER" in
  ''|*[!0-9]*) echo "unknown argument: --tier needs a non-negative integer, got '$TIER'" >&2; exit 2 ;;
esac

# The REAL unlink. Resolved by absolute path, and the shim is rejected even if it
# is found at one of those paths, so a reclaim can never land in the trash and
# report a reclaim that did not happen.
REAL_RM=""
for bin in /usr/bin/rm /bin/rm; do
  [ -x "$bin" ] || continue
  resolved=$(readlink -f "$bin" 2>/dev/null || printf '%s' "$bin")
  case "$resolved" in */shims/*|*/mavis-trash) continue ;; esac
  REAL_RM="$bin"; break
done

# The df the reclaim measures with. A test seam, so a test can prove that the
# reported bytes are MEASURED and never a sum of what the script believes it
# deleted: a fake df that reports MORE free space after the reclaim must not
# turn into a claim that the reclaim freed those bytes.
# shellcheck disable=SC2086  # DF_CMD is a command with its own arguments.
DF_CMD="${FM_RECLAIM_DF:-df -P /}"

disk_pct() { $DF_CMD 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}'; }
disk_avail_kb() { $DF_CMD 2>/dev/null | awk 'NR==2{print $4}'; }
size_kb() { du -x -s -k "$1" 2>/dev/null | awk '{print $1}'; }

# The whole log family on disk: the live log plus every generation beside it.
# A rotation moves the live file into a generation, so the bytes that stayed
# are the generation that was kept - measuring only the live file would
# overstate what was freed.
log_family_kb() {
  local log="$1" p total=0 kb
  for p in "$log" "$log".1 "$log".rot.*; do
    [ -f "$p" ] || continue
    kb=$(size_kb "$p")
    total=$((total + ${kb:-0}))
  done
  printf '%s\n' "$total"
}

# The archive-class inventory: cold, valuable, and NOT ours to delete. Measured
# so the Captain can decide where it goes. Archival only frees space if the
# bytes leave this filesystem.
#
# This is tier 4, so it is REPORTED and NEVER deleted. A separate lane is
# producing the decision brief about where this material belongs.
print_archive_inventory() {
  local p
  for p in /srv/hd2-canonical-recovery /root/migration-0043 /root/DeightonLLM_hub-main.pre_restore_20260601_191307 \
           /root/.treehouse/lead-gen-saas-v3-first-install-ready-20260710-cf6f60 /opt/core-distro-staging/releases \
           /root/agent-work/firstmate-local-backup-stash-20261013 /root/.antigravity-ide-server /root/.local/share/Trash; do
    [ -e "$p" ] || continue
    printf '  %-72s %s\n' "$p" "$(size_kb "$p") KB"
  done
}

# --inventory prints the archive inventory and nothing else. The flag used to be
# accepted and then ignored: the script ran every tier anyway, so an operator
# asking "what is the cold material?" got a full reclaim report instead.
if [ "$INVENTORY_ONLY" = 1 ]; then
  echo "=== capacity reclaim: archive-class inventory (reported, never deleted) ==="
  print_archive_inventory
  exit 0
fi

unlink_real() {  # <path>
  local p="$1"
  [ -n "$REAL_RM" ] || { echo "SKIP-NO-REAL-RM $p"; return 1; }
  if [ -L "$p" ] || [ ! -d "$p" ]; then
    "$REAL_RM" -f -- "$p" 2>/dev/null || return 1
  else
    "$REAL_RM" -rf -- "$p" 2>/dev/null || return 1
  fi
  return 0
}

# recent_content <path> <minutes>: succeeds when SOME entry under <path> was
# touched within the last <minutes>.
#
# The gate is deliberately "nothing inside is fresh", NOT "the top directory's
# own mtime is old". A directory's mtime only moves when an entry is added or
# removed, so gating on it would happily reclaim a cache whose contents were
# written minutes ago - which is exactly the live process sitting in it that
# this gate exists to avoid. Age-gating the CONTENTS is what makes the promise
# true.
#
# -mmin with a negative argument means "modified LESS than N minutes ago", so
# -mmin -120 is the last two hours. find exits 0 whether or not it matched, so
# the match is read off stdout rather than off the exit status.
recent_content() {  # <path> <minutes>
  find "$1" -mmin "-$2" -print -quit 2>/dev/null | grep -q .
}

CACHE_AGE_MINUTES="${FM_RECLAIM_CACHE_AGE_MINUTES:-120}"
TRANSCRIPT_AGE_DAYS="${FM_RECLAIM_TRANSCRIPT_AGE_DAYS:-14}"
# The transcript gate is expressed in days for readability and applied to file
# CONTENT in minutes, because that is what the content check can actually see.
case "$TRANSCRIPT_AGE_DAYS" in ''|*[!0-9]*) TRANSCRIPT_AGE_DAYS=14 ;; esac
TRANSCRIPT_AGE_MINUTES=$((TRANSCRIPT_AGE_DAYS * 1440))

echo "=== capacity reclaim ==="
# The filesystem's own numbers, read BEFORE anything is touched. The result line
# compares against these, so the reported figure is what the filesystem actually
# gave back - never a sum of what the script believes it deleted.
before_pct=$(disk_pct)
before_kb=$(disk_avail_kb)
# Fail closed on an unmeasurable filesystem. Without this guard the delta
# arithmetic below would run on an empty string and this script would print a
# freed-bytes figure it never measured.
case "${before_kb:-}" in
  ''|*[!0-9]*)
    echo "FATAL: root filesystem usage could not be measured before the reclaim (df returned '${before_kb:-nothing}'); refusing to report a freed-bytes figure" >&2
    exit 4
    ;;
esac
echo "mode: $([ "$APPLY" = 1 ] && echo APPLY || echo DRY-RUN) | tiers: 1-2$([ "$TIER" -ge 3 ] && echo '+3') | disk before: ${before_pct}% used, ${before_kb} KB free"

# dedupe_nested: read paths on stdin and print them with any path that sits
# UNDER an already-printed path dropped.
#
# A cache root and the directories inside it are ONE reclaim, not two. Counting
# both would double-count the reported size and would try to delete the same
# bytes twice. find walks depth-first, so the shallowest path of a nested group
# arrives first and is the one that is kept.
KEPT_NESTED=()
dedupe_nested() {
  local p k skip
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    skip=0
    # ${arr[@]+"${arr[@]}"} is the stock-Bash-3.2 idiom for an empty array under
    # `set -u`: on Bash 3.2 a bare "${arr[@]}" on an empty array is an unbound
    # variable error. The guard also runs on macOS (Brandon Compute).
    for k in ${KEPT_NESTED[@]+"${KEPT_NESTED[@]}"}; do
      case "$p" in
        "$k"/*) skip=1; break ;;
      esac
    done
    [ "$skip" = 0 ] || continue
    KEPT_NESTED+=("$p")
    printf '%s\n' "$p"
  done
}

# is_protected: true when the path sits inside an area another lane owns.
#
# The reclaimer's whole philosophy is explicit lists rather than wildcards, so
# this is an explicit list too. The tracker and campaign-dashboard areas are
# other lanes' work while they are in flight; the reclaim must never reach
# into them, not even to remove a byte-compiled __pycache__ directory. The byte
# cost of honouring this is negligible next to the worktree pool.
is_protected() {  # <path>
  case "$1" in
    */data/tracker|*/data/tracker/*|*/data/tracker-*|*/data/campaign-dashboard-20261015|*/data/campaign-dashboard-20261015/*) return 0 ;;
  esac
  return 1
}

# --- Tier 1: caches and build litter ------------------------------------------
# Every entry here is something the host rebuilds on demand.
tier1_candidates() {
  # apt's downloaded debs: the cache, by definition, of things already installed.
  find /var/cache/apt/archives -maxdepth 1 -type f -name '*.deb' 2>/dev/null | sort
  # pip and npm download caches.
  find /root/.cache/pip -maxdepth 2 -type d 2>/dev/null | sort | head -50
  find /root/.npm/_cacache -maxdepth 2 -type d 2>/dev/null | sort | head -20
  # Byte-compiled python: pure derived output, rebuilt on next import.
  find /root/agent-work /root/.minimax /root/.pi -maxdepth 5 -type d -name '__pycache__' 2>/dev/null | sort | head -200
}

echo
echo "--- tier 1: caches and build litter ---"
t1=0; t1_kb=0
if tier_enabled 1; then
while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ -e "$p" ] || continue
  if is_protected "$p"; then
    echo "SKIP-PROTECTED $p (another lane owns this area)"
    continue
  fi
  # Never touch something a live process is sitting in. The gate is on the
  # CONTENTS, not on the top directory's mtime - see recent_content.
  if recent_content "$p" "$CACHE_AGE_MINUTES"; then
    echo "SKIP-RECENT $p (something inside was touched in the last ${CACHE_AGE_MINUTES}m)"
    continue
  fi
  kb=$(size_kb "$p"); kb=${kb:-0}
  if [ "$APPLY" = 1 ]; then
    if unlink_real "$p"; then
      t1=$((t1+1)); t1_kb=$((t1_kb+kb)); echo "RECLAIMED $p (${kb} KB)"
    else
      echo "FAILED $p"
    fi
  else
    t1=$((t1+1)); t1_kb=$((t1_kb+kb)); echo "WOULD-RECLAIM $p (${kb} KB)"
  fi
done < <(tier1_candidates | dedupe_nested)
fi
if [ "$APPLY" = 1 ]; then
  echo "tier 1: $t1 item(s) reclaimed, ${t1_kb} KB by the files' own size"
else
  echo "tier 1: $t1 item(s) would be reclaimed, ${t1_kb} KB by the files' own size (a projection, NOT freed bytes)"
fi

# --- Tier 1b: dead lock scratch ------------------------------------------------
#
# The lock owner dirs and reclaim pointers of locks nobody holds any more.
# This is the class the reclaimer used to be blind to: it had no idea a lock
# owner dir existed, so the biggest reclaimable thing on the host (37,235 dirs,
# 357 MB, under state/comms-receipts/) was invisible to the thing whose job is
# reclaiming.
#
# The safety is a PROOF, not a heuristic: a dir is reclaimed only when its
# recorded pid is provably not the process that created it. See
# bin/fm-lock-reclaim-lib.sh for the argument.
echo
echo "--- tier 1b: dead lock owner dirs and stale lock pointers ---"
lock_roots=()
lock_root=""
while IFS= read -r lock_root; do
  [ -n "$lock_root" ] || continue
  lock_roots+=("$lock_root")
done <<< "$(reclaim_state_roots)"
if [ "${#lock_roots[@]}" -eq 0 ]; then
  echo "SKIP: no state roots to sweep"
elif ! tier_enabled 1b; then
  echo "SKIP: tier 1b is not in this run's tier set (${RECLAIM_TIERS})"
else
  FM_LOCK_RECLAIM_APPLY=$APPLY
  FM_LOCK_RECLAIM_DIRS=0
  FM_LOCK_RECLAIM_POINTERS=0
  FM_LOCK_RECLAIM_LIVE=0
  FM_LOCK_RECLAIM_UNKNOWN=0
  FM_LOCK_RECLAIM_BYTES=0
  # shellcheck source=bin/fm-lock-reclaim-lib.sh
  . "$SCRIPT_DIR/fm-lock-reclaim-lib.sh"
  # The lib resets its counters when it is sourced, so they are set AFTER it.
  FM_LOCK_RECLAIM_APPLY=$APPLY
  fm_lock_reclaim_sweep "${lock_roots[@]+"${lock_roots[@]}"}"
  lock_dirs=$FM_LOCK_RECLAIM_DIRS
  lock_pointers=$FM_LOCK_RECLAIM_POINTERS
  lock_live=$FM_LOCK_RECLAIM_LIVE
  lock_unknown=$FM_LOCK_RECLAIM_UNKNOWN
  lock_kb=$FM_LOCK_RECLAIM_BYTES
  if [ "$APPLY" = 1 ]; then
    echo "tier 1b: $lock_dirs dead lock owner dir(s) and $lock_pointers lock pointer(s) reclaimed, ${lock_kb} KB by the affected parents' own size (${lock_live} live holder(s) skipped, ${lock_unknown} undecidable holder(s) skipped)"
  else
    echo "tier 1b: $lock_dirs dead lock owner dir(s) and $lock_pointers lock pointer(s) would be reclaimed, ${lock_kb} KB by the affected parents' own size (a projection, NOT freed bytes; ${lock_live} live holder(s) skipped, ${lock_unknown} undecidable holder(s) skipped)"
  fi
fi

# --- Tier 1c: bounded logs ----------------------------------------------------
#
# An append-only log that grew past its cap is ROTATED, never blind-truncated:
# the recent tail is kept for diagnosis and the rest is rotated out. The
# comms ingest log reached 40 MB because an oversize file was re-reported on
# every scan and nothing ever rotated it.
#
# The rotation lives in bin/fm-log-rotate.sh so it can also run on its own
# (from a timer, or by hand) and not only from the reclaim path.
echo
echo "--- tier 1c: bounded logs (rotate, keep the recent tail) ---"
log_count=0
log_kb=0
if ! tier_enabled 1c; then
  echo "SKIP: tier 1c is not in this run's tier set (${RECLAIM_TIERS})"
else
for lock_root in ${lock_roots[@]+"${lock_roots[@]}"}; do
  log="$lock_root/fm-comms-ingest.log"
  [ -f "$log" ] || continue
  # The FAMILY, not just the live file: a rotation moves the live file into a
  # generation, so the bytes that stayed on the filesystem are the generation
  # that was kept. Measuring only the live file would overstate what was
  # freed.
  log_before=$(log_family_kb "$log"); log_before=${log_before:-0}
  if [ "$APPLY" = 1 ]; then
    log_out="$("$SCRIPT_DIR/fm-log-rotate.sh" --apply --log "$log" 2>&1)"
  else
    log_out="$("$SCRIPT_DIR/fm-log-rotate.sh" --log "$log" 2>&1)"
  fi
  printf '%s\n' "$log_out" | sed 's/^/  /'
  log_after=$(log_family_kb "$log"); log_after=${log_after:-0}
  log_kb=$((log_kb + log_before - log_after))
  log_count=$((log_count + 1))
done
if [ "$log_count" -eq 0 ]; then
  echo "tier 1c: no comms ingest log under the swept roots"
elif [ "$APPLY" = 1 ]; then
  echo "tier 1c: $log_count log(s) rotated, ${log_kb} KB by the live files' own size"
else
  echo "tier 1c: $log_count log(s) would be rotated, ${log_kb} KB by the live files' own size (a projection, NOT freed bytes)"
fi
fi

# --- Tier 2: the worktree pool --------------------------------------------------
# Delegated to treehouse, because treehouse owns the pool: it refuses a leased
# slot, refuses a slot with uncommitted changes, and only removes a slot whose
# HEAD is already merged into the default branch. A hand-rolled "rm -rf the pool
# dir" would throw all of that away.
echo
echo "--- tier 2: worktree pool (treehouse prune) ---"
pruned=0
if ! tier_enabled 2; then
  echo "SKIP: tier 2 is not in this run's tier set (${RECLAIM_TIERS})"
elif command -v treehouse >/dev/null 2>&1; then
  if [ "$APPLY" = 1 ]; then
    treehouse_out="$(treehouse prune --all --yes 2>&1)"
  else
    treehouse_out="$(treehouse prune --all 2>&1)"
  fi
  printf '%s\n' "$treehouse_out" | tail -12
  # How many worktrees treehouse says it removed. This feeds the summary line
  # only; the authoritative "bytes freed" number stays the df delta below.
  # The match is case-insensitive because treehouse's own wording differs
  # between the dry run ("would prune N") and the applied run ("Pruned N"), and
  # a count that silently reads zero is exactly the kind of quiet wrong number
  # this script exists to avoid.
  pruned=$(printf '%s\n' "$treehouse_out" \
    | sed -nE 's/.*([Ww]ould [Pp]rune|[Pp]runed) ([0-9]+) stale worktree.*/\2/p' | head -1)
  case "${pruned:-}" in ''|*[!0-9]*) pruned=0 ;; esac
  if [ "$APPLY" = 1 ]; then
    echo "tier 2: treehouse pruned ${pruned} worktree(s) (leased, dirty, in-use and unmerged slots are refused by treehouse itself)"
  else
    echo "tier 2: treehouse WOULD prune ${pruned} worktree(s)"
  fi
else
  echo "SKIP: treehouse not on PATH"
fi

# --- Tier 3: agent session transcripts -------------------------------------------
# Regenerable logs, but they are the fleet's record of what it did. Age-gated
# hard, and applied only when asked for by name.
t3=0
if [ "$TIER" -ge 3 ] && tier_enabled 3; then
  echo
  echo "--- tier 3: agent session transcripts (older than ${TRANSCRIPT_AGE_DAYS}d) ---"
  t3=0; t3_kb=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -e "$p" ] || continue
    # The directory's own age is not enough: a session directory old enough to
    # qualify can still have been written to this morning.
    if recent_content "$p" "$TRANSCRIPT_AGE_MINUTES"; then
      echo "SKIP-RECENT $p (something inside was touched in the last ${TRANSCRIPT_AGE_DAYS}d)"
      continue
    fi
    kb=$(size_kb "$p"); kb=${kb:-0}
    if [ "$APPLY" = 1 ]; then
      if unlink_real "$p"; then
        t3=$((t3+1)); t3_kb=$((t3_kb+kb)); echo "RECLAIMED $p (${kb} KB)"
      else
        echo "FAILED $p"
      fi
    else
      t3=$((t3+1)); t3_kb=$((t3_kb+kb)); echo "WOULD-RECLAIM $p (${kb} KB)"
    fi
  done < <(find /root/.codex/sessions /root/.pi/agent/sessions /root/.minimax/v2 -maxdepth 2 -type d -mtime "+$TRANSCRIPT_AGE_DAYS" 2>/dev/null | sort | head -60)
  if [ "$APPLY" = 1 ]; then
    echo "tier 3: $t3 item(s) reclaimed, ${t3_kb} KB by the files' own size"
  else
    echo "tier 3: $t3 item(s) would be reclaimed, ${t3_kb} KB by the files' own size (a projection, NOT freed bytes)"
  fi
fi

# --- Tier 4: archive-class inventory ---------------------------------------------
# Cold, valuable, and NOT ours to delete. Measured so the Captain can decide
# where they go. Archival only frees space if the bytes leave this filesystem.
echo
echo "--- tier 4: archive-class inventory (reported, never deleted) ---"
for p in /srv/hd2-canonical-recovery /root/migration-0043 /root/DeightonLLM_hub-main.pre_restore_20260601_191307 \
         /root/.treehouse/lead-gen-saas-v3-first-install-ready-20260710-cf6f60 /opt/core-distro-staging/releases \
         /root/agent-work/firstmate-local-backup-stash-20261013 /root/.antigravity-ide-server /root/.local/share/Trash; do
  [ -e "$p" ] || continue
  printf '  %-72s %s\n' "$p" "$(size_kb "$p") KB"
done

echo
echo "--- result ---"
after_pct=$(disk_pct); after_kb=$(disk_avail_kb)
echo "disk after: ${after_pct}% used, ${after_kb} KB free"
if [ "$APPLY" = 1 ]; then
  delta=$((after_kb - before_kb))
  reclaimed_any=0
  [ "$t1" -gt 0 ] && reclaimed_any=1
  [ "$pruned" -gt 0 ] && reclaimed_any=1
  [ "$t3" -gt 0 ] && reclaimed_any=1
  [ "${lock_dirs:-0}" -gt 0 ] && reclaimed_any=1
  [ "${log_count:-0}" -gt 0 ] && reclaimed_any=1
  if [ "$reclaimed_any" = 0 ]; then
    # Nothing was reclaimed, so the df change over the window is NOT this
    # script's doing: the host's own concurrent activity moved the numbers.
    # Reporting that delta as "the reclaim freed X" would be the exact
    # "freedKB=340864" lie this script exists to prevent - a number that grew
    # while nothing was freed. Say what actually happened.
    if [ "$delta" -gt 0 ]; then
      echo "measured: the reclaim removed NOTHING. The filesystem shows ${delta} KB MORE free than at the start of the window, but that is concurrent host activity, not bytes this script freed. This script's own contribution is 0 KB."
    else
      echo "measured: the reclaim removed NOTHING (0 KB freed by this script). The filesystem shows ${delta} KB of net change over the window, which is concurrent host activity, not a reclaim."
    fi
  elif [ "$delta" -lt 0 ]; then
    # Honest negative: something else on the host consumed the space faster
    # than the reclaim freed it. Clamping this to zero would claim the reclaim
    # freed bytes it did not free, which is the exact "freedKB=340864" lie the
    # 97%-disk incident taught this script.
    echo "measured: the filesystem gave back NOTHING (df available FELL by $((0 - delta)) KB while the reclaim ran - other activity consumed the space at least as fast as the reclaim freed it). This script's own removal was ${t1_kb} KB by file size; the honest df reading is the negative one, not a claim of freed bytes."
  else
    echo "measured: the filesystem gave back ${delta} KB (df before/after, net over the reclaim window, not what the script believes it deleted)"
  fi
  echo "capacity: ${before_pct}% -> ${after_pct}% used"
  if [ "$t1" -eq 0 ] && [ "$pruned" -eq 0 ] && [ "$t3" -eq 0 ] \
     && [ "${lock_dirs:-0}" -eq 0 ] && [ "${log_count:-0}" -eq 0 ]; then
    echo "idempotent: tiers 1-3 had nothing left to reclaim."
  fi
else
  echo "dry run: nothing was changed. Re-run with --apply to act."
fi
exit 0
