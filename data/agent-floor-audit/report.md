# Agent floor audit — visual ticket board vs live fleet

## Scope and method

Read-only audit of `kun-agent-workspace/.lavish/brandon-agent-floor.html` against Firstmate's authoritative records (home `kun-agent-workspace`). Authoritative sources used:

- `kun-agent-workspace/data/backlog.md`
- `kun-agent-workspace/data/projects.md`
- `kun-agent-workspace/state/<id>.meta` and `state/<id>.status` for every in-flight task id
- `kun-agent-workspace/state/home-summary.json` (regenerated 2026-09-23T04:43:05Z)
- Live Herdr: `herdr workspace list` and `herdr pane list` (called directly)
- `herdr pane get wB:p2` to confirm the worker reading this report is the live pane

The board's footer is honest about its nature — "Snapshot, not a live-refreshing board. The backlog is authoritative" — so the audit does not treat staleness as a bug on its own. It treats staleness as a bug only where the snapshot then misrepresents itself as current.

## Findings

### F1. Three of four visible tickets no longer exist as live work

The board shows 4 tickets; 3 of them are stale snapshots of audits that already completed and were recorded as `Done` earlier the same day.

| Board ticket | Backlog id | Backlog status | Live pane | Mismatch |
|---|---|---|---|---|
| `BR-01 · HERDR LAYOUT AUDIT · w3:p2` (`Working`) | `br-system-herdr-audit` | `Done` 2026-09-23, `data/br-system-herdr-audit/report.md` | none | id OK, status wrong, pane id does not exist |
| `BR-02 · GOALS & TICKETS AUDIT · w4:p2` (`Working`) | `br-system-ticket-audit` | `Done` 2026-09-23 | none | id OK, status wrong, pane id does not exist |
| `BR-03 · UPDATES · w5:p2` (`Working`) | `br-system-update-audit` | `Done` 2026-09-23 | none | id OK, status wrong, pane id does not exist |

Evidence:

- `data/backlog.md` "## Done" section lists all three with `(reported 2026-09-23)`.
- `herdr workspace list` returns 7 workspaces: `w2`, `wB`, `wA`, `w9`, `w7`, `w8`, `w6`. There is no `w3`, `w4`, or `w5` workspace.
- `herdr pane list` returns 8 panes total. None of them has pane_id starting with `w3:`, `w4:`, or `w5:`.

Consequence: the "Work in view" grid renders three cards that point at non-existent steering paths. A captain who clicks `w3:p2`, `w4:p2`, or `w5:p2` cannot reach a worker.

### F2. Five live tickets are missing from the board

The live fleet has 5 in-flight tickets that the board does not show, plus one shared-coordinator pane:

| Live ticket (id · pane · agent · status) | On board? |
|---|---|
| `agent-floor-audit` · `wB:p2` · pi · `working` | No |
| `orchestration-map` → `BR-08 · ORCHESTRATION MAP · M3` · `wA:p2` · pi · `done` | No |
| `local-model-audit` → `BR-07 · LFM + OLLAMA + GATEWAY · M3` · `w9:p2` · pi · `done` | No |
| `elevate-mobile-audit` → `BR-06 · ELEVATE SITE · M3` · `w8:p2` · pi · `done` (backlog captain hold) | No |
| `core-mobile-fix` → `BR-05 · CORE MOBILE · M3` · `w7:p2` · pi · Herdr=`done` / status-log last `RED` | No |
| `tool-auto-update` → `BR-04 · SAFE UPDATE ENGINE · M3` · `w6:p2` · pi · `idle` | No |
| `stream-a-deploy-artifact` → `BR-10 · CORE DISTRO · M3` · `w2:pM` · pi · `idle` | Yes (only BR-10 is shown) |

Evidence:

- `data/backlog.md` "## In flight" section lists all 6 by their backlog ids.
- `herdr pane list` pane labels include the BR-04..BR-08 strings and `BR-10 · CORE DISTRO · M3`.
- `state/home-summary.json` `active_children` array contains only `agent-floor-audit` and `core-mobile-fix`; the other 4 are missing from `active_children` because they are reconciled as `done` via `state/<id>.status` (`done [at=...]`) — the home-summary still surfaces them as live endpoints under `endpoints`, just not as `working`.

Consequence: the board understates active and recently-completed work by 6 tickets. The captain sees a fleet of 4 when there are 8 live panes.

### F3. The board omits the coordinating agent

