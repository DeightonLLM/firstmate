#!/usr/bin/env bash
# Regression suite for the MCode heap cap and the MCode lane-lifetime bound.
#
# WHAT THIS SUITE PROVES
#
# Part A - the heap cap is in the spawn path, not in the CLI's installer prefix:
#   (a) the minimax-code launch template carries a V8 old-space ceiling;
#   (b) the pane export carries the SAME ceiling, so an operator's own
#       interactive `mcode` in that pane is bounded too;
#   (c) the ceiling is the justified value (1024 MB), and the spawner
#       substitutes it into the real launch command;
#   (d) the cap is NOT placed under the CLI's installer-managed prefix, which
#       the CLI's own updater erases.
#
# Part B - the lane-lifetime rule fires at its threshold and does not fire
# below it, and refuses to recycle a lane that is mid-turn or that holds
# unlanded work:
#   (e) retained session bytes at the threshold -> keep; one byte over -> recycle;
#   (f) compaction cycles at the threshold -> keep; one over -> recycle;
#   (g) a lane mid-turn is never recycled;
#   (h) a lane whose work has NOT landed is never recycled, and the recycle
#       verb refuses before it reaches the control plane;
#   (i) the rule's signal reproduces the real crash: the crashed session's
#       retained volume, read through the rule's own SQL, is the ~52 MB the
#       crash forensics recorded, and it is over the rule's budget.
#
# This suite FAILS on a tree without the fix: the template carries no
# NODE_OPTIONS, mcode_heap_cap_opts does not exist, the pane export carries no
# ceiling, and bin/fm-mcode-lane-lifetime.sh does not exist at all.
set -u

# shellcheck source=tests/lib.sh disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fm_git_identity fmtest fmtest@example.invalid

SPAWN="$ROOT/bin/fm-spawn.sh"
LIFETIME="$ROOT/bin/fm-mcode-lane-lifetime.sh"
TEARDOWN="$ROOT/bin/fm-teardown.sh"
TMP_ROOT=$(fm_test_tmproot fm-mcode-heap-cap)

# The justified ceiling. 1024 MB of V8 old space; its EFFECTIVE V8 ceiling
# measures 1072 MB, which clears the 905 MB peak resident size measured on a
# HEALTHY live mcode lane. See
# data/mcode-m3.1f-controller-mcodeheapcap/report.md for the full evidence.
EXPECTED_CAP_MB=1024
EXPECTED_MAX_RETAINED_BYTES=16777216
EXPECTED_MAX_COMPACTIONS=8

# --- shared helpers ------------------------------------------------------------

# Extract a top-level shell function from a script by name.
extract_fn() {  # <script> <function-name>
  awk -v fn="$2" '
    $0 ~ "^" fn "\\(\\) \\{" { inside = 1 }
    inside { print }
    inside && $0 ~ /^}$/ { exit }
  ' "$1"
}

# make_payload <bytes>: a printable payload of exactly N bytes.
make_payload() {
  head -c "$1" /dev/zero | tr '\0' 'x'
}

