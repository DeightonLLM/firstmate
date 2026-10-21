#!/usr/bin/env bash
# fm-gate-lib.sh - the ONE owner of interactive-human-gate detection in
# rendered pane text.
#
# WHY THIS EXISTS (silent unattended stall, 2026-10-13): a crewmate parked on an
# interactive approval dialog is invisible to firstmate. The backend reports that
# pane as IDLE - herdr renders it as `agent_status: idle`, the semantic busy
# contract answers `idle` - and `idle` is ALSO exactly what a crew that finished
# its work reports. Nothing downstream could tell the two apart, so a lane
# blocked on an "Allow? Yes/No" dialog burned a slot with no alarm while every
# status read showed a healthy, finished lane. `idle` was carrying two meanings
# at once.
#
# THE CONTRACT: fm_gate_pane_awaiting_human is a POSITIVE, structural read of a
# bounded pane capture. It returns 0 only when the capture positively renders an
# interactive approval/permission gate waiting on a person, and non-zero for
# everything else - including a pane that is merely busy, empty, finished, or
# unreadable. It never infers a state from silence, never inspects process
# tables, and is harness-agnostic: it matches the SHAPE of an interactive choice
# (something asking the user to approve, plus a yes/no affordance to answer it
# with), not any one runtime's chrome, so a harness with no bespoke rule inherits
# the protection.
#
# STALL POLICY (captain, 2026-10-13): this owner DETECTS a gate and nothing else.
# It must never grow an answering path. No auto-Yes, no auto-Enter, no
# default-accept, no scripted send-keys: a gate is surfaced to the captain as a
# typed `gate:` wake and stays his decision. See docs/watcher-continuity.md
# ("Stall policy") and tests/fm-gate-lib.test.sh, which pins that no unattended
# path ever answers a detected gate.
#
# Detection deliberately follows the fleet's existing bias. A false "gate" only
# re-surfaces a pane a human should have looked at anyway (for example a finished
# pane whose transcript quotes a prompt), while a false "not a gate" is the silent
# stall this owner exists to prevent. Callers still layer their own dedup on top
# (bin/fm-watch.sh surfaces once per distinct rendered capture), so a persistent
# gate does not become a wake storm.
#
# Reuses the fleet-wide ANSI stripper (bin/fm-composer-lib.sh) rather than owning
# a second one, so a styled gate is detected exactly like a plain one.
# Re-sourcing is a cheap idempotent redefinition, so this file carries no include
# guard, matching bin/fm-tmux-lib.sh and bin/fm-composer-lib.sh.

_FM_GATE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || _FM_GATE_LIB_DIR="."
if [ -r "$_FM_GATE_LIB_DIR/fm-composer-lib.sh" ]; then
  # shellcheck source=bin/fm-composer-lib.sh
  . "$_FM_GATE_LIB_DIR/fm-composer-lib.sh"
fi

# Dialog titles some agents render above the choice. Lowercase: callers match
# against case-folded text (see fm_gate_plain).
FM_GATE_TITLE_RE='dangerous command|permission (required|denied)|approval required|request(ing)? permission|confirm (command|action|run)'
# A question asking the user to approve something, alone on its line. Anchored at
# both ends so ordinary prose ("we should run the suite") never matches.
FM_GATE_QUESTION_RE='^[[:space:]]*(allow|approve|authorise|authorize|confirm|proceed|continue|trust|run|execute)[^?]*\?[[:space:]]*$'
# A one-row choice affordance: "Yes,No", "Yes / No", "Yes|No".
FM_GATE_CHOICE_ROW_RE='^[[:space:]]*[^[:alnum:]]*yes[[:space:]]*[,/|][[:space:]]*no[[:space:]]*$'
# A standalone option row, with or without a selection marker ("> Yes", "* No").
FM_GATE_OPTION_RE='^[[:space:]]*[^[:alnum:]]*(yes|no)[[:space:]]*$'

# Plain, lowercase text for structural matching: drop ANSI through the shared
# fleet-wide owner when it is available, then case-fold so every pattern above is
# lowercase. Case folding uses bash expansion rather than `tr` on purpose: the
# no-mistakes gate runs the helper under a PATH holding only bash, git, grep, sed,
# head, cut, tail, dirname, and perl, and an external `tr` there both fails and
# prints to the helper's stdout.
fm_gate_plain() {
  local plain
  if [ "$(type -t fm_composer_strip_ansi 2>/dev/null)" = function ]; then
    plain=$(fm_composer_strip_ansi) || return 1
  else
    plain=$(sed -e "s/\x1b\[[0-9;?]*[a-zA-Z]//g") || return 1
  fi
  printf "%s\n" "${plain,,}"
}

# 0 iff <pane-text> positively renders an interactive human gate. With no
# argument the capture is read from stdin, so a caller holding a capture in a
# pipe never has to materialize it into a variable first.
fm_gate_pane_awaiting_human() {  # [pane-text]
  local text plain
  if [ "$#" -eq 0 ]; then
    text=$(cat)
  else
    text="$1"
  fi
  [ -n "$text" ] || return 1
  plain=$(printf "%s\n" "$text" | fm_gate_plain) || return 1
  [ -n "$plain" ] || return 1

  # Step 1: something must be ASKING the user to approve something.
  if ! printf "%s\n" "$plain" | grep -qE "$FM_GATE_TITLE_RE" \
     && ! printf "%s\n" "$plain" | grep -qE "$FM_GATE_QUESTION_RE"; then
    return 1
  fi

  # Step 2: there must be a way to ANSWER it. A compact choice row is the
  # strongest evidence; separate yes and no option rows are equally conclusive.
  if printf "%s\n" "$plain" | grep -qE "$FM_GATE_CHOICE_ROW_RE"; then
    return 0
  fi
  # Keep the option-row shape as the filter and match only the trailing word, so a
  # selection marker ("> ", "* ") stays legal without swallowing the answer.
  printf "%s\n" "$plain" | grep -E "$FM_GATE_OPTION_RE" | grep -qE "[^[:alnum:]]*yes[[:space:]]*$" \
    && printf "%s\n" "$plain" | grep -E "$FM_GATE_OPTION_RE" | grep -qE "[^[:alnum:]]*no[[:space:]]*$"
}
