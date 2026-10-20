# CBD G5 Source Refresh — Reconciled Acceptance Report

**Task:** `cbd-g5-source-refresh-0924`
**Date:** 2026-09-24 (Europe/Berlin)
**Author:** Scout (read-only)
**Approved route:** SSH `root@100.117.47.27` → path `/root/agent-work/projects/cbd-data.com/current-cbd-data`
**Scope corrections applied:** Inbox `001.msg` (scope correction: read-only git identity/ref/path-name commands and relevant non-secret documentation only; do not inspect source/test code, do not run tests). The report below is built from documented non-secret markdown plus path/ref/SHA evidence only.

---

## 1. Checkout Identity, Branch / HEAD, Timestamp

| Field | Value | Evidence |
|---|---|---|
| SSH host | `vmi3196300.contaboserver.net` (`root@100.117.47.27`) | `uname -a`, `whoami` |
| Working path | `/root/agent-work/projects/cbd-data.com/current-cbd-data` | SSH `pwd` |
| Committed HEAD | `b187f11e3826715416b7a11a55ea54f7255f2ee5` (detached) | `git rev-parse HEAD` |
| HEAD short SHA | `b187f11` | `git log -1 --format=%h` |
| HEAD commit subject | `chore: add Next.js project source and ignore generated artifacts` | `git log -1 --format=%s` |
| HEAD committer / date | `root <root@vmi3196300.contaboserver.net>  Mon Jun 29 06:19:28 2026 +0200` | `git log -1 --format=%cn <%ce> %ad` |
| Working-tree UTC time at inspection | `2026-09-23T22:05:28Z` | `date -u` |
| Default branch (remote HEAD) | `origin/mid-2026-update` (SHA `9cbb4c9`) | `git branch -a`, `git for-each-ref` |
| Tracked branches present locally | `lane-004-cbd-auth-hardening` (SHA `7134f43`), `mid-2026-update` (SHA `b187f11`, identical to detached HEAD), `origin/master` (SHA `e47d906`), `origin/mid-2026-update` (SHA `9cbb4c9`) | `git for-each-ref --format='%(refname:short) %(objectname:short) %(committerdate:short) %(subject)'` |
| Working tree state | 4 modified PHP files + 1 modified shell script; 5 untracked paths (1 PHP helper dir, 1 PHP boundary helper, 2 markdown docs, 1 `tests/` dir); 1 gitignored `data/lane-b-job-isolation-20260915/` containing one `EVIDENCE.md` | `git status --porcelain`, `find data -type f` |
| `.gitignore` rule that excludes `data/` | `**/data/**` (line 48) | `git check-ignore -v data/lane-b-job-isolation-20260915` |
| Tracked file count on HEAD | `674` | `git ls-files | wc -l` |
| Tracked file count on `lane-004-cbd-auth-hardening` | `675` | `git ls-tree -r lane-004-cbd-auth-hardening | wc -l` |
| Files added on `lane-004-cbd-auth-hardening` vs HEAD | `data/lane-004/artifact.md`, `scripts/sync_amino_canonical.sh` | `git diff --name-only HEAD lane-004-cbd-auth-hardening` |
| Lane-004 branch commit / date | `7134f43cf7012b95ad4a8c92c004223ea98cab79` / `2026-08-02 23:09:51 +0200` / subject `docs: add lane-004 artifact — auth hardening findings and operator-gated items` | `git log -1 lane-004-cbd-auth-hardening` |
| Lane-004 artifact blob SHA | `7fabc30a824c10eadc136a0be0b3b64cb2f3e3ee` | `git rev-parse lane-004-cbd-auth-hardening:data/lane-004/artifact.md` |
| Lane-004 artifact content SHA-256 | `76a53b615f604cac1bf3e8ffeb8021b6c4099edbf76bcbdf0f25f99db4e1aa6b` | `git cat-file -p … | sha256sum` |
| `data/` on disk (gitignored) | `data/lane-b-job-isolation-20260915/EVIDENCE.md` only | `find data -type f` |
| `data/lane-b-job-isolation-20260915/EVIDENCE.md` SHA-256 | `12c350bb5d53cc67999eb7e8f926d05ba4c7bb7a4eceab07da0cf7cd5ee4061d` | `sha256sum` on host |

