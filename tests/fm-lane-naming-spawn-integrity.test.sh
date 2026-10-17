#!/usr/bin/env bash
# tests/fm-lane-naming-spawn-integrity.test.sh - TDD: lane naming must fail at spawn.
#
# RED: A lane key is the task ID (AGENT-TODO-PROMPT-STYLE.md). The naming
# convention (<model>-<surface>-<task>, lowercase) is validated by
# fm-lane-naming-check.sh, but fm-spawn.sh never calls it. This test proves
# an invalid lane key is currently ACCEPTED (RED), then the fix turns it GREEN.
#
# Valid lane key examples:
#   m2.7-hd2-build   gem38f-dubz-comms   luna6-brandon-audit
#
# Invalid lane key examples (will be used in RED test then rejected in GREEN):
#   HD2-BUILD        (uppercase)
#   m2.7-hd2         (missing task segment)
#   m2.7hd2build     (no hyphens - not three segments)
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"

# =============================================================================
# RED: test shows an invalid lane key is currently accepted at spawn
# =============================================================================

# test_invalid_lane_key_accepted_at_spawn: the current fm-spawn.sh does NOT
# call fm-lane-naming-check.sh, so a task ID with an invalid lane key format
# is spawned without error. This test PROVES the gap by expecting spawn to
# SUCCEED (or at least not exit before the lane-naming gate).
#
# After the fix: this test will FAIL because spawn now exits with code 5
# (lane naming violation). We then add test_invalid_lane_key_rejected_at_spawn
# to capture the GREEN state.
test_invalid_lane_key_accepted_at_spawn() {
  local tmp out rc

  # Build a scratch firstmate home.
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-spawn-test.XXXXXX")
  mkdir -p "$tmp/state" "$tmp/data" "$tmp/config" "$tmp/projects"
  # Provide a minimal fake project dir so fm-spawn.sh passes its cd gate.
  mkdir -p "$tmp/projects/firstmate"
  git init -q "$tmp/projects/firstmate"
  printf 'first file\n' > "$tmp/projects/firstmate/README.md"
  git -C "$tmp/projects/firstmate" add README.md
  git -C "$tmp/projects/firstmate" commit -qm init

  # Write a brief for a ship task whose ID is an INVALID lane key (uppercase).
  # The brief must exist so fm-spawn.sh does not refuse earlier on "no brief".
  mkdir -p "$tmp/data/invalid-lane-key"
  cat > "$tmp/data/invalid-lane-key/brief.md" <<'BRIEF'
# Task
Test task with invalid lane key.
BRIEF

  # Spawn with an invalid lane key as the task ID.
  # FM_SPAWN_NO_GUARD=1 skips the watcher guard (harmless in test).
  # We use a raw sh launch so no real agent CLI is needed.
  out=$(FM_HOME="$tmp" \
        FM_ROOT_OVERRIDE="$ROOT" \
        FM_STATE_OVERRIDE="$tmp/state" \
        FM_DATA_OVERRIDE="$tmp/data" \
        FM_CONFIG_OVERRIDE="$tmp/config" \
        FM_PROJECTS_OVERRIDE="$tmp/projects" \
        FM_SPAWN_NO_GUARD=1 \
        "$SPAWN" invalid-lane-key firstmate "sh -c 'echo spawned'" 2>&1); rc=$?

  rm -rf "$tmp"

  # RED STATE: spawn currently exits at the lane-naming gate because the check
  # is NOT wired. It either succeeds (rc=0, agent launched) or fails on a
  # different gate (brief exists, worktree ok, etc.) — but NOT on lane naming.
  # After the fix, spawn will refuse at lane naming with exit 5.
  #
  # The test below expects the CURRENT broken behavior so we can capture the
  # RED signature. Commented-out assertion documents what the GREEN state needs.
  if [ "$rc" -eq 5 ]; then
    # GREEN: spawn refused at lane naming gate — this is the fixed state.
    # Comment out or delete this branch after verifying the fix.
    pass "spawn correctly refused invalid lane key at lane-naming gate (rc=5)"
  else
    # RED: spawn did NOT refuse at lane naming gate.
    # Show what happened so the reviewer can confirm the gap.
    printf 'RED: fm-spawn.sh accepted invalid lane key "invalid-lane-key" (rc=%d)\n' "$rc" >&2
    printf 'Output: %s\n' "$out" >&2
    fail "spawn should refuse invalid lane key; current gap: spawn proceeds (rc=$rc)"
  fi
}

