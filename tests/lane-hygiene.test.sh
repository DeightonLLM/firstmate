#!/usr/bin/env bash
# tests/lane-hygiene.test.sh — behavioral tests for /root/bin/lane-hygiene
set -u

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# shellcheck disable=SC2153
LANE_HYGIENE="$ROOT/bin/lane-hygiene"

make_test_env() {
  local prefix=$1 root
  root=$(fm_test_tmproot "$prefix")
  mkdir -p "$root/bin" "$root/config" "$root/state" "$root/data" "$root/projects"
  # Mock fm-guard.sh default: exit 0, silent (healthy watcher)
  cat > "$root/bin/fm-guard.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$root/bin/fm-guard.sh"

  # Mock fm-lock.sh default: exit 0, lock held
  cat > "$root/bin/fm-lock.sh" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "status" ]; then
  echo "lock: held by live harness pid 12345"
  exit 0
fi
exit 0
SH
  chmod +x "$root/bin/fm-lock.sh"

  # Copy fm-project-capacity-lib.sh & dependencies so real capacity logic is exercised
  cp "$ROOT/bin/fm-wake-lib.sh" "$root/bin/"
  cp "$ROOT/bin/fm-secondmate-registry-lib.sh" "$root/bin/"
  cp "$ROOT/bin/fm-backend.sh" "$root/bin/"
  cp "$ROOT/bin/fm-composer-lib.sh" "$root/bin/" 2>/dev/null || true
  cp "$ROOT/bin/fm-transition-lib.sh" "$root/bin/" 2>/dev/null || true
  cp "$ROOT/bin/fm-project-capacity-lib.sh" "$root/bin/"
  mkdir -p "$root/bin/backends"
  cp "$ROOT/bin/backends/"*.sh "$root/bin/backends/" 2>/dev/null || true

  printf '%s\n' "$root"
}

test_phantom_record_detected() {
  local env wt meta out rc
  env=$(make_test_env phantom-record)
  wt="$env/worktree-clean"
  fm_git_init_commit "$wt"

  # Phantom task: dead endpoint (tmux:dead-window), clean worktree
  meta="$env/state/phantom-task.meta"
  fm_write_meta "$meta" \
    "window=firstmate:dead-window" \
    "worktree=$wt" \
    "backend=tmux" \
    "kind=ship" \
    "mode=local-only"

  # Fake tmux that returns error for target-exists (dead endpoint)
  fakebin=$(fm_fakebin "$env")
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
exit 1
SH
  chmod +x "$fakebin/tmux"

  out=$(PATH="$fakebin:$PATH" \
    FM_ROOT_OVERRIDE="$env" \
    FM_HOME="$env" \
    FM_CONFIG_OVERRIDE="$env/config" \
    FM_STATE_OVERRIDE="$env/state" \
    HERDR_CAP_CHECK_SKIP=1 \
    bash "$LANE_HYGIENE" 2>&1) || rc=$?
  rc=${rc:-0}

  [ "$rc" -ne 0 ] || fail "phantom record must cause non-zero exit, got 0: $out"
  assert_contains "$out" "phantom-task" "phantom task id must be named in output"
  assert_contains "$out" "PHANTOM" "phantom finding must be surfaced"
  pass "phantom record detected (endpoint dead, worktree clean) -> finding, non-zero exit"
}

test_live_worker_not_phantom() {
  local env wt meta out rc
  env=$(make_test_env live-worker)
  wt="$env/worktree-live"
  fm_git_init_commit "$wt"

  meta="$env/state/live-task.meta"
  fm_write_meta "$meta" \
    "window=firstmate:live-window" \
    "worktree=$wt" \
    "backend=tmux" \
    "kind=ship" \
    "mode=local-only"

  # Fake tmux that returns success for display-message (live endpoint)
  fakebin=$(fm_fakebin "$env")
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$fakebin/tmux"

  out=$(PATH="$fakebin:$PATH" \
    FM_ROOT_OVERRIDE="$env" \
    FM_HOME="$env" \
    FM_CONFIG_OVERRIDE="$env/config" \
    FM_STATE_OVERRIDE="$env/state" \
    HERDR_CAP_CHECK_SKIP=1 \
    bash "$LANE_HYGIENE" 2>&1) || rc=$?
  rc=${rc:-0}

  [ "$rc" -eq 0 ] || fail "live worker alone should exit 0 when healthy, got $rc: $out"
  assert_not_contains "$out" "PHANTOM RECORD: live-task" "live worker must not be reported as phantom"
  pass "a genuinely live worker is NOT reported as phantom"
}