The committed HEAD `b187f11` is identical to the local branch tip of `mid-2026-update` and matches the HEAD inspected by both `cbd-acceptance-map-0923` and `cbd-g5-evidence-reconcile-0923` on 2026-09-23. No new commits have been added to HEAD since those reports. All new artefact-shaped content on disk (Lane-B enrichment contract helpers, ADR-001, the new contract document, `tests/`, and the lane-b-job-isolation evidence file) is **uncommitted, untracked, or gitignored** and therefore not part of any verifiable acceptance evidence for the committed source.

---

## 2. Commands and Paths Used

All commands were run read-only against the approved route. No remote file was edited, no test was run, no credential, secret, customer data, database, model data, or runtime service was inspected.

| Purpose | Command (exact form) | Result |
|---|---|---|
| SSH access confirm | `ssh -o BatchMode=yes root@100.117.47.27 "echo CONNECT_OK; uname -a; whoami; pwd"` | `CONNECT_OK`; `Linux vmi3196300 …`; `root`; `/root` |
| HEAD identity | `git rev-parse HEAD` and `git log -1 --format='%H%n%h%n%an%n%ae%n%ad%n%s'` | `b187f11e3826715416b7a11a55ea54f7255f2ee5` / `b187f11` / `root` / `root@vmi3196300.contaboserver.net` / `Mon Jun 29 06:19:28 2026 +0200` / `chore: add Next.js project source and ignore generated artifacts` |
| Branch and remote inventory | `git branch -a`, `git remote -v`, `git for-each-ref --format='%(refname:short) %(objectname:short) %(committerdate:short) %(subject)'` | `lane-004-cbd-auth-hardening 7134f43 2026-08-02 docs: add lane-004 artifact — auth hardening findings and operator-gated items`; `mid-2026-update b187f11 2026-06-29 chore: add Next.js project source and ignore generated artifacts`; `origin 9cbb4c9 2026-09-11`; `origin/master e47d906 2026-09-10`; `origin/mid-2026-update 9cbb4c9 2026-09-11` |
| Working-tree state | `git status --porcelain --branch` | See §1 above |
| Tracked file inventory | `git ls-files | wc -l` (HEAD); `git ls-tree -r lane-004-cbd-auth-hardening | wc -l` | `674` on HEAD; `675` on `lane-004-cbd-auth-hardening` |
| Lane-004 vs HEAD diff | `git diff --name-only HEAD lane-004-cbd-auth-hardening` | `data/lane-004/artifact.md`, `scripts/sync_amino_canonical.sh` |
| Phase 5 G4/G5 artefact search across working tree | `find . -path ./.git -prune -o -type f \( -iname '*g4*ledger*' -o -iname '*g4-ledger*' -o -iname '*ledger*g4*' \) -print` and same for `*g5*brief* / *g5*report* / *g5*prep* / *g5-evidence* / *cbd-data-recovery-g5*` and `*cbd-data-recovery-g4*` | No matches in working tree |
| Phase 5 G4/G5 artefact search across all git objects | `git log --all --pretty=format: --name-only --diff-filter=A | grep -E 'cbd-data-recovery'`; `git rev-list --all --objects | grep -E 'cbd-data-recovery|cbd-data-g[1-5]|mini-cbd-gates'` | No matches anywhere in object graph |
| Search for any GATE-CBD or Phase 5 framework reference | `git grep -lE 'GATE-CBD-ENRICH|GATE-CBD-G1|GATE-CBD-G2|GATE-CBD-G3|GATE-CBD-G4|GATE-CBD-G5|cbd-data-recovery|cbd-data-g[1-5]'` | No matches (HEAD) |
| Search for `READY_FOR_M3_REVIEW` marker | `grep -rEi 'READY_FOR_M3_REVIEW|M3_REVIEW' . --include='*.md' --include='*.txt'` | No matches |
| Confirm `data/` is gitignored | `git check-ignore -v data data/lane-b-job-isolation-20260915` | `.gitignore:48:**/data/**` |
| Lane-004 artefact blob identity | `git rev-parse lane-004-cbd-auth-hardening:data/lane-004/artifact.md` | `7fabc30a824c10eadc136a0be0b3b64cb2f3e3ee` |
| Lane-004 artefact content SHA-256 | `git cat-file -p <blob> | sha256sum` | `76a53b615f604cac1bf3e8ffeb8021b6c4099edbf76bcbdf0f25f99db4e1aa6b` |
| Non-secret CBD docs (markdown) | `ls -la docs/operations/` and `cat docs/operations/agent_packs/AGENTS_CBD_DATA.md`, `docs/operations/cbd-data-SECRET_ROTATION_RUNBOOK.md` (header), `docs/operations/cbd-data-BACKUP_VERIFICATION_TEST.md` (header), `docs/operations/CBD_DATA_FIX_PROMPT.md` | See §3 tables for SHAs and line counts |