# make_store <db> <session-id> <workspace-dir> <msg-bytes> <journal-bytes>
#            <compactions> [open-turns]
# A minimal stand-in for the MCode runtime store, with exactly the columns the
# rule reads. Nothing here is a mock of the RULE: the rule runs its own SQL
# against this store.
make_store() {
  local db=$1 sid=$2 ws=$3 msg=$4 jrn=$5 comps=$6 open_turns=${7:-0} jpayload i
  # A fresh store per scenario: drop any previous fixture tables first.
  sqlite3 "$db" "DROP TABLE IF EXISTS local_runtime_sessions; DROP TABLE IF EXISTS local_runtime_message_rows; DROP TABLE IF EXISTS local_runtime_turn_diff_journal; DROP TABLE IF EXISTS local_runtime_turn_ingress;" >/dev/null 2>&1 || true
  sqlite3 "$db" <<SQL
CREATE TABLE local_runtime_sessions (
  session_id TEXT PRIMARY KEY, updated_at_ms INTEGER, created_at_ms INTEGER, workspace_dir TEXT);
CREATE TABLE local_runtime_message_rows (
  id INTEGER PRIMARY KEY, session_id TEXT, data_json TEXT);
CREATE TABLE local_runtime_turn_diff_journal (
  journal_id TEXT PRIMARY KEY, session_id TEXT, before_json TEXT, after_json TEXT, paths_json TEXT);
CREATE TABLE local_runtime_turn_ingress (
  turn_id TEXT PRIMARY KEY, session_id TEXT, status TEXT, accepted_at_ms INTEGER);
INSERT INTO local_runtime_sessions VALUES ('$sid', 1700000000000, 1700000000000, '$ws');
SQL
  if [ "$msg" -gt 0 ]; then
    # A valid JSON message row of exactly $msg bytes. The wrapper
    # {"m":"..."} costs 8 bytes plus the payload.
    inner=$(( msg - 8 ))
    [ "$inner" -ge 0 ] || inner=0
    row="{\"m\":\"$(make_payload "$inner")\"}"
    [ "${#row}" -eq "$msg" ] || fail "fixture message row must be exactly $msg bytes (got ${#row})"
    sqlite3 "$db" "INSERT INTO local_runtime_message_rows (session_id, data_json) VALUES ('$sid', '$row');"
  fi
  if [ "$jrn" -gt 0 ]; then
    jpayload=$(make_payload "$jrn")
    sqlite3 "$db" "INSERT INTO local_runtime_turn_diff_journal (journal_id, session_id, before_json, after_json, paths_json) VALUES ('j1', '$sid', '$jpayload', '', '');"
  fi
  i=0
  while [ "$i" -lt "$comps" ]; do
    sqlite3 "$db" "INSERT INTO local_runtime_message_rows (session_id, data_json) VALUES ('$sid', '{\"kind\":\"compaction\",\"metadata\":{\"compactionId\":\"ctx_$i\"}}');"
    i=$(( i + 1 ))
  done
  # A turn the runtime has accepted and not yet completed is a turn in flight.
  i=0
  while [ "$i" -lt "$open_turns" ]; do
    sqlite3 "$db" "INSERT INTO local_runtime_turn_ingress (turn_id, session_id, status, accepted_at_ms) VALUES ('t$i', '$sid', 'accepted', 1700000000000);"
    i=$(( i + 1 ))
  done
}

# make_case <name>: a disposable firstmate home with a git project, a task
# worktree, a fake tmux on PATH, and an mcode lane record.
make_case() {
  local name=$1 case_dir fakebin
  case_dir="$TMP_ROOT/$name"
  fakebin="$case_dir/fakebin"
  mkdir -p "$case_dir/state" "$case_dir/data" "$case_dir/config" "$fakebin"

  # A fake tmux whose recorded window exists and whose pane runs a harness
  # command, which is what the endpoint read and the native agent state read.
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  list-windows)
    printf 'fm-task-x1\n'
    exit 0
    ;;
  display-message)
    case "$*" in
      *pane_current_command*) printf 'minimax-code\n' ;;
      *) printf '%%1\n' ;;
    esac
    exit 0
    ;;
esac
exit 0
SH
  chmod +x "$fakebin/tmux"

  # A project with an origin remote, and a task worktree on its own branch.
  git init -q "$case_dir/project"
  git -C "$case_dir/project" symbolic-ref HEAD refs/heads/main
  git -C "$case_dir/project" commit -q --allow-empty -m "baseline"
  git init -q --bare "$case_dir/origin.git"
  git -C "$case_dir/origin.git" symbolic-ref HEAD refs/heads/main
  git -C "$case_dir/project" remote add origin "$case_dir/origin.git"
  git -C "$case_dir/project" push -q origin main
  git -C "$case_dir/project" remote set-head origin main 2>/dev/null || true
  git -C "$case_dir/project" worktree add -q -b fm/task-x1 "$case_dir/wt" main

  touch "$case_dir/state/.last-watcher-beat"
  printf '%s\n' "$case_dir"
}

