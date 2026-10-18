# Goals, tickets, and visible status board — read-only audit

**Task:** br-system-ticket-audit
**Kind:** scout (read-only, no edits, no PR)
**Home:** `/home/hd2admin/kun-agent-workspace`
**Captured at:** 2026-09-23T03:52Z (snapshot `2026-09-23T03:51:43Z`)
**Companion task:** br-system-herdr-audit (mapping the Herdr pane side; this report joins the two sides)

---

## TL;DR for the captain

You already have a working ticket + visual-board system. The parts that exist:

- **Backlog** — `data/backlog.md` edited through `tasks-axi add / start / done / hold / block / mv / prune` (the `tasks-axi` markdown backend is what `.tasks.toml` selects).
- **Per-task state** — `state/<id>.meta` records project, backend, endpoint target, kind, harness, and Herdr pane id; `state/<id>.busy-state` records whether the harness is `busy` or `idle`; `state/<id>.status` records the append-only wake-event history.
- **Read-only aggregator** — `bin/fm-fleet-snapshot.sh --json` (schema `fm-fleet-snapshot.v1`) joins the backlog rows, the per-task metadata, the current crew state from `bin/fm-crew-state.sh`, and the live Herdr endpoint existence probe.
- **Text view** — `bin/fm-fleet-view.sh` renders a markdown table fleet view on top of that JSON.
- **Interactive visual board** — `/bearings lavish` runs `bin/fm-bearings-board.sh build`, which validates an `fm-bearings-board.v1` payload, injects it into `~/.lavish/bearings-board.html` (the shipped Firstmate Design System Lavish template), establishes the Lavish session, binds the board source to the keyed-answer intake through `bin/fm-captain-hold.sh bind`, and arms `lavish-axi poll` as a process-event source.

The two real gaps your ask exposed:

1. **There is no `goal` primitive in `tasks-axi`, in the snapshot, or in the board payload.** A goal has to be added as a lightweight convention on top of the existing pieces; nothing in Firstmate needs a new code path for it.
2. **The snapshot does not currently join the live Herdr pane label, agent name, or `agent_status` into the underway rows.** The board shows the durable task id and the crew's `current_state.detail`, but not "Pi on MiniMax-M3 in pane `w4:p2` is currently writing this report". The data is one `herdr pane list` call away — that is the only new wiring needed.

Everything else — states, owners, blocked / review / done buckets, and "what needs your input" — is already wired through `fm-captain-hold.sh hold / answer / open` and surfaced through the board's **Captain's Call** section.

---

## 1. Existing ticket lifecycle and state surface

### 1.1 Backlog schema (evidence)

`/home/hd2admin/kun-agent-workspace/.tasks.toml`:

```toml
backend = "markdown"

[markdown]
path = "data/backlog.md"
archive = "data/done-archive.md"
done_keep = 10
```

`/home/hd2admin/kun-agent-workspace/data/backlog.md` (current contents):

```
## In flight
- [ ] br-system-ticket-audit - Map goals, tickets, and visual status board (repo: firstmate) (kind: scout) (priority: 4) (since 2026-09-23)
  Read-only audit. Inspect the existing goals, tasks-axi backlog, Firstmate task lifecycle, and Lavish options. Recommend a minimal ticket workflow and visible status board that clearly maps tickets to worker panes and goals. Do not edit files.
- [ ] br-system-herdr-audit - Map visible Herdr panes and worker steering (repo: firstmate) (kind: scout) (priority: 4) (since 2026-09-23)
  Read-only audit. Report a concrete, low-confusion layout for visible, steerable parallel agents in this home, including pane naming, workspace/tab grouping, and supported Pi+MiniMax launch/control paths. Do not edit files.
- [ ] stream-a-deploy-artifact - Prepare Core Distro deployment artifact (repo: core-distro-saas-clean) (kind: ship) (priority: 4) (since 2026-09-23)
  In progress in visible Herdr pane w2:pM with Pi on MiniMax-M3. Existing branch/worktree: stream-a-language-nav. Preserve its existing uncommitted changes. Prepare a local artifact only; do not publish, deploy, push, or commit. This ticket is a visibility record; the current manually relaunched pane has no Firstmate task metadata.

## Queued
## Done
```

`tasks-axi` (run from this home, current):

