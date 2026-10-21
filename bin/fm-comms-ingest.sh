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

usage() {
  sed -n '2,64p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

# Every failure after the lock is taken must still release it, or one failed
# write wedges every later scan. A single idempotent EXIT trap owns that so no
# individual error path has to remember.
FM_COMMS_LOCK_HELD=
fm_comms_lock_release_on_exit() {
  FM_COMMS_LOCK_HELD=$1
  trap 'fm_comms_release "$FM_COMMS_LOCK_HELD"' EXIT
}
fm_comms_release() {
  [ -n "${1-}" ] || return 0
  fm_lock_release "$1" 2>/dev/null || true
  FM_COMMS_LOCK_HELD=
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
  base=$(receipts_dir "$id") || exit 1
  status_file="$STATE/$id.status"
  receipts="$base/receipts.tsv"
  handled="$base/handled.tsv"
  mkdir -p "$base"
  lock="$base/.lock"

  fm_lock_acquire_wait "$lock" || die "cannot acquire the comms receipt lock for $id"
  fm_comms_lock_release_on_exit "$lock"

  # One pass per source folder, in the order given, against the SAME receipts
  # ledger. Dedup is therefore cross-source by construction: the same reply
  # delivered through two mirrors is still received exactly once.
  for dir in "$@"; do
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      [ -f "$file" ] || continue
      name=${file##*/}
      # A zero-byte drop is a file caught mid-write by the sync, not a message.
      # Ingesting it records an empty reply, wakes the parent on nothing, and
      # produces the empty-string digest that is indistinguishable from a real
      # report by name alone. Report it as incomplete and wait for a real resend.
      if [ ! -s "$file" ]; then
        printf 'incomplete: %s (zero bytes, not ingested)\n' "$name"
        continue
      fi
      # A transport sync pushes this home's outbound into the remote's
      # controller-replies folder and then mirrors that same folder back for
      # scanning. Without an exclusion boundary the ingest records our OWN
      # outbound as an inbound reply and raises a wake, so every message we
      # send produces a self-trigger that reads as a remote reply.
      # FM_COMMS_EXCLUDE_NAMES_FROM names this home's outbound directory; a
      # scanned file whose basename appears there was authored here, not
      # received, and is skipped visibly rather than silently.
      if [ -n "${FM_COMMS_EXCLUDE_NAMES_FROM:-}" ] \
        && [ -e "${FM_COMMS_EXCLUDE_NAMES_FROM%/}/$name" ]; then
        printf 'excluded-own-outbound: %s\n' "$name"
        continue
      fi
      # An entry whose name cannot be a reply name is unusable, not invisible.
      # Report it so a broken pickup cannot hide behind a clean exit status.
      if ! valid_name "$name"; then
        printf 'malformed: %s (unusable reply name)\n' "$name"
        continue
      fi
      bytes=$(wc -c <"$file" 2>/dev/null | tr -d ' ')
      case "$bytes" in ''|*[!0-9]*) bytes=0 ;; esac
      if [ "$bytes" -gt "$max_bytes" ]; then
        printf 'oversize: %s (%s bytes, limit %s)\n' "$name" "$bytes" "$max_bytes"
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

      # Content-keyed exclusion. A message we send can reach the far side under
      # a filename this home never authored (the sender writes msg-<time>.msg
      # remotely, and the transport mirrors it back), so a name-based boundary
      # cannot see it. The sender records the sha of what it sent; any scanned
      # file whose content digest appears there was sent BY us, not to us.
      if [ -n "${FM_COMMS_EXCLUDE_SHA_LEDGER:-}" ] \
        && [ -f "${FM_COMMS_EXCLUDE_SHA_LEDGER}" ] \
        && grep -q "^$sha" "${FM_COMMS_EXCLUDE_SHA_LEDGER}" 2>/dev/null; then
        printf 'excluded-own-outbound: %s\n' "$name"
        continue
      fi

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
      printf '%s\n' "$line" >>"$status_file" || die "cannot write $status_file"
      printf '%s\t%s\n' "$sha" "$name" >>"$receipts" || die "cannot write $receipts"

      ingested=$((ingested + 1))
      printf 'received: %s\n' "$name"
      # Received but unmatchable to a request. It is delivered, not dropped,
      # and saying so is what stops it waiting forever for a match.
      [ -n "$corr" ] || printf 'uncorrelated: %s\n' "$name"

      fm_wake_append signal "$id.status" \
        "comms received from $id: $name$corr_part" \
        || die "cannot publish the comms wake for $id"

      if [ "${FM_COMMS_NO_NOTIFY:-0}" != 1 ] && [ -x "$SCRIPT_DIR/fm-comms-notify.sh" ]; then
        NOTIFY_ARGS=(
          notify
          --route controller
          --file "$name"
          --sha "$sha"
        )
        [ -z "$summary" ] || NOTIFY_ARGS+=(--summary "$summary")
        [ -z "$corr" ] || NOTIFY_ARGS+=(--corr "$corr")
        FM_HOME="$FM_HOME" FM_ROOT_OVERRIDE="$FM_ROOT" \
          "$SCRIPT_DIR/fm-comms-notify.sh" "${NOTIFY_ARGS[@]}" >/dev/null 2>&1 || true
      fi
    done < <(find "$dir" -maxdepth 1 -type f 2>/dev/null | LC_ALL=C sort)
  done

  fm_comms_release "$lock"

  printf 'ingested: %d\n' "$ingested"
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

  fm_lock_acquire_wait "$lock" || die "cannot acquire the comms receipt lock for $id"

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