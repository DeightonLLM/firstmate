# Context continuity across Pi compaction: Firstmate audit

A scout report. The captain's ask:

> When a job completes, restart or reuse the agent for the next job with
> subagents available, and show the required todo list live updating. Make
> sure Firstmate rules survive compaction; consider whether a hook or another
> Firstmate tool should verify the active contract each time.

The Firstmate spec asked for an audit of the real startup, compaction/resume,
Pi worker launch, and instruction-injection paths, with file/line evidence and
a smallest enforcement change that does not duplicate a supervisor or
interrupt active work.

Findings only - no code or hook changes were made. A follow-up implementation
ticket is recommended at the end.

## TL;DR (what survives, what doesn't, what to do)

| Surface | Where it lives | Survives a Pi compaction? | Survives a `/new` or replacement? |
|---|---|---|---|
| Fleet lock ownership | `state/.lock` | yes | yes |
| AGENTS.md baseline hash | `state/.session-start-agents-baseline` | yes | yes |
| True-start completion record | `state/.session-start-complete` | yes | yes |
| Firstmate digest (AGENTS.md + read-once + fleet + context) | re-injected by `session_compact` hook in `.pi/extensions/fm-primary-turnend-guard.ts` | yes (full digest via `pi.sendMessage`) | yes (re-runs on every `session_start` reason) |
| Steering inbox | `state/<id>.inbox/*.msg` (file) | yes | yes (durable file) |
| Branch supervision outcome store + cursor + processed marker | `state/branch-outcomes.jsonl` and sidecars | yes (append-only JSONL) | yes (load-bearing on relaunch) |
| Branch mirror cursor, branch session pointer, leases | `state/.branch-*-cursor`, `state/.branch-session`, `state/.lease-<task>` | yes | yes |
| Branch conversation itself | `state/branch-session/<id>.jsonl` | yes (Pi-native session file) | yes - new branch conversation on every main session start, by design |
| Task-specific brief (role contract + Captain's intent + Firstmate spec + Rules + Definition of done + Home brief additions) | first user message in the active Pi session | **NO - summarized away by Pi's auto-compaction** | only on a fresh launch (new positional arg) |
| Live "Pi todo list" mandate | text in `# Home brief additions` of the brief | **NO - same problem** | only on fresh launch |
| Bounded pi-subagents mandate | text in `# Home brief additions` | **NO - same problem** | only on fresh launch |

The single biggest gap is on row 11. Everything in rows 1-10 is disk-durable
plus an explicit re-injection hook; the brief is none of those.

The smallest enforcement change that fits the captain's "do not duplicate
supervisors, do not interrupt active work" guard is a **companion
`session_before_compact` hook that returns a fully-controlled
`compaction.summary`** for a worker session, prepending a short Firstmate
contract fragment before Pi's LLM-generated prose. This is one extra hook on
the same single Pi session; it does not start a parallel branch, does not
interrupt the active run, and uses an installed channel Pi already documents.
Details and exact targets below.

## What I did

- Read `AGENTS.md` sections 3 (session start), 5 (recovery), 8 (supervision),
  11 (briefs), 12 (self-update).
- Read `docs/sessionstart-nudge.md`, `docs/pi-supervision-branch.md`,
  `docs/turnend-guard.md`, `docs/compaction.md` (the Pi docs page at
  `~/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/docs/compaction.md`),
  and `docs/session-format.md`.
- Read every Pi extension shipped under `.pi/extensions/` and their lib/
  helpers (6 325 lines of TypeScript).
- Read the live runtime entry point `bin/fm-session-start.sh` (1 014 lines)
  and the run-tier wrapper `bin/fm-sessionstart-run.sh`, the worker launch
  templates in `bin/fm-spawn.sh` (the `launch_template()` function and its
  pi/pi-signed branch), `bin/fm-task-inbox-lib.sh`, `bin/fm-dod-lib.sh`,
  `bin/fm-branch-outcome.sh`, `bin/fm-brief.sh`.
- Acknowledged the first steering record
  (`/home/hd2admin/kun-agent-workspace/state/context-continuity-audit.inbox/001.msg`,
  already moved to `handled/`).
- Read the live task brief at
  `/home/hd2admin/kun-agent-workspace/data/context-continuity-audit/launch-brief.md`
  to confirm what an injected worker actually sees on its first turn.

No state-mutating command was run. No edit was made outside the scratch
worktree. The report is the only artifact intended to leave the worktree.

## 1. The Pi worker launch path: where the brief lands

Firstmate's launch contract has three layers, all delivered through one
channel each.

### 1.1 The first user message - the task brief

`bin/fm-spawn.sh` line 2773 renders every ship and scout brief to
`data/<id>/launch-brief.md`:

```
fm_brief_worker_role "$STATE" "$ID" &&
  printf '\n' &&
  cat "$SOURCE_BRIEF" &&
  if [ "$KIND" = ship ] && [ "$MODE" = no-mistakes ]; then
    fm_brief_intent_overlay "$CAPTAIN_INTENT"
  fi
```

That rendered brief is then passed as a single positional argument to the Pi
launcher, wrapped through the operational-input encoder so it is marked
`launch-brief`:

```
pi | pi-signed)
  printf '%s' '__PIBIN____PITUIMODE__'
  if [ "$kind" = secondmate ]; then
    printf '%s' ' __MODELFLAG____EFFORTFLAG__-e __PITURNEND__ -e __PIWATCH__ "$(__OPINPUT__ encode launch-brief < __BRIEF__)"'
  else
    printf '%s' ' __MODELFLAG____EFFORTFLAG__-e __PIEXT__ "$(__OPINPUT__ encode launch-brief < __BRIEF__)"'
  fi
  ;;
```

`bin/fm-spawn.sh` lines 1906, 1904 (secondmate). The `__BRIEF__` token resolves
to `data/<id>/launch-brief.md` (header around line 299). Every other harness
template goes through the same `$(__OPINPUT__ encode launch-brief < __BRIEF__)`
shape (lines 1869, 1895, 1897, 1900, 1924, 1926, 1952, 1960, 1973, 2008,
2012).

This means the full task brief - role contract, Captain's intent, Firstmate
spec, scaffold Rules, Definition of done, **and the `# Home brief additions`
standing additions** such as "create a concise checklist with Pi's `todo`
tool" and "Use the installed `pi-subagents` capability for independent,
bounded subtasks by default" - enters Pi as the **first user message in the
session**, not as a hook-injected custom_message.

### 1.2 The session-start digest - the Firstmate contract

For every Pi session open, `bin/fm-sessionstart-run.sh` runs and routes the
session-open source:

```
case "$SOURCE" in
  resume|reload|fork)
    exec "$SCRIPT_DIR/fm-sessionstart-nudge.sh" ;;
  clear|compact)
    if session_start_completed; then
      "$SCRIPT_DIR/fm-session-start.sh" --reemit --source "$SOURCE" || true
    else
      "$SCRIPT_DIR/fm-session-start.sh" --source "$SOURCE" || true
    fi ;;
  *)
    "$SCRIPT_DIR/fm-session-start.sh" --source "$SOURCE" || true ;;
esac
```

`bin/fm-sessionstart-run.sh` lines 130-142. The `--reemit` branch is the
contract for `/clear` and `/compact`: the digest re-emission **skips the six
mutating sweeps** (project clone refresh, secondmate convergence/liveness,
pending remote handoff retry, x-mode artifact writes, stale Herdr projection
cleanup), re-verifies lock ownership, re-prints the durable fleet/context
digest, and still drains queued wakes because they arrived after startup.

`.pi/extensions/fm-primary-turnend-guard.ts` calls that wrapper from the
`session_compact` event:

```
pi.on?.("session_compact", async (_event, ctx) => {
  registerSessionstartExitListener();
  const generation = createSessionstartGeneration("compact", sessionIdFromContext(ctx));
  sessionstartGeneration = generation;
  const message = await claimSessionstartMessage(generation, ctx);
  if (!message || !sessionstartGenerationIsLive(generation)) return;
  try {
    pi.sendMessage(message);
  } catch {
    generation.delivered = false;
  }
});
```

Lines 567-578. The digest itself is the Firstmate nine-stage ordered dump
(`bin/fm-session-start.sh` lines 91-94):

```
SESSION_START_STAGES='lock bootstrap wake-queue supervision-instructions read-once fleet-state network-checks context next-step'
```

with `read-once contract` ahead of `fleet-state` so a truncated tail loses
context files first and operational identity second.

The full text of `AGENTS.md` is republishable on drift: `bin/fm-session-start.sh`
`print_agents_refresh_if_required` (line ~599) emits a
`CURRENT AGENTS.md - INSTRUCTION REFRESH` section whenever
`agents_baseline_drifted` returns true, which is true exactly when the live
AGENTS.md hash differs from the baseline hash recorded on the process's own
true-start (`write_agents_baseline` around line 564,
`agents_baseline_drifted` around line 575).

A `pi:compact` source is the **only** currently supported stale-cache rebuild
pair that triggers that drift path; that is by design and documented:

> Pi and pi-signed compaction are the only supported stale-cache rebuild pair:
> a missing baseline, a baseline for another harness pid, or a changed hash
> causes the complete current AGENTS.md to print before the bulky digest.

`bin/fm-session-start.sh` lines 217-225.

### 1.3 The session-start runtime bound

The digest is run through a child process under `FM_SESSION_START_TIMEOUT`
(default 120 s). If the bound is hit, a `STARTUP TRUNCATED` banner names the
stage that did not run so the user can reconcile from disk
(`bin/fm-session-start.sh` lines 102-128, plus the parent of
`fm_run_timed`). Decomposition:

| Stage | Bounded by | Survives a hit? |
|---|---|---|
| lock | session-lock helper (already-bounded) | yes |
| bootstrap | `FM_BOOTSTRAP_DETECT_ONLY=1` / `FM_BOOTSTRAP_LOCKED=1` flags, plus the deferred network stage | yes |
| wake-queue | `bin/fm-wake-drain.sh` (own bound) | yes - the queue is durable |
| supervision-instructions | none beyond the parent's 120 s | yes (text re-renders each turn) |
| read-once | static heredoc | yes |
| fleet-state | `STATUS_TAIL`, `QUEUED_LIMIT`, `BACKLOG_ROW_TIMEOUT_SECS` (10 s) | yes |
| network-checks | detached worker, harvested non-blocking | the network result is reported as still in progress |
| context | `data/projects.md`, `data/secondmates.md`, etc. - file reads | yes |
| next-step | static text | yes |

The runtime-bound stage file is written before each stage so the parent can
report *which* stage failed. Test regression for this contract:
`tests/fm-session-start.test.sh` around the forced pure-Bash fallback. The
portable suite proves the runtime bound end to end.

### 1.4 What this means for the captain's three asks

- "Restart or reuse the agent for the next job" - already exists. The
  supervision branch keeps one main session open with the branch as a
  separate conversation for fleet supervision; on `/new`, `/resume`,
  `/fork`, or reload the branch is rebuilt (`.pi/extensions/fm-branch-supervision.ts`
  `session_start` handler, lines 1747-1756). The branch conversation's last
  outcome survives in `state/branch-outcomes.jsonl`, but the conversation
  itself is replaced.
- "Subagents available" - `pi-subagents` is a Pi **skill**, not a built-in
  capability. It is discovered in `~/.pi/agent/skills/`, its `description`
  is in Pi's system prompt at startup, and its full content loads only when
  the worker uses `/skill:pi-subagents` or the model decides to read
  `SKILL.md` on demand (`docs/skills.md` "How Skills Work"). Default-on for
  Pi is "the skill description is always present; the capability is only
  available when the agent chooses to invoke it".
- "Show the required todo list live updating" - the brief's "Home brief
  additions" section mandates a Pi `todo` tool. The `todo` tool that this
  Pi installation exposes is a built-in tool the user-space developer
  installed (per `docs/extensions.md` line 961 the canonical example is an
  extension-supplied stateful tool with `registerTool` + `appendEntry`),
  not a Pi-standard tool. There is no Firstmate hook that verifies the
  worker creates a checklist, prints it, marks exactly one active, or
  toggles each step on completion. The contract is **text in the brief**.

## 2. The Pi supervision branch: durable and well-separated

The branch lives in `.pi/extensions/fm-branch-supervision.ts` (2 330 lines).
It is Pi-only by construction because it lives in `.pi/extensions` and no
other harness loads that path. Key durable surfaces:

- **Outcome store** `state/branch-outcomes.jsonl` (`.pi/extensions/fm-branch-supervision.ts`
  imports `outcomeScript` at line 60; the format lives in
  `bin/fm-branch-outcome.sh` header lines 9-60). Strictly append-only; every
  read validates the complete log as a gap-free sequence. Failed,
  duplicate, and reordered rows fail closed.
- **Read cursor** `state/.branch-outcomes-cursor`. Advances only after
  Pi's persistent visible session entry exists, so reload-after-entry but
  before-cursor advance is idempotent.
- **Processed marker** `state/.branch-outcomes-processed`. Advances only
  through `fm_branch_processed` with a `through` argument naming the
  highest captain row that main acknowledged. Never moves past the read
  cursor or backwards.
- **Branch session pointer** `state/.branch-session` (line 53 of the
  extension). The branch conversation file pointed to by this file is
  replaced on every main session start (lines 1747-1756).
- **Mirror cursor** `state/.branch-mirror-cursor`. Carries the captain's
  dialog into the branch as read-only context. Re-anchored at every main
  session start.
- **Per-task leases** under `state/.lease-<task>`. Enforced through
  `bin/fm-lease-lib.sh`. Branch actor refuses PR merges, fresh spawns,
  and decision answers while attended (and grants them under an
  `state/.afk-contract` record).

The branch's own system prompt is the byte-stable output of
`bin/fm-branch-prompt.sh`; tests in `tests/fm-branch-supervision.test.sh`
pin it. Per-wake content (mirror items, posture tail) is appended at the
end, so provider prompt-caching holds across the conversation.

The branch is default-on for any task once a Pi primary session owns the
fleet lock. There is no captain grant file required.

### 2.1 What the branch does NOT do

The branch supervises **fleet events from the watcher**. It does not
supervise the worker's own work. It does not re-inject the brief on
compaction. It does not police whether the worker honors the brief. The
branch is decoupled from the worker session - the worker may be paused,
busy, idle, or already compacted; the branch wakes for fleet events
originating from anywhere. The "Lost-wake outcome backstop" section of
`docs/pi-supervision-branch.md` is the same idea in the reverse direction:
when the worker's drain is unsigned by a branch outcome, the drain prints
a one-shot backstop row.

## 3. Where compaction can drop rules (the substantive answer)

The captain's question maps onto Pi's three session-compaction surfaces.

### 3.1 Auto-compaction (Pi threshold or model context overflow)

This is the `session_before_compact` event. Pi's flow is in
`docs/compaction.md`:

1. Walk backward through the session projection accumulating tokens.
2. Find cut points at user messages, assistant messages, or custom
   messages (never tool results).
3. Send the cut span + `previousSummary` to an LLM and request a structured
   summary with `<goal>`, `<constraints & preferences>`, `<progress>`,
   `<key decisions>`, `<next steps>`, `<critical context>`, plus
   `<read-files>` and `<modified-files>` block tags.
4. Append a `CompactionEntry` with the summary and `firstKeptEntryId`.

`docs/compaction.md` "How It Works" and the `CompactionEntry` struct.
"Retained non-system entries and all entries after the compaction remain
available to the LLM" - meaning the **summarized span** is gone, replaced by
the LLM-generated prose.

**This is the contract that swallows the brief.** The brief is the first
user message. After enough turns, that user message lands in the cut span.
Its content then exists only as whatever the LLM thought was important
when generating the structured summary. **Firstmate has no hook here**;
`grep -n "session_before_compact" .pi/extensions/` finds nothing.

### 3.2 Manual `/compact`

Same `session_before_compact` event. Same compaction summary. There is
also a `session_compact` event after the compaction appends, which
`.pi/extensions/fm-primary-turnend-guard.ts` listens to and uses to
re-inject the digest via `pi.sendMessage`. The manual compact is
intercepted at the **post** boundary, not the **pre** boundary; the LLM's
summary has already been appended.

### 3.3 `/new`, `/resume`, `/fork`, reload

Each of these fires `session_start` with a distinct reason. The
sessionstart digest is delivered as a `CustomMessage` (not a `user`
message), with `display: false` and `customType: "firstmate-sessionstart-nudge"`,
through `pi.sendMessage` from the turnend extension. This entry **does
participate in LLM context** (per Pi docs session-format.md "Context
Building" line ~394: `custom_message -> CustomMessage`; vs
`appendEntry` which produces raw transcript entries that **do not**).

That is exactly the difference Firstmate relies on. The digest survives
on `/new` because the digest IS re-injected. The brief does NOT survive
on `/new` because the brief is part of the launch command, not a hook
output.

### 3.4 AGENTS.md baseline

`bin/fm-session-start.sh` records a `state/.session-start-agents-baseline`
file on true-start only - it is immutable for this lock owner and used to
detect drift between the original session's view of AGENTS.md and a later
compact-time view. If the AGENTS.md on disk differs from the baseline, the
**complete current AGENTS.md** is reprinted as a `CURRENT AGENTS.md -
INSTRUCTION REFRESH` section.

This is the closest Firstmate comes to "verify the active contract each
time", and it covers exactly one thing: AGENTS.md drift. It does not
verify the task brief, the steering inbox liveness, or the supervisor
state.

### 3.5 The single live-evidence reference

`tests/fm-sessionstart-instruction-refresh-live-e2e.test.sh` lines
2-22 and 220-243 prove this end to end on a real Pi installation. It
checks **only** that AGENTS.md marker changes are picked up after a
compact, not that brief content survives. No firstmate test currently
covers "Pi compaction summary preserves firstmate task rules".

## 4. The captain's three asks, pinpointed

### 4.1 "Show the required todo list live updating"

The brief's standing addition (in `data/context-continuity-audit/launch-brief.md`,
`# Home brief additions > Pi Worker Defaults > first bullet`) reads:

