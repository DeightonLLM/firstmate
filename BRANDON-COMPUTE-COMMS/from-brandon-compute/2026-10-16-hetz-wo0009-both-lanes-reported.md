# WO-0009 both lanes reported. One committed a real artifact, one found a real bug.

**Correlation:** `controller-wo-0009-dispatcher-20261015`

Report then move, as instructed.

## wo-0009-checklist-r2 - COMMITTED f339506e

The machine-readable acceptance checklist now exists. The Captain's completion numbers were, as I
warned him, **my judgement with an invented denominator.** That denominator now exists and is scored
from the file:

```
acceptance-checklist.json   schema_version 1
formula: 100 * PASS / (PASS + FAIL + UNVERIFIED), N/A excluded
overall: 5.0%  (1 of 20 applicable criteria verified)
```

**It scored itself 5% and refused to soften it.** Its own words:

> Conservative evidence-coverage checklist. **This cannot certify product/domain readiness** because
> the authoritative PRD report is absent from this worktree.

**It also declared UNVERIFIED is never PASS in the formula itself**, so the score cannot be inflated
later by converting unknown into pass.

**The 5% is evidence coverage, not product readiness, and it is correct.** Five sites return HTTP 200;
almost nothing about them is verified against acceptance criteria. The earlier 60% figure I gave the
Captain was optimistic, and this file is the honest counterweight.

## wo-0009-dispatcher-r2 - BLOCKED, and it found a genuine defect

```
The isolated copy is missing data/backlog.md and config/crew-dispatch.json,
so ticket eligibility and charter routing cannot be verified.
```

**My briefing error, third of this class.** Both files are gitignored, so they cannot exist in a clean
worktree. I have now briefed workers at non-existent paths three times tonight - the CBD-Data worktree,
the L6 Core repository, and this. **That is a repeatable failure in how I write briefs and I am
treating it as one.**

**But it did not stop at the blocker. It found a real defect in shipped code:**

> The existing selector also skips every ticket marked `blocked-by:` without resolving whether its
> dependency is complete.

**A ticket blocked on something already finished is skipped permanently.** That is a genuine defect,
independent of the missing inputs, and it is worth fixing on its own.

It added no test, made no implementation, and created no commit, and it asked for the canonical inputs
or authorisation for sanitised fixtures. **That is the correct behaviour under a missing input.**

## What I am doing next, without further authorisation

1. Re-dispatch the dispatcher with **sanitised fixtures checked into the repo**, so it is not dependent
   on gitignored state. That fixes my error rather than working around it.
2. Fix the `blocked-by` selector defect as a separate, small lane.
3. Then the two HIGH findings on `fm-to-controller.sh`.

## Confirmed unchanged

`data/backlog.md` and `config/crew-dispatch.json` are **gitignored and absent from any clean worktree.**
Any future lane brief that references them is wrong on arrival and I will stop writing them that way.

`srv1137994` / animovps / Aminolifesciences: untouched. Staging: one of two Hostinger nodes, one a hard
gate, one unidentified, KVM1 ruled out - **still needs a Captain-authorised node name.**
