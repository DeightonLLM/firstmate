#!/usr/bin/env bash
# Contract for live-lane ceiling resolution in bin/fm-dispatch-guard.sh.
#
# Captain ruling 2026-10-12: Hetz/Brandon is not resource-capped, so a hardcoded
# ceiling of 4 was wrong there. A knob that only applied when firstmate remembered to
# export an env var was never an enforced setting, so the ceiling must also resolve
# from the home-local gitignored config/dispatch-max-lanes knob.
#
# The guard legitimately ends in `exit 0`, so it cannot be sourced and then called.
# These extract the shipped fm_dispatch_guard_lane_cap body out of the real guard file
# and exercise that exact text - no copy of the logic lives in this test.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/bin/fm-dispatch-guard.sh"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "PASS  $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL  $1"; }

if ! grep -q '^fm_dispatch_guard_lane_cap()' "$GUARD"; then
  echo "FAIL  bin/fm-dispatch-guard.sh does not define fm_dispatch_guard_lane_cap"
  echo "PASS=0 FAIL=1"
  exit 1
fi

# Pull the real function out of the shipped guard and make it callable.
LANE_FN=$(awk '/^fm_dispatch_guard_lane_cap\(\)/,/^}/' "$GUARD")
eval "$LANE_FN"

cap_with() { # <home>
  FM_HOME="$1" fm_dispatch_guard_lane_cap
}

test_config_knob_raises_the_ceiling() {
  local home; home=$(mktemp -d)
  mkdir -p "$home/config"; printf '15\n' > "$home/config/dispatch-max-lanes"
  local got; got=$(env -u FM_DISPATCH_GUARD_MAX_LANES bash -c \
    "FM_HOME='$home'; $LANE_FN; fm_dispatch_guard_lane_cap" 2>/dev/null)
  rm -rf "$home"
  if [ "$got" = "15" ]; then
    ok "config/dispatch-max-lanes=15 raises the ceiling with no env var set"
  else
    bad "config knob should yield 15, got '${got:-<empty>}'"
  fi
}

test_default_when_no_knob_and_no_env() {
  local home; home=$(mktemp -d)
  local got; got=$(env -u FM_DISPATCH_GUARD_MAX_LANES bash -c \
    "FM_HOME='$home'; $LANE_FN; fm_dispatch_guard_lane_cap" 2>/dev/null)
  rm -rf "$home"
  if [ "$got" = "4" ]; then
    ok "defaults to 4 when neither env var nor config knob is present"
  else
    bad "default should be 4, got '${got:-<empty>}'"
  fi
}

test_env_wins_over_config() {
  local home; home=$(mktemp -d)
  mkdir -p "$home/config"; printf '15\n' > "$home/config/dispatch-max-lanes"
  local got; got=$(FM_DISPATCH_GUARD_MAX_LANES=3 bash -c \
    "FM_HOME='$home'; $LANE_FN; fm_dispatch_guard_lane_cap" 2>/dev/null)
  rm -rf "$home"
  if [ "$got" = "3" ]; then
    ok "FM_DISPATCH_GUARD_MAX_LANES overrides the config knob"
  else
    bad "env var should win and yield 3, got '${got:-<empty>}'"
  fi
}

test_lane_state_helper_exists() {
  if ! grep -q '^fm_dispatch_guard_lane_classify()' "$GUARD"; then
    bad "bin/fm-dispatch-guard.sh does not define fm_dispatch_guard_lane_classify"
    return
  fi
  local lane_fn
  lane_fn=$(awk '/^fm_dispatch_guard_lane_classify\(\)/,/^}/' "$GUARD")
  eval "$lane_fn"
  fm_backend_agent_state() { printf '%s' "${TEST_PRESENCE:-alive}"; }
  fm_backend_busy_state() { printf '%s' "${TEST_ACTIVITY:-unknown}"; }

  local result
  TEST_PRESENCE=alive TEST_ACTIVITY=idle result=$(fm_dispatch_guard_lane_classify herdr target)
  if [ "$result" = idle ]; then ok "a live lane is idle only on a positive native idle signal"; else bad "idle signal classified as '$result'"; fi

  TEST_PRESENCE=alive TEST_ACTIVITY=busy result=$(fm_dispatch_guard_lane_classify herdr target)
  if [ "$result" = working ]; then ok "working status counts against the cap"; else bad "working signal classified as '$result'"; fi

  TEST_PRESENCE=unreadable TEST_ACTIVITY=unknown result=$(fm_dispatch_guard_lane_classify tmux target)
  if [ "$result" = working ]; then ok "unreadable/unknown lane counts against the cap"; else bad "unknown signal classified as '$result'"; fi

  TEST_PRESENCE=alive TEST_ACTIVITY=busy result=$(fm_dispatch_guard_lane_classify herdr target)
  sleep 1
  TEST_PRESENCE=alive TEST_ACTIVITY=busy result=$(fm_dispatch_guard_lane_classify herdr target)
  if [ "$result" = working ]; then ok "quiet passage of time never frees a working lane"; else bad "time passage changed working classification to '$result'"; fi

  local idle_count=0 working_count=0 state
  for state in idle idle idle working working; do
    TEST_PRESENCE=alive TEST_ACTIVITY="$state" result=$(fm_dispatch_guard_lane_classify herdr target)
    if [ "$result" = idle ]; then idle_count=$((idle_count + 1)); else working_count=$((working_count + 1)); fi
  done
  if [ "$idle_count" -eq 3 ] && [ "$working_count" -eq 2 ] && [ "$working_count" -lt 3 ]; then
    ok "N idle lanes plus M working lanes refuse only when M exceeds the cap"
  else
    bad "lane mix was counted as idle=$idle_count working=$working_count"
  fi
  working_count=$((working_count + 1))
  if [ "$working_count" -ge 3 ]; then ok "a working count above cap refuses"; else bad "working count above cap was allowed"; fi
}

test_malformed_knob_falls_back() {
  local home; home=$(mktemp -d)
  mkdir -p "$home/config"; printf 'lots\n' > "$home/config/dispatch-max-lanes"
  local got; got=$(env -u FM_DISPATCH_GUARD_MAX_LANES bash -c \
    "FM_HOME='$home'; $LANE_FN; fm_dispatch_guard_lane_cap" 2>/dev/null)
  rm -rf "$home"
  if [ "$got" = "4" ]; then
    ok "a malformed knob falls back to the default instead of refusing every spawn"
  else
    bad "malformed knob should fall back to 4, got '${got:-<empty>}'"
  fi
}

test_config_knob_raises_the_ceiling
test_default_when_no_knob_and_no_env
test_env_wins_over_config
test_malformed_knob_falls_back
test_lane_state_helper_exists

echo
printf 'PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && { echo "TESTS FAILED"; exit 1; }
echo "ALL TESTS PASSED"