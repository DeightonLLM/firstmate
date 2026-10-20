# Prompt Orchestration Contract

Load this module when writing an execution prompt, multi-lane prompt, delegated task, or browser-routed prompt. It extends the one-deliverable rule in `OUTPUT_CONTRACT.md`; it does not authorize execution or delegation by itself.

## One coordinator, multiple lanes

- Prefer one paste-ready coordinator prompt when one receiving agent can own the outcome end to end.
- When the work contains genuinely independent, bounded lanes, instruct the coordinator to use its approved subagent facility when available (for example Pi's installed subagent plugin) and run safe lanes concurrently.
- The coordinator remains accountable for scope, dependency ordering, evidence review, shared-file reconciliation, cleanup, and the final classification. Subagents do not become separate operator workflows.
- Do not manufacture parallelism. Keep dependent work sequential, and do not run agents concurrently when they would edit the same files, mutate the same live resource, reuse one browser profile, or compete for a finite exclusive resource.
- If the subagent facility is unavailable, the coordinator executes the same lanes itself without stopping merely to request another prompt.

## Mandatory To-Do List behavior

Every execution prompt must say **Use the To-Do List extension** and require the receiving agent to build an in-depth, dependency-aware tracker before task action.

Every execution prompt must also contain a `PROGRESSIVE_DISCLOSURE:` field that
names the first one to three exact coordinates to read, prohibits broad scans
or history sweeps at task start, and permits scope expansion only to resolve a
specific unresolved To-Do item. Validate every completed lane prompt with
`/root/bin/validate-herdr-lane-prompt` before submitting it.

The tracker must:

- break work into preflight, diagnosis, rollback/backup, each bounded mutation, validation, documentation, version control, cleanup, and postflight;
- give each independent lane a parent item and granular child items;
- record blockers and dependencies so only genuinely unblocked lanes run in parallel;
- be updated throughout execution, not replaced by a prose progress summary;
- gate coordinator closeout on every required lane reaching a verified terminal state;
- never be duplicated as `todo.md`, `TODO.md`, `*_TODO.md`, or another filesystem task list.

## Subagent lane contract

For each delegated lane, the prompt must state:

- exact owner/host and mutation boundary;
- named starting coordinates (first one to three files, helpers, URLs, or commands);
- permitted edits and explicit forbidden actions;
- rollback and stop conditions;
- tests, live verification, evidence, documentation, Git, and cleanup requirements;
- the required final classification and what evidence is necessary to claim it.

Shared operational documents and shared release files are coordinator-owned unless the prompt assigns non-overlapping hunks. Reconcile shared files once after lane completion. Preserve unrelated worktree changes and use only verified repositories/remotes with scoped staging and non-force pushes.

## Herdr response reconciliation

When the operator authorizes work in existing Herdr panes, the coordinator owns the complete worker-response lifecycle:

- record each pane ID, assigned lane, mutation boundary, expected artifact, and terminal classification before dispatch;
- poll pane lifecycle state and read the pane response plus the actual deliverable instead of relying on an operator-pasted summary;
- review claims against the named evidence and send approval, rejection, or bounded corrections directly to the same pane;
- if a pane is blocked, inspect the blocker and restate existing operator authorization only when the blocked action remains inside the authorized scope; never bypass credentials, safety gates, or a new authorization boundary;
- repeat review and direct reply until every required lane is accepted or classified with a genuine terminal blocker;
- keep agent-level exchanges inside Herdr and give the operator one reconciled closeout, except when a material choice or new authority is required;
- never ask the operator to relay worker responses, and never close or release panes unless the operator explicitly requests it.

Coordinator closeout is prohibited while a required pane is merely `working`, has an unreviewed `done` response, or is awaiting a correction that remains within the authorized scope.

## Herdr model routing

Before assigning a Herdr lane, read `HERDR_AGENT_ROUTING.md` and verify both the pane lifecycle state and the runtime model displayed inside the pane. Route by verified model capability, not by the CLI/client brand (`pi`, `omp`, or `claude`) and not by a historical workspace name. OMP and Claude sessions running the same model receive the same capability classification.

Use this precedence:

1. GLM 5.3 Flash first for substantive review, checking, and high-impact non-browser work.
2. AGY Gemini 3.8 Flash Medium second for fast bounded implementation or review. Gemini 3.6 and all Gemini 3.7 routes are retired and refused (superseded by the 2026-09-02 route migration; see `HERDR_AGENT_ROUTING.md`).
3. MiniMax M3/M2.7 for basic work; M2.7 is the browser tier and M3 is non-browser only.
4. Queue browser work when no verified MiniMax M2.7 lane is available; never downgrade to a retired route.

If no eligible model is available, queue the lane instead of silently routing it to an ineligible tier. Parallelize only independent work with separate write targets, browser profiles, live resources, and rollback boundaries.

### Safe Herdr submission

- Build one complete coordinator-authored prompt and validate it before touching the pane.
- Do not include raw context-provider, compaction, page, tool, or worker-reasoning output. In particular, reject `context-mode active`, `<session_state`, synthetic role tags, and serialized tool calls.
- Confirm the pane is `idle` and confirm its displayed runtime model immediately before submission.
- Submit with one `herdr pane send-text` call and one `herdr pane send-keys ... enter` call. Do not combine follow-up text with an existing input buffer.
- Do not send another message while the pane is `working`. On queued/skipped/aborted output, stop, read the pane, and reconcile before any new input.

## Bounded Herdr execution

Every delegated Herdr prompt must load `HERDR_BOUNDED_EXECUTION.md` and state its attempt/retry contract. Unless the operator explicitly overrides it, use these defaults:

- maximum 3 meaningful attempts per failing step;
- maximum 1 retry after an initial network, DNS, or transient browser-tooling failure;
- maximum 2 coordinator revision rounds after the initial worker submission;
- stop when the same blocker occurs twice without new evidence;
- never rerun an unchanged test or repeat an unchanged mutation; and
- stop immediately on missing coordinates, authorization, rollback, credentials, target mismatch, or scope expansion.

A meaningful attempt must test a distinct evidence-backed hypothesis or apply a materially different scoped correction. Rewording the same idea, rerunning the same command, restarting the same tool, or waiting without an external-state reason is not a new attempt.

`REVISION_REQUIRED` is an interim coordinator decision, not a terminal lane state. A lane may close only with a classification defined in `HERDR_BOUNDED_EXECUTION.md`, including the existing policy-compatible coordinate and network states. Before stopping, preserve the last useful evidence, attempt counts, artifacts, cleanup state, and the exact condition required to resume.

## Browser routing flag

The **first non-empty line** of every agent prompt must be exactly one of these routing banners:

- `🚨 BROWSER AGENT REQUIRED — DO NOT SEND TO GEMINI`
- `✅ NO BROWSER WORK — SAFE FOR GEMINI`

This banner must appear before the role/host header and before the opening code fence when the prompt is presented to the operator. Do not rely on a field buried inside the prompt. Gemini is never an eligible executor for browser work.

The launcher derives this banner automatically from the explicit `BROWSER_WORK` field when the prompt omits it (`validate-agent-prompt-routing --banner-for YES|NO` is the canonical decision source), so lane authors do not hand-type model banners. A banner that is explicitly typed must match the capability — a contradicting banner is refused — and the browser refusal itself remains machine-checkable: browser work is eligible only on MiniMax M2.7, retired routes are refused unconditionally, and ineligible lanes are queued rather than downgraded.

Every agent prompt must also include one prominent field:

`BROWSER_WORK: YES` or `BROWSER_WORK: NO`

When `YES`, also identify:

- browser purpose: visual QA, authenticated functional QA, scraping, or deployment verification;
- target URLs and authentication boundary without exposing credentials;
- required browsers and viewports;
- whether the work needs a visible/operator browser or may use isolated headless automation;
- ownership of the browser profile/processes and cleanup requirements;
- finite-resource coordination: never kill, reuse, or interfere with another lane's browser processes.

Put `BROWSER_WORK` near the role/host header so the operator can immediately decide where to send the prompt. If only some lanes require a browser, the entire coordinator prompt uses the red browser banner and declares `BROWSER_WORK: YES`; label each lane separately.

Before returning a prompt, validate the draft with:

`/root/bin/validate-agent-prompt-routing <prompt-file>`

or pipe the prompt on standard input. A failed validation must be corrected before delivery.

## Prompt shape

A multi-lane execution prompt should normally contain:

1. the mandatory first-line routing banner;
2. role, host, owner, executor, handoff, mutation, and `BROWSER_WORK` fields;
3. one outcome and global safety boundaries;
4. To-Do List and orchestration instructions;
5. isolated lane contracts with dependencies and browser labels;
6. coordinator reconciliation and evidence review;
7. acceptance criteria, final classifications, Git/documentation requirements, cleanup, and stop conditions.

Keep the operator interface singular: one prompt in, one reconciled closeout out.
