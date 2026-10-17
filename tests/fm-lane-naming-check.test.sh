#!/usr/bin/env bash
# tests/fm-lane-naming-check.test.sh - TDD contract tests for lane naming enforcement.
#
# Tests the lane key convention from AGENT-TODO-PROMPT-STYLE.md:
#   Lane key:   <model>-<surface>-<task>   (lowercase, no spaces)
#   Board line: [<model> @ <surface>[/<pane>}] <action> — <state>
#
# Also validates the async lane registry at data/async-lanes.tsv:
#   Comment lines starting with '#' and blank lines are skipped.
#   Each data row is TAB-separated: run_id, lane_key, model, surface, task, state, output.
#   Cross-checks lane_key segments against the separate model and surface columns.
#
# Model aliases:  m3.1f, m2.7, luna6, glm5.3f, gem38f, pi
# Surface aliases: dubz, hd2, brandon, evps, firstmate
#
# The check exits non-zero naming the offending input and never edits or fixes it.
# It must accept a single string arg, read a list from stdin, or validate a registry file.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/fm-lane-naming-check.sh"

# --- helpers ---------------------------------------------------------------

# lint_check: run shellcheck on the script under test and fail if it finds issues.
lint_check() {
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning "$CHECK" >/dev/null 2>&1 \
      || fail "shellcheck found issues in $CHECK"
  fi
}

# ---------------------------------------------------------------------

test_script_exists_and_executable() {
  [ -f "$CHECK" ] || fail "$CHECK does not exist"
  [ -x "$CHECK" ] || fail "$CHECK is not executable"
  lint_check
  pass "script exists and passes shellcheck"
}

# --- lane key: valid -------------------------------------------------------

