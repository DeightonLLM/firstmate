#!/usr/bin/env bash
# tests/fm-lock-reclaim-acquire-family.test.sh - the ".lock.acquire" owner-dir
# family must be RECLAIMABLE, and a LIVE holder must still be refused.
#
# WHY THIS CASE EXISTS.
#
# On 2026-10-23 the session lock's claim mutex (state/.lock.acquire) stayed
# wedged behind a dead holder pid (3974499). Every session start then ran
# read-only, the watcher was never re-armed, and the to-do board froze for
# 15.6 hours.
#
# The cause was NOT the deadness proof. fm_lock_reclaim_holder_state_set
# compares the recorded pid's START TIME against the owner dir's own mtime, and
# that test is sound: a holder that started before the dir it created is still
# alive, and a pid that was recycled reads as dead.
#
# The cause was the NAME MATCHER. Both bin/fm-lock-reclaim-lib.sh and
# bin/fm-wake-lib.sh matched lock names through a helper that only accepted a
# basename ENDING in ".lock" (the case arms were *.lock, then *.steal, then a
# refusal). The claim mutex is named ".lock.acquire", so the whole family
# (.lock.acquire.owner.XXXXXX, .lock.acquire.steal.owner.XXXXXX, ...) matched
# NO arm at all. The sweep found 0 candidates while state/ held 1,932 dead
# owner dirs, and every failed claim added one more ".steal" level, so the
# wedge deepened with every attempt.
#
# Every case below is asserted by OBSERVED BEHAVIOUR of the sweep, not by
# reading the code.
#
# Usage: tests/fm-lock-reclaim-acquire-family.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_LIB="$ROOT/bin/fm-lock-reclaim-lib.sh"
WAKE_LIB="$ROOT/bin/fm-wake-lib.sh"
PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/fm-lock-acquire-family.XXXXXX")" \
  || { printf 'FAIL  could not create a work directory\n'; exit 1; }
cleanup() {
  [ -n "${LIVE_PID:-}" ] && kill "$LIVE_PID" 2>/dev/null
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

# Run the lock sweep over one root. The library is the sweep's owner; the
# reclaimer is the tier that calls it.
sweep() {  # <root>
  FM_LOCK_RECLAIM_APPLY=1 \
  FM_RECLAIM_LOCK_GRACE_S="${SWEEP_GRACE:-0}" \
  FM_RECLAIM_LOCK_MAXDEPTH="${SWEEP_DEPTH:-6}" \
  bash -c '. "$1"; fm_lock_reclaim_sweep "$2"' _ "$LOCK_LIB" "$1" 2>&1
}

[ -r "$LOCK_LIB" ] || { printf 'FAIL  the lock reclaim library is missing: %s\n' "$LOCK_LIB"; exit 1; }

DEAD_PID="$(dead_pid)"

echo "== the matcher recognises the .lock.acquire family =="

# The name shape is the defect: the claim mutex is ".lock.acquire", so the
# owner dirs are ".lock.acquire.owner.XXXXXX" and, one reclaim level down,
# ".lock.acquire.steal.owner.XXXXXX". Both libraries must recognise those, and
# both must still refuse a name that is not a lock owner directory at all.
#
# The two libraries are MIRRORED, not shared, so they are cross-checked here
# on the same corpus: the mirroring must not drift.
SHAPES_OUT="$(FM_HOME="$WORK" FM_STATE_OVERRIDE="$WORK/state" bash -c '
  . "$1" 2>/dev/null || exit 3
  command -v fm_lock_pointer_basename_matches >/dev/null 2>&1 || exit 4
  . "$2"
  mismatch=0
  for n in ".lock" ".lock.steal" ".lock.steal.steal" \
           ".lock.acquire" ".lock.acquire.steal" ".lock.acquire.steal.steal" \
           ".lock.owner.ABC123" ".lock.steal.owner.ABC123" \
           ".lock.acquire.owner.ABC123" ".lock.acquire.steal.owner.ABC123" \
           ".lock.acquire.steal.steal.owner.ABC123" \
           "plain.lock" "notes.lock.owner.ABC123"; do
    fm_lock_pointer_basename_matches "$n" && p1=0 || p1=1
    fm_lock_reclaim_pointer_basename_matches "$n" && p2=0 || p2=1
    [ "$p1" = "$p2" ] || { echo "pointer mismatch: $n"; mismatch=1; }
    fm_lock_owner_dir_basename_matches "$n" && o1=0 || o1=1
    fm_lock_reclaim_owner_dir_basename_matches "$n" && o2=0 || o2=1
    [ "$o1" = "$o2" ] || { echo "owner mismatch: $n"; mismatch=1; }
  done
  exit $mismatch
' _ "$WAKE_LIB" "$LOCK_LIB" 2>&1)"
SHAPES_RC=$?
case "$SHAPES_RC" in
  0) ok "the mirrored shape rules agree with the lock library on every name in the corpus" ;;
  3|4) printf 'FAIL  the lock library does not expose the shape matchers\n' ;;
  *) bad "the mirrored shape rules DISAGREE with the lock library: $SHAPES_OUT" ;;
esac

matcher_says() {  # <fn-prefix> <name>  -> prints yes|no
  FM_HOME="$WORK" FM_STATE_OVERRIDE="$WORK/state" bash -c '
    . "$1" 2>/dev/null || exit 3
    . "$2"
    if "$3" "$4"; then printf "yes"; else printf "no"; fi
  ' _ "$WAKE_LIB" "$LOCK_LIB" "$1" "$2"
}

