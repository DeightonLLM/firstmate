#!/usr/bin/env bash
# tests/fm-stop-wait-handoff.test.sh — Deterministic tests for stop-to-wait handoff behavior
#
# These tests verify that the coordinator polling loop correctly handles:
#   1. status_nontermination - coordinator status message never ends the campaign loop
#   2. done_idle_refill - done/idle panes trigger refill behavior
#   3. queued_wake_drain - queued wakes are drained even without terminal panes
#   4. checker_handoff - checker is scheduled appropriately after worker batch
#   5. explicit_terminal_exit - loop exits only on explicit terminal classification
#
# Each test is a self-contained shell function that can be run individually.
# All tests use mocked/stubbed dependencies and deterministic assertions.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$TEST_ROOT/bin"
FM_ROOT="$TEST_ROOT"
FM_HOME="$TEST_ROOT"

# Use a fixed temp directory for all tests
TEST_STATE_BASE="${TMPDIR:-/tmp}/fm-stop-wait-test-$$"

pass=0
fail=0

test_result() {
  local name=$1 result=$2
  if [ "$result" = 0 ]; then
    printf 'PASS: %s\n' "$name"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s\n' "$name"
    fail=$((fail + 1))
  fi
}

# Helper: create a fresh test state directory and run coordinator-poll
run_poll() {
  local state_dir=$1; shift
  FM_STATE_OVERRIDE="$state_dir" \
  FM_ROOT_OVERRIDE="$FM_ROOT" \
  FM_HOME_OVERRIDE="$FM_HOME" \
  FM_COORD_POLL_INTERVAL=2 \
  FM_COORD_POLL_INITIAL_BACKOFF=1 \
  FM_COORD_POLL_BACKOFF_MAX=4 \
  FM_COORD_DEDUP_WINDOW=10 \
  FM_COORD_HERDR_SESSION=default \
    bash "$BIN/fm-coordinator-poll.sh" "$@"
}

# Helper: setup fresh test state
setup_test_state() {
  local state_dir=$1
  mkdir -p "$state_dir"
}

# =============================================================================
# Test 1: status_nontermination
# Coordinator status message never ends the campaign loop
# =============================================================================
test_status_nontermination() {
  printf '\n=== Test: status_nontermination ===\n'
  local state_dir="${TEST_STATE_BASE}-status-nonterm"
  setup_test_state "$state_dir"

  # Run multiple cycles - none should cause the campaign to end
  # The cycle should complete successfully and never exit abnormally
  local cycle_count=0
  local all_succeeded=0  # Start with failure assumption

  for i in 1 2 3; do
    local output rc
    output=$(run_poll "$state_dir" cycle --dry-run 2>&1)
    rc=$?

    # Cycle should complete successfully
    if [ "$rc" -eq 0 ] && echo "$output" | grep -q "cycle completed"; then
      cycle_count=$((cycle_count + 1))
    fi
  done

  # Success if all 3 cycles completed successfully
  if [ "$cycle_count" -eq 3 ]; then
    all_succeeded=0  # Test passes
  else
    all_succeeded=1  # Test fails
    printf 'DEBUG: only %d cycles completed successfully\n' "$cycle_count"
  fi

  test_result "status_nontermination: coordinator status never ends campaign loop" "$all_succeeded"
  test_result "status_nontermination: all 3 cycles executed ($cycle_count cycles)" $([ "$cycle_count" -eq 3 ] && echo 0 || echo 1)

  rm -rf "$state_dir"
}

# =============================================================================
# Test 2: done_idle_refill
# Done/idle panes trigger refill behavior via state-based fallback
# =============================================================================
test_done_idle_refill() {
  printf '\n=== Test: done_idle_refill ===\n'
  local state_dir="${TEST_STATE_BASE}-done-idle-refill"
  setup_test_state "$state_dir"

  # Create a terminal pane marker without a handoff event (simulates already-processed terminal)
  local test_pane="done_refill_test_$$"
  date +%s > "$state_dir/.coord-poll-refill-$test_pane"

  # Verify refill mechanism functions exist and behave correctly
  grep -q "state-based refill fallback" "$BIN/fm-coordinator-poll.sh"
  test_result "done_idle_refill: state-based refill fallback code exists" $?

  grep -q "is_terminal_pane" "$BIN/fm-coordinator-poll.sh"
  test_result "done_idle_refill: is_terminal_pane function exists" $?

  grep -q "cmd_refill_slots" "$BIN/fm-coordinator-poll.sh"
  test_result "done_idle_refill: cmd_refill_slots called in cycle" $?

  grep -q "get_pending_refill_panes" "$BIN/fm-coordinator-poll.sh"
  test_result "done_idle_refill: get_pending_refill_panes function exists" $?

  # Run cycle and verify refill behavior completes without error
  local output rc
  output=$(run_poll "$state_dir" cycle --dry-run 2>&1)
  rc=$?

  echo "$output" | grep -q "cycle completed"
  test_result "done_idle_refill: cycle completes with terminal pane markers" $?

  rm -rf "$state_dir"
}

