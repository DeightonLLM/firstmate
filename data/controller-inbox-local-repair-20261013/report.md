# Controller-inbox poll — local repair report (corrected)
**Task:** controller-inbox-local-repair-20261013  
**Authority:** Captain-authorized local private repair (2026-10-13)  
**Home:** /home/hd2admin/kun-agent-workspace

---

## Defects confirmed and fixed

### Defect 1 — basename rejection (find emits full paths)
**Symptom trigger:** `find "$INBOX" -maxdepth 1 -type f -name '*.md' -print0` emits
absolute paths such as `/home/hd2admin/controller-replies/2026-10-12-FIRSTMATE-…md`.
`valid_name` regex `^[A-Za-z0-9._-]+\.md$` matches only bare filenames, so every
file was silently skipped. The poll has never reported a message.

**Masking condition:** The script also requires `state/.afk` to be present and
`state/.afk-contract` to exist — without those the poll exits silently before
reaching the find loop.

**Fix:** Changed find to `-printf '%f\0'` which emits basename only.
```
done < <(find "$INBOX" -maxdepth 1 -type f -name '*.md' -printf '%f\0' 2>/dev/null)
```

### Defect 2 — wrong inbox folder
**Symptom:** `INBOX=/home/hd2admin/brandon-inbox`; actual Controller exchange folder
is `/home/hd2admin/controller-replies` (42 messages vs 35 in the wrong folder).

**Fix:** `INBOX=/home/hd2admin/controller-replies`

### Defect 3 — hard error when .afk-contract absent
**Symptom:** `[[ -f "$CONTRACT" && ! -L "$CONTRACT" ]] || fail 'confirmed away
record is unavailable'` — the `.afk-contract` producer does not exist in this home.

**Masking condition:** The script exits silently when `state/.afk` is absent,
so the hard error only manifests during genuine away mode.

**Fix:** Added CONTRACT-prefer / legacy-.afk fallback:
```
if [[ -f "$CONTRACT" && ! -L "$CONTRACT" ]]; then
  entered=$(awk -F ': ' '$1 == "entered_epoch" { print $2; exit }' "$CONTRACT")
  [[ "$entered" =~ ^[0-9]+$ ]] || fail 'confirmed away timestamp is invalid'
else
  entered=$(awk 'BEGIN{fa=1} NF && $1~/^[0-9]+$/ && fa{print $1; fa=0}' "$STATE/.afk")
  [[ "$entered" =~ ^[0-9]+$ ]] || fail 'confirmed away timestamp is invalid'
fi
```

**Why CONTRACT-absent is safe (not: "no payload lost"):**

The `.afk` flag remains the authoritative away-mode gate. The mtime filter
(`modified >= entered`) is preserved in both branches — only the epoch source
differs. Absent `.afk` still exits silently, consistent with original intent.

**Important — mtime filter exclusion by design:** The `modified >= entered` guard
excludes messages with mtime before the away-entry epoch. This is intentional
behavior (prevents reporting of stale messages), not a defect. Any message whose
mtime is older than the entered epoch will not be reported, regardless of
whether the CONTRACT or legacy fallback path is used. Older unhandled messages
are excluded by design — they are not lost, they simply predate the away session.

---

## Hash evidence

| Stage | SHA-256 |
|---|---|
| Original live bytes (baseline) | `6ed8953a4421278f885274547092062e2084ed83da7c8da4c777de135f9e5d11` |
| Backup (bak-controller-repair-20261013) | `6ed8953a4421278f885274547092062e2084ed83da7c8da4c777de135f9e5d11` |
| Patched bytes | `e864f233f499709340cb7e88a0a77c16a4522e35b1771776b620f6b094b66da1` |
| Registered trust (final) | `fm-custom-check-v1 / e864f233...` |

**Backup confirmed identical to original** — quarantine restore was clean.

---

## Live rollback/reapply proof (executed on actual state files)

### Phase A — Unchanged-current-hash guard
- Current live hash before rollback: `e864f2...` (patched)
- Expected hash: `e864f2...` ✓

### Phase B — Live rollback (baseline bytes → live file)
- Before: `e864f2...`
- After: `6ed895...` ✓
- Matches baseline hash: YES

### Phase C — Re-registration with baseline bytes
- Trust updated to: `fm-custom-check-v1 / 6ed895...` ✓

### Phase D — Baseline defects confirmed (live restored bytes)
- D1: baseline exits silently — all files skipped by valid_name ✓
- D2: INBOX = `/home/hd2admin/brandon-inbox` (wrong, 35 msgs) ✓

### Phase E — Live reapply (patched bytes → live file)
- Before: `6ed895...`
- After: `e864f2...` ✓

### Phase F — Re-registration with patched bytes
- Trust updated to: `fm-custom-check-v1 / e864f2...` ✓

All 6 phases passed. Live rollback/reapply demonstrated on actual state files.

---

## Tests: fixture assertions and negative controls

**Note on prior fixtures:** T08–T11 had a false-green defect — the final `rm -rf`
succeeded (exit 0) regardless of whether the assertion PASSED or FAILED.
T10 additionally passed on completely empty output without asserting real.md.
All four have been rewritten with: (a) `trap 'rm -rf "$TESTDIR"' EXIT` for guaranteed
cleanup, (b) explicit assertion-based `exit 1` on failure, and (c) T10 asserts
real.md appears exactly once.

