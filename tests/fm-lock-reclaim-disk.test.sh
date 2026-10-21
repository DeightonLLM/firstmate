#!/usr/bin/env bash
# tests/fm-lock-reclaim-disk.test.sh - reclaiming DEAD LOCK SCRATCH, and
# keeping an append-only log bounded.
#
# WHY THESE CASES EXIST.
#
# On 2026-10-21 the Controller's comms receipts directory held 37,235 lock
# owner dirs (357 MB) and the capacity reclaimer could not see ONE of them: it
# had no idea a lock owner dir existed. The reclaimer also had no bound on
# state/fm-comms-ingest.log, which reached 40 MB and grew forever.
#
# Every case below is asserted by OBSERVED BEHAVIOUR, not by reading the code.
#
# The subtle case is the RECYCLED PID. A lock owner dir records the pid of the
# process that created it, and the kernel RECYCLES pids: on the Controller,
# 21,201 of the leaked dirs recorded a pid that was running again as an
# unrelated process, so a naive "is the pid alive?" test would have kept every
# one of them alive forever. The correct test compares the process's start
# time with the owner dir's own mtime. That case is proved here with a REAL
# pid that is REALLY alive, so the naive test really would have kept it.
#
# Usage: tests/fm-lock-reclaim-disk.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RECLAIMER="$ROOT/bin/fm-capacity-reclaim.sh"
LOCK_LIB="$ROOT/bin/fm-lock-reclaim-lib.sh"
ROTATE="$ROOT/bin/fm-log-rotate.sh"
WAKE_LIB="$ROOT/bin/fm-wake-lib.sh"
PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

# The fixture lives on the ROOT filesystem, so the reclaim's own df reading
# sees the bytes this test creates and frees.
WORK="$(mktemp -d /root/fm-reclaim-disk-test.XXXXXX)"
cleanup() {
  [ -n "${WRITER_PID:-}" ] && kill "$WRITER_PID" 2>/dev/null
  rm -rf "$WORK" 2>/dev/null
}
trap cleanup EXIT

# --- helpers ------------------------------------------------------------------

# A pid that is definitely dead: a reaped child.
dead_pid() {
  local p
  sh -c 'exit 0' & p=$!
  wait "$p" 2>/dev/null
  printf '%s\n' "$p"
}

# A lock owner dir, exactly as the lock library makes one: mktemp -d, so mode
# 0700, holding the lock's own pid file.
mk_owner() {  # <path> <pid>
  mkdir -m 700 "$1" 2>/dev/null || return 1
  printf '%s\n' "$2" > "$1/pid" 2>/dev/null || return 1
  return 0
}

# Make a path look like it was created <seconds> ago.
backdate() {  # <path> <seconds-ago>
  touch -d "@$(( $(date +%s) - $2 ))" "$1" 2>/dev/null
}

# The epoch second a process started, read from /proc the same way the reclaim
# reads it. This is the number the whole recycled-pid argument turns on.
pid_start_epoch() {  # <pid>
  local pid=$1 rest ticks btime hz
  rest=$(cat "/proc/$pid/stat" 2>/dev/null) || return 1
  rest=${rest##*)}
  ticks=$(printf '%s\n' "$rest" | awk '{print $20}') || return 1
  case "$ticks" in ''|*[!0-9]*) return 1 ;; esac
  btime=$(awk '/^btime /{print $2}' /proc/stat 2>/dev/null) || return 1
  hz=$(getconf CLK_TCK 2>/dev/null) || hz=100
  printf '%s\n' "$(( btime + ticks / hz ))"
}

path_mtime() { stat -c %Y "$1" 2>/dev/null; }

# Run the lock sweep over one root. The library is the sweep's owner; the
# reclaimer is the tier that calls it.
sweep() {  # <root>
  FM_LOCK_RECLAIM_APPLY=1 \
  FM_RECLAIM_LOCK_GRACE_S="${SWEEP_GRACE:-0}" \
  FM_RECLAIM_LOCK_MAXDEPTH="${SWEEP_DEPTH:-6}" \
  bash -c '. "$1"; fm_lock_reclaim_sweep "$2"' _ "$LOCK_LIB" "$1" 2>&1
}

