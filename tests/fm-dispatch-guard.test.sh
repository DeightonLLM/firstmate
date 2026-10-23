#!/usr/bin/env bash
# Tests for bin/fm-dispatch-guard.sh - the spawn-boundary enforcement of fleet rules.
#
# These exist because the guard's first two rules were silently decorative: the
# quota parser could never match quota-axi output, the lane cap counted every
# state/*.meta ever written, and the global bypass rescued the Sol ban that was
# supposed to have no bypass. Each of those passed inspection and would have
# shipped looking like enforcement. So each rule is asserted here by observed
# behaviour, not by reading the code.
#
# Usage: tests/fm-dispatch-guard.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/bin/fm-dispatch-guard.sh"
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

# assert_refuse <name> <expect-rc> <harness> <model> [env...]
assert_refuse() {
  name="$1"; want_rc="$2"; harness="$3"; model="$4"; shift 4
  out="$(env "$@" "$GUARD" "$harness" "$model" 2>&1)"; rc=$?
  if [ "$rc" != "$want_rc" ]; then
    bad "$name (rc=$rc, want $want_rc)"; return
  fi
  case "$out" in
    *REFUSED*) : ;;
    *) bad "$name (no REFUSED reason on stderr: $out)"; return ;;
  esac
  case "$out" in
    *"${5:-}"*) : ;;
  esac
  ok "$name"
}

# assert_allow <name> <harness> <model> [env...]
assert_allow() {
  name="$1"; harness="$2"; model="$3"; shift 3
  out="$(env "$@" "$GUARD" "$harness" "$model" 2>&1)"; rc=$?
  if [ "$rc" = 0 ]; then ok "$name"; else bad "$name (rc=$rc: $out)"; fi
}

[ -x "$GUARD" ] || { echo "FAIL  guard is not executable: $GUARD"; exit 1; }

LOGDIR="$(mktemp -d)"
export FM_DISPATCH_GUARD_LOG="$LOGDIR/guard.log"
# Hermetic home for every assertion that is NOT about Rule 3. The suite used to
# export FM_HOME="$ROOT", which made the lane rule read the host's real fleet
# state: slow (one probe per recorded meta) and wrong (a Controller running its
# own cap number of live lanes failed every Rule 1/2/4 assertion for reasons that
# had nothing to do with them). An empty scratch state/ is the honest fixture
# here - Rule 3 gets its own populated home below.
export FM_HOME="$LOGDIR/basehome"
mkdir -p "$FM_HOME/state"

# --- quota evidence for the WHOLE suite --------------------------------------
#
# QUOTA_AXI_SNAPSHOT must point at a REAL quota-axi cache file - a hand-written
# JSON fixture is rejected with VALIDATION_ERROR, which made an earlier version
# of this test assert against a fixture the tool never read. So the fixture is
# derived from the real cache, with every window's percentRemaining NORMALISED
# to a healthy value.
#
# The live cache is not a fixture: on a host where any window has actually run
# out, the unmodified cache is not healthy, and every assertion in this suite
# that is about a different rule then failed for a reason that had nothing to
# do with that rule. Normalising the readings keeps the schema real - which is
# the part quota-axi validates - while making the evidence mean what it says.
#
# The snapshot is exported for every assertion so the suite is deterministic on
# any host. Rule 4 below overrides it per assertion with its own fixtures.
CACHE="${QUOTA_AXI_CACHE:-$HOME/.cache/quota-axi/quotas.json}"
SNAP=""
DEAD=""
if [ ! -r "$CACHE" ]; then
  bad "quota-axi cache not readable at $CACHE (Rule 4 left unverified)"
else
  SNAP="$LOGDIR/quota.healthy.cache"
  jq '(.providers[]?.windows[]?) |= (.percentRemaining = 100)' "$CACHE" > "$SNAP" 2>/dev/null
  DEAD="$LOGDIR/quota.dead.cache"
  jq '(.providers[]?.windows[]?) |= (.percentRemaining = 0)' "$SNAP" > "$DEAD" 2>/dev/null
  export QUOTA_AXI_SNAPSHOT="$SNAP"