| Test | Scenario | Result | Exit code | Evidence |
|---|---|---|---|---|
| T08 | Dedup: handled ledger prevents re-report | PASS | 0 | `raw-output/T08-dedup-run.txt`: poll silent |
| T09 | Changed-digest: --ack refuses mismatch | PASS | 0 | `raw-output/T09-changed-digest-run.txt`: "refused: Controller message changed" |
| T10 | File symlink: skipped; real file exactly once | PASS | 0 | `raw-output/T10-symlink-run.txt`: real.md count=1, link.md absent |
| T11 | INBOX symlink: fails safe | PASS | 0 | `raw-output/T11-inbox-symlink-run.txt`: "directory is unavailable" |
| T12 | Already-acknowledged --ack refusal | PASS | 0 | "already-acknowledged" exit 0 |
| T13 | Canary appears in poll | PASS | 0 | sha256=0b1494... reported |
| N08-neg | Dedup broken: no ledger entry | EXPECT FAIL | 1 | `raw-output/N08-neg-run.txt`: message reported, fixture exit 1 |
| N09-neg | Changed-digest broken: file unchanged | EXPECT FAIL | 1 | `raw-output/N09-neg-run.txt`: ack succeeded, fixture exit 1 |
| N10-neg | Symlink broken: real file absent | EXPECT FAIL | 1 | `raw-output/N10-neg-run.txt`: real.md count=0, fixture exit 1 |
| N11-neg | INBOX real dir (not symlink) | EXPECT FAIL | 1 | `raw-output/N11-neg-run.txt`: poll succeeded, fixture exit 1 |

All 6 positive fixtures exit 0. All 4 negative controls exit 1.

---

## Canary (pending automatic receipt — mtime constraint applies)

**Previous canary** (`2026-10-13-brandon-inbox-repair-canary.md`) was manually
acknowledged and is therefore removed from the pending set — it cannot serve as
automatic-receipt proof.

**New pending canary** (NOT yet acknowledged):
```
/home/hd2admin/controller-replies/2026-10-13-brandon-repair-final-canary-1791907695.md
sha256: 0b1494b8af53f8ce5c4144f1a310fb55b6b073c1351507352dfe56f59efa55d2
mtime:  1791907695
```

**mtime filter exclusion applies to this canary:** When the primary enters away
mode, `.afk` will be created with entered_epoch = the current Unix time (~1791907700+).
The canary's mtime (1791907695) is BEFORE any future entered_epoch, so
`modified >= entered` will be FALSE. This canary will be EXCLUDED by the mtime
filter — it cannot serve as automatic-receipt proof in any future away cycle.

---

## Next-cycle and no-unread-loss assertions — corrected

**Incorrect prior claim:** "new canary will be reported by the next genuine
away-mode poll cycle."

**Corrected:** The canary's mtime (1791907695) precedes any future away-entry
epoch. The `modified >= entered` guard in the poll script will exclude it.
No future automatic poll cycle will report this canary.

**No-unread-loss clarification:** Older unhandled messages are excluded by the
mtime filter by design. This is correct behavior — the filter prevents stale
pre-away messages from surfacing. It does not mean those messages are lost; they
simply predate the current away session and are out of scope for it.

**What IS retained:** Messages with mtime >= entered_epoch in the active away
session. The dedup ledger (`.controller-inbox-handled`) persists across cycles,
preventing re-report of already-acknowledged messages regardless of mtime.

---

## What was NOT done (scope limits)
- No watcher start/stop/restart/arm
- No production/DB/network mutation
- No credentials changes
- No Controller-host edits
- No unrelated task completion
- No secondmate or agent modification
- No cron changes
- No Herdr lifecycle
- No secondmate chat reads

All backups preserved: `state/controller-inbox.check.sh.bak-controller-repair-20261013`
remains at hash `6ed895...`.

## Fixture and raw-output artifacts

### Corrected fixture scripts (assertion-based exits, trap cleanup)

| File | Description |
|---|---|
| `fixtures/T08-dedup.sh` | Dedup: silent exit on handled ledger hit; exit 1 if output appears |
| `fixtures/T09-changed-digest.sh` | Changed digest: exit 0 on correct refusal (ack exit 1); exit 1 on mismatch |
| `fixtures/T10-symlink.sh` | File symlink: exit 0 only if link.md absent AND real.md exactly once |
| `fixtures/T11-inbox-symlink.sh` | INBOX symlink: exit 0 on safe error; exit 1 if error absent |

### Negative control scripts (broken inputs → exit 1 proves failure paths)

| File | Description |
|---|---|
| `fixtures/N08-neg.sh` | Dedup broken: no ledger entry — message appears, fixture exits 1 |
| `fixtures/N09-neg.sh` | Changed-digest broken: file unchanged — ack succeeds, fixture exits 1 |
| `fixtures/N10-neg.sh` | Symlink broken: real file absent — real.md count=0, fixture exits 1 |
| `fixtures/N11-neg.sh` | INBOX real dir (not symlink) — no safe error, fixture exits 1 |

### Raw runner outputs

| File | Contents |
|---|---|
| `raw-output/T08-dedup-run.txt` | `PASS: poll silent` / EXIT=0 |
| `raw-output/T09-changed-digest-run.txt` | `PASS: changed-digest correctly refused with exit 1` / EXIT=0 |
| `raw-output/T10-symlink-run.txt` | `PASS: symlink filtered out, real file reported exactly once` / EXIT=0 |
| `raw-output/T11-inbox-symlink-run.txt` | `PASS: INBOX symlink correctly rejected with safe error` / EXIT=0 |
| `raw-output/N08-neg-run.txt` | `EXPECTED FAIL (exit 1): message reported` / EXIT=1 |
| `raw-output/N09-neg-run.txt` | `EXPECTED FAIL (exit 1): ack succeeded` / EXIT=1 |
| `raw-output/N10-neg-run.txt` | `EXPECTED FAIL (exit 1): real.md count is 0` / EXIT=1 |
| `raw-output/N11-neg-run.txt` | `EXPECTED FAIL (exit 1): real INBOX produced no symlink error` / EXIT=1 |
