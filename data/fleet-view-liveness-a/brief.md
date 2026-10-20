WORKTREE /tmp/wt-fleetview (branch fix/fleet-view-liveness). Do NOT work in the live home.
You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

# Task
FIX: fleet snapshot treats a leftover metadata file as a live task.

## The proven defect
bin/fm-fleet-snapshot.sh:404 iterates state/*.meta and emits ONE "under way" row per file, with no liveness
check. A meta file outlives any task closed by a path other than fm-teardown.sh.
Live proof: 17 meta files exist right now and ZERO of those tasks have a live endpoint. The board claimed
17 tasks were running when none were, every row reading `unknown / none`.
fm-teardown.sh:1753 does `rm -f "$STATE/$ID.status" "$STATE/$ID.turn-ended" "$STATE/$ID.meta"`, so teardown is
correct. The gap is every OTHER close path: tasks-axi done, manual reap, a worker that reaped itself.

## LANE A - your assignment
1. In bin/fm-fleet-snapshot.sh a task row must carry a real liveness determination, not metadata presence.
   Reuse the endpoint/backend probe the snapshot already has. Do not invent a new probe.
2. Classify each meta-backed task: LIVE (endpoint present AND agent alive) / STALE (endpoint absent) /
   UNKNOWN (probe could not run - say so, never guess).
3. "Under Way" shows ONLY live tasks. Add a separate "Stale - metadata without a live endpoint" section so
   nothing silently disappears. A stale row is information, not noise to hide.
4. A task whose endpoint is absent must NOT render as present. Confirm endpoint_exists does not return
   "present" for a dead pane, and fix it if so.
5. PRESERVE the stable JSON schema fm-fleet-snapshot.v1. Add fields additively. Break no existing consumer.
6. Add tests/fm-fleet-view-liveness.test.sh that PROVES the defect: temp state dir with a meta file and no
   live endpoint, run the snapshot, assert the task is NOT under way and IS stale. The test must FAIL against
   today's code before your fix and PASS after. Show both runs.

## NON-NEGOTIABLE for both lanes
- Work ONLY in your own worktree. Never touch the live home.
- READ ONLY on projects/, secondmate homes, the warehouse, and the network.
- Do not merge, push, or rebase main. Stop after committing on your branch.
- Every claim needs quoted command output. No summary of output.
- Run your own tests and paste the real PASS/FAIL counts.
- If bash is denied by the allowlist, say so and stop. Do not route around a denial.

## Report
data/fleet-view-liveness-a/report.md - diff summary, verbatim test output, and one line stating whether the defect is fixed
AND proven by a test that failed before the fix and passes after.
Your chat reply is not the deliverable. Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
The completion attestation IS authorised in this brief: run the required completion gate and record it.

# Herdr lifecycle declaration - NOT ENABLED
**HARD SAFETY GATE:** this scaffold cannot inspect the task text that replaces `FIX: fleet snapshot treats a leftover metadata file as a live task.

## The proven defect
bin/fm-fleet-snapshot.sh:404 iterates state/*.meta and emits ONE "under way" row per file, with no liveness
check. A meta file outlives any task closed by a path other than fm-teardown.sh.
Live proof: 17 meta files exist right now and ZERO of those tasks have a live endpoint. The board claimed
17 tasks were running when none were, every row reading `unknown / none`.
fm-teardown.sh:1753 does `rm -f "$STATE/$ID.status" "$STATE/$ID.turn-ended" "$STATE/$ID.meta"`, so teardown is
correct. The gap is every OTHER close path: tasks-axi done, manual reap, a worker that reaped itself.

## LANE A - your assignment
1. In bin/fm-fleet-snapshot.sh a task row must carry a real liveness determination, not metadata presence.
   Reuse the endpoint/backend probe the snapshot already has. Do not invent a new probe.
2. Classify each meta-backed task: LIVE (endpoint present AND agent alive) / STALE (endpoint absent) /
   UNKNOWN (probe could not run - say so, never guess).
3. "Under Way" shows ONLY live tasks. Add a separate "Stale - metadata without a live endpoint" section so
   nothing silently disappears. A stale row is information, not noise to hide.
4. A task whose endpoint is absent must NOT render as present. Confirm endpoint_exists does not return
   "present" for a dead pane, and fix it if so.
5. PRESERVE the stable JSON schema fm-fleet-snapshot.v1. Add fields additively. Break no existing consumer.
6. Add tests/fm-fleet-view-liveness.test.sh that PROVES the defect: temp state dir with a meta file and no
   live endpoint, run the snapshot, assert the task is NOT under way and IS stale. The test must FAIL against
   today's code before your fix and PASS after. Show both runs.

## NON-NEGOTIABLE for both lanes
- Work ONLY in your own worktree. Never touch the live home.
- READ ONLY on projects/, secondmate homes, the warehouse, and the network.
- Do not merge, push, or rebase main. Stop after committing on your branch.
- Every claim needs quoted command output. No summary of output.
- Run your own tests and paste the real PASS/FAIL counts.
- If bash is denied by the allowlist, say so and stop. Do not route around a denial.

## Report
data/fleet-view-liveness-a/report.md - diff summary, verbatim test output, and one line stating whether the defect is fixed
AND proven by a test that failed before the fix and passes after.
Your chat reply is not the deliverable. Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
The completion attestation IS authorised in this brief: run the required completion gate and record it.` later.
If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
Do not add Herdr lifecycle commands to this unguarded brief by hand.

# Setup
You are in a disposable git worktree of firstmate, at a detached HEAD on a clean default branch.

**Verify isolation before anything else.** Run `pwd -P` and `git rev-parse --show-toplevel`; both must resolve to the disposable task worktree you were launched in, such as a treehouse pool path or an Orca-managed worktree, not the primary checkout firstmate operates from.
The path check is authoritative: `git rev-parse --git-dir` and `git rev-parse --git-common-dir` can help inspect the repo, but they do not prove you are outside the primary checkout.
If the top-level path is the primary checkout or not the worktree you were launched in, STOP - do not branch or commit here - append `blocked: launched in primary checkout, not an isolated worktree` to the status file and stop.

1. First action: create your branch: `git checkout -b fm/fleet-view-liveness-a`

# Mandatory task breakdown
This requirement applies to you because your harness (`pi`) provides the To-Do List extension.
Before any investigation, edit, test, or other task action, use the harness's
To-Do List extension and create an in-depth dependency-aware tracker with at
least five checkable items: preflight, scoped discovery, bounded work/evidence,
validation, and postflight/closeout. Keep it visible and update it at every
phase change. Do not substitute prose or a filesystem TODO file. If the
extension is unavailable or the tracker has fewer than five items, append
`blocked: To-Do List extension unavailable or incomplete` to the status file and
stop; firstmate must not treat the task as started.

# Rules
1. Never push to any remote and never open a PR. Work only on your `fm/fleet-view-liveness-a` branch; firstmate handles the merge into local `main`.
2. Stay inside this worktree; modify nothing outside it.
3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
4. Report status by appending one line:
   `echo "{state}: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/fleet-view-liveness-a.status'`
   States: working, needs-decision, blocked, paused, done, failed.
   Each append wakes firstmate, so report sparingly: only phase changes a supervisor
   would act on (setup done, bug reproduced, fix implemented, validation passed) and the
   needs-decision/blocked/paused/done/failed states. No step-by-step FYI progress lines;
   firstmate reads your pane for that.
   Staying VISIBLE is enforced in code, not merely requested here: a live crewmate that has
   appended nothing for longer than FM_CREW_VISIBILITY_STALE_SEC (default 1800s), or has never
   appended anything within FM_CREW_VISIBILITY_GRACE_SEC (default 300s) of its spawn, raises a
   `crew-silent` breach naming you and the elapsed silence straight to the captain
   (bin/fm-crew-visibility.sh, checked by the watcher on every cycle). So re-append a `working:`
   line whenever a phase runs long - the watcher absorbs those as benign, so they cost the
   captain nothing, and they are exactly what keeps you readable. A declared `paused: {why}`
   for an external wait ends that obligation; going quiet never does.
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
The task is complete only when committed on your branch `fm/fleet-view-liveness-a`. Do NOT push, do NOT open a PR, do NOT merge.
Keep your branch a clean fast-forward onto the current default branch - if `main` has advanced, rebase onto it so the eventual merge stays a fast-forward.
When it is implemented and committed, append `done: ready in branch fm/fleet-view-liveness-a` to the status file and stop.
The configured merge authority approves the ready branch, then firstmate merges it into local `main` through the guarded fast-forward path.
# Fresh-agent baseline
Baseline manifest: fresh-agent-baseline/v1
policy=/home/hd2admin/kun-agent-workspace/AGENT-POLICY.md scope=home sha256:3cd8632098333f5a4c57810dbe8652f2c5f77d54a1531427f0e205021bd4cacd
project-policy=/home/hd2admin/agent-work/AGENTS.md scope=account sha256:8f8f9b43dd878bdf958b17be0e19b2cbcbc4dc03258173622808a944d48739c7
routing=/root/docs/agent-policy/HERDR_AGENT_ROUTING.md scope=cross-home:root sha256:6110b3a0c52911e2741ef089b24c746d2713b487120f59c273709f79e1382221
bounded=/root/docs/agent-policy/HERDR_BOUNDED_EXECUTION.md scope=cross-home:root sha256:4cccef8e14fd780e17b9b126daa023b1f3ad4a63722fe612929866c3ba8b46ce
lean-ctx=/home/hd2admin/.codex/LEAN-CTX.md scope=account sha256:fced95bfb43345ec12f3a4a533f176f174deb0813d25eb8da73a43f1221c8707
warehouse=/home/hd2admin/kun-agent-workspace/docs/system-context/INDEX.md sha256:5bd3821e290ca51a7b0f9023ee1aaaa250809dfe00fbd61840050c122bb57bb6
warehouse-preflight=/home/hd2admin/kun-agent-workspace/bin/fm-context-preflight.sh
goal-queue=/home/hd2admin/kun-agent-workspace/data/backlog.md
state-handoff=/home/hd2admin/kun-agent-workspace/state/.wake-queue
Read pointers and hashes above; do not paste or inherit prior conversation history.