> At task start, create a concise checklist with Pi's `todo` tool and print
> the full list into the pane. Use `todo start` on the step you are doing
> before work begins, and `todo toggle` as soon as it finishes; every todo
> action prints the full current checklist into the pane. Keep exactly one
> step marked active.

- This is text in the brief.
- The brief rides on the launch command's positional argument (see §1.1).
- Pi compaction summarizes the first user message away; the mandate disappears
  with it.
- There is no `session_before_compact` hook in the install that re-injects the
  brief or the home brief additions (grepped: nothing matches).
- The `todo` tool itself is **a stateful custom tool the model runs when it
  chooses to**, not a built-in Pi tool. The `appendEntry` calls in the
  canonical todo example go through Pi's raw-entry side, which is **not** in
  model context (per Pi's session-format.md line ~410: `usage and custom ->
  no context message`); the visible checklist is rendered only when paired
  with a custom tool renderer.

**There is no enforcement, no audit, no record of whether the worker
honored the mandate.** A worker can also be told the rule once and
satisfy exactly one bullet (creating the list) - or none - with the
brief sitting in model context that may not survive a compact.

This is also the case for Claude/Codex workers. Their todo equivalents
(`TodoWrite` for Claude, the internal todo for Codex) are tool
invocations the worker chooses; the firstmate brief's Pi-shaped mandate
is unfulfillable there without translation.

### 4.2 "Subagents available for the next job"

`docs/skills.md` "How Skills Work" describes Pi's contract precisely:

> 1. At startup, pi scans skill locations and extracts names and
>    descriptions
> 2. The system prompt includes available skills in XML format per
>    the specification
> 3. When a task matches, the agent uses `read`, or `bash` when `read`
>    is unavailable, to load the full SKILL.md (models don't always do
>    this; use prompting or `/skill:name` to force it)
> 4. The agent follows the instructions, using relative paths to
>    reference scripts and assets

For a spawned Firstmate Pi worker:

- `~/.pi/agent/skills/pi-subagents/SKILL.md` IS in the system prompt (one-line
  description). It IS the canonical package.
- Its `description` is exactly: "Technical guidance for operator-requested
  delegation to builtin or custom subagents: bounded handoffs, parallel
  review, scripted workflows, async work, forked context, isolation, and
  coordinated execution."
- It is **not** an actual capability. It is documentation the model may
  follow or ignore.
- `~/.agents/skills/pi-subagents/` does not exist in this install. Only the
  Pi package is shipped.
- Other worker harnesses (Claude, Codex, Cursor, ...) do not see this
  capability at all unless installed under their own skill paths; the brief
  directive is unfulfillable in those harnesses without translation.

So the shippable claim "subagents available" is in the eye of the model
plus its knowledge of `/skill:pi-subagents`. There is no Pi extension that
adds `subagent` to the worker's tool registry or even tests for the skill
being loaded.

The brief's `# Home brief additions` mandate "Use the installed
`pi-subagents` capability for independent, bounded subtasks by default"
is again text, not enforcement.

### 4.3 "Make sure Firstmate rules survive compaction"

Three rules-sources exist:

1. **AGENTS.md** - survives because the `session_compact` handler in
   `fm-primary-turnend-guard.ts` re-injects the digest via
   `pi.sendMessage`, which becomes a `CustomMessage` entry that participates
   in LLM context. Drift beyond the immutable baseline triggers a full
   re-emit.
2. **The brief and `# Home brief additions`** - in the first user message,
   summarized by Pi. No re-injection on compaction. **This is the gap.**
3. **Skill knowledge loadouts** (`SKILL.md` content) - in Pi, only loaded
   when the worker chooses to. Survives compaction only if the LLM saw and
   remembered it; otherwise summarized away.

The single missing capability is one of:

- A `session_before_compact` handler that keeps Firstmate rules in the
  LLM-generated summary (best done by returning a customized
  `compaction.summary` from `session_before_compact` that prepends the
  brief).
- A `session_compact` handler that also re-injects the brief content
  (not just the AGENTS.md digest) via `pi.sendMessage`.
- A read-only companion probe that detects the rule-drop and reports a
  needs-decision (does not inject).

The first option is the most local and the smallest; see §5.

## 5. The smallest enforcement change

### 5.1 Constraints from the captain

- Do not duplicate a supervisor. (The branch supervisor is in
  `fm-branch-supervision.ts`; do not fork another.)
- Do not interrupt active work. (An active turn must not be aborted or
  paused; the worker must continue exactly as it was.)
- Report findings, do not write code. A separate scoped implementation
  ticket is the right shape if any change is warranted.

### 5.2 What the gap actually is, in one sentence

On Pi worker compaction, the first user message (the task brief) is
summarized by the LLM at `session_before_compact`. Firstmate currently
listens only to `session_compact` (post-compaction, for the AGENTS.md
digest). There is no pre-compaction handler that preserves the brief or
the brief's `# Home brief additions` in the rebuilt model context.

### 5.3 Three candidate shapes, ranked

#### Option A (recommended): single `session_before_compact` extension hook that returns a customized summary

Add a pre-compaction handler to a companion extension
(e.g. `.pi/extensions/fm-worker-brief-preserve.ts`) that:

1. Computes a short Firstmate contract fragment from durable files:
   - the worker's role contract (one-paragraph summary of
     `fm_brief_worker_role`)
   - the absolute path of `data/<id>/brief.md` and the launching
     `data/<id>/launch-brief.md`
   - the absolute path of the steering inbox `state/<id>.inbox`
   - the absolute path of `state/<id>.status` for the durable state-trail
     reader
