# Parallel-dispatch audit — how Firstmate can keep the maximum safe number of independent ready ticket lanes active without giving every pane its own supervisor

**Task:** `parallel-dispatch-audit` (scout, read-only)
**Author:** Pi · MiniMax-M3 · `wF:p2` (worktree `/home/hd2admin/.treehouse/firstmate-46aafc/9/firstmate`)
**Captured:** 2026-09-23 (snapshot `2026-09-23T05:56:49Z`, quota snapshot `2026-09-23T05:56:53Z`)
**Companion reports already filed:** `data/orchestration-map/report.md`, `data/br-system-ticket-audit/report.md`. This audit does not repeat their topology or live-pane findings; it focuses on the **dispatch path, the queue-pump gap, and the quota ceiling that actually binds**.

---

## 1. Captain-facing summary

1. **Today, no helper refills a queue.** A queued ticket only becomes a worker when **firstmate** explicitly runs `bin/fm-spawn.sh <id> <repo> --harness …`. `bin/fm-watch.sh` surfaces status events and classified wakes; `bin/fm-teardown.sh` runs `tasks-axi ready` after a teardown to remind firstmate of the next options, but it does not itself call `fm-spawn.sh`. There is no script in `bin/` whose name contains `pump`, `dispatch-loop`, or `next-ready`. (`grep -rn 'pump\|next.*ready\|advance.*queue' bin docs .agents/skills` returns no dispatcher.)
2. **A queue-pump can be added as a single bounded bash loop firstmate runs after every actionable wake** — but the binding constraint is not visible panes or worktree slots, it is **quota runway**. On the live `quota-axi --json` at capture time, `minimax` (the harness+model used by every current worker) projects **10,844 s ≈ 3 h** of usable runway before the 5 h window exhausts; `zai/glm-5.3-flash` has the most generous runway (~21 h) but its `tools` scope is already at 0%; `claude`, `cursor`, `grok`, and `kimi` are `auth_required`. Spawning 25 workers today would burn the runway faster than the watcher can react.
3. **The smallest safe step toward the 25-worker ceiling is one new wrapper script, `bin/fm-queue-pump.sh`, that firstmate invokes after each wake**, which (a) reads `tasks-axi ready`, (b) parses each row's `repo:` and `--goal:` tag, (c) calls `quota-axi --json` once, (d) resolves the dispatch profile for each row through `config/crew-dispatch.json` and `quota-array-dispatch`, (e) skips held or dependency-blocked rows, (f) batches `fm-spawn.sh` calls with the existing `FM_SPAWN_DISPATCH_DELAY_SEC=0.25` pacing, and (g) stops at one of three terminal conditions: cap reached, no more `ready` rows, or provider runway exhausted. **Firstmate remains the only spawn authority**; the pump only packages its decision.
4. **Two-writer / duplicate-audit / hold-preservation safety is already built into `fm-spawn.sh`** through (a) the per-task lock `$STATE/.spawn-$ID.lock`, (b) treehouse's per-pool worktree allocation that rejects overlapping worktree roots, (c) `validate_spawn_worktree` that aborts if the resolved worktree is not distinct from the primary checkout, and (d) `tasks-axi`'s "an id can only be in `In flight` once" model that makes a duplicate audit structurally impossible. Captain holds are preserved because `tasks-axi hold --kind captain` rows are never returned by `tasks-axi ready`.
5. **Live visibility is also already built in.** Every `state/<id>.meta` records `herdr_pane_id`, `herdr_workspace_id`, `herdr_tab_id`, `model`, `harness`, and `kind`. `bin/fm-fleet-snapshot.sh --json` joins the backlog with `state/<id>.meta` and `bin/fm-crew-state.sh <id>`; `bin/fm-fleet-view.sh` renders it as a markdown table. The `herdr-pane-board-context` lane already in flight adds the Herdr `pane list` join (label, `agent_status`, terminal title); the parallel-dispatch layer only needs to consume that join.
6. **Recommendation:** ship the pump as a single ship ticket with one tight dependency on `herdr-pane-board-context`. Keep the captain's 25-worker ceiling as a configurable cap (`config/parallel-dispatch-cap`, default 6). Make the pump refuse when `tasks-axi ready` is empty, when the captain cap is met, when any required `quota-axi` window is `exhausted_now` or unauthenticated, or when any `blocked-by` is still unresolved. Anything the pump refuses goes back to firstmate through a `needs-decision [key=queue-pump] needs_human` line — never to an autonomous dispatch.

---

## 2. Current dispatch path — what code actually does

### 2.1 `tasks-axi` is a list-and-mutate tool, not a dispatcher

Verified at capture time on `/home/hd2admin/kun-agent-workspace`:

```
$ tasks-axi list --state queued
count: 0
tasks: 0 queued tasks in this backlog
$ tasks-axi ready
count: 0
ready: 0 unblocked queued tasks
```

