# Boards — every board in the fleet, and how they differ

**Nothing here is deleted.** Boards overlap on purpose: some are historical records, some are operator views, one is the Captain's own working board. This map says which one answers which question, so a board is never mistaken for another one.

**Generated:** 2026-10-21T03:26:32Z by `bin/build-boards-doc.py` (machine facts probed live from `/root/agent-work/deightonllm-firstmate`; the prose is written by hand). Re-run the script after adding or retiring a board.

## The one-line map

| Board | Kind | Audience | Live? | Size | In git |
|---|---|---|---|---|---|
| `unified-board.html` | hand-maintained HTML | the Captain (his working board) | hand-maintained (no generator) | 33,101 B | untracked |
| `.lavish/CAPTAIN-BOARD.html` | generated HTML | the Captain | yes | 135,742 B | ignored |
| `next-signpost/NEXT-BOARD.md` | generated markdown | agents + the Captain | yes | 0 B | absent |
| `data/tracker/fleet-dash.html` | generated HTML | operators | yes | 115,077 B | ignored |
| `data/tracker/board.html` | generated HTML | operators | yes | 29,198 B | ignored |
| `data/campaign-dashboard-20261015/board.html` | dated record + HTML view | everyone (historical) | frozen record | 18,229 B | ignored |
| `data/hd2-takeover/board.html` | generated HTML | the Controller | yes | 31,878 B | ignored |
| `.lavish/enforcement.html` | static HTML (2 copies) | operators + the Captain | static | 33,153 B | ignored |
| `.lavish/LANE-TODO-DASH.html` | generated HTML | operators | STALE | 11,204 B | ignored |
| `index.html` | generated HTML | operators | yes | 13,665 B | tracked |

## The differences that matter

**1. Where the data comes from.** Two boards are generated from the machine lane ledger (`ops/lane-ledger.tsv`) and cannot drift from it — the NEXT board and the Captain's board. The dashboards are generated from a host-side snapshot and are only as fresh as that snapshot. `unified-board.html` is hand-edited, which is why it is the Captain's and why nothing regenerates it.

**2. What they can do.** Only the Captain's board can *ask* you something: a radio question queues exactly one answer, and a ticket batch queues a set with a receipt contract that must account for every ticket number. Every other board is read-only.

**3. What they are for.** The campaign board is a frozen record (it is the only surviving text for the row ticket-0003 cites). The enforcement surface proves what the fleet enforces. The dashboards show lanes, tickets and capacity. The unified board is your working surface. The NEXT board is the textual contract the others project from.

**4. Where quota and token use belongs.** Today quota appears on the unified board as *status rows* about quota work, not as live numbers, and token use is not shown at all — that is the accuracy and design gap being closed in `fm/quota-board-20261021`.

## Board by board

### `unified-board.html`

- **Name:** HD2 Fleet Unified Board & To-Do Tracker
- **Kind:** hand-maintained HTML
- **Audience:** the Captain (his working board)
- **Data source:** hand-edited; status rows cite the docs that carry the truth
- **Live:** hand-maintained (no generator)
- **Present in the working checkout:** yes · 33,101 B · last modified 2026-10-19 00:59 · git state: **untracked**
- **What it is for:** The Captain's own board. Header carries the host/model line, the 'Unified Synced' pill and the Snapshot Freshness meter; the body is a feature-and-ticket table with section pills.
- **How it differs:** The only board the Captain edits by hand, so it holds his work and is never regenerated. Quota appears here as STATUS ROWS (e.g. 'Quota-axi 5-hour session primary display - delivered in QUOTA-ROUTING-RUBRIC.md'), not as live quota numbers or token meters - that is the gap the quota band fills.

### `.lavish/CAPTAIN-BOARD.html`

- **Name:** Captain's board (decision surface)
- **Kind:** generated HTML
- **Audience:** the Captain
- **Data source:** bin/build-captain-board.py -> the lane ledger + INBOX/ tickets
- **Live:** generated from machine state
- **Present in the working checkout:** yes · 135,742 B · last modified 2026-10-21 03:16 · git state: **ignored**
- **What it is for:** The decision surface. Ticket-0003 verbatim with the proposed window, three decision questions, the 42-ticket queue as a tracked batch, the decisions settled, the space job, and the live to-do list.
- **How it differs:** The ONLY board with decision controls (a radio question queues one answer; a tracked batch queues a ticket set with a receipt contract). The only board that carries the to-do list straight from the lane ledger, and the only one that shows a ticket in full.

### `next-signpost/NEXT-BOARD.md`

