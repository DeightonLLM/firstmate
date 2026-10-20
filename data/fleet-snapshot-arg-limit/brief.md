You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

# Task
Fix a confirmed, reproducible defect that makes firstmate's fleet visibility completely non-functional at realistic backlog sizes.

## The defect

`bin/fm-fleet-snapshot.sh` aborts with:

```
/usr/local/bin/jq: Argument list too long
fm-fleet-snapshot: main inventory summary failed
```

Reproduced repeatedly on 2026-10-13 at a 55-59 item backlog. It is NOT transient and NOT load-related flakiness.

Root cause, located and confirmed: `main_inventory_json()` at approximately line 565-567 invokes:

```sh
jq -n --argjson backlog "$1" --argjson tasks "$2" '...'
```

Passing the entire backlog JSON and tasks JSON through `--argjson` puts them in the **exec argument vector**, which is bounded by the kernel (`ARG_MAX`, typically ~2MB and shared across the whole command line including environment). Once the backlog JSON exceeds that budget, `jq` is never successfully executed and the snapshot fails outright.

The same pattern may exist at other call sites in this script and in sibling fleet scripts. Find them all; do not fix only the one that was observed.

## Your job

1. Reproduce it yourself before changing anything, and capture the exact command and the exact error. Do not fix a bug you have not demonstrated.
2. Find EVERY place in `bin/` that passes bulk JSON via `--argjson`/`--arg`/`-v` on the command line and would hit the same limit. Report the full list, even the ones not yet failing.
3. Fix it using a mechanism that does not scale with input size on the command line. Standard robust approaches: feed via stdin (`jq ... < file` or a heredoc), use `--rawfile`, or stream. **Choose the approach that matches this repository's existing conventions** — if sibling scripts already solved this, follow that pattern rather than inventing a new one.
4. Preserve output semantics exactly. The snapshot's JSON shape, field names, and values must not change. A caller such as `bin/fm-fleet-view.sh` and its tests depend on them.
5. Prove it at scale, not just at current size. After the fix, verify the snapshot succeeds with a synthetic input comfortably larger than the current backlog so the next growth does not re-break it. State the size you tested.
6. Add colocated regression tests in the repo's existing style, including at least one case with input large enough that it would have failed before the fix. Fixtures must fail loudly on unmet assertions; use a cleanup trap, not a trailing `rm -rf` that masks failure.

## Mandatory guidance

You are changing firstmate's own shared tracked tooling. Read and follow
`/home/hd2admin/kun-agent-workspace/.agents/skills/firstmate-coding-guidelines/SKILL.md` before editing.
Repo style: one sentence per line, plain dashes, no agent co-author, shellcheck-clean `bin/`, colocated tests.

## Boundaries

local-only delivery: stop with a clean ready branch. No push, no PR, no merge. No production, deployment,
credential, database, permission or host changes. Nothing under `projects/`. Do not touch the seven
secondmate homes or `data/secondmates.md`. Do not restart or replace any running worker. Do not change
`bin/fm-teardown.sh`, `bin/fm-spawn.sh`, `bin/fm-merge-local.sh`, or any merge, credential or permission path.

**Do not "fix" this by truncating or capping the input.** Truncating would hide records and make the tool
lie. If you believe capping is genuinely required, stop and report that as a decision instead.

## Definition of done

The snapshot succeeds at a synthetic input size well beyond the current backlog, output shape is
byte-compatible for existing consumers, regression tests cover the large-input case, and you report the
exact commands and real exit codes you ran. Report to
`/home/hd2admin/kun-agent-workspace/data/fleet-snapshot-arg-limit/report.md`, then follow the decision-hold
completion gate. Name every check you could not run; never describe an unrun check as passing.

# Herdr lifecycle declaration - NOT ENABLED
**HARD SAFETY GATE:** this scaffold cannot inspect the task text that replaces `{TASK}` later.
If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
Do not add Herdr lifecycle commands to this unguarded brief by hand.

# Setup
You are in a disposable git worktree of firstmate, at a detached HEAD on a clean default branch.

