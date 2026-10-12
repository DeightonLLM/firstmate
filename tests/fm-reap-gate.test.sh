#!/usr/bin/env bash
# Tests for bin/fm-reap-gate.sh - Automatic reap gate contract.
#
# Requirements under test:
# 1. A verified-landed crew is reaped automatically with no operator prompt.
# 2. A crew with unlanded work is preserved and the refusal is logged with its reason.
# 3. A Crisp-R pane/window/tab/workspace is never touched, even if it looks idle.
# 4. An undeterminable landed-work state preserves rather than reaps.
#
# Constraints:
# - Uses bin/fm-teardown.sh as the sole authority for "is it landed".
# - Never passes --force to teardown.
# - Refusal is a correct outcome, logged with task id, decision, and evidence.
# - Real worktrees and git repositories used for assertions.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAP_GATE="$ROOT/bin/fm-reap-gate.sh"
TEARDOWN="$ROOT/bin/fm-teardown.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-reap-gate-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

[ -x "$REAP_GATE" ] || { printf 'FAIL  reap gate script is not executable: %s\n' "$REAP_GATE"; exit 1; }

# Helper to build a real git repository and worktree for a task
setup_task_repo() {
  local case_dir=$1 task_id=$2
  local fakebin="$case_dir/fakebin"
  mkdir -p "$case_dir/state" "$case_dir/config" "$case_dir/data/$task_id" "$fakebin"

  # Mock treehouse return that cleans up worktree dir on success
  cat > "$fakebin/treehouse" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "return" ]; then
  shift
  [ "${1:-}" = "--force" ] && shift
  wt="${1:-}"
  if [ -n "$wt" ] && [ -d "$wt" ]; then
    rm -rf "$wt"
  fi
  exit 0
fi
exit 0
SH

  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
exit 0
SH

  cat > "$fakebin/gh-axi" <<'SH'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "pr list") printf '%s\n' "count: 0 (showing first 0)" "pull_requests[]: []" ; exit 0 ;;
  "pr view") echo "error: pull request not found" >&2 ; exit 1 ;;
esac
exit 0
SH

  cat > "$fakebin/gh" <<'SH'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "pr view") echo "error: pull request not found" >&2 ; exit 1 ;;
esac
exit 0
SH

  chmod +x "$fakebin/treehouse" "$fakebin/tmux" "$fakebin/gh-axi" "$fakebin/gh"

  # Create bare origin repo
  git init -q --bare "$case_dir/origin.git"
  git -C "$case_dir/origin.git" symbolic-ref HEAD refs/heads/main
  # Seed origin with a baseline file
  git clone -q "$case_dir/origin.git" "$case_dir/_seed" 2>/dev/null
  echo "baseline" > "$case_dir/_seed/baseline.txt"
  git -C "$case_dir/_seed" add baseline.txt
  git -C "$case_dir/_seed" -c user.email=t@t -c user.name=t \
    commit -q -m "origin baseline"
  git -C "$case_dir/_seed" push -q origin main
  rm -rf "$case_dir/_seed"

  # Clone as project
  git clone -q "$case_dir/origin.git" "$case_dir/project"
  git -C "$case_dir/project" remote set-head origin main 2>/dev/null || true

  # Add task worktree
  git -C "$case_dir/project" worktree add -q -b "fm/$task_id" "$case_dir/wt" main

  # Fresh beacon for guard
  touch "$case_dir/state/.last-watcher-beat"
}

# -----------------------------------------------------------------------------
# Test 1: Verified-landed crew is reaped automatically with no operator prompt
# -----------------------------------------------------------------------------
test_verified_landed_is_reaped() {
  local case_dir="$TMP_ROOT/test1"
  local task_id="task-landed-1"
  setup_task_repo "$case_dir" "$task_id"

  # Commit real file change in worktree and push to origin main so it is verified landed
  echo "landed content" > "$case_dir/wt/feature.txt"
  git -C "$case_dir/wt" add feature.txt
  git -C "$case_dir/wt" -c user.email=t@t -c user.name=t commit -q -m "landed work"
  git -C "$case_dir/wt" push -q origin "fm/$task_id:main"

  # Write task metadata
  cat > "$case_dir/state/$task_id.meta" <<EOF
window=firstmate:fm-$task_id
endpoint_task_id=$task_id
worktree=$case_dir/wt
project=$case_dir/project
kind=ship
mode=no-mistakes
backend=tmux
spawned_at=$(($(date +%s) - 3600))
EOF

  # Status done
  echo "done: work landed and verified" > "$case_dir/state/$task_id.status"

  # Run reap gate with FM_REAP_AGE_THRESHOLD_SECS=0 so age gate passes immediately
  local log="$case_dir/state/reap.log"
  local out rc=0
  out=$(PATH="$case_dir/fakebin:$PATH" FM_HOME="$case_dir" FM_STATE_OVERRIDE="$case_dir/state" \
        FM_DATA_OVERRIDE="$case_dir/data" FM_CONFIG_OVERRIDE="$case_dir/config" \
        FM_REAP_AGE_THRESHOLD_SECS=0 \
        "$REAP_GATE" "$task_id" "$case_dir/state" 2>&1) || rc=$?

  if [ "$rc" -eq 0 ] && [ ! -f "$case_dir/state/$task_id.meta" ] && [ ! -d "$case_dir/wt" ]; then
    ok "verified-landed crew is reaped automatically without operator prompt"
  else
    bad "verified-landed crew was not reaped (rc=$rc, meta exists: $([ -f "$case_dir/state/$task_id.meta" ] && echo yes || echo no), out: $out)"
  fi

  if [ -f "$log" ] && grep -q "REAP: $task_id" "$log"; then
    ok "verified-landed crew reap was logged"
  else
    bad "verified-landed crew reap was not logged in $log"
  fi
}

