#!/usr/bin/env bash
# tests/fm-claim-lock-shape.test.sh - the claim lock must be a LOCK SHAPE.
#
# Why this suite exists (item session-claim-lock-shape-fix-20261024):
# bin/fm-lock.sh claimed the session-lock mutex through "$STATE/.lock.acquire".
# Every lock-shape matcher in the fleet requires the basename to END IN
# ".lock" (fm_lock_pointer_basename_matches and fm_lock_owner_dir_basename_matches
# in bin/fm-wake-lib.sh, and the mirrored pair in bin/fm-lock-reclaim-lib.sh),
# so a claim lock named ".lock.acquire" was invisible to all of them. Two
# things followed:
#
#   1. fm_lock_release could not unlink it. fm_lock_purge_own refuses a path
#      whose shape it does not recognise, so the pointer SURVIVED its own
#      release as a dangling symlink beside a discarded owner dir, and the
#      wedge re-formed after every session.
#   2. Nothing could collect it afterwards: not the scratch purge, not the
#      owner-dir discard, not the dead-lock reclaimer.
#
# What this suite PROVES:
#   1. The claim lock's basename ends in ".lock", and every shape matcher in
#      BOTH implementation families accepts it and its owner dir.
#   2. The old name is still rejected by those matchers, so the defect
#      cannot come back silently.
#   3. A claim lock that is taken and then RELEASED leaves no pointer and no
#      owner dir behind, and the purge really unlinks a claim-lock pointer.
#   4. A dead claim lock is reclaimable by the outside reclaimer - which is
#      exactly what it was not before the rename.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOCK_LIB="$ROOT/bin/fm-wake-lib.sh"
RECLAIM_LIB="$ROOT/bin/fm-lock-reclaim-lib.sh"
LOCK_SCRIPT="$ROOT/bin/fm-lock.sh"
STARTUP_NETWORK="$ROOT/bin/fm-startup-network.sh"

# The claim-lock basename, read from the production definition rather than
# repeated here, so this suite cannot pass while the code says otherwise.
claim_lock_basename() {
  # The sed script must match the literal "$STATE/" in the source, so the
  # single quotes are deliberate.
  # shellcheck disable=SC2016
  sed -n 's/^CLAIM_LOCK="\$STATE\/\([^"]*\)"$/\1/p' "$LOCK_SCRIPT" | head -1
}

# --- case dirs ---------------------------------------------------------------
#
# The case dirs live under the repo's own gitignored state/ directory, NOT
# under /tmp. That placement is load-bearing: bin/fm-scratch-lib.sh accepts
# ANY path inside a system temp root (its rule T1), so a /tmp-based test
# never exercises the scratch-shape rules at all and the defect under test
# would not reproduce. The claim lock lives under a fleet home's state/
# directory, which is not a temp root, and that is where the pointer became
# unremovable.
CLAIM_SHAPE_CASE_DIRS=()
CLAIM_SHAPE_DIR=
# shellcheck disable=SC2329 # Registered by the EXIT and signal traps below.
cleanup_claim_shape() {
  local d
  for d in "${CLAIM_SHAPE_CASE_DIRS[@]:-}"; do
    [ -n "$d" ] && fm_purge_scratch --root "$ROOT/state" "$d" 2>/dev/null
  done
  fm_test_cleanup
}
trap cleanup_claim_shape EXIT
trap 'cleanup_claim_shape; exit 130' INT TERM

# make_case <name>: a private state dir plus a scratch area.
# Published in CLAIM_SHAPE_DIR, not on stdout: a command substitution would
# run make_case in a subshell and the case dir would never reach the
# registration array, leaking one dir per case per run.
make_case() {
  local name=$1
  # A fresh worktree has no state/ directory yet; the main checkout does.
  mkdir -p "$ROOT/state"
  CLAIM_SHAPE_DIR=$(mktemp -d "$ROOT/state/fm-claim-lock-shape-$name.XXXXXX")
  CLAIM_SHAPE_CASE_DIRS+=("$CLAIM_SHAPE_DIR")
  mkdir -p "$CLAIM_SHAPE_DIR/state" "$CLAIM_SHAPE_DIR/scratch"
}

# --- helpers -----------------------------------------------------------------

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
  printf '%s\n' "$2" >"$1/pid" 2>/dev/null || return 1
  return 0
}

# shape_verdict <library> <matcher> <name>
# Runs one matcher in its own shell, so the two implementation families never
# share a process and cannot mask each other.
shape_verdict() {  # <library> <matcher> <name>
  FM_ROOT_OVERRIDE="$ROOT" bash -c '
    set -u
    # shellcheck disable=SC1090
    . "$1"
    if "$2" "$3"; then printf "yes"; else printf "no"; fi
  ' _ "$1" "$2" "$3" 2>/dev/null
}

