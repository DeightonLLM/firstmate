# WO-0008 lane 2 - CBD-DATA: real verification, not documentation (Luna 6 high)

**Model:** openai-codex/gpt-6-luna, effort **high**. **Worktree:** `/tmp/wt-wo0008-cbddata`, branch `wo-0008/cbddata`.

## Native visible To-Do list - REQUIRED first
At least five items, real dependency chain, each prefixed `WO-0008-CBD:`:
1. preflight - locate the CBD-Data app and its export worker
2. establish the measured current state
3. run the verification path
4. run the export-worker path
5. report what passes and what FAILS - commit

## The point
The PRD says **documentation completion is NOT production validation.** So do not re-document anything.
The next step is the real one: **run the verification and export-worker path against the measured
current state, and report what actually passes and what actually fails.**

**A failing check reported honestly is a better deliverable than a passing check that was faked.**

## Safety - absolute
- **READ ONLY against production.** No production write. No migration, no schema change, no write query.
- No credentials beyond what already exists on this host. Do not request or transfer keys.
- Do not touch DNS, registrar, deployment, or anything on the srv1137994 / Aminolifesciences host in any form.

## Evidence rules
- Run the checks and quote the real output, including failures.
- If a check cannot run, say UNVERIFIED and name exactly why. Never infer a pass.
- Distinguish clearly between "passed", "failed", and "could not be run" in your verdict.

## Rules
- Work ONLY in /tmp/wt-wo0008-cbddata. Read-only on any app or project directory.
- Commit on branch wo-0008/cbddata. No merge, no push, no rebase of main.
- If bash is denied, report that as the finding and stop. Do not route around it.

## Report
data/wo-0008-cbddata/report.md with:
- what was run, verbatim output
- a clear PASS / FAIL / UNVERIFIED per check
- one VERDICT line stating the true current production state
