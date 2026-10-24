#!/usr/bin/env bash
# fm-crew-visibility.sh - detect a crewmate that has gone INVISIBLE to the captain.
#
# Why this exists: on 2026-10-11 the captain dispatched an agy/Gemini crewmate
# that ran for 25+ minutes without a single line in its status file. Nothing
# noticed. Nothing enforced the reporting contract the brief already stated. The
# captain's experience was "I have an invisible agent I can't read", and the
# ruling was to enforce the rule in code instead of describing it. A rule stated
# only in a brief is a request.
#
# This is the pure detector. It reads only files under one home's state/ dir and
# answers one question about ONE task: has this crew gone silent for longer than
# its reporting bound? It is harness-agnostic and backend-agnostic on purpose -
# it names no harness, no model, and no backend, so registering a new adapter
# (agy) can never silently fall outside the check.
#
# It is deliberately NOT a reader of state/<id>.status as current-state truth.
# That file is an append-only EVENT log (see bin/fm-crew-state.sh): it records
# what a crew SAID, and nothing at all when a crew says nothing. That is exactly
# the property this check needs - "the last thing this crew said was N seconds
# ago" - so the log is the right signal here, read strictly as a timestamp of
# the last report and never as a statement of what the crew is doing now.
#
# Bounds (both overridable, both defaulting to a value that catches the real
# incident without flagging a crew that is quietly finishing its work):
#   FM_CREW_VISIBILITY_GRACE_SEC  silence allowed BEFORE the crew's first
#                                 report ever, measured from spawn. Default 300.
#   FM_CREW_VISIBILITY_STALE_SEC  silence allowed AFTER a report, i.e. the
#                                 heartbeat bound. Default 1800, so one token
#                                 line buys 30 minutes, not the whole run.
# Setting either to <= 0 disables that half of the check; with both disabled
# this script is inert and always exits 0.
#
# A crew that legitimately stopped is never a breach: a terminal verb (done,
# needs-decision, blocked, failed) and a declared wait (paused, captain-held) are
# exemptions. Those crews said something and are owed nothing further.
#
# Liveness is the CALLER's job. This detector never probes a pane, because a
# stale meta from a torn-down crew is history, not an invisible agent: bin/
# fm-watch.sh calls it only for a window whose backend read just succeeded.
#
# Usage:
#   fm-crew-visibility.sh <task-id> [state-dir]
#
# Output: one captain-facing breach line on stdout and exit 1 when the task has
# gone silent past its bound; no output and exit 0 otherwise. Exit 2 on a usage
# error (no id). Never writes anything.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${2:-${FM_STATE_OVERRIDE:-$FM_HOME/state}}"

ID=${1:-}
[ -n "$ID" ] || { echo "usage: fm-crew-visibility.sh <task-id> [state-dir]" >&2; exit 2; }

# shellcheck source=bin/fm-classify-lib.sh
. "$SCRIPT_DIR/fm-classify-lib.sh"