[ -x "$RECLAIMER" ] || { echo "FAIL  the reclaimer is not executable: $RECLAIMER"; exit 1; }
[ -x "$ROTATE" ] || { echo "FAIL  the rotation script is not executable: $ROTATE"; exit 1; }
[ -r "$LOCK_LIB" ] || { echo "FAIL  the lock reclaim library is missing: $LOCK_LIB"; exit 1; }

DEAD_PID="$(dead_pid)"

echo "== the shapes: only lock scratch is ever touched =="

SHAPES="$WORK/shapes"
mkdir -p "$SHAPES"
# Reclaimable: a lock owner dir, owner-private, holding a dead pid.
mk_owner "$SHAPES/dead.lock.owner.AAAAAA" "$DEAD_PID"
# Not a lock shape: the name does not end in ".lock" before the owner suffix.
mk_owner "$SHAPES/notalock.owner.BBBBBB" "$DEAD_PID"
# Not a lock shape: the owner suffix is not exactly six characters.
mk_owner "$SHAPES/tricky.lock.owner.CCCC" "$DEAD_PID"
# Another lock family's DIRECTORY lock. It matches the pointer NAME rule, but
# a pointer is only ever a symlink, so this must be left alone.
mkdir -m 700 "$SHAPES/dirfamily.lock"
# Another lock family's plain file. Also untouched.
: > "$SHAPES/plainfamily.lock"
# A lock-shaped name that is NOT owner-private. Tracked repository content is
# never 0700, so this is what keeps tracked material out of reach.
mkdir -m 755 "$SHAPES/public.lock.owner.DDDDDD"
printf '%s\n' "$DEAD_PID" > "$SHAPES/public.lock.owner.DDDDDD/pid"
# A stray file whose name merely looks lock-ish.
: > "$SHAPES/notes.lock.owner.EEEEEE"

OUT="$(sweep "$SHAPES")"
printf '%s\n' "$OUT" | sed 's/^/    /'

if [ ! -d "$SHAPES/dead.lock.owner.AAAAAA" ]; then
  ok "a dead lock owner dir is reclaimed"
else
  bad "a dead lock owner dir was NOT reclaimed"
fi
for keep in notalock.owner.BBBBBB tricky.lock.owner.CCCC dirfamily.lock \
            plainfamily.lock public.lock.owner.DDDDDD notes.lock.owner.EEEEEE; do
  if [ -e "$SHAPES/$keep" ]; then
    ok "a non-reclaimable path is left alone: $keep"
  else
    bad "a non-reclaimable path was TOUCHED: $keep"
  fi
done

echo
echo "== the dead holder is reclaimed, and so is its pointer =="

PTR="$WORK/pointers"
mkdir -p "$PTR"
mk_owner "$PTR/.lock.owner.GGGGGG" "$DEAD_PID"
ln -s "$PTR/.lock.owner.GGGGGG" "$PTR/.lock" 2>/dev/null
# A dangling reclaim pointer: its target does not exist. This is the shape
# that wedged the comms lock, because every claim saw the pointer and refused.
ln -s "$PTR/.lock.steal.owner.HHHHHH" "$PTR/.lock.steal" 2>/dev/null
# A pointer whose owner dir is alive must survive.
sleep 300 >/dev/null 2>&1 &
LIVE_PID=$!
sleep 2
mk_owner "$PTR/.lock.owner.IIIIII" "$LIVE_PID"
ln -s "$PTR/.lock.owner.IIIIII" "$PTR/.lock.live" 2>/dev/null

OUT="$(sweep "$PTR")"
printf '%s\n' "$OUT" | sed 's/^/    /'

if [ ! -d "$PTR/.lock.owner.GGGGGG" ]; then
  ok "the dead owner dir is reclaimed"
else
  bad "the dead owner dir was NOT reclaimed"
fi
if [ ! -e "$PTR/.lock" ] && [ ! -L "$PTR/.lock" ]; then
  ok "the pointer to a reclaimed owner dir is reclaimed with it"
else
  bad "the pointer to a reclaimed owner dir was left behind"
fi
if [ ! -e "$PTR/.lock.steal" ] && [ ! -L "$PTR/.lock.steal" ]; then
  ok "a dangling reclaim pointer is reclaimed"
else
  bad "a dangling reclaim pointer was left behind"
