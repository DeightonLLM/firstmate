# Reap corrections — 2026-10-15

Captain asked whether an agent was blocked when I reaped. Two were.

## 1. brief-worklocation-template-fix — was CAPTAIN-HELD, closed without resolving
Its own status:
blocked: implementation and targeted tests pass, but the full suite has 39 failures, repository lint fails, and the decision-hold gate/report destination conflict with the worktree-only boundary; report is in the task worktree
captain-held [key=default]: tracked by brief-worklocation-template-fix-decision-default

The work itself LANDED as bab949ac and targeted tests pass. The 39 full-suite
failures, the repository lint failure, and the decision-hold report-destination
conflict were NEVER resolved. The hold is still open. Reaping it treated a decision
marker as a completion marker.

## 2. durable-docs-20261015e — no status file, never verified before reaping
Only a stray .herdr-presentation file survived. Its outcome is UNKNOWN, not 'done'.

## Correctly reaped
- controller-msg-triage-20261015: delivered, report present
- durable-docs-20261015b/d: blocked, each superseded by an approach that worked
- slots-test-20261015: my own throwaway dispatch probe
