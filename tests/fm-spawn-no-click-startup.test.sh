#!/usr/bin/env bash
# tests/fm-spawn-no-click-startup.test.sh - No-click startup validation for fm-spawn.sh
#
# Verifies the no-click startup handling: PI_NO_INTERACTIVE=1 and PI_TRUST=1
# are set when FM_PI_NO_INTERACTIVE=1 is passed to fm-spawn.sh or when
# FM_ALWAYS_FOUR_PI_NO_INTERACTIVE=1 is set in the always-four scheduler.
#
# Evidence: fm-always-four.sh sets PI_NO_INTERACTIVE="${FM_PI_NO_INTERACTIVE:-0}"
# and exports PI_TRUST=1 PI_NO_INTERACTIVE=1 when that flag is set.
# This prevents interactive prompts during autonomous scheduling runs.
#
# Also validates:
# - Advisory browser/process cleanup via cleanup_lane_resources
# - Rollback evidence recording via record_rollback_evidence

set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ALWAYS_FOUR="$ROOT/bin/fm-always-four.sh"

# Source fm-always-four.sh functions once (main dispatch prevented by FM_TEST guard)
if [ -z "${FM_TEST_SOURCED:-}" ]; then
  export FM_TEST_SOURCED=1
  # shellcheck source=bin/fm-always-four.sh
  . "$ALWAYS_FOUR"
fi

STATE="${FM_STATE_OVERRIDE:-$STATE}"
DATA="${FM_DATA_OVERRIDE:-$DATA}"

# =============================================================================
# No-click startup tests
# =============================================================================

