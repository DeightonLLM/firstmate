# Infra pass: determinable Firstmate tooling entries

Read-only investigation completed 2026-10-14. I read `data/backlog-truth-pass/report.md`, checked the visible backlog entry text, examined available task briefs/reports/status records, and read the decision-hold lifecycle instructions. I did not change code, backlog, or task state. Several requested task status/report paths are absent from this checkout/home; I mark those NOT ACTIONABLE HERE rather than infer a result from a title or unrelated report.

## Verdicts

| entry | verdict | evidence path | one specific next action or question |
|---|---|---|---|
| `controller-watcher-tdd` | STILL NEEDS WORK | `data/controller-watcher-tdd/report.md` (interim report); `state/controller-watcher-tdd.status`; `data/controller-watcher-tdd/brief.md`; `CONTROLLER_STATE.md` 2026-10-03 17:43 section | Resolve the four unchanged out-of-scope lint warnings and decide whether a no-skip publish/PR/CI run is authorized; current report explicitly says validation is incomplete. |
| `status-dir-validate` | NOT ACTIONABLE HERE | No matching task directory, report, or status record was found under `data/` or `state/`; `data/backlog.md` has no matching entry in the searched in-flight records. | Firstmate should locate the authoritative task ID/evidence, or confirm this name is stale. |
| `quota-aware-queue-pump` | NOT ACTIONABLE HERE | `data/quota-aware-queue-pump/brief.md` exists but no task report/status was found. `data/brief-compaction-preserve/report.md` only records a historical pipeline collision with this branch, superseded later by resolution; this does not establish the pump's outcome. | Locate the queue-pump task's own terminal report/status before deciding whether to resume or retire it. |
| `pi-live-todo-default` | NOT ACTIONABLE HERE | `data/pi-live-todo-default-0923/brief.md` and `captain-decision-20261012.md`; no matching status/report found. | Reconcile the task against its captain decision and obtain its result artifact before making a completion claim. |
| `afk-return-dir-fix` | NOT ACTIONABLE HERE | No matching `data/` task artifact or `state/` status record found. Runtime `state/.afk-return-catchup` exists but is not evidence of this task's result. | Find the task's actual result/status or confirm the entry is stale. |
| `brief-compaction-preserve` | STILL NEEDS WORK | `data/brief-compaction-preserve/brief.md`; `data/brief-compaction-preserve/report.md`; `state/brief-compaction-preserve.status` | The report says branch `fm/brief-compaction-preserve` at `eb14aefd` has tests/lint green and pipeline custody returned, but no-mistakes validation/shipping remains; run the authorized validation path rather than treating its worker `done` event as delivered. |
| `calm-worker-version-consistency` | OBSOLETE | `data/calm-worker-version-consistency/brief.md`; `state/calm-worker-version-consistency.status`; `state/.calm-worker-version-consistency.branch-outcome-index` | Reconcile/close the queued entry as cancelled per the recorded captain direction: no further Calm implementation/review; preserve the branch and worktree. |
| `controller-inbox-local-repair-20261013` | STILL NEEDS WORK | `data/controller-inbox-local-repair-20261013/report.md`; `data/controller-inbox-local-repair-20261013/brief.md`; `data/backlog.md` decision entries around lines 366–372 | Keep the automatic-receipt proof open: report says the canary mtime precedes any qualifying away entry, so it cannot prove an automatic receipt. Follow the existing captain-decision route; do not claim completion from manual poll/ack or hash-only evidence. |

## Prioritized actions for Firstmate

1. **Controller inbox automatic receipt:** the report itself disproves the claimed canary as valid future proof (its mtime predates the next away entry); the backlog already records unresolved captain decisions around lines 366–372. Obtain valid proof only through the authorized genuine away/notification flow, or route the explicit decision. One question: should this private repair remain open until genuine automatic receipt is observed, or be closed as incomplete with that limitation?
2. **Controller watcher:** implementation has focused tests and Review/Test evidence, but four unrelated lint warnings keep the lint gate red, and push/PR/CI were skipped. Decide whether to authorize out-of-scope lint cleanup and a no-skip delivery run; do not call it done meanwhile.
3. **Brief compaction:** worker branch/report evidence exists, but validation and delivery are still outstanding. Route to the owning no-mistakes path, preserving branch custody and requiring current green outcome.
4. **Calm version consistency:** captain's explicit stop makes the original implementation task obsolete; reconcile the task record without discarding its preserved branch/worktree.
5. **Missing-evidence queue entries:** resolve identity/evidence for `status-dir-validate`, `quota-aware-queue-pump`, `pi-live-todo-default`, and `afk-return-dir-fix` before any status changes. No code-based verdict is supportable here.

## Evidence limits and commands

Read-only files examined included:
- `data/backlog-truth-pass/report.md`
- `data/backlog.md`
- `data/controller-watcher-tdd/{brief.md,report.md}`
- `data/brief-compaction-preserve/{brief.md,report.md}`
- `data/calm-worker-version-consistency/brief.md`
- `data/pi-live-todo-default-0923/{brief.md,captain-decision-20261012.md}`
- `data/quota-aware-queue-pump/brief.md`
- `data/controller-inbox-local-repair-20261013/{brief.md,report.md}`
- `state/controller-watcher-tdd.status`, `state/brief-compaction-preserve.status`, `state/calm-worker-version-consistency.status`

I used directory listings and exact-path reads to check whether the missing target artifacts existed. I did not run project tests or inspect `projects/`. The evidence is sufficient to identify three concrete unfinished items and one explicitly cancelled task; it is insufficient to infer outcomes for four targets.

The decision-hold lifecycle instructions were read. No new independent captain choice was created by this report beyond the already-recorded inbox repair decision and watcher authorization questions. I did not update backlog/task state because this scout is report-only and Firstmate owns those changes.