fi

echo "== Rule 1: gpt-6.1-sol ban (no bypass) =="
assert_refuse "sol is refused" 64 codex gpt-6.1-sol
assert_refuse "sol variant is refused" 64 codex openai-codex/gpt-6.1-sol
assert_refuse "sol is NOT rescued by the global bypass" 64 codex gpt-6.1-sol FM_DISPATCH_GUARD_BYPASS=1
assert_refuse "codex with no --model is refused (config.toml defaults to Sol)" 64 codex ""
assert_allow "a legal codex model is allowed" codex gpt-6-luna
assert_allow "a non-codex harness with no model is allowed (no Sol risk)" pi ""

# The ban belongs to the MODEL VALUE, not to the adapter name. A reviewer found
# the guard keyed the empty-model refusal on the harness name while a configured
# model could arrive from config/secondmate-harness against any other adapter;
# these pin that the value itself is what is judged.
assert_refuse "a banned model on pi is refused" 64 pi gpt-6.1-sol
assert_refuse "a banned model on claude is refused" 64 claude gpt-6.1-sol
assert_refuse "a banned model on agy is refused" 64 agy gpt-6.1-sol
assert_refuse "a banned model on an unknown adapter is refused" 64 some-future-harness gpt-6.1-sol
# A legal, non-quota-mapped model on a non-codex adapter is allowed: the ban is
# the model value's property, not the adapter's.
assert_allow "a legal model on pi is allowed" pi some-legal-model

echo "== Rule 2: load ceiling =="
assert_allow "load below ceiling is allowed" agy gemini-3.1-pro-high
assert_allow "load bypass is honoured and logged" agy gemini-3.1-pro-high FM_DISPATCH_GUARD_LOAD_BYPASS=1
if grep -q BYPASS_LOAD "$FM_DISPATCH_GUARD_LOG" 2>/dev/null; then
  ok "load bypass is logged, never silent"
else
  bad "load bypass was not logged"
fi

# Unreadable load evidence. The rule used to substitute 0 for a failed read, so
# a host whose /proc/loadavg could not be read reported "load 0" and passed the
# ceiling silently - the one outcome a load ceiling must never produce.
NOLOAD="$LOGDIR/no-such-loadavg"
printf 'not a load file\n' > "$LOGDIR/load.garbage"
assert_refuse "an unreadable /proc/loadavg fails closed" 64 agy gemini-3.1-pro-high \
  FM_DISPATCH_GUARD_LOADAVG="$NOLOAD" FM_DISPATCH_GUARD_QUOTA_BYPASS=1
assert_refuse "an unparseable load reading fails closed" 64 agy gemini-3.1-pro-high \
  FM_DISPATCH_GUARD_LOADAVG="$LOGDIR/load.garbage" FM_DISPATCH_GUARD_QUOTA_BYPASS=1 \
  FM_DISPATCH_GUARD_LOG="$LOGDIR/garbage.log"
assert_allow "the documented load bypass still covers an unreadable load" agy gemini-3.1-pro-high \
  FM_DISPATCH_GUARD_LOADAVG="$NOLOAD" FM_DISPATCH_GUARD_LOAD_BYPASS=1
assert_allow "the global bypass still covers an unreadable load" agy gemini-3.1-pro-high \
  FM_DISPATCH_GUARD_LOADAVG="$NOLOAD" FM_DISPATCH_GUARD_BYPASS=1

# The ceiling itself: refuse at int(1-min load) >= cores, allow below it, with
# the truncation pinned so the boundary cannot drift silently.
CORES="$(nproc)"
HOT="$LOGDIR/load.hot"
COOL="$LOGDIR/load.cool"
printf '%s.00 2.00 2.00 1/1 1\n' "$CORES" > "$HOT"
printf '%s.99 2.00 2.00 1/1 1\n' "$((CORES - 1))" > "$COOL"
assert_refuse "load at the core count refuses" 64 agy gemini-3.1-pro-high \
  FM_DISPATCH_GUARD_LOADAVG="$HOT" FM_DISPATCH_GUARD_QUOTA_BYPASS=1 \
  FM_DISPATCH_GUARD_LOG="$LOGDIR/hot.log"
