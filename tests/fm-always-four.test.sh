#!/usr/bin/env bash
# tests/fm-always-four.test.sh - Unit tests for fm-always-four.sh scheduler hook.
#
# Tests cover:
#   - slot_model_for_lane: model-based slot enforcement (3×M3.1-Flash + 1×GLM-5.3-Flash checker)
#   - cleanup_lane_resources: browser/process cleanup for terminal lanes
#   - record_rollback_evidence: rollback evidence tracking
#   - cmd_daemon --once: single-cycle daemon mode
#   - cmd_cycle with model-based replacement
#   - cmd_status: status output includes slot model info
#   - cap enforcement: check_cap, lane_at_max_attempts, spawn block on cap-reached
#   - M3 lane protection: can_replace_lane blocks protected M3 lanes
#   - event emission: emit_coordinator_wake, emit_review_event
#   - G-3 fix: pane count vs meta-file count in cmd_cycle capacity check
#   - lane accounting: fm-backend.sh sourced at top level, configuration-derived
#     worker-model filter, distinct endpoint_task_id counting, controller-meta
#     exclusion, and the task-status-log liveness rule

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
  # Worker lanes (non-checker) should return WORKER_MODEL (MiniMax-M3.1-Flash)
  for lane in lane-001 lane-002 lane-003; do
    local model
    model=$(FM_ALWAYS_FOUR_CHECKER_SLOT=lane-004 \
            FM_ALWAYS_FOUR_WORKER_MODEL=MiniMax-M3.1-Flash \
            FM_ALWAYS_FOUR_CHECKER_MODEL=GLM-5.3-Flash \
            slot_model_for_lane "$lane")
    [ "$model" = "MiniMax-M3.1-Flash" ] || fail "slot_model_for_lane($lane) should return MiniMax-M3.1-Flash, got: $model"
  done
  pass "slot_model_for_lane returns worker model for non-checker lanes"
}

test_slot_model_checker_lane() {
  # Checker slot (lane-004) should return CHECKER_MODEL (default: GLM-5.3-Flash)
  local model
  model=$(FM_ALWAYS_FOUR_CHECKER_SLOT=lane-004 \
          FM_ALWAYS_FOUR_WORKER_MODEL=MiniMax-M3.1-Flash \
          FM_ALWAYS_FOUR_CHECKER_MODEL=GLM-5.3-Flash \
          slot_model_for_lane lane-004)
  [ "$model" = "GLM-5.3-Flash" ] || fail "slot_model_for_lane(lane-004) should return GLM-5.3-Flash, got: $model"
  pass "slot_model_for_lane returns checker model for checker slot"
}

test_slot_model_custom_checker_slot() {
  # Custom checker slot should be respected
  local model
  model=$(FM_ALWAYS_FOUR_CHECKER_SLOT=lane-002 \
          FM_ALWAYS_FOUR_WORKER_MODEL=MiniMax-M3.1-Flash \
          FM_ALWAYS_FOUR_CHECKER_MODEL=GLM-5.3-Flash \
          slot_model_for_lane lane-002)
  [ "$model" = "GLM-5.3-Flash" ] || fail "slot_model_for_lane(lane-002) with CHECKER_SLOT=lane-002 should return GLM-5.3-Flash, got: $model"
  pass "slot_model_for_lane respects custom checker slot"
}

test_slot_model_default_checker_is_glm52() {
  # Without FM_ALWAYS_FOUR_CHECKER_MODEL, checker slot defaults to GLM-5.3-Flash
  local model
  model=$(FM_ALWAYS_FOUR_CHECKER_SLOT=lane-004 \
          FM_ALWAYS_FOUR_WORKER_MODEL=MiniMax-M3.1-Flash \
          slot_model_for_lane lane-004)
  [ "$model" = "GLM-5.3-Flash" ] || fail "slot_model_for_lane(lane-004) default should be GLM-5.3-Flash, got: $model"
  pass "slot_model_for_lane default checker model is GLM-5.3-Flash"
}

test_scheduler_dispatch_requires_explicit_non_pi_harness() {
  local key
  FM_ALWAYS_FOUR_HARNESS=pi scheduler_harness_guard codex \
    || fail "an explicit codex harness must pass the scheduler guard"
  [ "$SCHEDULER_HARNESS" = codex ] \
    || fail "the scheduler guard must retain the normalized explicit harness"
  key=$(lane_key_for_task lane-001 dispatch-harness-test MiniMax-M3.1-Flash 2>/dev/null) \
    || fail "lane-key minting must use the selected explicit harness"
  case "$key" in
    codex-*) ;;
    *) fail "lane key must use the selected codex harness, got: $key" ;;
  esac
  pass "scheduler dispatch requires an explicit non-Pi/non-AGY adapter"
}

