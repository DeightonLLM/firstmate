#!/usr/bin/env bash
# fm-comms-ingest.sh - receive, receipt, and acknowledge a remote secondmate's
# file-drop replies on the parent home.
#
# Usage:
#   fm-comms-ingest.sh scan <secondmate-id> <report-dir> [<report-dir>...]
#   fm-comms-ingest.sh handled <secondmate-id> <report-name> --review <review-file>
#   fm-comms-ingest.sh --help
#
# WHY THIS EXISTS. A secondmate normally answers by appending to the PARENT
# home's state/<id>.status with the request's corr=<token>
# (bin/fm-secondmate-report.sh, bin/fm-pending-reply-lib.sh). A secondmate on
# another host cannot do that reliably: its route back to the parent home is
# the thing that is broken. Those secondmates instead drop report files into a
# local workspace directory that a transport sync mirrors onto the parent host.
#
# That mirror had no consumer. A reply landed on disk, the sync log recorded
# "new/changed files: N", and no wake, receipt, or acknowledgment ever followed
# - the reply simply disappeared. This command is that missing consumer.
#
# scan     Receive every not-yet-received regular file in EACH <report-dir>, in
#          the order given. Each new file appends one typed no-verb signal line
#          to the parent state/<secondmate-id>.status and publishes one
#          `signal` wake keyed to that status file, so the ordinary watcher
#          surfaces it. Prints "ingested: <n>" and one "received: <file>" line
#          per file. One task id may name several source folders, because the
#          same reply can be delivered through more than one mirror; dedup is
#          keyed on CONTENT plus name across ALL of them, so a periodic re-sync
#          of every folder still yields exactly one wake per distinct reply.
#
#          Nothing is swallowed. A file that cannot be used is reported as
#          "malformed: <name>"; a received reply carrying no corr token is
#          reported as "uncorrelated: <name>"; a reply already acknowledged is
#          reported as "already-handled: <name>". A folder that is missing or
#          is not a directory is a hard error, never a silent "ingested: 0".
# handled  Record that a received reply has been fully handled, which REQUIRES
#          --review <review-file>: a real, readable, substantive controller
#          review of the reply. A bare acknowledgment is refused, because a
#          receipt is delivery and only a reviewed decision is a result.
#          Prints "handled: <name>" once and "already-handled: <name>" on
#          every repeat, so a paired external effect is never authorized twice.
#          Acknowledging a reply that was never received FAILS: this command
#          never manufactures a receipt.
#
# SCOPE OF EACH FACT. A file on disk is transport delivery. The status line and
# signal wake are the receive and its receipt. `handled` is the parent's final
# acknowledgment and is a SEPARATE, later fact - receipt is never inferred from
# it, and it is never inferred from it backwards. A reply that arrives but is
# never acknowledged stays eligible on the next scan, exactly like an unhandled
# process-event result.
#
# DEDUP is keyed on CONTENT, not filename: a re-run over unchanged files is a
# no-op, while a file whose bytes changed is a genuinely new reply. This is what
# lets a periodic sync re-run safely.
#
# FAIL CLOSED. A missing or non-directory report path is an error, never an
# "ingested: 0" pass - an unmounted or unreachable mirror must not read as "no
# replies, all healthy". Only regular files directly inside the directory are
# received, so a partially synced tree cannot inject a fabricated reply. A task
# id that could escape state/ is refused before anything is written.
#
# THE LOCK IS BOUNDED. The receipt lock is taken with a deadline, so a scan that
# cannot take it says so and exits instead of spinning forever. It may also
# break a STUCK holder - a live process that has held the lock longer than
# FM_LOCK_MAX_HOLD_S - because a wedged scan must not hold the lock for the
# fleet's lifetime. This mattered in practice: on 2026-10-21 the Controller's
# receipt lock was held forever by a scan that could never finish, every later
# scan spun on it at 10 Hz, and each spin leaked a lock owner dir and spawned a
# dozen git subprocesses. That was a 14.32 load average on four cores, not real
# work, and it made bin/fm-dispatch-guard.sh refuse every spawn.
#
# THE LOG IS BOUNDED. This command's output is appended to the host wrapper's
# log (state/fm-comms-ingest.log). It reached 40 MB because an oversize file
# was re-reported on every scan and nothing ever rotated it. An oversize file
# is now reported ONCE, and the log is rotated to a single generation when it
# passes its cap.
#
# This command is transport-agnostic and one-shot. It does not poll, does not
# hold a watcher, and does not speak to the remote host; it only reads a mirror
# some other mechanism maintains and writes this home's own durable records.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-${STATE:-$FM_HOME/state}}"

