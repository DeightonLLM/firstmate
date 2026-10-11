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
export FM_HOME="$ROOT"

echo "== Rule 1: gpt-6.1-sol ban (no bypass) =="
assert_refuse "sol is refused" 64 codex gpt-6.1-sol
assert_refuse "sol variant is refused" 64 codex openai-codex/gpt-6.1-sol
assert_refuse "sol is NOT rescued by the global bypass" 64 codex gpt-6.1-sol FM_DISPATCH_GUARD_BYPASS=1
assert_refuse "codex with no --model is refused (config.toml defaults to Sol)" 64 codex ""
assert_allow "a legal codex model is allowed" codex gpt-6-luna
assert_allow "a non-codex harness with no model is allowed (no Sol risk)" pi ""

echo "== Rule 2: load ceiling =="
assert_allow "load below ceiling is allowed" agy gemini-3.1-pro-high
assert_allow "load bypass is honoured and logged" agy gemini-3.1-pro-high FM_DISPATCH_GUARD_LOAD_BYPASS=1
if grep -q BYPASS_LOAD "$FM_DISPATCH_GUARD_LOG" 2>/dev/null; then
  ok "load bypass is logged, never silent"
else
  bad "load bypass was not logged"
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
fi

echo "== Rule 4: quota ceiling =="
# QUOTA_AXI_SNAPSHOT must point at a REAL quota-axi cache file - a hand-written
# JSON fixture is rejected with VALIDATION_ERROR, which made an earlier version
# of this test assert against a fixture the tool never read. So the fixtures are
# derived from the real cache: one unmodified, one with every window zeroed.
CACHE="${QUOTA_AXI_CACHE:-$HOME/.cache/quota-axi/quotas.json}"
if [ ! -r "$CACHE" ]; then
  bad "quota-axi cache not readable at $CACHE (Rule 4 left unverified)"
  SNAP=""
else
  SNAP="$LOGDIR/quota.live.cache"
  cp "$CACHE" "$SNAP"
  DEAD="$LOGDIR/quota.dead.cache"
  jq '(.providers[]?.windows[]?) |= (.percentRemaining = 0)' "$SNAP" > "$DEAD" 2>/dev/null
fi

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

echo "== global bypass =="
assert_allow "global bypass allows a legal model" agy gemini-3.1-pro-high FM_DISPATCH_GUARD_BYPASS=1

echo
printf 'PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "TESTS FAILED"
  exit 1
fi
echo "ALL TESTS PASSED"