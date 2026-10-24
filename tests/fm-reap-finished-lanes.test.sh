#!/usr/bin/env bash
# tests/fm-reap-finished-lanes.test.sh - the safety contract for the lane-slot reaper.
#
# WHAT THIS PROVES.
#
#   (a) a lane with a terminal verb and a DEAD pane IS reclaimed;
#   (b) a lane with a terminal verb but a LIVE pane is NOT;
#   (c) a lane with NO terminal verb is NOT;
#   (d) a BLOCKED lane is NOT (both the status verb and the ledger state);
#   (e) a slot whose branch holds unmerged commits is preserved first - the
#       bundle that carries those commits exists and is verified - before the
#       return;
#   (f) the tar check catches an EMPTY archive;
#   (g) the DRY RUN WRITES NOTHING - the whole fixture tree is byte-identical
#       before and after the dry run, while the dry run still reports the
#       counts it would have preserved;
#   and the terminal-verb grammar accepts the real lines `done: ...` and
#   `resolved [key=...]: ...`, and a second run over the same pool is a no-op.
#
# RED CAPABILITY IS PROVEN, NOT ASSERTED.  Every guard in the script is
# mutated away in a copy of the script, and the suite then shows the mutant
# VIOLATING that guard's rule.  If a mutation stops changing the outcome, the
# guard is not load-bearing and this suite FAILS.  That is what makes the
# suite red-capable rather than merely green.
#
# The fixtures are real: a real git repository with real worktrees, a real
# bundle, a real tar.  Only the two things that must not touch the live fleet
# are faked - the treehouse binary and the pane oracle - and both are faked at
# the boundary the script actually calls.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPT_UNDER_TEST="$ROOT/bin/fm-reap-finished-lanes.sh"
ASSERTIONS=0

if [ -z "${FM_TEST_TIMEOUT_APPLIED:-}" ] && [ -n "${FM_TEST_OUTER_TIMEOUT:-}" ]; then
  export FM_TEST_TIMEOUT_APPLIED=1
  exec timeout "${FM_TEST_OUTER_TIMEOUT}" "$0" "$@"
fi

assert_ok() {  # <condition-result> <message>
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$1" = "0" ]; then
    pass "$2"
  else
    fail "$2"
  fi
}

# Clean up without rm -rf: the fleet's recoverable-delete shim when it exists.
fm_reap_test_trash() {  # <path>
  local p=$1 t
  t=$(command -v mavis-trash 2>/dev/null) || t="$HOME/.minimax/bin/mavis-trash"
  if [ -x "$t" ]; then
    "$t" -- "$p" >/dev/null 2>&1 && return 0
  fi
  return 1
}

# =============================================================================
# fixture
# =============================================================================

