# Adversarial audit — CBD-Data infrastructure PRD v1.0

**Audit date:** 2026-10-18  
**Scope:** Document-only verification of `data/prds/cbd-data-prd-v1.0.md`; no PRD, project, host, DNS, or service was changed.  
**Inputs read in full:** the canonical v3 PRD (`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`, 2,071 lines; the requested `..._PD_V3.md` does not exist), `docs/system-context/PRD_TRACEABILITY.md`, `docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md`, target PRD (768 lines), and the Whoosh PRD template (1,615 lines). Line references below are repository-relative.

## Verdict

The PRD mostly preserves the critical boundary: Gate-CBD-ENRICH-003 is a bounded private broker/status-helper slice, and it says Gate-004 and cutover are unauthorized. It does **not** claim the accepted end-to-end Hostinger-to-Hetzner chain exists. It also carries all eight product functions and explicitly records that the active worker placement on AminoVPS conflicts with v3's Hetzner target.

Two material findings remain:

1. **BLOCKED — overstated TDD/check evidence.** PRD lines 68–69 state RED/GREEN/REFACTOR and a full local-suite `CHECK_PASS` as evidenced. The YAML ledger says the referenced files were reconstructed and that underlying TDD/checker outputs were not retained and are unverified. The human-readable traceability table and delivery map say the local continuation was independently checked and passed. This is a direct source conflict, not a basis for silently choosing either reading. See the OPEN conflict below.
2. **BLOCKED — provenance labeling/count is not reliable.** The file has 90 bracketed provenance-label occurrences, but that count includes the three label definitions, the Section 7 taxonomy, and the summary—not 90 evidence rows. There are 88 lines containing those labels. `[PER v3]` is defined but not actually used to label a specific requirement row or claim in the PRD body; it appears only in the legend/taxonomy and summary. The summary nevertheless calls out many body sections as applied. Source: `data/prds/cbd-data-prd-v1.0.md:57-60,332,758-764`; command evidence recorded under Validation.

## 1. Enrichment gate — bounded slice, no authorization lift

The scope boundary is properly stated in PRD `:68,76-81,176-177,263-270,768`: the reported slice is private RabbitMQ `/cbddata` bootstrap plus local `cbd_initial_job_status()` helper; publisher/consumer adapter, `project_id`, idempotency key, durable persistence/restore, and accepted end-to-end Hostinger-to-Hetzner flow remain unproven; Gate-004/cutover remain unauthorized.

The delivery map independently limits Gate-003 to private queue bootstrap, says application cutover, worker rollout, staging, and production acceptance remain out of scope, and describes full job identity/idempotency/ingest as the Lane B work still to do (`docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md:86-107`). The human traceability ledger makes the same bounded statement (`docs/system-context/PRD_TRACEABILITY.md:125-136`). The v3 architecture describes desired job identity/project code/idempotency and write path as requirements, not evidence of implementation (`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:520-557,651-690`).

**OPEN source conflict — TDD and independent-check status:**

- Human-readable ledger reading: Gate-003 evidence includes local adapter `CHECK_PASS`, and its note says genuine RED/GREEN/REFACTOR and independent check (`docs/system-context/PRD_TRACEABILITY.md:131-136`). Delivery-map reading also calls the status-boundary slice independently checked and full-suite `CHECK_PASS` (`.../PRD_DELIVERY_MAP.md:100-105`).
- Structured-ledger reading: the same record says its files were reconstructed after being lost, that the TDD and checker records are claims whose underlying outputs were not retained, and that they are explicitly unverified and do not meet the real-independent-evidence rule (`docs/system-context/prd_traceability.yaml:95-116`).
- PRD reading: those disputed claims are presented as `EVIDENCED` (`data/prds/cbd-data-prd-v1.0.md:68-69,168-172`).

**Status: UNKNOWN** for the underlying TDD/full-suite verification; the RabbitMQ bootstrap and deterministic status helper alone remain EVIDENCED according to the structured record. Evidence needed to settle: retained raw test outputs and independent-check artifact, or an authoritative reconciliation explaining why the structured-ledger warning is superseded. Until then, do not cite the reconstructed TDD/checker text as accepted test proof. This does not change the separately explicit Gate-004 authorization blocker (`PRD_TRACEABILITY.md:132,136`; PRD `:80,268,659`).

## 2. Product scope from v3 §2.4

All eight functions are present verbatim in the PRD's §0.1: B2B business search by keyword/location; automated website visits/data acquisition; email, phone, social-profile/contact enrichment; lead-list management; CSV export; public share links; CRM integration; API access for larger plans (`data/prds/cbd-data-prd-v1.0.md:13-28`). That matches canonical v3 §2.4 (`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:118-134`). The PRD also requires Gate C to audit all eight (`data/prds/cbd-data-prd-v1.0.md:430-439`).

