# WO-0008 lane 4 - CORE-DISTRO: staging blocker list, recovery order, ticket 0017 (Luna 6 high)

**Model:** openai-codex/gpt-6-luna, effort **high**. **Worktree:** `/tmp/wt-wo0008-core`, branch `wo-0008/core`.

## Native visible To-Do list - REQUIRED first
At least five items, real dependency chain, each prefixed `WO-0008-CORE:`:
1. ticket 0017 - independently re-verify the artifact `50ae6849c190`
2. enumerate every staging blocker with evidence
3. order them by recovery dependency
4. state what is reachable and what is not
5. report - commit

## Core's finish line is NOT reachable today. Do not pretend otherwise.
Expired certificate plus an HTTP 500 behind it, chatbot inactive, artifact unverified.
**Do not burn a lane pretending you can fix it.**

## Part 1 - ticket 0017, still open
Artifact at:
```
/home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact
```
Revision `50ae6849c190`, 19 files. Run the cited checksum command on the exact artifact on disk and
report the verbatim result - every line OK, with the real OK and FAILED counts.

**An earlier run returned NOT ACCEPTED** because byte identity with the previously reported artifact
could not be proven: `SHA256SUMS` is generated from those same files, so it proves they have not
changed since that manifest was made, and nothing more. State plainly whether that is still true, and
say what evidence WOULD establish identity.

## Part 2 - the staging blocker list with exact recovery order
For each blocker: what it is, measured evidence, what it depends on, and what unblocks it. Then give
the **recovery order**, dependency-first.

**The host serving staging is UNRESOLVED and must stay that way.** Do not infer it. Do not resolve it
from a DNS record, PTR, or legacy alias. Record it as UNKNOWN and report what you need in order to
proceed.

## Absolute prohibitions
- No DNS, registrar, credentials, deployment, or production writes.
- **Never touch `srv1137994` / animovps / Aminolifesciences / elevatesVPS in any form.**
- Do not start the three retained-branch merges. Read-only inspection only.

## Rules
- Work ONLY in /tmp/wt-wo0008-core. Read-only on projects/ and every app directory.
- Commit on branch wo-0008/core. No merge, no push, no rebase of main.
- If bash is denied, report it as the finding and stop. Do not route around a denial.

## Report
data/wo-0008-core/report.md - ticket 0017 verbatim result, the blocker list, the recovery order, and
one VERDICT line on what is reachable today.
