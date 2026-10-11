#!/usr/bin/env bash
# tests/fm-raw-herdr-senpi.test.sh — Regression tests for RAW_HERDR_SENPI mode enforcement
#
# Run with:  cd /root/agent-work/deightonllm-firstmate && bash tests/fm-raw-herdr-senpi.test.sh
# Run with bypass (CI): FM_RAW_HERDR_SENPI_BYPASS=1 bash tests/fm-raw-herdr-senpi.test.sh

set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$SCRIPT_DIR/bin"
LIB="$SRC_DIR/fm-raw-herdr-senpi-lib.sh"
SPAWN="$SRC_DIR/fm-spawn.sh"
ALWAYS_FOUR="$SRC_DIR/fm-always-four.sh"
PREFLIGHT="/root/bin/herdr-dispatch-preflight"

# Counters
PASS=0 FAIL=0

# run_test: execute one test, track pass/fail
run_test() {
  local name=$1
  shift
  "$@" 2>&1
  local rc=$?
  if [ $rc -eq 0 ]; then
    PASS=$((PASS + 1))
    pass "$name"
  else
    FAIL=$((FAIL + 1))
    fail "$name (exit $rc)"
  fi
}

# Create isolated temp dir for config file tests
CONF_DIR=$(mktemp -d)
DATA_DIR=$(mktemp -d)
STATE_DIR=$(mktemp -d)
trap 'rm -rf "$CONF_DIR" "$DATA_DIR" "$STATE_DIR"' EXIT

# =============================================================================
# T1 — inactive when no env, no config
# =============================================================================
t1_inactive_default() {
  printf 'RAW_HERDR_SENPI=0\n' > "$CONF_DIR/raw-herdr-senpi.env"
  RAW_HERDR_SENPI=; unset RAW_HERDR_SENPI; FM_RAW_HERDR_SENPI_BYPASS=
  FM_CONFIG_OVERRIDE="$CONF_DIR"
  . "$LIB"
  fm_raw_herdr_senpi_is_active && fail "T1: should be inactive with no env, no=1 config" && return 1
  return 0
}

# =============================================================================
# T2 — active when RAW_HERDR_SENPI=1 env
# =============================================================================
t2_active_env() {
  RAW_HERDR_SENPI=1; FM_RAW_HERDR_SENPI_BYPASS=
  FM_CONFIG_OVERRIDE="$CONF_DIR"
  . "$LIB"
  fm_raw_herdr_senpi_is_active || { fail "T2: should be active when RAW_HERDR_SENPI=1 env"; return 1; }
  return 0
}

# =============================================================================
# T3 — active when config file contains RAW_HERDR_SENPI=1
# =============================================================================
t3_active_config_file() {
  printf 'RAW_HERDR_SENPI=1\n' > "$CONF_DIR/raw-herdr-senpi.env"
  RAW_HERDR_SENPI=; FM_RAW_HERDR_SENPI_BYPASS=
  FM_CONFIG_OVERRIDE="$CONF_DIR"
  . "$LIB"
  fm_raw_herdr_senpi_is_active || { fail "T3: should be active with config file RAW_HERDR_SENPI=1"; return 1; }
  return 0
}

# =============================================================================
# T4 — inactive when bypass flag set (even with env=1)
# =============================================================================
t4_inactive_bypass() {
  RAW_HERDR_SENPI=1; FM_RAW_HERDR_SENPI_BYPASS=1
  FM_CONFIG_OVERRIDE="$CONF_DIR"
  . "$LIB"
  fm_raw_herdr_senpi_is_active && { fail "T4: should be inactive with FM_RAW_HERDR_SENPI_BYPASS=1"; return 1; }
  return 0
}

