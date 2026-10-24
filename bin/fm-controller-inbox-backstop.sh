#!/usr/bin/env bash
# fm-controller-inbox-backstop.sh - the tracked owner of the controller-inbox backstop.
#
# Why it exists: the arrival poll (state/controller-inbox.check.sh) fires on a NEW
# file arrival only. If a wake is missed, or an acknowledgement is refused or lost,
# a real message can sit unread with no second signal ever surfacing it. This
# check closes that gap independently of the arrival event: it reconciles every
# inbound message against the durable acknowledgement ledgers and wakes the owning
# Firstmate for anything that has been sitting there long enough that it should
# already have been read.
#
# THE RULE: an acknowledgement is keyed by MESSAGE NAME, with the hash kept as
# the evidence of the bytes that were acknowledged.
#   * A name that was never acknowledged is UNHANDLED. When it has been sitting
#     longer than the stale threshold it is the actionable finding and it blocks.
#   * A name that WAS acknowledged stays HANDLED even when the bytes change. The
#     Controller republishes one logical board file with new bytes every minute;
#     a hash-keyed acknowledgement made that single logical message look like a
#     brand new unhandled message forever, so the watcher woke on every cycle and
#     supervision could never hold.
#   * A republication is REPORTED with both the old and the new hash, so the
#     change stays visible, but it never blocks: only an actionable finding does.
#
# Output contract (the watcher depends on this):
#   * stdout carries the ACTIONABLE finding ONLY. The watcher treats any stdout
#     from a check as actionable, so a republication notice on stdout would
#     re-arm the watcher on every cycle - the very defect this script exists to
#     remove. The republication notice goes to the durable republication log
#     instead, where it stays visible without waking anybody.
#   * --report prints the classification of every message on stdout for a human
#     reader. It is NOT the watcher check mode and must not be registered as one.
#
# Durable records, all in the home's state directory:
#   .controller-inbox-handled         the hash ledger: one sha256 per line. The
#                                     arrival poll reads it, and an acknowledgement
#                                     of these exact bytes is honoured here too.
#   .controller-inbox-handled-names   the name ledger: one message name per line.
#                                     This is the key of the acknowledgement.
#   .controller-inbox-acknowledged    the acknowledgement record: name, hash and
#                                     the UTC time the acknowledgement was made,
#                                     one tab-separated record per line.
#   .controller-inbox-republished.log the republication log: one line per
#                                     republished content, in the form
#                                     "<UTC> name=<name> sha256=<hash> - republished
#                                     after acknowledgement; visible, not blocking".
#
# No network calls. No writes to any message file. Every error in the scan mode
# exits 0, so a broken poll can never wedge the watcher.
#
# Environment:
#   FM_HOME                       the home whose state and inbound routes are used
#   FM_STATE_OVERRIDE             overrides the state directory
#   FM_INBOX_BACKSTOP_SECONDS     the stale threshold in seconds (default 900)
#   FM_INBOX_BACKSTOP_DIRS        colon-separated inbound routes the BACKSTOP
#                                 watches (default: the exchange directory and the
#                                 home's controller-replies mirror)
#   FM_INBOX_DIRS                 colon-separated inbound routes an --ack may
#                                 resolve a message name in (default: every
#                                 documented Controller route)
#   FM_INBOX_HANDLED_LEDGER       the hash ledger path
#   FM_INBOX_HANDLED_NAMES_LEDGER the name ledger path
#   FM_INBOX_ACKNOWLEDGED_LEDGER  the acknowledgement record path
#   FM_INBOX_REPUBLISHED_LOG      the republication log path
#   FM_INBOX_REPUBLISHED_MAX_LINES how many republication records are kept
#
# Usage:
#   fm-controller-inbox-backstop.sh                     # watcher check mode
#   fm-controller-inbox-backstop.sh --report            # classify every message
#   fm-controller-inbox-backstop.sh --ack <name> <sha256>
#
# Exit codes:
#   0 - the scan completed, or an acknowledgement was recorded
#   1 - an acknowledgement was refused
#   2 - usage error
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-$FM_ROOT}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"

