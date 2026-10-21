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
# ONE MODEL TURN PER MEANINGFUL PEER UPDATE
#   A peer that drops files into this home's comms inbox produces one comms
#   receipt per file, and every receipt enqueues its own signal wake. Two
#   different kinds of thing arrive from the same source, and the supervisor
#   must treat them differently:
#
#     - a MESSAGE addressed to the Controller. A peer wrote to the Captain.
#       It escalates immediately, every time, and never waits for a window.
#     - a MACHINE ARTEFACT - a published board, a ledger, a status snapshot
#       that the peer republishes on a timer. It is on disk, the receipt is
#       durable, and it changes on the peer's clock, not on the Captain's
#       need. The first one escalates; the repeats inside the coalescing
#       window are absorbed into the next escalation's summary instead of
#       costing a model turn each.
#
#   Measured on the Controller: one peer republished CAPTAIN-BOARD.html and
#   lane-ledger.tsv nineteen times in sixty minutes, and every republication
#   escalated and woke the Captain for a machine ledger being rewritten on a
#   timer. The classification is made from the RECEIPT's own metadata - the
#   source id and the artefact name the pending wake record carries - never
#   from a guess about what a message filename looks like, and the
#   machine-artefact table is CLOSED: a name it does not recognise is
#   escalated, never absorbed.
#
#   NOTHING IS DROPPED. An absorbed republication is still on disk and still
#   in the durable receipt ledger. The supervisor's job is to summarise it -
#   how many were absorbed, from which source, the latest artefact name and
#   its sha256, and when the window resets - not to consume it.
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
#     The pending wake records are READ, to summarise them; they are never
#     drained, acknowledged or rewritten. The primary owns the queue.
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
#   supervise: republication absorbed (<summary>) - re-arming
#                                              a republished machine artefact
#                                              that arrived inside the
#                                              coalescing window. It is
#                                              summarised, not escalated, and
#                                              no model turn is spent on it.
#   supervise: peer: source=<id> message=<name> sha=<sha256>
#                                              a peer file that is a message
#                                              addressed to the Controller. It
#                                              is named in the escalation, so
#                                              the Captain knows what to read.
#   supervise: peer: source=<id> absorbed=<n> latest=<name> sha=<sha256>
#             window-resets-at=<epoch> (<time>)
#                                              the coalescing summary: how many
#                                              republications were folded in,
#                                              from which source, the latest
#                                              artefact and its digest, and
#                                              when the window resets.
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
#   FM_WATCH_SUPERVISE_COALESCE_SECS  the peer republication coalescing window
#                                     in seconds (default 600). A machine
#                                     artefact republished by the same source
#                                     inside the window is absorbed instead of
#                                     escalating; the window is anchored at
#                                     the last escalation of that source, so
#                                     the Captain is re-notified at least once
#                                     per window while the peer is active.
#                                     0 disables coalescing entirely.
#   FM_WATCH_SUPERVISE_MACHINE_ARTEFACTS
#                                     the CLOSED list of artefact names that
#                                     may be coalesced, space separated
#                                     (default: CAPTAIN-BOARD.html
#                                     NEXT-BOARD.md LANE-CLAIMS.md
#                                     lane-ledger.tsv). A name that is not on
#                                     the list is escalated, never absorbed.
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

# The peer republication coalescing window. 600 seconds is the default because
# the measured republication cadence of the peer that produced the noise was
# roughly one republication every three minutes: a 600s window spans about
# three republications, so one escalation per window replaces one escalation
# per republication. The window is anchored at the LAST ESCALATION of that
# source, never at the last republication, so a peer that keeps publishing
# still re-notifies the Captain once per window instead of being folded away
# forever. 0 disables coalescing: every republication escalates, which is
# the pre-coalescing behaviour.
COALESCE_SECS="${FM_WATCH_SUPERVISE_COALESCE_SECS:-600}"