`tasks-axi`'s 19 commands are `add list show start done reopen update rm block unblock hold unhold ready public-followup mv prune render setup`. None of them spawns a worker; `ready` and `list --state queued` are read-only queries (`bin/fm-tasks-axi-lib.sh` is the compatibility shim — its entire surface is `fm_tasks_axi_compatible`, `fm_backlog_backend_value`, `fm_backlog_backend_manual`, `fm_tasks_axi_backend_available`). The markdown-backend shim (`config/backlog-backend=manual`) is also non-dispatcher; `bin/fm-teardown.sh:535` shows the manual branch only moves a row from `In flight` to `Done` and appends a wake — no spawn.

### 2.2 `fm-spawn.sh` is the only spawn path

`fm-spawn.sh` (1725 lines, `bin/fm-spawn.sh`) is the single point of spawn. It takes either one `<task-id> <project-dir>` or one or more `<id>=<repo>` pairs (batch dispatch). Its own header says: *"Batch dispatch: pass one or more `id=repo` pairs instead of a single `<id> <project>`, e.g. `fm-spawn.sh fix-a-k3=projects/foo add-b-q7=projects/bar [--scout]`. Each pair re-execs this script in single-task mode."* (header lines 4-12).

Three independent locks prevent double-spawn:
- `$STATE/.spawn-$ID.lock` (`fm-spawn.sh:415-420`) — one per task id, acquired by `fm_lock_try_acquire`; if held, the spawn refuses with `error: another spawn is already creating task $ID`.
- `fm_guard.sh` runs once per non-batch call before any state mutation (`fm-spawn.sh:139`).
- The single-task loop (`fm-spawn.sh:396-414`) re-execs `bin/fm-spawn.sh "${pair%%=*}" "${pair#*=}"` so the per-task lock above is acquired for every pair; if one pair fails the loop logs `batch: FAILED to spawn <id> (<repo>)` and continues.

Worktree allocation runs `treehouse get` inside the worker pane (`fm-spawn.sh:1296`) and `validate_spawn_worktree` (`fm-spawn.sh:1342`) refuses unless:
1. the resolved worktree path is a real git worktree root (`git -C "$WT" rev-parse --show-toplevel` succeeds),
2. its physical path is distinct from `PROJ_ABS_REAL` (the primary project checkout),
3. the worktree root equals the path the pane's shell actually entered.

Two workers cannot own the same worktree because each call to `treehouse get` leases a fresh worktree slot from the pool; the same path appearing in two `meta` files would require the same treehouse slot, which is single-tenant.

The pace control between batch items is **250 ms** (`docs/configuration.md:226-233` and `fm-spawn.sh` header):
> *"When `fm-spawn.sh` receives a batch of task pairs, it waits **250 ms** between successive launches by default. This prevents a six-lane refill from bursting all prompt submissions into the provider at once and triggering avoidable rate limits. The delay is controlled by the numeric `FM_SPAWN_DISPATCH_DELAY_SEC` environment variable for diagnostics or a deliberately different cadence; an unset value resolves to `0.25`. The delay applies only between batch items and does not change the launch command or the worker's retry budget."*

That pacing primitive is already there; a queue pump only needs to feed `fm-spawn.sh` pairs from `tasks-axi ready`.

### 2.3 `fm-watch.sh` and `fm-teardown.sh` are observation/cleanup, not dispatch

- `bin/fm-watch.sh` (1124 lines) classifies wakes (signal / stale / check / heartbeat), absorbs benign ones, and queues only actionable ones to `state/.wake-queue`. Header line 4: *"Classifies supervision wakes in bash. In normal mode it absorbs benign wakes and keeps blocking; it queues and exits only for actionable wakes."* It never spawns a worker.
- `bin/fm-teardown.sh:530-534` is the closest existing code to a refill trigger:
  ```
  # Execute the done command and queue-ready command to advance the queue
  printf '%s\n' "Backlog: $ID just finished. Executing: $done_cmd"
  eval "$done_cmd" || printf '%s\n' "warning: tasks-axi done command failed for $ID" >&2
  printf '%s\n' "Backlog: $ID just finished. Executing: tasks-axi ready"
  tasks-axi ready || printf '%s\n' "warning: tasks-axi ready command failed" >&2
  ```
  `tasks-axi ready` is **just a list command**; the comment *"to advance the queue"* is aspirational. The teardown only prints the list; firstmate reads the printed list and decides whether to spawn.

So: **today, every spawn decision is a firstmate turn**. The dispatcher is a human-in-the-loop LLM, not a script.

### 2.4 The "no queue pump" finding is consistent with what `bin/fm-watch-arm.sh` does

`bin/fm-watch-arm.sh` (498 lines) is the arm-and-attach wrapper around the watcher. It is concerned with **watcher liveness**, not task spawning: it forks the watcher as a tracked child, verifies the liveness beacon, and emits `started`, `attached`, or nonzero `FAILED`. It contains no `fm-spawn.sh` invocation and no `tasks-axi ready` call (`grep -n 'spawn\|ready\|dispatch' bin/fm-watch-arm.sh` returns zero matches).

The `bin/fm-supervise-daemon.sh` away-mode daemon (`AGENTS.md` section 8, `docs/architecture.md` "Event-driven supervision") likewise never spawns — it only injects digests into the captain's pane.

---

## 3. Same-file/worktree ownership, dependency/hold checks, duplicate audits

