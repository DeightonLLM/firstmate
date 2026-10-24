#!/usr/bin/env bash
# End-to-end test for the lane-worktree shape of the decision-hold lifecycle.
#
# A lane runs in its own disposable worktree while its task metadata, status
# event log, report, and backlog row live in the half that owns the originating
# work. The lifecycle therefore has two writers by path:
#
#   - the lane writes inside its own worktree (its hold, its attestation)
#   - the scheduler writes inside the half (the harvest)
#
# This test proves the shape with fixtures, and fails when the shape is
# removed: without the scheduler's seed the lane's own ownership test refuses
# the origin and the lane can register nothing at all.
set -u

# shellcheck source=tests/lib.sh
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DECISION_HOLD="$ROOT/bin/fm-decision-hold.sh"
HARVEST="$ROOT/bin/fm-decision-hold-harvest.sh"
TMP_ROOT=$(fm_test_tmproot fm-decision-hold-lane)

command -v tasks-axi >/dev/null 2>&1 || { echo "skip: tasks-axi not found"; exit 0; }

make_half() {  # <name>
  local half="$TMP_ROOT/$1"
  mkdir -p "$half/state" "$half/data" "$half/config"
  cat > "$half/data/backlog.md" <<'EOF'
# Backlog

## In flight
## Queued
## Done
EOF
  printf '%s\n' "$half"
}

make_lane_worktree() {  # <lane-id>
  local id=$1 wt="$TMP_ROOT/wt-$1"
  mkdir -p "$wt/data" "$wt/state"
  cp "$ROOT/.tasks.toml" "$wt/.tasks.toml"
  printf '%s\n' "$wt"
}

write_lane_meta() {  # <half> <lane-id> <worktree> [spawned-at]
  local half=$1 id=$2 wt=$3 spawned=${4:-1700000000}
  fm_write_meta "$half/state/$id.meta" \
    "window=firstmate:fm-$id" \
    "worktree=$wt" \
    "project=$half/projects/sample" \
    "harness=codex" \
    "kind=scout" \
    "mode=scout" \
    "spawned_at=$spawned" \
    "endpoint_task_id=$id"
}

tasks_at() {  # <backlog> <tasks-axi args...>
  local backlog=$1
  shift
  tasks-axi "$@" --file="$backlog"
}

write_lane_status() {  # <half> <lane-id> <key>
  local half=$1 id=$2 key=$3
  cat > "$half/state/$id.status" <<EOF
working: sample lane is working
needs-decision [key=$key]: the captain still has to choose the sample route
EOF
}

# A deterministic snapshot of a state directory: relative path plus content
# digest, so "the lane did not write into the half's state directory" is a
# measurement and not an assertion.
state_snapshot() {  # <state-dir>
  find "$1" -type f 2>/dev/null | LC_ALL=C sort | while read -r f; do
    printf '%s %s\n' "${f#"$1"/}" "$(sha256sum "$f" | cut -d' ' -f1)"
  done
}

run_harvest() {  # <half>
  local half=$1
  FM_HOME="$half" FM_STATE_OVERRIDE="$half/state" FM_DATA_OVERRIDE="$half/data" \
    "$HARVEST"
}

run_lane() {  # <worktree> <args...>
  local wt=$1
  shift
  FM_HOME="$wt" "$DECISION_HOLD" "$@"
}

run_half() {  # <half> <args...>
  local half=$1
  shift
  FM_HOME="$half" FM_STATE_OVERRIDE="$half/state" FM_DATA_OVERRIDE="$half/data" \
    FM_CONFIG_OVERRIDE="$half/config" "$DECISION_HOLD" "$@"
}

