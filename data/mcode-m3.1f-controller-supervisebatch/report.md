# Supervisor: one model turn per meaningful peer update, not one per republication

Lane: `mcode-m3.1f-controller-supervisebatch`
Kind: ship (shared tracked material in this repo)

## What changed

### `bin/fm-watch-supervise.sh`

The supervisor now tells two kinds of peer receipt apart, and coalesces the one
that is a heartbeat.

**The distinction.** A peer that drops files into this home's comms inbox
produces one comms receipt per file, and every receipt enqueues its own signal
wake. Two different kinds of thing arrive from the same source:

- a **message addressed to the Controller** - a peer wrote to the Captain. It
  escalates immediately, every time, and never waits for a window.
- a **machine artefact** - a published board, a ledger, a status snapshot the
  peer republishes on a timer. It is on disk, the receipt is durable, and it
  changes on the peer's clock, not on the Captain's need, so the repeats inside
  the coalescing window are absorbed into the next escalation's summary.

**How the two are told apart.** From the receipt's own metadata, never from a
filename guess about what a message looks like:

- the **source** is the task id of the status file the wake names, and the fact
  that it has a comms receipt ledger under `state/comms-receipts/<id>/`;
- the **artefact name** is the name the pending wake record carries
  (`comms received from <id>: <name>`), and the **sha256** is the matching entry
  in that source's receipt ledger, which is the receipt's own durable metadata
  (`<sha256>\t<name>`, one line per received file, in receipt order).

The machine-artefact table is **closed**: `CAPTAIN-BOARD.html`, `NEXT-BOARD.md`,
`LANE-CLAIMS.md`, `lane-ledger.tsv` (a base name followed by a dot also
matches, so a publish-stamped backup copy such as
`CAPTAIN-BOARD.html.bak-publish-20261021T1948Z` is the same artefact). A name
that is not on the table is escalated, never absorbed. The table is
`FM_WATCH_SUPERVISE_MACHINE_ARTEFACTS` if a home needs a different one.

**New behaviour, function by function:**

- `is_machine_artefact <name>` - the closed-table test. A name it does not
  recognise returns 1 and is escalated.
- `peer_pending_names <source>` - reads the pending wake records for one source
  and prints their artefact names. **Read-only**: the queue is never drained,
  acknowledged or rewritten. The primary owns the queue.
- `peer_ledger_entries <source>` - reads the source's receipt ledger, the
  authority for the full sha256 of each receipt.
- `coalesce_load` / `coalesce_save` - the durable per-source coalescing state
  in `state/.watch-supervise-coalesce`:
  `<source> <seen> <anchor> <absorbed> <name> <sha>`.
  - `seen` is the ledger index just after the last receipt already accounted
    for. It is what stops the same pending receipt being counted twice when
    the loop runs another cycle.
  - `anchor` is the epoch of the last escalation of that source. **The window
    is anchored here, never at the last republication**, so a peer that keeps
    publishing still re-notifies the Captain once per window instead of being
    folded away forever.
  - `absorbed` is how many republications were absorbed and not yet reported.
    The next escalation reports and resets it.
  - `name`/`sha` is the latest machine artefact, so an escalation can name it
    even when the cycle carried only a message.
  The state survives the supervisor's own exit and re-arm, which is required:
  the supervisor hands the cycle back to the primary between one window and the
  next.
- `peer_receipt_decision <source>` - the decision for one source. It aligns the
  pending wake records against the receipt ledger's tail; **a disagreement
  between the two is escalated, never absorbed**, because the classification
  cannot then be trusted. It returns `escalate` or `absorb` and builds the
  summary lines.
- `peer_signal_decision <file-list> <state>` - decides a signal wake that
  carries peer receipts. The peer's own status line is still checked with the
  shared classifier: **the peer path decides HOW a receipt is surfaced, never
  WHETHER it is**, so a receipt whose summary happens to read "merged" still
  escalates. The non-peer files in the same wake are still classified normally
  and outrank any coalescing.
