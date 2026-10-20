# WORK ORDER — Watcher heartbeat: reconcile Brandon branch with controller runtime fixes → PR
Issued: 2026-10-04 02:45Z · Owner: hetz @ brandon (herdr w2) · Priority: high · Lane: B-routed, 1 worker + checker

## Context
Controller branch `fm/controller-watcher-heartbeat-recovery` (commit 051cd56, Brandon) contains the TDD watcher fixes. Overnight the controller applied additional runtime fixes directly (documented, backups kept):
1. bin/backends/herdr.sh: every herdr CLI call bounded (`timeout -k 2 ${FM_BACKEND_HERDR_CLI_TIMEOUT:-10}`, gtimeout fallback)
2. bin/fm-watch.sh: dead-window decay (state/.win-dead-*, FM_DEAD_WINDOW_TTL=300) + amortized bulk `herdr pane list --json` map (FM_WIN_STATUS_MAP) + event-FIFO reads -t bounded + reader KILL-reap + per-window/phase beat touches
3. bin/fm-watch.sh instrumentation (state/.watch-cycle.log, .watch-phase.log if present) is TEMPORARY — strip in the PR

## Task (Brandon lane, TDD red-green-refactor)
1. Fetch controller state (route: this comms dir is source of truth; controller snapshot of changed files available on request).
2. Reconcile 051cd56 with the five runtime fixes above — single coherent change set on the branch.
3. red→green proof: watcher cycle completes with beats <300s under a simulated 90+ dead-window fleet; eventwait smoke suite green.
4. Strip temporary instrumentation; keep bounded-fix code + tests.
5. no-mistakes pipeline → PR. DO NOT MERGE (captain merge authority).

## Constraints
No spends, no DNS/registrar, no live deploys, backups before edits, upstream citations (oh-my-openagent poller pattern) in the PR body.
Report: BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-04-watcher-pr-reconcile-report.md + PR URL when checks green.
