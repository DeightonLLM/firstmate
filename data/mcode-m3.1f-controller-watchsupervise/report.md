# Report — continuous supervision for the minimax-code primary

Lane: `mcode-m3.1f-controller-watchsupervise`
Kind: ship (a change to shared tracked material in this repo)

## What changed

### `bin/fm-watch-supervise.sh` (new, executable)

The arm owner for a primary that has no native turn-end hook. It runs `bin/fm-watch-arm.sh`
in a loop, so the watcher stays alive across wakes, and it classifies every wake in bash
with the shared classifier so a routine wake costs no model turn at all.

Reason: on this primary the watcher had to be re-armed **by hand after every single wake**,
because the only mechanism that could keep it alive (a native turn-end hook, an extension
loader, an event push) does not exist for `mcode`. The measured cost was an 8-hour outage on
2026-10-21 with 59 captured Captain messages never handled. This script removes the model's
memory from the supervision loop.

The contract it implements:

- **Owns the cycle continuously.** `bin/fm-watch-arm.sh` runs in a loop. The script contains
  no shell `&` at all (proved mechanically by the test suite), so it can never leave a
  backgrounded child behind: the arm runs in this script's own foreground process tree, and a
  process-group teardown takes the arm and the watcher down together. This is the same shape
  `bin/fm-claude-stop-autoarm.sh` already relies on.
- **Self-handles routine wakes in bash.** Classification is delegated to `bin/fm-classify-lib.sh`
  — the same library `bin/fm-watch.sh` and `bin/fm-supervise-daemon.sh` source — so there is
  one captain-relevant definition, not a second copy that can drift. Routine = a signal whose
  crew is provably working, a transient stale, a pane the classifier proves is deliberately
  paused. A no-verb signal is absorbed **only** with positive provably-working evidence.
- **Escalates captain-relevant wakes.** `done`, `needs-decision`, `blocked`, `failed`, a
  terminal stale pane, an open decision, a persistent wedge, an approval gate, authenticated
  check output, and a heartbeat wake (which the watcher only surfaces when its fleet-scan found
  an unsurfaced captain-relevant status). The script prints `supervise: ESCALATION - ...` with
  the reason and exits 0, so the tracked background task completes and the primary is notified.
  Anything the classifier cannot confidently call routine is escalated (fail-safe).
- **Exits at a bounded park interval** with a compact summary (`supervise: PARKED after <N>s`
  plus `supervise: summary cycles=... routine=... escalated=... failures=...`). The bound is
  `FM_WATCH_SUPERVISE_PARK_SECS`, default 900s, 0 means no bound. The bound is enforced at
  **cycle boundaries**: a healthy blocked watcher is never interrupted, so a quiet fleet keeps
  one watcher alive instead of bouncing it every bound, and the park fires at the first
  boundary at or after it.
- **Fails loudly.** A watcher that cannot be kept alive is a non-zero exit with
  `supervise: FAILED - ...` and `supervise: supervision is DOWN`. It never exits 0 while
  supervision is down. The arm is retried within `FM_WATCH_SUPERVISE_ARM_ATTEMPTS` (default 3)
  before the failure is declared.
- **Safe to run twice.** A second invocation attaches to the live supervisor (it waits for the
  holder to end and then takes over the cycle) instead of fighting for the watcher, and
  `bin/fm-watch-arm.sh` itself attaches to a healthy watcher rather than starting a second one.
- **Prints its first status line as soon as the watcher is verified.** The arm's own
  `watcher: started ...` / `watcher: attached ...` line is relayed verbatim, live, while the
  cycle is still open.

The header documents what it does, what it never does, the meaning of every output line, the
exit-status table, and the environment knobs.

### `tests/fm-watch-supervise.test.sh` (new)

Hermetic suite: a temporary `FM_HOME` and `FM_STATE_OVERRIDE` per case, a stub arm
(`FM_WATCH_SUPERVISE_ARM`) and a stub crew-state reader (`FM_CREW_STATE_BIN`). The real
`bin/fm-watch-arm.sh` is never executed, so the live watcher, the live watch lock, the live
board and every real pane are untouched. 32 checks, all passing.

### `docs/supervision-protocols/minimax-code.md` (edited)

Names the **exact** tracked-background-task command (`exec bin/fm-watch-supervise.sh`), in the
same shape as `docs/supervision-protocols/grok.md`. States plainly that the re-arm step is no
longer the model's job, what the operator does for each of the script's three exits
(escalation, park, failure), how a wake is classified, and **why the supervision host itself
was not used** — `FM_SUPERVISION_ENGINES_VERIFIED='claude'` means no engine beyond Claude, and
`bin/fm-host-mirror.sh verified minimax-code` exits 1, so the attended host reports "no
verified dialog mirror for minimax-code". The next reader does not have to re-derive it.