### 3.1 Worktree ownership

Two lanes cannot write the same files because each lane gets:
- A unique `data/$ID/brief.md` (the brief scaffolding at `bin/fm-brief.sh` line 9: *"Scaffold a crewmate brief or persistent secondmate charter at `data/<task-id>/brief.md`"*);
- A unique `data/$ID/report.md` (scout deliverable path);
- A unique worktree leased from the treehouse pool via `treehouse get` (`fm-spawn.sh:1296`);
- A unique `state/$ID.meta` with `worktree=`, `endpoint_task_id=`, `herdr_pane_id=`, etc.

Two lanes pointing at the same worktree would require either (a) the same treehouse pool slot (single-tenant) or (b) a manual `git worktree add` to a path that already had one — neither path is in `fm-spawn.sh`. The `validate_spawn_worktree` invariant is enforced against the live pane cwd, not a static config (`fm-spawn.sh:1310-1342`), so a stale or pre-set worktree value cannot pass.

**Captain-owned shared files** (e.g. `data/backlog.md`, `data/goals.md`, `config/crew-dispatch.json`) are not written by workers; only `fm-teardown.sh` and the captain's firstmate session mutate them. The proposed pump also only writes `state/$ID.meta` and appends to `state/$ID.status`; it never touches backlog rows directly (it asks `tasks-axi start` and `tasks-axi ready` to do that).

### 3.2 Captain holds and dependency blocks

`tasks-axi hold --kind captain <id>` makes the row invisible to `tasks-axi ready` until `--until` or `unhold`. The pump's input is `tasks-axi ready`, so held rows simply do not appear; no extra guard needed.

`tasks-axi block --by <id>` adds the row to the row's `blocked_by_ids` set; the snapshot normalises this to `unresolved_blocker_ids` only when the blocker is **not yet `Done`**. `tasks-axi ready` filters unresolved blockers out, so a blocked row does not surface. The pump inherits this for free.

### 3.3 Duplicate audits

`tasks-axi` is the single source of truth and a row can only be in one section (`In flight`, `Queued`, or `Done`). A duplicate "audit" of the same topic requires either (a) minting a second `tasks-axi add` row with a different id (visible in the snapshot as two records, easy for firstmate to detect), or (b) re-opening a `Done` row via `tasks-axi reopen`. Both are explicit operator actions; neither happens silently.

The pump's job is to spawn one worker per row, not to create new rows.

### 3.4 Dependency edges between lanes

`data/goals.md` (read at `data/parallel-dispatch-audit/../goals.md`) declares:
> *"Parallelism: scale toward the captain's stated ceiling of 25 workers across at most five disjoint streams; never start a worker without a ready ticket and one clear worktree owner."*

The five disjoint streams are an organizational guideline, not a `tasks-axi` field. The pump cannot enforce that two lanes belong to different streams without an explicit `stream:` tag in the row body; this is one of the audit's open questions (see §7).

---

## 4. Quota evidence today — the real ceiling

`quota-axi --json` at capture time (`/home/hd2admin/kun-agent-workspace`, model `MiniMax-M3`, harness `pi`):

| Provider | `state.status` | Effective headroom | Usable runway | Limiting window |
|---|---|---|---|---|
| `minimax` | fresh | 76% | **10,844 s (≈3 h) → projected exhaustion 2026-09-23T08:57:48Z** | `model:general:5h` |
| `codex` (Plus) | fresh | 53% session / 79% weekly | through_reset | `five_hour` (limiting) |
| `zai` (GLM 5.3 Flash) | fresh | 36% all-models / **0% tools** | 75,652 s (≈21 h) on `weekly`, **`exhausted_now` on `mcp_month` tools** | `weekly` (all-models), `mcp_month` (tools) |
| `claude` | **auth_required** | — | — | — |
| `cursor` | **auth_required** | — | — | — |
| `copilot` | fresh | 100% chat / 100% completions / **0% premium_interactions** | unknown (unmeasurable) | `unknownWindowIds: [chat, completions, premium_interactions]` |
| `grok` | **auth_required** | — | — | — |
| `kimi` | **auth_required** | — | — | — |

The captain's `data/captain.md` pins the stack:
- **Coordinator** — Codex on Luna, continuous
- **Worker** — MiniMax M3, all coding
- **Discovery** — GLM 5.3 Flash, lint/schema/search
- **Batched Reviewer** — Codex Sol High, grouped review (3-5 tickets per turn)

Four of those six need credentials the captain has not authorized on this home (auth_required), and the one fully-credentialed worker model (`minimax`) projects **3 hours** of runway. `zai/glm-5.3-flash` is the only provider with long runway but its tools scope is exhausted — usable for `--intelligence low` reading-only tasks, not for spawning new workers.

**Conclusion:** the binding constraint on parallelism today is **provider runway on the only fully-credentialed worker model**. The 25-pane captain ceiling is not reachable without re-authenticating at least one more provider or accepting that `minimax`'s 5-hour window will throttle mid-burst.

---

## 5. Dispatch-profile evidence and model selection

### 5.1 Current `config/crew-dispatch.json`

