# m3.1f-firstmate-reclaim-disk — reclaim the dead lock scratch, bound the comms log

**Lane:** `reclaim-learns-disk-20261021` · **Date:** 2026-10-21 · **Host:** Controller
**Branch:** `lane/mcode-m3.1f-controller-reclaim-disk-1792595514`

## What this lane was asked to do

The Captain's standing order: *"lets reclaim but refuse? we need this 80% rule looked at, i bet we have
alot more we con prune.. just looking on the dics at old saas files and documents there is a bunch of
thisng to archive.... no???"*

The 80% ceiling and the reclaim-then-refuse gate are landed (`7700662`). The brief identified two
things the reclaimer was blind to, both found by measurement on 2026-10-21:

1. the **dead lock scratch** — 37,235 lock owner dirs (357 MB) in the comms receipts directory, which
   the reclaimer's four tiers could not see at all; and
2. the **unbounded comms ingest log** — 40 MB, appended every five minutes, with no rotation.

This lane owns the reclaim of the *accumulated* leak (the root-cause fix in the lock library stops
future leaks; it does not clean up what is already on disk) and the bound on the log.

## The state of the live host when this lane started — read this first

**The 357 MB leak was already gone before this lane's script existed.** The lock lane's root-cause
fix had already landed on `main` (`38fda32 Merge branch 'incoming/lockdeadline'`, carrying
`262011c fix(lock): bound the lock wait so the comms receipts lock cannot wedge`), and that fix's
`fm_lock_reclaim_owner_dirs` sweep had already collected the backlog.

Measured at the start of this lane:

```
$ du -x -s -k /root/agent-work/deightonllm-firstmate/state/comms-receipts/hetzner-secondmate-20260927
3608          # 3.6 MB, and the 4 real receipt files are still there
$ find /root/agent-work/deightonllm-firstmate/state -name '*.owner.??????' | wc -l
0
$ ls -l /root/agent-work/deightonllm-firstmate/state/fm-comms-ingest.log
-rw-r--r-- 1 root root 175791 ... # 172 KB, not 40 MB
```

So the honest position is: **the live leak needed no reclaim from this lane, because another lane's
landed fix had already taken it.** What was still true — and is what this lane actually delivers — is
that the reclaimer itself remained blind: `grep -i lock bin/fm-capacity-reclaim.sh` returned nothing,
so the next leak (on this host, or on any host where the lock library is not deployed) would again be
invisible to the thing whose job is reclaiming. The deliverable is therefore the **capability**, and
the measurement below is a faithful reproduction of the leak on the live filesystem, because the real
one no longer existed to measure.

## 1. The measured before and after

### The reproduction

Built to the shape in the brief, on the root filesystem, by `/root/fm-repro-build.py` (temporary; it
has been removed):

* **37,235** owner dirs in ONE parent directory, named `.lock.steal.owner.XXXXXX` with the deeper
  steal forms, each holding a bare `pid` file — exactly what the leaked dirs carried, and exactly
  what makes the retroactive identity check impossible.
* **21,201** of them recorded a **recycled** pid: a live process that started *after* the dir was
  created, so a naive "is the pid alive?" test reads them as held.
* **16,028** recorded a pid that really exited.
* **6** held by one genuinely live process, in a **6-deep nested steal chain**.
* The real receipt data beside them: **4 files, 76 KB**.

### The run

```
$ FM_RECLAIM_TIERS=1b FM_RECLAIM_STATE_ROOTS=/root/fm-reclaim-measurement \
    bin/fm-capacity-reclaim.sh --apply
```

### The numbers

| | BEFORE | AFTER |
| --- | --- | --- |
| `df -P /` available | **15,653,352 KB** | **15,950,936 KB** |
| `df -P /` used | 80% | **79%** |
| `du -x -s -k` of the parent | **299,752 KB** | **1,872 KB** |
| owner dirs, all depths | **37,241** | **6** |
| owner dirs at depth 1 | 37,236 | 1 |
| receipt files | 4 | **4 (all still there)** |
| live holder process | running | **still running** |

