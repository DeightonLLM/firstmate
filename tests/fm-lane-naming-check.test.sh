#!/usr/bin/env bash
# tests/fm-lane-naming-check.test.sh - contract tests for lane naming enforcement.
#
# Tests the lane key convention from AGENT-TODO-PROMPT-STYLE.md and
# docs/todo-prefix-canonical-format.md:
#   Lane key:   <harness>-<model>-<host>-<task>   (lowercase, no spaces)
#   Board row:  [<harness>·<ModelAbbrev> <effort> @<Host>] <action> - <state>
#
# The harness segment is not optional: without it a mcode lane and a pi lane
# running the same model are indistinguishable.
#
# Also validates the async lane registry at data/async-lanes.tsv:
#   Comment lines starting with '#' and blank lines are skipped.
#   Each data row is TAB-separated: run_id, lane_key, model, surface, task, state, output.
#   Cross-checks the lane_key model and host segments against the separate model
#   and surface columns, and requires every run_id to be a UUID unique to one row.
#
# Model aliases: m3.1f, m3.1, luna6, glm5.3f, gem38f, pi (active);
#                m2.7h, m2.7 (retired: they resolve for history only).
# Host segment: any hostname token (brandon, hd2stack, controller, elevate, ...).
#
# bin/fm-lane-naming-check.sh is the entry point under test; it delegates every
# check to bin/fm-todo-prefix-check.sh, the single owner of the vocabulary. The
# tests assert the two agree, because two copies of the rule is how the
# three-segment and four-segment lane keys drifted apart in the first place.
#
# The check exits non-zero naming the offending input and never edits or fixes it.
# Every case function below is invoked through the runner list at the end of
# this file, which shellcheck cannot resolve. The repo's own convention for
# indirectly invoked functions is the SC2329 directive (tests/fm-pending-reply.test.sh).
# shellcheck disable=SC2329
# It must accept a single string arg, read a list from stdin, or validate a registry file.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/fm-lane-naming-check.sh"
OWNER="$ROOT/bin/fm-todo-prefix-check.sh"
REGISTRY="$ROOT/data/async-lanes.tsv"

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
  [ -f "$OWNER" ] || fail "$OWNER does not exist"
  lint_check
  pass "script exists and passes shellcheck"
}

# --- lane key: valid -------------------------------------------------------

