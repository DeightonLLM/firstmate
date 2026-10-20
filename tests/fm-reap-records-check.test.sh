#!/usr/bin/env bash
# tests/fm-reap-records-check.test.sh - TDD contract tests for reap-record enforcement.
#
# Convention enforced: when a pane is closed or reaped, its status and meta
# records must be archived together. A status file with no matching .meta is an
# orphan. Registered secondmates are excluded from the orphan count and reported
# separately as 'registered secondmate without live metadata'.
#
# Two modes:
#   fm-reap-records-check.sh --scan <state-dir> <secondmates-md>
#     Scans <state-dir> for *.status files. For each, checks whether a matching
#     *.meta exists. Excludes secondmates registered in <secondmates-md>.
#     Exits non-zero if any genuine orphan is found; zero if only registered
#     secondmates are affected.
#
#   fm-reap-records-check.sh --pane-id <pane-id> <state-dir> <secondmates-md>
#     Answers whether a live metadata record for <pane-id> still exists.
#     Returns 0 if .meta is present, non-zero otherwise.
#
# The check never deletes or edits anything.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/fm-reap-records-check.sh"

# --- helpers ---------------------------------------------------------------

lint_check() {
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning "$CHECK" >/dev/null 2>&1 \
      || fail "shellcheck found issues in $CHECK"
  fi
}

# build_secondmates_md <dir> [id ...]: creates a secondmates.md with the given ids.
# Each entry uses the real repo format: "- <id> - description."
build_secondmates_md() {
  local dir=$1
  shift
  mkdir -p "$dir"
  : > "$dir/secondmates.md"
  for id in "$@"; do
    printf '%s\n' "- $id - test secondmate." >> "$dir/secondmates.md"
  done
}

# mkstatus <statedir> <id>: touch state/<id>.status
mkstatus() {
  mkdir -p "$1"
  touch "$1/$2.status"
}

# mkmeta <statedir> <id>: create state/<id>.meta with minimal content
mkmeta() {
  mkdir -p "$1"
  printf '%s\n' "window=firstmate:fm-$2" "endpoint_task_id=$2" "kind=task" \
    > "$1/$2.meta"
}

# ---------------------------------------------------------------------

test_script_exists_and_executable() {
  [ -f "$CHECK" ] || fail "$CHECK does not exist"
  [ -x "$CHECK" ] || fail "$CHECK is not executable"
  lint_check
  pass "script exists and passes shellcheck"
}

# --- scan mode: clean state (no orphans) ---------------------------------

test_scan_clean_state_is_zero() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-clean")
  mkstatus "$tmp" "alpha"
  mkmeta  "$tmp" "alpha"
  build_secondmates_md "$tmp" "beta"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "clean state should exit 0, got $rc: $out"
  pass "scan clean state: exit 0"
}

# --- scan mode: genuine orphan (status, no meta, not secondmate) -----------

test_scan_genuine_orphan_exits_nonzero() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-orphan")
  mkstatus "$tmp" "orphan-task"
  build_secondmates_md "$tmp" "secondmate-1"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "genuine orphan must exit non-zero, got $rc: $out"
  pass "scan genuine orphan: exit non-zero"
}

test_scan_genuine_orphan_reports_id() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-orphan-name")
  mkstatus "$tmp" "orphan-task"
  build_secondmates_md "$tmp"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  printf '%s\n' "$out" | grep -Fq "orphan-task" \
    || fail "orphan id must be named in output: $out"
  pass "scan genuine orphan: names the offending id"
}

test_scan_genuine_orphan_reports_reason() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-orphan-reason")
  mkstatus "$tmp" "orphan-task"
  build_secondmates_md "$tmp"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  printf '%s\n' "$out" | grep -qiE "status|meta|orphan" \
    || fail "output must name the reason (status/meta/orphan): $out"
  pass "scan genuine orphan: reports reason"
}

# --- scan mode: registered secondmate with no meta is NOT orphan -----------

test_scan_secondmate_no_meta_exits_zero() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-secondmate-clean")
  mkstatus "$tmp" "backup-dr"
  build_secondmates_md "$tmp" "backup-dr" "system-ops"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "secondmate with no meta must not count as orphan, got $rc: $out"
  pass "scan: registered secondmate with no meta is excluded, exit 0"
}

test_scan_secondmate_no_meta_reported_separately() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-secondmate-report")
  mkstatus "$tmp" "backup-dr"
  build_secondmates_md "$tmp" "backup-dr"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  printf '%s\n' "$out" | grep -qiE "secondmate|backup-dr" \
    || fail "secondmate must appear in 'registered secondmate without metadata' output: $out"
  pass "scan: secondmate with no meta reported separately"
}

test_scan_secondmate_with_meta_is_clean() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-secondmate-live")
  mkstatus "$tmp" "backup-dr"
  mkmeta  "$tmp" "backup-dr"
  build_secondmates_md "$tmp" "backup-dr"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "secondmate with live meta should be clean, got $rc: $out"
  printf '%s\n' "$out" | grep -qiE "backup-dr" \
    && fail "secondmate with live meta should not appear in any report: $out"
  pass "scan: secondmate with live meta is completely clean"
}

