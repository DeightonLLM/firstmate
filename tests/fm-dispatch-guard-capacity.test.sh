#!/usr/bin/env bash
# Tests for the Captain's disk-capacity ceiling ON THE PLACEMENT PATH.
#
# THE ENFORCEMENT POINT IS ONE COMPONENT: bin/fm-capacity-gate.sh, the single
# shared owner of the ladder and of the reclaim-then-refuse admission decision.
# bin/fm-spawn.sh is the ONE reader that consults it, before any worktree,
# endpoint, backend or state mutation. This suite proves that end to end.
#
# WHAT THIS SUITE IS FOR.
#
# The 80% ceiling was once only a label: it was configured, printed in a report
# and carded on a board, and the ladder's middle tiers said NOTHING to the
# person placing the work. A review tier that says nothing is a review tier
# that never happens. So this suite pins:
#
#   1. the ladder's four tiers and their exact boundaries;
#   2. CAPACITY_BLOCK_NEW_PLACEMENT REFUSES a placement (reclaim first, refuse
#      only if the disk is still over the ceiling), and the refusal carries the
#      verdict, the reading and where the reading came from;
#   3. CAPACITY_REVIEW_REQUIRED ADMITS but WARNS, out loud, on every placement;
#      CAPACITY_EARLY_WARNING admits and advises; CAPACITY_OK says nothing;
#   4. an unmeasurable disk FAILS CLOSED;
#   5. the bypass is narrow, explicit, logged, and names the variable that was
#      actually set;
#   6. the REAL spawn path refuses - on the ship/scout path AND on the
#      --secondmate path - and leaves no task record or worktree behind;
#   7. the owner that runs is the RUNNING firstmate's own, not whatever a
#      redirected FM_ROOT_OVERRIDE happens to point at.
#
# Every case is asserted by OBSERVED BEHAVIOUR - the real scripts, a fake `df`
# and a fake reclaimer through the owner's own documented seams - never by
# reading the code.
#
# NOTE ON THIS FILE'S NAME. It was created before the lane was re-scoped, when
# the plan was to add a disk rule to bin/fm-dispatch-guard.sh. That plan was
# dropped: the dispatch guard is not an independent placement entry point
# (bin/fm-spawn.sh is its only caller in bin/, and the capacity owner is
# consulted on that same path 19 lines later), so a disk rule there would have
# been a SECOND enforcement point for the same ceiling - a second gate, and the
# ladder's meaning duplicated in two places. The accurate name for this file is
# tests/fm-capacity-placement.test.sh; it was not renamed because this lane's
# boundaries forbid moving files. See the lane report.
#
# Usage: tests/fm-dispatch-guard-capacity.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT/bin/fm-capacity-gate.sh"
SPAWN="$ROOT/bin/fm-spawn.sh"
PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

LOGDIR="$(mktemp -d)"
export FM_CAPACITY_GATE_LOG="$LOGDIR/gate.log"
export FM_CAPACITY_GATE_LOCK="$LOGDIR/gate.lock"
# The other spawn-path rules are taken out of the picture so that what is
# asserted here is the CAPACITY decision and not the load or quota ceiling.
export FM_DISPATCH_GUARD_LOAD_BYPASS=1
export FM_DISPATCH_GUARD_QUOTA_BYPASS=1

# --- fixtures -----------------------------------------------------------------
#
# A fake `df -P /` whose reading comes from a state file, and a fake reclaimer
# that can either free the disk or not. A fake reclaimer is what makes "a
# reclaim that DOES free space" and "a reclaim that frees NOTHING" two
# provable cases instead of one hope.
STATE="$LOGDIR/disk.state"
FAKE_DF="$LOGDIR/fake-df.sh"
FAKE_RECLAIMER="$LOGDIR/fake-reclaim.sh"

cat > "$FAKE_DF" <<'EOF'
#!/bin/sh
pct=$(cat "$FAKE_DF_STATE" 2>/dev/null || echo 0)
case "$pct" in
  ''|*[!0-9]*) printf 'garbage\n'; exit 0 ;;
esac
printf 'Filesystem      1K-blocks     Used Available Use%% Mounted on\n'
printf '/dev/fake        100000000  %9d %9d %4s%% /\n' 59623588 15445140 "$pct"
EOF

