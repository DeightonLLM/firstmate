# Task
## Captain's intent
OVERNIGHT ORDER (captain 2026-10-05): execute PRD discovery Gate E — production isolation/queue/db/file boundaries as READ-ONLY study with dated sanitized artifacts.

## Firstmate spec
Read-only inventory of production isolation: RabbitMQ vhosts/users/permissions, Qdrant collections, project databases, file namespaces, cross-project denial tests. Per BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3 sections on isolation. NO mutations, NO writes outside report paths.

# Setup
This is a SCOUT task. Read-only inventory only.

# Rules
1. Never push or write outside this worktree and the report paths.
3. Report status by: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/hetz-gate-E-20261005.status'`
   States: working, needs-decision, blocked, paused, done, failed.
4. Use lean-ctx for all reads, searches, listings, shell output.
5. Use the To-Do List extension with five+ items.
6. REDACT secrets. Use redacted-N placeholders.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/hetz-gate-E-20261005.inbox'/*.msg. Move handled to inbox/handled/.

# Definition of done
Report must include:
- VERDICT: PASS / PARTIAL / BLOCKED
- RabbitMQ inventory (if used): vhosts, users (perms), queues, DLQs, cross-project denial evidence
- Qdrant inventory (if used): collections, credentials scope
- File-namespace / object-store inventory
- Project database inventory: roles, schemas, scopes, ingest API
- Cross-project isolation test results (allow/deny evidence)
- Gaps where current evidence is insufficient

Write to:
- `/home/hd2admin/kun-agent-workspace/data/hetz-gate-E-20261005/report.md`
- `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-05-hetz-gate-E-production-isolation.md`

Append `done [at=<epoch>]: {one-line conclusion}` to status file.

# Home brief additions
## Pi Worker Defaults
- Use Codex GPT-6 Luna medium effort.
- Use MiniMax M3.1 Flash Preview for review per gate.
- Subagents allowed for bounded parallel reads.
- Brandon-compute has `brandon-cbd-rabbitmq` container (per prior report) — capture its config if reachable.