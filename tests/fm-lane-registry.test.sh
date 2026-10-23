#!/usr/bin/env bash
# tests/fm-lane-registry.test.sh - the fleet's live-lane registry writer.
#
# The registry (state/lanes/<name>.lane) is what the host safety net counts and
# what the fleet's own lane board renders. Before this writer existed the
# registry held one stale hand-written registration and nothing in this repo
# ever wrote it, so the safety net counted zero lanes while two ran and filed
# `no-live-lanes` as a blocked wake, and the fleet's own board rendered
# "lanes: 0 (no active lanes)" while three task records existed.
#
# What this suite proves:
#   - the writer produces a registration the EXISTING readers accept
#     (bin/lane-todo-board.sh renders it with its pane and model);
#   - a live lane is COUNTED by the host reader's counting rules and a retired
#     one is NOT;
#   - the no-live-lanes alarm stays CAPABLE of firing when the fleet is empty,
#     which is what keeps the alarm alive rather than dead;
#   - the registered artifact never carries a verdict, so a live lane that has
#     written "VERDICT: PASS" is NOT retired for the wrong reason;
#   - the decision table: which lanes get a registration at all;
#   - a registration whose pane is not in the current layout is not counted,
#     and one without a pane key is not counted either.
#
# The counting rules are MIRRORED from the host reader
# (/root/bin/factory-safetynet.sh, which lives outside this repo) in
# count_live_lanes() below, so the suite stays hermetic. The REAL reader is
# driven too when this host has it and FM_LANE_REGISTRY_REAL_SAFETYNET=1 is
# set: that case runs /root/bin/factory-safetynet.sh against a scratch home
# and asserts on the script's own output, with FM_SAFETYNET_BK pointed at
# scratch space - never at /root/backups, which that script prunes with rm -rf.
#
# Self-contained on purpose: every case builds a throwaway home, so these tests
# never read or write the real firstmate home and never touch the network.
set -u

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REGISTRY_LIB="$ROOT/bin/fm-lane-registry-lib.sh"
BOARD="$ROOT/bin/lane-todo-board.sh"

# shellcheck source=bin/fm-lane-registry-lib.sh
. "$REGISTRY_LIB"

# --- helpers -----------------------------------------------------------------

new_home() {  # <name> -> prints a fresh throwaway home
  local home
  home=$(fm_test_tmproot "fm-lane-registry-$1")
  mkdir -p "$home/state" "$home/data"
  printf '%s\n' "$home"
}

# Register a lane exactly the way the spawn path does.
register_lane() {  # <home> <lane> <pane> [model]
  local home=$1 lane=$2 pane=$3 model=${4:-minimax/MiniMax-M3.1-Flash}
  fm_lane_registry_ensure_todo "$home/state" "$lane" >/dev/null 2>&1
  fm_lane_registry_write "$home/state" "$lane" "$pane" "$lane" "$model" "default" \
    "data/$lane/report.md" "ship lane; report: data/$lane/report.md"
}

