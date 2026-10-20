# Transcript store value-free sweep — lane report

**Lane:** `transcript-sweep-20261020` · **Queue row:** `transcript-store-valuefree-sweep-20261020`
**Decision record:** `data/decision-records/20261020-captain-decision-pass.md` §11
**Date:** 2026-10-20 → 2026-10-21
**Branch:** `/root/bin` → `fm/scan-transcript-sweep-20261020` (commit `9ea092f`), not pushed, not merged
**Host:** Controller

---

## 0. Bottom line

The compensating control the Captain's decision depends on **now exists, is
scheduled, has run under systemd, and is provably value-free.**

| | |
| --- | --- |
| Implementation | `/root/bin/transcript-sweep` (new) |
| Regression test | `/root/bin/transcript-sweep.test.sh` (new) — passes |
| Doc | `/root/bin/docs/transcript-sweep.md` (new) |
| Scheduling | `/etc/systemd/system/transcript-sweep.{service,timer}` (new) — enabled, daily 04:23, `Persistent=true` |
| Cost of one full sweep | **~90–126 s wall clock, 187 MB peak RSS** — affordable daily |
| Coverage | 18 registered store roots, 66,457 files, 540 files with matches, 6,358 findings |
| Value-free | Mechanically proven by the test, by the runtime guards, and independently by re-scanning every produced artifact with the scanner's own strong pattern (0 matches) |

---

## 1. Pre-state

### 1.1 Store registry summary (paths and counts only — no values)

`/root/bin/agent-session-stores.conf` is the runtime-loaded, config-owned
registry the scanner already reads. The sweep **reuses** it; it does not
maintain a second list.

| | |
| --- | --- |
| Registry entries in `agent-session-stores.conf` | 18 |
| Built-in scanner defaults (used when the registry is missing/empty) | 4 |
| Total entries the scanner's loader resolves | 22 (the 4 defaults are repeated verbatim in the registry) |
| **Distinct store roots** | **18** |
| Store roots present on this host | 16 of 18 |
| Store roots absent on this host | `.pi-m3/agent/sessions`, `.gemini/antigravity-cli/**/logs` (a glob, not a directory) |
| Total store data on disk | ~5.2 GB across ~66,400 files |

The resolved store roots, with the file and finding counts the sweep measured:

| Store root | Status | Files | Findings |
| --- | --- | --- | --- |
| `.senpi/agent/sessions` | present | 2 | 0 |
| `.pi-m3/agent/sessions` | absent | 0 | 0 |
| `.gemini/antigravity-cli/brain` | present | 19,250 | 2,696 |
| `.gemini/antigravity-cli/**/logs` | absent (glob) | 0 | 0 |
| `.minimax/v2/sessions` | present | 1,217 | 286 |
| `.minimax/sessions` | present | 14 | 0 |
| `.minimax/background-tasks` | present | 17,756 | 108 |
| `.pi/agent/sessions` | present | 2,801 | 686 |
| `.codex/sessions` | present | 155 | 2,545 |
| `.omp/agent/sessions` | present | 18 | 0 |
| `.claude/sessions` | present | 1 | 0 |
| `.gemini/antigravity-cli/conversations` | present | 500 | 0 |
| `.gemini/antigravity-ide/brain` | present | 1,263 | 37 |
| `.gemini/antigravity-ide/conversations` | present | 120 | 0 |
| `.zcode/cli/rollout` | present | 3 | 0 |
| `.zcode/cli/artifacts` | present | 32 | 0 |
| `.config/lean-ctx/sessions` | present | 3,739 | 0 |
| `.config/lean-ctx/value/sessions` | present | 344 | 0 |

The four built-in defaults (`.senpi/agent/sessions`, `.pi-m3/agent/sessions`,
`.gemini/antigravity-cli/brain`, `.gemini/antigravity-cli/**/logs`) appear
twice in the resolved list because the scanner's loader appends the registry
to the defaults rather than replacing them. The sweep inherits that exactly.

### 1.2 Scanner exit code before this change

**The brief's premise was already false at pre-state.** The brief said
"`check /root` exits 0, 166 accepted paths". Measured at 2026-10-20 23:44:

```
$ /root/bin/agent-secret-scan check /root
FAILED: new possible secret material found in 1 file(s); paths only:
/root/ops/bin/fm-todo-sync.sh
exit 1
```

- Exit code: **1**, not 0.
- Total matched paths: 167 → **166 accepted** by baseline/manifest (matching
  the brief's figure) + 1 new.
- The one new path is in another lane's file, last modified 23:44 today.

See §7 for the full deviation treatment.

### 1.3 Pre-state corroboration of the coverage gap

The prior triage's numbers were re-confirmed as the design premise rather
than re-litigated: the stores hold multi-hundred-megabyte transcripts
(`.codex/sessions` alone is 1.7 GB across 155 files, with individual
rollouts of 492 MB and 389 MB), and the path-based scan's effective coverage
of that set is near zero because `/root/.gitignore` hides it.

---

## 2. Files created

| Path | Description |
| --- | --- |
| `/root/bin/transcript-sweep` | The sweep. Executable, no extension — the same shape as `agent-secret-scan` next to it. Reads the registered stores, writes a value-free report. |
| `/root/bin/transcript-sweep.test.sh` | The regression test. Hermetic (all fixtures in a temp dir). Proves the value-free property mechanically, the class taxonomy, the scanner/sweep store-set agreement, the fail-closed registry behaviour, and the timer cadence check. |
| `/root/bin/docs/transcript-sweep.md` | The doc. Matches the existing `/root/bin/docs/` layout (`agent-secret-scan.md`, `agent-secret-scan-session-stores.md`, `agent-secret-scan-repo-copies.md`). |
| `/etc/systemd/system/transcript-sweep.service` | `Type=oneshot`, bounded `TimeoutStartSec=1800`, `ProtectSystem=strict` + `ReadWritePaths=` on the report dir only, `PrivateTmp`, `NoNewPrivileges`. |
| `/etc/systemd/system/transcript-sweep.timer` | `OnCalendar=*-*-* 04:23:00`, `AccuracySec=5min`, `Persistent=true`, no repeating interval that could shorten the cadence. |
| `/root/agent-work/transcript-sweep/` | The report directory: `latest.md`, `findings.tsv`, `events.log`. |
| `/root/bin/transcript-sweep` (branch) | Committed on `fm/scan-transcript-sweep-20261020` in the `/root/bin` repo, commit `9ea092f`. |

### 2.1 Design notes

- **The store set is the scanner's, by construction.** The sweep extracts the
  session-store loader out of `agent-secret-scan` itself (from
  `DEFAULT_SESSION_STORES=(` through the standalone `load_session_stores`
  call) and runs that slice in a throwaway shell. The scanner is never
  modified and never imported as code beyond that slice. The extracted result
  is then cross-checked against an **independent re-implementation** of the
  registry grammar; a disagreement is a hard failure, not a warning.
- **The credential-class indicator is the scanner's, by construction.** The
  sweep reads `DIRECTORY_CREDENTIAL_PATTERN` out of the scanner source at run
  time, splits it into its ten alternatives, and matches each alternative
  separately over the files that matched. The class of a finding is therefore
  *the alternative that actually matched*, never a guess from a value's shape.
- **Class names are descriptive, never provider constants.** A class token is
  metadata about a class, and a class token that happened to be the prefix of
  every value in that class would put credential material into every report.
  `sk-ant` is the prefix of every Anthropic key; `anthropic_token` is not a
  prefix of anything. The same rule is why the two GitHub classes are
  `classic_pat_token` and `fine_pat_token` rather than `ghp_` and
  `github_pat_`. (This was caught by the test, not by inspection: the first
  draft used `github_fine_token` and the test reported that a 6-character
  prefix of the fixture value had reached the report.)
- **Memory is bounded by streaming.** The stores contain 492 MB transcripts
  with 3.8 MB single lines, and the first implementation accumulated match
  lines and read whole files for the PEM-completeness check, peaking at
  4.9 GB. The shipped version streams matches, keeps only a bounded 4 KB
  window before each match, and answers the PEM question with ripgrep instead
  of reading the file.

---

## 3. The value-free proof

### 3.1 What the sweep emits

One row per finding. The value is never among the fields:

```
class	length	distinct	placeholder	vendor_doc	shared_body	identifier	path	line	bucket	seen_before
anthropic_token	32	19	false	false	false	unbound	/root/.minimax/.../messages.jsonl	1	real-looking-credential	false
```

The strong metadata allowed: credential class, length of the
credential-bearing portion, distinct-character count, placeholder boolean,
vendor-documentation-example boolean, shared-cross-provider-body boolean,
the identifier name the value is bound to, the file path and the line.

### 3.2 The regression test's own output

```
$ bash /root/bin/transcript-sweep.test.sh
PASS: value-free (no value, prefix, suffix or hash in any artifact),
      class taxonomy complete, scanner and sweep agree on the store set,
      malformed registry fails closed, timer cadence check accepts daily and
      refuses drift
exit 0
```

### 3.3 The mechanical proof, itemised

The test feeds a known fake credential through the sweep and then searches
**every produced artifact** for the value and its derivatives.

```
PROBE VALUE      : sk-ant-…al0001   (len 32)
PROBE SHA256     : 1e1ee746e11d80f3…

latest.md                    literal=0 sha256=0 prefixes>=6=0 suffixes>=4=0
findings.tsv                 literal=0 sha256=0 prefixes>=6=0 suffixes>=4=0
events.log                   literal=0 sha256=0 prefixes>=6=0 suffixes>=4=0
stdout.txt                   literal=0 sha256=0 prefixes>=6=0 suffixes>=4=0
```

and the row that *does* carry the metadata:

```
class	length	distinct	placeholder	vendor_doc	shared_body	identifier	path	line	bucket	seen_before
anthropic_token	32	19	false	false	false	unbound	/tmp/.../m.jsonl	1	real-looking-credential	false
```

The class token is **not** a prefix of the value — the taxonomy holds.

The test asserts this for **ten** fixture credentials, one per credential
class, and additionally asserts that no provider constant (`sk-`, `sk-ant-`,
`ghp_`, `github_pat_`, `AIza`, `AKIA`, `xoxb-`, `-----BEGIN`) appears in the
report at all.

**Threshold, stated precisely.** The runtime guard checks the whole value and
its 12-character head and tail. The test additionally checks every prefix of
6 characters or more and every suffix of 4 characters or more. The 12
character runtime threshold is deliberate: a production credential's 6
characters can be ordinary English (a value beginning `example…` would
false-positive against the report prose), so a stricter runtime threshold
would block legitimate reports. The 6-character test threshold is safe
because the fixtures are synthetic and distinctive, and it is what proves the
class vocabulary itself never embeds provider material.

### 3.4 Two runtime guards, independent of the test

1. **Per-row guard** — every emitted row is asserted at write time to
   contain neither its own value nor a 12-character head or tail of it. A
   violation aborts before anything is written.
2. **Whole-report guard** — after the report text is assembled and before it
   is published, the finished text is re-read and checked against every
   discovered value. A hit aborts the run and the report is not written.

```
FAILED: value-free guard tripped: a credential fragment reached the report
(class anthropic_token, /root/....jsonl:41). The report was NOT published.
```

### 3.5 Independent verification on the real artifacts

The produced artifacts were re-scanned with the **scanner's own strong
pattern** — a check that does not depend on the sweep's code at all:

| Artifact | Strong-pattern matches | 64-hex-string matches |
| --- | --- | --- |
| `/root/agent-work/transcript-sweep/latest.md` | **0** | 0 |
| `/root/agent-work/transcript-sweep/findings.tsv` | **0** | 11 |
| `/root/agent-work/transcript-sweep/events.log` | **0** | 0 |
| `journalctl -u transcript-sweep.service` (the unit's whole journal) | **0** | — |

The 11 hex strings in `findings.tsv` were located and confirmed to be
**tool-output filenames inside the path column**, not hashes of values:

```
class: named_credential_assignment
path : /root/.minimax/v2/sessions/2026/09/27/14-32-27-439-session_.../reports/tool-outputs/02dc2564495f...c651089fff42a151f0db4b6bbff.txt
line : 239
```

The unit's journal, in full, contains no credential material:

```
Starting transcript-sweep.service - Value-free credential sweep across the agent transcript stores...
SWEEP_OK: stores=22 findings=6358 new=6358 files=66457 matched_files=540 runtime_s=88.80 rss_kib=76964 report=/root/agent-work/transcript-sweep/latest.md
transcript-sweep.service: Deactivated successfully.
Finished transcript-sweep.service - Value-free credential sweep across the agent transcript stores.
```

---

## 4. Scheduling evidence

### 4.1 Unit files

`/etc/systemd/system/transcript-sweep.timer`:

```ini
[Timer]
OnCalendar=*-*-* 04:23:00
AccuracySec=5min
Persistent=true
Unit=transcript-sweep.service

[Install]
WantedBy=timers.target
```

`/etc/systemd/system/transcript-sweep.service`:

```ini
[Service]
Type=oneshot
ExecStart=/root/bin/transcript-sweep --report-dir /root/agent-work/transcript-sweep
TimeoutStartSec=1800
ProtectSystem=strict
ProtectHome=no
ReadWritePaths=/root/agent-work/transcript-sweep
PrivateTmp=true
NoNewPrivileges=true
SuccessExitStatus=0
StandardOutput=journal
StandardError=journal
SyslogIdentifier=transcript-sweep
```

`ProtectSystem=strict` makes the whole filesystem read-only except the report
directory, so **the sweep physically cannot write to a transcript store**
even by mistake. `TimeoutStartSec=1800` bounds the run. A completed sweep
exits 0 whether or not it found anything, so the unit does not fail on a
clean run; a non-zero exit means the sweep could not complete, and that is
deliberately visible as a failed unit.

`systemd-analyze verify` reports no problem with either unit beyond the
expected "not installed yet" for the ExecStart path, which is now resolved.

### 4.2 Timer enabled and scheduled

```
$ systemctl enable --now transcript-sweep.timer
Created symlink /etc/systemd/system/timers.target.wants/transcript-sweep.timer → /etc/systemd/system/transcript-sweep.timer.

$ systemctl list-timers --all | grep transcript
Wed 2026-10-21 04:23:00 BST     3h 49min -                                       - transcript-sweep.timer            transcript-sweep.service

$ systemctl is-enabled transcript-sweep.timer
enabled
$ systemctl is-active transcript-sweep.timer
active

$ systemctl show transcript-sweep.timer -p TimersCalendar -p Persistent
TimersCalendar={ OnCalendar=*-*-* 04:23:00 ; next_elapse=Wed 2026-10-21 04:23:00 BST }
Persistent=yes
```

The sweep's own timer-unit checker agrees:

```
$ /root/bin/transcript-sweep --check-timer-unit /etc/systemd/system/transcript-sweep.timer
CADENCE_OK: /etc/systemd/system/transcript-sweep.timer declares OnCalendar=*-*-* 04:23:00 with Persistent=true
```

### 4.3 One manual run under systemd

```
$ systemctl start transcript-sweep.service
$ echo $?
0

$ systemctl show transcript-sweep.service -p Result -p ExecMainStatus -p ActiveState
Result=success
ExecMainStatus=0
ActiveState=inactive
```

Report produced by that run:

```
-rw-r--r-- 1 root root    243 Oct 21 00:32 events.log
-rw-r--r-- 1 root root 1293627 Oct 21 00:32 findings.tsv
-rw-r--r-- 1 root root  109418 Oct 21 00:32 latest.md
```

Run ledger (`/root/agent-work/transcript-sweep/events.log`):

```
2026-10-20T23:27:46Z	findings=6358	new=6358	files=66422	stores=22	runtime_s=126.17	rss_kib=76360	verdict=FINDINGS_PRESENT
2026-10-20T23:31:04Z	findings=6358	new=6358	files=66457	stores=22	runtime_s=88.80	rss_kib=76964	verdict=FINDINGS_PRESENT
```

No reboot, halt or poweroff was performed.

---

## 5. The agreement table — scanner vs sweep

### 5.1 Resolved store sets

The sweep resolves its store set by **running the scanner's own loader**, so
the two lists are the same list by construction, not by agreement. The
sweep additionally cross-checks the result against an independent
re-implementation of the registry grammar and aborts on any difference.

| | Scanner | Sweep |
| --- | --- | --- |
| Registry file | `agent-session-stores.conf` (next to the scanner) | **the same file**, resolved through the same precedence |
| Registry loader | `load_session_stores` in `agent-secret-scan` | **the extracted scanner loader, executed as-is** |
| Resolution precedence | `$AGENT_SECRET_SESSION_STORES` → sibling → on-PATH | identical, replicated |
| Fail-closed default | built-in defaults (4) when the registry is missing/empty | identical — the same defaults come out of the same slice |
| Malformed entry | hard failure, exit 2 | hard failure, exit 2 (tested) |
| Independent cross-check | — | own re-implementation of the grammar; mismatch = hard failure |
| Entries resolved | 22 (18 distinct roots) | **22 (18 distinct roots) — identical** |
| Scan root | `/root` | `/root` (the registry stores roots relative to it) |

### 5.2 Behavioural proof, on a fixture

`transcript-sweep.test.sh` proves the agreement behaviourally rather than by
asserting two lists match:

| Probe | Scanner | Sweep | Verdict |
| --- | --- | --- | --- |
| Credential-shaped file **inside** a registered store | **not reported** | **reported** | agree: the store is out of the scanner's scope and in the sweep's scope |
| Credential-shaped file **outside** every registered store | reported | not reported | agree: the sweep does not widen scope |
| Malformed registry entry | exit 2 | exit 2 | agree: both fail closed |

### 5.3 Behavioural proof, on this host (read-only)

Six files the sweep found, checked against the scanner's own `list` output
over `/root` — no file was written to any store:

```
AGREE: scanner blind to /root/.codex/sessions/2026/09/21/rollout-2026-09-21T03-31-39-...jsonl  (sweep found class=named_credential_assignment line=7)
AGREE: scanner blind to /root/.codex/sessions/2026/09/21/rollout-2026-09-21T19-29-56-...jsonl  (sweep found class=named_credential_assignment line=7)
... (6 sampled)

control: scanner sees /root/.checkpoints/pi-auth-pre-transplant-20260930.json   (outside the stores)
```

The scanner matched 168 paths across `/root`; **none** of them is inside a
registered store, and **all 540** files the sweep matched are.

---

## 6. The cost table

| Run | Runtime | Peak RSS (sweep process) | Peak RSS (incl. ripgrep) | Files in scope | Findings |
| --- | --- | --- | --- | --- | --- |
| Direct, `/usr/bin/time -v` | 126.17 s (2 min 07 s wall) | 76,360 KiB (74.6 MB) | 191,488 KiB (187 MB) | 66,422 | 6,358 |
| Under systemd | 88.80 s (2 min 43 s CPU) | 76,964 KiB (75.2 MB) | — | 66,457 | 6,358 |

Store data swept: **~5.2 GB**. Effective throughput: ~40–60 MB/s of store
data, dominated by the 492 MB and 389 MB single-rollout files in
`.codex/sessions` and the 2.0 GB `.gemini/antigravity-cli` tree.

**Verdict on affordability: a daily sweep is cheap.** ~2 minutes once a day
at 04:23, under 190 MB of resident memory, with a 30-minute service timeout
that is never approached. For comparison, the path-based secret scan of the
whole of `/root` takes ~26 s and is also already scheduled.

For reference, the first implementation of the same sweep peaked at
**4.89 GB** and took 241 s. The difference is entirely the streaming
rewrite and the ripgrep-based PEM check (§2.1). The shipped version is
within an order of magnitude of the memory the largest single transcript
file requires.

---

## 7. Deviations, unverified items, and deliberate non-changes

### 7.1 The scanner's exit code was not 0 — and was not 0 before this lane started

**This is the one acceptance item that is not literally met, and it could
not be met within this lane's scope.**

| | Pre-state (23:44) | Post-change (00:35) |
| --- | --- | --- |
| `agent-secret-scan check /root` exit code | **1** | **1** |
| New paths | 1 | 2 |
| Accepted paths | 166 | 166 |

The new paths are:

- `/root/ops/bin/fm-todo-sync.sh` — mtime 23:44, before this lane started.
  A `kv_assign`-class match (a credential-named assignment), identified by
  class only, never by value.
- `/root/agent-work/deightonllm-firstmate/bin/fm-whoosh-fixture.sh` — mtime
  00:03, created by **another lane** during this lane's work, also a
  `kv_assign`-class match.

Neither is mine, and **neither of my files is a scanner finding**:

```
$ /root/bin/agent-secret-scan list /root | grep transcript-sweep
(no output)
```

The invariant the acceptance item protects — *this lane did not alter the
scanner's verdict* — is met, and provably so: the scanner's output before
and after this lane is identical apart from the file another lane created in
between.

The literal "exits 0" cannot be made true here. Making it true would
require either modifying `agent-secret-scan` or adding a row to
`/root/.agent-secret-false-positive-manifest.tsv` for another lane's
fixture — and **both are explicitly forbidden by this lane's brief**
("Do NOT modify `/root/bin/agent-secret-scan` itself, its detection patterns,
or the false-positive manifest"). I did neither, deliberately.

**Action for the Captain / firstmate:** the scanner is red for two other
lanes' files. That is a separate decision, and it belongs to whoever owns
those files.

### 7.2 Deliberately not changed

- **`/root/bin/agent-secret-scan`** — not modified. Not one byte. Its
  detection patterns, its broad `PATTERN`, its strong
  `DIRECTORY_CREDENTIAL_PATTERN`, its false-positive manifest handling and
  its baseline semantics are all untouched. The sweep *reads* the scanner
  and *runs its own loader*; it never edits it.
- **`/root/bin/agent-session-stores.conf`** — not modified. Reused.
- **`/root/.agent-secret-baseline` and
  `/root/.agent-secret-false-positive-manifest.tsv`** — not modified.
- **Every credential store** — read only. The sweep never writes to a store,
  never rotates anything, never creates a credential. Under systemd this is
  enforced by the sandbox (`ProtectSystem=strict`), not merely by intent.
- **`/etc/systemd/system/tracker-view-serve.service` and
  `lane-dash-serve.service.d/`** — another lane owns those; not created,
  not edited.
- **The host** — no reboot, halt or poweroff. No container, service or
  deployment touched. The only systemd change is the new
  `transcript-sweep.service` / `.timer` pair plus `daemon-reload` and
  `enable --now` on the new timer.

### 7.3 Known gaps in the control, stated plainly

1. **No live-store overlap signal.** The prior triage found the live
   credentials by checking whether a transcript value *also* appears in a
   live credential holder. The sweep deliberately does **not** read live
   credential stores, so it cannot escalate that way. Shape, length, entropy,
   placeholder markers and shared-body structure narrow a finding but cannot
   settle whether it is a live key or a documentation sample; that residue is
   bucketed `needs-live-check` (1,560 of the 6,358 findings). This is the
   single most valuable thing to add next, and it needs its own authority
   decision, because it means reading live secret holders. **I did not add
   it unilaterally.**
2. **Binary files are skipped.** ripgrep does not search a file it detects as
   binary. The path-based scanner has the same limitation, so the two agree,
   but a credential inside a binary store file would be missed by both.
3. **The `seen_before` key is positional** — class, length, distinct count,
   identifier, path and line. A credential that moves to a different line
   looks new. It is a triage convenience, not an audit trail.
4. **The entropy thresholds behind the `bucket` column are a documented
   heuristic** chosen for this sweep; the prior triage's own formula was not
   published. The raw signals are all in the report, so any bucket can be
   re-derived.
5. **`seen_before` needs two runs to be meaningful.** The first run against
   a fresh report directory reports everything as new (6,358) and says so
   explicitly in the report (`- baseline: initialised`). From the second run
   on, the column is meaningful.

### 7.4 Items I could not verify

- **The timer firing unattended.** I proved the timer is enabled, scheduled
  for 2026-10-21 04:23, `Persistent=yes`, and that the service runs
  successfully under systemd when started manually. I did **not** wait for
  the timer to fire on its own, and I did not reboot the host to prove the
  `Persistent=true` catch-up path. The catch-up behaviour is systemd's, and
  the unit follows the same pattern as
  `controller-resource-audit.timer`, which is already in production.
- **The sweep's behaviour against a store larger than this host's.** The
  streaming design is bounded by construction, and the largest single
  transcript on this host (492 MB, 3.8 MB max line) is handled, but I have
  no observation of a materially larger store.
- **Behaviour under a concurrent write to a store.** The sweep reads live
  transcript directories that agents are actively writing to. Every run
  completed cleanly, and a torn read would surface as a parse miss rather
  than a wrong value, but I did not construct a torn-read test.

---

## 8. The commit

`/root/bin` repository, branch `fm/scan-transcript-sweep-20261020`, based on
`master` at `6f6a599`:

```
9ea092f scan: add value-free transcript-store sweep as the compensating control
6f6a599 scan: register the lint-baseline repo copy root
```

Exactly three files were staged and committed — no blanket staging, no
`git commit -a`, no `--force`:

```
$ git diff --cached --name-status
A	docs/transcript-sweep.md
A	transcript-sweep
A	transcript-sweep.test.sh
```

The branch is a clean fast-forward onto `master` and was created in a
dedicated worktree at `/root/.treehouse/bin-transcript-sweep/bin`, so the
live `/root/bin` working tree — which carries 171 entries of other lanes'
unlanded work — was never touched beyond installing the three runtime files
(`/root/bin/transcript-sweep`, `/root/bin/transcript-sweep.test.sh`,
`/root/bin/docs/transcript-sweep.md`), which the systemd unit's `ExecStart`
requires.

**Not pushed. No PR opened. Not merged.** Firstmate merges.

---

## 9. Acceptance checklist

| # | Acceptance item | Result | Evidence |
| --- | --- | --- | --- |
| 1 | The sweep runs to completion, exit 0, and writes its report | **MET** | §4.3, §6 — exit 0, three artifacts written |
| 2 | The value-free test passes: the known fake value appears nowhere in the output, the report, the journal, or any file the sweep wrote | **MET** | §3.2, §3.3, §3.5 — ten fixture credentials, literal/sha256/prefix/suffix all zero; the real artifacts and the unit's journal re-scanned with the scanner's own strong pattern: 0 matches |
| 3 | The sweep and the scanner agree about the store list; the store set each resolves is recorded | **MET** | §5 — identical by construction, plus a behavioural proof on a fixture and on this host |
| 4 | The scanner still exits 0 after the change | **NOT LITERALLY MET — pre-existing, unchanged by this lane, out of scope to fix** | §7.1 — exit 1 before and after, for two other lanes' files; my files are not findings; making it 0 would require a forbidden change to the scanner or its manifest |
| 5 | The timer is enabled and `systemctl list-timers` shows it scheduled | **MET** | §4.2 — enabled, active, next elapse 2026-10-21 04:23, `Persistent=yes` |
| 6 | The service actually runs under systemd once and produced its report | **MET** | §4.3 — `Result=success`, `ExecMainStatus=0`, three artifacts written by that run |
| 7 | The sweep's own cost is measured and reported; a full sweep is affordable daily | **MET** | §6 — 88–126 s, 187 MB peak RSS over 5.2 GB |
| 8 | Value-free, with mechanical proof | **MET** | §3 — per-row guard, whole-report guard, and a test that proves it |
| 9 | Nothing outside the write boundary changed | **MET** | §7.2 — the scanner, the registry, the baseline, the manifest, the stores and the other lane's units are all untouched |
| 10 | No credential value in any artifact, commit, status line or fixture | **MET** | §3.5 — the scanner's own strong pattern finds 0 matches in every produced artifact and in the unit's journal |

---

## 10. One thing worth the Captain's attention

The control is built, and it is finding what it was built to find. In the
stores the path-based scan cannot see, it found **6,358 findings across 540
files**, of which **2,236 are bucketed `real-looking-credential`** and 1,560
are `needs-live-check` — the bucket the prior triage used for exactly the
material it could not settle value-free.

The largest single contributors are `.gemini/antigravity-cli/brain` (2,696)
and `.codex/sessions` (2,545). Both are stores the path-based scan has
**never** been able to see.

That is the compensating control doing its job. The next question is not
whether the sweep works — it does — but what should happen to a
`real-looking-credential` finding when it is not in a live store. The
sweep deliberately does not answer that question on its own, because
answering it requires reading live credential holders, which is a
different authority than this lane was given.

---

VERDICT: PASS
