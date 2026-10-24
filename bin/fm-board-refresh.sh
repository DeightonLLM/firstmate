#!/usr/bin/env bash
# fm-board-refresh.sh - keep the generated to-do board in step with the machine lane ledger.
#
# WHY: the to-do board is GENERATED from the machine lane ledger, and it records
# that ledger's digest. Every time the ledger is republished the recorded digest
# stops matching the ledger bytes, the board is stale, and bin/fm-todo-gate.sh
# refuses to let a lane close. That refusal is correct and it keeps its teeth:
# a stale board is still a refusal. What was missing is the step that follows the
# ledger, so the board does not decay behind the gate's back.
#
# THE RULE: the board is rebuilt from the live ledger before the to-do gate
# judges it. This script is that step and nothing else. It never weakens the
# gate, never decides whether a lane may close, and never edits the gate.
#
# THE LEDGER IS PUBLISHED FIRST. The board is GENERATED from the machine lane
# ledger, so a board built from a ledger that under-reports the lanes that
# are running under-reports them too. The ledger publisher (bin/fm-lane-
# ledger-publish.py) owns that file: it writes the row for a lane the moment
# the lane spawns, so the ledger is true before the board is built from it.
# This script therefore asks the publisher to publish the ledger first, and
# then rebuilds the board from the ledger it published. A board can no longer
# be built from a ledger that says no lane is in flight while one is.
#
# --no-publish-ledger skips that step. The publisher uses it when it calls
# this script, so the two never call each other in a loop. The environment
# variable does the same job, so the publisher can call this script even when
# it ships an older copy of it.
#
# The board and the ledger are resolved with exactly the same order
# bin/fm-todo-gate.sh uses, so the board this script refreshes is always the very
# board the gate judges, and the ledger it compares against is always the very
# ledger the gate compares against. Two tools that disagree about which file
# they mean would make the gate judge a board nobody refreshed.
#
# Usage:
#   fm-board-refresh.sh [--repo <path>] [--out <dir>] [--ledger <path>]
#                       [--board <path>] [--stale-days N] [--check]
#
#   --check       report whether the board is current and change nothing.
#                 Exit 1 means stale.
#   --repo        the firstmate home that owns the backlog and the board.
#   --out         the directory the board is published into.
#   --ledger      the machine lane ledger the board is generated from.
#   --board       the published to-do board to compare and refresh.
#   --stale-days  how many days a lane may sit idle before the board calls it stale.
#   --no-publish-ledger
#                 do not publish the ledger first; build the board from the
#                 ledger that is already there.
#
# Environment:
#   FM_REPO        the firstmate home that owns the board
#   FM_OUT         the directory the board is published into
#   FM_TODO_BOARD  the published to-do board
#   FM_TODO_LEDGER the machine lane ledger
#   FM_ROOT_OVERRIDE  the tracked code root this script ships in
#
# Exit codes:
#   0 - the board is current (already current, or rebuilt to current)
#   1 - the board is stale and nothing was rebuilt (--check), or the rebuild
#       did not produce a board that matches the live ledger
#   2 - usage error
#   3 - cannot verify: the ledger, the board, or the builder is unavailable
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

REPO_ARG=""
OUT_ARG=""
LEDGER_ARG=""
BOARD_ARG=""
STALE_DAYS=3
CHECK_ONLY=0
PUBLISH_LEDGER=1
# The ledger publisher sets this when it calls this script, so the two never
# call each other in a loop. An older copy of this script simply ignores it.
if [ -n "${FM_LANE_LEDGER_PUBLISHED:-}" ]; then
  PUBLISH_LEDGER=0
fi

usage() {
  printf 'Usage: %s [--repo <path>] [--out <dir>] [--ledger <path>] [--board <path>] [--stale-days N] [--check] [--no-publish-ledger]\n' \
    "$(basename "$0")"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO_ARG=${2:-}; shift 2 ;;
    --out) OUT_ARG=${2:-}; shift 2 ;;
    --ledger) LEDGER_ARG=${2:-}; shift 2 ;;
    --board) BOARD_ARG=${2:-}; shift 2 ;;
    --stale-days) STALE_DAYS=${2:-}; shift 2 ;;
    --check) CHECK_ONLY=1; shift ;;
    --no-publish-ledger) PUBLISH_LEDGER=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

