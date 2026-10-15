#!/usr/bin/env bash
# fm-hetz-send.sh - send one controller message to the Hetz inbound queue and
# report whether it actually arrived.
#
# Usage:
#   fm-hetz-send.sh <message text>
#   fm-hetz-send.sh --help
#
# WHY THIS EXISTS. The live helper echoed "sent at <ts>" unconditionally, after
# the ssh call, whatever ssh returned. A refused connection, a wrong path or a
# quoting failure therefore all reported success. That false success is worse
# than a loud failure: the controller records an unanswered request as
# delivered and nobody ever chases it.
#
# The contract here is the opposite one. The message is written to the local
# outbound log first, then handed to ssh, and the REAL ssh return code decides
# both the printed line and this command's exit status:
#
#   ssh_rc=0  -> "sent at <ts>" and exit 0
#   ssh_rc=N  -> "not sent: ssh rc=N ..." on stderr and exit N
#
# so a caller can never mistake a failed transfer for a delivered one.
#
# Environment:
#   FM_HETZ_LOG   outbound log path (default: this home's
#                 state/outbound-to-hetz.log)
#   FM_HETZ_HOST  remote ssh target (default: hd2admin@brandon-compute)
#   FM_HETZ_INBOUND  remote inbound directory (default: /tmp/hetzner-inbound)
#
# The outbound log records controller INTENT ("FROM CONTROLLER: ..."), which is
# true the moment it is written. It is not evidence of delivery; only this
# command's exit status and its stdout are.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-${STATE:-$FM_HOME/state}}"

LOG="${FM_HETZ_LOG:-$STATE/outbound-to-hetz.log}"
HOST="${FM_HETZ_HOST:-hd2admin@brandon-compute}"
INBOUND="${FM_HETZ_INBOUND:-/tmp/hetzner-inbound}"

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

case "${1-}" in
  -h|--help|help) usage ;;
esac

MESSAGE="$*"
[ -n "$MESSAGE" ] || usage

mkdir -p "$(dirname "$LOG")" 2>/dev/null || die "cannot create the outbound log directory"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Intent is recorded before the send, so a crash mid-send still leaves the
# attempted message on record. This is a log of intent, never of delivery.
printf '[%s] FROM CONTROLLER: %s\n' "$TS" "$MESSAGE" >>"$LOG" \
  || die "cannot write the outbound log: $LOG"

TS2=$(date -u +%H%M%S)

# The remote write is a single-quoted heredoc-free stream so the message body
# never undergoes a second round of shell interpretation on the far side.
ssh -o BatchMode=yes -o ConnectTimeout=10 "$HOST" \
  "cat > '$INBOUND'/msg-${TS2}.msg" <<<"$MESSAGE"
ssh_rc=$?

if [ "$ssh_rc" -ne 0 ]; then
  # The real return code is the message. Never print the success line here.
  printf 'not sent: ssh rc=%s to %s (inbound %s)\n' "$ssh_rc" "$HOST" "$INBOUND" >&2
  exit "$ssh_rc"
fi

if [ "${FM_COMMS_NO_NOTIFY:-0}" != 1 ] && [ -x "$SCRIPT_DIR/fm-comms-notify.sh" ]; then
  FM_HOME="$FM_HOME" FM_ROOT_OVERRIDE="$FM_ROOT" \
    "$SCRIPT_DIR/fm-comms-notify.sh" notify \
      --route hetz \
      --file "msg-${TS2}.msg" \
      --content "$MESSAGE" >/dev/null 2>&1 || true
fi

printf 'sent at %s\n' "$TS2"