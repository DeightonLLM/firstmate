#!/usr/bin/env bash
# Tests for bin/fm-crew-visibility.sh - the mechanical enforcement of "every
# spawned crewmate must be VISIBLE to the captain".
#
# Why these exist: the 2026-10-11 agy/Gemini crewmate ran 25+ minutes with an
# empty status file and nothing in the system noticed. A rule written only in a
# brief is a request, so the bound has to be enforced by code and then PROVEN by
# observed behaviour. Every assertion here runs the real detector against a real
# state dir; none of them read the script's source to decide what it "should" do.
#
# The bounds are driven through FM_CREW_VISIBILITY_NOW (the detector's documented
# test seam) so "six hours ago" is a fact rather than a six-hour sleep.
#
# Usage: tests/fm-crew-visibility.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIS="$ROOT/bin/fm-crew-visibility.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-crew-visibility.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

[ -x "$VIS" ] || { printf 'FAIL  detector is not executable: %s\n' "$VIS"; exit 1; }

NOW=1700000000

# make_crew <id> <spawn_epoch> [status-lines...] - write a meta plus an optional
# status file, both stamped with FM_CREW_VISIBILITY_NOW so "age" is exact.
make_crew() {
  local id=$1 spawned=$2; shift 2
  local dir="$TMP_ROOT/$id"
  mkdir -p "$dir"
  {
    echo "window=test:$id"
    echo "endpoint_task_id=$id"
    echo "harness=agy"
    echo "kind=ship"
    echo "spawned_at=$spawned"
  } > "$dir/$id.meta"
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$@" > "$dir/$id.status"
  fi
  printf '%s' "$dir"
}

# Set a file's mtime to <epoch> (portable across GNU and BSD touch).
set_mtime() { touch -m -t "$(date -u -d "@$2" +%Y%m%d%H%M.%S 2>/dev/null || date -u -r "$2" +%Y%m%d%H%M.%S)" "$1" 2>/dev/null; }

# breach <name> <expect-flagged:yes|no> <dir> <id> [env...]
breach() {
  local name=$1 want=$2 dir=$3 id=$4; shift 4
  local out rc
  out=$(env FM_CREW_VISIBILITY_NOW="$NOW" "$@" "$VIS" "$id" "$dir" 2>&1); rc=$?
  local got=no
  [ "$rc" = 1 ] && got=yes
  if [ "$got" != "$want" ]; then
    bad "$name (flagged=$got, want $want, rc=$rc, out=$out)"
    return 1
  fi
  if [ "$want" = yes ]; then
    case "$out" in
      *"crew-silent:"*"$id"*) ;;
      *) bad "$name (reason does not name the task: $out)"; return 1 ;;
    esac
  fi
  ok "$name"
  return 0
}

echo "== a crewmate that reports promptly is NOT flagged =="
D=$(make_crew prompt "$((NOW - 120))")
set_mtime "$D/prompt.status" "$((NOW - 60))"
breach "reported 60s ago inside the grace" no "$D" prompt

echo "== a crewmate that never reports past the grace IS flagged =="
D=$(make_crew mute "$((NOW - 400))")
out=$(env FM_CREW_VISIBILITY_NOW="$NOW" "$VIS" mute "$D" 2>&1); rc=$?
if [ "$rc" = 1 ]; then ok "never-reported crew is flagged"; else bad "never-reported crew was NOT flagged (rc=$rc: $out)"; fi
case "$out" in
  *"crew-silent: mute"*"silent 400s"*) ok "breach reason names the task and the elapsed silence" ;;
  *) bad "breach reason does not name task + silence: $out" ;;
esac
case "$out" in
  *"300s first-report grace"*) ok "breach reason names the grace it broke" ;;
  *) bad "breach reason does not name the grace: $out" ;;
esac

echo "== a crewmate that reported once and then went stale IS flagged =="
D=$(make_crew token "$((NOW - 4000))")
printf 'working: started\n' > "$D/token.status"
set_mtime "$D/token.status" "$((NOW - 1900))"
breach "one token line then 1900s of silence breaches the heartbeat" yes "$D" token
out=$(env FM_CREW_VISIBILITY_NOW="$NOW" "$VIS" token "$D" 2>&1)
case "$out" in
  *"heartbeat bound"*"last report working"*) ok "stale breach names the heartbeat bound and the last verb" ;;
  *) bad "stale breach reason is not specific: $out" ;;
esac