for pair in \
  "fm_lock_owner_dir_basename_matches:.lock.acquire.owner.ABC123" \
  "fm_lock_owner_dir_basename_matches:.lock.acquire.steal.owner.ABC123" \
  "fm_lock_owner_dir_basename_matches:.lock.acquire.steal.steal.owner.ABC123" \
  "fm_lock_owner_dir_basename_matches:.lock.owner.ABC123" \
  "fm_lock_owner_dir_basename_matches:.lock.steal.owner.ABC123" \
  "fm_lock_pointer_basename_matches:.lock.acquire" \
  "fm_lock_pointer_basename_matches:.lock.acquire.steal" \
  "fm_lock_pointer_basename_matches:.lock" ; do
  fn="${pair%%:*}"; name="${pair#*:}"
  if [ "$(matcher_says "$fn" "$name")" = "yes" ]; then
    ok "the matcher accepts $name"
  else
    bad "the matcher REFUSES $name (the .lock.acquire family is invisible)"
  fi
done

for pair in \
  "fm_lock_owner_dir_basename_matches:not-a-lock-owner-dir" \
  "fm_lock_owner_dir_basename_matches:notalock.owner.BBBBBB" \
  "fm_lock_owner_dir_basename_matches:data.owner.ABC123" \
  "fm_lock_owner_dir_basename_matches:.lockowner.ABC123" \
  "fm_lock_owner_dir_basename_matches:.lock.acquire.owner.ABC12" \
  "fm_lock_owner_dir_basename_matches:.lock.acquire.owner.ABC1234" \
  "fm_lock_pointer_basename_matches:not-a-lock-pointer" \
  "fm_lock_pointer_basename_matches:lock.acquire" ; do
  fn="${pair%%:*}"; name="${pair#*:}"
  if [ "$(matcher_says "$fn" "$name")" = "yes" ]; then
    bad "the matcher ACCEPTS $name (a name that is not a lock owner directory)"
  else
    ok "the matcher refuses $name"
  fi
done

echo
echo "== the sweep FINDS a dead owner dir in the .lock.acquire family =="

FAM="$WORK/family"
mkdir -p "$FAM"
# The claim mutex's own owner dir, and the reclaim level below it. Both are
# the shape the sweep used to miss entirely.
mk_owner "$FAM/.lock.acquire.owner.AAAAAA" "$DEAD_PID"
mk_owner "$FAM/.lock.acquire.steal.owner.BBBBBB" "$DEAD_PID"
mk_owner "$FAM/.lock.acquire.steal.steal.owner.CCCCCC" "$DEAD_PID"
# Not a lock owner directory at all: the name must never be touched.
mk_owner "$FAM/notalock.owner.DDDDDD" "$DEAD_PID"
# A lock owner dir that is NOT owner-private. Tracked repository content is
# never 0700, so this is what keeps tracked material out of reach.
mkdir -m 755 "$FAM/.lock.acquire.owner.EEEEEE"
printf '%s\n' "$DEAD_PID" > "$FAM/.lock.acquire.owner.EEEEEE/pid"

OUT="$(sweep "$FAM")"
printf '%s\n' "$OUT" | sed 's/^/    /'

for gone in .lock.acquire.owner.AAAAAA .lock.acquire.steal.owner.BBBBBB \
            .lock.acquire.steal.steal.owner.CCCCCC ; do
  if [ ! -d "$FAM/$gone" ]; then
    ok "a dead owner dir in the .lock.acquire family is reclaimed: $gone"
  else
    bad "a dead owner dir in the .lock.acquire family was NOT reclaimed: $gone"
  fi
done

for keep in notalock.owner.DDDDDD .lock.acquire.owner.EEEEEE ; do
  if [ -e "$FAM/$keep" ]; then
    ok "a path that is not a reclaimable lock owner dir is left alone: $keep"
  else
    bad "a path that is not a reclaimable lock owner dir was TOUCHED: $keep"
  fi
done

echo
echo "== the sweep REFUSES a live holder in the .lock.acquire family =="

LIVE="$WORK/live"
mkdir -p "$LIVE"
# A REAL live process, started BEFORE the dir is created, so its start time is
# older than the dir's mtime and the deadness proof reads it as live.
sleep 300 >/dev/null 2>&1 &
LIVE_PID=$!
sleep 2
mk_owner "$LIVE/.lock.acquire.owner.FFFFFF" "$LIVE_PID"
# A dead one beside it, so the sweep has both to tell apart.
mk_owner "$LIVE/.lock.acquire.owner.GGGGGG" "$DEAD_PID"

OUT="$(sweep "$LIVE")"
printf '%s\n' "$OUT" | sed 's/^/    /'

if [ -d "$LIVE/.lock.acquire.owner.FFFFFF" ]; then
  ok "a LIVE holder in the .lock.acquire family is refused"
else
  bad "a LIVE holder in the .lock.acquire family was TOUCHED"
fi
if [ ! -d "$LIVE/.lock.acquire.owner.GGGGGG" ]; then
  ok "the dead holder beside the live one is reclaimed"
else
  bad "the dead holder beside the live one was NOT reclaimed"
fi

echo
echo "== summary =="
printf 'PASS %s  FAIL %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
