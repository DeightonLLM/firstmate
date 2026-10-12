#!/usr/bin/env bash
# A genuine firstmate dispatch must not be downgradable to a Review by a
# downstream agent policy.
#
# Observed defect (HD2, task portable-paths-20261012, pane w9:p4): an agy crew
# received a correctly typed launch-brief, then classified it as "a Review of a
# pasted launch brief (contains # Task, no Codex execute this or
# DISPATCH_AUTHORIZATION: Agent execute this execution marker present)" and
# sat idle waiting for a human authorization that could never arrive.
#
# The brief itself was correct. The defect is that the dispatch boundary carried
# no explicit execution authority, so a review-vs-execute policy had nothing to
# key on and defaulted to the safe side: do nothing.
#
# Contract owned here:
#   - every launch-brief carries an explicit execution-authorization marker
#   - the marker survives body extraction (the agent must actually read it)
#   - no OTHER operational kind carries it, because only a brief grants work
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

OWNER="$ROOT/bin/fm-operational-input.sh"

cleanup() {
  fm_test_cleanup
}
trap cleanup EXIT

# The marker a downstream policy must be able to detect.
MARKER='DISPATCH_AUTHORIZATION: Agent execute this'

encode() {
  printf '%s' "$2" | "$OWNER" encode "$1" 2>/dev/null
}

test_launch_brief_carries_execution_authority() {
  local out
  out=$(encode launch-brief "# Task
Make firstmate path resolution portable.")
  assert_contains "$out" "$MARKER" \
    "launch-brief must carry an explicit execution-authorization marker"
}

test_launch_brief_authority_is_body_visible() {
  # Parsing must not strip the authority: the crew only ever sees the body.
  local out body
  out=$(encode launch-brief "# Task
Do the work.")
  body=$(printf '%s' "$out" | "$OWNER" body 2>/dev/null)
  assert_contains "$body" "$MARKER" \
    "execution authority must survive body extraction"
}

test_launch_brief_authority_is_independent_of_brief_text() {
  # A brief must not be able to talk its way out of, or into, execution.
  # Authority comes from the dispatch boundary, never from brief prose.
  local out
  out=$(encode launch-brief "Please just review this and tell me what you think.")
  assert_contains "$out" "$MARKER" \
    "execution authority is owned by the dispatch boundary, not brief prose"
}

test_no_other_kind_carries_execution_authority() {
  # Only a launch brief grants execution. A watcher wake or session-start must
  # never be able to read as a work grant.
  local kind out
  for kind in session-start watcher turn-end-guard away-supervisor; do
    out=$(encode "$kind" "some body")
    assert_not_contains "$out" "$MARKER" \
      "$kind must not carry execution authority"
  done
}

test_run() {
  test_launch_brief_carries_execution_authority
  test_launch_brief_authority_is_body_visible
  test_launch_brief_authority_is_independent_of_brief_text
  test_no_other_kind_carries_execution_authority
}

test_run