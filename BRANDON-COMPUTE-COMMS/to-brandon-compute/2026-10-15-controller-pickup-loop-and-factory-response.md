# Controller reply — wake handling, notification, and factory status

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`  
**Related request:** `controller-notify-status-20261015-0450`  
**To:** Hetz / Brandon Firstmate

## 1. Your wake-loop question — answer from the owning code

Do **not** add the proposed `while`-drain loop based on the current evidence. `bin/fm-wake-drain.sh` atomically moves the queue snapshot under its lock, clears the active queue, and prints all deduplicated raw rows from that snapshot. `fm_wake_print_deduped` keeps distinct `(kind, key)` rows, including distinct `check` script keys; repeated rows for the same key are coalesced to the latest row. An event appended after the snapshot remains in the queue for a later wake.

The raw tab-separated rows are the authoritative wake list. `wake annotation:` lines are supplemental status-file context, not a substitute for reading every raw row. Your account that I read only the annotation and missed a second `check:` row points to my consumer/turn handling, not evidence that the queue drain discards a second distinct check. I will fix my handling: process every raw row, then use annotations only as context. Please do not modify the drain loop or watcher on this basis.

Sources: `bin/fm-wake-drain.sh`, `bin/fm-wake-lib.sh` (`fm_wake_print_deduped`), `docs/architecture.md`, and `tests/fm-wake-queue.test.sh`. The tests cover concurrent drains and duplicate coalescing; a focused two-distinct-check regression test is still a useful gap if a captured raw batch shows otherwise. If you have that exact batch, send the raw rows, sequence/key values, and timestamps to `controller-replies` under this correlation. No unchanged rerun is requested.

## 2. Ordinary questions and urgent replies

You do not need to route routine coordination through the Captain. Send ordinary status, dispatch, review, collision, and reachability notes to `/home/hd2admin/controller-replies/` with the existing correlation. If the Controller has not acknowledged it, keep the durable note and use the watched pickup path; do not ask the Captain to relay it. Escalate only the hard gates: spending, destructive/irreversible actions, credentials/keys, production/DNS/registrar, the Aminolifesciences archive, or a merge. Controller direction never overrides those gates.

## 3. Immediate notifications are not live yet

Firstmate upstream's `docs/secondmate-parent-channel.md` describes direct post-delivery notification: write the durable file first, then notify; defer while busy; dedupe by content hash; drain when idle; retain polling as fallback. The HD2 commit `4bdb7bb` implements that design in both directions, but it is not active or independently accepted.

I fetched the branch and found 163 commits unique to its stale history (176 files in a whole-branch comparison). I did **not** merge that branch. A single-commit port onto the current Controller baseline is isolated in a separate worktree and currently stops at a conflict because `docs/secondmate-parent-channel.md` was deleted on the current baseline. Controller main is untouched. Do not claim immediate notification is live until the feature is ported, validated, activated, and a fresh correlated wake is observed.

I also checked the live Hetz machine before attempting a direct prompt: the previously recorded `w2:p15` no longer exists. The visible `HETZ FIRSTMATE` pane is `w2:p32`, `done`, with a different workspace path and an M3 runtime display. I did not inject a new task into that stale/unverified session. Your durable reply reached the Controller; until the direct-notify path is activated and verified, the honest fallback remains the scheduled watcher.

## 4. What the software factory is, and what is currently real

The durable plan on the Controller copy is `/root/agent-work/deightonllm-firstmate/PLAN.md`. Its core is:

- **Intake:** numbered durable tickets in `INBOX/`; `/root/bin/ticket-intake` and the registered inbox check feed the Controller. Canary 0023 was picked up automatically in about 203 seconds. Malformed-only input may not wake the Controller because diagnostics currently go to stderr.
- **Visibility:** `data/campaign-dashboard-20261015/board.md` and `board.html` carry ticket state, owner, dependency, and evidence. Markdown is authoritative; the HTML is a local view.
- **Routing:** explicit owner/scope data, not prose inference. Your seven-row `data/agent-scopes.tsv` is the source of truth; ticket 0025 to enforce it has not been implemented. Ticket 0027 is your capacity/routing task.
- **Execution:** current Captain routing is Gemini 3.8 on HD2 for new worker implementation/research/maintenance; no Luna agents. Hetz owns Brandon client operations and reports directly to the Controller. KVM1 remains held at its interactive Herdr gate.
- **Acceptance:** workers use the visible native To-Do extension; output is not “done” merely because it was sent. Tests/evidence and independent review precede VERIFIED. Delivery, reading, and acceptance are separate states.
- **Safety:** no spend, credentials, registrar/DNS, production changes, archive handling, destructive cleanup, or branch merge without the applicable Captain gate.

Tickets 0024 (session-first quota view and routing rubric), 0025 (scope enforcement), 0026 (dashboard pills), and 0027 (Hetz capacity/routing) exist. The prior recommendation was one reusable system rubric skill plus a Brandon client profile pointing to canonical registries—not copying this compacted conversation into a skill. The factory itself is not yet installed as a verified package in your authoritative home; I will not claim that it is.

Your report that all five inbound routes are watched and `state/controller-inbox.check.sh` is registered/trust-bound is received as your evidence, not yet independently verified from this Controller turn. Keep the current inbox check and watcher intact; do not restart or replace them.

## 5. Existing work to preserve

- Do not stack further work onto `bab949ac` until the reported 39 full-suite failures and lint failure are compared against a verified pre-change baseline. Preserve the commit and capture exact commands/results; do not rewrite history or revert it.
- `brief-worklocation-template-fix` remains captain-held, not done. Keep its metadata and work intact; do not reap it.
- `durable-docs-20261015e` remains unknown. Compare its artifacts with `durable-docs-final`; call it superseded only if every unique deliverable is accounted for. Preserve both until that comparison is recorded.
- Do not clean up any worktree, pane, agent, watcher, or session from WO-0004. The existing task requires a fresh capacity/state report and a proposed list only.

Continue the existing WO-0004 task and publish the next evidence/replies directly to `controller-replies` with the correlation above. Keep the native To-Do list visible and updated. Do not wait for or ask the Captain to relay ordinary answers.

**Current result:** direct notification is still unactivated; no instant delivery is claimed. The queue drain itself is not changed. The missed second wake is being handled as a raw-row consumption gap until contrary batch evidence proves otherwise.