# build_fixture <root> <broken-tar:0|1>
build_fixture() {
  local root=$1 broken=${2:-0}
  local repo="$root/repo" pool="$root/pool" state="$root/state" fake="$root/fakebin"

  mkdir -p "$repo" "$pool" "$state" "$root/ops" "$fake"

  # The pool ceiling.  It is never raised by the reaper; it is only reported.
  printf 'max_trees = 48\n' > "$pool/treehouse.toml"

  # A real repository, with a real origin/main to measure "merged" against.
  git init -q "$repo"
  git -C "$repo" symbolic-ref HEAD refs/heads/main
  git -C "$repo" config user.email "fixture@example.invalid"
  git -C "$repo" config user.name "fixture"
  printf 'base\n' > "$repo/README.md"
  printf '*.log\nignored-dir/\nignored-dir2\n' > "$repo/.gitignore"
  git -C "$repo" add README.md .gitignore
  git -C "$repo" commit -q -m "base"
  git -C "$repo" update-ref refs/remotes/origin/main "$(git -C "$repo" rev-parse main)"

  # One worktree per slot, exactly the shape treehouse keeps.
  local n
  for n in 1 2 3 4 5 6 7 8 9 10; do
    mkdir -p "$pool/$n"
    git -C "$repo" worktree add -q "$pool/$n/repo" -b "fm/lane-slot-$n" main 2>/dev/null
  done

  # slot 1: terminal verb, dead pane, and files that must survive.
  printf 'a\n' > "$pool/1/repo/untracked-a.txt"
  printf 'b\n' > "$pool/1/repo/untracked-b.txt"
  printf 'c\n' > "$pool/1/repo/ignored.log"
  # An ignored directory whose pattern ends in a slash: git DESCENDS into it
  # and reports the file.
  mkdir -p "$pool/1/repo/ignored-dir"
  printf 'd\n' > "$pool/1/repo/ignored-dir/inside.txt"
  # An ignored directory whose pattern does NOT end in a slash: git reports the
  # DIRECTORY as one entry and does not recurse.  A list built only from git's
  # entries therefore misses the file inside it - which is exactly the hole the
  # live pool had.
  mkdir -p "$pool/1/repo/ignored-dir2"
  printf 'e\n' > "$pool/1/repo/ignored-dir2/inner.txt"

  # slot 6: two commits that are NOT in origin/main.
  git -C "$pool/6/repo" commit -q --allow-empty -m "unmerged one"
  git -C "$pool/6/repo" commit -q --allow-empty -m "unmerged two"

  # The lane records.
  mk_meta "$state" lane-slot-1  "$pool/1/repo"  w-dead
  mk_meta "$state" lane-slot-2  "$pool/2/repo"  w-live
  mk_meta "$state" lane-slot-3  "$pool/3/repo"  w-dead
  mk_meta "$state" lane-slot-4  "$pool/4/repo"  w-dead
  mk_meta "$state" lane-slot-5  "$pool/5/repo"  w-dead
  mk_meta "$state" lane-slot-6  "$pool/6/repo"  w-dead
  mk_meta "$state" lane-slot-7  "$pool/7/repo"  w-unknown
  mk_meta "$state" lane-slot-8  "$pool/8/repo"  w-dead
  # slot 9 deliberately has NO lane record.
  mk_meta "$state" lane-slot-10 "$pool/10/repo" w-dead

  # The task logs.  slot 8 deliberately has NO task log.
  mk_log "$state" lane-slot-1  "done: the lane finished and its pane is dead"
  mk_log "$state" lane-slot-2  "done: the lane finished but its pane still runs the worker"
  mk_log "$state" lane-slot-3  "working: the lane is still working"
  mk_log "$state" lane-slot-4  "blocked: waiting on a decision that will never arrive"
  mk_log "$state" lane-slot-5  "done: finished, but the ledger says the lane is blocked"
  mk_log "$state" lane-slot-6  "done: finished with unmerged commits"
  mk_log "$state" lane-slot-7  "done: finished, but the pane state cannot be read"
  mk_log "$state" lane-slot-9  "done: finished, but no lane record names this slot"
  mk_log "$state" lane-slot-10 "resolved [key=core-session-lock-repair-20261023]: cleared"

  # The ledger.  lane-slot-5 is BLOCKED there.
  {
    printf '# lane-ledger.tsv\n'
    printf 'lane_id\tstate\towner\topened\tupdated\texpires\tnext\tartifact\tbranch\n'
    printf 'lane-slot-5\tBLOCKED\tsomeone\t2026-10-24T00:00:00Z\t2026-10-24T00:00:00Z\t\twaiting\t-\t-\n'
  } > "$root/ops/lane-ledger.tsv"

  # The pool inventory the fake treehouse serves.
  {
    printf '[\n'
    local first=1
    for n in 1 2 3 4 5 6 7 8 9 10; do
      [ $first -eq 1 ] || printf ',\n'
      first=0
      printf '  {"name":"%s","path":"%s","status":"in-use","branch":"","detached":true,"flavor":"git","lease_id":"","lease_holder":"","leased_at":null,"processes":[]}' \
        "$n" "$pool/$n/repo"
    done
    printf '\n]\n'
  } > "$root/pool.json"

  # The fake treehouse: status serves the inventory, return records the call.
  cat > "$fake/treehouse" <<'FAKE_TREEHOUSE'
#!/usr/bin/env bash
set -uo pipefail
cmd=${1:-}
case "$cmd" in
  status)
    cat "$FM_FAKE_POOL_JSON"
    ;;
  return)
    shift
    path=""
    expect_value=0
    for a in "$@"; do
      if [ "$expect_value" = "1" ]; then expect_value=0; continue; fi
      case "$a" in
        --if-lease-id|--if-lease-holder) expect_value=1 ;;
        -*) : ;;
        *) path=$a ;;
      esac
    done
    printf 'return\t%s\t%s\n' "$path" "$*" >> "$FM_FAKE_TREEHOUSE_LOG"
    python3 - "$FM_FAKE_POOL_JSON" "$path" <<'PY'
import json, sys
p, path = sys.argv[1], sys.argv[2]
d = json.load(open(p))
for x in d:
    if x["path"] == path:
        x["status"] = "available"
        x["lease_id"] = ""
        x["lease_holder"] = ""