assert_allow "load just below the core count is allowed" agy gemini-3.1-pro-high \
  FM_DISPATCH_GUARD_LOADAVG="$COOL" FM_DISPATCH_GUARD_QUOTA_BYPASS=1 \
  FM_DISPATCH_GUARD_LOG="$LOGDIR/cool.log"

# A refusal is not a bypass. The refusing branch used to log BYPASS_LOAD, which
# made "the host was saturated" indistinguishable in the audit log from "an
# operator skipped the check".
if grep -q BYPASS_LOAD "$LOGDIR/hot.log" 2>/dev/null; then
  bad "a genuine load refusal was logged as BYPASS_LOAD"
else
  ok "a genuine load refusal is not logged as BYPASS_LOAD"
fi
if grep -q LOAD_REFUSED "$LOGDIR/hot.log" 2>/dev/null; then
  ok "a genuine load refusal is logged as LOAD_REFUSED"
else
  bad "a genuine load refusal was not logged as LOAD_REFUSED"
fi

echo "== Rule 3: live-lane ceiling =="
# Hermetic: the guard counts a lane only when the tmux session named in its
# meta still exists, so this builds its own session, meta, and FM_HOME rather
# than depending on the host's real fleet state. The first version of this test
# read the repo's live state/, which meant it passed on the Controller and
# failed in a fresh worktree where gitignored state/ does not exist.
TFMHOME="$LOGDIR/home"
mkdir -p "$TFMHOME/state"
TSESS="fmguardtest$$"
tmux new-session -d -s "$TSESS" -n w1 "sleep 300" 2>/dev/null
cleanup() { tmux kill-session -t "$TSESS" 2>/dev/null || true; }
trap cleanup EXIT

if ! tmux has-session -t "$TSESS" 2>/dev/null; then
  bad "could not create the test tmux session; Rule 3 left unverified"