Evidence that distinguishes the current checkout from other branch names:

- `mid-2026-update` (local) and HEAD `b187f11` resolve to the **same commit**. They are not different sources of evidence; `mid-2026-update` adds no files beyond HEAD.
- `origin/mid-2026-update` and `origin/master` resolve to commits `9cbb4c9` (2026-09-11) and `e47d906` (2026-09-10), which are reachable from HEAD as ancestors in `git log --all` only if fetched; the local checkout has not advanced onto either. These remote tips were checked via `git for-each-ref` and are the only `+` candidates that could in principle carry `data/cbd-data-recovery-*` content. They do not (see search above).
- `lane-004-cbd-auth-hardening` is the only branch that adds any `data/lane-*` artefact, and the artefact it adds is `data/lane-004/artifact.md`, an **auth-hardening markdown record**, not a Phase 5 G4 canary ledger (see §4 reconciliation).

---

## 3. G4 / G5 Artefact Tables

### 3.1 G4 — Bounded canary contract (Phase 5 recovery gate)

Per the earlier audit (`data/cbd-acceptance-map-0923/report.md` §2 and the corrected errata at its foot), the canonical G4 artefact is the bounded canary contract report, expected at `data/cbd-data-recovery-g4-canary-prep/report.md`. Per the brief, this is the artefact the Controller referred to as "G4 ledger".

| Canonical path (expected) | Status at HEAD `b187f11` | Criterion it would support | Evidence |
|---|---|---|---|
| `data/cbd-data-recovery-g4-canary-prep/report.md` | **Absent — unverified at approved checkout** | G4 bounded canary contract (28-min window, S1–S10 / A1–A10 / E1–E16, canary SHAs, D6 deferral) | `find . -path ./.git -prune -o -type f -iname '*cbd-data-recovery-g4*' -print` → no match; `git rev-list --all --objects | grep -E 'cbd-data-recovery-g4'` → no match; `data/` is gitignored at `.gitignore:48` so any local copy would not be tracked. No second source coordinates were provided by the Controller (see §4). |
| `data/cbd-data-recovery-g4-canary-prep/brief.md` (companion brief) | **Absent — unverified at approved checkout** | Companion to G4 contract | Same search; no match. |
| `mini-cbd-gates/report.md` (cited by earlier audit as rubric source) | **Absent** | Phase 5 gate audit trail | `git rev-list --all --objects | grep -E 'mini-cbd-gates'` → no match; `git ls-files | grep -E 'mini-cbd-gates'` → no match. |
| `CONTROLLER_OPS_DECISIONS_20260730_CBD.md` (cited by earlier audit as D6 deferral record) | **Absent** | D6 operator-deferral record | `find . -path ./.git -prune -o -type f -iname 'CONTROLLER_OPS*' -print` → no match in remote repo; same against `git rev-list --all --objects` → no match. |
| Any working-tree file matching `*canary*` | **Absent** | G4 canary language | `grep -rEi 'bounded canary|canary contract|canary execution' docs/` → 0 matches in the approved checkout's `docs/` tree. |
| `READY_FOR_M3_REVIEW` marker anywhere in repo | **Absent** | M3-review readiness claim | `grep -rEi 'READY_FOR_M3_REVIEW|M3_REVIEW' . --include='*.md' --include='*.txt'` → 0 matches. |

No G4 canary ledger is present in the approved checkout, no `data/cbd-data-recovery-g4-canary-prep` directory is tracked or visible in any branch, no canary execution record is present, and the M3-review readiness marker is absent. **G4 cannot be marked `PRESENT` or `READY_FOR_M3_REVIEW` from this evidence.**

### 3.2 G5 — Evidence review (Phase 5 recovery gate)

Per the earlier audit (`data/cbd-acceptance-map-0923/report.md` §4) and the brandon-inbox follow-up, the canonical G5 artefacts are the evidence-prep brief at `data/cbd-data-recovery-g5-evidence-prep/brief.md` and its report `data/cbd-data-recovery-g5-evidence-prep/report.md`.

