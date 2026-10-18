# Task
## Captain's intent
OVERNIGHT ORDER (captain 2026-10-05): execute PRD discovery Gate A — host/server inventory as READ-ONLY study with dated sanitized artifacts. Per hetz-study-20261005 report remediation sequence item 1.

## Firstmate spec
Read-only host/server inventory. Produce dated, sanitized evidence artifact describing: provider(s), host account(s), per-host: CPU/RAM/disk/OS, services running, Docker/Coolify versions, firewall and DNS exposure. NO mutations, NO writes outside report paths.

# Setup
This is a SCOUT task. Read-only inventory only.

# Rules
1. Never push or write outside this worktree and the report paths.
3. Report status by: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/hetz-gate-A-20261005.status'`
   States: working, needs-decision, blocked, paused, done, failed.
4. Use lean-ctx for all reads, searches, listings, shell output.
5. Use the To-Do List extension with five+ dependency-aware items: preflight, host enumeration (sanitized), service enumeration, version/Docker inventory, network exposure inventory, report.
6. REDACT all account numbers, secrets, IPs except tailscale/100.x.x.x range. Use provider/account "redacted-N" placeholders.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/hetz-gate-A-20261005.inbox'/*.msg. Move handled to inbox/handled/.

# Definition of done
Report must include:
- VERDICT: PASS / PARTIAL / BLOCKED
- Per-host inventory table: provider, account-redacted, OS, CPU/RAM/disk, services running, Docker/Coolify version, role
- Network exposure: tailscale IP, public-facing ports, firewall rules, DNS records
- Capture timestamp UTC; source commands cited
- Gaps where current evidence is insufficient

Write to:
- `/home/hd2admin/kun-agent-workspace/data/hetz-gate-A-20261005/report.md` (full)
- `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-05-hetz-gate-A-host-inventory.md`

Append `done [at=<epoch>]: {one-line conclusion}` to status file.

# Home brief additions
## Pi Worker Defaults
- Use Codex GPT-6 Luna medium effort (workhorse).
- Use MiniMax M3.1 Flash Preview (independent review per gate).
- Subagents allowed for bounded parallel reads.
- Capture timestamp is mandatory for every finding.