cat > "$FAKE_RECLAIMER" <<'EOF'
#!/bin/sh
case "${FAKE_RECLAIM_MODE:-free}" in
  free)    echo 60 > "$FAKE_DF_STATE" ;;
  nofree)  : ;;
esac
echo "measured: the filesystem gave back 1234 KB (df before/after, not what the script believes it deleted)"
echo "capacity: 82% -> 60% used"
exit 0
EOF

cat > "$LOGDIR/bad-df.sh" <<'EOF'
#!/bin/sh
printf 'this is not a df table\n'
EOF
chmod +x "$FAKE_DF" "$FAKE_RECLAIMER" "$LOGDIR/bad-df.sh"

export FM_CAPACITY_GATE_DF="$FAKE_DF"
export FM_CAPACITY_GATE_RECLAIMER="$FAKE_RECLAIMER"
export FM_CAPACITY_GATE_RECLAIM_TIMEOUT_S=5
export FAKE_DF_STATE="$STATE"

# set_disk <percent>
set_disk() { echo "$1" > "$STATE"; }

# run_gate <reclaim-mode> [env...]: run the real owner with the disk at the
# current fixture reading. Sets GATE_OUT and GATE_RC.
#
# The reclaim mode is passed with `env`, not with a shell assignment prefix: a
# prefix assignment that has no command word is a PERSISTENT but UNEXPORTED
# shell variable, so the fake reclaimer would never see it and would silently
# run its default behaviour instead of the case under test.
#
# run_gate is called directly, never inside a command substitution: a
# substitution runs it in a subshell and every variable it set would be lost.
GATE_OUT=""
GATE_RC=0
run_gate() {
  mode="$1"; shift
  GATE_OUT="$(env FAKE_RECLAIM_MODE="$mode" "$@" "$GATE" check 2>&1)"
  GATE_RC=$?
}

[ -x "$GATE" ]  || { echo "FAIL  the ladder owner is not executable: $GATE"; exit 1; }
[ -x "$SPAWN" ] || { echo "FAIL  fm-spawn.sh is not executable: $SPAWN"; exit 1; }

echo "== the ladder: one owner, one copy of the thresholds =="
for pair in 69:CAPACITY_OK 70:CAPACITY_EARLY_WARNING 74:CAPACITY_EARLY_WARNING \
            75:CAPACITY_REVIEW_REQUIRED 79:CAPACITY_REVIEW_REQUIRED \
            80:CAPACITY_BLOCK_NEW_PLACEMENT 85:CAPACITY_BLOCK_NEW_PLACEMENT; do
  pct="${pair%%:*}"; want="${pair##*:}"
  got="$("$GATE" verdict "$pct" 2>/dev/null)"
  if [ "$got" = "$want" ]; then ok "verdict $pct -> $want"; else bad "verdict $pct -> $got (want $want)"; fi
done
if "$GATE" verdict 200 >/dev/null 2>&1; then
  bad "an out-of-range percent must be refused by the ladder owner"
else
  ok "an out-of-range percent is refused by the ladder owner"
fi

echo "== reclaim first, then refuse =="
# The Captain's standing order is "lets reclaim but refuse". At the ceiling the
# owner reclaims, re-measures, and refuses ONLY if the disk is STILL over the
# ceiling afterwards.
set_disk 82
run_gate nofree
if [ "$GATE_RC" = 64 ]; then ok "a reclaim that frees NOTHING over the ceiling refuses"; else bad "a reclaim that frees NOTHING should refuse (rc=$GATE_RC): $GATE_OUT"; fi
case "$GATE_OUT" in
  *"still at 82%"*) ok "the refusal says what the disk reads now" ;;
  *) bad "the refusal did not disclose the current disk reading: $GATE_OUT" ;;
esac
case "$GATE_OUT" in
  *"REFUSED"*) ok "the refusal is stated on stderr, not swallowed" ;;
  *) bad "the refusal message is missing from stderr: $GATE_OUT" ;;
esac
case "$GATE_OUT" in
  *CAPACITY_BLOCK_NEW_PLACEMENT*) ok "the refusal states the verdict" ;;
  *) bad "the refusal did not state the verdict: $GATE_OUT" ;;
esac
case "$GATE_OUT" in
  *"df -P /"*) ok "the refusal states where the number came from" ;;
  *) bad "the refusal did not state where the number came from: $GATE_OUT" ;;