# =============================================================================
# T5 — refuse_mutate exits 1 when active (env)
# =============================================================================
t5_refuse_active_env() {
  RAW_HERDR_SENPI=1; FM_RAW_HERDR_SENPI_BYPASS=
  FM_CONFIG_OVERRIDE="$CONF_DIR"
  # Wrap in subshell so exit 1 from the library doesn't kill the test script
  ( . "$LIB"; fm_raw_herdr_senpi_refuse_mutate "test-op" ) 2>/dev/null
  local rc=$?
  [ "$rc" -eq 1 ] || { fail "T5: refuse_mutate exit should be 1, got $rc"; return 1; }
  return 0
}

# =============================================================================
# T6 — refuse_mutate exits 1 when active (config file)
# =============================================================================
t6_refuse_active_file() {
  printf 'RAW_HERDR_SENPI=1\n' > "$CONF_DIR/raw-herdr-senpi.env"
  RAW_HERDR_SENPI=; FM_RAW_HERDR_SENPI_BYPASS=
  FM_CONFIG_OVERRIDE="$CONF_DIR"
  ( . "$LIB"; fm_raw_herdr_senpi_refuse_mutate "test-op" ) 2>/dev/null
  local rc=$?
  [ "$rc" -eq 1 ] || { fail "T6: refuse_mutate exit should be 1, got $rc"; return 1; }
  return 0
}

# =============================================================================
# T7 — refuse_mutate is no-op when inactive
# =============================================================================
t7_refuse_inactive() {
  printf 'RAW_HERDR_SENPI=0\n' > "$CONF_DIR/raw-herdr-senpi.env"
  RAW_HERDR_SENPI=; FM_RAW_HERDR_SENPI_BYPASS=
  FM_CONFIG_OVERRIDE="$CONF_DIR"
  . "$LIB"
  fm_raw_herdr_senpi_refuse_mutate "test-op" 2>/dev/null || { fail "T7: refuse_mutate should return 0 when inactive"; return 1; }
  return 0
}

# =============================================================================
# T8 — fm-spawn.sh MUTATION refuses when RAW_HERDR_SENPI=1 env
# Test with a real mutation (task args, not --help) so the env check fires.
# =============================================================================
t8_spawn_refuses_env() {
  mkdir -p "$STATE_DIR" "$DATA_DIR"
  RAW_HERDR_SENPI=1 \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    FM_STATE_OVERRIDE="$STATE_DIR" \
    FM_DATA_OVERRIDE="$DATA_DIR" \
    timeout 10s "$SPAWN" dummy-task dummy-project --harness echo 2>/dev/null
  local rc=$?
  [ "$rc" -eq 1 ] || [ "$rc" -eq 64 ] || { fail "T8: fm-spawn.sh should refuse (exit 1 or 64) when RAW_HERDR_SENPI=1 env, got $rc"; return 1; }
  return 0
}

# =============================================================================
# T9 — fm-spawn.sh MUTATION refuses when RAW_HERDR_SENPI=1 config file
# Test with a real mutation so the config-file check fires.
# =============================================================================
t9_spawn_refuses_file() {
  printf 'RAW_HERDR_SENPI=1\n' > "$CONF_DIR/raw-herdr-senpi.env"
  mkdir -p "$STATE_DIR" "$DATA_DIR"
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    FM_STATE_OVERRIDE="$STATE_DIR" \
    FM_DATA_OVERRIDE="$DATA_DIR" \
    timeout 10s "$SPAWN" dummy-task dummy-project --harness echo 2>/dev/null
  local rc=$?
  [ "$rc" -eq 1 ] || [ "$rc" -eq 64 ] || { fail "T9: fm-spawn.sh should refuse (exit 1 or 64) when RAW_HERDR_SENPI=1 file, got $rc"; return 1; }
  return 0
}

# =============================================================================
# T10 — fm-spawn.sh --help succeeds even when RAW_HERDR_SENPI=1 env
# --help is read-only and must never be blocked by RAW_HERDR_SENPI.
# =============================================================================
t10_spawn_help_allowed_env() {
  mkdir -p "$STATE_DIR" "$DATA_DIR"
  RAW_HERDR_SENPI=1 \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    FM_STATE_OVERRIDE="$STATE_DIR" \
    FM_DATA_OVERRIDE="$DATA_DIR" \
    timeout 10s "$SPAWN" --help >/dev/null 2>&1
  local rc=$?
  [ "$rc" -eq 0 ] || { fail "T10: fm-spawn.sh --help must succeed even when RAW_HERDR_SENPI=1 env (read-only), got $rc"; return 1; }
  return 0
}

