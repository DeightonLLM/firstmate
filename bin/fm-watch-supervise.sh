#!/usr/bin/env bash
# fm-watch-supervise.sh - the arm owner for a primary with NO native turn-end hook.
#
# WHAT IT DOES
#   This script owns the watcher cycle for a primary that cannot re-arm itself.
#   The minimax-code (MCode) primary is that primary today: the mcode CLI has no
#   turn-end, Stop, session_end, or idle hook, no extension loader, and no event
#   push (docs/supervision-protocols/minimax-code.md owns that list), so the
#   model had to remember to re-arm the watcher BY HAND after every single wake.
#   That is the defect this script removes.
#
#   It runs bin/fm-watch-arm.sh in a LOOP. Each arm cycle either:
#     - surfaces a ROUTINE wake   -> classified in bash, absorbed here, and the
#                                    next cycle is armed again with no model turn;
#     - surfaces a CAPTAIN-RELEVANT wake -> classified, printed, and the script
#                                    EXITS so the primary's tracked background
#                                    task completes and the model is notified;
#     - FAILS to keep a watcher alive -> printed loudly and the script exits
#                                    NON-ZERO, because supervision is down and
#                                    only an operator can fix it.
#   A routine wake therefore costs no model turn at all, and the model is never
#   asked to remember a re-arm step.
#
# WHY IT IS NOT THE SUPERVISION HOST
#   bin/fm-supervision-host.sh is the designed answer for a primary with no
#   native hook, but it is not reachable from this primary today, for two
#   measured reasons:
#     1. bin/fm-supervision-engine-lib.sh sets
#        FM_SUPERVISION_ENGINES_VERIFIED='claude'. A host that names any other
#        engine is refused, and the default engine of a non-Claude primary has
#        no verified engine at all.
#     2. fm_supervision_host_attended_ready requires a verified dialog mirror
#        for the primary, and bin/fm-host-mirror.sh has no writer for
#        minimax-code, so the attended path reports
#        "no verified dialog mirror for minimax-code".
#   This script is the ADDITIVE replacement for the missing arm owner: it uses
#   the same arm, the same watcher, and the same shared classifier, and it needs
#   no engine and no mirror.
#
# WHAT IT NEVER DOES
#   - It NEVER uses a shell `&` for the watcher. The watcher is launched only by
#     bin/fm-watch-arm.sh, as that arm's own tracked child; this script runs the
#     ARM in its own foreground process tree. The prohibition on shell `&` is
#     about a backgrounded child being reaped when the CALL returns: this
#     script is itself the harness-owned tracked task, so its child cannot
#     outlive it. A process-group teardown takes the arm and the watcher down
#     together, exactly as bin/fm-claude-stop-autoarm.sh relies on.
#   - It NEVER swallows a captain-relevant wake. Escalation is the point.
#   - It NEVER exits 0 while supervision is down. A watcher that cannot be kept
#     alive is a non-zero exit with an unambiguous line.
#   - It NEVER starts a second watcher. bin/fm-watch-arm.sh owns that decision:
#     a live, fresh watcher is attached to, never replaced.
#   - It NEVER writes a project's files, drains the wake queue, or decides
#     anything about the fleet's work. It classifies wakes and hands them back.
#   - It NEVER competes with away mode. While state/.afk exists the away
#     daemon owns triage, so this script stands down instead of racing it.
#
# OUTPUT LINES (stdout; each one means exactly this)
#   watcher: started pid=<N> (beacon fresh)   the arm's own line, relayed
#                                              verbatim the moment the arm
#                                              verified a fresh watcher.
#   watcher: attached pid=<N> (beacon <age>s)  the arm's own line, relayed
#                                              verbatim: a live cycle already
#                                              existed and this cycle follows it.
#   supervise: routine wake absorbed (<reason>) - re-arming
#                                              a wake the shared classifier
#                                              proved not captain-relevant. No
#                                              model turn is spent on it.
#   supervise: ESCALATION - ...                a captain-relevant wake. The
#                                              reason and the arm's own lines
#                                              follow; supervision is handed
#                                              back to the primary.
#   supervise: PARKED after <N>s - ...         the bounded park interval ended
#                                              while the watcher was still
#                                              alive; a compact summary follows.
#   supervise: FAILED - ...                    the watcher could not be kept
#                                              alive. Supervision is DOWN and
#                                              the exit status is non-zero.
#
# EXIT STATUS
#   0  a captain-relevant wake was delivered and supervision was handed back to
#      the primary, or the bounded park interval ended with the watcher alive.
#   1  the watcher could not be kept alive. Supervision is DOWN.
#   2  usage error.
#
# ENVIRONMENT KNOBS
#   FM_WATCH_SUPERVISE_PARK_SECS      bounded park interval in seconds
#                                     (default 900). 0 means no bound. The
#                                     bound is enforced at cycle boundaries: a
#                                     healthy blocked watcher is never
#                                     interrupted, so the park fires at the
#                                     first boundary at or after the bound.
#   FM_WATCH_SUPERVISE_ARM_ATTEMPTS   consecutive arm attempts allowed before
#                                     the failure is declared (default 3).
#   FM_WATCH_SUPERVISE_CYCLE_GAP_SECS seconds between two routine cycles
#                                     (default 1). Keeps a fast-failing arm
#                                     from spinning.
#   FM_WATCH_SUPERVISE_ARM            the arm script to run. A TEST SEAM:
#                                     production always uses the sibling
#                                     bin/fm-watch-arm.sh.
#   FM_HOME / FM_STATE_OVERRIDE / FM_CONFIG_OVERRIDE
#                                     the usual home-scoped overrides.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
CONFIG="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"
export FM_HOME FM_ROOT STATE
mkdir -p "$STATE"

