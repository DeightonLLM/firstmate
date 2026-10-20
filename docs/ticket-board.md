# Ticket board

`bin/fm-ticket-board.sh` renders one screen that answers three questions across this fleet: what needs the Captain's input, what is under way, and what is planned.
It is a read-only view over the ticket system this repo already has.
It is not a new tracker, it is not a second backlog, and it never closes, moves, reorders or edits a ticket.

## Why it exists

The Captain's to-do list is dirty and stale, and he is lost in it.
The ticket system itself is not the problem: `data/backlog.md` is the backend file, `tasks-axi` is the CLI over it, and it already carries the five states the Captain wants.
What was missing was one honest view over that system, and one that says which rows are stale rather than presenting them as live work.

## Usage

```
bin/fm-ticket-board.sh                render the board for this home
bin/fm-ticket-board.sh --file PATH    render the board for another backlog file
bin/fm-ticket-board.sh --full         expand every section
bin/fm-ticket-board.sh --help         print the usage
```

The board is safe to run at any time and changes nothing.
Exit 0 means the board rendered.
Exit 1 is a usage error.
Exit 2 means the backlog file is missing, unreadable, or holds no backlog section, and the message names the exact path.
Exit 3 means a required tool is missing.

`--file` exists so a secondmate home can point the board at its own backlog.
Without it the board reads `<FM_HOME>/data/backlog.md`.

## Sections, in order

1. `NEEDS YOUR INPUT` is first, because it is the section the Captain reads first.
2. `BLOCKED` shows each blocked ticket with its blocker, the blocker's owner, and where the blocker id was resolved.
3. `IN FLIGHT` shows what is under way, with the owning lane and the recorded artifact path.
4. `READY / QUEUED` shows the next wave as counts by kind and by repo, plus the first few ready tickets.
5. `STALE` lists open tickets that look finished.
6. `LANES` shows the live lane rows from the lane registry.

## Data sources

All sources are read-only.

| Source | What it supplies |
| --- | --- |
| `<backlog>` | every ticket, its state, kind, repo, priority, date, hold, blocker and body |
| `<data>/async-lanes.tsv` | the lane registry: run_id, lane_key, model, surface, task, state, output |
| `<data>/core-remediation/lanes.json` | the Core programme lane manifest: id, status, owner, artifact, question |
| `<state>/<id>.meta` | the spawn record for a ticket, when this home has one: harness, model, effort |

The backlog file is parsed with the same rules `tasks-axi` applies, so the board and the ticket system agree on ids, states, holds, blockers and dates.
`tasks-axi list` and `tasks-axi show` have no read-only JSON mode, so the backend file is read directly with read-only tools instead.
The mirrored grammar lives in `tasks-axi/dist/src/backends/markdown-grammar.js`: the bullet patterns at lines 9 to 11, the trailing tag patterns at lines 44 to 52, `extractTags` at line 104, and `sectionState` at line 288.
The hold kinds come from `tasks-axi/dist/src/model.js` line 10 and are `captain`, `external`, `load`, `parked` and `future`.

## How each section decides

### Needs your input

A ticket is held on the Captain when its line carries the trailing tag `(hold-kind: captain)`, which is the `captain` entry of the `tasks-axi` hold kinds.
The first live example is `data/backlog.md` line 272.
The question shown is the ticket's own `(hold: ...)` text, which is the reason `tasks-axi` records for the hold.
The waiting age is computed from the ticket's `(since YYYY-MM-DD)` date, which is the `TAIL_SINCE` tag at grammar line 48.
A hold on a ticket that is already closed is not shown here, because it is no longer waiting on anybody.

### Blocked

A ticket is blocked when its line carries a trailing `blocked-by: <id>` edge, which is the `TAIL_DEP` tag at grammar line 44.
The first live example is `data/backlog.md` line 272.
The blocker id is resolved against the backlog and against the Core lane manifest, and the board says which one it found.
When neither holds the id, the board says `not in the backlog or the core lane manifest` rather than guessing an owner.
When the blocker resolves to a Core lane, the board also prints that lane's status, which is how a ticket blocked on a closed lane becomes visible.

This is deliberately broader than `tasks-axi list --blocked`.
`tasks-axi` only calls a ticket blocked when the blocker id resolves to a live ticket, and in this home no blocker id does, so `tasks-axi` reports zero blocked tickets while the board shows the seven tickets that really carry the edge, measured on 2026-10-20.
The board never hides a recorded edge because the ticket system cannot resolve it.

### In flight

