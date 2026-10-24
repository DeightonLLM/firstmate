#!/usr/bin/env bash
# fm-hetz-send.sh - send one controller message to the Hetz inbound queue and
# report whether it actually arrived.
#
# Usage:
#   fm-hetz-send.sh [--route <route-id>] <message text>
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
# ROUTE RESOLUTION. The remote target is a route, not a literal. When a route
# registry exists it is the only authority for which host and which inbox a
# route id resolves to; the built-in literals are a fallback for a home that
# keeps no registry at all, never a silent override of a registry that exists.
#
#   registry path   FM_HETZ_ROUTE_REGISTRY, default $FM_HOME/data/hetz-routes.tsv
#   registry line   <id> <host> [<inbox>], whitespace separated; '#' comments
#                   and blank lines are skipped
#   default id      FM_HETZ_ROUTE_ID, default "hetz-inbound"
#
# An id that is not registered, and a registry that cannot be read, are both
# refused BEFORE any transport is attempted (exit 3). Nothing is written and no
# success line is printed, because a route nobody can resolve must never look
# like a delivery.
#
# REMOTE INBOX. The remote inbox must already exist and be a directory. This
# helper never creates it: a destination this command invents is not a
# destination any consumer watches. A reachable route whose inbox is missing is
# named as missing and refused (exit 4) instead of collapsing into an opaque
# transport return code that an operator cannot tell apart from a refused key.
#
# The default inbox is the folder the Hetz lane actually reads:
# /home/hd2admin/controller-replies/. The old default, /tmp/hetzner-inbound, is
# not present on Hetz, so every send to it failed with "No such file or
# directory" (ssh rc=1) and was indistinguishable from a refused key.
#
# The inbox is probed BEFORE the message is written, and the probe reports an
# absent inbox through its own exit code (3) rather than through its output.
# That sentinel is this helper's contract with itself: the far side runs
# "test -d <inbox> || exit 3", so exit 3 means "the directory is not there"
# and every other non-zero code is a genuine transport failure, reported
# verbatim with its real ssh return code. An absent inbox is therefore named
# as absent, with the exact remediation, and never reported as a delivery.
#
# MESSAGE IDENTITY. The remote file name is unique per invocation, and the
# remote write refuses to overwrite an existing file. Two sends inside the same
# second used to collide on one name: both printed "sent" and exited 0 while the
# inbox held one file containing only the second message. The first message was
# destroyed without a word. A collision is now a loud failure, never a silent
# loss.
#
# Exit status:
#   0   the message is in the remote inbox
#   1   a local configuration or log failure
#   2   usage, including --help and an empty message
#   3   the route is unresolvable, or its registry cannot be read
#   4   the route resolved but the remote inbox is missing or not a directory
#   N   the real ssh return code of the transfer
#
# Environment:
#   FM_HETZ_LOG   outbound log path (default: this home's
#                 state/outbound-to-hetz.log)
#   FM_HETZ_HOST  remote ssh target (default: hd2admin@brandon-compute)
#   FM_HETZ_INBOUND  remote inbound directory (default: /home/hd2admin/controller-replies)
#   FM_HETZ_ROUTE_REGISTRY  route registry path
#   FM_HETZ_ROUTE_ID  route id used when --route is not given
#   FM_HETZ_MSG_NAME  pin the remote file name (testing seam; the default is a
#                     unique msg-<HHMMSS>-<pid>.msg)
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
INBOUND="${FM_HETZ_INBOUND:-/home/hd2admin/controller-replies}"
REGISTRY="${FM_HETZ_ROUTE_REGISTRY:-$FM_HOME/data/hetz-routes.tsv}"
ROUTE_ID="${FM_HETZ_ROUTE_ID:-hetz-inbound}"
ROUTE=""

EXIT_ROUTE=3
EXIT_INBOX=4
# The exit code the far-side probe uses to say "that directory is not there".
# It is the probe's own contract, not a transport code: ssh returns the remote
# command's status, and the probe only ever exits 0 or this value.
EXIT_INBOX_ABSENT=3

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
  exit 2
}

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help|help) usage ;;
    --route)
      [ $# -ge 2 ] || die "--route requires a route id"
      ROUTE="$2"
      shift 2
      ;;
    --route=*)
      ROUTE="${1#--route=}"
      shift
      ;;
    --) shift; break ;;
    *) break ;;
  esac
done

MESSAGE="$*"
[ -n "$MESSAGE" ] || usage

