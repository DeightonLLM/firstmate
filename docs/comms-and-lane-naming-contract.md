# Comms and lane-naming contract

Owner: this file. Both surfaces mirror it; if a mirror disagrees with a copy, the copy that disagrees is wrong.
Status: 2026-10-17. Unlanded in this repository; mirrors confirm receipt by returning the exact sha256.

## 1. What "delivered" means

Four separate facts. Never collapse them:

| Fact | How it is proven |
|---|---|
| Published | the file exists in the outbox directory |
| Transmitted | the local send helper printed success for each target path |
| Received | the recipient can see the file in their own inbound directory |
| Accepted | the recipient replied, referencing the correlation id |

A notification is not delivery. A "delivered" report is not receipt. If you cannot see the file, it was not delivered.

## 2. Delivery paths on this surface

- Outbound: write to `BRANDON-COMPUTE-COMMS/from-brandon-compute/` in the active firstmate home, then run `bash bin/fm-to-controller.sh <file>`. The helper writes both the local mirror and the shared exchange directory and records the content hash.
- Publishing by writing the file alone is a known failure mode. Writing and sending are one atomic step by design.
- Inbound: the recipient publishes into this home's `BRANDON-COMPUTE-COMMS/to-brandon-compute/`. A poll reports filenames and digests only, never content.
- A file placed in a SUBDIRECTORY of the outbox is not exempt from delivery guards and is not the documented path. Use the outbox root.
- Every note carries a `Correlation:` line and ends with a `VERDICT:` line stating the measured outcome.

## 3. Reading

- A reply the sender claims to have sent is verified by reading it from the inbound directory, never from the sender's description.
- If a path is unreadable, that is a reader or access fact, not proof the file does not exist. Report the exact path and the exact refusal.
- Read the inbound queue before asking for anything that may already have been delivered.

## 4. Lane naming

The async panel renders only the lane key. An unnamed lane is invisible to the operator, which is the defect this rule prevents.

- Lane key: `<model>-<surface>-<task>`, lowercase, no spaces. Example: `m2.7-brandon-widget-sizing`.
- Model aliases: `m2.7h`, `m2.7`, `m3.1`, `m3.1f`, `luna6`, `glm5.3f`, `gem38f`, `pi`.
  `m2.7h` is MiniMax M2.7 Highspeed, the tier live worker lanes actually run.
- Surface aliases: `brandon`, `hd2`, `dubz`, `evps`, `firstmate`.
- To-Do board line: `[<model> @ <surface>[/<pane>}] <action> — <state>`.
- Dispatch async lanes as a workflow whose per-child key is the lane key, so the panel shows the name. A direct single-child dispatch shows only the agent kind and is not acceptable for work the operator must watch.
- The operator's durable registry is `data/async-lanes.tsv`: run id, lane key, model, surface, task, state, output. Write the row at dispatch, update it at every phase change, and never delete a row while the run exists.
- `bin/fm-lane-naming-check.sh` validates lane keys, board lines, and the registry file. It is not yet wired into a launcher, so it reports rather than blocks. Treat that as known-open, not as enforcement.

## 5. Model visibility and cost

- Every lane the operator can see names its model. Never report a lane without model, name and state.
- Re-measure quota at intake and state the window plainly. Never claim capacity that was not measured, never purchase quota, and never edit the operator's own settings to change a model.
- Routing is cost-first while Codex is exhausted: routine bounded work on the cheapest adequate model, escalated only when the reasoning class genuinely requires it.

## 6. Surface parity

- A change to shared instructions is not real until every surface that loads them carries the same bytes. Publishing on one surface and assuming propagation is how the stale-identity and false-notification claims survived.
- Parity is proven by a round trip with names, timestamps and hashes, not by a merge message saying it landed.
- Host identity comes from measurement on the owning surface. A document that asserts an identity that a surface contradicts is a document defect to report, never an instruction to obey.

## 7. Alias-dispatch binding (m27.12)

The lane-key validator's hardcoded alias set must not drift from the models actually configured for dispatch.  Q2 fixed the surface symptom by adding `m2.7h`, but did not close the mechanism.

`bin/fm-lane-naming-check.sh --self-check config/crew-dispatch.json` is the binding check.  It reads the dispatch config, derives a lane-key alias for every MiniMax model id present, and:

- **Fails (exit 2)** when a configured MiniMax model has no alias in the hardcoded set.
- **Reports orphaned aliases** (hardcoded but no corresponding MiniMax dispatch model) as informational warnings on stdout.

The alias derivation rule (one canonical statement, one place):

- **MiniMax provider**: model id like `minimax/MiniMax-M<family>[-<tier>]`
  derives to lane-key alias = family + tier-marker, where:
  - family = text before the first `-` in the model id tail (e.g. `m2.7`)
  - tier-marker = keyword mapping of the **first** tier segment:
    `highspeed` -> `h`, `flash` -> `f`, bare/unrecognised -> `''`
  - Example: `minimax/MiniMax-M2.7-highspeed` -> `m2.7h`
            `minimax/MiniMax-M3.1-Flash-Preview` -> `m3.1f`
            `minimax/MiniMax-M2.7` -> `m2.7`
- **Other providers** (openai-codex, etc.): no programmatic rule defined.  Their model ids do not derive to lane-key aliases through the above rule.  Adding an alias for a non-MiniMax model requires explicit verification; do not guess.

Adding a new MiniMax model variant to `config/crew-dispatch.json` without adding its alias to the validator's hardcoded set will now cause `--self-check` to fail and stop the pipeline.  This is the correct failure mode: it forces the developer to add the alias at the same time as the model, rather than silently diverging.