# -----------------------------------------------------------------------------
# Test 2: Crew with unlanded work is preserved and the refusal is logged
# -----------------------------------------------------------------------------
test_unlanded_work_is_preserved_and_logged() {
  local case_dir="$TMP_ROOT/test2"
  local task_id="task-unlanded-2"
  setup_task_repo "$case_dir" "$task_id"

  # Commit real file change in worktree that is NOT pushed or in main
  echo "unpushed content" > "$case_dir/wt/unpushed.txt"
  git -C "$case_dir/wt" add unpushed.txt
  git -C "$case_dir/wt" -c user.email=t@t -c user.name=t commit -q -m "unlanded work"

  # Write task metadata
  cat > "$case_dir/state/$task_id.meta" <<EOF
window=firstmate:fm-$task_id
endpoint_task_id=$task_id
worktree=$case_dir/wt
project=$case_dir/project
kind=ship
mode=no-mistakes
backend=tmux
spawned_at=$(($(date +%s) - 3600))
EOF

  # Status done
  echo "done: finished local work" > "$case_dir/state/$task_id.status"

  # Run reap gate with FM_REAP_AGE_THRESHOLD_SECS=0
  local log="$case_dir/state/reap.log"
  local out rc=0
  out=$(PATH="$case_dir/fakebin:$PATH" FM_HOME="$case_dir" FM_STATE_OVERRIDE="$case_dir/state" \
        FM_DATA_OVERRIDE="$case_dir/data" FM_CONFIG_OVERRIDE="$case_dir/config" \
        FM_REAP_AGE_THRESHOLD_SECS=0 \
        "$REAP_GATE" "$task_id" "$case_dir/state" 2>&1) || rc=$?

  if [ -f "$case_dir/state/$task_id.meta" ] && [ -d "$case_dir/wt" ]; then
    ok "crew with unlanded work is preserved"
  else
    bad "crew with unlanded work was destroyed! (meta exists: $([ -f "$case_dir/state/$task_id.meta" ] && echo yes || echo no))"
  fi

  if [ -f "$log" ] && grep -q "REFUSE: $task_id" "$log"; then
    ok "refusal of unlanded crew was logged with reason"
  else
    bad "refusal of unlanded crew was not logged in $log (log content: $(cat "$log" 2>/dev/null || echo '<none>'))"
  fi
}

# -----------------------------------------------------------------------------
# Test 3: Crisp-R pane/window/tab/workspace is never touched even if idle
# -----------------------------------------------------------------------------
test_crisp_r_pane_is_never_touched() {
  local case_dir="$TMP_ROOT/test3"
  local task_id="task-crisp-3"
  setup_task_repo "$case_dir" "$task_id"

  # Commit real landed work
  echo "landed content" > "$case_dir/wt/crisp.txt"
  git -C "$case_dir/wt" add crisp.txt
  git -C "$case_dir/wt" -c user.email=t@t -c user.name=t commit -q -m "landed work"
  git -C "$case_dir/wt" push -q origin "fm/$task_id:main"

  # Target is in a Crisp-R window
  cat > "$case_dir/state/$task_id.meta" <<EOF
window=Crisp-R — captain session:fm-$task_id
endpoint_task_id=$task_id
worktree=$case_dir/wt
project=$case_dir/project
kind=ship
mode=no-mistakes
backend=tmux
spawned_at=$(($(date +%s) - 3600))
EOF

  echo "done: work done" > "$case_dir/state/$task_id.status"

  local log="$case_dir/state/reap.log"
  local out rc=0
  out=$(PATH="$case_dir/fakebin:$PATH" FM_HOME="$case_dir" FM_STATE_OVERRIDE="$case_dir/state" \
        FM_DATA_OVERRIDE="$case_dir/data" FM_CONFIG_OVERRIDE="$case_dir/config" \
        FM_REAP_AGE_THRESHOLD_SECS=0 \
        "$REAP_GATE" "$task_id" "$case_dir/state" 2>&1) || rc=$?

  if [ -f "$case_dir/state/$task_id.meta" ] && [ -d "$case_dir/wt" ]; then
    ok "Crisp-R window is preserved and never touched"
  else
    bad "Crisp-R window was destroyed!"
  fi

  if [ -f "$log" ] && grep -qi "Crisp-R" "$log"; then
    ok "Crisp-R protection refusal was logged"
  else
    bad "Crisp-R protection was not logged in $log"
  fi
}

