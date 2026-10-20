# Agent To-Do naming contract

Status: ACTIVE.
Captain renewed this requirement on 2026-10-18.
This file owns the naming format for the native task list, lane labels and board entries.

## Required visible prefix

Every task subject starts with `[<harness>·<model> @<execution-host> | <owner-role>]`.
Use the actual harness and exact model or an unambiguous abbreviation documented alongside its exact identifier.
Include configured effort only when measured; use `effort=unknown` if relevant but unavailable.
The host is where the owner runs, not the remote target being investigated.
End each subject with the concrete state and dependency, such as `waiting on HD2 evidence` or `blocked on Captain approval`.

Examples:

- `[pi·GPT6.1-sol @brandon | controller] Reconcile ticket evidence — waiting on HD2`
- `[mcode·M2.7-Highspeed @brandon | worker] Implement scoped fixture — queued, depends on access`
- `[mcode·M3.1 @brandon | lead] Reconcile worker results — running`

A controller-owned blocked item names the controller, not a hypothetical future worker.
Never label a completed run or an unassigned task as a running worker.
Requested model, actual execution model, and verified execution model are different facts.
Record the exact requested identifier and execution receipt in the task description or evidence record.
If the actual model or Highspeed tier is not measurable, label it requested/unverified rather than asserting it ran.
Do not confuse Highspeed with reasoning effort.

## Lane keys and dispatch

Use `<harness>-<model>-<host>-<task>` for lane keys, lowercase and without spaces.
Use readable model abbreviations such as `m27-highspeed` and `m31`; record exact catalog identifiers in the dispatch evidence.
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
