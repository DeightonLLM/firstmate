#!/usr/bin/env bash
# tests/fm-todo-prefix-check.test.sh - contract tests for the canonical todo prefix.
#
# Contract under test (owner: docs/todo-prefix-canonical-format.md):
#   Board row prefix: [<harness>·<ModelAbbrev> <effort> @<Host>]
#   Lane key:         <harness>-<model>-<host>-<task>
#
# The checker validates and reports. It never edits or fixes its input, and it
# names the offending input on stderr when it rejects one.
#
# Every case runs, each case prints a PASS/FAIL line, and the suite exits
# non-zero when any case failed.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/fm-todo-prefix-check.sh"
TMP_ROOT=$(fm_test_tmproot fm-todo-prefix-check-tests)
# fm_test_tmproot installs its cleanup trap inside the command substitution, so
# the temp root is gone by the time this line runs. Recreate it and write the
# fixtures into it.
mkdir -p "$TMP_ROOT"

# The legacy board rows carry an em dash between the task and the state.
# It is built from a unicode escape so this file holds no em dash bytes.
EMDASH=$'\u2014'

PASS_COUNT=0
FAIL_COUNT=0

# --- helpers ---------------------------------------------------------------

# t_fail <reason>: report the detail of a failing case and return non-zero.
# It does not abort the suite, so every case still runs.
t_fail() {
  printf '  detail: %s\n' "$1" >&2
  return 1
}

# expect_exit <expected> <actual> <label>
expect_exit() {
  [ "$2" = "$1" ] || { t_fail "$3: expected exit $1, got $2"; return 1; }
  return 0
}

# expect_contains <output> <needle> <label>
expect_contains() {
  printf '%s\n' "$1" | grep -qF -- "$2" \
    || { t_fail "$3: the output does not contain '$2'"; return 1; }
  return 0
}

# run_check <args...>: run the checker and capture its output and exit code.
run_check() {
  RUN_OUT=$(bash "$CHECK" "$@" 2>&1)
  RUN_RC=$?
  return 0
}

# lint_check: run shellcheck on the script under test and fail if it finds issues.
lint_check() {
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning "$CHECK" >/dev/null 2>&1 \
      || { t_fail "shellcheck found issues in $CHECK"; return 1; }
  fi
  return 0
}

# --- cases -----------------------------------------------------------------

test_script_exists_and_executable() {
  [ -f "$CHECK" ] || { t_fail "$CHECK does not exist"; return 1; }
  [ -x "$CHECK" ] || { t_fail "$CHECK is not executable"; return 1; }
  lint_check || return 1
  return 0
}

test_help_exits_zero_and_prints_usage() {
  run_check --help
  expect_exit 0 "$RUN_RC" '--help must exit 0' || return 1
  expect_contains "$RUN_OUT" 'Usage:' '--help must print usage' || return 1
  return 0
}

test_valid_board_row_passes() {
  run_check "[mcode·m3.1f m @brandon] Reconcile worker results ${EMDASH} running"
  expect_exit 0 "$RUN_RC" 'a canonical board row must pass' || return 1
  return 0
}

test_valid_lane_key_passes() {
  run_check --lane-key 'pi-luna6-brandon-theme-whoosh'
  expect_exit 0 "$RUN_RC" 'a canonical lane key must pass' || return 1
  return 0
}

test_stdin_valid_rows_pass() {
  local file="$TMP_ROOT/valid-rows.txt" out rc
  {
    printf '[mcode·m3.1f m @brandon] Reconcile worker results %s running\n' "$EMDASH"
    printf '[pi·luna6 high @hd2stack] Repair the comms route %s queued\n' "$EMDASH"
    printf '[agy·gem38f l @elevate] Check the widget panel %s blocked\n' "$EMDASH"
  } > "$file"
  out=$(bash "$CHECK" --stdin < "$file" 2>&1); rc=$?
  expect_exit 0 "$rc" 'a file of valid rows must pass in --stdin mode' || return 1
  return 0
}

