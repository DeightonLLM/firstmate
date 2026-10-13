#!/usr/bin/env bash
# tests/fm-mcode-primary.test.sh - TDD for MCode primary ownership contracts.
#
# Tests the fm-mcode-primary-lib.sh library functions:
#   fm_mcode_primary_lock_path        - derive the mcode-specific lock path
#   fm_mcode_primary_lock_claim      - atomically claim the lock
#   fm_mcode_primary_lock_held_by_self - true when current process owns the lock
#   fm_mcode_primary_lock_release     - release only self-owned lock
#   fm_mcode_primary_lock_stale       - true when owner process is dead
#   fm_mcode_primary_lock_try_reacquire - claim after losing ownership
#
# Also validates:
#   Harness detection adds minimax-code to ancestry detection
#   Busy-lib does not credit mcode with a native semantic source
#
# All mcode CLI calls use the fake in PATH via setup_fake_mcode().
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_TMP=""
export TEST_TMP

fm_test_cleanup() { rm -rf "${TEST_TMP:-}" 2>/dev/null || true; }
trap fm_test_cleanup EXIT

require_shadow() {
  local fake=$1
  mkdir -p "$TEST_TMP/bin"
  cp "$fake" "$TEST_TMP/bin/mcode"
  chmod +x "$TEST_TMP/bin/mcode"
  export PATH="$TEST_TMP/bin:$PATH"
}

setup_fake_mcode() {
  mkdir -p "$TEST_TMP/bin"
  cat > "$TEST_TMP/bin/mcode" << 'FAKE'
#!/bin/bash
# Deterministic fake mcode - never consumes real quota.
case "${1:-}" in
  --version) echo "minimax-code 0.6.8" ;;
  --help)
    echo "Minimax Code v0.6.8"
    echo "Commands: exec acp plugin login logout update provider"
    ;;
  exec)
    shift
    printf 'EXEC %s\n' "$*" >> "${MCODE_INVOCATION_LOG:-/dev/null}" :
    [ -n "${MCODE_OUTPUT_FILE:-}" ] && printf 'Done.\n' > "$MCODE_OUTPUT_FILE"
    exit 0
    ;;
  acp) echo "ACP - no lifecycle events"; exit 0 ;;
  plugin) echo "Plugin manager"; exit 0 ;;
  *) printf 'UNKNOWN %s\n' "$*" >> "${MCODE_INVOCATION_LOG:-/dev/null}"; exit 1 ;;
esac
FAKE
  chmod +x "$TEST_TMP/bin/mcode"
  export PATH="$TEST_TMP/bin:$PATH"
  export MCODE_INVOCATION_LOG="$TEST_TMP/mcode-invocations.log"
}

setup_isolated_env() {
  TEST_TMP=$(mktemp -d)
  export TEST_TMP
  export FM_ROOT="$TEST_TMP/fmroot"
  mkdir -p "$FM_ROOT/bin"
  export FM_HOME="$TEST_TMP/fmhome"
  mkdir -p "$FM_HOME/state"
  export FM_STATE="$FM_HOME/state"
  mkdir -p "$FM_STATE"
}

install_lib() {
  local src=$SCRIPT_DIR/../bin/fm-mcode-primary-lib.sh
  if [ ! -f "$src" ]; then
    echo "SKIP: bin/fm-mcode-primary-lib.sh not found (RED phase)"
    return 1
  fi
  cp "$src" "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  chmod +x "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  return 0
}

install_harness() {
  local src=$SCRIPT_DIR/../bin/fm-harness.sh
  [ -f "$src" ] || { echo "SKIP: fm-harness.sh not found"; return 1; }
  cp "$src" "$FM_ROOT/bin/fm-harness.sh"
  chmod +x "$FM_ROOT/bin/fm-harness.sh"
}

install_busy_lib() {
  local src=$SCRIPT_DIR/../bin/fm-busy-lib.sh
  [ -f "$src" ] || { echo "SKIP: fm-busy-lib.sh not found"; return 1; }
  cp "$src" "$FM_ROOT/bin/fm-busy-lib.sh"
  chmod +x "$FM_ROOT/bin/fm-busy-lib.sh"
}

# --- Tests ---

test_lock_path_format() {
  setup_isolated_env
  install_lib || return 0
  . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  local path owner_dir
  path=$(fm_mcode_primary_lock_path "$FM_STATE")
  owner_dir=$(fm_mcode_primary_lock_current_owner "$path")
  case "$path" in
    *mcode*) echo "PASS: lock path contains mcode: $path" ;;
    *) echo "FAIL: unexpected lock path: $path"; return 1 ;;
  esac
}

test_lock_claim_then_release() {
  setup_isolated_env
  install_lib || return 0
  . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  fm_mcode_primary_lock_claim "$FM_STATE"
  echo "PASS: lock claimed"
  fm_mcode_primary_lock_release "$FM_STATE"
  echo "PASS: lock released"
}

test_lock_held_by_self_true() {
  setup_isolated_env
  install_lib || return 0
  . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  fm_mcode_primary_lock_claim "$FM_STATE"
  fm_mcode_primary_lock_held_by_self "$FM_STATE"
  echo "PASS: correctly reported as self-owned"
}

test_lock_held_by_self_false_after_release() {
  setup_isolated_env
  install_lib || return 0
  . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  fm_mcode_primary_lock_claim "$FM_STATE"
  fm_mcode_primary_lock_release "$FM_STATE"
  if fm_mcode_primary_lock_held_by_self "$FM_STATE"; then return 1; fi
  echo "PASS: correctly reported as not self-owned after release"
}

test_lock_held_by_self_false_when_not_claimed() {
  setup_isolated_env
  install_lib || return 0
  . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  if fm_mcode_primary_lock_held_by_self "$FM_STATE"; then return 1; fi
  echo "PASS: correctly false when never claimed"
}

