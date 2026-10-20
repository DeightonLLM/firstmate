You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

# Task
## Captain's intent
Implement automatic updates for Pi, Codex, and the other agent tools and extensions this Firstmate home uses. Pi is out of date; keep agent panes visible and usable while updates happen.

please set this shit to auto update on load.... NOW

## Firstmate spec
Inspect the existing watched-tool check, each supported install path, and the runtime and extension lifecycle before changing shared tracked files. Build an automatic update path that uses staged installs where available and only applies an update when it cannot disrupt active work. Detect tool-specific live workers and fail closed if their state cannot be established. Never restart a live Herdr server, terminate a visible pane, interrupt an active no-mistakes run, use a force flag, choose preview channels, or discard prior versions. Queue unsafe or unverifiable updates as visible findings so they can run in a later idle window. Cover Pi itself and its installed extensions, Codex CLI, Herdr client/server boundaries, and any other agent tools for which this home has a safe supported update path. Reuse the existing watcher and update records where possible; do not create duplicate hand-maintained status. Load `.agents/skills/firstmate-coding-guidelines/SKILL.md` and obey its shared-file ownership rules. Do not add or run tests unless the captain asks for testing or verification; report any validation not performed. Make a local-only commit on the scaffolded branch, with no push, PR, merge, or deployment.

For the new Pi on-load requirement, inspect the actual Pi entry and task-launch paths. Reuse the watched-tool detector and existing live-worker gates. Check and apply Pi self and extension updates before a new Pi process loads when that can be done safely; never replace files under an active Pi worker or treat an unknown liveness result as idle. If a safe update cannot run at that launch, record a visible pending outcome instead of silently skipping it. Preserve all existing task worktrees and the current uncommitted updater changes.

# Herdr lifecycle declaration - NOT ENABLED
**HARD SAFETY GATE:** this scaffold cannot inspect the task text filled in above.
If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
Do not add Herdr lifecycle commands to this unguarded brief by hand.

# Setup
You are in a disposable git worktree of firstmate, at a detached HEAD on a clean default branch.

**Verify isolation before anything else.** Run `pwd -P` and `git rev-parse --show-toplevel`; both must resolve to the disposable task worktree you were launched in, such as a treehouse pool path or an Orca-managed worktree, not the primary checkout firstmate operates from.
The path check is authoritative: `git rev-parse --git-dir` and `git rev-parse --git-common-dir` can help inspect the repo, but they do not prove you are outside the primary checkout.
If the top-level path is the primary checkout or not the worktree you were launched in, STOP - do not branch or commit here - append `blocked [at=<epoch>]: launched in primary checkout, not an isolated worktree` to the status file and stop.

1. First action: create your branch: `git checkout -b fm/tool-auto-update`

# Rules
1. Never push to any remote and never open a PR. Work only on your `fm/tool-auto-update` branch; firstmate handles the merge into local `main`.
2. Stay inside this worktree; modify nothing outside it.
3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
4. Report status by appending one line:
   `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/tool-auto-update.status'`
   States: working, needs-decision, blocked, paused, done, failed.
   Substitute `<epoch>` with the current Unix time in seconds - run `date +%s` and write the number it printed; a stamp that is not plain digits records no time at all.
   Each append wakes firstmate, so report sparingly: only phase changes a supervisor
   would act on (setup done, bug reproduced, fix implemented, validation passed) and the
   needs-decision/blocked/paused/done/failed states. No step-by-step FYI progress lines;
   firstmate reads your pane for that.
   Whenever you mention a PR anywhere - a status line, your terminal, a summary - write its full
   https:// URL exactly as the forge printed it, never a bare number such as "PR 108"; firstmate
   copies that URL from your line rather than assembling one.
   A mid-task `working:` line (including setup complete) is nonterminal: do not end the
   turn after it; continue the same stage until a defined `done:` gate under Definition of done.
   Use `paused: {why}` - distinct from `blocked:` - ONLY when you are deliberately idling on a
   known external wait you expect to clear on its own (an upstream release, a rate-limit reset, a scheduled window, or your own validation round):
   firstmate then leaves your idle pane alone and rechecks it on a long
   cadence instead of treating it as a possible wedge. Use `blocked:` when you are stuck and need help.
