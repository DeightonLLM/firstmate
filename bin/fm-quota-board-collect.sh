#!/usr/bin/env bash
# fm-quota-board-collect.sh - regenerate the HD2 quota + aggregate token-use band.
#
# One command, two steps:
#   1. fm-quota-board-snapshot.py  reads quota-axi on every reachable fleet host
#      and the usage ledger on every host that has one, then writes ONE snapshot
#      JSON that respects the ledger's contract (null != zero, official totals
#      supersede local subsets, surfaces are partitioned, unknown stays labelled).
#   2. fm-quota-board-bind.py      inlines that snapshot into the board HTML so
#      the band renders from a file:// URL with no fetch and no CDN.
#
# The collector never reads credentials, never refreshes a credential
# (quota-axi runs with --no-credential-refresh), and never writes to any host
# other than this one.
#
# Usage:
#   bin/fm-quota-board-collect.sh [--home DIR] [--html FILE] [--snapshot FILE]
#                                 [--check] [--no-bind]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HOME_DIR="$REPO_ROOT"
HTML_FILE=""
SNAPSHOT_FILE=""
CHECK=0
NO_BIND=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --home) HOME_DIR="$2"; shift 2 ;;
    --html) HTML_FILE="$2"; shift 2 ;;
    --snapshot) SNAPSHOT_FILE="$2"; shift 2 ;;
    --check) CHECK=1; shift ;;
    --no-bind) NO_BIND=1; shift ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) printf 'collect: FAIL unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [ -z "$SNAPSHOT_FILE" ]; then
  SNAPSHOT_FILE="$HOME_DIR/data/hd2-takeover/quota-board-snapshot.json"
fi
if [ -z "$HTML_FILE" ]; then
  HTML_FILE="$HOME_DIR/unified-board.html"
fi

if [ "$CHECK" -eq 1 ]; then
  # Check mode writes nothing into the repo: the snapshot is built in a
  # temporary directory and only compared with what the board carries.
  TMP_OUT="$(mktemp -d "${TMPDIR:-/tmp}/qm-board-check.XXXXXX")"
  trap 'rm -rf "$TMP_OUT"' EXIT
  printf 'collect: check only (nothing is written)\n'
  python3 "$SCRIPT_DIR/fm-quota-board-snapshot.py" --home "$HOME_DIR" --out "$TMP_OUT/snapshot.json" --print-summary
  python3 "$SCRIPT_DIR/fm-quota-board-bind.py" --home "$HOME_DIR" --snapshot "$TMP_OUT/snapshot.json" --html "$HTML_FILE" --check || true
  exit 0
fi

printf 'collect: snapshot -> %s\n' "$SNAPSHOT_FILE"
python3 "$SCRIPT_DIR/fm-quota-board-snapshot.py" --home "$HOME_DIR" --out "$SNAPSHOT_FILE" --print-summary

if [ "$NO_BIND" -eq 1 ]; then
  printf 'collect: bind skipped (--no-bind)\n'
  exit 0
fi

printf 'collect: bind -> %s\n' "$HTML_FILE"
python3 "$SCRIPT_DIR/fm-quota-board-bind.py" --home "$HOME_DIR" --snapshot "$SNAPSHOT_FILE" --html "$HTML_FILE"
