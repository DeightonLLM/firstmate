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

# m2.7h is MiniMax M2.7 Highspeed, the tier live worker lanes actually run. Without it the
# validator rejected every real lane key we dispatched, which is the defect Q2 fixed.
test_lane_key_valid_m2_7h() {
  local out rc
  out=$(bash "$CHECK" "m2.7h-brandon-build" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key m2.7h-brandon-build should pass, got exit $rc: $out"
  pass "m2.7h-brandon-build passes"
}

test_board_line_valid_m2_7h() {
  local out rc
  out=$(bash "$CHECK" "[m2.7h @ brandon] widget fix — working" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid board line [m2.7h @ brandon] should pass, got exit $rc: $out"
  pass "[m2.7h @ brandon] board line passes"
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
abc123	mcode-m2.7-hd2-build	m2.7	hd2	build	running	https://...
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
abc123-def	mcode-m2.7-hd2-build	gem38f	hd2	build	running	https://...
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
abc123-def	mcode-m2.7-hd2-build	m2.7	brandon	build	running	https://...
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
not-a-uuid	mcode-m2.7-hd2-build	m2.7	hd2	build	running	https://...
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
abc123de-f123-4567-8901-abcdef123456	mcode-m2.7-hd2-build	m2.7	hd2	build	running	https://...
abc123de-f234-5678-9012-bcdef1234567	mcode-m3.1f-dubz-comms	m3.1f	dubz	comms	done	https://...
abc123de-f345-6789-0123-cdef12345678	mcode-luna6-brandon-audit	luna6	brandon	audit	idle	https://...
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid multi-row registry should pass, got exit $rc: $out"
  rm -rf "$tmp"
  pass "valid multi-row registry passes"
}

# test_registry_duplicate_run_id_rejected: every registry row must have its own run id.
test_registry_duplicate_run_id_rejected() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
abc123de-f123-4567-8901-abcdef123456	mcode-m2.7-hd2-build	m2.7	hd2	build	running	first
abc123de-f123-4567-8901-abcdef123456	mcode-m2.7-hd2-review	m2.7	hd2	review	running	second
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "duplicate run_id must be rejected, got exit $rc: $out"
  printf '%s\n' "$out" | grep -qi "already claimed" \
    || fail "duplicate run_id diagnostic must explain the collision: $out"
  rm -rf "$tmp"
  pass "registry duplicate run_id is rejected"
}

# test_registry_distinct_run_ids_accepted: distinct recorded runs may coexist.
test_registry_distinct_run_ids_accepted() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
abc123de-f123-4567-8901-abcdef123456	mcode-m2.7-hd2-build	m2.7	hd2	build	running	first
def234ef-f234-5678-9012-bcdef1234567	mcode-m2.7-hd2-review	m2.7	hd2	review	running	second
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "distinct run_ids should pass, got exit $rc: $out"
  rm -rf "$tmp"
  pass "registry distinct run_ids are accepted"
}

# test_registry_does_not_edit: the check must never modify the registry file.
test_registry_does_not_edit() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
bad-run-id	mcode-m2.7-hd2-build	m2.7	hd2	build	running	https://...
EOF
  bash "$CHECK" "$tmp/registry.tsv" > /dev/null 2>&1 || true
  grep -q "bad-run-id" "$tmp/registry.tsv" \
    || fail "check must not edit the registry file"
  rm -rf "$tmp"
  pass "check does not edit the registry file"
}

# ========================================================================
# Alias-to-dispatch binding (m27.12)
#
# Root defect: the hardcoded alias set in the validator could drift from
# the models actually configured for dispatch.  Q2 fixed the symptom by
# adding m2.7h, but did not close the mechanism.  The fix adds a
# --self-check mode that reads config/crew-dispatch.json, derives the
# expected alias for every model id present, and fails loudly when a
# configured model has no alias or when an alias has no corresponding model.
#
# Alias derivation rule (ONE canonical statement, one place):
#   MiniMax provider: model id like minimax/MiniMax-M<family>[-<tier>]
#   -> lane-key alias = 'm' + family (strip leading M) + tier-marker
#     tier-marker = last letter of the tier keyword:
#       'highspeed' -> 'h', 'flash' -> 'f', bare -> ''
#     Example: minimax/MiniMax-M2.7-highspeed  -> m2.7h
#              minimax/MiniMax-M3.1-Flash         -> m3.1f
#              minimax/MiniMax-M2.7                -> m2.7
#   Other providers (openai-codex, etc.): no programmatic rule defined;
#   their model ids (gpt-6-luna, gpt-6.1-sol) do not derive to any
#   lane-key alias through the above rule.  Any alias claimed for them
#   must be verified explicitly before addition.
# ========================================================================