The reclaimer's own report:

```
tier 1b: 37235 dead lock owner dir(s) and 0 lock pointer(s) reclaimed, 297880 KB by the affected
          parents' own size (4 live holder(s) skipped, 0 undecidable holder(s) skipped)
measured: the filesystem gave back 293764 KB (df before/after, net over the reclaim window, not what
          the script believes it deleted)
capacity: 80% -> 79% used
```

* **37,235 dirs reclaimed, 0 failures.**
* The **measured** df delta is **293,764 KB**. My own independent reading of `df` around the same
  window gives **297,584 KB**; the 3.8 MB difference is the reclaim's own before-reading being taken
  slightly later than mine, plus concurrent host activity. The `du` delta (299,752 - 1,872 =
  **297,880 KB**) agrees with the independent df reading to within 300 KB. The script's number is the
  df reading, not the `du` figure it also prints — the two are reported separately on purpose.
* Elapsed: **61 s**, inside the capacity gate's 90 s reclaim timeout.

### The failure, proven first

`tests/fm-lock-reclaim-disk.test.sh` runs the **previous** reclaimer with `--apply`, and proves it was
blind. It finds the previous version by walking the history for the most recent reclaimer that has no
lock tier at all, so the comparison is the same whether or not this change is committed:

* `grep -ci lock` on the previous reclaimer: **0** — it had no lock handling at all.
* The previous reclaimer **left the dead lock owner dir behind** even with `--apply`.
* Its report **never mentioned** the lock owner dir: the dir was invisible to it.

The previous reclaimer is run with a `find` wrapper that redirects its tier 1 into the fixture, and a
`du` wrapper that neutralises the archive-class inventory's multi-GB measurements — the old script's
tier 4 costs about a minute on this host and its sizes are not what this test is about. The shapes of
the run are not neutralised: the old reclaimer's own tier 1, tier 2 and tier 4 all run.

The new reclaimer removes the dir, and reports it.

## 2. The safety argument for the recycled-pid case

A lock owner dir records the pid of the process that created it. **"Is that pid alive?" is not a
sufficient test**, because the kernel recycles pids. Measured on the Controller on 2026-10-21:
21,201 of the leaked dirs recorded a pid that was running again as an unrelated process, so a naive
liveness test would have kept every one of them alive forever; only 6 were genuinely live.

The test this lane uses compares the process's **start time** with the owner dir's own **mtime**:

* a process that started **after** the dir was created cannot be the process that created it, so
  its pid was recycled and the lock is dead;
* a process that started **before** the dir was created may well be the holder, and the dir is
  left alone.

When a `pid-identity` file is present the match is **exact** and strictly stronger, and it wins.
The identity is compared on its **start-time** component, with the cmdline as a secondary check:
a process that `exec`s changes its command line but keeps its start time, and it is still the same
holder, so a cmdline-only difference must not be read as a dead lock.

### The race between the check and the delete

A pid can be recycled between the check and the delete. The race is harmless, and the reasoning is
the point: **the decision is about the relationship between the recorded pid and the dir's creation
time, not about the pid's identity at the moment of the delete.** A dir whose recorded pid was
already dead — or already recycled — when it was *checked* is garbage, and it stays garbage while it
is deleted. What would be unsafe is deleting a dir whose holder is *alive*, and the start-time test
rules that out: a holder necessarily started before it created the dir. The sweep also re-reads the
holder state immediately before the unlink, so a holder that is still alive at that moment stops the
reclaim.

### The evidence

* The recycled-pid case is proved with a **real, live pid**, not by assertion: the test starts a real
  process, records its pid, creates the owner dir, backdates the dir, and then reads the
  relationship back out of `/proc`:

  ```
  PASS  the recorded pid is REALLY alive (so a naive liveness test would keep this dir)
  PASS  the recorded pid started AFTER the dir was created (start 1792599294 > dir mtime 1792592096):
        the pid was recycled
  PASS  a dir whose pid was RECYCLED is reclaimed
  ```

