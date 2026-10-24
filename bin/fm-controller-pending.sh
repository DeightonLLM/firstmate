#!/usr/bin/env bash
# fm-controller-pending.sh - report notes written for Controller but NOT yet
# transmitted. A transmission is keyed by MESSAGE NAME.
#
# THE RULE: a transmission is recorded by MESSAGE NAME, and the hash is kept as
# the evidence of the bytes that were transmitted.
#   * A name that was transmitted is TRANSMITTED, even when its bytes changed
#     since it was transmitted. The change stays visible: a reissued note is
#     reported as reissued, with the old hash and the new hash, and it never
#     blocks.
#   * A name that was never transmitted is unsent, and it still reports.
#
# WHY: this check used to compare the CURRENT hash of every note in the outbox
# against a ledger of bare hashes. A note that was transmitted and then
# reissued has bytes that are not the bytes that went out, so the hash on
# record was the old one and the note was reported as never sent on every
# single cycle. A permanently unsent backlog kept the watcher exiting with an
# actionable reason, so supervision never held.
#
# WHERE THE ANSWER COMES FROM, in order:
#   1. the name-keyed transmission record written by bin/fm-outbound.sh: the
#      message name, the hash of the bytes transmitted under that name, and the
#      UTC time of the transmission.
#   2. the hash ledger: these exact bytes were transmitted before. A note in
#      the outbox that carries those exact bytes under that name was
#      transmitted, and it is reconciled into the name-keyed record so that a
#      later reissue of the same name is recognisable as a reissue.
#   3. the delivery route: a copy of that name is at the route the notes are
#      sent to. That copy is evidence of the transmission when it carries the
#      same bytes as the note, or when its bytes are on record in the hash
#      ledger. A copy at the route that this home never sent is not evidence.
#
# A note whose name has no transmission record and no evidence of one is
# reported as unsent. A never-transmitted note stays visible: it is never
# suppressed because its name looks like a reissue.
#
# OUTPUT CONTRACT (the watcher depends on this):
#   * stdout carries the ACTIONABLE finding ONLY: the notes that were never
#     transmitted, oldest first, and the action line. The watcher treats any
#     stdout from a check as actionable, so a notice on stdout is the defect
#     this script exists to remove.
#   * A reissue is NOT on stdout. It is recorded in the durable reissue log,
#     once per reissue, so the change stays visible without re-arming the
#     watcher on every cycle and without the log growing on every scan.
#   * --report prints the classification of every note for a human reader. It
#     is NOT the watcher check mode and must not be registered as one.
#
# The age of an unsent note is reported in whole days, so two scans of an
# unchanged set produce identical output and the watcher is not woken by the
# clock alone.
#
# Usage:
#   fm-controller-pending.sh
#   fm-controller-pending.sh --report
#
# Exit:
#   0 nothing pending, 1 something pending (message on stdout), 2 usage error
set -u

FM_HOME="${FM_HOME:-/home/hd2admin/kun-agent-workspace}"
STATE="$FM_HOME/state"
OUTBOX="${FM_OUTBOUND_OUTBOX:-$FM_HOME/BRANDON-COMPUTE-COMMS/from-brandon-compute}"
HASH_LEDGER="${FM_OUTBOUND_HASH_LEDGER:-$STATE/.controller-inbox-outbound}"
NAMES_LEDGER="${FM_OUTBOUND_NAMES_LEDGER:-$STATE/.controller-inbox-outbound-names}"
RECORDS="${FM_OUTBOUND_RECORDS:-$STATE/.controller-inbox-outbound-transmitted}"
REISSUED_LOG="${FM_OUTBOUND_REISSUED_LOG:-$STATE/.controller-inbox-outbound-reissued.log}"
DELIVERY_ROUTES="${FM_OUTBOUND_DELIVERY_ROUTES:-/home/hd2admin/controller-replies}"
REISSUED_MAX_LINES="${FM_OUTBOUND_REISSUED_MAX_LINES:-500}"

REPORT=
case "${1:-}" in
  --report) REPORT=1 ;;
  '') ;;
  *)
    printf 'usage: %s [--report]\n' "$(basename "$0")" >&2
    exit 2
    ;;