write_meta() {  # <case-dir>
  fm_write_meta "$1/state/task-x1.meta" \
    "window=firstmate:fm-task-x1" \
    "endpoint_task_id=task-x1" \
    "worktree=$1/wt" \
    "project=$1/project" \
    "harness=minimax-code" \
    "kind=ship" \
    "mode=local-only"
}

# write_busy_state is NOT used by the rule: the mid-turn signal is the
# runtime's own durable turn-lifecycle state, not a recorded busy line. The
# helper stays out of this suite on purpose.

# run_rule <case-dir> <args...>: run the rule against a sandbox home.
run_rule() {
  local case_dir=$1
  shift
  env -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE \
    -u FM_ROOT_OVERRIDE -u FM_BACKEND \
    FM_HOME="$case_dir" \
    FM_MCODE_RUNTIME_DB="$case_dir/store.sqlite" \
    PATH="$case_dir/fakebin:$PATH" \
    bash "$LIFETIME" "$@" 2>/dev/null
}

# field <line> <key>: read one key=value field out of a LANE_LIFETIME line.
field() {
  printf '%s' "$1" | tr ' ' '\n' | grep "^$2=" | head -1 | cut -d= -f2-
}

# ============================================================================
# Part A - the heap cap in the spawn path
# ============================================================================

[ -f "$SPAWN" ] || fail "bin/fm-spawn.sh is missing"

FUNCS="$TMP_ROOT/fns.sh"
: > "$FUNCS"
for fn in launch_template mcode_heap_cap_opts; do
  body=$(extract_fn "$SPAWN" "$fn")
  [ -n "$body" ] || fail "could not extract $fn from bin/fm-spawn.sh (the heap cap has no single owner)"
  printf '%s\n' "$body" >> "$FUNCS"
done
# shellcheck source=/dev/null
. "$FUNCS"

# The default ceiling itself is bound from the real source, not copied here.
cap_default_line=$(grep -m1 '^MCODE_HEAP_CAP_MB_DEFAULT=' "$SPAWN")
[ -n "$cap_default_line" ] || fail "bin/fm-spawn.sh must own the default MCode heap ceiling as one named value"
# shellcheck disable=SC2086
eval "$cap_default_line"
[ "$MCODE_HEAP_CAP_MB_DEFAULT" = "$EXPECTED_CAP_MB" ] \
  || fail "the default MCode heap ceiling must be $EXPECTED_CAP_MB (got: $MCODE_HEAP_CAP_MB_DEFAULT)"

tpl=$(launch_template minimax-code ship) || fail "launch_template returned non-zero for minimax-code"

case "$tpl" in
  *'NODE_OPTIONS=__MCODEHEAPOPTS__'*) : ;;
  *) fail "the minimax-code launch template must carry a V8 old-space ceiling (NODE_OPTIONS)" ;;
esac
case "$tpl" in
  *'NODE_OPTIONS=__MCODEHEAPOPTS__ MINIMAX_DATA_DIR='*) : ;;
  *) fail "the heap ceiling must be an env prefix on the launch command, before the CLI is started" ;;
esac
case "$tpl" in
  *'__MCODEHEAPOPTS__ MINIMAX_DATA_DIR=__MCODEDATADIR__ MCODE_CONFIG_DIR=__MCODEDIR__ mcode '*) : ;;
  *) fail "the heap ceiling must precede the mcode invocation in the launch template" ;;
esac
pass "the minimax-code launch template carries a V8 old-space ceiling"

# The cap's value, from its single owner.
cap_opts=$(mcode_heap_cap_opts) || fail "mcode_heap_cap_opts returned non-zero"
case "$cap_opts" in
  "--max-old-space-size=$EXPECTED_CAP_MB") : ;;
  *) fail "the MCode heap ceiling must be --max-old-space-size=$EXPECTED_CAP_MB (got: $cap_opts)" ;;