# Resolve the route against the registry when one exists. A registry that
# exists is the only authority: FM_HETZ_HOST and FM_HETZ_INBOUND are overridden
# by the registered values, because a registered route that silently sent to an
# unregistered place is the defect this replaces.
resolve_route() {
  local want
  want="${ROUTE:-$ROUTE_ID}"

  if [ ! -f "$REGISTRY" ]; then
    if [ -n "$ROUTE" ]; then
      printf 'error: route %s cannot be resolved: no route registry at %s\n' \
        "$want" "$REGISTRY" >&2
      exit "$EXIT_ROUTE"
    fi
    # No registry in this home: keep the historical literal route.
    return 0
  fi

  local id host inbox found=0
  while read -r id host inbox _rest; do
    case "${id:-}" in
      ''|'#'*) continue ;;
    esac
    [ "$id" = "$want" ] || continue
    if [ -z "${host:-}" ]; then
      printf 'error: route %s is registered without a host in %s\n' "$want" "$REGISTRY" >&2
      exit "$EXIT_ROUTE"
    fi
    HOST="$host"
    [ -n "${inbox:-}" ] && INBOUND="$inbox"
    found=1
    break
  done <"$REGISTRY"

  if [ "$found" -ne 1 ]; then
    printf 'error: unresolvable notify route: %s is not registered in %s\n' \
      "$want" "$REGISTRY" >&2
    exit "$EXIT_ROUTE"
  fi
}

resolve_route

mkdir -p "$(dirname "$LOG")" 2>/dev/null || die "cannot create the outbound log directory"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Intent is recorded before the send, so a crash mid-send still leaves the
# attempted message on record. This is a log of intent, never of delivery.
printf '[%s] FROM CONTROLLER: %s\n' "$TS" "$MESSAGE" >>"$LOG" \
  || die "cannot write the outbound log: $LOG"

TS2=$(date -u +%H%M%S)
# Unique per invocation. A second-resolution name alone collided: two sends in
# the same second produced one remote file and one silently destroyed message.
MSG_NAME="${FM_HETZ_MSG_NAME:-msg-${TS2}-$$.msg}"

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10)

# Pre-flight the destination. The probe reports an absent inbox through its own
# exit code (3), never through its output and never through an opaque transport
# code: the far side runs "test -d <inbox> || exit 3", so exit 3 means "that
# directory is not there" and every other non-zero code is a real transport
# failure, reported verbatim with its real ssh return code. The probe reads
# nothing from stdin, so it can never swallow the message body.
# shellcheck disable=SC2029 # Client-side expansion is intended: $INBOUND is
# substituted here and quoted into the remote command string.
ssh "${SSH_OPTS[@]}" "$HOST" \
  "test -d '$INBOUND' || exit $EXIT_INBOX_ABSENT" </dev/null >/dev/null 2>&1
inbox_rc=$?

case "$inbox_rc" in
  0)
    # The inbox exists. Carry on and write the message.
    ;;
  "$EXIT_INBOX_ABSENT")
    # The far side answered, and the answer is "that directory is not there".
    # Name it, give the exact remediation, and refuse: a destination this
    # helper invents is not a destination any consumer watches.
    printf 'error: remote inbox is missing or absent: %s on %s (no message written)\n' \
      "$INBOUND" "$HOST" >&2
    printf 'remediation: the remote inbox must already exist. Create it on the far side, or set FM_HETZ_INBOUND to a directory the peer actually reads (the Hetz lane reads /home/hd2admin/controller-replies). This helper never creates the destination it writes to.\n' >&2
    exit "$EXIT_INBOX"
    ;;
  *)
    # A genuine transport failure. The real ssh return code is the message.
    printf 'not sent: ssh rc=%s to %s (inbound %s)\n' "$inbox_rc" "$HOST" "$INBOUND" >&2
    exit "$inbox_rc"
    ;;
esac

# The remote write is a single-quoted heredoc-free stream so the message body
# never undergoes a second round of shell interpretation on the far side.
# "set -C" is noclobber: the write refuses to replace an existing message, so a
# name collision is a loud failure instead of a silent overwrite.
# shellcheck disable=SC2029 # Client-side expansion is intended: $INBOUND and
# $MSG_NAME are substituted here and quoted into the remote command string.
ssh "${SSH_OPTS[@]}" "$HOST" \
  "set -C; cat > '$INBOUND'/$MSG_NAME" <<<"$MESSAGE"
ssh_rc=$?

if [ "$ssh_rc" -ne 0 ]; then
  # The real return code is the message. Never print the success line here.
  printf 'not sent: ssh rc=%s to %s (inbound %s, message %s)\n' \
    "$ssh_rc" "$HOST" "$INBOUND" "$MSG_NAME" >&2
  exit "$ssh_rc"
fi

if [ "${FM_COMMS_NO_NOTIFY:-0}" != 1 ] && [ -x "$SCRIPT_DIR/fm-comms-notify.sh" ]; then
  FM_HOME="$FM_HOME" FM_ROOT_OVERRIDE="$FM_ROOT" \
    "$SCRIPT_DIR/fm-comms-notify.sh" notify \
      --route hetz \
      --file "$MSG_NAME" \
      --content "$MESSAGE" >/dev/null 2>&1 || true
fi

printf 'sent at %s (%s)\n' "$TS2" "$MSG_NAME"