```
in_flight: 3 (the three rows above)
queued:    0
public_followups: 0 obligations
done: 0 retained
```

### 1.2 What `tasks-axi` already supports (evidence: `tasks-axi --help`, `tasks-axi add --help`, `tasks-axi list --help`)

| Field / verb | Type | Notes for this audit |
|---|---|---|
| `--kind <ship\|scout\|docs\|...>` | string | captain, secondmate, ship, scout, docs, program all exist. The snapshot uses these to drive `current_role` (worker / program / held / queued / done). |
| `--repo <name>` | string | Pinned in `data/projects.md` (`firstmate`, `core-distro-saas-clean`). Already on every row above. |
| `--priority <0-4>` | int | Snapshot passes it through to the board payload. |
| `--blocked-by <id>` (repeatable) | ids | Snapshot normalizes to `blocked_by_ids` and `unresolved_blocker_ids`. |
| `--pr <url>` | url | Mirrored into `state/<id>.meta::pr=` by `fm-pr-check` and surfaced by the snapshot. |
| `--report <path>` | path | Mirrored into `state/<id>.meta` as `report=` and surfaced by the snapshot. |
| `start` / `done` / `reopen` / `rm` | lifecycle | Section moves (Queued → In flight → Done). |
| `hold` / `unhold` (`--reason`, `--until`, `--kind captain`) | hold | Drives Captain's Call on the board. `--until` defers to a date. |
| `block` / `unblock` (`--by <id>`) | dep | Drives blocked / Charted Next on the board. |
| `ready` | query | Lists unblocked queued work — already the canonical "what can I dispatch next" surface. |
| `mv` / `prune` / `render` | housekeeping | `render` re-canonicalizes the markdown. |
| `setup hooks` | bootstrap | Installs the bridge that lets `state/<id>.status` lines auto-update the backlog (no manual duplicate status writes). |

**There is no native `goal` field.** None of `--goal`, `--parent`, `--program`, or `--objective` appears in the help, in `bin/fm-fleet-snapshot.sh`'s jq parser, or in the board-template validator. This is the first gap.

### 1.3 Per-task state surface (evidence: `state/<id>.meta` + `state/<id>.busy-state`)