# shellcheck source=bin/fm-wake-lib.sh
. "$SCRIPT_DIR/fm-wake-lib.sh"

# The single owner of bounded command execution. The notification dispatch
# below is run through it so a recipient pane that never answers cannot hold
# this scan - and the receipts lock - open indefinitely.
if [ -f "$SCRIPT_DIR/fm-timeout-lib.sh" ]; then
  # shellcheck source=bin/fm-timeout-lib.sh
  . "$SCRIPT_DIR/fm-timeout-lib.sh"
fi

# How long one notification dispatch may take. The reply is already receipted
# and durable on disk by then, so an abandoned notification costs a prompt,
# never a delivery.
FM_COMMS_NOTIFY_DISPATCH_TIMEOUT_S="${FM_COMMS_NOTIFY_DISPATCH_TIMEOUT_S:-30}"
case "$FM_COMMS_NOTIFY_DISPATCH_TIMEOUT_S" in
  '' | *[!0-9]*) FM_COMMS_NOTIFY_DISPATCH_TIMEOUT_S=30 ;;
esac

usage() {
  sed -n '2,64p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

# Every failure after the lock is taken must still release it, or one failed
# write wedges every later scan. A single idempotent EXIT trap owns that so no
# individual error path has to remember. The same trap rotates the ingest log,
# so the log cannot grow without bound even when a scan dies mid-flight.
FM_COMMS_LOCK_HELD=
fm_comms_release() {
  [ -n "${1-}" ] || return 0
  fm_lock_release "$1" 2>/dev/null || true
  FM_COMMS_LOCK_HELD=
}

# fm_comms_rotate_log
# Keep the ingest log bounded. The log is appended by the host wrapper
# (">> $FM/state/fm-comms-ingest.log"), so this command cannot stop the
# wrapper from appending - but it can stop the file from growing without
# bound, which is what turned it into 40 MB.
#
# The rotation uses `mv`, not `rm`: on this host `rm` is a recoverable-delete
# shim that MOVES its target into ~/.local/share/Trash, which frees zero bytes
# on the same filesystem. `mv -f` renames the file and unlinks the previous
# generation for real, so the total on disk stays bounded at two generations.
fm_comms_rotate_log() {
  local log="$STATE/fm-comms-ingest.log" size max
  max=${FM_COMMS_INGEST_LOG_MAX_BYTES:-5242880}
  case "$max" in ''|*[!0-9]*) max=5242880 ;; esac
  [ -f "$log" ] || return 0
  size=$(wc -c <"$log" 2>/dev/null | tr -d ' ')
  case "$size" in ''|*[!0-9]*) return 0 ;; esac
  [ "$size" -gt "$max" ] || return 0
  mv -f "$log" "$log.1" 2>/dev/null || true
}

fm_comms_on_exit() {
  fm_comms_release "$FM_COMMS_LOCK_HELD"
  fm_comms_rotate_log
}
trap fm_comms_on_exit EXIT

fm_comms_lock_release_on_exit() {
  FM_COMMS_LOCK_HELD=$1
}

# fm_comms_take_lock <lock> <id>
# Take the receipt lock with a deadline. The wait may break a STUCK holder -
# a live process that has held the lock longer than FM_LOCK_MAX_HOLD_S - so a
# wedged scan cannot hold the lock for the fleet's lifetime. A holder that is
# merely BUSY is never displaced: the wait reports the reason and gives up.
# fm_comms_dispatch_notifications <names-array> <shas-array> <summaries-array> <corrs-array>
# Send the queued notifications now that the receipts lock is released. Each
# dispatch is bounded, so a recipient pane that never answers costs one
# notification and nothing else.
fm_comms_dispatch_notifications() {
  local -n names_ref=$1 shas_ref=$2 summaries_ref=$3 corrs_ref=$4
  local index
  [ "${#names_ref[@]}" -gt 0 ] || return 0
  if ! command -v fm_run_timed >/dev/null 2>&1; then
    printf 'notify-unavailable: the bounded-execution helper is missing; %s notification(s) were not sent\n' \
      "${#names_ref[@]}" >&2
    return 0
  fi
  for index in "${!names_ref[@]}"; do
    local -a notify_args=(
      notify
      --route controller
      --file "${names_ref[$index]}"
      --sha "${shas_ref[$index]}"
    )
    [ -z "${summaries_ref[$index]}" ] || notify_args+=(--summary "${summaries_ref[$index]}")
    [ -z "${corrs_ref[$index]}" ] || notify_args+=(--corr "${corrs_ref[$index]}")
    FM_HOME="$FM_HOME" FM_ROOT_OVERRIDE="$FM_ROOT" \
      fm_run_timed "$FM_COMMS_NOTIFY_DISPATCH_TIMEOUT_S" \
      "$SCRIPT_DIR/fm-comms-notify.sh" "${notify_args[@]}" >/dev/null 2>&1 || true
  done
  return 0
}