5. If you hit the same obstacle twice, append `blocked [at=<epoch>]: {why}` and stop; firstmate will help.
6. If a decision belongs above the implementation worker (product choices, destructive actions),
   append `needs-decision [at=<epoch>]: {summary of options}` and stop. Firstmate will reply with the decision.

   A decision or blocker you opened stays open until a `resolved` line carrying its exact key lands; a later `done:` or `working:` line never closes it, even when the answer is what started that work.
   Firstmate's reply normally writes that closing line at answer time; when a blocker or wait clears WITHOUT a firstmate reply, append `resolved [at=<epoch>]: {how it cleared}` yourself (same `[key=<slug>]` if you opened it with one) as you resume.
7. Never stop, restart, or update the shared `no-mistakes` daemon - it is one instance serving
   every lane/home, so restarting it kills other lanes' in-flight pipeline runs; only firstmate
   manages the daemon.
   Before you append `blocked:` about the pipeline, run `no-mistakes daemon status` and
   `no-mistakes axi status`. If the daemon socket refuses connections or is missing, append
   `blocked [at=<epoch>]: {the daemon error}` and stop even when the local run record still says running or
   fixing, because that record can be stale after the daemon exits. A run record failed with a
   daemon error is also a real block.
   Only after ruling out socket refusal, if the run is still running or fixing, reattach and keep
   going. A drive-call error, timeout, slow read, or generic unreachability is NOT a daemon error:
   the daemon accepts `respond` immediately and runs the round in the background, so a killed or
   timed-out call was only waiting for a read while the run kept working.