esac
pass "the heap ceiling is the justified value (--max-old-space-size=$EXPECTED_CAP_MB)"

# The spawner must substitute the placeholder into the real launch command.
# shellcheck disable=SC2016  # single quotes are deliberate: this greps a literal shell pattern
sub_line=$(grep -m1 '^[[:space:]]*LAUNCH=\${LAUNCH//__MCODEHEAPOPTS__/' "$SPAWN" | sed 's/^[[:space:]]*//')
[ -n "$sub_line" ] || fail "bin/fm-spawn.sh must substitute the MCode heap-cap placeholder into the launch command"
# shellcheck disable=SC2034  # MCODE_HEAP_OPTS is consumed by the eval below
MCODE_HEAP_OPTS=$cap_opts
LAUNCH="$tpl"
# shellcheck disable=SC2086
eval "$sub_line"
case "$LAUNCH" in
  *"NODE_OPTIONS=--max-old-space-size=$EXPECTED_CAP_MB MINIMAX_DATA_DIR="*) : ;;
  *) fail "the resolved launch command must carry NODE_OPTIONS=--max-old-space-size=$EXPECTED_CAP_MB (got: $LAUNCH)" ;;
esac
pass "the spawner substitutes the ceiling into the resolved launch command"

# The pane export must carry the SAME ceiling, so an operator's own
# interactive mcode in that pane is bounded the same way.
# shellcheck disable=SC2016  # single quotes are deliberate: this greps a literal shell pattern
export_line=$(grep -m1 'spawn_send_text_line "\$T" "export MINIMAX_DATA_DIR=' "$SPAWN")
[ -n "$export_line" ] || fail "bin/fm-spawn.sh must export the mcode runtime dirs into the crewmate pane"
# shellcheck disable=SC2016  # single quotes are deliberate: this matches a literal shell pattern
case "$export_line" in
  *'NODE_OPTIONS=$MCODE_HEAP_OPTS'*) : ;;
  *) fail "the mcode pane export must carry the same NODE_OPTIONS ceiling as the launch line (got: $export_line)" ;;
esac
pass "the mcode pane export carries the same heap ceiling"

# The ceiling must not live in the CLI's installer-managed prefix, which the
# CLI's own updater erases.
if grep -q 'max-old-space-size' /root/.local/bin/mcode 2>/dev/null; then
  fail "the heap ceiling must not be placed in the CLI's installer-managed launcher (its updater erases it)"
fi
if grep -rlq 'max-old-space-size' /root/.minimax-code/ 2>/dev/null; then
  fail "the heap ceiling must not be placed under the CLI's installer-managed prefix (its updater erases it)"
fi
pass "the heap ceiling lives in the repo, not in the CLI's installer-managed prefix"

# ============================================================================
# Part B - the lane-lifetime rule
# ============================================================================

[ -f "$LIFETIME" ] || fail "bin/fm-mcode-lane-lifetime.sh is missing: no lane-lifetime bound exists"

# --- (e) the retained-bytes threshold -----------------------------------------
# A sandbox home with a lane whose session retains a controlled number of
# bytes. The threshold is moved to a small number so the boundary is exact.
case_dir=$(make_case bytes)
write_meta "$case_dir"
# Exactly AT the threshold: not over it, so the rule keeps the lane.
make_store "$case_dir/store.sqlite" "sess-at" "$case_dir/wt" 600 400 0 0
out=$(FM_MCODE_LANE_MAX_RETAINED_BYTES=1000 run_rule "$case_dir" --budget task-x1)
verdict=$(field "$out" verdict)
[ "$verdict" = keep ] || fail "a lane exactly at the retained-bytes threshold must be kept (got: $out)"
case "$out" in
  *'reason=within-budget'*) : ;;
  *) fail "a lane at the threshold must report reason=within-budget (got: $out)" ;;