| Canonical path (expected) | Status at HEAD `b187f11` | Criterion it would support | Evidence |
|---|---|---|---|
| `data/cbd-data-recovery-g5-evidence-prep/brief.md` | **Absent — unverified at approved checkout** | G5 evidence-prep lane brief (5+ dependency-aware items, READY_FOR_M3_REVIEW required) | `find . -path ./.git -prune -o -type f -iname '*cbd-data-recovery-g5*' -print` → no match; `git rev-list --all --objects | grep -E 'cbd-data-recovery-g5'` → no match; `data/` is gitignored so any local copy would not be tracked. The brandon-inbox handoff repeated the earlier audit's claim that the brief exists; this report's evidence shows it does not, at the path and HEAD the audit cited. |
| `data/cbd-data-recovery-g5-evidence-prep/report.md` | **Absent — unverified at approved checkout** | G5 evidence-prep output (rubric checklist, W1–W10 sign-off, READY_FOR_M3_REVIEW) | Same search; no match. |
| `mini-cbd-g2-prep-2/report.md` (cited by earlier audit as rubric source) | **Absent** | G2 prep evidence | No match in working tree, no match in any git object. |
| `READY_FOR_M3_REVIEW` marker | **Absent** | M3-review readiness claim | See G4 table; same absence. |
| Any tracked file containing G5 rubric language (e.g. `W1` through `W10` prerequisites) | **Absent** | G5 prerequisite rubric | No tracked file in HEAD `b187f11` references `CBD G1..G5` or `Phase 5` recovery gates. The only "Phase 5" reference in `docs/` is `APP_UPDATE_BACKUP_CLEANUP_PLAYBOOK.md` line 81, "Phase 5: Rollback Protection" — unrelated to a recovery-gate framework. |

No G5 brief, no G5 rubric, no G5 report, no G5 rubric source is present in the approved checkout or in any tracked branch. **G5 cannot be marked `PRESENT` or `READY_FOR_M3_REVIEW` from this evidence.**

### 3.3 Lane-B enrichment contract artefacts (parallel track, distinct from G4/G5)

These files exist on disk at the working tree but are **uncommitted, untracked, or gitignored**, so they cannot be cited as committed-source acceptance evidence at HEAD `b187f11`. They are listed here only to confirm the brief's instruction to distinguish parallel tracks from the G4/G5 framework.

| Path on disk | Tracked at `b187f11`? | Note |
|---|---|---|
| `Leads gen saas/source/lead-gen-saas/includes/cbd_hetzner_enrichment_contract.php` | No — `??` (untracked) | Companion GATE-CBD-ENRICH-001 helper per its own header; production placement per Lane-B contract, but uncommitted. |
| `Leads gen saas/source/lead-gen-saas/includes/cbd_job_boundary.php` | No — `??` (untracked) | Lane B job-boundary helper. |
| `docs/operations/ADR-001-CBD-ENRICHMENT-QUEUE.md` | No — `??` (untracked) | ADR for queue transport (RabbitMQ). Self-declared status `ACCEPTED` for GATE-CBD-ENRICH-002; **not committed**. |
| `docs/operations/CBD-HETZNER-ENRICHMENT-CONTRACT.md` | No — `??` (untracked) | Architecture-decision document. Self-declared status `PROPOSED — awaiting GATE-CBD-ENRICH-001`; **not committed**. |
| `tests/local/*.php` (7 files) | No — `??` (untracked) | Companion tests per Lane-B contract; **not committed**. |
| `data/lane-b-job-isolation-20260915/EVIDENCE.md` | No — gitignored (`**/data/**` at `.gitignore:48`) | Lane-B local job/isolation evidence; `PASS 14/14` bounded fixture; explicitly notes "not a PRD completion claim". |
| `Leads gen saas/source/lead-gen-saas/{admin.php, cron_drip.php, install.php, leadlists.php}` | No — ` M` (modified vs HEAD) | Working-tree edits; not committed. |
| `scripts/sync_amino_canonical.sh` | No — ` M` (modified vs HEAD); committed as modified on `lane-004-cbd-auth-hardening` (different content there) | Working-tree edits not in HEAD; tracked variant lives only on `lane-004-cbd-auth-hardening`. |

**Distinguishing note required by inbox 001 and the brief:** none of the Lane-B enrichment contract artefacts is a Phase 5 G4 canary ledger or a Phase 5 G5 evidence brief. The Lane-B enrichment contract is a **separate track** (GATE-CBD-ENRICH-001–004), explicitly scoped "not a PRD completion claim" by its own `EVIDENCE.md`. Lane-004 (auth hardening) and Lane-B (enrichment contract) are unrelated to Phase 5 recovery gates G1–G5.

### 3.4 CBD documentation actually present at HEAD `b187f11` (non-secret, committed)

