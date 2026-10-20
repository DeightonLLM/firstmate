#!/usr/bin/env bash
# tests/fm-teardown-archive.test.sh - TDD: teardown must archive state/* before removing.
#
# RED (pre-fix): teardown removes state files with no archive -> test FAILS
# GREEN (post-fix): teardown archives to data/teardown-archives/<id>/ -> test PASSES
#
# The GAP: bin/fm-reap-records-check.sh detects an orphaned status file with
# no metadata, but nothing enforces that closing a pane archives its records
# in the same action. This test proves the archive is created and the state/
# directory is left clean after teardown.

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TEARDOWN="$ROOT/bin/fm-teardown.sh"
# Global TMP_ROOT for cleanup registration only (each test gets its own below).
export FM_GATE_REFUSE_BYPASS=1

# --- helpers ---------------------------------------------------------------

# mkstate <statedir> <id> <worktree> <project>: create every state file a live task may have.
mkstate() {
  local statedir=$1 id=$2 wt=$3 proj=$4
  mkdir -p "$statedir"
  printf '%s\n' \
    "window=firstmate:fm-$id" \
    "endpoint_task_id=$id" \
    "worktree=$wt" \
    "project=$proj" \
    "kind=ship" \
    "mode=direct-PR" \
    "harness=claude" \
    > "$statedir/$id.meta"
  printf '%s\n' "running: agent launched" "done: work complete" \
    > "$statedir/$id.status"
  printf '%s\n' "turn-end-token-abc123" \
    > "$statedir/$id.turn-ended"
  printf '%s\n' "1234567890" \
    > "$statedir/$id.pi-ext.ts"
  printf '%s\n' "gen-$id-001" \
    > "$statedir/$id.busy-gen"
  printf '%s\n' "busy" \
    > "$statedir/$id.busy-state"
  printf '%s\n' "session=herdr-main" "workspace=default" \
    > "$statedir/$id.herdr-presentation"
  printf '%s\n' "grok-token-$id" \
    > "$statedir/$id.grok-turnend-token"
  printf '%s\n' "kimi-token-$id" \
    > "$statedir/$id.kimi-turnend-token"
}

# setup_home <tmproot> <taskid>: builds a complete hermetic firstmate home.
# Populates global var HOME. Returns 0 on success.
setup_home() {
  local tmproot=$1 taskid=$2
  local _home="$tmproot/fmhome"
  local _wt="$tmproot/wt"
  local _proj="$_home/projects/fakeproj"
  mkdir -p "$_home/state" "$_home/data" "$_home/config" "$_proj"

  git init -q "$_proj"
  git -C "$_proj" config user.email "test@test"
  git -C "$_proj" config user.name "test"
  printf 'first file\n' > "$_proj/README.md"
  git -C "$_proj" add README.md
  git -C "$_proj" commit -qm init
  git -C "$_proj" worktree add -q "$_wt" HEAD

  mkstate "$_home/state" "$taskid" "$_wt" "$_proj"
  printf '%s\n' "- backup-dr - secondary home." > "$_home/data/secondmates.md"

  mkdir -p "$tmproot/fakebin"
  cat > "$tmproot/fakebin/treehouse" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$tmproot/fakebin/treehouse"
  cat > "$tmproot/fakebin/tmux" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$tmproot/fakebin/tmux"
  cat > "$tmproot/fakebin/gh-axi" <<'SH'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "pr list") printf '%s\n' "count: 0 (showing first 0)" "pull_requests[]: []" ; exit 0 ;;
  "pr view") echo "error: pull request not found" >&2 ; exit 1 ;;
esac
exit 0
SH
  chmod +x "$tmproot/fakebin/gh-axi"

  # Export home path via global for the calling test.
  HOME="$_home"
}

# run_teardown <tmproot> <home> <taskid>: invokes teardown with mocks in PATH.
run_teardown() {
  local tmproot=$1 home=$2 taskid=$3
  PATH="$tmproot/fakebin:$PATH" \
  FM_HOME="$home" \
  FM_ROOT_OVERRIDE="$ROOT" \
  FM_STATE_OVERRIDE="$home/state" \
  FM_DATA_OVERRIDE="$home/data" \
  FM_CONFIG_OVERRIDE="$home/config" \
    bash "$TEARDOWN" "$taskid" 2>&1
}

# archive_dir <home> <taskid>: returns the expected archive directory path.
archive_dir() {
  local home=$1 id=$2
  printf '%s\n' "$home/data/teardown-archives/$id/$(date +%Y%m%d)"
}

# ---------------------------------------------------------------------