**Gap:** the detailed acceptance list tests business search and CSV export but has no separate acceptance criterion for public share links, CRM integration, or larger-plan API access (`data/prds/cbd-data-prd-v1.0.md:334-347`). These functions are in scope in §0.1, but their implementation/current-state acceptance is not made traceable in AC-1–AC-10. This is an acceptance-coverage omission, not evidence that the functions are absent. Status: UNKNOWN pending explicit per-function audit/test criteria or a sourced deferment.

## 3. Placement conflict — v3 target versus active service catalogue

The v3 reading is explicit: CBD-Data is expected to be the heaviest scraping/enrichment/queue/export/data-volume workload, its public application remains on Hostinger, and scraping/enrichment/AI/batch run on Hetzner (`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:123-134`).

The service-catalogue reading is that `cbd-worker.service` is **KNOWN active** on `srv1137994-aminolifesciences` (AminoVPS), with `hetzner-compute` as intended host and migration requiring separate authority (`docs/system-context/SERVICE_CATALOG.md:210-224`; `docs/system-context/service_catalog.yaml:220-240`). These entries cite 2026-09-15 evidence, not an audit-date live read.

There is also a direct historical-state conflict: BR-INV-001 says the worker was active on AminoVPS (`docs/system-context/evidence/BR-INV-001/report.md:54,77`), while the canary reconciliation says the service was inactive on 2026-07-31, reports a successful bounded cycle on 2026-08-01, and says subsequent access failed (`docs/system-context/evidence/cbd-worker-canary/report.md:25-33`). The later September catalogue says active, but supplies no fresh command output in its row (`SERVICE_CATALOG.md:217-224`). Current live activity therefore remains UNKNOWN until remeasured.

The PRD records the placement mismatch: active AminoVPS placement and its IP are marked EVIDENCED; it says this is not v3 target and migration is authorization-blocked (`data/prds/cbd-data-prd-v1.0.md:87-92,214-225,292-297,619-623`). It does not mislabel AminoVPS as v3-compliant. The architecture conflict remains OPEN between v3's Hetzner target and catalogued AminoVPS placement; do not claim Hetzner placement is delivered. A fresh read-only service check can settle current activity, but not erase the v3 target without an approved architecture decision.

## 4. Adversarial spot-check of 15 provenance labels

Counted PRD references below, not the definition rows. A “passes” result means the cited source supports the narrow claim and label; it does not mean the underlying system was remeasured today.

| # | PRD location / label | Check result | Evidence and adversarial note |
|---:|---|---|---|
| 1 | `:66` `[PER TRACEABILITY]` source exists | EVIDENCED | Ledger records BR-AUD-005 and project source/audit scope (`PRD_TRACEABILITY.md:99-110`); no claim of deployment is made. |
| 2 | `:67` `[PER TRACEABILITY]` audit coverage | EVIDENCED | Map identifies scraping, enrichment, queue, export, storage, and compute placement discovery (`PRD_DELIVERY_MAP.md:25`); this is discovery, not implementation. |
| 3 | `:68` `[PER TRACEABILITY]` bounded RabbitMQ/status-helper slice | EVIDENCED, narrowly | Both ledgers support private bootstrap and local helper (`PRD_TRACEABILITY.md:131-136`; `prd_traceability.yaml:111-116`). The label must not be broadened to include the TDD proofs below. |
| 4 | `:69` `[PER TRACEABILITY]` RED/GREEN/REFACTOR and full-suite `CHECK_PASS` | **BLOCKED — label fails for this claim** | Human ledger/map say passed (`PRD_TRACEABILITY.md:133`; `PRD_DELIVERY_MAP.md:100-105`), but structured ledger expressly marks underlying outputs unretained/unverified (`prd_traceability.yaml:111-116`). OPEN conflict; current PRD presents one side as fact. |
| 5 | `:70` `[PER TRACEABILITY]` local restore/backup documents and tests | EVIDENCED | Delivery map and human ledger state documents/tests exist (`PRD_DELIVERY_MAP.md:25`; `PRD_TRACEABILITY.md:107-110`). This does not mean live Namecheap backup/restore. |
| 6 | `:76` `[PER TRACEABILITY]` adapter UNKNOWN | UNKNOWN | Structured ledger explicitly says no publisher/consumer adapter (`prd_traceability.yaml:115-116`); this is an evidence-bound absence, not a claim of a live code scan. |
| 7 | `:77` `[PER TRACEABILITY]` `project_id` UNKNOWN | UNKNOWN | Structured ledger explicitly lists no `project_id` evidence (`prd_traceability.yaml:115-116`). |
| 8 | `:78` `[PER TRACEABILITY]` idempotency UNKNOWN | UNKNOWN | Structured ledger explicitly lists no idempotency key (`prd_traceability.yaml:115-116`); delivery map lists idempotency as Lane B scope/done criteria (`PRD_DELIVERY_MAP.md:88,107`). |
| 9 | `:79` `[PER TRACEABILITY]` durable persistence/restore UNKNOWN | UNKNOWN | Structured ledger explicitly lists no durable persistence/restore (`prd_traceability.yaml:115-116`); map distinguishes local backup tests from end-to-end acceptance (`PRD_DELIVERY_MAP.md:25`). |
| 10 | `:80` `[PER TRACEABILITY]` Gate-004 blocked | BLOCKED | Human and structured ledgers both identify `AUTHORIZATION` and Gate-004 closed/unauthorized (`PRD_TRACEABILITY.md:131-136`; `prd_traceability.yaml:98-99,116`). |
| 11 | `:81` `[PER TRACEABILITY]` end-to-end chain UNKNOWN | UNKNOWN | Map and both ledgers state no accepted end-to-end Hostinger↔Hetzner chain (`PRD_DELIVERY_MAP.md:25`; `PRD_TRACEABILITY.md:107-110,136`). |
| 12 | `:87` `[PER TRACEABILITY]` local worker canary EVIDENCED | EVIDENCED | Human ledger lists local canary as EVIDENCED and points to report (`PRD_TRACEABILITY.md:112-123`); explicitly local only. |
| 13 | `:88` `[PER TRACEABILITY]` active AminoVPS service | UNKNOWN for current activity; placement EVIDENCED historically | Catalog says service active on AminoVPS, last verified 2026-09-15 (`SERVICE_CATALOG.md:217-224`; `BR-INV-001/report.md:77`), but canary record says inactive on 2026-07-31, successful bounded cycle on Aug 1, then access unavailable (`cbd-worker-canary/report.md:25-33`). The PRD presents the later active reading without this source conflict. |
| 14 | `:89` `[PER TRACEABILITY]` AminoVPS IP | EVIDENCED, historical/source-dependent | PRD cites BR-INV-001 §Host 1 and the catalog entry; the catalog row itself contains no IP (`SERVICE_CATALOG.md:214-224`). Underlying report is the cited evidence path, but this audit did not remeasure the address. |
| 15 | `:90` `[PER TRACEABILITY]` AminoVPS differs from v3 target | EVIDENCED | Catalog and traceability explicitly distinguish current AminoVPS placement from intended Hetzner (`SERVICE_CATALOG.md:217-224`; `PRD_TRACEABILITY.md:118-123`), while v3 assigns CBD-Data compute to Hetzner (`BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:134`). PRD's `CONFIRMED` is not one of the ledger's five status values; use EVIDENCED for this sourced architectural comparison. |