`herdr pane list` shows a focused `codex` pane at `w2:pA` labelled `BR-00 · COORDINATOR` with `agent_status=blocked`. The board's "Workers running" stat says "All Pi + MiniMax-M3, in Firstmate worktrees" and never mentions codex. The "Active goal" stat reads "Visible multi-agent work / Goal is active in this conversation" — the actual backlog goal is `visible-parallel-firstmate` (`data/backlog.md` goal tag).

Evidence:

- `herdr pane get w2:pA` returns `{"agent":"codex","agent_status":"blocked","label":"BR-00 · COORDINATOR","terminal_title":"[ . ] Action Required | Coordinate Stream A kickoff | kun-agent-workspace"}`.
- `data/captain.md` describes a "Codex on Luna" orchestrator; the board does not surface that role.

Consequence: the captain's "where is the coordinator" question cannot be answered from the board alone.

### F4. Counts and statuses do not match the live fleet

Board claim: `4 tickets · 3 agents working`.

Live counts (from `herdr pane list` agent_status field and `home-summary.json`):

| Status | Pi panes | Codex panes | Total |
|---|---|---|---|
| `working` | 1 (`agent-floor-audit` itself) | 0 | 1 |
| `blocked` | 0 | 1 (`BR-00`) | 1 |
| `idle` | 2 (`BR-10`, `BR-04`) | 0 | 2 |
| `done` | 4 (`BR-08`, `BR-07`, `BR-05`, `BR-06`) | 0 | 4 |

Consequence: "3 agents working" overstates the working count by 2 and understates the done count by 1. The board hides the blocked coordinator and the two idle Pi panes entirely from the overview stat.

### F5. BR-10 status is wrong

Board says `Review needed`. Herdr says `idle`. The backlog entry already notes `the current manually relaunched pane has no Firstmate task metadata` and the pane has no `state/stream-a-deploy-artifact.meta` or `.status` file.

Evidence:

- `ls kun-agent-workspace/state/stream-a-deploy-artifact.*` returns nothing.
- `herdr pane get w2:pM` returns `"agent_status":"idle"`, `"terminal_title":"π · M3 · w2:pM"` — the pane is alive but is not actively reviewing.
- `home-summary.json` `invalidity.reason`: `in-flight backlog item has no child metadata: stream-a-deploy-artifact`. `invalidity.kind`: `orphan_in_flight`.

Consequence: the "Ready for review: 1" stat asserts a state that Firstmate cannot prove, and the orphan-in-flight flag in the home-summary is not surfaced on the board.

### F6. core-mobile-fix shows split state across sources

`state/core-mobile-fix.status` ends with `RED [at=1790138500]: test_mobile_theme_toggle_hide.js fails on HEAD ... Applying late-scoped @media (max-width:767px) override ...` — i.e., the worker was actively applying a fix ~2 minutes before the audit.

`herdr pane get w7:p2` shows `agent_status=done` and `terminal_title="π · M3 · w7:p2"` — i.e., the Herdr runtime has marked the pane idle/done.

These disagree. The Firstmate status log is authoritative for what the worker last did; the Herdr pane-status reflects the harness/transport state.

Consequence: the captain cannot tell from either source alone whether this work is parked on a done pane or actively in flight. The board does not surface either signal, so it does not help disambiguate.

### F7. Duplicate entry in the "Jump to a worker" list

The "Herdr workspaces" card lists:

```
- w5 · BR-03 AGENT UPDATES — w5:p2 update audit
- w5 · BR-03 UPDATES — w5:p2 update audit
```

Two consecutive bullets resolve to the same `w5:p2` pane. There is no `w5` workspace in the live Herdr list.

Evidence: raw HTML at `kun-agent-workspace/.lavish/brandon-agent-floor.html`, "Jump to a worker" `<ul>`.

Consequence: a literal duplicate plus a non-existent workspace id in the same list.

### F8. Project and worktree are not actionable from the board

For BR-01/02/03 the board's only project/worktree hint is "Own Firstmate treehouse worktree". It does not link to:

- the absolute worktree path,
- the current branch (e.g. `fm/core-mobile-fix` for `core-mobile-fix`),
- the steering inbox path (`state/<id>.inbox/`),
- the backlog anchor for that task.

For BR-10 the board does give a branch (`stream-a-language-nav`) and a SHA-256, but does not give the worktree path or the inbox path.

