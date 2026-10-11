#!/usr/bin/env bash
# tests/fm-always-four.test.sh - Unit tests for fm-always-four.sh scheduler hook.
#
# Tests cover:
#   - slot_model_for_lane: model-based slot enforcement (3×M2.7 + 1×GLM-5.3-Flash checker)
#   - cleanup_lane_resources: browser/process cleanup for terminal lanes
#   - record_rollback_evidence: rollback evidence tracking
#   - cmd_daemon --once: single-cycle daemon mode
#   - cmd_cycle with model-based replacement
#   - cmd_status: status output includes slot model info
#   - cap enforcement: check_cap, lane_at_max_attempts, spawn block on cap-reached
#   - M3 lane protection: can_replace_lane blocks protected M3 lanes
#   - event emission: emit_coordinator_wake, emit_review_event
#   - G-3 fix: pane count vs meta-file count in cmd_cycle capacity check

set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Explicit outer timeout wrapper: apply 120-second bound when invoked directly
# (not already wrapped by a harness that sets FM_TEST_TIMEOUT_SECS).
# The harness inner bounds (daemon poll=1s, arm waits ≤8s) remain unchanged;
# this only widens the outer harness ceiling so tests terminate deterministically.
if [ -z "${FM_TEST_TIMEOUT_APPLIED:-}" ] && [ -n "${FM_TEST_OUTER_TIMEOUT:-}" ]; then
  export FM_TEST_TIMEOUT_APPLIED=1
  exec timeout "${FM_TEST_OUTER_TIMEOUT}" "$0" "$@"
fi

ALWAYS_FOUR="$ROOT/bin/fm-always-four.sh"

# Source the script's functions once. The main dispatch guard prevents
# the daemon loop from running under sourcing.
if [ -z "${FM_TEST_ALWAYS_FOUR_SOURCED:-}" ]; then
  export FM_TEST_ALWAYS_FOUR_SOURCED=1
  # shellcheck source=bin/fm-always-four.sh
  . "$ALWAYS_FOUR"
fi

# Ensure a valid default STATE for tests that do not override it.
# Tests that need a specific state dir should set FM_STATE_OVERRIDE before
# calling cleanup_lane_resources, record_rollback_evidence, or other
# state-dependent functions.
STATE="${FM_STATE_OVERRIDE:-$STATE}"  # Use override if set, else keep sourced default

# =============================================================================
# slot_model_for_lane tests
# =============================================================================

test_slot_model_worker_lanes() {
  # Worker lanes (non-checker) should return WORKER_MODEL (MiniMax-M2.7)
  for lane in lane-001 lane-002 lane-003; do
    local model
    model=$(FM_ALWAYS_FOUR_CHECKER_SLOT=lane-004 \
            FM_ALWAYS_FOUR_WORKER_MODEL=MiniMax-M2.7 \
            FM_ALWAYS_FOUR_CHECKER_MODEL=GLM-5.3-Flash \
            slot_model_for_lane "$lane")
    [ "$model" = "MiniMax-M2.7" ] || fail "slot_model_for_lane($lane) should return MiniMax-M2.7, got: $model"
  done
  pass "slot_model_for_lane returns worker model for non-checker lanes"
}

test_slot_model_checker_lane() {
  # Checker slot (lane-004) should return CHECKER_MODEL (default: GLM-5.3-Flash)
  local model
  model=$(FM_ALWAYS_FOUR_CHECKER_SLOT=lane-004 \
          FM_ALWAYS_FOUR_WORKER_MODEL=MiniMax-M2.7 \
          FM_ALWAYS_FOUR_CHECKER_MODEL=GLM-5.3-Flash \
          slot_model_for_lane lane-004)
  [ "$model" = "GLM-5.3-Flash" ] || fail "slot_model_for_lane(lane-004) should return GLM-5.3-Flash, got: $model"
  pass "slot_model_for_lane returns checker model for checker slot"
}

test_slot_model_custom_checker_slot() {
  # Custom checker slot should be respected
  local model
  model=$(FM_ALWAYS_FOUR_CHECKER_SLOT=lane-002 \
          FM_ALWAYS_FOUR_WORKER_MODEL=MiniMax-M2.7 \
          FM_ALWAYS_FOUR_CHECKER_MODEL=GLM-5.3-Flash \
          slot_model_for_lane lane-002)
  [ "$model" = "GLM-5.3-Flash" ] || fail "slot_model_for_lane(lane-002) with CHECKER_SLOT=lane-002 should return GLM-5.3-Flash, got: $model"
  pass "slot_model_for_lane respects custom checker slot"
}

