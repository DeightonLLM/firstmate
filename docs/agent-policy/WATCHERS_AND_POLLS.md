# Watchers and polls: the definitive way we work

**Status:** canonical. This file is the single source of truth for background watchers,
polls and sync loops across the HD2Stack fleet. If any other doc, script or habit
contradicts it, this file wins and the other one is wrong.

**Owner:** `p1-leadlists` (HD2Stack firstmate)
**Applies to:** every host in the fleet — the Controller/Conable VPS (`vmi3238503`,
tailscale `100.71.95.76`), Hetz (`hd2admin@100.106.6.22`), and Elevate
(`root@100.69.211.43`).
**Reason it exists:** the knowledge gap kept recurring. Agents kept asking "should this
poll run, and who owns it?", and on 2026-10-23 a watcher pile-up on the Controller took
the host to **load average 340 on 6 cores** with 577 stuck processes. This document is
the answer, so nobody has to rediscover it.

---

## 1. The three questions, answered once

| Question | Answer |
|---|---|
| **Should a watcher run 24/7?** | Yes — **if** it is cheap, bounded and self-limiting. A watcher that is *not* bounded is a bug, not a watcher. |
| **Should it be stopped?** | Only if it cannot be made bounded. A watcher that has no measured purpose, or whose lock wait is unbounded, must be stopped. |
| **Who owns it?** | One named lane, recorded in `ops/lane-ledger.tsv`, with a `NEXT:` line and a `VERDICT:` line in its artifact. Not "the fleet". |

**The rule that settles the arguments:** a watcher that **cannot pile up** runs 24/7. A
watcher that **can** pile up does not run until it is fixed. Never both.

---

## 2. The three layers, and what each one is for

Do not mix these up. Most "which one do I use?" confusion is really this confusion.

### Layer 1 — the Lavish board poll (the Captain's feedback channel)

**What it is:** `lavish-axi poll <board.html>` — a long-poll that returns the Captain's
review feedback for the Captain's board. It is the ONLY way the Captain's browser
feedback reaches an agent.

**Where it lives:** the **Controller/Conable VPS only** (`vmi3238503`, port 4387). It
does **not** run on Hetz or Elevate. Hetz does not serve the board and must not poll it.

**How it must be run:** in a **harness-native tracked background job**, and re-armed when
it ends. The upstream `lavish-axi` documentation is explicit:

> "The no-timeout poll always writes an immediate stderr banner so it is visibly not
> hung... Stdout always stays reserved for the final response; **if the poll is
> interrupted or times out before feedback arrives, re-run it** because feedback remains
> queued until delivery."

So the poll has **no timeout by design** — it is *meant* to wait indefinitely for the
Captain. The 3600 s limit is our **harness's** limit on a background job, not Lavish's
limit on the poll. When the harness ends the job, **re-arm it**. That is not a failure;
that is the operating rhythm. Feedback is never lost — it stays queued until a poll
delivers it.

**Never:** run `lavish-axi poll` while another listener is already active for the same
file. One poll per board. Two polls on one file means feedback is consumed by whichever
listener wins, and the Captain's note may be delivered to the wrong agent.

**Never:** treat "the poll returned nothing" as "the Captain has no feedback". It means
the Captain has not sent feedback yet.

### Layer 2 — the comms sync (`hetz-comms-sync.sh`)

**What it is:** a two-way rsync between the Controller's comms directories and Hetz's,
plus an ingest pass that turns remote replies into receipts.

**Where it lives:** the Controller runs it **to** Hetz (the Controller owns Hetz comms
end-to-end, routed away from the Controller on 2026-10-17 — Hetz does not sync back to
us on its own schedule).

**How often:** every minute is fine **only** because the runs are now non-overlapping
(§4). Overlap is what caused the incident.

### Layer 3 — the fleet scheduler daemons (`fm-always-four.sh daemon`)

**What it is:** the always-four scheduler that keeps the 6+6 lanes alive on Hetz. One
daemon per half, each in its own tracked, non-visible terminal.

**What is NOT a layer 3 job:** reaping finished lanes. That is the **reaper**, and it is
still the Captain's word (§6).

---

## 3. Why the pile-up happened (2026-10-23, measured)

This is the worked example. Read it before writing a new watcher.

On the Controller (`vmi3238503`, 6 cores) at 01:40Z:

```
577   hetz-comms-sync.sh processes
419   fm-comms-ingest.sh scan processes
156   mktemp -d .../.lock.owner.XXXXXX
211   leaked .lock.owner.* directories
307   processes in D state (uninterruptible I/O)
load average 340   (on 6 cores)
```

Four defects compounded:

1. **The lock wait was unbounded.** `fm_lock_acquire_wait()` in `bin/fm-wake-lib.sh`
   looped `while ! fm_lock_try_acquire; do sleep 0.1; done` — forever. A cron tick that
   lost the race **parked permanently**, holding a process and a `sleep` child.
2. **Three callers contended for one lock.** The every-minute `hetz-comms-sync.sh` calls
   the scan **twice** (two different directories), and a separate `*/5` cron called the
   same scan a third time. Three callers, one lock, no timeout.
