#!/usr/bin/env bash
# Tests for the disk-capacity admission rule: bin/fm-capacity-gate.sh (the
# single shared owner of the ladder and of the reclaim-then-refuse decision),
# and the reader that consults it, bin/fm-spawn.sh.
#
# These exist because the 80% ceiling was real and LANDED (e552a42) while the
# ENFORCEMENT was not: nothing in the dispatch path read the verdict, so the
# root filesystem sat at 79-80% and every dispatch sailed straight through. A
# ceiling that is documented but not enforced is the same failure as a fake
# freedKB. So each behaviour below is asserted by OBSERVED BEHAVIOUR, not by
# reading the code.
#
# The rule under test, in one line: RECLAIM FIRST, THEN REFUSE. At or over the
# ceiling the gate reclaims, re-measures, and refuses ONLY if the disk is STILL
# over the ceiling afterwards.
#
# Usage: tests/fm-capacity-refuse.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT/bin/fm-capacity-gate.sh"
RECLAIMER="$ROOT/bin/fm-capacity-reclaim.sh"
AUDIT="$ROOT/bin/controller-resource-audit.sh"
SPAWN="$ROOT/bin/fm-spawn.sh"
PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

LOGDIR="$(mktemp -d)"
export FM_CAPACITY_GATE_LOG="$LOGDIR/gate.log"
export FM_CAPACITY_GATE_LOCK="$LOGDIR/gate.lock"

# --- fixtures -----------------------------------------------------------------
#
# A fake `df -P /` whose reading comes from a state file, and a fake reclaimer
# that can either free the disk or not. Using a fake reclaimer is what makes
# "a reclaim that DOES free space" and "a reclaim that frees NOTHING" two
# different, provable cases instead of one hope.
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
  hang)    sleep 60 ;;
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

# run_gate <mode>: run the gate with the disk at 82% and the given reclaim
# behaviour. Sets GATE_OUT and GATE_RC.
#
# The mode is passed with `env`, not with a shell assignment prefix: a prefix
# assignment that has no command word is a PERSISTENT but UNEXPORTED shell
# variable, so the fake reclaimer would never see it and would silently run its
# default "free" behaviour instead of the case under test.
#
# run_gate is called directly, never inside a command substitution: a
# substitution runs it in a subshell, and every variable it set would be lost.
GATE_OUT=""
GATE_RC=0
run_gate() {
  echo 82 > "$STATE"
  GATE_OUT="$(env FAKE_RECLAIM_MODE="$1" "$GATE" check 2>&1)"
  GATE_RC=$?
}

[ -x "$GATE" ] || { echo "FAIL  the shared capacity owner is not executable: $GATE"; exit 1; }
[ -x "$RECLAIMER" ] || { echo "FAIL  the reclaimer is not executable: $RECLAIMER"; exit 1; }
[ -x "$SPAWN" ] || { echo "FAIL  the spawn reader is not executable: $SPAWN"; exit 1; }

echo "== the ladder: one owner, one copy of the thresholds =="
for pair in 69:CAPACITY_OK 70:CAPACITY_EARLY_WARNING 74:CAPACITY_EARLY_WARNING \
            75:CAPACITY_REVIEW_REQUIRED 79:CAPACITY_REVIEW_REQUIRED \
            80:CAPACITY_BLOCK_NEW_PLACEMENT 85:CAPACITY_BLOCK_NEW_PLACEMENT; do
  pct="${pair%%:*}"; want="${pair##*:}"
  got="$("$GATE" verdict "$pct" 2>/dev/null)"
  if [ "$got" = "$want" ]; then ok "verdict $pct -> $want"; else bad "verdict $pct -> $got (want $want)"; fi
done
# The audit script must DELEGATE to the shared owner, so the repo carries one
# ladder and a second copy cannot drift from the first.
got="$("$AUDIT" verdict 80 2>/dev/null)"
if [ "$got" = "CAPACITY_BLOCK_NEW_PLACEMENT" ]; then
  ok "the audit script delegates its verdict to the shared owner (one ladder)"
else
  bad "the audit script did not delegate its verdict (got '$got')"
fi
if "$GATE" verdict 200 >/dev/null 2>&1; then
  bad "an out-of-range percent must be refused by the ladder owner"
else
  ok "an out-of-range percent is refused by the ladder owner"
fi

echo "== reclaim first, then refuse =="
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

run_gate free
if [ "$GATE_RC" = 0 ]; then ok "a reclaim that DOES free space allows the placement"; else bad "a reclaim that frees space should allow (rc=$GATE_RC): $GATE_OUT"; fi
case "$GATE_OUT" in
  *"back at 60%"*) ok "the allow path reports the disk reading after the reclaim" ;;
  *) bad "the allow path did not report the post-reclaim reading: $GATE_OUT" ;;