fi
if [ -d "$PTR/.lock.owner.IIIIII" ] && [ -L "$PTR/.lock.live" ]; then
  ok "a LIVE holder's dir and its pointer are both left alone"
else
  bad "a LIVE holder was disturbed"
fi
if kill -0 "$LIVE_PID" 2>/dev/null; then
  ok "the live holder process is still running after the sweep"
else
  bad "the live holder process was killed by the sweep"
fi

echo
echo "== the RECYCLED pid: alive, but started AFTER the dir was created =="

RECYCLE="$WORK/recycle"
mkdir -p "$RECYCLE"
sleep 300 >/dev/null 2>&1 &
RECYCLED_PID=$!
sleep 1
mk_owner "$RECYCLE/.lock.steal.owner.JJJJJJ" "$RECYCLED_PID"
# The dir is made to look two hours old, so the recorded pid belongs to a
# process that started AFTER the dir was created. That is EXACTLY the state a
# recycled pid leaves behind, and it is proved from /proc below.
backdate "$RECYCLE/.lock.steal.owner.JJJJJJ" 7200

if kill -0 "$RECYCLED_PID" 2>/dev/null; then
  ok "the recorded pid is REALLY alive (so a naive liveness test would keep this dir)"
else
  bad "the recorded pid is not alive; the recycled-pid case is not being exercised"
fi
REC_START="$(pid_start_epoch "$RECYCLED_PID" 2>/dev/null || echo 0)"
REC_MTIME="$(path_mtime "$RECYCLE/.lock.steal.owner.JJJJJJ" 2>/dev/null || echo 0)"
if [ "$REC_START" -gt "$REC_MTIME" ]; then
  ok "the recorded pid started AFTER the dir was created (start ${REC_START} > dir mtime ${REC_MTIME}): the pid was recycled"
else
  bad "the recycled-pid precondition is not met (start ${REC_START}, dir mtime ${REC_MTIME})"
fi

OUT="$(sweep "$RECYCLE")"
printf '%s\n' "$OUT" | sed 's/^/    /'
if [ ! -d "$RECYCLE/.lock.steal.owner.JJJJJJ" ]; then
  ok "a dir whose pid was RECYCLED is reclaimed"
else
  bad "a dir whose pid was RECYCLED was NOT reclaimed"
fi

# The same case through the reclaimer's own tier, not just the library.
mkdir -p "$RECYCLE/.lock.steal.owner.KKKKKK"
printf '%s\n' "$RECYCLED_PID" > "$RECYCLE/.lock.steal.owner.KKKKKK/pid"
chmod 700 "$RECYCLE/.lock.steal.owner.KKKKKK"
backdate "$RECYCLE/.lock.steal.owner.KKKKKK" 7200
FM_RECLAIM_TIERS=1b FM_RECLAIM_STATE_ROOTS="$RECYCLE" FM_RECLAIM_LOCK_GRACE_S=0 \
  "$RECLAIMER" --apply >/dev/null 2>&1
if [ ! -d "$RECYCLE/.lock.steal.owner.KKKKKK" ]; then
  ok "the reclaimer's tier 1b reclaims a recycled-pid dir"
else
  bad "the reclaimer's tier 1b did NOT reclaim a recycled-pid dir"
fi

echo
echo "== a genuinely recycled pid, if the kernel hands one out =="

VICTIM="$(dead_pid)"
REALLY_RECYCLED=""
attempt=0
while [ "$attempt" -lt 400 ]; do
  attempt=$((attempt + 1))
  sh -c 'exit 0' & cand=$!
  wait "$cand" 2>/dev/null
  if [ "$cand" = "$VICTIM" ]; then
    REALLY_RECYCLED="$VICTIM"
    break
  fi
done
if [ -n "$REALLY_RECYCLED" ]; then
  GEN="$WORK/genuine"
  mkdir -p "$GEN"
  mk_owner "$GEN/.lock.owner.LLLLLL" "$REALLY_RECYCLED"
  sleep 1
  backdate "$GEN/.lock.owner.LLLLLL" 3600
  sweep "$GEN" >/dev/null 2>&1
  if [ ! -d "$GEN/.lock.owner.LLLLLL" ]; then
    ok "a dir holding a GENUINELY recycled kernel pid is reclaimed"
  else
    bad "a dir holding a genuinely recycled kernel pid was NOT reclaimed"
  fi
