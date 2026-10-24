#!/usr/bin/env bash
# tests/fm-spawn-liveness-verification.test.sh - Verified agent liveness at spawn
#
# Proves:
# 1. fm-spawn.sh verifies the agent process, not just pane existence.
# 2. A pane sitting at a bare shell prompt after launch (agent died at startup)
#    is a typed nonzero failure, NOT a success line.
# 3. Liveness verification has a bounded timeout and does not hang.
# 4. Unverifiable launches fail closed.
# 5. Failure messages name the cause, window, and observed state.
# 6. Explicit failure custody is retained in .status and .meta so resources
#    are not orphaned.
#
# Runs against real isolated Herdr and tmux lab sessions, never mocks.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# shellcheck source=tests/herdr-test-safety.sh
. "$ROOT/tests/herdr-test-safety.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"
TMP_ROOT=$(fm_test_tmproot fm-spawn-liveness)

setup_test_project() {
  local proj=$1
  mkdir -p "$proj"
  (
    cd "$proj" || exit 1
    git init -b main >/dev/null 2>&1
    git config user.name "Liveness Test"
    git config user.email "test@example.com"
    echo "# test project" > README.md
    git add README.md
    git commit -m "init" >/dev/null 2>&1
  )
}

setup_firstmate_home() {
  local home=$1 id=$2
  mkdir -p "$home/data/$id" "$home/state" "$home/projects" "$home/config"
  echo "brief for $id" > "$home/data/$id/brief.md"
}

# --- Test 1: Real Herdr isolated lab - agent dying at startup fails typed with custody ---
test_herdr_agent_died_at_startup_fails() {
  command -v herdr >/dev/null 2>&1 || { echo "skip: herdr not installed"; return 0; }
  herdr_forget_inherited_pane

  local session scratch home proj id out status
  session=$(fm_herdr_lab_name "liveness-dead")
  export HERDR_SESSION="$session"
  fm_herdr_lab_provision "$session" || fail "could not provision isolated herdr lab session"

  scratch="$TMP_ROOT/herdr-dead"
  home="$scratch/home"
  proj="$scratch/proj"
  id="herdr-dead-task"

  setup_firstmate_home "$home" "$id"
  setup_test_project "$proj"

  out=$(
    HERDR_SESSION="$session" FM_ROOT_OVERRIDE="" FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_DISPATCH_GUARD_BYPASS=1 \
    FM_SPAWN_VERIFY_TIMEOUT=2 \
    env -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_TAB_ID -u HERDR_WORKSPACE_ID -u HERDR_SOCKET_PATH \
    "$SPAWN" "$id" "$proj" "sh -c exit" --backend herdr --model gemini-3.8-flash-medium 2>&1
  )
  status=$?

  # Teardown lab
  treehouse free "$proj" 2>/dev/null || rm -rf "/root/.treehouse/$(basename "$proj")"-* 2>/dev/null || true
  fm_herdr_lab_teardown "$session"

  [ "$status" -ne 0 ] || fail "fm-spawn should have exited non-zero when agent died at startup in herdr, got 0 with output: $out"
  assert_not_contains "$out" "spawned $id" \
    "fm-spawn must not report success for an agent that died at startup"
  assert_contains "$out" "error:" \
    "failure must be typed with error: prefix"
  assert_contains "$out" "observed state: dead" \
    "failure message must name the observed state (dead)"
  assert_contains "$out" "inspect window" \
    "failure message must provide inspection custody pointer"

  # Explicit failure custody verification
  [ -f "$home/state/$id.status" ] || fail "failure custody: status file must exist"
  assert_contains "$(cat "$home/state/$id.status")" "failed: spawned agent not alive in window" \
    "failure custody: status log must record typed failed: wake event"
  assert_contains "$(cat "$home/state/$id.status")" "(observed state: dead)" \
    "failure custody: status log must record observed state dead"
  [ -f "$home/state/$id.meta" ] || fail "failure custody: meta file must be retained for teardown/recovery"

  pass "real herdr lab: agent dying at startup produces typed nonzero failure and retains explicit custody"
}