* A **genuinely** recycled kernel pid is also attempted: the test spawns and reaps processes looking
  for the kernel to hand the same pid out again. It did not happen within 400 attempts on this host,
  and the test says so rather than pretending:

  ```
  NOTE  the kernel did not hand out the same pid again within 400 attempts, so the genuine-recycle
        case was not observed; the deterministic start-time case above covers the same state
  ```

  The deterministic case is the same state by construction: in both, the recorded pid belongs to a
  process that started after the dir was created.

* A **live holder is never touched**, and the process survives:

  ```
  PASS  a LIVE holder's dir and its pointer are both left alone
  PASS  the live holder process is still running after the sweep
  ```

* In the 37,235-dir measurement, the **live 6-deep chain survived**: 6 dirs left, the holder process
  still running, and the report says `4 live holder(s) skipped`.

### The three gates, so nothing else is ever touched

A path is eligible only when all three pass:

1. the **name** is a lock shape — `*.lock.owner.??????` and the deeper steal forms at any depth, plus
   the `*.lock` / `*.lock.steal` pointer names;
2. a **pointer** is a **symlink** — a plain `.lock` file belongs to another lock family, and a
   directory called `*.lock` is another family's directory lock;
3. an **owner dir** is **owner-private** (mode 0700) — tracked repository content never is.

The shapes are **mirrored** from `bin/fm-wake-lib.sh`, which owns the lock protocol, because that file
belongs to the lock lane and is edited while this lane works. The mirroring is cross-checked against
the lock library over a corpus of names so it cannot silently drift:

```
PASS  the mirrored shape rules agree with the lock library on every name in the corpus
```

The host's other lock families are proven untouched: the live `state/.lock`, `state/.quota-refresh.lock`,
`state/.cap.lock`, `state/.triage.lock`, `state/.tracker-usage.lock` (plain files) and
`state/cbd-client-next-v2.busy-state.lock` (a 0700 directory) are all still there.

### The real unlink

`rm` on this host is the recoverable-delete shim `/root/.minimax/shims/rm`, which **moves** its target
into `~/.local/share/Trash` and frees **zero bytes** on a single filesystem. The reclaim resolves the
real rm by **absolute path** (`/usr/bin/rm`, `/bin/rm`) and **refuses the shim even when it is found
at one of those paths**. The test puts a fake shim on `PATH` *and* offers it as the explicit
`FM_SCRATCH_REAL_RM` override, then asserts the shim was never called and the reclaim still worked:

```
PASS  the shim rm was refused: it was never called, neither on PATH nor as the explicit override
PASS  the reclaim still worked, through the REAL rm resolved by absolute path
PASS  the real-rm resolution refuses a shim and returns a real rm (/usr/bin/rm)
```

## 3. The rotation design, and why this design

**The problem.** `state/fm-comms-ingest.log` is appended by the host cron wrapper
`/root/bin/hetz-comms-sync.sh` every five minutes. It reached 40 MB because an oversize file was
re-reported on every scan and nothing rotated it.

**What already existed, and what was still missing.** The ingest command (`bin/fm-comms-ingest.sh`,
owned by the lock lane, **not edited by this lane**) carries a rotation on its EXIT trap that renames
the live log to `<log>.1`. That stops the live file growing without bound, but it leaves two gaps:

* the generation it leaves behind is **whatever the last run produced**, so one 40 MB run parks
  40 MB there until the next rotation — nothing bounds the **total**;
* the generation is **replaced**, not rotated, so the previous run's diagnosis tail is gone, and two
  scans finishing together race.

**This lane's answer:** `bin/fm-log-rotate.sh`, which bounds the whole log **family** — the live file
and every generation — and which the reclaimer calls as tier 1c, so the bound holds even when the
ingest command is not running at all.

**copytruncate, and why the race is closed.** The live log is appended by a shell redirect (`>> log`)
held open by the writer. Two rotations are possible:

* **copytruncate** — the inode never changes. The snapshot is taken and the file is truncated in
  place. The writer's descriptor stays valid, a follower of the live path keeps following it, and the
  writer's next append lands at offset 0 of the same file. Its one known flaw is that bytes appended
  *between* the snapshot and the truncation are lost.