# The shared wake classifier. This is the SAME library bin/fm-watch.sh and
# bin/fm-supervise-daemon.sh source, so the captain-relevant verb set, the
# absorb-only-when-provably-working rule, and the keyed-decision fold have one
# definition instead of a third copy that can drift.
# shellcheck source=bin/fm-classify-lib.sh
. "$SCRIPT_DIR/fm-classify-lib.sh"
# The portable lock helpers (fm_lock_try_acquire, fm_lock_release).
# shellcheck source=bin/fm-wake-lib.sh
. "$SCRIPT_DIR/fm-wake-lib.sh"

# --- tunables ---------------------------------------------------------------
ARM="${FM_WATCH_SUPERVISE_ARM:-$SCRIPT_DIR/fm-watch-arm.sh}"
PARK_SECS="${FM_WATCH_SUPERVISE_PARK_SECS:-900}"
ARM_ATTEMPTS="${FM_WATCH_SUPERVISE_ARM_ATTEMPTS:-3}"
CYCLE_GAP_SECS="${FM_WATCH_SUPERVISE_CYCLE_GAP_SECS:-1}"
SUPERVISE_LOCK="$STATE/.watch-supervise.lock"
LOG="$STATE/.watch-supervise.log"
LOG_MAX_BYTES=${FM_WATCH_SUPERVISE_LOG_MAX_BYTES:-262144}
LOG_KEEP_LINES=${FM_WATCH_SUPERVISE_LOG_KEEP_LINES:-1000}

# A non-numeric knob is an actionable configuration error, not a silent
# fallback: a mistyped park bound must not read as "park immediately" or
# "never park". The check runs in THIS shell (not a command substitution) so a
# bad value stops the script instead of leaving the knob empty.
require_number() {  # <value> <name>
  case "${1:-}" in
    ''|*[!0-9]*)
      printf 'supervise: FAILED - %s must be a whole number of seconds (got "%s")\n' "$2" "${1:-}" >&2
      exit 2
      ;;
  esac
}
require_number "$PARK_SECS" FM_WATCH_SUPERVISE_PARK_SECS
require_number "$ARM_ATTEMPTS" FM_WATCH_SUPERVISE_ARM_ATTEMPTS
require_number "$CYCLE_GAP_SECS" FM_WATCH_SUPERVISE_CYCLE_GAP_SECS
case "$LOG_MAX_BYTES" in ''|*[!0-9]*|0) LOG_MAX_BYTES=262144 ;; esac
case "$LOG_KEEP_LINES" in ''|*[!0-9]*|0) LOG_KEEP_LINES=1000 ;; esac

# grep's line-buffered mode is what lets the arm's readiness line reach the
# caller the moment it is printed instead of sitting in a stdio buffer until
# the pipe closes. Every grep this repo ships supports it; the plain fallback
# keeps the script working where it does not.
#
# The probe must feed grep a MATCHING line: `grep -q ''` over empty input
# matches nothing and exits 1, which would silently select the block-buffered
# path and delay every readiness line until the cycle closed.
GREP_LINE_BUFFERED=
if printf 'probe\n' | grep --line-buffered -q 'probe' 2>/dev/null; then
  GREP_LINE_BUFFERED=1
fi

# --- counters ---------------------------------------------------------------
cycles=0
routine=0
escalated=0
failures=0
attempts=0

log() {  # <line>
  [ -n "${LOG:-}" ] && printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$LOG" 2>/dev/null
  return 0
}

