# Herdr Pane Cleanup Inventory — 2026-09-23

**Task:** `window-cleanup-inventory-0923` (scout, read-only)
**Scope:** All 14 Herdr workspaces / panes visible via `herdr pane list`. Reconciled against Firstmate task metadata (`state/<id>.meta`), backlog (`data/backlog.md`), `bin/fm-crew-state.sh`, worktree existence, and pane terminal output.

**Evidence collected:**
- `herdr workspace list` + `herdr pane list` (raw JSON, 14 workspaces, 15 panes)
- `herdr pane get <pane_id>` for all 13 non-coordinator panes
- `herdr pane read <pane_id>` for orphaned and ambiguous panes
- `bin/fm-crew-state.sh <task_id>` for all 8 task-tracked panes
- `data/backlog.md` full contents (In Flight, Queued, Done)
- `state/<id>.meta` and `state/<id>.status` for all registered tasks
- Worktree existence checks on `/home/hd2admin/kun-agent-workspace-8bf1b0/{4,5,7,8,9,10}/`
- Pane terminal output for wY:p2, wZ:p2, w0:p2 (trust-prompt state), wS:p2, w12:p2

---

## Complete Pane Inventory (14 panes)

| # | Pane | Workspace Label | Agent | Herdr State | Task ID | Backlog | Must Keep? | Reason |
|---|------|----------------|-------|-------------|---------|---------|-----------|--------|
| 1 | w2:pA | 05 · FIRSTMATE / SYSTEM · BRANDON WAR ROOM | codex | **working** | — (coordinator) | — | **YES** | Coordinator pane; active fleet management |
| 2 | w2:pP | π · M3 · w2:pP | pi | **working** | — (firstmate primary) | — | **YES** | Primary firstmate; active supervision cycle |
| 3 | wF:p2 | └ parallel-dispatch-audit | pi | idle | parallel-dispatch-audit | In Flight | **(candidate)** | Scout done, report filed, worktree clean, pane idle |
| 4 | wJ:p2 | └ brief-compaction-preserve | pi | idle | brief-compaction-preserve | In Flight | **YES** | Ship blocked: 12 unfixed findings, unlanded commits (branch fm/brief-compaction-preserve at b55afe13 vs d723e16b clean) |
| 5 | wK:p2 | └ calm-worker-version-consistency | pi | idle | calm-worker-version-consistency | Done (canceled) | **YES** | Branch `fm/calm-worker-version-consistency` preserved per explicit captain instruction; worktree /10 intact |
| 6 | wR:p2 | └ elevate-ops-source-map | codex | idle | elevate-ops-source-map | In Flight | **YES** | Scout blocked: source/tests/command unidentified; blocked since epoch 1790164412 |
| 7 | wT:p2 | └ core-v3-prd-gap-map | codex | idle | core-v3-prd-gap-map | In Flight | **YES** | Scout paused: awaiting controller reply on Core V3 spec coordinates |
| 8 | w6:p2 | BR-04 · SAFE UPDATE ENGINE · M3 | pi | idle | tool-auto-update | In Flight (done, unmerged) | **YES** | Branch `fm/tool-auto-update` ready at 3aa352a; awaiting merge approval (local-only, yolo=on) |
| 9 | wM:p3 | 2ndmate-system-ops | pi | idle | system-ops | Secondmate | **YES** | Secondmate; idle but registered and supervised |
| 10 | wS:p2 | └ quota-aware-queue-pump | pi | working→idle | quota-aware-queue-pump | Not in backlog | **(candidate)** | Pipeline done (all gates green), push blocked 403; worktree /5 deleted; no pending decisions |
| 11 | wV:p2 | └ trace-dir-probe | pi | idle | trace-dir-probe | In Flight | **EXCLUDE** | Ship in-flight, meta exists, no report yet |
| 12 | wY:p2 | └ trace-treehouse-task | pi | idle | trace-treehouse-task | Not in backlog | **(candidate)** | Orphaned pane; worktree /7 deleted; stuck at Pi trust-prompt; no metadata, no report, no unlanded work |
| 13 | wZ:p2 | └ trace-status-probe-2202657 | pi | idle | trace-status-probe-2202657 | Not in backlog | **(candidate)** | Orphaned pane; worktree /8 deleted; stuck at Pi trust-prompt; no metadata, no report, no unlanded work |
| 14 | w0:p2 | └ trace-main-home-2217411 | pi | idle | trace-main-home-2217411 | Not in backlog | **(candidate)** | Orphaned pane; worktree /9 deleted; stuck at Pi trust-prompt; no metadata, no report, no unlanded work |
| 15 | w12:p2 | └ status-dir-validate | pi | idle | status-dir-validate | Not in backlog | **(candidate)** | Pipeline done (all gates green), push blocked 403; worktree /10 deleted; report filed in system-ops secondmate data |

