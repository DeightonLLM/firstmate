# CBD-Data G5 Evidence-Readiness Blueprint

**Task:** `cbd-g5-readiness-blueprint-0923`
**Date:** 2026-09-23
**Scope:** Verified local blueprint for CBD-Data G5 evidence readiness after reconciliation confirmed all previously cited G4/G5 lane outputs are absent from warehouse and remote checkout at HEAD `b187f11e3826715416b7a11a55ea54f7255f2ee5`.
**Access:** SSH confirmed to `root@100.117.47.27:/root/agent-work/projects/cbd-data.com/current-cbd-data`

---

## 1. Verification Summary

SSH inspection confirmed the following documents exist in the remote checkout at `b187f11`:

| Document | Path | Lines | Status |
|---|---|---|---|
| AI Rules | `AI_RULES.md` | 73 | ✅ Verified |
| CBD Agent Context | `docs/operations/agent_packs/AGENTS_CBD_DATA.md` | 23 | ✅ Verified |
| UI Fix Prompt | `docs/operations/CBD_DATA_FIX_PROMPT.md` | 120 | ✅ Verified |
| Backup Verification Test | `docs/operations/cbd-data-BACKUP_VERIFICATION_TEST.md` | 216 | ✅ Verified (draft) |
| Secret Rotation Runbook | `docs/operations/cbd-data-SECRET_ROTATION_RUNBOOK.md` | 123 | ✅ Verified (staged) |
| Next.js app source | `src/` | — | ✅ Verified |
| PHP app inspection snapshot | `app_inspect/cbd-data/` | — | ✅ Verified (9.8 MB) |
| CBD deploy/diagnostic scripts | `scripts/deploy_cbd_*.py`, `scripts/test_cbd_*.py`, `scripts/list_cbd_*.sh` | — | ✅ Verified |

The earlier report's cited G4/G5 lane outputs are confirmed absent from both the warehouse and the remote checkout. No G4 canary contract, no G5 brief, no G5 rubric, no G5 output exists anywhere at HEAD `b187f11`.

---

## 2. Evidence Triage — Four Buckets

### Bucket A: Verifiable Offline Source Material

These documents exist at `b187f11` and require no credentials, no G1/G2/G3 resolution, and no operator action to read.