3. **The lock holder re-entered the scan it already held the lock for.** The holder
   spawned a fresh `fm-comms-ingest.sh scan` as its own child while holding the lock, so
   the lock was **never released** — every other caller then waited forever.
4. **Every retry leaked a `.lock.owner.XXXXXX` directory.** The lock-owner churn itself
   thrashed the filesystem metadata path, which is why 307 processes were stuck in
   **D state** — uninterruptible, unkillable-by-ordinary-means, and directly responsible
   for the load average of 340.

**The lesson, in one line:** *a watcher is only safe if losing a race is cheap.* Every
one of those four defects is a way of making losing a race expensive.

---

## 4. The rules (non-negotiable)

Every watcher, poll or sync loop in this fleet obeys all seven.

### R1 — Bounded waits. No unbounded locks.
No watcher may wait on a lock, socket or IO forever. Every wait has a timeout, and
timing out is a **normal, successful outcome** that exits non-zero with a clear
message. A wait that cannot time out is a defect.

### R2 — Never overlap a run with itself.
A watcher started while a previous run of the same watcher is still going must **exit
immediately**, not start a second copy. Use `flock -n <lockfile> <command>` in the cron
line. Two copies of the same watcher are never better than one.

### R3 — One caller per lock.
If two different cron entries or scripts contend for the same lock, that is a design
smell. Either they are the same job (merge them, one caller) or they need different
locks.

### R4 — The lock is released on every exit path.
Use a single idempotent `EXIT` trap that owns lock release, including on error paths. A
holder that can exit without releasing turns every other caller into a permanent waiter.

### R5 — No re-entrancy.
A process that holds a lock must not spawn a copy of itself that takes the same lock.
If the work is genuinely recursive, the recursion must happen **inside** the lock holder,
not by re-invoking the whole script.

### R6 — One poll per artifact, one owner per watcher.
Never two `lavish-axi poll` processes for the same file. The owning lane is named in
`ops/lane-ledger.tsv` and the watcher's artifact carries `NEXT:` and `VERDICT:` lines.

### R7 — Measure it, then decide.
A watcher's cost is measured, not guessed: process count, RSS, and the host's load
average, before and after. A watcher that cannot be measured cannot be justified.

---

## 5. The checklist for adding a watcher

Before any new watcher is written:

1. **What does it watch, and what would it do about it?** If the answer is "nothing",
   do not add it.
2. **Who owns it?** Name the lane. Record it in `ops/lane-ledger.tsv` with a `NEXT:`
   line. Unowned watchers get removed.
3. **Does it satisfy R1–R7?** In particular: name the timeout, and name the
   non-overlap mechanism (`flock -n` or equivalent).
4. **What does it cost?** State the expected process count, RSS and CPU. Measure it
   after the first day against those numbers.
5. **How does it stop?** A watcher you cannot stop is a trap. Say in its artifact how
   to stop it in one command.

---

## 6. Still the Captain's word

Two things are **not** decided here, and no agent may decide them:

- **The reaper.** Letting the fleet close a replaced or finished lane's pane
  automatically. Until the Captain says so, the reclaim is done **by hand**, in this
  order, and never more than needed: bundle the commits → tar the untracked files →
  verify both → `treehouse return`. A finished lane's slot is reclaimed; a lane that is
  `blocked` or `needs-decision` is **live work** and is never reclaimed.
- **Where a lane's decision hold may live** (worktree + harvest, or the half's state
  dir). A design call, still open.

---

## 7. Where this is enforced

| Where | What |
|---|---|
| `bin/fm-wake-lib.sh` | `fm_lock_acquire_wait` — the bounded wait (R1). |
| `bin/fm-comms-ingest.sh` | The scan's lock handling and the no-re-entrancy rule (R4, R5). |
| `bin/hetz-comms-sync.sh` (host: `/root/bin/`) | The non-overlap cron line (R2). |
| `ops/lane-ledger.tsv` | Who owns what (R6). |
| `docs/agent-policy/HERDR_BOUNDED_EXECUTION.md` | The general bounded-execution contract. |
| `bin/fm-brief.sh` + `bin/fm-baseline-lib.sh` | This file is in the **fresh-agent baseline manifest**, so every new agent is pointed at it before its first action. |

---

## 8. If you are reading this because something is already wrong

1. **Do not add another watcher.** Adding a watcher to a host that already has a
   pile-up makes it worse.
2. **Measure first:** `pgrep -fc <watcher>`, `ps -eo stat | grep -c '^D'`, `uptime`,
   `free -m`, `df -h /`.
3. **Reap, then fix.** Reap the stuck copies by explicit PID (`pkill -f` is banned),
   then fix the wait, the overlap and the re-entrancy. Reaping without fixing just
   refills.
4. **If you use `mavis-trash` for the leaked lock-owner directories, that is the
   sanctioned recoverable removal path** — never `rm -rf`.
5. **Report it on the board** with the measured numbers before and after. A watcher
   incident without numbers is an anecdote.

---

*Written 2026-10-23 after the measured pile-up on `vmi3238503` (load average 340,
577 stuck sync processes, 307 in D state). The upstream `lavish-axi` documentation was
consulted for the poll semantics: the poll has **no timeout by design**, feedback stays
queued until delivered, and a poll that is interrupted must simply be re-armed.*