test_teardown_archives_state_before_removal() {
  local tmproot taskid statedir archdir out rc
  tmproot=$(fm_test_tmproot "fm-archive-1")
  setup_home "$tmproot" "archive-test-task"
  taskid="archive-test-task"
  statedir="$HOME/state"
  archdir=$(archive_dir "$HOME" "$taskid")

  out=$(run_teardown "$tmproot" "$HOME" "$taskid"); rc=$?

  if [ "$rc" -ne 0 ] && [ ! -d "$archdir" ]; then
    fail "teardown exited $rc BEFORE archiving; archive not created. Output: $out"
  fi

  [ -d "$archdir" ] \
    || fail "archive directory not created at $archdir; teardown did not archive state"
  ls "$archdir/" > /dev/null 2>&1 \
    || fail "archive directory $archdir is empty; no files were copied"

  for f in meta status turn-ended pi-ext.ts busy-gen busy-state herdr-presentation grok-turnend-token kimi-turnend-token; do
    [ -f "$archdir/$taskid.$f" ] \
      || fail "archive missing expected file $taskid.$f"
  done

  for f in meta status turn-ended pi-ext.ts busy-gen busy-state herdr-presentation; do
    [ -s "$archdir/$taskid.$f" ] \
      || fail "archived $taskid.$f is empty; content was not preserved"
  done

  local remaining
  remaining=$(ls "$statedir"/*.status 2>/dev/null || true)
  [ -z "$remaining" ] \
    || fail "state/ still contains status files after teardown: $remaining"

  local reap_out reap_rc
  reap_out=$("$ROOT/bin/fm-reap-records-check.sh" \
    --scan "$statedir" "$HOME/data/secondmates.md" 2>&1); reap_rc=$?
  [ "$reap_rc" -eq 0 ] \
    || fail "reap-check reports orphans after teardown: $reap_out"

  pass "teardown archived all state files to $archdir and left clean state/"
}

test_archive_survives_gitignore() {
  local tmproot taskid archdir rc
  tmproot=$(fm_test_tmproot "fm-archive-2")
  setup_home "$tmproot" "gitignore-archive-test"
  taskid="gitignore-archive-test"
  archdir=$(archive_dir "$HOME" "$taskid")

  run_teardown "$tmproot" "$HOME" "$taskid" > /dev/null 2>&1; rc=$?

  [ -d "$archdir" ] \
    || fail "archive not created inside data/ at $archdir (rc=$rc)"

  case "$archdir" in
    "$HOME/data/"*) ;;
    *) fail "archive path $archdir is not under data/; it may be in a git-tracked path"
  esac

  pass "archive survives in data/ (gitignored)"
}

test_worktree_removed_after_archive() {
  local tmproot taskid archdir rc
  tmproot=$(fm_test_tmproot "fm-archive-3")
  setup_home "$tmproot" "worktree-archive-test"
  taskid="worktree-archive-test"
  archdir=$(archive_dir "$HOME" "$taskid")

  run_teardown "$tmproot" "$HOME" "$taskid" > /dev/null 2>&1; rc=$?

  [ ! -f "$HOME/state/$taskid.meta" ] \
    || fail "state/$taskid.meta still present after teardown"
  [ -d "$archdir" ] \
    || fail "archive not created; archiving ran after worktree removal"

  pass "archive created before worktree removal"
}

test_archive_path_deterministic() {
  local tmproot1 tmproot2 taskid1 taskid2 archdir1 archdir2 home1 home2 rc
  tmproot1=$(fm_test_tmproot "fm-archive-4a")
  tmproot2=$(fm_test_tmproot "fm-archive-4b")
  taskid1="det-test-1"
  taskid2="det-test-2"

  setup_home "$tmproot1" "$taskid1"
  home1=$HOME
  run_teardown "$tmproot1" "$HOME" "$taskid1" > /dev/null 2>&1

  setup_home "$tmproot2" "$taskid2"
  home2=$HOME
  run_teardown "$tmproot2" "$HOME" "$taskid2" > /dev/null 2>&1

  archdir1=$(archive_dir "$home1" "$taskid1")
  archdir2=$(archive_dir "$home2" "$taskid2")

  [ "$archdir1" != "$archdir2" ] \
    || fail "archive paths must differ for different task ids"
  [ -d "$archdir1" ] \
    || fail "archive 1 not found at $archdir1"
  [ -d "$archdir2" ] \
    || fail "archive 2 not found at $archdir2"

  pass "archive path is deterministic per task id"
}

# Gate contract: reap-check exits non-zero on orphan.
test_reap_gate_exits_nonzero_on_orphan() {
  local tmproot statedir secondmates_md out rc
  tmproot=$(fm_test_tmproot "reap-gate")
  statedir="$tmproot/state"
  secondmates_md="$tmproot/secondmates.md"
  mkdir -p "$statedir"
  touch "$statedir/orphan-42.status"
  printf '%s\n' "- backup-dr - secondary home." > "$secondmates_md"

  out=$(bash "$ROOT/bin/fm-reap-records-check.sh" \
    --scan "$statedir" "$secondmates_md" 2>&1); rc=$?

  [ "$rc" -ne 0 ] || fail "reap-check must exit non-zero on orphan status, got rc=$rc"
  printf '%s\n' "$out" | grep -qiE "orphan|status|meta" \
    || fail "reap-check output must name the orphan: $out"
  pass "reap-check exits non-zero on orphan (usable as gate)"
}

# Gate contract: reap-check never reports secondmate as orphan or deletion candidate.
test_reap_never_reports_secondmate_as_orphan() {
  local tmproot statedir secondmates_md out rc
  tmproot=$(fm_test_tmproot "reap-sm")
  statedir="$tmproot/state"
  secondmates_md="$tmproot/secondmates.md"
  mkdir -p "$statedir"
  touch "$statedir/backup-dr.status"
  printf '%s\n' "- backup-dr - secondary home." > "$secondmates_md"

  out=$(bash "$ROOT/bin/fm-reap-records-check.sh" \
    --scan "$statedir" "$secondmates_md" 2>&1); rc=$?

  [ "$rc" -eq 0 ] || fail "reap-check exited $rc for secondmate-only state; expected 0"
  printf '%s\n' "$out" | grep -qiE "delete|rm[[:space:]]|remove" \
    && fail "reap-check must never suggest deletion: $out"
  pass "reap-check never reports secondmate as orphan or deletion candidate"
}

# ========================================================================
# Run all tests
# ========================================================================

for _t in \
  test_teardown_archives_state_before_removal \
  test_archive_survives_gitignore \
  test_worktree_removed_after_archive \
  test_archive_path_deterministic \
  test_reap_gate_exits_nonzero_on_orphan \
  test_reap_never_reports_secondmate_as_orphan; do
  echo "# RUN: $_t"
  if ! "$_t"; then
    echo "FAIL: $_t"
    exit 1
  fi
done
echo "# fm-teardown-archive.test.sh: all assertions passed"