| Artifact | What it provides | Gating relevance |
|---|---|---|
| `AI_RULES.md` (73 lines) | Next.js tech stack: App Router, TypeScript, Shadcn/UI, Tailwind, React Hook Form + Zod, Lucide React, Recharts, Sonner, `src/lib/utils.ts` patterns | Context only; not a G4/G5 gate input |
| `docs/operations/agent_packs/AGENTS_CBD_DATA.md` (23 lines) | Domain: `cbd-data.com`; cPanel user: `cbddpolp`; server: `server401-3` / `68.65.123.217`; document root: `/home/cbddpolp/public_html/`; known app status: HTTP 200 (2026-05-08); completion checklist shows `Backup artifact verified` and `cPanel cron verified` as `[ ] BLOCKED`; SSH access: publickey rejected | **G1 account context** — documents the blocked state that G1 must resolve |
| `docs/operations/cbd-data-BACKUP_VERIFICATION_TEST.md` (216 lines) | Backup artifact path on controller: `/root/dropbox_ephemeral/namecheap_backups/cbddpolp_cbd-data.com/`; DB name: `cbddpolp_saas`; artifact naming: `cbddpolp_cbd-data.com_files_<YYYYMMDD>.tar.gz`, `cbddpolp_cbd-data.com_db_<YYYYMMDD>.sql.gz`, with SHA-256 sidecars; 10 failure codes (F1–F10); dry-run tar integrity check; content spot-checks for `cron_drip.php`, `routes/`, `config/`, `app/`, `.env`-must-be-absent rule | **G1-unblocked artifact review protocol** — readable now, executable only after G1 |
| `docs/operations/cbd-data-SECRET_ROTATION_RUNBOOK.md` (123 lines) | 5 exposed secrets (all PENDING rotation): `RAPIDAPI_KEY`, `REPLICATE_API_KEY`, `CBD_ADMIN_PASS`, `CBD_DB_PASS`, cPanel UAPI token; pointer files all in `/root/.secrets/`; hidden-prompt collection procedure; verification checklist (8 items, no live deploy); no-commit directive on staged file | **G1 root cause document** — rotating these 5 secrets is the unblock action for G1 |
| `docs/operations/CBD_DATA_FIX_PROMPT.md` (120 lines) | Blueprint: `amino-data.com` CSS vars as template for `cbd-data.com`; ONLY difference: `--accent: #c85719` (orange) vs `--accent: #00388F` (blue); two-logo bug in `.theme-logo`; deploy scripts: `deploy_cbd_theme_fix.py`, `deploy_leadlists.py` to `cbddpolp@cbd-data.com` via cPanel API | **Out-of-scope for G4/G5** — UI fix is a separate parallel workstream; not a gate input |
| `src/` (Next.js source) | 6 subdirs: `app/`, `components/`, `hooks/`, `lib/`, `ui/`, `components/ui/`; UI components: Shadcn (resizable, checkbox, radio-group, sheet, toggle, form, textarea, pagination, alert, card, drawer, menubar, input, input-otp, collapsible, sidebar, dialog, tooltip, navigation-menu, breadcrumb, switch, popover); custom components: tools-section, footer, tools-directory, hero, courses-section, navigation, courses-directory, ticker | **App source snapshot at b187f11** — can serve as SHA reference for "app unchanged since backup" |
| `app_inspect/cbd-data/` (9.8 MB PHP snapshot) | 30+ PHP files: `admin.php`, `api_dashboard.php`, `api_keys.php`, `api_wrapper.php`, `cron_drip.php`, `dashboard.php`, `leadlists.php`, `pricing.php`, `stripe_webhook.php`, `subscription.php`, `webhook_scrape.php`, `includes/theme_bootstrap.php`, `config/`, `assets/`, `composer.json` | **Live PHP app snapshot** — used as reference for UI fix and backup completeness check |
| `scripts/` (CBD deploy/diagnostic scripts) | 5 deploy scripts, 1 test script, 3 list scripts | **Tooling present at b187f11** — available for post-G1 operations |

**Bucket A verdict:** Seven document families confirmed present. All are readable offline. None constitutes G4 or G5 gate evidence.

---

### Bucket B: G1 / D6 Operator Gates

These gates are owned by the operator. No crewmate action can advance them.

#### G1 — Credentials (BLOCKED_OPERATOR_INPUT)

**What G1 requires:** All five secrets currently marked PENDING in the runbook audit log must be rotated at their providers, and local pointer files in `/root/.secrets/` must be updated with new values (no live deploy yet).

| Secret | Pointer File | Exposure Date | Rotation Status |
|---|---|---|---|
| `RAPIDAPI_KEY` | `/root/.secrets/rapidapi_key.txt` | 2026-05-08 | **PENDING** |
| `REPLICATE_API_KEY` | `/root/.secrets/replicate_api_key.txt` | 2026-05-08 | **PENDING** |
| `CBD_ADMIN_PASS` | `/root/.secrets/cbd_admin_login.txt` | 2026-05-09 | **PENDING** |
| `CBD_DB_PASS` | `/root/.secrets/cbd_db_pass` | 2026-05-09 | **PENDING** |
| cPanel UAPI token | `/root/.secrets/cbd_cpanel_token` | 2026-05-09 | **PENDING** (HTTP 401 on last check) |

**What unblocks G1:** Operator follows `cbd-data-SECRET_ROTATION_RUNBOOK.md` to rotate all five secrets via their provider dashboards, using hidden-prompt collection (never typing secrets into chat). After pointer files are updated, a cPanel UAPI smoke test confirms G1 resolved. **This is the single highest-leverage operator action.**

#### D6 — Canary Authorization (BLOCKED_OPERATOR_INPUT)

**What D6 requires:** Operator decision on the bounded canary execution window. Earlier deferral is documented in a referenced `CONTROLLER_OPS_DECISIONS_20260730_CBD.md` that does not exist at `b187f11` — its contents and current status are **UNKNOWN** and must be confirmed directly with the operator before any canary work can proceed.