fm_comms_take_lock() {
  local lock=$1 id=$2
  # R5: a scan that already holds this lock must not re-enter the scan it
  # holds the lock for. Re-entering is what made the lock un-releasable, and
  # every other caller then waited on it forever.
  if fm_lock_held_by_ancestor "$lock"; then
    die "refusing to re-enter the scan: an ancestor already holds the comms receipt lock for $id"
  fi
  FM_LOCK_BREAK_STUCK_HOLDERS=1
  if fm_lock_acquire_wait "$lock"; then
    fm_comms_lock_release_on_exit "$lock"
    return 0
  fi
  die "cannot acquire the comms receipt lock for $id (${FM_LOCK_WAIT_REASON:-contended}; holder pid ${FM_LOCK_HELD_PID:-unknown})"
}

receipts_dir() { printf '%s/comms-receipts/%s\n' "$STATE" "$1"; }

# The task id is used as a state/<id>.status path component, so it is validated
# against the same shape the wake library accepts for a signal key.
valid_id() {
  case "$1" in
    ''|.*|*[!A-Za-z0-9._-]*) return 1 ;;
  esac
  [ "${#1}" -le 64 ]
}

valid_name() {
  case "$1" in
    ''|.|..) return 1 ;;
    */*|*[!A-Za-z0-9._-]*) return 1 ;;
  esac
  [ "${#1}" -le 255 ]
}

digest_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$1" 2>/dev/null | awk '{print $1}'
  else
    shasum -a 256 -- "$1" 2>/dev/null | awk '{print $1}'
  fi
}

# The reply's correlation token, when it answers a specific request. Optional:
# an uncorrelated reply is still received, it just cannot auto-match an
# expectation.
corr_of() {
  grep -aoE 'corr=[A-Fa-f0-9]{16}' -- "$1" 2>/dev/null | head -1
}

# One bounded, single-line, control-character-free summary of the reply.
# awk takes the path as an operand, not after a `--` separator: the awk in use
# reads `--` as a filename.
summary_of() {
  awk 'NF { gsub(/[[:cntrl:]]/, " "); print; exit }' "$1" 2>/dev/null \
    | cut -c1-200
}

# fm_comms_oversize_first_seen <name> <bytes> <ledger>
# 0 when this oversize file has not been reported before, 1 when it has.
#
# An oversize file is reported ONCE, not on every scan. The Controller's
# mirror carried a 71 MB bundle that was re-reported on every five-minute
# scan for as long as the mirror held it, which is a slow leak in the ingest
# log rather than a fact anyone needs repeated.
#
# The ledger is keyed on name AND size, so a file whose size later changes is
# reported again - that is new information - while an unchanged one stays
# quiet. The ledger is capped so it cannot become the next unbounded file.
fm_comms_oversize_first_seen() {
  local name=$1 bytes=$2 ledger=$3 line max=262144 size
  line="$name"$'\t'"$bytes"
  if [ -f "$ledger" ] && grep -qxF "$line" "$ledger" 2>/dev/null; then
    return 1
  fi
  printf '%s\n' "$line" >>"$ledger" 2>/dev/null || true
  size=$(wc -c <"$ledger" 2>/dev/null | tr -d ' ')
  case "$size" in ''|*[!0-9]*) size=0 ;; esac
  if [ "$size" -gt "$max" ]; then
    tail -100 "$ledger" >"$ledger.tmp" 2>/dev/null \
      && mv -f "$ledger.tmp" "$ledger" 2>/dev/null \
      || rm -f "$ledger.tmp" 2>/dev/null || true
  fi
  return 0
}

cmd_scan() {
  local id=${1-}
  [ -n "$id" ] || usage
  shift
  [ "$#" -ge 1 ] || usage
  valid_id "$id" || die "refusing task id that could escape the status channel: $id"

  local dir
  for dir in "$@"; do
    [ -d "$dir" ] || die "report directory does not exist: $dir"
  done

  local status_file lock receipts handled ingested=0 file name sha corr short_sha
  local summary bytes corr_part line
  local max_bytes=1048576
  local oversize_ledger wake_failures=0
  local -a notify_names=() notify_shas=() notify_summaries=() notify_corrs=()
  base=$(receipts_dir "$id") || exit 1
  status_file="$STATE/$id.status"
  receipts="$base/receipts.tsv"
  handled="$base/handled.tsv"
  oversize_ledger="$base/oversize.tsv"
  mkdir -p "$base"
  lock="$base/.lock"

  fm_comms_take_lock "$lock" "$id"

  # One pass per source folder, in the order given, against the SAME receipts
  # ledger. Dedup is therefore cross-source by construction: the same reply
  # delivered through two mirrors is still received exactly once.
  for dir in "$@"; do
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      [ -f "$file" ] || continue
      name=${file##*/}
      # An entry whose name cannot be a reply name is unusable, not invisible.
      # Report it so a broken pickup cannot hide behind a clean exit status.
      if ! valid_name "$name"; then
        printf 'malformed: %s (unusable reply name)\n' "$name"
        continue
      fi
      bytes=$(wc -c <"$file" 2>/dev/null | tr -d ' ')
      case "$bytes" in ''|*[!0-9]*) bytes=0 ;; esac
      if [ "$bytes" -gt "$max_bytes" ]; then
        # Reported once, not on every scan. See fm_comms_oversize_first_seen.
        if fm_comms_oversize_first_seen "$name" "$bytes" "$oversize_ledger"; then
          printf 'oversize: %s (%s bytes, limit %s)\n' "$name" "$bytes" "$max_bytes"
        fi
        continue
      fi
      sha=$(digest_of "$file")
      case "$sha" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) ;;
        *)
          printf 'malformed: %s (unreadable content)\n' "$name"
          continue
          ;;
      esac

      # Content-keyed dedup: an unchanged file is already received. Say which
      # of the two terminal states it is in, so a re-sync of an acknowledged
      # reply is visibly acknowledged rather than silently dropped.
      if grep -qxF "$sha"$'\t'"$name" "$receipts" 2>/dev/null; then
        if grep -qF "$sha"$'\t'"$name"$'\t' "$handled" 2>/dev/null; then
          printf 'already-handled: %s\n' "$name"
        else
          printf 'already-received: %s\n' "$name"
        fi
        continue
      fi

      corr=$(corr_of "$file")
      summary=$(summary_of "$file")
      corr_part=''
      [ -n "$corr" ] && corr_part=" $corr"

      # A typed no-verb signal line: no captain-relevant verb, so the watcher
      # treats it as a signal to surface rather than a verdict to absorb.
      short_sha=$(printf '%s' "$sha" | cut -c1-12)
      line="comms-received: $id $name sha=$short_sha bytes=$bytes$corr_part | untrusted-reply-text: $summary"
      # The wake is published BEFORE the receipt is recorded.
      #
      # A receipt says "this reply was received". Recording it while the wake
      # failed would mark a reply as delivered that nothing ever surfaced -
      # and the content-keyed dedup would then skip that reply forever, so the
      # reply would be lost silently. Publishing the wake first means a failed
      # wake leaves the reply un-receipted, and the next scan retries it.
      printf '%s\n' "$line" >>"$status_file" || die "cannot write $status_file"

      if ! fm_wake_append signal "$id.status" \
        "comms received from $id: $name$corr_part"; then
        printf 'wake-failed: %s (reply received but not queued; the next scan retries it)\n' "$name"
        wake_failures=$((wake_failures + 1))
        continue
      fi

      printf '%s\t%s\n' "$sha" "$name" >>"$receipts" || die "cannot write $receipts"

      ingested=$((ingested + 1))
      printf 'received: %s\n' "$name"
      # Received but unmatchable to a request. It is delivered, not dropped,
      # and saying so is what stops it waiting forever for a match.
      [ -n "$corr" ] || printf 'uncorrelated: %s\n' "$name"

      # The notification is QUEUED here, not sent here.
      #
      # Sending it here meant this scan called the notifier while HOLDING the
      # receipts lock. The notifier's prompt blocks until the recipient pane
      # accepts the submission, and a pane whose real state is unknown never
      # accepts it - so one unresponsive pane held the receipts lock forever
      # and every later scan piled up behind it. The notification is a
      # courtesy prompt to a live agent; the receipt ledger is the durable
      # fact. They must not share a critical section.
      if [ "${FM_COMMS_NO_NOTIFY:-0}" != 1 ] && [ -x "$SCRIPT_DIR/fm-comms-notify.sh" ]; then
        notify_names+=("$name")
        notify_shas+=("$sha")
        notify_summaries+=("$summary")
        notify_corrs+=("$corr")
      fi
    done < <(find "$dir" -maxdepth 1 -type f 2>/dev/null | LC_ALL=C sort)
  done

  fm_comms_release "$lock"

  # Notifications are dispatched AFTER the receipts lock is released, and each
  # one is bounded. A notification problem can therefore never stall receipt
  # recording again.
  fm_comms_dispatch_notifications notify_names notify_shas notify_summaries notify_corrs

  printf 'ingested: %d\n' "$ingested"
  if [ "$wake_failures" -gt 0 ]; then
    # The replies were received but not queued. They stay eligible for the
    # next scan, so this is a retryable condition, not a silent success.
    printf 'wake-failures: %d\n' "$wake_failures" >&2
    return 1
  fi
}

