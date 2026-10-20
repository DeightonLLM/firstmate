# Adversarial audit — Whoosh PRD status brief

**Audit date:** 2026-10-18  
**Scope:** `data/prds/whoosh-prd-status-brief.md` (373 lines). Document-only review; no project, service, DNS, host, or PRD changes were made.

## Verdict

The brief gets the two ledger statuses and Phase 5 project order right, and it includes both dated hostname observations. It does **not** explicitly mark their conflict `OPEN`, overstates what a failed `curl` proves about DNS records, and does not stay a non-duplicative status brief: it reproduces broad authoritative-PRD scope, non-goals, acceptance, rollout, and decision content. The central status claims are sound against the cited ledger; the external-measurement claims are not independently reproducible from the evidence included in the brief.

## Findings

### 1. Ledger status and bot-routing caution — EVIDENCED

The brief correctly records `whoosh-audit` as `BLOCKED` with `COORDINATES_MISSING` and `whoosh-bot-routing` as `UNKNOWN`, and explicitly says not to claim bot-routing completion without an accepted artifact (`data/prds/whoosh-prd-status-brief.md:32-35, 62-63`). The ledger independently records the audit as `BLOCKED`, blocker `DEPENDENCY` (`COORDINATES_MISSING`), and evidence `BR-AUD-004` `BLOCKED_BY_DEPENDENCY`; the bot-routing row is `UNKNOWN` with no surfaced completion evidence (`docs/system-context/PRD_TRACEABILITY.md:140-161`). The delivery map likewise says exact repo/hosting/runtime/production IP are required and identifies `BR-AUD-004` as blocked (`docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md:5, 76-78`).

### 2. 502 versus non-resolving — conflict preserved, but not explicitly OPEN — EVIDENCED

Both readings appear: v1.0 §2.5 reports HTTPS `502 Bad Gateway` for `data` and `lc` (`data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md:137-142`); the brief reports the 2026-10-18 measurement as no resolution/no HTTP response (`data/prds/whoosh-prd-status-brief.md:39-40, 75-89`). It also acknowledges that the observations may be true at different times and requests timestamped remeasurement (`...whoosh-prd-status-brief.md:89, 136-140`). It therefore does not silently erase the 502 reading.

However, the brief never labels the conflict `OPEN`; instead it calls the 2026-10-18 state authoritative for that date (`...whoosh-prd-status-brief.md:89`). This is a material documentation defect against the requested explicit conflict disposition: the dated readings are retained, but a reviewer cannot find an explicit `OPEN` marker. The underlying measurement method/output is also absent from the cited source index (`...whoosh-prd-status-brief.md:363-373`), so the claimed external reading itself is **UNKNOWN** from this review's supplied artifacts; settle it with the timestamped DNS query, resolver/server, and raw response/exit output.

The brief also leaps from “curl exit, no HTTP response” to “DNS records themselves do not exist” and “there is no host to repair” (`...whoosh-prd-status-brief.md:72, 87, 199`). A failed curl alone does not distinguish NXDOMAIN from resolver timeout, local resolver/configuration failure, or other connection/name-resolution errors. No query type, resolver, DNS response code, or raw command output is cited. This claim is **UNKNOWN** without direct DNS evidence. Preserve “not resolving in this measurement” as an observation, not proof of absent A/CNAME records or a specific repair path.

### 3. Non-restatement / duplication — not satisfied

The brief does not say it is *not* a restatement. It presents itself as derived from the authoritative PRD (`data/prds/whoosh-prd-status-brief.md:5, 16`), then restates domain scope (`...:93-104`), non-goals (`...:108-120`), extensive project acceptance criteria (`...:162-232`), a multi-phase rollout (`...:236-314`), evidence requirements (`...:332-344`), and an ADR register (`...:348-359`). Those are already substantive sections of the authoritative PRD, including purpose/scope and non-goals (`data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md:1-11, 123-144`), acceptance requirements (`...:1460-1547`), rollout (`...:1320-1458`), and decision register (`...:1578-1595`). This is duplication, not a tight status-only derivative.

There is also an avoidable inference/contradiction: the brief calls the lack of DNS resolution proof that “No DNS A/CNAME records” exist (`...whoosh-prd-status-brief.md:72`), while v1.0 reports HTTP 502 on those names on October 17 and cautions that this is not evidence the underlying systems are absent (`...whoosh-performance-wp-data-outreach-prd-v1.0.md:137-142`). The dated readings can differ, but the brief cannot infer record absence or service absence from the stated curl result. Its scope section also promotes shared v3 architecture components (queues, database roles, Qdrant) into Whoosh scope (`...whoosh-prd-status-brief.md:95-104`) despite v1.0 explicitly directing that these components be added only if audit proves need (`...whoosh-performance-wp-data-outreach-prd-v1.0.md:95-101`). This risks broadening the authoritative Whoosh contract.

The brief uses status labels outside the permitted vocabulary, including `NOT ELIGIBLE`, `NOT PRESENT`, and `NOT RESOLVING` (`...whoosh-prd-status-brief.md:22, 38-41`). For a status-led artifact, normalize classifications to `DELIVERED`, `EVIDENCED`, `IN_PROGRESS`, `BLOCKED`, or `UNKNOWN`, and keep the measurement wording in the evidence/notes field.

### 4. Phase 5 ordering — EVIDENCED

The brief's order is Core Distro → Elevate → Whoosh → CBD-Data (`data/prds/whoosh-prd-status-brief.md:236-238`). This matches v3 Phase 5's numbered order exactly (`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:1780-1787`). No ordering discrepancy found.

## Authoritative template integrity

The requested template is `data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md`. It remains unchanged in this audit: `git diff -- data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md` and `git diff --cached -- data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md` printed no diff. Measured size: **60,818 bytes**. SHA-256: **ace333174d065c5c341a31ae34b7f8a6d2ee1b8a6c68634798aa26337e10a35d** (command: `wc -c data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md; sha256sum data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md`).

## Commands and boundaries

- Read the complete selected v3 file (PD variant absent; PRD variant present, 2,071 lines), traceability file, delivery map, authoritative v1.0 PRD, and audited brief before reaching findings.
- `wc -l -c ...` confirmed the audited brief is 373 lines and v3 selected source is 2,071 lines.
- `git status --short` showed pre-existing unrelated changes/untracked paths (`data/async-lanes.tsv`, `core-distro-saas-clean`, `firstmate`); none were modified by this audit.
- `git diff --cached --name-only` printed no paths: no staged files were present at check time.
- Only this report was created by the audit.

## Recommended correction to the brief

Keep the correct `BLOCKED`/`UNKNOWN` ledger statuses and the exact rollout order. Mark the 502/non-resolving discrepancy `OPEN`, retain both dated observations without selecting a historical winner, attach the raw DNS/HTTP measurement evidence, and remove assertions about absent records/origin unless directly measured. Replace the repeated PRD scope, non-goals, acceptance lists, phase plan, and ADR catalog with concise pointers to the authoritative PRD plus only current status, blockers, conflicts, and evidence gaps.