# run_lock_lib <body>
# Runs a body with the production lock library loaded against the current
# case state dir. The body is written to a file first and sourced, because
# ". <string>" would read the body as a path.
run_lock_lib() {  # <body>
  local body_file="$CLAIM_SHAPE_DIR/body.sh"
  printf '%s\n' "$1" >"$body_file"
  FM_STATE_OVERRIDE="$CLAIM_SHAPE_DIR/state" FM_ROOT_OVERRIDE="$ROOT" \
    bash -c '
      set -u
      # shellcheck disable=SC1090
      . "$1"
      . "$2"
    ' _ "$LOCK_LIB" "$body_file"
}

# sweep <root>
# Run the outside reclaim sweep over one root, in apply mode.
sweep() {  # <root>
  FM_LOCK_RECLAIM_APPLY=1 \
  FM_RECLAIM_LOCK_GRACE_S=0 \
  FM_RECLAIM_LOCK_MAXDEPTH=6 \
  bash -c '. "$1"; fm_lock_reclaim_sweep "$2"' _ "$RECLAIM_LIB" "$1" 2>&1
}

[ -r "$LOCK_LIB" ] || { echo "FAIL  the lock library is missing: $LOCK_LIB"; exit 1; }
[ -r "$RECLAIM_LIB" ] || { echo "FAIL  the reclaim library is missing: $RECLAIM_LIB"; exit 1; }
[ -r "$LOCK_SCRIPT" ] || { echo "FAIL  the lock script is missing: $LOCK_SCRIPT"; exit 1; }

BASENAME="$(claim_lock_basename)"
[ -n "$BASENAME" ] || { echo "FAIL  could not read CLAIM_LOCK from $LOCK_SCRIPT"; exit 1; }
OWNER_DIR_NAME="${BASENAME}.owner.AAAAAA"
DEAD_PID="$(dead_pid)"

echo "== the claim lock is a lock shape =="

case "$BASENAME" in
  *.lock) pass "the claim lock basename ends in .lock ($BASENAME)" ;;
  *) fail "the claim lock basename does not end in .lock: $BASENAME" ;;
esac

case "$BASENAME" in
  .lock.acquire) fail "the claim lock still uses the pre-fix name .lock.acquire" ;;
  *) pass "the claim lock does not use the pre-fix name" ;;
esac

# Every shape matcher, in both implementation families, must accept the
# pointer and the owner dir.
for spec in \
  "$LOCK_LIB fm_lock_pointer_basename_matches $BASENAME" \
  "$LOCK_LIB fm_lock_owner_dir_basename_matches $OWNER_DIR_NAME" \
  "$RECLAIM_LIB fm_lock_reclaim_pointer_basename_matches $BASENAME" \
  "$RECLAIM_LIB fm_lock_reclaim_owner_dir_basename_matches $OWNER_DIR_NAME"; do
  # shellcheck disable=SC2086
  set -- $spec
  verdict="$(shape_verdict "$1" "$2" "$3")"
  if [ "$verdict" = "yes" ]; then
    pass "$2 accepts $3"
  else
    fail "$2 does not accept $3"
  fi
done

echo "== the pre-fix name is still invisible, so the defect is pinned =="

for spec in \
  "$LOCK_LIB fm_lock_pointer_basename_matches .lock.acquire" \
  "$LOCK_LIB fm_lock_owner_dir_basename_matches .lock.acquire.owner.AAAAAA" \
  "$RECLAIM_LIB fm_lock_reclaim_pointer_basename_matches .lock.acquire" \
  "$RECLAIM_LIB fm_lock_reclaim_owner_dir_basename_matches .lock.acquire.owner.AAAAAA"; do
  # shellcheck disable=SC2086
  set -- $spec
  verdict="$(shape_verdict "$1" "$2" "$3")"
  if [ "$verdict" = "no" ]; then
    pass "$2 rejects $3 (the pre-fix name stays invisible)"
  else
    fail "$2 accepts $3; the pre-fix name is no longer the pinned defect"
  fi
done

echo "== no production call site keeps the pre-fix name =="

for f in "$LOCK_SCRIPT" "$STARTUP_NETWORK"; do
  # Comments may still NAME the pre-fix name to explain why it is wrong; a
  # live call site may not use it.
  if grep -v '^[[:space:]]*#' "$f" | grep -q '\.lock\.acquire'; then
    fail "$f still calls .lock.acquire"
  else
    pass "$f has no .lock.acquire call site"
  fi
done

echo "== a released claim lock leaves nothing behind =="

make_case release
STATE_DIR="$CLAIM_SHAPE_DIR/state"
LOCK_PATH="$STATE_DIR/$BASENAME"

run_lock_lib "
  fm_lock_acquire_wait '$LOCK_PATH' || exit 3
  [ -L '$LOCK_PATH' ] || exit 4
  fm_lock_release '$LOCK_PATH'
" >"$CLAIM_SHAPE_DIR/release.out" 2>&1
rc=$?

if [ "$rc" -ne 0 ]; then
  fail "taking and releasing the claim lock failed (rc=$rc); see $CLAIM_SHAPE_DIR/release.out"
else
  pass "the claim lock was taken and released"
fi