- `supervise_classify` now sets globals (`SUPERVISE_ACTION`,
  `SUPERVISE_DISTILLED`, `SUPERVISE_EXTRA`) instead of printing
  `<action>|<distilled>`, because it is no longer run in a command
  substitution: the peer path updates durable state and builds the escalation
  summary, and a subshell would throw both away. A new third action, `absorb`,
  means "a republished machine artefact, folded in, no model turn".
- `escalate_and_exit` prints `SUPERVISE_EXTRA`, so the hand-back always carries
  the coalescing summary.
- The main loop handles the `absorb` action: it counts the republication as
  routine, prints `supervise: republication absorbed (...)`, and re-arms. **No
  model turn is spent on it.**

**Nothing is dropped.** The escalation states the absorbed count, the source,
the latest artefact name and its sha256, and when the window resets:

```
supervise: peer: source=hetzner-secondmate-20260927 absorbed=10 latest=lane-ledger.tsv sha=a8768845... window-resets-at=1792619501 (2026-10-21T22:51:41+0100)
```

The absorbed items are still on disk, still in the durable receipt ledger, and
still recorded on the peer's status channel. The supervisor summarises them; it
does not consume them.

**New environment knobs:** `FM_WATCH_SUPERVISE_COALESCE_SECS` (default 600, 0
disables coalescing entirely) and `FM_WATCH_SUPERVISE_MACHINE_ARTEFACTS`.

**Header:** "WHAT IT DOES", "OUTPUT LINES", "ENVIRONMENT KNOBS" and the usage
text document the new behaviour, the new output lines and the new knobs.

### `tests/fm-watch-supervise.test.sh`

25 new checks (57 total, up from 32). The peer fixture writes exactly what a
peer drop produces - a receipt ledger line with the full sha256, a
`comms-received:` status line, and one pending wake record - and the stub arm
surfaces the peer status file as a signal. The stub crew verdict is
deliberately **not** provably working, so an escalation in the peer cases can
only come from the supervisor's own peer decision: if the peer path had not
handled the wake, the ordinary classifier would have escalated it and the
"absorbed" checks would fail.

New checks, by the brief's numbering:

| # | Requirement | Checks |
|---|---|---|
| 1 | A republished machine artefact escalates the first time | 2 |
| 2 | Further republications inside the window are absorbed; the escalation states the absorbed count, source, latest artefact and sha256 | 6 |
| 3 | The absorbed count resets after the window | 3 |
| 4 | A message to the Controller escalates immediately, inside the window, with republications absorbed before it | 4 |
| 5 | A message and a republication arriving together produce one escalation naming both | 2 |
| 6 | An unrecognised artefact kind escalates, never absorbed | 3 |
| 7 | The supervisor does not consume or mutate the wake queue | 2 |
| 8 | An absorbed republication is still on disk and in the ledger | 2 |

Plus the 32 existing checks, unchanged and still passing.

### `data/mcode-m3.1f-controller-supervisebatch/report.md`

This report.

## How it was verified

Every command below was actually run, and the output is pasted as produced.

### The full suite

```
$ timeout 600 bash tests/fm-watch-supervise.test.sh
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
ok   park interval: the supervisor kept the cycle alive across the park window (arm ran 5 times)
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
ok   peer republication: the first republished machine artefact escalates
ok   peer republication: the escalation names the source, the artefact and its sha256
ok   peer coalescing: the first republication establishes the window and escalates
ok   peer coalescing: republications inside the window are absorbed, not escalated
ok   peer coalescing: an absorbed republication produced no escalation
ok   peer coalescing: the absorbed count states how many republications were folded in
ok   peer coalescing: the republication after the window escalates again
ok   peer coalescing: the escalation states the absorbed count, the source, the latest artefact and its sha256
ok   peer coalescing: one republication inside the window is counted as absorbed
ok   peer coalescing: the escalation after the window reports the count that was folded in
ok   peer coalescing: the absorbed count resets after the window
ok   peer message: the window is established by the first republication
ok   peer message: a republication inside the window is absorbed before the message arrives
ok   peer message: a message to the Controller escalates immediately, inside the window
ok   peer message: the escalation names the message the peer sent
ok   peer message: the escalation still reports the republications that were absorbed before it
ok   peer message and republication together: exactly one escalation was produced
ok   peer message and republication together: the single escalation names both
ok   peer unrecognised artefact: the window is established by the first republication
ok   peer unrecognised artefact: an unrecognised artefact kind escalates inside the window
ok   peer unrecognised artefact: the unrecognised artefact kind was not absorbed
ok   peer wake queue: the supervisor did not mutate the wake queue
ok   peer wake queue: the pending records are still in the queue for the primary to drain
ok   peer nothing dropped: the absorbed republication is still in the durable receipt ledger
ok   peer nothing dropped: the absorbed republication is still recorded on the peer status channel
ok   bash -n is clean
ok   shellcheck reports no errors
ok   the header documents 'WHAT IT DOES'
ok   the header documents 'WHAT IT NEVER DOES'
ok   the header documents 'OUTPUT LINES'
ok   the header documents 'EXIT STATUS'
ALL TESTS PASSED (57 checks)
```