# =============================================================================
# GREEN: after the fix, an invalid lane key is rejected at spawn
# =============================================================================

# test_invalid_lane_key_rejected_at_spawn_uppercase: uppercase lane key rejected.
test_invalid_lane_key_rejected_at_spawn_uppercase() {
  local tmp out rc

  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-upper-test.XXXXXX")
  mkdir -p "$tmp/state" "$tmp/data" "$tmp/config" "$tmp/projects"
  mkdir -p "$tmp/projects/firstmate"
  git init -q "$tmp/projects/firstmate"
  printf 'x\n' > "$tmp/projects/firstmate/README.md"
  git -C "$tmp/projects/firstmate" add README.md
  git -C "$tmp/projects/firstmate" commit -qm init

  mkdir -p "$tmp/data/HD2-BUILD"
  cat > "$tmp/data/HD2-BUILD/brief.md" <<'BRIEF'
# Task
Uppercase lane key test.
BRIEF

  out=$(FM_HOME="$tmp" \
        FM_ROOT_OVERRIDE="$ROOT" \
        FM_STATE_OVERRIDE="$tmp/state" \
        FM_DATA_OVERRIDE="$tmp/data" \
        FM_CONFIG_OVERRIDE="$tmp/config" \
        FM_PROJECTS_OVERRIDE="$tmp/projects" \
        FM_SPAWN_NO_GUARD=1 \
        "$SPAWN" "HD2-BUILD" firstmate "sh -c 'echo ok'" 2>&1); rc=$?
  rm -rf "$tmp"

  # Spawn MUST refuse with exit 5 (lane naming violation).
  [ "$rc" -eq 5 ] || fail "spawn must exit 5 for invalid lane key, got $rc: $out"
  # Error message must name the offending lane key.
  printf '%s\n' "$out" | grep -qi "HD2-BUILD" \
    || fail "error message must name the offending lane key 'HD2-BUILD': $out"
  pass "uppercase lane key 'HD2-BUILD' rejected at spawn with exit 5"
}

# test_invalid_lane_key_rejected_at_spawn_missing_task_segment: key missing task.
test_invalid_lane_key_rejected_at_spawn_missing_task_segment() {
  local tmp out rc

  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-seg-test.XXXXXX")
  mkdir -p "$tmp/state" "$tmp/data" "$tmp/config" "$tmp/projects"
  mkdir -p "$tmp/projects/firstmate"
  git init -q "$tmp/projects/firstmate"
  printf 'x\n' > "$tmp/projects/firstmate/README.md"
  git -C "$tmp/projects/firstmate" add README.md
  git -C "$tmp/projects/firstmate" commit -qm init

  mkdir -p "$tmp/data/m2.7-hd2"
  cat > "$tmp/data/m2.7-hd2/brief.md" <<'BRIEF'
# Task
Missing task segment test.
BRIEF

  out=$(FM_HOME="$tmp" \
        FM_ROOT_OVERRIDE="$ROOT" \
        FM_STATE_OVERRIDE="$tmp/state" \
        FM_DATA_OVERRIDE="$tmp/data" \
        FM_CONFIG_OVERRIDE="$tmp/config" \
        FM_PROJECTS_OVERRIDE="$tmp/projects" \
        FM_SPAWN_NO_GUARD=1 \
        "$SPAWN" "m2.7-hd2" firstmate "sh -c 'echo ok'" 2>&1); rc=$?
  rm -rf "$tmp"

  [ "$rc" -eq 5 ] || fail "spawn must exit 5 for missing task segment, got $rc: $out"
  printf '%s\n' "$out" | grep -qi "m2.7-hd2" \
    || fail "error must name the offending key 'm2.7-hd2': $out"
  pass "lane key 'm2.7-hd2' (missing task) rejected at spawn with exit 5"
}

