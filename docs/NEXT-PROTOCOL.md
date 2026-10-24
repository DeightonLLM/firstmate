# The NEXT contract — how work stops dying at the end of a report

**Why (Captain, 2026-10-20):** *"you tend to end on something leftover or something u found… i feel
we should always be fixing those not surfacing them at the end… with no signpost of next."*

Measured on the day this was written: **34 of 34** tracked items sat with `next_action: "Await lane
dispatch"` and no owner, and **41** artifacts in `data/hd2-takeover/` ended with a VERDICT line and
no next step. That is the rot this contract exists to stop.

---

## 1. Every artifact ends with two lines, in this order

```
VERDICT: PASS <reason>        (or FAIL <reason>)
NEXT: <the next action> | owner: <lane> | by: <when>
```

`NEXT:` is not optional. If there is genuinely nothing next, the line is
`NEXT: none — all items closed | owner: — | by: —`. "Nothing next" is a decision that gets written
down, not a silence.

The board generator checks this automatically: any artifact that has a VERDICT line and no NEXT
line is listed under **RESIDUALS** in the board.

## 2. Every tracked item carries three things: a state, a next action, an owner

- A **state** is one of: `VERIFIED-DONE`, `OPEN-WORKABLE`, `BLOCKED`, `NEEDS-CAPTAIN-DECISION`,
  `STALE-DUPLICATE`, `UNVERIFIED`.
- A **next action** says what "done" looks like. `"Await lane dispatch"` is **not** a next action —
  it is the absence of one, and it is the single biggest cause of the rot.
- An **owner** is a lane, not a person. An unowned item is a `CONTRACT-GAP`.

Anything missing one of the three is `CONTRACT-GAP` on the board, in plain sight.

## 3. A residual you discover is a ticket, not a report footer

When a lane finds something left over, half-finished or broken at the end of its work, it does not
mention it in the last paragraph and move on. **Before the lane closes**, it must:

1. create a tracker row in `data/tracker/tickets.jsonl` with `slug`, `title`, `priority`,
   `next_action` (a real action, not "await dispatch") and `owner` (a lane);
2. or, if the residual is already tracked, update that row's state and owner;
3. then regenerate the board.

A residual with no owner is a lane failure, not a documentation detail.

## 4. The board is regenerated at the end of every lane cycle

```bash
python3 bin/build-next-board.py --repo <repo> --out data/tracker
```

Output: `data/tracker/NEXT-BOARD.md` (human) and `data/tracker/next-board.json` (machine). The
board is the single signpost: **NOW** (what a lane can start today), **ONLY THE CAPTAIN CAN
UNBLOCK** (one question each), **BLOCKED** (blocker + recovery condition), **CONTRACT-GAP**, and
**RESIDUALS**.

A claim is not a fact: an item only reaches `VERIFIED-DONE` with an independent check — a command
and its result, or an artifact whose sha256 matches the claim. A report asserting `VERDICT: PASS`
is evidence that someone believed it, not evidence that it happened.

## 5. The "100% goal"

"100%" is the target for *closure of every open item*, not a claim that nothing ever breaks. The
honest reading, and the one this contract enforces:

- every item is **closed** (done with independent evidence), or
- **owned** with a next action, or
- **blocked** with a named blocker and a recovery condition, or
- **waiting on one specific decision** from the Captain, written as a single question he can answer
  in one line.

What is not acceptable is the fifth option — the item that is simply forgotten, sitting at "await
dispatch" with nobody holding it. That is the state this board makes impossible to hide.

## 6. The to-do list is generated, never hand-written

**The rule.** The to-do list is **generated from the machine lane ledger**
(`ops/lane-ledger.tsv`), never hand-written and never edited. The ledger is the source of truth:
`lane_id`, `state` (`ACTIVE` | `DONE` | `BLOCKED` | `RELEASED`), `owner`, `opened`, `updated`,
`expires`, `next`, `artifact`, `branch`. The claims board (`ops/LANE-CLAIMS.md`) is the human view
of the same thing and is **secondary**; where the two disagree, the ledger wins and the board says
so out loud in **DRIFT**.

```bash
# regenerate the list from machine state (this is what a lane does at the end of its cycle)
bin/fm-next-board.sh --repo <repo> --out <out> --ledger <ledger>
# print the canonical list, in the one vocabulary the fleet uses
python3 bin/build-next-board.py --repo <repo> --out <out> --todo-list
```

