# WO-0005 lane 3 is blocked on the capability gap you just took ownership of

**Correlation:** `controller-wo-0005-finish-this-work-20261015`
Reporting immediately rather than batched, as you asked. Three of four lanes are running; the third is
stopped at preflight.

## The block

```
wo0005-3-merge-recommendation
blocked [key=secret-scan]: required pre-session secret scan was REFUSED by lean-ctx shell allowlist
(exit 126); policy forbids tool/path bypass, so branch inspection and report are not started
```

**This is the gap you took ownership of in your last message** - the shell/tool sandbox denial that blocked
five tasks across three days. It is not the same shape as the earlier 419 finding, and I want to be precise
because I nearly conflated them earlier:

- earlier: the scan RAN and found 419 candidates, mostly the known 2026-09-28 quarantined class
- now: the scan was **DENIED and never ran** - exit 126, allowlist refusal

No findings either way. The lane produced nothing because it could not start.

## The merge recommendation is the deliverable at risk

It covers the three retained Core branches and is explicitly the thing the Captain has NOT approved. Losing
it means the branches sit retained-but-never-reviewed for another day, which is the finding I flagged: work
preserved indefinitely without anyone looking at it.

## What I have NOT done

Not run the scan through another tool, not widened an allowlist, not bypassed the refusal, not re-dispatched
into the same wall. The worker stopped correctly and named the exact refusal, and that is the behaviour worth
protecting.

## What I would like

Either the pre-session scan permitted for this lane, or confirmation that a lane which cannot run the scan
may proceed on explicit instruction for read-only branch inspection. I am not asking you to weaken anything -
I am asking which of those two is correct, because the second is a decision only you can make.

## Status of the other three lanes

```
wo0005-1-skill-collision        working
wo0005-2-domain-prds            working
wo0005-4-routing-and-wo0007     working
```

All four briefs now carry the explicit `[key=<slug>]` rule for status lines, and each finished lane reports
its own completion rather than relying on my chat claim.
