# WO-0006 L1 — worker admission gap (HIGHEST LEVERAGE)

**Model:** MiniMax M3.1, effort **high**. **Worktree:** `/tmp/wt-wo0006-l1`, branch `wo-0006/l1`.

## Why this lane exists

Five tasks across three days could not run their own tests, and could not even run `bash -n`, because the
shell/tool sandbox refused. This lane gates more of the rest of the queue than anything else in WO-0006.

## Native visible To-Do list — REQUIRED, do this first

Create a visible To-Do tracker in your harness's To-Do extension with **at least five items** and a real
dependency chain, each prefixed `WO-0006-L1:`:

1. `WO-0006-L1:` preflight - reproduce the refusal, capture the exact denial text and exit code
2. `WO-0006-L1:` scoped discovery - find every allowlist/permission source consulted during worker exec
3. `WO-0006-L1:` write the RED test - out-of-scope path is refused (must FAIL before any fix)
4. `WO-0006-L1:` GREEN - implement the narrow admission
5. `WO-0006-L1:` postflight - prove narrow scope held, paste verbatim output, commit on your branch

Keep it visible and update it at every phase change. A prose plan is not a substitute.

## The assignment

Deliver a **narrow, tested** admission for exactly this: **a worker may syntax-check and run its own colocated
test suite inside its own worktree, and nothing broader.**

**Explicitly NOT in scope. All of these are refusals you must preserve, not bugs to fix:**

- No blanket bash
- No global widening
- No path escape outside the worktree
- No credential access
- No weakening of the decision-hold, secret-scan or scope gates

**RED then GREEN.** You must include a test proving that a genuinely out-of-scope path is *still* refused.
A fix that makes everything pass is a failed lane.

## The honest escape hatch

**If the honest answer is that this needs a firstmate change on the Controller side, say so and deliver the
failing test as the specification.** Do not invent a local workaround, do not route around a denial, and do
not weaken a guard to make your own tests run. A clear "this cannot be fixed locally, here is the spec and the
red test" is a SUCCESSFUL lane, not a failure.

## Rules

- Work ONLY in `/tmp/wt-wo0006-l1`. Never touch the live home, `projects/`, secondmate homes, or the warehouse.
- Commit on branch `wo-0006/l1`. Do not merge, push, or rebase main.
- Every claim needs **verbatim** command output, not a summary.
- If bash is denied, that IS the finding - record it and stop. Never try another tool to get around it.

## Report

`data/wo-0006-l1-admission/report.md` - the exact denial reproduced, the discovery, the red test showing
failure before, the green test showing pass after, the out-of-scope refusal still intact, and one line
stating whether the gap is closed locally or needs the Controller.

Use an explicit `[key=<slug>]` on any `blocked:` or `needs-decision:` line. Your chat reply is not the
deliverable.