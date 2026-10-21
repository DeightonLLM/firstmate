#!/usr/bin/env bash
# fm-next-board-feedback.sh - turn a saved board message into a durable wake.
#
# The board's own form (POST /next-board/feedback, handled by
# bin/fm-tracker-view-serve.py) saves the Captain's message as a file under
# state/next-board-feedback/. Saving the file is not enough: the agent has to
# be woken by it, or the message sits there unread.
#
# This script appends that wake. The wake goes through fm_wake_append from
# bin/fm-wake-lib.sh, so the queue file format, its lock, and its sequence
# counter stay owned by that library: this script never writes a queue line by
# hand, never invents one, and never touches the queue file directly.
#
# The wake key carries the message's own identity - its file name and a digest
# of its content - so two different messages can never collapse into one wake,
# and the same message can never produce two different wakes.
#
# The contract is docs/next-board-token-and-chat-contract.md, Contract B.
#
# Usage:
#   fm-next-board-feedback.sh <feedback-file>
#   fm-next-board-feedback.sh --file <feedback-file> [--ticket <id>]
#   fm-next-board-feedback.sh --help
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

resolve_root() {
  if [ -n "${FM_ROOT_OVERRIDE:-}" ]; then
    printf '%s\n' "$FM_ROOT_OVERRIDE"
    return 0
  fi
  case "${SELF_DIR##*/}" in
    next-board-publish) (cd "$SELF_DIR/../.." && pwd -P) ;;
    *) (cd "$SELF_DIR/.." && pwd -P) ;;
  esac
}

FM_ROOT="$(resolve_root)"
FM_HOME="${FM_HOME:-$FM_ROOT}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
export FM_HOME
export FM_STATE_OVERRIDE="$STATE"
export FM_ROOT_OVERRIDE="$FM_ROOT"

WAKE_LIB="$FM_ROOT/bin/fm-wake-lib.sh"
if [ ! -f "$WAKE_LIB" ] || [ -L "$WAKE_LIB" ]; then
  printf 'error: missing required library: %s\n' "$WAKE_LIB" >&2
  exit 1
fi
# shellcheck source=bin/fm-wake-lib.sh
. "$WAKE_LIB"

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
fm-next-board-feedback.sh - wake the agent for a saved board message

Usage:
  fm-next-board-feedback.sh <feedback-file>   wake for that saved message
  fm-next-board-feedback.sh --file <file>     the same, with an explicit flag
  fm-next-board-feedback.sh --ticket <id>     override the ticket label
  fm-next-board-feedback.sh --help             show this help

The message file is the one the board's form saved under
  <state>/next-board-feedback/
It must exist, be a readable regular file, and not be empty.

The wake is appended through fm_wake_append from bin/fm-wake-lib.sh as a
`signal` record, which is the same durable wake queue every other Firstmate
event uses. The queue file, its lock, and its sequence counter belong to that
library; this script never writes a queue line by hand.
USAGE
}

now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# A short, stable digest of the message. It is what makes the wake key unique
# per message: the same file with the same content is one message, and a
# different file or different content is a different message.
content_digest() {  # <file>
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$1" 2>/dev/null | awk '{print substr($1, 1, 12)}'
  else
    shasum -a 256 -- "$1" 2>/dev/null | awk '{print substr($1, 1, 12)}'
  fi
}

# The ticket label, taken from the message's own metadata line unless the
# caller overrides it.
ticket_from_file() {  # <file>
  awk '/^- Ticket:[[:space:]]*/ { sub(/^- Ticket:[[:space:]]*/, ""); print; exit }' "$1"
}

# The first line of the Captain's comment, so the wake carries the message
# itself and not only a path.
comment_summary() {  # <file>
  local line
  line="$(awk '
    /^## Comment[[:space:]]*$/ { seen = 1; next }
    seen && /^[[:space:]]*$/ { next }
    seen && /^>[[:space:]]?/ { sub(/^>[[:space:]]?/, ""); if (length($0)) { print; exit } }
    seen && !/^>/ { exit }
  ' "$1")"
  if [ -z "$line" ]; then
    line="$(awk '
      length($0) && $0 !~ /^#/ && $0 !~ /^- / { sub(/^>[[:space:]]?/, ""); print; exit }
    ' "$1")"
  fi
  printf '%s' "$line"
}

# One line, bounded, and safe to store in a tab-separated queue record.
flatten() {  # <text> <max-chars>
  local text="$1" max="$2"
  text="$(printf '%s' "$text" | tr '\t\r\n' '   ' | sed -e 's/[[:space:]]\{1,\}/ /g' -e 's/^ //' -e 's/ $//')"
  if [ "${#text}" -gt "$max" ]; then
    text="${text:0:$((max - 3))}..."
  fi
  printf '%s' "$text"
}

slugify() {  # <text>
  printf '%s' "$1" | LC_ALL=C tr -c 'A-Za-z0-9._-' '-' | sed -e 's/-\{2,\}/-/g' -e 's/^-//' -e 's/-$//'
}

file=""
ticket_override=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --file)
      [ "$#" -ge 2 ] || die "--file needs a path"
      file="$2"
      shift 2
      ;;
    --ticket)
      [ "$#" -ge 2 ] || die "--ticket needs a ticket id"
      ticket_override="$2"
      shift 2
      ;;
    --help|-h|help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      [ -z "$file" ] || die "only one feedback file may be given"
      file="$1"
      shift
      ;;
  esac
done

if [ "$#" -gt 0 ]; then
  [ -z "$file" ] || die "only one feedback file may be given"
  file="$1"
  shift
  [ "$#" -eq 0 ] || die "only one feedback file may be given"
fi

[ -n "$file" ] || {
  usage >&2
  exit 2
}

if [ ! -e "$file" ]; then
  die "no board feedback file at $file"
fi
if [ ! -f "$file" ] || [ -L "$file" ]; then
  die "the board feedback must be a readable regular file, not a link or a directory: $file"
fi
if [ ! -r "$file" ]; then
  die "the board feedback file is not readable: $file"
fi
if [ ! -s "$file" ]; then
  die "the board feedback file is empty: $file"
fi

digest="$(content_digest "$file")"
[ -n "$digest" ] || die "cannot read the board feedback file: $file"

real="$(perl -MCwd=realpath -e '$p = realpath($ARGV[0]); defined($p) or exit 1; print "$p\n"' "$file" 2>/dev/null)"
[ -n "$real" ] || real="$file"

base="${file##*/}"
base="${base%.md}"
slug="$(slugify "$base")"
[ -n "$slug" ] || slug="message"

ticket="$ticket_override"
if [ -z "$ticket" ]; then
  ticket="$(ticket_from_file "$file")"
fi
[ -n "$ticket" ] || ticket="none"

summary="$(flatten "$(comment_summary "$file")" 200)"

key="next-board-feedback.${slug}.${digest}"
payload="next-board feedback: ${real} | ticket: ${ticket}"
if [ -n "$summary" ]; then
  payload="${payload} | ${summary}"
fi

fm_wake_append signal "$key" "$payload" \
  || die "cannot append the board feedback wake"

printf 'woke: %s\n' "$key"
printf 'feedback: %s\n' "$real"
printf 'ticket: %s\n' "$ticket"
if [ -n "$summary" ]; then
  printf 'summary: %s\n' "$summary"
fi
printf 'at: %s\n' "$(now_iso)"