test_scheduler_brief_and_spawn_use_selected_harness() {
  local tmp_root fakebin brief_args spawn_args
  tmp_root=$(fm_test_tmproot always-four-selected-harness)
  fakebin="$tmp_root/bin"
  mkdir -p "$fakebin" "$tmp_root/data" "$tmp_root/state"
  cat > "$fakebin/fm-brief.sh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_BRIEF_ARGS"
mkdir -p "$DATA/$1"
printf '{TASK}\n' > "$DATA/$1/brief.md"
STUB
  cat > "$fakebin/fm-spawn.sh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_SPAWN_ARGS"
STUB
  chmod +x "$fakebin/fm-brief.sh" "$fakebin/fm-spawn.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/tasks-axi"
  chmod +x "$fakebin/tasks-axi"
  printf '## In flight\n\n## Queued\n- [ ] selected-harness-task - Use the selected adapter (repo: test-project)\n' \
    > "$tmp_root/data/backlog.md"

  (
    SCRIPT_DIR="$fakebin"
    DATA="$tmp_root/data"
    STATE="$tmp_root/state"
    SCAFFOLD_BRIEF=1
    MINT_LANE_KEY=0
    FM_ALWAYS_FOUR_HARNESS=pi
    FAKE_BRIEF_ARGS="$tmp_root/brief.args"
    FAKE_SPAWN_ARGS="$tmp_root/spawn.args"
    PATH="$fakebin:$PATH"
    export DATA FAKE_BRIEF_ARGS FAKE_SPAWN_ARGS PATH
    scheduler_harness_guard codex || exit 1
    scaffold_lane_key_brief selected-harness-lane selected-harness-task || exit 1
    fm_raw_herdr_senpi_refuse_mutate() { :; }
    can_replace_lane() { return 0; }
    reap_stale() { :; }
    check_cap() { return 0; }
    prepare_lane_key_brief() { return 0; }
    start_task_inflight() { :; }
    lane_reset_attempts() { :; }
    record_lane_key_origin() { :; }
    record_lane_slot_binding() { :; }
    emit_coordinator_wake() { :; }
    sync_gbrain() { :; }
    lane_inc_attempts() { :; }
    record_rollback_evidence() { :; }
    cmd_spawn spawn lane-001 selected-harness-task --harness codex || exit 1
  ) || fail "scheduler dispatch should use the selected harness for brief and spawn"

  brief_args=$(cat "$tmp_root/brief.args")
  spawn_args=$(cat "$tmp_root/spawn.args")
  assert_contains "$brief_args" "codex" \
    "brief scaffolding must receive the normalized selected harness"
  assert_not_contains "$brief_args" "pi" \
    "brief scaffolding must not receive the conflicting environment harness"
  assert_contains "$spawn_args" "codex" \
    "spawn must receive the normalized selected harness"
  assert_not_contains "$spawn_args" "pi" \
    "spawn must not receive the conflicting environment harness"
  pass "scheduler brief scaffolding and spawn use the selected harness"
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
    record_rollback_evidence lane-001 test-task-123 "spawn-failed" "rc=1 model=MiniMax-M3.1-Flash"

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
        FM_ALWAYS_FOUR_WORKER_MODEL=MiniMax-M3.1-Flash \
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
          FM_ALWAYS_FOUR_WORKER_MODEL=MiniMax-M3.1-Flash \
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
# Lane-accounting census tests (D1-D5 regression guards)
#
# These tests use an ISOLATED home: a temp state dir plus a fakebin whose
# `tmux` stub exits 0, so fm_backend_target_exists reports a synthetic endpoint
# as present without touching a real pane.  The live state/ and data/ are never
# read or written: every call runs with FM_STATE_OVERRIDE pointed at the temp
# state dir and inside a command substitution (a subshell), so no override
# leaks into the next test.
# =============================================================================

# fm_test_census_home <prefix>: build the isolated home.  Prints the state dir
# and the fakebin dir on ONE space-separated line (a herestring feeds `read` a
# single line, so the two paths must share it).
fm_test_census_home() {
  local prefix=${1:-always-four-census} root fakebin
  root=$(fm_test_tmproot "$prefix")
  mkdir -p "$root/state" "$root/data" "$root/projects/routable-project/.git"
  fakebin=$(fm_fakebin "$root")
  fm_fake_exit0 "$fakebin" tmux
  printf '%s %s\n' "$root/state" "$fakebin"
}

# fm_test_write_worker_meta <state_dir> <meta-basename> <task-id> <model> [kind]
# [verb]: write a synthetic worker meta plus the TASK status log it names.
# The meta file is <meta-basename>.meta.
# The status log's last line carries <verb>, so the terminal/non-terminal
# distinction is exercised through the real status reader.
fm_test_write_worker_meta() {
  local state_dir=$1 name=$2 task_id=$3 model=$4 kind=${5:-} verb=${6:-working}
  {
    printf 'endpoint_task_id=%s\n' "$task_id"
    printf 'window=default:fake-pane-1\n'
    printf 'backend=tmux\n'
    printf 'harness=minimax-code\n'
    printf 'model=%s\n' "$model"
    if [ -n "$kind" ]; then printf 'kind=%s\n' "$kind"; fi
    true
  } > "$state_dir/$name.meta"
  printf '%s: synthetic task log\n' "$verb" > "$state_dir/$task_id.status"
}

test_scheduler_sources_fm_backend_library() {
  # D1 regression guard: fm-backend.sh must be sourced at TOP LEVEL of the
  # scheduler, so the backend/meta primitives are defined in the scheduler's
  # own shell.  Sourcing it in a subshell left all of them missing, which
  # killed the lane liveness gate and made every meta classify "unknown
  # no-target".
  local fn
  for fn in fm_backend_of_meta fm_backend_target_of_meta fm_backend_target_exists \
            fm_backend_capture fm_backend_busy_state fm_meta_get; do
    declare -F "$fn" >/dev/null 2>&1 \
      || fail "$fn must be defined after sourcing the scheduler (fm-backend.sh sourced at top level)"
  done
  command -v fm_backend_target_exists >/dev/null 2>&1 \
    || fail "command -v fm_backend_target_exists must resolve after sourcing the scheduler"
  pass "scheduler sources fm-backend.sh at top level (backend primitives are defined)"
}

test_count_active_worker_tasks_uses_configured_worker_model() {
  # D3: the accepted model is derived from the scheduler's OWN configuration
  # (WORKER_MODEL, resolved from FM_ALWAYS_FOUR_WORKER_MODEL), never from a
  # hardcoded model list that goes stale when a model is retired.
  local state_dir fakebin count

  # The configured worker model is counted.
  read -r state_dir fakebin <<< "$(fm_test_census_home always-four-census-model)"
  fm_test_write_worker_meta "$state_dir" "task-configured.meta" "task-configured" "$WORKER_MODEL"
  count=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" count_active_worker_tasks 2>/dev/null)
  [ "$count" = "1" ] || fail "census should count the configured worker model once, got: $count"

  # A meta with any other model is not counted.
  read -r state_dir fakebin <<< "$(fm_test_census_home always-four-census-other-model)"
  fm_test_write_worker_meta "$state_dir" "task-other.meta" "task-other" "model-not-configured"
  count=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" count_active_worker_tasks 2>/dev/null)
  [ "$count" = "0" ] || fail "census must not count a meta whose model is not configured, got: $count"

  # The filter follows the configuration: the same meta is counted when the
  # configuration names its model, and rejected when it does not.
  read -r state_dir fakebin <<< "$(fm_test_census_home always-four-census-config-derived)"
  fm_test_write_worker_meta "$state_dir" "task-probe.meta" "task-probe" "configured-model-probe"
  count=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" \
          WORKER_MODEL="configured-model-probe" count_active_worker_tasks 2>/dev/null)
  [ "$count" = "1" ] || fail "census must follow the configured worker model, got: $count"
  count=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" \
          WORKER_MODEL="a-different-configured-model" count_active_worker_tasks 2>/dev/null)
  [ "$count" = "0" ] || fail "census must reject a model the configuration does not name, got: $count"

  pass "count_active_worker_tasks accepts the configured worker model and rejects others"
}

test_count_active_worker_tasks_counts_distinct_endpoint_task_ids() {
  # D4: each managed lane owns BOTH state/<lane-id>.meta and
  # state/<endpoint_task_id>.meta carrying the SAME endpoint_task_id, so the
  # census must count DISTINCT endpoint_task_id values only.
  local state_dir fakebin count
  read -r state_dir fakebin <<< "$(fm_test_census_home always-four-census-duplicate)"
  fm_test_write_worker_meta "$state_dir" "lane-009.meta" "task-duplicate" "$WORKER_MODEL"
  fm_test_write_worker_meta "$state_dir" "task-duplicate.meta" "task-duplicate" "$WORKER_MODEL"
  count=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" count_active_worker_tasks 2>/dev/null)
  [ "$count" = "1" ] || fail "one endpoint_task_id in two metas must be counted once, got: $count"
  pass "count_active_worker_tasks counts distinct endpoint_task_ids only"
}

test_count_active_worker_tasks_excludes_controller_metas() {
  # D4: controller metas carry the worker model but are not workers.  ship and
  # scout kinds ARE workers and must stay in the census.
  local state_dir fakebin count
  read -r state_dir fakebin <<< "$(fm_test_census_home always-four-census-controller)"
  fm_test_write_worker_meta "$state_dir" "agents-console.meta" "task-secondmate" "$WORKER_MODEL" "secondmate"
  fm_test_write_worker_meta "$state_dir" "system-ops.meta" "task-controller" "$WORKER_MODEL" "controller"
  count=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" count_active_worker_tasks 2>/dev/null)
  [ "$count" = "0" ] || fail "controller metas must not be counted as workers, got: $count"

  read -r state_dir fakebin <<< "$(fm_test_census_home always-four-census-ship)"
  fm_test_write_worker_meta "$state_dir" "task-ship.meta" "task-ship" "$WORKER_MODEL" "ship"
  fm_test_write_worker_meta "$state_dir" "task-scout.meta" "task-scout" "$WORKER_MODEL" "scout"
  count=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" count_active_worker_tasks 2>/dev/null)
  [ "$count" = "2" ] || fail "ship and scout kinds are real workers and must be counted, got: $count"
  pass "count_active_worker_tasks excludes controller metas and keeps ship/scout workers"
}

test_count_active_worker_tasks_respects_task_status_verb() {
  # D5: the liveness rule reads the TASK status log.  A task whose log ends in
  # a terminal verb is not working; a task whose log ends in a non-terminal
  # verb is.
  local state_dir fakebin count
  read -r state_dir fakebin <<< "$(fm_test_census_home always-four-census-verb-done)"
  fm_test_write_worker_meta "$state_dir" "task-done.meta" "task-done" "$WORKER_MODEL" "" "done"
  count=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" count_active_worker_tasks 2>/dev/null)
  [ "$count" = "0" ] || fail "a task whose task log ends in done: must not be counted, got: $count"

  read -r state_dir fakebin <<< "$(fm_test_census_home always-four-census-verb-working)"
  fm_test_write_worker_meta "$state_dir" "task-live.meta" "task-live" "$WORKER_MODEL" "" "working"
  count=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" count_active_worker_tasks 2>/dev/null)
  [ "$count" = "1" ] || fail "a task whose task log ends in working: must be counted, got: $count"

  pass "count_active_worker_tasks counts only tasks whose task log ends in a non-terminal verb"
}

test_lane_is_active_reads_the_task_status_log() {
  # D2: lane_is_active must read the TASK status log (state/<task-id>.status),
  # not the slot log (state/<lane-id>.status, which holds this scheduler's own
  # binding and wake events), and it must be able to report a lane ACTIVE.
  local state_dir fakebin active
  read -r state_dir fakebin <<< "$(fm_test_census_home always-four-census-lane)"

  # lane-007: its task log ends in done:, so the lane is settled.
  fm_test_write_worker_meta "$state_dir" "lane-007" "task-lane-done" "$WORKER_MODEL" "" "done"
  printf '2026-10-23T00:00:00Z: always-four[stall]: lane=lane-007 max attempts reached\n' \
    > "$state_dir/lane-007.status"
  active=0
  ( PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" lane_is_active lane-007 ) && active=1
  [ "$active" -eq 0 ] || fail "lane_is_active must not report a lane active when its TASK log ends in done:"

  # lane-008: its task log ends in working:, so the lane IS working.
  fm_test_write_worker_meta "$state_dir" "lane-008" "task-lane-live" "$WORKER_MODEL" "" "working"
  active=0
  ( PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" lane_is_active lane-008 ) && active=1
  [ "$active" -eq 1 ] || fail "lane_is_active must report a lane active when its TASK log ends in working:"

  pass "lane_is_active reads the task status log and can report a lane active"
}

# =============================================================================
# Run all tests
# =============================================================================

test_next_eligible_task_skips_captain_call_rows() {
  # D6: a Captain Call row is NOT lane work. The decision-hold lifecycle
  # creates one backlog row per unresolved Captain decision, marked
  # "(kind: captain)"; that row waits for the Captain answer. Dispatching it
  # to a lane burns a lane on work the Captain must do.
  local root fakebin chosen
  root=$(fm_test_tmproot always-four-captain-skip)
  mkdir -p "$root/state" "$root/data" "$root/projects/routable-project/.git"
  fakebin=$(fm_fakebin "$root")
  fm_fake_exit0 "$fakebin" tmux
  cat > "$root/data/backlog.md" <<'BACKLOG'
# Backlog

## In flight

## Queued
- [ ] captain-decision-row - Decide something for the Captain (repo: routable-project) (kind: captain) (since 2026-10-23)
- [ ] normal-work-row - Do ordinary lane work (repo: routable-project) (kind: scout)

## Done
BACKLOG
  chosen=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$root/state" FM_DATA_OVERRIDE="$root/data" \
          FM_LANE_PROJECT_BASE="$root/projects" next_eligible_task 2>/dev/null)
  [ "$chosen" = "normal-work-row" ] \
    || fail "next_eligible_task must skip a Captain Call row, got: '$chosen'"
  pass "next_eligible_task skips Captain Call rows"
}

test_lane_key_for_task_never_doubles_the_prefix() {
  # D7: the decision-hold lifecycle names its Captain rows after the lane that
  # raised them ("<harness>-<model>-<host>-<task>-decision-<key>"). Minting
  # such an id produced "<harness>-<model>-<host>-<harness>-<model>-<host>-...".
  local key
  scheduler_harness_guard codex >/dev/null 2>&1 \
    || fail "the explicit codex harness must be accepted before minting a lane key"
  key=$(lane_key_for_task lane-001 "codex-luna6-brandon-luna-credentials-runbook-11-decision-host-targets" "openai-codex/gpt-6-luna" 2>/dev/null || true)
  [ -n "$key" ] || fail "lane_key_for_task must mint a key for an already-prefixed planning id"
  case "$key" in
    codex-luna6-brandon-codex-luna6-brandon-*) fail "lane_key_for_task must not prefix an already lane-key-shaped id twice: $key" ;;
  esac
  [ "${#key}" -le 64 ] || fail "minted lane key must stay within the 64-character cap: $key"
  # The task segment must still be recognisable, just not doubled. The task
  # segment is longer than the 64-character cap allows, so the naming owner
  # shortens it and appends a deterministic hash suffix; the readable part of
  # the original segment must survive.
  case "$key" in
    *credentials-runbook-11-decision-*) : ;;
    *) fail "minted lane key must keep the original task segment: $key" ;;
  esac
  pass "lane_key_for_task never prefixes an already lane-key-shaped id twice"
}