case "$ID" in */*|.|..) echo "fm-crew-visibility.sh: refusing unsafe task id: $ID" >&2; exit 2 ;; esac

# Portable stat: macOS/BSD uses -f %m, Linux/GNU uses -c %Y. Same platform split
# fm-watch.sh uses; do not write the `stat -f || stat -c` fallback form, which
# dumps filesystem garbage on Linux before failing.
if [ "$(uname)" = Darwin ]; then
  _vis_mtime() { stat -f %m "$1" 2>/dev/null; }
else
  _vis_mtime() { stat -c %Y "$1" 2>/dev/null; }
fi

META="$STATE/$ID.meta"
LOG="$STATE/$ID.status"

# No metadata means no crew was ever recorded here: nothing to check, and no
# reason to invent one. This is also what makes the check inert on an idle home.
[ -f "$META" ] || exit 0

# The first-report grace is the default the whole fleet is told about: the
# brief handed to every crewmate (bin/fm-brief.sh) says "default 300s", and
# bin/fm-watch.sh falls back to 300s when it cannot read the bound out of the
# breach line. Those two are the published contract, so the detector's default
# is 300s too.
#
# A host whose own lanes legitimately run longer can raise it per-process with
# FM_CREW_VISIBILITY_GRACE_SEC; that override existed before and is unchanged.
# Changing the DEFAULT alone would silently contradict the contract the crew
# was briefed on, which is how the bound drifted to 900s once already.
GRACE=${FM_CREW_VISIBILITY_GRACE_SEC:-300}
STALE=${FM_CREW_VISIBILITY_STALE_SEC:-1800}
case "$GRACE" in ''|*[!0-9]*) GRACE=300 ;; esac
case "$STALE" in ''|*[!0-9]*) STALE=1800 ;; esac
# Both halves disabled: the whole check is off.
[ "$GRACE" -le 0 ] && [ "$STALE" -le 0 ] && exit 0

# FM_CREW_VISIBILITY_NOW is a test seam so the bounds can be exercised without
# sleeping. Production callers never set it.
NOW=${FM_CREW_VISIBILITY_NOW:-$(date +%s)}
case "$NOW" in ''|*[!0-9]*) NOW=$(date +%s) ;; esac

# Spawn time: the explicit stamp fm-spawn.sh writes, else the meta's own mtime -
# but only while that mtime is still a plausible launch stamp. Without spawned_at=
# a meta's mtime is a WEAK proxy: state/ is append-only history that tooling
# back-dates and that unrelated appends (fm-pr-check records pr=, fm-x-link
# records x_request=) bump. A meta older than the trust window cannot tell a
# just-launched crew from a long-idle record, so the first-report grace is not
# claimed from it; the heartbeat bound above is unaffected and still fires. This
# is disclosed uncertainty, not a silent skip: every spawn from now on carries
# spawned_at=, so only pre-existing records take this path.
SPAWNED_AT=$(grep -m1 '^spawned_at=' "$META" 2>/dev/null | cut -d= -f2- || true)
case "$SPAWNED_AT" in ''|*[!0-9]*) SPAWNED_AT=$(_vis_mtime "$META") ;; esac
case "$SPAWNED_AT" in ''|*[!0-9]*) exit 0 ;; esac
META_TRUST=${FM_CREW_VISIBILITY_META_TRUST_SEC:-86400}
case "$META_TRUST" in ''|*[!0-9]*) META_TRUST=86400 ;; esac
if ! grep -q '^spawned_at=[0-9]' "$META" 2>/dev/null \
   && [ $(( NOW - SPAWNED_AT )) -gt "$META_TRUST" ]; then
  SPAWNED_AT=''
fi

LAST=$(last_status_line "$LOG" 2>/dev/null || true)

# A crew that finished, failed, parked on a decision, or declared an external
# wait is not invisible. It said something and owes nothing more.
if [ -n "$LAST" ] && { status_is_terminal_verb "$LAST" || status_is_paused_or_captain_held "$LAST"; }; then
  exit 0
fi

if [ -n "$LAST" ]; then
  # It has reported before: this is the heartbeat bound, not the first-report
  # grace. Recomputed from the file's CURRENT mtime every call, so a line written
  # six hours ago is never mistaken for a live report.
  LAST_REPORT=$(_vis_mtime "$LOG")
  case "$LAST_REPORT" in ''|*[!0-9]*) exit 0 ;; esac
  BOUND=$STALE
  [ "$BOUND" -le 0 ] && exit 0
  SILENCE=$(( NOW - LAST_REPORT ))
  [ "$SILENCE" -gt "$BOUND" ] || exit 0
  VERB=$(status_line_verb "$LAST")
  [ -n "$VERB" ] || VERB=none
  REASON="silent ${SILENCE}s past the ${BOUND}s heartbeat bound; last report ${VERB}"
else
  # Never reported at all - the incident this file exists for. Measured from
  # spawn, and a status file that exists but holds no line is still "never
  # reported", so an empty file cannot masquerade as a report. With no trustworthy
  # spawn stamp there is no sound way to say how long it has been silent, so the
  # crew is left alone rather than accused on a guess.
  [ -n "$SPAWNED_AT" ] || exit 0
  SILENCE=$(( NOW - SPAWNED_AT ))
  [ "$SILENCE" -gt "$GRACE" ] || exit 0
  REASON="silent ${SILENCE}s past the ${GRACE}s first-report grace; never reported"
fi

WINDOW=$(grep -m1 '^window=' "$META" 2>/dev/null | cut -d= -f2- || true)
printf 'crew-silent: %s %s (window %s)\n' "$ID" "$REASON" "${WINDOW:-unknown}"
exit 1