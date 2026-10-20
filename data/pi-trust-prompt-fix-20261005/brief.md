# Task
## Captain's intent
BRANDON pi trust-prompt fatigue fix: pre-seed worktree root pattern trust so Pi does not re-prompt trust on every fresh worktree. Captain route noted (captain 2026-10-04): "brandon pi trust-prompt fatigue fix (pre-seed worktree root pattern trust, backup-then-test) — same standards as the RAG work".

## Firstmate spec
Read-only discovery of the current pi trust-prompt mechanism + a tested approach for pre-seeding trust on worktree root pattern. Backup any mutated files. Test the fix end-to-end. Report findings + VERDICT.

# Setup
This is a SCOUT task + bounded fix. First inventory, then bounded mutation, then verify.

# Rules
1. Never push or write outside this worktree, the report paths, and the inbox/handled directory.
3. Report status by: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/pi-trust-prompt-fix-20261005.status'`
   States: working, needs-decision, blocked, paused, done, failed.
4. Use lean-ctx for all reads, searches, listings, shell output.
5. Use the To-Do List extension with five+ dependency-aware items: preflight, locate pi trust mechanism, draft pre-seed approach, backup affected files, apply + test, report.
6. **BACKUP before any mutation** — name `.bak-pi-trust-20261005` on every file you mutate.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/pi-trust-prompt-fix-20261005.inbox'/*.msg. Move handled to inbox/handled/.

# Definition of done
Report must include:
- VERDICT: PASS / PARTIAL / BLOCKED
- Where pi trust lives in the toolchain (file paths, settings location)
- The pre-seed approach used
- Files backed up (path + sha256)
- Files mutated (path + sha256 before/after)
- Test: prove the fix works (e.g., new worktree no longer prompts, existing workspace still works)

Write to:
- `/home/hd2admin/kun-agent-workspace/data/pi-trust-prompt-fix-20261005/report.md`
- `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-05-pi-trust-fix.md`

Append `done [at=<epoch>]: {one-line conclusion}` to status file.

# Home brief additions
## Pi Worker Defaults
- Create one concise checklist with Pi's `todo` tool at task start.
- Use lean-ctx for shell output; find it at ~/.local/bin/lean-ctx if not on PATH.
- Use Codex GPT-6 Luna medium effort.
- Use MiniMax M3.1 Flash Preview for review.
- Use `which pi && pi --version` and `find ~ -name 'trust*' -type f 2>/dev/null | head -20` as starting points.