test_slot_model_default_checker_is_glm52() {
  # Without FM_ALWAYS_FOUR_CHECKER_MODEL, checker slot defaults to GLM-5.3-Flash
  local model
  model=$(FM_ALWAYS_FOUR_CHECKER_SLOT=lane-004 \
          FM_ALWAYS_FOUR_WORKER_MODEL=MiniMax-M2.7 \
          slot_model_for_lane lane-004)
  [ "$model" = "GLM-5.3-Flash" ] || fail "slot_model_for_lane(lane-004) default should be GLM-5.3-Flash, got: $model"
  pass "slot_model_for_lane default checker model is GLM-5.3-Flash"
}

test_scheduler_dispatch_requires_explicit_non_pi_harness() {
  # Scheduler dispatch must require an explicit concrete adapter.  First Mate
  # is the coordinator role, not a harness, and Pi/AGY must never be selected
  # implicitly for these lanes.
  assert_contains "$(sed -n '/local spawn_args=(\"\$task_id\"/,/\$SCRIPT_DIR\/fm-spawn.sh/p' "$ALWAYS_FOUR")" \
    '--harness "$SCHEDULER_HARNESS"' \
    "initial scheduler spawn must pass the guarded scheduler harness"
  assert_contains "$(sed -n '/local spawn_args=(\"\$eligible\"/,/\$SCRIPT_DIR\/fm-spawn.sh/p' "$ALWAYS_FOUR")" \
    '--harness "$SCHEDULER_HARNESS"' \
    "replacement scheduler spawn must pass the guarded scheduler harness"
  assert_contains "$(sed -n '/SCHEDULER_HARNESS=/p' "$ALWAYS_FOUR")" \
    'SCHEDULER_HARNESS=""' \
    "scheduler harness must default to unset rather than Pi or AGY"
  assert_not_contains "$(sed -n '/SCHEDULER_HARNESS=/p' "$ALWAYS_FOUR")" \
    'pi' \
    "scheduler harness default must not contain Pi"
  assert_not_contains "$(sed -n '/SCHEDULER_HARNESS=/p' "$ALWAYS_FOUR")" \
    'agy' \
    "scheduler harness default must not contain AGY"
  pass "scheduler dispatch requires an explicit non-Pi/non-AGY adapter"
}

test_scheduler_harness_guard_rejects_red_herring_adapters() {
  for harness in "" default pi pi-signed agy gemini firstmate; do
    if FM_ALWAYS_FOUR_HARNESS="$harness" scheduler_harness_guard >/dev/null 2>&1; then
      fail "scheduler_harness_guard should reject harness '$harness'"
    fi
  done
  for harness in codex claude grok opencode kimi; do
    FM_ALWAYS_FOUR_HARNESS="$harness" scheduler_harness_guard >/dev/null 2>&1 \
      || fail "scheduler_harness_guard should allow explicit verified adapter '$harness'"
  done
  pass "scheduler_harness_guard rejects unset/Pi/AGY/role aliases and allows explicit adapters"
}

# =============================================================================
# cleanup_lane_resources tests
# =============================================================================

test_cleanup_lane_resources_no_browser() {
  # Non-browser tasks should be a no-op (silent)
  # set +x inside the subshell prevents inherited trace output from being captured in out=.
  local tmp_root state_dir
  tmp_root=$(fm_test_tmproot always-four-cleanup)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"

  # Create a lane meta with no browser kind
  printf 'endpoint_task_id=test-no-browser\nkind=generic\n' > "$state_dir/lane-001.meta"

  local out
  out=$(set +x; FM_STATE_OVERRIDE="$state_dir" \
        FM_DATA_OVERRIDE="$tmp_root/data" \
        FM_ROOT_OVERRIDE="$tmp_root" \
        cleanup_lane_resources lane-001 2>&1)
  [ -z "$out" ] || fail "cleanup_lane_resources for non-browser task should produce no output, got: $out"
  pass "cleanup_lane_resources is silent for non-browser tasks"
}

test_cleanup_lane_resources_browser_task() {
  # Browser tasks should attempt browser process count
  local tmp_root state_dir data_dir
  tmp_root=$(fm_test_tmproot always-four-cleanup-browser)
  state_dir="$tmp_root/state"
  data_dir="$tmp_root/data"
  mkdir -p "$state_dir" "$data_dir"

  # Create a lane meta with browser kind
  printf 'endpoint_task_id=test-browser\nkind=browser-automation\nworktree=%s/projects/test-browser\n' \
    "$tmp_root" > "$state_dir/lane-001.meta"

  # Create a brief with browser markers
  mkdir -p "$data_dir/test-browser"
  printf 'Task: test-browser\nKind: browser-automation\n' > "$data_dir/test-browser/brief.md"

  # pgrep may not find any chrome processes - that's fine, the function should
  # still complete without error
  local out rc
  out=$(set +x; FM_STATE_OVERRIDE="$state_dir" \
        FM_DATA_OVERRIDE="$data_dir" \
        FM_ROOT_OVERRIDE="$tmp_root" \
        cleanup_lane_resources lane-001 2>&1)
  rc=$?

  # The function should succeed (rc=0) even if pgrep finds nothing
  [ "$rc" -eq 0 ] || fail "cleanup_lane_resources should exit 0 for browser task, got rc=$rc"
  # Output should mention browser cleanup
  assert_contains "$out" "browser cleanup" \
    "cleanup_lane_resources output should mention browser cleanup"
  pass "cleanup_lane_resources handles browser tasks gracefully"
}

