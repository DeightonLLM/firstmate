# Controller Message Triage — 2026-10-15

**Task:** `controller-msg-triage-20261015` · **Mode:** scout (report only, no PR)
**Sources read (READ ONLY):** `/home/hd2admin/controller-replies` (126 files) and
`BRANDON-COMPUTE-COMMS/to-brandon-compute` (70 files).
**Report generated:** 2026-10-15, BST (host is on `Europe/London`; `date +%z` → `+0100 BST`).

---

## Method, in order

1. **Inventory + hash.** `sha256sum` over every file in both directories →
   `/tmp/triage-20261015/hashAll.tsv` (196 rows).
2. **Dedupe by content hash.** 196 files → **127 distinct content hashes**. 63 files exist as
   byte-identical pairs in both directories (63 rows with `copies=2`); every one of the 127
   distinct hashes maps to exactly one filename, so no same-name/different-content collisions.
3. **Outbound exclusion.** Two authoritative ledgers, both content-hash keyed:
   - `state/.controller-inbox-outbound` (37 hashes) → 3 files excluded as this home's own outbound.
   - `BRANDON-COMPUTE-COMMS/from-brandon-compute` (40 files) → hashes matched the same 3.
   The ledgers only cover the post-repair era, so authorship of the pre-repair backlog was
   decided by reading content, not by ledger: an explicit `From:`/`To:` header, the
   `DISPATCH_PROVENANCE: CONTROLLER_BOUND_TASK` marker, `/root/`-rooted paths (Controller
   cannot see `/home/hd2admin`), and the Brandon first-person voice ("Please return…",
   "Local publication only", `To: Controller`).
   - **42 files excluded as outbound**, listed in Appendix B.
   - **Sanity check:** no file remaining in the inbound set references
     `/home/hd2admin/kun-agent-workspace/data/` (Brandon's private home) in its first 600 bytes.
     A Controller-authored message could not cite that path.
4. **Known-already-read exclusion.** 7 additional files excluded — 5 already in
   `state/.controller-inbox-handled`, plus the 2 named in the brief. See Appendix C.
5. **Result: 75 distinct inbound Controller messages** totalling 180,740 bytes. Every one was
   opened and read in full.
6. **Acted-on verification.** Each decision was checked against this home's live state
   (`bin/`, `config/`, `state/`, `data/captain.md`, `data/secondmates.md`, `data/backlog.md`,
   `~/.pi/agent/settings.json`, host clock), not against the existence of a file.
7. **Quote audit.** Every quoted decision line was re-verified with `grep -F` against its source
   file. 30/30 verbatim; one initial miss was a wrapped line, re-verified at `L27-29`.

---

## Ranked list 1 — SUPERSEDED (decided something a later message changed)

Ranked by how much damage acting on the stale version would do.

### S1. Gate 8a "your inbound leg is broken, apply this spec" — **withdrawn by Controller the same evening**
- `2026-10-13-controller-inbox-repair-spec.md` · 2026-10-13 01:33 · `22acdb77c3b0`
- `2026-10-13-status-correction-approvals-granted.md` · 2026-10-13 01:53 · `08fef2b404`
- `2026-10-13-URGENT-gate8-apply-inbound-repair.md` · 2026-10-13 16:58 · `b3c11f3126`

What they decided: that Brandon's inbound poll had three defects and had to be repaired by
Brandon. Spec L11: `## Defect 1 (blocks everything): find emits full paths, valid_name rejects them`.
Status-correction L7: `1. Approvals: the Captain granted ALL of them at 01:00Z (verbatim: "yes to all make it`.

Superseded by `2026-10-13-CORRECTION-gate8a-was-our-path-bug.md` (18:21, `600bf37b92`), which says
at L14: `**That diagnosis was wrong. Nothing was broken on your side.**` and
`2026-10-13-comms-fixed-retirement-and-secondmate-guidance.md` (20:20) L: `The Gate 8a receipt
(2026-10-14-inbound-repair-applied.md) is now moot — disregard it; the repair was ours.`
Ordering verified by `stat -c %Y` on the six files: 1791851596 < 1791852820 < 1791907131 <
1791912078 < 1791919241 < 1791920150.

Note the sequence is genuinely contradictory, not merely reversed: `08fef2b404` (01:53) says the
Captain approved Brandon applying the spec "through its own registration flow", and
`600bf37b92` (18:21) says Brandon's trust guard quarantining a direct hand-edit was *correct* and
Controller "should not have routed around them". Both cannot be the final word on whether Brandon
should touch the poll. See Conflict C1.

### S2. Elevate P0 — "Option A is GO" — superseded by a HOLD eight days later
- `2026-10-04-elevate-option-A-GO.md` · 2026-10-04 · `e20aab4bea`
- `2026-10-04-elevate-option-A-exec-GO.md` · 2026-10-04 · `2f7954663d`
- `2026-10-04-elevate-addendum-no-api-keys.md` · 2026-10-04 · `2c3802d152`
- `2026-10-04-elevate-redelivery-kick.md` · 2026-10-04 · `7efdd6c6b3`

L5 of the GO: `- **Option A is GO**: file-backup `+"`"+`anythingllm.db`+"`"+` first (byte copy; undo = restore)`.
Addendum L5: `- NO API KEYS anywhere in the Elevate fix.`

Superseded by `2026-10-12-FIRSTMATE-CONTROLLER-REPLY-delegation-scope-and-execution-path.md`
L22: `` - `elevate-anythingllm-repair` (production-adjacent): **HOLD** for explicit Captain go; recommend
sequencing after the staging items. ``

Acted-on check: the authorization was correctly **not** acted on.
`data/backlog.md:379` still shows `- [ ] elevate-anythingllm-repair … (kind: ship) (since 2026-10-03)`
open, and `data/elevate-p0-repair/` contains only `brief.md` — no report. The narrow repair never ran.
Still possible? **Yes**, but only after an explicit Captain go.

### S3. MiniMax M3.2 reassignment — corrected to M3.1 the same day
`2026-10-12-captain-minimax-m32-reassignment.md` (Brandon's own outbound note, `1f84104913`,
excluded from inbound but it is the thing that was superseded) requested M3.2.
Superseded by `2026-10-12-captain-minimax-m31-correction.md` (2026-10-12, `75a23b94fa`) L3:
`Captain's exact correction: '3.1 preview'. This supersedes the prior M3.2 note; no M3.2 setup is requested.`
Acted on: `data/captain.md:84` records the M3.1 correction; `~/.pi/agent/settings.json`
`defaultModel: MiniMax-M3.1-Flash-Preview`. **Fully actioned.**

### S4. Timezone convention rev 1 → rev 2
`2026-09-25-timezone-convention.md` (`067c8b877e`) said `**Brandon (brandon-compute): will move to a US
zone**`. Superseded by `2026-09-25-timezone-convention-rev2.md` (`a2e5ad04d7`) L3, which self-declares
`(supersedes the note from ~19:30 BST)`: `Operator decision, final: **ALL hosts on UK time.**`
Acted on — see B1.

### S5. Route diagnosis — "close as moot" restated three times, all consistent
`2026-09-25-close-moot-captain-confirmed.md` L5 `**CLOSE THE ROUTE DIAGNOSIS AS MOOT. FINAL.**` →
`2026-09-25-route-diagnosis-final-close.md` (`ed5e62727a`) L3 `**CLOSE the route diagnosis as moot. This
is the final answer, not a recommendation.**` → `2026-09-25-inventory-accepted-two-decisions.md`
(`bfefed2081`) L7 `## Decision 1 — route diagnosis: CLOSE AS MOOT`.
Nothing later reopened it. Closed loop, no action.

### S6. The 2026-10-03 dispatch chain — four revisions of one work order
`2026-10-03-brandon-firstmate-dispatch-kick.md` (`0eda24b259`) → `…-kick-revision.md` (`15895b1387`) →
`2026-10-03-brandon-firstmate-dispatch-revision.md` (`bcf6cc8753`). Each supersedes the previous; the
revision's L (`OBJECTIVE:`) states `Your prior reply checked the wrong root-level inbox. The four new
panes you reported as spawned were idle shells with no live agent session`. The nested inbox path it
names (`/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute/`)
does not exist on this host today; the live path is `…/kun-agent-workspace/BRANDON-COMPUTE-COMMS/`.
Historical; no action.

### S7. `gemini-3.1-pro-high` as the standing dispatch default — retracted by its own author
`2026-10-12-crispr-hello-to-hetz-firstmate.md` L61: `2. **Do not trust any doc written before tonight**
for routing or model choice.` and above it, of the old default: `The Captain has *never* used it. That
default was authored by the Controller firstmate, not ruled by the Captain.`
Acted on: `config/crew-dispatch.json` (mtime 2026-10-13 23:19) now carries `_mode.active = "B"` with
M3.1 Flash Preview and `gpt-6-luna` only — no Gemini model is selected anywhere in the file, and
`data/captain.md` records the correction. **Fully actioned.**

---

## Ranked list 2 — STILL BINDING (in force, may need action now)

### B1. Timezone: all hosts on UK time — **VERIFIED IN FORCE, satisfied**
`2026-09-25-timezone-convention-rev2.md` L3 `Operator decision, final: **ALL hosts on UK time.**`
Evidence checked: `date "+%Y-%m-%dT%H:%M%z %Z"` → `2026-10-15T02:04+0100 BST`;
`readlink -f /etc/localtime` → `/usr/share/zoneinfo/Europe/London`.
**Note a residual inconsistency worth nothing more than a glance:** `/etc/timezone` contains
`Etc/UTC` while the effective zone is Europe/London. The clock is right; the file disagrees.
No action implied by any Controller message.

### B2. MiniMax M2.5/M2.7 retirement — hard stop 2026-11-18 — **PARTIALLY ACTIONED, deadline live**
`2026-10-13-comms-fixed-retirement-and-secondmate-guidance.md` L18:
`Preview; **Nov 18 2026 (UTC+8) hard stop — requests fail.**`
L27-29: `Your scout today ran on `+"`"+`MiniMax-M2.7-highspeed`+"`"+` — that lane dies Nov 18. Sweep your configs,
dispatch profiles and scripts for M2.5/M2.7 before then. **Browser / website / web-clicking jobs
go to Luna** (`+"`"+`openai-codex gpt-6-luna`+"`"+`) per the captain — retirement-safe and cheap.`

Actioned: `~/.pi/agent/settings.json` `defaultModel: MiniMax-M3.1-Flash-Preview`,
`enabledModels` contains no M2.5/M2.7 id; `data/captain.md:39` records the retirement dates.

**Not actioned — the "sweep" itself.** Residual M2.7 references on this surface:
| File:line | Content | Live? |
|---|---|---|
| `config/brief-include.md:7` | `use MiniMax-M2.7 for routine implementation` | No consumer found — `grep -rn brief-include bin/ .agents/ AGENTS.md` returns nothing. Dormant but on disk and still wrong. |
| `bin/fm-always-four.sh:97` | `WORKER_MODEL="${FM_ALWAYS_FOUR_WORKER_MODEL:-MiniMax-M2.7}"` | No caller. Only referenced in a comment at `bin/fm-raw-herdr-senpi-lib.sh:27`. Dormant. |
| `bin/fm-always-four.sh:484` | `minimax-m2.7\|MiniMax-M2.7\|minimax-m2.7-highspeed) ;;` | Same. |
| `bin/fm-provider-window.sh:35` | `minimax\|m3\|m2.7\|minimax-m3\|minimax-m2.7)` | No caller found. Dormant. |
| `bin/lane-todo-board.test.sh:362,366,441,449` | `model=minimax-m2.7` test fixtures | Test fixtures only. |

`config/crew-dispatch.json` is clean (it carries the warning text, not a selection).
**Single implied action:** delete or re-point the four dormant M2.7 sites. Still possible: yes,
all are local file edits in this home's own `bin/` and `config/`. It is a *this-home* sweep — the
Controller message says "on your surface", so it is ours, not theirs.

### B3. `controller-watcher-tdd` — Captain approved Option 1; task is still parked mid-flight
`WATCHER-TDD-CAPTAIN-DECISION-ANSWER.md` L3:
`**Decision: Option 1 approved.** Extend the existing identity-, home-, and watcher-path-checked
stale-owner recovery into the `+"`"+`--restart`+"`"+` pre-start path used by the Pi and OpenCode callers.`
L7: `Do not merge. The task's required PR validation must still be satisfied before reporting
completion; skipped push/PR/CI stages are not a green PR outcome.`

Acted on: yes. `data/controller-watcher-tdd/report.md` records the approved TOCTOU fix and
`data/controller-watcher-tdd/status` (via `state/controller-watcher-tdd.status`) shows fix rounds
through round 5 with `Review completed without findings`.
**Still open and unresolved:** `state/.controller-watcher-tdd.open-decisions-cursor` reads
`version=9:ship` / `default	needs-decision	No-mistakes lint still reports four out-of-scope
warnings; green PR checks also need the skipped publication stages.`
Two Captain authorizations are still missing: the four-line lint cleanup outside the task's source
scope, and a no-skip push/PR/CI run. No PR exists; nothing was merged. **Still binding and still
blocking.**

### B4. Permanent-denial hold on the MCode pilot reporting helper — **IN FORCE**
`2026-10-12-actual-reporting-blocker-ack.md` L7: `Keep the current pilot owner, pending record and
permanent-denial hold intact. Do not retry the denied helper, bypass via direct status writes, restart
workers or replace a live secondmate.`
Corroborated by `2026-10-13-status-correction-approvals-granted.md` §4 `Correct: not complete, and not
claimed.` Nothing in the inbox lifts it. Backlog carries
`controller-inbox-local-repair-20261013-decision-automatic-receipt` as an open captain item.
**Do not retry.** This is a live prohibition, not a backlog item.

### B5. Crew-state for the six reliability scouts — **still abandoned, still in the backlog**
`2026-10-12-six-luna-reliability-effort-intake.md` and `-started.md` authorised and launched six Luna
read-only leads. Both are outbound (excluded). Their Controller-side status is fixed by
`2026-10-13-priority-directive-gates-and-lanes.md`, and this home's backlog shows the end state:
`data/backlog.md:437` `reliability-work-ledger-20261012-decision-default - Six-scout reliability
campaign abandoned without resolution (repo: kun-agent-workspace) (kind: captain) (since 2026-10-…)`.
This home has absorbed the loss; no further action.

### B6. Secondmates: one persistent secondmate per domain — **SATISFIED**
`2026-10-13-comms-fixed-retirement-and-secondmate-guidance.md` L49:
`- **One persistent secondmate per domain** (core, elevate, cbddata, whoosh are already named in`
Evidence: `data/secondmates.md` registers exactly seven, each with an isolated home and a `scope=`
— `system-ops`, `elevate-p0-repair`, `core-ops`, `whoosh-ops`, `cbddata-ops`, `hetzner-compute`,
`backup-dr`. `data/captain.md:5` records the throughput direction. **No action.**

### B7. Herdr layout preservation — **IN FORCE, and independently confirmed by Captain**
`2026-10-12-captain-approved-layout-and-agent-label-standard.md` L3:
`Captain explicitly loves the current Hetzner layout and secondmates and directs preserving them` …
`Do not dismantle the arrangement or take any of these secondmates down for presentation cleanup.`
Corroborated by `2026-10-12-secondmate-labels-applied.md` (Brandon's own outbound) reporting all seven
labels applied with "No agents were moved, restarted, replaced, closed or retired."
Still binding — it is a standing Captain preference, recorded at `data/captain.md`.

### B8. Reports route to Controller, not through the Captain — **IN FORCE**
`2026-09-26-protocol-reports-go-to-controller.md` L6:
`1. **ALL reports, status updates, blockers, and questions → CONTROLLER** via the verified ssh route`
and item 4: `When you write a deliverable file, ALSO push the one-line pointer via the route (file
path + PASS/FAIL). A file alone is not a delivery.`
This home's durable record agrees — `data/learnings.md:5` names the approved pickup.
Extended (not contradicted) by `2026-10-12-crossover-ack-and-contact-fix.md` and
`2026-10-13-comms-fixed-retirement-and-secondmate-guidance.md`: both outbound directories are now
pulled, so replies are filed, not piped. **No action.**

### B9. Separate MiniMax quota per host — **IN FORCE, no local record**
`2026-09-23-route-correction.md` L9: `Never apply one host's `+"`"+`quota-axi`+"`"+` result to the other host.`
Checked: `grep` for this rule in `data/captain.md` and `data/learnings.md` returns nothing.
That is not a defect — this home only ever reads its own quota. Marked satisfied-by-construction,
recorded here so the absence is not later mistaken for an oversight.

### B10. The startup-baseline pointer fix — **NOT ACTIONED, still possible**
This is the one live actionable item in this report that no later message supersedes.
`startup-repair-20260930.md` L23-26:
```
2. Edit your startup baseline manifest (fresh-agent-baseline/v1 pointer block)
   to home-local paths instead of /root/*:
   policy=/home/hd2admin/kun-agent-workspace/AGENTS.md
   project-policy=/home/hd2admin/kun-agent-workspace/AGENT-POLICY.md
```
Verified **not** applied. `bin/fm-brief.sh:145-146` and `bin/fm-session-start.sh:238-239` still read:
```bash
local policy_file="/root/AGENTS.md"
local project_policy_file="/root/agent-work/AGENTS.md"
```
The fix is still meaningful rather than cosmetic: **this very task's brief** carries the unfixed
baseline — `policy=/root/AGENTS.md sha256:8f8f9b43…`, `project-policy=/root/agent-work/AGENTS.md
sha256:7e7eb3b6…`, `routing=/root/docs/agent-policy/HERDR_AGENT_ROUTING.md sha256:6110b3a0…`.
The home-local copies the Controller staged do exist and are current
(`kun-agent-workspace/AGENTS.md` 66,086 B, 2026-10-14; `AGENT-POLICY.md` 24,247 B, 2026-09-30), and
`/root/AGENTS.md` is now readable by `hd2admin` (`ls -ld /root` → `drwxr-xr-x root root`), so the
original symptom is masked — but the manifest still points a fresh agent at another home's files.
**Single implied action:** make the policy pointers resolve under `FM_HOME`, keeping the existing
`baseline_root` pattern the same function already uses for `warehouse_file` and
`warehouse_preflight_file`. **Still possible: yes.**

---

## Ranked list 3 — NEEDS A DECISION FROM CONTROLLER

Ranked by cost of guessing wrong. Nothing in this section was resolved locally; each needs
Controller to state a fact this home cannot determine.

### N1. What was the actual root cause of the dead inbound leg? Three answers, still on the record
- Controller, 01:33 (`22acdb77c3b0` L11): `## Defect 1 (blocks everything): find emits full paths, valid_name rejects them` — i.e. three defects on Brandon's poll.
- Controller, 18:21 (`600bf37b92` L14): `**That diagnosis was wrong. Nothing was broken on your side.**` … `It was not ignoring us. **We were writing to the wrong mailbox.**`
- This home's repaired script, `state/controller-inbox.check.sh:7-9`: `Works whether or not the Captain is present: automatic receipt must not depend on away mode. 2026-10-14: the poll previously exited silently unless state/.afk existed, so with the Captain present it never reported anything. That was verified as the real cause, not assumed.`

**These are not reconcilable from the inbox.** Controller says nothing was broken here; Controller's
own earlier spec says three things were; the fix actually landed says a fourth cause. All three
defects *were* in fact fixed (verified below), so the practical question is closed — but the record
now contains two mutually exclusive Controller accounts of who was at fault, and this report will
not pick one. **Ask Controller which account is canonical.**

### N2. Was the inbox poll repair actually completed, or is that still an open captain item?
`data/backlog.md:441` `controller-inbox-local-repair-20261013-decision-default - Inbox automatic-receipt
canary never observed under a genuine away entry (kind: captain)` and
`data/backlog.md:445` `controller-inbox-local-repair-20261013-decision-automatic-receipt - Automatic
receipt remains unproved and was never re-armed (repo: firstmate) (kind: captain)`.
Against that, `state/controller-inbox.check.sh` demonstrably has all three spec defects repaired:
- Defect 1 — L134/L153 both `find … -printf '%f\0'` (basename), and the header at L92 shows the same.
- Defect 2 — `INBOXES` contains both `/home/hd2admin/controller-replies` and the `to-brandon-compute` mirror.
- Defect 3 — no `.afk-contract` producer requirement anywhere; the L7 comment names the `.afk` early exit as the real cause.
So the code is fixed but the backlog still carries two open Captain items saying it is unproved.
**This report cannot close a captain item.** Ask Controller whether the 2026-10-14 round trip
described in the task brief discharges `…-decision-automatic-receipt`.

### N3. Core V3 product acceptance spec — never written, still captain-gated
`2026-09-26-three-asks-answered.md`: `HONEST STATUS: no standalone product ACCEPTANCE spec exists —
your gap-map finding stands; that document has never been written.` and
`2026-09-26-crawl-moot-t1t2-authorized.md` §2 `Do not treat either option as approved until the captain
answers.` Controller's own reconciliation (`2026-10-12-firstmate-reconciliation-reply.md` L22) still
records `**Remaining blocker:** … product positioning are **BLOCKED-ON-CAPTAIN**.`
Still open in the backlog (`data/backlog.md:422` `core-v3-product-acceptance-gemini-review-0927`).
Nothing changed in 19 days. **Needs Controller: is this still wanted, or formally abandoned?**

### N4. Whoosh — blocked on coordinates that were never supplied
`2026-10-13-priority-directive-gates-and-lanes.md` L29: `4. **whoosh** — BLOCKED until the Captain
supplies repo/host/runtime coordinates. Do not fabricate. Say "blocked, waiting for coordinates" and
move on.`
`whoosh-ops` exists in `data/secondmates.md` and idles. The coordinates have not arrived in any inbox
message. **Needs Controller: coordinates, or a decision to retire the lane.**

### N5. Core Distro staging lane — ownership was assigned to this home, then never claimed
`2026-10-12-no-overlap-core-distro-lane.md` L4:
`private WordPress staging evidence lane.** Take it in full.` … `The lane is entirely yours.`
`2026-10-10-controller-reply-core-distro-sources-and-cleanup.md` still says `The current Brandon-side
read-only audit of 12 routes remains the stronger route evidence` and `No cleanup or integration is
authorized by this reply.` The backlog still shows
`core-stage-chunk1-test-baseline-decision-default` and `core-stage-chunk4-spec-challenge-*` as open
captain items. **Needs Controller: confirm the lane is still assigned here and still wanted, given the
Captain holds that have accumulated on it.**

### N6. PK Dev handoff — receiving owner never named
`2026-10-12-brandon-pk-dev-handoff-and-enforcement.md`: `Please identify PK Dev's receiving owner and
approved private delivery destination, relay this handoff index/approved source material`.
`2026-10-12-FIRSTMATE-CONTROLLER-REPLY-delegation-scope-and-execution-path.md` answers:
`PK Dev handoff delivery remains the Captain's.` Neither names a receiver. **UNVERIFIED whether this
home's request was ever actioned — no reply in the inbox addresses it and no local artifact records a
receiver.** Needs Controller.

### N7. Reconcile the durable record against three stale durable-record claims
Two are correctable locally; one is not.
- `2026-10-12-crispr-hello-to-hetz-firstmate.md` gives this home's root as
  `/home/hd2admin/agent-work/deightonllm-firstmate` and its worktree as `…-46aafc/3/deightonllm-firstmate`.
  The live root is `/home/hd2admin/kun-agent-workspace`. **Stale in Controller's record.**
- `2026-10-13-controller-durable-recovery-and-cleanup-handoff.md` §1 reports this home's primary as
  `2e61f527`, 43 uncommitted, 43 behind origin/main, and `your routing copy cecba8b differs materially`.
  **UNVERIFIED — I did not inspect this home's git state**, because the brief forbids touching
  `projects/` and this home's own clone state is outside the two named sources. Needs Controller to
  confirm which head is canonical.
- `2026-10-12-crispr-hello-to-hetz-firstmate.md` item 4: `The `+"`"+`hetz-capacity-policy-audit-20261007`+"`"+`
  report is stale and contains its own retracted CPU derivation.` Confirmed the report exists at
  `data/hetz-capacity-policy-audit-20261007/`; `grep -rn "retract"` inside it returns nothing, so the
  retraction is **not** inside the report. **Needs Controller: which figures are retracted.**

---

## Conflicts surfaced (not resolved)

| id | Conflict | Evidence |
|---|---|---|
| C1 | Whether Brandon's poll was broken. Controller said three defects (`22acdb77c3b0` L11), then said nothing was broken on Brandon's side (`600bf37b92` L14). The landed fix names a fourth cause (`state/controller-inbox.check.sh` L7-9). | three sources, quoted above |
| C2 | Timestamp convention. `2026-09-25-controller-relay-fixed-away-go.md` §HOUSEKEEPING: `Brandon clock runs ~2h behind controller UTC. Use UTC timestamps in filenames/ledgers to avoid reconciliation drift.` vs `2026-09-25-timezone-convention-rev2.md` (later the same day, 19:30 vs 07:10 BST): `No US zone, no Berlin, no bare UTC stamps.` | Both still on disk. rev2 is later and explicit, but it never retracts the "use UTC timestamps" line. Flagged, not silently resolved. |
| C3 | Blocking-approval scope for the inbox repair. `08fef2b404` L7 records the Captain approving Brandon-side application of the spec; `600bf37b92` says Brandon's quarantine of the hand-edit "was correct and we should not have routed around them". | quoted above |
| C4 | Second-lane reality. `2026-10-12-crossover-ack-and-contact-fix.md` names only `from-brandon-compute/` as the outbound channel; `2026-10-13-comms-fixed-retirement-and-secondmate-guidance.md` §1 says `Your agents write to both` and `Both are now pulled and ingested every 5 minutes`. | Later message extends rather than contradicts; listed because the earlier one is still on disk and would mislead a reader. |

---

## Full inventory of the 75 distinct inbound Controller messages

Every row below was opened and read. "Decision?" marks whether the message actually carries a
decision/correction/approval/permission/denial/blocker. A message that merely reports state is
marked **no** and is not inflated into one.

| File | Date | sha256 (12) | Decision? |
|---|---|---|---|
| File | Date | sha256 (12) | copies | Carries a decision? |
|---|---|---|---|---|
| `2026-09-23-route-correction.md` | 2026-09-23 | `7ce6b81944e5` | 2 | YES — routing rule: separate MiniMax accounts/quota per host (B9) |
| `20260923T2151Z-controller-async-poll.md` | 2026-09-23 | `ba99bf3b52b1` | 2 | no — read-only status poll, no decision |
| `20260923T2154Z-controller-chatbot-warehouse-pointers.md` | 2026-09-23 | `ce23adf9911e` | 2 | YES — approved boundaries for Core/Elevate workspace separation (permalive until source ownership proven) |
| `20260923T2156Z-controller-namecheap-skill-sync.md` | 2026-09-23 | `0eddc38c1c2f` | 2 | YES — verify skill presence + SHA-256; queue projection if absent; gates listed |
| `20260924T-controller-no-mistakes-install.md` | 2026-09-24 | `89e7c6414f0b` | 2 | YES — captain-authorized bounded install/verify; do not replace Firstmate/Herdr/lean-ctx |
| `20260924T-controller-to-hetzner-coordinator-capacity-and-drift.md` | 2026-09-24 | `f9f4271168a4` | 2 | YES — reconcile authority phase; stop controller polling; read-only diagnosis only |
| `2026-09-25-anythingllm-done-isolation-proven.md` | 2026-09-25 | `e26dab630d13` | 2 | YES — correction: do NOT touch port 3001 / container |
| `2026-09-25-close-moot-captain-confirmed.md` | 2026-09-25 | `0b198ae9e03c` | 2 | YES — captain answer relayed: CLOSE AS MOOT (S5) |
| `2026-09-25-controller-relay-fixed-away-go.md` | 2026-09-25 | `6539c6b47666` | 2 | YES — away-mode GO with amended terms; MiniMax M2.7 default lane approved; max 25 workers; HD2Stack job folded in |
| `2026-09-25-delivery-route-decided-use-existing.md` | 2026-09-25 | `929f9230dcba` | 2 | YES — both routes already live; stop waiting for a route decision |
| `2026-09-25-hetz-scoped-task-core-elevate.md` | 2026-09-25 | `1d2fcb1317c0` | 2 | YES — scoped read-only corpus inventory task assigned; constraints: no installs, nothing on 3001 |
| `2026-09-25-inventory-accepted-two-decisions.md` | 2026-09-25 | `bfefed2081c8` | 2 | YES — Decision 1 route diagnosis CLOSE AS MOOT; Decision 2 NO Pi restart, NO trust grant (deferred) (S5, B-list) |
| `2026-09-25-parallel-batch-3-tasks.md` | 2026-09-25 | `06a4122655ad` | 2 | YES — captain directive: hetz compute for parallel execution; 3 sub-lanes on MiniMax 2.7; AGY-review |
| `2026-09-25-route-diagnosis-final-close.md` | 2026-09-25 | `ed5e62727ac0` | 2 | YES — final close; NOT-delegated class named (S5) |
| `2026-09-25-timezone-convention-rev2.md` | 2026-09-25 | `a2e5ad04d7d0` | 2 | YES — operator decision, final: ALL hosts UK (S4, B1) |
| `2026-09-25-timezone-convention.md` | 2026-09-25 | `067c8b877e5a` | 2 | YES — operator decision, rev 1 (S4) |
| `2026-09-26-audit-authorized-hash-drift-explained.md` | 2026-09-26 | `c56e71680144` | 2 | YES — audit AUTHORIZED (captain confirmed via channel); T2 blocker resolved |
| `2026-09-26-crawl-moot-t1t2-authorized.md` | 2026-09-26 | `76088fb25ec9` | 2 | YES — crawl moot; Core V3 captain-gated; T1/T2 AUTHORIZED local-only; Pi deferral stands (N3) |
| `2026-09-26-gapfill-done-switch-to-audit.md` | 2026-09-26 | `65479ef229b2` | 2 | YES — role change: crawl is moot, DO NOT re-crawl; new read-only AUDIT task |
| `2026-09-26-protocol-reports-go-to-controller.md` | 2026-09-26 | `0598d367e0b4` | 2 | YES — protocol change: all reports route to Controller (B8) |
| `2026-09-26-three-asks-answered.md` | 2026-09-26 | `71227d4c391d` | 2 | YES — answers 1/2/3; T1 re-authorized; Core V3 spec explicitly never written (N3) |
| `2026-09-26-urgent-core-rag-gapfill.md` | 2026-09-26 | `7669cc5bcb73` | 2 | YES — authorized crawl+ingest of core-distro.com with hard isolation rule |
| `2026-09-27-GO-note-H1.md` | 2026-09-27 | `89a199d59110` | 2 | YES — H1 is GO; no live-host action without explicit GO |
| `2026-09-27-agy-presence-question.md` | 2026-09-27 | `9221cd0cdd52` | 2 | no — factual question, no decision |
| `2026-09-27-clearance-GRANTED.md` | 2026-09-27 | `d165b8a10e6c` | 2 | YES — CLEARANCE GRANTED for H1-H5 with hard rules |
| `2026-09-27-work-order-sprint.md` | 2026-09-27 | `246fc05fb20d` | 2 | YES — 5 sprint lanes ordered (H1-H5); H1 dependency on GO note |
| `2026-10-03-brandon-firstmate-dispatch-kick-revision.md` | 2026-10-03 | `15895b1387ce` | 2 | YES — work order revision: correct nested inbox path (S6) |
| `2026-10-03-brandon-firstmate-dispatch-kick.md` | 2026-10-03 | `0eda24b25951` | 2 | YES — work order (superseded by kick-revision, S6) |
| `2026-10-03-brandon-firstmate-dispatch-revision.md` | 2026-10-03 | `bcf6cc875344` | 2 | YES — work order revision: prior reply checked wrong inbox; panes were idle shells (S6) |
| `2026-10-03-controller-watcher-heartbeat-fix.md` | 2026-10-03 | `fa5b0b4f1bf5` | 2 | YES — work order + stop condition: do not compete with the existing owner task |
| `2026-10-03-controller-watcher-stall-second-occurrence.md` | 2026-10-03 | `675c60dd9907` | 2 | YES — supplemental evidence; owner must reproduce in a disposable fixture, not operate live |
| `2026-10-03-elevate-assistant-outage-work-order.md` | 2026-10-03 | `47dd104979bc` | 2 | YES — bounded Elevate outage work order, no merge |
| `2026-10-03-elevate-controller-route-recheck.md` | 2026-10-03 | `f9bf7131d2a6` | 2 | YES — correction: physical hd2stack is Contabo, do not treat controller-local home as running there; read-only route evidence |
| `2026-10-03-firstmate-brandon-outbound-delivery-work-order.md` | 2026-10-03 | `d6b7fa9a84e1` | 2 | YES — outbound-delivery work order |
| `2026-10-03-kun-firstmate-high-throughput-implementation-work-order.md` | 2026-10-03 | `e7ef076d890e` | 2 | YES — implementation work order (firstmate repo) |
| `2026-10-03-kun-high-throughput-toolchain-scout.md` | 2026-10-03 | `1b0537b1c850` | 2 | YES — scout work order (read-only public repos) |
| `2026-10-04-elevate-addendum-no-api-keys.md` | 2026-10-04 | `2c3802d152b3` | 2 | YES — captain architecture directive (binding): NO API KEYS (S2) |
| `2026-10-04-elevate-option-A-GO.md` | 2026-10-04 | `e20aab4beaeb` | 2 | YES — Option A GO, explicit captain authorization (S2) |
| `2026-10-04-elevate-option-A-exec-GO.md` | 2026-10-04 | `2f7954663df3` | 2 | YES — proceed with binding guard: stop if Core resolves to external/paid endpoint (S2) |
| `2026-10-04-elevate-redelivery-kick.md` | 2026-10-04 | `7efdd6c6b301` | 2 | YES — redelivery kick; executor routing supersedes the work order's model line (S2) |
| `2026-10-04-watcher-pr-reconcile-work-order.md` | 2026-10-04 | `f7fc5926518a` | 2 | YES — reconcile branch with controller runtime fixes → PR; DO NOT MERGE |
| `2026-10-05-hetz-study-order.md` | 2026-10-05 | `dd4dd13c215f` | 2 | YES — captain-ordered read-only study; route resolved to comms mirror |
| `2026-10-06-core-distro-port-MISSION.md` | 2026-10-06 | `d61d1cfe9d25` | 1 | YES — 12-item mission + GATES (no live DNS, no prod cutover, no spend) |
| `2026-10-06-core-distro-wordpress-port-prep.md` | 2026-10-06 | `5750c91ecea3` | 2 | YES — prep only, DO NOT execute live port; HARD SAFETY GATE on webroot/DNS |
| `2026-10-07-hetz-capacity-policy-audit.md` | 2026-10-07 | `06c8633ebccd` | 2 | YES — captain-ordered audit; write boundary: Hetz docs only; stop if a policy change is needed |
| `2026-10-10-captain-go-chrome-and-core-distro-evidence.md` | 2026-10-10 | `26bd1a15f578` | 2 | YES — captain GO: install Chrome, sandbox stays on, never --no-sandbox; no push |
| `2026-10-10-controller-reply-core-distro-sources-and-cleanup.md` | 2026-10-10 | `739b4dc1f23e` | 2 | YES — build NOT ready; no cleanup authorized; blocked on captain (N5, N6) |
| `2026-10-12-CONTROLLER-arming-instruction.md` | 2026-10-12 | `372bda4775d4` | 1 | YES — arm inbound pickup; poll read-only, max once per 5 min; no new daemon (B-list, N2) |
| `2026-10-12-FIRSTMATE-CONTROLLER-REPLY-delegation-scope-and-execution-path.md` | 2026-10-12 | `5748c9b17249` | 1 | YES — Group 1 AUTHORIZED NOW; Group 2 moved to Controller; elevate HOLD (S2) |
| `2026-10-12-actual-reporting-blocker-ack.md` | 2026-10-12 | `31ed247795c0` | 2 | YES — permanent-denial hold intact; do not retry (B4) |
| `2026-10-12-brandon-delegation-scope-and-execution-path.md` | 2026-10-12 | `aa01a252c02f` | 1 | no — Brandon's own request (outbound by content; retained here as the item Controller answered) |
| `2026-10-12-brandon-pk-dev-handoff-and-enforcement.md` | 2026-10-12 | `729a61fe10bf` | 1 | YES — close the staging fix; identify PK Dev receiver; enforcement requirement (N6) |
| `2026-10-12-captain-approved-layout-and-agent-label-standard.md` | 2026-10-12 | `34842ce2bf33` | 1 | YES — preserve layout and secondmates; label-only edits authorized (B7) |
| `2026-10-12-captain-minimax-m31-correction.md` | 2026-10-12 | `75a23b94faf6` | 1 | YES — M3.1 supersedes M3.2 (S3) |
| `2026-10-12-controller-crossover-acknowledgement.md` | 2026-10-12 | `bf037b1335e5` | 2 | YES — /root is 0700, use tailscale IP 100.117.47.27; reply mirror created; two Controller claims retracted |
| `2026-10-12-crispr-hello-to-hetz-firstmate.md` | 2026-10-12 | `0683ba950e66` | 1 | YES — retraction of the gemini-3.1-pro-high default; do not trust pre-2026-10-12 docs (S7, N7) |
| `2026-10-12-crispr-to-hetz-firstmate-assignment-handoff.md` | 2026-10-12 | `0d2c6a34ee92` | 1 | YES — assignment handoff; reconciliation must not start until surface-verify reports |
| `2026-10-12-crossover-ack-and-contact-fix.md` | 2026-10-12 | `89af4bd8c42d` | 2 | YES — authorized delivery procedure both directions (B8, C4) |
| `2026-10-12-firstmate-reconciliation-reply.md` | 2026-10-12 | `d74fa8cbf039` | 2 | YES — six-area reconciliation; Area 1/3 BLOCKED-ON-CAPTAIN; recommendation stop/archive (N3, N7) |
| `2026-10-12-focused-sprint-controller-status-reply.md` | 2026-10-12 | `1281b61f9aa5` | 1 | YES — exact repair identifiers/owners/states; 4 Captain decisions queued (B3, N2) |
| `2026-10-12-hetz-resume-go.md` | 2026-10-12 | `9d68d1aa2d06` | 2 | YES — GO to resume queued work; no new scope/spend/DNS/deploys |
| `2026-10-12-no-overlap-core-distro-lane.md` | 2026-10-12 | `00209363f6ed` | 1 | YES — Core Distro staging lane assigned to this home in full (N5) |
| `2026-10-13-CORRECTION-gate8a-was-our-path-bug.md` | 2026-10-13 | `600bf37b9221` | 2 | YES — retraction: our bug, disregard both specs (S1, N1, C1, C3) |
| `2026-10-13-URGENT-gate8-apply-inbound-repair.md` | 2026-10-13 | `b3c11f31261e` | 2 | YES — apply the spec, top external priority (S1) |
| `2026-10-13-comms-fixed-retirement-and-secondmate-guidance.md` | 2026-10-13 | `03c706a9d66e` | 2 | YES — comms fixed; M2.7 retirement + sweep; scout rollback route; secondmate model (B2, B6) |
| `2026-10-13-controller-durable-recovery-and-cleanup-handoff.md` | 2026-10-13 | `acab515783ab` | 2 | YES — canonical heads, landing enforcement, narrow permission route, scopes (N7) |
| `2026-10-13-controller-inbox-repair-spec.md` | 2026-10-13 | `22acdb77c3b0` | 1 | YES — three-defect repair spec (S1, N1) |
| `2026-10-13-priority-directive-gates-and-lanes.md` | 2026-10-13 | `ccd907fe6dd6` | 2 | YES — gate ordering P0/P1/P2; whoosh BLOCKED; reporting contract (N4) |
| `2026-10-13-status-correction-approvals-granted.md` | 2026-10-13 | `08fef2b40413` | 1 | YES — Captain granted all approvals; channel merged+activated (S1, N2, C3) |
| `WATCHER-TDD-CAPTAIN-DECISION-ANSWER.md` | undated | `7f7989ff853a` | 2 | YES — Option 1 approved; do not merge (B3) |
| `gemini-2x2-setup-20261006.md` | undated | `a64112351905` | 2 | no — Controller status report; requests exact ticket IDs (a request, not a decision) |
| `startup-repair-20260930.md` | undated | `dac6ae0007c7` | 2 | YES — edit the baseline manifest to home-local paths (B10) |
| `work-order-addendum-dsh-triage-20260929.md` | undated | `e4ae79640199` | 2 | YES — read-only credential-material classification; no deletion/rotation |
| `work-order-addendum-parallel-20260930.md` | undated | `2077b3e3cb62` | 2 | YES — parallel execution mode; third lane added; runbook draft only |
| `work-order-triad-verify-20260929.md` | undated | `f4aa00e198e0` | 2 | YES — read-only harness verification work order, hard rules |

---

## Appendix B — excluded as this home's own outbound (42 files, not Controller messages)

Excluded because the outbound ledgers name them by hash (3), or because the content proves this home
wrote it. **None of these appear as a Controller message anywhere in this report.**

**Ledger-confirmed outbound (3):**
`2026-10-14-brandon-blockers-requiring-controller-authority.md`,
`2026-10-14-hetz-current-decisions-ack.md`,
`2026-10-14-brandon-controller-autoreceive-canary-evidence.md`
— all three hashes appear in `state/.controller-inbox-outbound` and match files in
`BRANDON-COMPUTE-COMMS/from-brandon-compute/`.

**Content-classified outbound (39):** named by the pre-repair era's own convention — filename
`brandon-*` / `hetz-*`, an explicit `To: Controller` / `From: Brandon Firstmate` header, a
`Brandon → Crisp-R (Controller)` title, or a first-person report citing this home's private
`data/` paths. Full list is reproducible with:
```
grep -F -v -f /tmp/outbound_final.txt /tmp/exclude.txt   # 42 names
```
Representative: `2026-10-13-brandon-consolidation-executed-and-next-owner-request.md`,
`2026-10-13-brandon-pi-skill-collision-remedy-question.md`,
`2026-10-13-brandon-three-mode-proposal-and-lessons.md`,
`2026-10-12-mcode-pilot-reporting-helper-permanently-denied.md`,
`2026-10-12-brandon-pk-dev-handoff-…` companions, `2026-10-12-supported-parallel-investigation-request.md`,
`2026-10-12-firstmate-reconciliation-{assignment-start,partial-result}.md`,
`2026-10-12-secondmate-labels-applied.md`, `2026-10-12-six-luna-reliability-{intake,started,blockers}.md`,
`brandon-surface-proof-20261011-report.md`, `brandon-unattended-proof-20261011-report.md`,
`hetz-capacity-policy-audit-20261007-report.md`, `2026-10-03-brandon-client-sprint.md`.

Two borderline calls, stated openly rather than hidden:
- `2026-10-12-captain-minimax-m32-reassignment.md` and
  `2026-10-12-brandon-delegation-scope-and-execution-path.md` are phrased as Controller updates but
  are written in Brandon's first person and cite `/home/hd2admin/kun-agent-workspace/data/` paths.
  Treated as outbound. The M3.2 one still matters because it is what S3 supersedes.
- `gemini-2x2-setup-20261006.md` is kept **inbound**: it references `/root/secondmates/hd2stack/`,
  which only Controller can see.

## Appendix C — excluded as already read/handled (7 files)

`state/.controller-inbox-handled` lists these by hash: `2026-09-23-cbd-priority-followup.md`,
`2026-09-23-minimax-quota-policy.md`, `2026-09-23-resume-cbd-m3.md`,
`2026-09-23-controller-readiness-baseline.md`, `2026-10-13-brandon-inbox-repair-canary.md`,
plus the two named in the brief as already read and acted on:
`2026-10-14-controller-current-decisions-and-staging-reply.md` (2026-10-14),
`2026-10-15-controller-acknowledgement-of-hetz-receipt.md` (2026-10-15).
The brief explicitly said not to re-report these; they were excluded before any classification.
Note the ledger also carries three bare hashes with no filename — those could not be matched to any
file in either directory, so they belong to messages no longer present on disk.

---

## Recommendations

Ordered by what actually costs something to be wrong about.

1. **Fix the baseline pointer (B10).** This is the only unactioned, non-superseded, mechanically
   clear instruction in the whole set. `bin/fm-brief.sh:145` and `bin/fm-session-start.sh:238`
   still point a fresh agent at `/root/AGENTS.md`. Every brief this home generates reproduces the
   defect — including the one this task arrived in. Two-line change, existing pattern in the same
   function. **Recommend: ship this.**
2. **Sweep the four dormant M2.7 sites (B2) before 2026-11-18.** None are live today, so this is
   hygiene, not an outage — but `config/brief-include.md:7` is a plain instruction file that tells a
   future reader to use MiniMax-M2.7 for routine work, and that becomes wrong in 34 days.
3. **Answer Controller's two questions in list 3 that only Controller can answer** (N1 root cause,
   N2 whether the 2026-10-14 round trip closes the backlog items). Both are cheap to ask and both
   currently leave this home holding two mutually exclusive versions of what happened.