A ticket is in flight when it sits under the `## In flight` section header, which is `data/backlog.md` line 3.
The owning lane is found by an exact id match against the lane registry, and by an artifact path match as a fallback.
The board labels which kind of match it used, and prints `lane: none recorded` when neither match exists, because the lane registry records lane task descriptions rather than backlog ids.
The artifact path is the path the ticket itself records, and the board marks it `exists` or `missing` against the home's own data directory.

### Ready and queued

A queued ticket is ready when it carries neither an active hold nor a `blocked-by` edge.
The board prints the queue split so the arithmetic is visible: `queued N = ready N + held N + blocked N + held and blocked N`.
The counts are by kind and by repo rather than a dump of every row.

### Stale

A ticket is listed as stale when it is still open and one of two evidence signals fires.
The first signal is a title that states a resolution, matched against a short fixed phrase list: `no guard defect found`, `no defect found`, `cancelled`, `canceled`, `recovered intact`, `spec recovered`, `already satisfied`, `already complete`, `already done`, `nothing to do`, `no action needed`, `obsolete`, `superseded`, `no change needed`, `resolved`, `clearing pass complete`.
The second signal is a report path the ticket records that already exists on disk while the row is open.
Each row states which signal fired and why.
The section says in its own header that it closes nothing, and the script mutates no ticket.
The Captain decides what to close.

### Lanes

A lane row is live when the first token of its state is not a terminal token.
The terminal tokens are `complete`, `completed`, `done`, `stopped`, `failed`, `failure`, `timeout`, `timed`, `terminal`, `duplicate`, `artifact`, `stale`, `unverified` and `candidate`.
Terminal rows are counted and hidden by default, and `--full` reveals them.

## The board prefix

Every rendered row carries the captain-locked prefix documented in [`todo-prefix-canonical-format.md`](todo-prefix-canonical-format.md) line 34:

```
[<harness>·<ModelAbbrev> <effort> @<Host>]
```

The four parts come from recorded evidence only.
The harness and effort come from the ticket's own `state/<id>.meta` spawn record.
The lane registry contributes the same three parts for lane rows, with the registry `surface` column as the host.
A ticket that no spawn record covers falls back to a lane row that names its id, and then to a lane row that owns the artifact path the ticket records.
Every part is taken from a recorded value.
A part that no source records prints as `unknown`.
No harness, model, effort or host is ever invented, and a value is never guessed from a name.

The model is shortened with the canonical alias table in `bin/fm-todo-prefix-check.sh`, which `docs/todo-prefix-canonical-format.md` names as the single owner of that table.
A model that no alias claims prints as `unknown` rather than as a raw identifier, so the board never puts a token on a row that the canonical alias table does not own.
The host is the recorded hostname token, in the lowercase form the canonical contract uses.
The effort is the bare code from the recorded effort word, using `l`, `m`, `h`, `xh` and `x`.

### The one known divergence

`bin/fm-todo-prefix-check.sh` rejects a board row whose harness or model is not a canonical token, so the rows whose harness and model no source records are reported by that checker as an unknown harness token.
This is deliberate.
The board's rule is that absence prints `unknown`, and the alternative would be to invent a harness, which the board must never do.
On the live backlog at the time of writing, 18 of 85 rendered rows carry a full canonical prefix and the rest carry `unknown` for the parts the backlog never recorded.

## Home resolution

The board follows the house idiom used by `bin/lane-todo-board.sh`.

| Variable | Meaning |
| --- | --- |
| `FM_HOME` | the home that owns `data/` and `state/` |
| `FM_ROOT_OVERRIDE` | the code root, when it is not the parent of `bin/` |
| `FM_DATA_OVERRIDE` | the data directory, when it is not `<FM_HOME>/data` |
| `FM_STATE_OVERRIDE` | the state directory, when it is not `<FM_HOME>/state` |

## What the board does not do

It never writes to the backlog, never runs a mutating `tasks-axi` command, and never closes a stale row.
It reads `data/backlog.md`, `data/async-lanes.tsv`, `data/core-remediation/lanes.json` and `state/<id>.meta`, and it prints.
`BOARD.md` is a durable navigation record rather than a live tracker, so the board does not read it.

[`scripts.md`](scripts.md) owns the purpose map for `bin/` scripts.
[`decision-hold-lifecycle.md`](decision-hold-lifecycle.md) owns the mechanism for recording and completing unresolved investigation decisions.
[`todo-prefix-canonical-format.md`](todo-prefix-canonical-format.md) owns the canonical board prefix and the model alias table.