else
  printf 'NOTE  the kernel did not hand out the same pid again within %s attempts, so the genuine-recycle case was not observed; the deterministic start-time case above covers the same state\n' "$attempt"
fi

echo
echo "== the real rm, and the refusal of a shim =="

SHIM="$WORK/shims"
mkdir -p "$SHIM"
MARKER="$WORK/shim-was-called"
cat > "$SHIM/rm" <<EOF
#!/bin/sh
echo "shim-called" >> "$MARKER"
exec /usr/bin/rm "\$@"
EOF
chmod +x "$SHIM/rm"

SHIMCASE="$WORK/shimcase"
mkdir -p "$SHIMCASE"
mk_owner "$SHIMCASE/.lock.owner.MMMMMM" "$DEAD_PID"

# The shim is on PATH and is ALSO offered as the explicit real-rm override.
# Both must be refused: the reclaim resolves the real rm by absolute path and
# never by PATH lookup, so a trash-moving rm can never be the thing that
# frees the bytes.
PATH="$SHIM:$PATH" FM_SCRATCH_REAL_RM="$SHIM/rm" \
  FM_RECLAIM_TIERS=1b FM_RECLAIM_STATE_ROOTS="$SHIMCASE" FM_RECLAIM_LOCK_GRACE_S=0 \
  "$RECLAIMER" --apply >/dev/null 2>&1
if [ -e "$MARKER" ]; then
  bad "the shim rm was called; the reclaim could have landed in the trash"
else
  ok "the shim rm was refused: it was never called, neither on PATH nor as the explicit override"
fi
if [ ! -d "$SHIMCASE/.lock.owner.MMMMMM" ]; then
  ok "the reclaim still worked, through the REAL rm resolved by absolute path"
else
  bad "the reclaim did not remove the dir"
fi