cmd_handled() {
  local id=${1-} name=${2-} review='' review_words='' review_sha=''
  [ -n "$id" ] && [ -n "$name" ] || usage
  valid_id "$id" || die "refusing task id that could escape the status channel: $id"
  valid_name "$name" || die "invalid reply name: $name"

  # Receipt first. Whether the reply was ever received is the more fundamental
  # refusal: reporting "review evidence required" for a reply that was never
  # received would send the caller looking for the wrong problem.
  local base receipts handled lock sha
  base=$(receipts_dir "$id") || exit 1
  receipts="$base/receipts.tsv"
  handled="$base/handled.tsv"
  [ -d "$base" ] || die "not-received: $name (no receipt for $id)"
  lock="$base/.lock"

  fm_comms_take_lock "$lock" "$id"

  sha=$(grep -F "$name" "$receipts" 2>/dev/null | tail -1 | cut -f1)
  if [ -z "$sha" ]; then
    fm_comms_release "$lock"
    die "not-received: $name (never received for $id; refusing to manufacture a receipt)"
  fi

  # --review is mandatory: acknowledgment is a reviewed decision, and a
  # receipt is only delivery.
  if [ "${3-}" = "--review" ]; then
    review=${4-}
    [ -n "$review" ] || die "missing review evidence: --review needs a review file"
  else
    die "review evidence required: handled <id> <name> --review <review-file>"
  fi
  [ -f "$review" ] && [ -r "$review" ] \
    || die "review evidence is not a readable file: $review"
  # Substantive, not a placeholder. A review must actually state a decision, so
  # the floor is on words rather than bytes: "ok", "done" or "reviewed" are one
  # word and are refused, while a single honest sentence passes regardless of
  # how long its words are.
  review_words=$(awk '{print NF}' "$review" 2>/dev/null | tail -1)
  case "$review_words" in ''|*[!0-9]*) review_words=0 ;; esac
  [ "$review_words" -ge 5 ] \
    || die "review evidence is not substantive ($review_words words, need 5): $review"

  # The ledger row carries a trailing timestamp, so this is a field-prefix
  # match on "<sha>\t<name>\t", not a whole-line match.
  if grep -qF "$sha"$'\t'"$name"$'\t' "$handled" 2>/dev/null; then
    fm_comms_release "$lock"
    printf 'already-handled: %s\n' "$name"
    return 0
  fi

  review_sha=$(digest_of "$review")
  case "$review_sha" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) ;;
    *) review_sha=unknown ;;
  esac

  printf '%s\t%s\t%s\treview=%s\n' "$sha" "$name" "$(date +%s)" "$review_sha" >>"$handled" \
    || die "cannot write the handled ledger"
  fm_comms_release "$lock"
  printf 'handled: %s\n' "$name"
}

case "${1-}" in
  scan)    shift; cmd_scan "$@" ;;
  handled) shift; cmd_handled "$@" ;;
  -h|--help|help) usage ;;
  *) usage ;;
esac