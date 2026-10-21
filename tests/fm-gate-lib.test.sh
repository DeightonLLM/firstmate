#!/usr/bin/env bash
# Unit tests for bin/fm-gate-lib.sh - the ONE owner of interactive-human-gate
# detection in rendered pane text.
#
# The fleet defect these pin: an unattended crewmate parked on an approval
# dialog reads as `idle` - exactly what a finished crew reads as - so the lane
# burned a slot with no alarm. The classifier is the positive, structural read
# that separates them, and it must match the SHAPE of an interactive choice
# rather than any one harness's chrome.
#
# STALL POLICY (captain, 2026-10-13) is pinned here too: this owner DETECTS and
# nothing else. It must never grow an answering path - no auto-Yes, no
# auto-Enter, no default-accept, no scripted send-keys. The behavioural half of
# that policy (a real watcher run over a gated pane, with a recorder fakebin
# proving zero keys were sent) lives in tests/fm-watch-triage.test.sh.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=/dev/null
. "$ROOT/bin/fm-gate-lib.sh"

# The verbatim rendering that produced the silent stall, byte-for-byte in shape.
incident_gate='⚠️ DANGEROUS COMMAND

 cd /root/agent-work/deightonllm-firstmate && unset BASH_ENV
 s=/tmp/c1check; rm -rf $s; mkdir -p $s/home/{data/c1-task,state,projects,config} $s/proj
 echo "brief" > $s/home/data/c1-task/brief.md
 (cd $s

 Allow?
 Yes,No
 → Yes
   No
 ↑↓ navigate  enter sele'

gate_option_rows='⚠️ DANGEROUS COMMAND

 rm -rf /tmp/x

Allow this command?
 ❯ Yes
   No'

test_incident_rendering_is_a_gate() {
  fm_gate_pane_awaiting_human "$incident_gate" \
    || fail "the verbatim stalled-lane rendering must be detected as a human gate"
  pass "verbatim stalled-lane rendering is detected as an interactive gate"
}

test_styled_gate_is_a_gate() {
  local styled
  styled=$(printf '\033[1;33mAllow?\033[0m\n\033[2mYes,No\033[0m\n')
  fm_gate_pane_awaiting_human "$styled" \
    || fail "a gate wrapped in ANSI styling must still be detected"
  pass "ANSI-styled gate is detected (shared fleet-wide stripper, not a second one)"
}

test_option_rows_with_selection_marker_are_a_gate() {
  fm_gate_pane_awaiting_human "$gate_option_rows" \
    || fail "separate yes/no option rows are equally conclusive as a compact choice row"
  pass "separate yes/no option rows with a selection marker are detected"
}

test_busy_pane_is_not_a_gate() {
  local out
  out=$(printf 'running tests\nesc to interrupt\n')
  fm_gate_pane_awaiting_human "$out" && fail "a busy pane must never be classified as a gate"
  pass "a busy pane is not a gate (a live turn cannot be parked at a dialog)"
}

test_finished_pane_is_not_a_gate() {
  local out
  out=$(printf 'done: branch fm/x pushed\nall quiet\n> \n')
  fm_gate_pane_awaiting_human "$out" && fail "a finished pane must never be classified as a gate"
  pass "a finished/empty pane is not a gate (idle stays truthful for real completions)"
}

test_ordinary_prose_is_not_a_gate() {
  local out
  out=$(printf 'Allow? is not something this tool accepts.\nI will run the suite.\n')
  fm_gate_pane_awaiting_human "$out" \
    && fail "prose quoting 'Allow?' must not match: the question form is anchored at both ends"
  pass "prose that merely quotes a prompt is not a gate"
}

test_choice_without_a_question_is_not_a_gate() {
  local out
  out=$(printf 'config answers\nYes,No\n')
  fm_gate_pane_awaiting_human "$out" \
    && fail "a choice affordance alone is not proof: something must ask for approval"
  pass "a choice row with no approval question is not a gate"
}

test_question_without_a_choice_is_not_a_gate() {
  local out
  out=$(printf 'Allow?\n')
  fm_gate_pane_awaiting_human "$out" \
    && fail "an approval question with no answerable choice is not a gate"
  pass "an approval question with no yes/no affordance is not a gate"
}

test_empty_capture_is_not_a_gate() {
  fm_gate_pane_awaiting_human "" && fail "an empty capture must never be classified as a gate"
  fm_gate_pane_awaiting_human "   " && fail "a whitespace-only capture must never be a gate"
  pass "an empty or whitespace-only capture is not a gate"
}

test_stdin_capture_is_accepted() {
  local rc=0
  printf '%s\n' "$incident_gate" | fm_gate_pane_awaiting_human || rc=1
  [ "$rc" -eq 0 ] || fail "the classifier must accept a capture on stdin"
  rc=0
  printf 'all quiet\n' | fm_gate_pane_awaiting_human && rc=1
  [ "$rc" -eq 0 ] || fail "a piped non-gate capture must not be detected as a gate"
  pass "captures are accepted on stdin as well as by argument"
}

# STALL POLICY: the detector must stay detection-only. Structural guard - the
# behavioural proof that no unattended path answers a gate is the recorder
# fakebin case in tests/fm-watch-triage.test.sh.
test_detector_has_no_answering_primitive() {
  local hits
  hits=$(grep -nE 'send-keys|send_keys|xdotool|osascript|fm-send|auto-?accept|auto-?approve|press[ _-]?enter' \
    "$ROOT/bin/fm-gate-lib.sh" | grep -v '^\s*[0-9]*:\s*#' || true)
  [ -z "$hits" ] || fail "fm-gate-lib.sh must never grow an answering path, found: $hits"
  pass "the gate owner carries no answering primitive (detection only)"
}

test_incident_rendering_is_a_gate
test_styled_gate_is_a_gate
test_option_rows_with_selection_marker_are_a_gate
test_busy_pane_is_not_a_gate
test_finished_pane_is_not_a_gate
test_ordinary_prose_is_not_a_gate
test_choice_without_a_question_is_not_a_gate
test_question_without_a_choice_is_not_a_gate
test_empty_capture_is_not_a_gate
test_stdin_capture_is_accepted
test_detector_has_no_answering_primitive
