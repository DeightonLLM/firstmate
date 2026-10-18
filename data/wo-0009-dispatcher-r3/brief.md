# WO-0009 dispatcher r3 - build it against FIXTURES you create, not gitignored state

**Model:** openai-codex/gpt-6-luna, effort **high**. **Worktree:** `/tmp/wt-wo0009-disp-r3`, branch `wo-0009/dispatcher-r3`.

## Why r3 exists
r2 blocked because `data/backlog.md` and `config/crew-dispatch.json` are **gitignored and cannot exist in
a clean worktree.** That was my briefing error. **You will not be given those paths again.**

**You will build fixtures yourself, inside this worktree, and commit them.**

## Native visible To-Do list - REQUIRED first
Five or more items, real dependency chain, each prefixed `WO-0009-D3:`:
1. preflight - read `bin/fm-dispatch-guard.sh` and its tests
2. create committed fixtures representing backlog records and charter scopes
3. RED test for the selector defect below
4. GREEN - implement
5. full-suite regression run, commit

## The real defect r2 found - fix this first

> The existing selector skips every ticket marked `blocked-by:` without resolving whether its dependency
> is complete.

**A ticket blocked on something already finished is skipped permanently.** That is a live bug in
shipped code.

Required behaviour:
- `blocked-by: X` where **X is Done** -> the ticket IS eligible
- `blocked-by: X` where **X is open or blocked** -> not eligible
- unresolved dependency -> refuse, never silently skip
- **RED then GREEN.** The test must fail against today's code and pass after. Show both runs.

## Fixtures you must create and commit
- a backlog fixture set covering: no blockers, satisfied blocker, unsatisfied blocker, chained blockers
- a scope fixture covering: a ticket whose charter scope matches a registered owner, and one that matches none

Put them under `tests/fixtures/` so they are committed and reproducible. **Do not reference
gitignored paths.**

## Shell
`bash <script>` RUNS. `bash -c` and `python3 -c` are still BLOCKED - use script paths.

## Hard rules
- **Do not weaken any existing guard.** No bypasses, no blanket permissions, no path escapes.
- Refuse ineligible tickets rather than skipping them silently.
- Extend what exists. **Do not build a second dispatch system, board, or backlog.**
- No credentials, no production, no DNS, no registrar.
- **Never touch `srv1137994` / animovps / Aminolifesciences / elevatesVPS in any form.**

## Rules
- Work ONLY in /tmp/wt-wo0009-disp-r3.
- Commit on branch wo-0009/dispatcher-r3. **No merge, no push, no rebase of main** - the Captain owns merges.

## Report
data/wo-0009-dispatcher-r3/report.md with RED output, GREEN output, full-suite PASS/FAIL counts, and one
line stating whether a satisfied `blocked-by` ticket is now correctly eligible.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