test_lane_hold_lands_in_the_worktree_and_is_harvested_into_the_half() {
  local half wt id key out rc before after
  half=$(make_half half-a)
  wt=$(make_lane_worktree lane-a)
  id=lane-a
  key=sample-route
  write_lane_meta "$half" "$id" "$wt"
  write_lane_status "$half" "$id" "$key"

  # Without the scheduler's seed the lane's own ownership test refuses the
  # origin. This is the defect the lane shape removes.
  out=$(run_lane "$wt" hold "$id" "$key" --title "Sample captain choice" \
    --reason "sample reason" 2>&1) && rc=0 || rc=$?
  [ "$rc" -ne 0 ] || fail "the unseeded lane hold unexpectedly succeeded"
  assert_contains "$out" "not owned by the active home" \
    "the unseeded lane refusal no longer names the ownership test"

  # The scheduler seeds the lane's own identity into the lane's worktree.
  run_harvest "$half" > "$TMP_ROOT/harvest-seed.out" 2>&1 \
    || fail "the scheduler harvest failed: $(cat "$TMP_ROOT/harvest-seed.out")"
  assert_present "$wt/state/$id.meta" \
    "the scheduler did not seed the lane's own identity into its worktree"

  # From here the lane is the only writer of its own worktree.
  before=$(state_snapshot "$half/state")
  out=$(run_lane "$wt" hold "$id" "$key" --title "Sample captain choice" \
    --reason "sample reason" 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 0 ] || fail "a lane in a worktree could not register its hold: $out"
  assert_contains "$out" "$id-decision-$key" \
    "the lane did not receive the deterministic hold identity"

  # The hold landed inside the lane's own worktree.
  assert_grep "$id-decision-$key" "$wt/data/backlog.md" \
    "the hold did not land inside the lane's worktree"
  assert_no_grep "$id-decision-$key" "$half/data/backlog.md" \
    "the lane wrote its hold into the half's backlog"

  # The lane never writes into the half's state directory.
  after=$(state_snapshot "$half/state")
  [ "$before" = "$after" ] || fail "the lane mutated the half's state directory"
  assert_absent "$half/state/decision-holds" \
    "the lane created the half's harvested hold directory"

  # The completion gate passes for the lane, in the lane's own worktree.
  out=$(run_lane "$wt" complete "$id" "$key" 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 0 ] || fail "the lane's completion gate refused: $out"
  assert_grep "decisions_reviewed=1" "$wt/state/$id.meta" \
    "the lane did not record its completion attestation in its own state"
  after=$(state_snapshot "$half/state")
  [ "$before" = "$after" ] || fail "the lane mutated the half's state directory"

  # The scheduler harvests the hold into the half that owns the origin.
  run_harvest "$half" > "$TMP_ROOT/harvest-hold.out" 2>&1 \
    || fail "the second scheduler harvest failed: $(cat "$TMP_ROOT/harvest-hold.out")"
  assert_grep "$id-decision-$key" "$half/data/backlog.md" \
    "the scheduler did not harvest the hold into the half's backlog"
  assert_present "$half/state/decision-holds/$id-decision-$key.hold" \
    "the scheduler did not record the harvested hold in the half's state directory"
  assert_grep "decisions_reviewed=1" "$half/state/$id.meta" \
    "the scheduler did not merge the lane's completion attestation into the half's metadata"
  assert_grep "captain-held [key=$key]" "$half/state/$id.status" \
    "the scheduler did not transfer the open status decision in the half"

  # The half's own read-only verify gate passes. This is the gate scout
  # teardown calls before it may erase a source.
  out=$(run_half "$half" verify "$id" 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 0 ] || fail "the half's verify gate refused after the harvest: $out"

  pass "a lane registers its hold in its own worktree and the scheduler harvests it into the half"
}

test_lane_reaches_the_origin_row_in_the_owning_half() {
  local half wt out rc
  local id=lane-a-row key=row-key
  half=$(make_half half-row)
  wt=$(make_lane_worktree lane-a-row)
  write_lane_meta "$half" lane-a "$wt"
  # The lane's task row lives in the half's backlog under its own id.
  cat > "$half/data/backlog.md" <<EOF
# Backlog

## In flight
- [ ] $id - Sample lane task (repo: sample) (kind: scout) (since 2026-07-14)

## Queued

## Done
EOF
  run_harvest "$half" > "$TMP_ROOT/harvest-row.out" 2>&1 \
    || fail "the scheduler harvest failed: $(cat "$TMP_ROOT/harvest-row.out")"

  # The lane's own ownership test reaches the origin row in the owning half,
  # not only the seeded metadata id.
  out=$(run_lane "$wt" hold "$id" "$key" --title "Sample captain choice" \
    --reason "sample reason" 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 0 ] || fail "the lane could not reach the origin row in the owning half: $out"
  assert_grep "$id-decision-$key" "$wt/data/backlog.md" \
    "the hold for the half's backlog row did not land inside the lane's worktree"
  assert_no_grep "$id-decision-$key" "$half/data/backlog.md" \
    "the lane wrote the hold into the half's backlog instead of its own worktree"

  pass "a lane reaches the origin row that lives in the owning half"
}

