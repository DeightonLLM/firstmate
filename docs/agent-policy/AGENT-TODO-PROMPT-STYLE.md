# Agent To-Do naming contract

Status: ACTIVE.
Captain renewed this requirement on 2026-10-18.
This file owns the naming format for the native task list, lane labels and board entries.

## Required visible prefix

Every task subject starts with `[<harness>·<ModelAbbrev> <effort> @<Host>]`.
Use the actual harness and a documented short alias for the exact model identifier.
Include the measured effort token, or the literal `unknown` when the effort is not measurable.
The host is where the owner runs, not the remote target being investigated.
State the owner role in the task text, not in the prefix.
End each subject with the concrete state and dependency, such as `waiting on HD2 evidence` or `blocked on Captain approval`.

Examples:

- `[pi·luna6 m @brandon] Reconcile ticket evidence - waiting on HD2`
- `[mcode·m2.7h m @brandon] Implement scoped fixture - queued, depends on access`
- `[mcode·m3.1 m @brandon] Reconcile worker results - running`

The canonical format, its model alias table and the machine checker live in `docs/todo-prefix-canonical-format.md` and `bin/fm-todo-prefix-check.sh`.

A controller-owned blocked item names the controller, not a hypothetical future worker.
Never label a completed run or an unassigned task as a running worker.
Requested model, actual execution model, and verified execution model are different facts.
Record the exact requested identifier and execution receipt in the task description or evidence record.
If the actual model or Highspeed tier is not measurable, label it requested/unverified rather than asserting it ran.
Do not confuse Highspeed with reasoning effort.

## Lane keys and dispatch

Use `<harness>-<model>-<host>-<task>` for lane keys, lowercase and without spaces.
Use the documented model aliases from `docs/todo-prefix-canonical-format.md`, such as `m3.1f` and `m3.1`; record exact catalog identifiers in the dispatch evidence.
A retired alias such as `m2.7h` resolves for history only and is refused for a new lane key.
Captain permits MCode MiniMax M2.7 Highspeed asynchronous workers directly, or a MCode M3.1 lead coordinating M2.7 workers and reviewing within the same run.
Do not infer an exact catalog identifier, silently substitute a model, or invent a persistent second mate from a one-shot lead.
Every worker receives this naming contract before work starts.
The coordinator checks visible labels before counting the worker as started and corrects missing harness/model/host fields before accepting a deliverable.
Receipt and observable execution are required; a label or sent instruction alone is not proof of running work.

## Live list and acceptance

Use the harness-native To-Do extension, not a filesystem replacement.
For non-trivial dispatch, represent preflight, scoped discovery, bounded work/evidence, validation and closeout with dependency-aware checkable items before dispatch.
Exactly one item is in_progress; running, queued and blocked distinctions belong in each item's text.
Keep only active or genuinely blocked work visible.
Remove finished, superseded and handed-off items immediately after recording their durable outcome.
Do not duplicate an approval blocker and its dependent action when a single item can express both clearly.
Before closeout, list the native tracker and check every remaining subject for harness, model, execution host, owner, state and named dependency.
Missing or vague fields require correction, not a compliance claim.
Other instructions should point here rather than maintain competing naming examples.
