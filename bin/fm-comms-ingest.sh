#!/usr/bin/env bash
# fm-comms-ingest.sh - receive, receipt, and acknowledge a remote secondmate's
# file-drop replies on the parent home.
#
# Usage:
#   fm-comms-ingest.sh scan <secondmate-id> <report-dir>
#   fm-comms-ingest.sh handled <secondmate-id> <report-name>
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
# scan     Receive every not-yet-received regular file in <report-dir>. Each new
#          file appends one typed no-verb signal line to the parent
#          state/<secondmate-id>.status and publishes one `signal` wake keyed to
#          that status file, so the ordinary watcher surfaces it. Prints
#          "ingested: <n>" and one "received: <file>" line per file.
# handled  Record that a received reply has been fully handled. Prints
#          "handled: <name>" once and "already-handled: <name>" on every
#          repeat, so a paired external effect is never authorized twice.
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
  sed -n '2,45p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
  grep -aoE 'corr=[A-Za-z0-9._-]{8,}' -- "$1" 2>/dev/null | head -1
}

# One bounded, single-line, control-character-free summary of the reply.
# awk takes the path as an operand, not after a `--` separator: the awk in use
# reads `--` as a filename.
summary_of() {
  awk 'NF { gsub(/[[:cntrl:]]/, " "); print; exit }' "$1" 2>/dev/null \
    | cut -c1-200
}

cmd_scan() {
  local id=${1-} dir=${2-}
  [ -n "$id" ] && [ -n "$dir" ] || usage
  valid_id "$id" || die "refusing task id that could escape the status channel: $id"
  [ -d "$dir" ] || die "report directory does not exist: $dir"

  local status_file lock receipts ingested=0 file name sha corr short_sha
  local summary bytes corr_part line
  base=$(receipts_dir "$id") || exit 1
  status_file="$STATE/$id.status"
  receipts="$base/receipts.tsv"
  mkdir -p "$base"
  lock="$base/.lock"

  fm_lock_acquire_wait "$lock" || die "cannot acquire the comms receipt lock for $id"
  fm_comms_lock_release_on_exit "$lock"

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ -f "$file" ] || continue
    name=${file##*/}
    valid_name "$name" || continue
    sha=$(digest_of "$file")
    case "$sha" in
      [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) ;;
      *) continue ;;
    esac

    # Content-keyed dedup: an unchanged file is already received.
    if grep -qxF "$sha"$'\t'"$name" "$receipts" 2>/dev/null; then
      continue
    fi

    corr=$(corr_of "$file")
    summary=$(summary_of "$file")
    bytes=$(wc -c <"$file" 2>/dev/null | tr -d ' ')
    case "$bytes" in ''|*[!0-9]*) bytes=0 ;; esac
    corr_part=''
    [ -n "$corr" ] && corr_part=" $corr"

    # A typed no-verb signal line: no captain-relevant verb, so the watcher
    # treats it as a signal to surface rather than a verdict to absorb.
    short_sha=$(printf '%s' "$sha" | cut -c1-12)
    line="comms-received: $id $name sha=$short_sha bytes=$bytes$corr_part | $summary"
    printf '%s\n' "$line" >>"$status_file" || die "cannot write $status_file"
    printf '%s\t%s\n' "$sha" "$name" >>"$receipts" || die "cannot write $receipts"

    ingested=$((ingested + 1))
    printf 'received: %s\n' "$name"

    fm_wake_append signal "$id.status" \
      "comms received from $id: $name$corr_part" \
      || die "cannot publish the comms wake for $id"
  done < <(find "$dir" -maxdepth 1 -type f 2>/dev/null | LC_ALL=C sort)

  fm_comms_release "$lock"

  printf 'ingested: %d\n' "$ingested"
}

cmd_handled() {
  local id=${1-} name=${2-}
  [ -n "$id" ] && [ -n "$name" ] || usage
  valid_id "$id" || die "refusing task id that could escape the status channel: $id"
  valid_name "$name" || die "invalid reply name: $name"

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

  # The ledger row carries a trailing timestamp, so this is a field-prefix
  # match on "<sha>\t<name>\t", not a whole-line match.
  if grep -qF "$sha"$'\t'"$name"$'\t' "$handled" 2>/dev/null; then
    fm_comms_release "$lock"
    printf 'already-handled: %s\n' "$name"
    return 0
  fi

  printf '%s\t%s\t%s\n' "$sha" "$name" "$(date +%s)" >>"$handled" \
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