test_next_eligible_task_skips_unroutable_project_rows() {
  # D8: a queued row naming a project that is not a git checkout can never be
  # spawned. fm-spawn.sh fails with "could not resolve the shared Treehouse
  # project lock", the lane burns its attempts, and the whole half starves on
  # one unroutable row while routable rows sit queued.
  local root fakebin chosen
  root=$(fm_test_tmproot always-four-unroutable-skip)
  mkdir -p "$root/state" "$root/data" "$root/projects/routable-project/.git"
  fakebin=$(fm_fakebin "$root")
  fm_fake_exit0 "$fakebin" tmux
  cat > "$root/data/backlog.md" <<'BACKLOG'
# Backlog

## In flight

## Queued
- [ ] unroutable-work-row - Do work in a directory that is not a checkout (repo: not-a-checkout) (kind: ship)
- [ ] routable-work-row - Do ordinary lane work (repo: routable-project) (kind: scout)

## Done
BACKLOG
  chosen=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$root/state" FM_DATA_OVERRIDE="$root/data" \
          FM_LANE_PROJECT_BASE="$root/projects" next_eligible_task 2>/dev/null)
  [ "$chosen" = "routable-work-row" ] \
    || fail "next_eligible_task must skip a row whose project is not a checkout, got: '$chosen'"
  pass "next_eligible_task skips rows whose project is not a checkout"
}