**What unblocks D6:** Operator either (A) authorizes a bounded canary window with UTC time range and traffic percentage, or (B) formally maintains indefinite deferral. The canonical decision record itself is missing.

**Bucket B verdict:** Two operator gates. G1 is the prerequisite for everything downstream (G3, G4, G5, backup execution). D6 controls canary execution timing. Neither can be advanced by this crewmate.

---

### Bucket C: Evidence That Can Only Exist After G4

G4 = bounded canary contract execution. Because the G4 lane was never instantiated, no G4 evidence exists. The following items would be G4 outputs and are structurally impossible to produce before G4 completes:

| Would-be G4 output | Why it cannot exist yet |
|---|---|
| Canary execution record (S1–S10 pass/fail, A1–A10, E1–E16) | Canary has never executed; no lane produced this |
| Canary artifact SHA registry (`.cbd-workload-disabled`, `.cbd-legacy-routes-disabled`, etc.) | Same — no execution, no SHA to register |
| G4 gate status (CONTRACT PREPARED or EXECUTED) | No contract exists to be prepared or executed |
| G4→G5 handoff artifact | No G4 output means no handoff |
| G5 evidence-review checklist | G5 lane was never created; its brief is absent |
| G1/G2/G3 completion sign-off | G1 is blocked (operator action needed); G2 is informational-only for Namecheap-hosted CBD; G3 is downstream of G1 |

**Bucket C verdict:** Entirely empty. There is nothing to bridge from G4 to G5 because G4 never happened. Any claim of G4 completion or G5 readiness in the earlier report is unsubstantiated.

---

### Bucket D: Missing Canonical G5 Rubric / Owner

This is the critical gap.

| Item | Status | Evidence |
|---|---|---|
| G5 lane brief | ❌ **MISSING** — `data/cbd-data-recovery-g5-evidence-prep/brief.md` does not exist in warehouse or remote checkout | Confirmed absent at b187f11 |
| G5 evidence-review rubric | ❌ **MISSING** — no rubric document exists anywhere at b187f11 | Earlier report described one but it was never created |
| G5 rubric owner | ❌ **UNKNOWN** — no designated owner in any present document | AGENTS_CBD_DATA.md does not name a G5 owner; no `CONTROLLER_OPS_DECISIONS_20260730_CBD.md` at b187f11 |
| G5 lane report | ❌ **MISSING** — no output from a lane that was never instantiated | — |
| G5 W1–W10 prerequisites | ❌ **UNKNOWN** — earlier report cited these from a non-existent G4 canary prep report | No source for these |
| Canonical G5 rubric source | ❌ **MISSING** — earlier report cited `mini-cbd-gates/report.md` and `mini-cbd-g2-prep-2/report.md` as rubric sources; neither exists | Non-existent file references |

**Unknowns that must be resolved before G5 can be planned:**
1. Who owns the G5 evidence-review gate? (No name found in any present document.)
2. What is the G5 acceptance rubric — the specific criteria against which G4 output would be reviewed? (No document.)
3. Were the G5 W1–W10 prerequisites ever defined in a committed artifact? (No evidence they were.)
4. What is the current D6 decision status — deferral maintained or window authorized? (Decision record absent from b187f11.)
5. Was there ever a G5 brief in a prior commit, since deleted? (No evidence at b187f11 or its branch history.)

**Bucket D verdict:** No G5 rubric, no G5 owner, no G5 brief, no G5 lane. This is the root absence — all earlier acceptance claims were projections, not evidence.

---

## 3. Gap Summary

