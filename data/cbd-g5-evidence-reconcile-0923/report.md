# CBD G5 Evidence Reconciliation — Scout Report

**Task:** `cbd-g5-evidence-reconcile-0923`
**Date:** 2026-09-23
**Scope:** Verify CBD acceptance evidence contradiction; identify canonical G5 rubric location and offline-preparable evidence.

---

## 1. Evidence Inventory: What Was Checked

### 1.1 Local warehouse

| Path checked | Result |
|---|---|
| `data/cbd-acceptance-map-0923/report.md` | ✅ Present — the earlier report |
| `data/cbd-acceptance-map-0923/brief.md` | ✅ Present |
| `data/cbd-data-recovery-g5-evidence-prep/brief.md` | ❌ **ABSENT** — no such directory exists in warehouse |
| `data/cbd-data-recovery-g5-evidence-prep/report.md` | ❌ **ABSENT** — no such directory exists in warehouse |
| `data/cbd-data-recovery-g4-canary-prep/report.md` | ❌ **ABSENT** — no such directory exists in warehouse |
| `mini-cbd-gates/report.md` | ❌ **ABSENT** — not a warehouse path |
| `mini-cbd-g2-prep-2/report.md` | ❌ **ABSENT** — not a warehouse path |
| `CONTROLLER_OPS_DECISIONS_20260730_CBD.md` | ❌ **ABSENT** — not a warehouse path |

Warehouse contents (`/home/hd2admin/kun-agent-workspace/data/`):
`cbd-acceptance-map-0923/` and `cbd-g5-evidence-reconcile-0923/` are the only CBD-named entries. `cbd-data-recovery-g5-evidence-prep/` and `cbd-data-recovery-g4-canary-prep/` do not exist.

### 1.2 Remote repo — `root@100.117.47.27:/root/agent-work/projects/cbd-data.com/current-cbd-data` at HEAD `b187f11`

| Path checked | Result |
|---|---|
| `data/cbd-data-recovery-g5-evidence-prep/brief.md` | ❌ `fatal: path does not exist in b187f11` |
| `data/cbd-data-recovery-g5-evidence-prep/report.md` | ❌ `fatal: path does not exist in b187f11` |
| `data/cbd-data-recovery-g4-canary-prep/report.md` | ❌ `fatal: path does not exist in b187f11` |
| `mini-cbd-gates/report.md` | ❌ `fatal: path does not exist in b187f11` |
| `mini-cbd-g2-prep-2/report.md` | ❌ `fatal: path does not exist in b187f11` |
| `CONTROLLER_OPS_DECISIONS_20260730_CBD.md` | ❌ `fatal: path does not exist in b187f11` |
| `includes/cbd_hetzner_enrichment_contract.php` | ❌ `fatal: path does not exist in b187f11` |
| `tests/local/cbd-hetzner-enrichment-contract-test.php` | ❌ `fatal: path does not exist in b187f11` |
| `docs/operations/ADR-001-CBD-ENRICHMENT-QUEUE.md` | ❌ `fatal: path does not exist in b187f11` |
| `BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/status.txt` | ❌ not in repo |

**Git HEAD:** `b187f11e3826715416b7a11a55ea54f7255f2ee5` (detached, matches earlier report)  
**Default branch:** `origin/mid-2026-update`  
**Current branch:** `lane-004-cbd-auth-hardening` (local)

### 1.3 CBD-specific files actually present in remote repo at b187f11

| Path | Description |
|---|---|
| `AI_RULES.md` | Next.js tech-stack guidelines (73 lines) |
| `docs/operations/agent_packs/AGENTS_CBD_DATA.md` | CBD agent context, domain/cPanel/account facts, blockers |
| `docs/operations/CBD_DATA_FIX_PROMPT.md` | UI fix prompt (amino-data blueprint) |
| `docs/operations/cbd-data-BACKUP_VERIFICATION_TEST.md` | Backup verification test (DRAFT, BLOCKED by G1) |
| `docs/operations/cbd-data-SECRET_ROTATION_RUNBOOK.md` | Secret rotation runbook |
| `app_inspect/cbd-data/` | PHP source snapshot of live cbd-data.com app |
| `scripts/deploy_cbd_*.py` | CBD deployment scripts |
| `scripts/test_cbd_uapi.py`, `scripts/list_cbd_*.sh` | CBD diagnostic scripts |
| `src/` | Next.js application source (cbd-data.com public site) |