# How long a message may sit before we assume it was meant to be acted on.
# Comfortably longer than a poll cycle, so ordinary latency never causes noise.
STALE_SECONDS="${FM_INBOX_BACKSTOP_SECONDS:-900}"

HANDLED="${FM_INBOX_HANDLED_LEDGER:-$STATE/.controller-inbox-handled}"
HANDLED_NAMES="${FM_INBOX_HANDLED_NAMES_LEDGER:-$STATE/.controller-inbox-handled-names}"
ACKNOWLEDGED="${FM_INBOX_ACKNOWLEDGED_LEDGER:-$STATE/.controller-inbox-acknowledged}"
REPUBLISHED_LOG="${FM_INBOX_REPUBLISHED_LOG:-$STATE/.controller-inbox-republished.log}"
REPUBLISHED_MAX_LINES="${FM_INBOX_REPUBLISHED_MAX_LINES:-500}"

# The routes the backstop watches for age: the shared exchange directory and the
# home's controller-replies mirror.
BACKSTOP_DIRS="${FM_INBOX_BACKSTOP_DIRS:-$FM_HOME/BRANDON-COMPUTE-COMMS/to-brandon-compute:$FM_HOME/controller-replies}"

# The routes an acknowledgement may resolve a message name in: every documented
# Controller route, so a message the arrival poll reported can be acknowledged.
INBOX_DIRS="${FM_INBOX_DIRS:-/home/hd2admin/controller-replies:$FM_HOME/BRANDON-COMPUTE-COMMS/to-brandon-compute:$FM_HOME/agent-work/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute:$FM_HOME/agent-work/firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute:/home/hd2admin/brandon-inbox:$FM_HOME/controller-replies}"

# Portable stat: macOS (BSD) uses -f, Linux (GNU) uses -c. See bin/fm-watch.sh for
# why the two are never mixed in one command line.
if [ "$(uname)" = Darwin ]; then
  stat_mtime() { stat -f %m "$1" 2>/dev/null; }
else
  stat_mtime() { stat -c %Y "$1" 2>/dev/null; }
fi

file_hash() {  # <path>
  local out
  if command -v sha256sum >/dev/null 2>&1; then
    out=$(sha256sum -- "$1" 2>/dev/null) || return 1
  elif command -v shasum >/dev/null 2>&1; then
    out=$(shasum -a 256 -- "$1" 2>/dev/null) || return 1
  else
    return 1
  fi
  out=${out%% *}
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

valid_name() {  # <name>
  [[ "$1" =~ ^[A-Za-z0-9._-]+\.md$ ]]
}

# --- the ledgers ---------------------------------------------------------------
#
# They are read once per run and held in memory, so a scan of a few hundred
# messages costs a few reads instead of a few hundred greps.

HANDLED_BODY=
HANDLED_NAMES_BODY=
load_ledgers() {
  if [ -f "$HANDLED" ] && [ ! -L "$HANDLED" ]; then
    HANDLED_BODY=$(cat -- "$HANDLED" 2>/dev/null || true)
  else
    HANDLED_BODY=
  fi
  if [ -f "$HANDLED_NAMES" ] && [ ! -L "$HANDLED_NAMES" ]; then
    HANDLED_NAMES_BODY=$(cat -- "$HANDLED_NAMES" 2>/dev/null || true)
  else
    HANDLED_NAMES_BODY=
  fi
}

# is_handled: these exact bytes were acknowledged before.
is_handled() {  # <sha256>
  case "$HANDLED_BODY" in
    *"$1"*) return 0 ;;
  esac
  return 1
}

# is_handled_name: this message NAME was acknowledged before, so the logical
# message has been read and answered even if the Controller republished it.
is_handled_name() {  # <name>
  local want=$1 line
  while IFS= read -r line; do
    [ "$line" = "$want" ] && return 0
  done <<EOF
$HANDLED_NAMES_BODY
EOF
  return 1
}

# --- writing the ledgers --------------------------------------------------------

