# Recurring Failure Answers

Durable rules, root-cause explanations, enforcement mechanisms, and honest enforcement-strength ratings for nine recurring failures. No enforcement is invented; every "no mechanism" is stated plainly.

---

## 1. Writing a file into the outbox being treated as delivery when it was never transmitted

**Durable rule:** Published ≠ Transmitted. A file placed in the outbox directory is not evidence of delivery. The file must also be recorded in the outbound hash ledger.

**Why it keeps happening:** The outbox is a plain directory. Anyone can write a file there and report "it's in the outbox" as if it were sent. The writing step is cheap and looks like completion.

**Mechanism that now enforces it:**

- `bin/fm-to-controller.sh` performs write-and-send as one atomic step. It copies the file to both the local mirror and the shared exchange directory, records the SHA-256 hash in `state/.controller-inbox-outbound`, and only then reports success. Writing without running this helper leaves the hash absent from the ledger.
- `bin/fm-controller-pending.sh` detects the gap: it scans every `.md` file in the outbox, computes its SHA-256, and checks whether that hash appears in `state/.controller-inbox-outbound`. If the hash is absent, it prints `unsent-to-controller:` and exits 1.

**Enforcement strength:** CONVENTION-ONLY, with a supplemental advisory check. The atomic helper is the documented path, but nothing blocks a bare write to the outbox directory. `fm-controller-pending.sh` is an advisory detector — it surfaces the problem when run, but it is not wired as a hard gate in the delivery path. A worker who writes a file and claims it was sent without running `fm-to-controller.sh` will not be stopped by code.

---

## 2. A notification being treated as receipt

**Durable rule:** Notification ≠ Receipt. A signal that a message was sent or delivered is not proof that it was received. Only the recipient's reply, referencing the correlation id, constitutes receipt.

**Why it keeps happening:** Notification is immediate and visible. Confirmation from the recipient is delayed or absent. It is easy to treat the convenient signal as the authoritative one.

**Mechanism that now enforces it:**

- `bin/fm-comms-ingest.sh` lines 33–49 are explicit:
  - "receipt is delivery and only a reviewed decision is a result."
  - "A bare acknowledgment is refused, because a receipt is delivery."
  - "This script never manufactures a receipt."
  - `fm_pending_reply_confirm_delivery` in `bin/fm-pending-reply-lib.sh` accepts a pending-reply delivery only from a correlated parent report — the exact status line referencing the correlation id.
  - `bin/fm-comms-ingest.sh handled` requires `--review` as a mandatory argument; acknowledgment is a reviewed decision, not a default assumption.

**Enforcement strength:** CONVENTION-ONLY. The comments in the code are precise and correct, but they are comments. There is no runtime assertion that prevents a caller from treating a notification as a receipt. A worker who acts on a notification signal without waiting for the correlated reply will not be stopped by code. The enforcement is the stated rule, and breaking it requires choosing to ignore the rule.

---

## 3. Two lanes reporting mutually exclusive measurements of the same page with neither checked

**Durable rule:** When two sources give different measurements of the same thing, do not report either as fact until the conflict is resolved.

**Why it keeps happening:** Each lane has a plausible signal. The captain receives both as if they were independent data points rather than conflicting evidence. There is no mechanism that requires reconciliation before reporting.

**Mechanism that now enforces it:** **NONE.** No file in this repository detects a conflict between two measurements, compares them, or requires resolution before the conflict is reported. The `docs/verification-discipline.md` document names this class of failure ("treating one convenient signal as the whole state") and establishes the second-signal rule, but it is documentation, not enforcement. The code has no mechanism that compares two measurements of the same entity and refuses to report either until they agree.

---

## 4. Lanes showing as anonymous "worker" in the operator's async panel

**Durable rule:** Every async lane must carry a named key in the format `<model>-<surface>-<task>` so the operator can identify it in the panel. An unnamed lane is invisible to the operator.

**Why it keeps happening:** Direct single-child dispatch shows only the agent kind in the panel. Without a deliberate per-child key, the panel renders "worker" or nothing.

