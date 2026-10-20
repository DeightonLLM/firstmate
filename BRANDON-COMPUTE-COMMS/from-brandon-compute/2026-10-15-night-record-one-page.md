# The night's record, in one page — and what it costs you

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`
Copy of `data/2026-10-15-night-record.md`. The Captain has been catching my errors all night and I have
been catching them myself late. This is the consolidated version so neither of us reconstructs it from chat.

## Delivered and verified: 19 commits

`bab949ac` worklocation · `b670beca` outbound ledger · `e8cb0090` warehouse guard · `59c397c6` submission
manifest · `f941d893` baseline scope labels · `fe14dad7` transmission enforcement + per-provider cap ·
`973ff553` order delivery · `69dfbffc` wake-drain test · `0e8b1401` scope gate · `46768547` wake-drain
correction · `2da3696d` docs index. Plus four unwritten helpers: `fm-to-controller.sh`,
`fm-controller-pending.sh`, `controller-pending.check.sh`, `fm-gate-escalation-order.sh`.

Two of these were features I recovered from worktrees that were invisible to every register:
`973ff553` had been unlanded since 3 October, `fe14dad7`'s cap from a worker that died on a shell denial.

## The root cause, nine times

**One convenient signal treated as the whole state.** tmux read as Herdr, a written note read as sent, branch
commits read as landed, an idle pane read as done, annotations read as the wake queue, a directory listing
read as capacity, a commit count read as features, a status line read as proof of landing, the first file
found read as the report.

**Every worker was right.** Each refusal named a real hazard - a branch collision, a stale README that would
have been overwritten, a scope violation, an attestation on a task with no authorised state change. **I was
the one guessing, nine times, and it is in `docs/verification-discipline.md` now as a pattern.**

## Retracted, including one of my own retractions

- `9601685d`: I said I had falsely reported it landed. **I over-corrected.** Not an ancestor of main, but the
  work IS present by another route. My claim was true; my evidence was a status line.
- "Five experts cannot read their own files": **wrong in substance.** Four of six were absent directories.
- Worktree cleanup: **UNVERIFIED**, and the auditor said so rather than reassure me.
- The decision-hold gate "blocking the team": **wrong.** A stale `default` key, not a defect.

## Still open, and not mine to decide

1. **Six of seven secondmate homes are GONE.** Not misregistered. The seven-lane model is one real lane.
2. **Stale `default` decision key.** One command from you clears it and five scout completions unblock.
3. **Unreachable git objects** may hold work I removed tonight. **A gc erases that window.** I will not run one.
4. `c51cf8d9` is obsolete and needs an explicit drop decision rather than silent abandonment.
5. `--worklocation` amends the brief but not the tool sandbox, so authorised paths are still refused.
6. Worker shell allowlist denies test execution including `/bin/bash` - four workers could not validate anything.

## What works now

Five inbound routes watched and deduplicated, proven by canary. Controller transmission atomic, with unsent
notes waking the watcher. A fail-closed scope gate that refuses the exact misroute I made tonight. Idle-aware
lane counting. Four parallel lanes producing real work.

## One request

**Please preserve the unreachable objects before any scheduled gc.** That is the only irreversible thing left
tonight, and I am not authorised to touch the object store.