# test_valid_lane_key_accepted_at_spawn: valid lane key still works.
test_valid_lane_key_accepted_at_spawn() {
  local tmp out rc

  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-valid-test.XXXXXX")
  mkdir -p "$tmp/state" "$tmp/data" "$tmp/config" "$tmp/projects"
  mkdir -p "$tmp/projects/firstmate"
  git init -q "$tmp/projects/firstmate"
  printf 'x\n' > "$tmp/projects/firstmate/README.md"
  git -C "$tmp/projects/firstmate" add README.md
  git -C "$tmp/projects/firstmate" commit -qm init

  mkdir -p "$tmp/data/m2.7-hd2-build"
  cat > "$tmp/data/m2.7-hd2-build/brief.md" <<'BRIEF'
# Task
Valid lane key test.
BRIEF

  # A valid lane key spawns successfully (rc=0) but may fail later at
  # the tmux/herdr pane-creation step (no real tmux in test). We only care
  # that it did NOT exit 5 (lane naming gate) — any non-5 exit means it
  # passed the naming check and proceeded to the next gate.
  out=$(FM_HOME="$tmp" \
        FM_ROOT_OVERRIDE="$ROOT" \
        FM_STATE_OVERRIDE="$tmp/state" \
        FM_DATA_OVERRIDE="$tmp/data" \
        FM_CONFIG_OVERRIDE="$tmp/config" \
        FM_PROJECTS_OVERRIDE="$tmp/projects" \
        FM_SPAWN_NO_GUARD=1 \
        "$SPAWN" "m2.7-hd2-build" firstmate "sh -c 'echo ok'" 2>&1); rc=$?
  rm -rf "$tmp"

  [ "$rc" -ne 5 ] || fail "valid lane key 'm2.7-hd2-build' should NOT be rejected at lane naming gate; got exit 5: $out"
  pass "valid lane key 'm2.7-hd2-build' passed the lane-naming gate (exit $rc != 5)"
}

# test_secondmate_spawn_exempt_from_lane_naming: secondmate spawn uses
# a different naming convention (bare slug) so it must not be blocked.
test_secondmate_spawn_exempt_from_lane_naming() {
  local tmp out rc

  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm-lane-2ndm-test.XXXXXX")
  mkdir -p "$tmp/state" "$tmp/data" "$tmp/config" "$tmp/projects"
  mkdir -p "$tmp/projects/firstmate"
  git init -q "$tmp/projects/firstmate"
  printf 'x\n' > "$tmp/projects/firstmate/README.md"
  git -C "$tmp/projects/firstmate" add README.md
  git -C "$tmp/projects/firstmate" commit -qm init
  # Write the required secondmate home marker.
  printf 'sm-alpha\n' > "$tmp/.fm-secondmate-home"

  # A secondmate with a non-lane-key ID should still be able to attempt
  # spawn (it may fail for other reasons, but NOT for lane naming).
  out=$(FM_HOME="$tmp" \
        FM_ROOT_OVERRIDE="$ROOT" \
        FM_STATE_OVERRIDE="$tmp/state" \
        FM_DATA_OVERRIDE="$tmp/data" \
        FM_CONFIG_OVERRIDE="$tmp/config" \
        FM_PROJECTS_OVERRIDE="$tmp/projects" \
        FM_SPAWN_NO_GUARD=1 \
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
  test_invalid_lane_key_accepted_at_spawn \
  test_invalid_lane_key_rejected_at_spawn_uppercase \
  test_invalid_lane_key_rejected_at_spawn_missing_task_segment \
  test_valid_lane_key_accepted_at_spawn \
  test_secondmate_spawn_exempt_from_lane_naming; do
  echo "# RUN: $_t"
  if ! "$_t"; then
    echo "FAIL: $_t"
    exit 1
  fi
done
echo "# fm-lane-naming-spawn-integrity.test.sh: all assertions passed"