### `docs/supervision-host.md` (edited, "Arm owners" table only)

The table gained a minimax-code row naming `bin/fm-watch-supervise.sh` as that primary's arm
owner, plus a short paragraph explaining that it is the one row that does not run on a home
that runs the host (because the host cannot be reached from that primary), and why.

## How it was verified

### 1. The suite (hermetic, stubbed arm)

```
$ bash tests/fm-watch-supervise.test.sh
ok   routine wakes: the supervisor ends on its own park bound with exit 0
ok   routine wakes: at least three consecutive routine wakes were absorbed (8)
ok   routine wakes: no escalation was produced
ok   the loop re-armed itself: the arm ran 8 times inside ONE supervisor run
ok   the arm's readiness line is relayed as soon as the watcher is verified
ok   the supervisor kept its state inside the temporary home (the live home was untouched)
ok   no supervisor artifact was written into the live home's state directory
ok   captain-relevant wake: the supervisor exits 0 after handing the wake back
ok   captain-relevant wake: an escalation was printed
ok   captain-relevant wake: the escalation names the wake
ok   captain-relevant wake: the loop stopped on the escalation (arm ran 2 times)
ok   captain-relevant wake: the routine wake before it was absorbed, not escalated
ok   park interval: the supervisor exits 0 when the park bound is reached
ok   park interval: the park exit is announced
ok   park interval: the park exit carries a compact summary
ok   park interval: the supervisor kept the cycle alive across the park window (arm ran 4 times)
ok   failed watcher: the supervisor exits non-zero (1)
ok   failed watcher: the failure is loud
ok   failed watcher: the failure says supervision is down
ok   failed watcher: the arm was retried within the attempt budget (arm ran 2 times)
ok   the script contains no shell '&' at all (no backgrounded child, least of all the watcher)
ok   the script never launches the watcher: only bin/fm-watch-arm.sh does
ok   the script owns the cycle through bin/fm-watch-arm.sh
ok   the script backgrounds no command
ok   readiness: the arm's readiness line reached the caller while the cycle was still open
ok   readiness: the supervisor was still inside the cycle when the bounded runner stopped it
ok   bash -n is clean
ok   shellcheck reports no errors
ok   the header documents 'WHAT IT DOES'
ok   the header documents 'WHAT IT NEVER DOES'
ok   the header documents 'OUTPUT LINES'
ok   the header documents 'EXIT STATUS'

ALL TESTS PASSED (32 checks)
```

Exit status 0. The six behaviours the lane was opened for are each proven by an executed
check: (1) a routine wake does not stop the loop and produces no escalation; (2) a
captain-relevant wake stops the loop and the escalation names it; (3) the bounded park
interval exits with a summary; (4) a watcher that cannot be kept alive exits non-zero with a
loud line; (5) the script never uses a shell `&` for the watcher; (6) the loop survives at
least three consecutive routine wakes inside one supervisor run, with the arm invoked 8 times
and no operator re-run.

### 2. The real arm and the real watcher (temporary home, real `bin/fm-watch-arm.sh`)

Captain-relevant wake, real arm, real watcher:

```
$ FM_HOME=$EXP/home FM_STATE_OVERRIDE=$EXP/home/state \
  timeout 100 ./bin/fm-watch-supervise.sh
watcher: started pid=2353926 (beacon fresh)
supervise: ESCALATION - a captain-relevant wake needs a handling turn now.
supervise: reason: signal: /tmp/fm-sup-int.AQfrii/home/state/alpha.status
supervise: detail: alpha.status: done: lane alpha shipped the fix
supervise: arm: watcher: started pid=2353926 (beacon fresh)
supervise: arm: signal: /tmp/fm-sup-int.AQfrii/home/state/alpha.status
supervise: supervision is handed back to the primary: re-arm with bin/fm-watch-supervise.sh
=== exit: 0 ===
```

Routine wake, real arm, real watcher, 45s park bound — the readiness line is delivered while
the cycle is still open (this is what exposed a real buffering bug, fixed below):

```
--- supervisor output at 8s (cycle still open) ---
watcher: started pid=2411845 (beacon fresh)
--- live watcher alive? ---
-rw-r--r-- 1 root root   0 .../home/state/.last-watcher-beat
lrwxrwxrwx 1 root root  59 .../home/state/.watch.lock -> .../home/state/.watch.lock.owner.OyaHjJ
```

The live home was untouched by every run: `ls ./state/.watch-supervise*` → "No such file or
directory", and the supervisor's own log and lock live under the temporary `FM_HOME`.

### 3. Safe to run twice (two supervisors, one home)

