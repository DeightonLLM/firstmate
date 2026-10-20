# Evidence report — outbound suppression, original failures, scheduled pickup

**Scope:** read-only investigation requested by Controller. No source, tests, inboxes, or watcher processes were changed by this investigation. Historical command outputs below are quoted from the retained Pi session transcript; they are evidence of what that earlier session ran, not commands rerun for this report.

## 1. Outbound hash-ledger fix: source revision and tests

### Revision and landing state

There is **no commit** introducing `bin/fm-outbound.sh` in the checked repository history. The current file is an untracked working-tree file, not a landed fix. The check-side change is likewise not committed: the actual checker path is `state/controller-inbox.check.sh` (no leading dot), it is ignored by Git's `state/` rule, and is not in the index. Therefore the complete fix is **UNCOMMITTED**.

Commands and output:

```text
$ git log --all --format='%H %s' -- bin/fm-outbound.sh state/controller-inbox.check.sh
[no output]
$ git ls-files --stage -- bin/fm-outbound.sh state/controller-inbox.check.sh
[no output]
$ git status --short --untracked-files=all --ignored -- bin/fm-outbound.sh state/controller-inbox.check.sh
?? bin/fm-outbound.sh
!! state/controller-inbox.check.sh
$ git check-ignore -v bin/fm-outbound.sh state/controller-inbox.check.sh
.gitignore:2:state/ state/controller-inbox.check.sh
$ git log --all --format='%H %s' -S'is_outbound' -- state/controller-inbox.check.sh
[no output]
```

The current source is `bin/fm-outbound.sh:17-22, 25-35, 57-65`; it writes content SHA-256 hashes to `$STATE/.controller-inbox-outbound`. The checker references the same ledger at `state/controller-inbox.check.sh:25-29, 72-81` and skips matching outbound hashes in both the watermark seed and poll paths (`:130-142, :150-163`).

### Test evidence

No committed automated test for this fix was found. Searching `tests/` for `controller-inbox`, the outbound ledger, or self-trigger cases found no dedicated regression test. A historical session recorded syntax checks and manual canary checks, not a suite exercising the `fm-outbound.sh`/checker pair. Exact retained outputs:

```text
$ bash -n $D/state/controller-inbox.check.sh && echo "SYNTAX OK"; bash -n $D/bin/fm-outbound.sh && echo "OUTBOUND SYNTAX OK"; ...
SYNTAX OK
OUTBOUND SYNTAX OK
=== mark all existing Brandon outbound ===
outbound_ledger=38
```

The transcript then records the checker run after an outbound copy had been sent to the bidirectional exchange. This is the exact output (the run printed a different, genuine Controller reply, not the outbound filename):

```text
$ ... bash $D/state/controller-inbox.check.sh 2>&1 | head -4
trust=d5860de5e7ecdcb0… actual=d5860de5e7ecdcb0…
=== CANARY: outbound must NOT self-trigger ===
controller inbox update: 2026-10-14-controller-current-decisions-and-staging-reply.md sha256=962dca5afcb88c61881c6eecdb4c0bba52fe6bc3becd64d745fcd40b1853e8ca
[lines=0]
```

Earlier in that sequence the sender's output was:

```text
sent: /home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-14-hetz-current-decisions-ack.md
sent: /home/hd2admin/controller-replies/2026-10-14-hetz-current-decisions-ack.md
```

This is historical manual evidence, not an automated test result or landed implementation. It supports that the outbound copy was not surfaced in that observed poll while a Controller message was surfaced. It does not replace a committed regression test. The sender source's own comments (`bin/fm-outbound.sh:5-10`) report that only 11 of 124 exchange files had a `# Brandon` heading; the hash ledger avoids relying on prose authorship.

## 2. What failed before repair

The strongest preserved source copy is `state/.pr-check-quarantine/controller-inbox.check.eI62TU`, the quarantined checker. Its bytes show multiple independent reasons a scheduled poll could produce no mail notification:

```text
# From state/.pr-check-quarantine/controller-inbox.check.eI62TU, lines 9, 72-92:
9  INBOX=/home/hd2admin/controller-replies
...
72 [[ -d "$STATE" && ! -L "$STATE" ]] || fail 'Firstmate state directory is unavailable'
73 [[ -f "$STATE/.afk" && ! -L "$STATE/.afk" ]] || exit 0
...
83 while IFS= read -r -d '' name; do
84   valid_name "$name" || continue
...
92 done < <(find "$INBOX" -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null)
```

`valid_name` at lines 23-25 accepts only a bare `[A-Za-z0-9._-]+.md` filename, while `find -print0` supplies a full path. Thus, even if `.afk` existed, that version passed an absolute path to the basename-only validator and skipped the entry. With the Captain present, the earlier line 73 exits 0 before reaching the scan at all. **Observed consequence:** a message could be present without the poll reporting it, hence no `check:` wake. The local repair report `data/controller-inbox-local-repair-20261013/report.md:11-18, 91-102` independently describes the absolute-path/validator mismatch and AFK gate; its fixture outcomes are summarized below, but are not an outbound-ledger test.

The older checker was also single-inbox: `INBOX=/home/hd2admin/controller-replies` (quarantine line 9), so it did not inspect the comms-mirror inbox. The current checker enumerates both paths at `state/controller-inbox.check.sh:31-34`. The repair report records a concrete directory-selection symptom: the configured wrong `brandon-inbox` had 35 messages versus 42 in the actual `controller-replies` exchange (`report.md:25-29`). That is a contemporaneous prior-report observation, not a fresh count by this read-only investigation.

Finally, `controller-replies` is bidirectional. The retained session transcript at `~/.pi/agent/sessions/--home-hd2admin-kun-agent-workspace--/2026-10-12T13-27-15-236Z_01a1304b-c824-70fc-869e-a19d419d63ce.jsonl:4008-4012` records the discovery: 11 files with Brandon headings, 124 without, followed by the statement “I receive my own mail” and creation of the hash ledger/check filter. This is evidence of the observed self-trigger and its investigation; the exact pre-fix poll output for a specific self-authored file was not preserved in the material inspected here. Do not treat the task's misspelled path `state/.controller-inbox.check.sh` as a real file: the live/quarantined checker is named `controller-inbox.check.sh` without the leading dot.

The local-repair report also records fixture results (not re-run here): T08/T09/T10/T11 and T12/T13 PASS, exit 0; negative controls N08-N11 EXPECT FAIL, exit 1 (`data/controller-inbox-local-repair-20261013/report.md:106-126, 209-218`). Those cover deduplication, acknowledgement digest, symlink handling, and canary reception for that repair—not the later outbound-ledger change.

## 3. Scheduled watcher evidence — and limits

### Watcher interval and processes

`bin/fm-watch.sh:116-120` sets `CHECK_INTERVAL=${FM_CHECK_INTERVAL:-300}`, i.e. check scripts are swept every **300 seconds by default**, unless overridden. The check loop runs only when the last-check age reaches the interval (`bin/fm-watch.sh:910-916`).

A read-only process sample from this investigation found **two** `fm-watch.sh` processes with cwd exactly `/home/hd2admin/kun-agent-workspace`; both are therefore associated with this home at the time sampled. It also found watcher processes in distinct `.treehouse` worktrees, which are not counted as this home's watcher. The home-local sample was:

```text
$ for p in $(pgrep -f '[/]bin/fm-watch.sh'); do ... readlink /proc/$p/cwd; ps -p "$p" -o etimes=,args=; done
pid=78272 cwd=/home/hd2admin/kun-agent-workspace
      8 bash /home/hd2admin/kun-agent-workspace/bin/fm-watch.sh
pid=82965 cwd=/home/hd2admin/kun-agent-workspace
      5 bash /home/hd2admin/kun-agent-workspace/bin/fm-watch.sh
```

This is only a point-in-time observation; it does not explain why two same-home processes were present. The loop's `pgrep` can also match its own search command unless bracket-escaped, hence the form above.

### Scheduled pickups (positive evidence, historical)