json.dump(d, open(p, "w"))
PY
    printf 'returned %s\n' "$path"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
FAKE_TREEHOUSE
  chmod 755 "$fake/treehouse"

  # The pane oracle: 0 alive, 1 dead, 2 unknown.
  cat > "$fake/pane-probe" <<'FAKE_PANE'
#!/usr/bin/env bash
case "${1:-}" in
  w-dead) exit 1 ;;
  w-live) exit 0 ;;
  w-unknown) exit 2 ;;
esac
exit 2
FAKE_PANE
  chmod 755 "$fake/pane-probe"

  # The broken tar: it reproduces the "-C after -T" bug by ALWAYS writing an
  # empty archive.  The script's entry-count check must catch it.
  if [ "$broken" = "1" ]; then
    cat > "$fake/tar" <<'FAKE_TAR'
#!/usr/bin/env bash
set -uo pipefail
if [ "${1:-}" = "-czf" ]; then
  gzip -c </dev/null > "$2"
  exit 0
fi
exec /usr/bin/tar "$@"
FAKE_TAR
    chmod 755 "$fake/tar"
  fi

  : > "$root/treehouse.log"
}

mk_meta() {  # <state-dir> <task-id> <worktree> <window>
  cat > "$1/$2.meta" <<EOF
endpoint_task_id=$2
window=$4
backend=herdr
herdr_pane_id=$4
model=minimax/MiniMax-M3.1-Flash
harness=minimax-code
worktree=$3
EOF
}

mk_log() {  # <state-dir> <task-id> <line>
  printf '%s\n' "$3" > "$1/$2.status"
}

# run_reaper <root> <script> [mode]
run_reaper() {  # <root> <script> [apply|dry]
  local root=$1 script=$2 mode=${3:-apply}
  local -a args=()
  [ "$mode" = "apply" ] && args+=(--apply)
  env \
    FM_REAP_POOL="$root/pool" \
    FM_REAP_STATE="$root/state" \
    FM_REAP_LEDGER="$root/ops/lane-ledger.tsv" \
    FM_REAP_PRESERVE_DIR="$root/preserve" \
    FM_REAP_TREEHOUSE="$root/fakebin/treehouse" \
    FM_REAP_PANE_PROBE="$root/fakebin/pane-probe" \
    FM_REAP_BASE_REF="origin/main" \
    FM_REAP_LOCK_FILE="$root/reap.lock" \
    FM_FAKE_POOL_JSON="$root/pool.json" \
    FM_FAKE_TREEHOUSE_LOG="$root/treehouse.log" \
    FM_ROOT_OVERRIDE="$ROOT" \
    PATH="$root/fakebin:$PATH" \
    bash "$script" "${args[@]+"${args[@]}"}" > "$root/out.txt" 2>&1
  return $?
}

returned_slot() {  # <root> <slot-number> -> 0 when that slot was returned
  grep -q "return	$1/pool/$2/repo" "$1/treehouse.log" 2>/dev/null
}

# snapshot_tree <dir> - the complete inventory of a directory tree: every
# path, and the content hash of every file.  "The dry run wrote nothing" is
# then a comparison of two snapshots, not a promise.
snapshot_tree() {  # <dir>
  local dir=$1 f
  if [ ! -d "$dir" ]; then
    printf 'ABSENT %s\n' "$dir"
    return 0
  fi
  (
    cd "$dir" 2>/dev/null || exit 0
    find . -mindepth 1 \( -type d -printf 'DIR  %p\n' -o -type f -printf 'FILE %p\n' \) 2>/dev/null \
      | LC_ALL=C sort
    find . -mindepth 1 -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
      printf 'HASH %s %s\n' "$f" "$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)"
    done
  )
}

# =============================================================================
# (a) the main run
# =============================================================================