test_lane_key_valid_canonical() {
  local out rc
  out=$(bash "$CHECK" "pi-luna6-brandon-theme-whoosh" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key pi-luna6-brandon-theme-whoosh should pass, got exit $rc: $out"
  pass "pi-luna6-brandon-theme-whoosh passes"
}

# m2.7h is MiniMax M2.7 Highspeed. The alias is retired for dispatch, so a NEW
# lane key naming it is refused; the historical rows that really ran on it stay
# valid in the registry (see the registry tests below).
test_lane_key_retired_alias_refused_for_new_key() {
  local out rc
  out=$(bash "$CHECK" "pi-m2.7h-brandon-inbox-review" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "a new lane key naming the retired m2.7h alias must be refused, got exit $rc: $out"
  printf '%s\n' "$out" | grep -qi "retired" \
    || fail "the rejection must name the retired alias: $out"
  pass "a new lane key naming a retired alias is refused"
}

test_lane_key_valid_m3_1f() {
  local out rc
  out=$(bash "$CHECK" "mcode-m3.1f-hd2stack-build" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key mcode-m3.1f-hd2stack-build should pass, got exit $rc: $out"
  pass "mcode-m3.1f-hd2stack-build passes"
}

test_lane_key_valid_glm() {
  local out rc
  out=$(bash "$CHECK" "pi-glm5.3f-brandon-wo0011" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key pi-glm5.3f-brandon-wo0011 should pass, got exit $rc: $out"
  pass "pi-glm5.3f-brandon-wo0011 passes"
}

test_lane_key_valid_gem() {
  local out rc
  out=$(bash "$CHECK" "agy-gem38f-elevate-masterlist" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key agy-gem38f-elevate-masterlist should pass, got exit $rc: $out"
  pass "agy-gem38f-elevate-masterlist passes"
}

test_lane_key_valid_luna6() {
  local out rc
  out=$(bash "$CHECK" "codex-luna6-controller-audit" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key codex-luna6-controller-audit should pass, got exit $rc: $out"
  pass "codex-luna6-controller-audit passes"
}

test_lane_key_valid_pi() {
  local out rc
  out=$(bash "$CHECK" "pi-m3.1f-dubz-triage" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid key pi-m3.1f-dubz-triage should pass, got exit $rc: $out"
  pass "pi-m3.1f-dubz-triage passes"
}

# --- lane key: the three-segment legacy form is refused --------------------

test_lane_key_three_segment_rejected() {
  local out rc
  out=$(bash "$CHECK" "m3.1f-firstmate-lockdeadline" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "the three-segment legacy key must be refused, got exit $rc: $out"
  printf '%s\n' "$out" | grep -qi "m3.1f-firstmate-lockdeadline" \
    || fail "the rejection must name the offending input: $out"
  printf '%s\n' "$out" | grep -qi "<harness>-<model>-<host>-<task>" \
    || fail "the rejection must name the expected lane-key shape: $out"
  pass "the three-segment legacy key is refused and the expected shape is named"
}

test_lane_key_two_segment_rejected() {
  local out rc
  out=$(bash "$CHECK" "build-ttft" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "a two-segment key must be refused, got exit $rc: $out"
  printf '%s\n' "$out" | grep -qi "<harness>-<model>-<host>-<task>" \
    || fail "the rejection must name the expected lane-key shape: $out"
  pass "a two-segment key is refused and the expected shape is named"
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

test_lane_key_missing_task() {
  local out rc
  out=$(bash "$CHECK" "pi-luna6-brandon" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "key missing task must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "pi-luna6-brandon" \
    || fail "error message must name the offending input 'pi-luna6-brandon': $out"
  pass "key missing task is rejected with named error"
}

test_lane_key_unknown_harness() {
  local out rc
  out=$(bash "$CHECK" "bogus-luna6-brandon-theme" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "an unknown harness segment must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "harness" \
    || fail "the rejection must name the harness segment: $out"
  pass "an unknown harness segment is rejected with named error"
}

# --- lane key: uppercase / spaces ----------------------------------------

test_lane_key_uppercase_rejected() {
  local out rc
  out=$(bash "$CHECK" "PI-LUNA6-BRANDON-THEME" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "uppercase key must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "PI-LUNA6-BRANDON-THEME" \
    || fail "error message must name the offending input 'PI-LUNA6-BRANDON-THEME': $out"
  pass "uppercase key is rejected with named error"
}

test_lane_key_spaces_rejected() {
  local out rc
  out=$(bash "$CHECK" "pi luna6 brandon theme" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "key with spaces must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "pi luna6 brandon theme" \
    || fail "error message must name the offending input 'pi luna6 brandon theme': $out"
  pass "key with spaces is rejected with named error"
}

# --- To-Do board row --------------------------------------------------

test_board_line_valid() {
  local out rc
  out=$(bash "$CHECK" "[mcode·m3.1f m @brandon] build lane" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid board row should pass, got exit $rc: $out"
  pass "valid board row passes"
}

test_board_line_missing_model() {
  local out rc
  out=$(bash "$CHECK" "[mcode m @brandon] build lane" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "board row missing model must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "model" \
    || fail "error message must name the offending board segment: $out"
  pass "board row missing model is rejected with named error"
}

test_board_line_missing_effort() {
  local out rc
  out=$(bash "$CHECK" "[mcode·luna6 @brandon] build lane" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "board row missing effort must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "effort" \
    || fail "error message must name the offending board segment: $out"
  pass "board row missing effort is rejected with named error"
}

test_board_line_legacy_model_surface_rejected() {
  local out rc
  out=$(bash "$CHECK" "[m2.7h @ brandon] widget fix — working" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "the legacy [model @ surface] board row must be refused, got exit $rc: $out"
  printf '%s\n' "$out" | grep -qi "<harness>·<ModelAbbrev> <effort> @<Host>]" \
    || fail "the rejection must name the expected canonical shape: $out"
  pass "the legacy [model @ surface] board row is refused"
}

test_board_line_no_brackets() {
  local out rc
  out=$(bash "$CHECK" "mcode·luna6 m @brandon build lane" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "board row without [ ] must exit non-zero, got $rc: $out"
  pass "board row without [ ] is rejected"
}

# --- stdin mode ---------------------------------------------------------

test_stdin_valid_list() {
  local out rc
  out=$(printf 'pi-luna6-brandon-theme-whoosh\nmcode-m3.1f-hd2stack-build\ncodex-luna6-controller-audit\n' \
    | bash "$CHECK" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "valid stdin list must pass, got exit $rc: $out"
  pass "stdin valid list passes"
}

test_stdin_invalid_line_rejected() {
  local out rc
  out=$(printf 'pi-luna6-brandon-theme-whoosh\nhd2-build\nmcode-m3.1f-hd2stack-build\n' \
    | bash "$CHECK" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "stdin with invalid line must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "hd2-build" \
    || fail "error message must name the offending stdin line 'hd2-build': $out"
  pass "stdin with invalid line is rejected with named error"
}

test_stdin_mixed_valid_and_invalid() {
  local out rc
  # Should report all bad lines or at minimum the first.
  out=$(printf 'pi-luna6-brandon-theme\nm3.1f-firstmate-lockdeadline\nm3.1f\npi-glm5.3f-brandon-x\n' \
    | bash "$CHECK" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "stdin with invalid lines must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "firstmate-lockdeadline" \
    || fail "error message must name the offending input: $out"
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
  # A meta file is not a lane key and not a registry file; it must not pass as
  # either, because a path is not a lane key.
  out=$(bash "$CHECK" "$tmp/data/test-task/meta" 2>&1); rc=$?
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
  [ "$rc" -eq 1 ] || fail "an invalid key must exit exactly 1, got $rc: $out"
  pass "exit code is 1 on failure (got: $rc)"
}

# --- registry file mode ---------------------------------------------------

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
abc123	mcode-m3.1f-hd2stack-build	m3.1f	hd2	build	running	https://...
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
abc123de-f123-4567-8901-abcdef123456	mcode-m3.1f-hd2stack-build	gem38f	hd2stack	build	running	https://...
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "model disagreement must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "$tmp/registry.tsv" \
    || fail "error must name the offending file: $out"
  printf '%s\n' "$out" | grep -qiE "model|m3.1f|gem38f" \
    || fail "error must name the disagreeing model: $out"
  rm -rf "$tmp"
  pass "lane_key model disagrees with model column: rejected with file + reason"
}

# test_registry_host_disagrees: lane_key host segment disagrees with surface column.
test_registry_host_disagrees() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
abc123de-f123-4567-8901-abcdef123456	mcode-m3.1f-hd2stack-build	m3.1f	brandon	build	running	https://...
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "host disagreement must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "$tmp/registry.tsv" \
    || fail "error must name the offending file: $out"
  printf '%s\n' "$out" | grep -qiE "host|hd2stack|brandon" \
    || fail "error must name the disagreeing host: $out"
  rm -rf "$tmp"
  pass "lane_key host disagrees with surface column: rejected with file + reason"
}

# test_registry_lane_key_not_lowercase: lane_key contains uppercase or spaces.
test_registry_lane_key_not_lowercase() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
abc123de-f123-4567-8901-abcdef123456	M3.1F-HD2STACK-build	m3.1f	hd2stack	build	running	https://...
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
not-a-uuid	mcode-m3.1f-hd2stack-build	m3.1f	hd2stack	build	running	https://...
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
abc123de-f123-4567-8901-abcdef123456	mcode-m3.1f-hd2stack-build	m3.1f	hd2stack	build	running	https://...
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
abc123de-f123-4567-8901-abcdef123456	mcode-m3.1f-hd2stack-build	m3.1f	hd2stack	build	running	first
abc123de-f123-4567-8901-abcdef123456	mcode-m3.1f-hd2stack-review	m3.1f	hd2stack	review	running	second
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "duplicate run_id must be rejected, got $rc: $out"
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
abc123de-f123-4567-8901-abcdef123456	mcode-m3.1f-hd2stack-build	m3.1f	hd2stack	build	running	first
def234ef-f234-5678-9012-bcdef1234567	mcode-m3.1f-hd2stack-review	m3.1f	hd2stack	review	running	second
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "distinct run_ids should pass, got $rc: $out"
  rm -rf "$tmp"
  pass "registry distinct run_ids are accepted"
}

# test_registry_does_not_edit: the check must never modify the registry file.
test_registry_does_not_edit() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
bad-run-id	mcode-m3.1f-hd2stack-build	m3.1f	hd2stack	build	running	https://...
EOF
  bash "$CHECK" "$tmp/registry.tsv" > /dev/null 2>&1 || true
  grep -q "bad-run-id" "$tmp/registry.tsv" \
    || fail "check must not edit the registry file"
  rm -rf "$tmp"
  pass "check does not edit the registry file"
}

# test_live_registry_validates: the tracked registry must pass its own checker
# with zero errors, through both entry points.
test_live_registry_validates() {
  local out rc err
  # The shared repo tracks no live registry (data/async-lanes.tsv is a live
  # artifact of the home that runs the lanes), so where it is absent this case
  # SKIPS rather than failing; where it is present it must still validate.
  if [ ! -f "$REGISTRY" ]; then
    printf '  skip: no tracked registry at %s in this clone\n' "$REGISTRY"
    return 0
  fi
  err=$(mktemp "${TMPDIR:-/tmp}/fm-lane-reg-err.XXXXXX")
  out=$(bash "$CHECK" "$REGISTRY" 2>"$err"); rc=$?
  [ "$rc" -eq 0 ] || fail "the tracked registry must validate, got exit $rc: $out $(cat "$err")"
  [ ! -s "$err" ] || fail "the tracked registry must validate with zero error lines: $(cat "$err")"
  rm -f "$err"
  out=$(bash "$OWNER" --registry "$REGISTRY" 2>"$err"); rc=$?
  [ "$rc" -eq 0 ] || fail "the tracked registry must validate through the owner, got exit $rc: $out"
  [ ! -s "$err" ] || fail "the tracked registry must validate with zero error lines: $(cat "$err")"
  rm -f "$err"
  pass "the tracked registry validates with zero errors through both entry points"
}

# test_live_registry_run_ids_unique: a run_id identifies one lane, so no two
# rows in the tracked registry may share one.
test_live_registry_run_ids_unique() {
  local dupes
  dupes=$(awk -F'\t' '!/^#/ && NF > 1 { print $1 }' "$REGISTRY" | sort | uniq -d)
  [ -z "$dupes" ] || fail "the tracked registry reuses a run_id: $dupes"
  pass "every run_id in the tracked registry is unique"
}

# test_historical_retired_alias_row_accepted: a row that recorded a lane which
# really ran on a retired model stays valid, because a registry row records
# what ran and cannot be rewritten into a model the lane never ran.
test_historical_retired_alias_row_accepted() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-reg.XXXXXX")
  cat > "$tmp/registry.tsv" <<'EOF'
# run_id	lane_key	model	surface	task	state	output
abc123de-f123-4567-8901-abcdef123456	pi-m2.7h-brandon-inbox-review	m2.7h	brandon	inbox-review	done	https://...
EOF
  out=$(bash "$CHECK" "$tmp/registry.tsv" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "a historical row naming a retired alias must stay valid, got exit $rc: $out"
  rm -rf "$tmp"
  pass "a historical registry row naming a retired alias stays valid"
}

# ========================================================================
# Alias-to-dispatch binding
#
# Root defect: the hardcoded alias set in the validator could drift from
# the models actually configured for dispatch.  The fix is a --self-check
# mode that reads config/crew-dispatch.json, derives the expected alias for
# every model id present, and fails loudly when a configured model has no
# alias in the table.
#
# The alias table lives in ONE place, bin/fm-todo-prefix-check.sh, which is
# the owner this entry point delegates to.
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
# each derived alias is in the validator's alias table.
test_self_check_configured_model_has_alias() {
  local out rc
  out=$(bash "$CHECK" --self-check "$ROOT/config/crew-dispatch.json" 2>&1)
  rc=$?
  # Exit 0 = self-check passed (all configured models have aliases).
  [ "$rc" -eq 0 ] || fail "self-check must exit 0; got $rc: $out"
  pass "self-check passes: all dispatch-config models have lane-key aliases"
}

# test_self_check_proves_alias_removed_causes_failure: prove the self-check
# catches the root defect class by patching the OWNER to remove m2.7h (the
# alias that was present when workers ran minimax/MiniMax-M2.7-highspeed),
# then asserting the patched owner rejects that configured model.
test_self_check_proves_alias_removed_causes_failure() {
  local tmp out rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-alias-sim.XXXXXX")
  cat > "$tmp/dispatch.json" <<'JSON'
{"default":{"model":"minimax/MiniMax-M2.7-highspeed"}}
JSON
  # First establish that the live owner accepts this configured alias.
  out=$(bash "$OWNER" --self-check "$tmp/dispatch.json" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "self-check must accept configured m2.7h before mutation; got $rc: $out"
  # Remove precisely the literal alias entry; no regex wildcard is introduced.
  python3 - "$OWNER" "$tmp/patched-owner.sh" <<'PY_PATCH'
from pathlib import Path
import sys
source, destination = map(Path, sys.argv[1:])
text = source.read_text()
token = " m2.7h=minimax/MiniMax-M2.7-highspeed:minimax:retired"
assert text.count(token) == 1, "expected exactly one canonical m2.7h table entry"
destination.write_text(text.replace(token, "", 1))
PY_PATCH
  chmod +x "$tmp/patched-owner.sh"
  out=$(bash "$tmp/patched-owner.sh" --self-check "$tmp/dispatch.json" 2>&1); rc=$?
  rm -rf "$tmp"
  [ "$rc" -ne 0 ] || fail "self-check must reject configured m2.7h when that alias is removed"
  printf '%s\n' "$out" | grep -qiE 'm2\.7h|highspeed|alias|model' \
    || fail "self-check error must identify the missing alias/model: $out"
  pass "self-check accepts configured m2.7h, then rejects it when the alias is removed"
}

# test_self_check_reports_orphaned_aliases: the self-check must name any
# alias that has no corresponding model in the dispatch config.  A retired
# alias is expected to have none, and is named as retired.
test_self_check_reports_orphaned_aliases() {
  local out rc
  out=$(bash "$CHECK" --self-check "$ROOT/config/crew-dispatch.json" 2>&1)
  rc=$?
  printf '%s\n' "$out" | grep -qiE 'm2\.7[^h]|orphaned|retired|not.*configured' \
    || fail "self-check output must name m2.7 (no corresponding dispatch model): $out"
  pass "self-check names the m2.7 alias (retired, no corresponding dispatch model)"
}

# ========================================================================
# The two entry points must agree
#
# Two copies of the vocabulary is how the three-segment and four-segment lane
# keys drifted apart.  The entry point delegates, so they cannot disagree.
# ========================================================================

test_both_checkers_accept_canonical_key() {
  local a b rc_a rc_b
  a=$(bash "$CHECK" "pi-luna6-brandon-theme-whoosh" 2>&1); rc_a=$?
  b=$(bash "$OWNER" --lane-key "pi-luna6-brandon-theme-whoosh" 2>&1); rc_b=$?
  [ "$rc_a" -eq 0 ] || fail "the entry point must accept a canonical key, got $rc_a: $a"
  [ "$rc_b" -eq 0 ] || fail "the owner must accept a canonical key, got $rc_b: $b"
  pass "both checkers accept a canonical four-segment key"
}

test_both_checkers_reject_three_segment_key() {
  local a b rc_a rc_b
  a=$(bash "$CHECK" "m3.1f-firstmate-lockdeadline" 2>&1); rc_a=$?
  b=$(bash "$OWNER" --lane-key "m3.1f-firstmate-lockdeadline" 2>&1); rc_b=$?
  [ "$rc_a" -eq 1 ] || fail "the entry point must refuse a three-segment key with exit 1, got $rc_a: $a"
  [ "$rc_b" -eq 1 ] || fail "the owner must refuse a three-segment key with exit 1, got $rc_b: $b"
  printf '%s\n' "$a" | grep -qi "<harness>-<model>-<host>-<task>" \
    || fail "the entry point rejection must name the expected shape: $a"
  printf '%s\n' "$b" | grep -qi "<harness>-<model>-<host>-<task>" \
    || fail "the owner rejection must name the expected shape: $b"
  pass "both checkers refuse a three-segment key and name the expected shape"
}

test_owner_holds_the_only_alias_table() {
  local owner_hits other_hits
  owner_hits=$(grep -c "m2.7h=minimax/MiniMax-M2.7-highspeed" "$OWNER" || true)
  [ "$owner_hits" -ge 1 ] || fail "the owner must hold the model alias table"
  other_hits=$(grep -rl "m2.7h=minimax/MiniMax-M2.7-highspeed" "$ROOT/bin" 2>/dev/null \
    | grep -vc "fm-todo-prefix-check.sh" || true)
  [ "$other_hits" -eq 0 ] || fail "the alias table must live in exactly one script, found $other_hits other copies"
  pass "the model alias table lives in exactly one script"
}

# ========================================================================
# Run all tests
# ========================================================================

for _t in \
  test_script_exists_and_executable \
  test_lane_key_valid_canonical \
  test_lane_key_retired_alias_refused_for_new_key \
  test_lane_key_valid_m3_1f \
  test_lane_key_valid_glm \
  test_lane_key_valid_gem \
  test_lane_key_valid_luna6 \
  test_lane_key_valid_pi \
  test_lane_key_three_segment_rejected \
  test_lane_key_two_segment_rejected \
  test_lane_key_missing_model \
  test_lane_key_missing_task \
  test_lane_key_unknown_harness \
  test_lane_key_uppercase_rejected \
  test_lane_key_spaces_rejected \
  test_board_line_valid \
  test_board_line_missing_model \
  test_board_line_missing_effort \
  test_board_line_legacy_model_surface_rejected \
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
  test_registry_host_disagrees \
  test_registry_lane_key_not_lowercase \
  test_registry_non_uuid_run_id \
  test_registry_valid_multi_row \
  test_registry_duplicate_run_id_rejected \
  test_registry_distinct_run_ids_accepted \
  test_registry_does_not_edit \
  test_live_registry_validates \
  test_live_registry_run_ids_unique \
  test_historical_retired_alias_row_accepted \
  test_self_check_configured_model_has_alias \
  test_self_check_proves_alias_removed_causes_failure \
  test_self_check_reports_orphaned_aliases \
  test_both_checkers_accept_canonical_key \
  test_both_checkers_reject_three_segment_key \
  test_owner_holds_the_only_alias_table; do
  echo "# RUN: $_t"
  if ! "$_t"; then
    echo "FAIL: $_t"
    exit 1
  fi
done
echo "# fm-lane-naming-check.test.sh: all assertions passed"