**Verify isolation before anything else.** Run `pwd -P` and `git rev-parse --show-toplevel`; both must resolve to the disposable task worktree you were launched in, such as a treehouse pool path or an Orca-managed worktree, not the primary checkout firstmate operates from.
The path check is authoritative: `git rev-parse --git-dir` and `git rev-parse --git-common-dir` can help inspect the repo, but they do not prove you are outside the primary checkout.
If the top-level path is the primary checkout or not the worktree you were launched in, STOP - do not branch or commit here - append `blocked: launched in primary checkout, not an isolated worktree` to the status file and stop.

1. First action: create your branch: `git checkout -b fm/fleet-snapshot-arg-limit`

# Mandatory task breakdown
Before any investigation, edit, test, or other task action, use the harness's
To-Do List extension and create an in-depth dependency-aware tracker with at
least five checkable items: preflight, scoped discovery, bounded work/evidence,
validation, and postflight/closeout. Keep it visible and update it at every
phase change. Do not substitute prose or a filesystem TODO file. If the
extension is unavailable or the tracker has fewer than five items, append
 to the status file and
stop; firstmate must not treat the task as started.

# Rules
1. Never push to any remote and never open a PR. Work only on your `fm/fleet-snapshot-arg-limit` branch; firstmate handles the merge into local `main`.
2. Stay inside this worktree; modify nothing outside it.
3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
4. Report status by appending one line:
   `echo "{state}: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/fleet-snapshot-arg-limit.status'`
   States: working, needs-decision, blocked, paused, done, failed.
   Each append wakes firstmate, so report sparingly: only phase changes a supervisor
   would act on (setup done, bug reproduced, fix implemented, validation passed) and the
   needs-decision/blocked/paused/done/failed states. No step-by-step FYI progress lines;
   firstmate reads your pane for that.
   A mid-task `working:` line (including setup complete) is nonterminal: do not end the
   turn after it; continue the same stage until a defined `done:` gate under Definition of done.
   Use `paused: {why}` - distinct from `blocked:` - ONLY when you are deliberately idling on a
   known external wait you expect to clear on its own (an upstream release, a rate-limit reset,
   a scheduled window): firstmate then leaves your idle pane alone and rechecks it on a long
   cadence instead of treating it as a possible wedge. Use `blocked:` when you are stuck and need help.
5. If you hit the same obstacle twice, append `blocked: {why}` and stop; firstmate will help.
6. If a decision belongs above the implementation worker (product choices, destructive actions, ask-user findings),
   append `needs-decision: {summary of options}` and stop. Firstmate will apply the configured authority and reply with the decision.
   When firstmate replies or a blocker clears and you resume, append `resolved: {how it was decided or unblocked}` (add the same `[key=<slug>]` if you opened it with one) so the decision or blocker is durably closed and does not keep resurfacing.
7. Never stop, restart, or update the shared `no-mistakes` daemon - it is one instance serving
   every lane/home, so restarting it kills other lanes' in-flight pipeline runs. On ANY no-mistakes
   daemon error, append `blocked: {the daemon error}` and stop; only firstmate manages the daemon.

# Project memory
If `AGENTS.md` or `CLAUDE.md` already exists, or if this task produced durable project-intrinsic knowledge, run `/home/hd2admin/kun-agent-workspace/bin/fm-ensure-agents-md.sh .` in the worktree.
Record only project knowledge useful to almost every future session.
For anything the codebase already shows, prefer a pointer to the authoritative file, command, or doc over copying the detail.
If you touch a project `AGENTS.md` that lacks `## Maintaining this file`, add that short self-governance section from `/home/hd2admin/kun-agent-workspace/bin/fm-ensure-agents-md.sh` in the same pass.
Keep it proportionate: skip `AGENTS.md` edits for trivial tasks that produced no durable project knowledge.

# Definition of done
This project ships **local-only**: no remote, no PR, no pipeline.
The task is complete only when committed on your branch `fm/fleet-snapshot-arg-limit`. Do NOT push, do NOT open a PR, do NOT merge.
Keep your branch a clean fast-forward onto the current default branch - if `main` has advanced, rebase onto it so the eventual merge stays a fast-forward.
When it is implemented and committed, append `done: ready in branch fm/fleet-snapshot-arg-limit` to the status file and stop.
The configured merge authority approves the ready branch, then firstmate merges it into local `main` through the guarded fast-forward path.