---

## 2. Contradiction Resolution

### Claim 1 — Earlier report (§4.1): "G5 evidence-prep brief: `data/cbd-data-recovery-g5-evidence-prep/brief.md` ✅ Present"

**Verdict: Incorrect.** The directory `data/cbd-data-recovery-g5-evidence-prep/` does not exist in the local warehouse. The brief was never written. The earlier report asserted this file existed without it being present.

### Claim 2 — Controller handoff: "G5 evidence-prep has `brief.md` only; `report.md` and `READY_FOR_M3_REVIEW` evidence are absent"

**Verdict: Incorrect (partially).** The brief does not exist either. The controller handoff repeated the earlier report's claim without independent verification.

### Claim 3 — "Later read-only check found both named files absent from the remote repo at HEAD b187f11"

**Verdict: Correct.** Both `data/cbd-data-recovery-g5-evidence-prep/brief.md` and `report.md` are absent from the remote repo. This is expected — those are warehouse task paths, not source repo paths. But the "later check" finding them absent confirmed they were never landed anywhere.

### Claim 4 — Earlier report (§3.1): "G4 canary prep report: `data/cbd-data-recovery-g4-canary-prep/report.md` (489 lines, READY_FOR_M3_REVIEW) ✅ Present"

**Verdict: Incorrect.** This directory does not exist in the warehouse. The G4 canary contract described in the earlier report (28-min window, S1–S10, A1–A10, E1–E16, canary SHAs, D6 deferral) is not backed by any file that can be verified.

### Claim 5 — Earlier report (§5): Lane-B enrichment contract evidence (GATE-CBD-ENRICH-001–004, helper checksums, test suite SHAs)

**Verdict: Incorrect.** All files cited (`includes/cbd_hetzner_enrichment_contract.php`, `tests/local/cbd-hetzner-enrichment-contract-test.php`, `docs/operations/ADR-001-CBD-ENRICHMENT-QUEUE.md`, `BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/status.txt`) do not exist in the remote repo at b187f11. The "Lane-B enrichment contract" described in the earlier report is not present in the committed codebase.

---

## 3. Root Cause Analysis

The earlier `cbd-acceptance-map-0923` report contains two categories of claim:

**Category A — Reputable references** (confirmed present):
- CBD domain, cPanel account, and hosting platform facts from `docs/operations/agent_packs/AGENTS_CBD_DATA.md`
- CBD backup verification test and secret rotation runbook from `docs/operations/`
- CBD app inspection directory in `app_inspect/cbd-data/`
- Next.js project structure in `src/`

**Category B — Unverified/hallucinated references** (confirmed absent):
- `data/cbd-data-recovery-g5-evidence-prep/brief.md` — never created
- `data/cbd-data-recovery-g5-evidence-prep/report.md` — never created
- `data/cbd-data-recovery-g4-canary-prep/report.md` — never created
- `mini-cbd-gates/report.md` — not a warehouse path; no such file
- `mini-cbd-g2-prep-2/report.md` — not a warehouse path; no such file
- `CONTROLLER_OPS_DECISIONS_20260730_CBD.md` — not in warehouse or remote repo
- Lane-B enrichment contract files — not in remote repo

The earlier report appears to have described intended or planned lane outputs as if they already existed, rather than documenting what was actually present.

---

## 4. Canonical G5 Rubric/Brief/Output Location

There is **no canonical G5 brief, rubric, or output location** for CBD-Data Phase 5 gates. The `cbd-data-recovery-g5-evidence-prep` lane was never instantiated — neither its brief nor its report exist.

The G5 gate taxonomy described in the earlier report (G1→G2→G3→G4→G5, with D6 operator-authorization gate) is a planning construct with no committed evidence trail.

What does exist that could serve as G5 rubric inputs:
- `docs/operations/agent_packs/AGENTS_CBD_DATA.md` — domain facts, current blockers
- `docs/operations/cbd-data-BACKUP_VERIFICATION_TEST.md` — backup test protocol (draft, G1-blocked)
- `docs/operations/cbd-data-SECRET_ROTATION_RUNBOOK.md` — rotation runbook
- `docs/operations/CBD_DATA_FIX_PROMPT.md` — UI fix specification

