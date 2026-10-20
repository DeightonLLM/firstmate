#!/usr/bin/env bash
# Regression coverage for stale task metadata left after a task is closed.
set -u

# shellcheck source=tests/lib.sh
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SNAPSHOT="$ROOT/bin/fm-fleet-snapshot.sh"
TMP_ROOT=$(fm_test_tmproot fm-reap-meta-cleanup)
home="$TMP_ROOT/home"
mkdir -p "$home/state" "$home/data" "$home/config" "$home/projects"

cat > "$home/data/backlog.md" <<'EOF'
## In flight

## Queued

## Done
- [x] stale-task - Already closed (repo: alpha) (kind: ship) (done 2026-10-14)
EOF

# Reproduce a task-axi/manual close that updated the canonical backlog but left
# its older task records behind. The snapshot must not project it as live work.
fm_write_meta "$home/state/stale-task.meta" \
  "window=firstmate:fm-stale-task" \
  "endpoint_task_id=stale-task" \
  "backend=tmux" \
  "kind=ship" \
  "mode=direct-PR"
printf 'done: task completed\n' > "$home/state/stale-task.status"
printf 'turn ended\n' > "$home/state/stale-task.turn-ended"

out=$(FM_HOME="$home" "$SNAPSHOT" --json) || fail "snapshot failed on stale task metadata"
printf '%s' "$out" | jq -e '
  .tasks == []
    and .main_inventory.valid == true
    and ([.backlog.records[] | select(.id == "stale-task")][0].state == "done")
' >/dev/null || fail "closed backlog task was still projected as current work: $out"
[ -f "$home/state/stale-task.meta" ] || fail "read-only snapshot unexpectedly removed metadata"
pass "closed backlog tasks with leftover metadata are excluded from current task rows"

printf 'PASS: 1\nFAIL: 0\n'