- **Name:** NEXT board (machine to-do list)
- **Kind:** generated markdown
- **Audience:** agents + the Captain
- **Data source:** bin/build-next-board.py -> the lane ledger, the tracker, the backlog
- **Live:** generated; carries the ledger digest
- **Present in the working checkout:** no · 0 B · last modified - · git state: **absent**
- **What it is for:** The substrate under the Captain's board: every item with a state, an owner and a next action, plus the drift section and the push ledger.
- **How it differs:** Not HTML and not a dashboard - it is the TEXTUAL contract. It embeds '**Ledger digest:** sha256:...' so a reader can see the moment it stops matching the ledger. Published byte-identical to Controller, Hetzner and HD2Stack.

### `data/tracker/fleet-dash.html`

- **Name:** Fleet ticket dashboard (full)
- **Kind:** generated HTML
- **Audience:** operators
- **Data source:** a host-side snapshot of the live ticket queue
- **Live:** snapshot
- **Present in the working checkout:** yes · 115,077 B · last modified 2026-10-18 18:56 · git state: **ignored**
- **What it is for:** The busiest operator view: lane activity, tickets by priority, Hetz comms receipts and capacity.
- **How it differs:** Operator-facing and snapshot-based. It shows lanes and tickets, not decisions and not token/quota meters.

### `data/tracker/board.html`

- **Name:** Firstmate Lane Tracker
- **Kind:** generated HTML
- **Audience:** operators
- **Data source:** state/*.status, BOARD.md, CONTROLLER_STATE.md
- **Live:** snapshot
- **Present in the working checkout:** yes · 29,198 B · last modified 2026-10-18 04:49 · git state: **ignored**
- **What it is for:** Lane counts, per-lane status, the board and controller state, and a ticket intake panel.
- **How it differs:** The lane-state view: it answers 'which lane holds what', not 'what do I decide'.

### `data/campaign-dashboard-20261015/board.html`

- **Name:** Campaign Board 2026-10-15
- **Kind:** dated record + HTML view
- **Audience:** everyone (historical)
- **Data source:** data/campaign-dashboard-20261015/board.md (56 rows)
- **Live:** frozen record
- **Present in the working checkout:** yes · 18,229 B · last modified 2026-10-18 03:07 · git state: **ignored**
- **What it is for:** The dated campaign board, split into six areas: surface parity and trust, dispatch reliability and trust gates, communication and notification, Hetz/Brandon client work, staging/publication/retained Core work, and client archive and production safety.
- **How it differs:** The ONLY surviving record of the 'KVM1 Herdr registration | HELD' row that ticket-0003 cites - and the STATUS.md it cites does not exist anywhere, so this board row is the authoritative text. Frozen history, never regenerated.

### `data/hd2-takeover/board.html`

- **Name:** HD2 Fleet Controller Board
- **Kind:** generated HTML
- **Audience:** the Controller
- **Data source:** the controller queue + fleet state
- **Live:** snapshot
- **Present in the working checkout:** yes · 31,878 B · last modified 2026-10-17 17:51 · git state: **ignored**
- **What it is for:** The Controller's own board: controller queue plus fleet board.
- **How it differs:** Controller-facing. Not the Captain's surface and not a decision surface.

### `.lavish/enforcement.html`

- **Name:** Firstmate Enforcement Surface
- **Kind:** static HTML (2 copies)
- **Audience:** operators + the Captain
- **Data source:** the enforcement rule set
- **Live:** static
- **Present in the working checkout:** yes · 33,153 B · last modified 2026-10-13 21:57 · git state: **ignored**
- **What it is for:** What the fleet enforces: 11 rules enforced, 3 removed/inactive.
- **How it differs:** Proves enforcement rather than tracking state. Two copies exist (.lavish/ and data/lavish/) - identical purpose, different homes.

### `.lavish/LANE-TODO-DASH.html`

- **Name:** Fleet ticket dashboard (snapshot copy)
- **Kind:** generated HTML
- **Audience:** operators
- **Data source:** a host-side snapshot that does not exist on this host
- **Live:** STALE
- **Present in the working checkout:** yes · 11,204 B · last modified 2026-10-13 22:07 · git state: **ignored**
- **What it is for:** A 2026-10-13 copy of the fleet dashboard. It reads a host snapshot that is not present here, so every lane renders as 'unknown' and the ticket table says 'No backlog tickets found'.
- **How it differs:** This is the board that looks broken. It is kept, not deleted: it is the record of the older fleet-dashboard family and of the failure mode a board with no live data source has.

### `index.html`

- **Name:** Fleet ticket dashboard (repo entry point)
- **Kind:** generated HTML
- **Audience:** operators
- **Data source:** the live backlog
- **Live:** snapshot
- **Present in the working checkout:** yes · 13,665 B · last modified 2026-10-18 22:46 · git state: **tracked**
- **What it is for:** The tracked entry point of the same dashboard family.
- **How it differs:** Same family as LANE-TODO-DASH and fleet-dash, but it is the one that is committed to the repo.

## The rule

A board is retired by being **documented as superseded here**, never by being deleted. `LANE-TODO-DASH.html` is the example: it renders as broken because its data source is gone, and it stays in the tree as the record of that failure mode.