else
  printf 'window=%s:w1:%%0\nendpoint_task_id=guardtest\nharness=agy\n' "$TSESS" \
    > "$TFMHOME/state/guardtest.meta"
  # Dead-session metas: history that must NOT count as a live lane. This is the
  # regression that would have wedged the fleet shut as state/ accumulated.
  for i in $(seq 1 120); do
    printf 'window=gone-%s:w1:%%0\nendpoint_task_id=stale%s\n' "$i" "$i" \
      > "$TFMHOME/state/stale$i.meta"
  done

  assert_refuse "one live lane refuses at cap 1" 64 agy gemini-3.1-pro-high \
    FM_HOME="$TFMHOME" FM_DISPATCH_GUARD_MAX_LANES=1
  assert_allow "one live lane is allowed at cap 2" agy gemini-3.1-pro-high \
    FM_HOME="$TFMHOME" FM_DISPATCH_GUARD_MAX_LANES=2

  # With the one live lane's meta moved aside, 120 stale metas remain and the cap
  # of 1 must still ALLOW. If stale metas counted, this would be 120 live lanes
  # and would refuse - which is the exact wedge that would have made the fleet
  # undispatchable once state/ accumulated.
  mv "$TFMHOME/state/guardtest.meta" "$LOGDIR/guardtest.meta.moved"
  assert_allow "120 stale metas do NOT count as live lanes" agy gemini-3.1-pro-high \
    FM_HOME="$TFMHOME" FM_DISPATCH_GUARD_MAX_LANES=1
  assert_allow "lane rule is inert without an FM_HOME state dir" agy gemini-3.1-pro-high \
    FM_HOME="$LOGDIR/nohome"

  # --- lanes, not sessions -------------------------------------------------
  # One tmux session hosts every crew that shares it plus windows that belong to
  # nobody in state/. The old rule asked whether the SESSION was alive, so it
  # counted a crew whose window had been closed as a live lane and refused at
  # the cap for lanes that no longer existed.

  # (a) two crews sharing one session are two lanes
  tmux new-window -t "$TSESS" -n w2 "sleep 300"
  tmux new-window -t "$TSESS" -n unrelated "sleep 300"
  printf 'window=%s:w2\nendpoint_task_id=guardtest2\nharness=agy\n' "$TSESS" \
    > "$TFMHOME/state/guardtest2.meta"
  mv "$LOGDIR/guardtest.meta.moved" "$TFMHOME/state/guardtest.meta"
  assert_refuse "two crews in one tmux session count as two lanes" 64 agy gemini-3.1-pro-high \
    FM_HOME="$TFMHOME" FM_DISPATCH_GUARD_MAX_LANES=2 FM_DISPATCH_GUARD_QUOTA_BYPASS=1
  assert_allow "two lanes are allowed at cap 3 (the unrelated window is nobody's lane)" \
    agy gemini-3.1-pro-high \
    FM_HOME="$TFMHOME" FM_DISPATCH_GUARD_MAX_LANES=3 FM_DISPATCH_GUARD_QUOTA_BYPASS=1

  # (b) one crew among unrelated panes in that session is one lane
  mv "$TFMHOME/state/guardtest2.meta" "$LOGDIR/guardtest2.meta.moved"
  assert_refuse "one crew among unrelated panes counts as one live lane" 64 agy gemini-3.1-pro-high \
    FM_HOME="$TFMHOME" FM_DISPATCH_GUARD_MAX_LANES=1 FM_DISPATCH_GUARD_QUOTA_BYPASS=1
  assert_allow "one live lane is allowed at cap 2" agy gemini-3.1-pro-high \
    FM_HOME="$TFMHOME" FM_DISPATCH_GUARD_MAX_LANES=2 FM_DISPATCH_GUARD_QUOTA_BYPASS=1

  # (c) a crew whose window is gone while its session lives is NOT a lane. This
  # is the false refusal the session-level count produced: with one real lane
  # plus this dead-window meta, cap 2 is the point where a session-level count
  # refused and a lane-level count must allow.
  printf 'window=%s:window-that-never-existed\nendpoint_task_id=guardtest3\nharness=agy\n' "$TSESS" \
    > "$TFMHOME/state/guardtest3.meta"
  assert_allow "a dead window in a live session does not count as a lane" agy gemini-3.1-pro-high \
    FM_HOME="$TFMHOME" FM_DISPATCH_GUARD_MAX_LANES=2 FM_DISPATCH_GUARD_QUOTA_BYPASS=1
  assert_refuse "the one real lane is still counted" 64 agy gemini-3.1-pro-high \
    FM_HOME="$TFMHOME" FM_DISPATCH_GUARD_MAX_LANES=1 FM_DISPATCH_GUARD_QUOTA_BYPASS=1
  mv "$TFMHOME/state/guardtest3.meta" "$LOGDIR/guardtest3.meta.moved"

  # (d) the inventory is bounded, and an inventory that cannot finish refuses
  # rather than counting a partial fleet.
  assert_refuse "an unfinished lane inventory refuses instead of allowing" 64 agy gemini-3.1-pro-high \
    FM_HOME="$TFMHOME" FM_DISPATCH_GUARD_MAX_LANES=99 FM_DISPATCH_GUARD_LANE_BUDGET_S=0 \
    FM_DISPATCH_GUARD_QUOTA_BYPASS=1
  assert_allow "a lane budget of 99 allows the same fleet" agy gemini-3.1-pro-high \
    FM_HOME="$TFMHOME" FM_DISPATCH_GUARD_MAX_LANES=99 FM_DISPATCH_GUARD_QUOTA_BYPASS=1

  # (e) a meta whose endpoint cannot be placed at all is disclosed, not silent
  printf 'endpoint_task_id=nolane\nharness=agy\n' > "$TFMHOME/state/nolane.meta"
  : > "$LOGDIR/lanefix.log"
  env FM_HOME="$TFMHOME" FM_DISPATCH_GUARD_MAX_LANES=99 FM_DISPATCH_GUARD_QUOTA_BYPASS=1 \
    FM_DISPATCH_GUARD_LOG="$LOGDIR/lanefix.log" "$GUARD" agy gemini-3.1-pro-high >/dev/null 2>&1
  if grep -q LANE_UNRESOLVED "$LOGDIR/lanefix.log" 2>/dev/null; then
    ok "a meta with no resolvable endpoint is disclosed in the log"
  else
    bad "a meta with no resolvable endpoint was dropped silently"
  fi
  mv "$TFMHOME/state/nolane.meta" "$LOGDIR/nolane.meta.moved"
