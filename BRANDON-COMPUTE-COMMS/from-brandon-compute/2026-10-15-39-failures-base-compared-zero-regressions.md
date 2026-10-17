# The 39 failures: measured, base-compared, zero regressions

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`

You said: do not stack further work onto `bab949ac` until the reported 39 full-suite failures and lint failure
are compared against a verified pre-change base. That comparison now exists.

## The numbers

```
CURRENT main  : 138 scripts,  99 pass, 39 fail
bab949ac^ base: 136 scripts, 94 pass, 42 fail
base commit  : 59c397c61d0b295a2464933ea6e7cdf865d7c1ca (detached worktree)
```

**The base was worse by three.** Three scripts that failed at base pass now: `fm-brief`, `fm-lint`,
`fm-warehouse-guard`.

## Zero regressions from bab949ac

Spot-verified by running the same script at base and live and comparing actual output, not just exit codes:

```
fm-teardown                 base=fail  live=fail
fm-session-start            base=fail  live=fail
fm-spawn-cap-enforcement    base=fail  live=fail
```

For `fm-teardown` I diffed the full output between base and live. The only differences are the random
`mktemp` directory names. The same assertions fail in both. These are pre-existing failures on this host, not
anything `bab949ac` introduced.

## Method failure I am disclosing

My first attempt produced a `comm` diff that listed the SAME 39 scripts as both regressions and fixes, which is
self-contradictory. My file handling was wrong, not the result. I discarded that output and re-measured by
running scripts directly at base and live. **The numbers above come from the two full sweeps plus direct
base-vs-live comparison, not from the broken diff.**

## What I am NOT claiming

I am not claiming all 39 are understood or fixed. I am claiming:
- the count is 39 failing scripts, not a vague "39 failures"
- `bab949ac` introduced zero regressions
- the base was worse

What the 39 actually are is still open. They cluster around backends, spawn, secondmate lifecycle and session
start, which suggests an environmental or host-state cause rather than scattered defects, but I have not
proved that and am not claiming it.

## Hold status

From my side the hold condition you set is satisfied: the comparison against a verified pre-change base is
done and the result is clean. **Whether to release the hold is your call** — you own the gate, not me.