Consequence: even for the one ticket the board does render correctly, the captain cannot directly steer the worker from the board. They would have to switch to Herdr to click the pane and type into the Pi REPL.

### F9. Captain hold is not surfaced

`data/backlog.md` carries `(hold: Provide the Elevate marketing source ... hold-kind: captain)` for `elevate-mobile-audit`, and `state/home-summary.json` `decisions_open[0]` lists the same `captain-hold`. The board does not surface either an open hold or a `Needs captain decision` field anywhere.

Consequence: the captain's open decisions are invisible from the board.

### F10. Quota and freshness stat is a stamped snapshot

`MiniMax remaining 88% · Quota snapshot 03:51 UTC · reset 05:00 UTC`. The board has no link, command, or path that lets the captain refresh this number. The snapshot time on the eyebrow line is `2026-09-23 03:53 UTC`; the file was last written ~50 minutes before the audit.

Consequence: the stat is informationally correct but operationally dead — the captain has no on-board path to verify it.

## Minimal recommendation

The audit is read-only. No code or config changes are made. The minimum changes that would make the board honest about itself and match the live fleet:

1. Replace the 4 "Work in view" cards with content driven by `bin/fm-tasks-axi.sh list` plus `state/<id>.meta` joined to `herdr pane list`, filtered to in-flight backlog items only. Render `done` items only if there is a captain hold or unresolved decision; otherwise drop them.
2. For each rendered ticket, show: backlog id, pane id, agent, harness state (from Herdr), last status event timestamp (from `state/<id>.status`), worktree path, branch, and the steering inbox path (`state/<id>.inbox/`).
3. Replace the "Workers running: 3" stat with the live histogram from `herdr pane list` (`working` / `idle` / `blocked` / `done`) and add `Coordinator: codex · w2:pA` separately.
4. Add a `stale` badge to the eyebrow when the file mtime is older than e.g. 10 minutes, with a "regenerate" link to whatever script wrote the file.
5. Render any open captain hold from `state/home-summary.json` `decisions_open[]` in its own card.
6. For `stream-a-deploy-artifact` (no `state/<id>.meta`), render an explicit `(no firstmate metadata)` badge instead of a fabricated "Review needed".
7. For tickets where Herdr pane state and Firstmate status-log state disagree (e.g. `core-mobile-fix`), show both side by side so the captain can see which source says what.
8. Remove the duplicate `w5 · BR-03 UPDATES` bullet in "Jump to a worker".
9. Add an `Agent: codex · pi` row for `BR-00` so the captain can locate the coordinator.

Items 1–3, 6, and 8 alone would eliminate every concrete mismatch listed above. Items 4, 5, 7, and 9 add the freshness, decision, and role-surfacing that the brief asked about ("a visible and steerable view").

## What was NOT investigated

Per the steering instruction in `state/agent-floor-audit.inbox/001.msg`, timestamp and clock-runtime anomalies were not investigated beyond the freshness note in F10.

No changes were made to the board, backlog, status/meta files, panes, agents, worktrees, projects, secondmates, or child supervisors. No child supervisor was created per pane. No secrets were inspected. No tests were run.

## Evidence pointers

- Board: `kun-agent-workspace/.lavish/brandon-agent-floor.html` (128 lines, mtime 2026-09-23T03:55:16Z, snapshot stamp 2026-09-23T03:53Z)
- Backlog: `kun-agent-workspace/data/backlog.md` (In flight: 7 items; Done: 3 items; Queued: empty)
- Projects: `kun-agent-workspace/data/projects.md` (2 projects: `core-distro-saas-clean`, `firstmate`, both `local-only +yolo`)
- Home summary: `kun-agent-workspace/state/home-summary.json` (generated 2026-09-23T04:43:05Z, `valid: false`, reason `orphan_in_flight` for `stream-a-deploy-artifact`)
- Herdr: `herdr workspace list` → 7 workspaces (`w2`, `wB`, `wA`, `w9`, `w7`, `w8`, `w6`); `herdr pane list` → 8 panes
- Task meta files: `kun-agent-workspace/state/{agent-floor-audit,core-mobile-fix,orchestration-map,local-model-audit,elevate-mobile-audit,tool-auto-update}.meta` (no `stream-a-deploy-artifact.meta` exists)
- Task status tails: latest events read from each `state/<id>.status`; full logs preserved at those paths
- Inbox: `kun-agent-workspace/state/agent-floor-audit.inbox/001.msg` (handled, moved to `handled/`)

Audit completed. No further action taken.