```
{
  "rules": [
    { "when": "high-complexity technical architecture, product design, creative brainstorming, or grouped review of 3-5 completed tickets",
      "use": { "harness": "pi", "model": "gpt-5.6-sol", "effort": "low" },
      "why": "Codex Sol Low is reserved for batched architectural reviews across completed tickets to preserve quota." },
    { "when": "live news, current events, X/Twitter data, market sentiment, or web-connected research",
      "use": { "harness": "grok", "model": "grok-4.5", "effort": "high" },
      "why": "Grok Build is bundled with X subscription..." },
    { "when": "routine day-to-day coding, bug fixing, test writing, refactoring, or feature implementation",
      "use": { "harness": "pi", "model": "MiniMax-M3", "effort": "medium" },
      "why": "MiniMax M3 is the primary execution worker..." }
  ],
  "default": [ { "harness": "pi", "model": "MiniMax-M3", "effort": "medium" } ]
}
```

This file is the canonical input for `AGENTS.md` section 4 and the `quota-array-dispatch` skill. Rules match natural-language task descriptions and emit one harness+model+effort tuple. With three rules and one default, today the matched profiles are **singletons**, not arrays — the `quota-array-dispatch` array-resolution procedure is dormant in this home until a rule returns an array. The pump only needs to consume a single tuple per task today.

### 5.2 Hard precedence — captain override, then best-fit, then default, then static

`AGENTS.md` section 4 spells the dispatch-intake contract:

> *"Routing precedence is an explicit per-task captain override, then the best-fit configured rule, then the configured default, then the static crewmate harness. Firstmate alone resolves a matched profile array: run `quota-axi --json` at that intake, evaluate every configured candidate against that current output, and choose with inspectable effective headroom and usable runway, using pace and reserve only later when needed."*

> *"Account for every candidate with the catalog evidence, provider relationship, applicable quota and authentication facts, remaining uncertainty, fit and reasoning class, and the headroom, runway, and later pace or reserve evidence used in selection; never omit a candidate, guess, fall back silently, or call the result quota-informed without them."*

The pump inherits that contract: it runs `quota-axi --json` once per pump cycle and uses that one snapshot for every candidate it considers in that cycle. (The snapshot has a `generatedAt` ISO timestamp; using a fresh one per pump cycle avoids stale-runway hazards.)

### 5.3 The hard fallback chain

`config/crew-harness=pi` (verified: `cat /home/hd2admin/kun-agent-workspace/config/crew-harness` returns `pi`). When `config/crew-dispatch.json` is absent, `fm-spawn.sh` falls back to `config/crew-harness` automatically (header line 32). When `config/crew-dispatch.json` is present and the spawn lacks an explicit `--harness`, `fm-spawn.sh` fails closed:

> *"`fm-spawn.sh` refuses crewmate and scout launches without an explicit harness, so `config/crew-harness` is only automatic when no dispatch profile file is active."* (`docs/configuration.md:167`)

This fail-closed rule means the pump **must** resolve a harness per row before calling `fm-spawn.sh`. It can never pass the raw task id without `--harness`.

---

## 6. Direct steerability and live todo visibility

### 6.1 Steer

`bin/fm-send.sh <id> '<text>'` is the only steer path. Verified against the header:
- Fail-closed when `FM_HOME` is unset (cross-home injection is impossible).
- `bin/fm-send.sh --key Enter|Escape|C-c` for keystroke steering.
- Submit confirmation waits for the worker's `working|blocked` busy state.
- Composer-safety gate per `bin/fm-composer-lib.sh` to avoid clobbering a half-typed input.

The pump never needs to steer; it only spawns.

### 6.2 Live checklist

Every Pi worker has its own `todo` tool, and every todo action (add / start / toggle) renders the full current checklist into the pane. The captain-facing read paths are:
- `bin/fm-peek.sh <id> 80` — read the last 80 lines of the worker pane
- `bin/fm-fleet-view.sh` — markdown table of every in-flight worker with current step (`current_state.detail`)
- `/bearings lavish` — visual Lavish board with pane label and busy/idle (the `herdr-pane-board-context` task already in flight is wiring this exact join)

The pump does not need to read live checklists; it only writes state and spawns. Live todo visibility belongs to firstmate's existing read paths.

### 6.3 Capacity to add lanes vs. current concurrency

`herdr pane list` JSON at capture time (12 panes total):
- 1 focused coordinator pane: `w2:pA` (codex, working)
- 1 Stream-A pane: `w2:pM` (pi, idle, `agent_session` points to the stream-a-language-nav worktree)
- 2 actively-working Pi panes: `wE:p2` (herdr-pane-board-context) and `wF:p2` (this audit)
- 8 idle Pi panes from prior audits (BR-04 through BR-12)

So **4 panes are actively working**, not 25. The visible surface has space for more (`herdr` has no documented pane ceiling), but each new pane costs a slot on `minimax`'s 3-hour runway.

---

## 7. Concrete proposal — bounded queue-pump

### 7.1 What the pump does and does not do

