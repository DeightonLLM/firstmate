# 2026-10-15 — the night's record

One page. What was delivered, what was wrong, and what is still open.
Every claim here traces to a command, a commit, or an audit report in `data/`.

## Delivered and verified — 19 commits on origin/main

| commit | what it fixed |
|---|---|
| `bab949ac` | brief `--worklocation` — amends the brief, **not** the tool sandbox (still incomplete) |
| `b670beca` | outbound hash ledger, so our own mail is never read as a reply |
| `e8cb0090` | warehouse write guard, 13/13 tests |
| `59c397c6` | mechanical warehouse submission manifest |
| `f941d893` | fresh-agent baseline scope labels — **corrects my own regression** |
| `fe14dad7` | transmission enforcement + per-provider cap recovered from a dead worker, 19/19 |
| `973ff553` | checksum-verified order delivery, recovered from 3 Oct, 9/9 |
| `69dfbffc` | wake-drain loop regression test, recovered from a worktree |
| `0e8b1401` | `fm-scope-check.sh` fail-closed scope gate, 6/6 |
| `358e39a3` → `46768547` | wake-drain contract — **added then reverted at Controller's direction** |
| `2da3696d` | docs index, 120 files |

Plus, unwritten to a commit: `bin/fm-to-controller.sh`, `bin/fm-controller-pending.sh`,
`state/controller-pending.check.sh`, `bin/fm-gate-escalation-order.sh`.

## The root cause, nine times

**One convenient signal was treated as the whole state.**

```
tmux empty        → "no agents"           deleted 20 LIVE records
note written      → "sent"                nothing was sent
branch commits    → "landed"              not in main
idle pane         → "done"                reaped a captain-held hold
annotations       → "the wake queue"      the raw rows are authoritative
ls of slot dirs   → "16/16 full"          12 were already gone
commit count      → "17 features"         16 nightly mail syncs
status line       → "landed"              9601685d: true claim, unverified evidence
first file found  → "the report"          copied a stale 8KB over a good 19KB
```

The workers were right every time. Each refusal named a real hazard. **I was the one guessing.**

## Retracted after audit

| claim | outcome |
|---|---|
| `9601685d` "not landed" | **I over-corrected.** Not an ancestor, but the work IS present by another route. My original claim was true; my evidence was a status line. |
| "five experts can't read own files" | **wrong in substance.** 4 of 6 were absent directories, not permission errors. |
| 12 worktrees safely removed | **UNVERIFIED**, honestly. `git fsck` shows unreachable objects — recovery may still be possible until gc. |
| decision-hold gate "blocking the team" | **wrong.** A stale `default` key, not a gate defect. |

## Open — and none of it mine to decide

1. **Six of seven secondmate homes are GONE.** Not misregistered. The seven-lane model is one real lane.
2. **Stale `default` decision key** blocking scout completions. Needs one command from Controller.
3. **Unreachable git objects** — may hold deleted work. **A gc would erase the recovery window.**
4. `c51cf8d9` — obsolete, needs an explicit drop decision.
5. `--worklocation` incomplete: amends the brief, not the sandbox root.
6. Worker shell allowlist denies test execution, including `/bin/bash`.

## What actually works now

- Five inbound routes watched, content-hash deduplicated, proven by canary
- Controller transmission is atomic and unsent notes **wake the watcher**
- A fail-closed scope gate that refuses the exact misroute I made tonight
- Idle-aware lane counting, so idle panes don't consume budget
- 4+ parallel lanes running real work

## For the next Firstmate

Read `docs/README-index.md` first. Then `docs/verification-discipline.md`, which
carries the nine instances above as a pattern rather than nine anecdotes.

**One observation is not a state.** That is the whole lesson of this night.