# --- scan mode: mixed — genuine orphan + secondmate ------------------------

test_scan_mixed_genuine_and_secondmate() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-mixed")
  mkstatus "$tmp" "orphan-task"
  mkstatus "$tmp" "backup-dr"
  build_secondmates_md "$tmp" "backup-dr"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "mixed state with genuine orphan must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -Fq "orphan-task" \
    || fail "genuine orphan 'orphan-task' must be named: $out"
  printf '%s\n' "$out" | grep -qi "backup-dr" \
    || fail "secondmate 'backup-dr' must be named separately: $out"
  pass "scan mixed: genuine orphan non-zero, both ids named"
}

# --- scan mode: multiple genuine orphans -----------------------------------

test_scan_multiple_orphans() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-multi-orphan")
  mkstatus "$tmp" "task-alpha"
  mkstatus "$tmp" "task-beta"
  build_secondmates_md "$tmp" "secondmate-1"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "multiple orphans must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -Fq "task-alpha" \
    || fail "task-alpha must be named: $out"
  printf '%s\n' "$out" | grep -Fq "task-beta" \
    || fail "task-beta must be named: $out"
  pass "scan multiple orphans: both named, exit non-zero"
}

# --- scan mode: status file with matching meta is clean --------------------

test_scan_status_with_meta_is_clean() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-paired")
  mkstatus "$tmp" "task-paired"
  mkmeta  "$tmp" "task-paired"
  build_secondmates_md "$tmp"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "status with matching meta must be clean, got $rc: $out"
  printf '%s\n' "$out" | grep -qiE "task-paired|orphan|secondmate" \
    && fail "task-paired should not appear in any report: $out"
  pass "scan: status with matching meta is clean"
}

# --- scan mode: meta without status is not reported ------------------------

test_scan_meta_without_status_is_ignored() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-meta-only")
  mkmeta  "$tmp" "task-meta-only"
  build_secondmates_md "$tmp"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "meta without status is not an orphan, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "task-meta-only" \
    && fail "meta-without-status should not appear: $out"
  pass "scan: meta without status is not reported"
}

# --- scan mode: only secondmates, no genuine orphans ------------------------

test_scan_only_secondmates_no_genuine_orphans_is_zero() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-secondmates-only")
  mkstatus "$tmp" "backup-dr"
  mkstatus "$tmp" "system-ops"
  mkstatus "$tmp" "hetzner-compute"
  build_secondmates_md "$tmp" "backup-dr" "system-ops" "hetzner-compute"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "only registered secondmates (no genuine orphans) must exit 0, got $rc: $out"
  pass "scan: only registered secondmates affected -> exit 0"
}

# --- scan mode: does not edit anything -------------------------------------

test_scan_does_not_edit_or_delete() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-noedit")
  mkstatus "$tmp" "orphan-task"
  mkmeta  "$tmp" "live-task"
  build_secondmates_md "$tmp"

  bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" > /dev/null 2>&1 || true

  [ -f "$tmp/orphan-task.status" ] \
    || fail "check must not delete orphan-task.status"
  [ -f "$tmp/live-task.meta" ] \
    || fail "check must not delete live-task.meta"
  [ -f "$tmp/secondmates.md" ] \
    || fail "check must not delete secondmates.md"
  pass "check never edits or deletes any file"
}

# --- pane-id mode: meta exists ---------------------------------------------

test_pane_id_has_meta_exits_zero() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-pane-meta")
  mkmeta  "$tmp" "task-live"
  build_secondmates_md "$tmp"

  out=$(bash "$CHECK" --pane-id "task-live" "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -eq 0 ] || fail "pane with meta must exit 0, got $rc: $out"
  pass "pane-id: live metadata -> exit 0"
}

test_pane_id_has_meta_reports_yes() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-pane-yes")
  mkmeta  "$tmp" "task-live"
  build_secondmates_md "$tmp"

  out=$(bash "$CHECK" --pane-id "task-live" "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  printf '%s\n' "$out" | grep -qi "live\|present\|exists\|metadata" \
    || fail "output must indicate metadata is present: $out"
  pass "pane-id: live metadata indicated in output"
}

# --- pane-id mode: no meta, not secondmate ---------------------------------

test_pane_id_no_meta_not_secondmate_exits_nonzero() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-pane-no")
  build_secondmates_md "$tmp" "some-secondmate"

  out=$(bash "$CHECK" --pane-id "unknown-task" "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "pane without meta and not a secondmate must exit non-zero, got $rc: $out"
  pass "pane-id: no meta, not secondmate -> exit non-zero"
}

test_pane_id_no_meta_not_secondmate_reports_no() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-pane-no-out")
  build_secondmates_md "$tmp"

  out=$(bash "$CHECK" --pane-id "unknown-task" "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  printf '%s\n' "$out" | grep -qiE "no|absent|gone|missing|metadata" \
    || fail "output must indicate metadata is absent: $out"
  pass "pane-id: no metadata indicated in output"
}

# --- pane-id mode: no meta, but is registered secondmate -------------------

