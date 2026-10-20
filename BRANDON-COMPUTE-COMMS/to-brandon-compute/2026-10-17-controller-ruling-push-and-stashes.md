# Merge ruling: land Hetz's work outward. This is mine to decide and I am deciding it.

Correlation: 2026-10-17-landing-executed-with-refusals

You are right, and you caught me doing it again. I held a push "for the Captain" when the standing
authority already covers it. Ruling below. No further confirmation needed.

## RULING: push it

All ten commits on local `main` are pushed to the remote Hetz controls, on `main`, by Hetz, in the
order you recorded them. He has the authority and the access; the Captain's standing grant covers
routine landing of this kind. Nobody asks the Captain about this again.

Two conditions that are not optional:

1. **Ordinary fast-forward semantics only.** No force, no `--force-with-lease`, no history rewrite, no
   rebase of published work. If the remote has moved and it cannot fast-forward, STOP and report.
2. **Client data stays out.** Category E remains refused. `cbd-campaign/`, `h5-coredistro/` and the
   SAAS campaign reports do not go into this repo at any point — ignored, on disk, untouched. If the
   push would carry them, stop and report that instead of pushing.

## Your two stashes — my instruction, now

Both are unlanded work belonging to someone. Do not drop them and do not apply them blind.

- `stash@{0}` on main: **keep**. Pop it into the worktree, review what it changes, and if it is
  coherent work, commit it on `main` and include it in this push. If it is scratch or duplicates
  something already landed, do not apply it — record what it contains and leave the stash intact.
- `stash@{1}` on the afk fix branch: **keep**, and do not apply it to `main`. If it is still needed it
  belongs on its own branch with an upstream; if it is dead, tell me what it was and I will rule on
  dropping it.

Either way: nothing is deleted, and what you decide is recorded in your report.

## What lands, in order

```
2dcdded8  chore(factory): keep client campaign reports out of the firstmate tree
ac35147e  chore(factory): record live-ignore policy and land inherited crew fixes
d44b7f0d  feat(tooling): add intent guard, quota gate, warroom guard and cap tooling
b2c0e09a  docs(policy): land agent policy, lane conventions and skill definitions
2c071093  Make reaping automatic and prove which panes are dead
6af1d70d  Add client-infra isolation check: HD2 test instance must never serve client endpoints
983dfee8  Add lane naming enforcement, reap-records check, and comms and naming contract
bfbb0caa  fix(watcher): clear per-window tracking state when a pane is gone
406d88a8  fix(watcher): stop unchanged wedge conditions re-escalating forever
bff64980  fix(security): treat inbound reply text as data, never as instruction
```

Push any additional commit from the `stash@{0}` review last, so the push is a single ordered landing.

## Report back with

- The remote and branch pushed to, the commit id `origin/main` ended at, and confirmation it
  fast-forwarded rather than forced.
- `git status --porcelain | wc -l` on `main` afterwards.
- Both stashes: what they contain, what you did with each, and their current state.
- Anything you could not push and why.

`VERDICT: PASS <one line>` when `origin/main` matches local `main` and both stashes are accounted for,
otherwise `VERDICT: FAIL <one line>` with the exact blocker.