# The CLOSED table of artefact names that may be coalesced. A name that is
# not on this list is escalated, never absorbed: a new kind of peer artefact,
# and any file the classifier cannot confidently call a republished machine
# artefact, reaches the Captain.
MACHINE_ARTEFACTS="${FM_WATCH_SUPERVISE_MACHINE_ARTEFACTS:-CAPTAIN-BOARD.html NEXT-BOARD.md LANE-CLAIMS.md lane-ledger.tsv}"

# The durable per-source coalescing state. It survives the supervisor's own
# exit and re-arm, because the supervisor hands the cycle back to the primary
# between one coalescing window and the next.
COALESCE_STATE="$STATE/.watch-supervise-coalesce"

TAB=$'\t'

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
require_number "$COALESCE_SECS" FM_WATCH_SUPERVISE_COALESCE_SECS
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
turn, coalesces republished peer machine artefacts, exits with the reason on
a captain-relevant wake, and exits non-zero when the watcher cannot be kept
alive.

Knobs: FM_WATCH_SUPERVISE_PARK_SECS (default 900, 0 = no bound),
FM_WATCH_SUPERVISE_ARM_ATTEMPTS (default 3),
FM_WATCH_SUPERVISE_CYCLE_GAP_SECS (default 1),
FM_WATCH_SUPERVISE_COALESCE_SECS (default 600, 0 = no coalescing),
FM_WATCH_SUPERVISE_MACHINE_ARTEFACTS (default: the published board, next
board, lane claims and lane ledger names).
USAGE
}

# --- peer receipt coalescing ------------------------------------------------
#
# A peer that drops files into this home's comms inbox produces one comms
# receipt per file, and every receipt enqueues its own signal wake. Two
# different kinds of thing arrive from the same source, and the supervisor
# must treat them differently:
#
#   * a MESSAGE addressed to the Controller - a peer wrote to the Captain. It
#     escalates immediately, every time, and never waits for a window.
#   * a MACHINE ARTEFACT - a published board, a ledger, a status snapshot the
#     peer republishes on a timer. It is on disk, the receipt is durable, and
#     it changes on the peer's clock, not on the Captain's need, so the
#     repeats inside the coalescing window are absorbed into the next
#     escalation's summary instead of costing a model turn each.
#
# The decision is made from the RECEIPT's own metadata - the source id and the
# artefact name the pending wake record carries - and never from a guess about
# what a message filename looks like. The machine-artefact table is CLOSED: a
# name it does not recognise is escalated, never absorbed, so a new kind of
# artefact reaches the Captain instead of being silently folded away.
#
# NOTHING IS DROPPED. An absorbed republication is still on disk and still in
# the durable receipt ledger; the supervisor's job is to summarise it - how
# many were absorbed, from which source, the latest artefact name and its
# sha256, and when the window resets - not to consume it. The pending wake
# records are READ to summarise them; they are never drained, acknowledged or
# rewritten. The primary owns the queue.

PEER_ACTION=
PEER_DETAIL=
PEER_SUMMARY=

# is_machine_artefact <name>
# 0 when <name> is a known machine artefact: a published board, a ledger or a
# status snapshot that a peer republishes on a timer. The table is closed, so
# a name it does not recognise returns 1 and is escalated instead of absorbed.
# A published artefact's own publish-stamped backup copy (for example
# "CAPTAIN-BOARD.html.bak-publish-20261021T1948Z") is the same artefact, so a
# base name followed by a dot matches too.
is_machine_artefact() {  # <name>
  local name=$1 base
  [ -n "$name" ] || return 1
  # shellcheck disable=SC2086 # The table is deliberately word-split into names.
  for base in $MACHINE_ARTEFACTS; do
    [ -n "$base" ] || continue
    case "$name" in
      "$base"|"$base".*) return 0 ;;
    esac
  done
  return 1
}