**Mechanism that now enforces it:**

- `bin/fm-spawn.sh` lines 938–945: before any endpoint, worktree, or state mutation, `fm-spawn` validates the task ID against the `<model>-<surface>-<task>` convention using `bin/fm-lane-naming-check.sh`. If validation fails, spawn exits 5 with an explicit error message. Grandfather clause: existing tasks with pre-existing `state/<id>.meta` are exempt so recovery cases are not stranded.
- `bin/fm-lane-naming-check.sh`: validates lane key format, To-Do board line format, and the `data/async-lanes.tsv` registry file structure including cross-checking lane-key segments against model and surface columns.

**Enforcement strength:** TESTED AND BLOCKING (spawn level). The lane key must be valid before `fm-spawn` creates the endpoint. An invalid lane key causes an immediate exit 5. The advisory `fm-lane-naming-check.sh` that checks registry files is not wired into a launcher and cannot block on its own, but the spawn-level enforcement is hard and blocks the bad key from ever reaching the panel.

**Remaining gap:** The registry file (`data/async-lanes.tsv`) and To-Do board line format are advisory-only enforcement. A lane spawned with a valid key can still have malformed board lines that go undetected until manual inspection.

---

## 5. No model visible on a running lane

**Durable rule:** Every lane the operator can see must name its model.

**Why it keeps happening:** Model information lives in the task metadata or brief. Nothing in the display path requires it to be surfaced or validated before the lane is shown to the operator.

**Mechanism that now enforces it:** **NONE.** No file in this repository reads the task's recorded model and asserts it into the lane display. `lane-todo-board.sh` includes `[<model> @ <surface>]` in its documented format, but the format is advisory — nothing blocks a lane from appearing without a model. The `data/async-lanes.tsv` registry has a model column, but there is no mechanism that ensures this column is populated, readable, and rendered for every active lane.

---

## 6. Work dispatched to the wrong repository or a repository that did not exist

**Durable rule:** A dispatch must target an existing, verified project clone.

**Why it keeps happening:** Project arguments are passed as strings. Nothing validates that the named repository exists as a local clone before the worker is sent to it.

**Mechanism that now enforces it:** **NONE.** No file in this repository validates that a project clone exists at the named path before spawning a worker against it. `bin/fm-spawn.sh` calls `resolve_project_dir_arg` and `fm-project-mode.sh`, but these resolve the argument to a path — they do not assert that the path exists or that it is a git repository. A malformed or non-existent project name produces a spawn failure only at the point where the worker actually tries to use the repository, not at dispatch time. The `fm-fleet-sync.sh` comment "resolve_project_arg: accept a path (used as-is when it already exists)" confirms that existence is not checked.

---

## 7. A hard gate written days earlier silently overriding today's new instruction, with nobody noticing the conflict

**Durable rule:** A decision hold (a captain decision recorded as a `captain` kind backlog item) blocks work until the captain resolves it. A new instruction does not override a hold unless the hold is explicitly resolved first.

**Why it keeps happening:** The hold is durable and correctly blocks the work queue. The new instruction arrives as a separate signal. Nothing compares their timestamps or detects that the hold's premise is now obsolete.

**Mechanism that now enforces it:** **CONVENTION-ONLY.** `bin/fm-decision-hold.sh` correctly manages the hold lifecycle — it creates, resolves, and verifies holds. `bin/fm-bearings-snapshot.sh` correctly projects open captain holds into `decisions_open`. The system enforces that a hold blocks work and that resolution closes it. But the system does not compare a hold's creation date against incoming instructions to detect staleness or premise conflict. A hold created on Monday can still be blocking work on Friday with no automatic flag. The `fm-fleet-view.sh` and `fm-bearings-snapshot.sh` surfaces show open holds, but there is no mechanism that says "this hold predates the latest instruction and may now be in conflict."

**Additional gap:** There is no mechanism that detects two simultaneously active holds with mutually exclusive decision keys, or that detects when a new instruction directly contradicts a still-open hold's premise.

---

## 8. A worker's summary being accepted without independent verification