esac

TAB=$(printf '\t')

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

# Portable stat: macOS (BSD) uses -f, Linux (GNU) uses -c.
if [ "$(uname)" = Darwin ]; then
  stat_mtime() { stat -f %m "$1" 2>/dev/null; }
else
  stat_mtime() { stat -c %Y "$1" 2>/dev/null; }
fi

# --- the ledgers ----------------------------------------------------------------
#
# They are read once per run and held in memory, so a scan of a few hundred
# notes costs a few reads instead of a few hundred greps.

HASH_BODY=
NAMES_BODY=
RECORDS_BODY=
load_ledgers() {
  if [ -f "$HASH_LEDGER" ] && [ ! -L "$HASH_LEDGER" ]; then
    HASH_BODY=$(cat -- "$HASH_LEDGER" 2>/dev/null || true)
  else
    HASH_BODY=
  fi
  if [ -f "$NAMES_LEDGER" ] && [ ! -L "$NAMES_LEDGER" ]; then
    NAMES_BODY=$(cat -- "$NAMES_LEDGER" 2>/dev/null || true)
  else
    NAMES_BODY=
  fi
  if [ -f "$RECORDS" ] && [ ! -L "$RECORDS" ]; then
    RECORDS_BODY=$(cat -- "$RECORDS" 2>/dev/null || true)
  else
    RECORDS_BODY=
  fi
}

# hash_on_record: these exact bytes were transmitted before.
hash_on_record() {  # <sha256>
  case "$HASH_BODY" in
    *"$1"*) return 0 ;;
  esac
  return 1
}

# NAME_INDEX: the names that are on record, delimited so a name can be matched
# exactly and not as a substring of another name.
NAME_INDEX=
build_name_index() {
  local line n
  NAME_INDEX="|"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$NAME_INDEX" in
      *"|$line|"*) : ;;
      *) NAME_INDEX="${NAME_INDEX}${line}|" ;;
    esac
  done <<EOF
$NAMES_BODY
EOF
  while IFS="$TAB" read -r n _; do
    [ -n "$n" ] || continue
    case "$NAME_INDEX" in
      *"|$n|"*) : ;;
      *) NAME_INDEX="${NAME_INDEX}${n}|" ;;
    esac
  done <<EOF
$RECORDS_BODY
EOF
}

# name_on_record: this message NAME was transmitted before, so the logical
# message has been sent even if the bytes changed since.
name_on_record() {  # <name>
  case "$NAME_INDEX" in
    *"|$1|"*) return 0 ;;
  esac
  return 1
}

# recorded_hash_for_name: the hash that was last recorded for this name. It is
# the old hash a reissue replaces.
recorded_hash_for_name() {  # <name>
  local want=$1 line n h stamp found=
  [ -n "$RECORDS_BODY" ] || return 1
  while IFS="$TAB" read -r n h stamp; do
    [ "$n" = "$want" ] || continue
    [ -n "$h" ] || continue
    found=$h
  done <<EOF
$RECORDS_BODY
EOF
  [ -n "$found" ] || return 1
  printf '%s\n' "$found"
}

# --- the delivery route ----------------------------------------------------------

split_dirs() {  # <colon-separated list>; echoes one directory per line
  local list=$1 d
  local IFS=':'
  for d in $list; do
    [ -n "$d" ] || continue
    printf '%s\n' "$d"
  done
}

route_copy_for_name() {  # <name>
  local name=$1 dir path
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    [ -d "$dir" ] && [ ! -L "$dir" ] || continue
    path="$dir/$name"
    [ -f "$path" ] && [ ! -L "$path" ] || continue
    printf '%s\n' "$path"
    return 0
  done <<EOF
$(split_dirs "$DELIVERY_ROUTES")
EOF
  return 1
}

# --- the reconciliation ----------------------------------------------------------
#
# A transmission that the old hash-keyed ledger can prove, but that predates the
# name-keyed record, is reconciled into the name-keyed record here. That is the
# reconciliation path the ledger did not have: after this, the name is the key
# and a later reissue of that name is recognisable as a reissue.
#
# Nothing is reconciled that cannot be proven. A note whose name has no
# transmission record and no evidence of one stays unsent and stays visible.