**Does:**
- Read `tasks-axi ready` once per call.
- Parse each row's `repo:` and `goal:` tags (existing convention, no new field).
- Resolve the dispatch profile per row using `config/crew-dispatch.json` (firstmate may consult, but the pump only emits a single tuple per row to keep this lightweight).
- Run `quota-axi --json` once and refuse any profile whose provider window is `exhausted_now` or `auth_required`.
- Skip rows whose `blocked_by_ids` are not all `Done`.
- Skip rows whose `hold_kind=captain` is still live.
- Batch `fm-spawn.sh` calls with the existing `FM_SPAWN_DISPATCH_DELAY_SEC=0.25` pacing.
- Stop at one of: cap reached (default 6 from `config/parallel-dispatch-cap`), `tasks-axi ready` empty, provider runway exhausted for the chosen profile.
- Print a structured summary the captain can paste into chat.

**Does NOT do (and refuses to):**
- Does not spawn rows whose `hold_kind=captain` is live (these require an `answer`).
- Does not invent or hold rows; backlog mutations remain `tasks-axi`-only.
- Does not bypass `bin/fm-spawn.sh`; it only feeds pairs to it.
- Does not own a watcher or a daemon; it is an on-demand tool.
- Does not auto-provision a secondmate; that is `bin/fm-home-seed.sh`.
- Does not modify `config/crew-dispatch.json`; profiles are resolved against the existing file.

### 7.2 Termination conditions (and how each one reports)

| Condition | Behaviour |
|---|---|
| `tasks-axi ready` empty | Pump exits 0, prints `pump: no ready rows`. |
| Cap reached | Pump exits 0, prints `pump: cap reached (<n>/<cap>)`. |
| Provider runway exhausted for any chosen profile | Pump exits 0, prints `pump: runway exhausted for <profile>` with the `quota-axi` evidence summary; remaining rows are returned as `unspawned`. |
| Row in `tasks-axi ready` fails its spawn (e.g. invalid task id, worktree tangle) | Pump prints `pump: spawn failed <id>: <reason>` and continues with the next row. |
| `config/parallel-dispatch-cap` missing | Pump exits 1, prints `pump: missing config/parallel-dispatch-cap (default 6)`; firstmate treats this as `needs-decision [key=queue-pump-cap]`. |
| `quota-axi` JSON missing or malformed | Pump exits 1, prints `pump: quota-axi --json failed`; firstmate treats this as `blocked:`. |
| A held row is in `tasks-axi ready` (defensive) | Pump skips it, prints `pump: skip <id> (hold_kind=captain)`. |

### 7.3 Example invocation

```bash
FM_HOME=/home/hd2admin/kun-agent-workspace \
  bash /home/hd2admin/.treehouse/firstmate-46aafc/9/firstmate/bin/fm-queue-pump.sh
```

Output (illustrative, with the live quota snapshot):

```
pump: quota snapshot 2026-09-23T05:56:53Z (minimax runway 10844s, zai weekly 75652s)
pump: ready=[fix-auth-e1 (repo:firstmate, goal:visible-parallel-firstmate),
             tool-auto-update (repo:firstmate, goal:visible-parallel-firstmate),
             ship-board-paint (repo:core-distro-saas-clean, goal:stream-a)]
pump: skip ship-board-paint (repo:core-distro-saas-clean has no quota evidence on the chosen profile)
pump: profile for fix-auth-e1 → pi / MiniMax-M3 / medium (rule: routine-coding)
pump: profile for tool-auto-update → pi / MiniMax-M3 / medium (default)
pump: launching fix-auth-e1 ... ok (harness=pi window=default:wG:p2 worktree=/home/hd2admin/.treehouse/firstmate-46aafc/10/firstmate)
pump: sleeping 0.25s
pump: launching tool-auto-update ... ok (harness=pi window=default:wH:p2 worktree=/home/hd2admin/.treehouse/firstmate-46aafc/11/firstmate)
pump: cap reached (2/6); 1 row unspawned (ship-board-paint)
pump: unspawned: ship-board-paint (reason: profile zai/glm-5.3-flash tools=0%)
```

Firstmate reads the unspawned line and decides whether to wait, swap profiles, or escalate.

### 7.4 Where the pump is invoked from

The pump is invoked **by firstmate** after each actionable wake — not by the watcher, not by `bin/fm-supervise-daemon.sh`. This keeps:
- The watcher's classification contract unchanged (it surfaces, not acts).
- The away-mode daemons's "report digest" semantics unchanged (the daemon reports, firstmate pumps).
- The captain-in-the-loop semantics preserved (the captain can see every unspawned row).

The pump is **also** invokable manually: `bin/fm-queue-pump.sh --dry-run` prints what would spawn without spawning; `--cap N` overrides the cap for one run; `--only <id>` filters to one task id.

### 7.5 Same-file/worktree ownership under the pump

The pump calls `fm-spawn.sh` exactly as the captain would; the per-task lock, the worktree allocation, and the `validate_spawn_worktree` invariants all hold. The pump's only added invariant is **at most one in-flight spawn per `<id>`**, which is already enforced by `$STATE/.spawn-$ID.lock`. No new ownership code is needed.

---

## 8. Minimal ticket breakdown

