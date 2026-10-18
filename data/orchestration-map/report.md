# Visible parallel work, secondmates, and per-pane supervision — read-only audit

**Task:** `orchestration-map` (scout, read-only)
**Author:** Pi · MiniMax-M3 · `wA:p2` (worktree `/home/hd2admin/.treehouse/firstmate-46aafc/3/firstmate`)
**Captured:** 2026-09-23
**Companion reports already filed:** `br-system-herdr-audit/report.md`, `br-system-ticket-audit/report.md`, `br-system-update-audit/report.md`, `local-model-audit/report.md`. This audit integrates those into a single recommendation for the captain's three questions.

---

## Captain-facing summary

1. **No — every worker pane does not need its own child supervisor.** The main `bin/fm-watch.sh` watcher already aggregates, drains, and decides; per-pane daemons would race on the same `state/<id>.status` append and on the same `state/.watch.lock`. The right design is **one main firstmate watcher** plus, when you walk away, **one `bin/fm-supervise-daemon.sh`** in a dedicated Herdr workspace, not N.
2. **No — do not provision a secondmate for the current lanes.** The in-flight set is bounded, two-project, and already fits the main home's flat shape. A secondmate is justified only when a domain has recurring work that needs its own backlog stream, charter, and secondmate-harness pin. None of the six current lanes qualifies.
3. **You already have a visible + steerable + parallel pattern.** It is the one in use right now: one Herdr workspace per task, one Pi-on-MiniMax-M3 worker pane per task, one disposable worktree per task, one `state/<id>.meta` per task, one main watcher supervising them all. The remaining lift is naming convention and one always-on board, not new infrastructure.

---

## 1. Roles — plain language

**Firstmate** is your operator. It is the captain's single point of contact and the only thing that runs in the main session. It holds the fleet lock, drains the wake queue, classifies each wake as captain-relevant or absorbable, reads the busy record for each in-flight worker, decides when to steer a worker or wake you, and runs the watcher (`bin/fm-watch.sh`) that connects the whole fleet. It never writes project code; a crewmate does that.

**A crewmate** is one of Firstmate's hired hands: one agent, one worktree, one backend endpoint, one backlog item. There are two kinds:
- **Ship** changes project code and ends in a PR (or a local artifact for `local-only` delivery).
- **Scout** is read-only and ends in `data/<id>/report.md`.

A crewmate is autonomous once spawned. Firstmate steers it with `bin/fm-send.sh` and reads its current state with `bin/fm-crew-state.sh`. A crewmate does **not** watch itself; the main Firstmate watcher does.

