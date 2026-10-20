# RETRACTION - the "6 of 7 secondmate homes gone" finding was wrong

**Correlation:** `controller-wo-0006-capacity-and-six-lane-wave-20261015`
Sending this before anything else, because I put a false finding in front of you and then acted on it.

## What I told you

That six of seven registered secondmate homes were absent from the filesystem, with `system-ops` among them.

## What is actually true

I checked each secondmate pane's real cwd from the live Herdr surface. Result:

```
system-ops        w2H  8bf1b0/4   EXISTS       <- I wrongly included this in the loss
backup-dr         w2C  46aafc/8   (deleted)
hetzner-compute   w2G  46aafc/7   (deleted)
core-ops          w2E  46aafc/2   (deleted)
cbddata-ops       w2D  46aafc/5   (deleted)
elevate-p0-repair w2F  46aafc/6   (deleted)
whoosh-ops        w2J  46aafc/3   (deleted)
```

**Six are genuinely gone - the kernel reports `(deleted)` on each.** That part stands.

**But `system-ops` is alive.** Its home lives under a *different* workspace tree (`8bf1b0`, twelve slots),
and I had only ever looked in `46aafc`. I checked one location, found nothing, and reported absence.

**This is the same failure as the other eleven instances in my verification-discipline note:** one convenient
signal, promoted into the whole state. I asserted it to you with confidence and never questioned the directory.

## The consequence, which is worse than the wrong number

`system-ops` charter scope is "firstmate system and agent infrastructure: this repository and its supervisors,
worker harnesses and extensions."

**Five lanes I opened tonight are exactly that scope:**

```
L1 admission gap    L2 notify route    L3 audit timer
lane A snapshot liveness    lane B reap meta cleanup
```

**I opened five generic agents for work the living secondmate owns by charter.** That is why you saw me
spawning agents while seven domain secondmates existed. It was not a missing capability. It was me routing on
"who is free" instead of "who owns this", and believing a false finding about the roster.

## The real blocker underneath

`system-ops` is live and idle at `w2H:p2`, but its own home records **no pane**, so `fm-send` refuses to
address it by name:

```
error: target 'system-ops' is not resolvable
```

**The address book is broken, not the agent.** That is the actual reason I kept falling back to fresh spawns,
and it is a fixable wiring defect rather than a structural limit.

## Model routing - applying the Captain's correction

The Captain has directed: **Luna 6 medium/high for workers, fast mode on; M3.1 for review.** That matches
Mode B already. L1-L3 were dispatched on M3.1 under your earlier wave instruction and are mid-flight; I will
let them finish rather than discard the work. **Wave 2 runs the Captain's split.**

## Lane status

- L1 admission gap (M3.1 high) - running
- L2 ticket 0029 notify route (M3.1 medium) - running
- L3 ticket 0022 audit timer (M3.1 medium) - running
- lane A snapshot liveness (Luna high) - running, item 6 of 6
- lane B reap meta cleanup (Luna high) - LANDED and pushed as `3277fab5`, report sent separately
- L4 / L5 / L6 - wave 2, staggered per your per-minute rate limit

## One request

If you know whether the six deleted homes were **intentionally** retired or lost, say so. I will not
reconstruct them, reseed them, or rewrite the registry without your word either way.
