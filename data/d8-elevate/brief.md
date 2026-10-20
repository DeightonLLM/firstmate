# WO-0016 - Elevate: measure the AnythingLLM workspace before and after (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort high. Worktree: /tmp/wt-d8-elevate, branch d8/elevate.

## Why
A prior lane (WO-0008 elevate) reported BLOCKED: before/after measurements unchanged, workspace state
UNVERIFIED. **It could not establish a baseline, so it could not prove or disprove a repair.**

## Your job - establish the real baseline, then repair only what is provably broken

### Step 1: establish what the workspace actually is
```
https://agents.elevatesci.com   -> 200, AnythingLLM
```
- What API/version is it? Look for `/api/system`, `/api/v1/...`, a version string in the page.
- Is there a workspace list endpoint you can read **without credentials you do not have**?
- If it needs auth you do not hold: say so, name the endpoint, and stop. **Do not try to obtain
  credentials.** An honest "requires auth I do not have" is a good result.

### Step 2: measure, do not assume
- HTTP status, response shape, page title, version, any workspace/agent count you can read.
- **Use a second signal for every claim.** A 200 alone is not proof of a working workspace - that is
  exactly the mistake that made `whooshperformance.com` read as live when it is a parked page.

### Step 3: repair only what is provably broken, within scope
- **Staging and workspace scope only.**
- **`elevatesci.com` production is OUT.** Do not modify it.
- No DNS, registrar, credentials, spending, deployment.
- **Never touch `srv1137994` / elevatesVPS / Aminolifesciences** - that machine also holds
  Aminolifesciences client and archive data which is a hard gate even though the staging gate lifted.

## Rules
- Work ONLY in /tmp/wt-d8-elevate. Commit on d8/elevate. **No merge, no push.**
- `bash <script>` RUNS. `bash -c` / `python3 -c` BLOCKED - write a script file.
- Quote real output. UNVERIFIED is a valid, useful answer.

## Report
data/d8-elevate/report.md - before table, after table, the exact endpoints you hit, and one VERDICT
line. If auth blocked you, say exactly which endpoint and what credential class would unblock it.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.