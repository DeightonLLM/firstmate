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

---

**VERDICT: PASS** — the NEXT contract is defined, the board generator is written and running
(`build-next-board.py`, which measures the current rot at 34/34 contract gaps and 41 artifacts
without a NEXT line), and the rule is now written down where the lanes that will inherit it can
read it. The board regenerates from live sources on every lane cycle.