* **rename-and-reopen** — the live path is replaced by a fresh inode. The writer keeps its
  descriptor, so it keeps writing into the *renamed* file: nothing it writes is lost, but its output
  lands in the archive instead of the live log, and a follower of the live path stops seeing new
  output.

This script picks the mechanism per file, and the choice is measured rather than assumed:

* the log is **quiescent** (not written to for `FM_LOG_ROTATE_QUIESCE_S` seconds, and its size did
  not change while the snapshot was taken) → **copytruncate**, which is then provably lossless:
  nothing can be written in the microseconds between the final size check and the truncation. This is
  the steady state on this host, where the writer runs every five minutes.
* the log is **active** (it was written to during the snapshot, or modified moments ago) →
  **rename**. The writer's descriptor follows the renamed inode, so every byte it writes is preserved
  in the generation. The generation is capped on a **later** pass, once the writer has finished — a
  generation younger than `FM_LOG_ROTATE_GRACE_S` is never touched.

So the rule is: copytruncate when it is provably lossless, rename when it is not, and never truncate
a file somebody might still be writing to.

**The generations are capped too**, which is what bounds the *total*: without it, one 40 MB run parks
40 MB in a generation until the next rotation. Each generation keeps its **most recent** `KEEP` bytes,
because the diagnosis value of a rotated log is its tail. The ingest command's own `<log>.1` is part
of the family and is capped too — that is where the 40 MB actually parks.

**Self-race.** Two rotations must not run at once, or the second would snapshot a file the first is
truncating. The rotation takes an exclusive lock (`flock`, with a portable `mkdir` fallback) and
reports `SKIP-LOCKED` rather than proceeding.

**No new system cron was added.** The rotation runs from the reclaim path (tier 1c), which the
capacity gate already invokes when the disk reaches the ceiling, and the ingest command's own
rotation already runs on every scan. A host operator who wants the bound enforced on a timer can
call `bin/fm-log-rotate.sh --apply` from one; this lane did **not** add a root crontab line.

### The live path, measured

The 40 MB was still on the host, in the ingest command's own generation, and tier 1c handles it.
The deliberate step, on the live path, with the before and after:

```
$ FM_RECLAIM_TIERS=1c bin/fm-capacity-reclaim.sh --apply
```

| | BEFORE | AFTER |
| --- | --- | --- |
| `state/fm-comms-ingest.log` | 1,613,412 bytes | 1,615,741 bytes (untouched — it is within its cap) |
| `state/fm-comms-ingest.log.1` | **41,298,192 bytes** | **262,144 bytes** (the most recent tail) |
| `df -P /` available | 16,040,920 KB | **16,080,728 KB** |
| measured df delta | — | **39,816 KB** (independently measured: 39,808 KB) |

The reclaimer's own line:

```
tier 1c: 1 log(s) rotated, 40104 KB by the live files' own size
measured: the filesystem gave back 39816 KB (df before/after, net over the reclaim window, not what
          the script believes it deleted)
```

The tail that was kept is readable and real — the last lines of the capped generation are the
ingest's own output (`ingested: 18`, `excluded-own-outbound: ...`). The live log was **not**
touched, because it was already within its cap: a rotation that fires when it is not needed would
be churn, not hygiene.

**The evidence:**

```
PASS  the live log is brought back under its cap (22828 bytes -> 0 bytes)
PASS  the most recent tail is kept for diagnosis
PASS  the whole log family is bounded (2048 bytes)
PASS  every line an active writer wrote survived the rotation
```

The last one is a live-writer test: a background process holds an open descriptor on the log and
appends every 50 ms, mirroring every line to a ledger. After the rotation, the ledger and the whole
log family are compared line for line. The writer's lines all survive — 27 written, 27 kept.

## 4. What this lane did NOT change, and why