| Path | Lines | SHA-256 | What it provides | Accepts-or-blocks relevance |
|---|---|---|---|---|
| `docs/operations/agent_packs/AGENTS_CBD_DATA.md` | 23 | `ba4fc27fc347d5d82f17e67cf96ad28bbdc6e2ae42e69f400737890a5dda1cb8` | Domain, cPanel user `cbddpolp`, hosting platform, document root, known app status, completion-evidence checklist, current blockers | Background only; **not** G4/G5 evidence |
| `docs/operations/cbd-data-SECRET_ROTATION_RUNBOOK.md` | 123 | `6c6e56634ddd4b8d83f3cf3c7a8ee266edece4c64f0a51b7c9a4346b3ff5f9f1` | Pointer-only rotation procedure for 5 exposed secrets | **G1 root-cause document** (rotation unblocks G1; not yet rotated) |
| `docs/operations/cbd-data-BACKUP_VERIFICATION_TEST.md` | 216 | `4202e2b4de26b80760b211e129c12d439a4ba8dc8ea68cd3648453dc9537a5ac` | Backup artifact path, DB name, naming convention, F1–F10 failure codes, integrity check | **G1-blocked for live execution; protocol itself readable now** |
| `docs/operations/CBD_DATA_FIX_PROMPT.md` | 120 | `ce71265ec6f60c3ebe9c1435bb3124e9d466c456e2edf2cdcb1cddc25bcf0eab` | UI-fix blueprint vs `amino-data.com`; deploy scripts | Out of scope for G4/G5 |
| `AI_RULES.md` | 73 | `e1982da85eca329ec18d279bc7af4d9d98b96893eb02089821597e383662a804` | Next.js tech stack | Context only |
| `docs/AGENTS.md` | — | `46806f03e8ac5e8dbb3099c95838d3670865a94d9e2a5327a0ed9b0b3e5d12fa` | DubzAi agent policy on `/root` | Background only |

**No document in the approved checkout defines the G4 canary contract, the G5 evidence rubric, or the W1–W10 G5 prerequisites.** The Phase 5 G1–G5 recovery-gate framework itself is **not committed anywhere** in the local or remote branch graph reachable from `b187f11`.

---

## 4. Reconciliation of the Controller's Statement

The Controller's brandon-inbox handoff (`/home/hd2admin/brandon-inbox/2026-09-23-cbd-priority-followup.md`, 2026-09-23) states:

> "G4 ledger exists; the named controller acceptance artifact is missing."
> "G5 evidence-prep has `brief.md` only; `report.md` and `READY_FOR_M3_REVIEW` evidence are absent."

The earlier audit (`data/cbd-acceptance-map-0923/report.md`, with its appended corrective errata) and the follow-up reconciliation (`data/cbd-g5-evidence-reconcile-0923/report.md`) both concluded:

> The G4 canary prep report (`data/cbd-data-recovery-g4-canary-prep/report.md`) and the G5 evidence-prep brief (`data/cbd-data-recovery-g5-evidence-prep/brief.md`) and report do **not exist** in the local Firstmate warehouse or in the approved remote checkout at HEAD `b187f11`.

**Reconciliation at the current refresh (2026-09-23, after inbox 001):**

1. **G4 — "ledger exists" cannot be confirmed at the approved checkout.** No file matching `*g4*ledger*` / `*cbd-data-recovery-g4*` / `*canary*` is present in the working tree, in HEAD `b187f11`, in any tracked branch, or in any object reachable from `git rev-list --all`. `READY_FOR_M3_REVIEW` is absent. The earlier audit's claim that a G4 canary contract was "prepared" is, per its own appended errata, unverified and must not be treated as acceptance evidence. The only `data/lane-*` artefact in any branch is `data/lane-004/artifact.md` on `lane-004-cbd-auth-hardening` (blob `7fabc30a…`, content SHA-256 `76a53b61…`); that artefact is an **auth-hardening markdown record** for `lane-004-cbd-auth-hardening`, **not** a Phase 5 G4 bounded canary ledger. **Lane-004 ≠ G4.** The Controller may have meant lane-004; this report does not assume that interpretation.

2. **G5 — "brief exists" cannot be confirmed at the approved checkout.** No file matching `*g5*brief*` / `*cbd-data-recovery-g5*` is present in the working tree, in HEAD `b187f11`, in any tracked branch, or in any object reachable from `git rev-list --all`. The Controller's handoff is consistent with the earlier audit, but the earlier audit itself was retracted in its own errata. Both the brief and the report are absent at the canonical path cited.