# peer_pending_names <source>
# Print the artefact name of every comms receipt of <source> that is still
# PENDING in the durable wake queue, oldest first.
#
# READ-ONLY BY CONTRACT. This script never drains, acknowledges or rewrites
# the wake queue; it reads the pending records only so it can summarise them.
# The queue lock is not taken: the queue is append-only and a record is
# written with one append, so a torn read can only ever lose a record (which
# makes the supervisor escalate more, never less).
peer_pending_names() {  # <source>
  local src=$1
  [ -s "$FM_WAKE_QUEUE" ] || return 0
  awk -F '\t' -v src="$src" -v key="$src.status" '
    NF >= 5 && $3 == "signal" && $4 == key {
      pref = "comms received from " src ": "
      if (index($5, pref) == 1) {
        name = substr($5, length(pref) + 1)
        sub(/[ ]*corr=[A-Za-z0-9]+$/, "", name)
        if (name != "") print name
      }
    }
  ' "$FM_WAKE_QUEUE" 2>/dev/null
}

# peer_ledger_entries <source>
# Print "<sha256>\t<name>" for every entry of the source's comms receipt
# ledger, in receipt order. The ledger is the receipt's own durable metadata:
# one line per received file, carrying the full digest.
peer_ledger_entries() {  # <source>
  local src=$1 ledger
  ledger="$STATE/comms-receipts/$src/receipts.tsv"
  [ -f "$ledger" ] || return 0
  awk -F '\t' 'NF >= 2 { print $1 "\t" $2 }' "$ledger" 2>/dev/null
}

# --- the durable coalescing state -------------------------------------------
#
# One record per peer source:
#
#   <source> <seen> <anchor> <absorbed> <name> <sha>
#
#   seen     the ledger index just after the last receipt this supervisor has
#            already accounted for. It is what stops the same pending receipt
#            from being counted twice when the loop runs another cycle.
#   anchor   the epoch of the last escalation of this source. The coalescing
#            window is anchored here, so the Captain is re-notified once per
#            window while the peer keeps publishing.
#   absorbed how many republications were absorbed and NOT yet reported in an
#            escalation. The next escalation reports and resets it.
#   name/sha the latest machine artefact of this source, so an escalation can
#            name it even when this cycle carried only a message.
#
# Empty fields are written as "-" because a tab-separated field that is
# genuinely empty would be swallowed by the reader's field splitting.

COAL_SEEN=0
COAL_ANCHOR=0
COAL_ABSORBED=0
COAL_NAME=
COAL_SHA=

coalesce_load() {  # <source>
  local src=$1 s sn an ab nm sh
  COAL_SEEN=0
  COAL_ANCHOR=0
  COAL_ABSORBED=0
  COAL_NAME=
  COAL_SHA=
  [ -f "$COALESCE_STATE" ] || return 0
  while IFS="$TAB" read -r s sn an ab nm sh; do
    [ "$s" = "$src" ] || continue
    case "$sn" in ''|*[!0-9]*) sn=0 ;; esac
    case "$an" in ''|*[!0-9]*) an=0 ;; esac
    case "$ab" in ''|*[!0-9]*) ab=0 ;; esac
    COAL_SEEN=$sn
    COAL_ANCHOR=$an
    COAL_ABSORBED=$ab
    [ "$nm" = "-" ] && nm=
    [ "$sh" = "-" ] && sh=
    COAL_NAME=$nm
    COAL_SHA=$sh
    return 0
  done < "$COALESCE_STATE"
  return 0
}

