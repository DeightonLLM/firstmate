#!/usr/bin/env bash
# tests/fm-lane-naming-spawn-integrity.test.sh - lane naming must fail at spawn.
#
# A lane key is the task ID (AGENT-TODO-PROMPT-STYLE.md). The canonical
# convention is <harness>-<model>-<host>-<task>, lowercase, enforced by
# bin/fm-lane-naming-check.sh, which fm-spawn.sh calls before it creates any
# endpoint, worktree or state.
#
# The harness segment is not optional: without it a mcode lane and a pi lane
# running the same model are indistinguishable.
#
# Valid lane key examples:
#   pi-luna6-brandon-theme-whoosh   mcode-m3.1f-hd2stack-build
#
# Invalid lane key examples (each must be refused with exit 5):
#   m3.1f-firstmate-lockdeadline   (three segments: no harness)
#   m2.7-hd2                       (three segments: no task)
#   HD2-BUILD                      (uppercase)
#
# The grandfather clause stays: a lane that already has state/<id>.meta is an
# existing recovery case and is not blocked by the naming gate, so unlanded
# work is never stranded.
#
# The tests below run the spawn in a scratch home with a scratch project, a
# Every case function below is invoked through the runner list at the end of
# this file, which shellcheck cannot resolve. The repo's own convention for
# indirectly invoked functions is the SC2329 directive (tests/fm-pending-reply.test.sh).
# shellcheck disable=SC2329
# scratch tmux socket and a scratch state directory, so nothing outside the
# temporary directory is touched.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"

# =============================================================================
# helpers
# =============================================================================

# make_scratch_home: build a scratch firstmate home and print its path.
make_scratch_home() {
  local tmp
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-spawn-test.XXXXXX")
  mkdir -p "$tmp/state" "$tmp/data" "$tmp/config" "$tmp/projects/firstmate" "$tmp/tmux"
  git init -q "$tmp/projects/firstmate"
  printf 'x\n' > "$tmp/projects/firstmate/README.md"
  git -C "$tmp/projects/firstmate" add README.md
  git -C "$tmp/projects/firstmate" commit -qm init
  # A low load reading, so the dispatch guard's load ceiling is evaluated and
  # passes instead of refusing a saturated host before the naming gate.
  printf '0.10 0.20 0.30 1/100 1234\n' > "$tmp/loadavg"
  printf '%s\n' "$tmp"
}

# run_spawn <scratch_home> <lane_key>: spawn a lane in the scratch home.
run_spawn() {
  local tmp=$1 key=$2
  mkdir -p "$tmp/data/$key"
  printf '# Task\nLane naming spawn test.\n' > "$tmp/data/$key/brief.md"
  FM_HOME="$tmp" \
  FM_ROOT_OVERRIDE="$ROOT" \
  FM_STATE_OVERRIDE="$tmp/state" \
  FM_DATA_OVERRIDE="$tmp/data" \
  FM_CONFIG_OVERRIDE="$tmp/config" \
  FM_PROJECTS_OVERRIDE="$tmp/projects" \
  FM_SPAWN_NO_GUARD=1 \
  FM_DISPATCH_GUARD_LOADAVG="$tmp/loadavg" \
  FM_DISPATCH_GUARD_QUOTA_BYPASS=1 \
  TMUX_TMPDIR="$tmp/tmux" \
  "$SPAWN" "$key" "projects/firstmate" "sh -c 'echo ok'" --backend tmux 2>&1
}

# =============================================================================
# The gate must refuse a key that is not canonical
# =============================================================================

# test_three_segment_lane_key_rejected_at_spawn: the three-segment legacy form
# is refused with exit 5 and a message naming the expected canonical shape.
test_three_segment_lane_key_rejected_at_spawn() {
  local tmp out rc
  tmp=$(make_scratch_home)
  out=$(run_spawn "$tmp" "m3.1f-firstmate-lockdeadline"); rc=$?
  rm -rf "$tmp"

  [ "$rc" -eq 5 ] || fail "spawn must exit 5 for a three-segment lane key, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "m3.1f-firstmate-lockdeadline" \
    || fail "error message must name the offending lane key: $out"
  printf '%s\n' "$out" | grep -qi "<harness>-<model>-<host>-<task>" \
    || fail "error message must name the expected canonical shape: $out"
  pass "three-segment lane key refused at spawn with exit 5 and the expected shape named"
}

# test_invalid_lane_key_rejected_at_spawn_uppercase: uppercase lane key rejected.
test_invalid_lane_key_rejected_at_spawn_uppercase() {
  local tmp out rc
  tmp=$(make_scratch_home)
  out=$(run_spawn "$tmp" "HD2-BUILD"); rc=$?
  rm -rf "$tmp"

  [ "$rc" -eq 5 ] || fail "spawn must exit 5 for an invalid lane key, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "HD2-BUILD" \
    || fail "error message must name the offending lane key 'HD2-BUILD': $out"
  pass "uppercase lane key 'HD2-BUILD' rejected at spawn with exit 5"
}

