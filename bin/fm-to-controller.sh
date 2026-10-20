#!/usr/bin/env bash
# fm-to-controller.sh - write AND send a note to Controller in ONE atomic step.
#
# WHY THIS EXISTS
# On 2026-10-15 firstmate said "sending" in chat about a capacity report and did
# not send it. The failure was not capability: bin/fm-outbound.sh existed and
# worked. The failure was that sending was a separate, optional act after the
# writing, so it could be skipped while the intent was stated as done. This
# script removes the gap: there is no way to create a note for Controller without
# it being transmitted by the same command that creates it.
#
# Delivery is still three separate facts. This guarantees TRANSMISSION only. It
# does not claim Controller read it, and it does not claim he accepted it.
#
# Usage:
#   fm-to-controller.sh <file> [destination-filename]
#   fm-to-controller.sh --text <name> <<'EOF' ... EOF
#
# Exit: 0 sent, non-zero refused with a reason.
set -u

FM_HOME="${FM_HOME:-/home/hd2admin/kun-agent-workspace}"
OUTBOX="$FM_HOME/BRANDON-COMPUTE-COMMS/from-brandon-compute"
LEDGER="$FM_HOME/state/.controller-inbox-outbound"

fail() { printf 'fm-to-controller: REFUSED - %s\n' "$1" >&2; exit 1; }

valid_name() { [[ "$1" =~ ^[A-Za-z0-9._-]+\.md$ ]]; }

record_hash() {  # <file>
  local hash tmp
  hash=$(sha256sum -- "$1" 2>/dev/null) || return 1
  hash=${hash%% *}
  mkdir -p "$(dirname "$LEDGER")" 2>/dev/null || return 1
  tmp=$(mktemp "$LEDGER.XXXXXX") || return 1
  if [ -f "$LEDGER" ] && ! cat -- "$LEDGER" > "$tmp"; then rm -f "$tmp"; return 1; fi
  printf '%s\n' "$hash" >> "$tmp"
  chmod 0600 "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f -- "$tmp" "$LEDGER" || { rm -f "$tmp"; return 1; }
}

transmit() {  # <dest-filename>
  local dest=$1 dir
  valid_name "$dest" || fail "invalid destination filename: $dest"
  mkdir -p "$OUTBOX" 2>/dev/null || fail "cannot create outbox"
  for dir in "$OUTBOX" /home/hd2admin/controller-replies; do
    [ -d "$dir" ] || continue
    cp -- "$OUTBOX/.send-staging" "$dir/$dest" 2>/dev/null \
      || cp -- "$TMP_SEND_SRC" "$dir/$dest" 2>/dev/null \
      || fail "could not write $dir/$dest"
    printf 'transmitted: %s\n' "$dir/$dest"
  done
  record_hash "$TMP_SEND_SRC" >/dev/null || printf 'fm-to-controller: WARNING ledger not updated\n' >&2
}

case "${1:-}" in
  '') printf 'usage: fm-to-controller.sh <file> [name] | --text <name>\n' >&2; exit 2 ;;
  --text)
    dest=${2:-}
    valid_name "$dest" || fail "--text requires a destination filename"
    TMP_SEND_SRC=$(mktemp "${TMPDIR:-/tmp}/fm-to-controller.XXXXXX.md") || fail "cannot stage"
    cat > "$TMP_SEND_SRC" || fail "cannot read stdin"
    ;;
  *)
    src=$1
    dest=${2:-$(basename "$1")}
    [ -f "$src" ] && [ ! -L "$src" ] || fail "source is not a readable regular file: $src"
    TMP_SEND_SRC=$(mktemp "${TMPDIR:-/tmp}/fm-to-controller.XXXXXX.md") || fail "cannot stage"
    cp -- "$src" "$TMP_SEND_SRC" || fail "cannot stage source"
    ;;
esac

transmit "$dest"
rm -f -- "$TMP_SEND_SRC"
printf 'SENT (transmission only; read and acceptance remain separate facts)\n'
exit 0