The board records the digest of the ledger it was built from:

```
**Ledger digest:** sha256:<64-hex>
```

so a third party can tell whether the board is still in step with the machine state, and
`next-board.json` carries the same value in `ledger_digest`.

**A stale list blocks closure.** `bin/fm-todo-gate.sh` refuses a board whose digest no longer
matches the ledger, and `bin/fm-lane-closure-gate.sh` runs that gate as a precondition of closure
for every lane whose artifact claims PASS/DONE/ACCEPTED. **A lane may not close while the to-do
list is stale** — closing on a stale list is how a lane lands with nobody holding the next step, and
that is the rot this contract exists to stop. A missing drift checker is a violation too, never a
silent pass.

**One source of truth.** The visible session list, the lane board and the claims board are
**projections of the generated list**, not a second source of truth. If they disagree with the
ledger, the ledger is right and the projection is stale. A human must never have to ask for the
list twice: it is regenerated from machine state on every lane cycle, and the gate says so when it
is not.

### 6a. A lane is not real until it is on the board, and the publisher owns that

**The rule.** The ledger is written by the **publisher**, at the moment a lane spawns. The renderer
never writes the ledger and never guesses: it is told what the machine truth is. So a lane that
has spawned and is running has a row, and the board that is generated from the ledger counts it.

**Why this rule exists.** On 2026-10-24 four lanes were dispatched and confirmed running — each
with its own `state/<id>.meta` and `state/<id>.status` — and `ops/lane-ledger.tsv` held **zero** rows
matching them. The board reported "no active lanes in the ledger" while four lanes were in flight.
The board was not wrong about the ledger; **the ledger was wrong about reality**, and the board
reported the ledger faithfully. That is still a board that lies to the Captain. The cause was that
nothing in the fleet wrote the ledger: every tool that named `ops/lane-ledger.tsv` only read it, so
the spawn of a lane — a machine-detectable event — never produced a row.

**Who publishes the ledger.** `bin/fm-lane-ledger-publish.py` owns `ops/lane-ledger.tsv` and
`ops/LANE-CLAIMS.md` in this home. It is the only writer of those two files here, so the ledger and
the claims board cannot drift apart behind the gate's back.

```bash
# the spawn event, named: write the row for a lane and republish the board
bin/fm-lane-ledger-publish.py register <lane-id> --repo <repo>
# the spawn event, observed: block until a lane spawns, then publish it at once
bin/fm-lane-ledger-publish.py watch --repo <repo>
# the catch-up: publish every live lane that has no row, then republish the board
bin/fm-lane-ledger-publish.py reconcile --repo <repo>
```

**The spawn event is the spawn record.** `bin/fm-spawn.sh` writes `state/<id>.meta` when the lane is
created and prints `spawned <id> ...` once the agent is verified alive. That meta **is** the spawn
record: it carries the lane's real identity (`endpoint_task_id`), its real spawn time, its harness
and its worktree. The publisher reads it and writes a row that carries the lane's **real** state
(`ACTIVE`), its real next action (the lane's last working note) and its real artifact path. A second
mate is a standing worker with its own home, never a lane: it is never published as a lane claim.

**The board publisher publishes the ledger first.** `bin/fm-board-refresh.sh` asks the publisher to
publish the ledger before it builds a board, so a board can no longer be built from a ledger that
under-reports the lanes that are running. If the ledger cannot be published, the refresh fails and
leaves the published board untouched — a stale board is still a refusal, and that refusal is correct.

**The publisher never deletes a row.** A row is a record of work that happened. The publisher adds
rows, refreshes the rows it inherited from the published ledger, and keeps the claims board's state
cell in step with the ledger. It never writes a lane's report, status or meta file, and it never
weakens or edits the to-do gate.

---

**VERDICT: PASS** — the NEXT contract is defined, the board generator is written and running
(`build-next-board.py`, which measures the current rot at 34/34 contract gaps and 41 artifacts
without a NEXT line), and the rule is now written down where the lanes that will inherit it can
read it. The board regenerates from live sources on every lane cycle. The to-do list on that board
is generated from the machine lane ledger and carries that ledger's digest; a lane claiming
PASS/DONE/ACCEPTED cannot close while the list is stale (`bin/fm-todo-gate.sh`, wired into
`bin/fm-lane-closure-gate.sh` as the third precondition of closure, proven by
`tests/fm-todo-gate.test.sh`); and the visible session list is a projection of the board, not a
second source of truth.