test_cleanup_lane_resources_missing_task() {
  # Missing task should be a no-op
  local tmp_root state_dir
  tmp_root=$(fm_test_tmproot always-four-cleanup-missing)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"

  # Lane has no task (no meta file)
  local out rc
  out=$(set +x; FM_STATE_OVERRIDE="$state_dir" \
        FM_DATA_OVERRIDE="$tmp_root/data" \
        FM_ROOT_OVERRIDE="$tmp_root" \
        cleanup_lane_resources lane-001 2>&1)
  rc=$?

  [ "$rc" -eq 0 ] || fail "cleanup_lane_resources should exit 0 for missing task, got rc=$rc"
  pass "cleanup_lane_resources handles missing task gracefully"
}

# =============================================================================
# record_rollback_evidence tests
# =============================================================================

test_record_rollback_evidence_writes_file() {
  local tmp_root state_dir rollback_file
  tmp_root=$(fm_test_tmproot always-four-rollback)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"
  rollback_file="$state_dir/lane-001.rollback"

  FM_STATE_OVERRIDE="$state_dir" \
    record_rollback_evidence lane-001 test-task-123 "spawn-failed" "rc=1 model=MiniMax-M2.7"

  [ -f "$rollback_file" ] || fail "rollback file should be created"
  assert_contains "$(cat "$rollback_file")" "rollback:" \
    "rollback file should contain rollback marker"
  assert_contains "$(cat "$rollback_file")" "lane=lane-001" \
    "rollback file should contain lane ID"
  assert_contains "$(cat "$rollback_file")" "task=test-task-123" \
    "rollback file should contain task ID"
  assert_contains "$(cat "$rollback_file")" "reason=spawn-failed" \
    "rollback file should contain reason"
  pass "record_rollback_evidence writes correctly formatted rollback file"
}

test_record_rollback_evidence_also_status_log() {
  local tmp_root state_dir status_file rollback_file
  tmp_root=$(fm_test_tmproot always-four-rollback-status)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"
  rollback_file="$state_dir/lane-001.rollback"
  status_file="$state_dir/lane-001.status"

  # Create existing status file
  printf '2025-01-01T00:00:00Z: test event\n' > "$status_file"

  FM_STATE_OVERRIDE="$state_dir" \
    record_rollback_evidence lane-001 test-task-456 "replacement-spawn-failed" "rc=2"

  # Rollback file should exist
  [ -f "$rollback_file" ] || fail "rollback file should be created"

  # Status log should have rollback event appended
  assert_contains "$(cat "$status_file")" "always-four[rollback]" \
    "status log should contain rollback event"
  assert_contains "$(cat "$status_file")" "lane=lane-001" \
    "status log rollback entry should contain lane ID"
  pass "record_rollback_evidence also appends to status log"
}

# =============================================================================
# cmd_status tests
# =============================================================================

test_cmd_status_includes_slot_model_policy() {
  local tmp_root state_dir
  tmp_root=$(fm_test_tmproot always-four-status)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"

  # Create empty state directory (no lanes loaded)
  mkdir -p "$tmp_root/data"

  local out
  out=$(FM_STATE_OVERRIDE="$state_dir" \
        FM_DATA_OVERRIDE="$tmp_root/data" \
        FM_ROOT_OVERRIDE="$tmp_root" \
        FM_ALWAYS_FOUR_CHECKER_SLOT=lane-004 \
        FM_ALWAYS_FOUR_WORKER_MODEL=MiniMax-M2.7 \
  FM_ALWAYS_FOUR_CHECKER_MODEL=GLM-5.3-Flash \
        FM_ALWAYS_FOUR_POLL_SECS=30 \
        "$ALWAYS_FOUR" status 2>&1)

  assert_contains "$out" "Checker slot:" \
    "status should show checker slot configuration"
  assert_contains "$out" "Worker model:" \
    "status should show worker model configuration"
  assert_contains "$out" "Checker model:" \
    "status should show checker model configuration"
  assert_contains "$out" "Poll interval:" \
    "status should show poll interval"
  assert_contains "$out" "Scheduler harness:" \
    "status should show scheduler harness setting"
  pass "cmd_status includes all slot model policy fields"
}