# =============================================================================
# T11 — fm-always-four spawn refuses when mode active
# =============================================================================
t11_alwaysfour_spawn_refuses() {
  printf 'RAW_HERDR_SENPI=1\n' > "$CONF_DIR/raw-herdr-senpi.env"
  mkdir -p "$STATE_DIR" "$DATA_DIR"
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    FM_STATE_OVERRIDE="$STATE_DIR" \
    FM_DATA_OVERRIDE="$DATA_DIR" \
    timeout 10s "$ALWAYS_FOUR" spawn lane-001 test-task 2>/dev/null && { fail "T11: always-four spawn should refuse"; return 1; }
  local rc=$?
  [ "$rc" -eq 1 ] || { fail "T11: always-four spawn should exit 1, got $rc"; return 1; }
  return 0
}

# =============================================================================
# T12 — fm-always-four cycle refuses when mode active
# =============================================================================
t12_alwaysfour_cycle_refuses() {
  printf 'RAW_HERDR_SENPI=1\n' > "$CONF_DIR/raw-herdr-senpi.env"
  mkdir -p "$STATE_DIR" "$DATA_DIR"
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    FM_STATE_OVERRIDE="$STATE_DIR" \
    FM_DATA_OVERRIDE="$DATA_DIR" \
    timeout 10s "$ALWAYS_FOUR" cycle 2>/dev/null && { fail "T12: always-four cycle should refuse"; return 1; }
  local rc=$?
  [ "$rc" -eq 1 ] || { fail "T12: always-four cycle should exit 1, got $rc"; return 1; }
  return 0
}

# =============================================================================
# T13 — fm-always-four daemon refuses when mode active
# =============================================================================
t13_alwaysfour_daemon_refuses() {
  printf 'RAW_HERDR_SENPI=1\n' > "$CONF_DIR/raw-herdr-senpi.env"
  mkdir -p "$STATE_DIR" "$DATA_DIR"
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    FM_STATE_OVERRIDE="$STATE_DIR" \
    FM_DATA_OVERRIDE="$DATA_DIR" \
    timeout 10s "$ALWAYS_FOUR" daemon --once 2>/dev/null && { fail "T13: always-four daemon should refuse"; return 1; }
  local rc=$?
  [ "$rc" -eq 1 ] || { fail "T13: always-four daemon should exit 1, got $rc"; return 1; }
  return 0
}

# =============================================================================
# T14 — fm-always-four status ALLOWED when mode active (read-only)
# =============================================================================
t14_alwaysfour_status_allowed() {
  printf 'RAW_HERDR_SENPI=1\n' > "$CONF_DIR/raw-herdr-senpi.env"
  mkdir -p "$STATE_DIR" "$DATA_DIR"
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    FM_STATE_OVERRIDE="$STATE_DIR" \
    FM_DATA_OVERRIDE="$DATA_DIR" \
    timeout 10s "$ALWAYS_FOUR" status >/dev/null 2>&1 || { fail "T14: always-four status should be allowed when RAW_HERDR_SENPI=1"; return 1; }
  return 0
}

# =============================================================================
# T15 — fm-always-four check-eligible ALLOWED when mode active (read-only)
# =============================================================================
t15_alwaysfour_checkeligible_allowed() {
  printf 'RAW_HERDR_SENPI=1\n' > "$CONF_DIR/raw-herdr-senpi.env"
  mkdir -p "$STATE_DIR" "$DATA_DIR"
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    FM_STATE_OVERRIDE="$STATE_DIR" \
    FM_DATA_OVERRIDE="$DATA_DIR" \
    timeout 10s "$ALWAYS_FOUR" check-eligible test-task >/dev/null 2>&1 || { fail "T15: always-four check-eligible should be allowed when RAW_HERDR_SENPI=1"; return 1; }
  return 0
}

