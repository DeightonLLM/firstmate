# WO-0006 L4 - independent verification of the three HD2 artifacts (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort **high**. **Worktree:** `/tmp/wt-wo0006-l4`, branch `wo-0006/l4`.

## Native visible To-Do list - REQUIRED first
At least five items, real dependency chain, each prefixed `WO-0006-L4:`:
1. preflight - locate the three artifacts
2. scoped discovery - what each claims to be
3. verify each claim independently
4. record findings
5. postflight - commit, verbatim output

## Your job
Independently verify the three artifacts that came back from HD2. **Do not trust their own reports.**
The three are: the domain scope-enforcement work, the Hetz outbound order delivery work, and the
factory health baseline work.

For each:
- find it and hash it yourself
- confirm the artifact matches what its report claims, without reading the report as authority
- state ACCEPTED or NOT ACCEPTED per artifact with evidence

**A report claiming success is not evidence. Verify the bytes or the behaviour yourself.**

## Rules
- Work ONLY in /tmp/wt-wo0006-l4. Never touch the live home, projects/, secondmate homes, or warehouse.
- Commit on branch wo-0006/l4. No merge, no push, no rebase of main.
- Verbatim command output only. If you cannot check something, say UNVERIFIED and why.

## Report
data/wo-0006-l4-artifact-review/report.md. Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
