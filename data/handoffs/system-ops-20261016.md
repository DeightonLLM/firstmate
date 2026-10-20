# Firstmate infrastructure queue - system-ops

Owner: system-ops. Tracking task: #41. Grouping: data/2026-10-15/todo-grouping-20261016.md

Scope: this repository and its supervisors, harnesses, dispatch, fleet visibility, workflow
reliability. One isolated worktree per task. Do not modify client repositories, client data,
production services, host configuration, or live runtimes.

## Already landed today, do not redo
- `bff64980` security P0 - inbound reply text treated as data, never instruction (21 tests pass)
- `406d88a8` watcher escalation loop - guard the wake append so an unchanged wedge cannot
  re-escalate forever
- `bfbb0caa` watcher dead-pane cleanup - clear per-window tracking state when a pane is gone

## #38 Pre-existing FM_HOME unbound-variable bug  [do this first - it is blocking test signal]
`bin/fm-classify-lib.sh:361` in `crew_live_pane_working` throws `FM_HOME: unbound variable`. It
fails one test in `tests/fm-watch-triage.test.sh` ("stale working: status-log classed absorbable").
This is PRE-EXISTING and unrelated to the three commits above.
- Reproduce against a clean baseline worktree; stashing `bin/fm-classify-lib.sh` and
  `bin/fm-crew-visibility.sh` makes the suite pass 0 failures, which proves the fault is theirs.
- Both files currently hold UNCOMMITTED work. Do not discard it. Back up before touching.

## #26 Regenerate stale BOARD.md from live state
BOARD.md no longer matches reality. Regenerate from live fleet state, not from memory.

## #25 Enforced reap on completion with a durable test
A finished lane must be reaped in the same action, and a durable test must prove it.

## #34 Stop depending on pane cwd when collecting worker output
Collecting worker output must not depend on the pane's current directory.

## #4 Fleet view and warehouse
- **#5** Remove 5 duplicate skill-name startup warnings
- **#31** Repair secondmate addressing so work can be routed by name
- **#30** Route by scope ownership, not by who is free
- **#21** Durable config + docs for the 2026-10-16 decisions

## Contract
Each item lands with evidence or reports a blocker with an explicit `[key=<slug>]`.
- Never weaken a guard or delete a check to make a test pass.
- Never use a broad process-name kill. One named pane, one verified decision, one action.
- Never discard unlanded work.
