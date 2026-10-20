---
name: handover
description: Prepare a fleet home for a Captain handover or session change. Use when the Captain says handover, hand over, swap session, step away from the keyboard, or asks to tidy before he leaves - and BEFORE any /new, /resume, context reset, or stow. Must leave the home land-reaped-tidy, never mid-merge.
metadata:
  internal: true
---

# Fleet handover: land, reap, then hand over

A handover is only safe if the home is TIDY at the moment of the handover. A lane that finished but was not landed, or a worktree nobody reaped, is a landmine the next session steps on. Tidy BEFORE handing over, not after.

## Order matters: land, reap, verify, hand over

1. **LAND everything finished.** Working tree clean, no uncommitted changes in the primary checkout. If the tree is dirty, that is unfinished work: capture it to a branch (`git checkout -b fm/preserve-<reason>-<date>`, `git add -A`, commit with the pre-tidy HEAD in the message) BEFORE touching anything. Never discard.
2. **REAP every finished lane** whose work has landed: `bin/fm-teardown.sh <task>`. Teardown fails closed on unlanded work - that refusal is correct, land first. After teardown, update `data/backlog.md`: move the task to Done, keep Done to the 10 most recent.
3. **VERIFY clean:** `git status --porcelain` empty; `git log --oneline -3` readable; no `.lock` pinned to a dead pid; watcher beacon fresh.
4. **HANDOVER STATE** into the durable record: what landed (shas), what is in flight, what is queued and why, rollback paths, and any Captain decision still pending.

## Hard rules
- LAND IS THE DEFAULT. Finished work merges; dropping needs a reason.
- Never `--force`, never `git reset --hard`, never discard uncommitted work. Preserve to a branch.
- Record a dated rollback BEFORE every merge.
- A stash is not preservation. A branch or a commit is.
- Do not kill panes or processes to look tidy; reap through the sanctioned teardown.
- If a lane is mid-edit, leave it and say so in the handover notes. A half-told state is honest; a falsely tidy one is not.

## Supervisor note
If the handover means the current harness session ends, re-arm the watcher first (`bin/fm-watch-arm.sh --restart` as a tracked background task) so supervision survives the transition, and confirm the session lock points at a LIVE harness pid.