# Firstmate instruction inbox
Firstmate steers you through durable message files in '/home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox'.
When a terminal message says an instruction is waiting there - and at any natural checkpoint when you are unsure - list '/home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox'/*.msg, read and act on each message in numeric order, then acknowledge each handled message by moving it: `mv '/home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox'/NNN.msg '/home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox'/handled/`.
The move IS the acknowledgement: without it firstmate rings again and eventually treats you as stuck. An empty or absent inbox needs no action.

# Project memory
If `AGENTS.md` or `CLAUDE.md` already exists, or if this task produced durable project-intrinsic knowledge, run `/home/hd2admin/kun-agent-workspace/bin/fm-ensure-agents-md.sh .` in the worktree.
Record only project knowledge useful to almost every future session.
For anything the codebase already shows, prefer a pointer to the authoritative file, command, or doc over copying the detail.
If you touch a project `AGENTS.md`, follow `/home/hd2admin/kun-agent-workspace/bin/fm-ensure-agents-md.sh`'s self-governance contract in the same pass.
Keep it proportionate: skip `AGENTS.md` edits for trivial tasks that produced no durable project knowledge.

# Definition of done
Delivery contract: mode=local-only
This task ships **local-only**: no remote, no PR, no pipeline.
The task is complete only when committed on your branch `fm/tool-auto-update`. Do NOT push, do NOT open a PR, do NOT merge.
Keep your branch a clean fast-forward onto the current default branch - if `main` has advanced, rebase onto it so the eventual merge stays a fast-forward.
When it is implemented and committed, append `done [at=<epoch>]: ready in branch fm/tool-auto-update` to the status file and stop.
The configured merge authority approves the ready branch, then firstmate merges it into local `main` through the guarded fast-forward path.

## Progress note (2026-09-23T04:15:16Z)

This task was relaunched. Continue from here; the local copy and every
uncommitted change are exactly as the previous worker left them.

First, check your instruction inbox: list /home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox/*.msg, act on
each message in numeric order, then mv each handled file into
/home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox/handled/. A steer sent before the relaunch survives there.

Coordinator review found blocking gaps in the committed implementation: the armed shim only reads prior outcome records and never invokes an update scan/install; --all has no read-only version-available check and would run installers regardless; --check only prints gate/allowlist status; and Pi extensions are not included. Please correct these before done: make the scheduled path check each tool for an actual update, install only then and only after its live-worker gate passes, include Pi extensions through Pi's supported updater, and surface manual-required/blocked outcomes once without repeating every poll. Keep the update interval bounded, do not modify the live host, do not use shell &, do not add or run tests, and preserve existing work. The reviewed branch is 8f6216b.

## Progress note (2026-09-23T05:24:10Z)

This task was relaunched. Continue from here; the local copy and every
uncommitted change are exactly as the previous worker left them.

First, check your instruction inbox: list /home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox/*.msg, act on
each message in numeric order, then mv each handled file into
/home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox/handled/. A steer sent before the relaunch survives there.

Continue in the existing clean branch and pane. Implement only the reviewed timeout-bound fix: avoid starving slow Pi extension/self updates and keep watcher runtime bounded. Preserve the existing two commits. Follow the repo coding and no-mistakes workflow; report exact changed files, validation performed, and any remaining risk. Do not commit, push, open a PR, merge, or deploy.

## Progress note (2026-09-23T07:15:15Z)

This task was relaunched. Continue from here; the local copy and every
uncommitted change are exactly as the previous worker left them.

First, check your instruction inbox: list /home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox/*.msg, act on
each message in numeric order, then mv each handled file into
/home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox/handled/. A steer sent before the relaunch survives there.

Captain added this exact follow-up to the task brief: “please set this shit to auto update on load.... NOW”. Continue in this same tree and preserve the existing uncommitted timeout-bound changes. First create and print the live Pi TODO, then inspect the real Pi invocation path and wire a safe self+extension update check before a new Pi process loads, reusing the watcher/install/live-worker gates. Never replace files under an active Pi worker; make any blocked or unverifiable update visible. No tests unless explicitly asked, no commit/push/PR/merge/deploy. Use MiniMax-M2.7 for this relaunch.

## Progress note (2026-09-23T07:57:00Z)

This task was relaunched. Continue from here; the local copy and every
uncommitted change are exactly as the previous worker left them.

First, check your instruction inbox: list /home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox/*.msg, act on
each message in numeric order, then mv each handled file into
/home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox/handled/. A steer sent before the relaunch survives there.

Do a bounded review and verification of the existing on-load auto-update implementation in this same worktree. Keep a visible three-step TODO: inspect the session_start path; run only the existing focused checks needed to verify it; report exact files, evidence, and whether it is active in the primary installation. Do not edit files, install or update tools, commit, push, open a PR, merge, or deploy. Preserve the branch and all current work. No child agent needed.

## Progress note (2026-09-23T16:19:26Z)

This task was relaunched. Continue from here; the local copy and every
uncommitted change are exactly as the previous worker left them.

First, check your instruction inbox: list /home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox/*.msg, act on
each message in numeric order, then mv each handled file into
/home/hd2admin/kun-agent-workspace/state/tool-auto-update.inbox/handled/. A steer sent before the relaunch survives there.

Captain authorized focused non-network regressions and fixes for the three identified cases: current-pane exclusion, timeout cleanup on child close/error, and the scheduled/on-load duplicate-install race. Read and acknowledge inbox message 009. Continue the same local-only task in its existing worktree and branch `fm/tool-auto-update` at `dac9e8e`; current worktree is clean and the three commits must remain intact. Add/run only the focused tests needed to prove those behaviors and the relevant existing local suite. Fix only demonstrated failures. Do not make network calls, update/install tools, deploy, push, open a PR, or merge. Keep the Pi TODO visible and update it around each test.
