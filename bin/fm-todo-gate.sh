#!/usr/bin/env bash
# fm-todo-gate.sh - fail closed when the to-do list is stale.
#
# The Captain's to-do list is GENERATED from the machine lane ledger
# (ops/lane-ledger.tsv) and records that ledger's digest. A lane may not close
# while the list is stale: an instrument that lies is worse than no instrument.
#
# This gate is a thin wrapper around the drift checker (ops/bin/fm-todo-sync.sh),
# which consumes the same ledger and reports the drift between the ledger, the
# to-do board and the claims board.
#
# Contract:
#   * The drift checker is located with --sync-gate / $FM_TODO_SYNC_GATE first,
#     then in this order:
#         /root/ops/bin/fm-todo-sync.sh
#         /home/hd2admin/ops/bin/fm-todo-sync.sh
#         /root/agent-work/ops/bin/fm-todo-sync.sh
#         <repo>/ops/bin/fm-todo-sync.sh
#   * The checker is expected to exit 0 when there is no drift and non-zero when
#     there is, with a human-readable reason on stdout or stderr. Any non-zero
#     is drift.
#   * The checker is handed the very board and the very ledger this gate judged
#     (--board, --ledger, and --ops-dir when the claims board sits next to the
#     ledger), so the two can never disagree about what was checked. They are
#     exported as FM_TODO_BOARD and FM_TODO_LEDGER as well.
#   * The gate also compares the digest the board records against the digest of
#     the ledger bytes. A board that was not regenerated after the ledger moved
#     is stale, and no checker can make that board current.
#
# Exit codes:
#   0 - the to-do list agrees with the machine ledger
#   1 - drift: the to-do list is stale, or the checker reported drift
#   2 - usage error
#   3 - cannot verify: the drift checker is unavailable, or the ledger is missing
#   4 - nothing to judge: no to-do list has been published yet
#
# Usage:
#   fm-todo-gate.sh [--sync-gate <path>] [--board <path>] [--ledger <path>] [<artifact>]
#
# The trailing artifact path is accepted and ignored, so this gate can be run
# exactly like the other closure preconditions.
#
# Environment:
#   FM_TODO_SYNC_GATE   explicit drift checker path
#   FM_TODO_BOARD        explicit to-do board path
#   FM_TODO_LEDGER       explicit lane ledger path
#   FM_REPO              the firstmate home that owns the board
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REPO="${FM_REPO:-$FM_ROOT}"

SYNC_GATE_ARG=""
BOARD_ARG=""
LEDGER_ARG=""

usage() {
  printf 'Usage: %s [--sync-gate <path>] [--board <path>] [--ledger <path>] [<artifact>]\n' "$(basename "$0")"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --sync-gate)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      SYNC_GATE_ARG="$2"
      shift 2
      ;;
    --board)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      BOARD_ARG="$2"
      shift 2
      ;;
    --ledger)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      LEDGER_ARG="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

# resolve_board: the published to-do list. An explicit path is honoured as
# given, so a caller that points at a board the lane owns judges that board.
resolve_board() {
  if [ -n "$BOARD_ARG" ]; then
    printf '%s\n' "$BOARD_ARG"
    return 0
  fi
  if [ -n "${FM_TODO_BOARD:-}" ]; then
    printf '%s\n' "$FM_TODO_BOARD"
    return 0
  fi
  local candidate
  for candidate in "/root/agent-work/next-signpost/NEXT-BOARD.md" \
                   "$REPO/data/tracker/NEXT-BOARD.md" \
                   "$FM_ROOT/data/tracker/NEXT-BOARD.md" \
                   "/root/agent-work/deightonllm-firstmate/data/tracker/NEXT-BOARD.md"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '%s\n' "$REPO/data/tracker/NEXT-BOARD.md"
}

# resolve_ledger: the machine truth the to-do list is generated from.
resolve_ledger() {
  if [ -n "$LEDGER_ARG" ]; then
    printf '%s\n' "$LEDGER_ARG"
    return 0
  fi
  if [ -n "${FM_TODO_LEDGER:-}" ]; then
    printf '%s\n' "$FM_TODO_LEDGER"
    return 0
  fi
  local candidate
  for candidate in "$REPO/ops/lane-ledger.tsv" \
                   "/root/agent-work/ops/lane-ledger.tsv" \
                   "/root/ops/lane-ledger.tsv"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '%s\n' "$REPO/ops/lane-ledger.tsv"
}