test_main_run_reclaims_only_the_proven_safe_slot() {
  local root
  root=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root" 0

  run_reaper "$root" "$SCRIPT_UNDER_TEST" apply
  local rc=$?
  assert_ok "$([ $rc -eq 0 ] && echo 0 || echo 1)" "the reaper exits 0 on a clean fixture"

  # (a) terminal verb + dead pane -> reclaimed.
  returned_slot "$root" 1
  assert_ok "$?" "a lane with a terminal verb and a dead pane IS reclaimed"

  # The real terminal line `resolved [key=...]: ...` is terminal too.
  returned_slot "$root" 10
  assert_ok "$?" "a lane whose log ends 'resolved [key=...]: ...' IS reclaimed"

  # (b) terminal verb + live pane -> NOT.
  ! returned_slot "$root" 2
  assert_ok "$?" "a lane with a terminal verb but a LIVE pane is NOT reclaimed"

  # (c) no terminal verb -> NOT.
  ! returned_slot "$root" 3
  assert_ok "$?" "a lane with NO terminal verb is NOT reclaimed"

  # (d) blocked -> NOT, by the status verb and by the ledger.
  ! returned_slot "$root" 4
  assert_ok "$?" "a lane whose status says 'blocked' is NOT reclaimed"
  ! returned_slot "$root" 5
  assert_ok "$?" "a lane whose LEDGER state is BLOCKED is NOT reclaimed"
  grep -q 'live work' "$root/out.txt"
  assert_ok "$?" "the report says a blocked lane is live work"

  # Unknown fails closed.
  ! returned_slot "$root" 7
  assert_ok "$?" "a lane whose pane state is UNKNOWN is NOT reclaimed"
  ! returned_slot "$root" 8
  assert_ok "$?" "a lane with NO task log is NOT reclaimed"
  ! returned_slot "$root" 9
  assert_ok "$?" "a slot with NO lane record is NOT reclaimed"

  # The report says why, and the counts are reported.
  grep -q 'SKIP' "$root/out.txt"
  assert_ok "$?" "the report lists the skipped slots"
  grep -q 'records_before=' "$root/out.txt" && grep -q 'records_after=' "$root/out.txt"
  assert_ok "$?" "the report states the pool record count before and after"
  grep -q 'ceiling=' "$root/out.txt"
  assert_ok "$?" "the report states the pool ceiling"

  # (e) the unmerged-commit slot: the bundle must carry the branch.
  returned_slot "$root" 6
  assert_ok "$?" "a slot whose branch holds unmerged commits IS reclaimed (after preservation)"
  local bundle bundle_ok=0
  bundle=$(find "$root/preserve" -name '*lane-slot-6*.bundle' 2>/dev/null | head -1)
  [ -n "$bundle" ] || bundle_ok=1
  assert_ok "$bundle_ok" "a bundle was created for the unmerged-commit slot"
  git -C "$root/repo" bundle verify "$bundle" >/dev/null 2>&1
  assert_ok "$?" "the bundle VERIFIES"
  git -C "$root/repo" bundle list-heads "$bundle" 2>/dev/null | grep -q 'refs/heads/fm/lane-slot-6$'
  assert_ok "$?" "the bundle CARRIES the unmerged branch"

  # The preserved files survive, and the tar is the right size.
  local tarball tar_ok=0 tar_count=0
  tarball=$(find "$root/preserve" -name '*slot-1*files.tar.gz' 2>/dev/null | head -1)
  [ -n "$tarball" ] || tar_ok=1
  assert_ok "$tar_ok" "a tar of the slot's untracked+ignored files was created"
  [ -n "$tarball" ] && tar_count=$(tar -tzf "$tarball" 2>/dev/null | wc -l | tr -d ' ')
  local tar_count_ok=0
  # The contract's own check, computed from the artifacts: the number of
  # archive entries equals the number of listed paths.
  local listcount=0
  local listfile2
  listfile2=$(find "$root/preserve" -name '*slot-1*.filelist' 2>/dev/null | head -1)
  [ -n "$listfile2" ] && listcount=$(tr -cd '\0' < "$listfile2" | wc -c | tr -d ' ')
  [ "$tar_count" = "$listcount" ] || tar_count_ok=1
  assert_ok "$tar_count_ok" "the archive entry count equals the listed path count"
  tar -tzf "$tarball" 2>/dev/null | grep -q 'untracked-a.txt'
  assert_ok "$?" "the tar holds the untracked file"
  tar -tzf "$tarball" 2>/dev/null | grep -q 'ignored.log'
  assert_ok "$?" "the tar holds the ignored file"
  tar -tzf "$tarball" 2>/dev/null | grep -q 'ignored-dir/inside.txt'
  assert_ok "$?" "the tar holds the file inside an ignored directory"
  tar -tzf "$tarball" 2>/dev/null | grep -q 'ignored-dir2/inner.txt'
  assert_ok "$?" "the tar holds the file inside an ignored DIRECTORY git reported as one entry"
  # Completeness: every path git reported is in the reaper's file list, and the
  # archive holds EXACTLY the listed paths.  This is the hole the live pool had:
  # five ignored paths were dropped from the list, and the entry-count check
  # could not see it because it compared the archive against the same list.
  local gitlist listfile tarlist miss=0 e
  gitlist=$(mktemp)
  listfile=$(find "$root/preserve" -name '*slot-1*.filelist' 2>/dev/null | head -1)
  tarlist=$(mktemp)
  {
    git -C "$root/pool/1/repo" ls-files --others --exclude-standard
    git -C "$root/pool/1/repo" ls-files --others --ignored --exclude-standard
  } | LC_ALL=C sort -u > "$gitlist"
  if [ -n "$listfile" ] && [ -n "$tarball" ]; then
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      tr '\0' '\n' < "$listfile" | grep -Fxq "$e" || miss=1
    done < "$gitlist"
    tr '\0' '\n' < "$listfile" | LC_ALL=C sort -u > "$tarlist"
    tar -tzf "$tarball" 2>/dev/null | LC_ALL=C sort -u > "$tarlist.archive"
    cmp -s "$tarlist" "$tarlist.archive" || miss=1
  else
    miss=1
  fi
  assert_ok "$miss" "every path git reported is in the list, and the archive holds exactly the listed paths"

  # Nothing was deleted: the moved copy is still on disk.
  local moved_ok=0
  [ -f "$root/preserve/moved/slot-1-repo/untracked-a.txt" ] || \
    [ -f "$root/preserve/moved/slot-1/untracked-a.txt" ] || moved_ok=1
  assert_ok "$moved_ok" "the untracked file was moved out of the slot, not deleted"

  # The slot was made clean, not forced.
  [ -z "$(git -C "$root/pool/1/repo" status --porcelain 2>/dev/null)" ]
  assert_ok "$?" "the reclaimed slot is clean (no force flag was needed)"

  fm_reap_test_trash "$root" >/dev/null 2>&1
}