---

## Safe Teardown Candidates (6 panes)

All six pass the decision-gate check: no pending captain-held decisions, no unresolved ask-user findings, no blockers requiring captain action.

### 1. `wF:p2` — parallel-dispatch-audit

- **Task ID:** `parallel-dispatch-audit`
- **Workspace/Pane:** wF (parallel-dispatch-audit) / wF:p2
- **Report:** `data/parallel-dispatch-audit/report.md` ✓ filed
- **Current state:** idle (fm-crew-state: `unknown — no current-state source available`)
- **Backlog:** In Flight (mis-categorized; report complete since epoch 1790143178)
- **Worktree:** `/home/hd2admin/.treehouse/firstmate-46aafc/9/firstmate` — detached HEAD at `2e61f52`, **nothing to commit, working tree clean**
- **Meta file:** `state/parallel-dispatch-audit.meta` exists (stale; agent exited cleanly)
- **Why teardown-safe:** Scout read-only investigation. Report filed. Worktree is bare default-branch checkout with zero uncommitted and zero unlanded changes. Agent exited cleanly. No pending decisions, no unlanded work. Pane has been idle since epoch 1790143178.

---

### 2. `wY:p2` — trace-treehouse-task

- **Task ID:** `trace-treehouse-task`
- **Workspace/Pane:** wY (└ trace-treehouse-task) / wY:p2
- **Report:** None — task never produced output
- **Current state:** idle — stuck at Pi trust-prompt (`Trust project folder?`)
- **Worktree:** `/home/hd2admin/kun-agent-workspace-8bf1b0/7/` — **directory does not exist**
- **Meta file:** None in main home or any secondmate home
- **Backlog:** Not present
- **Why teardown-safe:** No metadata in any home, no backlog entry, no report produced, no unlanded work (worktree deleted). FM_TASK_ID was set in the session but no formal firstmate spawn metadata exists. Pane is stuck at the Pi trust-prompt — the agent session never progressed past launch. No active work can be lost. Teardown closes a zombie pane.

---

### 3. `wZ:p2` — trace-status-probe-2202657

- **Task ID:** `trace-status-probe-2202657`
- **Workspace/Pane:** wZ (└ trace-status-probe-2202657) / wZ:p2
- **Report:** None — task never produced output
- **Current state:** idle — stuck at Pi trust-prompt
- **Worktree:** `/home/hd2admin/kun-agent-workspace-8bf1b0/8/` — **directory does not exist**
- **Meta file:** None in any home
- **Backlog:** Not present
- **Why teardown-safe:** Identical to wY:p2. No metadata, no backlog entry, no report, no unlanded work. Worktree deleted. Pane stuck at trust-prompt. Teardown closes a zombie pane.

---

### 4. `w0:p2` — trace-main-home-2217411

- **Task ID:** `trace-main-home-2217411`
- **Workspace/Pane:** w0 (└ trace-main-home-2217411) / w0:p2
- **Report:** None — task never produced output
- **Current state:** idle — stuck at Pi trust-prompt
- **Worktree:** `/home/hd2admin/kun-agent-workspace-8bf1b0/9/` — **directory does not exist**
- **Meta file:** None in any home
- **Backlog:** Not present
- **Why teardown-safe:** Identical to wY:p2 and wZ:p2. No metadata, no backlog entry, no report, no unlanded work. Worktree deleted. Pane zombie. Teardown closes it safely.

---

### 5. `wS:p2` — quota-aware-queue-pump

- **Task ID:** `quota-aware-queue-pump`
- **Workspace/Pane:** wS (└ quota-aware-queue-pump) / wS:p2
- **Report:** Produced — no-mistakes pipeline: Review + Test + Document + Lint all completed
- **Current state:** idle — pane shows `✓ M3 · wS:p2 · READY`; inbox confirms: *"Standing by. Holding for the captain to configure the GitHub token."*
- **Worktree:** `/home/hd2admin/kun-agent-workspace-8bf1b0/5/` — **directory does not exist** (already cleaned up by system-ops secondmate)
- **Meta file:** None in main home; none in system-ops secondmate home (secondmate home `/4/` has no `state/` directory at all)
- **Backlog:** Not present in main backlog
- **Branch:** `fm/quota-aware-queue-pump` at `c912e97a` — 7 unpushed commits preserved by system-ops secondmate
- **Why teardown-safe:** Full no-mistakes pipeline completed (all gates green). Push stopped at 403 per supervisor instruction — GitHub token not configured, not a task failure. Worktree already deleted. Branch commits preserved by system-ops secondmate (confirmed: *"Both crews confirmed terminal at 403 push gate, both worktrees preserved"*). No pending decisions, no inbox messages, no blocker requiring captain action before pane closure. The hold is on the *branch landing*, not on any in-progress work. Pane is a completed-work display terminal, not active work.