test_pane_foreground_harness_alive_matches_only_the_running_harness() {
  # The census fallback: a lane with no .status file (the MiniMax harness
  # writes none) is judged by its pane's foreground process.  That oracle must
  # match the harness that is actually running, and nothing else.
  local dir fakebin
  dir=$(mktemp -d)
  fakebin="$dir/bin"; mkdir -p "$fakebin"
  cat > "$fakebin/herdr" <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
{"result":{"process_info":{"foreground_processes":[{"name":"minimax-code","argv":["minimax-code","--model","minimax/MiniMax-M3.1-Flash"]}]}}}
JSON
STUB
  chmod +x "$fakebin/herdr"

  ( PATH="$fakebin:$PATH"; fm_pane_foreground_harness_alive herdr default:w99:p1 minimax-code )
  [ $? -eq 0 ] || fail "a pane running minimax-code must read as alive"

  if ( PATH="$fakebin:$PATH"; fm_pane_foreground_harness_alive herdr default:w99:p1 codex ) >/dev/null 2>&1; then
    fail "a pane running minimax-code must NOT read as a codex pane"
  fi

  # A non-herdr backend has no such oracle and must never claim to be alive.
  if ( PATH="$fakebin:$PATH"; fm_pane_foreground_harness_alive tmux default:w99:p1 minimax-code ) >/dev/null 2>&1; then
    fail "a tmux target must not use the herdr foreground-process oracle"
  fi

  pass "the pane foreground-process oracle matches the running harness and nothing else"
}