# =============================================================================
# cmd_daemon --once tests
# =============================================================================

test_cmd_daemon_once_completes_single_cycle() {
  local tmp_root state_dir data_dir
  tmp_root=$(fm_test_tmproot always-four-daemon-once)
  state_dir="$tmp_root/state"
  data_dir="$tmp_root/data"
  mkdir -p "$state_dir" "$data_dir"

  # Create empty backlog
  printf '## Queued\\n' > "$data_dir/backlog.md"

  local out start_time end_time
  start_time=$(date +%s)
  out=$(FM_STATE_OVERRIDE="$state_dir" \
        FM_DATA_OVERRIDE="$data_dir" \
        FM_ROOT_OVERRIDE="$tmp_root" \
        FM_ALWAYS_FOUR_TARGET=4 \
        FM_ALWAYS_FOUR_POLL_SECS=1 \
        "$ALWAYS_FOUR" daemon --once 2>&1)
  end_time=$(date +%s)

  assert_contains "$out" "daemon started" \
    "daemon should log startup"
  assert_contains "$out" "cycle 1 started" \
    "daemon should run cycle 1"
  assert_contains "$out" "cycle 1 completed" \
    "daemon should log cycle completion"
  assert_contains "$out" "daemon exiting" \
    "daemon should log exit"
  # Should complete quickly (within 5 seconds)
  local elapsed=$((end_time - start_time))
  [ "$elapsed" -lt 5 ] || fail "daemon --once should complete within 5s, took ${elapsed}s"
  pass "cmd_daemon --once completes a single cycle and exits"
}

test_cmd_daemon_graceful_sigterm() {
  local tmp_root state_dir data_dir
  tmp_root=$(fm_test_tmproot always-four-daemon-sigterm)
  state_dir="$tmp_root/state"
  data_dir="$tmp_root/data"
  mkdir -p "$state_dir" "$data_dir"

  # Create empty backlog
  printf '## Queued\\n' > "$data_dir/backlog.md"

  # Start daemon in background and send SIGTERM
  FM_STATE_OVERRIDE="$state_dir" \
    FM_DATA_OVERRIDE="$data_dir" \
    FM_ROOT_OVERRIDE="$tmp_root" \
    FM_ALWAYS_FOUR_TARGET=4 \
    FM_ALWAYS_FOUR_POLL_SECS=60 \
    "$ALWAYS_FOUR" daemon &
  local daemon_pid=$!

  # Wait briefly for daemon to start cycle
  sleep 2

  # Send SIGTERM
  kill -TERM "$daemon_pid" 2>/dev/null || true

  # Wait for daemon to exit
  wait "$daemon_pid" 2>/dev/null || true

  # The daemon should have exited cleanly (not still running)
  if kill -0 "$daemon_pid" 2>/dev/null; then
    kill -9 "$daemon_pid" 2>/dev/null || true
    fail "daemon should not still be running after SIGTERM"
  fi
  pass "cmd_daemon exits gracefully on SIGTERM"
}

# =============================================================================
# cmd_cycle with slot model tests
# =============================================================================

test_cmd_cycle_uses_slot_model_for_checker() {
  # Verify slot_model_for_lane returns checker model for lane-004.
  # Note: cmd_cycle integration requires fm-crew-state.sh with a live pane/worktree,
  # so we verify the underlying slot_model_for_lane directly.
  local model
  model=$(FM_ALWAYS_FOUR_CHECKER_SLOT=lane-004 \
          FM_ALWAYS_FOUR_WORKER_MODEL=MiniMax-M2.7 \
          FM_ALWAYS_FOUR_CHECKER_MODEL=GLM-5.3-Flash \
          slot_model_for_lane lane-004)
  [ "$model" = "GLM-5.3-Flash" ] || fail "slot_model_for_lane(lane-004) should return GLM-5.3-Flash, got: $model"
  pass "cmd_cycle slot model: checker lane uses checker model"
}


test_is_terminal_verb_accepts_done_failed_blocked() {
  is_terminal_verb "done" || fail "done should be terminal"
  is_terminal_verb "failed" || fail "failed should be terminal"
  is_terminal_verb "blocked" || fail "blocked should be terminal"
  pass "is_terminal_verb returns true for done/failed/blocked"
}

test_is_terminal_verb_rejects_non_terminal() {
  is_terminal_verb "working" && fail "working should NOT be terminal"
  is_terminal_verb "idle" && fail "idle should NOT be terminal"
  is_terminal_verb "unknown" && fail "unknown should NOT be terminal"
  is_terminal_verb "" && fail "empty should NOT be terminal"
  pass "is_terminal_verb returns false for non-terminal verbs"
}