**Herdr** is the visible terminal plane. The workspaces, tabs, panes you see in your terminal are Herdr; the native `agent_status` (`working`/`idle`/`done`/`blocked`/`unknown`) is Herdr; the protocol-16 `pane.agent_status_changed` push events that shorten wake latency are Herdr. Herdr owns nothing about decisions; it owns the shell, the labels, and the lifecycle event stream. The current installation is `herdr 0.9.1 / protocol 22` (verified at the audit's start).

**A secondmate** is a whole separate Firstmate running in its own `FM_HOME`, with its own charter, own backlog, own watcher, own crewmates, and its own Herdr workspace labeled `2ndmate-<id>`. It is persistent and idle by default — it never self-initiates surveys or audits. Each secondmate reconciles only its own work. The main Firstmate does not supervise a secondmate's children; the secondmate's own watcher does.

---

## 2. What is visible and steerable per pane

Every task pane in this home exposes the same surface (verified by reading the live `herdr pane list` JSON for all seven live panes):

| Visible | Source | Read with | Steer with |
| --- | --- | --- | --- |
| Workspace label (`BRANDON · WAR ROOM`, `BR-08 · VISIBLE FLEET MODEL`, …) | Herdr mutable label | `herdr workspace list` | `herdr workspace rename` (cosmetic only) |
| Tab label (`BR-08 · VISIBLE FLEET MODEL`) | Herdr mutable label | `herdr tab list` | `herdr tab rename` |
| Pane label (`BR-08 · ORCHESTRATION MAP · M3`) | Herdr mutable label | `herdr pane list` | `herdr pane rename` |
| Terminal title (`π · M3 · wA:p2`) | Herdr from harness | `herdr pane list` | (set by harness) |
| `agent_status` (working/idle/done/blocked/unknown) | Herdr native | `herdr agent list` | (set by agent) |
| `agent_session.value` (path to Pi session JSONL) | Herdr native | `herdr agent list` | — |
| Pane tail (last N lines) | Herdr capture | `herdr pane read <p> --lines 200` / `bin/fm-peek.sh <id> 80` | — |
| Deterministic current state | Firstmate `bin/fm-crew-state.sh <id>` reading `state/<id>.busy-state` (driven by `state/<id>.pi-ext.ts` `agent_start` / `agent_settled` events) | `bin/fm-crew-state.sh <id>` | — |
| Send text | `bin/fm-send.sh <id> '<text>'` (fail-closed, settles slash/dollar prefixes) | — | yes |
| Send keys (Enter / Escape / Ctrl-C) | `bin/fm-send.sh <id> --key Enter|Escape|C-c` | — | yes |

What is **not** steerable from outside the pane: the agent's in-flight tool call, its context, the worktree's uncommitted work. Those belong to the agent and to Firstmate's `bin/fm-spawn.sh` / `bin/fm-teardown.sh` lifecycle.

---

## 3. Who owns what

| Surface | Single owner | Notes |
| --- | --- | --- |
| Ticket lifecycle (Queued / In flight / Done) | `data/backlog.md` edited through `tasks-axi add / start / done / hold / block / mv / prune` | `bin/fm-fleet-snapshot.sh --json` (schema `fm-fleet-snapshot.v1`) is the read-only contract; never fork the snapshot for a captain preference |
| Per-task durable record (`state/<id>.meta`, `.status`, `.busy-state`, `.turn-ended`, `.pi-ext.ts`) | Firstmate `bin/fm-spawn.sh` (writes meta + pi-ext) + the live `bin/fm-watch.sh` (appends `.status`) + the agent's own `state/<id>.pi-ext.ts` (writes `.busy-state`) | A `.status` line is a wake event, **not** current state; use `bin/fm-crew-state.sh` for current state |
| Live agent busy state | Firstmate `bin/fm-busy-lib.sh` (semantic verdict: busy / idle / unknown / dead) + `bin/fm-busy-event.sh apply` (only writer) | Pi/pi-signed report through the Firstmate-owned extension's `agent_start` / `agent_settled`, confirmed by `ctx.isIdle()` |
| Current state read | `bin/fm-crew-state.sh <id>` | One deterministic answer; consult `state/<id>.status` only for tail history |
| Wake classification + durable queue | `bin/fm-watch.sh` (always-on bash triage) + `bin/fm-supervise-daemon.sh` (when `/afk`) | Both share `bin/fm-classify-lib.sh` for captain-relevant verbs and declared-pause vocabulary |
| Push-event subscription (Herdr protocol 16+) | `bin/backends/herdr-eventwait.py` invoked by the watcher | Polling fallback is permanent when protocol-16 / Python / connection / reader execution is unavailable |
| Steering | `bin/fm-send.sh` (text or keys) → `bin/fm-backend.sh` → runtime backend (herdr / tmux / etc.) | Per-pane submit confirmation waits for `working`/`blocked`; composer-safety gate per `bin/fm-composer-lib.sh` |
| Visual board | `/bearings lavish` builds `$FM_HOME/.lavish/bearings-board.html` via `bin/fm-bearings-board.sh build` from the snapshot + Herdr `pane list` join | The board rebuilds in place; its id is `lavish-<sha256[:16]>` over `realpath` |

The architecture.md section "Busy state is semantic, per adapter" is the source for the busy-state contract; the key fact is "missing, malformed, stale, untrusted, or unverified semantic state is unknown, never idle, and unknown is never promoted to busy either." That is the rule that keeps a dead pane from being absorbed as still-working.

---

## 4. Does every worker pane need its own child supervisor?

**No.** Three reasons.

1. **The main watcher already aggregates.** `bin/fm-watch.sh` polls every `state/<id>.meta`, joins each pane's `herdr pane list` line, deduplicates by `agent_status_changed` (push events when protocol 16+ is available), and writes one durable wake to `state/.wake-queue` per actionable event. N per-pane daemons would each write to the same queue and race on the same `state/.watch.lock`; one would always win, the others would be absorbed as duplicate or stale.

2. **Per-pane daemons duplicate the per-pane status emission the agent already does.** Every Pi pane already emits `agent_start` / `agent_settled` through `state/<id>.pi-ext.ts`; Firstmate's busy record is therefore already per-pane. A sub-supervisor reading the same pane adds no information; it only adds latency.

3. **The architecture.md pattern is "one supervisor per home, not per pane."** A persistent secondmate is a whole second Firstmate with its own watcher — that watcher watches only the secondmate's own children. The main home's watcher watches only the main home's direct reports. Each home has **one** watcher, **one** daemon (when `/afk`), and **N** crewmate/scout panes inside.

The one place a per-pane-shaped subprocess is correct is the `/afk` daemon, and even that runs **once** in a dedicated Herdr workspace, not once per task. `bin/fm-afk-launch.sh` creates one unfocused workspace, runs `bin/fm-supervise-daemon.sh` there with an explicit supervisor target and backend, and closes only that exact pane on stop. It never splits the captain's active tab.

---

## 5. Pattern for 2-4 (and up to ~6) simultaneous tasks

What the captain is already running is the recommended pattern. Verified against the live `herdr workspace list` (captured 2026-09-23, seven workspaces, seven panes).

### 5.1 Topology

| Layer | Rule | Why |
| --- | --- | --- |
| One Herdr workspace per task | Yes, except the coordinator's own workspace | Label isolation; captain can scan `herdr workspace list` once |
| One tab + one pane per task | Yes, except `BRANDON · WAR ROOM` which keeps the coordinator pane + its own worker pane | A second tab in the same workspace splits attention |
| One disposable worktree per task | Yes — `bin/fm-spawn.sh` refuses to launch unless the resolved task path is a real git worktree distinct from the primary checkout | Independent git state; one task can `git checkout fm/<id>` without disturbing another |
| One `state/<id>.meta` per task | Always | Single owner of harness/model/kind/worktree/Herdr pane/backend/busy-state refs |
| One `state/<id>.pi-ext.ts` per task | Always for Pi | The bridge that emits Pi's `agent_start` / `agent_settled` to Firstmate's busy record |
| One main watcher | Always | Aggregation, dedupe, durable queue |
| One daemon (when `/afk`) | Optional, not per-task | Batched away-mode digests in a dedicated Herdr workspace |
| Quota check at intake | `quota-axi --json` + dispatch profile at intake; `bin/fm-procevent-quota.sh arm` for ongoing watching | Catches a tight runway before dispatch, not after |
| Read-only checker | Only when it avoids edit conflicts (e.g. a code-review ship with a static analyzer on the same branch, **without** `git checkout`); not for read-only scout tasks | Two writers on one worktree is a conflict; one reader + one writer is fine |

### 5.2 Concrete launch recipe (Pi + MiniMax-M3 — the verified fleet stack)

This is the captain-facing one-liner; `br-system-herdr-audit/report.md` lists the full evidence trail.

```bash
FM_HOME=/home/hd2admin/kun-agent-workspace \
  bash /home/hd2admin/.treehouse/firstmate-46aafc/1/firstmate/bin/fm-spawn.sh \
    <task-id> <project-dir> \
    --harness pi \
    --model minimax/MiniMax-M3 \
    --effort medium
```

`bin/fm-spawn.sh` expands this to `pi --model minimax/MiniMax-M3 -e <state>/<id>.pi-ext.ts "<encoded launch-brief>"` and emits the `state/<id>.meta` with `backend=herdr`, `herdr_session=default`, `herdr_workspace_id=<ws>`, `herdr_tab_id=<ws>:t2`, `herdr_pane_id=<ws>:p2` (template at `bin/fm-spawn.sh:478`; `model_flag_for_harness` at `:602`; Pi-ext generation at `:1482`).

The four steer/status commands a captain needs:

```bash
FM_HOME=/home/hd2admin/kun-agent-workspace bash bin/fm-send.sh <id> 'next: ship the no-mistakes ax init'
FM_HOME=… bash bin/fm-send.sh <id> --key Enter
FM_HOME=… bash bin/fm-peek.sh <id> 80
FM_HOME=… bash bin/fm-crew-state.sh <id>
```

### 5.3 The current fleet is already on this pattern

Snapshot of `herdr workspace list` (verbatim from the JSON; full `pane list` JSON captured at audit start):

```
w2  BRANDON · WAR ROOM           focused  panes=2  tabs=1   (codex coordinator + Stream A worker)
wA  BR-08 · VISIBLE FLEET MODEL          panes=1  tabs=1   (orchestration-map, this task)
w9  BR-07 · LOCAL MODEL HEALTH           panes=1  tabs=1   (local-model-audit, done)
w7  BR-05 · CORE MOBILE                  panes=1  tabs=1   (core-mobile-fix)
w8  BR-06 · ELEVATE MARKETING            panes=1  tabs=1   (elevate-mobile-audit, held)
w6  BR-04 · AUTO UPDATES                 panes=1  tabs=1   (tool-auto-update)
```

Six workspaces, six independent worktrees (`firstmate-46aafc/{1,3,4}/firstmate`, `firstmate-46aafc/2/firstmate`, `core-distro-saas-clean-172fa0/1/core-distro-saas-clean`, `core-distro-saas-clean-stream-a-nav`), one main firstmate watcher. The pattern holds.

### 5.4 Naming convention (recommendation, not implemented in this audit)

Three independent decisions, none load-bearing:

- **Workspace label**: `<STREAM> · <AREA>` (e.g. `STREAM-A · CORE DISTRO`, `OPS · INFRA`, `PRIM · FIRSTMATE`). Already roughly in use.
- **Tab label**: `BR-NN · <concise task>` (so the captain can scan all tabs in a workspace by `BR-NN` prefix). Already in use.
- **Pane label**: `<agent> · <model> · <pane-id>` — Herdr already does this (`π · M3 · wA:p2`); no rename needed.

These labels are **cosmetic only**. Herdr does not enforce label uniqueness (`docs/herdr-backend.md` line 50), and Firstmate agrees — only the pane-id is authority.

### 5.5 Optional knob: `config/herdr-presentation-spaces`

This is the smallest "give every task its own disposable workspace" knob (`docs/herdr-backend.md` lines 60-123). Default is OFF; `config/herdr-presentation-spaces` is absent in this home (verified). Enabling it gives each new task its own workspace and journal-bound token, and a narrow home-local cleanup pass at locked session start removes the exact orphaned childless idle-shell shape. Trade-off: more workspaces, slightly more session-start cleanup. **Recommendation: leave OFF for the current six lanes; revisit only when the captain wants disposable, per-task workspaces even after teardown.**

---

## 6. When a long-lived secondmate is worth provisioning

From `secondmate-provisioning/SKILL.md` and `docs/architecture.md` "Optional secondmates":

| Signal | Worth provisioning? |
| --- | --- |
| A backlog area has recurring work for the foreseeable future | Yes — the natural fit |
| Captain wants a clean isolation boundary between domains (e.g. "core-distro tickets never touch the main firstmate's state") | Yes |
| The domain needs a secondmate-harness pin or model pin that differs from the main's default (`config/secondmate-harness` may carry `<harness> [<model>] [<effort>]`) | Yes — that's why the pin exists |
| The work is a one-off bounded project | No |
| The work fits naturally in the main home | No |
| The team has not decided who owns the domain long-term | No — wait |
| The work is `local-only` | **No** — `local-only` stays with the main firstmate (hard rule, `architecture.md` "Optional secondmates") |
| Current lanes can all be shipped by the main firstmate | No |

**Quorum for provisioning**: at least 3-5 queued tickets in a domain, a captain-known scope phrased as a one-sentence charter, and a charter that won't change quarterly.

**Operational load a secondmate introduces** (every item is a real ongoing cost, not a one-time setup cost):

1. **One more watcher** (`bin/fm-watch.sh` per home). One more `state/.watch.lock`. One more `state/.watch-cycle-exits.log`.
2. **One more process-event registration family** (`state/procevent/`, `state/procevent-inbox/`). Cleanup on retirement must retire every registered source through the safe generation-bound path; ambiguous cleanup refuses.
3. **One more backlog** (`data/backlog.md` in the secondmate home). `bin/fm-backlog-handoff.sh` moves in-scope items atomically via `tasks-axi mv`; new main-side tickets in that scope must be routed, not auto-flowed.
4. **One more Herdr workspace** (`2ndmate-<id>`). All the placement / launcher-binding / cleanup rules from `herdr-backend.md` lines 41-58.
5. **One more charter file** (`data/charter.md`) plus the `.fm-secondmate-home` marker. Re-seeding a populated home as project-less is refused non-destructively.
6. **One more inheritance set**: `config/crew-dispatch.json`, `config/crew-harness`, `config/backlog-backend`, `config/backend`, `config/herdr-presentation-spaces`, `config/startup-memory-budget`, and `data/captain-shared.md` must be propagated. Per `secondmate-provisioning`, these are primary-authoritative copies that converge on every launch and on every locked session-start sweep.
7. **One more recovery story** at startup. Confirmed-dead endpoints relaunch through `bin/fm-spawn.sh --secondmate`; ambiguous liveness reads are left untouched.
8. **One more PR-based teardown rule**. Forced retirement requires explicit captain authority (`--force`); plain retirement refuses while `state/*.meta` has in-flight work.
9. **One more X-mode story** if X mode is on (`data/captain-shared.md` is read-only in secondmate homes; `bin/fm-public-followup-emit.sh` is the typed terminal-result owner).

In short: a secondmate is a whole new Firstmate, not a faster worker. Provision one when the domain's recurring work and isolation need justify the steady-state overhead, not as a habit.

---

## 7. Hierarchy sketch (ASCII)

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │ captain (you) — chat window, /bearings lavish, gh-axi       │
                    └───────────────────────────┬─────────────────────────────────┘
                                                │ captain answer / wake
                                                ▼
                    ┌─────────────────────────────────────────────────────────────┐
                    │ main Firstmate session  (FM_HOME=kun-agent-workspace)       │
                    │  - bin/fm-watch.sh  (always-on bash triage, .wake-queue)    │
                    │  - bin/fm-supervise-daemon.sh  (only when /afk)            │
                    │  - bin/fm-captain-hold.sh  (keyed answer intake)            │
                    │  - data/backlog.md  /  data/projects.md  /  data/captain.md │
                    └────────────┬─────────────────────────────────┬─────────────┘
                                 │ fm-spawn / fm-peek / fm-send    │ secondmate registry (none today)
                                 │ per task                        │
                                 ▼                                 ▼
   ┌──────────────────────────────────────────────────────────────────────────┐
   │ N parallel panes, each in its own Herdr workspace                       │
   │                                                                          │
   │  w2  BRANDON · WAR ROOM      wA  BR-08 · VISIBLE FLEET MODEL             │
   │   └─ pA codex (coordinator, blocked)   └─ p2 pi · M3 (this audit, work)  │
   │   └─ pM pi · M3 (Stream A, idle)                                          │
   │                                                                          │
   │  w9  BR-07 · LOCAL MODEL     w7  BR-05 · CORE MOBILE                     │
   │   └─ p2 pi · M3 (audit, done)   └─ p2 pi · M3 (ship, work)               │
   │                                                                          │
   │  w8  BR-06 · ELEVATE         w6  BR-04 · AUTO UPDATES                    │
   │   └─ p2 pi · M3 (scout, held)  └─ p2 pi · M3 (ship, idle)                │
   └──────────────────────────────────────────────────────────────────────────┘
        │                  │                       │
        ▼                  ▼                       ▼
   ┌──────────┐      ┌──────────┐           ┌──────────┐
   │ worktree │      │ worktree │           │ worktree │     one disposable
   │ 46aafc/3 │      │ core-d-  │           │ 46aafc/1 │     worktree per task
   │ firstmate│      │ 172fa0/1 │           │ firstmate│     (Treehouse or git)
   └────┬─────┘      └────┬─────┘           └────┬─────┘
        │                 │                      │
        ▼                 ▼                      ▼
   state/orchestration-map.*  state/core-mobile-fix.*  state/<id>.meta + .busy-state + .pi-ext.ts + .turn-ended
                                                            written by fm-spawn / pi-ext / watcher
```

Key invariant: **one watcher, N panes.** The watcher reads every pane's busy record, every task's meta, every status append; it dedupes, queues, and wakes Firstmate once per actionable event. Adding a sub-supervisor per pane would race on the same lock and emit duplicate wakes.

---

## 8. Concrete recommendation for the current lanes

Verified by reading `data/backlog.md`, `data/projects.md`, `state/home-summary.json`, `config/crew-dispatch.json`, `config/crew-harness`, `config/backend`, `config/startup-memory-budget`, and `herdr pane list`/`workspace list` at audit time.

| Lane | Recommendation |
| --- | --- |
| `orchestration-map` (scout, firstmate) | **Keep in main.** This audit is the deliverable. |
| `local-model-audit` (scout, firstmate) | **Keep in main; one-off.** Already `done`; the report stands. No secondmate justified. |
| `elevate-mobile-audit` (scout, firstmate, held) | **Keep in main.** Held on a captain gate; no secondmate justified. |
| `core-mobile-fix` (ship, core-distro-saas-clean) | **Keep in main for now.** Worth re-evaluating only when 3+ more core-distro ship tickets land in the same domain. |
| `tool-auto-update` (ship, firstmate) | **Keep in main.** Firstmate repo work belongs to the main home unless a dedicated firstmate-tooling secondmate is chartered. |
| `stream-a-deploy-artifact` (ship, local-only, core-distro-saas-clean) | **Keep in main — hard rule.** `local-only` cannot move to a secondmate (it merges into the main local checkout, not a PR path). |

**The single conditional recommendation:** if the captain anticipates 3+ recurring `core-distro-saas-clean` tickets in the next two weeks AND wants them isolated from the main home's state, provision a `core-distro` secondmate with `--no-projects` only if the core-distro-saas-clean repo IS the firstmate repo (it isn't — it is a separate project, so use a real project list). Charter scope: "all Core Distro SaaS delivery tickets on `core-distro-saas-clean`; local-only stays in main". Harness pin: the captain's current default (`config/crew-harness=pi`); no override needed. Operational load introduced: the nine items in §6.

**Do not** provision a secondmate for the firstmate-repo tickets. Firstmate is the captain's own infrastructure; isolating it from the main firstmate would make `/updatefirstmate` and charter work unnecessarily round-trip.

**Do not** add per-pane sub-supervisors. The main watcher already aggregates; the `/afk` daemon already batches.

**Do not** enable `config/herdr-presentation-spaces` for the current lanes. The flat shape (one workspace per task) is working and visible. Revisit only when the captain wants disposable, per-task workspaces that persist after teardown.

**Do keep** the existing pattern as-is:
- One Herdr workspace per task
- One Pi + MiniMax-M3 worker pane per task with `state/<id>.pi-ext.ts` loaded
- One disposable worktree per task (Treehouse or git worktree add)
- One `bin/fm-watch.sh` main watcher
- Optional `quota-axi` arm and `bin/fm-procevent-tool.sh` arm for early warnings

---

## 9. What this report deliberately does not do

- Does not provision a secondmate (out of brief).
- Does not launch any agent (out of brief).
- Does not change `config/backend`, `config/crew-harness`, `config/crew-dispatch.json`, `config/herdr-presentation-spaces`, `config/startup-memory-budget`, or any other local config.
- Does not create `data/secondmates.md`, `data/goals.md`, or any other durable file in the main home.
- Does not edit `state/<id>.meta` for any peer task.
- Does not change Herdr state (no `workspace create`, `pane rename`, `tab move`).
- Does not install or update any tool.
- Does not inspect secrets, run inference prompts, or contact any other host.
- Does not open a captain hold; all recommendations are captain-decision-shaped but not captain-required to complete this scout (`bin/fm-captain-hold.sh complete --none` is the appropriate close per `captain-hold-lifecycle/SKILL.md`'s "Resolved findings, recommendations that need no captain choice … do not create held tasks").

The deliverable is the recommendation. The captain decides what to ship.

---

## 10. Evidence index

| Finding | Source |
| --- | --- |
| Seven Herdr workspaces, seven panes, all live | `herdr workspace list` + `herdr pane list --json` (full JSON captured at audit start) |
| Live install is `herdr 0.9.1 / protocol 22`, endpoint_compatible yes | `herdr --version`; `herdr status` |
| Per-task `state/<id>.meta` shape: `harness=pi kind=scout model=minimax/MiniMax-M3 effort=medium backend=herdr herdr_session=default herdr_workspace_id=<ws> herdr_tab_id=<ws>:t2 herdr_pane_id=<ws>:p2` | `cat /home/hd2admin/kun-agent-workspace/state/orchestration-map.meta` (this task's own) |
| Pi extension bridge for busy state | `bin/fm-busy-lib.sh` (semantic verdict) + `bin/fm-busy-event.sh apply` (only writer) + `state/<id>.pi-ext.ts` per task |
| Pi on MiniMax-M3 launch recipe and template | `bin/fm-spawn.sh:478` (pi template), `:602` (`model_flag_for_harness`), `:1482` (pi-ext generation), `:1654` (model expansion) |
| Steer / peek / state commands | `bin/fm-send.sh`, `bin/fm-peek.sh`, `bin/fm-crew-state.sh` headers |
| Herdr per-task workspace placement and binding | `docs/herdr-backend.md` lines 41-58 (workspace labels), 60-123 (presentation spaces), 199-215 (native agent state), 247-266 (push events), 269-284 (away-mode daemon) |
| Architecture: one supervisor per home, not per pane | `docs/architecture.md` "Event-driven supervision" + "Optional secondmates" + `docs/architecture.md` "Runtime session backends" |
| Secondmate operational load | `.agents/skills/secondmate-provisioning/SKILL.md` (full sync + propagation + inherited-local-material contract) |
| Pi supervision protocol (auto-load, watcher cycle, turn-end guard) | `docs/supervision-protocols/pi.md` |
| Busy-state semantic contract | `docs/architecture.md` "Busy state is semantic, per adapter" |
| Captain-hold lifecycle (held-tasks-are-decisions; recommendations don't create holds) | `.agents/skills/captain-hold-lifecycle/SKILL.md` "Resolved findings, recommendations that need no captain choice … do not create held tasks." |
| `config/backend=herdr`, `config/crew-harness=pi`, `config/startup-memory-budget=7500`, `config/herdr-presentation-spaces` absent, `config/crew-dispatch.json` rules list | `cat /home/hd2admin/kun-agent-workspace/config/{backend,crew-harness,startup-memory-budget,herdr-presentation-spaces,crew-dispatch.json}` |
| `data/secondmates.md` does not exist (no secondmates registered) | `ls /home/hd2admin/kun-agent-workspace/data/secondmates.md` → not found |
| Companion audits (already filed) | `data/br-system-herdr-audit/report.md`, `data/br-system-ticket-audit/report.md`, `data/br-system-update-audit/report.md`, `data/local-model-audit/report.md` |

---

## 11. Summary

You do not need a child supervisor per pane; one main watcher plus an optional `/afk` daemon already cover it. You do not need a secondmate for the current six lanes; provisioning one is justified only when a domain has 3+ recurring tickets, a stable charter, and a real isolation need. The visible + steerable + parallel pattern is already in place — one Herdr workspace per task, one Pi + MiniMax-M3 worker pane per task, one disposable worktree per task, one `state/<id>.meta` per task, one main firstmate watcher supervising them all. The remaining lift is naming + one always-on board, not new infrastructure. If a future `core-distro-saas-clean` stream grows into a sustained backlog, provision a `core-distro` secondmate then; for everything else, the main home is the right home.