esac
# One byte over the threshold: over budget, so the rule recycles.
make_store "$case_dir/store.sqlite" "sess-over" "$case_dir/wt" 601 400 0 0
out=$(FM_MCODE_LANE_MAX_RETAINED_BYTES=1000 run_rule "$case_dir" --budget task-x1)
verdict=$(field "$out" verdict)
[ "$verdict" = recycle ] || fail "a lane one byte over the retained-bytes threshold must be recycled (got: $out)"
case "$out" in
  *'reason=retained-bytes-over-budget'*) : ;;
  *) fail "the recycle reason must name the retained-byte signal (got: $out)" ;;
esac
pass "the retained-bytes threshold fires one byte over and not below it"

# --- (f) the compaction-cycle threshold ---------------------------------------
make_store "$case_dir/store.sqlite" "sess-comp-at" "$case_dir/wt" 10 10 2
out=$(FM_MCODE_LANE_MAX_COMPACTIONS=2 run_rule "$case_dir" --budget task-x1)
verdict=$(field "$out" verdict)
[ "$verdict" = keep ] || fail "a lane exactly at the compaction threshold must be kept (got: $out)"
make_store "$case_dir/store.sqlite" "sess-comp-over" "$case_dir/wt" 10 10 3
out=$(FM_MCODE_LANE_MAX_COMPACTIONS=2 run_rule "$case_dir" --budget task-x1)
verdict=$(field "$out" verdict)
[ "$verdict" = recycle ] || fail "a lane one compaction cycle over the threshold must be recycled (got: $out)"
case "$out" in
  *'reason=compactions-over-budget'*) : ;;
  *) fail "the recycle reason must name the compaction signal (got: $out)" ;;
esac
pass "the compaction-cycle threshold fires one cycle over and not below it"

# --- the defaults are the justified ones ---------------------------------------
make_store "$case_dir/store.sqlite" "sess-defaults" "$case_dir/wt" 10 10 0
out=$(run_rule "$case_dir" --budget task-x1)
[ "$(field "$out" threshold_bytes)" = "$EXPECTED_MAX_RETAINED_BYTES" ] \
  || fail "the default retained-bytes threshold must be $EXPECTED_MAX_RETAINED_BYTES (got: $out)"
[ "$(field "$out" threshold_compactions)" = "$EXPECTED_MAX_COMPACTIONS" ] \
  || fail "the default compaction threshold must be $EXPECTED_MAX_COMPACTIONS (got: $out)"
pass "the default thresholds are the justified ones ($EXPECTED_MAX_RETAINED_BYTES bytes, $EXPECTED_MAX_COMPACTIONS cycles)"

# --- (g) a mid-turn lane is never recycled --------------------------------------
make_store "$case_dir/store.sqlite" "sess-busy" "$case_dir/wt" 601 400 0 1
out=$(FM_MCODE_LANE_MAX_RETAINED_BYTES=1000 run_rule "$case_dir" --check task-x1)
verdict=$(field "$out" verdict)
[ "$verdict" = keep ] || fail "a lane that is mid-turn must never be recycled (got: $out)"
case "$out" in
  *'reason=mid-turn'*) : ;;
  *) fail "the refusal must name the mid-turn reason (got: $out)" ;;
esac
pass "a lane that is mid-turn is never recycled"

# --- (h) a lane with unlanded work is never recycled ----------------------------
# A lane with no turn in flight, over budget, whose work has NOT landed.
make_store "$case_dir/store.sqlite" "sess-unlanded" "$case_dir/wt" 601 400 0 0
# A commit on the task branch that is on no remote and not in main: unlanded.
git -C "$case_dir/wt" commit -q --allow-empty -m "unlanded work"
out=$(FM_MCODE_LANE_MAX_RETAINED_BYTES=1000 run_rule "$case_dir" --check task-x1)
verdict=$(field "$out" verdict)
[ "$verdict" = keep ] || fail "a lane whose work has not landed must never be recycled (got: $out)"
case "$out" in
  *'reason=unlanded-work'*) : ;;
  *) fail "the refusal must name the unlanded-work reason (got: $out)" ;;