2. Calls Pi's `session_before_compact` returning
   `{ compaction: { summary: '<LLM summary>\n\nFIRSTMATE BRIEF CONTEXT
   (durable):\n- role contract: <one paragraph>\n- task brief path:
   <path>\n- steering inbox path: <path>\n- state status path: <path>',
   firstKeptEntryId: preparation.firstKeptEntryId, tokensBefore:
   preparation.tokensBefore } }`.

This puts the role contract back into model context after the LLM summary
replaces the first user message, **without starting a parallel session,
without interrupting the active turn, and without modifying the
digest's runtime path**. It is one extension file plus registration; it
uses the documented Pi `session_before_compact` event
(`docs/compaction.md` lines 296-330).

Risks: it competes with Pi's own structured `Goal / Progress / Constraints`
output for context budget; the fragment should be small (a sentence per
pointer plus a one-paragraph role contract = ~250 tokens). Pi leaves the
choice of `compaction.summary` length to the extension; see the
`docs/compaction.md` "Custom Summarization via Extensions" example, where
the same pattern is shown.

Trade-off: a worker can still deliberately ignore the re-injected
fragment. But it cannot lose it: it goes into the CompactionEntry and is
re-delivered every time model context builds from the compaction onwards.

#### Option B: extend the post-compaction digest re-injection