echo "== staleness is recomputed, never latched =="
# Same crew, same file: as time advances the silence grows and the verdict stays
# a breach, and a FRESH write must clear it. A latched detector fails this.
D=$(make_crew relatch "$((NOW - 9000))")
printf 'working: still going\n' > "$D/relatch.status"
set_mtime "$D/relatch.status" "$((NOW - 7000))"
breach "6h-old line is not a live report" yes "$D" relatch
# Same crew, same detector, silence re-evaluated at a different instant.
set_mtime "$D/relatch.status" "$((NOW - 300))"
breach "the same crew quiet 5m is inside the heartbeat" no "$D" relatch
set_mtime "$D/relatch.status" "$((NOW - 7000))"
breach "and it breaches again once silence passes the bound" yes "$D" relatch
printf 'working: still going\n' >> "$D/relatch.status"
breach "a fresh append clears the breach" no "$D" relatch

echo "== a crewmate that reported done/blocked/failed is NOT flagged =="
for verb in "done" blocked failed "needs-decision"; do
  D=$(make_crew "fin-$verb" "$((NOW - 9000))")
  printf '%s: wrapping up\n' "$verb" > "$D/fin-$verb.status"
  set_mtime "$D/fin-$verb.status" "$((NOW - 8000))"
  breach "$verb is a declared end, not a breach" no "$D" "fin-$verb"
done
D=$(make_crew fin-paused "$((NOW - 9000))")
printf 'paused: waiting on an upstream release to clear on its own\n' > "$D/fin-paused.status"
set_mtime "$D/fin-paused.status" "$((NOW - 8000))"
breach "declared external wait is not a breach" no "$D" fin-paused
D=$(make_crew fin-held "$((NOW - 9000))")
printf 'captain-held: handed to the captain directly\n' > "$D/fin-held.status"
set_mtime "$D/fin-held.status" "$((NOW - 8000))"
breach "captain-held handoff is not a breach" no "$D" fin-held

echo "== the grace period override works =="
D=$(make_crew override "$((NOW - 400))")
out=$(env FM_CREW_VISIBILITY_NOW="$NOW" FM_CREW_VISIBILITY_GRACE_SEC=900 "$VIS" override "$D" 2>&1); rc=$?
if [ "$rc" = 0 ]; then ok "a longer grace spares a 400s-silent crew"; else bad "grace override ignored (rc=$rc: $out)"; fi
out=$(env FM_CREW_VISIBILITY_NOW="$NOW" FM_CREW_VISIBILITY_GRACE_SEC=60 "$VIS" override "$D" 2>&1); rc=$?
if [ "$rc" = 1 ]; then ok "a shorter grace flags the same crew"; else bad "short grace override ignored (rc=$rc: $out)"; fi
out=$(env FM_CREW_VISIBILITY_NOW="$NOW" FM_CREW_VISIBILITY_GRACE_SEC=0 FM_CREW_VISIBILITY_STALE_SEC=0 "$VIS" override "$D" 2>&1); rc=$?
if [ "$rc" = 0 ] && [ -z "$out" ]; then ok "both bounds disabled makes the check inert"; else bad "disabling the bounds did not make it inert (rc=$rc: $out)"; fi

echo "== a back-dated or long-idle meta cannot fabricate a first-report breach =="
# Regression: a legacy meta with no spawned_at= whose mtime was back-dated (state/
# is append-only history that tooling back-dates) must not read as "a crew that
# launched in the year 2000 and never reported". This is exactly how the watcher's
# own triage fixtures simulate an old crew, and a false breach there wakes the
# supervisor on a fiction.
D="$TMP_ROOT/backdated"; mkdir -p "$D"
printf 'window=test:backdated\nkind=ship\n' > "$D/backdated.meta"
set_mtime "$D/backdated.meta" "$((NOW - 9000000))"
out=$(env FM_CREW_VISIBILITY_NOW="$NOW" "$VIS" backdated "$D" 2>&1); rc=$?
if [ "$rc" = 0 ] && [ -z "$out" ]; then
  ok "a 104-day-old meta with no spawn stamp raises no first-report breach"
else
  bad "a back-dated legacy meta produced a fabricated breach (rc=$rc): $out"
fi
# The same old meta WITH an explicit spawn stamp is judged on that stamp, and the
# trust window is what makes an unstamped record exempt rather than the age alone.
D="$TMP_ROOT/stamped"; mkdir -p "$D"
printf 'window=test:stamped\nkind=ship\nspawned_at=%s\n' "$((NOW - 400))" > "$D/stamped.meta"
set_mtime "$D/stamped.meta" "$((NOW - 9000000))"
breach "an explicit spawn stamp wins over an old meta mtime" yes "$D" stamped
# The heartbeat bound is unaffected by the trust window.
printf 'working: long job\n' > "$D/stamped.status"
set_mtime "$D/stamped.status" "$((NOW - 2000))"
breach "an old unstamped record still breaches on the heartbeat" yes "$D" stamped

