# Task
## Captain's intent
Read-only inventory of Brandon's current Firstmate/Codex/Pi configuration and installed plugins. Find: current concurrency settings in Firstmate config/docs, Codex settings.json and config, Pi models.json and settings, installed plugins and their sources, and any existing safety caps. Note which settings are enforced vs advisory. Report sanitized paths and values (no secrets).

## Firstmate spec
Read-only lane. No writes except the report. Report to data/kun-config-inventory/report.md AND copy to BRANDON-COMPUTE-COMMS/from-brandon-compute/Kun-Lane-B-config-inventory.md

# Setup
This is a SCOUT task. Read config files only. No credential access, no changes.

# Rules
1. Never push or write outside this worktree and the two report paths.
2. Report status by: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/kun-config-inventory.status'`
   States: working, needs-decision, blocked, paused, done, failed.
3. If blocked twice, append `blocked [at=<epoch>]: {why}` and stop.
4. Never stop the no-mistakes daemon.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/kun-config-inventory.inbox'/*.msg. Move handled to inbox/handled/.

# Definition of done
Report must identify: current concurrency values, safety cap settings, installed plugins with sources, and config file paths.
Write to: `/home/hd2admin/kun-agent-workspace/data/kun-config-inventory/report.md`
Copy to: `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/Kun-Lane-B-config-inventory.md`
Append `done [at=<epoch>]: {one-line conclusion}` to status file.

# Home brief additions
## Pi Worker Defaults
- Create one concise checklist with Pi's `todo` tool at task start.
- Use lean-ctx for shell output; find it at ~/.local/bin/lean-ctx if not on PATH.
- Use MiniMax-M2.7 for routine reading.
- If a capability is unavailable, report the exact gap.