test_idle_capacity_reported() {
  local env wt meta out rc
  env=$(make_test_env idle-capacity)
  wt="$env/worktree-live"
  fm_git_init_commit "$wt"

  # Declare capacity for project
  printf 'testproj 4\n' > "$env/config/project-capacity"

  meta="$env/state/live-task.meta"
  fm_write_meta "$meta" \
    "window=firstmate:live-window" \
    "worktree=$wt" \
    "project=$env/projects/testproj" \
    "backend=tmux" \
    "kind=ship" \
    "mode=local-only"

  fakebin=$(fm_fakebin "$env")
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$fakebin/tmux"

  out=$(PATH="$fakebin:$PATH" \
    FM_ROOT_OVERRIDE="$env" \
    FM_HOME="$env" \
    FM_CONFIG_OVERRIDE="$env/config" \
    FM_STATE_OVERRIDE="$env/state" \
    FM_PROJECT_NAME="testproj" \
    HERDR_CAP_CHECK_SKIP=1 \
    bash "$LANE_HYGIENE" 2>&1) || rc=$?
  rc=${rc:-0}

  assert_contains "$out" "1/4" "idle capacity must report running/total (1/4)"
  assert_contains "$out" "idle" "idle capacity must be mentioned"
  pass "idle capacity reported when running < total"
}

test_healthy_host_exits_0_and_announces() {
  local env out rc
  env=$(make_test_env healthy-host)

  out=$(FM_ROOT_OVERRIDE="$env" \
    FM_HOME="$env" \
    FM_CONFIG_OVERRIDE="$env/config" \
    FM_STATE_OVERRIDE="$env/state" \
    HERDR_CAP_CHECK_SKIP=1 \
    bash "$LANE_HYGIENE" 2>&1) || rc=$?
  rc=${rc:-0}

  [ "$rc" -eq 0 ] || fail "healthy host must exit 0, got $rc: $out"
  assert_contains "$out" "VERDICT: HEALTHY" "verdict must be announced when healthy"
  pass "healthy host -> exit 0 and still prints the verdict"
}

test_stale_watcher_detected() {
  local env out rc
  env=$(make_test_env stale-watcher)

  # Mock fm-guard.sh reporting stale watcher alarm
  cat > "$env/bin/fm-guard.sh" <<'SH'
#!/usr/bin/env bash
echo "WARNING: watcher still down (last beat: 1200s ago, grace 300s)" >&2
exit 0
SH
  chmod +x "$env/bin/fm-guard.sh"

  out=$(FM_ROOT_OVERRIDE="$env" \
    FM_HOME="$env" \
    FM_CONFIG_OVERRIDE="$env/config" \
    FM_STATE_OVERRIDE="$env/state" \
    HERDR_CAP_CHECK_SKIP=1 \
    bash "$LANE_HYGIENE" 2>&1) || rc=$?
  rc=${rc:-0}

  [ "$rc" -ne 0 ] || fail "stale watcher must cause non-zero exit, got 0: $out"
  assert_contains "$out" "watcher still down" "watcher warning must be surfaced verbatim"
  pass "stale watcher warning surfaced and causes non-zero exit"
}

test_broken_gate_detected() {
  local env fakebin out rc
  env=$(make_test_env broken-gate)

  fakebin=$(fm_fakebin "$env")
  # Mock herdr workspace list as succeeding (herdr is up)
  cat > "$fakebin/herdr" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "workspace" ] && [ "${2:-}" = "list" ]; then
  echo '{"id":"cli:workspace:list","result":{"workspaces":[{"workspace_id":"wA"}]}}'
  exit 0
fi
exit 0
SH
  chmod +x "$fakebin/herdr"

  # Mock herdr-subagent-cap-check as reporting exit 3 (server unavailable)
  cat > "$fakebin/herdr-subagent-cap-check" <<'SH'