# -----------------------------------------------------------------------------
# Test 4: Undeterminable landed-work state preserves rather than reaps
# -----------------------------------------------------------------------------
test_undeterminable_state_preserves() {
  local case_dir="$TMP_ROOT/test4"
  local task_id="task-undetermined-4"
  setup_task_repo "$case_dir" "$task_id"

  # Corrupt the git index of the worktree so git status / rev-parse errors
  local git_index
  git_index=$(git -C "$case_dir/wt" rev-parse --git-path index)
  echo "corrupt index content" > "$git_index"

  cat > "$case_dir/state/$task_id.meta" <<EOF
window=firstmate:fm-$task_id
endpoint_task_id=$task_id
worktree=$case_dir/wt
project=$case_dir/project
kind=ship
mode=no-mistakes
backend=tmux
spawned_at=$(($(date +%s) - 3600))
EOF

  echo "done: work done" > "$case_dir/state/$task_id.status"

  local log="$case_dir/state/reap.log"
  local out rc=0
  out=$(PATH="$case_dir/fakebin:$PATH" FM_HOME="$case_dir" FM_STATE_OVERRIDE="$case_dir/state" \
        FM_DATA_OVERRIDE="$case_dir/data" FM_CONFIG_OVERRIDE="$case_dir/config" \
        FM_REAP_AGE_THRESHOLD_SECS=0 \
        "$REAP_GATE" "$task_id" "$case_dir/state" 2>&1) || rc=$?

  if [ -f "$case_dir/state/$task_id.meta" ] && [ -d "$case_dir/wt" ]; then
    ok "undeterminable landed-work state preserves crew"
  else
    bad "undeterminable landed-work state was destroyed instead of preserved!"
  fi

  if [ -f "$log" ] && grep -q "REFUSE: $task_id" "$log"; then
    ok "undeterminable state refusal was logged"
  else
    bad "undeterminable state refusal was not logged in $log"
  fi
}

# -----------------------------------------------------------------------------
# Test 5: Session start sweep reaps landed and preserves unlanded across fleet
# -----------------------------------------------------------------------------
test_sweep_mode() {
  local case_dir="$TMP_ROOT/test5"
  local task_landed="task-sweep-landed"
  local task_unlanded="task-sweep-unlanded"
  setup_task_repo "$case_dir" "$task_landed"
  
  # Set up second task
  git -C "$case_dir/project" worktree add -q -b "fm/$task_unlanded" "$case_dir/wt2" main

  # task_landed has landed work
  echo "landed" > "$case_dir/wt/landed.txt"
  git -C "$case_dir/wt" add landed.txt
  git -C "$case_dir/wt" -c user.email=t@t -c user.name=t commit -q -m "landed"
  git -C "$case_dir/wt" push -q origin "fm/$task_landed:main"

  cat > "$case_dir/state/$task_landed.meta" <<EOF
window=firstmate:fm-$task_landed
endpoint_task_id=$task_landed
worktree=$case_dir/wt
project=$case_dir/project
kind=ship
mode=no-mistakes
backend=tmux
spawned_at=$(($(date +%s) - 3600))
EOF
  echo "done: landed" > "$case_dir/state/$task_landed.status"

  # task_unlanded has unpushed work
  echo "unpushed" > "$case_dir/wt2/unpushed.txt"
  git -C "$case_dir/wt2" add unpushed.txt
  git -C "$case_dir/wt2" -c user.email=t@t -c user.name=t commit -q -m "unpushed"

  cat > "$case_dir/state/$task_unlanded.meta" <<EOF
window=firstmate:fm-$task_unlanded
endpoint_task_id=$task_unlanded
worktree=$case_dir/wt2
project=$case_dir/project
kind=ship
mode=no-mistakes
backend=tmux
spawned_at=$(($(date +%s) - 3600))
EOF
  echo "done: unpushed" > "$case_dir/state/$task_unlanded.status"

  local log="$case_dir/state/reap.log"
  local out rc=0
  out=$(PATH="$case_dir/fakebin:$PATH" FM_HOME="$case_dir" FM_STATE_OVERRIDE="$case_dir/state" \
        FM_DATA_OVERRIDE="$case_dir/data" FM_CONFIG_OVERRIDE="$case_dir/config" \
        FM_REAP_AGE_THRESHOLD_SECS=0 \
        "$REAP_GATE" --sweep "$case_dir/state" 2>&1) || rc=$?

  if [ ! -f "$case_dir/state/$task_landed.meta" ] && [ -f "$case_dir/state/$task_unlanded.meta" ]; then
    ok "--sweep reaped landed task and preserved unlanded task"
  else
    bad "--sweep failed: landed meta=$([ -f "$case_dir/state/$task_landed.meta" ] && echo exists || echo gone), unlanded meta=$([ -f "$case_dir/state/$task_unlanded.meta" ] && echo exists || echo gone)"
  fi
}

test_verified_landed_is_reaped
test_unlanded_work_is_preserved_and_logged
test_crisp_r_pane_is_never_touched
test_undeterminable_state_preserves
test_sweep_mode

printf '\nPASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