`total ok: 57  total FAIL: 0`, exit 0.

The suite was run three further times to check for flakiness in the
timing-dependent window cases:

```
run 1: exit=0 -> ALL TESTS PASSED (57 checks)
run 2: exit=0 -> ALL TESTS PASSED (57 checks)
run 3: exit=0 -> ALL TESTS PASSED (57 checks)
```

(One earlier run reported a shell parse error at line 769. That was my own
doing: I edited the test file while the background loop was reading it, so
bash read a half-written file. It does not reproduce - the three runs above,
and the final run above, were all clean.)

### Lint, per file

The whole-repo `bin/fm-lint.sh` was **not** run, as the brief requires.

```
$ bash -n bin/fm-watch-supervise.sh && shellcheck -x bin/fm-watch-supervise.sh
lint clean

$ bash -n tests/fm-watch-supervise.test.sh
```

ShellCheck 0.11.0, all severities, with `-x` for source following. The
supervisor script is clean at every level. For the test file, the diff against
the pre-change baseline is empty:

```
$ diff <(git show HEAD:tests/fm-watch-supervise.test.sh | shellcheck -x - 2>&1 | grep -oE 'SC[0-9]+' | sort -u) \
       <(shellcheck -x tests/fm-watch-supervise.test.sh 2>&1 | grep -oE 'SC[0-9]+' | sort -u)
no new shellcheck findings
```

The three pre-existing infos in the test file (`SC2329` on the trap-invoked
cleanup, `SC2012` on two `ls` calls) are baseline and were not introduced here.

The script's own `&`-free rule still holds:

```
$ sed -e 's/[[:space:]]*#.*$//' bin/fm-watch-supervise.sh | grep -v '^[[:space:]]*$' \
    | sed -E 's/&>>/>/g; s/[0-9]*>&[0-9-]//g; s/&&//g; s/&>//g' | grep -n '&' || echo "no bare & found"
no bare & found
```

### Against the real production receipts

The live home was never supervised. The real receipt data was copied into a
throwaway temporary home, the pending wake queue was rebuilt from the last
twelve real receipts, and the supervisor was run there with a stub arm and a
stub crew reader.

Twelve real pending receipts at once - ten machine artefacts and two code
drops:

```
supervise: ESCALATION - a captain-relevant wake needs a handling turn now.
supervise: reason: signal: /tmp/fm-sim.bWPCS5/state/hetzner-secondmate-20260927.status
supervise: detail: peer message from hetzner-secondmate-20260927: fm-credential-guard.test.sh
supervise: peer: source=hetzner-secondmate-20260927 message=fm-credential-guard.test.sh sha=13cceda85fb52dbec16b530a524a9c5499faf120c1c8ccb4bd5f5adba5455560
supervise: peer: source=hetzner-secondmate-20260927 message=fm-credential-guard.sh sha=69d57918d96d594cb654e0122b35fe4d82491a86a8a3a91c60b761e4ef9b6ec1
supervise: peer: source=hetzner-secondmate-20260927 absorbed=10 latest=lane-ledger.tsv sha=a8768845e5e4462319e89163c49187e2060aada40a078e700f13333ff85f0cee window-resets-at=1792619501 (2026-10-21T22:51:41+0100)
```

