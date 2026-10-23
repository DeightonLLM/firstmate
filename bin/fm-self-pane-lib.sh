#!/usr/bin/env bash
# fm-self-pane-lib.sh - the single owner of "which pane is the watcher itself in".
#
# WHY THIS EXISTS. The always-on watcher (bin/fm-watch.sh) runs INSIDE the
# primary's own pane. The primary is not a crewmate: it does not write heartbeat
# lines to its OWN task record the way a crewmate writes to its report file.
# The crew-visibility check (bin/fm-crew-visibility.sh) therefore measured the
# primary as permanently silent and escalated it to the Captain as an invisible
# crew - the watcher accusing the agent that is doing the watching. Measured on
# 2026-10-23: "crew-silent: m3.1f-firstmate-boardland silent 120645s past the
# 1800s heartbeat bound" against the primary's own window default:wDB:p2.
# That was the third false positive in the same escalation treadmill.
#
# WHAT IT RESOLVES. The window TARGET of the pane this process runs in, in the
# same shape a task meta records in its window= field, because that is the
# space the watcher compares in:
#   herdr  "<herdr-session>:<pane-id>"  e.g. "default:wDB:p2"
#   tmux   "<session>:<window name>"   e.g. "firstmate:fm-m3.1f-firstmate-boardland"
# Resolution is innermost-first, matching bin/fm-backend.sh's fm_backend_detect
# and bin/fm-supervisor-target-lib.sh: a tmux pane nested inside herdr resolves
# to tmux.
#
# FAILS CLOSED, NEVER GUESSES. An unresolvable pane prints NOTHING. The caller
# must then behave exactly as it did before: no exclusion, no new skip, and no
# invented value. There is deliberately no fallback default - a wrong value here
# would either silence a real crew or hide a genuine breach, and both are worse
# than the status quo. The supervisor's own pane discovery
# (bin/fm-supervisor-target-lib.sh) is a DIFFERENT contract: it names a pane to
# inject into and is allowed to guess a legacy fallback, so it is not reused
# here.
#
# OVERRIDE. FM_WATCH_SELF_PANE sets the resolved value explicitly and wins over
# detection, for an operator whose backend does not expose its pane, and for
# tests that need a deterministic value. An empty override is treated as
# "not set" and detection runs.

# fm_self_pane_resolve: print the window target of the pane this process runs
# in, or nothing when it cannot be identified.
fm_self_pane_resolve() {
  if [ -n "${FM_WATCH_SELF_PANE:-}" ]; then
    printf '%s' "$FM_WATCH_SELF_PANE"
    return 0
  fi
  # tmux first (innermost-first), exactly like fm_backend_detect: $TMUX_PANE is
  # set in every tmux pane and names the pane precisely, so the window name is
  # read for THAT pane rather than for whichever pane tmux considers current.
  if [ -n "${TMUX_PANE:-}" ]; then
    tmux display-message -p -t "$TMUX_PANE" '#{session_name}:#{window_name}' 2>/dev/null || true
    return 0
  fi
  # herdr: the session is always the FIRST field of the target and the remainder
  # is the whole pane id (which itself contains a colon), the same composition
  # bin/fm-supervisor-target-lib.sh uses. The pane id alone is NOT a target.
  if [ "${HERDR_ENV:-}" = "1" ] && [ -n "${HERDR_PANE_ID:-}" ]; then
    printf '%s:%s' "${HERDR_SESSION:-default}" "$HERDR_PANE_ID"
    return 0
  fi
  return 0
}

# fm_self_pane_is_self: true when <window-target> is the watcher's own pane.
# Fails closed: an unidentifiable self pane matches NOTHING, so no check is
# skipped on a guess. The value compared against is FM_WATCH_SELF_PANE, which
# the watcher resolves once at startup from fm_self_pane_resolve.
fm_self_pane_is_self() {  # <window-target>
  local win=${1:-} self=${FM_WATCH_SELF_PANE:-}
  [ -n "$win" ] || return 1
  [ -n "$self" ] || return 1
  [ "$win" = "$self" ]
}
