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
# A content hash ledger is deterministic. Usage:
#   bin/fm-outbound.sh <existing-file> <destination-filename>
#   bin/fm-outbound.sh --mark-only <existing-file>
set -u

FM_HOME="${FM_HOME:-/home/hd2admin/kun-agent-workspace}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
EXCHANGE=/home/hd2admin/controller-replies
MIRROR="$FM_HOME/BRANDON-COMPUTE-COMMS/from-brandon-compute"
OUTBOUND_LEDGER="$STATE/.controller-inbox-outbound"

valid_name() { [[ "$1" =~ ^[A-Za-z0-9._-]+\.md$ ]]; }

mark() {  # <file>
  local hash tmp
  hash=$(sha256sum -- "$1" 2>/dev/null) || { printf 'fm-outbound: cannot hash %s\n' "$1" >&2; return 1; }
  hash=${hash%% *}
  [[ -d "$STATE" && ! -L "$STATE" ]] || { printf 'fm-outbound: state unavailable\n' >&2; return 1; }
  tmp=$(mktemp "$STATE/.controller-inbox-outbound.XXXXXX") || return 1
  if [[ -f "$OUTBOUND_LEDGER" ]] && ! cat -- "$OUTBOUND_LEDGER" > "$tmp"; then rm -f -- "$tmp"; return 1; fi
  grep -Fqx -- "$hash" "$tmp" || printf '%s\n' "$hash" >> "$tmp"
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$OUTBOUND_LEDGER" || { rm -f -- "$tmp"; return 1; }
  printf '%s\n' "$hash"
}

case "${1:-}" in
  --mark-only)
    [[ $# -eq 2 ]] || { printf 'usage: fm-outbound.sh --mark-only <file>\n' >&2; exit 2; }
    [[ -f "$2" && ! -L "$2" ]] || { printf 'fm-outbound: source is unavailable\n' >&2; exit 1; }
    mark "$2" >/dev/null || exit 1
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

mark "$src" >/dev/null || printf 'fm-outbound: WARNING copy succeeded but outbound ledger was not updated\n' >&2
exit 0