fi

echo "== Rule 4: quota ceiling =="
# The healthy and the dead fixtures are built at the top of this suite, so
# every assertion here inherits a deterministic healthy snapshot and varies
# it explicitly for the rule under test.

if [ -n "$SNAP" ]; then
  assert_refuse "exhausted provider is refused" 64 pi minimax/MiniMax-M2.7 QUOTA_AXI_SNAPSHOT="$DEAD"
  assert_allow "healthy provider is allowed" agy gemini-3.1-pro-high QUOTA_AXI_SNAPSHOT="$SNAP"
  assert_allow "quota bypass is honoured" agy gemini-3.1-pro-high QUOTA_AXI_SNAPSHOT="$DEAD" FM_DISPATCH_GUARD_QUOTA_BYPASS=1
  assert_allow "codex passes on its most constrained window" codex gpt-6-luna QUOTA_AXI_SNAPSHOT="$SNAP"
  # A harness with no mapped provider must never block.
  assert_allow "unmapped harness never blocks" claude some-model QUOTA_AXI_SNAPSHOT="$SNAP"
  # A snapshot that answers nothing must not block: unknown is disclosed
  # uncertainty, and a quota bug must never be able to wedge the whole fleet.
  NOSNAP="$LOGDIR/empty.cache"
  printf '{"schemaVersion":5,"providers":[]}' > "$NOSNAP"
  assert_allow "missing quota evidence never blocks" agy gemini-3.1-pro-high QUOTA_AXI_SNAPSHOT="$NOSNAP"
  # An unreadable snapshot must not block either.
  assert_allow "unreadable quota evidence never blocks" agy gemini-3.1-pro-high QUOTA_AXI_SNAPSHOT="$LOGDIR/does-not-exist"
fi

