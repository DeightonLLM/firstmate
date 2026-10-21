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
# The repo defaults to the checkout this script ships in, so the default is a real
# path on every host. FM_REPO or --repo names a different one.
#
# Fail closed. A repo that does not exist, or a board with nothing on it, is
# reported and the script exits non-zero, because a board built from an empty
# backlog is a signpost that points nowhere and nobody notices.
#
# usage: fm-next-board.sh [--repo <path>] [--out <dir>] [--stale-days N] [--ledger <path>]
set -uo pipefail

REPO_ARG=""
OUT_ARG=""
STALE=3
LEDGER="${FM_LEDGER:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO_ARG="$2"; shift 2 ;;
    --out) OUT_ARG="$2"; shift 2 ;;
    --stale-days) STALE="$2"; shift 2 ;;
    --ledger) LEDGER="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_REPO="$(cd "$HERE/.." 2>/dev/null && pwd -P)" || DEFAULT_REPO=""
REPO="${REPO_ARG:-${FM_REPO:-$DEFAULT_REPO}}"
OUT="${OUT_ARG:-${FM_OUT:-$REPO/data/tracker}}"

if [ -z "$REPO" ]; then
  echo "fm-next-board: FAIL the firstmate repo could not be determined from $HERE" >&2
  echo "  name one with --repo <path> or FM_REPO=<path>" >&2
  exit 2
fi
if [ ! -d "$REPO" ]; then
  echo "fm-next-board: FAIL the firstmate repo does not exist: $REPO" >&2
  echo "  named by: --repo, FM_REPO, or the checkout this script ships in" >&2
  exit 2
fi

BUILDER="$HERE/build-next-board.py"
[ -f "$BUILDER" ] || BUILDER="$REPO/bin/build-next-board.py"
if [ ! -f "$BUILDER" ]; then
  echo "fm-next-board: FAIL builder not found (looked in $HERE and $REPO/bin)" >&2
  exit 2
fi

mkdir -p "$OUT"
# The board is built in a temporary directory and published only once it has
# passed its checks, so a board that fails never replaces the published one.
TMP_OUT="$(mktemp -d "${TMPDIR:-/tmp}/fm-next-board.XXXXXX")" || {
  echo "fm-next-board: FAIL could not create a temporary build directory" >&2
  exit 2
}
trap 'rm -rf "$TMP_OUT"' EXIT

if [ -n "$LEDGER" ]; then
  builder_output=$(python3 "$BUILDER" --repo "$REPO" --out "$TMP_OUT" --stale-days "$STALE" --ledger "$LEDGER" 2>&1)
else
  builder_output=$(python3 "$BUILDER" --repo "$REPO" --out "$TMP_OUT" --stale-days "$STALE" 2>&1)
fi
rc=$?
if [ $rc -ne 0 ]; then
  printf '%s\n' "$builder_output" >&2
  echo "fm-next-board: FAIL builder exited $rc" >&2
  exit $rc
fi
printf '%s\n' "$builder_output" | sed "s|$TMP_OUT|$OUT|g"

BOARD="$TMP_OUT/NEXT-BOARD.md"
[ -f "$BOARD" ] || { echo "fm-next-board: FAIL board not written" >&2; exit 2; }

# A board with nothing on it means the backlog was not read, and a signpost that
# points nowhere is worse than no signpost, because it looks like an answer.
items=$(sed -n 's/.*\*\*items:\*\* \([0-9][0-9]*\).*/\1/p' "$BOARD" 2>/dev/null | head -1)
if [ -z "$items" ] || [ "$items" -eq 0 ]; then
  echo "fm-next-board: FAIL the board has no items, so the backlog was not read from $REPO" >&2
  echo "  check data/backlog.md and origin/main:data/backlog.md in $REPO" >&2
  echo "  the published board was left untouched" >&2
  exit 2
fi

mv "$TMP_OUT/NEXT-BOARD.md" "$OUT/NEXT-BOARD.md" || {
  echo "fm-next-board: FAIL could not publish the board to $OUT" >&2
  exit 2
}
if [ -f "$TMP_OUT/next-board.json" ]; then
  mv "$TMP_OUT/next-board.json" "$OUT/next-board.json" || {
    echo "fm-next-board: FAIL could not publish the machine board to $OUT" >&2
    exit 2
  }
fi

echo "fm-next-board: board at $OUT/NEXT-BOARD.md ($items items, $(grep -c '^| `' "$OUT/NEXT-BOARD.md" 2>/dev/null || echo 0) rows)"
echo "fm-next-board: ledger digest $(grep -m1 '^\*\*Ledger digest:\*\* ' "$OUT/NEXT-BOARD.md" 2>/dev/null | sed -e 's/^\*\*Ledger digest:\*\*[[:space:]]*//')"
echo "NEXT: regenerate this board at the end of every lane cycle | owner: p1-leadlists | by: every lane close"
exit 0