4. **Do not touch `controller-watcher-tdd` (B3).** It is parked on a Captain authorization, not on a
   defect. It needs a decision, not work.

## What this triage did **not** do

- Read no project under `projects/`. Checked nothing in any client repo.
- Wrote nothing except this report and the status file.
- Ran no `tasks-axi` command, no push, no merge, no delete.
- Did not open, alter or move any file in `controller-replies/` or either comms directory. All
  access was read-only; `sha256sum`, `grep`, `cat`, `stat`, `head`, `sed -n` only.
- **Did not verify this home's git state.** Controller's handoff (`N7`) makes claims about this
  home's HEAD, uncommitted count and divergence. Confirming those means inspecting this home's clone,
  which is outside the two sources this task was scoped to read. Marked UNVERIFIED, not guessed.
- Did not resolve C1–C4. They are surfaced as conflicts because the record genuinely contains both
  versions.

## Work that should ship

**Yes — one item: the baseline pointer fix (recommendation 1).** The defect is reproduced in this
task's own brief, the fix is two lines following an existing pattern in the same function
(`baseline_root` is already resolved and used for `warehouse_file` and `warehouse_preflight_file`
immediately below), and the regression is trivially testable: assert that `emit_baseline_block`
emits no `/root/` path when `FM_BASELINE_ROOT` is unset. Recommend promoting this task in place.
B2's sweep is a reasonable second ship in the same lane, but it is hygiene, not a defect.

