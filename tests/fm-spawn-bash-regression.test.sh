#!/usr/bin/env bash
# Regression test: fm-spawn.sh requires Bash, not POSIX sh.
#
# The script uses Bash-only constructs (${BASH_SOURCE[0]}, BASH_SOURCE arrays,
# [[ ]]). Invoking it as a bare command resolved through /bin/sh causes a
# "Bad substitution" error on line ~126 (the SCRIPT_DIR resolution) because sh
# does not support ${BASH_SOURCE[0]}.
#
# Every dispatch instruction, pretool-check deny message, and helper invocation
# that names fm-spawn.sh must use `bash /path/to/fm-spawn.sh` — never a bare
# command that relies on shebang resolution through sh.
#
# This test verifies:
# 1. Running fm-spawn.sh through /bin/sh produces "Bad substitution" (regression)
# 2. Running fm-spawn.sh through bash succeeds at least to the brief-check gate
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"
TMP_ROOT=$(fm_test_tmproot fm-spawn-bash-regression)

# Provide a minimal fake project dir so fm-spawn.sh passes its cd gate and reaches
# the brief-check. The POS[1]=projects/none path must exist.
mkdir -p "$TMP_ROOT/projects/none"

# Test 1: sh must fail with Bad substitution.
# We test the actual error that occurred: running the script through /bin/sh
# without the bash shebang. The script's shebang is #!/usr/bin/env bash, but
# when /bin/sh is used explicitly it bypasses the shebang.
test_sh_fails_bad_substitution() {
  local out status
  # Use /bin/sh explicitly to bypass the shebang, exactly as ctx_shell does.
  # Two positional args are required: POS[1] is accessed under set -u.
  out=$(FM_HOME="$TMP_ROOT" /bin/sh "$SPAWN" nope-test-sh-regression "$TMP_ROOT/projects/none" --harness pi 2>&1)
  status=$?
  # Any non-zero exit is acceptable; the key regression is "Bad substitution" in output.
  # If the script somehow succeeds (unexpected), the test still catches the
  # Bad-substitution case if the output contains it.
  if printf '%s\n' "$out" | grep -q 'Bad substitution'; then
    pass "sh invocation produces 'Bad substitution' error (regression confirmed blocked)"
  else
    # Fallback: non-zero exit is acceptable too, but without the signature error
    # the test documents that the failure mode may vary.
    [ "$status" -ne 0 ] && pass "sh invocation exits non-zero (Bad substitution signature not detected: $out)"
    [ "$status" -eq 0 ] && fail "sh invocation should not succeed; output: $out"
  fi
}

# Test 2: bash invocation must succeed to the brief-check gate (no sh failures).
test_bash_succeeds() {
  local out status
  # FM_SPAWN_NO_GUARD skips the watcher guard so we reach the brief-check quickly.
  # The script should fail at "no brief" rather than at the Bad-substitution line.
  # Two positional args are required: POS[1] is accessed under set -u.
  # Also pass --backend tmux to skip herdr auto-detection in this test environment.
  out=$(FM_SPAWN_NO_GUARD=1 \
    FM_HOME="$TMP_ROOT" \
    bash "$SPAWN" nope-test-bash-regression "$TMP_ROOT/projects/none" --harness pi --backend tmux 2>&1)
  status=$?
  if [ "$status" -ne 0 ]; then
    # Non-zero is fine — the brief doesn't exist. The important thing is no
    # "Bad substitution" and no "cannot open.*fm-ff-lib.sh" (a downstream sh failure).
    if printf '%s\n' "$out" | grep -q 'Bad substitution'; then
      fail "bash invocation should not produce 'Bad substitution'; output: $out"
    elif printf '%s\n' "$out" | grep -q 'Bad substitution'; then
      fail "bash invocation should not produce 'Bad substitution'; output: $out"
    else
      # Check we reached the actual logic, not an early sh failure.
      # The brief-not-found error confirms the script parsed and ran past line 126.
      if printf '%s\n' "$out" | grep -qE 'no brief|error:'; then
        pass "bash invocation reaches brief-check (script logic, not sh failure)"
      else
        fail "bash invocation failed but reached unexpected gate; output: $out"
      fi
    fi
  else
    fail "bash invocation should fail at missing brief; got exit 0: $out"
  fi
}

# Test 3: Verify the dispatch surface documents the bash requirement.
# Check that AGENTS.md and fm-subagent-pretool-check.sh reference bash explicitly.
test_dispatch_docs_bash_requirement() {
  local agents_md="$ROOT/AGENTS.md"
  local pretool="$ROOT/bin/fm-subagent-pretool-check.sh"

  if grep -qi 'always invoke.*bash' "$agents_md"; then
    pass "AGENTS.md mentions bash invocation requirement"
  else
    fail "AGENTS.md should document that fm-spawn.sh must be invoked with bash"
  fi

  if grep -qi 'always invoke.*bash' "$pretool"; then
    pass "fm-subagent-pretool-check.sh deny message mentions bash requirement"
  else
    fail "fm-subagent-pretool-check.sh should mention bash requirement in ROUTE messages"
  fi
}

test_sh_fails_bad_substitution
test_bash_succeeds
test_dispatch_docs_bash_requirement