# resolve_checker: the drift checker. An explicit path is honoured as given: if
# it does not exist the caller must see that it is unavailable, because a missing
# checker must never silently become a missing check.
resolve_checker() {
  if [ -n "$SYNC_GATE_ARG" ]; then
    printf '%s\n' "$SYNC_GATE_ARG"
    return 0
  fi
  if [ -n "${FM_TODO_SYNC_GATE:-}" ]; then
    printf '%s\n' "$FM_TODO_SYNC_GATE"
    return 0
  fi
  local candidate
  for candidate in /root/ops/bin/fm-todo-sync.sh \
                   /home/hd2admin/ops/bin/fm-todo-sync.sh \
                   /root/agent-work/ops/bin/fm-todo-sync.sh \
                   "$FM_ROOT/ops/bin/fm-todo-sync.sh"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 0
}

BOARD=$(resolve_board)
LEDGER=$(resolve_ledger)
CHECKER=$(resolve_checker)

# Nothing published means nothing to judge. It is reported loudly, because a
# missing publication is how the rot starts - but a list that was never
# published is not the same fault as a list that was published and went stale.
if [ ! -f "$BOARD" ]; then
  printf 'TO-DO GATE: nothing to judge - no to-do list is published at %s\n' "$BOARD" >&2
  printf '  publish it with: python3 bin/build-next-board.py --repo <repo> --out <out>\n' >&2
  exit 4
fi

if [ -z "$CHECKER" ] || [ ! -f "$CHECKER" ]; then
  printf 'VIOLATION: the to-do drift checker is unavailable: %s\n' "${CHECKER:-not resolved}" >&2
  printf '  looked in: /root/ops/bin/fm-todo-sync.sh /home/hd2admin/ops/bin/fm-todo-sync.sh /root/agent-work/ops/bin/fm-todo-sync.sh %s\n' \
    "$FM_ROOT/ops/bin/fm-todo-sync.sh" >&2
  exit 3
fi

if [ ! -f "$LEDGER" ]; then
  printf 'VIOLATION: the machine lane ledger is missing: %s\n' "$LEDGER" >&2
  printf '  the to-do list is generated from that ledger; without it there is no machine truth\n' >&2
  exit 3
fi

# The checker has the last word on drift. It is handed the very board and the
# very ledger this gate judged, so the two can never disagree about what was
# checked, and it is also handed them in the environment for a checker that
# prefers to read them from there.
ledger_dir=$(dirname "$LEDGER")
checker_args=()
if [ -f "$ledger_dir/LANE-CLAIMS.md" ]; then
  checker_args+=("--ops-dir" "$ledger_dir")
fi
checker_args+=("--board" "$BOARD" "--ledger" "$LEDGER")

checker_output=$(FM_TODO_BOARD="$BOARD" FM_TODO_LEDGER="$LEDGER" \
  "$CHECKER" "${checker_args[@]}" 2>&1)
checker_status=$?
if [ -n "$checker_output" ]; then
  printf '%s\n' "$checker_output"
fi
if [ "$checker_status" -ne 0 ]; then
  printf 'VIOLATION: the to-do drift checker reported drift: %s\n' \
    "${checker_output:-no reason given}" >&2
  exit "$checker_status"
fi

# The board records the digest of the ledger it was generated from. A board
# that does not match the ledger on disk was generated from a machine state
# that has moved on: it is stale, and no checker can make it current.
board_digest=$(grep -m1 '^\*\*Ledger digest:\*\* ' "$BOARD" 2>/dev/null \
  | sed -e 's/^\*\*Ledger digest:\*\*[[:space:]]*//' | tr -d '[:space:]')
ledger_digest="sha256:$(sha256sum "$LEDGER" 2>/dev/null | cut -d' ' -f1)"

if [ -z "$board_digest" ]; then
  printf 'VIOLATION: the to-do board records no ledger digest: %s\n' "$BOARD" >&2
  printf '  regenerate it so the board says which machine state it was built from\n' >&2
  exit 3
fi

if [ "$board_digest" != "$ledger_digest" ]; then
  printf 'VIOLATION: the to-do list is stale - the board records %s, the ledger is %s\n' \
    "$board_digest" "$ledger_digest" >&2
  printf '  regenerate it: python3 bin/build-next-board.py --repo <repo> --out <out>\n' >&2
  exit 1
fi

printf 'TO-DO GATE: the to-do list is current (board: %s, ledger: %s, %s)\n' \
  "$BOARD" "$LEDGER" "$ledger_digest"
exit 0
