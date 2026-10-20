# WO-0016 - CBD-Data: locate the app and the export worker (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort high. Worktree: /tmp/wt-d8-cbd, branch d8/cbd.

## Why
A prior lane (WO-0008 cbddata) reported UNVERIFIED because **the authorised worktree contained no
CBD-Data application or worker code at all.** The PRD says documentation complete. The filesystem
says there is nothing there. That gap is the work.

## Your job - FIND IT, with exhaustive, evidenced searches
Search every location that could hold it. **Do not stop at the first place you did not find it - that
is the exact error this home has made repeatedly.** Use the second signal every time.

Look in:
- `/home/hd2admin/kun-agent-workspace/projects/` (only core-distro-saas-clean and firstmate present)
- **every** `.treehouse/kun-agent-workspace-*` slot, all of them, including `8bf1b0`
- `~/brandon-inbox` and any cbd brief
- `data/wo0005-2-domain-prds/report.md` - the CBD PRD row
- `/home/hd2admin/agent-work/` subdirectories
- anywhere with `cbd` in the name, any depth
- `docs/system-context/hosts.yaml` for the host
- git repos with an unrelated history (there are two firstmate clones - check both)

Then answer concretely:
1. **Where does the CBD-Data application live?** repo path + remote + runtime.
2. **Where does the export worker live?** same detail.
3. **Does the live site serve it?** `https://cbd-data.com` and `https://data.core-distro.com` both
   return 200 - what is actually serving them, and from which host?
4. **If it does not exist here, where should it be?** Say which system of record would hold it.

## Hard rules
- READ ONLY everywhere. No production writes, no DNS, no credentials, no deployment.
- **Never touch `srv1137994` / elevatesVPS / Aminolifesciences.**
- Do not scaffold a project. Finding or definitively closing is the task.

## Rules
- Work ONLY in /tmp/wt-d8-cbd. Commit on d8/cbd. **No merge, no push, no rebase of main.**
- `bash <script>` RUNS. `bash -c` and `python3 -c` are BLOCKED - write a script file.
- Verbatim command output for every search. An evidenced negative is a SUCCESSFUL lane.

## Report
data/d8-cbd/report.md with a VERDICT line:
`VERDICT: APP LOCATED` (with coordinates) or `VERDICT: NOT PRESENT ON THIS HOST` (with full search log).
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.