trim_log() {
  local sz tmp
  [ -n "${LOG:-}" ] || return 0
  sz=$(wc -c < "$LOG" 2>/dev/null | tr -d '[:space:]') || return 0
  [ -n "$sz" ] || return 0
  [ "$sz" -ge "$LOG_MAX_BYTES" ] || return 0
  tmp="${LOG}.tmp.$$" || return 0
  tail -n "$LOG_KEEP_LINES" "$LOG" > "$tmp" 2>/dev/null && mv -f "$tmp" "$LOG" 2>/dev/null
  rm -f "$tmp" 2>/dev/null || true
  return 0
}

usage() {
  cat <<'USAGE'
usage: fm-watch-supervise.sh

Owns the watcher cycle for a primary with no native turn-end hook: it runs
bin/fm-watch-arm.sh in a loop, absorbs routine wakes in bash with no model
turn, exits with the reason on a captain-relevant wake, and exits non-zero
when the watcher cannot be kept alive.

Knobs: FM_WATCH_SUPERVISE_PARK_SECS (default 900, 0 = no bound),
FM_WATCH_SUPERVISE_ARM_ATTEMPTS (default 3),
FM_WATCH_SUPERVISE_CYCLE_GAP_SECS (default 1).
USAGE
}

# --- classification ---------------------------------------------------------
#
# Every predicate here comes from bin/fm-classify-lib.sh. These wrappers only
# decide what to DO with a classified wake; they never re-implement the
# captain-relevant test.

# classify_signal <space-separated-file-list> <state>
# A signal is captain-relevant when a listed status carries a captain-relevant
# verb. A no-verb signal is absorbed ONLY when every task it names is provably
# working; an unreadable or unresolvable task is not provably working, so it
# surfaces. That is the shared absorb-only-when-provably-working rule.
classify_signal() {  # <file-list> <state>
  local reason=$1 state=$2 f last distilled="" rel=0
  for f in $reason; do
    [ -e "$f" ] || continue
    last=$(last_status_line "$f")
    [ -n "$last" ] || continue
    distilled="${distilled}$(basename "$f"): ${last} | "
    status_is_captain_relevant "$last" && rel=1
  done
  distilled="${distilled% | }"
  if [ "$rel" = 1 ]; then
    printf 'escalate|%s' "$distilled"
    return
  fi
  # shellcheck disable=SC2086 # The list is deliberately word-split into paths.
  if signal_crew_provably_working $reason; then
    printf 'self|routine signal (crew provably working): %s' "${distilled:-no status}"
  else
    printf 'escalate|%s' "${distilled:-signal with no provably-working crew}"
  fi
}

# classify_stale <window> <detail> <state>
# The detail is the watcher's own parenthetical, which carries the reasons a
# stale pane is NOT routine: a crew the captain cannot see, and a persistent
# wedge. A pane whose status is captain-relevant is a captain wake. A declared
# pause is an EXPECTED idle. A pane that is provably working is mid-work. What
# is left is a transient stale, which the shared classifier does not call
# captain-relevant, so it is absorbed here.
classify_stale() {  # <window> <detail> <state>
  local win=$1 detail=$2 state=$3 task last
  task=$(window_to_task "$win" "$state")
  last=$(last_status_line "$state/$task.status")
  case "$detail" in
    *crew-silent*)
      printf 'escalate|crew silent: %s' "$detail"
      return
      ;;
    *"possible wedge"*|*demand-deep-inspection*)
      printf 'escalate|possible wedge: %s' "$detail"
      return
      ;;
  esac
  if [ -n "$last" ] && status_is_paused "$last"; then
    printf 'self|declared pause (awaiting external): %s' "$last"
    return
  fi
  if [ -n "$last" ] && status_is_captain_relevant "$last"; then
    printf 'escalate|stale + captain-relevant status: %s' "$last"
    return
  fi
  if crew_is_provably_working "$task"; then
    printf 'self|provably working: %s' "$win"
    return
  fi
  if crew_is_paused "$task"; then
    printf 'self|declared pause: %s' "$win"
    return
  fi
  printf 'self|transient stale: %s' "${last:-no status}"
}