coalesce_save() {  # <source> <seen> <anchor> <absorbed> <name> <sha>
  local src=$1 seen=$2 anchor=$3 absorbed=$4 name=$5 sha=$6 tmp out='' s a b c d e
  [ -n "$name" ] || name='-'
  [ -n "$sha" ] || sha='-'
  if [ -f "$COALESCE_STATE" ]; then
    while IFS="$TAB" read -r s a b c d e; do
      [ -n "$s" ] || continue
      [ "$s" = "$src" ] && continue
      out="${out}${s}${TAB}${a}${TAB}${b}${TAB}${c}${TAB}${d}${TAB}${e}
"
    done < "$COALESCE_STATE"
  fi
  out="${out}${src}${TAB}${seen}${TAB}${anchor}${TAB}${absorbed}${TAB}${name}${TAB}${sha}
"
  tmp=$(mktemp "$STATE/.watch-supervise-coalesce.XXXXXX" 2>/dev/null) || return 1
  if ! printf '%s' "$out" > "$tmp" 2>/dev/null; then
    rm -f "$tmp" 2>/dev/null || true
    return 1
  fi
  if ! mv -f "$tmp" "$COALESCE_STATE" 2>/dev/null; then
    rm -f "$tmp" 2>/dev/null || true
    return 1
  fi
  return 0
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

# peer_unverified_escalation <source> <why>
# The receipt metadata and the pending wake records disagree, so the
# classification cannot be trusted. The fail-safe applies: escalate, and say
# what could not be trusted. Nothing is folded away.
peer_unverified_escalation() {  # <source> <why>
  local src=$1 why=$2
  PEER_ACTION=escalate
  PEER_DETAIL="unverified peer receipt from ${src}: ${why}"
  PEER_SUMMARY="supervise: peer: source=${src} unverified=${why}"
  return 0
}

# peer_coalesce_line <source> <absorbed> <name> <sha> <resets-at>
# The one line that says nothing was dropped: how many republications were
# folded in, from which source, the latest artefact and its digest, and when
# the window resets.
peer_coalesce_line() {  # <source> <absorbed> <name> <sha> <resets-at>
  local src=$1 absorbed=$2 name=$3 sha=$4 resets=$5 when
  when=$(date -d "@$resets" '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null) \
    || when=$(date -r "$resets" '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null) \
    || when=''
  [ -n "$name" ] || name=none
  [ -n "$sha" ] || sha=none
  if [ -n "$when" ]; then
    printf 'supervise: peer: source=%s absorbed=%s latest=%s sha=%s window-resets-at=%s (%s)\n' \
      "$src" "$absorbed" "$name" "$sha" "$resets" "$when"
  else
    printf 'supervise: peer: source=%s absorbed=%s latest=%s sha=%s window-resets-at=%s\n' \
      "$src" "$absorbed" "$name" "$sha" "$resets"
  fi
  return 0
}

# peer_receipt_decision <source>
# Decide what the supervisor does with one peer's pending comms receipts.
#
# Sets PEER_ACTION to "escalate" or "absorb", PEER_DETAIL to a one-line
# summary, and PEER_SUMMARY to the extra lines an escalation must print.
# Returns 1 when the source has nothing pending, so the caller can fall back
# to the ordinary classifier.
peer_receipt_decision() {  # <source>
  local src=$1
  PEER_ACTION=
  PEER_DETAIL=
  PEER_SUMMARY=

  local -a pnames=() lsha=() lname=()
  local name sha

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    pnames[${#pnames[@]}]=$name
  done <<EOF
$(peer_pending_names "$src")
EOF
  local pending=${#pnames[@]}
  [ "$pending" -gt 0 ] || return 1

  while IFS="$TAB" read -r sha name; do
    [ -n "$name" ] || continue
    lsha[${#lsha[@]}]=$sha
    lname[${#lname[@]}]=$name
  done <<EOF
$(peer_ledger_entries "$src")
EOF
  local total=${#lsha[@]}

  # The pending wake records and the receipt ledger must agree about what
  # arrived: the pending block is the ledger's tail, in the same order. A
  # disagreement means the classification cannot be trusted, and the
  # fail-safe is to escalate.
  if [ "$total" -lt "$pending" ]; then
    peer_unverified_escalation "$src" "the receipt ledger holds fewer entries than the pending wake records"
    return 0
  fi
  local i
  for ((i = 0; i < pending; i++)); do
    if [ "${lname[$total - pending + i]}" != "${pnames[$i]}" ]; then
      peer_unverified_escalation "$src" "the pending wake records and the receipt ledger disagree about what arrived"
      return 0
    fi
  done

  coalesce_load "$src"
  local seen=$COAL_SEEN anchor=$COAL_ANCHOR absorbed=$COAL_ABSORBED
  local stored_name=$COAL_NAME stored_sha=$COAL_SHA

  # The receipts this supervisor has not accounted for yet. The cursor skips
  # the receipts already folded into an earlier decision, so the same pending
  # record is never counted twice when the loop runs another cycle.
  local start=$((total - pending))
  if [ "$seen" -gt "$start" ]; then
    start=$seen
  fi

  local machine=0 other=0
  local -a other_names=() other_shas=()
  local last_machine_name='' last_machine_sha=''
  for ((i = start; i < total; i++)); do
    name=${lname[$i]}
    sha=${lsha[$i]}
    if is_machine_artefact "$name"; then
      machine=$((machine + 1))
      last_machine_name=$name
      last_machine_sha=$sha
    else
      other=$((other + 1))
      other_names[${#other_names[@]}]=$name
      other_shas[${#other_shas[@]}]=$sha
    fi
  done

  local now resets summary j reported
  now=$(date +%s)
  resets=$((now + COALESCE_SECS))

  # A message addressed to the Controller escalates immediately, every time,
  # and never waits for the window. Any republication that arrived with it is
  # folded into the SAME escalation's summary, so it is reported rather than
  # dropped.
  if [ "$other" -gt 0 ]; then
    summary=''
    for ((j = 0; j < other; j++)); do
      summary="${summary}supervise: peer: source=${src} message=${other_names[$j]} sha=${other_shas[$j]}
"
    done
    reported=$((absorbed + machine))
    # The latest machine artefact is this batch's, or the one the last
    # decision left behind: the summary must always name an artefact.
    local mname=$last_machine_name msha=$last_machine_sha
    [ -n "$mname" ] || { mname=$stored_name; msha=$stored_sha; }
    summary="${summary}$(peer_coalesce_line "$src" "$reported" "$mname" "$msha" "$resets")
"
    PEER_ACTION=escalate
    PEER_DETAIL="peer message from ${src}: ${other_names[0]}"
    PEER_SUMMARY=$summary
    coalesce_save "$src" "$total" "$now" 0 "$mname" "$msha"
    return 0
  fi

  [ "$machine" -gt 0 ] || [ "$other" -gt 0 ] || {
    # The peer still has receipts pending, but every one of them was already
    # accounted for by an earlier decision. There is nothing new to surface,
    # and the pending records stay in the queue for the primary to drain. This
    # must NOT fall through to the ordinary classifier: that classifier asks
    # whether the peer's crew is provably working, and a peer that publishes
    # on a timer is often not - which is exactly the republication noise the
    # coalescing window exists to absorb.
    PEER_ACTION=absorb
    PEER_DETAIL="source=${src} no new peer receipt since the last decision (${pending} still pending in the wake queue)"
    PEER_SUMMARY=''
    coalesce_save "$src" "$total" "$anchor" "$absorbed" "$stored_name" "$stored_sha"
    return 0
  }

  # Every new receipt is a machine artefact. Inside the coalescing window they
  # are absorbed: the peer is publishing on a timer, the artefact is on disk,
  # and the receipt is durable, so a model turn would do nothing but read it.
  if [ "$COALESCE_SECS" -gt 0 ] && [ "$anchor" -gt 0 ] \
     && [ $((now - anchor)) -lt "$COALESCE_SECS" ]; then
    local newabsorbed=$((absorbed + machine))
    local resets_at=$((anchor + COALESCE_SECS))
    PEER_ACTION=absorb
    PEER_DETAIL="source=${src} artefact=${last_machine_name} sha=${last_machine_sha} absorbed=${newabsorbed} window-resets-at=${resets_at}"
    PEER_SUMMARY="$(peer_coalesce_line "$src" "$newabsorbed" "$last_machine_name" "$last_machine_sha" "$resets_at")
"
    coalesce_save "$src" "$total" "$anchor" "$newabsorbed" "$last_machine_name" "$last_machine_sha"
    return 0
  fi

  # The window is closed: the first republication escalates and the rest of
  # the batch is folded into the same escalation's summary. Nothing is
  # dropped, and the window restarts here.
  reported=$((absorbed + machine - 1))
  summary="$(peer_coalesce_line "$src" "$reported" "$last_machine_name" "$last_machine_sha" "$resets")
"
  PEER_ACTION=escalate
  PEER_DETAIL="peer machine artefact republished: ${last_machine_name}"
  PEER_SUMMARY=$summary
  coalesce_save "$src" "$total" "$now" 0 "$last_machine_name" "$last_machine_sha"
  return 0
}

# peer_signal_decision <file-list> <state>
# Decide a signal wake that carries comms receipts from one or more peers.
# Sets PEER_ACTION, PEER_DETAIL and PEER_SUMMARY. PEER_ACTION stays empty
# when the wake carries no pending peer receipt, so the caller falls back to
# the ordinary classifier.
peer_signal_decision() {  # <file-list> <state>
  local list=$1 state=$2
  PEER_ACTION=
  PEER_DETAIL=
  PEER_SUMMARY=
  local f base id last
  local -a peer_files=() other_files=() peer_ids=()
  for f in $list; do
    [ -e "$f" ] || continue
    base=${f##*/}
    case "$base" in
      *.status) id=${base%.status} ;;
      *) id= ;;
    esac
    if [ -n "$id" ] && [ -f "$state/comms-receipts/$id/receipts.tsv" ]; then
      peer_files[${#peer_files[@]}]=$f
      peer_ids[${#peer_ids[@]}]=$id
    else
      other_files[${#other_files[@]}]=$f
    fi
  done
  [ "${#peer_files[@]}" -gt 0 ] || return 0

  local handled=0 escalate=0 detail='' extra='' k sep=''
  for k in "${!peer_ids[@]}"; do
    id=${peer_ids[$k]}
    f=${peer_files[$k]}
    # The peer's own status line can still carry a captain-relevant verb, and
    # the shared classifier's verdict stands: the peer path decides HOW a
    # receipt is surfaced, never WHETHER it is. A receipt whose summary
    # happens to read "merged" is escalated, not folded away.
    last=$(last_status_line "$f")
    if [ -n "$last" ] && status_is_captain_relevant "$last"; then
      escalate=1
      extra="${extra}supervise: peer: source=${id} status=captain-relevant
"
    fi
    peer_receipt_decision "$id"
    [ -n "$PEER_ACTION" ] || continue
    handled=1
    extra="${extra}${PEER_SUMMARY}
"
    [ "$PEER_ACTION" = "escalate" ] && escalate=1
    detail="${detail}${sep}${PEER_DETAIL}"
    sep='; '
  done
  [ "$handled" -eq 1 ] || return 0

  # The rest of the wake still decides: another task in the same signal may
  # carry a captain-relevant status of its own, and that outranks any
  # coalescing.
  if [ "${#other_files[@]}" -gt 0 ]; then
    local rest_decision rest_action
    rest_decision=$(classify_signal "${other_files[*]}" "$state")
    rest_action=${rest_decision%%|*}
    [ "$rest_action" = "escalate" ] && escalate=1
  fi

  if [ "$escalate" -eq 1 ]; then
    PEER_ACTION=escalate
    PEER_DETAIL="${detail:-a peer comms receipt that needs a handling turn now}"
    PEER_SUMMARY=$extra
    return 0
  fi
  PEER_ACTION=absorb
  PEER_DETAIL="${detail:-a republished peer machine artefact, coalesced}"
  PEER_SUMMARY=$extra
  return 0
}

# supervise_classify <reason> <state>
# Sets SUPERVISE_ACTION ("self", "absorb" or "escalate"), SUPERVISE_DISTILLED
# and SUPERVISE_EXTRA (the extra lines an escalation must print).
#
# It is deliberately NOT run in a command substitution: the peer path updates
# durable coalescing state and builds the escalation summary, and a subshell
# would throw both away.
SUPERVISE_ACTION=
SUPERVISE_DISTILLED=
SUPERVISE_EXTRA=

supervise_classify() {  # <reason> <state>
  local reason=$1 state=$2 arg detail decision
  SUPERVISE_ACTION=escalate
  SUPERVISE_DISTILLED=
  SUPERVISE_EXTRA=
  case "$reason" in
    signal:*)
      arg="${reason#signal: }"
      # A peer comms receipt is decided by the RECEIPT, not by the peer's crew
      # state: a message addressed to the Controller escalates immediately,
      # and a republished machine artefact is coalesced instead of costing a
      # model turn each.
      peer_signal_decision "$arg" "$state"
      if [ -n "$PEER_ACTION" ]; then
        SUPERVISE_ACTION=$PEER_ACTION
        SUPERVISE_DISTILLED=$PEER_DETAIL
        SUPERVISE_EXTRA=$PEER_SUMMARY
        return 0
      fi
      decision=$(classify_signal "$arg" "$state")
      SUPERVISE_ACTION=${decision%%|*}
      SUPERVISE_DISTILLED=${decision#*|}
      ;;
    stale:*)
      arg="${reason#stale: }"
      detail=""
      case "$arg" in
        *" ("*) detail="${arg#*" ("}"; arg="${arg%% \(*}" ;;
      esac
      decision=$(classify_stale "$arg" "$detail" "$state")
      SUPERVISE_ACTION=${decision%%|*}
      SUPERVISE_DISTILLED=${decision#*|}
      ;;
    gate:*)
      # A crew parked on an approval gate is a captain decision, always. It is
      # never absorbed and never answered here.
      SUPERVISE_DISTILLED="${reason}"
      ;;
    check:*)
      # Authenticated check output is always actionable (the watcher's own
      # contract), and the shared classifier has no predicate that could call a
      # check wake routine. Fail-safe: escalate.
      SUPERVISE_DISTILLED="${reason}"
      ;;
    heartbeat|heartbeat:*)
      # In normal mode the watcher surfaces a heartbeat only when its
      # fleet-scan found an UNSURFACED captain-relevant status, so the wake
      # itself is the captain-relevant finding. There is no shared predicate
      # that could call it routine. Fail-safe: escalate.
      SUPERVISE_DISTILLED="${reason}"
      ;;
    *)
      SUPERVISE_DISTILLED="unclassified wake: ${reason}"
      ;;
  esac
  return 0
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
  # The coalescing summary rides with the hand-back: how many republications
  # were folded in, from which source, the latest artefact and its digest,
  # and when the window resets. Nothing that was absorbed is silently lost.
  [ -n "$SUPERVISE_EXTRA" ] && printf '%s' "$SUPERVISE_EXTRA"
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
      # supervise_classify is called in THIS shell, not in a command
      # substitution: the peer path updates the durable coalescing state and
      # builds the escalation summary, and a subshell would throw both away.
      supervise_classify "$reason" "$STATE"
      action=$SUPERVISE_ACTION
      distilled=$SUPERVISE_DISTILLED
      if [ "$action" = "absorb" ]; then
        # A republished machine artefact from a peer, inside the coalescing
        # window. It is on disk, the receipt is durable, and the peer changes
        # it on its own timer, so no model turn is spent on it. The count is
        # carried forward and reported by the next escalation.
        routine=$((routine + 1))
        attempts=0
        log "coalesced: $distilled"
        trim_log
        printf 'supervise: republication absorbed (%s) - re-arming\n' "$distilled"
        rm -f "$capture" 2>/dev/null || true
        CURRENT_CAPTURE=
        if [ "$CYCLE_GAP_SECS" -gt 0 ]; then
          sleep "$CYCLE_GAP_SECS"
        fi
        continue
      fi
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