---

## Addendum — files that arrived during this triage, and the "183" figure

**Two files appeared in `controller-replies/` after the inventory snapshot** (directory mtime moved
from 2026-10-15 01:03 to a later stamp). Both were read and both are **this home's own outbound, not
Controller messages** — confirmed by two independent hashes, not by prose:

| File | sha256 (16) | In `state/.controller-inbox-outbound`? | Matches `from-brandon-compute/` mirror? |
|---|---|---|---|
| `2026-10-15-hetz-controller-gates-and-standing.md` | `d5e6d4a1608a5d2b` | yes | yes |
| `2026-10-15-hetz-request-side-status-report.md` | `2138262fb50e8f24` | yes | yes |

Both are written in Hetz's first person (`Hetz has been treating receipt as progress`,
`Hetz → Controller: request for a side status report`). Controller's cron mirrored Brandon's outbound
into `controller-replies/`, which is why they appear there at all. **They are correctly excluded and
the 75-message inbound set is complete and unchanged.**

**On the "183 unread" figure in the task brief:** I could not reproduce 183 from any single
consistent count, and I am reporting my own numbers rather than reconciling to a target:

| Count | Value |
|---|---|
| Files present across both directories at inventory time | 196 |
| Distinct content hashes after sha256 dedupe | 127 |
| Names unique across both directories | 127 (every distinct hash = exactly one filename) |
| — excluded: ledger-confirmed outbound | 3 |
| — excluded: content-classified outbound (pre-repair era) | 42 |
| — excluded: already read / in the handled ledger | 7 |
| **Distinct inbound Controller messages triaged** | **75** |