# =============================================================================
# T16 — fm-raw-herdr-senpi_report() shows inactive
# =============================================================================
t16_report_inactive() {
  printf 'RAW_HERDR_SENPI=0\n' > "$CONF_DIR/raw-herdr-senpi.env"
  RAW_HERDR_SENPI=; FM_RAW_HERDR_SENPI_BYPASS=
  FM_CONFIG_OVERRIDE="$CONF_DIR"
  . "$LIB"
  local report
  report=$(fm_raw_herdr_senpi_report)
  echo "$report" | grep -q "inactive" || { fail "T16: report should say inactive, got: $report"; return 1; }
  return 0
}

# =============================================================================
# T17 — fm-raw-herdr-senpi_report() shows active (env)
# =============================================================================
t17_report_active_env() {
  RAW_HERDR_SENPI=1; FM_RAW_HERDR_SENPI_BYPASS=
  FM_CONFIG_OVERRIDE="$CONF_DIR"
  . "$LIB"
  local report
  report=$(fm_raw_herdr_senpi_report)
  echo "$report" | grep -q "ACTIVE" || { fail "T17: report should say ACTIVE, got: $report"; return 1; }
  return 0
}

# =============================================================================
# T18 — fm-raw-herdr-senpi_report() shows active (config file)
# =============================================================================
t18_report_active_file() {
  printf 'RAW_HERDR_SENPI=1\n' > "$CONF_DIR/raw-herdr-senpi.env"
  RAW_HERDR_SENPI=; FM_RAW_HERDR_SENPI_BYPASS=
  FM_CONFIG_OVERRIDE="$CONF_DIR"
  . "$LIB"
  local report
  report=$(fm_raw_herdr_senpi_report)
  echo "$report" | grep -q "ACTIVE" || { fail "T18: report should say ACTIVE, got: $report"; return 1; }
  return 0
}

# =============================================================================
# T19 — herdr-dispatch-preflight is NOT blocked when RAW_HERDR_SENPI=1
# CRITICAL INVARIANT: preflight is the native Herdr safety gate and must remain
# permitted under RAW_HERDR_SENPI mode. Only FirstMate project lifecycle
# (fm-spawn, fm-always-four) is refused.
# =============================================================================
t19_preflight_not_blocked_by_mode() {
  printf 'RAW_HERDR_SENPI=1\n' > "$CONF_DIR/raw-herdr-senpi.env"
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    output=$(timeout 10s "$PREFLIGHT" --pane-id test-pane --expected-model MiniMax-M2.7 2>&1 || true)
  # preflight must NOT cite RAW_HERDR_SENPI refusal line
  echo "$output" | grep -q "RAW_HERDR_SENPI mode is active" && { fail "T19: preflight MUST NOT cite RAW_HERDR_SENPI — it is the native Herdr gate"; return 1; }
  return 0
}

# =============================================================================
# T20 — herdr-dispatch-preflight does NOT cite RAW_HERDR_SENPI when inactive
# =============================================================================
t20_preflight_allows() {
  printf 'RAW_HERDR_SENPI=0\n' > "$CONF_DIR/raw-herdr-senpi.env"
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    output=$(timeout 10s "$PREFLIGHT" --pane-id test-pane --expected-model MiniMax-M2.7 2>&1 || true)
  echo "$output" | grep -q "RAW_HERDR_SENPI mode is active" && { fail "T20: preflight should not cite RAW_HERDR_SENPI when inactive"; return 1; }
  return 0
}

# =============================================================================
# T21 — fm-spawn.sh --help succeeds when RAW_HERDR_SENPI=0 in config file
# =============================================================================
t21_spawn_allows_zero() {
  printf 'RAW_HERDR_SENPI=0\n' > "$CONF_DIR/raw-herdr-senpi.env"
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    timeout 10s "$SPAWN" --help >/dev/null 2>&1
  local rc=$?
  [ "$rc" -eq 0 ] || { fail "T21: fm-spawn.sh --help should succeed when RAW_HERDR_SENPI=0, got $rc"; return 1; }
  return 0
}