RECONCILE_TMP=
reconcile_add() {  # <name> <hash>
  [ -n "$RECONCILE_TMP" ] || return 0
  printf '%s\t%s\n' "$1" "$2" >> "$RECONCILE_TMP" 2>/dev/null || return 0
}

reconcile_flush() {
  local name hash stamp tmp
  [ -n "$RECONCILE_TMP" ] || return 0
  [ -s "$RECONCILE_TMP" ] || return 0
  [ -d "$STATE" ] && [ ! -L "$STATE" ] || return 0
  stamp=$(date -u +%FT%TZ)

  tmp=$(mktemp "$STATE/.controller-inbox-outbound-transmitted.XXXXXX") || return 0
  if [ -f "$RECORDS" ] && [ ! -L "$RECORDS" ]; then
    cat -- "$RECORDS" > "$tmp" 2>/dev/null || { rm -f -- "$tmp"; return 0; }
  fi
  while IFS="$TAB" read -r name hash; do
    [ -n "$name" ] && [ -n "$hash" ] || continue
    grep -Fq -- "$name""$TAB""$hash" "$tmp" 2>/dev/null && continue
    printf '%s\t%s\t%s\n' "$name" "$hash" "$stamp" >> "$tmp" 2>/dev/null || true
  done < "$RECONCILE_TMP"
  chmod 0600 "$tmp" 2>/dev/null || true
  mv -f -- "$tmp" "$RECORDS" 2>/dev/null || rm -f -- "$tmp"

  tmp=$(mktemp "$STATE/.controller-inbox-outbound-names.XXXXXX") || return 0
  if [ -f "$NAMES_LEDGER" ] && [ ! -L "$NAMES_LEDGER" ]; then
    cat -- "$NAMES_LEDGER" > "$tmp" 2>/dev/null || { rm -f -- "$tmp"; return 0; }
  fi
  while IFS="$TAB" read -r name hash; do
    [ -n "$name" ] || continue
    grep -Fqx -- "$name" "$tmp" 2>/dev/null && continue
    printf '%s\n' "$name" >> "$tmp" 2>/dev/null || true
  done < "$RECONCILE_TMP"
  chmod 0600 "$tmp" 2>/dev/null || true
  mv -f -- "$tmp" "$NAMES_LEDGER" 2>/dev/null || rm -f -- "$tmp"
  return 0
}

# --- the reissue log -------------------------------------------------------------
#
# A reissue is visible, and it is not blocking. It goes to a durable log and
# not to stdout, because the watcher treats any stdout from a check as
# actionable and a notice on stdout is the defect itself.

reissue_already_logged() {  # <name> <sha256>
  [ -f "$REISSUED_LOG" ] && [ ! -L "$REISSUED_LOG" ] || return 1
  grep -Fq -- "name=$1 sha256=$2 " "$REISSUED_LOG" 2>/dev/null
}

record_reissue() {  # <name> <old-hash> <new-hash>
  local name=$1 old=$2 new=$3
  reissue_already_logged "$name" "$new" && return 0
  [ -d "$STATE" ] && [ ! -L "$STATE" ] || return 0
  printf '%s name=%s sha256=%s old_sha256=%s - reissued after transmission; visible, not blocking\n' \
    "$(date -u +%FT%TZ)" "$name" "$new" "$old" >> "$REISSUED_LOG" 2>/dev/null || return 0
  chmod 0600 "$REISSUED_LOG" 2>/dev/null || true
  cap_reissue_log
}

cap_reissue_log() {
  local lines tmp
  [ -f "$REISSUED_LOG" ] && [ ! -L "$REISSUED_LOG" ] || return 0
  lines=$(wc -l < "$REISSUED_LOG" 2>/dev/null || echo 0)
  case "$lines" in
    ''|*[!0-9]*) return 0 ;;
  esac
  [ "$lines" -gt "$REISSUED_MAX_LINES" ] || return 0
  tmp=$(mktemp "$STATE/.controller-inbox-outbound-reissued.XXXXXX") || return 0
  tail -n "$REISSUED_MAX_LINES" -- "$REISSUED_LOG" > "$tmp" 2>/dev/null || {
    rm -f -- "$tmp"
    return 0
  }
  chmod 0600 "$tmp" 2>/dev/null || true
  mv -f -- "$tmp" "$REISSUED_LOG" 2>/dev/null || rm -f -- "$tmp"
}

