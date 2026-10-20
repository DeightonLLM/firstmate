# WO-0008 lane 1 - WHOOSH: does the application exist at all? (Luna 6 high)

**Model:** openai-codex/gpt-6-luna, effort **high**. **Worktree:** `/tmp/wt-wo0008-whoosh`, branch `wo-0008/whoosh`.

## Native visible To-Do list - REQUIRED first
At least five items, real dependency chain, each prefixed `WO-0008-WHOOSH:`:
1. preflight - search every local location for any Whoosh artifact
2. DNS/hosting evidence - does a runtime exist?
3. repository evidence - does source exist?
4. deployment/hosting evidence
5. verdict: EXISTS with coordinates, or DOES NOT EXIST — commit

## The question, stated precisely
**Establish whether a Whoosh application exists AT ALL: repository, runtime, hosting coordinates.**

Nothing on this host evidences a Whoosh application ever having existed. `whooshperformance.com`
returns HTTP 200 but serves a **parked Hostinger page, not an application.**

**Your job is to find it or definitively close it.** Not to optimise. Not to redesign. One owner, one
outcome.

## Where to look - be exhaustive, then report the negative honestly
- `/home/hd2admin/kun-agent-workspace/projects/` (only core-distro-saas-clean and firstmate present)
- every `.treehouse` workspace slot
- git repos under `/home/hd2admin` with whoosh in the name
- `/home/hd2admin/brandon-inbox` and any whoosh brief
- `data/wo0005-2-domain-prds/report.md` - the PRD that assigned the owner
- DNS: does whooshperformance.com resolve, what does it serve, is it a Hostinger parked page
- warehouse/preserved-work if it exists

## Do NOT
- Do not touch production, DNS, registrar, or credentials.
- Do not create a repository, scaffold a project, or stand anything up. Finding or closing is the task.
- Do not connect to any host. No credentials, no ssh.

## If it does not exist
**Say so definitively and show the searches.** A clean, evidenced negative is a SUCCESSFUL lane and
is more valuable than speculation. Do not hedge, and do not invent a plan to build one.

## If it does exist
Report exact coordinates: repository path, remote, runtime/deploy path, hosting, and what state it is in.

## Rules
- Work ONLY in /tmp/wt-wo0008-whoosh. Read-only everywhere else.
- Commit on branch wo-0008/whoosh. No merge, no push, no rebase of main.
- Verbatim command output for every search.
- If bash is denied by the allowlist, report that as the finding and stop. Do not route around it.

## Report
data/wo-0008-whoosh/report.md with a single VERDICT line:
`VERDICT: WHOOSH EXISTS` (with coordinates) or `VERDICT: WHOOSH DOES NOT EXIST` (with search evidence).
