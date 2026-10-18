# Brandon Pi pane startup/runtime audit and bounded recovery

Captain-authorized task: inspect only the Herdr workspaces `w1T`, `w1V`, `w1W`, `w1X`, `w1Y`, `w1Z`, and `w10` on Brandon; capture exact startup/runtime errors; fix only with documented Firstmate/Herdr recovery; return the exact before/after pane list and a VERDICT.

## Constraints

- Do not inspect or touch any workspace/pane outside the seven named workspace IDs.
- First establish the exact named Herdr session and workspace-to-pane mapping from structured Herdr state. If a target ID is ambiguous, belongs to another session/home, or cannot be verified, stop on that target and report the ambiguity; do not search for lookalike labels.
- Before changing anything, capture every target's exact workspace ID, tab ID, pane ID, displayed pane/workspace name, registered agent/harness, expected model from authoritative task metadata/configuration, native agent state, and the exact visible error text. Preserve the exact error wording; redact secret values only, marking redaction explicitly.
- Use only documented Firstmate/Herdr commands and recovery procedures. Do not hand-edit Herdr state, launch configuration, credentials, or task metadata; do not restart hosts/services/containers; do not touch live sites, DNS, or spend.
- Repair only panes with a positively identified Firstmate-owned task and a confirmed startup/runtime fault. Preserve any task's work and recorded endpoint identity. For ambiguous ownership, missing expected name/model evidence, or a repair outside the documented recovery path, stop and report rather than guessing.
- Do not send prompts, assign tasks, or change the intended model. No broad workspace search, cleanup, renaming, or changes to unrelated panes.

## Required procedure and evidence

1. Read the current `docs/herdr-backend.md` and the relevant `bin/` script headers before using their procedures. Use structured Herdr state and Firstmate's recorded task metadata as authority, not workspace labels alone.
2. Take the complete before snapshot of the seven exact workspaces and their panes before any repair.
3. For each pane, report its exact error or `NO STARTUP/RUNTIME ERROR`, and the evidence source. Distinguish observed error from diagnosis.
4. Apply the smallest documented recovery only to confirmed Firstmate-owned faulty endpoints; record exact command/procedure and result per pane. If no documented recovery safely applies, leave it unchanged.
5. Re-read all seven exact workspace/pane identities. Confirm each intended session is READY and verify its expected name and model against authoritative records. Retain exact error/startup failure when recovery did not succeed.
6. Write the detailed report to `/home/hd2admin/kun-agent-workspace/data/brandon-pi-pane-startup-audit/report.md`, including exact before and after pane lists, errors, actions, validation, and a clear `VERDICT: PASS`, `PARTIAL`, or `FAIL`.
7. Return to the parent through the secondmate status path with correlation ID supplied in the routed message and the report path.
