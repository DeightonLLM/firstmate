# Task
## Captain's intent
Read-only study of the hetz (brandon-compute) surface vs the v3 PRD (`BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` on dubz). Per captain 2026-10-05 order: "study what is on this surface vs what the v3 PRD requires". Deliverable: gap report with severity + remediation plan. Models: Codex GPT-6 Luna med (workhorse), MiniMax M3.1 Flash Preview (independent review). Subagents allowed.

## Firstmate spec
Read-only scout. No service / container / db / docker / volume / network changes. No installs, no kills.

# Setup
This is a SCOUT task. Read-only inventory + gap analysis. No credential access, no writes outside report paths.

# Rules
1. Never push or write outside this worktree and the three report paths.
2. Report status by: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/hetz-study-20261005.status'`
   States: working, needs-decision, blocked, paused, done, failed.
3. If blocked twice, append `blocked [at=<epoch>]: {why}` and stop.
4. Use lean-ctx for all reads, searches, listings, shell output.
5. Use the To-Do List extension with five dependency-aware items: preflight, surface enumeration, PRD review, gap table, report write.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/hetz-study-20261005.inbox'/*.msg. Move handled to inbox/handled/.

# Definition of done
Report must include:
- Verdict: PASS or BLOCKED
- Gap table with: gap, severity (P0/P1/P2), evidence path, smallest mechanical fix
- PRD v3 status check: met / partial / missing per requirement
- All evidence paths cited; no speculative findings

Write to:
- `/home/hd2admin/kun-agent-workspace/data/hetz-study-20261005/report.md` (full)
- `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-05-hetz-study-report.md` (mirror copy)

Mirror queue: `DROP_SENT` per controller-queue-guide.md format at the Mirror queue directory.

Append `done [at=<epoch>]: {one-line conclusion}` to status file.

# Home brief additions
## Pi Worker Defaults
- Create one concise checklist with Pi's `todo` tool at task start.
- Use lean-ctx for shell output; find it at ~/.local/bin/lean-ctx if not on PATH.
- Use Codex GPT-6 Luna medium effort per captain order.
- Use MiniMax M3.1 Flash Preview for independent review pass before final commit.
- Subagents allowed for bounded parallel reads within the surface rules.
- If PRD file is missing on this host, note the dubz path and request via mirror queue; do NOT guess content.