# The host reader's counting loop, mirrored rule for rule: a registration
# counts as a live lane only when it has a pane key, its artifact does not
# already carry a verdict, and its pane is in the current layout.
count_live_lanes() {  # <repo root> <pane id, one per line>
  local repo=$1 panes=$2 lane_dir f lpane lart count=0
  lane_dir="$repo/state/lanes"
  for f in "$lane_dir"/*.lane; do
    [ -f "$f" ] || continue
    lpane=$(sed -n 's/^pane=//p' "$f" | head -1)
    lart=$(sed -n 's/^artifact=//p' "$f" | head -1)
    [ -n "$lpane" ] || continue
    if [ -n "$lart" ] && [ -f "$repo/$lart" ] && grep -q 'VERDICT:' "$repo/$lart" 2>/dev/null; then
      continue
    fi
    case "$lpane" in
      ssh:*:*) : ;;
      *) if ! printf '%s\n' "$panes" | grep -qxF -- "$lpane"; then continue; fi ;;
    esac
    count=$((count + 1))
  done
  printf '%s\n' "$count"
}

# The host reader's issue list, mirrored: an empty fleet files no-live-lanes.
issue_list() {  # <repo root> <pane id, one per line>
  local count
  count=$(count_live_lanes "$1" "$2")
  if [ "$count" -gt 0 ]; then
    printf 'none\n'
  else
    printf ' no-live-lanes\n'
  fi
}

run_board() {  # <home> -> sets OUT
  OUT=$(FM_HOME="$1" bash "$BOARD" 2>&1)
}

# --- cases -------------------------------------------------------------------

test_registration_is_accepted_by_the_existing_board() {
  local home
  home=$(new_home readers)
  register_lane "$home" "lane-alpha" "w1:p9Z" "mcode"
  printf 'window=default:w1:p9Z\nendpoint_task_id=lane-alpha\nmodel=mcode\n' \
    > "$home/state/lane-alpha.meta"
  run_board "$home"
  assert_contains "$OUT" "lanes: 1" "the board must count the registered lane"
  assert_contains "$OUT" "[mcode @ default·w1:p9Z] lane-alpha" \
    "the board must render the lane with its model, surface and pane"
  pass "a registration written by the registry is rendered by the existing board"
}

test_live_lane_is_counted_and_retired_lane_is_not() {
  local home panes count
  home=$(new_home counted)
  panes="w1:p1"
  register_lane "$home" "lane-live" "w1:p1"
  count=$(count_live_lanes "$home" "$panes")
  assert_equals "1" "$count" "a live lane must be counted"
  assert_contains "$(issue_list "$home" "$panes")" "none" \
    "a live lane must keep no-live-lanes out of the issue list"
  fm_lane_registry_retire "$home/state" "lane-live"
  count=$(count_live_lanes "$home" "$panes")
  assert_equals "0" "$count" "a retired lane must not be counted"
  assert_contains "$(issue_list "$home" "$panes")" "no-live-lanes" \
    "a retired lane must leave the fleet empty, so the alarm can fire"
  pass "a live lane is counted and a retired one is not"
}

test_the_alarm_is_capable_of_firing_on_an_empty_fleet() {
  local home issues
  home=$(new_home empty)
  assert_equals "0" "$(count_live_lanes "$home" "w1:p1")" \
    "an empty registry must count no lanes"
  issues=$(issue_list "$home" "w1:p1")
  assert_contains "$issues" "no-live-lanes" \
    "an empty fleet must still file no-live-lanes, or the alarm is dead"
  pass "the no-live-lanes alarm is still capable of firing when the fleet is empty"
}

test_a_verdict_carrying_report_does_not_retire_a_live_lane() {
  local home artifact
  home=$(new_home verdict)
  register_lane "$home" "lane-verdict" "w1:p2"
  # The fleet's report contract ends a report in "VERDICT: PASS". A report that
  # carries a verdict must NOT retire a lane that is still live and unreaped:
  # the lane being gone is the right reason, the artifact's text is not.
  mkdir -p "$home/data/lane-verdict"
  printf 'report body\n\nVERDICT: PASS\n' > "$home/data/lane-verdict/report.md"
  assert_equals "1" "$(count_live_lanes "$home" "w1:p2")" \
    "a live lane must stay counted after its report carries a verdict"
  artifact="$home/state/lanes/lane-verdict.todo.md"
  assert_present "$artifact" "the registered artifact must exist"
  assert_no_grep "VERDICT:" "$artifact" \
    "the registered artifact must never carry a verdict"
  pass "a verdict-carrying report does not retire a live, unreaped lane"
}

test_a_registration_the_reader_cannot_resolve_is_not_counted() {
  local home
  home=$(new_home stale)
  register_lane "$home" "lane-stale" "w1:pZZ"
  assert_equals "0" "$(count_live_lanes "$home" "w1:p1")" \
    "a registration whose pane is not in the layout must not be counted"
  home=$(new_home nopane)
  mkdir -p "$home/state/lanes"
  printf 'artifact=state/lanes/lane-nopane.todo.md\ntask=lane-nopane\n' \
    > "$home/state/lanes/lane-nopane.lane"
  assert_equals "0" "$(count_live_lanes "$home" "w1:p1")" \
    "a registration without a pane key must not be counted"
  pass "a registration the reader cannot resolve is not counted as live work"
}

test_only_crewmate_and_scout_lanes_are_registered() {
  if fm_lane_registry_should_register ship "w1:p1"; then :; else fail "a ship lane must be registered"; fi
  if fm_lane_registry_should_register scout "w1:p1"; then :; else fail "a scout lane must be registered"; fi
  if fm_lane_registry_should_register secondmate "w1:p1"; then
    fail "a secondmate must not be registered in the primary home"
  fi
  if fm_lane_registry_should_register ship ""; then
    fail "a lane with no pane id must not be registered"
  fi
  pass "only crewmate and scout lanes with a pane are registered"
}

test_retirement_archives_the_registration_out_of_the_active_directory() {
  local home archived=""
  home=$(new_home archived)
  register_lane "$home" "lane-gone" "w1:p3"
  fm_lane_registry_retire "$home/state" "lane-gone"
  assert_absent "$home/state/lanes/lane-gone.lane" \
    "the retired registration must leave the active directory"
  assert_absent "$home/state/lanes/lane-gone.todo.md" \
    "the retired lane's work list must leave the active directory too"
  for archived in "$home/state/lanes/archived"/*.lane; do
    [ -f "$archived" ] && break
  done
  assert_present "$archived" "the retired registration must be archived"
  run_board "$home"
  assert_contains "$OUT" "lanes: 0" "an archived lane is history, not live work"
  assert_contains "$OUT" "(no active lanes)" "an archived-only registry renders honestly"
  pass "retirement archives the registration and the board renders no lanes"
}

test_retirement_is_safe_for_a_lane_that_was_never_registered() {
  local home
  home=$(new_home never)
  fm_lane_registry_retire "$home/state" "lane-absent"
  pass "retiring a lane that was never registered is a no-op, not an error"
}

test_an_unsafe_lane_name_is_refused() {
  local home
  home=$(new_home unsafe)
  if fm_lane_registry_write "$home/state" "../escape" "w1:p1" "escape" "mcode" "default" \
    "data/escape/report.md" "note"; then
    fail "a lane name that escapes the lanes directory must be refused"
  fi
  if fm_lane_registry_write "$home/state" "lane" "" "lane" "mcode" "default" \
    "data/lane/report.md" "note"; then
    fail "a registration without a pane must be refused"
  fi
  pass "an unsafe lane name and a registration without a pane are refused"
}

test_the_real_host_safety_net_counts_the_lane_and_fires_again_when_empty() {
  local scratch home pane count
  if [ "${FM_LANE_REGISTRY_REAL_SAFETYNET:-0}" != "1" ]; then
    printf '# skipped: set FM_LANE_REGISTRY_REAL_SAFETYNET=1 to drive the real host reader\n'
    return 0
  fi
  if [ ! -r /root/bin/factory-safetynet.sh ]; then
    printf '# skipped: /root/bin/factory-safetynet.sh is not present on this host\n'
    return 0
  fi
  pane=$(herdr pane list 2>/dev/null | jq -r '.result.panes[]?.pane_id' 2>/dev/null | head -1)
  if [ -z "$pane" ]; then
    printf '# skipped: no live herdr pane to register\n'
    return 0
  fi
  scratch=$(fm_test_tmproot "fm-lane-registry-realnet")
  home="$scratch/home"
  mkdir -p "$home/state" "$home/data" "$scratch/bk"
  register_lane "$home" "lane-real" "$pane"
  # The reader's own mkdir creates state/lanes when it is missing; the scratch
  # home already has it because the registration lives there.
  FM_SAFETYNET_REPO="$home" FM_SAFETYNET_BK="$scratch/bk" \
    bash /root/bin/factory-safetynet.sh >/dev/null 2>&1
  count=$(grep -o 'lanes=[0-9]*' "$home/state/safetynet.log" | tail -1 | cut -d= -f2)
  assert_equals "1" "$count" "the real reader must count the registered lane"
  assert_no_grep "no-live-lanes" "$home/state/safetynet.log" \
    "the real reader must not file no-live-lanes while a lane is registered"
  fm_lane_registry_retire "$home/state" "lane-real"
  sleep 61
  FM_SAFETYNET_REPO="$home" FM_SAFETYNET_BK="$scratch/bk" \
    bash /root/bin/factory-safetynet.sh >/dev/null 2>&1
  count=$(grep -o 'lanes=[0-9]*' "$home/state/safetynet.log" | tail -1 | cut -d= -f2)
  assert_equals "0" "$count" "the real reader must count no lanes once the lane is retired"
  assert_grep "no-live-lanes" "$home/state/safetynet.log" \
    "the real reader must file no-live-lanes again once the lane is gone"
  pass "the real host safety net counts the lane and fires again when it is gone"
}

test_registration_is_accepted_by_the_existing_board
test_live_lane_is_counted_and_retired_lane_is_not
test_the_alarm_is_capable_of_firing_on_an_empty_fleet
test_a_verdict_carrying_report_does_not_retire_a_live_lane
test_a_registration_the_reader_cannot_resolve_is_not_counted
test_only_crewmate_and_scout_lanes_are_registered
test_retirement_archives_the_registration_out_of_the_active_directory
test_retirement_is_safe_for_a_lane_that_was_never_registered
test_an_unsafe_lane_name_is_refused
test_the_real_host_safety_net_counts_the_lane_and_fires_again_when_empty