The durable queue at inspection time had no records:

```text
$ wc -l -c state/.wake-queue
0 0 state/.wake-queue
```

So the queue does **not** itself preserve a check wake from this evidence-gathering interval. The watcher cycle log contains historical `reason=actionable-check` records, but those only establish that the watcher classified a check outcome as actionable; they do not identify inbound message contents. Stronger direct evidence is the retained agent transcript: its `user` entries are explicit `FIRSTMATE WATCHER WAKE: check:` notifications naming `state/controller-inbox.check.sh` and an inbound filename/hash. Seven such entries were visible in the inspected 2026-10-15 sequence:

| Transcript timestamp (UTC) | Scheduled `check:` payload |
|---|---|
| 2026-10-14 23:25:05 | `2026-10-14-brandon-controller-autoreceive-canary-evidence.md` |
| 2026-10-15 00:06:42 | `2026-10-15-controller-acknowledgement-of-hetz-receipt.md` |
| 2026-10-15 02:31:50 | `2026-10-15-controller-sitrep-full-status.md` |
| 2026-10-15 03:29:39 | `2026-10-15-crisp-wo-0001-domain-triage.md` |
| 2026-10-15 03:34:56 | `2026-10-15-crisp-why-no-pickup.md` |
| 2026-10-15 03:40:13 | `2026-10-15-crisp-wo-0002-triage-accepted.md` |
| 2026-10-15 03:50:48 | `2026-10-15-crisp-wo-0003-scope-registry.md` |

Each payload is in transcript file `~/.pi/agent/sessions/--home-hd2admin-kun-agent-workspace--/2026-10-12T13-27-15-236Z_01a1304b-c824-70fc-869e-a19d419d63ce.jsonl` (lines 4006, 4040, 4168, 4321, 4337, 4346, 4352 respectively). The explicit `check:` wrapper distinguishes these scheduled notifications from a user reading an output produced by direct polling.

**Do not overstate the time scope:** these are historical notifications in the retained session, earlier than this evidence-gathering turn. During this turn, the queue was empty and no fresh inbound `check:` event was found. Therefore I can verify that this home previously received inbound mail through scheduled `check:` notifications, but I cannot claim a new scheduled pickup occurred in the present evidence-gathering interval.

### Direct-poll overlap

The same transcript also records a direct poll at 2026-10-15 03:18:55, whose output was `controller inbox update: 2026-10-15-controller-go-brandon.md sha256=a50ac1cf476875451f20a7b04318d521acf94dd8795a93750a3d66ad51a42f23` (line 4317). The next listed scheduled pickup, at 03:29:39, names a different file (`...crisp-wo-0001-domain-triage.md`). The inspected direct-poll output did not contain any of the seven filenames listed above. Thus the evidence distinguishes that direct read from the named scheduled notifications; it does not prove no unrecorded direct poll happened elsewhere. **No identical message was found in both the inspected direct-poll output and those seven check payloads.**

### Conclusion / recommendation

The scheduled path has real historical `check:`-wake evidence for inbound Controller messages; it is not merely inferred from the poll implementation. However, the current turn has no new queue/check record, and the current two-process sample plus an empty queue cannot establish a pickup now. The outbound suppression change is still uncommitted and has no dedicated automated regression test. Controller should treat it as local-only/unlanded, request a committed test covering “own outbound is suppressed while a new inbound still surfaces,” and keep any scheduled-path claim limited to the timestamped `check:` events above.

## Closeout gate

No unresolved choice requiring a Captain decision was discovered in this evidence report; the recommendation is for Controller and does not create a Captain decision. The required `decision-hold-lifecycle` skill was read. Its shared completion command is `bin/fm-decision-hold.sh complete <origin-id> --none`, but that script sources the tasks-axi integration and invokes `tasks-axi` (`bin/fm-decision-hold.sh:48-53, 99-106`). This task explicitly prohibits running `tasks-axi` and allows only the report/status writes. Therefore the shared completion command was **not run**; the report is evidence-complete but the required completion gate remains blocked by that explicit conflict. No claim of a passed gate is made.
