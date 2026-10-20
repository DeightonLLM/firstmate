# WO-0006 L5 - security review of the merged direct-notify feature (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort **high**. **Worktree:** `/tmp/wt-wo0006-l5`, branch `wo-0006/l5`.

## Native visible To-Do list - REQUIRED first
At least five items, real dependency chain, each prefixed `WO-0006-L5:`:
1. preflight - locate the merged direct-notify code and its tests
2. scoped discovery - every path that delivers a file or sends a notification
3. threat model - who can trigger a notification, to whom
4. adversarial review - attempt to interrupt, hijack, or leak
5. postflight - findings with evidence, commit

## The invariant under review
**The notification guard must NEVER interrupt a working or blocked recipient.**

Attempt to break exactly that. Specifically probe:
- can a notification reach a recipient that is busy or blocked?
- can the deferred/queued path grow without bound?
- can a recipient be made to execute content it did not author?
- does the content-hash dedup have a collision or replay weakness?
- what happens on a `done` recipient? (Controller has been asked to change this - confirm current behaviour)

## Rules
- Work ONLY in /tmp/wt-wo0006-l5. Read-only on live home, projects/, secondmate homes, warehouse.
- **Do NOT send any real notification to any real recipient while testing.** Use temp targets.
- No credentials, no production, no network targets outside localhost.
- Commit on branch wo-0006/l5. No merge, no push, no rebase of main.
- Verbatim output. Say UNVERIFIED when you cannot check.

## Report
data/wo-0006-l5-notify-security/report.md - findings ranked by severity with reproduction steps.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