`/home/hd2admin/kun-agent-workspace/state/br-system-ticket-audit.meta` (this task's own record):

```
window=default:w4:p2
endpoint_task_id=br-system-ticket-audit
worktree=/home/hd2admin/.treehouse/firstmate-46aafc/2/firstmate
project=/home/hd2admin/kun-agent-workspace/projects/firstmate
harness=pi
kind=scout
tasktmp=/tmp/fm-br-system-ticket-audit
model=minimax/MiniMax-M3
effort=medium
busy_gen=g1790135398.3991137.20784
spawn_gen=s1790135398.3989164.30814
backend=herdr
herdr_session=default
herdr_workspace_id=w4
herdr_tab_id=w4:t2
herdr_pane_id=w4:p2
```

`/home/hd2admin/kun-agent-workspace/state/br-system-ticket-audit.busy-state`:

```
v1 gen=g1790135398.3991137.20784 seq=2 state=busy source=pi-ext event=agent-start ts=1790135418
```

The `busy-state` file is updated by the `bin/fm-busy-event.sh apply` calls that `state/<id>.pi-ext.ts` emits (header of that file: *"Semantic state: `agent_start` → busy when a low-level agent run begins; `agent_settled` → idle only when `ctx.isIdle()` confirms Pi will not continue automatically"*). That gives Firstmate a continuously refreshed `busy | idle | unknown` view of every harness without anyone writing it by hand.

`bin/fm-crew-state.sh <id>` is the single owner of *current state* — the values it returns are `state: working · source: pane · harness busy (pi-ext)` for this task right now, and the snapshot already pipes that into the board's underway rows.

### 1.4 States the captain wants to see (the five buckets in your ask)

Mapping your five buckets to the existing states already emitted by the snapshot and the board (`Underway` / `Charted Next` / `Recently Landed` / `Captain's Call`):

| Your bucket | Existing state | How it surfaces today | Source of truth |
|---|---|---|---|
| **Queued** (planned, not started) | `backlog.records[].state == "queued"` with `requires_child_metadata == false` (no child meta yet) | Board → `Charted Next` (kind `queued`) and `fm-fleet-view.sh` → `## Queued` table | `data/backlog.md` |
| **Active** (in flight, worker is making progress) | `tasks[].current_state.state ∈ {working}` and `current_role == "worker"` | Board → `Underway` row showing `name`, `kind`, `repo`, and `doing = current_state.detail`; view → `## Under Way` | `bin/fm-crew-state.sh` reading `state/<id>.busy-state` + `state/<id>.pi-ext.ts` |
| **Blocked** | `backlog.records[].unresolved_blocker_ids.length > 0` (any blocker still queued/in-flight) **or** `current_state.state ∈ {blocked, parked, paused}` | Board → `Charted Next` row with `blocked_by`, or `Holds` row in the secondmate summary; view shows the structured row's blockers | backlog + `state/<id>.status` |
| **Review** (validation/PR-ready, awaiting merge) | `current_state.state ∈ {parked}` from validation **or** `pr.url != null && current_state.state == "working"` (worker still validating) **or** `hold_kind == "captain"` row sitting in `decisions_open` because of a `--release` keep-on-hold | Board → `Captain's Call` `type=merge` card with the PR URL and a single `merge` value; nothing else surfaces "review" without a structured field | `state/<id>.meta::pr=`, `bin/fm-captain-hold.sh` |
| **Done** | `backlog.records[].state == "done"` with `completion.verb ∈ {merged, reported, done}` and a populated `pr_url` or `report_path` | Board → `Recently Landed` row with `what`, `owner`, optional `pr_url`; view → `## Done` table | backlog Done section + `data/done-archive.md` |
| **(extra) Needs your input** | `hold_kind == "captain"` rows where the captain hold is currently `live` and the blocker set is empty (`captain_actionable == true`) | Board → `Captain's Call` card with structured options, fed by the bound Lavish source | `bin/fm-captain-hold.sh` |

The four board sections plus `Holds` cover your five buckets without inventing new state. `done_keep = 10` in `.tasks.toml` already gives a bounded "Recently Landed" feed.

### 1.5 What the snapshot returns for *this* home right now (evidence)

```
$ bash bin/fm-fleet-snapshot.sh --json | jq '.tasks[] | {id, current_state, endpoint: .endpoint.target}'
{
  "id": "br-system-herdr-audit",
  "current_state": { "state": "working", "source": "pane", "detail": "harness busy (pi-ext)" },
  "endpoint": "default:w3:p2"
}
{
  "id": "br-system-ticket-audit",
  "current_state": { "state": "working", "source": "pane", "detail": "harness busy (pi-ext)" },
  "endpoint": "default:w4:p2"
}
```

The snapshot already joins every in-flight backlog row to its `state/<id>.meta` and exposes the Herdr endpoint target as `endpoint.target`. What's missing is the join back to a human-readable pane label and the live agent name (`pi` / `codex`, with model suffix when the harness reports one), which is one `herdr pane list` call away (see §2.3).

---

## 2. Visual surface — what's there and the smallest way to keep it always-on

### 2.1 The Lavish board already exists

`/home/hd2admin/kun-agent-workspace/.agents/skills/bearings/assets/board-template.html` (749 lines, the shipped Firstmate Design System template) is the visual surface. The board path is stable at `$FM_HOME/.lavish/bearings-board.html`, so a rebuild keeps the same URL and the same canonical process-event source id (`fm-procevent-lavish.sh source-id` derives a `lavish-<sha256[:16]>` id from `realpath`).

`bin/fm-bearings-board.sh build` (the only thing you need to invoke) does, in this order:

1. Validates the payload against the `fm-bearings-board.v1` schema (every field is type-checked; `repo` and `name` are required markers; `reconcile` is reserved as a value the script itself injects so the composer cannot forget it).
2. Drops every Captain's Call decision card whose subject has already landed (in this home's own payload or via `bin/fm-captain-hold.sh open` returning 1 = "no longer an open captain call").
3. Injects the standard `reconcile` option onto every surviving decision card.
4. Compacts the JSON and `\\u003c`-escapes every `<` so a payload containing `</script>` cannot terminate the data block early.
5. Renders to `$FM_HOME/.lavish/bearings-board.html`, runs `lavish-axi <board>` to establish the session, and **proves the session is live** by checking the server's own session listing (`open`, not `user-ended`).
6. Reopens an ended session exactly once if needed (retiring the pre-reopen source generation through the guarded adapter path).
7. **Binds first** (`bin/fm-captain-hold.sh bind <sid>` — the binding precedes the arm), so a board that produces an answer with nowhere to go is impossible.
8. **Arms only after binding** (`fm-procevent-lavish.sh arm <board>`), then reconciles if no live listener owns the source.
9. Refuses to arm if the session is not listed open.

