# WO-0009 - build the ticket dispatcher (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort **high**. **Worktree:** `/tmp/wt-wo0009-dispatcher-r2`, branch `wo-0009/dispatcher-r2`.

## Native visible To-Do list - REQUIRED first
At least five items, real dependency chain, each prefixed `WO-0009-DISP:`:
1. preflight - read the existing backlog and dispatch plumbing
2. scoped discovery - what already exists, what is genuinely missing
3. write the RED test for the missing behaviour
4. GREEN - implement
5. postflight - full suite green, commit

## The problem this solves
Work is chosen by **whoever happens to be free at the moment**, not by what the backlog says is next.
That produced, tonight, five lanes opened for work a living secondmate already owned by charter, while
queued tickets sat untouched.

## What to build
A dispatcher that takes the backlog and **selects the next eligible ticket automatically**, and opens
a lane for it, honouring:
- **dependency order** - never start a ticket whose blockers are unresolved
- **scope ownership** - prefer the registered secondmate whose charter owns it; fall back to a generic
  lane ONLY when no scope fits, and record why
- **per-provider concurrency** - never exceed the configured cap
- **explicit BLOCKED handling** - a real gate blocks with a named recovery condition, never a silent stop

## Read before writing
- `data/agent-scopes.tsv` (the machine-readable scope registry, six columns, seven owners)
- `bin/fm-scope-check.sh` (fail-closed scope gate, 6/6 tests)
- `bin/fm-dispatch-guard*` and its test (`tests/fm-dispatch-guard-max-lanes.test.sh`, 19/19)
- `config/crew-dispatch.json` (mode B routing)
- `.tasks.toml` and `data/backlog.md`

**Extend what exists. Do not build a second dispatch system, a second board, or a second backlog.**
Crisp-R's rule: the Controller is the single queue; this picks the next item, it does not invent a new
source of truth.

## Hard rules
- **Do not weaken any existing guard.** No bypasses, no blanket permissions, no path escapes.
- The dispatcher must **refuse** an ineligible ticket, not silently skip it.
- Fail closed on anything ambiguous. UNVERIFIED is a valid output.
- No credentials, no production, no DNS, no registrar.
- **Never touch `srv1137994` / animovps / Aminolifesciences / elevatesVPS in any form.**

## Evidence rules
- RED then GREEN. The test must fail before the fix and pass after.
- Paste real PASS/FAIL counts from a full run of the affected suites.
- If bash is denied by the allowlist, report that verbatim as the finding and stop. Do not route around it.

## Rules
- Work ONLY in /tmp/wt-wo0009-dispatcher-r2. Read-only on projects/, secondmate homes, warehouse.
- Commit on branch wo-0009/dispatcher-r2. **No merge, no push, no rebase of main** - the Captain owns merges.

## Report
data/wo-0009-dispatcher/report.md with the RED test output, the GREEN test output, the full-suite
counts, and one line stating whether the dispatcher now selects by dependency and scope.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.

## UPDATE - the shell allowlist changed. Read this before assuming it is still blocked.

`bash` is now permitted **as a binary** so you can execute your own test scripts:
```
bash tests/foo.sh     -> RUNS
bash -c '...'         -> STILL BLOCKED
python3 -c '...'      -> STILL BLOCKED
```
So: run test scripts by path. Do not expect inline `bash -c` or `python3 -c` to work, and do not
report "bash is denied" as a blanket blocker without testing a script path first.

A previous attempt at this lane died on the old allowlist and left partial work in
`/tmp/wt-wo0009-dispatch`. **That worktree is stale - work fresh in this one, but you may read it.**