# test_invalid_lane_key_rejected_at_spawn_missing_task_segment: key missing task.
test_invalid_lane_key_rejected_at_spawn_missing_task_segment() {
  local tmp out rc
  tmp=$(make_scratch_home)
  out=$(run_spawn "$tmp" "mcode-m3.1f-hd2stack"); rc=$?
  rm -rf "$tmp"

  [ "$rc" -eq 5 ] || fail "spawn must exit 5 for a missing task segment, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "mcode-m3.1f-hd2stack" \
    || fail "error must name the offending key 'mcode-m3.1f-hd2stack': $out"
  pass "lane key 'mcode-m3.1f-hd2stack' (missing task) rejected at spawn with exit 5"
}

# test_canonical_lane_key_accepted_at_spawn: a canonical four-segment key must
# pass the naming gate. Any later gate may refuse it; only exit 5 is a naming
# failure.
test_canonical_lane_key_accepted_at_spawn() {
  local tmp out rc
  tmp=$(make_scratch_home)
  out=$(run_spawn "$tmp" "pi-luna6-brandon-theme-whoosh"); rc=$?
  rm -rf "$tmp"

  [ "$rc" -ne 5 ] || fail "canonical lane key must NOT be rejected at the naming gate, got exit 5: $out"
  printf '%s\n' "$out" | grep -qi "violates the canonical" \
    && fail "canonical lane key must not be reported as a naming violation: $out"
  pass "canonical lane key 'pi-luna6-brandon-theme-whoosh' passed the lane-naming gate (exit $rc != 5)"
}

# =============================================================================
# The grandfather clause must keep working
# =============================================================================

# test_existing_task_with_meta_is_exempt: an existing lane that already has a
# state/<id>.meta is a recovery case. The naming rule does not apply to it, so
# the gate must not exit 5 and strand unlanded work.
test_existing_task_with_meta_is_exempt() {
  local tmp out rc
  tmp=$(make_scratch_home)
  mkdir -p "$tmp/state"
  printf 'window=firstmate:fm-test\nmodel=luna6\nharness=pi\nkind=task\n' \
    > "$tmp/state/m3.1f-firstmate-recovery.meta"
  out=$(run_spawn "$tmp" "m3.1f-firstmate-recovery"); rc=$?
  rm -rf "$tmp"

  [ "$rc" -ne 5 ] || fail "an existing lane with a .meta must be exempt from the naming gate, got exit 5: $out"
  pass "existing lane with a .meta is exempt from the naming gate (exit $rc != 5)"
}

# test_grandfather_clause_is_still_in_spawn_source: the clause itself must stay
# in the spawn script, or a future edit could strand unlanded work.
test_grandfather_clause_is_still_in_spawn_source() {
  grep -qF "\$STATE/\$ID.meta" "$SPAWN" \
    || fail "the grandfather clause must remain in $SPAWN"
  pass "the grandfather clause remains in fm-spawn.sh"
}

# =============================================================================
# The gate must be wired, and it must name the canonical shape
# =============================================================================

test_checker_is_called_at_the_spawn_gate() {
  grep -q 'fm-lane-naming-check.sh' "$SPAWN" \
    || fail "fm-spawn.sh must call the lane naming checker"
  grep -qi 'canonical <harness>-<model>-<host>-<task>' "$SPAWN" \
    || fail "fm-spawn.sh must name the canonical lane key shape in its refusal"
  pass "fm-spawn.sh calls the lane naming checker and names the canonical shape"
}

# =============================================================================
# Secondmates use a different naming convention and stay exempt
# =============================================================================

test_secondmate_spawn_exempt_from_lane_naming() {
  local tmp out rc
  tmp=$(make_scratch_home)
  # Write the required secondmate home marker.
  printf 'sm-alpha\n' > "$tmp/.fm-secondmate-home"

  out=$(FM_HOME="$tmp" \
        FM_ROOT_OVERRIDE="$ROOT" \
        FM_STATE_OVERRIDE="$tmp/state" \
        FM_DATA_OVERRIDE="$tmp/data" \
        FM_CONFIG_OVERRIDE="$tmp/config" \
        FM_PROJECTS_OVERRIDE="$tmp/projects" \
        FM_SPAWN_NO_GUARD=1 \
        FM_DISPATCH_GUARD_LOADAVG="$tmp/loadavg" \
        FM_DISPATCH_GUARD_QUOTA_BYPASS=1 \
        TMUX_TMPDIR="$tmp/tmux" \
        "$SPAWN" "sm-alpha" "$tmp" --secondmate 2>&1); rc=$?
  rm -rf "$tmp"

  # Exit 5 would mean the lane naming gate blocked the secondmate — that is wrong.
  [ "$rc" -ne 5 ] || fail "secondmate spawn must NOT be blocked by lane naming gate; got exit 5: $out"
  pass "secondmate spawn is exempt from lane naming gate (exit $rc != 5)"
}

# =============================================================================
# Run all tests
# =============================================================================

for _t in \
  test_three_segment_lane_key_rejected_at_spawn \
  test_invalid_lane_key_rejected_at_spawn_uppercase \
  test_invalid_lane_key_rejected_at_spawn_missing_task_segment \
  test_canonical_lane_key_accepted_at_spawn \
  test_existing_task_with_meta_is_exempt \
  test_grandfather_clause_is_still_in_spawn_source \
  test_checker_is_called_at_the_spawn_gate \
  test_secondmate_spawn_exempt_from_lane_naming; do
  echo "# RUN: $_t"
  if ! "$_t"; then
    echo "FAIL: $_t"
    exit 1
  fi
done
echo "# fm-lane-naming-spawn-integrity.test.sh: all assertions passed"