This is the right order. The only thing it is not is *continuous* — today the board is rebuilt on `/bearings lavish`. The smallest way to keep it always-on is one re-arm per snapshot tick, not a new template, not a new schema, not a new aggregator.

### 2.2 The captain's view already exists

The four board sections, in payload order, already answer every bucket in your ask:

| Section | Lives in the board | Captain's question |
|---|---|---|
| **Captain's Call** | `captains_call[]` | "What needs my input?" — every `hold_kind=captain` row that is `live` (blocker empty), plus PR-ready merge cards, plus needed credentials. |
| **Recently Landed** | `landed[]` | "What shipped?" — `backlog.records[].state == done` rows within the retention bound (`done_keep = 10`). |
| **Underway** | `underway[]` | "What is in flight, who owns it, and what is it doing right now?" — one row per in-flight `tasks[]` whose `current_role == worker`. The template already leads with the durable `name` and puts `kind`, `repo`, and `doing` (= `current_state.detail`) on the second line (`.agents/skills/bearings/assets/board-template.html:631-637`). |
| **Charted Next** | `charted[]` | "What is planned / what is waiting on me indirectly?" — queued items, blocked items, dated holds, action-free integrity warnings (the `(main-inventory)` and `(return-catchup)` gates). |

Every chart row's `dispatchable` boolean is the canonical gate — `warning` rows stay out of the dispatch picker, and `omitted` counts separate `charted_more` from `charted_warning_more`. There is no need to invent a separate "planned" column.

### 2.3 The only new join: live Herdr label, agent name, and `agent_status`

`herdr pane list` (verified at capture time on this very home) returns the join you want:

```json
{"panes":[
  {"pane_id":"w2:pA","workspace_id":"w2","tab_id":"w2:tA",
   "label":"BR-00 · COORDINATOR","agent":"codex","agent_status":"working","focused":true,
   "terminal_title":"⠦ Coordinate Stream A kickoff | kun-agent-workspace",
   "agent_session":{"agent":"pi","kind":"path","source":"herdr:pi","value":"...pi-session.jsonl"}},
  {"pane_id":"w2:pM","workspace_id":"w2","tab_id":"w2:tA",
   "label":"BR-10 · CORE DISTRO · M3","agent":"pi","agent_status":"idle",
   "agent_session":{"agent":"pi","kind":"path","source":"herdr:pi","value":"...stream-a-nav...jsonl"}},
  {"pane_id":"w3:p2","workspace_id":"w3","tab_id":"w3:t2",
   "label":"BR-01 · HERDR LAYOUT AUDIT","agent":"pi","agent_status":"working",
   "agent_session":{"agent":"pi","kind":"path","source":"herdr:pi","value":"...herdr-audit...jsonl"}},
  {"pane_id":"w4:p2","workspace_id":"w4","tab_id":"w4:t2",
   "label":"BR-02 · GOALS & TICKETS AUDIT","agent":"pi","agent_status":"working",
   "agent_session":{"agent":"pi","kind":"path","source":"herdr:pi","value":"...ticket-audit...jsonl"}}
]}
```

