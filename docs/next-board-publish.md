# The live fleet board — how it is published and how it is kept honest

**Why (Captain, 2026-10-21):** *"I want to see those tokens showing up on the to-do tracker
also."* The tracker the Captain opens showed a static preview, and the NEXT board — the
signpost the repo already owns — was never regenerated. This is the last mile that connects
the two.

---

## 1. What the Captain opens, and where the live board is

| Surface | URL | What it is |
|---|---|---|
| Fleet ticket dashboard | `http://100.117.47.27:8477/` | the vendored Lavish board UI (read-only artifact) |
| **Fleet live board** | `http://100.117.47.27:8477/next-board/` | **the live board** — your ticket queue, the NEXT signpost, and the delivery state |

The dashboard page carries a small, fixed-position link — **LIVE FLEET BOARD →** — in its
bottom-left corner. One click, no instructions.

That link is injected at serve time by `bin/fm-tracker-view-serve.py`, which is
`python3 -m http.server` plus one thing. The dashboard artifact
(`data/tracker-build-20261017/tracker/candidate-preview.html`) is a self-contained HTML file
with **no `<a>` tags at all**, and it is read-only, so a link cannot be written into it. The
serving layer is the only honest place for one. The file on disk is never modified; if the
injection cannot be performed the original bytes are served unchanged.

**Rollback** (if the dashboard ever misbehaves):

```bash
rm /etc/systemd/system/tracker-view-serve.service.d/20-live-board-link.conf
systemctl daemon-reload && systemctl restart tracker-view-serve
```

---

## 2. The publish path

```
fm-next-board-publish.timer  (every 10 minutes, Persistent=true)
        │
        ▼
fm-next-board-publish.service  (oneshot)
        │
        ├─ 1. /root/bin/ticket-intake --root <repo>
        │       ingests anything new in INBOX/ into the queue board
        ├─ 2. merge the queue into data/tracker/tickets.jsonl
        │       (new tickets get a row; a lane's annotations are never overwritten)
        ├─ 3. bin/build-next-board.py  →  NEXT-BOARD.md + next-board.json
        │       (the existing builder owns the rules; nothing is re-derived)
        ├─ 4. measure the delivery state (listener, last delivery, pending)
        ├─ 5. render one self-contained HTML board
        └─ 6. publish atomically into data/next-board-publish/
                └─ served at /next-board/ through the symlink in /root/tracker-view
```

A measured publish takes **0.78 seconds** — a 0.13% duty cycle at a 10-minute cadence.

### Why 10 minutes

The board is regenerated at the end of every lane cycle, and a lane cycle is minutes long.
Ten minutes is therefore the shortest interval that is not busy-work: the board is never
more than one lane cycle behind the fleet. Fifteen minutes is equally defensible; ten was
chosen because the cost is negligible and it halves the worst case the Captain can see.

---

## 3. Where the Captain's tickets come from

The queue's real source is **`data/campaign-dashboard-20261015/board.md`** — the board file
`/root/bin/ticket-intake` reads and writes. The board reads that file directly on every
publish. It is **not** transcribed into a second list that could drift from the first.

The tracker snapshot `data/tracker/tickets.jsonl` is refreshed from the same queue on every
publish. A ticket already tracked keeps every field a lane wrote about it; a ticket new to
the tracker gets a row whose next action is the ticket's own description and **no owner** —
so the board reports it as a `CONTRACT-GAP` (nobody holds it) rather than pretending it is
handled.

---

## 4. What the delivery-state block says

The board states, from the durable record and never by guesswork:

- whether the long-poll listener is **alive** (the `fm-procevent` runner and the
  `lavish-axi poll` process are both checked by PID);
- when the **last delivery** happened, and whether that result has been handled;
- how many captured results are **still unhandled**;
- the **watcher heartbeat age**, because a stale watcher is why a listener can die unnoticed;
- the plain-language truth: a message sent while the agent is busy is **queued, not lost** —
  it is delivered on the next poll — together with the one documented limit (the poll
  destructively clears feedback when it returns it, so the narrow handoff window between
  that clear and the runner's durable capture is the single place a message can be lost).

If any of that cannot be read, the board says **unknown** rather than guessing.

---

## 5. What the disk-capacity card says

The board carries the **live root-disk verdict**, because the Captain's ceiling was enforced
but invisible: the dispatch gate refused a placement above it, and the board showed nothing
at all that said where the host stood.

The card names three things, so the Captain can act on it without reading code:

- the **root-disk percent**, measured with `df -P /` at publish time;
- the **verdict token** — `CAPACITY_OK`, `CAPACITY_EARLY_WARNING`, `CAPACITY_REVIEW_REQUIRED`
  or `CAPACITY_BLOCK_NEW_PLACEMENT`;
- **what that verdict means for dispatch** — `admit`, or `reclaim-then-refuse`.

The verdict is **asked for, not derived**. `bin/fm-capacity-gate.sh` is the one owner of the
capacity ladder; the publisher measures the percent and then calls that owner's `verdict`
subcommand, the same way `bin/controller-resource-audit.sh` already delegates to it. The board
holds no threshold of its own, and it never parses the host's prose audit file for a verdict.

If the disk or the owner cannot be read, the card says so and names the reason. It never prints
a verdict it did not receive, and it never prints a zero for a disk it could not measure — the
dispatch gate refuses a placement when it cannot measure the disk either, so an unreadable disk
is not a safe disk.

---

## 6. The regression check

```bash
python3 tests/test-next-board-publish.py --repo /root/agent-work/deightonllm-firstmate
```

Non-interactive, exits 0 or 1, safe to run repeatedly, and it only reads. It fails when the
board is missing or stale, when a queue ticket is absent from the board, when the delivery
block is missing or disagrees with the listener state measured at that moment, when the NEXT
contract is broken, when the board is not served over HTTP, when the dashboard page does
not carry the one-click link, or when the disk-capacity card is missing, or shows a verdict
that the publish record does not carry.

---

## 7. After a change to the tracked source

The systemd units run the copies in the runtime directory, so re-install after editing
anything in `bin/`:

```bash
bash bin/fm-next-board-install.sh --repo /root/agent-work/deightonllm-firstmate
systemctl start fm-next-board-publish.service
```

---

VERDICT: PASS — the tracker now reaches a live board that carries the Captain's ticket
queue, the NEXT signpost and the truthful delivery state, rebuilt every 10 minutes by a
timer that survives a reboot, with a regression check that fails when any of it goes stale.
NEXT: keep the board's content truthful — a lane that adds a ticket to INBOX/ gets it on
the board within 10 minutes | owner: every lane | by: every lane close