Three new tickets plus a small surface in existing files. The captain already owns `visible-parallel-firstmate` in `data/goals.md`; this audit attaches each ticket via the existing `goal:` tag convention.

### 8.1 Ticket 1 — `queue-pump-script` (ship, repo: firstmate, priority 4)

**Owns:** `bin/fm-queue-pump.sh` (new file). Reads `tasks-axi ready`, runs `quota-axi --json`, resolves `config/crew-dispatch.json`, batches `fm-spawn.sh` calls.

**Depends on:** none (existing primitives are sufficient).

**Acceptance:**
- Refuses without `config/parallel-dispatch-cap` or `config/parallel-dispatch-cap.d/<name>` matching one positive integer.
- Refuses any profile whose `quota-axi` window is `exhausted_now` or whose provider is `auth_required`.
- Honours `FM_SPAWN_DISPATCH_DELAY_SEC` exactly like `fm-spawn.sh` does (default `0.25`).
- Skips rows whose `hold_kind=captain` is live (the row's `tasks-axi show <id> --json` reports it).
- Skips rows whose `unresolved_blocker_ids` is non-empty (covered by `tasks-axi ready` but verified defensively).
- Exits non-zero only on infrastructure failures (`quota-axi` missing, dispatch file malformed); spawn failures inside the batch are reported per-row, not raised.
- Logs each spawn's `harness=`, `window=`, `worktree=` so firstmate can quote it.

**Tests:**
- One test for empty `tasks-axi ready` (exit 0, no spawn).
- One test for one row with a held task in `ready` (pump skips, prints reason).
- One test for cap reached (pump stops at N).
- One test for runway exhaustion (pump exits 0 with `unspawned` line).
- One test for a `quota-axi` missing/exhausted window (pump refuses to spawn rows matching that profile).

### 8.2 Ticket 2 — `queue-pump-cap-default` (config-only, ship, repo: firstmate)

**Owns:** `config/parallel-dispatch-cap` (new local file; default `6`; persistent operator-overridable).

**Depends on:** none.

**Acceptance:**
- File is gitignored (sits next to `config/crew-harness`, `config/backend`).
- One positive integer per line; malformed values refuse rather than default.
- Empty file is treated as missing.
- `config/parallel-dispatch-cap.d/<name>` overrides per-stream if needed (e.g. `stream-a: 4`, `firstmate: 8`); the pump reads the override by looking up the row's `goal:` tag in the override file.

**Why a separate ticket:** the cap is the captain's lever; separating it from the script lets the captain tune the cap without re-reviewing the script.

### 8.3 Ticket 3 — `pump-skill` (skill, agent-only)

**Owns:** `.agents/skills/queue-pump/SKILL.md` (new file, internal metadata, mirrors `quota-array-dispatch` shape).

**Depends on:** ticket 1.

**Acceptance:**
- Triggers on the operator's explicit `/queuepump` invocation or on firstmate's automatic post-wake pump decision.
- States the intake boundary, the row-skip rules, the dispatch-file precedence chain, the quota-snapshot reuse rule (one snapshot per pump cycle, not per row), and the rejection-of-cap-inflation rule (the pump never silently downgrades reasoning class to keep a row in the batch).
- Lists the failing-cap-when-pump-refuses escalation: a `needs-decision [key=queue-pump-cap]` line that names the refusing condition.

### 8.4 Surface in existing files

The pump itself touches only the new files above. Three tiny edits to existing files are required and live in their own ship tickets if the captain wants them isolated:

| File | Edit | Why |
|---|---|---|
| `data/goals.md` | append the three new ticket ids under `visible-parallel-firstmate` | traceability |
| `AGENTS.md` §7 (intake / dispatch) | one paragraph documenting `bin/fm-queue-pump.sh` as the captain's pump primitive | so a future firstmate does not re-invent it |
| `docs/configuration.md` "Toolchain" | no change — pump reuses existing toolchain (tasks-axi, quota-axi, jq, fm-spawn.sh) | — |

---

## 9. Distinguishing current capability from proposed work

| Capability | Today | After the three tickets |
|---|---|---|
| Read `tasks-axi ready` | yes (any user, any task) | yes |
| Run `quota-axi --json` | yes (any user) | yes |
| Resolve `config/crew-dispatch.json` rules | firstmate-only (manual LLM judgment) | firstmate OR the pump (mechanical) |
| Spawn one worker with `fm-spawn.sh` | firstmate-only | firstmate OR the pump |
| Batch-spawn N workers with `FM_SPAWN_DISPATCH_DELAY_SEC` | yes (manual `fm-spawn.sh id1=repo1 id2=repo2 …`) | yes |
| Refuse a row whose profile is exhausted | firstmate-only (reads quota) | the pump (refuses before spawn) |
| Refuse a row whose `hold_kind=captain` is live | firstmate-only | the pump (skips, prints reason) |
| Refuse to exceed a cap | no cap exists | `config/parallel-dispatch-cap` (default 6) |
| Refuse to silently downgrade reasoning class | n/a (one row at a time, captain controls choice) | the pump refuses and surfaces |
| Same-file/worktree ownership | enforced by `fm-spawn.sh` (per-task lock, treehouse pool, validate_spawn_worktree) | unchanged |
| Captain holds | `bin/fm-captain-hold.sh hold`; held rows invisible to `tasks-axi ready` | unchanged |
| Live visibility of workers | `bin/fm-peek.sh`, `bin/fm-fleet-view.sh`, `bin/fm-fleet-snapshot.sh`, `/bearings lavish` | unchanged; the `herdr-pane-board-context` ship already in flight wires the Herdr `pane list` join |
| Same-pane duplicate-spawn prevention | per-task lock, single-tenant treehouse slot | unchanged |

The pump **does not** introduce new ownership primitives; it packages firstmate's existing decision into a script. The hard safety boundaries (per-task lock, worktree allocation, holds, blocked-by) are inherited untouched.

---

## 10. Behaviour when queue or runway is exhausted

### 10.1 Queue empty

`tasks-axi ready` returns zero rows. The pump exits 0 with `pump: no ready rows`. Firstmate stays silent. The watcher continues absorbing benign wakes.

### 10.2 Provider runway exhausted

The pump's pre-spawn `quota-axi --json` check sees a chosen profile whose effective availability is `exhausted_now` (e.g. `zai` tools scope, `minimax` 5h window past projection). The pump **refuses to spawn that profile**, prints `pump: runway exhausted for <profile> (usableRunwaySeconds=0)` and `pump: unspawned: <id> ...`, and exits 0. Firstmate surfaces the unspawned row to the captain. The captain chooses: wait for the reset, swap profiles via a new `config/crew-dispatch.json` rule, or escalate to a different provider.

### 10.3 `tasks-axi` query error / quota-axi JSON missing

The pump exits non-zero with `pump: <reason>`; firstmate treats it as `blocked:` (no infrastructure failure should silently degrade to "spawn nothing").

### 10.4 Watcher wedge

Unchanged. The pump is invoked by firstmate, not by the watcher; if the watcher wedges, firstmate drains the queue and decides whether to invoke the pump. `bin/fm-watch-arm.sh` and `bin/fm-supervise-daemon.sh` (away mode) keep their existing contracts.

### 10.5 Pane visibility exhausted

`herdr` has no documented pane ceiling; the live session has 12 panes (`herdr pane list` at capture time) and the captain's terminal has only the visible portion. If the captain wants to scale beyond ~12 panes they will need an explicit pane-attach strategy (out of scope; the existing `orchestration-map/report.md` covers that question).

---

## 11. Anti-recommendations

1. **Do not invent a new `goal:` task system or a parallel queue file.** `data/backlog.md` plus `tasks-axi` plus `data/goals.md` is already the family. A second queue file would diverge.
2. **Do not make `fm-spawn.sh` itself pump from `tasks-axi`.** That couples spawn to backlog ownership and breaks the per-task lock model. The pump is a separate script.
3. **Do not let the pump bypass `bin/fm-captain-hold.sh`.** Held rows are the captain's call; the pump only sees unheld, unblocked rows from `tasks-axi ready`.
4. **Do not bind the pump to the watcher.** The watcher's contract is classification; the pump's contract is dispatch. Keeping them separate preserves the watchdog role and the captain-in-the-loop role.
5. **Do not introduce a daemon mode for the pump.** A daemon that pumps unattended breaks the operator's view. The pump is on-demand and firstmate-invoked only.
6. **Do not silently downgrade reasoning class.** `quota-array-dispatch` already refuses this; the pump inherits the rule and surfaces a `needs-decision` line when the strongest class is exhausted.
7. **Do not auto-provision a secondmate for the current lanes.** `data/orchestration-map/report.md` §8 already proved that no current lane is secondmate-worthy. The pump operates inside the main home.
8. **Do not move the captain's `data/captain.md` stack assumptions.** The pinned `pi / MiniMax-M3` worker is intentional; the pump uses it as-is.
9. **Do not commit `config/parallel-dispatch-cap` or any captain-private state.** Same gitignore family as `config/crew-harness`, `config/backend`, `data/goals.md`.
10. **Do not let the pump run `tasks-axi start` itself.** The teardown `done_cmd` is the existing path that moves a row from `In flight` to `Done`; spawn already moves from `Queued` to `In flight` as a side effect of the meta-write under the per-task lock — but the pump should only call `tasks-axi ready` and `fm-spawn.sh`, not `tasks-axi start`. The lock semantics are the only reason a queued row may safely skip `tasks-axi start` today, and that contract is owned by the existing `tasks-axi`-aware segments of `fm-spawn.sh` / `fm-teardown.sh`.

---

## 12. Decisions that need explicit captain authority

These are separated from decisions already authorized in `data/goals.md` and `data/captain.md`. None of them is currently in a `captain-held` task in `data/backlog.md`; the pump just surfaces them on its first run if it cannot resolve them from existing config.

| Key | Question | Why not autonomous |
|---|---|---|
| `parallel-dispatch-cap` | What is the safe default cap? (Recommendation: 6.) | The captain explicitly stated 25 in `data/captain.md`; the pump's default is a conservative safety floor, not the ceiling. |
| `parallel-dispatch-cap-overrides` | Per-stream override file or single global cap? | If the captain wants `stream-a: 4 / firstmate: 8 / total: 10`, the pump needs the override format; `config/parallel-dispatch-cap.d/<goal>.cap` is the suggested shape. |
| `parallel-pump-invocation` | Firstmate auto-invokes after every actionable wake, or only on `/queuepump`? | Auto-invocation is the natural reading of "queue pump", but it changes firstmate's contract — the captain must approve auto-invocation explicitly. |
| `quota-axi-on-captain` | When the only available worker model projects <1h runway, should the pump refuse every row, or spawn at the captain's risk? | Today the captain approves risky spawns; the pump should refuse and surface, not silently accept risk. |
| `minimax-fallback` | When `minimax` exhausts mid-burst, should the pump auto-swap to `zai/glm-5.3-flash` (longer runway, different tool scope), pause, or escalate? | Each option has different quota-conservation consequences. |

The pump surfaces these via `needs-decision [key=<slug>]` lines; firstmate replies through `bin/fm-send.sh --resolve-key` or chat. Held tasks under those keys live in `data/backlog.md` (existing convention).

---

## 13. Evidence index

| Finding | Command run | Path / line |
|---|---|---|
| No script named `pump`, `next-ready`, or `dispatch-loop` in `bin/` | `grep -rn 'pump\|next.*ready\|advance.*queue' bin .agents/skills docs` | this report §2.1 |
| `tasks-axi` has 19 commands, none spawn | `tasks-axi --help` | this report §2.1 |
| `tasks-axi ready` empty at capture time | `tasks-axi ready` from `/home/hd2admin/kun-agent-workspace` | this report §2.1 |
| `fm-spawn.sh` is the only spawn path | `bin/fm-spawn.sh` header lines 4-12; lock at line 415-420; worktree validation at line 1342 | this report §2.2 |
| Batch pacing is `FM_SPAWN_DISPATCH_DELAY_SEC=0.25` | `docs/configuration.md:226-233`; `fm-spawn.sh` header | this report §2.2 |
| `fm-watch.sh` classifies, never spawns | `bin/fm-watch.sh` header line 4 | this report §2.3 |
| `fm-teardown.sh` prints `tasks-axi ready` after teardown but does not spawn | `bin/fm-teardown.sh:530-534` | this report §2.3 |
| `fm-watch-arm.sh` is watcher-liveness, not dispatch | `grep -n 'spawn\|ready\|dispatch' bin/fm-watch-arm.sh` (zero matches) | this report §2.4 |
| Two-writer protection: per-task lock, treehouse pool, `validate_spawn_worktree` | `fm-spawn.sh:415-420`, `fm-spawn.sh:1296-1342` | this report §3.1 |
| Holds preserved: `tasks-axi ready` filters held rows | `tasks-axi hold --help`; live `tasks-axi ready` empty | this report §3.2 |
| `elevate-mobile-audit` is the only live held task | `cat data/backlog.md` (hold: Captain hold set 2026-09-23T04:33:47Z) | this report §3.2 |
| `quota-axi --json` at capture time | `quota-axi --json` | this report §4 (table) |
| `config/crew-dispatch.json` rules | `cat /home/hd2admin/kun-agent-workspace/config/crew-dispatch.json` | this report §5.1 |
| `config/crew-harness=pi` | `cat /home/hd2admin/kun-agent-workspace/config/crew-harness` | this report §5.3 |
| Fail-closed dispatch when no `--harness` and `crew-dispatch.json` exists | `docs/configuration.md:167` | this report §5.3 |
| `AGENTS.md` section 4 dispatch precedence | `AGENTS.md` lines 213-260 | this report §5.2 |
| `bin/fm-send.sh` is fail-closed steer path | `bin/fm-send.sh` header | this report §6.1 |
| Live Herdr pane count = 12, working panes = 4 | `herdr pane list --json` | this report §6.3 |
| `bin/fm-fleet-snapshot.sh` schema is `fm-fleet-snapshot.v1` | `bin/fm-fleet-snapshot.sh` header | this report §6.2 |
| Companion reports already filed | `data/orchestration-map/report.md`, `data/br-system-ticket-audit/report.md` | this report preamble |

---

## 14. Summary

Today there is no queue pump; every spawn is a firstmate decision. The smallest safe addition is one bash script (`bin/fm-queue-pump.sh`) plus one config file (`config/parallel-dispatch-cap`) plus one skill (`queue-pump`) — three new tickets attached to the existing `visible-parallel-firstmate` goal. The script never bypasses existing primitives (`fm-spawn.sh`, `tasks-axi`, `quota-axi`, `bin/fm-captain-hold.sh`); it only packages firstmate's decision into a bounded batch with three explicit terminations (cap reached, queue empty, runway exhausted). The binding constraint today is **provider runway on `minimax`** (≈3 h projected, `zai` tools already at 0%), not pane slots or worktree slots; the captain's 25-worker ceiling is not reachable without re-authenticating at least one more provider. The pump is invoked by firstmate after each actionable wake, never by the watcher, never by the away-mode daemon, and never autonomously — so the captain remains in the loop and every unspawned row is reported back as a `needs-decision` line rather than silently dropped.