One escalation. The two artefacts that are not on the closed table (the
credential-guard scripts) escalate as messages; the ten board and ledger
republications are folded in and counted.

The steady-state republication cycle, which is the case the lane exists for -
the board republished on the peer's timer:

```
=== RUN A: next republication of the board (window still open) ===
supervise: republication absorbed (source=hetzner-secondmate-20260927 artefact=CAPTAIN-BOARD.html sha=d53aac4df47f319e728bca5e4309817cd88358450d9884fdcf2ae9a1c58d3027 absorbed=1 window-resets-at=1792619501) - re-arming

=== RUN B: one more republication, still inside the window ===
supervise: republication absorbed (source=hetzner-secondmate-20260927 artefact=CAPTAIN-BOARD.html sha=7f92c5a378b2f7ee6dbc3c5aa596a172798cbd499077ba9130fc3a28dd7678a8 absorbed=2 window-resets-at=1792619501) - re-arming
```

No escalation, no model turn, for either republication.

After the window expires, the next republication escalates and reports what
was folded in:

```
supervise: ESCALATION - a captain-relevant wake needs a handling turn now.
supervise: detail: peer machine artefact republished: CAPTAIN-BOARD.html
supervise: peer: source=hetzner-secondmate-20260927 absorbed=3 latest=CAPTAIN-BOARD.html sha=b737e1a824b46effc72ff8772d9a59910933d4ccd7a56368f3266b2fe7409600 window-resets-at=1792619002 (2026-10-21T22:43:22+0100)
```

The sha256 in that line is the digest of the artefact that was actually
dropped (`b737e1a8...`), checked by comparison against the computed digest.

And the wake queue is untouched by the supervisor:

```
queue sha before: b2545eb1346d58ad4e5f114e1a6b70e9cf98190a3e68d76e41e0a20fb866347c
queue sha after : b2545eb1346d58ad4e5f114e1a6b70e9cf98190a3e68d76e41e0a20fb866347c
records before=16 after=16
=> supervisor mutated the wake queue? NO
```

The durable coalescing state left behind in the temporary home:

```
hetzner-secondmate-20260927 | 578 | 1792618997 | 0 | CAPTAIN-BOARD.html | b737e1a824b46effc72ff8772d9a59910933d4ccd7a56368f3266b2fe7409600
```

(the fields are source, seen, anchor, absorbed, latest name, latest sha).

The simulation directory was removed afterwards. Nothing was written to the
live home, no systemd unit was touched, and the supervisor was never run
against the live home.

## The window you chose and why

**600 seconds (10 minutes), `FM_WATCH_SUPERVISE_COALESCE_SECS`.**

The measured cadence of the peer that produced the noise was roughly one
republication every three minutes (19 receipts in 60 minutes, of which 10 were
`CAPTAIN-BOARD.html` and 9 were `lane-ledger.tsv`). A 600-second window spans
about three republications at that cadence, so it absorbs the repeats while
still re-notifying the Captain roughly once per window while the peer is
active. A 300-second window would span only about one and a half
republications and would let a second republication through as its own
escalation, which is roughly the behaviour this lane exists to remove.

The brief asked for something in the region of 300-600 seconds; I took the top
of that region because the aim is one model turn per meaningful peer update,
and the smaller end of the range would still produce two escalations per peer
publish cycle at the measured cadence.

Two properties of the window are deliberate and worth stating plainly:

1. **The window is anchored at the last ESCALATION of that source, not at the
   last republication.** A sliding window anchored at the last republication
   would fold the peer away entirely while it kept publishing - the Captain
   would never learn the board had changed again. Anchoring at the escalation
   guarantees a re-notification once per window while the peer is active. The
   cost is a bounded worst case: the Captain can be up to one window late
   learning about a board change, which is acceptable because the board is on
   disk and the receipt is durable.