---

## 5. What Can Be Prepared Offline Without Blocked G1/D6 Gates

G5 is defined as an "evidence review" gate that executes after G4 completes. Because neither G4 nor G5 lanes produced outputs, no review checklist exists to prepare offline. However, the following **structural and documentation groundwork** can be done now without G1/G2/G3 resolution:

| Item | Source | Blocked? | Notes |
|---|---|---|---|
| Domain/account facts audit | `docs/operations/agent_packs/AGENTS_CBD_DATA.md` | No | cPanel user, hosting platform, document root, current status |
| Backup verification protocol (draft) | `docs/operations/cbd-data-BACKUP_VERIFICATION_TEST.md` | Partially (G1-blocked for live execution; protocol itself readable) | 216-line draft; artifact path, DB name, backup structure documented |
| Secret rotation runbook | `docs/operations/cbd-data-SECRET_ROTATION_RUNBOOK.md` | No | Pointer-only secret handling procedure |
| UI fix specification | `docs/operations/CBD_DATA_FIX_PROMPT.md` | No | Amino-data blueprint comparison; two-logo and aesthetic issues |
| Next.js project SHA snapshot | `src/` in remote repo | No | `b187f11` is the committed HEAD |
| CBD app inspection snapshot | `app_inspect/cbd-data/` | No | PHP source snapshot of live app |

**What cannot be prepared offline:**
- Any G4 canary contract evidence (G4 lane never ran)
- Any G5 rubric checklist (G5 lane never ran)
- Any G1/G2/G3 completion sign-off
- Any Lane-B enrichment contract evidence
- Any canary SHAs, kill-switch registry, or bounded execution criteria

---

## 6. Uncertainty

- **Unknown:** Whether the G4/G5 gate framework and Lane-B enrichment contract were ever committed to a different branch or commit. The current HEAD `b187f11` and all visible branches (`mid-2026-update`, `master`) do not contain these files.
- **Unknown:** Whether `mini-cbd-gates/report.md` or `mini-cbd-g2-prep-2/report.md` existed at an earlier commit and were deleted, or were always a misreference.
- **Unknown:** Whether the controller handoff's claim about the G5 brief was based on a prior brief that was since deleted.

---

## 7. Verdict

> **The earlier report's G5 brief claim is not authoritative.**  
> `data/cbd-data-recovery-g5-evidence-prep/brief.md` does not exist — it was never created.  
> The controller handoff repeated this claim without verification.  
> The "later read-only check" (confirmed by this scout) is the authoritative finding: the files are absent.

> **The G5 evidence-prep lane was never instantiated.** No brief, no rubric, no output. There is no G5 evidence to reconcile — there is a G5 lane that was planned but not delivered.

> **No G5 evidence can be prepared offline** without first creating the lane. The CBD app inspection data and operations docs in the remote repo are useful background, but they are not G5-specific evidence review artifacts.

---

## 8. Smallest Next Safe Action

1. **Create the G5 evidence-prep lane properly** (`cbd-data-recovery-g5-evidence-prep`). The lane needs a brief first — one that references the actual canonical sources (`docs/operations/agent_packs/AGENTS_CBD_DATA.md`, `docs/operations/cbd-data-BACKUP_VERIFICATION_TEST.md`, etc.) rather than non-existent files. This can be done read-only against the remote repo.

2. **Do not claim G4 is "PRESENT — CONTRACT PREPARED"** without verifiable evidence. The G4 canary prep report does not exist. If a bounded canary contract was prepared, it needs to be re-created and committed.

3. **Do not claim Lane-B enrichment gates are "DONE"** without verifiable evidence. The cited files (`includes/cbd_hetzner_enrichment_contract.php`, `ADR-001-CBD-ENRICHMENT-QUEUE.md`, etc.) are not in the committed codebase at `b187f11`.

4. **The CBD project structure at b187f11** is a Next.js public site with PHP app inspection data — consistent with a CBD-Data recovery programme in early/planning stages, not with a project that has completed G4 canary contracts or Lane-B enrichment gates.