**Spot-check result:** one provenance application clearly overstates evidence (`:69`); `:88` presents current activity as EVIDENCED despite conflicting dated source readings and should be UNKNOWN until remeasured; `:89` is supported by its named underlying report citation but not by the catalog row itself. No other sampled labels failed their narrow source claim. The outstanding TDD evidence conflict applies to both `:68`'s broad evidence-tree reference and `:69`; retain the narrower broker/helper claim only.

## Other traceability defects found

- The PRD's provenance summary says `[PER v3]` is applied to §0.1, §0.3, phases, and other sections, but actual line-level occurrences show no `[PER v3]` attached to those claims; only the definition, Section 7 taxonomy, and summary contain the marker (`data/prds/cbd-data-prd-v1.0.md:58-60,332,763`; v3 claims are independently sourceable at `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:123-134`). Thus the sources are cited in prose, but the claimed label application is false.
- PRD line 90 uses `CONFIRMED`, which is outside the traceability schema’s defined statuses (`PRD_TRACEABILITY.md:8-18`). Its fact is supportable; status should be normalized to EVIDENCED, not treated as a new accepted state.
- Many cited statuses have source dates 2026-09-15 or 2026-09-18, while the PRD says it was last updated October 2026 and this audit is October 18. Those dates are properly reproduced, but do not substantiate “today”/fresh live state. The PRD's label legend appropriately says no `[VERIFIED TODAY]` entries exist (`data/prds/cbd-data-prd-v1.0.md:58,762`).

## Validation record

- Full required inputs read; line counts confirmed: target 768, v3 2,071, traceability 339, delivery map 136, template 1,615 (`wc -l` command).
- Label-count command found 84 `[PER TRACEABILITY]`, 3 `[PER v3]`, and 3 `[VERIFIED TODAY]` occurrences = 90 occurrences across 88 lines; those include label definitions and summary/section taxonomy, not 90 individually sourced evidence rows.
- Spot checks were against the human traceability ledger, structured YAML ledger, delivery map, v3, and service catalogue; no live infrastructure was queried.

## Residual risk

The most consequential unresolved issue is the contradictory record about whether the local TDD and independent-checker outputs are real, retained evidence. Do not elevate the full test/check claim to accepted proof until the raw outputs are reconciled. The catalogued active AminoVPS status conflicts with the older canary record (inactive as of 2026-07-31, later bounded run Aug 1); a fresh read-only measurement is needed before asserting current activity.