2. **0 disables coalescing entirely**, which restores the pre-coalescing
   behaviour exactly. A home that prefers to see every republication can set
   it without a code change.

## What remains open

- **The default machine-artefact table is a judgement about this fleet's
  published artefacts.** It holds `CAPTAIN-BOARD.html`, `NEXT-BOARD.md`,
  `LANE-CLAIMS.md` and `lane-ledger.tsv` - the board and ledger family the
  peer republishes. If a peer starts publishing a new machine artefact on a
  timer, that artefact escalates every time until the table is extended. That
  is the fail-safe direction, so it is the right default, but the table is
  worth revisiting once the peer set is stable.
- **`fm-credential-guard.sh` and `fm-credential-guard.test.sh` escalate on
  every republication.** They are code drops, not board publications, and a
  changed script is a real change worth surfacing. At the measured rate that
  is two escalations an hour rather than nineteen, so it is not worth
  classifying code drops as machine artefacts.
- **The supervisor cannot escalate on its own when the peer goes quiet.** The
  loop is driven by the arm, and the arm blocks until a wake arrives. If
  republications are absorbed and the peer then stops publishing, the
  absorbed count stays unreported until the next wake of any kind. The
  republications are not lost - they are in the ledger, on the status channel
  and in the wake queue for the primary to drain - but the *summary* of them
  waits for the next cycle. This is a property of the event-driven arm, not of
  this change, and closing it would need the supervisor to own a timer.
- **The coalescing state is a new file in `state/`.** It is a dotfile in the
  home's own state directory, alongside the existing `.watch-supervise.log`,
  and it is written only by the supervisor, which holds the supervisor lock.
  A home that scrubs unfamiliar dotfiles should be checked, though the
  supervisor rebuilds it from the receipt ledger on the next run if it is
  removed.
- **Not tested against the live home.** By instruction the supervisor was not
  run against the live home - the firstmate owns the live arm. The validation
  above used the real receipt data copied into a temporary home, so the
  behaviour against real artefacts is proven, but the first live arm of the
  changed script is untested.
- **`docs/supervision-protocols/minimax-code.md` was not updated.** It is out
  of this lane's scope, but the protocol doc now describes a supervisor whose
  behaviour has one more documented mode (coalesced republications). A
  follow-up doc lane would be worth it.
---

# Task 2 — the live-home isolation check

**Lane:** `mcode-m3.1f-controller-supervisebatch` (second required task, same
branch, on top of `e0a5c54`)
**Files changed:** `tests/fm-watch-supervise.test.sh` only.
`bin/fm-watch-supervise.sh` is **not** changed by this task.

## What changed

### The defect, confirmed

The first task's suite ended with a check that asserted the **absence** of any
supervisor artefact in the home it runs in:

```bash
live_state="$ROOT/state"
if [ -d "$live_state" ] && ls "$live_state"/.watch-supervise* >/dev/null 2>&1; then
  bad "the supervisor wrote an artifact into the live home's state directory"
```

`ROOT` is derived from the test file's own location, so `$ROOT/state` is
whichever home the suite is run from. The standing arm legitimately lives in
the production home and legitimately writes `.watch-supervise.log`,
`.watch-supervise.lock` and `.watch-supervise-output.*` into that home's
`state/`. So the check measured **whether production happened to be idle at the
moment the suite ran**, and it failed when production was doing its job.

Re-measured on this branch, with the old check still in place and two
legitimate artefacts present in the home's `state/`:

```
$ git show HEAD:tests/fm-watch-supervise.test.sh > tests/fm-watch-supervise.old-isolation.test.sh
$ ls state/.watch-supervise*
state/.watch-supervise.lock
state/.watch-supervise.log

$ timeout 900 bash tests/fm-watch-supervise.old-isolation.test.sh
exit=1
FAIL the supervisor wrote an artifact into the live home's state directory
       -rw-r--r-- 1 root root  5 Oct 21 23:34 /root/.treehouse/deightonllm-firstmate-46aafc/5/deightonllm-firstmate/state/.watch-supervise.lock
       -rw-r--r-- 1 root root 22 Oct 21 23:34 /root/.treehouse/deightonllm-firstmate-46aafc/5/deightonllm-firstmate/state/.watch-supervise.log
1 of 57 CHECK(S) FAILED
```

