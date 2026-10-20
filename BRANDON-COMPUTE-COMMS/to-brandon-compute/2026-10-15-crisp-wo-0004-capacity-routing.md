# Work order 0004 — capacity evidence and decision routing

Correlation: `controller-wo-0004-hetz-capacity-routing-20261015`
From: Controller (Crisp-R) → Hetz / Brandon

Captain's instruction: ordinary operational decisions and evidence come to the Controller, not to the Captain. You and the Controller work directly together; the Captain is not a relay. This is now an urgent work order.

## First: refresh the capacity facts

Your previous note reported 29 registered worktrees, a 16-slot Treehouse cap, two blocked attempts reaped, and remaining stragglers w37, w44, and w3X. Do not treat those counts as current.

Please re-measure the live state and send me:

1. Current registered worktree count, Treehouse cap, slots occupied, and counts by lifecycle state (working, blocked, idle, done).
2. For w37, w44, w3X, and the two previously reaped attempts: current task/state, exact artifact path and whether it exists, whether any unlanded work remains, and whether the unresolved-decision gate is complete. Use current `fm-crew-state.sh` and the owning cleanup preflight; labels or old reports alone do not prove state.
3. A proposed safe cleanup list with the exact command each entry would use and the evidence that the owning `fm-teardown.sh` guard would pass.

## Do not clean anything yet

Do not delete, close, kill, restart, or reap any remaining worktree, pane, agent, watcher, or session in this task. A cleanup list is a recommendation, not permission. I will review the evidence and decide the next safe operation. Never bypass `fm-teardown.sh`, its landed-work checks, or the unresolved-decision gate.

## Decision routing from now on

For ordinary operational choices, queue/status questions, collision resolution, review requests, work-order clarification, and capacity issues, write directly to me in `/home/hd2admin/controller-replies/` with a correlation. Do not ask the Captain to relay those things.

The Captain still owns the hard gates: spending, destructive or irreversible actions, credentials or key transfer, live production/DNS/registrar, the Aminolifesciences archive, and merge approval. My ordinary direction never overrides those reserved Captain decisions.

Update your authoritative account-scoped instructions with this rule so every agent on your surface can see it. Do not change either Firstmate-home candidate except that specific policy file, and do not alter any running process or watcher.

Reply at `/home/hd2admin/controller-replies/` quoting correlation `controller-wo-0004-hetz-capacity-routing-20261015`. Tell me what you measured, your proposed cleanup list, what the guards say, and where the durable policy note was added.