# record_handled: append a hash to the hash ledger.
record_handled() {  # <sha256>
  local hash=$1 tmp
  [ -d "$STATE" ] && [ ! -L "$STATE" ] || return 1
  tmp=$(mktemp "$STATE/.controller-inbox-handled.XXXXXX") || return 1
  if [ -f "$HANDLED" ] && [ ! -L "$HANDLED" ]; then
    cat -- "$HANDLED" > "$tmp" 2>/dev/null || { rm -f -- "$tmp"; return 1; }
  fi
  printf '%s\n' "$hash" >> "$tmp" || { rm -f -- "$tmp"; return 1; }
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$HANDLED" || { rm -f -- "$tmp"; return 1; }
}

# record_handled_name: append the message name to the name ledger, once.
record_handled_name() {  # <name>
  local name=$1 tmp
  [ -d "$STATE" ] && [ ! -L "$STATE" ] || return 1
  tmp=$(mktemp "$STATE/.controller-inbox-handled-names.XXXXXX") || return 1
  if [ -f "$HANDLED_NAMES" ] && [ ! -L "$HANDLED_NAMES" ]; then
    cat -- "$HANDLED_NAMES" > "$tmp" 2>/dev/null || { rm -f -- "$tmp"; return 1; }
  fi
  grep -Fqx -- "$name" "$tmp" || printf '%s\n' "$name" >> "$tmp" \
    || { rm -f -- "$tmp"; return 1; }
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$HANDLED_NAMES" || { rm -f -- "$tmp"; return 1; }
}

# record_acknowledged: the acknowledgement record proper - the name, the hash as
# the evidence of the bytes, and the UTC time the acknowledgement was made.
record_acknowledged() {  # <name> <sha256> <utc>
  local name=$1 hash=$2 stamp=$3 tmp
  [ -d "$STATE" ] && [ ! -L "$STATE" ] || return 1
  tmp=$(mktemp "$STATE/.controller-inbox-acknowledged.XXXXXX") || return 1
  if [ -f "$ACKNOWLEDGED" ] && [ ! -L "$ACKNOWLEDGED" ]; then
    cat -- "$ACKNOWLEDGED" > "$tmp" 2>/dev/null || { rm -f -- "$tmp"; return 1; }
  fi
  printf '%s\t%s\t%s\n' "$name" "$hash" "$stamp" >> "$tmp" \
    || { rm -f -- "$tmp"; return 1; }
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$ACKNOWLEDGED" || { rm -f -- "$tmp"; return 1; }
}

# --- the republication log ------------------------------------------------------

REPUBLISHED_BODY=
load_republished() {
  if [ -f "$REPUBLISHED_LOG" ] && [ ! -L "$REPUBLISHED_LOG" ]; then
    REPUBLISHED_BODY=$(cat -- "$REPUBLISHED_LOG" 2>/dev/null || true)
  else
    REPUBLISHED_BODY=
  fi
}

# republication_already_logged: this exact republished content is already on
# record, so a scan that keeps seeing it does not keep writing it.
republication_already_logged() {  # <name> <sha256>
  case "$REPUBLISHED_BODY" in
    *"name=$1 sha256=$2 "*) return 0 ;;
  esac
  return 1
}

# acknowledged_hash_for_name: the hash that was acknowledged for this name, read
# from the acknowledgement record. It is the OLD hash a republication replaces.
acknowledged_hash_for_name() {  # <name>
  local want=$1 line n h stamp found=
  [ -f "$ACKNOWLEDGED" ] && [ ! -L "$ACKNOWLEDGED" ] || return 1
  while IFS=$'\t' read -r n h stamp; do
    [ -n "$n" ] || continue
    [ "$n" = "$want" ] || continue
    [ -n "$h" ] || continue
    found=$h
  done < "$ACKNOWLEDGED"
  [ -n "$found" ] || return 1
  printf '%s\n' "$found"
}