# --- Test 2: Real tmux isolated session - agent dying at startup fails typed with custody ---
test_tmux_agent_died_at_startup_fails() {
  command -v tmux >/dev/null 2>&1 || { echo "skip: tmux not installed"; return 0; }

  local scratch home proj id out status
  scratch="$TMP_ROOT/tmux-dead"
  home="$scratch/home"
  proj="$scratch/proj"
  id="tmux-dead-task"

  setup_firstmate_home "$home" "$id"
  setup_test_project "$proj"

  out=$(
    FM_ROOT_OVERRIDE="" FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_DISPATCH_GUARD_BYPASS=1 \
    FM_SPAWN_VERIFY_TIMEOUT=2 \
    "$SPAWN" "$id" "$proj" "sh -c exit" --backend tmux --model gemini-3.8-flash-medium 2>&1
  )
  status=$?

  tmux kill-session -t "firstmate" 2>/dev/null || true
  treehouse free "$proj" 2>/dev/null || rm -rf "/root/.treehouse/$(basename "$proj")"-* 2>/dev/null || true

  [ "$status" -ne 0 ] || fail "fm-spawn should have exited non-zero when agent died at startup in tmux, got 0 with output: $out"
  assert_not_contains "$out" "spawned $id" \
    "fm-spawn must not report success for an agent that died at startup in tmux"
  assert_contains "$out" "error:" \
    "failure must be typed with error: prefix"
  assert_contains "$out" "observed state: dead" \
    "failure message must name the observed state (dead)"
  assert_contains "$out" "inspect window" \
    "failure message must provide inspection custody pointer"

  # Explicit failure custody verification
  [ -f "$home/state/$id.status" ] || fail "failure custody: status file must exist"
  assert_contains "$(cat "$home/state/$id.status")" "failed: spawned agent not alive in window" \
    "failure custody: status log must record typed failed: wake event"
  assert_contains "$(cat "$home/state/$id.status")" "(observed state: dead)" \
    "failure custody: status log must record observed state dead"
  [ -f "$home/state/$id.meta" ] || fail "failure custody: meta file must be retained for teardown/recovery"

  pass "real tmux: agent dying at startup produces typed nonzero failure and retains explicit custody"
}

# --- Test 3: Unverifiable launch fails closed without production overrides ---
test_unverifiable_launch_fails_closed() {
  local scratch home proj id out status test_root

  # 1. Direct contract verification: backends without liveness support return 'unverified'
  # shellcheck source=bin/fm-backend.sh
  . "$ROOT/bin/fm-backend.sh"
  [ "$(fm_backend_agent_state zellij "any:target")" = "unverified" ] || \
    fail "zellij backend must return unverified for agent state"
  [ "$(fm_backend_agent_state cmux "any:target")" = "unverified" ] || \
    fail "cmux backend must return unverified for agent state"

  # 2. fm-spawn verification: an unverified state aborts before reporting success
  scratch="$TMP_ROOT/unverifiable"
  home="$scratch/home"
  proj="$scratch/proj"
  id="unverif-task"
  test_root="$scratch/test_root"

  setup_firstmate_home "$home" "$id"
  setup_test_project "$proj"

  # Build an isolated test-root overlay that wraps fm_backend_agent_state to unverified
  # without touching any production files
  mkdir -p "$test_root/bin"
  cp -r "$ROOT/bin/"* "$test_root/bin/"
  cat >> "$test_root/bin/fm-backend.sh" <<'SH'
fm_backend_agent_state() {
  printf 'unverified'
}
SH

  out=$(
    FM_ROOT_OVERRIDE="$test_root" FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_DISPATCH_GUARD_BYPASS=1 \
    FM_SPAWN_VERIFY_TIMEOUT=1 \
    "$test_root/bin/fm-spawn.sh" "$id" "$proj" "sh -c exit" --backend tmux --model gemini-3.8-flash-medium 2>&1
  )
  status=$?

  tmux kill-session -t "firstmate" 2>/dev/null || true
  treehouse free "$proj" 2>/dev/null || rm -rf "/root/.treehouse/$(basename "$proj")"-* 2>/dev/null || true

  [ "$status" -ne 0 ] || fail "unverifiable launch must fail non-zero, got 0 with output: $out"
  assert_not_contains "$out" "spawned $id" \
    "unverifiable launch must never report success"
  assert_contains "$out" "observed state: unverified" \
    "unverifiable launch failure message must name observed state unverified"
  assert_contains "$(cat "$home/state/$id.status")" "(observed state: unverified)" \
    "unverifiable launch must record failure custody in status file"

  pass "unverifiable launch fails closed without reporting success and retains custody"
}

# --- Test 4: Liveness verification bounded timeout does not hang ---
test_bounded_timeout_does_not_hang() {
  local scratch home proj id out status started ended elapsed
  scratch="$TMP_ROOT/timeout"
  home="$scratch/home"
  proj="$scratch/proj"
  id="timeout-task"

  setup_firstmate_home "$home" "$id"
  setup_test_project "$proj"

  started=$(date +%s)
  out=$(
    FM_ROOT_OVERRIDE="" FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_DISPATCH_GUARD_BYPASS=1 \
    FM_SPAWN_VERIFY_TIMEOUT=1 \
    "$SPAWN" "$id" "$proj" "sh -c exit" --backend tmux --model gemini-3.8-flash-medium 2>&1
  )
  status=$?
  ended=$(date +%s)
  elapsed=$((ended - started))

  tmux kill-session -t "firstmate" 2>/dev/null || true
  treehouse free "$proj" 2>/dev/null || rm -rf "/root/.treehouse/$(basename "$proj")"-* 2>/dev/null || true

  [ "$status" -ne 0 ] || fail "timed out verification must exit non-zero"
  [ "$elapsed" -lt 10 ] || fail "verification should have respected bounded timeout 1s, took ${elapsed}s"

  pass "bounded timeout: verification does not hang and respects configured timeout"
}

