# Task
## Captain's intent
Fix the recurring Firstmate controller supervision failure where the watcher remains apparently owned but its heartbeat stops advancing, preventing automatic recovery. The issue: arm parent PID waits in do_wait, watcher PID blocked in pipe_read, lock symlink shows exact owner match, but heartbeat is stale. Reproduce in a disposable fixture, implement the smallest deterministic fix, prove exactly-one-cycle behavior and safe stale-owner recovery. TDD red/green/refactor required. No merge.

Supplemental evidence at: `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-03-controller-watcher-stall-second-occurrence.md`

Key evidence from controller:
- arm parent PID 1637272 running `fm-watch-arm.sh --restart`, waiting in do_wait
- watcher PID 1637287 blocked in pipe_read
- lock symlink target state/.watch.lock.owner.4kCG50, pid=1637287, pid-identity exactly matches watcher
- .last-watcher-beat stale (>7 minutes old)
- Terminating ONLY arm parent PID allowed Pi to auto-restart fresh arm+watcher, beat advanced
- No broad kill, second arm, or source change resolved it

The fix must be in tracked Firstmate source, not live controller processes.

## Firstmate spec
- Role: ship with TDD red/green/refactor
- Mode: no-mistakes (PR path)
- Model: gpt-6-luna xhigh if available
- Target: Firstmate repo in isolated worktree
- DO NOT touch live controller processes, /root/.pi/agent, or system-ops owned files
- Scope: only fm-watch-arm.sh and fm-watch.sh source fixes

# Setup
You are in a disposable git worktree of the firstmate repo. This is a SHIP task with no-mistakes pipeline. Create isolated test fixtures that reproduce the wedge, implement smallest fix, prove green. Do not merge.

# Rules
1. Never push to any remote and never merge.
2. Stay inside this worktree; only write the report and status file outside it.
3. Report status by: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/controller-watcher-tdd.status'`
   States: working, needs-decision, blocked, paused, done, failed.
4. If blocked twice, append `blocked [at=<epoch>]: {why}` and stop.
5. Never stop the no-mistakes daemon.
6. Run no-mistakes pipeline before reporting done.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/controller-watcher-tdd.inbox'/*.msg. Move handled to inbox/handled/.

# Definition of done
Write report to: `/home/hd2admin/kun-agent-workspace/data/controller-watcher-tdd/report.md`
AND copy to: `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-03-controller-watcher-heartbeat-fix.md`
Report must include: RED test evidence, GREEN fix evidence, REFACTOR evidence, no-mistakes PR URL, and any residual limitations.
Append `done [at=<epoch>]: {one-line conclusion}` to status file when complete.

# Home brief additions
## Pi Worker Defaults
- Create one concise checklist with Pi's `todo` tool at task start. Keep exactly one step active; update in place.
- Use lean-ctx for shell output; find it at ~/.local/bin/lean-ctx if not on PATH.
- Use gpt-6-luna for difficult implementation.
- If a capability is unavailable, report the exact gap.