3. **No second source coordinates were provided by the Controller.** The handoff names `/root/agent-work/projects/cbd-data.com/current-cbd-data` as the source. No alternative canonical path, no branch name, no remote URL, no controller-side coordinate beyond that source was supplied. The brief explicitly says: "Do not assume the Controller means the same canonical source/path; distinguish that ambiguity explicitly."

4. **Ambiguity is the most likely explanation.** "G4 ledger" is plausibly confusable with the lane-004 artefact (`data/lane-004/artifact.md` on the `lane-004-cbd-auth-hardening` branch), which is the only `data/lane-*` artefact in the repo and which is real and committed to that branch. "G5 brief" is not reconcilable to any file in the approved checkout; the only `data/cbd-data-recovery*` references are all negative.

**Exact path or coordinate needed from the Controller to resolve:**

- For G4: the Controller should name which artefact is meant. If it is the `data/lane-004/artifact.md` blob `7fabc30a824c10eadc136a0be0b3b64cb2f3e3ee` on branch `lane-004-cbd-auth-hardening`, the brief should call it "lane-004" and not "G4 ledger"; if it is a true Phase 5 G4 canary contract, the Controller must supply the canonical path that holds it, because none exists at the paths the earlier audit cited. The brief must not be reclassified into a Phase 5 G4 artefact without that.
- For G5: the Controller must supply the canonical path that holds the brief. The paths the earlier audit cited (`data/cbd-data-recovery-g5-evidence-prep/brief.md`, `data/cbd-data-recovery-g5-evidence-prep/report.md`) are absent at HEAD `b187f11` and at every tracked branch tip. If the brief lives in a different coordinate (a different repo, a different branch, the controller side outside the approved path, or a Firstmate warehouse path other than `data/cbd-data-recovery-g5-evidence-prep/`), the Controller must name that exact path or coordinate.

**No path has been invented.** This report does not infer or assign a path to either artefact.

---

## 5. Offline-Preparation Checklist (PROPOSED / UNACCEPTED)

The following items are **proposed, unaccepted**, and not authorized by any G4/G5 acceptance gate. They are derived from non-secret documentation that does exist at HEAD `b187f11`. They are intentionally limited to operator-free, read-only preparation work; no live credentials, runtime, or deployment are involved.

### 5.1 Items crewmate can do offline without operator input

| # | Item | Source | Why safe |
|---|---|---|---|
| P1 | Produce a `READY` note that re-states what is provably committed at HEAD `b187f11` and what is **not** (G4 ledger, G5 brief/report, M3-review markers). | This report. | Read-only consolidation; no edits. |
| P2 | Sketch a candidate G5 evidence rubric outline from the four committed CBD docs in §3.4 (domain facts, secret-rotation procedure, backup-verification protocol, UI-fix blueprint). Mark every line `PROPOSED` and require re-confirmation once the Controller supplies the missing canonical path. | `AGENTS_CBD_DATA.md`, `cbd-data-SECRET_ROTATION_RUNBOOK.md`, `cbd-data-BACKUP_VERIFICATION_TEST.md`, `CBD_DATA_FIX_PROMPT.md`. | Read-only; explicitly proposed. |
| P3 | Capture the lane-004 artefact (blob SHA, content SHA-256, branch tip, commit metadata) as the **only** `data/lane-*` artefact reachable from the approved checkout, and label it `lane-004 auth hardening` — never `G4 ledger`. | `lane-004-cbd-auth-hardening` branch, blob `7fabc30a…`. | Read-only. |
| P4 | Record the SHA and gitignore basis for `data/` exclusion (`.gitignore:48:**/data/**`) so that any future "G4 ledger" / "G5 brief" claim referencing a `data/` path is read with that fact in mind. | `.gitignore`, `git check-ignore`. | Read-only. |

### 5.2 Items NOT crewmate-actionable (operator-owned blockers)

These block the actual G4/G5 acceptance gates from being marked `PRESENT` or `READY_FOR_M3_REVIEW` and require operator authorization. They are out of scope for this scout.