The temporary copy was deleted immediately afterwards; it was never committed.

### The fix

The check now measures **the suite's own behaviour** instead of the host's
mood.

**1. A "before" snapshot, taken before any case runs.** The snapshot lives
under the suite's own temp root (`$TMP`), never in the home it measures:

```bash
HOME_ARTEFACTS_BEFORE="$TMP/home-artefacts.before"
HOME_ARTEFACTS_AFTER="$TMP/home-artefacts.after"

snapshot_home_artefacts() {  # <out-file>
  local out=$1 f
  : > "$out" || return 1
  [ -d "$ROOT/state" ] || return 0
  (
    cd "$ROOT/state" 2>/dev/null || exit 0
    for f in .watch-supervise*; do
      [ -e "$f" ] || continue
      printf '%s\n' "$f"
    done
  ) | LC_ALL=C sort > "$out"
  return 0
}

snapshot_home_artefacts "$HOME_ARTEFACTS_BEFORE" \
  || fatal "could not snapshot the home's supervisor artefacts"
```

It is taken immediately after the temp root is created, **before the stub arms
are even built**, so it is genuinely before the suite's work and the
comparison is not vacuous.

**2. Names, not contents.** The snapshot is the sorted set of artefact
**names**. A live supervisor APPENDS to `.watch-supervise.log` while the suite
runs, so that file's contents, size and mtime all change for reasons that are
not pollution; a checksum or size comparison would fail on a busy host for no
reason. A pre-existing artefact is legitimate. Only a **new name** is
pollution.

**3. The comparison, at the end of the suite.** The check moved from the
middle of the suite (it sat inside the first case) to the end, so it compares
the whole suite's work, not one case:

```bash
snapshot_home_artefacts "$HOME_ARTEFACTS_AFTER"
added=$(awk 'FILENAME == ARGV[1] { seen[$0] = 1; next } !($0 in seen)' \
  "$HOME_ARTEFACTS_BEFORE" "$HOME_ARTEFACTS_AFTER")
if [ -z "$added" ]; then
  ok "the suite added no supervisor artefact to the home's state directory"
else
  added_count=$(printf '%s\n' "$added" | grep -c .)
  bad "the suite added $added_count supervisor artefact(s) to the home's state directory"
  printf '%s\n' "$added" | sed 's/^/       /'
fi
```

The wording no longer claims the home is artefact-free; it names what was
measured, and lists the offending names when it fails.

The check was **relocated, not deleted**: the count stays at 57, and the
relocated check is strictly stronger, because it now covers every case rather
than the first one. The `awk` uses `FILENAME == ARGV[1]` rather than the
`NR == FNR` idiom, because `NR == FNR` misfires when the first file is empty -
exactly the case that must pass.

### The timing margins, widened

While re-measuring, one run of the first task's suite failed `1 of 57` with a
message I could not attribute, and it did not reproduce in the runs that
followed. Rather than wave that away, I widened every timing bound in the
suite that could depend on host speed. **No assertion was changed, relaxed or
deleted** - only the test PARAMETERS that decide how long the suite waits:

| Bound | Was | Now | Why it is safe |
|---|---|---|---|
| The readiness case's bounded runner | `run_bounded 3` | `run_bounded 10` | The stub arm still holds the cycle open for 30s, so the cycle is still OPEN when the runner stops it; the assertion ("the readiness line reached the caller while the cycle was still open") is unchanged. |
| Case 1's park bound | 3s | 5s | A parameter, not an assertion: it only sets how many cycles the loop gets before the "at least three consecutive routine wakes" check. |
| Case 3's park bound | 2s | 3s | Same: a parameter, not an assertion. |
| The peer coalescing window | 5s | 20s | The window is anchored at the last escalation, so the next supervisor run has to land inside it. 5s was a thin margin on a busy host. |
| The window-expiry sleeps | `sleep 6` | `sleep 25` | Both are longer than the 20s window, so the expiry the test relies on is still real, not assumed. |