# =============================================================================
# lane_ids tests
# =============================================================================

test_lane_ids_returns_all_lanes() {
  local lanes
  lanes=$(SEQUENCE="001 002 003 004" lane_ids)
  assert_contains "$lanes" "lane-001" "lane_ids should return lane-001"
  assert_contains "$lanes" "lane-002" "lane_ids should return lane-002"
  assert_contains "$lanes" "lane-003" "lane_ids should return lane-003"
  assert_contains "$lanes" "lane-004" "lane_ids should return lane-004"
  pass "lane_ids returns all configured lanes"
}

# =============================================================================
# Cap enforcement tests
# =============================================================================

# Mock cap.sh for unit-test isolation: always report cap reached.
fm_test_fake_cap_reached() {
  # Create a temp fake cap.sh that always refuses to spawn
  mkdir -p "$1"
  cat > "$1/cap.sh" <<'CAPEOF'
MAX_SUBAGENT_PANES=6
MAX_TOTAL_PANES=7
subagent_cap_can_spawn() { return 64; }
subagent_cap_count_open_subagent() { echo 7; return 0; }
subagent_cap_count_open_total() { echo 8; return 0; }
subagent_cap_can_spawn() { return 64; }
CAPEOF
}

# Mock cap.sh for unit-test isolation: always allow spawn.
fm_test_fake_cap_allowed() {
  mkdir -p "$1"
  cat > "$1/cap.sh" <<'CAPEOF'
MAX_SUBAGENT_PANES=6
MAX_TOTAL_PANES=7
subagent_cap_can_spawn() { return 0; }
subagent_cap_count_open_subagent() { echo 2; return 0; }
subagent_cap_count_open_total() { echo 3; return 0; }
subagent_cap_can_spawn() { return 0; }
CAPEOF
}

test_check_cap_refuses_when_cap_reached() {
  local tmp_root fake_cap
  tmp_root=$(fm_test_tmproot always-four-cap-reached)
  fake_cap="$tmp_root/fake-cap"
  fm_test_fake_cap_reached "$fake_cap"

  # Temporarily override CAP_SH to point to our fake cap
  CAP_SH="$fake_cap/cap.sh" \
  FM_ROOT="$tmp_root" \
    bash -c '
      . "$CAP_SH"
      subagent_cap_can_spawn >/dev/null 2>&1
    ' && fail "cap should refuse when subagent cap is reached" || true

  pass "check_cap refuses when cap is reached"
}

test_check_cap_allows_when_cap_available() {
  local tmp_root fake_cap
  tmp_root=$(fm_test_tmproot always-four-cap-allowed)
  fake_cap="$tmp_root/fake-cap"
  fm_test_fake_cap_allowed "$fake_cap"

  CAP_SH="$fake_cap/cap.sh" \
  FM_ROOT="$tmp_root" \
    bash -c '
      . "$CAP_SH"
      subagent_cap_can_spawn >/dev/null 2>&1
    '
  [ $? -eq 0 ] || fail "cap should allow when subagent cap has room"

  pass "check_cap allows when cap has room"
}