# last_republished_hash_for_name: the hash this name was last seen with in the
# republication log. It is the OLD hash when the acknowledgement record does not
# carry one.
last_republished_hash_for_name() {  # <name>
  local want=$1 line found=
  [ -n "$REPUBLISHED_BODY" ] || return 1
  while IFS= read -r line; do
    case "$line" in
      *" name=$want sha256="*)
        case "$line" in
          *" sha256="*)
            found=${line##* sha256=}
            found=${found%% *}
            ;;
        esac
        ;;
    esac
  done <<EOF
$REPUBLISHED_BODY
EOF
  [ -n "$found" ] || return 1
  printf '%s\n' "$found"
}

# record_republication: the republication is visible, and it is not blocking.
# Both hashes are recorded: the old one the acknowledgement carried and the new
# one the republished content has.
record_republication() {  # <name> <sha256> <old-hash>
  local name=$1 hash=$2 old=$3
  [ -d "$STATE" ] && [ ! -L "$STATE" ] || return 0
  printf '%s name=%s sha256=%s old_sha256=%s - republished after acknowledgement; visible, not blocking\n' \
    "$(date -u +%FT%TZ)" "$name" "$hash" "$old" >> "$REPUBLISHED_LOG" 2>/dev/null || true
  chmod 0600 "$REPUBLISHED_LOG" 2>/dev/null || true
  cap_republished
}

cap_republished() {
  local lines tmp
  [ -f "$REPUBLISHED_LOG" ] && [ ! -L "$REPUBLISHED_LOG" ] || return 0
  lines=$(wc -l < "$REPUBLISHED_LOG" 2>/dev/null || echo 0)
  case "$lines" in
    ''|*[!0-9]*) return 0 ;;
  esac
  [ "$lines" -gt "$REPUBLISHED_MAX_LINES" ] || return 0
  tmp=$(mktemp "$STATE/.controller-inbox-republished.XXXXXX") || return 0
  tail -n "$REPUBLISHED_MAX_LINES" -- "$REPUBLISHED_LOG" > "$tmp" 2>/dev/null || {
    rm -f -- "$tmp"
    return 0
  }
  chmod 0600 "$tmp" 2>/dev/null || true
  mv -f -- "$tmp" "$REPUBLISHED_LOG" 2>/dev/null || rm -f -- "$tmp"
}

# --- the inbound routes ---------------------------------------------------------

split_dirs() {  # <colon-separated list>; echoes one directory per line
  local list=$1 d
  local IFS=':'
  for d in $list; do
    [ -n "$d" ] || continue
    printf '%s\n' "$d"
  done
}

# locate: resolve a message name to a real regular file across the routes.
locate() {  # <name>
  local name=$1 dir path
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    [ -d "$dir" ] && [ ! -L "$dir" ] || continue
    path="$dir/$name"
    [ -f "$path" ] && [ ! -L "$path" ] || continue
    printf '%s\n' "$path"
    return 0
  done <<EOF
$(split_dirs "$INBOX_DIRS")
EOF
  return 1
}

# --- acknowledgement ------------------------------------------------------------

ack_message() {  # <name> <sha256>
  local name=$1 expected=$2 path actual stamp
  valid_name "$name" || {
    printf 'refused: invalid Controller message filename\n' >&2
    return 2
  }
  case "$expected" in
    *[!a-f0-9]*|'') length=0 ;;
    *) length=${#expected} ;;
  esac
  if [ "${length:-0}" -ne 64 ]; then
    printf 'refused: invalid Controller message digest\n' >&2
    return 2
  fi
  path=$(locate "$name") || {
    printf 'refused: Controller message is unavailable\n' >&2
    return 1
  }
  actual=$(file_hash "$path") || {
    printf 'refused: could not verify Controller message\n' >&2
    return 1
  }
  [ "$actual" = "$expected" ] || {
    printf 'refused: Controller message changed after it was read\n' >&2
    return 1
  }
  stamp=$(date -u +%FT%TZ)
  # The name is recorded even when these exact bytes were acknowledged before:
  # the name is the key of the acknowledgement, and a message acknowledged
  # before the name ledger existed must still be handled after it is
  # republished.
  record_handled_name "$name" || {
    printf 'refused: could not record the message name\n' >&2
    return 1
  }
  record_acknowledged "$name" "$expected" "$stamp" || {
    printf 'refused: could not record the acknowledgement\n' >&2
    return 1
  }
  if is_handled "$expected"; then
    printf 'already-acknowledged: %s sha256=%s\n' "$name" "$expected"
    return 0
  fi
  record_handled "$expected" || {
    printf 'refused: could not record acknowledgement\n' >&2
    return 1
  }
  printf 'acknowledged: %s sha256=%s\n' "$name" "$expected"
}