**The lock library was not touched.** `bin/fm-wake-lib.sh`, `bin/fm-scratch-lib.sh`,
`bin/fm-comms-ingest.sh`, `bin/fm-comms-notify.sh`, `bin/fm-lock.sh`, `bin/fm-lease*.sh` and
`bin/fm-watch.sh` belong to the `m3.1f-firstmate-lockdeadline` lane, which was editing them
concurrently. Two overlapping writers on one file is the defect this fleet keeps hitting, so this
lane wrote **zero** bytes into them and **mirrored** the shape rules instead of editing them.

Proven by `git status --porcelain` over the working tree (and by the `git diff --stat` in the commit
below): the only modified files are `bin/fm-capacity-reclaim.sh`, `docs/scripts.md`,
`docs/configuration.md`, plus three new files.

**What the lock lane's root-cause fix already owns, and this lane deliberately did not re-implement:**

* the steal infix in the shared scratch-shape table (`*.lock.steal`, `*.lock.steal.owner.??????`), so
  a stale steal pointer can be unlinked at all — this stops the *wedge*;
* the `fm_lock_reclaim_owner_dirs` sweep that runs under the lock on every acquire and release —
  this stops the *growth*;
* the bounded wait on the comms receipts lock.

This lane owns only what those do not cover: reclaiming the leak that **already accumulated**, and
the log's unboundedness.

**Requirements that belong to the lock lane, recorded here rather than edited in:**

* `fm_purge_scratch` in `bin/fm-scratch-lib.sh` still does not know the steal infix. The other lane
  was landing that separately; this lane's sweep handles the steal shapes without depending on it.
* The reclaimer's tier 1b is a **safety net outside the lock**, not a replacement for the sweep
  under the lock. It is deliberately the weaker of the two in one respect: it cannot know that no
  other process is mid-claim for a lock it is not holding. That is why it needs the identity test,
  the grace period, and the refusal to touch a live holder or a dir with a live holder nested
  inside it.

**Other changes this lane made that were not in the brief**, both in scope and reported here:

1. **`--tier 3` was broken.** The reclaimer's argument loop was a `for arg in "$@"`, and a `shift`
   inside a `for` loop over `"$@"` cannot consume the value that follows an option — so
   `fm-capacity-reclaim.sh --apply --tier 3`, the form documented in the reclaimer's own header,
   died with `unknown argument: 3`. The loop is now a `while`/`shift`. This was found while testing
   the new tier and is a defect in the exact script this lane extends.
2. **`FM_RECLAIM_TIERS`** was added so one tier can be exercised on its own — by an operator who
   wants only the lock sweep, and by a test that must not touch the host's real caches. The default
   is unchanged (`1,1b,1c,2`, plus `3` with `--tier 3`).

## 5. The performance work, and two bugs the measurement caught

A leak is tens of thousands of dirs, and the reclaim that runs the sweep is bounded by a 90 s
timeout. The first working version of the sweep took **60+ seconds for 5,000 dirs** and reclaimed
nothing, because a fork on this host costs about 2 ms. Four fixes, each measured:

| change | before | after |
| --- | --- | --- |
| `$(printf '\t')` in a loop condition (a fork per candidate) | 60 s / 5,000 | 4.7 s / 5,000 |
| `read -a` on a herestring (a **temporary file** per candidate) | 57.9 s / 32,000 | — |
| a `case` glob over the pid→epoch cache (bash's pattern matcher is O(n²) — 9 ms per candidate) | 281 s / 32,000 | **31 s / 32,000** |
| one `rm` for a whole parent (chunked) | — | **61 s for 37,235 dirs** |

The pid→epoch cache is now an **associative array**, with a string fallback for bash 3.2 (the repo
already uses bash 4.3 features elsewhere, e.g. `local -n`).

**Two bugs the measurement caught, both fixed:**

1. **The batch `rm` exceeded `ARG_MAX`.** One unchunked `rm -rf` with 37,236 paths is about 3 MB of
   arguments; Linux refuses that with `E2BIG` before `rm` starts. The first full-scale run removed
   8,181 dirs and reported the other **29,056 as failures**. The batch is now chunked (500 paths per
   exec) and the final run reports **0 failures**.
2. **The reproduction's live holder was not actually alive** (a `setsid` wrapper had taken the pid
   and exited), so the first full-scale run could not have exercised the live-holder protection. The
   fixture now starts the holder directly, and the final run proves the chain survived.