The suite now takes about 87 seconds instead of about 38. That is the cost of
a suite whose result does not depend on the machine being idle - which is the
point the firstmate made about the original check.

## How it was verified

### The three-way reproduction, re-measured on this branch

All three cases were re-measured in the **scratch worktree** (a throwaway
home). The production home was never used to run the suite.

| # | Situation | Artefacts in the home's `state/` | Before the fix | After the fix |
|---|---|---|---|---|
| 1 | Suite run in a clean home | none | `ALL TESTS PASSED (57 checks)` | `ALL TESTS PASSED (57 checks)` |
| 2 | Suite run in a home where the standing arm has run | `.watch-supervise.log`, `.watch-supervise.lock` | **FAIL** - `1 of 57 CHECK(S) FAILED` | `ALL TESTS PASSED (57 checks)` |
| 3 | The suite itself writes a new artefact into the home's `state/` | injected `.watch-supervise-canary` | (the old check could not see this case) | **FAIL** - `1 of 57 CHECK(S) FAILED`, exit 1, naming the canary |

Case 1:

```
$ ls state/.watch-supervise*
ls: cannot access 'state/.watch-supervise*': No such file or directory

$ timeout 900 bash tests/fm-watch-supervise.test.sh
exit=0
ok   the suite added no supervisor artefact to the home's state directory
ALL TESTS PASSED (57 checks)
```

Case 2:

```
$ printf 'standing arm log line\n' > state/.watch-supervise.log
$ printf 'lock\n' > state/.watch-supervise.lock
$ ls state/.watch-supervise*
state/.watch-supervise.lock
state/.watch-supervise.log

$ timeout 900 bash tests/fm-watch-supervise.test.sh
exit=0
ok   the suite added no supervisor artefact to the home's state directory
ALL TESTS PASSED (57 checks)
```

### The fault-injection proof

The injection was applied to the LAST peer case (case 8h), deliberately, so
that it also proves the relocated check covers the whole suite and not just
the first case. The injected block was:

```bash
# ===== TEMPORARY FAULT INJECTION (removed after the proof) =====
# Deliberately pollute the home the suite runs in, to prove the isolation
# check can still fail. It is injected in a LATE case on purpose: the check
# runs at the END of the suite, so it must catch pollution from any case.
mkdir -p "$ROOT/state"
printf 'fault injection canary\n' > "$ROOT/state/.watch-supervise-canary"
```

applied with a python one-liner that splices it after the last peer case, and
removed afterwards by restoring the file from a backup copy. The run:

```
$ cp tests/fm-watch-supervise.test.sh /tmp/test-backup.sh
$ python3 /tmp/apply-injection.py
fault injection applied in case 8h

$ bash -n tests/fm-watch-supervise.test.sh
bash -n: OK

$ timeout 900 bash tests/fm-watch-supervise.test.sh
exit=1
FAIL the suite added 1 supervisor artefact(s) to the home's state directory
       .watch-supervise-canary
1 of 57 CHECK(S) FAILED
```

The check **can still fail**, it names the offending artefact, and the suite
exits non-zero. The injection was then removed and the file verified
byte-identical to its pre-injection state:

```
$ cp /tmp/test-backup.sh tests/fm-watch-supervise.test.sh
$ rm -f state/.watch-supervise-canary
$ cmp /tmp/test-backup.sh tests/fm-watch-supervise.test.sh && echo "IDENTICAL (cmp clean)"
IDENTICAL (cmp clean)

$ grep -n 'canary\|FAULT INJECTION' tests/fm-watch-supervise.test.sh || echo "none"
none
```

### The suite is now stable on a home that has artefacts

Five consecutive runs with the pre-existing artefacts in place, which is the
live-host condition:

```
seq 1: exit=0 | ALL TESTS PASSED (57 checks)
seq 2: exit=0 | ALL TESTS PASSED (57 checks)
seq 3: exit=0 | ALL TESTS PASSED (57 checks)
seq 4: exit=0 | ALL TESTS PASSED (57 checks)
seq 5: exit=0 | ALL TESTS PASSED (57 checks)
```