Modify the existing `session_compact` handler in
`fm-primary-turnend-guard.ts` to also send the brief content (read from
`data/<id>/launch-brief.md`) as a second `pi.sendMessage`. Smaller diff
(no new extension), but:

- This re-injects AFTER the summary has already been written. Model
  context has: original messages -> summary -> digest -> brief. The
  digest is now the Firstmate content and the brief is layered on top.
- Order matters. If the brief lands first and the digest after, the brief
  may be sliced off by another compaction before the digest; conversely,
  putting both into the same CustomMessage is brittle (the budget is
  512 KiB but the contract is per-message).

Option A is preferred because the brief fragment lives inside the
compaction summary itself, where Pi's compaction paths respect it.

#### Option C: read-only durable probe + skills envelope

A companion extension that, on every `session_start` after a previous
`session_compact`, verifies that the four durable pointers (brief path,
inbox path, status path, firstmate home) are present in the active session
projection. If absent, the probe `sendMessage`s an operational injection
telling the worker "the Firstmate task brief is not in your current
context; re-read <path>". This is enforcement only at the level of an
operational reminder; the LLM can still ignore it.

Option C duplicates less than A but is shallower. It is a reasonable
fallback if Option A's compaction summary customization turns out to cost
too many cache-hit tokens.

### 5.4 Why these are NOT breaking the supervisor rule