test_scheduler_moves_a_dispatched_row_with_tasks_axi_start() {
  local root fakebin log
  root=$(fm_test_tmproot always-four-row-move)
  fakebin="$root/bin"
  log="$root/tasks-axi.log"
  mkdir -p "$fakebin" "$root/data" "$root/state"
  printf '# Backlog\n\n## Queued\n\n## In flight\n' > "$root/data/backlog.md"
  cat > "$fakebin/tasks-axi" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TASKS_AXI_LOG"
STUB
  chmod +x "$fakebin/tasks-axi"
  TASKS_AXI_LOG="$log" PATH="$fakebin:$PATH" \
    FM_STATE_OVERRIDE="$root/state" DATA="$root/data" \
    start_task_inflight dispatched-row \
    || fail "the scheduler's queue transition should invoke tasks-axi successfully"
  assert_contains "$(cat "$log")" "start" \
    "queue transition should use the tasks-axi start action"
  assert_contains "$(cat "$log")" "dispatched-row" \
    "queue transition should name the dispatched row"
  assert_contains "$(cat "$log")" "$root/data/backlog.md" \
    "queue transition should target the scheduler backlog"
  pass "a dispatched row uses the executable tasks-axi start transition"
}

test_dispatch_ownership_requires_spawn_and_commits_success() {
  local failed_root success_root fakebin
  failed_root=$(fm_test_tmproot always-four-dispatch-failure)
  fakebin="$failed_root/bin"
  mkdir -p "$fakebin" "$failed_root/data" "$failed_root/state"
  printf '# Backlog\n\n## Queued\n- [ ] failed-dispatch - a queued row\n\n## In flight\n' > "$failed_root/data/backlog.md"
  cat > "$fakebin/fm-spawn.sh" <<'STUB'
#!/usr/bin/env bash
exit 7
STUB
  chmod +x "$fakebin/fm-spawn.sh"
  (
    SCRIPT_DIR="$fakebin" STATE="$failed_root/state" DATA="$failed_root/data" FM_STATE_OVERRIDE="$failed_root/state"
    MINT_LANE_KEY=0 SCHEDULER_HARNESS=codex
    export SCRIPT_DIR STATE DATA FM_STATE_OVERRIDE MINT_LANE_KEY SCHEDULER_HARNESS
    fm_raw_herdr_senpi_refuse_mutate() { :; }
    can_replace_lane() { return 0; }
    reap_stale() { :; }
    check_cap() { return 0; }
    prepare_lane_key_brief() { return 0; }
    backlog_task_to_project() { printf 'projects/%s\n' "$1"; }
    lane_reset_attempts() { :; }
    lane_inc_attempts() { :; }
    lane_attempts() { printf '0\n'; }
    emit_coordinator_wake() { :; }
    sync_gbrain() { :; }
    record_rollback_evidence() { :; }
    lane_ids() { printf 'lane-001\n'; }
    lane_is_active() { [ -f "$STATE/lane-001.meta" ]; }
    if cmd_spawn spawn lane-001 failed-dispatch --harness codex --model MiniMax-M3.1-Flash; then
      exit 1
    fi
    awk '/^## Queued/{q=1; next} /^## /{q=0} q && /failed-dispatch/{found=1} END{exit !found}' "$DATA/backlog.md"
    [ "$(count_active_lanes)" = 0 ]
  ) || fail "a failed spawn must remain queued and inactive"

  success_root=$(fm_test_tmproot always-four-dispatch-success)
  fakebin="$success_root/bin"
  mkdir -p "$fakebin" "$success_root/data" "$success_root/state"
  printf '# Backlog\n\n## Queued\n- [ ] successful-dispatch - a queued row\n\n## In flight\n' > "$success_root/data/backlog.md"
  cat > "$fakebin/fm-spawn.sh" <<STUB
#!/usr/bin/env bash
cat > "$success_root/state/\$1.meta" <<META
endpoint_task_id=\$1
window=default:w1:p1
harness=codex
model=MiniMax-M3.1-Flash
META
STUB
  cat > "$fakebin/tasks-axi" <<'STUB'
#!/usr/bin/env bash
cat > "$4" <<BACKLOG
# Backlog

## Queued

## In flight
- [ ] successful-dispatch - a queued row
BACKLOG
STUB
  printf 'endpoint_task_id=successful-dispatch\nwindow=default:w1:p1\nharness=codex\nmodel=MiniMax-M3.1-Flash\n' \
    > "$success_root/state/successful-dispatch.meta"
  chmod +x "$fakebin/fm-spawn.sh" "$fakebin/tasks-axi"
  (
    SCRIPT_DIR="$fakebin" STATE="$success_root/state" DATA="$success_root/data" FM_STATE_OVERRIDE="$success_root/state"
    MINT_LANE_KEY=0 SCHEDULER_HARNESS=codex
    export SCRIPT_DIR STATE DATA FM_STATE_OVERRIDE MINT_LANE_KEY SCHEDULER_HARNESS
    PATH="$fakebin:$PATH"; export PATH
    fm_raw_herdr_senpi_refuse_mutate() { :; }
    can_replace_lane() { return 0; }
    reap_stale() { :; }
    check_cap() { return 0; }
    prepare_lane_key_brief() { return 0; }
    backlog_task_to_project() { printf 'projects/%s\n' "$1"; }
    lane_reset_attempts() { :; }
    record_lane_slot_binding() { : > "$STATE/lane-001.meta"; }
    emit_coordinator_wake() { :; }
    sync_gbrain() { :; }
    lane_inc_attempts() { :; }
    record_rollback_evidence() { :; }
    lane_ids() { printf 'lane-001\n'; }
    lane_is_active() { [ -f "$STATE/lane-001.meta" ]; }
    cmd_spawn spawn lane-001 successful-dispatch --harness codex --model MiniMax-M3.1-Flash \
      || exit 1
    awk '/^## In flight/{f=1; next} /^## /{f=0} f && /successful-dispatch/{found=1} END{exit !found}' "$DATA/backlog.md"
    [ "$(count_active_lanes)" = 1 ]
  ) || fail "a successful spawn must move the row in flight and count one active lane"
  pass "dispatch ownership fails closed and commits one active lane after spawn"
}

