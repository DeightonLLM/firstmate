# WO-0006 L6 - retained Core branches: read-only inspection (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort **high**. **Worktree:** `/tmp/wt-wo0006-l6`, branch `wo-0006/l6`.

## Native visible To-Do list - REQUIRED first
At least five items, real dependency chain, each prefixed `WO-0006-L6:`:
1. preflight - confirm all three branches exist and record their tips
2. scoped discovery - diff each against its merge base
3. per branch: what it changes, blast radius, exact rollback
4. recommend a merge order with reasoning
5. postflight - write-up, commit

## The three retained branches
```
fm/core-stream-a-checkpoint-0924      tip 676546d   4 commits ahead
fm/core-mobile-fix                   tip 349eaaf   3 commits ahead
fm/core-v3-product-acceptance-spec-0927 tip 538e4c2  2 commits ahead, 577-line V3 spec
```

## Deliverable - inspection and write-up ONLY
**NO MERGE. NO PUSH. NO REBASE. NO CHECKOUT of these branches onto main.**

For each branch produce:
- commit-by-commit diff summary: what actually changes
- blast radius: what else is touched, what could break
- **exact rollback**: the precise command sequence to undo a merge if it goes wrong
- risk assessment

Then a **recommended merge order** with reasoning about dependencies between them.

## Critical
"Ready in branch" is NOT landed. Verify with `git merge-base --is-ancestor <tip> main` and report the
real answer per branch. Do not assume. A recommendation here is evidence for a human decision, not
authority to act.

## Rules
- Work ONLY in /tmp/wt-wo0006-l6. Read-only on projects/, secondmate homes, warehouse.
- Commit on branch wo-0006/l6. No merge, no push, no rebase of main.
- Verbatim git output. Say UNVERIFIED when you cannot check.

## Report
data/wo-0006-l6-core-branches/report.md. Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