REPO="${REPO_ARG:-${FM_REPO:-$FM_ROOT}}"
[ -d "$REPO" ] || { printf 'board-refresh: FAIL the firstmate home does not exist: %s\n' "$REPO" >&2; exit 3; }

# resolve_board: the published to-do list, in the same order bin/fm-todo-gate.sh
# uses, so the refresh and the gate always mean the same file.
resolve_board() {
  local candidate
  if [ -n "$BOARD_ARG" ]; then printf '%s\n' "$BOARD_ARG"; return 0; fi
  if [ -n "${FM_TODO_BOARD:-}" ]; then printf '%s\n' "$FM_TODO_BOARD"; return 0; fi
  for candidate in "/root/agent-work/next-signpost/NEXT-BOARD.md" \
                   "$REPO/data/tracker/NEXT-BOARD.md" \
                   "$FM_ROOT/data/tracker/NEXT-BOARD.md" \
                   "/root/agent-work/deightonllm-firstmate/data/tracker/NEXT-BOARD.md" \
                   "/root/ops/NEXT-BOARD.md" \
                   "/home/hd2admin/ops/NEXT-BOARD.md"; do
    if [ -f "$candidate" ]; then printf '%s\n' "$candidate"; return 0; fi
  done
  printf '%s\n' "$REPO/data/tracker/NEXT-BOARD.md"
}

# resolve_ledger: the machine truth the to-do list is generated from, in the same
# order bin/fm-todo-gate.sh uses.
resolve_ledger() {
  local candidate
  if [ -n "$LEDGER_ARG" ]; then printf '%s\n' "$LEDGER_ARG"; return 0; fi
  if [ -n "${FM_TODO_LEDGER:-}" ]; then printf '%s\n' "$FM_TODO_LEDGER"; return 0; fi
  for candidate in "$REPO/ops/lane-ledger.tsv" \
                   "/root/agent-work/ops/lane-ledger.tsv" \
                   "/root/ops/lane-ledger.tsv" \
                   "/home/hd2admin/ops/lane-ledger.tsv" \
                   "/home/hd2admin/agent-work/core-distro-saas-clean/ops/lane-ledger.tsv"; do
    if [ -f "$candidate" ]; then printf '%s\n' "$candidate"; return 0; fi
  done
  printf '%s\n' "$REPO/ops/lane-ledger.tsv"
}

BOARD=$(resolve_board)

# Publish the machine lane ledger before the board is built from it. A lane
# that spawned and is running must have a row, or the board that is generated
# from this ledger will not carry it. The publisher owns that file; this
# script only asks for it to be published.
if [ "$PUBLISH_LEDGER" -eq 1 ] && [ "$CHECK_ONLY" -eq 0 ]; then
  LEDGER_PUBLISHER="$SCRIPT_DIR/fm-lane-ledger-publish.py"
  if [ ! -f "$LEDGER_PUBLISHER" ]; then
    LEDGER_PUBLISHER="$FM_ROOT/bin/fm-lane-ledger-publish.py"
  fi
  if [ -f "$LEDGER_PUBLISHER" ]; then
    publish_args=(--repo "$REPO" --no-refresh)
    [ -n "$LEDGER_ARG" ] && publish_args+=(--ledger "$LEDGER_ARG")
    [ -n "$BOARD_ARG" ] && publish_args+=(--board "$BOARD_ARG")
    ledger_output=$(python3 "$LEDGER_PUBLISHER" reconcile "${publish_args[@]}" 2>&1)
    ledger_rc=$?
    if [ $ledger_rc -ne 0 ]; then
      printf '%s\n' "$ledger_output" >&2
      printf 'board-refresh: FAIL the machine lane ledger could not be published (exit %s)\n' \
        "$ledger_rc" >&2
      printf '  a board built from a ledger that under-reports the running lanes would lie\n' >&2
      printf '  the published board was left untouched; the to-do gate still refuses it\n' >&2
      exit 1
    fi
    printf '%s\n' "$ledger_output" | sed -n 's/^lane-ledger-publish: /board-refresh: ledger /p'
  else
    printf 'board-refresh: FAIL the machine lane ledger publisher is unavailable: %s\n' \
      "$LEDGER_PUBLISHER" >&2
    printf '  without it a lane that spawns never reaches the board\n' >&2
    exit 3
  fi