# --- the scan --------------------------------------------------------------------

load_ledgers
build_name_index

UNSENT_TMP=$(mktemp "${TMPDIR:-/tmp}/fm-controller-pending.XXXXXX") || exit 0
RECONCILE_TMP=$(mktemp "${TMPDIR:-/tmp}/fm-controller-pending-reconcile.XXXXXX") || exit 0
trap 'rm -f -- "$UNSENT_TMP" "$RECONCILE_TMP"' EXIT

pending=0
now=$(date +%s)
for f in "$OUTBOX"/*.md; do
  [ -f "$f" ] && [ ! -L "$f" ] || continue
  name=$(basename "$f")
  cur=$(file_hash "$f") || continue
  [ -n "$cur" ] || continue

  class=unsent
  old=

  if name_on_record "$name"; then
    # The name was transmitted. The bytes may have changed since: that is a
    # reissue, and it is not a message that was never sent.
    old=$(recorded_hash_for_name "$name" 2>/dev/null || true)
    if [ -n "$old" ] && [ "$old" != "$cur" ]; then
      class=reissued
    else
      class=transmitted
    fi
  elif hash_on_record "$cur"; then
    # These exact bytes were transmitted before, and this note carries them
    # under this name: the name was transmitted. Reconcile it by name so a
    # later reissue of this name is recognisable as a reissue.
    class=transmitted
    reconcile_add "$name" "$cur"
  else
    route=$(route_copy_for_name "$name" 2>/dev/null || true)
    if [ -n "$route" ]; then
      route_hash=$(file_hash "$route" 2>/dev/null || true)
      if [ -n "$route_hash" ]; then
        if [ "$route_hash" = "$cur" ]; then
          # A copy of this name is at the route with these bytes: it was sent.
          class=transmitted
          reconcile_add "$name" "$cur"
        elif hash_on_record "$route_hash"; then
          # The name was transmitted with bytes that are not the bytes now in
          # the outbox: a reissue. Visible, and not blocking.
          class=reissued
          old=$route_hash
          reconcile_add "$name" "$route_hash"
        fi
      fi
    fi
  fi

  case "$class" in
    transmitted)
      if [ -n "$REPORT" ]; then
        printf 'transmitted: %s sha256=%s\n' "$name" "$cur"
      fi
      ;;
    reissued)
      old=${old:-unknown}
      record_reissue "$name" "$old" "$cur"
      if [ -n "$REPORT" ]; then
        printf 'reissued: %s old_sha256=%s new_sha256=%s\n' "$name" "$old" "$cur"
      fi
      ;;
    unsent)
      mtime=$(stat_mtime "$f") || mtime=$now
      case "$mtime" in
        ''|*[!0-9]*) mtime=$now ;;
      esac
      age=$(( now - mtime ))
      [ "$age" -ge 0 ] || age=0
      printf '%s\t%s\t%s\n' "$age" "$name" "$cur" >> "$UNSENT_TMP" 2>/dev/null || true
      pending=$(( pending + 1 ))
      ;;
  esac
done

reconcile_flush

if [ "$pending" -gt 0 ]; then
  # Oldest first, so the first line is the note that has been waiting longest.
  sort -t "$TAB" -k1,1nr -k2,2 -- "$UNSENT_TMP" 2>/dev/null \
    | while IFS="$TAB" read -r age name cur; do
        if [ -n "$REPORT" ]; then
          printf 'unsent-to-controller: %s sha256=%s age=%ss\n' "$name" "$cur" "$age"
        else
          printf 'unsent-to-controller: %s sha256=%s age_days=%s\n' "$name" "$cur" "$(( age / 86400 ))"
        fi
      done
  printf 'ACTION: transmit with bin/fm-to-controller.sh <file> <name> before reporting this work as done.\n'
  exit 1
fi

exit 0
