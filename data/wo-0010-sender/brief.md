# WO-0010 - harden fm-to-controller.sh: two HIGH findings from the WO-0006 L5 security review

**Model:** openai-codex/gpt-6-luna, effort **high**. **Worktree:** `/tmp/wt-wo0010-sender`, branch `wo-0010/sender-hardening`.

## Why this lane exists
WO-0006 L5 ran a security review of the direct-notify path and returned **two HIGH findings against
`bin/fm-to-controller.sh` - the script that carries every message I send to the Controller.** It is
currently the least-hardened piece of code on my most important path.

## Native visible To-Do list - REQUIRED first
Five or more items, real dependency chain, each prefixed `WO-0010-SND:`:
1. preflight - read the script and its existing tests
2. scoped discovery - confirm both findings still reproduce
3. RED tests for both
4. GREEN - fix both
5. regression suite + commit

## HIGH 1 - an existing recipient file can be overwritten

`fm-to-controller.sh:44-49` validates filename shape then copies with ordinary `cp`, which **replaces
the destination.** No exclusive create, no existing-file refusal, no content or version check.

Consequences to eliminate:
- a caller can reuse a destination name and replace a message already awaiting review, **including one
  written by another sender**
- **partial success**: first copy succeeds, second fails, script exits before the ledger update, and a
  retry replaces the already-delivered file

Required: refuse to clobber. Be idempotent for a genuine retry of the **same** content, and refuse
**different** content to an existing name. Never lose a delivered message.

## HIGH 2 - no recipient lifecycle guard

The sender writes directly and resolves no recipient identity or lifecycle state, so it **cannot
distinguish working, blocked, or done.** The invariant "never interrupt a working or blocked recipient"
is not enforced by this code.

Required: enforce it in this code path, or fail closed if the state cannot be determined. A `done`
recipient must never be queued. Only a genuinely busy recipient may be deferred.

## MEDIUM findings from the same review - fix if cheap, do not expand scope
- **hash ledger conflates identical bodies** - keyed on body SHA only, so two filenames with identical
  bytes collide. Include filename or a send id. **This is a semantic key collision, not a crypto one.**
- **no retention bound** on the ledger and destination
- **no provenance binding** on caller-supplied Markdown

## Hard rules
- **Do not weaken the guarded notification contract.** Never Ctrl-C or Escape. Keep content-hash dedup
  and the durable pending queue.
- **Never send a real notification to any real recipient while testing.** Temp targets only.
- Never touch `srv1137994` / animovps / Aminolifesciences / elevatesVPS.
- No credentials, no production, no DNS.

## Evidence rules
- **RED then GREEN for each finding.** Show the failing run and the passing run.
- Report the **full suite counts honestly**, including pre-existing failures. **Do not report a green
  suite you did not get.** The known baseline is roughly 41 failures out of 143; do not make it worse
  and do not pretend it is better.
- If a finding turns out not to reproduce, say so with evidence. Do not manufacture it.

## Shell
`bash <script>` RUNS. `bash -c` and `python3 -c` are BLOCKED - use script paths.

## Rules
- Work ONLY in /tmp/wt-wo0010-sender. Commit on branch wo-0010/sender-hardening.
- **No merge, no push, no rebase of main** - the Captain owns merges.

## Report
data/wo-0010-sender/report.md with RED and GREEN output per finding, full-suite counts, and one line per
finding stating fixed or not-reproduced.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
