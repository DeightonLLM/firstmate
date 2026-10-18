# Task
## Captain's intent
Read-only study of public Kun/high-throughput sources to identify the exact config key for agent concurrency, plugin names, compatibility, and data/security effects. Target sources: YouTube video `https://youtu.be/MSbacZ99E14`, GitHub repos `kun`, `gnhf`, `backpass`. Extract: config key name, expected value (operator requests 50), whether it bypasses any required safety cap, plugin list with source URLs and permissions, and any security/data implications.

## Firstmate spec
Read-only lane. No writes except the report. Report to data/kun-video-source-study/report.md AND copy to BRANDON-COMPUTE-COMMS/from-brandon-compute/Kun-Lane-A-video-source-study.md

# Setup
This is a SCOUT task. Read public sources only. Use curl or yt-dlp for video transcript if available. No credential access.

# Rules
1. Never push or write outside this worktree and the two report paths.
2. Report status by: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/kun-video-source-study.status'`
   States: working, needs-decision, blocked, paused, done, failed.
3. If blocked twice, append `blocked [at=<epoch>]: {why}` and stop.
4. Never stop the no-mistakes daemon.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/kun-video-source-study.inbox'/*.msg. Move handled to inbox/handled/.

# Definition of done
Report must identify: exact config key, value, safety implications, plugin list, source URLs, and security notes.
Write to: `/home/hd2admin/kun-agent-workspace/data/kun-video-source-study/report.md`
Copy to: `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/Kun-Lane-A-video-source-study.md`
Append `done [at=<epoch>]: {one-line conclusion}` to status file.

# Home brief additions
## Pi Worker Defaults
- Create one concise checklist with Pi's `todo` tool at task start.
- Use lean-ctx for shell output; find it at ~/.local/bin/lean-ctx if not on PATH.
- Use MiniMax-M2.7 for routine reading; gpt-6-luna for difficult analysis.
- If a capability is unavailable, report the exact gap.