if [ -L "$LOCK_PATH" ] || [ -e "$LOCK_PATH" ]; then
  fail "the claim-lock pointer survived its own release: $LOCK_PATH still exists"
else
  pass "the claim-lock pointer is gone after the release"
fi

leftovers="$(find "$STATE_DIR" -maxdepth 1 -name "$BASENAME.owner.*" 2>/dev/null | head -5)"
if [ -n "$leftovers" ]; then
  fail "the claim lock left owner dirs behind: $leftovers"
else
  pass "the claim lock left no owner dir behind"
fi

echo "== the purge unlinks a claim-lock pointer, and could not before =="

make_case purge
STATE_DIR="$CLAIM_SHAPE_DIR/state"
LOCK_PATH="$STATE_DIR/$BASENAME"
mk_owner "$STATE_DIR/$BASENAME.owner.BBBBBB" "$DEAD_PID"
ln -s "$STATE_DIR/$BASENAME.owner.BBBBBB" "$LOCK_PATH" 2>/dev/null

run_lock_lib "fm_lock_purge_own '$LOCK_PATH'" >"$CLAIM_SHAPE_DIR/purge.out" 2>&1
if [ -L "$LOCK_PATH" ] || [ -e "$LOCK_PATH" ]; then
  fail "the purge did not unlink a claim-lock pointer: $LOCK_PATH still exists"
else
  pass "the purge unlinks a claim-lock pointer"
fi

# The same fixture under the pre-fix name must NOT be purged. This is the
# mechanism of the original leak, asserted so the fix cannot be undone by
# renaming the pointer somewhere else.
OLD_PATH="$STATE_DIR/.lock.acquire"
mk_owner "$STATE_DIR/.lock.acquire.owner.CCCCCC" "$DEAD_PID"
ln -s "$STATE_DIR/.lock.acquire.owner.CCCCCC" "$OLD_PATH" 2>/dev/null

run_lock_lib "fm_lock_purge_own '$OLD_PATH'" >"$CLAIM_SHAPE_DIR/purge-old.out" 2>&1
if [ -L "$OLD_PATH" ] || [ -e "$OLD_PATH" ]; then
  pass "the pre-fix name is still unpurgeable, as it was before the fix"
else
  fail "the pre-fix name was purged; the pinned defect no longer reproduces"
fi

echo "== a dead claim lock is reclaimable by the outside reclaimer =="

make_case reclaim
STATE_DIR="$CLAIM_SHAPE_DIR/state"
LOCK_PATH="$STATE_DIR/$BASENAME"
mk_owner "$STATE_DIR/$OWNER_DIR_NAME" "$DEAD_PID"
ln -s "$STATE_DIR/$OWNER_DIR_NAME" "$LOCK_PATH" 2>/dev/null

OUT="$(sweep "$STATE_DIR")"
printf '%s\n' "$OUT" >"$CLAIM_SHAPE_DIR/sweep.out"

if [ ! -d "$STATE_DIR/$OWNER_DIR_NAME" ]; then
  pass "the dead claim-lock owner dir is reclaimed"
else
  fail "the dead claim-lock owner dir was NOT reclaimed"
fi

if [ -L "$LOCK_PATH" ] || [ -e "$LOCK_PATH" ]; then
  fail "the dead claim-lock pointer was NOT reclaimed"
else
  pass "the dead claim-lock pointer is reclaimed with its owner dir"
fi

# Control: the same fixture under the pre-fix name stays untouched, which is
# the invisibility that let the wedge re-form after every session.
OLD_OWNER="$STATE_DIR/.lock.acquire.owner.DDDDDD"
OLD_PATH="$STATE_DIR/.lock.acquire"
mk_owner "$OLD_OWNER" "$DEAD_PID"
ln -s "$OLD_OWNER" "$OLD_PATH" 2>/dev/null

sweep "$STATE_DIR" >"$CLAIM_SHAPE_DIR/sweep-old.out" 2>&1

if [ -d "$OLD_OWNER" ] && { [ -L "$OLD_PATH" ] || [ -e "$OLD_PATH" ]; }; then
  pass "the pre-fix name stays invisible to the reclaimer"
else
  fail "the pre-fix name was reclaimed; the pinned defect no longer reproduces"
fi

echo "== a live claim lock is never reclaimed =="

make_case live
STATE_DIR="$CLAIM_SHAPE_DIR/state"
LIVE_OWNER="$STATE_DIR/$BASENAME.owner.EEEEEE"
LIVE_PATH="$STATE_DIR/$BASENAME.live"
mk_owner "$LIVE_OWNER" "$$"
ln -s "$LIVE_OWNER" "$LIVE_PATH" 2>/dev/null

sweep "$STATE_DIR" >"$CLAIM_SHAPE_DIR/sweep-live.out" 2>&1

if [ -d "$LIVE_OWNER" ] && [ -L "$LIVE_PATH" ]; then
  pass "a live holder's owner dir and pointer survive the sweep"
else
  fail "the sweep removed a live holder's lock scratch"
fi

exit 0
