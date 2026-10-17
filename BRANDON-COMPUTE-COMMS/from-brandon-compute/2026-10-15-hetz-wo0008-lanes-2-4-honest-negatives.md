# WO-0008 lanes 2-4 delivered - all three refused to claim an unearned pass

**Correlation:** `controller-wo-0008-prd-work-20261015`

Reporting each as it landed. Three of four complete; Whoosh still running.

## Core-Distro (65 lines)

```
VERDICT: staging blocker list and dependency order ARE reachable as a bounded evidence report,
and the artifact self-check is reachable (19/19 OK); staging recovery and acceptance of ticket
0017's historical byte identity are NOT reachable today. The serving host remains UNKNOWN.
```

**19/19 checksums OK**, re-verified on the exact artifact on disk. It did **not** re-grant acceptance:
byte identity with the historically reported artifact still cannot be proven, because `SHA256SUMS` is
generated from those same files. It recorded that as NOT reachable rather than quietly rounding up.

**The serving host stays UNKNOWN, as instructed.** It did not resolve it from DNS, PTR, or a legacy
alias, and it did not touch the three retained branches.

## CBD-Data (61 lines)

```
VERDICT: the public homepage was reachable (HTTP 200), but current production data/application
correctness and export-worker health are UNVERIFIED because the authorized worktree contains no
CBD-Data application or worker code, and the production verification/export paths could not be run
within the stated safety and work-boundary constraints.
```

**This is the honest failure I asked for.** The PRD documented this as complete; the worker found there
is **no application code in the authorized worktree at all**, so documentation completion is provably
not production validation. It declined to write to production to manufacture a result.

**Documentation said done. Reality says there is nothing there to run.** That gap is the finding.

## Elevate (33 lines)

```
VERDICT: BLOCKED - before and after measurements are unchanged; workspace state and staging-only
identity remain UNVERIFIED, so no repair is claimed.
```

It recorded the measurement as unchanged rather than claiming a repair it could not evidence. No
production write to `elevatesci.com`, no new credentials.

## The pattern across all three

**Not one of them converted UNVERIFIED into PASS.** Each named exactly what it could not check and why.
Three lanes, three honest negatives, zero manufactured successes.

**And a correction to my own brief-writing:** I sent these workers into worktrees that may not contain
the applications their tickets describe. That is my error in scoping, and it is why CBD-Data and Elevate
came back UNVERIFIED rather than completed. **The blocker is a location problem, not an execution
problem.**

## Also confirmed and unchanged

- `srv1137994` / `animovps` / Aminolifesciences: untouched, unprobed, unrouted.
- KVM1 = HD2 main WordPress site; not `elevatesVPS`, not `srv1137994`. Corrected registry noted.
- Core staging host: **UNKNOWN**, correctly left unresolved.

## Next

Whoosh is still running - establishing whether a Whoosh application exists at all. I will report it the
moment it lands, and I will pass on a negative result as readily as a positive one.
