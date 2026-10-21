#!/usr/bin/env bash
# fm-live-state-refresh.sh - keep the board's verified-state source fresh.
#
# WHY THIS EXISTS.
#
# The board's signpost is built from TWO sources that must agree:
#   * data/tracker/live-state-20261020.json - the verifier lane's evidence-backed
#     states (schema hd2-live-state/v1). This is a CANONICAL shared file: it names
#     the shared repo path, it is written by the verifier lane's independent checks,
#     and every other surface reads it.
#   * data/tracker/tickets.jsonl - the Captain's own ticket rows.
#
# On 2026-10-21 this home was simply MISSING the live-state file. The board did not
# complain, it did not show an error - it quietly reported 39 tickets as CONTRACT-GAP
# that the verifier lane had already proved done, blocked or owned. The board was
# not stale, it was wrong, and it looked authoritative while being wrong. That is the
# worst kind of rot.
#
# So the file is refreshed, not left to chance. The transport is the comms mirror
# that already runs on its own cron: HD2 publishes the file into its comms outbox,
# the existing sync pulls it into BRANDON-COMPUTE-COMMS/from-hd2stack/, and this
# script installs it here. No network call happens in the publish path - the sync
# already did that - and the publish only ever reads a local file.
#
# FAILURE IS NEVER FATAL. A missing, stale or unreadable mirror leaves the installed
# file exactly as it was, and the publish continues. A board that is a few hours old
# is better than a board that is empty because a refresh failed.
#
# USAGE.
#   fm-live-state-refresh.sh           refresh if the mirror carries a newer file
#   fm-live-state-refresh.sh --check   report what would happen, change nothing
set -uo pipefail

REPO="${FM_REPO:-/root/agent-work/deightonllm-firstmate}"
MIRROR_REL="BRANDON-COMPUTE-COMMS/from-hd2stack/live-state-20261020.json"
DEST_REL="data/tracker/live-state-20261020.json"

CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

mirror="$REPO/$MIRROR_REL"
dest="$REPO/$DEST_REL"

if [ ! -f "$mirror" ]; then
  echo "fm-live-state-refresh: no mirror at $MIRROR_REL; keeping the installed file"
  exit 0
fi
if ! [ -r "$mirror" ]; then
  echo "fm-live-state-refresh: mirror is unreadable; keeping the installed file"
  exit 0
fi

mirror_sha=$(sha256sum "$mirror" 2>/dev/null | awk '{print $1}')
dest_sha=$(sha256sum "$dest" 2>/dev/null | awk '{print $1}')
if [ -n "$mirror_sha" ] && [ "$mirror_sha" = "$dest_sha" ]; then
  echo "fm-live-state-refresh: installed file is current ($dest_sha)"
  exit 0
fi

# A malformed file must never replace a good one. The schema is the contract.
if ! python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
items=d.get('tickets') or d.get('items') or []
if not isinstance(items,list) or not items:
    raise SystemExit(1)
for row in items:
    if not row.get('slug') or not row.get('true_state'):
        raise SystemExit(1)
" "$mirror" 2>/dev/null; then
  echo "fm-live-state-refresh: mirror file is malformed or empty; keeping the installed file"
  exit 0
fi

if [ "$CHECK_ONLY" = 1 ]; then
  echo "fm-live-state-refresh: WOULD install $mirror_sha (installed: ${dest_sha:-none})"
  exit 0
fi

mkdir -p "$(dirname "$dest")"
tmp="$(mktemp "$(dirname "$dest")/.live-state-refresh.XXXXXX")" || exit 0
if cp "$mirror" "$tmp" 2>/dev/null; then
  chmod 0644 "$tmp"
  mv -f -- "$tmp" "$dest" 2>/dev/null || rm -f -- "$tmp"
  echo "fm-live-state-refresh: installed $mirror_sha ($(wc -c < "$dest" 2>/dev/null) bytes)"
else
  rm -f -- "$tmp"
  echo "fm-live-state-refresh: copy failed; keeping the installed file"
fi
exit 0