# =============================================================================
# (f) the empty-archive check
# =============================================================================

test_empty_archive_is_caught() {
  local root
  root=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root" 1

  run_reaper "$root" "$SCRIPT_UNDER_TEST" apply
  local rc=$?
  assert_ok "$([ $rc -eq 0 ] && echo 0 || echo 1)" "the reaper still exits 0 when the tar is broken"

  ! returned_slot "$root" 1
  assert_ok "$?" "an EMPTY archive stops the reclaim"
  grep -q 'count-mismatch' "$root/out.txt"
  assert_ok "$?" "the report says the archive entry count did not match the file count"

  fm_reap_test_trash "$root" >/dev/null 2>&1
}

# =============================================================================
# red capability: every guard is load-bearing
# =============================================================================

# mutate <root> <name> <sed-expression>
mutate() {  # <root> <name> <sed-expr>
  local root=$1 name=$2 expr=$3
  mkdir -p "$root/$name/bin"
  sed "$expr" "$SCRIPT_UNDER_TEST" > "$root/$name/bin/fm-reap-finished-lanes.sh"
  chmod 755 "$root/$name/bin/fm-reap-finished-lanes.sh"
  if cmp -s "$SCRIPT_UNDER_TEST" "$root/$name/bin/fm-reap-finished-lanes.sh"; then
    printf 'MUTATION DID NOT APPLY: %s\n' "$name" >&2
    return 1
  fi
  return 0
}

