# Comms and lane-naming contract

Owner: this file owns the comms and delivery facts below; [`AGENT-TODO-PROMPT-STYLE.md`](../AGENT-TODO-PROMPT-STYLE.md) owns the naming format.
Status: 2026-10-17; transmission-record rule amended 2026-10-22. Unlanded in this repository; mirrors confirm receipt by returning the exact sha256.

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

### 2.1 How a transmission is recorded

**THE RULE: a transmission is recorded by MESSAGE NAME, and the hash is the evidence of the bytes that were transmitted.**

- The name is the key of the record. The sha256 is kept as the evidence of which bytes went out under that name, not as the key.
- A name that has been transmitted is TRANSMITTED, even when its bytes have changed since it was transmitted.
- A name that has never been transmitted is UNSENT. It still reports, and it stays visible. A note is never suppressed because its name looks like a reissue.
- A note that was transmitted and then reissued has bytes that are not the bytes that went out. It is reported as REISSUED, with the old hash and the new hash. A reissue is VISIBLE and it is NOT BLOCKING: it is not an unsent note, and it does not re-arm the watcher on every cycle.

Why the name and not the hash: a ledger keyed by the hash alone makes a reissued note read as a message that was never sent, on every scan, forever. A permanently unsent backlog then keeps the watcher exiting with an actionable reason and supervision never holds. Keyed by the name, the note is known to have been sent, and the change in its bytes is a reissue - a visible change, not a false alarm.

The record lives beside the hash ledger in the home's state directory: the hash ledger keeps the bare sha256 of the transmitted bytes, the name ledger keeps one message name per line, and the transmission record keeps the name, the hash of the bytes transmitted under that name, and the UTC time of the transmission. `bin/fm-outbound.sh` writes all three, and `bin/fm-outbound.sh --mark-only <file>` reconciles a transmission that the name ledger predates, by the file's own name.

### 2.2 What the pending check reports

`bin/fm-controller-pending.sh` is the enforcement point, and it is a watcher check.

- Its stdout carries the ACTIONABLE finding ONLY: the notes that were never transmitted, oldest first, and the action line. The watcher treats any stdout from a check as actionable, so a notice on stdout is itself the defect.
- A reissue is not on stdout. It goes to a durable reissue log, once per reissue, so the change stays visible without re-arming the watcher on every cycle and without the log growing on every scan.
- `--report` prints the classification of every note for a human reader. It is not the watcher check mode and must not be registered as one.
- The age of an unsent note is reported in whole days in check mode, so two scans of an unchanged set produce identical output and the watcher is not woken by the clock alone. The report mode gives the exact age.


## 3. Reading

- A reply the sender claims to have sent is verified by reading it from the inbound directory, never from the sender's description.
- If a path is unreadable, that is a reader or access fact, not proof the file does not exist. Report the exact path and the exact refusal.
- Read the inbound queue before asking for anything that may already have been delivered.

## 4. Lane naming validation

[`AGENT-TODO-PROMPT-STYLE.md`](../AGENT-TODO-PROMPT-STYLE.md) owns the naming format; the validator enforces only part of that contract and is not its definition.

The format has one owner: `bin/fm-todo-prefix-check.sh` holds the model alias table, the harness and effort tokens, the lane-key shape and the registry rules. `bin/fm-lane-naming-check.sh` is an entry point that forwards every check to that owner, so the two cannot disagree.

When given a registry file, `bin/fm-lane-naming-check.sh` requires each `lane_key` to match `<harness>-<model>-<host>-<task>`, with a recognized harness segment, and checks the model and host against the row's model and surface fields.
The registry check also requires each `run_id` to be a UUID unique to one row; duplicate IDs are rejected, as verified by the negative control in `tests/fm-lane-naming-check.test.sh`.

Closed defect: direct single-key input used to accept a key without a harness segment, so a key rejected in the registry could pass when supplied directly to the checker, and `bin/fm-spawn.sh` gated on that accepted form.
The direct input path now enforces the same canonical four-segment rule as the registry path, so a key that is refused in the registry is refused directly too, and the spawn gate refuses a three-segment key with exit 5.
The legacy direct-input behavior is gone, and the tests in `tests/fm-lane-naming-check.test.sh` and `tests/fm-lane-naming-spawn-integrity.test.sh` assert the closed behavior in both directions.

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
            `minimax/MiniMax-M3.1-Flash` -> `m3.1f`
            `minimax/MiniMax-M2.7` -> `m2.7`
- **Other providers** (openai-codex, etc.): no programmatic rule defined.  Their model ids do not derive to lane-key aliases through the above rule.  Adding an alias for a non-MiniMax model requires explicit verification; do not guess.

Adding a new MiniMax model variant to `config/crew-dispatch.json` without adding its alias to the validator's hardcoded set will now cause `--self-check` to fail and stop the pipeline.  This is the correct failure mode: it forces the developer to add the alias at the same time as the model, rather than silently diverging.