# supervise_classify <reason> <state>
# Prints "<action>|<distilled>"; action is "self" (routine) or "escalate".
supervise_classify() {  # <reason> <state>
  local reason=$1 state=$2 arg detail decision
  case "$reason" in
    signal:*)
      arg="${reason#signal: }"
      decision=$(classify_signal "$arg" "$state")
      ;;
    stale:*)
      arg="${reason#stale: }"
      detail=""
      case "$arg" in
        *" ("*) detail="${arg#*" ("}"; arg="${arg%% \(*}" ;;
      esac
      decision=$(classify_stale "$arg" "$detail" "$state")
      ;;
    gate:*)
      # A crew parked on an approval gate is a captain decision, always. It is
      # never absorbed and never answered here.
      decision="escalate|${reason}"
      ;;
    check:*)
      # Authenticated check output is always actionable (the watcher's own
      # contract), and the shared classifier has no predicate that could call a
      # check wake routine. Fail-safe: escalate.
      decision="escalate|${reason}"
      ;;
    heartbeat|heartbeat:*)
      # In normal mode the watcher surfaces a heartbeat only when its
      # fleet-scan found an UNSURFACED captain-relevant status, so the wake
      # itself is the captain-relevant finding. There is no shared predicate
      # that could call it routine. Fail-safe: escalate.
      decision="escalate|${reason}"
      ;;
    *)
      decision="escalate|unclassified wake: ${reason}"
      ;;
  esac
  printf '%s' "$decision"
}

# capture_reason <capture-file>
# The watcher's own reason line, which the arm printed when the cycle closed.
# `gate:` is included on purpose: bin/fm-watch-arm.sh's own reason detector
# does not know that verb, so a gate cycle can close with a generic
# "cycle ended without an actionable reason" line beside the real gate line.
# The real reason wins here; the arm's gap is reported, not inherited.
capture_reason() {  # <capture-file>
  [ -f "$1" ] || return 0
  grep -E '^(signal:|stale:|check:|gate:|heartbeat($|:))' "$1" 2>/dev/null | head -1
}

# --- one arm cycle ----------------------------------------------------------

# run_cycle <capture-file>
# Runs the arm in THIS script's foreground process tree (never behind a shell
# `&`). The capture file keeps the arm's whole output for the classifier; the
# arm's readiness line is relayed to stdout as it is printed.
run_cycle() {  # <capture-file>
  local capture=$1 rc
  if [ -n "$GREP_LINE_BUFFERED" ]; then
    "$ARM" 2>&1 | tee "$capture" | grep --line-buffered -E '^watcher: (started|attached)'
  else
    "$ARM" 2>&1 | tee "$capture" | grep -E '^watcher: (started|attached)'
  fi
  rc=${PIPESTATUS[0]}
  return "$rc"
}

print_arm_lines() {  # <capture-file>
  local capture=$1
  [ -f "$capture" ] || return 0
  grep -E '^(watcher:|signal:|stale:|check:|gate:|heartbeat)' "$capture" 2>/dev/null \
    | head -8 | sed 's/^/supervise: arm: /'
  return 0
}

# --- supervisor lifecycle ----------------------------------------------------

# The capture file of the cycle in flight. It is removed on every exit path,
# so a parked, escalated or failed supervisor leaves no scratch behind.
CURRENT_CAPTURE=

supervisor_cleanup() {
  [ -n "$CURRENT_CAPTURE" ] && rm -f "$CURRENT_CAPTURE" 2>/dev/null
  fm_lock_release "$SUPERVISE_LOCK" 2>/dev/null || true
  return 0
}

escalate_and_exit() {  # <reason> <distilled> <capture-file>
  printf 'supervise: ESCALATION - a captain-relevant wake needs a handling turn now.\n'
  printf 'supervise: reason: %s\n' "$1"
  printf 'supervise: detail: %s\n' "$2"
  print_arm_lines "$3"
  printf 'supervise: supervision is handed back to the primary: re-arm with bin/fm-watch-supervise.sh\n'
  log "escalate: $1 -> $2"
  trim_log
  exit 0
}

fail_and_exit() {  # <message> <capture-file>
  printf 'supervise: FAILED - %s\n' "$1" >&2
  print_arm_lines "$2"
  printf 'supervise: supervision is DOWN. Fix the cause, then re-arm with bin/fm-watch-supervise.sh\n' >&2
  log "failed: $1"
  trim_log
  exit 1
}

park_and_exit() {  # <elapsed-seconds>
  printf 'supervise: PARKED after %ss - the watcher is still alive and the primary owns the next cycle.\n' "$1"
  printf 'supervise: summary cycles=%s routine=%s escalated=%s failures=%s\n' \
    "$cycles" "$routine" "$escalated" "$failures"
  printf 'supervise: re-arm to continue: bin/fm-watch-supervise.sh\n'
  log "parked after ${1}s cycles=$cycles routine=$routine escalated=$escalated failures=$failures"
  trim_log
  exit 0
}