test_lane_completion_gate_reads_the_owning_half_live_status() {
  local half wt out rc before after
  local id=lane-c key=other-key
  half=$(make_half half-c)
  wt=$(make_lane_worktree lane-c)
  write_lane_meta "$half" lane-c "$wt"
  write_lane_status "$half" lane-c open-key
  run_harvest "$half" > "$TMP_ROOT/harvest-c.out" 2>&1 \
    || fail "the scheduler harvest failed: $(cat "$TMP_ROOT/harvest-c.out")"
  before=$(state_snapshot "$half/state")

  out=$(run_lane "$wt" hold "$id" "$key" --title "Sample captain choice" \
    --reason "sample reason" 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 0 ] || fail "the lane could not register its hold: $out"

  # The half's live status event log holds an open decision the inventory does
  # not cover, so the completion gate must refuse.
  out=$(run_lane "$wt" complete "$id" "$key" 2>&1) && rc=0 || rc=$?
  [ "$rc" -ne 0 ] || fail "the lane's completion gate ignored an open decision in the owning half's status"
  assert_contains "$out" "has no captain-held inventory entry" \
    "the lane's completion gate did not report the uncovered open decision"

  after=$(state_snapshot "$half/state")
  [ "$before" = "$after" ] || fail "the lane mutated the half's state directory"

  pass "the lane's completion gate reads the owning half's live status event log"
}

test_two_lanes_holding_concurrently_never_collide() {
  local half wt_a wt_b out rc
  local key=sample-route
  half=$(make_half half-b)
  wt_a=$(make_lane_worktree lane-a2)
  wt_b=$(make_lane_worktree lane-b2)
  write_lane_meta "$half" lane-a2 "$wt_a"
  write_lane_meta "$half" lane-b2 "$wt_b"

  run_harvest "$half" > "$TMP_ROOT/harvest-two-seed.out" 2>&1 \
    || fail "the scheduler harvest failed for two lanes"
  assert_present "$wt_a/state/lane-a2.meta" \
    "the scheduler did not seed the first lane's worktree"
  assert_present "$wt_b/state/lane-b2.meta" \
    "the scheduler did not seed the second lane's worktree"

  out=$(run_lane "$wt_a" hold lane-a2 "$key" --title "First lane choice" \
    --reason "first reason" 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 0 ] || fail "the first lane could not register its hold: $out"
  out=$(run_lane "$wt_b" hold lane-b2 "$key" --title "Second lane choice" \
    --reason "second reason" 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 0 ] || fail "the second lane could not register its hold: $out"

  # Each lane owns its own path: neither worktree holds the other's hold.
  assert_grep "lane-a2-decision-$key" "$wt_a/data/backlog.md" \
    "the first lane's hold is missing from its own worktree"
  assert_grep "lane-b2-decision-$key" "$wt_b/data/backlog.md" \
    "the second lane's hold is missing from its own worktree"
  assert_no_grep "lane-b2-decision-$key" "$wt_a/data/backlog.md" \
    "the first lane's worktree holds the second lane's hold"
  assert_no_grep "lane-a2-decision-$key" "$wt_b/data/backlog.md" \
    "the second lane's worktree holds the first lane's hold"

  # One harvest registers both, with distinct durable identities.
  run_harvest "$half" > "$TMP_ROOT/harvest-two.out" 2>&1 \
    || fail "the scheduler harvest failed for two held lanes"
  assert_grep "lane-a2-decision-$key" "$half/data/backlog.md" \
    "the scheduler did not harvest the first lane's hold"
  assert_grep "lane-b2-decision-$key" "$half/data/backlog.md" \
    "the scheduler did not harvest the second lane's hold"
  assert_present "$half/state/decision-holds/lane-a2-decision-$key.hold" \
    "the first harvested hold record is missing"
  assert_present "$half/state/decision-holds/lane-b2-decision-$key.hold" \
    "the second harvested hold record is missing"

  pass "two lanes holding concurrently never collide on the same path"
}