Four runs in parallel, to put the host under load:

```
par 1: exit=0 | ALL TESTS PASSED (57 checks)
par 2: exit=0 | ALL TESTS PASSED (57 checks)
par 3: exit=0 | ALL TESTS PASSED (57 checks)
par 4: exit=0 | ALL TESTS PASSED (57 checks)
```

### Lint, per file

The whole-repo `bin/fm-lint.sh` was **not** run.

```
$ bash -n tests/fm-watch-supervise.test.sh
bash -n: clean

$ diff <(git show HEAD:tests/fm-watch-supervise.test.sh | shellcheck -x - 2>&1 | grep -oE 'SC[0-9]+' | sort -u) \
       <(shellcheck -x tests/fm-watch-supervise.test.sh 2>&1 | grep -oE 'SC[0-9]+' | sort -u)
no new shellcheck findings
```

The remaining findings in that file (`SC2012` on two `ls` calls, `SC2329` on
the trap-invoked cleanup) are baseline and predate this lane.

### The production home was not touched

```
$ ls -la /root/agent-work/firstmate/state/.watch-supervise-coalesce
ls: cannot access '/root/agent-work/firstmate/state/.watch-supervise-coalesce': No such file or directory

$ grep -c 'peer-a\|stub\|case-' /root/agent-work/firstmate/state/.watch-supervise.log
0
```

The production supervisor writes `.watch-supervise-coalesce` into its own
home on every peer decision. That file does **not** exist in the production
home, so no test run ever supervised it. The production log contains no entry
from any test run. The production home was never used to run the suite, no
systemd unit was touched, and the standing arm was left alone.

### A live confirmation of the problem this lane fixes

While working, the production home's **own live** supervisor log (written by
the unfixed script on `main`) recorded the exact defect, on its own, without
any help from me:

```
[2026-10-21T23:01:40+0100] escalate: signal: /root/agent-work/deightonllm-firstmate/state/hetzner-secondmate-20260927.status -> hetzner-secondmate-20260927.status: comms-received: hetzner-secondmate-20260927 CAPTAIN-BOARD.html sha=eb3e136b3db0 bytes=268813 | untrusted-reply-text: <!doctype html>
[2026-10-21T23:14:39+0100] escalate: signal: /root/agent-work/deightonllm-firstmate/state/hetzner-secondmate-20260927.status -> hetzner-secondmate-20260927.status: comms-received: hetzner-secondmate-20260927 lane-ledger.tsv sha=afe3fcc3ad2e bytes=33399 | untrusted-reply-text: # lane-ledger.tsv - the machine truth for "what is happening right now".
```

Two escalations, thirteen minutes apart, for a republished board and a
republished ledger - one model turn each, for machine artefacts. That is the
behaviour the first task's coalescing removes, and it is still live on `main`
because this branch has not been landed.

## What remains open

- **The same defective check is still on `main`.** It is at
  `tests/fm-watch-supervise.test.sh` lines 229-236 in the 32-check version.
  This fix lands for both when the firstmate lands this branch, but until then
  `main` still fails that check whenever the standing arm is running.
- **The suite is now slower** - about 87 seconds against about 38. That is the
  price of the timing margins, and it is deliberate: a suite that passes only
  when the machine is idle is not a suite anyone can trust.
- **The relocation of the check is a judgement call.** The brief did not
  specify where the check lives. It sat inside the first case, where an
  "after" snapshot would have covered only that case; it now runs at the end,
  covering the whole suite. The check count is unchanged at 57 and no
  assertion was weakened, but the firstmate should know the check moved.
- **The first task's report claimed "four consecutive clean runs".** That
  claim was true but measured on an idle host, which is exactly the
  condition that hides this class of defect. The suite now passes on a home
  with artefacts, under parallel load, and the fault injection proves the
  check can still fail.
- **The production home's live supervisor is still running the unfixed
  script**, and is still escalating every board republication. This branch
  fixes that only once it is landed.

VERDICT: PASS