# take_supervise_lock <deadline-epoch>
# One supervisor per home. A second invocation does not fight the first one for
# the watcher: it attaches, waits for the holder to end, and then takes over.
# The lock is reclaimed automatically when its holder is gone.
# Returns 1 when the lock could not be taken; the caller decides whether that
# is a park (the deadline passed) or a failure.
take_supervise_lock() {
  local holder deadline=$1
  if fm_lock_try_acquire "$SUPERVISE_LOCK"; then
    return 0
  fi
  holder=${FM_LOCK_HELD_PID:-}
  printf 'supervise: attached - supervisor pid=%s already owns the watcher cycle; waiting for it to end\n' \
    "${holder:-unknown}"
  while [ -n "$holder" ] && fm_pid_alive "$holder"; do
    if [ "$deadline" -gt 0 ] && [ "$(date +%s)" -ge "$deadline" ]; then
      return 1
    fi
    sleep 1
  done
  fm_lock_try_acquire "$SUPERVISE_LOCK" || return 1
  return 0
}

main() {
  local capture reason decision action distilled arm_rc started deadline elapsed
  case "${1:-}" in
    --help|-h) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
  esac

  if [ ! -x "$ARM" ]; then
    printf 'supervise: FAILED - the watcher arm is missing or not executable: %s\n' "$ARM" >&2
    exit 1
  fi

  # Away mode owns triage: the daemon classifies every wake while state/.afk
  # exists, so this supervisor stands down instead of racing it.
  if [ -e "$STATE/.afk" ]; then
    printf 'supervise: away mode owns triage (state/.afk is present) - not arming\n'
    log "stood down: away mode owns triage"
    exit 0
  fi

  # X mode lowers the watcher's check cadence; the arm inherits it exactly as
  # the Grok and Claude arms do.
  if [ -f "$CONFIG/x-mode.env" ]; then
    # shellcheck source=/dev/null
    . "$CONFIG/x-mode.env" || true
  fi

  started=$(date +%s)
  if [ "$PARK_SECS" -gt 0 ]; then
    deadline=$((started + PARK_SECS))
  else
    deadline=0
  fi

  take_supervise_lock "$deadline" || {
    elapsed=$(( $(date +%s) - started ))
    park_and_exit "$elapsed"
  }
  trap supervisor_cleanup EXIT

  while :; do
    if [ "$deadline" -gt 0 ] && [ "$(date +%s)" -ge "$deadline" ]; then
      elapsed=$(( $(date +%s) - started ))
      park_and_exit "$elapsed"
    fi

    capture=$(mktemp "$STATE/.watch-supervise-output.XXXXXX" 2>/dev/null || true)
    if [ -z "$capture" ]; then
      printf 'supervise: FAILED - could not create a capture file under %s\n' "$STATE" >&2
      exit 1
    fi
    CURRENT_CAPTURE="$capture"

    run_cycle "$capture"
    arm_rc=$?
    cycles=$((cycles + 1))
    reason=$(capture_reason "$capture")

    if [ -n "$reason" ]; then
      decision=$(supervise_classify "$reason" "$STATE")
      action=${decision%%|*}
      distilled=${decision#*|}
      if [ "$action" = "self" ]; then
        routine=$((routine + 1))
        attempts=0
        log "routine: $reason -> $distilled"
        trim_log
        printf 'supervise: routine wake absorbed (%s) - re-arming\n' "$reason"
        rm -f "$capture" 2>/dev/null || true
        CURRENT_CAPTURE=
        if [ "$CYCLE_GAP_SECS" -gt 0 ]; then
          sleep "$CYCLE_GAP_SECS"
        fi
        continue
      fi
      escalated=$((escalated + 1))
      escalate_and_exit "$reason" "$distilled" "$capture"
    fi

    # No wake reason: the arm closed without one, so the watcher could not be
    # kept alive. Try again within the attempt budget, then fail loudly.
    failures=$((failures + 1))
    attempts=$((attempts + 1))
    log "failed cycle: rc=$arm_rc attempts=$attempts"
    trim_log
    if [ "$attempts" -lt "$ARM_ATTEMPTS" ]; then
      printf 'supervise: FAILED - attempt %s of %s; the watcher is not alive, re-arming\n' \
        "$attempts" "$ARM_ATTEMPTS" >&2
      print_arm_lines "$capture"
      rm -f "$capture" 2>/dev/null || true
      CURRENT_CAPTURE=
      if [ "$CYCLE_GAP_SECS" -gt 0 ]; then
        sleep "$CYCLE_GAP_SECS"
      fi
      continue
    fi
    fail_and_exit "the watcher could not be kept alive after $attempts attempt(s)" "$capture"
  done
}

main "$@"