esac

set_disk 82
run_gate free
if [ "$GATE_RC" = 0 ]; then ok "a reclaim that DOES free space allows the placement"; else bad "a reclaim that frees space should allow (rc=$GATE_RC): $GATE_OUT"; fi
case "$GATE_OUT" in
  *"back at 60%"*) ok "the allow path reports the disk reading after the reclaim" ;;
  *) bad "the allow path did not report the post-reclaim reading: $GATE_OUT" ;;
esac

echo "== under the ceiling: nothing is reclaimed =="
: > "$LOGDIR/gate.log"
set_disk 40
run_gate nofree
if [ "$GATE_RC" = 0 ]; then ok "a disk under the ceiling is admitted"; else bad "a disk under the ceiling must be admitted (rc=$GATE_RC): $GATE_OUT"; fi
if grep -q CAPACITY_BLOCKED "$LOGDIR/gate.log" 2>/dev/null; then
  bad "a disk under the ceiling triggered a reclaim"
else
  ok "a disk under the ceiling triggers no reclaim"
fi

echo "== the review tier is NOT a silent no-op =="
# The ladder's middle tiers used to print NOTHING to the person placing the
# work: the gate wrote CAPACITY_ALLOW into its own log file and returned 0.
# The ladder says "review before placing anything new", and the review was
# invisible to the only person who could act on it.
set_disk 75
run_gate nofree
if [ "$GATE_RC" = 0 ]; then ok "CAPACITY_REVIEW_REQUIRED admits the placement"; else bad "the review tier must admit (rc=$GATE_RC): $GATE_OUT"; fi
case "$GATE_OUT" in
  *CAPACITY_REVIEW_REQUIRED*) ok "the review tier says so out loud" ;;
  *) bad "the review tier was silent: $GATE_OUT" ;;
esac
case "$GATE_OUT" in
  *"75%"*) ok "the review warning states the actual disk usage" ;;
  *) bad "the review warning did not state the disk usage: $GATE_OUT" ;;
esac
case "$GATE_OUT" in
  *WARNING*) ok "the review warning is marked as a warning" ;;
  *) bad "the review warning is not marked as a warning: $GATE_OUT" ;;
esac
case "$GATE_OUT" in
  *"df -P /"*) ok "the review warning states where the number came from" ;;
  *) bad "the review warning did not state where the number came from: $GATE_OUT" ;;
esac
# The review tier must be on the record too, not only on stderr.
: > "$LOGDIR/gate.log"
run_gate nofree
if grep -q CAPACITY_REVIEW "$LOGDIR/gate.log" 2>/dev/null; then
  ok "the review tier is recorded in the gate's log"
else
  bad "the review tier was not recorded in the gate's log: $(cat "$LOGDIR/gate.log" 2>/dev/null)"
fi

echo "== the early-warning tier advises and does not block =="
set_disk 72
run_gate nofree
if [ "$GATE_RC" = 0 ]; then ok "CAPACITY_EARLY_WARNING admits the placement"; else bad "the early-warning tier must admit (rc=$GATE_RC): $GATE_OUT"; fi
case "$GATE_OUT" in
  *CAPACITY_EARLY_WARNING*) ok "the early-warning tier says so out loud" ;;
  *) bad "the early-warning tier was silent: $GATE_OUT" ;;
esac

echo "== a healthy disk says nothing =="
set_disk 40
run_gate nofree
if [ "$GATE_RC" = 0 ]; then ok "a healthy disk is admitted"; else bad "a healthy disk must be admitted (rc=$GATE_RC): $GATE_OUT"; fi
case "$GATE_OUT" in
  *CAPACITY_*) bad "a healthy disk produced a capacity message: $GATE_OUT" ;;
  *) ok "a healthy disk produces no capacity message" ;;
esac

echo "== fail closed on an unmeasurable disk =="
GATE_OUT="$(env FM_CAPACITY_GATE_DF="$LOGDIR/bad-df.sh" "$GATE" check 2>&1)"; GATE_RC=$?
if [ "$GATE_RC" = 64 ]; then ok "an unmeasurable disk refuses"; else bad "an unmeasurable disk must refuse (rc=$GATE_RC): $GATE_OUT"; fi
case "$GATE_OUT" in
  *"could not be measured"*) ok "the unmeasurable disk is disclosed, not silent" ;;
  *) bad "the unmeasurable disk refusal did not disclose itself: $GATE_OUT" ;;