test_mutants_are_caught() {
  local root

  # The terminal-verb guard.  It is the ONE gate that decides terminality, so
  # removing it must let BOTH the "working" lane and the "blocked" lane through:
  # `blocked` is excluded by the terminal set, not by a second redundant gate.
  root=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root" 0
  # The `$verb` below is the LITERAL text of the script under test: this sed
  # expression matches the source line, so the dollar sign must NOT expand.
  # shellcheck disable=SC2016
  if mutate "$root" m1 's#if ! fm_reap_is_reclaim_terminal_verb "$verb"; then#if false; then#'; then
    run_reaper "$root" "$root/m1/bin/fm-reap-finished-lanes.sh" apply
    returned_slot "$root" 3
    assert_ok "$?" "MUTANT: removing the terminal-verb guard reclaims the 'working' lane (the guard is load-bearing)"
    returned_slot "$root" 4
    assert_ok "$?" "MUTANT: removing the terminal-verb guard also reclaims the 'blocked' lane (blocked is excluded BY the terminal set)"
  else
    fail "MUTATION DID NOT APPLY: the terminal-verb guard"
  fi
  fm_reap_test_trash "$root" >/dev/null 2>&1

  # The ledger-BLOCKED guard.
  root=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root" 0
  # The `$lane_state` is the LITERAL text of the script under test, so the
  # dollar sign must NOT expand.
  # shellcheck disable=SC2016
  if mutate "$root" m3 's#if \[ "$lane_state" = "BLOCKED" \]; then#if false; then#'; then
    run_reaper "$root" "$root/m3/bin/fm-reap-finished-lanes.sh" apply
    returned_slot "$root" 5
    assert_ok "$?" "MUTANT: removing the ledger-BLOCKED guard reclaims the ledger-blocked lane (the guard is load-bearing)"
  else
    fail "MUTATION DID NOT APPLY: the ledger-BLOCKED guard"
  fi
  fm_reap_test_trash "$root" >/dev/null 2>&1

  # The pane guard.
  root=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root" 0
  # The `$pane_state` is the LITERAL text of the script under test, so the
  # dollar sign must NOT expand.
  # shellcheck disable=SC2016
  if mutate "$root" m4 's#if \[ "$pane_state" != "1" \]; then#if false; then#'; then
    run_reaper "$root" "$root/m4/bin/fm-reap-finished-lanes.sh" apply
    returned_slot "$root" 2
    assert_ok "$?" "MUTANT: removing the pane guard reclaims the live-pane lane (the guard is load-bearing)"
  else
    fail "MUTATION DID NOT APPLY: the pane guard"
  fi
  fm_reap_test_trash "$root" >/dev/null 2>&1

  # The tar count check.
  root=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root" 1
  # The `$entries` and `$listed` are the LITERAL text of the script under
  # test, so the dollar signs must NOT expand.
  # shellcheck disable=SC2016
  if mutate "$root" m5 's#if \[ "$entries" != "$listed" \]; then#if false; then#'; then
    run_reaper "$root" "$root/m5/bin/fm-reap-finished-lanes.sh" apply
    returned_slot "$root" 1
    assert_ok "$?" "MUTANT: removing the tar count check reclaims a slot with an EMPTY archive (the check is load-bearing)"
  else
    fail "MUTATION DID NOT APPLY: the tar count check"
  fi
  fm_reap_test_trash "$root" >/dev/null 2>&1

  # The preservation step.
  root=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root" 0
  # The `$path`, `$label`, `$task` and `$preserve_dir` are the LITERAL text
  # of the script under test, so the dollar signs must NOT expand.
  # shellcheck disable=SC2016
  if mutate "$root" m6 's#pres=$(fm_reap_preserve "$path" "$label" "$task" "$preserve_dir" 2>&1)#pres="bundle=SKIPPED"#'; then
    run_reaper "$root" "$root/m6/bin/fm-reap-finished-lanes.sh" apply
    local bundle
    bundle=$(find "$root/preserve" -name '*lane-slot-6*.bundle' 2>/dev/null | head -1)
    if [ -z "$bundle" ] && returned_slot "$root" 6; then
      ASSERTIONS=$((ASSERTIONS + 1))
      pass "MUTANT: removing the preservation step reclaims an unmerged slot with NO bundle (the step is load-bearing)"
    else
      fail "MUTANT: removing the preservation step did not reclaim the unmerged slot without a bundle (the step is not load-bearing)"
    fi
  else
    fail "MUTATION DID NOT APPLY: the preservation step"
  fi
  fm_reap_test_trash "$root" >/dev/null 2>&1

  # The dry-run guard.  Removing it must make the dry run WRITE: the mutant
  # has to create the bundle and the tar, because writing in a dry run is
  # exactly what the guard exists to prevent.
  root=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root" 0
  # The `$APPLY` is the LITERAL text of the script under test, so the dollar
  # sign must NOT expand.
  # shellcheck disable=SC2016
  if mutate "$root" m7 's#if \[ "$APPLY" != "1" \]; then#if false; then#'; then
    run_reaper "$root" "$root/m7/bin/fm-reap-finished-lanes.sh" dry
    local drybundle drytar
    drybundle=$(find "$root/preserve" -name '*.bundle' 2>/dev/null | head -1)
    drytar=$(find "$root/preserve" -name '*files.tar.gz' 2>/dev/null | head -1)
    if [ -n "$drybundle" ] && [ -n "$drytar" ]; then
      ASSERTIONS=$((ASSERTIONS + 1))
      pass "MUTANT: removing the dry-run guard makes the dry run WRITE a bundle and a tar (the guard is load-bearing)"
    else
      fail "MUTANT: removing the dry-run guard did not make the dry run write (the guard is not load-bearing)"
      find "$root/preserve" 2>/dev/null | head -20 >&2
    fi
  else
    fail "MUTATION DID NOT APPLY: the dry-run guard"
  fi
  fm_reap_test_trash "$root" >/dev/null 2>&1
}