test_reused_slot_seeds_only_the_current_owner() {
  local half wt
  half=$(make_half half-reuse)
  wt=$(make_lane_worktree lane-slot)
  # A pool slot is reused: an older lane and a newer lane point at one path.
  write_lane_meta "$half" lane-old "$wt" 2000000000
  write_lane_meta "$half" lane-new "$wt" 2000000001
  run_harvest "$half" > "$TMP_ROOT/harvest-reuse.out" 2>&1 \
    || fail "the scheduler harvest failed: $(cat "$TMP_ROOT/harvest-reuse.out")"
  assert_present "$wt/state/lane-new.meta" \
    "the current owner of the slot was not seeded"
  assert_absent "$wt/state/lane-old.meta" \
    "a stale lane identity was seeded into a reused slot"

  pass "a reused slot seeds only the current owner"
}

test_foreign_hold_in_a_slot_is_not_harvested() {
  local half wt out rc
  half=$(make_half half-foreign)
  wt=$(make_lane_worktree lane-foreign)
  write_lane_meta "$half" lane-foreign "$wt" 2000000002
  # A captain hold whose identity belongs to no lane of this half, in the same
  # slot. The pool is shared between halves, so it must not leak in.
  tasks_at "$wt/data/backlog.md" add other-half-lane-decision-key "Foreign hold" \
    --kind captain --repo sample --body "Origin: other-half-lane" >/dev/null 2>&1
  tasks_at "$wt/data/backlog.md" hold other-half-lane-decision-key \
    --reason "foreign reason" --kind captain >/dev/null 2>&1
  run_harvest "$half" > "$TMP_ROOT/harvest-foreign.out" 2>&1 \
    || fail "the scheduler harvest failed: $(cat "$TMP_ROOT/harvest-foreign.out")"
  assert_no_grep "other-half-lane-decision-key" "$half/data/backlog.md" \
    "the harvest imported a hold that belongs to no lane of this half"
  assert_absent "$half/state/decision-holds/other-half-lane-decision-key.hold" \
    "the harvest recorded a foreign hold in this half's state directory"

  pass "a hold that belongs to no lane of this half is never harvested"
}

test_existing_home_behaviour_is_not_regressed() {
  local home id out rc
  home=$(make_half half-home)
  id=sample-home-review
  mkdir -p "$home/data/$id"
  cat > "$home/data/backlog.md" <<EOF
# Backlog

## In flight
- [ ] $id - Investigate sample routing (repo: sample) (kind: scout) (since 2026-07-14)

## Queued

## Done
EOF
  fm_write_meta "$home/state/$id.meta" \
    "window=firstmate:fm-$id" \
    "worktree=$home/projects/missing-scratch" \
    "project=$home/projects/sample" \
    "harness=codex" \
    "kind=scout" \
    "mode=scout"
  printf 'done: report and visual review complete\n' > "$home/state/$id.status"

  # A home that owns its origin keeps registering the hold in its own backlog.
  out=$(run_half "$home" hold "$id" sample-key --title "Sample home choice" \
    --reason "sample reason" 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 0 ] || fail "the home hold path regressed: $out"
  assert_grep "$id-decision-sample-key" "$home/data/backlog.md" \
    "the home hold did not land in the home's own backlog"

  out=$(run_half "$home" complete "$id" sample-key 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 0 ] || fail "the home completion path regressed: $out"
  assert_grep "decisions_reviewed=1" "$home/state/$id.meta" \
    "the home completion attestation regressed"
  out=$(run_half "$home" verify "$id" 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 0 ] || fail "the home verify gate regressed: $out"

  pass "the existing home behaviour is not regressed"
}

test_lane_hold_lands_in_the_worktree_and_is_harvested_into_the_half
test_lane_reaches_the_origin_row_in_the_owning_half
test_lane_completion_gate_reads_the_owning_half_live_status
test_two_lanes_holding_concurrently_never_collide
test_reused_slot_seeds_only_the_current_owner
test_foreign_hold_in_a_slot_is_not_harvested
test_existing_home_behaviour_is_not_regressed
