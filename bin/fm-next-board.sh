#!/usr/bin/env bash
# fm-next-board.sh — regenerate the NEXT signpost.
#
# The board says: what is happening now, what is next, what only the Captain can
# decide, and what is still a residual. It is regenerated at the end of every lane
# cycle, so work cannot quietly die at the end of a report.
#
# The to-do list on the board is GENERATED from the machine lane ledger, so the
# ledger is passed through to the builder. The builder records the ledger's digest
# in the board, and bin/fm-todo-gate.sh uses that digest to tell whether the list
# is still in step with the machine state.
#
# usage: fm-next-board.sh [--repo <path>] [--out <dir>] [--stale-days N] [--ledger <path>]
set -uo pipefail

REPO="${FM_REPO:-/root/agent-work/deightonllm-firstmate}"
OUT="${FM_OUT:-$REPO/data/tracker}"
STALE=3
LEDGER="${FM_LEDGER:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --stale-days) STALE="$2"; shift 2 ;;
    --ledger) LEDGER="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BUILDER="$HERE/build-next-board.py"
[ -f "$BUILDER" ] || BUILDER="$REPO/bin/build-next-board.py"
if [ ! -f "$BUILDER" ]; then
  echo "fm-next-board: FAIL builder not found (looked in $HERE and $REPO/bin)" >&2
  exit 2
fi

mkdir -p "$OUT"
if [ -n "$LEDGER" ]; then
  python3 "$BUILDER" --repo "$REPO" --out "$OUT" --stale-days "$STALE" --ledger "$LEDGER"
else
  python3 "$BUILDER" --repo "$REPO" --out "$OUT" --stale-days "$STALE"
fi
rc=$?
[ $rc -eq 0 ] || { echo "fm-next-board: FAIL builder exited $rc" >&2; exit $rc; }

BOARD="$OUT/NEXT-BOARD.md"
[ -f "$BOARD" ] || { echo "fm-next-board: FAIL board not written" >&2; exit 2; }

gaps=$(grep -c '^- `' "$BOARD" 2>/dev/null || true)
echo "fm-next-board: board at $BOARD ($(grep -c '^| `' "$BOARD" 2>/dev/null || echo 0) rows)"
echo "fm-next-board: ledger digest $(grep -m1 '^\*\*Ledger digest:\*\* ' "$BOARD" 2>/dev/null | sed -e 's/^\*\*Ledger digest:\*\*[[:space:]]*//')"
echo "NEXT: regenerate this board at the end of every lane cycle | owner: p1-leadlists | by: every lane close"
exit 0
