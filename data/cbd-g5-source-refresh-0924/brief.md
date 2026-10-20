# Task
## Captain's intent
Reconcile conflicting CBD G4/G5 acceptance claims against current evidence. Produce a trustworthy offline preparation report so the CBD work can resume from verified facts, not stale or invented artifact paths.

## Firstmate spec
Use only the already approved SSH route `root@100.117.47.27` and source checkout `/root/agent-work/projects/cbd-data.com/current-cbd-data`. Inspect repository identity/status, current HEAD and relevant branch heads, tracked path names, and non-secret documentation directly related to G4/G5 acceptance. Verify whether a G4 ledger or G5 brief/report exists in the current checkout or visible branches, and inspect only the documentation needed to state current acceptance criteria.

Reconcile these Firstmate artifacts:
- `data/cbd-acceptance-map-0923/report.md` (contains claims later corrected in its errata)
- `data/cbd-g5-evidence-reconcile-0923/report.md` (the latest local reconciliation at its recorded source revision)
- `/home/hd2admin/brandon-inbox/2026-09-23-cbd-priority-followup.md` (says a G4 ledger exists and G5 brief exists)

Treat the reconciliation as authoritative for the exact paths and HEAD it checked. Do not assume the Controller means the same canonical source/path; distinguish that ambiguity explicitly. No Controller contact is required for this task.

Forbidden: do not read credentials, `.env`, secret files, customer data/exports, databases, model data, or runtime service state. Do not run tests, access cPanel/UAPI, edit or commit any remote file, make deployment/service changes, or access a different host. Do not claim an acceptance gate is complete or `READY_FOR_M3_REVIEW` without direct current evidence for its criteria.

Write `/home/hd2admin/kun-agent-workspace/data/cbd-g5-source-refresh-0924/report.md` with:
1. Exact checkout identity, branch/HEAD, and timestamp.
2. Precise commands and paths used, with evidence distinguishing the current checkout from other branch names.
3. A table for each G4/G5 artifact: canonical path, present/absent/unverified, criterion it supports, and evidence.
4. Reconciliation of the Controller's “G4 ledger exists / G5 brief exists” statement with the earlier audit; do not invent a path. If the statement cannot be resolved from the approved checkout, name the exact path or coordinate needed from the Controller.
5. A short offline-preparation checklist clearly labeled proposed/unaccepted, and concrete operator-owned blockers that prevent execution.
6. An honest conclusion and smallest next step. Keep G1 credentials and all live canary work explicitly out of scope.

Use one concise Pi `todo` checklist at task start; print the entire list into the visible pane, keep one item active, and update the same checklist as each step changes. Before long commands or a child review, print a one-line progress note; after it returns, update the list and report the result before continuing.

After the report exists, one bounded MiniMax-M2.7 child may independently verify its artifact-path and evidence-status claims against captured command output. No recursive children and no web/live-service checks. The Firstmate/Codex owner performs final review.

Use `lean-ctx` for routine local reads if available; use direct output for exact commands, paths, and errors. Keep one worktree owner. Append only phase-change and final status events. Stop with `blocked` if the approved SSH route or source checkout is inaccessible; include the exact safe diagnostic.