# =============================================================================
# the verb grammar and the dry run
# =============================================================================

test_terminal_verb_grammar() {
  local root
  root=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root" 0

  run_reaper "$root" "$SCRIPT_UNDER_TEST" dry
  local rc=$?
  assert_ok "$([ $rc -eq 0 ] && echo 0 || echo 1)" "the dry run exits 0"
  [ ! -s "$root/treehouse.log" ]
  assert_ok "$?" "the dry run returns NO slot"
  grep -q 'mode=dry-run' "$root/out.txt"
  assert_ok "$?" "the dry run says it is a dry run"
  grep -q 'CANDIDATE' "$root/out.txt"
  assert_ok "$?" "the dry run reports the candidates it would reclaim"

  fm_reap_test_trash "$root" >/dev/null 2>&1
}

# =============================================================================
# (g) the dry run writes nothing
# =============================================================================

test_dry_run_writes_nothing() {
  local root before after rc same=0 gone=0
  root=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root" 0

  before=$(snapshot_tree "$root")

  # The dry run, with NO FM_REAP_LOCK_FILE: the script must not create a
  # lock file in the state directory either.  Its output goes OUTSIDE the
  # fixture tree, so the tree itself can be compared before and after.
  env \
    FM_REAP_POOL="$root/pool" \
    FM_REAP_STATE="$root/state" \
    FM_REAP_LEDGER="$root/ops/lane-ledger.tsv" \
    FM_REAP_PRESERVE_DIR="$root/preserve" \
    FM_REAP_TREEHOUSE="$root/fakebin/treehouse" \
    FM_REAP_PANE_PROBE="$root/fakebin/pane-probe" \
    FM_REAP_BASE_REF="origin/main" \
    FM_FAKE_POOL_JSON="$root/pool.json" \
    FM_FAKE_TREEHOUSE_LOG="$root/treehouse.log" \
    FM_ROOT_OVERRIDE="$ROOT" \
    PATH="$root/fakebin:$PATH" \
    bash "$SCRIPT_UNDER_TEST" > "$root.out.txt" 2>&1
  rc=$?

  after=$(snapshot_tree "$root")

  assert_ok "$([ $rc -eq 0 ] && echo 0 || echo 1)" "the dry run exits 0"

  # THE PURITY ASSERTION.  The whole fixture tree - every file, with every
  # content hash - is the same before and after.  Not "the important files
  # are unchanged": the tree.
  [ "$before" = "$after" ] || same=1
  assert_ok "$same" "the dry run created NO file and changed NO file anywhere under the fixture tree"
  if [ "$same" != "0" ]; then
    printf '  --- before ---\n%s\n  --- after ---\n%s\n' "$before" "$after" >&2
  fi

  [ ! -e "$root/preserve" ] || gone=1
  assert_ok "$gone" "the dry run did not even create the preserve directory"

  gone=0
  [ ! -e "$root/preserve/slot-1-repo.all-refs.bundle" ] || gone=1
  assert_ok "$gone" "the dry run created no bundle"

  gone=0
  [ ! -e "$root/preserve/slot-1-repo-files.tar.gz" ] || gone=1
  assert_ok "$gone" "the dry run created no tar"

  gone=0
  [ ! -e "$root/preserve/slot-1-repo.filelist" ] || gone=1
  assert_ok "$gone" "the dry run created no file list"

  gone=0
  [ ! -e "$root/state/lane-slot-1.fm-reaped" ] || gone=1
  assert_ok "$gone" "the dry run wrote no lane marker"

  gone=0
  [ ! -e "$root/state/.fm-reap-finished-lanes.lock" ] || gone=1
  assert_ok "$gone" "the dry run created no lock file in the state directory"

  gone=0
  [ ! -s "$root/treehouse.log" ] || gone=1
  assert_ok "$gone" "the dry run returned no slot"

  # A dry run that reports nothing is useless: the counts it WOULD have
  # preserved are still printed.
  grep -q 'WOULD-CREATE' "$root.out.txt"
  assert_ok "$?" "the dry run says what it would create"

  grep -qE 'files=[0-9]+ entries=[0-9]+ bytes=[0-9]+' "$root.out.txt"
  assert_ok "$?" "the dry run reports the file count, the entry count and the byte count"

  grep -qE 'files=[1-9][0-9]* entries=[1-9][0-9]* bytes=[1-9][0-9]*' "$root.out.txt"
  assert_ok "$?" "the dry run reports a non-zero file, entry and byte count for the slot that has files"

  grep -q 'CANDIDATE' "$root.out.txt"
  assert_ok "$?" "the dry run still reports the candidate it would reclaim"

  grep -q 'lane-slot-1' "$root.out.txt"
  assert_ok "$?" "the dry run names the lane it would reclaim"

  # And the dry run's counts are the apply run's counts: the same fixture,
  # run for real, archives exactly what the dry run said it would.
  local root2 real_files real_entries dry_files dry_entries
  root2=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root2" 0
  run_reaper "$root2" "$SCRIPT_UNDER_TEST" apply
  real_files=$(grep -oE 'files=[0-9]+' "$root2/out.txt" 2>/dev/null | head -1 | cut -d= -f2)
  real_entries=$(grep -oE 'entries=[0-9]+' "$root2/out.txt" 2>/dev/null | head -1 | cut -d= -f2)
  dry_files=$(grep -oE 'files=[0-9]+' "$root.out.txt" 2>/dev/null | head -1 | cut -d= -f2)
  dry_entries=$(grep -oE 'entries=[0-9]+' "$root.out.txt" 2>/dev/null | head -1 | cut -d= -f2)
  [ -n "$dry_files" ] && [ "$dry_files" = "$real_files" ]
  assert_ok "$?" "the dry run's file count equals the apply run's archived file count"

  [ -n "$dry_entries" ] && [ "$dry_entries" = "$real_entries" ]
  assert_ok "$?" "the dry run's entry count equals the apply run's archive entry count"

  fm_reap_test_trash "$root" >/dev/null 2>&1
  fm_reap_test_trash "$root2" >/dev/null 2>&1
}