esac

echo "== the bypass is narrow, documented and logged =="
: > "$LOGDIR/gate.log"
set_disk 99
run_gate nofree FM_CAPACITY_GATE_BYPASS=1
if [ "$GATE_RC" = 0 ]; then ok "the capacity bypass admits a dispatch over the ceiling"; else bad "the capacity bypass should admit (rc=$GATE_RC): $GATE_OUT"; fi
if grep -q BYPASS_CAPACITY "$LOGDIR/gate.log" 2>/dev/null; then
  ok "the capacity bypass is logged, never silent"
else
  bad "the capacity bypass was not logged"
fi
case "$GATE_OUT" in
  *"BYPASS"*) ok "the capacity bypass says so on stderr" ;;
  *) bad "the capacity bypass was silent on stderr: $GATE_OUT" ;;
esac
# The notice must name the variable that was ACTUALLY set: a bypass message
# that names the wrong knob sends the next reader looking for a variable that
# was never exported.
case "$GATE_OUT" in
  *"FM_CAPACITY_GATE_BYPASS=1"*) ok "the bypass notice names the variable that was set" ;;
  *) bad "the bypass notice did not name the variable that was set: $GATE_OUT" ;;
esac
# The second name must work too, and must be named in its own notice.
: > "$LOGDIR/gate.log"
run_gate nofree FM_DISPATCH_GUARD_CAPACITY_BYPASS=1
if [ "$GATE_RC" = 0 ]; then ok "FM_DISPATCH_GUARD_CAPACITY_BYPASS admits over the ceiling too"; else bad "FM_DISPATCH_GUARD_CAPACITY_BYPASS did not admit (rc=$GATE_RC): $GATE_OUT"; fi
case "$GATE_OUT" in
  *"FM_DISPATCH_GUARD_CAPACITY_BYPASS=1"*) ok "the bypass notice names the variable that was set (second name)" ;;
  *) bad "the bypass notice named the wrong variable: $GATE_OUT" ;;
esac

echo "== the real spawn path: a placement over the ceiling is REFUSED =="
# Proved at the real call site of the real fm-spawn.sh, against a scratch
# FM_HOME and a target that does not exist, so a spawn that passes the gate
# still aborts before any worktree, endpoint, or meta can be created.
SB="$LOGDIR/spawn"
spawn_home() {
  local h="$SB/$1"
  mkdir -p "$h/state" "$h/config" "$h/data" "$h/projects"
  printf '%s\n' "$h"
}

H_SHIP="$(spawn_home ship)"
set_disk 82
out="$(env FM_HOME="$H_SHIP" FAKE_RECLAIM_MODE=nofree \
  FM_CAPACITY_GATE_LOG="$LOGDIR/spawn-ship.log" \
  FM_CAPACITY_GATE_LOCK="$LOGDIR/spawn-ship.lock" \
  "$SPAWN" cap-ship "$H_SHIP/no-such-home" 2>&1)"; rc=$?
if [ "$rc" = 64 ]; then ok "fm-spawn refuses a placement over the capacity ceiling"; else bad "fm-spawn should refuse over the ceiling (rc=$rc): $out"; fi
case "$out" in
  *"capacity-gate: REFUSED"*) ok "the refusal came from the CAPACITY OWNER, the one enforcement point" ;;
  *) bad "the refusal did not come from the capacity owner: $out" ;;
esac
case "$out" in
  *CAPACITY_BLOCK_NEW_PLACEMENT*) ok "the spawn refusal names the verdict" ;;
  *) bad "the spawn refusal did not name the verdict: $out" ;;