# --- the scan -------------------------------------------------------------------

REPORT=
scan() {
  local dir f name hash mtime age old
  local now oldest_age=0 oldest_name=""
  now=$(date +%s)
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    [ -d "$dir" ] && [ ! -L "$dir" ] || continue
    for f in "$dir"/*.md; do
      [ -f "$f" ] && [ ! -L "$f" ] || continue
      name=$(basename "$f")
      valid_name "$name" || continue
      hash=$(file_hash "$f") || continue
      [ -n "$hash" ] || continue
      # These exact bytes were acknowledged before: nothing to say.
      if is_handled "$hash"; then
        if [ -n "$REPORT" ]; then
          printf 'handled: %s sha256=%s\n' "$name" "$hash"
        fi
        continue
      fi
      # The logical message was acknowledged and the Controller republished it
      # with new bytes. That is visible, and it does not block.
      if is_handled_name "$name"; then
        old=$(acknowledged_hash_for_name "$name" || true)
        [ -n "$old" ] || old=$(last_republished_hash_for_name "$name" || true)
        [ -n "$old" ] || old="unknown"
        if ! republication_already_logged "$name" "$hash"; then
          record_republication "$name" "$hash" "$old"
          load_republished
        fi
        if [ -n "$REPORT" ]; then
          printf 'republished: %s old_sha256=%s new_sha256=%s\n' "$name" "$old" "$hash"
        fi
        continue
      fi
      mtime=$(stat_mtime "$f") || continue
      case "$mtime" in
        ''|*[!0-9]*) continue ;;
      esac
      age=$(( now - mtime ))
      if [ -n "$REPORT" ]; then
        if [ "$age" -gt "$STALE_SECONDS" ]; then
          printf 'unhandled: %s sha256=%s age=%ss action=blocking\n' "$name" "$hash" "$age"
        else
          printf 'unhandled: %s sha256=%s age=%ss\n' "$name" "$hash" "$age"
        fi
      fi
      if [ "$age" -gt "$STALE_SECONDS" ] && [ "$age" -gt "$oldest_age" ]; then
        oldest_age=$age
        oldest_name=$name
      fi
    done
  done <<EOF
$(split_dirs "$BACKSTOP_DIRS")
EOF

  if [ -n "$oldest_name" ]; then
    # The actionable finding. This is the only thing on stdout in the watcher
    # check mode.
    printf 'unhandled inbound message older than %ss: %s age=%ss - read, handle, then acknowledge its bytes\n' \
      "$STALE_SECONDS" "$oldest_name" "$oldest_age"
    if [ -n "$REPORT" ]; then
      printf '  acknowledge it by name: %s --ack %s <sha256>\n' "$(basename "$0")" "$oldest_name"
    fi
  fi
}

case "${1:-}" in
  --ack)
    if [ "$#" -ne 3 ]; then
      printf 'usage: %s --ack <filename> <sha256>\n' "$(basename "$0")" >&2
      exit 2
    fi
    load_ledgers
    ack_message "$2" "$3"
    exit $?
    ;;
  --report)
    REPORT=1
    shift
    ;;
  '')
    ;;
  *)
    printf 'usage: %s [--report] [--ack <filename> <sha256>]\n' "$(basename "$0")" >&2
    exit 2
    ;;
esac

load_ledgers
load_republished
# The scan mode never fails the watcher. The watcher treats a check that exits
# non-zero as a broken poll, so nounset is released for the scan: an unexpected
# expansion error must never turn into a non-zero exit.
set +u
scan
exit 0