| # | Item | Owner | Source documenting the block |
|---|---|---|---|
| B1 | Rotate the five PENDING secrets (`RAPIDAPI_KEY`, `REPLICATE_API_KEY`, `CBD_ADMIN_PASS`, `CBD_DB_PASS`, cPanel UAPI token). `cbd_cpanel_token` is currently returning HTTP 401 and is the binding G1 blocker. | Operator (provider dashboards + hidden prompt + pointer-file update). | `cbd-data-SECRET_ROTATION_RUNBOOK.md` (header: `stage-created (do NOT commit yet — BLOCKED item B1)`); `AGENTS_CBD_DATA.md` (`Completion Evidence Checklist`: `Backup artifact verified` and `cPanel cron verified via CLI` both `[ ] BLOCKED`). |
| B2 | Authorize or formally maintain D6 deferral (bounded canary window). The earlier-cited `CONTROLLER_OPS_DECISIONS_20260730_CBD.md` is absent from the approved checkout; current D6 status is unknown and not verifiable from this scout. | Operator. | Earlier audit §3.1 references a D6 deferral decision, but the decision record does not exist at HEAD `b187f11`; no path was verified for it. |
| B3 | Confirm the canonical path or coordinate for the G4 ledger and G5 brief. Without that, no G4/G5 evidence can be cited and no rubric can be finalized offline. | Controller (via Firstmate). | This report §4. |
| B4 | Decide whether lane-004 (`data/lane-004/artifact.md` on `lane-004-cbd-auth-hardening`) is a separate lane artefact or should be relabelled into the Phase 5 G4 framework. The current evidence does not support the latter. | Operator / Controller. | Lane-004 artefact §5 (auth-hardening record, B1-bound items, no canary language). |

### 5.3 Items explicitly out of scope for this scout

| Item | Reason |
|---|---|
| Live cPanel/UAPI/SSH access to `cbddpolp@server401-3` | Forbidden by brief (no live canary, no cPanel/UAPI, no remote writes, no credential work). G1 credentials are out of scope. |
| Live AminoVPS/Tailscale connectivity | Not part of the CBD hosting path (CBD is on Namecheap per `AGENTS_CBD_DATA.md`); not blocking. |
| Tests | Forbidden by brief and reaffirmed by inbox 001. |
| Customer data, exports, databases, model data, runtime service state | Forbidden by brief. |
| Lane-B enrichment contract contents (uncommitted PHP / tests) | Out of G4/G5 scope per inbox 001 ("must distinguish from Phase 5 G4 and must not claim evidence from implementation code"). |

---

## 6. Conclusion and Smallest Next Step

### 6.1 Honest conclusion

- **At the approved checkout (`/root/agent-work/projects/cbd-data.com/current-cbd-data` at HEAD `b187f11e3826715416b7a11a55ea54f7255f2ee5`):** no G4 canary ledger, no G5 evidence-prep brief, no G5 evidence-prep report, no `READY_FOR_M3_REVIEW` marker, no `data/cbd-data-recovery-*` artefact, no `mini-cbd-gates` or `mini-cbd-g2-prep-2` artefact, and no `CONTROLLER_OPS_DECISIONS_20260730_CBD.md` are present, in the working tree or in any tracked branch.
- **At the local branch `lane-004-cbd-auth-hardening`:** one additional artefact exists, `data/lane-004/artifact.md` (blob `7fabc30a824c10eadc136a0be0b3b64cb2f3e3ee`; content SHA-256 `76a53b615f604cac1bf3e8ffeb8021b6c4099edbf76bcbdf0f25f99db4e1aa6b`), which is an **auth-hardening markdown record**, not a Phase 5 G4 canary ledger. `lane-004` and `G4` are different identifiers and must not be conflated.
- **Working tree at inspection time (`2026-09-23T22:05:28Z`):** the only `data/` content on disk is `data/lane-b-job-isolation-20260915/EVIDENCE.md`, which is gitignored and which is a Lane-B local isolation fixture (`PASS 14/14`), explicitly "not a PRD completion claim". Five additional untracked files and one untracked `tests/` directory exist on disk and are Lane-B enrichment contract artefacts (ADR-001, the new contract doc, two PHP helpers, seven test files), but **none is committed** and none can be cited as committed-source G4/G5 acceptance evidence.
- **The earlier audit's "Lane-B enrichment contract GATE-CBD-ENRICH-001–003 DONE" claim cannot be re-confirmed at HEAD `b187f11`** because those files are not in HEAD. They are on disk but uncommitted.
- **The Controller's "G4 ledger exists / G5 brief exists" statement cannot be reconciled to the approved checkout** at the canonical paths cited by the earlier audit. The only ambiguity-resolving path is a direct Controller reply naming the exact coordinate.
- **No G4 gate and no G5 gate is `READY_FOR_M3_REVIEW`** at this approved checkout. The Phase 5 G1–G5 recovery-gate framework itself is not committed anywhere in the local or remote branch graph reachable from `b187f11`.