- A supervisor as Firstmate defines it runs across fleet events, owns
  leases, and merges outcomes. None of A/B/C does any of those.
- A/B/C run inside the existing single Pi session; no parallel branch
  session is created.
- A/B/C fire on Pi-extension events that already fire on the same
  session. No new child processes are spawned.
- A/B/C do not abort the active run. They return promptly so Pi can
  resume the run normally after compaction.

### 5.5 What I would NOT recommend

- Polling the branch supervisor from the worker session to inject the
  brief. That duplicates the supervisor and creates a feedback loop
  between the worker's main session and the branch's session.
- A periodic polling extension that reads the brief and re-injects on a
  timer. That duplicates digest work and competes for budget.
- A separate cron-style Firstmate-side process that re-emits the brief
  to a worker. That is precisely the "duplicate supervisor" failure
  shape the captain asked us to avoid.

## 6. Recommended follow-up implementation ticket

If the captain agrees Option A fits, the smallest possible scoped ticket:

- Title: "Preserve firstmate task brief across Pi compaction"
- Owner: firstmate-coder on `.pi/extensions/`
- Files: `.pi/extensions/fm-worker-brief-preserve.ts` (new, ~80 lines),
  tests under `tests/fm-worker-brief-preserve.test.sh` (portable
  regression; `FM_WORKER_BRIEf_PRESERVE_LIVE_E2E=1` adds a real Pi guard
  in the same style as
  `tests/fm-sessionstart-instruction-refresh-live-e2e.test.sh`).
