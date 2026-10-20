# WO-0008 lane 3 - ELEVATE: AnythingLLM workspace repair with measured before/after (Luna 6 high)

**Model:** openai-codex/gpt-6-luna, effort **high**. **Worktree:** `/tmp/wt-wo0008-elevate`, branch `wo-0008/elevate`.

## Native visible To-Do list - REQUIRED first
At least five items, real dependency chain, each prefixed `WO-0008-ELV:`:
1. preflight - reach agents.elevatesci.com and record the CURRENT workspace state
2. identify what is broken or missing
3. repair within staging and workspace scope only
4. re-measure the same facts
5. report measured before/after - commit

## Scope - hard limits
- **Staging and workspace scope ONLY.**
- **`elevatesci.com` production stays OUT.** Do not modify it. Do not write to it.
- No DNS, registrar, credentials, spending, deployment.
- Never touch `srv1137994` / Aminolifesciences / elevatesVPS in any form.
- No new credentials. Use what already exists on this host.

## The deliverable is MEASUREMENT
**Report the measured before and after.** Not a description of what you intended to change - the actual
state before, the actual state after, with the evidence for both. If the repair cannot be completed
within scope, report the exact before state and the precise blocker.

A report that says "workspace repair attempted, blocked at X, current state measured as Y" is a
successful lane. A report that claims a fix you did not verify is a failed one.

## Evidence rules
- Quote real output. Anything unverified says UNVERIFIED and why.
- Never infer a pass from a file existing.

## Rules
- Work ONLY in /tmp/wt-wo0008-elevate. Read-only on any project or app directory.
- Commit on branch wo-0008/elevate. No merge, no push, no rebase of main.
- If bash is denied, report it as the finding and stop. Do not route around a denial.

## Report
data/wo-0008-elevate/report.md with a before table, an after table, and one VERDICT line.