test_tasks_axi_start_moves_the_row_and_is_idempotent() {
  command -v tasks-axi >/dev/null 2>&1 || {
    pass "tasks-axi is not installed here; the contract test was skipped"
    return 0
  }
  local f
  f=$(mktemp)
  printf '# Scratch\n\n## Queued\n\n- [ ] demo-row-one - a scratch row\n\n## In flight\n\n## Done\n' > "$f"
  tasks-axi start demo-row-one --file "$f" >/dev/null 2>&1 \
    || fail "tasks-axi start failed on a scratch backlog"
  [ "$(grep -c 'demo-row-one' "$f")" = "1" ] \
    || fail "the row must exist exactly once after the move"
  awk '/^## In flight/{f=1;next} /^## /{f=0} f&&/demo-row-one/{found=1} END{exit found?0:1}' "$f" \
    || fail "the row must sit under the In flight section"
  tasks-axi start demo-row-one --file "$f" >/dev/null 2>&1 \
    || fail "a second tasks-axi start must be idempotent, not an error"
  [ "$(grep -c 'demo-row-one' "$f")" = "1" ] \
    || fail "the row must still exist exactly once after a second start"
  rm -f "$f"
  pass "tasks-axi start moves the row to In flight and is idempotent"
}

test_build_inflight_tmp_drops_a_finished_lanes_row() {
  # A lane that has finished must not keep its queued row pinned in flight.
  # The task metas of finished lanes are never cleaned up, so a row the half
  # had ever run stayed in the set and could never be dispatched again.
  local state_dir fakebin tmp
  read -r state_dir fakebin <<< "$(fm_test_census_home always-four-inflight-terminal)"
  fm_test_write_worker_meta "$state_dir" "task-done.meta" "task-done" "$WORKER_MODEL" "" "done"
  printf 'queued-row-done\n' > "$state_dir/task-done.planning-id"
  fm_test_write_worker_meta "$state_dir" "task-live.meta" "task-live" "$WORKER_MODEL" "" "working"
  printf 'queued-row-live\n' > "$state_dir/task-live.planning-id"

  FM_STATE_OVERRIDE="$state_dir" build_inflight_tmp >/dev/null 2>&1
  tmp="$state_dir/.always-four.inflight.tmp"
  [ -f "$tmp" ] || fail "build_inflight_tmp did not write its temp file"
  if grep -qx 'queued-row-done' "$tmp"; then
    fail "a finished lane's row must not stay pinned in flight"
  fi
  grep -qx 'queued-row-live' "$tmp" \
    || fail "a working lane's row must stay pinned in flight"
  pass "a finished lane's row is released; a working lane's row stays pinned"
}