```
Bucket A (offline-ready)      Bucket B (operator gates)    Bucket C (post-G4 only)    Bucket D (absent entirely)
─────────────────────────    ──────────────────────────    ──────────────────────    ────────────────────────
AI_RULES.md ✅               G1: 5 secrets PENDING ❌     Canary execution record ❌  G5 brief ❌
AGENTS_CBD_DATA.md ✅         D6: decision record MISSING ❌ G4→G5 handoff ❌           G5 rubric ❌
BACKUP_VERIFICATION_TEST ✅                             G5 checklist ❌              G5 owner ❌
SECRET_ROTATION_RUNBOOK ✅                               G1/G2/G3 sign-off ❌         G5 W1–W10 ❌
CBD_DATA_FIX_PROMPT ✅                                                                  D6 current status ❌
src/ snapshot ✅                                                                  CONTROLLER_OPS_DECISIONS_*
app_inspect/cbd-data/ ✅                                                           20260730_CBD.md ❌
scripts/ ✅
```

---

## 4. Unknowns Explicitly Flagged

The following facts are claimed in present documents but cannot be verified from sources at `b187f11`:

1. **D6 deferral status:** `cbd-data-SECRET_ROTATION_RUNBOOK.md` and `AGENTS_CBD_DATA.md` reference a prior D6 operator decision, but `CONTROLLER_OPS_DECISIONS_20260730_CBD.md` does not exist at b187f11. Whether deferral is currently in force is **UNKNOWN** and must be confirmed with the operator.

2. **G5 W1–W10 prerequisites:** Earlier report cited these from `cbd-data-recovery-g4-canary-prep/report.md` which does not exist. Their definitions and current status are **UNKNOWN**.

3. **AminoVPS/Tailscale G2 claim:** `AGENTS_CBD_DATA.md` notes "informational only; CBD is on Namecheap not AminoVPS." Whether a separate AminoVPS validation was completed or deferred is **UNKNOWN** — no document at b187f11 addresses it.

4. **Lane-B enrichment contract:** Earlier report claimed GATE-CBD-ENRICH-001–003 were DONE. No enrichment contract files exist at b187f11. Whether this track was ever in this repo or exists elsewhere is **UNKNOWN**.

5. **G5 owner:** No document at b187f11 names a responsible party for the G5 evidence-review gate.

---

## 5. Smallest Next Safe Input

**For G5 evidence readiness to begin (crewmate-actionable, no operator needed):**

1. **Create a G5 lane brief.** The smallest safe input is a brief for `cbd-data-recovery-g5-evidence-prep` that uses only documents that actually exist at b187f11 as sources:
   - `AGENTS_CBD_DATA.md` for domain/cPanel/account context and current blockers
   - `cbd-data-BACKUP_VERIFICATION_TEST.md` for the artifact-review protocol
   - `cbd-data-SECRET_ROTATION_RUNBOOK.md` for the G1 unblock path
   - `AI_RULES.md` for app-stack context
   - `src/` and `app_inspect/cbd-data/` for SHA reference

   The brief must **not** reference non-existent files (`mini-cbd-gates/report.md`, `mini-cbd-g2-prep-2/report.md`, `CONTROLLER_OPS_DECISIONS_20260730_CBD.md`, `data/cbd-data-recovery-g4-canary-prep/report.md`).

2. **Designate a G5 owner.** AGENTS_CBD_DATA.md does not name one. Before any G5 lane runs, someone must own the evidence-review gate. **Recommendation: operator names a G5 owner before approving the brief.**

**For G4 to become reachable (operator-actionable, highest leverage):**

- Rotate the five PENDING secrets per `cbd-data-SECRET_ROTATION_RUNBOOK.md`. This resolves G1, which unblocks G3 and enables backup capture. G4 canary execution cannot proceed without G1 resolved.

**For D6 to be resolved (operator-actionable):**

- Confirm whether the prior D6 deferral is still in force, or authorize a bounded canary window. The decision record `CONTROLLER_OPS_DECISIONS_20260730_CBD.md` is absent — the operator must produce a current D6 status.

---

## 6. What This Report Does NOT Claim

- This report does **not** claim G4 is complete, prepared, or reachable.
- This report does **not** claim G5 evidence exists or is preparable offline without G4.
- This report does **not** claim Lane-B enrichment gates are DONE — no enrichment contract files exist at b187f11.
- This report does **not** verify any credentials, live runtime state, or database content.
- This report does **not** execute any G4/G5 gate or contact the controller.