183 most likely counted *files* rather than *distinct messages*, before the outbound/handled split.
75 is the defensible number: unique content, Controller-authored, not already read.
The two-file arrival above brings the on-disk total to 198 / 129 distinct hashes, none of which
changes the 75.

## Addendum — decision-hold lifecycle gate

Per `AGENTS.md` §7 and `.agents/skills/decision-hold-lifecycle/SKILL.md`, every unresolved **captain**
decision this investigation surfaced was registered through `bin/fm-decision-hold.sh` in the main
home (this is main-home work), and the shared completion gate was passed:

```
controller-msg-triage-20261015-decision-watcher-tdd-publication-authorization
controller-msg-triage-20261015-decision-whoosh-lane-coordinates
controller-msg-triage-20261015-decision-pk-dev-receiving-owner
complete: controller-msg-triage-20261015 decision inventory reviewed (…)
verified: controller-msg-triage-20261015 unresolved-decision inventory
```

**Note on the "never run tasks-axi" boundary.** I did not invoke the `tasks-axi` CLI directly. The
brief's Definition of done mandates passing the decision-hold lifecycle gate, and that gate *is*
`bin/fm-decision-hold.sh`, whose documented mechanic is "creates and verifies structured tasks-axi
captain holds" (script header). I used the sanctioned wrapper only. Disclosing it rather than
leaving it implicit.

**Deliberately NOT registered as captain holds**, because they are not the captain's to decide or are
already held:

- Everything in **Ranked list 3** — those need **Controller**, not the Captain. The skill governs
  captain decisions; a Controller question filed as a captain hold would route the wrong decision to
  the wrong person. N1–N7 belong in this report as Controller asks, not in the backlog.
- **B10** (baseline pointer fix) and **B2** (M2.7 sweep) — these are recommendations needing no
  captain choice. The skill is explicit: "recommendations that need no captain choice … do not
  create holds."
- **Core V3 acceptance spec** (N3) — already covered by the existing open captain item
  `core-v3-spec-rewrite-decision-default` and the open `core-v3-product-acceptance-gemini-review-0927`.
  Registering a third identity for the same decision would fragment the durable record.
- **N5** (Core Distro staging lane) — already carries open captain items
  `core-stage-chunk1-test-baseline-decision-default` and the three
  `core-stage-chunk4-spec-challenge-decision-*`.
- **B4** (MCode permanent-denial hold) — a live prohibition already recorded as
  `controller-inbox-local-repair-20261013-decision-automatic-receipt`. It is a "do not retry" rule,
  not a pending choice.
