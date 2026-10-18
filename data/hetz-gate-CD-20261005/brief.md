# Task
## Captain's intent
OVERNIGHT ORDER (captain 2026-10-05): execute PRD discovery Gates C+D — four-project application audit + persistent data classification as READ-ONLY study with dated sanitized artifacts.

## Firstmate spec
Read-only audit of 4 production applications (per Gate C in BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3) + persistent data classification (Gate D). For each project: current deployment location, dependencies, deployment mechanism, then data classification (sensitivity, retention, residency). NO mutations, NO writes outside report paths.

# Setup
This is a SCOUT task. Read-only audit only.

# Rules
1. Never push or write outside this worktree and the report paths.
3. Report status by: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/hetz-gate-CD-20261005.status'`
   States: working, needs-decision, blocked, paused, done, failed.
4. Use lean-ctx for all reads, searches, listings, shell output.
5. Use the To-Do List extension with five+ items.
6. REDACT secrets, customer PII, internal-only domains. Use redacted-N placeholders.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/hetz-gate-CD-20261005.inbox'/*.msg. Move handled to inbox/handled/.

# Definition of done
Report must include:
- VERDICT: PASS / PARTIAL / BLOCKED
- Gate C: 4-project application audit (project-redacted-id, deploy location, dependencies, deploy mechanism, source repo, recent change evidence)
- Gate D: data classification table (data-redacted-id, sensitivity tier, retention, residency/jurisdiction, owner)
- Gaps where current evidence is insufficient

Write to:
- `/home/hd2admin/kun-agent-workspace/data/hetz-gate-CD-20261005/report.md`
- `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-05-hetz-gate-CD-project-audit-and-data-classification.md`

Append `done [at=<epoch>]: {one-line conclusion}` to status file.

# Home brief additions
## Pi Worker Defaults
- Use Codex GPT-6 Luna medium effort.
- Use MiniMax M3.1 Flash Preview for review per gate.
- Subagents allowed for bounded parallel reads.
- 4 projects likely = Music Metrics, CBD, Core-Distro, Elevate per existing evidence.