echo "== harness-agnostic: an unregistered adapter is still checked =="
D="$TMP_ROOT/agnostic"; mkdir -p "$D"
{ echo "window=test:agnostic"; echo "harness=some-future-cli"; echo "kind=scout"; echo "spawned_at=$((NOW - 900))"; } > "$D/agnostic.meta"
breach "an unknown harness is subject to the same bound" yes "$D" agnostic

echo "== inert when there is no crew to check =="
mkdir -p "$TMP_ROOT/empty"
out=$(env FM_CREW_VISIBILITY_NOW="$NOW" "$VIS" no-such-task "$TMP_ROOT/empty" 2>&1); rc=$?
if [ "$rc" = 0 ] && [ -z "$out" ]; then ok "an unknown task id is silently not-a-breach"; else bad "unknown task id produced output (rc=$rc: $out)"; fi
# An idle home whose recorded crews all ended must produce no breach storm.
IDLE="$TMP_ROOT/idle"; mkdir -p "$IDLE"
for i in $(seq 1 40); do
  printf 'window=gone-%s\nspawned_at=%s\n' "$i" "$((NOW - 90000))" > "$IDLE/old$i.meta"
  printf 'done: shipped and torn down\n' > "$IDLE/old$i.status"
done
storm=0
for i in $(seq 1 40); do
  out=$(env FM_CREW_VISIBILITY_NOW="$NOW" "$VIS" "old$i" "$IDLE" 2>&1) || storm=$((storm + 1))
done
if [ "$storm" = 0 ]; then ok "40 finished crews in an idle home produce zero breaches"; else bad "$storm of 40 finished crews were flagged"; fi

echo "== the composed breach reason is one the watcher actually wakes on =="
# Detection alone is not surfacing. bin/fm-watch.sh enqueues this as a `stale:`
# wake and prints the reason, and bin/fm-watch-arm.sh decides from that printed
# line whether the supervisor is woken at all - a reason the arm layer does not
# recognise would print into the void and reproduce exactly the invisible-agent
# failure. Both the real detector and the real arm recogniser are exercised here.
ARM_FN="$TMP_ROOT/arm-wake-fn.sh"
sed -n '/^watch_output_has_wake()/,/^}/p' "$ROOT/bin/fm-watch-arm.sh" > "$ARM_FN"
if [ ! -s "$ARM_FN" ]; then
  bad "could not load watch_output_has_wake from bin/fm-watch-arm.sh; wake-recognition left unverified"
else
  # shellcheck source=/dev/null
  . "$ARM_FN"
  D=$(make_crew armcheck "$((NOW - 400))")
  vline=$(env FM_CREW_VISIBILITY_NOW="$NOW" "$VIS" armcheck "$D" 2>/dev/null || true)
  if [ -z "$vline" ]; then
    bad "detector produced no line for the arm-recognition case"
  else
    composed="stale: test:armcheck ($vline)"
    # watch_output_has_wake takes the PATH of the captured watcher output, which
    # is how fm-watch-arm.sh calls it, so drive it the same way.
    printf '%s\n' "$composed" > "$TMP_ROOT/arm-output.txt"
    if watch_output_has_wake "$TMP_ROOT/arm-output.txt"; then
      ok "the composed crew-silent reason is recognized as a supervisor wake"
    else
      bad "the composed crew-silent reason would NOT wake the supervisor: $composed"
    fi
  fi
fi

echo "== the detector never writes to the crew's own state =="
D=$(make_crew nowrite "$((NOW - 4000))")
printf 'working: in progress\n' > "$D/nowrite.status"
set_mtime "$D/nowrite.status" "$((NOW - 3000))"
before=$(cat "$D/nowrite.status")
env FM_CREW_VISIBILITY_NOW="$NOW" "$VIS" nowrite "$D" >/dev/null 2>&1 || true
after=$(cat "$D/nowrite.status")
if [ "$before" = "$after" ]; then ok "detection does not append to the crew's status log"; else bad "detection mutated the crew's status log"; fi

echo
printf 'PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && { echo "TESTS FAILED"; exit 1; }
echo "ALL TESTS PASSED"