esac

echo "== under the ceiling: nothing is reclaimed =="
: > "$LOGDIR/gate.log"
echo 40 > "$STATE"
GATE_OUT="$("$GATE" check 2>&1)"; GATE_RC=$?
if [ "$GATE_RC" = 0 ]; then ok "a disk under the ceiling is admitted"; else bad "a disk under the ceiling must be admitted (rc=$GATE_RC): $GATE_OUT"; fi
if grep -q CAPACITY_BLOCKED "$LOGDIR/gate.log" 2>/dev/null; then
  bad "a disk under the ceiling triggered a reclaim"
else
  ok "a disk under the ceiling triggers no reclaim"
fi

echo "== fail closed on an unmeasurable disk =="
GATE_OUT="$(env FM_CAPACITY_GATE_DF="$LOGDIR/bad-df.sh" "$GATE" check 2>&1)"; GATE_RC=$?
if [ "$GATE_RC" = 64 ]; then ok "an unmeasurable disk refuses"; else bad "an unmeasurable disk must refuse (rc=$GATE_RC)"; fi
case "$GATE_OUT" in
  *"could not be measured"*) ok "the unmeasurable disk is disclosed, not silent" ;;
  *) bad "the unmeasurable disk refusal did not disclose itself: $GATE_OUT" ;;
esac

echo "== the bypass is narrow, documented and logged =="
: > "$LOGDIR/gate.log"
echo 99 > "$STATE"
GATE_OUT="$(env FM_CAPACITY_GATE_BYPASS=1 "$GATE" check 2>&1)"; GATE_RC=$?
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
# The briefed name must keep working too, so an operator who read the brief
# does not reach for a bypass that does nothing.
echo 99 > "$STATE"
GATE_OUT="$(env FM_DISPATCH_GUARD_CAPACITY_BYPASS=1 "$GATE" check 2>&1)"; GATE_RC=$?
if [ "$GATE_RC" = 0 ]; then ok "the briefed bypass name FM_DISPATCH_GUARD_CAPACITY_BYPASS works too"; else bad "FM_DISPATCH_GUARD_CAPACITY_BYPASS did not admit (rc=$GATE_RC)"; fi

echo "== the reclaim is bounded by a timeout =="
started="$(date +%s)"
run_gate hang
elapsed=$(( $(date +%s) - started ))
if [ "$GATE_RC" = 64 ]; then ok "a hanging reclaim ends in a refusal, not a hang"; else bad "a hanging reclaim should refuse (rc=$GATE_RC)"; fi
if [ "$elapsed" -lt 20 ]; then
  ok "the hanging reclaim was stopped by the timeout (${elapsed}s, bound 5s)"
else
  bad "the hanging reclaim was not stopped by the timeout (${elapsed}s elapsed, bound 5s)"
fi
case "$GATE_OUT" in
  *"timed-out"*) ok "the timeout is disclosed in the refusal" ;;
  *) bad "the timeout was not disclosed: $GATE_OUT" ;;
esac

echo "== the reader: bin/fm-spawn.sh consults the shared owner =="
# The reader is proved at the real call site of the real fm-spawn.sh, against a
# scratch FM_HOME and a target that does not exist, so a spawn that passes the
# gate still aborts before any worktree, endpoint, or meta can be created.
SB="$LOGDIR/spawn"
spawn_home() {
  local h="$SB/$1"
  mkdir -p "$h/state" "$h/config" "$h/data" "$h/projects"
  printf '%s\n' "$h"
}
# The other guard rules are taken out of the picture so that what is being
# asserted is the CAPACITY decision and not the load or quota ceiling.
export FM_DISPATCH_GUARD_LOAD_BYPASS=1
export FM_DISPATCH_GUARD_QUOTA_BYPASS=1

H_BLOCKED="$(spawn_home blocked)"
echo 82 > "$STATE"
out="$(env FM_HOME="$H_BLOCKED" FM_CAPACITY_GATE_DF="$FAKE_DF" \
  FM_CAPACITY_GATE_RECLAIMER="$FAKE_RECLAIMER" FAKE_DF_STATE="$STATE" \
  FAKE_RECLAIM_MODE=nofree FM_CAPACITY_GATE_LOG="$LOGDIR/spawn.log" \
  FM_CAPACITY_GATE_LOCK="$LOGDIR/spawn.lock" \
  "$SPAWN" cap-blocked "$H_BLOCKED/no-such-home" 2>&1)"; rc=$?