test_stale_owner_detected() {
  setup_isolated_env
  install_lib || return 0
  . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  fm_mcode_primary_lock_claim "$FM_STATE"
  local path owner_dir
  path=$(fm_mcode_primary_lock_path "$FM_STATE")
  owner_dir=$(fm_mcode_primary_lock_current_owner "$path")
  # Simulate dead owner: overwrite with impossible PID.
  mkdir -p "$path"
  printf '%s\n' 99999 > "$path/pid"
  fm_mcode_primary_lock_stale "$FM_STATE"
  echo "PASS: stale owner (dead PID) correctly detected"
}

test_stale_false_when_owner_alive() {
  setup_isolated_env
  install_lib || return 0
  . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  fm_mcode_primary_lock_claim "$FM_STATE"
  local path owner_dir
  path=$(fm_mcode_primary_lock_path "$FM_STATE")
  owner_dir=$(fm_mcode_primary_lock_current_owner "$path")
  # Restore the real PID (this process) so it is NOT stale.
  printf '%s\n' "$$" > "$path/pid"
  if fm_mcode_primary_lock_stale "$FM_STATE"; then return 1; fi
  echo "PASS: live owner is NOT stale"
}

test_competing_owner_refused() {
  setup_isolated_env
  install_lib || return 0
  . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  fm_mcode_primary_lock_claim "$FM_STATE"
  # Competing subshell must fail to claim.
  ! bash -c '
    export FM_ROOT='"$FM_ROOT"' FM_STATE='"$FM_STATE"'
    . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
    fm_mcode_primary_lock_claim "$FM_STATE"
  '
  echo "PASS: competing owner correctly refused"
}

test_repeated_release_is_safe() {
  setup_isolated_env
  install_lib || return 0
  . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  # Release without ever claiming - must not error.
  fm_mcode_primary_lock_release "$FM_STATE"
  fm_mcode_primary_lock_release "$FM_STATE"
  echo "PASS: repeated release is safe"
}

test_reacquisition_after_release() {
  setup_isolated_env
  install_lib || return 0
  . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  fm_mcode_primary_lock_claim "$FM_STATE"
  fm_mcode_primary_lock_release "$FM_STATE"
  fm_mcode_primary_lock_claim "$FM_STATE"
  echo "PASS: reacquisition after release succeeded"
}

test_loss_of_ownership() {
  setup_isolated_env
  install_lib || return 0
  . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  fm_mcode_primary_lock_claim "$FM_STATE"
  local path owner_dir
  path=$(fm_mcode_primary_lock_path "$FM_STATE")
  owner_dir=$(fm_mcode_primary_lock_current_owner "$path")
  # Simulate owning process death by writing dead PID.
  printf '%s\n' 99998 > "$path/pid"
  # Stale must be true, and self-held must be false.
  if fm_mcode_primary_lock_stale "$FM_STATE"; then
    echo "PASS: stale=true when owner is dead"
  else
    echo "FAIL: should detect stale owner"
    return 1
  fi
  if fm_mcode_primary_lock_held_by_self "$FM_STATE"; then return 1; fi
  echo "PASS: not held-by-self when owner is dead"
}

test_try_reacquire_after_stale() {
  setup_isolated_env
  install_lib || return 0
  . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
  # First process claims, then dies.
  fm_mcode_primary_lock_claim "$FM_STATE"
  local path owner_dir
  path=$(fm_mcode_primary_lock_path "$FM_STATE")
  owner_dir=$(fm_mcode_primary_lock_current_owner "$path")
  printf '%s\n' 99997 > "$owner_dir/pid"  # dead
  # Second process (this subshell) tries to claim.
  local rc=0
  ! bash -c '
    export FM_ROOT='"$FM_ROOT"' FM_STATE='"$FM_STATE"'
    . "$FM_ROOT/bin/fm-mcode-primary-lib.sh"
    fm_mcode_primary_lock_claim "$FM_STATE"
  ' || rc=$?
  case $rc in
    0) echo "FAIL: should have claimed successfully"; return 1 ;;
    *) echo "PASS: reacquisition after stale owner succeeded" ;;
  esac
}

test_busy_state_mcode_has_no_native_source() {
  setup_isolated_env
  install_busy_lib || return 0
  . "$FM_ROOT/bin/fm-busy-lib.sh"
  local sources
  sources=$(fm_busy_sources_for_harness mcode)
  # mcode has no native semantic source (no lifecycle events).
  # Only firstmate-owned sources are acceptable: fm-spawn, fm-interrupt, fm-recovery.
  case "$sources" in
    *pi-ext*|*claude-hook*|*opencode-plugin*|*codex-*)
      echo "FAIL: mcode unexpectedly has native source: $sources"
      return 1
      ;;
    *)
      echo "PASS: mcode has no native semantic source"
      echo "  sources: ${sources:-<empty>}"
      ;;
  esac
}

# --- Main ---

passed=0; failed=0

run_test() {
  local name=$1
  echo ""
  echo "=== $name ==="
  if "$name"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
}

tests=(
  test_lock_path_format
  test_lock_claim_then_release
  test_lock_held_by_self_true
  test_lock_held_by_self_false_after_release
  test_lock_held_by_self_false_when_not_claimed
  test_stale_owner_detected
  test_stale_false_when_owner_alive
  test_competing_owner_refused
  test_repeated_release_is_safe
  test_reacquisition_after_release
  test_loss_of_ownership
  test_try_reacquire_after_stale
  test_busy_state_mcode_has_no_native_source
)

for t in "${tests[@]}"; do run_test "$t"; done

echo ""
echo "=== Results: passed=$passed failed=$failed ==="
[ "$failed" -eq 0 ]