**Durable rule:** Never report state from one signal when a second is available and cheap. When a second signal is unavailable, say UNVERIFIED.

**Why it keeps happening:** A worker's summary is convenient. Verifying it costs additional time and API calls. The summary arrives first and sets the frame.

**Mechanism that now enforces it:** `docs/verification-discipline.md` documents this failure explicitly, with a table of twelve instances where a single signal was treated as complete state. The rule stated there is: "Never report state from one signal when a second is available and cheap." The document also states: "When a second signal genuinely is unavailable, say UNVERIFIED and name what is missing. Do not promote the first signal into confidence. `UNKNOWN` is a valid, honest answer." `bin/fm-watch.sh` and `bin/fm-crew-state.sh` implement a two-signal discipline for some state checks (e.g., pane liveness checks both the pane itself and the status file), but this discipline is not enforced as a universal rule. The verification discipline is stated policy, not a runtime constraint. A worker who reports "all checks green" after reading only one source will not be blocked by code.

**Enforcement strength:** CONVENTION-ONLY. The policy exists in writing, the incident history is documented, and some specific checks use two-signal verification in practice, but there is no enforcement that requires a worker to cite independent evidence before a summary is accepted.

---

## 9. Repeated worker restarts throwing away partial work

**Durable rule:** Teardown must not discard uncommitted work without explicit captain-approved `--force`. Partial work that is worth keeping must survive a restart and be reconciled on recovery.

**Why it keeps happening:** A restart creates a fresh context. Without durable state, the new instance has no record of what the previous instance had done. The teardown guard refuses to proceed if work is uncommitted, but the restart itself may not preserve the artifacts needed to resume.

**Mechanism that now enforces it:**

- `bin/fm-teardown.sh`: refuses to clean up a task while uncommitted work is present. Exit 1 if the worktree is dirty and `--force` is not set. The `--force` flag is the explicit captain-approved discard escape hatch. The refusal message is: "Cannot verify dirty or unlanded work; restore the worktree path or get explicit OK to discard, then --force."
- `bin/fm-brief.sh` lines 326–332: the worktree isolation assertion stops if the worker is launched in the primary checkout, preventing partial work from accumulating in a non-disposable location. Line 331 explicitly states: "The worktree is your laboratory — install, run, edit, and make scratch commits freely; all of it is discarded at teardown." This is a stated discard-at-teardown policy for the brief's worktree, not a preservation policy.
- `bin/fm-bearings-snapshot.sh` and `bin/fm-fleet-snapshot.sh`: surface work that is in-flight, so a captain can notice work that appears to have been lost to a restart.

**Enforcement strength:** PARTIAL — the teardown guard prevents silent discard, but the brief's own stated policy discards the worktree on teardown, and there is no mechanism that preserves partial artifacts across a restart so the next instance can reconcile them. A worker that accumulates partial results in its worktree and then restarts will lose those results. The teardown guard prevents a second party from discarding work, but it does not prevent the worker itself from discarding its own work through a restart. The `--force` flag exists for explicit discard, but the restart path does not require an explicit preservation step.

**Additional gap:** Recovery through `fm-spawn` after a teardown reads the brief fresh. There is no checkpointing mechanism that carries forward intermediate artifacts from a crashed run into the resumed run.

---

## VERDICT

Two failures have no enforcement at all. Ranked by how much Captain time they have cost:

**Rank 1 — Failure 5: No model visible on a running lane.** This has cost the most Captain time because it makes every lane indistinguishable from every other lane in the async panel. The operator cannot tell which lane is doing what, cannot assess reasoning quality, cannot track cost, and cannot route follow-up questions to the right worker. It is the most basic operational visibility failure and the most disruptive to the Captain's ability to supervise the fleet.

**Rank 2 — Failure 3: Two lanes reporting mutually exclusive measurements of the same page with neither checked.** This has cost significant Captain time because it produces two credible but contradictory facts that both appear to be evidence. The Captain must investigate both sources, determine which measurement is wrong, and correct the record. There is no mechanism to detect the conflict, surface it, or require reconciliation before the conflict is reported.