test_legacy_owner_role_row_rejected() {
  run_check "[mcode·luna6 m @brandon | worker] Implement scoped fixture ${EMDASH} queued"
  expect_exit 1 "$RUN_RC" 'the legacy owner-role row must be rejected' || return 1
  expect_contains "$RUN_OUT" 'owner-role' 'the rejection must name the owner-role segment' || return 1
  expect_contains "$RUN_OUT" '[<harness>·<ModelAbbrev> <effort> @<Host>]' \
    'the rejection must name the expected canonical shape' || return 1
  return 0
}

test_legacy_owner_host_row_rejected() {
  run_check "[controller @ brandon] reconcile evidence ${EMDASH} running"
  expect_exit 1 "$RUN_RC" 'the legacy [owner @ host] row must be rejected' || return 1
  expect_contains "$RUN_OUT" '[<harness>·<ModelAbbrev> <effort> @<Host>]' \
    'the rejection must name the expected canonical shape' || return 1
  return 0
}

test_legacy_model_surface_row_rejected() {
  run_check "[m2.7h @ brandon] widget fix ${EMDASH} working"
  expect_exit 1 "$RUN_RC" 'the legacy [model @ surface] row must be rejected' || return 1
  expect_contains "$RUN_OUT" '[<harness>·<ModelAbbrev> <effort> @<Host>]' \
    'the rejection must name the expected canonical shape' || return 1
  return 0
}

test_lane_key_missing_harness_rejected() {
  run_check --lane-key 'luna6-brandon-theme'
  expect_exit 1 "$RUN_RC" 'a lane key without a harness segment must be rejected' || return 1
  expect_contains "$RUN_OUT" 'harness' 'the rejection must name the harness segment' || return 1
  expect_contains "$RUN_OUT" '<harness>-<model>-<host>-<task>' \
    'the rejection must name the expected lane-key shape' || return 1
  return 0
}

test_registry_model_disagreement_rejected() {
  local file="$TMP_ROOT/registry-disagree.tsv" out rc
  printf '# run_id\tlane_key\tmodel\tsurface\ttask\tstate\toutput\n' > "$file"
  printf 'abc123de-f123-4567-8901-abcdef123456\tpi-luna6-brandon-theme\tluna6\tbrandon\ttheme\trunning\tout.md\n' >> "$file"
  printf 'abc123de-f234-5678-9012-bcdef1234567\tpi-m2.7-brandon-review\tgem38f\tbrandon\treview\trunning\tout.md\n' >> "$file"
  out=$(bash "$CHECK" --registry "$file" 2>&1); rc=$?
  expect_exit 1 "$rc" 'a registry row whose lane_key disagrees with its model column must be rejected' || return 1
  expect_contains "$out" 'disagrees' 'the rejection must explain the disagreement' || return 1
  expect_contains "$out" 'm2.7' 'the rejection must name the disagreeing model' || return 1
  return 0
}

test_self_check_missing_alias_exits_two() {
  local file="$TMP_ROOT/dispatch-gap.json" out rc
  printf '{"default":{"model":"minimax/MiniMax-M4.0-turbo"}}\n' > "$file"
  out=$(bash "$CHECK" --self-check "$file" 2>&1); rc=$?
  expect_exit 2 "$rc" 'a configured MiniMax model without an alias must exit 2' || return 1
  expect_contains "$out" 'm4.0' 'the failure must name the derived alias' || return 1
  return 0
}

test_self_check_all_models_aliased_passes() {
  local file="$TMP_ROOT/dispatch-ok.json" out rc
  printf '{"default":{"model":"minimax/MiniMax-M2.7-highspeed"}}\n' > "$file"
  printf '{"rules":[{"use":{"model":"minimax/MiniMax-M3.1-Flash"}}]}\n' >> "$file"
  out=$(bash "$CHECK" --self-check "$file" 2>&1); rc=$?
  expect_exit 0 "$rc" 'a dispatch config whose models all have aliases must pass' || return 1
  return 0
}

test_registry_valid_rows_pass() {
  local file="$TMP_ROOT/registry-valid.tsv" out rc
  printf '# run_id\tlane_key\tmodel\tsurface\ttask\tstate\toutput\n' > "$file"
  printf 'abc123de-f123-4567-8901-abcdef123456\tpi-luna6-brandon-theme\tluna6\tbrandon\ttheme\trunning\tout.md\n' >> "$file"
  printf 'abc123de-f234-5678-9012-bcdef1234567\tmcode-m3.1f-hd2stack-review\tm3.1f\thd2stack\treview\trunning\tout.md\n' >> "$file"
  out=$(bash "$CHECK" --registry "$file" 2>&1); rc=$?
  expect_exit 0 "$rc" 'a registry of canonical rows must pass' || return 1
  return 0
}