esac
if ls "$H_SHIP"/state/*.meta >/dev/null 2>&1; then
  bad "a capacity-refused spawn left a task record behind"
else
  ok "a capacity-refused spawn leaves no task record behind"
fi
if [ -n "$(ls -A "$H_SHIP/projects" 2>/dev/null)" ]; then
  bad "a capacity-refused spawn left worktree state behind"
else
  ok "a capacity-refused spawn leaves no worktree state behind"
fi

echo "== the --secondmate path is not exempt =="
# A secondmate spawn stands up its own home rather than acting as a fresh
# worker dispatch, so it is the placement path most likely to be waved through.
# It must be refused exactly like the ship path.
H_SM="$(spawn_home secondmate)"
printf 'minimax-code minimax/MiniMax-M3.1-Flash\n' > "$H_SM/config/secondmate-harness"
set_disk 82
out="$(env FM_HOME="$H_SM" FAKE_RECLAIM_MODE=nofree \
  FM_CAPACITY_GATE_LOG="$LOGDIR/spawn-sm.log" \
  FM_CAPACITY_GATE_LOCK="$LOGDIR/spawn-sm.lock" \
  "$SPAWN" cap-secondmate "$H_SM/no-such-home" --secondmate 2>&1)"; rc=$?
if [ "$rc" = 64 ]; then ok "fm-spawn refuses a --secondmate placement over the ceiling"; else bad "fm-spawn should refuse a --secondmate over the ceiling (rc=$rc): $out"; fi
case "$out" in
  *"capacity-gate: REFUSED"*) ok "the --secondmate refusal came from the capacity owner" ;;
  *) bad "the --secondmate refusal did not come from the capacity owner: $out" ;;
esac
case "$out" in
  *CAPACITY_BLOCK_NEW_PLACEMENT*) ok "the --secondmate refusal names the verdict" ;;
  *) bad "the --secondmate refusal did not name the verdict: $out" ;;
esac

echo "== the review tier warns on the real spawn path and does not block =="
H_REVIEW="$(spawn_home review)"
set_disk 75
out="$(env FM_HOME="$H_REVIEW" FAKE_RECLAIM_MODE=nofree \
  FM_CAPACITY_GATE_LOG="$LOGDIR/spawn-review.log" \
  FM_CAPACITY_GATE_LOCK="$LOGDIR/spawn-review.lock" \
  "$SPAWN" cap-review "$H_REVIEW/no-such-home" 2>&1)"; rc=$?
case "$out" in
  *"capacity-gate: REFUSED"*)
    bad "the review tier refused a spawn: $out" ;;
  *)
    ok "the review tier warns and lets the spawn through (it fails later, on the missing target: rc=$rc)" ;;
esac
case "$out" in
  *CAPACITY_REVIEW_REQUIRED*) ok "the spawn carries the review warning" ;;
  *) bad "the spawn carried no review warning: $out" ;;
esac

echo "== the owner that runs is the RUNNING firstmate's own =="
# A redirected FM_ROOT_OVERRIDE may name a checkout that carries no bin/ tree
# at all, and a mandatory policy gate must be the gate the RUNNING firstmate
# ships. So the spawn must not take its ceiling from whatever FM_ROOT points
# at - it must take it from its own code root. The fake owner below would
# leave a marker if it were ever consulted.
FAKEROOT="$LOGDIR/fakeroot"
mkdir -p "$FAKEROOT/bin"
cat > "$FAKEROOT/bin/fm-capacity-gate.sh" <<'EOF'
#!/bin/sh
: > "$FAKE_OWNER_MARKER"
echo "the redirected owner was consulted" >&2
exit 0
EOF
chmod +x "$FAKEROOT/bin/fm-capacity-gate.sh"
export FAKE_OWNER_MARKER="$LOGDIR/fake-owner.marker"

H_ROOT="$(spawn_home root)"
set_disk 82
out="$(env FM_HOME="$H_ROOT" FM_ROOT_OVERRIDE="$FAKEROOT" FAKE_RECLAIM_MODE=nofree \
  FM_CAPACITY_GATE_LOG="$LOGDIR/spawn-root.log" \
  FM_CAPACITY_GATE_LOCK="$LOGDIR/spawn-root.lock" \
  "$SPAWN" cap-root "$H_ROOT/no-such-home" 2>&1)"; rc=$?
if [ -e "$FAKE_OWNER_MARKER" ]; then
  bad "the spawn consulted the redirected owner instead of its own code root"
else
  ok "the spawn uses the RUNNING firstmate's own owner, not the redirected one"
fi
if [ "$rc" = 64 ]; then ok "the spawn still refuses over the ceiling with a redirected FM_ROOT"; else bad "the spawn should refuse over the ceiling (rc=$rc): $out"; fi

echo
printf 'PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "TESTS FAILED"
  exit 1
fi
echo "ALL TESTS PASSED"