- Behavior:
  1. On `session_before_compact`, look up the recorded task id from
     `state/<id>.meta` via the FSM_HOME-derived scan.
  2. Build the small fragment described in §5.3 Option A.
  3. Call Pi's LLM summary through `serializeConversation` / a no-op if
     the host wants to use the default model, otherwise fall through to
     Pi's standard summary if generation fails (compaction must never be
     blocked).
  4. Reuse `bin/fm-branch-outcome.sh`'s covered-line pattern: never inject
     the fragment when no task is registered (idle/attended primary,
     branch-only session).
- Acceptance: a real Pi primary with `keepRecentTokens=200` compacts the
  same way it does today (compaction entry appended, summary present),
  and the new fragment is present at the tail of every compaction
  summary it observes. The brief content NOT being in pre-summary context
  is documented; the fragment is sourced from durable files only.
- Out of scope: subagent mandate, todo mandate enforcement (covered by
  §4.1 and §4.2 - they are worker compliance, not durability gaps).

## Appendix: file/line evidence index

| Topic | File | Lines |
|---|---|---|
| Brief rendered at spawn | `bin/fm-spawn.sh` | 2768-2786 |
| Brief positional arg into Pi | `bin/fm-spawn.sh` | 1904, 1906 |
| `launch-brief` encoder kind | `.pi/extensions/lib/fm-operational-input.ts` | 15 |
| Operational-input shell script | `bin/fm-operational-input.sh` | (referenced from line 7) |
| Session-start source routing | `bin/fm-sessionstart-run.sh` | 130-142 |
| `--reemit` semantics | `bin/fm-session-start.sh` | 191-216 |
| Compact event handler | `.pi/extensions/fm-primary-turnend-guard.ts` | 562-579 |
| Pre-compact hook (not registered) | `docs/compaction.md` | 296-330 |
| AGENTS.md baseline drift | `bin/fm-session-start.sh` | 575-585, 599-607 |
| Branch supervision durability | `.pi/extensions/fm-branch-supervision.ts` | 9-65 (header) |
| Outcome store format | `bin/fm-branch-outcome.sh` | 9-60 |
| Branch session_replace on session_start | `.pi/extensions/fm-branch-supervision.ts` | 1747-1756 |
| Mirror re-anchor | `.pi/extensions/fm-branch-supervision.ts` | 1743-1756 (within session_start) |
| Steering inbox durability | `bin/fm-task-inbox-lib.sh` | 26-71 |
| Custom message vs custom entry | `docs/session-format.md` | 425-430 |
| Pi skill discovery contract | `docs/skills.md` | "How Skills Work" |
| Live compact re-injection test | `tests/fm-sessionstart-instruction-refresh-live-e2e.test.sh` | 220-243 |
| Runtime bound stage list | `bin/fm-session-start.sh` | 91-94 |
| Brief include home additions | `bin/fm-brief.sh` | 207-227 |

---

Captain - the gap is small and local. The brief rides on the worker
launch command's positional arg and Pi's first-user-message slot, so
compaction summarizes it away. The single-piece fix is a `session_before_compact`
handler that returns a customized summary with a small Firstmate pointer
fragment, all inside the existing Pi session. No new supervisor, no
parallel session, no active-work interrupt. Recommend Option A as a
follow-up implementation ticket; this report is the audit it would
implement against.