Joining `state/<id>.meta::herdr_pane_id` to `herdr pane list[].pane_id` (or via the snapshot's `endpoint.target` = `default:w<…>:p<…>`) gives, per ticket:

- `pane.label` — the human-readable working name the captain sees in Herdr (e.g. `BR-02 · GOALS & TICKETS AUDIT`).
- `pane.agent` + `pane.agent_session.value` — who is running it (e.g. `pi` on `MiniMax-M3`).
- `pane.agent_status` — `working` vs `idle`, the most recent fresh read (refreshed on the same cadence the bearings snapshot uses; the snapshot already reads `endpoint.exists` cheaply per row, so the `agent_status` read is the same cost shape).
- `pane.focused` + `pane.workspace_id` — which workspace the captain should attach to (`herdr workspace attach <id>`).

This is *not* duplicate status — it is read from Herdr directly, exactly like the `busy-state` file is read from `state/<id>.pi-ext.ts`. The board never authors agent status; it joins two existing sources.

The board's underway payload validator (`bin/fm-bearings-board.sh validate_payload`, `underway_item`) already requires `repo`, `name`, `id`, `state`, `doing`, and `kind`. Adding three optional keys — `pane_label`, `agent_name`, `agent_status` — extends that contract without breaking any past payload, because `validate_payload` checks "every required field is present" rather than "no extra fields" (it uses `has(...)` guards).

### 2.4 Why this is the smallest path

- **No new schema.** The board payload is already versioned (`fm-bearings-board.v1`); the change is three optional fields on `underway_item`.
- **No new aggregator.** The snapshot already runs `fm_backend_target_exists` per row; `agent_status` joins on the same endpoint probe.
- **No new file.** `data/goals.md` is the only durable new file (see §3.1); everything else reads existing state.
- **No new command in the captain's hands.** The board URL stays at `$FM_HOME/.lavish/bearings-board.html`; the rebuild cadence stays the only knob.
- **No duplicate status.** Agent activity is read from Herdr; task state is read from `state/<id>.meta`/`busy-state`; nobody writes either by hand.

---

## 3. Goals — minimal convention on top of existing primitives

### 3.1 Why a goal is not a Firstmate primitive

`tasks-axi` does not know `goal`. The snapshot's `parse_row` jq only knows `repo`, `kind`, `priority`, `hold*`, `blocked_by*`, `since`, `merged/reported/done`, `links`, `pr_url`, `report_path`, `local_note`, `body_lines`. The board validator only accepts `captains_call[]`, `underway[]`, `landed[]`, `charted[]` items with the documented field shapes.

So a goal has to live as either (a) a markdown convention the parser can be taught to recognize, or (b) a parallel file the composer can join against. The smallest is (b), because (a) requires a snapshot schema bump (the snapshot's job is to be a read-only contract — bumping it for a captain preference is the wrong tool).

### 3.2 Recommended convention: `data/goals.md`

One file. One bullet per goal. Optional `repos:` list. Optional `parent:` for sub-goals. The snapshot does not need to read it; the board composer reads it (or any composer that wants to group underway / charted rows by goal reads it).

Example shape (the only durable new artifact this audit proposes):

```markdown
# Goals

## br-launch-1 — Brandon multi-project infrastructure (parent)
repos: firstmate, core-distro-saas-clean
filed: 2026-09-23
- (none)

## br-herdr-vis — Visible Herdr pane layout and per-pane task binding
repos: firstmate
parent: br-launch-1
filed: 2026-09-23
- (none)

## br-ticket-vis — Ticket, goal, and live-status board
repos: firstmate
parent: br-launch-1
filed: 2026-09-23
- (none)

## br-stream-a — Stream A deployment artifact (local-only, no publish)
repos: core-distro-saas-clean
parent: br-launch-1
filed: 2026-09-23
- (none)
```

Each ticket then carries a `goal:<slug>` tag in its body. The parser doesn't need to read it; humans and the board composer do.

### 3.3 Adding `goal:<slug>` to a backlog row

The smallest way to attach a goal to a ticket without changing `tasks-axi`:

```bash
# Attach a goal tag to the body of an existing task (manual once, durable).
tasks-axi update <id> --body-file <(printf 'goal:br-stream-a\n\n%s' "$(tasks-axi show <id> --full | sed -n '/^body:/,$p')")
```

`tasks-axi update --body-file` replaces the body and `--archive-body` preserves the prior body. There is no need for a new field.

To extract the goal tag when composing the board, the composer's own snippet:

```bash
jq -r '.body // "" | match("goal:([a-z0-9._-]+)"; "g") | .string[1]' "data/<id>/report.md"
# or against the backlog directly:
awk -v id="<id>" '
  /^## / { if (hit) exit; in_section = ($2 == "In flight" || $2 == "Queued") }
  in_section && $0 ~ "[[:space:]]" id "[[:space:]]-" { hit = 1 }
  hit && /goal:/{ sub(/.*goal:/, ""); sub(/[[:space:]].*$/, ""); print; exit }
' data/backlog.md
```

That is a one-line composer join. The board template adds an optional `goal` field to `underway_item` and `charted_item` and renders it as a chip.

### 3.4 How goals surface on the board

- `underway[].goal` (optional string) — chip on the row.
- `charted[].goal` (optional string) — chip on the row, used by the same composer to group related rows.
- `captains_call[].goal` (optional string) — chip on a decision card; answers recorded against a card also stamp `data/goals.md` for that goal's history.
- Goals themselves are *not* items in `captains_call` or `charted`. They are a roll-up grouping; the only place they need to be queryable as a list is the board's section sort and the `prs_live` header (existing `home` / `generated`).

### 3.5 Why not bump the schema for goals

- The snapshot's contract is read-only and must not depend on a captain preference.
- `tasks-axi`'s `--kind` is a fixed vocabulary (`ship`/`scout`/`docs`/...). Overloading `kind` would break the snapshot's `current_role` derivation.
- A second file (`data/goals.md`) is gitignored next to `data/backlog.md`, `data/projects.md`, `data/secondmates.md`, `data/learnings.md`, and `data/captain.md`. It belongs in the same family — captain-private, locally owned, never committed.

---

## 4. Concrete setup commands (in order)

These are the commands a follow-up implementation worker should run, grouped by owner. None of them ship today; this audit only recommends them.

### 4.1 Establish `data/goals.md` (one-time)

```bash
# Create the captain-private goals file (gitignored, sits with backlog/projects/learnings).
mkdir -p data
cat > data/goals.md <<'GOALS'
# Goals

## br-launch-1 — Brandon multi-project infrastructure (parent)
repos: firstmate, core-distro-saas-clean
filed: 2026-09-23
- (none)
GOALS
chmod 0600 data/goals.md
```

### 4.2 Attach the goal to existing tickets (per ticket)

```bash
# Get current body, append goal tag, replace via tasks-axi update.
for id in br-system-ticket-audit br-system-herdr-audit; do
  body=$(tasks-axi show "$id" --json | jq -r '.body // ""')
  printf 'goal:br-launch-1\n\n%s\n' "$body" > /tmp/body.txt
  tasks-axi update "$id" --body-file /tmp/body.txt --archive-body
done

tasks-axi update stream-a-deploy-artifact \
  --body-file <(printf 'goal:br-stream-a\n\n%s' "$(tasks-axi show stream-a-deploy-artifact --json | jq -r '.body // "")") \
  --archive-body
```

### 4.3 Build the board (per snapshot tick)

```bash
# Read snapshot, compose payload, build.
snapshot=$(bash bin/fm-fleet-snapshot.sh --json)

# The composer (NOT this audit's job) joins three things:
#  1) backlog records (the snapshot already parses them with all blockers/holds resolved)
#  2) state/<id>.meta::herdr_pane_id  → herdr pane list[].pane_id (label, agent, agent_status)
#  3) data/goals.md (the captain-private file from §4.1) joined on each row's goal tag
# The composer writes the payload to /tmp/board.json, then runs:
bash bin/fm-bearings-board.sh build /tmp/board.json
```

`bin/fm-bearings-board.sh build` is already designed for that exact input flow:

- It validates the payload, drops landed cards, injects `reconcile`, escapes `<`, establishes the Lavish session, proves it is `open`, **binds before arm**, and only then arms the source.
- It prints the final live status:
  - `board: <path>`
  - `served: <path>`
  - `bound: <sid>`
  - `armed: <sid>` (first time) or `already-armed: <sid>` (rebuild)
  - `listening: live` (if a replacement was needed)

### 4.4 Always-on rebuild cadence (the smallest knob)

The board source id is `lavish-<sha256[:16]>` over the canonical board path; rebuilding in place reuses the same id. The cheapest continuous loop is:

```bash
# Inside the supervised shell of the home (one cron entry or one shell loop on a long cadence).
while sleep 30; do
  snapshot=$(bash bin/fm-fleet-snapshot.sh --json)
  composer_output=$(compose-board-payload "$snapshot")      # writes /tmp/board.json
  bash bin/fm-bearings-board.sh build /tmp/board.json \
    >/tmp/board-build.log 2>&1 || logger -t fm-board "build failed: $(tail -1 /tmp/board-build.log)"
done
```

This is what `fm-procevent.sh` already does for *rebuilding when the source gets orphaned*: the reconciliation loop calls `await_source_owner` and starts a replacement listener, so a board that loses its session gets restarted by the watcher rather than the captain. The continuous rebuild is just an additional tick on the same id.

### 4.5 The captain's three-line read path

```bash
# 1) What needs my input?
tasks-axi list --kind captain --state in_flight

# 2) What's underway, who owns it, what is it doing?
bash bin/fm-fleet-view.sh

# 3) What does the board say?
open "$FM_HOME/.lavish/bearings-board.html"   # the same URL the rebuild keeps re-publishing
```

`bin/fm-fleet-view.sh` already prints Under Way / Queued / Done tables; the board adds the visual grouping and the click-to-answer intake.

---

## 5. State buckets → captain answer mapping (your five states)

| Bucket | Definition (no invention) | Owner | Captain action |
|---|---|---|---|
| **Queued** | `backlog.records[].state == "queued"` | `data/backlog.md` | Optional — dispatch from `tasks-axi ready` (already lists unblocked queued). |
| **Active** | `tasks[].current_state.state == "working"` AND `current_role == "worker"` | `bin/fm-crew-state.sh` reading `state/<id>.busy-state` (driven by `state/<id>.pi-ext.ts`) | None unless `hints.pending_decision == true`. |
| **Blocked** | `backlog.records[].unresolved_blocker_ids.length > 0` (a blocker id still in `in_flight` or `queued`) OR `current_state.state ∈ {blocked, parked, paused}` without a `hold_kind=captain` row | `data/backlog.md` + `state/<id>.status` | Clear the blocker or escalate. |
| **Review** | `current_state.state == "parked"` while a no-mistakes pipeline is running **OR** `current_state.state == "working"` AND `pr.url != null` (worker is validating) **OR** a captain hold with `close=release` waiting on the merge | `state/<id>.meta::pr=` + `bin/fm-crew-state.sh` | Approve the PR (board card → `merge`) or release the work (`--release` on `answer`). |
| **Done** | `backlog.records[].state == "done"` with `pr_url` or `report_path` populated | `data/backlog.md` Done section + `data/done-archive.md` | None; the row is the receipt. |
| **(extra) Needs your input** | `hold_kind=captain` with empty blocker set AND `decisions_open` (snapshot's authoritative fold) | `bin/fm-captain-hold.sh open` + bound board source | Answer via board card or `bin/fm-captain-hold.sh answer <id> --decision-file <file>`. |

The board maps these to its four sections (`Captain's Call`, `Underway`, `Recently Landed`, `Charted Next`) automatically. `decisions_open` is the durable fold; `current_state` is the live read; `blocked_by_ids` is the dependency DAG; `hold_kind` is the routing field. No new vocabulary is needed.

---

## 6. Anti-recommendations (what NOT to do)

1. **Do not invent a second status field maintained by hand.** `busy-state` is already driven by `pi-ext.ts`'s `agent_start` / `agent_settled` events; the agent_status read joins the same Herdr source. Hand-maintained state will diverge the moment the captain leaves the room.
2. **Do not add a `goal` field to `tasks-axi`.** It would force a snapshot schema bump for a captain-local convention. Use `data/goals.md` + a `goal:<slug>` tag in the body.
3. **Do not fork `fm-fleet-snapshot.sh`.** The snapshot is the read-only contract; per-captain preferences must not leak into it. Compose a board payload from the snapshot instead.
4. **Do not bind or arm the Lavish source before the session is `open`.** The build script already enforces this; a hand-rolled rebuild would break it. If the session ended from the captain's browser, `bin/fm-bearings-board.sh` reopens it exactly once and retires the pre-reopen source generation.
5. **Do not poll `lavish-axi poll` from a conversational turn.** The supervised runner owns the blocking poll; the watcher repairs an orphaned source automatically via `await_source_owner` + `reconcile`. Run `bin/fm-procevent-lavish.sh arm <board>` once per rebuild and let the watcher handle the rest.
6. **Do not re-register the board's source id under a new path.** The id is `lavish-<sha256[:16]>` over `realpath` of `$FM_HOME/.lavish/bearings-board.html`; two paths for one file = one source.
7. **Do not move the canonical board path out of `$FM_HOME/.lavish/`.** That is the path the bearings skill expects; moving it breaks every existing reference.
8. **Do not use the chat version of `/bearings` for the always-on surface.** Plain `/bearings` is chat-only and writes no artifact. The board needs `/bearings lavish` (or the rebuild loop in §4.4) to exist on disk.
9. **Do not treat `state/.afk` as visual data.** Away-mode is supervisor state, not a board surface; the board's `(return-catchup)` gate is the action-free integrity notice the captain sees when away-mode is active.
10. **Do not commit `data/goals.md` or any captain-private state.** `data/` is gitignored in the same family as `captain.md`, `projects.md`, `secondmates.md`, `learnings.md`, and `backlog.md`. Keep the goal file there.

---

## 7. Evidence ledger

| Finding | Command run | Path / line |
|---|---|---|
| Backlog has 3 in-flight, 0 queued, 0 done | `tasks-axi list` from `/home/hd2admin/kun-agent-workspace` | this report §1.1 |
| Tasks-axi has no `goal` field | `tasks-axi add --help`, `tasks-axi list --help`, `tasks-axi update --help`, `tasks-axi show --help` | this report §1.2 |
| Snapshot is `fm-fleet-snapshot.v1`, joins backlog + state + endpoint | `bin/fm-fleet-snapshot.sh --json` | output captured §1.5 |
| Fleet view renders Under Way / Queued / Done | `cat bin/fm-fleet-view.sh` | this report §2.2 |
| Board template is the Firstmate Design System, 749 lines | `wc -l .agents/skills/bearings/assets/board-template.html` | this report §2.1 |
| Build script enforces serve-then-bind-then-arm ordering | `bin/fm-bearings-board.sh` (read in full) | this report §2.1 |
| Live Herdr panes this audit joined against | `herdr pane list` | JSON captured §2.3 |
| `state/<id>.busy-state` is driven by `state/<id>.pi-ext.ts` (`agent_start` / `agent_settled`) | `cat state/br-system-ticket-audit.pi-ext.ts` + busy-state file | this report §1.3 |
| `.tasks.toml` selects the `markdown` backend with `path=data/backlog.md`, `done_keep=10` | `cat .tasks.toml` | this report §1.1 |
| `state/<id>.meta` already records `herdr_session=`, `herdr_workspace_id=`, `herdr_tab_id=`, `herdr_pane_id=` | `cat state/br-system-ticket-audit.meta` | this report §1.3 |
| `bin/fm-captain-hold.sh` is the one keyed-answer intake; board bind precedes arm | `bin/fm-captain-hold.sh --help` + `bin/fm-bearings-board.sh` `bind` before `arm` ordering | this report §2.1, §3.5 |

---

## 8. Summary

- **You have a ticket system already** — `data/backlog.md` + `tasks-axi`, edited by `add`/`start`/`done`/`hold`/`block`/`ready`. The five states you asked for are exactly the existing `Queued` / `Active` / `Blocked` / `Review` / `Done` plus the orthogonal "Needs your input" channel (`hold_kind=captain` rows).
- **You have a visual board already** — `/bearings lavish` builds `~/.lavish/bearings-board.html` via `bin/fm-bearings-board.sh`, in the shipped Firstmate Design System template, with the four sections that answer every bucket of your ask. It is not continuous; the smallest way to keep it always-on is a per-tick `build` over the same canonical path.
- **The two real gaps** are (1) a `goal` primitive (recommend: `data/goals.md` + `goal:<slug>` tag in the ticket body; no `tasks-axi` field, no snapshot bump), and (2) the live Herdr pane label + agent name + `agent_status` join into the underway rows (one `herdr pane list` call per snapshot tick, three optional keys on `underway_item`).
- **The smallest wiring is one composer.** It reads the snapshot, joins the Herdr pane list on `endpoint.target`, joins `data/goals.md` on the `goal:<slug>` tag, writes the `fm-bearings-board.v1` payload, and calls `bin/fm-bearings-board.sh build`. Everything else — ordering, validation, escaping, session liveness, binding, arming, listener replacement — is already owned by the build script and the watcher.

If you want this shipped, the implementation is a follow-up scout or ship task with a brief that says "compose the board payload, attach the goal tag to each in-flight row, bind the board source once, run the rebuild loop on a 30 s tick, hand back the live URL." The audit's deliverable is the recommendation above; the captain's own decision on whether to keep the board always-on, intermittent, or only on `/bearings lavish` belongs in Captain's call before any worker ships.