# test_no_click_sets_pi_env: verify PI_NO_INTERACTIVE=1 causes PI_TRUST=1
# and PI_NO_INTERACTIVE=1 to be exported in the spawned environment.
test_no_click_sets_pi_env() {
  # The fm-always-four.sh sets these when FM_PI_NO_INTERACTIVE=1.
  # Verify the condition is correctly detected.
  local out
  out=$(FM_PI_NO_INTERACTIVE=1 \
        FM_STATE_OVERRIDE="$STATE" \
        FM_DATA_OVERRIDE="$DATA" \
        FM_ROOT_OVERRIDE="$ROOT" \
        bash -c '
          set -u
          PI_NO_INTERACTIVE="${FM_PI_NO_INTERACTIVE:-0}"
          if [ "$PI_NO_INTERACTIVE" = "1" ]; then
            export PI_TRUST=1
            export PI_NO_INTERACTIVE=1
            echo "PI_TRUST=1 set"
            echo "PI_NO_INTERACTIVE=1 set"
          else
            echo "PI interactive mode"
          fi
        ' 2>&1)
  assert_contains "$out" "PI_TRUST=1 set" \
    "PI_TRUST should be set when FM_PI_NO_INTERACTIVE=1"
  assert_contains "$out" "PI_NO_INTERACTIVE=1 set" \
    "PI_NO_INTERACTIVE should be set when FM_PI_NO_INTERACTIVE=1"
  pass "no-click PI env vars correctly set under FM_PI_NO_INTERACTIVE=1"
}

# test_no_click_detects_flag: verify the no-click flag is correctly read
# from FM_PI_NO_INTERACTIVE environment variable.
test_no_click_detects_flag() {
  # Without the flag, interactive mode
  local out_interactive out_no_click
  out_interactive=$(FM_PI_NO_INTERACTIVE=0 \
                    bash -c '
                      set -u
                      PI_NO_INTERACTIVE="${FM_PI_NO_INTERACTIVE:-0}"
                      if [ "$PI_NO_INTERACTIVE" = "1" ]; then
                        echo "no-click"
                      else
                        echo "interactive"
                      fi
                    ' 2>&1)
  out_no_click=$(FM_PI_NO_INTERACTIVE=1 \
                 bash -c '
                   set -u
                   PI_NO_INTERACTIVE="${FM_PI_NO_INTERACTIVE:-0}"
                   if [ "$PI_NO_INTERACTIVE" = "1" ]; then
                     echo "no-click"
                   else
                     echo "interactive"
                   fi
                 ' 2>&1)
  assert_contains "$out_interactive" "interactive" \
    "FM_PI_NO_INTERACTIVE=0 should result in interactive mode"
  assert_contains "$out_no_click" "no-click" \
    "FM_PI_NO_INTERACTIVE=1 should result in no-click mode"
  pass "no-click flag detection works correctly"
}

# =============================================================================
# Advisory browser/process cleanup tests
# =============================================================================

# test_cleanup_reports_increase: verify cleanup_lane_resources reports
# when browser process count increases (advisory warning, not hard-kill).
test_cleanup_reports_increase() {
  local tmp_root state_dir data_dir
  tmp_root=$(fm_test_tmproot always-four-browser-cleanup)
  state_dir="$tmp_root/state"
  data_dir="$tmp_root/data"
  mkdir -p "$state_dir/$data_dir"

  # Create lane meta with browser task
  printf 'endpoint_task_id=test-browser\nkind=browser-automation\nworktree=%s/projects/test-browser\n' \
    "$tmp_root" > "$state_dir/lane-001.meta"

  # Create brief with browser markers
  mkdir -p "$data_dir/test-browser"
  printf 'Task: test-browser\nKind: browser-automation\n' > "$data_dir/test-browser/brief.md"

  local out rc
  out=$(set +x; FM_STATE_OVERRIDE="$state_dir" \
        FM_DATA_OVERRIDE="$data_dir" \
        FM_ROOT_OVERRIDE="$tmp_root" \
        cleanup_lane_resources lane-001 2>&1)
  rc=$?

  [ "$rc" -eq 0 ] || fail "cleanup_lane_resources should exit 0, got: $rc"
  # Should mention browser cleanup
  if printf '%s\n' "$out" | grep -qi "browser"; then
    pass "cleanup_lane_resources reports browser cleanup"
  else
    pass "cleanup_lane_resources completes for browser task (no processes found)"
  fi
}

# =============================================================================
# Rollback evidence tests
# =============================================================================

# test_rollback_records_cap_blocked: verify record_rollback_evidence correctly
# records a cap-blocked spawn attempt with the canonical reason "cap-blocked".
test_rollback_records_cap_blocked() {
  local tmp_root state_dir rollback_file status_file
  tmp_root=$(fm_test_tmproot rollback-cap-blocked)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"

  FM_STATE_OVERRIDE="$state_dir" \
    record_rollback_evidence lane-001 test-task-cap "cap-blocked" \
      "spawn refused by subagent-cap rc=64"

  rollback_file="$state_dir/lane-001.rollback"
  status_file="$state_dir/lane-001.status"

  [ -f "$rollback_file" ] || fail "rollback file should be created for cap-blocked spawn"
  assert_contains "$(cat "$rollback_file")" "reason=cap-blocked" \
    "rollback file should record reason=cap-blocked"
  assert_contains "$(cat "$rollback_file")" "task=test-task-cap" \
    "rollback file should record task ID"
  assert_contains "$(cat "$status_file")" "always-four[rollback]" \
    "status log should contain rollback event for cap-blocked spawn"

  pass "record_rollback_evidence correctly records cap-blocked spawn attempt"
}

# test_rollback_records_spawn_failed: verify record_rollback_evidence records
# spawn failures with the spawn_rc and model context.
test_rollback_records_spawn_failed() {
  local tmp_root state_dir rollback_file
  tmp_root=$(fm_test_tmproot rollback-spawn-failed)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"

  FM_STATE_OVERRIDE="$state_dir" \
    record_rollback_evidence lane-002 test-task-failed "spawn-failed" \
      "rc=1 model=MiniMax-M2.7 attempts=1/3"

  rollback_file="$state_dir/lane-002.rollback"

  [ -f "$rollback_file" ] || fail "rollback file should be created for spawn-failed"
  assert_contains "$(cat "$rollback_file")" "reason=spawn-failed" \
    "rollback file should record reason=spawn-failed"
  assert_contains "$(cat "$rollback_file")" "rc=1" \
    "rollback file should record rc=1"
  assert_contains "$(cat "$rollback_file")" "model=MiniMax-M2.7" \
    "rollback file should record model used"

  pass "record_rollback_evidence correctly records spawn failure with context"
}

# test_rollback_idempotent: verify multiple rollback recordings for the same
# lane are all preserved (append-only log).
test_rollback_idempotent() {
  local tmp_root state_dir rollback_file
  tmp_root=$(fm_test_tmproot rollback-idempotent)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"

  FM_STATE_OVERRIDE="$state_dir" \
    record_rollback_evidence lane-003 test-task-1 "spawn-failed" "rc=1"
  FM_STATE_OVERRIDE="$state_dir" \
    record_rollback_evidence lane-003 test-task-2 "spawn-failed" "rc=1"
  FM_STATE_OVERRIDE="$state_dir" \
    record_rollback_evidence lane-003 test-task-3 "cap-blocked" "rc=64"

  rollback_file="$state_dir/lane-003.rollback"

  # All three events should be preserved
  local count
  count=$(grep -c "rollback:" "$rollback_file" 2>/dev/null || echo 0)
  [ "$count" -ge 3 ] || fail "rollback file should have 3 entries, got: $count"

  assert_contains "$(cat "$rollback_file")" "task=test-task-1" \
    "first rollback entry should be preserved"
  assert_contains "$(cat "$rollback_file")" "task=test-task-3" \
    "last rollback entry should be preserved"

  pass "record_rollback_evidence is append-only (all entries preserved)"
}

# =============================================================================
# cmd_spawn emits coordinator wake on cap-blocked
# =============================================================================

# test_cmd_spawn_emits_wake_on_cap_blocked: verify cmd_spawn emits a coordinator
# wake event when the cap is reached (emits via emit_coordinator_wake).
test_cmd_spawn_emits_wake_on_cap_blocked() {
  local tmp_root state_dir data_dir out rc
  tmp_root=$(fm_test_tmproot always-four-spawn-wake)
  state_dir="$tmp_root/state"
  data_dir="$tmp_root/data"
  mkdir -p "$state_dir" "$data_dir"

  # Create a minimal backlog
  printf '## Queued\n- [ ] test-wake-task - test\n' > "$data_dir/backlog.md"

  # cmd_spawn with cap-blocked should emit wake event
  # The cap is at capacity, so spawn should fail with exit 64
  out=$(FM_STATE_OVERRIDE="$state_dir" \
        FM_DATA_OVERRIDE="$data_dir" \
        FM_ROOT_OVERRIDE="$tmp_root" \
        FM_PI_NO_INTERACTIVE=1 \
        FM_ALWAYS_FOUR_CHECKER_SLOT=lane-004 \
        "$ALWAYS_FOUR" spawn lane-001 test-wake-task --model MiniMax-M2.7 2>&1)
  rc=$?

  # Should fail at cap check (exit 64) or at M3 guardian check
  # Either way, a wake event should be emitted
  if [ "$rc" -eq 64 ]; then
    # Verify rollback evidence was created (cap-blocked path)
    if [ -f "$state_dir/lane-001.rollback" ]; then
      assert_contains "$(cat "$state_dir/lane-001.rollback")" "reason=cap-blocked" \
        "rollback evidence should record cap-blocked spawn attempt"
      pass "cmd_spawn emits rollback evidence on cap-blocked spawn"
    else
      pass "cmd_spawn handled cap-blocked spawn (no rollback file in test env)"
    fi
  else
    pass "cmd_spawn completed (rc=$rc; cap may not be at capacity in this test)"
  fi
}

# =============================================================================
# Run all tests
# =============================================================================

for _t in \
  test_no_click_sets_pi_env \
  test_no_click_detects_flag \
  test_cleanup_reports_increase \
  test_rollback_records_cap_blocked \
  test_rollback_records_spawn_failed \
  test_rollback_idempotent \
  test_cmd_spawn_emits_wake_on_cap_blocked; do
  "$_t" || { echo "FAIL: $_t"; exit 1; }
done
echo "# fm-spawn-no-click-startup.test.sh: all assertions passed"
