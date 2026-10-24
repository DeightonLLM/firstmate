#!/usr/bin/env bash
# Send a message to Controller and record it, so the inbound poll never reports
# this home's own outbound mail back to it.
#
# The exchange directory /home/hd2admin/controller-replies is BIDIRECTIONAL:
# both sides write there. Writing outbound into it without a record made the
# Controller-inbox poll report Brandon's own messages as if they were replies.
# Guessing authorship from the message prose was rejected: 11 of 124 files in
# that directory carry a "# Brandon" heading, and the rest do not, so a heading
# filter would either leak or silently drop real replies.
#
# THE RECORD: a transmission is recorded by MESSAGE NAME, and the hash is kept
# as the evidence of the bytes that were transmitted. This is the outbound twin
# of the inbound acknowledgement rule, where the name is the key and the hash
# is the evidence.
#
#   state/.controller-inbox-outbound             the hash ledger: one sha256 per
#                                               line. The evidence of the bytes
#                                               that were transmitted.
#   state/.controller-inbox-outbound-names       the name ledger: one message
#                                               name per line. This is the KEY
#                                               of the transmission record.
#   state/.controller-inbox-outbound-transmitted the transmission record: the
#                                               message name, the hash of the
#                                               bytes transmitted under that
#                                               name, and the UTC time of the
#                                               transmission, one tab-separated
#                                               record per line.
#
# WHY THE NAME IS THE KEY: a note that was transmitted and then reissued has
# bytes that are not the bytes that went out. A ledger keyed by the hash alone
# made that note read as a message that was never sent, on every single scan,
# forever. Keyed by the name, the note is known to have been sent, and the
# change in its bytes is a reissue - visible, and not a false alarm.
#
# The record is written before the name, so a name is never on record without
# the evidence that backs it.
#
# Usage:
#   bin/fm-outbound.sh <existing-file> <destination-filename>
#   bin/fm-outbound.sh --mark-only <existing-file>
#
# Environment:
#   FM_HOME                   the home that owns the mirror and the ledgers
#   FM_STATE_OVERRIDE         overrides the state directory holding the ledgers
#   FM_OUTBOUND_EXCHANGE      the shared exchange directory
#   FM_OUTBOUND_MIRROR        the local outbox mirror
#   FM_OUTBOUND_NAMES_LEDGER  the name ledger
#   FM_OUTBOUND_RECORDS       the transmission record
set -u

FM_HOME="${FM_HOME:-/home/hd2admin/kun-agent-workspace}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
EXCHANGE="${FM_OUTBOUND_EXCHANGE:-/home/hd2admin/controller-replies}"
MIRROR="${FM_OUTBOUND_MIRROR:-$FM_HOME/BRANDON-COMPUTE-COMMS/from-brandon-compute}"
OUTBOUND_LEDGER="$STATE/.controller-inbox-outbound"
NAMES_LEDGER="${FM_OUTBOUND_NAMES_LEDGER:-$STATE/.controller-inbox-outbound-names}"
RECORDS="${FM_OUTBOUND_RECORDS:-$STATE/.controller-inbox-outbound-transmitted}"

valid_name() { [[ "$1" =~ ^[A-Za-z0-9._-]+\.md$ ]]; }

# mark: record the transmission of <file> under <name>.
#
# The hash ledger keeps the bare sha256 per line, unchanged, so every consumer
# of that ledger keeps working. The name ledger and the transmission record
# carry the name, so a later reissue of the same name is recognisable as a
# reissue and not as a message that was never sent.
mark() {  # <file> <name>
  local src=$1 name=$2 hash tmp stamp
  hash=$(sha256sum -- "$src" 2>/dev/null) || { printf 'fm-outbound: cannot hash %s\n' "$src" >&2; return 1; }
  hash=${hash%% *}
  [[ -n "$name" ]] || { printf 'fm-outbound: no message name to record\n' >&2; return 1; }
  [[ -d "$STATE" && ! -L "$STATE" ]] || { printf 'fm-outbound: state unavailable\n' >&2; return 1; }

  # The evidence of the bytes, one bare sha256 per line.
  tmp=$(mktemp "$STATE/.controller-inbox-outbound.XXXXXX") || return 1
  if [[ -f "$OUTBOUND_LEDGER" ]] && ! cat -- "$OUTBOUND_LEDGER" > "$tmp"; then rm -f -- "$tmp"; return 1; fi
  grep -Fqx -- "$hash" "$tmp" || printf '%s\n' "$hash" >> "$tmp"
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$OUTBOUND_LEDGER" || { rm -f -- "$tmp"; return 1; }

  # The record: the name, the hash of the bytes transmitted under that name,
  # and the UTC time of the transmission.
  stamp=$(date -u +%FT%TZ)
  tmp=$(mktemp "$STATE/.controller-inbox-outbound-transmitted.XXXXXX") || return 1
  if [[ -f "$RECORDS" ]] && ! cat -- "$RECORDS" > "$tmp"; then rm -f -- "$tmp"; return 1; fi
  grep -Fq -- "$name"$'\t'"$hash" "$tmp" || printf '%s\t%s\t%s\n' "$name" "$hash" "$stamp" >> "$tmp"
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$RECORDS" || { rm -f -- "$tmp"; return 1; }

  # The key: the name on its own, once.
  tmp=$(mktemp "$STATE/.controller-inbox-outbound-names.XXXXXX") || return 1
  if [[ -f "$NAMES_LEDGER" ]] && ! cat -- "$NAMES_LEDGER" > "$tmp"; then rm -f -- "$tmp"; return 1; fi
  grep -Fqx -- "$name" "$tmp" || printf '%s\n' "$name" >> "$tmp"
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$NAMES_LEDGER" || { rm -f -- "$tmp"; return 1; }

  printf '%s\n' "$hash"
}

case "${1:-}" in
  --mark-only)
    [[ $# -eq 2 ]] || { printf 'usage: fm-outbound.sh --mark-only <file>\n' >&2; exit 2; }
    [[ -f "$2" && ! -L "$2" ]] || { printf 'fm-outbound: source is unavailable\n' >&2; exit 1; }
    mark "$2" "$(basename "$2")" >/dev/null || exit 1
    printf 'recorded: %s\n' "$2"
    ;;
  '')
    printf 'usage: fm-outbound.sh <file> <destination-filename> | --mark-only <file>\n' >&2
    exit 2
    ;;
esac

src=$1
dest=$2
[[ $# -eq 2 ]] || { printf 'usage: fm-outbound.sh <file> <destination-filename>\n' >&2; exit 2; }
valid_name "$dest" || { printf 'fm-outbound: invalid destination filename\n' >&2; exit 2; }
[[ -f "$src" && ! -L "$src" ]] || { printf 'fm-outbound: source is unavailable\n' >&2; exit 1; }

mkdir -p "$MIRROR" 2>/dev/null || true
for dir in "$MIRROR" "$EXCHANGE"; do
  [[ -d "$dir" && ! -L "$dir" ]] || continue
  cp -- "$src" "$dir/$dest" 2>/dev/null || { printf 'fm-outbound: could not write %s\n' "$dir/$dest" >&2; exit 1; }
  printf 'sent: %s\n' "$dir/$dest"
done

mark "$src" "$dest" >/dev/null || printf 'fm-outbound: WARNING copy succeeded but outbound ledger was not updated\n' >&2
exit 0