echo "== Rule 4 scoping: never refuse on a window the spawn does not use =="
# Regression found by independent review of a live guard: the rule took the
# provider-wide MINIMUM across all windows, so an exhausted UNUSED agy
# claude_gpt window refused a Gemini spawn. That is a live over-refusal that
# would have wedged Gemini precisely when Claude's window died.
SCOPED="$LOGDIR/quota.scoped.cache"
DEADGEM="$LOGDIR/quota.deadgemini.cache"
if [ -r "$CACHE" ]; then
  # Derive from the REAL cache - quota-axi rejects hand-written snapshots with
  # VALIDATION_ERROR, which would make the guard fail open and turn every
  # "allow" assertion into a false pass - and normalise the readings, so the
  # fixture does not inherit an exhausted window from the live host state.
  jq '(.providers[]? | select(.provider=="agy") | .windows[]?
        | select((.id // "") | test("claude_gpt"))) |= (.percentRemaining = 0)' \
    "$SNAP" > "$SCOPED" 2>/dev/null
  jq '(.providers[]? | select(.provider=="agy") | .windows[]?
        | select((.id // "") | test("gemini"))) |= (.percentRemaining = 0)' \
    "$SNAP" > "$DEADGEM" 2>/dev/null
fi

if [ -s "$SCOPED" ] && [ -s "$DEADGEM" ]; then
  # Guard against a fixture that does not actually carry the windows we need.
  if jq -e 'any(.providers[]? | select(.provider=="agy") | .windows[]?;
              (.id|test("claude_gpt")) and .percentRemaining==0)' "$SCOPED" >/dev/null 2>&1 \
     && jq -e 'any(.providers[]? | select(.provider=="agy") | .windows[]?;
                     (.id|test("gemini")) and .percentRemaining==0)' "$DEADGEM" >/dev/null 2>&1; then
    assert_allow "gemini spawn ALLOWED even when the unused claude window is 0%" agy gemini-3.1-pro-high QUOTA_AXI_SNAPSHOT="$SCOPED"
    assert_refuse "a claude model on the dead claude window IS still refused" 64 agy claude-opus-5-5-high QUOTA_AXI_SNAPSHOT="$SCOPED"
    assert_refuse "a genuinely dead gemini window IS refused" 64 agy gemini-3.1-pro-high QUOTA_AXI_SNAPSHOT="$DEADGEM"
  else
    bad "scoped quota fixtures are invalid - Rule 4 scoping left unverified"
  fi
else
  bad "could not derive scoped quota fixtures from $CACHE - Rule 4 scoping left unverified"
fi

echo "== global bypass =="
assert_allow "global bypass allows a legal model" agy gemini-3.1-pro-high FM_DISPATCH_GUARD_BYPASS=1

echo "== spawn boundary: the guard is handed the RESOLVED model =="
# A reviewer found the guard call site running BEFORE the block that resolves a
# secondmate's model from config/secondmate-harness, so a secondmate configured
# with a banned model reached the guard as an empty model and was never checked.
# These cases observe the guard's OWN record of its arguments (its audit log,
# which it now writes for allowed invocations too) at the real call site of the
# real fm-spawn.sh, rather than reading the code.
#
# Every case runs against a scratch FM_HOME and a target that does not exist, so
# a spawn that passes the guard still aborts on the missing home or the missing
# brief - before any worktree, endpoint, or meta can be created. Nothing here
# can launch an agent CLI even if the guard is broken.
SB="$LOGDIR/spawn"
spawn_home() {  # <name>
  local h="$SB/$1"
  mkdir -p "$h/state" "$h/config" "$h/data" "$h/projects"
  printf '%s\n' "$h"
}

# These cases are about MODEL RESOLUTION only, so the host's load and quota are
# taken out of the picture (both are logged bypasses). The Sol ban is evaluated
# before any bypass, so nothing here weakens the assertions it makes.
export FM_DISPATCH_GUARD_LOAD_BYPASS=1
export FM_DISPATCH_GUARD_QUOTA_BYPASS=1

# assert_guard_saw <name> <want-rc> <want-log-args> <home> <id> <argv...>
# Runs the REAL fm-spawn.sh and asserts what the guard recorded as its own
# arguments, then that a refused spawn created no task state and no worktree.
assert_guard_saw() {
  name="$1"; want_rc="$2"; want="$3"; home="$4"; id="$5"; shift 5
  lg="$LOGDIR/spawn-$id.log"
  out="$(env FM_HOME="$home" FM_DISPATCH_GUARD_LOG="$lg" \
    "$ROOT/bin/fm-spawn.sh" "$id" "$@" 2>&1)"; rc=$?
  if [ "$rc" != "$want_rc" ]; then
    bad "$name (rc=$rc, want $want_rc: $out)"; return
  fi
  if [ -n "$want" ] && ! grep -qF "$want" "$lg" 2>/dev/null; then
    bad "$name (guard was not handed [$want]; log: $(tr '\n' '|' < "$lg" 2>/dev/null))"; return
  fi
  case "$out" in
    *dispatch-guard*) : ;;
    *) bad "$name (no guard refusal in the spawn output: $out)"; return ;;
  esac
  # A refused spawn leaves nothing behind: no task meta, no worktree.
  if ls "$home"/state/*.meta >/dev/null 2>&1; then
    bad "$name (a meta was left behind: $(ls "$home"/state/*.meta))"; return
  fi
  if [ -n "$(ls -A "$home/projects" 2>/dev/null)" ]; then
    bad "$name (worktree state left behind: $(ls -A "$home/projects"))"; return
  fi
  ok "$name"
}

H_PI=$(spawn_home pi)
H_CLAUDE=$(spawn_home claude)
H_AGY=$(spawn_home agy)
H_RAW=$(spawn_home raw)
H_CODEX=$(spawn_home codex)

# The reviewer's exact trigger inputs: config/secondmate-harness pins a banned
# model against non-codex adapters. Before the ordering fix the guard saw an
# empty model on this path and allowed the launch.
printf 'pi gpt-6.1-sol\n' > "$H_PI/config/secondmate-harness"
assert_guard_saw "secondmate configured 'pi gpt-6.1-sol' is REFUSED by the guard" 64 \
  "harness=pi model=gpt-6.1-sol" "$H_PI" sm-pi "$H_PI/no-such-home" --secondmate

printf 'claude gpt-6.1-sol\n' > "$H_CLAUDE/config/secondmate-harness"
assert_guard_saw "secondmate configured 'claude gpt-6.1-sol' is REFUSED by the guard" 64 \
  "harness=claude model=gpt-6.1-sol" "$H_CLAUDE" sm-claude "$H_CLAUDE/no-such-home" --secondmate

printf 'agy openai-codex/gpt-6.1-sol\n' > "$H_AGY/config/secondmate-harness"
assert_guard_saw "secondmate configured 'agy <variant>/gpt-6.1-sol' is REFUSED by the guard" 64 \
  "harness=agy model=openai-codex/gpt-6.1-sol" "$H_AGY" sm-agy "$H_AGY/no-such-home" --secondmate

# The raw-launch path: the model rides inside the launch command, where no flag
# parser will ever see it, so the guard call site has to extract it.
assert_guard_saw "a raw launch command's own --model reaches the guard" 64 \
  "harness=true model=gpt-6.1-sol" "$H_RAW" raw-model "$LOGDIR/no-such-repo" \
  "true --model gpt-6.1-sol"

# The ship path with an explicit flag was always checked; assert it still is, on
# the real spawn path, and that it refuses before creating anything.
assert_guard_saw "an explicit banned --model is REFUSED on the ship path" 64 \
  "harness=codex model=gpt-6.1-sol" "$H_CODEX" ship-sol "$LOGDIR/no-such-repo" \
  --harness codex --model gpt-6.1-sol --backend tmux

# The ordering fix must not turn a legal configured model into an unresolved one:
# an empty model on codex fails closed, so a secondmate configured with a legal
# model proves the resolved value reached the guard rather than "".
H_OK=$(spawn_home ok)
printf 'codex gpt-6-luna\n' > "$H_OK/config/secondmate-harness"
lg="$LOGDIR/spawn-sm-legal.log"
out="$(env FM_HOME="$H_OK" FM_DISPATCH_GUARD_LOG="$lg" \
  "$ROOT/bin/fm-spawn.sh" sm-legal "$H_OK/no-such-home" --secondmate 2>&1)"; rc=$?
if [ "$rc" = 64 ]; then
  bad "a legal configured model was refused (rc=64): $out"
elif ! grep -qF "harness=codex model=gpt-6-luna" "$lg" 2>/dev/null; then
  bad "a legal configured model never reached the guard (log: $(tr '\n' '|' < "$lg" 2>/dev/null))"
elif ls "$H_OK"/state/*.meta >/dev/null 2>&1; then
  bad "a legal spawn created a meta before reaching its missing home"
else
  ok "a legal configured model is resolved and passed to the guard"
fi
unset FM_DISPATCH_GUARD_LOAD_BYPASS FM_DISPATCH_GUARD_QUOTA_BYPASS

echo
printf 'PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "TESTS FAILED"
  exit 1
fi
echo "ALL TESTS PASSED"