test_lock_prevents_overlap() {
  local root
  root=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root" 0

  mkdir -p "$root"
  exec 8>"$root/reap.lock"
  flock -n 8 || true
  local out
  out=$(env \
    FM_REAP_POOL="$root/pool" \
    FM_REAP_STATE="$root/state" \
    FM_REAP_LEDGER="$root/ops/lane-ledger.tsv" \
    FM_REAP_PRESERVE_DIR="$root/preserve" \
    FM_REAP_TREEHOUSE="$root/fakebin/treehouse" \
    FM_REAP_PANE_PROBE="$root/fakebin/pane-probe" \
    FM_REAP_BASE_REF="origin/main" \
    FM_REAP_LOCK_FILE="$root/reap.lock" \
    FM_FAKE_POOL_JSON="$root/pool.json" \
    FM_FAKE_TREEHOUSE_LOG="$root/treehouse.log" \
    FM_ROOT_OVERRIDE="$ROOT" \
    bash "$SCRIPT_UNDER_TEST" --apply 2>&1)
  local rc=$?
  [ "$rc" = "3" ]
  assert_ok "$?" "a second run refuses to start while the lock is held (exit 3)"
  printf '%s' "$out" | grep -q 'another run holds the lock'
  assert_ok "$?" "the refused run says the lock is held"
  exec 8>&-

  fm_reap_test_trash "$root" >/dev/null 2>&1
}


# =============================================================================
# idempotency: a second run is a no-op
# =============================================================================

test_reaper_is_idempotent() {
  local root
  root=$(mktemp -d /tmp/fm-reap-test.XXXXXX)
  build_fixture "$root" 0

  run_reaper "$root" "$SCRIPT_UNDER_TEST" apply
  returned_slot "$root" 1
  assert_ok "$?" "the first run reclaims the proven-safe slot"

  [ -f "$root/state/lane-slot-1.fm-reaped" ]
  assert_ok "$?" "the first run writes the lane's reaped marker"

  : > "$root/treehouse.log"
  run_reaper "$root" "$SCRIPT_UNDER_TEST" apply
  ! returned_slot "$root" 1
  assert_ok "$?" "a second run does NOT reclaim the same lane again"
  grep -q 'already reclaimed by this reaper' "$root/out.txt"
  assert_ok "$?" "the second run says the lane was already reclaimed"

  fm_reap_test_trash "$root" >/dev/null 2>&1
}

# =============================================================================

for _t in \
  test_main_run_reclaims_only_the_proven_safe_slot \
  test_empty_archive_is_caught \
  test_mutants_are_caught \
  test_terminal_verb_grammar \
  test_dry_run_writes_nothing \
  test_lock_prevents_overlap \
  test_reaper_is_idempotent; do
  "$_t" || { echo "FAIL: $_t"; exit 1; }
done

printf '# fm-reap-finished-lanes.test.sh: %s assertions passed\n' "$ASSERTIONS"