#!/usr/bin/env bash
echo "SUBAGENT-CAP: herdr pane list failed (server unavailable)" >&2
exit 3
SH
  chmod +x "$fakebin/herdr-subagent-cap-check"

  out=$(PATH="$fakebin:$PATH" \
    FM_ROOT_OVERRIDE="$env" \
    FM_HOME="$env" \
    FM_CONFIG_OVERRIDE="$env/config" \
    FM_STATE_OVERRIDE="$env/state" \
    HERDR_CAP_CHECK_BIN="$fakebin/herdr-subagent-cap-check" \
    bash "$LANE_HYGIENE" 2>&1) || rc=$?
  rc=${rc:-0}

  [ "$rc" -ne 0 ] || fail "broken gate must cause non-zero exit, got 0: $out"
  assert_contains "$out" "BROKEN GATE" "broken gate must be announced"
  assert_contains "$out" "server unavailable" "gate failure must be surfaced"
  pass "broken gate detected (helper fails while backing service up)"
}

test_fail_closed_on_error() {
  local env out rc
  env=$(make_test_env fail-closed)

  # Corrupt project-capacity file (invalid syntax: missing capacity integer)
  printf 'invalid line without integer\n' > "$env/config/project-capacity"

  out=$(FM_ROOT_OVERRIDE="$env" \
    FM_HOME="$env" \
    FM_CONFIG_OVERRIDE="$env/config" \
    FM_STATE_OVERRIDE="$env/state" \
    HERDR_CAP_CHECK_SKIP=1 \
    bash "$LANE_HYGIENE" 2>&1) || rc=$?
  rc=${rc:-0}

  [ "$rc" -ne 0 ] || fail "corrupt configuration must cause non-zero exit, got 0: $out"
  assert_contains "$out" "ERROR" "error during inspection must be surfaced"
  pass "fail-closed: error during inspection is a finding, never a silent pass"
}

test_live_agents_counted_not_meta_records() {
  local env wt meta out rc fakebin
  env=$(make_test_env live-count-herdr)

  # Project capacity = 4
  printf 'testproj 4\n' > "$env/config/project-capacity"

  # 3 meta records
  for i in 1 2 3; do
    wt="$env/worktree-$i"
    fm_git_init_commit "$wt"
    meta="$env/state/task-$i.meta"
    fm_write_meta "$meta" \
      "window=default:wA:p$i" \
      "worktree=$wt" \
      "project=$env/projects/testproj" \
      "backend=herdr" \
      "kind=ship" \
      "mode=local-only"
  done

  # Fake herdr: 1 working pane, 1 idle pane, 1 done pane
  fakebin=$(fm_fakebin "$env")
  cat > "$fakebin/herdr" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "pane" ] && [ "${2:-}" = "list" ]; then
  cat <<'JSON'
{"id":"cli:pane:list","result":{"panes":[{"pane_id":"wA:p1","agent":"agy","agent_status":"working"},{"pane_id":"wA:p2","agent":"pi","agent_status":"idle"},{"pane_id":"wA:p3","agent":"codex","agent_status":"done"}]},"type":"pane_list"}
JSON
  exit 0
fi
exit 0
SH
  chmod +x "$fakebin/herdr"

  out=$(PATH="$fakebin:$PATH" \
    FM_ROOT_OVERRIDE="$env" \
    FM_HOME="$env" \
    FM_CONFIG_OVERRIDE="$env/config" \
    FM_STATE_OVERRIDE="$env/state" \
    FM_PROJECT_NAME="testproj" \
    HERDR_CAP_CHECK_SKIP=1 \
    bash "$LANE_HYGIENE" 2>&1) || rc=$?
  rc=${rc:-0}

  # With 3 meta records but only 1 working pane in herdr pane list, running count must be 1/4, not 3/4
  assert_contains "$out" "running/total = 1/4" "running count must reflect live working agent count (1), not meta records (3)"
  assert_contains "$out" "3 meta record(s)" "in-flight task records must be listed as a separate number"
  pass "live agents counted from herdr pane list, not meta records (1 working of 3 meta records)"
}

test_phantom_record_detected
test_live_worker_not_phantom
test_idle_capacity_reported
test_healthy_host_exits_0_and_announces
test_stale_watcher_detected
test_broken_gate_detected
test_fail_closed_on_error
test_live_agents_counted_not_meta_records