# =============================================================================
# T22 — config file with RAW_HERDR_SENPI unset still inactive
# =============================================================================
t22_config_file_missing_var() {
  # File exists but RAW_HERDR_SENPI is not set in it → inactive
  printf '# RAW_HERDR_SENPI not set here\n' > "$CONF_DIR/raw-herdr-senpi.env"
  RAW_HERDR_SENPI=; FM_RAW_HERDR_SENPI_BYPASS=
  FM_CONFIG_OVERRIDE="$CONF_DIR"
  . "$LIB"
  fm_raw_herdr_senpi_is_active && { fail "T22: should be inactive when config file exists but RAW_HERDR_SENPI is not =1"; return 1; }
  return 0
}

# =============================================================================
# T23 — status output includes RAW_HERDR_SENPI line when active
# =============================================================================
t23_status_shows_senpi_active() {
  printf 'RAW_HERDR_SENPI=1\n' > "$CONF_DIR/raw-herdr-senpi.env"
  mkdir -p "$STATE_DIR" "$DATA_DIR"
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    FM_STATE_OVERRIDE="$STATE_DIR" \
    FM_DATA_OVERRIDE="$DATA_DIR" \
    output=$("$ALWAYS_FOUR" status 2>&1)
  echo "$output" | grep -q "RAW_HERDR_SENPI" || { fail "T23: status should include RAW_HERDR_SENPI line"; return 1; }
  return 0
}

# =============================================================================
# T24 — status output includes RAW_HERDR_SENPI line when inactive
# =============================================================================
t24_status_shows_senpi_inactive() {
  printf 'RAW_HERDR_SENPI=0\n' > "$CONF_DIR/raw-herdr-senpi.env"
  mkdir -p "$STATE_DIR" "$DATA_DIR"
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    FM_CONFIG_OVERRIDE="$CONF_DIR" \
    FM_STATE_OVERRIDE="$STATE_DIR" \
    FM_DATA_OVERRIDE="$DATA_DIR" \
    output=$("$ALWAYS_FOUR" status 2>&1)
  echo "$output" | grep -q "RAW_HERDR_SENPI" || { fail "T24: status should include RAW_HERDR_SENPI line even when inactive"; return 1; }
  return 0
}

# =============================================================================
# T25 — durable live mode blocks fm-spawn.sh using the REAL config file
# Uses the actual firstmate config directory so this tests the deployed durable marker.
# =============================================================================
t25_live_durable_mode_blocks_spawn() {
  mkdir -p "$STATE_DIR" "$DATA_DIR"
  # FM_CONFIG_OVERRIDE points at the real SCRIPT_DIR/config which has RAW_HERDR_SENPI=1
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_CONFIG_OVERRIDE="$SCRIPT_DIR/config" \
    FM_STATE_OVERRIDE="$STATE_DIR" \
    FM_DATA_OVERRIDE="$DATA_DIR" \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    timeout 10s "$SPAWN" dummy-task dummy-project --harness echo 2>/dev/null
  local rc=$?
  [ "$rc" -eq 1 ] || [ "$rc" -eq 64 ] || { fail "T25: durable-live mode should refuse fm-spawn (exit 1 or 64), got $rc"; return 1; }
  return 0
}

# =============================================================================
# T26 — durable live mode: herdr-dispatch-preflight is NOT blocked
# The native Herdr safety gate must remain permitted regardless of RAW_HERDR_SENPI.
# =============================================================================
t26_live_preflight_not_blocked() {
  # Use the real firstmate config (RAW_HERDR_SENPI=1 is set there)
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_CONFIG_OVERRIDE="$SCRIPT_DIR/config" \
    output=$(timeout 10s "$PREFLIGHT" --pane-id test-pane --expected-model MiniMax-M2.7 2>&1 || true)
  # Must NOT cite RAW_HERDR_SENPI
  echo "$output" | grep -q "RAW_HERDR_SENPI mode is active" && { fail "T26: preflight MUST NOT cite RAW_HERDR_SENPI — it is the native Herdr gate"; return 1; }
  return 0
}

