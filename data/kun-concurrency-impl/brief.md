# Task
## Captain's intent
Implement the Kun-inspired high-throughput setup in Firstmate based on Lane A+B findings. Lane A found: no single concurrency=50 config key exists in Kun ecosystem — "50 cap" is Fable's provider-enforced 50% quota (not configurable). Closest: treehouse.max_trees=50. Lane B found: Firstmate's parallel-dispatch cap=6, no existing concurrency setting, 18 skills, 3 dispatch rules. Determine the correct smallest safe change to implement the operator's intent, add concise coding direction in the authoritative config/docs, and verify plugin load.

## Firstmate spec
- Role: ship with no-mistakes pipeline
- Model: gpt-6-luna xhigh
- Based on: `from-brandon-compute/Kun-Lane-A-video-source-study.md` and `from-brandon-compute/Kun-Lane-B-config-inventory.md`
- If the operator's "concurrency=50" maps to a Firstmate setting that doesn't exist: report the exact conflict and stop with evidence rather than guessing

# Setup
This is a SHIP task. Read Lane A and B reports first. Implement the smallest evidence-supported change in an isolated firstmate worktree. Run no-mistakes pipeline. Do not merge.

# Rules
1. Never push or merge.
2. Stay inside this worktree; only write the report and status file outside it.
3. Report status by: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/kun-concurrency-impl.status'`
   States: working, needs-decision, blocked, paused, done, failed.
4. If blocked twice, append `blocked [at=<epoch>]: {why}` and stop.
5. Never stop the no-mistakes daemon.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/kun-concurrency-impl.inbox'/*.msg. Move handled to inbox/handled/.

# Definition of done
Write report to: `/home/hd2admin/kun-agent-workspace/data/kun-concurrency-impl/report.md`
AND copy to: `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-03-kun-firstmate-high-throughput-implementation.md`
Report must include: video/source citations, before/after config paths, sanitized diff, plugin load verification, TDD evidence, config parse/dry-run evidence, no-mistakes PR URL, and independent checker verdict.
Append `done [at=<epoch>]: {one-line conclusion}` to status file when complete.

# Home brief additions
## Pi Worker Defaults
- Create one concise checklist with Pi's `todo` tool at task start.
- Use lean-ctx for shell output; find it at ~/.local/bin/lean-ctx if not on PATH.
- If a capability is unavailable, report the exact gap.