---

### 6. `w12:p2` — status-dir-validate

- **Task ID:** `status-dir-validate`
- **Workspace/Pane:** w12 (└ status-dir-validate) / w12:p2
- **Report:** `data/status-dir-validate/report.md` in system-ops secondmate data ✓ filed
- **Current state:** idle — pane shows `✓ M3 · w12:p2 · READY`; terminal output confirms full pipeline summary
- **Worktree:** `/home/hd2admin/kun-agent-workspace-8bf1b0/10/` — **directory does not exist** (already cleaned up)
- **Meta file:** None in main home or any secondmate home
- **Backlog:** Not present in main backlog
- **Branch:** `fm/status-dir-validate` — 8 commits on branch, preserved by system-ops secondmate
- **Pipeline evidence (from pane terminal output):**
  - Regression tests: 4/4 PASSED
  - no-mistakes gates: intent→rebase→review→test→document→lint = all green
  - Push: Failed 403 (isolated worktree, expected)
- **Why teardown-safe:** Complete pipeline with all gates green. Report filed. Worktree already deleted by system-ops secondmate. Branch commits preserved. No pending decisions, no inbox messages. Pane shows final summary output. Identical safe-completion profile to wS:p2.

---

## Panes That Must Remain

### Coordinator and Primary Firstmate
- **`w2:pA`** — BRANDON WAR ROOM coordinator (codex, working). Fleet management pane. **Never close.**
- **`w2:pP`** — Primary firstmate Pi (π · M3, working). Active supervision cycle. **Never close.**

### Active / Blocked / Ship Work
- **`wJ:p2`** — brief-compaction-preserve. Blocked: 12 findings (4 ask-user + 8 auto-fix) unfixed; pipeline head b55afe13 vs local clean d723e16b. **Unlanded work.**
- **`wR:p2`** — elevate-ops-source-map. Blocked since epoch 1790164412: source repo/tests/command unidentified. **Active blocker.**
- **`wT:p2`** — core-v3-prd-gap-map. Paused: awaiting controller reply on Core V3 spec coordinates. **External wait.**
- **`wV:p2`** — trace-dir-probe. Scout in-flight, no report yet. **Active work.**

### Secondmate
- **`wM:p3`** — 2ndmate-system-ops. Secondmate; idle but registered and supervised by parent. **Never close a secondmate pane.**

### Unlanded / Held Branches
- **`wK:p2`** — calm-worker-version-consistency. Done/canceled; branch `fm/calm-worker-version-consistency` preserved per explicit captain instruction (`"no further Calm implementation or review. Preserve the branch, worktree, and existing composer text"`). **Unlanded work + explicit preservation.**
- **`w6:p2`** — tool-auto-update. Done; branch `fm/tool-auto-update` ready at 3aa352a. local-only mode, yolo=on. **Awaiting merge approval** — not a teardown candidate while unmerged.

---

## Summary

**6 candidates** (all < 14 cap):

| Pane | Task | State | Unlanded? | Decision Gate |
|------|------|-------|-----------|---------------|
| wF:p2 | parallel-dispatch-audit | Scout done, worktree clean | None | Clear |
| wY:p2 | trace-treehouse-task | Orphaned, trust-prompt | None (worktree gone) | Clear |
| wZ:p2 | trace-status-probe-2202657 | Orphaned, trust-prompt | None (worktree gone) | Clear |
| w0:p2 | trace-main-home-2217411 | Orphaned, trust-prompt | None (worktree gone) | Clear |
| wS:p2 | quota-aware-queue-pump | Pipeline done, push blocked 403 | Branch preserved by 2ndmate | Clear |
| w12:p2 | status-dir-validate | Pipeline done, push blocked 403 | Branch preserved by 2ndmate | Clear |

**8 must remain:** w2:pA (coordinator), w2:pP (primary firstmate), wJ:p2 (blocked ship), wK:p2 (preserved branch + explicit captain hold), wR:p2 (blocked scout), wT:p2 (paused scout), w6:p2 (unmerged local-only), wM:p3 (secondmate), wV:p2 (active scout in-flight).

---

## Recommendation

Close the 6 candidate panes via `bin/fm-teardown.sh` for each respective task ID, in any order. The three orphaned trace panes (wY:p2, wZ:p2, w0:p2) have no associated task ID in the formal fleet registry — firstmate should close them directly via Herdr (`herdr pane close wY:p2 wZ:p2 w0:p2`) after verifying no formal task was intended to outlive the trust-prompt wait.

No pending captain-held decisions block any of the 6 candidates. The two completed-pipeline panes (wS:p2, w12:p2) hold preserved branches in the system-ops secondmate's custody, ready for manual GitHub token configuration and merge when the captain is ready.
