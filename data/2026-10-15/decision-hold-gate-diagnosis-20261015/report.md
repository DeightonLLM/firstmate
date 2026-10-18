# Decision-hold completion gate diagnosis

## Scope and method

Read-only inspection of `bin/fm-decision-hold.sh`, `bin/fm-brief.sh`, `.agents/skills/decision-hold-lifecycle/SKILL.md`, and `docs/decision-hold-lifecycle.md`. Used file reads and code search only; did not run tasks-axi or modify project code/config. The account-scoped `/root/agent-work/deightonllm-firstmate/CONTROLLER_STATE.md` baseline pointer was absent (read returned `ENOENT`), and lean-ctx denied a read of the external account-scoped report destination; native read confirmed other supplied baseline files. Those access constraints do not prevent this scoped source inspection.

## Findings: metadata attestation versus restricted write scope

The exact conflict established from the available source is between **the required completion attestation's write to the originating task's `state/<id>.meta`** and **a task authorization/scope that permits only three files and excludes that metadata**. These cannot both be satisfied by the worker when the metadata file is outside the authorized set.

Evidence on the gate side:

- `bin/fm-decision-hold.sh`, `command_complete()`, lines 277–283, sets `meta="$STATE/$origin.meta"` and records whether it exists.
- Lines 320–323 perform the write: when task metadata exists, the function appends `decisions_reviewed=1` and `decision_keys=...` to that metadata file. This includes an empty inventory (`--none`) when the attestation is not already present.
- The script header, lines 7–10, describes this as recording the completion attestation in originating-task metadata.
- The semantic requirement is explicit in `.agents/skills/decision-hold-lifecycle/SKILL.md`, “Policy” paragraph 3 and “Operating sequence” step 4: run `complete` with all unresolved keys, or `--none` when there are none.

Evidence on the brief side:

- `bin/fm-brief.sh`, lines 513–517, requires the scout report and says to follow `decision-hold-lifecycle` and pass its shared completion gate before reporting done.
- The generic scout write boundary is `bin/fm-brief.sh`, lines 328–335: only the report and status file may be written outside the worktree. This generic provision alone does **not** establish a three-file restriction inside a task; the reported “authorized three-file scope” is task-specific scope not present in the source files inspected here.

**Brief contract or gate?** The attestation write is part of the gate implementation, and the completion mandate is part of the brief contract. The three-file authorization is a narrower task-specific brief constraint. Where it excludes `state/<id>.meta`, the contradiction is in the combined authorization contract: the brief demands an operation whose required side effect it does not authorize. The gate's metadata write is directly evidenced above; I could not locate or inspect the separate code that enforces the reported “three-file scope,” so I cannot name its file, function, or line numbers. Those exact scope-check coordinates cannot be responsibly supplied from this worktree's evidence.

A brief that authorizes only three specific files and excludes task metadata is structurally unable to satisfy this gate **as implemented for a live task with metadata**: `command_complete()` appends to that metadata at lines 320–323. The report that one worker was blocked for precisely that reason is consistent with the source, but the worker's actual scope definition/guard was not available here to independently verify.

## Smallest non-weakening correction

For the reported three-file case, the smallest correction is to the task-specific brief's authorized file set: explicitly include the originating task metadata file as an authorized gate side-effect (or otherwise authorize the gate operation that writes it). This preserves all semantic decision inventory and hold checks; it merely authorizes the gate's existing required write. I cannot give the exact edit location without the three-file brief or the guard implementation. Changing the gate to skip attestation or silently bypass scope would weaken the gate and is not recommended.

## PLAN ONLY / no-state-change case

This is a distinct contract defect if the task truly authorizes no state changes. The lifecycle skill unconditionally requires `complete` before completion (`.agents/skills/decision-hold-lifecycle/SKILL.md`, Policy paragraph 3 and Operating sequence step 4), while `command_complete()` writes task metadata at `bin/fm-decision-hold.sh:320–323` whenever metadata exists and the attestation needs recording. `--none` means “no unresolved captain decision”; it does not mean “perform no write.” Thus a PLAN ONLY task that forbids all state changes can be blocked by the same gate, even with no decisions to register. The skill's `--none` clause and script's write branch support this conclusion; I did not inspect the specific `skill-collision-audit` brief or its live metadata, so cannot verify whether its actual task had a metadata file or whether the gate was invoked. The smallest non-weakening remedy is to distinguish semantic inventory from its durable attestation and authorize that specific metadata write for report completion; alternatively provide a durable, authorized attestation location that preserves the same inventory verification. Do not waive the semantic inventory or unresolved-hold checks.

## Exact limitation on requested line references

I found the producer of the attestation requirement and the metadata write, but not the “scope check that rejects it.” Repository search did not find the reported rejection text or an implementation matching that scope check. Therefore its exact file/function/line references—and whether it compares the same canonical path as `command_complete()`—remain undetermined. The controller state pointer was also unavailable, so the cited prior worker outcomes were treated as supplied observations, not independently verified artifacts.

## Completion-gate limitation

Per the required lifecycle procedure, this read-only task cannot run `complete`: doing so would write task metadata (and potentially status), contradicting its explicit read-only boundary. No completion attestation was run. This report documents that blocker rather than making an unauthorized state change.