test_pane_id_secondmate_no_meta_exits_nonzero() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-pane-sm")
  build_secondmates_md "$tmp" "secondmate-dr"

  out=$(bash "$CHECK" --pane-id "secondmate-dr" "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  # pane-id answers "does live metadata exist?" — a secondmate without meta has
  # no live record, so non-zero. This is intentionally different from scan mode
  # (which exits 0 for the same case): scan asks "any genuine orphans?" while
  # pane-id asks "is there live metadata?".
  [ "$rc" -ne 0 ] || fail "pane-id: secondmate without meta has no live metadata, got $rc: $out"
  pass "pane-id: secondmate without meta exits non-zero (no live record)"
}

test_pane_id_secondmate_no_meta_reports_absent() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-pane-sm-out")
  build_secondmates_md "$tmp" "secondmate-dr"

  out=$(bash "$CHECK" --pane-id "secondmate-dr" "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  printf '%s\n' "$out" | grep -qiE "no|absent|gone|missing|secondmate|metadata" \
    || fail "output must indicate metadata is absent: $out"
  pass "pane-id: secondmate without metadata indicated in output"
}

# --- pane-id mode: does not edit anything ----------------------------------

test_pane_id_does_not_edit_or_delete() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-pane-noedit")
  mkmeta  "$tmp" "live-task"
  build_secondmates_md "$tmp"

  bash "$CHECK" --pane-id "live-task" "$tmp" "$tmp/secondmates.md" > /dev/null 2>&1 || true

  [ -f "$tmp/live-task.meta" ] \
    || fail "check must not delete live-task.meta"
  [ -f "$tmp/secondmates.md" ] \
    || fail "check must not delete secondmates.md"
  pass "pane-id mode never edits or deletes any file"
}

# --- argument validation ----------------------------------------------------

test_missing_state_dir_exits_nonzero() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-no-state")
  build_secondmates_md "$tmp"

  out=$(bash "$CHECK" --scan "/nonexistent-path" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "missing state dir must exit non-zero, got $rc: $out"
  pass "missing state dir: exit non-zero"
}

test_missing_secondmates_md_exits_nonzero() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-no-sm")
  mkdir -p "$tmp/state"

  out=$(bash "$CHECK" --scan "$tmp/state" "/nonexistent/secondmates.md" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "missing secondmates.md must exit non-zero, got $rc: $out"
  pass "missing secondmates.md: exit non-zero"
}

test_unknown_mode_exits_nonzero() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-bad-mode")

  out=$(bash "$CHECK" --badmode "$tmp" "$tmp" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "unknown mode must exit non-zero, got $rc: $out"
  pass "unknown mode: exit non-zero"
}

# --- secondmates.md parsing: real repo format -------------------------------

test_secondmates_md_real_format() {
  local tmp out rc
  tmp=$(fm_test_tmproot "fm-reap-sm-real")
  # Real format from data/secondmates.md: "- <id> - <description>"
  # build_secondmates_md produces this format, so use it directly.
  build_secondmates_md "$tmp" "backup-dr" "system-ops"
  mkstatus "$tmp" "backup-dr"
  mkstatus "$tmp" "orphan-task"

  out=$(bash "$CHECK" --scan "$tmp" "$tmp/secondmates.md" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "genuine orphan must exit non-zero, got $rc: $out"
  printf '%s\n' "$out" | grep -Fq "orphan-task" \
    || fail "orphan-task must be named: $out"
  printf '%s\n' "$out" | grep -qi "backup-dr" \
    || fail "backup-dr secondmate must appear separately: $out"
  pass "real secondmates.md format: both ids handled correctly"
}

# ========================================================================
# Run all tests
# ========================================================================

for _t in \
  test_script_exists_and_executable \
  test_scan_clean_state_is_zero \
  test_scan_genuine_orphan_exits_nonzero \
  test_scan_genuine_orphan_reports_id \
  test_scan_genuine_orphan_reports_reason \
  test_scan_secondmate_no_meta_exits_zero \
  test_scan_secondmate_no_meta_reported_separately \
  test_scan_secondmate_with_meta_is_clean \
  test_scan_mixed_genuine_and_secondmate \
  test_scan_multiple_orphans \
  test_scan_status_with_meta_is_clean \
  test_scan_meta_without_status_is_ignored \
  test_scan_only_secondmates_no_genuine_orphans_is_zero \
  test_scan_does_not_edit_or_delete \
  test_pane_id_has_meta_exits_zero \
  test_pane_id_has_meta_reports_yes \
  test_pane_id_no_meta_not_secondmate_exits_nonzero \
  test_pane_id_no_meta_not_secondmate_reports_no \
  test_pane_id_secondmate_no_meta_exits_nonzero \
  test_pane_id_secondmate_no_meta_reports_absent \
  test_pane_id_does_not_edit_or_delete \
  test_missing_state_dir_exits_nonzero \
  test_missing_secondmates_md_exits_nonzero \
  test_unknown_mode_exits_nonzero \
  test_secondmates_md_real_format; do
  echo "# RUN: $_t"
  if ! "$_t"; then
    echo "FAIL: $_t"
    exit 1
  fi
done
echo "# fm-reap-records-check.test.sh: all assertions passed"