# =============================================================================
# T27 — durable live mode: fm-spawn.sh --help ALLOWED (read-only)
# --help is read-only and must exit cleanly even when the durable config file
# sets RAW_HERDR_SENPI=1. This is the primary scenario the operator cares about.
# =============================================================================
t27_live_help_allowed() {
  RAW_HERDR_SENPI= \
    FM_RAW_HERDR_SENPI_BYPASS= \
    FM_CONFIG_OVERRIDE="$SCRIPT_DIR/config" \
    FM_HOME="$CONF_DIR" \
    FM_ROOT="$SCRIPT_DIR" \
    timeout 10s "$SPAWN" --help >/dev/null 2>&1
  local rc=$?
  [ "$rc" -eq 0 ] || { fail "T27: fm-spawn.sh --help must succeed against durable live config (read-only), got $rc"; return 1; }
  return 0
}

# =============================================================================
# Run all tests
# =============================================================================

echo "Running RAW_HERDR_SENPI regression tests..."
echo "=========================================="

run_test "T1: inactive when no env, no=1 config"      t1_inactive_default
run_test "T2: active when RAW_HERDR_SENPI=1 env"     t2_active_env
run_test "T3: active when config file RAW_HERDR_SENPI=1" t3_active_config_file
run_test "T4: inactive when bypass flag set"          t4_inactive_bypass
run_test "T5: refuse_mutate exits 1 when active (env)" t5_refuse_active_env
run_test "T6: refuse_mutate exits 1 when active (file)" t6_refuse_active_file
run_test "T7: refuse_mutate is no-op when inactive"   t7_refuse_inactive
run_test "T8: fm-spawn.sh mutation refuses when env=1"     t8_spawn_refuses_env
run_test "T9: fm-spawn.sh mutation refuses when file=1"    t9_spawn_refuses_file
run_test "T10: fm-spawn.sh --help ALLOWED when env=1"   t10_spawn_help_allowed_env
run_test "T11: always-four spawn refuses when active"  t11_alwaysfour_spawn_refuses
run_test "T12: always-four cycle refuses when active"  t12_alwaysfour_cycle_refuses
run_test "T13: always-four daemon refuses when active" t13_alwaysfour_daemon_refuses
run_test "T14: always-four status allowed when active" t14_alwaysfour_status_allowed
run_test "T15: always-four check-eligible allowed when active" t15_alwaysfour_checkeligible_allowed
run_test "T16: report() shows inactive"               t16_report_inactive
run_test "T17: report() shows active (env)"          t17_report_active_env
run_test "T18: report() shows active (file)"         t18_report_active_file
run_test "T19: preflight NOT blocked by RAW_HERDR_SENPI=1" t19_preflight_not_blocked_by_mode
run_test "T20: preflight NOT cited when RAW_HERDR_SENPI=0" t20_preflight_allows
run_test "T21: fm-spawn.sh --help succeeds when=0"   t21_spawn_allows_zero
run_test "T22: inactive when config file lacks =1"     t22_config_file_missing_var
run_test "T23: status shows RAW_HERDR_SENPI line (active)" t23_status_shows_senpi_active
run_test "T24: status shows RAW_HERDR_SENPI line (inactive)" t24_status_shows_senpi_inactive
run_test "T25: durable-live mode blocks fm-spawn (live config)" t25_live_durable_mode_blocks_spawn
run_test "T26: durable-live mode: preflight NOT blocked by RAW_HERDR_SENPI=1" t26_live_preflight_not_blocked
run_test "T27: durable-live: --help ALLOWED (read-only)" t27_live_help_allowed

echo "=========================================="
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  echo "FAILED"
  exit 1
else
  echo "ALL TESTS PASSED"
  exit 0
fi