test_invalid_input_exits_one() {
  run_check '[not a board row'
  expect_exit 1 "$RUN_RC" 'an invalid input must exit 1' || return 1
  expect_contains "$RUN_OUT" 'invalid board row' 'the failure must name the offending input' || return 1
  return 0
}

test_unknown_model_alias_rejected() {
  run_check '[mcode·gpt9 z @brandon] unknown model'
  expect_exit 1 "$RUN_RC" 'an unknown model alias must be rejected' || return 1
  expect_contains "$RUN_OUT" 'gpt9' 'the rejection must name the unknown alias' || return 1
  return 0
}

test_missing_effort_rejected() {
  run_check '[mcode·luna6 @brandon] missing effort token'
  expect_exit 1 "$RUN_RC" 'a prefix without an effort token must be rejected' || return 1
  expect_contains "$RUN_OUT" 'effort' 'the rejection must name the missing effort token' || return 1
  return 0
}

test_unknown_harness_rejected() {
  run_check '[bogus·m3.1f m @brandon] unknown harness'
  expect_exit 1 "$RUN_RC" 'an unknown harness token must be rejected' || return 1
  expect_contains "$RUN_OUT" 'harness' 'the rejection must name the unknown harness' || return 1
  return 0
}

test_lane_key_missing_task_rejected() {
  run_check --lane-key 'pi-luna6-brandon'
  expect_exit 1 "$RUN_RC" 'a lane key without a task segment must be rejected' || return 1
  expect_contains "$RUN_OUT" 'task' 'the rejection must name the missing task segment' || return 1
  return 0
}

test_checker_does_not_edit_input() {
  local file="$TMP_ROOT/input.txt"
  printf '[controller @ brandon] legacy row\n' > "$file"
  bash "$CHECK" --stdin < "$file" > /dev/null 2>&1 || true
  grep -qF '[controller @ brandon] legacy row' "$file" \
    || { t_fail 'the checker must not edit its input'; return 1; }
  return 0
}

test_hd2_worked_example_passes() {
  # The cross-surface tracker's own worked example must pass here, so a row
  # written on this host survives the round trip to the other host.
  run_check '[agy·G38F m @HD2] Test-first bounded implementation'
  expect_exit 0 "$RUN_RC" 'the HD2 worked example must pass' || return 1
  return 0
}

# --- runner ----------------------------------------------------------------

# run_case <name> <function>: run one case and count the result.
run_case() {
  local name=$1
  shift
  printf '# CASE: %s\n' "$name"
  if "$@"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS: %s\n' "$name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL: %s\n' "$name"
  fi
}

for _case in \
  test_script_exists_and_executable \
  test_help_exits_zero_and_prints_usage \
  test_valid_board_row_passes \
  test_valid_lane_key_passes \
  test_stdin_valid_rows_pass \
  test_legacy_owner_role_row_rejected \
  test_legacy_owner_host_row_rejected \
  test_legacy_model_surface_row_rejected \
  test_lane_key_missing_harness_rejected \
  test_registry_model_disagreement_rejected \
  test_self_check_missing_alias_exits_two \
  test_self_check_all_models_aliased_passes \
  test_registry_valid_rows_pass \
  test_invalid_input_exits_one \
  test_unknown_model_alias_rejected \
  test_missing_effort_rejected \
  test_unknown_harness_rejected \
  test_lane_key_missing_task_rejected \
  test_checker_does_not_edit_input \
  test_hd2_worked_example_passes; do
  run_case "$_case" "$_case"
done

printf '\n# SUMMARY: total %d, passed %d, failed %d\n' \
  "$((PASS_COUNT + FAIL_COUNT))" "$PASS_COUNT" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -ne 0 ]; then
  printf '# RESULT: FAILED\n'
  exit 1
fi

printf '# RESULT: PASSED\n'
exit 0
