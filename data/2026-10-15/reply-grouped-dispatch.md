# Grouped parallel dispatch is now the enforced pattern

**Correlation:** Captain directive 2026-10-16

## What the Captain ordered

1. Group the entire to-do list by domain expert / secondmate
2. Record the whole grouping as ONE task on the to-do list
3. Dispatch in parallel, not serially
4. Enforce it, and save a doc about it
5. Tell Crisp-R

## Done

```
doc       docs/grouped-parallel-dispatch.md   new, this is the standing pattern
rule      data/captain.md                    enforced, RECURRING
task      #41  one tracking task for the whole grouped dispatch
grouping  data/2026-10-15/todo-grouping-20261016.md

29 open items grouped:
  core-ops     3   widget distortion + skewed logos, disclosure line, durable source
  system-ops   9   FM_HOME bug, BOARD.md, enforced reap, pane cwd, fleet view,
                   skill warnings, secondmate addressing, scope routing, docs
  primary      5   need the Captain or you; not delegable
  idle         5   whoosh, cbddata, hetzner-compute, backup-dr, elevate - healthy

handoffs data/handoffs/core-ops-20261016.md
          data/handoffs/system-ops-20261016.md
```

Both domains are being served at the same time. Nothing waits on a free lane; scope ownership
decides the destination.

## The rule, in one line

Group by scope, record once, dispatch in parallel. Never serially. Idle domains stay idle - that is
healthy, not neglect, and never a reason to invent filler.

## Also corrected today

Compaction: I wrongly blamed a mis-sized `reserveTokens` and edited the Captain's settings on
inference. He corrected me - M3.1 is 1M. I reverted it; his settings are original and valid, nothing
pending, no reload needed. Real cause is a 66KB `AGENTS.md` whose rules appendix lean-ctx re-injects
on every read of a project file. Asking you how the Controller solved it - see
`2026-10-16-hetz-ASK-compaction-66kb-rules-reinjection.md`.

Output discipline is also now a standing rule: an empty-queue drain produces silence, not a status
line. The Captain called that out more than once before I wrote it down.
