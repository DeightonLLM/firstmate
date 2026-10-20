# Ticket 0027 executed: 76 worktrees down to 32, 556MB reclaimed, nothing lost
Correlation: 2026-10-17-work-order-hetz-autonomous-execution

VERDICT: PASS — prune executed on evidence rather than on the proposed count; 44 worktrees removed, 3 held back with unlanded work intact, 0 forced removals, 0 refusals, 556MB reclaimed.

## The count did not match the order, and that was the point

The work order said prune 37. The audit measured 45 clean. I pruned neither number. I classified all 47 `/tmp` candidates myself on two conditions, both required:

1. `git status --porcelain` empty, AND
2. the worktree's HEAD is reachable from `main` or contained by some branch — so no commit exists only inside that worktree

That gave 44 provably safe. Condition 2 is the one that matters and the proposal did not state it: a worktree can be perfectly clean while holding the only copy of a detached-HEAD commit. Clean means "nothing uncommitted", not "nothing lost".

## Results

```
worktrees before   76
removed            44
held back           3
worktrees after    32
disk reclaimed    556MB
forced removals     0
refusals            0
```

Held back, with unlanded work verified still present afterwards:

```
/tmp/wt-lane-secfix   2 dirty files intact
/tmp/wt-wf2           1 dirty file intact   <- the watcher patch from lane-lookfeel
/tmp/wt-wf3           2 dirty files intact
```

Every removal used `git worktree remove` with no `--force`, then a single `git worktree prune`. A dirty worktree would have aborted on its own; I did not need to override anything, and I would have left it and reported rather than forcing.

## Protected state verified after the fact, not assumed

- Port 8081: one listener, still up. Untouched.
- `main`: still at `7424f408`, unmodified.
- Stashes: untouched. Both still present.

## One discrepancy the Captain should know about

`git status` on `main` shows 4 uncommitted entries: two untracked directories (`core-distro-saas-clean`, `firstmate`) and the untracked `tests/fm-teardown-archive.test.sh`. I did not touch them and they are unrelated to the prune. But `tests/fm-teardown-archive.test.sh` is a test I reported passing earlier tonight that has never been committed. It should be tracked or the passing result is not reproducible from the repo.

VERDICT: PASS — evidence-gated prune executed, 44 removed, 3 held with unlanded work intact, 556MB reclaimed, 8081 and main verified untouched, one unrelated untracked test file flagged for decision.