# test_self_check_configured_model_has_alias: --self-check reads the dispatch
# config, derives aliases for every model id present, and verifies that
# each derived alias is in the validator's hardcoded alias set.
# RED: current script has no --self-check flag; it exits 2 (unrecognised).
# GREEN: after implementing --self-check, exit 0 when all dispatch models
# have aliases (proving the binding holds for the live configuration).
test_self_check_configured_model_has_alias() {
  local out rc
  out=$(bash "$CHECK" --self-check "$ROOT/config/crew-dispatch.json" 2>&1)
  rc=$?
  # Exit 0 = self-check passed (all configured models have aliases).
  # Any non-zero = self-check failure (missing alias for a configured model
  # OR --self-check flag not implemented yet).
  [ "$rc" -eq 0 ] || fail "self-check must exit 0; got $rc: $out"
  pass "self-check passes: all dispatch-config models have lane-key aliases"
}

# test_self_check_proves_alias_removed_causes_failure: prove the self-check
# catches the Q2 defect by patching the script to remove m2.7h (the alias
# that should have been present when workers ran minimax/MiniMax-M2.7-highspeed).
# We sed-out m2.7h, run --self-check against the patched script, and assert
# non-zero exit with a diagnostic that names the missing alias or model.
# RED: current script exits 2 (--self-check not implemented).
# GREEN: patched script (m2.7h removed) exits non-zero because the configured
# model minimax/MiniMax-M2.7-highspeed has no alias.
test_self_check_proves_alias_removed_causes_failure() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-alias-sim.XXXXXX")
  cat > "$tmp/dispatch.json" <<'JSON'
{"default":{"model":"minimax/MiniMax-M2.7-highspeed"}}
JSON
  # First establish that the live checker accepts this configured alias.
  out=$(bash "$CHECK" --self-check "$tmp/dispatch.json" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "self-check must accept configured m2.7h before mutation; got $rc: $out"
  # Remove precisely the literal alias token; no regex wildcard is introduced.
  python3 - "$CHECK" "$tmp/patched-check.sh" <<'PY_PATCH'
from pathlib import Path
import sys
source, destination = map(Path, sys.argv[1:])
text = source.read_text()
token = "_model_pat='m2\\.7h|"
assert text.count(token) == 1, "expected exactly one canonical m2.7h token"
destination.write_text(text.replace(token, "_model_pat='", 1))
PY_PATCH
  chmod +x "$tmp/patched-check.sh"
  out=$(bash "$tmp/patched-check.sh" --self-check "$tmp/dispatch.json" 2>&1); rc=$?
  rm -rf "$tmp"
  [ "$rc" -ne 0 ] || fail "self-check must reject configured m2.7h when that alias is removed"
  printf '%s\n' "$out" | grep -qiE 'm2\.7h|highspeed|alias|model' \
    || fail "self-check error must identify the missing alias/model: $out"
  pass "self-check accepts configured m2.7h, then rejects it when the alias is removed"
}

# test_self_check_reports_orphaned_aliases: the self-check must name any
# hardcoded alias that has no corresponding model in the dispatch config.
# This catches the root cause class (alias list grows independently of config).
# m2.7 is hardcoded; minimax/MiniMax-M2.7 is NOT in dispatch config (that
# family was retired 2026-10-19).  The self-check must report it.
# RED: current script exits 2 (--self-check not implemented).
# GREEN: --self-check runs and names m2.7 as orphaned in its output.
test_self_check_reports_orphaned_aliases() {
  local out rc
  out=$(bash "$CHECK" --self-check "$ROOT/config/crew-dispatch.json" 2>&1)
  rc=$?
  # Self-check may exit 0 (all configured models have aliases) OR exit non-zero
  # (orphaned aliases reported).  Either is acceptable as long as m2.7 is named.
  printf '%s\n' "$out" | grep -qiE 'm2\.7[^h]|orphaned|not.*configured' \
    || fail "self-check output must name m2.7 as orphaned (no dispatch-config model): $out"
  pass "self-check names orphaned alias m2.7 (no corresponding dispatch model)"
}

# ========================================================================
# Run all tests
# ========================================================================

for _t in \
  test_script_exists_and_executable \
  test_lane_key_valid_m2_7 \
  test_lane_key_valid_m2_7h \
  test_self_check_configured_model_has_alias \
  test_self_check_proves_alias_removed_causes_failure \
  test_self_check_reports_orphaned_aliases \
  test_board_line_valid_m2_7h \
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
  test_registry_duplicate_run_id_rejected \
  test_registry_distinct_run_ids_accepted \
  test_registry_does_not_edit; do
  echo "# RUN: $_t"
  if ! "$_t"; then
    echo "FAIL: $_t"
    exit 1
  fi
done
echo "# fm-lane-naming-check.test.sh: all assertions passed"