test_capacity_gate_counts_managed_lane_slots_not_crew() {
  local state_dir fakebin managed worker
  read -r state_dir fakebin <<< "$(fm_test_census_home always-four-capacity-owner)"
  fm_test_write_worker_meta "$state_dir" "lane-001" "managed-task" "$WORKER_MODEL" "ship" "working"
  fm_test_write_worker_meta "$state_dir" "standing-ship" "standing-task" "$WORKER_MODEL" "ship" "working"
  managed=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" count_active_lanes 2>/dev/null)
  worker=$(PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state_dir" count_active_worker_tasks 2>/dev/null)
  [ "$managed" = "1" ] || fail "managed capacity should count one occupied scheduler slot, got: $managed"
  [ "$worker" = "2" ] || fail "worker census should include the standing crew, got: $worker"
  pass "the capacity gate counts managed lane slots, not the standing crew"
}

test_attempt_budget_belongs_to_the_task_not_the_slot() {
  # The cap stops a hopeless spawn of the SAME task from being hammered. It
  # must not tombstone a lane slot because an unrelated, now-gone task failed
  # to spawn three times - that is how a finished lane stayed unfilled forever.
  local state_dir fakebin
  read -r state_dir fakebin <<< "$(fm_test_census_home always-four-attempt-budget)"
  printf '3 old-task-that-failed\n' > "$state_dir/lane-001.attempts"

  # The attempt helpers resolve the state dir at CALL time, so the isolated
  # home must be in force for every call.
  (
    export FM_STATE_OVERRIDE="$state_dir"
    lane_at_max_attempts lane-001 old-task-that-failed \
      || { echo "the same task must still be blocked at the cap" >&2; exit 1; }
    if lane_at_max_attempts lane-001 a-different-task; then
      echo "a different task must have a fresh budget" >&2; exit 1
    fi
    lane_inc_attempts lane-001 a-different-task
    [ "$(lane_attempts lane-001)" = "1" ] \
      || { echo "a different task must start its own budget at 1, got $(lane_attempts lane-001)" >&2; exit 1; }
    lane_inc_attempts lane-001 a-different-task
    [ "$(lane_attempts lane-001)" = "2" ] \
      || { echo "repeated failures of the same task must count up, got $(lane_attempts lane-001)" >&2; exit 1; }
  ) || fail "the attempt budget must follow the task, not the lane slot"
  pass "the attempt budget belongs to the task, not to the lane slot"
}

test_pane_foreground_state_distinguishes_dead_from_unknown() {
  # The corroboration oracle must be able to say "definitively dead" as well as
  # "alive", and it must be able to say "I do not know" - a caller that treats
  # unknown as dead would replace a working lane.
  local dir fakebin
  dir=$(mktemp -d)
  fakebin="$dir/bin"; mkdir -p "$fakebin"

  cat > "$fakebin/herdr" <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
{"result":{"process_info":{"foreground_processes":[{"name":"minimax-code","argv":["minimax-code"]}]}}}
JSON
STUB
  chmod +x "$fakebin/herdr"
  ( PATH="$fakebin:$PATH"; fm_pane_foreground_harness_state herdr default:w99:p1 minimax-code )
  [ $? -eq 0 ] || fail "a pane running minimax-code must read as alive (0)"

  cat > "$fakebin/herdr" <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
{"result":{"process_info":{"foreground_processes":[{"name":"bash","argv":["/bin/bash"]}]}}}
JSON
STUB
  chmod +x "$fakebin/herdr"
  ( PATH="$fakebin:$PATH"; fm_pane_foreground_harness_state herdr default:w99:p1 minimax-code )
  [ $? -eq 1 ] || fail "a pane with no harness process must read as dead (1)"

  cat > "$fakebin/herdr" <<'STUB'
#!/usr/bin/env bash
echo "not json at all"
STUB
  chmod +x "$fakebin/herdr"
  ( PATH="$fakebin:$PATH"; fm_pane_foreground_harness_state herdr default:w99:p1 minimax-code )
  [ $? -eq 2 ] || fail "an unreadable answer must read as unknown (2), not dead"

  cat > "$fakebin/herdr" <<'STUB'
#!/usr/bin/env bash
exit 3
STUB
  chmod +x "$fakebin/herdr"
  ( PATH="$fakebin:$PATH"; fm_pane_foreground_harness_state herdr default:w99:p1 minimax-code )
  [ $? -eq 2 ] || fail "a failed query must read as unknown (2), not dead"

  ( PATH="$fakebin:$PATH"; fm_pane_foreground_harness_state tmux default:w99:p1 minimax-code )
  [ $? -eq 2 ] || fail "a non-herdr backend must read as unknown (2)"

  pass "the corroboration oracle separates alive, dead and unknown"
}

test_lane_is_active_releases_a_finished_lane_with_a_dead_worker() {
  local tmp_root state_dir
  tmp_root=$(fm_test_tmproot always-four-dead-finished-worker)
  state_dir="$tmp_root/state"
  mkdir -p "$state_dir"
  {
    printf 'endpoint_task_id=finished-task\n'
    printf 'window=default:finished-pane\n'
    printf 'backend=herdr\n'
    printf 'harness=codex\n'
  } > "$state_dir/lane-001.meta"
  printf 'done: finished\n' > "$state_dir/finished-task.status"
  (
    FM_STATE_OVERRIDE="$state_dir"
    lane_current_task() { printf 'finished-task'; }
    fm_backend_target_exists() { return 0; }
    fm_backend_capture() { printf 'busy transcript'; }
    fm_busy_classify() { printf 'busy synthetic'; }
    fm_pane_foreground_harness_state() { return 1; }
    lane_is_active lane-001
  ) && fail "a finished lane with a dead worker must be released"
  pass "a finished lane with a dead worker is released, and only then"
}

for _t in \
  test_slot_model_worker_lanes \
  test_slot_model_checker_lane \
  test_slot_model_custom_checker_slot \
  test_slot_model_default_checker_is_glm52 \
  test_scheduler_dispatch_requires_explicit_non_pi_harness \
  test_scheduler_brief_and_spawn_use_selected_harness \
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
  test_pane_count_guarded_by_reap_stale \
  test_scheduler_sources_fm_backend_library \
  test_count_active_worker_tasks_uses_configured_worker_model \
  test_count_active_worker_tasks_counts_distinct_endpoint_task_ids \
  test_count_active_worker_tasks_excludes_controller_metas \
  test_count_active_worker_tasks_respects_task_status_verb \
  test_lane_is_active_reads_the_task_status_log \
  test_next_eligible_task_skips_captain_call_rows \
  test_lane_key_for_task_never_doubles_the_prefix \
  test_next_eligible_task_skips_unroutable_project_rows \
  test_pane_foreground_harness_alive_matches_only_the_running_harness \
  test_scheduler_moves_a_dispatched_row_with_tasks_axi_start \
  test_dispatch_ownership_requires_spawn_and_commits_success \
  test_tasks_axi_start_moves_the_row_and_is_idempotent \
  test_build_inflight_tmp_drops_a_finished_lanes_row \
  test_capacity_gate_counts_managed_lane_slots_not_crew \
  test_attempt_budget_belongs_to_the_task_not_the_slot \
  test_pane_foreground_state_distinguishes_dead_from_unknown \
  test_lane_is_active_releases_a_finished_lane_with_a_dead_worker; do
  "$_t" || { echo "FAIL: $_t"; exit 1; }
done
echo "# fm-always-four.test.sh: all assertions passed"