fi

LEDGER=$(resolve_ledger)
OUT="${OUT_ARG:-${FM_OUT:-$(dirname "$BOARD")}}"

if [ ! -f "$LEDGER" ]; then
  printf 'board-refresh: FAIL the machine lane ledger is missing: %s\n' "$LEDGER" >&2
  printf '  the to-do board is generated from that ledger; without it there is no machine truth\n' >&2
  exit 3
fi

BUILDER="$SCRIPT_DIR/fm-next-board.sh"
if [ ! -f "$BUILDER" ]; then
  printf 'board-refresh: FAIL the board builder is unavailable: %s\n' "$BUILDER" >&2
  exit 3
fi

# ledger_digest: the digest of the live ledger bytes, in the same shape the board
# records and the gate compares.
ledger_digest() {
  local sum
  sum=$(sha256sum -- "$LEDGER" 2>/dev/null | cut -d' ' -f1) || return 1
  [ -n "$sum" ] || return 1
  printf 'sha256:%s\n' "$sum"
}

# board_digest: the digest the published board says it was built from.
board_digest() {
  grep -m1 '^\*\*Ledger digest:\*\* ' "$BOARD" 2>/dev/null \
    | sed -e 's/^\*\*Ledger digest:\*\*[[:space:]]*//' | tr -d '[:space:]'
}

LIVE_DIGEST=$(ledger_digest) || {
  printf 'board-refresh: FAIL could not hash the machine lane ledger: %s\n' "$LEDGER" >&2
  exit 3
}

PREVIOUS_DIGEST=$(board_digest)
[ -n "$PREVIOUS_DIGEST" ] || PREVIOUS_DIGEST="none"

printf 'board-refresh: previous digest %s\n' "$PREVIOUS_DIGEST"

if [ "$PREVIOUS_DIGEST" = "$LIVE_DIGEST" ]; then
  printf 'board-refresh: new digest %s\n' "$LIVE_DIGEST"
  printf 'board-refresh: the board is current with the live ledger: %s\n' "$BOARD"
  exit 0
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  printf 'board-refresh: new digest %s\n' "$LIVE_DIGEST"
  printf 'board-refresh: STALE the board records %s and the live ledger is %s\n' \
    "$PREVIOUS_DIGEST" "$LIVE_DIGEST" >&2
  printf '  refresh it with: %s --repo %s --out %s\n' "$BUILDER" "$REPO" "$OUT" >&2
  exit 1
fi

# Rebuild from the live ledger. The builder is the tracked owner of board
# generation: it builds into a temporary directory and publishes only a board
# that passed its checks, so a failed build never replaces a good board.
build_output=$(bash "$BUILDER" --repo "$REPO" --out "$OUT" --ledger "$LEDGER" --stale-days "$STALE_DAYS" 2>&1)
build_rc=$?
if [ "$build_rc" -ne 0 ]; then
  printf '%s\n' "$build_output" >&2
  printf 'board-refresh: FAIL the board builder exited %s\n' "$build_rc" >&2
  printf '  the published board was left untouched; the to-do gate still refuses it\n' >&2
  exit 1
fi

NEW_DIGEST=$(board_digest)
printf 'board-refresh: new digest %s\n' "${NEW_DIGEST:-none}"

if [ "$NEW_DIGEST" != "$LIVE_DIGEST" ]; then
  printf 'board-refresh: FAIL the rebuilt board does not match the live ledger\n' >&2
  printf '  board says: %s\n' "${NEW_DIGEST:-none}" >&2
  printf '  ledger is: %s\n' "$LIVE_DIGEST" >&2
  exit 1
fi

printf 'board-refresh: rebuilt %s from %s\n' "$BOARD" "$LEDGER"
exit 0
