# Verification discipline — the second-signal rule

This home has one recurring failure. It is not carelessness. It is a specific, repeatable reasoning error.

## The failure

**Treating one convenient signal as the whole state.**

A signal arrives. It is cheap. It is plausible. It is taken as the answer — and then propagated,
repeated, and reported to the Captain as fact, without ever checking a second source.

## Every instance, with the signal that lied

| # | Signal accepted | What was actually true | Second signal that caught it |
|---|---|---|---|
| 1 | `tmux ls` showed no panes | 17 workers were live | `herdr workspace list` — Herdr is the live surface, tmux is not an agent inventory |
| 2 | A note file existed in the outbox | It was never transmitted | Controller's own inbox directory |
| 3 | Branch had 4 commits ahead | Not one was landed | `git merge-base --is-ancestor <tip> main` |
| 4 | Pane idle | Worker had finished and exited | Pane content **+** status file |
| 5 | `wake annotation:` lines | The raw rows were authoritative | Read the raw tab-separated rows |
| 6 | 27 slot directories in treehouse | The **40** ceiling was never established | Read the live state file; **0 certified** |
| 7 | 18 commits landed | **Not 18 features** | Each commit's actual content |
| 8 | `done:` status line | Report absent | Status line **+** report file |
| 9 | Backlog row existed | Six implied work that never happened | `data/<id>/` artifacts |
| 10 | Backlog label | A label, not progress | Artifact **+** commit |
| 11 | `state/<id>.meta` exists | **17 stale files, 0 live tasks** | Endpoint probe — fixed by lanes A/B |
| 12 | Artifact matched `SHA256SUMS` | Self-referential; proves nothing about identity | A digest recorded independently at hand-off |

## The rule

**Never report state from one signal when a second is available and cheap.**

State plus artifact. Branch plus ancestor check. Pane plus status. File plus content or hash.
Endpoint plus process. Read plus write.

When a second signal genuinely is unavailable, **say UNVERIFIED and name what is missing.** Do not
promote the first signal into confidence. `UNKNOWN` is a valid, honest answer.

## What the workers got right

**Every refusal tonight named a real hazard.** The security scan genuinely found 419 candidates.
The unkeyed status line genuinely opened a stale `default` decision. The shell allowlist genuinely denied
exit 126. The secondmate refusal was genuinely a missing directory, not a permission.

Not one worker invented a failure to look careful, and not one "passed" result was a false green.

**The guessing was mine, every time.** The workers applied this rule. I did not.

## Consequences of breaking it

- Claiming work landed when it was ready in a branch — reported a false completion
- Reporting "13 free slots" from arithmetic on an unverified ceiling
- Marking Gate 8a superseded when only the repair spec was corrected, not acceptance
- Calling a home "clean" because nothing was obviously wrong

Each of these reached the Captain as a fact. The correction cost more trust than the work was worth.

## Related

- `wake-drain-loop.md` — how the drain contract was wrongly looped, then reverted at Controller's direction
- `operating-decisions-2026-10-14-15.md` — the dated decisions
- `data/2026-10-15/INDEX.md` — tonight's evidence index