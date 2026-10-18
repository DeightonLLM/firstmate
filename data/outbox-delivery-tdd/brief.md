# Task
## Captain's intent
Fix the verified failure where controller work orders were written locally but never reached Brandon's inbox. Establish a tested, idempotent, checksum-verifiable outbound delivery path for explicitly selected Firstmate work orders. At 2026-10-03 04:29Z the to-brandon-compute/ inbox was absent locally, so Elevate and Kun orders existed only remotely. The current Herdr pane inventory has not confirmed worker pickup. Do not treat a local file as delivered without remote receipt evidence.

## Firstmate spec
Use TDD red/green/refactor. Create executable tests for: absent destination, identical idempotent resend, mismatch/no-overwrite, unsafe path, transport failure, and checksum mismatch. Provide remote-inbox verification and a receipt/ack state distinguishing queued/transferred/accepted (a transfer is not worker acceptance). Run focused suite and Firstmate no-mistakes pipeline. Do not merge.

# Setup
You are in a disposable git worktree. This is a SCOUT task: deliver a written report, not a PR. The worktree is your laboratory - install, run, edit freely; discarded at teardown.

# Rules
1. Never push to any remote and never open a PR.
2. Stay inside this worktree; only write the report and status file outside it.
3. Report status by appending: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/outbox-delivery-tdd.status'`
   States: working, needs-decision, blocked, paused, done, failed.
4. If blocked twice on same obstacle, append `blocked [at=<epoch>]: {why}` and stop.
5. Never stop or update the shared no-mistakes daemon.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/outbox-delivery-tdd.inbox'/*.msg in numeric order. Move handled messages to inbox/handled/.

# Definition of done
Write report to: `/home/hd2admin/kun-agent-workspace/data/brandon-outbound-delivery/report.md`
AND copy to: `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-03-firstmate-brandon-outbound-delivery.md`
Report must stand alone with evidence (commands, output, file:line refs), test results, no-mistakes PR URL if created, and independent checker verdict.
Append `done [at=<epoch>]: {one-line conclusion}` to status file when complete.

# Home brief additions
## Pi Worker Defaults
- Create one concise checklist with Pi's `todo` tool at task start. Keep exactly one step active; update in place; rebuild if missing after compaction.
- Before long commands, start the checklist item and print a short progress line. Report result immediately.
- Model routing: use MiniMax-M2.7 for routine work; use gpt-6-luna for difficult/architectural work.
- Use lean-ctx for shell output; find it at ~/.local/bin/lean-ctx if not on PATH.
- Use subagents for independent bounded subtasks; one owner per worktree.
- If a capability is unavailable, report the exact gap and continue useful work in the visible pane.
