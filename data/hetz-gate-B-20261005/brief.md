# Task
## Captain's intent
OVERNIGHT ORDER (captain 2026-10-05): execute PRD discovery Gate B — Namecheap 4-target capability classification as READ-ONLY study with dated sanitized artifacts.

## Firstmate spec
Read-only inventory of 4 Namecheap backup targets (per BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3). For each target: capability, ownership, DR readiness, restore evidence. NO mutations, NO writes outside report paths.

# Setup
This is a SCOUT task. Read-only inventory only.

# Rules
1. Never push or write outside this worktree and the report paths.
3. Report status by: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/hetz-gate-B-20261005.status'`
   States: working, needs-decision, blocked, paused, done, failed.
4. Use lean-ctx for all reads, searches, listings, shell output.
5. Use the To-Do List extension with five+ items.
6. REDACT account numbers, secrets, domains where they're internal-only. Use redacted-N placeholders.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/hetz-gate-B-20261005.inbox'/*.msg. Move handled to inbox/handled/.

# Definition of done
Report must include:
- VERDICT: PASS / PARTIAL / BLOCKED
- Table of 4 targets with: target-redacted-id, capability (full backup / DB-only / object-only / etc.), ownership/contact, last available restore-test date+result, encryption-at-rest status, retention policy
- Gaps where current evidence is insufficient

Write to:
- `/home/hd2admin/kun-agent-workspace/data/hetz-gate-B-20261005/report.md`
- `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-05-hetz-gate-B-namecheap-classification.md`

Append `done [at=<epoch>]: {one-line conclusion}` to status file.

# Home brief additions
## Pi Worker Defaults
- Use Codex GPT-6 Luna medium effort.
- Use MiniMax M3.1 Flash Preview for review per gate.
- Subagents allowed for bounded parallel reads.
- If SAAS_ACCESS_INVENTORY has Namecheap data, redact before reporting.