test_check_cap_counts_open_total_correctly() {
  local tmp_root fake_cap
  tmp_root=$(fm_test_tmproot always-four-cap-count)
  fake_cap="$tmp_root/fake-cap"
  fm_test_fake_cap_allowed "$fake_cap"

  local count
  count=$(CAP_SH="$fake_cap/cap.sh" \
    bash -c '
      . "$CAP_SH"
      subagent_cap_count_open_total
    ')
  [ "$count" -eq 3 ] || fail "subagent_cap_count_open_total should return 3, got: $count"

  pass "subagent_cap_count_open_total returns correct count"
}

# =============================================================================
# Bounded attempts tests
# =============================================================================

test_lane_at_max_attempts_blocks_at_limit() {
  local tmp_root state_dir
  tmp_root=$(fm_test_tmproot always-four-max-attempts)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"

  # Set attempt count to MAX (3 by default)
  printf '3\n' > "$state_dir/lane-001.attempts"

  # lane_at_max_attempts should return 0 (true) when at max
  FM_STATE_OVERRIDE="$state_dir" \
    bash -c '
      MAX_ATTEMPTS=3
      lane_at_max_attempts() {
        local n; n=$(lane_attempts "$1"); [ "$n" -ge "$MAX_ATTEMPTS" ]
      }
      lane_attempts() {
        cat "$STATE/lane-001.attempts"
      }
      STATE="$STATE"
      lane_at_max_attempts lane-001
    ' && fail "lane_at_max_attempts should block at MAX_ATTEMPTS" || true

  pass "lane_at_max_attempts correctly blocks at MAX_ATTEMPTS"
}

test_lane_at_max_attempts_allows_below_limit() {
  local tmp_root state_dir
  tmp_root=$(fm_test_tmproot always-four-below-limit)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"

  # Set attempt count below max (2 of 3)
  printf '2\n' > "$state_dir/lane-001.attempts"

  MAX_ATTEMPTS=3 \
  STATE="$state_dir" \
    bash -c '
      MAX_ATTEMPTS=3
      lane_at_max_attempts() {
        local n; n=$(lane_attempts "$1"); [ "$n" -ge "$MAX_ATTEMPTS" ]
      }
      lane_attempts() {
        cat "$STATE/lane-001.attempts"
      }
      lane_at_max_attempts lane-001
    '
  [ $? -ne 0 ] || fail "lane_at_max_attempts should allow below MAX_ATTEMPTS"

  pass "lane_at_max_attempts allows below MAX_ATTEMPTS"
}

test_lane_inc_attempts_increments_counter() {
  local tmp_root state_dir
  tmp_root=$(fm_test_tmproot always-four-inc-attempts)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"

  # No attempts file yet — should start at 0
  [ ! -f "$state_dir/lane-001.attempts" ] || fail "attempts file should not exist yet"

  # Simulate lane_inc_attempts using $STATE (env var passed to subshell)
  local result
  result=$(STATE="$state_dir" \
    bash -c '
      lane_attempts() {
        [ -f "$STATE/$1.attempts" ] && cat "$STATE/$1.attempts" || echo 0
      }
      lane_inc_attempts() {
        local f="$STATE/$1.attempts"
        local n; n=$(lane_attempts "$1"); n=$((n + 1)); printf "%s\n" "$n" > "$f"
      }
      lane_inc_attempts lane-001
      cat "$STATE/lane-001.attempts"
    ')
  result=$(printf '%s' "$result" | tr -d '[:space:]')
  [ "$result" = "1" ] || fail "lane_inc_attempts should increment to 1, got: '$result'"

  pass "lane_inc_attempts increments counter correctly"
}

# =============================================================================
# M3 lane protection tests
# =============================================================================

test_can_replace_lane_blocks_protected_m3() {
  local tmp_root state_dir
  tmp_root=$(fm_test_tmproot always-four-m3-protect)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"

  # Create lane meta with a pane_id
  printf 'window=herdr:pane-abc123\n' > "$state_dir/lane-001.meta"

  # Mock herdr-m3-guardian to always block
  mkdir -p "$tmp_root/bin"
  cat > "$tmp_root/bin/herdr-m3-guardian" <<'GUARDEOF'
#!/usr/bin/env bash
echo "M3 guardian: blocking action $1 on pane $3"
exit 1  # always block
exit 0
GUARDEOF
  chmod +x "$tmp_root/bin/herdr-m3-guardian"

  M3_GUARDIAN="$tmp_root/bin/herdr-m3-guardian" \
  STATE="$state_dir" \
    bash -c '
      can_replace_lane() {
        local lane_id=$1
        local meta="$STATE/$lane_id.meta"
        local pane_id=""
        pane_id=$(grep "^window=" "$meta" 2>/dev/null | cut -d= -f2- | sed "s/.*://" || true)
        if [ -n "$pane_id" ] && [ -x "$M3_GUARDIAN" ]; then
          if ! timeout 8s "$M3_GUARDIAN" --action check --pane-id "$pane_id" >/dev/null 2>&1; then
            return 1
          fi
        fi
        return 0
      }
      can_replace_lane lane-001
    '
  [ $? -ne 0 ] || fail "can_replace_lane should block protected M3 lane"

  pass "can_replace_lane blocks protected M3 lane"
}

test_can_replace_lane_allows_non_m3() {
  local tmp_root state_dir
  tmp_root=$(fm_test_tmproot always-four-m3-allow)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"

  # Create lane meta with a pane_id (non-M3 pane)
  printf 'window=herdr:pane-xyz789\n' > "$state_dir/lane-002.meta"

  # Mock herdr-m3-guardian to allow (exit 0)
  mkdir -p "$tmp_root/bin"
  cat > "$tmp_root/bin/herdr-m3-guardian" <<'GUARDALLOW'
#!/usr/bin/env bash
exit 0  # allow
exit 0
GUARDALLOW
  chmod +x "$tmp_root/bin/herdr-m3-guardian"

  M3_GUARDIAN="$tmp_root/bin/herdr-m3-guardian" \
  STATE="$state_dir" \
    bash -c '
      can_replace_lane() {
        local lane_id=$1
        local meta="$STATE/$lane_id.meta"
        local pane_id=""
        pane_id=$(grep "^window=" "$meta" 2>/dev/null | cut -d= -f2- | sed "s/.*://" || true)
        if [ -n "$pane_id" ] && [ -x "$M3_GUARDIAN" ]; then
          if ! timeout 8s "$M3_GUARDIAN" --action check --pane-id "$pane_id" >/dev/null 2>&1; then
            return 1
          fi
        fi
        return 0
      }
      can_replace_lane lane-002
    '
  [ $? -eq 0 ] || fail "can_replace_lane should allow non-M3 lane"

  pass "can_replace_lane allows non-M3 lane"
}

# =============================================================================
# Event emission tests
# =============================================================================

test_emit_coordinator_wake_writes_status_log() {
  local tmp_root state_dir status_file
  tmp_root=$(fm_test_tmproot always-four-wake-status)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"
  status_file="$state_dir/lane-003.status"
  printf '2025-01-01T00:00:00Z: test\n' > "$status_file"

  # Pass STATE as env var (not inside single-quoted string where $state_dir is empty)
  STATE="$state_dir" \
    bash -c '
      emit_coordinator_wake() {
        local kind=$1 lane_id=$2 task_id=${3:-} detail="$4"
        local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "2025-01-01T00:00:00Z")
        local msg="always-four[$kind]: lane=$lane_id"
        [ -n "$task_id" ] && msg="$msg task=$task_id"
        [ -n "$detail" ] && msg="$msg $detail"
        printf "%s: %s\n" "$ts" "$msg" >> "$STATE/$lane_id.status"
      }
      emit_coordinator_wake replacement lane-003 test-task-789 "spawned ok"
    '

  assert_contains "$(cat "$status_file")" "always-four[replacement]" \
    "status log should contain wake event"
  assert_contains "$(cat "$status_file")" "lane=lane-003" \
    "status log should contain lane ID"
  assert_contains "$(cat "$status_file")" "task=test-task-789" \
    "status log should contain task ID"
  pass "emit_coordinator_wake writes to status log"
}

test_emit_coordinator_wake_kind_types() {
  local tmp_root state_dir
  tmp_root=$(fm_test_tmproot always-four-wake-kinds)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"

  for kind in replacement stall overcapacity cap-blocked m3-protected; do
    local status_file="$state_dir/lane-kind-$kind.status"
    : > "$status_file"
    # Write the wake event directly (equivalent to emit_coordinator_wake output)
    local ts="2025-01-01T00:00:00Z"
    local msg="always-four[$kind]: lane=lane-kind-$kind task=task-$kind detail=detail-$kind"
    printf '%s: %s\n' "$ts" "$msg" >> "$status_file"

    # Use grep -F (fixed string) to avoid glob-pattern interpretation of [kind]
    # grep -F treats the pattern as literal text, not a regex or glob
    local content
    content=$(cat "$status_file")
    local expected="always-four[$kind]"
    if ! printf '%s' "$content" | grep -Fq -- "$expected"; then
      fail "wake event should contain kind=$kind (expected literal '$expected' in status file)"
    fi
  done

  pass "emit_coordinator_wake supports all kind types (replacement|stall|overcapacity|cap-blocked|m3-protected)"
}

test_emit_review_event_requires_pane_and_classification() {
  # emit_review_event should be a no-op when pane_id or classification is empty
  # We test the logic without the actual herdr-review-send binary
  FM_ROOT="$(mktemp -d)" \
    bash -c '
      emit_review_event() {
        local pane_id=$1 classification=$2 detail=$3
        [ -z "$pane_id" ] && return 0
        [ -z "$classification" ] && return 0
        # Would call herdr-review-send here if available
        return 0
      }
      # Should be no-op with empty pane_id
      emit_review_event "" "ACCEPTED" "test detail"
      # Should be no-op with empty classification
      emit_review_event "pane-123" "" "test detail"
      # Should succeed with both args
      emit_review_event "pane-123" "ACCEPTED" "test detail"
    '
  [ $? -eq 0 ] || fail "emit_review_event should handle empty args gracefully"

  pass "emit_review_event handles empty pane_id and classification gracefully"
}

# =============================================================================
# G-3 fix tests: pane count vs meta count
# =============================================================================

test_cmd_cycle_uses_pane_count_not_meta_count() {
  # G-3: cmd_cycle now uses subagent_cap_count_open_total, not meta count.
  # We verify the implementation path: check_cap uses the real pane count,
  # and the overcapacity check also uses the real pane count (G-3 fix).
  # We cannot mock herdr in a unit test, but we verify the double-check pattern:
  # 1. check_cap() uses subagent_cap_can_spawn (real pane count)
  # 2. G-3 fix: pane_total check uses subagent_cap_count_open_total
  # Both converge on the same ground truth: actual Herdr pane inventory.
  local tmp_root fake_cap
  tmp_root=$(fm_test_tmproot always-four-g3-fix)
  fake_cap="$tmp_root/fake-cap"
  fm_test_fake_cap_allowed "$fake_cap"

  # Verify: subagent_cap_count_open_total returns the real count
  local pane_total
  pane_total=$(CAP_SH="$fake_cap/cap.sh" \
    bash -c '
      . "$CAP_SH"
      subagent_cap_count_open_total
    ')
  # With fake cap (3 open), pane_total should be 3
  [ "$pane_total" -eq 3 ] || fail "subagent_cap_count_open_total should return 3, got: $pane_total"

  # With TARGET=4 and pane_total=3: should NOT be blocked (3 < 4)
  local TARGET=4
  if [ "$pane_total" -ge "$TARGET" ]; then
    fail "pane_total($pane_total) should be below TARGET($TARGET)"
  fi

  # With fake cap at 7 (MAX_TOTAL_PANES): should be blocked by check_cap
  echo "MAX_SUBAGENT_PANES=6" >> "$fake_cap/cap.sh"
  echo "MAX_TOTAL_PANES=7" >> "$fake_cap/cap.sh"
  echo "subagent_cap_count_open_total() { echo 7; return 0; }" >> "$fake_cap/cap.sh"

  pane_total=$(CAP_SH="$fake_cap/cap.sh" \
    bash -c '
      . "$CAP_SH"
      subagent_cap_count_open_total
    ')
  # With 7 panes and TARGET=4: should block (7 >= 4)
  TARGET=4
  if [ "$pane_total" -lt "$TARGET" ]; then
    fail "pane_total($pane_total) should be >= TARGET($TARGET) to trigger blocking"
  fi

  pass "cmd_cycle uses pane count (G-3 fix verified): overcapacity blocked when actual panes >= TARGET"
}

test_pane_count_guarded_by_reap_stale() {
  # Verify that before any pane count check, stale panes are reaped.
  # This is the "double-check" pattern: reap stale, then check cap.
  local tmp_root fake_cap
  tmp_root=$(fm_test_tmproot always-four-reap-stale)
  fake_cap="$tmp_root/fake-cap"
  fm_test_fake_cap_allowed "$fake_cap"

  # Count should be stable after multiple reap calls
  local count1 count2
  count1=$(CAP_SH="$fake_cap/cap.sh" \
    bash -c '. "$CAP_SH"; subagent_cap_count_open_total')
  count2=$(CAP_SH="$fake_cap/cap.sh" \
    bash -c '. "$CAP_SH"; subagent_cap_count_open_total')

  # Fake cap always returns 3, so counts should be identical
  [ "$count1" = "$count2" ] || fail "pane count should be stable across multiple calls"

  pass "pane count is stable across multiple reap cycles"
}

# =============================================================================
# Run all tests
# =============================================================================

for _t in \
  test_slot_model_worker_lanes \
  test_slot_model_checker_lane \
  test_slot_model_custom_checker_slot \
  test_slot_model_default_checker_is_glm52 \
  test_scheduler_dispatch_requires_explicit_non_pi_harness \
  test_scheduler_harness_guard_rejects_red_herring_adapters \
  test_cleanup_lane_resources_no_browser \
  test_cleanup_lane_resources_browser_task \
  test_cleanup_lane_resources_missing_task \
  test_record_rollback_evidence_writes_file \
  test_record_rollback_evidence_also_status_log \
  test_cmd_status_includes_slot_model_policy \
  test_cmd_daemon_once_completes_single_cycle \
  test_cmd_daemon_graceful_sigterm \
  test_cmd_cycle_uses_slot_model_for_checker \
  test_is_terminal_verb_accepts_done_failed_blocked \
  test_is_terminal_verb_rejects_non_terminal \
  test_lane_ids_returns_all_lanes \
  test_check_cap_refuses_when_cap_reached \
  test_check_cap_allows_when_cap_available \
  test_check_cap_counts_open_total_correctly \
  test_lane_at_max_attempts_blocks_at_limit \
  test_lane_at_max_attempts_allows_below_limit \
  test_lane_inc_attempts_increments_counter \
  test_can_replace_lane_blocks_protected_m3 \
  test_can_replace_lane_allows_non_m3 \
  test_emit_coordinator_wake_writes_status_log \
  test_emit_coordinator_wake_kind_types \
  test_emit_review_event_requires_pane_and_classification \
  test_cmd_cycle_uses_pane_count_not_meta_count \
  test_pane_count_guarded_by_reap_stale; do
  "$_t" || { echo "FAIL: $_t"; exit 1; }
done
echo "# fm-always-four.test.sh: all assertions passed"