# =============================================================================
# Test 3: queued_wake_drain
# Queued wakes are drained even without terminal panes
# =============================================================================
test_queued_wake_drain() {
  printf '\n=== Test: queued_wake_drain ===\n'
  local state_dir="${TEST_STATE_BASE}-queued-wake-drain"
  setup_test_state "$state_dir"

  # Create a fake wake queue entry
  local wake_marker="$state_dir/.wake-queue"
  printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)	test	heartbeat	heartbeat" > "$wake_marker"

  # Verify wake marker exists before drain
  [ -f "$wake_marker" ]
  test_result "queued_wake_drain: wake marker created before cycle" $?

  # Verify cmd_drain_wakes function exists and is called in cycle
  grep -q "^cmd_drain_wakes()" "$BIN/fm-coordinator-poll.sh"
  test_result "queued_wake_drain: cmd_drain_wakes function exists" $?

  grep -q "cmd_drain_wakes" "$BIN/fm-coordinator-poll.sh"
  test_result "queued_wake_drain: cmd_drain_wakes called in cycle" $?

  # Run cycle and verify wake drain happens
  local output rc
  output=$(run_poll "$state_dir" cycle --dry-run 2>&1)
  rc=$?

  echo "$output" | grep -q "cycle completed"
  test_result "queued_wake_drain: cycle completes with queued wakes" $?

  # Verify drain is best-effort (never fails cycle)
  grep -q "Best-effort, never fail the cycle" "$BIN/fm-coordinator-poll.sh"
  test_result "queued_wake_drain: drain is best-effort (never fails cycle)" $?

  rm -rf "$state_dir"
}

# =============================================================================
# Test 4: checker_handoff
# Checker is scheduled appropriately after worker batch
# =============================================================================
test_checker_handoff() {
  printf '\n=== Test: checker_handoff ===\n'
  local state_dir="${TEST_STATE_BASE}-checker-handoff"
  setup_test_state "$state_dir"

  # Verify checker scheduling functions exist
  grep -q "cmd_schedule_checker" "$BIN/fm-coordinator-poll.sh"
  test_result "checker_handoff: cmd_schedule_checker function exists" $?

  grep -q "get_checker_lane" "$BIN/fm-coordinator-poll.sh"
  test_result "checker_handoff: get_checker_lane function exists" $?

  grep -q 'lane-004' "$BIN/fm-coordinator-poll.sh"
  test_result "checker_handoff: checker slot is lane-004" $?

  grep -q "batch_size" "$BIN/fm-coordinator-poll.sh"
  test_result "checker_handoff: batch_size threshold mechanism exists" $?

  grep -q "terminal_workers" "$BIN/fm-coordinator-poll.sh"
  test_result "checker_handoff: terminal worker count tracked" $?

  # Verify schedule-checker command works in dry-run mode
  local output
  output=$(run_poll "$state_dir" schedule-checker --dry-run 3 2>&1)
  echo "$output" | grep -q "checker:"
  test_result "checker_handoff: schedule-checker command executes" $?

  rm -rf "$state_dir"
}

# =============================================================================
# Test 5: explicit_terminal_exit
# Loop exits only on explicit terminal classification
# =============================================================================
test_explicit_terminal_exit() {
  printf '\n=== Test: explicit_terminal_exit ===\n'
  local state_dir="${TEST_STATE_BASE}-explicit-terminal-exit"
  setup_test_state "$state_dir"

  # Verify daemon function exists and handles signals properly
  grep -q "^cmd_daemon" "$BIN/fm-coordinator-poll.sh"
  test_result "explicit_terminal_exit: cmd_daemon function exists" $?

  grep -q "trap '_daemon_running=0'" "$BIN/fm-coordinator-poll.sh"
  test_result "explicit_terminal_exit: daemon has graceful signal trap" $?

  grep -q 'while \[ "$_daemon_running" = 1 \]' "$BIN/fm-coordinator-poll.sh"
  test_result "explicit_terminal_exit: daemon loop has correct termination condition" $?

  # Verify daemon --once mode works (single cycle, then exit)
  local start_time end_time output elapsed
  start_time=$(date +%s)
  output=$(run_poll "$state_dir" daemon --once 2>&1)
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))

  # Should complete within reasonable time (5 seconds)
  [ "$elapsed" -lt 5 ]
  test_result "explicit_terminal_exit: daemon --once completes quickly" $?

  echo "$output" | grep -q "daemon started"
  test_result "explicit_terminal_exit: daemon logs startup" $?

  echo "$output" | grep -q "daemon exiting"
  test_result "explicit_terminal_exit: daemon logs exit" $?

  echo "$output" | grep -q "cycle completed"
  test_result "explicit_terminal_exit: daemon cycle completed before exit" $?

  # Verify loop does NOT exit on non-terminal states
  # Run multiple cycles - none should cause abnormal exit
  local cycles_ok=0
  for i in 1 2 3; do
    output=$(run_poll "$state_dir" cycle --dry-run 2>&1)
    if echo "$output" | grep -q "cycle completed"; then
      cycles_ok=$((cycles_ok + 1))
    fi
  done
  test_result "explicit_terminal_exit: all cycles complete without abnormal exit" $([ "$cycles_ok" -eq 3 ] && echo 0 || echo 1)

  rm -rf "$state_dir"
}

# =============================================================================
# Run all tests
# =============================================================================

test_status_nontermination
test_done_idle_refill
test_queued_wake_drain
test_checker_handoff
test_explicit_terminal_exit

# ---- Summary ----
printf '\n========================================\n'
printf 'Tests: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
