# WO-0006 L2 — ticket 0029: silent notify failure

**Model:** MiniMax M3.1, effort **medium**. **Worktree:** `/tmp/wt-wo0006-l2`, branch `wo-0006/l2`.

## Native visible To-Do list — REQUIRED, do this first

At least five items, real dependency chain, each prefixed `WO-0006-L2:`:

1. `WO-0006-L2:` preflight - reproduce both defects with quoted output
2. `WO-0006-L2:` scoped discovery - read `bin/fm-hetz-send.sh` and the registry id it should resolve against
3. `WO-0006-L2:` write the RED tests - unresolvable route fails, absent inbox fails
4. `WO-0006-L2:` GREEN - fix both, in-repo
5. `WO-0006-L2:` postflight - prove the guarded contract survived, paste output, commit

## The two defects

1. `bin/fm-hetz-send.sh` **hardcodes a notify route that does not resolve against the registry id**, and
   **swallows the error** so delivery reports success while nothing is ever notified.
2. Its **default remote inbox does not exist on this host.**

**Fix both in-repo, with tests.** An unresolvable route and an absent inbox must **fail loudly** instead of
silently succeeding.

## Do NOT weaken the guarded notification contract

These are the guarantees a reviewer depends on. Preserve every one:

- Never interrupt a working or blocked recipient
- Never send Ctrl-C or Escape
- Keep the content-hash dedup
- Keep the durable pending queue

A fix that makes delivery "work" by removing a guard is a failed lane. If you cannot fix the route without
touching those guards, say so and deliver the red test as the spec.

## Rules

- Work ONLY in `/tmp/wt-wo0006-l2`. Never touch the live home, `projects/`, secondmate homes, or the warehouse.
- Do not send any real notification to any real recipient while testing. Use a temp target.
- Commit on branch `wo-0006/l2`. No merge, no push, no rebase of main.
- Every claim needs verbatim command output.

## Report

`data/wo-0006-l2-notify-route/report.md` - both defects reproduced, red-then-green tests, proof the guards
survive, one line stating whether silent success is now impossible.

Use an explicit `[key=<slug>]` on any `blocked:` or `needs-decision:` line.