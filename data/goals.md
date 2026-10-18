# Home Goals

This file tracks durable home-level outcomes; `tasks-axi` remains the source of truth for ticket status and ownership.
Use `goal:<slug>` on each linked ticket so the goal can be audited without adding a second task system.

## visible-parallel-firstmate

- Status: active.
- Outcome: Brandon can see which agents are actually working, steer each worker, inspect live ticket progress, and expand parallel work up to independent ticket supply and safe provider quota.
- Scope: goals and ticket links, quota-aware dispatch, Firstmate supervision, visible Herdr panes, Pi live todo updates, bounded M2.7 subagents, and a reviewable fleet board.
- Parallelism: scale toward the captain's stated ceiling of 25 workers across at most five disjoint streams; never start a worker without a ready ticket and one clear worktree owner.
- Safety: preserve Firstmate's single-supervisor-per-home model, current project delivery contracts, all unlanded work, and the captain's no-publish/no-merge boundaries.
- Acceptance: every active lane links to a ready or in-flight `tasks-axi` ticket; live views show task, project, pane, harness/model, and current worker state; steering uses the task's guarded Firstmate channel; quota is checked before dispatch and does not rely on an unmeasurable provider window.
- Acceptance: each Pi worker's pane displays its full checklist after every todo update and identifies its current step; the Firstmate backlog remains the durable ticket record.
- Acceptance: nontrivial Pi lanes use a bounded M2.7 subagent for independent progress or review when quota runway covers the task; children do not recursively delegate unless explicitly asked.
- Current tickets: `calm-worker-version-consistency`, `brief-compaction-preserve`, `context-continuity-audit`, `fleet-view-live-actions`, `parallel-dispatch-audit`, `herdr-pane-board-context`, `elevate-mobile-audit`, `tool-auto-update`, and `quota-aware-queue-pump`.
