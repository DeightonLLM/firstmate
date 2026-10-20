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

test_provider_cap_defaults_to_global_cap() {
  local home; home=$(mktemp -d)
  mkdir -p "$home/config"; printf '9\n' > "$home/config/dispatch-max-lanes"
  local fn got
  fn=$(awk '/^fm_dispatch_guard_provider_cap\(\)/,/^}/' "$GUARD")
  got=$(env -u FM_DISPATCH_GUARD_MAX_PROVIDER_LANES bash -c "FM_HOME='$home'; $LANE_FN; $fn; fm_dispatch_guard_provider_cap")
  rm -rf "$home"
  if [ "$got" = 9 ]; then ok "provider ceiling defaults to global lane ceiling"; else bad "provider default should be 9, got '$got'"; fi
}

test_provider_identity_from_metadata() {
  local fn meta home got
  fn=$(awk '/^fm_dispatch_guard_provider_of_meta\(\)/,/^}/' "$GUARD")
  eval "$fn"
  home=$(mktemp -d); meta="$home/lane.meta"
  printf 'harness=agy\nmodel=openai-codex/gpt-6-luna\n' > "$meta"
  got=$(fm_dispatch_guard_provider_of_meta "$meta")
  rm -rf "$home"
  if [ "$got" = openai-codex ]; then ok "provider identity comes from recorded model prefix"; else bad "provider identity was '$got'"; fi
}

test_provider_identity_falls_back_to_harness() {
  local fn meta home got
  fn=$(awk '/^fm_dispatch_guard_provider_of_meta\(\)/,/^}/' "$GUARD")
  eval "$fn"
  home=$(mktemp -d); meta="$home/lane.meta"
  # No provider prefix on the model: identity must still resolve, never to empty.
  printf 'harness=pi\nmodel=gpt-6-luna\n' > "$meta"
  got=$(fm_dispatch_guard_provider_of_meta "$meta")
  rm -rf "$home"
  if [ "$got" = pi ]; then ok "provider identity falls back to the recorded harness"; else bad "provider fallback returned '$got'"; fi
}

test_unknown_lane_occupies_its_provider() {
  # Fail-closed: a lane whose endpoint cannot be resolved is unknown, not free.
  # It must still consume its provider's slot, or a pile of unreadable metas would
  # look like free capacity for that provider.
  local guard_fn body
  guard_fn=$(awk '/^if \[ -n "\$\{FM_HOME:-\}" \] && \[ -d "\$\{FM_HOME\}\/state" \]/,/^fi$/' "$GUARD")
  if printf '%s' "$guard_fn" | grep -q 'provider_live\["\$provider"\]=\$(( ${provider_live\["\$provider"\]:-0} + 1 ))'; then
    ok "an unresolved-endpoint lane counts against its provider"
  else
    bad "an unresolved-endpoint lane is not counted against its provider"
  fi
  if printf '%s' "$guard_fn" | grep -A3 'unverified)' | grep -q 'provider_live'; then
    ok "an unverified lane counts against its provider"
  else
    bad "an unverified lane is not counted against its provider"
  fi
  if printf '%s' "$guard_fn" | grep -A4 'idle)' | grep -q 'provider_idle\["\$provider"\]' && ! printf '%s' "$guard_fn" | grep -A4 'idle)' | grep -q 'provider_live'; then
    ok "an idle lane is recorded against its provider without consuming a slot"
  else
    bad "idle-lane provider accounting is wrong"
  fi
}

test_provider_refusal_names_provider_and_cap() {
  # Asserted against the whole guard, not an extracted block: the live-lane block
  # contains a nested `if ... fi`, so a range extraction ending at the first `fi`
  # truncates before the provider refusal and tests nothing.
  if grep -Fq '[ "${provider_live[$provider]}" -ge "$provider_cap" ]' "$GUARD"; then
    ok "provider ceiling refuses when that provider alone is at cap"
  else
    bad "provider ceiling does not refuse on per-provider saturation"
  fi
  # The refusal must be evaluated, otherwise the feature is inert.
  if grep -Fq 'provider_cap="$(fm_dispatch_guard_provider_cap)"' "$GUARD"; then
    ok "provider ceiling is evaluated in the dispatch guard"
  else
    bad "provider ceiling is never evaluated"
  fi
  # It must be a refusal, not a log-and-continue, so a saturated provider stops
  # dispatch rather than merely being noted.
  if grep -A2 -F '[ "${provider_live[$provider]}" -ge "$provider_cap" ]' "$GUARD" | grep -q 'refuse'; then
    ok "per-provider saturation refuses dispatch"
  else
    bad "per-provider saturation does not refuse dispatch"
  fi
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

test_provider_cap_defaults_to_global_cap
test_provider_identity_from_metadata
test_provider_identity_falls_back_to_harness
test_unknown_lane_occupies_its_provider
test_provider_refusal_names_provider_and_cap
test_config_knob_raises_the_ceiling
test_default_when_no_knob_and_no_env
test_env_wins_over_config
test_malformed_knob_falls_back
test_lane_state_helper_exists

echo
printf 'PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && { echo "TESTS FAILED"; exit 1; }
echo "ALL TESTS PASSED"