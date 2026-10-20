# WO-0006 L6 RETRY - retained Core branches, CORRECT repository this time

**Model:** openai-codex/gpt-6-luna, effort **high**. **Worktree:** `/tmp/wt-wo0006-l6b`, branch `wo-0006/l6-retry`.

## Why you are running again
A previous lane refused to produce a merge order because the three branches were absent from the
firstmate repo. **That was my briefing error.** They live here:

```
REPO: /home/hd2admin/kun-agent-workspace/projects/core-distro-saas-clean
fm/core-stream-a-checkpoint-0924      tip 676546d  (verified NOT landed)
fm/core-mobile-fix                    tip 349eaaf  (verified NOT landed)
fm/core-v3-product-acceptance-spec-0927 tip 538e4c2 (verified already landed)
```

**READ ONLY on that repo.** Use `git -C <path>` for every command. Do not checkout, merge, rebase,
or write to it in any way.

## Native visible To-Do list - REQUIRED first
At least five items, real dependency chain, each prefixed `WO-0006-L6R:`:
1. preflight - confirm all three refs resolve in the correct repo
2. diff each branch against its merge base
3. per branch: what changes, blast radius, exact rollback command sequence
4. dependency analysis between the three
5. recommended merge order with reasoning, then postflight commit

## Deliverable
Per branch:
- commit-by-commit diff summary
- blast radius: what else is touched, what could break
- **exact rollback** - the precise command sequence to undo a merge
- risk assessment

Then a **recommended merge order** with dependency reasoning.

## Verified facts you must confirm yourself, not inherit
```
git -C <repo> merge-base --is-ancestor <tip> main
```
Confirm landed or not for each. My numbers may be wrong - I have been wrong about locations twice
tonight. Re-derive everything.

## INSPECTION AND WRITE-UP ONLY
**NO MERGE. NO PUSH. NO CHECKOUT onto main. NO WRITE to the project repo.**
This is evidence for a human decision, not authority to act. A recommendation is not a merge.

## Rules
- Work ONLY in /tmp/wt-wo0006-l6b for any file you create.
- Commit on branch wo-0006/l6-retry. No merge, no push, no rebase of main.
- Verbatim git output. Say UNVERIFIED when you cannot check.

## Report
data/wo-0006-l6-core-branches/report-retry.md
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
