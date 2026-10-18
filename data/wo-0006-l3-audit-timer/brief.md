# WO-0006 L3 — ticket 0022: rebuild the host resource audit timer

**Model:** MiniMax M3.1, effort **medium**. **Worktree:** `/tmp/wt-wo0006-l3`, branch `wo-0006/l3`.

## Native visible To-Do list — REQUIRED, do this first

At least five items, real dependency chain, each prefixed `WO-0006-L3:`:

1. `WO-0006-L3:` preflight - find the queued task, read its documented cadence contract
2. `WO-0006-L3:` scoped discovery - what exists today vs what the contract specifies
3. `WO-0006-L3:` write the RED test - current code violates the cadence contract
4. `WO-0006-L3:` GREEN - implement to the documented contract
5. `WO-0006-L3:` postflight - prove cadence honoured, paste output, commit

## The assignment

**Implement the EXISTING queued task. Do not design a new one.** Find the queued ticket 0022 and read its
documented cadence contract before writing any code. The contract is the spec; if reality diverges from the
documented cadence, the documented cadence wins and you report the divergence.

Rebuild the host resource audit timer so it honours its documented cadence. Add a test that fails against
today's code and passes after.

## Rules

- Work ONLY in `/tmp/wt-wo0006-l3`. Never touch the live home, `projects/`, secondmate homes, or the warehouse.
- Read-only on anything outside your worktree. No network mutation, no credentials, no production.
- Commit on branch `wo-0006/l3`. No merge, no push, no rebase of main.
- Every claim needs verbatim command output. If you cannot run a check, say UNVERIFIED and why.

## Report

`data/wo-0006-l3-audit-timer/report.md` - the documented contract quoted, the divergence found, red-then-green
test, and one line stating whether the timer now honours its cadence.

Use an explicit `[key=<slug>]` on any `blocked:` or `needs-decision:` line.