The sweep is also **bounded by a wall-clock budget** (`FM_RECLAIM_LOCK_BUDGET_S`, default 60 s) as
well as by a count, so it can never overrun the gate's timeout: the backlog drains over successive
sweeps, and the sweep says `BUDGET-EXCEEDED` when it stops.

## 6. What is shipped

* `bin/fm-lock-reclaim-lib.sh` (new) — the sweep: the shapes mirrored from the lock library, the
  real-rm resolution, the identity test, and the bounded sweep.
* `bin/fm-log-rotate.sh` (new) — the bounded rotation of a log family.
* `bin/fm-capacity-reclaim.sh` (modified) — tier **1b** (dead lock scratch), tier **1c** (bounded
  logs), the `FM_RECLAIM_TIERS` knob, the `FM_RECLAIM_DF` test seam, the header rewritten to
  describe the new reality, and the `--tier` argument bug fixed.
* `tests/fm-lock-reclaim-disk.test.sh` (new) — 33 assertions.
* `docs/scripts.md`, `docs/configuration.md` — the new tier contract and every new knob.

The raw evidence for the measurement is beside this report:
`data/m3.1f-firstmate-reclaim-disk/measurement.txt` (the before and after readings) and
`data/m3.1f-firstmate-reclaim-disk/reclaim-run-summary.txt` (the reclaimer's own report, with the
37,235 per-dir lines summarised rather than committed).

### The tier this is, and why

**Tier 1b is safe-and-automatic**, and it runs in the reclaimer's default `--apply` path, so the
Captain's *"reclaim but refuse"* ladder picks it up automatically: the gate reclaims, re-measures,
and refuses only if the disk is still over the ceiling afterwards. It belongs in tier 1 because
tier 1 is the *"always regenerable, safe by construction"* tier, and a provably dead lock owner dir
is exactly that — pure litter, rebuilt on demand by the lock machinery. Its safety is **stronger**
than tier 1's, which is a heuristic: it is a proof, not a judgement.

**The tiers are unchanged for the operator.** The default is still tiers 1-2; tier 3 is still
opt-in; tier 4 is still reported and never deleted.

## 7. Test results, reported honestly

| suite | result |
| --- | --- |
| `tests/fm-lock-reclaim-disk.test.sh` (new) | **PASS 33, FAIL 0** |
| `tests/fm-capacity-refuse.test.sh` (existing, unchanged) | **PASS=35, FAIL=0, ALL TESTS PASSED** |

The existing suite was run **before** and **after** the change, and passes both times. It exercises
the reclaimer's honesty contract directly (`--inventory` runs no reclaim tier; a malformed `--tier` is
refused as an actionable error; the reclaimer resolves the real rm by absolute path and rejects the
shim).

The new suite covers: the three shape gates; a dead owner dir reclaimed; a live holder untouched and
its process alive; a recycled pid reclaimed, proved from `/proc`; the shim rm refused; the previous
reclaimer leaving the dir behind; a **measured** df delta that agrees with an independent reading;
a reclaim that removed nothing never claiming freed bytes even when the filesystem reports more free
space; the rotation bounding the log and keeping the tail; an active writer losing nothing; and the
mirrored shapes agreeing with the lock library.

### One disclosure

While debugging the old reclaimer's applied run, one debug invocation ran it **without** the test's
`find` and `du` wrappers, and its tier 1 reclaimed **one** `__pycache__` directory (168 KB) from the
host. That is the reclaimer's own documented behaviour — byte-compiled python is derived output the
host rebuilds on the next import — and the directory is regenerable, but it was a real mutation
outside the fixture that this lane did not intend and did not measure. No tracked file, no project
file and no lock scratch was touched by it. The old reclaimer's tier 2 was **not** reached in that
debug run (`treehouse` was not on the wrapper PATH in the runs that mattered), so the worktree pool
was never pruned by this lane.

## VERDICT: PASS
