#!/usr/bin/env bash
# fm-subagent-cap.sh — bounded path-compatibility wrapper.
#
# m27-worker-{1..5}, m27-worker-r{2,3,4}-{1..5}, and cap-repair-m27-worker-1
# briefs were authored against a path that pre-dated the FIRSTMATE_OP v1
# canonical source-of-truth at /root/lib/subagent-cap/cap.sh. This wrapper
# translates the brief-style command names onto the canonical module so
# those lanes can run without script edits.
#
# Mapping:
#   count-open   -> /root/lib/subagent-cap/cap.sh count-subagent
#   count-total  -> /root/lib/subagent-cap/cap.sh count-total
#   can-spawn    -> /root/lib/subagent-cap/cap.sh can-spawn [WS]
#   assert       -> /root/lib/subagent-cap/cap.sh assert [WS]
#   reap         -> /root/lib/subagent-cap/cap.sh reap [WS]
#   constants    -> /root/lib/subagent-cap/cap.sh constants
#
# The canonical module is the single source of truth. Any new cap operation
# MUST be added there first; this wrapper only adapts names.

set -euo pipefail

CANONICAL=/root/lib/subagent-cap/cap.sh

if [ ! -r "$CANONICAL" ]; then
  printf 'fm-subagent-cap: canonical module missing at %s\n' "$CANONICAL" >&2
  exit 3
fi

cmd="${1:-}"
shift || true

case "$cmd" in
  count-open|count-subagent)
    exec "$CANONICAL" count-subagent "$@"
    ;;
  count-total)
    exec "$CANONICAL" count-total "$@"
    ;;
  can-spawn)
    "$CANONICAL" can-spawn "$@"
    exit $?
    ;;
  assert)
    "$CANONICAL" assert "$@"
    exit $?
    ;;
  reap)
    exec "$CANONICAL" reap "$@"
    ;;
  constants)
    exec "$CANONICAL" constants
    ;;
  -h|--help|help|"")
    cat <<USAGE
usage: fm-subagent-cap.sh <command> [WORKSPACE]

commands:
  count-open    Print the number of open subagent panes (excludes Codex).
  count-total   Print the number of open panes including Codex.
  can-spawn     Exit 0 if a new subagent may be spawned, 64 otherwise.
  assert        Exit 0 if can spawn, 64 with ERR_SUBAGENT_CAP_REACHED otherwise.
  reap          Close stale done/idle panes (never working/blocked).
  constants     Print the canonical constants.

Canonical source: $CANONICAL
USAGE
    exit 0
    ;;
  *)
    printf 'fm-subagent-cap: unknown command %s\n' "$cmd" >&2
    exit 2
    ;;
esac