```
$ ./bin/fm-watch-supervise.sh &          # supervisor A
$ ./bin/fm-watch-supervise.sh            # supervisor B
--- B output ---
supervise: attached - supervisor pid=2467138 already owns the watcher cycle; waiting for it to end
watcher: started pid=2467908 (beacon fresh)
--- A output ---
watcher: started pid=2467200 (beacon fresh)
supervise: ESCALATION - a captain-relevant wake needs a handling turn now.
...
```

The second supervisor attached, waited for the first to end, and then took over the cycle
instead of racing it for the watcher.

### 4. Lint (per file — the whole-repo `bin/fm-lint.sh` was NOT run, as instructed)

```
$ bash -n bin/fm-watch-supervise.sh && bash -n tests/fm-watch-supervise.test.sh
bash -n bin OK
bash -n tests OK
$ shellcheck -S warning bin/fm-watch-supervise.sh tests/fm-watch-supervise.test.sh
shellcheck (warning) clean
$ shellcheck -S error bin/fm-watch-supervise.sh tests/fm-watch-supervise.test.sh
shellcheck (error) clean
```

### 5. Docs drift gate (the real closeout gate)

```
$ bin/fm-docs-drift-gate.sh
DOCS_DRIFT_GATE=PASS window_since=2026-10-21T20:51:55+01:00 docs_changed=1 drifted=0
```

## What remains open

1. **`bin/fm-watch-arm.sh` does not recognise the `gate:` wake verb — found, reported, NOT
   fixed.** The watcher can surface `gate: <window> harness=<h> blocked on an interactive
   approval gate awaiting the CAPTAIN`, but the arm's own detector
   (`watch_output_has_wake`) matches only `signal:|stale:|check:|heartbeat`, so a gate cycle
   closes with the misleading line `watcher: FAILED - cycle ended without an actionable
   reason`. The gate is not lost (the watcher enqueues it durably and the arm still exits
   non-zero), but it is mislabelled as a supervision failure, which would send an operator
   hunting for a broken watcher while the real problem is an approval dialog waiting for
   them. I did not patch the arm: it is shared material outside this lane's ownership, the
   same gap exists in other consumers (`bin/fm-claude-stop-autoarm.sh` uses the same
   four-verb regex), and a partial fix here would leave the others inconsistent. This lane
   handles it additively instead: `capture_reason` in the new script includes `gate:`, and a
   real gate reason wins over the arm's generic FAILED line. **The arm's owner should widen
   the verb set in all four places.**

2. **`bin/fm-doc-audience-check.sh` fails repo-wide, pre-existing.** It reports ~450 tracked
   markdown files as "unclassified", including `docs/supervision-host.md` and
   `docs/supervision-protocols/minimax-code.md`, which were already unclassified before this
   lane touched them (the inventory `docs/documentation-audiences.json` has no entry for
   either, and hundreds of untouched files are in the same list). The check is not referenced
   by `.github/workflows/ci.yml`. Not caused by this lane and not fixed here.

3. **The park bound is a cycle-boundary bound, not a wall-clock bound.** A healthy blocked
   watcher is never interrupted, so on a quiet fleet the tracked background task stays alive
   indefinitely instead of parking every 900s. That is deliberate — interrupting a healthy
   watcher to force a park would recreate the "supervision is down between the park and the
   next re-arm" window this lane exists to close — but it does mean the parked summary is only
   produced when wakes are actually flowing. This is stated in the script header and in the
   protocol doc.

4. **Signal delivery depends on the harness killing the process group.** The script contains
   no shell `&`, so the arm and the watcher are children of this script's own process tree. A
   group teardown (the normal way a tracked task is stopped) takes the whole tree down. A
   pid-only kill leaves the arm and the watcher running as orphans; the watcher keeps
   supervising and enqueues any wake durably, so no wake is lost, but the supervisor's own
   exit is not reported. Matching the arm's own lifecycle exactly would need a pid-carrying
   wrapper, which was judged more machinery than this lane should add.

5. **The lane was not pushed and `origin/main` was not touched**, as instructed. The commit
   is on the lane branch only.

6. **A defect I introduced and fixed during the lane, recorded here for honesty:** the first
   version probed for `grep --line-buffered` with `printf '' | grep --line-buffered -q ''`,
   which matches nothing over empty input and exits 1. The probe therefore always failed,
   the block-buffered `grep` path was selected, and the arm's readiness line sat in a stdio
   buffer until the cycle closed — which the real-arm integration run caught (it produced no
   output at all for 90 seconds). The probe now feeds grep a matching line, and the suite has
   a dedicated check ("readiness: the arm's readiness line reached the caller while the cycle
   was still open") that kills the supervisor mid-cycle, so a buffered line is lost and the
   check fails.

VERDICT: PASS