if [ "$rc" = 64 ]; then ok "fm-spawn refuses a placement over the capacity ceiling"; else bad "fm-spawn should refuse over the ceiling (rc=$rc): $out"; fi
case "$out" in
  *"capacity-gate"*) ok "the spawn refusal names the capacity gate" ;;
  *) bad "the spawn refusal did not name the capacity gate: $out" ;;
esac
if ls "$H_BLOCKED"/state/*.meta >/dev/null 2>&1; then
  bad "a capacity-refused spawn left a task record behind"
else
  ok "a capacity-refused spawn leaves no task record behind"
fi

H_ALLOWED="$(spawn_home allowed)"
echo 40 > "$STATE"
out="$(env FM_HOME="$H_ALLOWED" FM_CAPACITY_GATE_DF="$FAKE_DF" \
  FM_CAPACITY_GATE_RECLAIMER="$FAKE_RECLAIMER" FAKE_DF_STATE="$STATE" \
  FM_CAPACITY_GATE_LOG="$LOGDIR/spawn2.log" FM_CAPACITY_GATE_LOCK="$LOGDIR/spawn2.lock" \
  "$SPAWN" cap-allowed "$H_ALLOWED/no-such-home" 2>&1)"; rc=$?
case "$out" in
  *"capacity-gate: REFUSED"*)
    bad "fm-spawn refused a placement under the capacity ceiling: $out" ;;
  *)
    ok "fm-spawn passes the capacity gate under the ceiling (it fails later, on the missing target: rc=$rc)" ;;
esac

# The capacity bypass must skip ONLY the capacity rule. The load ceiling is a
# different rule in a different process, and it must still bite.
H_NARROW="$(spawn_home narrow)"
HOT="$LOGDIR/load.hot"
printf '%s.00 2.00 2.00 1/1 1\n' "$(nproc)" > "$HOT"
echo 99 > "$STATE"
out="$(env FM_HOME="$H_NARROW" FM_DISPATCH_GUARD_LOADAVG="$HOT" \
  FM_DISPATCH_GUARD_LOAD_BYPASS=0 FM_CAPACITY_GATE_BYPASS=1 \
  FM_CAPACITY_GATE_DF="$FAKE_DF" FM_CAPACITY_GATE_RECLAIMER="$FAKE_RECLAIMER" \
  FAKE_DF_STATE="$STATE" FM_CAPACITY_GATE_LOG="$LOGDIR/spawn3.log" \
  FM_CAPACITY_GATE_LOCK="$LOGDIR/spawn3.lock" \
  "$SPAWN" cap-narrow "$H_NARROW/no-such-home" 2>&1)"; rc=$?
if [ "$rc" = 64 ]; then
  ok "the capacity bypass does NOT bypass the load ceiling (narrow bypass)"
else
  bad "the capacity bypass let a saturated host through (rc=$rc): $out"
fi
case "$out" in
  *"load"*) ok "the refusal names the load ceiling, not the capacity ceiling" ;;
  *) bad "expected a load-ceiling refusal, got: $out" ;;
esac
unset FM_DISPATCH_GUARD_LOAD_BYPASS FM_DISPATCH_GUARD_QUOTA_BYPASS

echo "== the reclaimer is honest about what it did =="
# --inventory prints the archive inventory and nothing else. The flag used to be
# accepted and ignored, so an operator asking for the cold material got a full
# reclaim report instead.
inv_out="$("$RECLAIMER" --inventory 2>&1)"
if printf '%s' "$inv_out" | grep -q "archive-class inventory"; then
  ok "--inventory prints the archive-class inventory"
else
  bad "--inventory did not print the archive-class inventory: $inv_out"
fi
if printf '%s' "$inv_out" | grep -q "tier 1:"; then
  bad "--inventory also ran the reclaim tiers"
else
  ok "--inventory runs no reclaim tier"
fi
# A malformed tier must be an actionable error, not a silent downgrade.
if "$RECLAIMER" --tier notanumber >/dev/null 2>&1; then
  bad "a malformed --tier must be refused"
else
  ok "a malformed --tier is refused as an actionable error"
fi
# The reclaimer must never resolve rm through PATH: on this host PATH rm is a
# recoverable-delete shim that moves the target into the trash and frees
# nothing, which is how a guard once reported freedKB=340864 having freed
# nothing.
if grep -qE 'REAL_RM|/usr/bin/rm' "$RECLAIMER" && grep -q 'shims' "$RECLAIMER"; then
  ok "the reclaimer resolves the real rm by absolute path and rejects the shim"
else
  bad "the reclaimer does not show a real-rm resolution that rejects the shim"
fi

echo
printf 'PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "TESTS FAILED"
  exit 1
fi
echo "ALL TESTS PASSED"