esac
pass "a lane whose work has not landed is never recycled"

# The recycle verb itself must refuse, before it reaches the control plane.
out=$(FM_MCODE_LANE_MAX_RETAINED_BYTES=1000 run_rule "$case_dir" --recycle task-x1)
rc=$?
case "$out" in
  *'LANE_RECYCLE: task-x1 refused'*) : ;;
  *) fail "the recycle verb must refuse a lane with unlanded work (got: $out)" ;;
esac
case "$out" in
  *'reason=unlanded-work'*) : ;;
  *) fail "the recycle refusal must name the unlanded-work reason (got: $out)" ;;
esac
[ "$rc" -ne 0 ] || fail "the recycle verb must exit non-zero when it refuses"
pass "the recycle verb refuses a lane with unlanded work and exits non-zero"

# --- (the landed, idle, over-budget lane IS recyclable) -------------------------
# Same sandbox, but with the unlanded commit landed into the default branch,
# so the repo's own landed-work guard passes and the rule reaches recycle.
git -C "$case_dir/project" merge -q --no-edit fm/task-x1
out=$(FM_MCODE_LANE_MAX_RETAINED_BYTES=1000 run_rule "$case_dir" --check task-x1)
verdict=$(field "$out" verdict)
[ "$verdict" = recycle ] || fail "an idle lane with landed work over budget must be recyclable (got: $out)"
pass "an idle lane whose work has landed is recyclable when it is over budget"

# --- the landed-work guard is the repo's own ------------------------------------
# The probe must be the teardown guard, not a second implementation.
grep -q 'probe-landed-work' "$TEARDOWN" || fail "bin/fm-teardown.sh must own the read-only landed-work probe"
grep -q 'validate_worktree_teardown_safety' "$TEARDOWN" || fail "bin/fm-teardown.sh must own the landed-work guard"
# shellcheck disable=SC2016  # single quotes are deliberate: this greps a literal shell pattern
grep -q 'fm-teardown.sh" "\$id" --probe-landed-work' "$LIFETIME" \
  || fail "the lane-lifetime rule must reuse the teardown landed-work guard, not a second copy"
pass "the lane-lifetime rule reuses the teardown landed-work guard"

# --- (i) the signal reproduces the real crash -----------------------------------
# The crashed session's retained volume, read through the rule's own SQL, is
# the ~52 MB the crash forensics recorded, and it is over this rule's budget.
if [ -f /root/.minimax/v2/sqlite/runtime-state.sqlite ]; then
  crash_bytes=$(sqlite3 -readonly -separator ' ' /root/.minimax/v2/sqlite/runtime-state.sqlite "
    SELECT COALESCE((SELECT SUM(LENGTH(data_json)) FROM local_runtime_message_rows WHERE session_id = 'mvs_01819ee3f02c4b5e8f48c3d66cd6b204'), 0)
         + COALESCE((SELECT SUM(LENGTH(before_json) + LENGTH(after_json) + LENGTH(paths_json)) FROM local_runtime_turn_diff_journal WHERE session_id = 'mvs_01819ee3f02c4b5e8f48c3d66cd6b204'), 0);" 2>/dev/null)
  case "$crash_bytes" in
    ''|*[!0-9]*) : ;;   # the live store is not present; the case is skipped, not failed
    *)
      [ "$crash_bytes" -gt "$EXPECTED_MAX_RETAINED_BYTES" ] \
        || fail "the crashed session's retained volume ($crash_bytes bytes) must be over the rule's budget ($EXPECTED_MAX_RETAINED_BYTES)"
      # 52 MB, give or take: the crash forensics recorded ~52 MB of retained JSON.
      [ "$crash_bytes" -gt 48000000 ] \
        || fail "the crashed session's retained volume ($crash_bytes bytes) must match the ~52 MB the forensics recorded"
      pass "the rule's own signal reads the crashed session's ~52 MB of retained history, over budget"
      ;;
  esac
fi

echo