# --- Test 5: Verified alive agent succeeds and reports spawned in real tmux ---
test_verified_live_agent_succeeds() {
  command -v tmux >/dev/null 2>&1 || { echo "skip: tmux not installed"; return 0; }

  local scratch home proj id out status bin_dir
  scratch="$TMP_ROOT/alive"
  home="$scratch/home"
  proj="$scratch/proj"
  id="alive-task"
  bin_dir="$scratch/bin"

  setup_firstmate_home "$home" "$id"
  setup_test_project "$proj"

  # Create an executable named 'pi' that stays alive so tmux "#{pane_current_command}"
  # genuinely reports 'pi', recognized by fm_backend_tmux_agent_state as 'alive'.
  mkdir -p "$bin_dir"
  cp /bin/sleep "$bin_dir/pi"
  chmod +x "$bin_dir/pi"

  out=$(
    FM_ROOT_OVERRIDE="" FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_DISPATCH_GUARD_BYPASS=1 \
    FM_SPAWN_VERIFY_TIMEOUT=5 \
    "$SPAWN" "$id" "$proj" "$bin_dir/pi 30" --backend tmux --model gemini-3.8-flash-medium 2>&1
  )
  status=$?

  tmux kill-session -t "firstmate" 2>/dev/null || true
  treehouse free "$proj" 2>/dev/null || rm -rf "/root/.treehouse/$(basename "$proj")"-* 2>/dev/null || true

  expect_code 0 "$status" "verified live agent should succeed with exit 0"
  assert_contains "$out" "spawned $id" \
    "verified live agent must print the spawned success line"
  assert_contains "$out" "harness=pi" \
    "verified live agent output must report harness=pi"
  [ -f "$home/state/$id.meta" ] || fail "meta file must exist for verified live agent"

  pass "real tmux: verified live agent survives launch, settles, and reports spawned success"
}

# --- Test 6: C1 attack resistance - FM_TEST_AGENT_STATE_OVERRIDE in env cannot fake liveness ---
test_c1_override_attack_refused_dead_agent_still_fails() {
  command -v tmux >/dev/null 2>&1 || { echo "skip: tmux not installed"; return 0; }

  local scratch home proj id out status
  scratch="$TMP_ROOT/c1-override-attack"
  home="$scratch/home"
  proj="$scratch/proj"
  id="c1-attack-task"

  setup_firstmate_home "$home" "$id"
  setup_test_project "$proj"

  # Under C1 attack: a crew sets FM_TEST_AGENT_STATE_OVERRIDE=alive in ambient environment.
  # Production dispatch MUST ignore it: a dead agent must still report dead, never succeed.
  out=$(
    FM_TEST_AGENT_STATE_OVERRIDE=alive \
    FM_ROOT_OVERRIDE="" FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_DISPATCH_GUARD_BYPASS=1 \
    FM_SPAWN_VERIFY_TIMEOUT=2 \
    "$SPAWN" "$id" "$proj" "sh -c exit" --backend tmux --model gemini-3.8-flash-medium 2>&1
  )
  status=$?

  tmux kill-session -t "firstmate" 2>/dev/null || true
  treehouse free "$proj" 2>/dev/null || rm -rf "/root/.treehouse/$(basename "$proj")"-* 2>/dev/null || true

  [ "$status" -ne 0 ] || fail "C1 attack: dead agent with FM_TEST_AGENT_STATE_OVERRIDE=alive must NOT succeed, got 0 with: $out"
  assert_not_contains "$out" "spawned $id" \
    "C1 attack: fm-spawn must not report success when override is present in ambient env"
  assert_contains "$out" "observed state: dead" \
    "C1 attack: dead agent must still report observed state: dead despite ambient override"
  [ -f "$home/state/$id.status" ] || fail "failure custody: status file must exist"
  assert_contains "$(cat "$home/state/$id.status")" "(observed state: dead)" \
    "C1 attack: status log must record observed state dead"

  pass "C1 attack defeated: ambient FM_TEST_AGENT_STATE_OVERRIDE=alive is ignored; dead agent still fails"
}

test_herdr_agent_died_at_startup_fails
test_tmux_agent_died_at_startup_fails
test_unverifiable_launch_fails_closed
test_bounded_timeout_does_not_hang
test_verified_live_agent_succeeds
test_c1_override_attack_refused_dead_agent_still_fails