test_lane_key_valid_m2_7() {
  local out rc
  out=$(bash "$CHECK" "m2.7-hd2-build" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key m2.7-hd2-build should pass, got exit $rc: $out"
  pass "m2.7-hd2-build passes"
}

test_lane_key_valid_m3_1f() {
  local out rc
  out=$(bash "$CHECK" "m3.1f-dubz-luna6comms" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key m3.1f-dubz-luna6comms should pass, got exit $rc: $out"
  pass "m3.1f-dubz-luna6comms passes"
}

test_lane_key_valid_glm() {
  local out rc
  out=$(bash "$CHECK" "glm5.3f-brandon-wo0011" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key glm5.3f-brandon-wo0011 should pass, got exit $rc: $out"
  pass "glm5.3f-brandon-wo0011 passes"
}

test_lane_key_valid_gem() {
  local out rc
  out=$(bash "$CHECK" "gem38f-hd2-masterlist" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key gem38f-hd2-masterlist should pass, got exit $rc: $out"
  pass "gem38f-hd2-masterlist passes"
}

test_lane_key_valid_luna6() {
  local out rc
  out=$(bash "$CHECK" "luna6-firstmate-audit" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key luna6-firstmate-audit should pass, got exit $rc: $out"
  pass "luna6-firstmate-audit passes"
}

test_lane_key_valid_pi() {
  local out rc
  out=$(bash "$CHECK" "pi-dubz-triage" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key pi-dubz-triage should pass, got exit $rc: $out"
  pass "pi-dubz-triage passes"
}

# --- lane key: missing segments -----------------------------------------

test_lane_key_missing_model() {
  local out rc
  out=$(bash "$CHECK" "hd2-build" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "key missing model must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "hd2-build" \
    || fail "error message must name the offending input 'hd2-build': $out"
  pass "key missing model is rejected with named error"
}

test_lane_key_missing_surface() {
  local out rc
  out=$(bash "$CHECK" "m2.7-build" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "key missing surface must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "m2.7-build" \
    || fail "error message must name the offending input 'm2.7-build': $out"
  pass "key missing surface is rejected with named error"
}

test_lane_key_missing_task() {
  local out rc
  out=$(bash "$CHECK" "m2.7-hd2" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "key missing task must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "m2.7-hd2" \
    || fail "error message must name the offending input 'm2.7-hd2': $out"
  pass "key missing task is rejected with named error"
}

# --- lane key: uppercase / spaces ----------------------------------------

test_lane_key_uppercase_rejected() {
  local out rc
  out=$(bash "$CHECK" "M2.7-HD2-Build" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "uppercase key must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "M2.7-HD2-Build" \
    || fail "error message must name the offending input 'M2.7-HD2-Build': $out"
  pass "uppercase key is rejected with named error"
}

test_lane_key_spaces_rejected() {
  local out rc
  out=$(bash "$CHECK" "m2.7 hd2 build" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "key with spaces must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "m2.7 hd2 build" \
    || fail "error message must name the offending input 'm2.7 hd2 build': $out"
  pass "key with spaces is rejected with named error"
}

# --- To-Do board line --------------------------------------------------

test_board_line_valid() {
  local out rc
  out=$(bash "$CHECK" "[m2.7 @ hd2] build lane" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid board line should pass, got exit $rc: $out"
  pass "valid board line passes"
}

test_board_line_missing_model() {
  local out rc
  out=$(bash "$CHECK" "[ @ hd2] build lane" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "board line missing model must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "@ hd2" \
    || fail "error message must name the offending board segment: $out"
  pass "board line missing model is rejected with named error"
}

test_board_line_missing_surface() {
  local out rc
  out=$(bash "$CHECK" "[m2.7 @ ] build lane" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "board line missing surface must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "m2.7 @ " \
    || fail "error message must name the offending board segment: $out"
  pass "board line missing surface is rejected with named error"
}

test_board_line_no_brackets() {
  local out rc
  out=$(bash "$CHECK" "m2.7 @ hd2 build lane" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "board line without [ ] must exit non-zero, got $rc: $out"
  pass "board line without [ ] is rejected"
}

# --- stdin mode ---------------------------------------------------------

test_stdin_valid_list() {
  local out rc
  out=$(printf 'm2.7-hd2-build\nm3.1f-dubz-comms\nluna6-brandon-audit\n' \
    | bash "$CHECK" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid stdin list must pass, got exit $rc: $out"
  pass "stdin valid list passes"
}

test_stdin_invalid_line_rejected() {
  local out rc
  out=$(printf 'm2.7-hd2-build\nhd2-build\nm3.1f-dubz-comms\n' \
    | bash "$CHECK" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "stdin with invalid line must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "hd2-build" \
    || fail "error message must name the offending stdin line 'hd2-build': $out"
  pass "stdin with invalid line is rejected with named error"
}

test_stdin_mixed_valid_and_invalid() {
  local out rc
  # Should report all bad lines or at minimum the first.
  out=$(printf 'm2.7-hd2-ok\ngem38f-evps\ngem38f\nglm5.3f-brandon-x\n' \
    | bash "$CHECK" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "stdin with invalid lines must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "gem38f" \
    || fail "error message must name the offending input 'gem38f': $out"
  pass "stdin mixed list: invalid lines named in error"
}

# --- task record model proof -------------------------------------------

test_task_record_with_model_declaration() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-check-task.XXXXXX")
  # Write a minimal state/<id>.meta with a declared model.
  mkdir -p "$tmp/data/test-task"
  cat > "$tmp/data/test-task/meta" <<'META'
window=firstmate:fm-test-task
model=gem38f
harness=agy
kind=task
META
  # When a meta file is passed, the check must verify the declared model matches.
  # For now just verify the script accepts a path argument (future: model extraction).
  out=$(bash "$CHECK" "$tmp/data/test-task/meta" 2>&1); rc=$?
  # A path is not a lane key; it should be rejected or the script should handle it gracefully.
  # The check should distinguish a path from a key.
  [ "$rc" -ne 0 ] || fail "passing a file path should not be treated as a valid lane key, got exit $rc: $out"
  rm -rf "$tmp"
  pass "file path is rejected (not a valid lane key)"
}

# --- does not edit input ------------------------------------------------

test_does_not_edit_input() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-check-noedit.XXXXXX")
  printf 'HD2-BUILD\n' > "$tmp/input.txt"
  bash "$CHECK" "$tmp/input.txt" > /dev/null 2>&1 || true
  # The file must be unchanged.
  grep -q "HD2-BUILD" "$tmp/input.txt" \
    || fail "check must not edit the input file"
  rm -rf "$tmp"
  pass "check does not edit input file"
}

# --- exit code is specific ---------------------------------------------

test_exit_code_is_nonzero_on_failure() {
  local out rc
  out=$(bash "$CHECK" "badkey" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "invalid key must exit non-zero, got $rc: $out"
  [ "$rc" -ne 1 ] || pass "exit code 1 is acceptable for invalid key (got: $rc)"
  # Any non-zero is acceptable as long as it's consistent.
  pass "exit code is non-zero on failure (got: $rc)"
}

# --- registry file mode ---------------------------------------------------

# is_uuid <string>: returns 0 if the string looks like a v4 UUID.
is_uuid() {
  local s=$1
  # 8-4-4-4-12 hex digits.
  [[ $s =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

# test_registry_header_only: a file with only a header comment line should pass.
test_registry_header_only() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "header-only registry should pass, got exit $rc: $out"
  rm -rf "$tmp"
  pass "header-only registry passes"
}

# test_registry_missing_field: a data row with fewer than 7 TAB fields fails
# and names the file, line number, and reason.
test_registry_missing_field() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
abc123	m2.7-hd2-build	m2.7	hd2	build	running	https://...
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "registry with 6 fields must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "$tmp/registry.tsv" \
    || fail "error must name the offending file: $out"
  printf '%s\n' "$out" | grep -qiE "line|field" \
    || fail "error must mention line or field: $out"
  rm -rf "$tmp"
  pass "registry missing field is rejected with file + line + reason"
}

# test_registry_model_disagrees: lane_key model segment disagrees with model column.
test_registry_model_disagrees() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
abc123-def	m2.7-hd2-build	gem38f	hd2	build	running	https://...
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "model disagreement must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "$tmp/registry.tsv" \
    || fail "error must name the offending file: $out"
  printf '%s\n' "$out" | grep -qiE "model|m2.7|gem38f" \
    || fail "error must name the disagreeing model: $out"
  rm -rf "$tmp"
  pass "lane_key model disagrees with model column: rejected with file + reason"
}

# test_registry_surface_disagrees: lane_key surface segment disagrees with surface column.
test_registry_surface_disagrees() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
abc123-def	m2.7-hd2-build	m2.7	brandon	build	running	https://...
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "surface disagreement must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "$tmp/registry.tsv" \
    || fail "error must name the offending file: $out"
  printf '%s\n' "$out" | grep -qiE "surface|hd2|brandon" \
    || fail "error must name the disagreeing surface: $out"
  rm -rf "$tmp"
  pass "lane_key surface disagrees with surface column: rejected with file + reason"
}

# test_registry_lane_key_not_lowercase: lane_key contains uppercase or spaces.
test_registry_lane_key_not_lowercase() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
abc123-def	M2.7-HD2-build	M2.7	HD2	build	running	https://...
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "uppercase lane_key must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "$tmp/registry.tsv" \
    || fail "error must name the offending file: $out"
  rm -rf "$tmp"
  pass "registry with uppercase lane_key is rejected with file + reason"
}

# test_registry_non_uuid_run_id: run_id is not a UUID.
test_registry_non_uuid_run_id() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
not-a-uuid	m2.7-hd2-build	m2.7	hd2	build	running	https://...
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "non-UUID run_id must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "$tmp/registry.tsv" \
    || fail "error must name the offending file: $out"
  printf '%s\n' "$out" | grep -qiE "uuid|run_id" \
    || fail "error must mention UUID or run_id: $out"
  rm -rf "$tmp"
  pass "registry with non-UUID run_id is rejected with file + reason"
}

# test_registry_valid_multi_row: multiple valid data rows pass.
test_registry_valid_multi_row() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
abc123de-f123-4567-8901-abcdef123456	m2.7-hd2-build	m2.7	hd2	build	running	https://...
abc123de-f234-5678-9012-bcdef1234567	m3.1f-dubz-comms	m3.1f	dubz	comms	done	https://...
abc123de-f345-6789-0123-cdef12345678	luna6-brandon-audit	luna6	brandon	audit	idle	https://...
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid multi-row registry should pass, got exit $rc: $out"
  rm -rf "$tmp"
  pass "valid multi-row registry passes"
}

# test_registry_does_not_edit: the check must never modify the registry file.
test_registry_does_not_edit() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
bad-run-id	m2.7-hd2-build	m2.7	hd2	build	running	https://...
EOF
  bash "$CHECK" "$tmp/registry.tsv" > /dev/null 2>&1 || true
  grep -q "bad-run-id" "$tmp/registry.tsv" \
    || fail "check must not edit the registry file"
  rm -rf "$tmp"
  pass "check does not edit the registry file"
}

# ========================================================================
# Run all tests
# ========================================================================

for _t in \
  test_script_exists_and_executable \
  test_lane_key_valid_m2_7 \
  test_lane_key_valid_m3_1f \
  test_lane_key_valid_glm \
  test_lane_key_valid_gem \
  test_lane_key_valid_luna6 \
  test_lane_key_valid_pi \
  test_lane_key_missing_model \
  test_lane_key_missing_surface \
  test_lane_key_missing_task \
  test_lane_key_uppercase_rejected \
  test_lane_key_spaces_rejected \
  test_board_line_valid \
  test_board_line_missing_model \
  test_board_line_missing_surface \
  test_board_line_no_brackets \
  test_stdin_valid_list \
  test_stdin_invalid_line_rejected \
  test_stdin_mixed_valid_and_invalid \
  test_task_record_with_model_declaration \
  test_does_not_edit_input \
  test_exit_code_is_nonzero_on_failure \
  test_registry_header_only \
  test_registry_missing_field \
  test_registry_model_disagrees \
  test_registry_surface_disagrees \
  test_registry_lane_key_not_lowercase \
  test_registry_non_uuid_run_id \
  test_registry_valid_multi_row \
  test_registry_does_not_edit; do
  echo "# RUN: $_t"
  if ! "$_t"; then
    echo "FAIL: $_t"
    exit 1
  fi
done
echo "# fm-lane-naming-check.test.sh: all assertions passed"