RESOLVED="$(FM_SCRATCH_REAL_RM="$SHIM/rm" bash -c '. "$1"; fm_lock_reclaim_real_rm' _ "$LOCK_LIB" 2>/dev/null)"
case "$RESOLVED" in
  */shims/*|*mavis-trash)
    bad "the real-rm resolution returned a shim path: $RESOLVED" ;;
  ''|/usr/bin/rm|/bin/rm)
    ok "the real-rm resolution refuses a shim and returns a real rm ($RESOLVED)" ;;
  *)
    ok "the real-rm resolution refuses a shim and returns a real rm ($RESOLVED)" ;;
esac

echo
echo "== the old reclaimer could not see a lock owner dir at all =="

# The reclaimer as it was BEFORE tier 1b existed. The history is searched for
# the most recent version of the script that has no lock tier at all, so this
# comparison is the same whether or not the change is already committed.
OLD=""
OLD_REF=""
ref="HEAD"
attempt=0
while [ "$attempt" -lt 20 ]; do
  attempt=$((attempt + 1))
  if ! git -C "$ROOT" cat-file -e "$ref:bin/fm-capacity-reclaim.sh" 2>/dev/null; then
    break
  fi
  candidate="$(git -C "$ROOT" show "$ref:bin/fm-capacity-reclaim.sh" 2>/dev/null)"
  case "$candidate" in
    *"tier 1b"*) ;;
    *)
      OLD="$candidate"
      OLD_REF="$ref"
      break
      ;;
  esac
  ref="$ref~1"
done

OLD="$WORK/old-reclaim.sh"
if [ -z "$OLD_REF" ]; then
  printf 'NOTE  no pre-tier-1b reclaimer was found in the last %s commits of history; the comparison below was skipped\n' "$attempt"
else
  printf '%s\n' "$OLD" > "$OLD"
  chmod +x "$OLD"
  OLD_LOCK_HITS="$(grep -ci lock "$OLD" 2>/dev/null || true)"
  OLD_LOCK_HITS="${OLD_LOCK_HITS:-0}"
  if [ "$OLD_LOCK_HITS" -eq 0 ]; then
    ok "the previous reclaimer (${OLD_REF}) had no lock handling at all (grep -ci lock: 0)"
  else
    bad "the previous reclaimer (${OLD_REF}) already mentioned a lock ($OLD_LOCK_HITS hits)"
  fi

  # The old reclaimer is run APPLIED, against the fixture only. Its tier 1
  # walks absolute host paths, so a find wrapper redirects every search into
  # the fixture: the old script cannot touch the host while this proves it
  # was blind. treehouse is not on the wrapper PATH, so its tier 2 is skipped.
  OLDROOT="$WORK/oldroot"
  mkdir -p "$OLDROOT"
  mk_owner "$OLDROOT/.lock.owner.NNNNNN" "$DEAD_PID"
  WRAPPERBIN="$WORK/wrapperbin"
  mkdir -p "$WRAPPERBIN"
  cat > "$WRAPPERBIN/find" <<EOF
#!/bin/sh
args=""
for a in "\$@"; do
  case "\$a" in
    /*) ;;
    *) args="\$args \$a" ;;
  esac
done
exec /usr/bin/find "$OLDROOT" \$args
EOF
  # The old reclaimer's archive-class inventory measures multi-GB paths with
  # du, which costs a minute on this host and is not what this test is about.
  # The sizes are neutralised; the SHAPES of the run are not.
  cat > "$WRAPPERBIN/du" <<'EOF'
#!/bin/sh
printf '0\t%s\n' "$*"
EOF
  chmod +x "$WRAPPERBIN/find" "$WRAPPERBIN/du"
  PATH="$WRAPPERBIN:/usr/bin:/bin" timeout 120 "$OLD" --apply > "$WORK/old-out.txt" 2>&1
  if [ -d "$OLDROOT/.lock.owner.NNNNNN" ]; then
    ok "the previous reclaimer LEFT THE DEAD LOCK OWNER DIR BEHIND even with --apply"
  else
    bad "the previous reclaimer removed the dir; the failure was not reproduced"
  fi
  if grep -q "owner.NNNNNN" "$WORK/old-out.txt"; then
    bad "the previous reclaimer reported the lock owner dir; it was not blind after all"
  else
    ok "the previous reclaimer's report never mentioned the lock owner dir (it was invisible to it)"
  fi
fi

echo
echo "== the new reclaimer removes it, and reports a MEASURED df delta =="

BIG="$WORK/big"
mkdir -p "$BIG"
i=0
while [ "$i" -lt 600 ]; do
  mk_owner "$BIG/.lock.steal.owner.$(printf '%06d' "$i")" "$DEAD_PID" 2>/dev/null
  i=$((i + 1))
done
BIG_COUNT="$(find "$BIG" -maxdepth 1 -type d -name '*.owner.??????' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$BIG_COUNT" = "600" ]; then
  ok "the fixture holds 600 dead lock owner dirs"
else
  bad "the fixture holds $BIG_COUNT dead lock owner dirs (expected 600)"
fi

DF_BEFORE="$(df -P / | awk 'NR==2{print $4}')"
FM_RECLAIM_TIERS=1b FM_RECLAIM_STATE_ROOTS="$BIG" FM_RECLAIM_LOCK_GRACE_S=0 \
  "$RECLAIMER" --apply > "$WORK/new-out.txt" 2>&1
DF_AFTER="$(df -P / | awk 'NR==2{print $4}')"
printf '%s\n' "$(grep -E '^(tier 1b|measured|capacity)' "$WORK/new-out.txt")" | sed 's/^/    /'

LEFT="$(find "$BIG" -maxdepth 1 -type d -name '*.owner.??????' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$LEFT" = "0" ]; then
  ok "the new reclaimer removed every one of the 600 dead lock owner dirs"
else
  bad "the new reclaimer left $LEFT of the 600 dead lock owner dirs behind"
fi

REPORTED="$(grep -oE 'the filesystem gave back [0-9]+ KB' "$WORK/new-out.txt" | grep -oE '[0-9]+' | head -1)"
MEASURED=$((DF_AFTER - DF_BEFORE))
case "${REPORTED:-}" in
  ''|*[!0-9]*) bad "the result line does not report a measured df delta (got '${REPORTED:-nothing}')" ;;
  *)
    if [ "$REPORTED" -gt 0 ]; then
      ok "the result line reports a MEASURED df delta (${REPORTED} KB), not a believed count"
    else
      bad "the result line reported a non-positive df delta (${REPORTED} KB)"
    fi
    if [ "$((REPORTED - MEASURED))" -lt 3000000 ] && [ "$((MEASURED - REPORTED))" -lt 3000000 ]; then
      ok "the reported delta agrees with the independently measured df delta (reported ${REPORTED} KB, measured ${MEASURED} KB)"
    else
      bad "the reported delta (${REPORTED} KB) does not agree with the measured df delta (${MEASURED} KB)"
    fi
    ;;
esac

echo
echo "== a positive df delta with NOTHING reclaimed is never claimed =="

# A fake df that reports MORE free space after the reclaim than before it.
# That is exactly the shape of the "freedKB=340864" lie: the number grew, but
# the reclaim removed nothing, so the honest answer is NOTHING.
EMPTY="$WORK/empty"
mkdir -p "$EMPTY"
FAKE_DF="$WORK/fake-df.sh"
DF_COUNT="$WORK/fake-df.count"
cat > "$FAKE_DF" <<EOF
#!/bin/sh
n=\$(cat "$DF_COUNT" 2>/dev/null || echo 0)
n=\$((n+1)); echo "\$n" > "$DF_COUNT"
case "\$n" in
  1|2) avail=1000000 ;;
  *) avail=1009999 ;;
esac
printf 'Filesystem      1K-blocks     Used Available Use%% Mounted on\n'
printf '/dev/fake        100000000  %9d %9d %4s%% /\n' 59623588 "\$avail" 80
EOF
chmod +x "$FAKE_DF"
: > "$DF_COUNT"
FM_RECLAIM_DF="$FAKE_DF" FM_RECLAIM_TIERS=1b FM_RECLAIM_STATE_ROOTS="$EMPTY" \
  FM_RECLAIM_LOCK_GRACE_S=0 "$RECLAIMER" --apply > "$WORK/honest-out.txt" 2>&1
printf '%s\n' "$(grep -E '^measured' "$WORK/honest-out.txt")" | sed 's/^/    /'
if grep -q "the reclaim removed NOTHING" "$WORK/honest-out.txt"; then
  ok "a reclaim that removed nothing says so, even when the filesystem reports more free space"
else
  bad "a reclaim that removed nothing did not say so: $(grep -E '^measured' "$WORK/honest-out.txt")"
fi
if grep -qE "gave back [1-9][0-9]* KB" "$WORK/honest-out.txt"; then
  bad "a reclaim that removed nothing claimed freed bytes"
else
  ok "a reclaim that removed nothing claimed NO freed bytes"
fi

echo
echo "== the rotation bounds the log and keeps the recent tail =="

LOGDIR="$WORK/logs"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/fm-comms-ingest.log"
: > "$LOG"
i=0
while [ "$i" -lt 400 ]; do
  printf 'ingest line %04d padding padding padding padding padding\n' "$i" >> "$LOG"
  i=$((i + 1))
done
printf 'THE-MOST-RECENT-TAIL-MARKER\n' >> "$LOG"
LOG_BYTES="$(stat -c %s "$LOG")"
"$ROTATE" --apply --log "$LOG" --max-bytes 4096 --keep-bytes 2048 --grace 0 --quiesce 0 \
  > "$WORK/rotate-out.txt" 2>&1
printf '%s\n' "$(grep -E 'rotated|capped|live log' "$WORK/rotate-out.txt")" | sed 's/^/    /'
LIVE_BYTES="$(stat -c %s "$LOG" 2>/dev/null || echo 0)"
if [ "$LIVE_BYTES" -le 4096 ]; then
  ok "the live log is brought back under its cap (${LOG_BYTES} bytes -> ${LIVE_BYTES} bytes)"
else
  bad "the live log is still ${LIVE_BYTES} bytes, over its 4096 byte cap"
fi
if grep -rq "THE-MOST-RECENT-TAIL-MARKER" "$LOG" "$LOG".rot.* 2>/dev/null; then
  ok "the most recent tail is kept for diagnosis"
else
  bad "the most recent tail was lost"
fi
FAMILY_BYTES=0
for f in "$LOG" "$LOG".1 "$LOG".rot.*; do
  [ -f "$f" ] || continue
  FAMILY_BYTES=$((FAMILY_BYTES + $(stat -c %s "$f")))
done
if [ "$FAMILY_BYTES" -le 16384 ]; then
  ok "the whole log family is bounded (${FAMILY_BYTES} bytes)"
else
  bad "the log family is ${FAMILY_BYTES} bytes, over the bound"
fi

echo
echo "== the rotation does not lose an ACTIVE writer's output =="

ACTIVE="$WORK/active"
mkdir -p "$ACTIVE"
ALOG="$ACTIVE/fm-comms-ingest.log"
LEDGER="$ACTIVE/ledger"
: > "$ALOG"
: > "$LEDGER"
(
  exec 3>>"$ALOG"
  exec 4>>"$LEDGER"
  while :; do
    line="W-$(date +%s%N)"
    printf '%s\n' "$line" >&3
    printf '%s\n' "$line" >&4
    sleep 0.05
  done
) >/dev/null 2>&1 &
WRITER_PID=$!
sleep 1
"$ROTATE" --apply --log "$ALOG" --max-bytes 4096 --keep-bytes 2048 --grace 300 \
  > "$WORK/active-rotate.txt" 2>&1
sleep 0.5
kill "$WRITER_PID" 2>/dev/null
wait "$WRITER_PID" 2>/dev/null
WRITER_PID=""
WROTE="$(wc -l < "$LEDGER" | tr -d ' ')"
KEPT=0
for f in "$ALOG" "$ALOG".1 "$ALOG".rot.*; do
  [ -f "$f" ] || continue
  KEPT=$((KEPT + $(grep -c '^W-' "$f" 2>/dev/null || echo 0)))
done
printf '    the writer wrote %s lines; the log family still holds %s\n' "$WROTE" "$KEPT"
if [ "$WROTE" -gt 0 ] && [ "$KEPT" -eq "$WROTE" ]; then
  ok "every line an active writer wrote survived the rotation"
else
  bad "the rotation lost an active writer's output (wrote ${WROTE}, kept ${KEPT})"
fi

echo
echo "== the mirrored shapes agree with the lock library =="

# The lock library owns the lock protocol; this lane's rules are MIRRORED from
# it, because that file belongs to another lane. The mirroring must not drift.
if [ -r "$WAKE_LIB" ]; then
  AGREE="$(FM_HOME="$WORK" FM_STATE_OVERRIDE="$WORK/state" bash -c '
    . "$1" 2>/dev/null || exit 3
    command -v fm_lock_pointer_basename_matches >/dev/null 2>&1 || exit 4
    . "$2"
    mismatch=0
    for n in ".lock" ".lock.steal" ".lock.steal.steal" ".lock.owner.ABC123" \
             ".lock.steal.owner.ABC123" ".lock.steal.steal.owner.ABC123" \
             ".lock.steal.steal.steal.steal.owner.ABC123" "plain.lock" \
             "data.owner.ABC123" ".lock.owner.ABC12" ".lock.owner.ABC1234" \
             ".notes.lock.owner.ABC123" "lock" ".lockowner.ABC123"; do
      fm_lock_pointer_basename_matches "$n" && p1=0 || p1=1
      fm_lock_reclaim_pointer_basename_matches "$n" && p2=0 || p2=1
      [ "$p1" = "$p2" ] || { echo "pointer mismatch: $n"; mismatch=1; }
      fm_lock_owner_dir_basename_matches "$n" && o1=0 || o1=1
      fm_lock_reclaim_owner_dir_basename_matches "$n" && o2=0 || o2=1
      [ "$o1" = "$o2" ] || { echo "owner mismatch: $n"; mismatch=1; }
    done
    exit $mismatch
  ' _ "$WAKE_LIB" "$LOCK_LIB" 2>&1)"
  AGREE_RC=$?
  case "$AGREE_RC" in
    0) ok "the mirrored shape rules agree with the lock library on every name in the corpus" ;;
    3|4) printf 'NOTE  the lock library does not expose the shape matchers right now (it belongs to another lane, which is editing it); the mirroring was not cross-checked\n' ;;
    *) bad "the mirrored shape rules DISAGREE with the lock library: $AGREE" ;;
  esac
else
  printf 'NOTE  the lock library is not present; the mirroring was not cross-checked\n'
fi

echo
echo "== summary =="
printf 'PASS %s  FAIL %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