### 6.2 Smallest next step

1. **Send the Controller (via Firstmate, not via this scout) one question** with three explicit sub-questions, no path assumed:

   - Is "G4 ledger" the lane-004 auth-hardening artefact `data/lane-004/artifact.md` (blob `7fabc30a824c10eadc136a0be0b3b64cb2f3e3ee` on branch `lane-004-cbd-auth-hardening`)? If yes, the brief must call it `lane-004` and not `G4 ledger`.
   - If "G4 ledger" is meant to be a Phase 5 G4 bounded canary contract, what is the **exact canonical path** (and, if it is on a different branch or repo, the **exact branch name / remote / commit SHA**) that holds it?
   - If "G5 brief" is meant to be a Phase 5 G5 evidence-prep brief, what is the **exact canonical path** that holds it? The earlier-cited `data/cbd-data-recovery-g5-evidence-prep/brief.md` is absent at HEAD `b187f11`.

2. **Until the Controller replies, do not dispatch** a G5 evidence-prep lane or a G4 canary lane. Both rely on canonical artefacts that this scout could not locate at the approved checkout.

3. **Treat the four committed CBD docs in §3.4** as the only **proven** CBD-side background. Any G5 rubric draft built from them must be labelled `PROPOSED` and must not be cited as `READY_FOR_M3_REVIEW`.

4. **Operator-owned blockers B1, B2, B3, B4** (in §5.2) remain on the operator's plate. This scout cannot advance G1, D6, the missing path resolution, or the lane-004 relabelling decision.

### 6.3 What this report does NOT claim

- It does **not** claim G4 is `PRESENT`, `PREPARED`, `EXECUTED`, or `READY_FOR_M3_REVIEW`.
- It does **not** claim G5 is `PARTIALLY PRESENT`, `PRESENT`, or `READY_FOR_M3_REVIEW`.
- It does **not** claim the Lane-B enrichment contract gates (GATE-CBD-ENRICH-001–003) are `DONE` at the committed source — the helper files and ADR/contract are present on disk only and uncommitted at HEAD `b187f11`.
- It does **not** claim lane-004's `data/lane-004/artifact.md` is a Phase 5 G4 ledger.
- It does **not** verify any credentials, secrets, live runtime state, database content, customer data, model data, or runtime service. (Forbid list applied: no credential read, no `.env`, no secret file, no customer/export, no database, no model data, no runtime service, no cPanel/UAPI, no tests, no remote edit or commit, no deployment/service change, no other host.)
- It does **not** contact the Controller.
- It does **not** invent a path for the G4 ledger or G5 brief.

---

## Appendix A — Inbox acknowledgements

| Msg | Path | Action | Notes |
|---|---|---|---|
| `001.msg` | `/home/hd2admin/kun-agent-workspace/state/cbd-g5-source-refresh-0924.inbox/001.msg` | Read; recorded as bounded scope correction; moved to `handled/` | Stop inspecting source/test code; stay on git identity/ref/path-name commands and non-secret documentation; report must distinguish lane-004 from Phase 5 G4; must not claim evidence from implementation code. |

## Appendix B — Local Firstmate warehouse reconciliation

Local files relied on as evidence (read-only):

- `/home/hd2admin/kun-agent-workspace/data/cbd-acceptance-map-0923/report.md` — the earlier audit (with appended corrective errata).
- `/home/hd2admin/kun-agent-workspace/data/cbd-g5-evidence-reconcile-0923/report.md` — the follow-up reconciliation that established the absence findings at the same HEAD `b187f11`.
- `/home/hd2admin/kun-agent-workspace/data/cbd-g5-readiness-blueprint-0923/report.md` — the readiness blueprint that confirmed the same absence findings.
- `/home/hd2admin/brandon-inbox/2026-09-23-cbd-priority-followup.md` — the Controller handoff whose G4/G5 claims this report reconciles.
- `/home/hd2admin/kun-agent-workspace/state/cbd-g5-source-refresh-0924.inbox/001.msg` — the scope correction.

The warehouse contains no other CBD-named directories beyond `cbd-acceptance-map-0923/`, `cbd-g5-evidence-reconcile-0923/`, `cbd-g5-readiness-blueprint-0923/`, and `cbd-g5-source-refresh-0924/`. There is no `data/cbd-data-recovery-g5-evidence-prep/` or `data/cbd-data-recovery-g4-canary-prep/` directory in the local warehouse.
