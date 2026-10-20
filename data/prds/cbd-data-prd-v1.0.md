# CBD-Data Infrastructure PRD v1.0

**Client:** Brandon  
**Primary domain:** `cbd-data.com`  
**Project code:** `cbddata`  
**Prepared for:** the Captain  
**Orchestration and technical acceptance:** the Captain  
**Implementation:** Saad and approved HD2 implementation agents  
**Business and final production approval:** Eric and Brandon  
**PRD source:** derives from `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (v3.0, 2026-08-04)  
**Status:** In progress — source and local evidence exist; PRD-wide production acceptance is not proven  
**Last updated:** October 2026

---

## 0. Executive Directive

HD2 will implement CBD-Data's public application on Hostinger, its scraping, enrichment, AI execution, and batch-processing workloads on Hetzner, and its encrypted backup and recovery material on a dedicated Namecheap target, per the architecture in the canonical v3 PRD.

### 0.1 Application Scope [PER v3 §2.4]

CBD-Data is the **heaviest scraping, enrichment, queue, export, and data-volume workload** of the four projects. Its product functions are:

- B2B business search by keyword and location
- Automated website visits and data acquisition
- Email, phone, social-profile, and contact enrichment
- Lead-list management
- CSV export
- Public share links
- CRM integration
- API access for larger plans

Source: canonical v3 §2.4 (2026-08-04). These are scope requirements, not implementation evidence. Current implementation and acceptance are UNKNOWN for each function until Gate C evidence is recorded.

| v3 §2.4 function | Current implementation / target acceptance |
|---|---|
| B2B search by keyword/location | UNKNOWN — no function-specific accepted evidence cited |
| Website visits/data acquisition | UNKNOWN — audit scope reported; target acceptance not established |
| Contact enrichment | UNKNOWN — audit scope reported; full product acceptance not established |
| Lead-list management | UNKNOWN — no function-specific accepted evidence cited |
| CSV export | UNKNOWN — audit scope reported; user-facing acceptance not established |
| Public share links | UNKNOWN — acceptance criterion/evidence not separately cited |
| CRM integration | UNKNOWN — acceptance criterion/evidence not separately cited |
| Larger-plan API access | UNKNOWN — acceptance criterion/evidence not separately cited |

### 0.2 Phase 5 Placement Rationale

CBD-Data is placed **last** in the Phase 5 rollout per v3 PRD §19 Phase 5 ordering: "CBD-Data is last because it exercises the heaviest data and processing path. Its rollout becomes the final capacity and backpressure validation of the platform."

Source: v3 PRD §19 Phase 5 ordering rationale (2026-08-04).

### 0.3 Required Placement (PER v3 §§7.1–7.2)

- **Hostinger KVM8:** public website, API, authentication, customer dashboards, file delivery, finalized exports, primary application control plane, PostgreSQL/PgBouncer.  
- **Hetzner dedicated server:** scraping, browser automation, enrichment, AI-agent execution, background jobs, compute-heavy transformations, queue consumers, temporary working data, RabbitMQ virtual host `/cbddata`, Qdrant collections, browser pools.  
- **Namecheap:** one dedicated encrypted backup/DR target for CBD-Data only (per v3 PRD §7.3 "One Namecheap target assigned per project").

Source: v3 PRD §§6.1, 7.1–7.3, 7.2 RabbitMQ Isolation, 8.2 Worker Write Path (2026-08-04).

### 0.4 Honest Verdict

CBD-Data has real Next/PHP source at `projects/cbd-data.com/` and accepted local evidence for scraping, enrichment, queue, export, storage, and compute placement discovery (BR-AUD-005, manifest line 11). Local restore/backup documents and tests exist. Gate-CBD-ENRICH-003 proves only the bounded broker/runtime slice — a private RabbitMQ `/cbddata` virtual host bootstrap and a deterministic local `cbd_initial_job_status()` helper used at both import insert sites. Gate-004 and production cutover remain unauthorized. Live worker placement on AminoVPS is not the PRD-v3 target. No accepted end-to-end Hostinger-to-Hetzner queue/isolation/restore/signoff chain is present.

---

## 1. Current State

Each row carries a provenance label:
- **[VERIFIED TODAY]** — fresh measurement with command/output cited; none in this PRD repair
- **[PER v3]** — product scope or target requirement from canonical v3 dated 2026-08-04; not implementation evidence
- **[PER TRACEABILITY]** — ledger status/date/scope only; not broader acceptance

### 1.1 Source and Evidence

| Item | Status | Provenance | Notes |
|---|---|---|---|
| Real Next/PHP project source at `projects/cbd-data.com/` | `EVIDENCED` | [PER TRACEABILITY] | `cbd-data-source-and-audit`; last verified 2026-09-15; BR-AUD-005 accepted; manifest line 11 |
| Scraping, enrichment, queue, export, storage, compute placement discovery audited | `EVIDENCED` | [PER TRACEABILITY] | `cbd-data-source-and-audit`; last verified 2026-09-15; BR-AUD-005; PRD_DELIVERY_MAP.md CBD-Data row |
| Bounded broker/runtime slice — private RabbitMQ `/cbddata` virtual host bootstrap on `brandon-compute` + deterministic `cbd_initial_job_status()` local status helper | `EVIDENCED` (run-record claim; not independently reverified) | [PER TRACEABILITY] | `cbd-data-enrichment-gap`; run date 2026-09-18; `status.txt` retained. `evidence.md` was reconstructed 2026-10-11 from that record; see its provenance warning. |
| RED/GREEN/REFACTOR evidence and full local-suite CHECK_PASS for bounded broker slice | `UNKNOWN` | [OPEN CONFLICT] | Human traceability and delivery-map text report a pass, but structured `prd_traceability.yaml` says the underlying outputs were not retained and marks those claims unverified. Settle with retained raw test output and independent-check artifact, or authoritative reconciliation of the structured-ledger warning; do not treat reconstructed claims as accepted proof. |
| Local restore/backup documents and tests | `EVIDENCED` | [PER TRACEABILITY] | `cbd-data-source-and-audit`; last verified 2026-09-15; PRD_DELIVERY_MAP.md CBD-Data row |

### 1.2 Adapter and Integration Layer

| Item | Status | Provenance | Notes |
|---|---|---|---|
| Publisher/consumer adapter | `UNKNOWN` | [PER TRACEABILITY] | Gate-CBD-ENRICH-003 proves only the bounded broker/runtime bootstrap and local status helper. No adapter code, test, or evidence is cited in any source. |
| project_id injection into jobs | `UNKNOWN` | [PER TRACEABILITY] | Same as above — no cited evidence for job-level project scoping beyond the local status helper. |
| Idempotency key implementation | `UNKNOWN` | [PER TRACEABILITY] | No cited evidence in Gate-CBD-ENRICH-003, PRD_TRACEABILITY.md, or PRD_DELIVERY_MAP.md. |
| Durable persistence and restore for adapter layer | `UNKNOWN` | [PER TRACEABILITY] | Gate-CBD-ENRICH-003 proves only a local status helper. No durable persistence, backup, or restore evidence for the adapter layer is cited. |
| Gate-004 (enrichment authorization/cutover) | `BLOCKED` (AUTHORIZATION) | [PER TRACEABILITY] | `cbd-data-enrichment-gap`; Gate-004 remains closed; explicit authorization from Eric and Dubz required. |
| End-to-end Hostinger-to-Hetzner queue/isolation/restore/signoff chain | `UNKNOWN` | [PER TRACEABILITY] | PRD_DELIVERY_MAP.md CBD-Data row explicitly states "no accepted end-to-end Hostinger↔Hetzner queue/isolation/restore/signoff chain is present." |

### 1.3 Worker and Placement

| Item | Status | Provenance | Notes |
|---|---|---|---|
| Local worker canary | `EVIDENCED` (historical local canary record; current worker state UNKNOWN) | [PER TRACEABILITY] | `cbd-worker-canary`; ledger date 2026-09-15. The available 2026-08-02 canary reconciliation reports AminoVPS access unavailable and service inactive/disabled as attested 2026-07-31; this conflicts with the later catalogue summary and is not a current measurement. |
| Historical recorded placement of `cbd-worker.service` on `srv1137994-aminolifesciences` (AminoVPS) | `EVIDENCED` (catalogue record dated 2026-09-15; activity UNKNOWN) | [PER TRACEABILITY] | SERVICE_CATALOG.md `cbd-worker`; conflicts with `docs/system-context/evidence/cbd-worker-canary/report.md` (dated 2026-08-02; reports service inactive/disabled as attested 2026-07-31 and access unavailable). Neither is a current measurement. |
| AminoVPS Tailscale IP `100.69.211.43` | `EVIDENCED` | [PER TRACEABILITY] | BR-INV-001/report.md §Host 1; SERVICE_CATALOG.md `cbd-worker` |
| **AminoVPS placement differs from the v3 Hetzner target** | `EVIDENCED` | [PER TRACEABILITY + PER v3 §2.4] | SERVICE_CATALOG.md `cbd-worker` and PRD_TRACEABILITY.md `cbd-worker-canary` describe AminoVPS as legacy; canonical v3 §2.4 assigns compute workloads to Hetzner. This establishes the target mismatch, not current service liveness or migration authorization. |
| Current AminoVPS worker activity / placement | `UNKNOWN`; further live access is authorization/access-gated | [PER TRACEABILITY] | PRD_TRACEABILITY.md `cbd-worker-canary`; PRD_DELIVERY_MAP.md unresolved area 2; dated canary report records access failure and inactive/disabled state. |
| PRD-v3 target worker placement on Hetzner | `UNKNOWN` | [PER TRACEABILITY] | No accepted migration plan or authorization; PRD_DELIVERY_MAP.md unresolved area 2 |
| Worker denial of cross-project queue access | `UNKNOWN` | [PER TRACEABILITY] | `platform-isolation`; PRD_DELIVERY_MAP.md unresolved area 3 |
| Worker denial of Hostinger internal database access | `UNKNOWN` | [PER TRACEABILITY] | `platform-isolation`; PRD_DELIVERY_MAP.md unresolved area 3 |

### 1.4 Application Stack on Hostinger

| Item | Status | Provenance | Notes |
|---|---|---|---|
| Public site (`cbd-data.com`) over HTTPS | `UNKNOWN` | — | No cited evidence in v3 PRD or traceability ledger. Gate C must audit current state. |
| Application frontend container/service on Hostinger | `UNKNOWN` | — | v3 PRD §§7.1, 20.4 require this; no cited evidence. Gate C required. |
| Application API on Hostinger | `UNKNOWN` | — | v3 PRD §§7.1, 20.4 require this; no cited evidence. Gate C required. |
| PostgreSQL database and project roles on Hostinger | `UNKNOWN` | — | v3 PRD §8.1 target; PRD_DELIVERY_MAP.md unresolved area 2 — architecture decision pending. |
| PgBouncer connection pooling | `UNKNOWN` | — | v3 PRD §8.1 target; blocked on PostgreSQL architecture decision. |
| File namespaces on Hostinger (`/srv/brandon-files/cbddata/`) | `UNKNOWN` | — | v3 PRD §9.2 requires this; no cited deployment evidence. |
| File namespace isolation (CBD-Data files not in other project paths) | `UNKNOWN` | [PER TRACEABILITY] | `platform-isolation`; PRD_DELIVERY_MAP.md unresolved area 3 |
| Internal ingest API on Hostinger (scoped to CBD-Data tenant) | `UNKNOWN` | [PER TRACEABILITY] | `platform-isolation`; PRD_DELIVERY_MAP.md unresolved area 3; v3 PRD §8.2 worker write path requires this |

### 1.5 Database Isolation

| Item | Status | Provenance | Notes |
|---|---|---|---|
| CBD-Data database and roles isolated from other projects | `UNKNOWN` | [PER TRACEABILITY] | `platform-isolation`; PRD_DELIVERY_MAP.md unresolved area 3; v3 PRD §8.1 requires dedicated role per project |
| CBD-Data data absent from other project databases, logs, files, backups | `UNKNOWN` | [PER TRACEABILITY] | `platform-isolation`; PRD_DELIVERY_MAP.md unresolved area 3; v3 PRD §11.5 multi-tenant boundary |

### 1.6 Queue and Compute on Hetzner

| Item | Status | Provenance | Notes |
|---|---|---|---|
| RabbitMQ virtual host `/cbddata` on Hetzner — bounded private slice | `EVIDENCED` | [PER TRACEABILITY] | Gate-CBD-ENRICH-003; PRD_DELIVERY_MAP.md Lane B; last verified 2026-09-18 |
| Four RabbitMQ vhosts (core/elevate/whoosh/cbddata) isolated | `UNKNOWN` | [PER TRACEABILITY] | `platform-isolation`; PRD_DELIVERY_MAP.md unresolved area 3 |
| RabbitMQ vhost `/cbddata` users, permissions, rate policies, dead-letter queue | `UNKNOWN` | — | v3 PRD §7.2 requires this; no cited evidence of full configuration |
| Queue naming per v3 PRD §7.2 (`cbddata.scrape.jobs`, `cbddata.enrich.jobs`, `cbddata.export.jobs`, `cbddata.deadletter`, etc.) | `UNKNOWN` | — | v3 PRD §7.2 requires this; no cited evidence |
| Qdrant collection isolation (`cbddata_*` prefixed collections, separate credentials, snapshots) | `UNKNOWN` | [PER TRACEABILITY] | `platform-isolation`; PRD_DELIVERY_MAP.md unresolved area 3 |
| Browser pool isolation with mandatory tenant identifier | `UNKNOWN` | [PER TRACEABILITY] | `platform-isolation`; PRD_DELIVERY_MAP.md unresolved area 3 |
| Hetzner CBD-Data workspace with disk quota, retention job, cleanup logs | `UNKNOWN` | — | v3 PRD §7.2 "Temporary Workspaces" requires this; no cited evidence |

### 1.7 Backup, DR, and Observability

| Item | Status | Provenance | Notes |
|---|---|---|---|
| Live encrypted production backup to Namecheap CBD-Data target | `UNKNOWN` | [PER TRACEABILITY] | `backup-dr`; PRD_DELIVERY_MAP.md unresolved area 6; `BR-HUB-010 BLOCKED_OPERATOR_INPUT` |
| Namecheap CBD-Data DR target assigned (account, credentials, retention, RPO/RTO, key custody) | `BLOCKED` (OPERATOR_INPUT) | [PER TRACEABILITY] | `backup-dr`; PRD_DELIVERY_MAP.md unresolved area 6 |
| Backup manifests, checksums, retention enforced | `UNKNOWN` | — | v3 PRD §15 requires this; no cited evidence for CBD-Data specifically |
| Actual RPO/RTO measured | `UNKNOWN` | [PER TRACEABILITY] | `backup-dr`; PRD_DELIVERY_MAP.md unresolved area 6 |
| CBD-Data DR drill completed | `UNKNOWN` | [PER TRACEABILITY] | `backup-dr`; PRD_DELIVERY_MAP.md unresolved area 6 |
| `DR-CBD-DATA.md` runbook written and approved | `UNKNOWN` | — | v3 PRD §16.2 lists this as required; no cited evidence |
| Observability deployed (metrics, logs, alerts for CBD-Data) | `UNKNOWN` | [PER TRACEABILITY] | `observability`; PRD_DELIVERY_MAP.md unresolved area 7 |
| CBD-Data SLO/alert/restore-age implementation | `UNKNOWN` | [PER TRACEABILITY] | `observability`; PRD_DELIVERY_MAP.md unresolved area 7 |

### 1.8 CI/CD and Release Controls

| Item | Status | Provenance | Notes |
|---|---|---|---|
| CBD-Data CI/CD pipeline (container build, vulnerability scan, secret scan, migration dry run, staging, smoke, health, rollback) | `UNKNOWN` | [PER TRACEABILITY] | `platform-release-controls`; PRD_DELIVERY_MAP.md unresolved area 5 |
| CBD-Data GitHub Actions workflow per v3 PRD §12 | `UNKNOWN` | — | v3 PRD §12 requires this; no cited evidence for CBD-Data specifically |

### 1.9 Architecture and Governance

| Item | Status | Provenance | Notes |
|---|---|---|---|
| Canonical application architecture ADR accepted (PHP/MySQL retention vs PostgreSQL/PgBouncer) | `BLOCKED` (DEPENDENCY) | [PER TRACEABILITY] | PRD_DELIVERY_MAP.md unresolved area 2 — no ADR maps existing software to v3 target |
| Live end-to-end smoke test (public site → job → Hetzner → result → export) | `UNKNOWN` | — | v3 PRD §20.4 requires this; no cited evidence |
| ADR-CBD-001 (application architecture) | Required | — | Must resolve before Phase 3 |
| ADR-CBD-002 (worker placement: AminoVPS vs Hetzner) | Required | — | Must resolve before Phase 4 |
| ADR-CBD-003 (enrichment adapter scope for Gate-004) | Required | — | Must resolve before Phase 5 cutover |
| ADR-CBD-004 (Namecheap DR target assignment) | BLOCKED (OPERATOR_INPUT) | — | Must resolve before Phase 7 |
| ADR-CBD-005 (AnythingLLM/vector-store relationship) | Required | — | Must resolve before Phase 5 if vector store is used |
| Canonical source provenance (historical Git blob) | `BLOCKED` (DEPENDENCY) | [PER TRACEABILITY] | `platform-source-provenance`; blob `b98c887b8abdf0041d52faf2405ec5a76ec8fcf2` absent; only matters if exact-byte signoff required |

---

## 2. What Is Actually Proven vs. What Is Not

### 2.1 Proven (Working Evidence Exists; PRD-Wide Acceptance Not Shown)

| What is proven | Evidence | Gaps remaining |
|---|---|---|
| Real Next/PHP source at `projects/cbd-data.com/` | [PER TRACEABILITY] `cbd-data-source-and-audit`; last verified 2026-09-15; BR-AUD-005 | Full Gate C audit, application stack on Hostinger, deployment pipeline |
| Bounded broker/runtime slice on `brandon-compute` | [PER TRACEABILITY] Gate-CBD-ENRICH-003; last verified 2026-09-18 | Publisher/consumer adapter, project_id, idempotency, durable persistence, Gate-004 authorization |
| Local restore/backup documents and tests | [PER TRACEABILITY] `cbd-data-source-and-audit`; last verified 2026-09-15 | Live encrypted off-host backup to Namecheap, real restore test, RPO/RTO measurement |
| Historical catalogue record places `cbd-worker.service` on AminoVPS | [PER TRACEABILITY] SERVICE_CATALOG.md `cbd-worker`, dated 2026-09-15; conflicting 2026-08-02 canary report says inactive/disabled as attested 2026-07-31 | Current activity UNKNOWN; this legacy host is not the v3 target; placement change requires ADR/authorization. The 2026-10-18 Brandon reply reports `cbd-data.com` live/healthy on AminoVPS; attribution only, not independent verification of this worker or current placement. |

### 2.2 Not Proven (PRD-Wide Acceptance Not Shown)

- **No end-to-end Hostinger-to-Hetzner job flow.** Gate-CBD-ENRICH-003 proves only the bounded broker slice and local status helper. The full flow (Hostinger API → PostgreSQL job record → publish to Hetzner RabbitMQ `/cbddata` → Hetzner worker → scoped ingest → acknowledgment) is not accepted. Source: [PER TRACEABILITY] PRD_DELIVERY_MAP.md CBD-Data row; `cbd-data-enrichment-gap`.
- **No production cutover authorization.** Gate-004 is BLOCKED (AUTHORIZATION). Gate-004 and cutover remain unauthorized. Source: [PER TRACEABILITY] `cbd-data-enrichment-gap`.
- **No v3 target placement.** A historical catalogue record places `cbd-worker.service` on AminoVPS, but the 2026-08-02 canary report records inactive/disabled status as attested 2026-07-31 and unavailable access. Current worker activity is UNKNOWN; placement is not the PRD-v3 target (Hetzner compute plane). Migration requires separate authority. The 2026-10-18 Brandon reply designates `cbd-campaign/L2` as a target branch and reports the site live/healthy on AminoVPS; both are attributed statements, not independent measurements, and branch designation does not prove branch contents or worker activity. Gate-004 remains HELD/BLOCKED; cutover and production authorization remain ungranted. Source: [PER TRACEABILITY] `cbd-worker-canary`; SERVICE_CATALOG.md `cbd-worker`; PRD_DELIVERY_MAP.md unresolved area 2; attributed reply dated 2026-10-18.
- **No application database, PgBouncer, file namespaces, frontend, or API on Hostinger.** Canonical application architecture is unresolved (PHP/MySQL vs PostgreSQL/PgBouncer). No accepted ADR maps existing software to the v3 target. Source: [PER TRACEABILITY] PRD_DELIVERY_MAP.md unresolved area 2.
- **No cross-project isolation evidence.** No accepted evidence proves four RabbitMQ vhosts, worker denial tests, project-scoped ingest, file namespaces, database roles, or Qdrant collection isolation end-to-end. Source: [PER TRACEABILITY] `platform-isolation`; PRD_DELIVERY_MAP.md unresolved area 3.
- **No live production backup to Namecheap.** No live encrypted off-host provider assignment, per-project target proof, real restore, measured RPO/RTO, or DR drill evidence. Source: [PER TRACEABILITY] `backup-dr`; PRD_DELIVERY_MAP.md unresolved area 6.
- **No CI/CD release controls.** Accepted local hardening/self-tests are not the PRD's project CI/CD gates. Source: [PER TRACEABILITY] `platform-release-controls`; PRD_DELIVERY_MAP.md unresolved area 5.
- **No observability.** No complete four-project SLO/alert/restore-age implementation is evidenced. Source: [PER TRACEABILITY] `observability`; PRD_DELIVERY_MAP.md unresolved area 7.

---

## 3. Scope

This PRD covers:

**Hostinger (public and control plane):**
- CBD-Data public application (`cbd-data.com`): frontend, API, authentication, customer dashboards, file delivery, finalized CSV/report exports.
- PostgreSQL/PgBouncer (pending ADR-CBD-001 architecture decision).
- Internal ingest API scoped to CBD-Data tenant.
- Job-submission persistence and durable pending-state for jobs when Hetzner is unavailable.
- File namespaces `/srv/brandon-files/cbddata/public/`, `private/`, `uploads/`, `exports/`.
- Central monitoring collectors.

**Hetzner (compute plane):**
- Scraping, browser automation, enrichment, AI-agent execution, batch-processing workers per the product scope (§0.1).
- RabbitMQ virtual host `/cbddata` with project-specific users, exchanges, queues, permissions, rate policies, dead-letter queue.
- Queue naming per v3 PRD §7.2: `cbddata.scrape.jobs`, `cbddata.enrich.jobs`, `cbddata.verify.jobs`, `cbddata.ai.jobs`, `cbddata.export.jobs`, `cbddata.scheduled.jobs`, `cbddata.deadletter`.
- Qdrant collection isolation (`cbddata_<dataset>_<embedding_version>`).
- Browser pool isolation with mandatory tenant identifier, per-domain rate limits, timeout, maximum page size.
- Temporary workspace with disk quota, retention job, cleanup logs.
- Result ingest back through scoped Hostinger ingest API.

**Namecheap (DR target):**
- One dedicated CBD-Data target: encrypted backups, manifests, restore tests, `DR-CBD-DATA.md`.
- Backup layout per v3 PRD §15.2–15.5 and §7.3.

**Across all planes:**
- Job idempotency, duplicate-safe handling, project isolation, backpressure per v3 PRD §§8.3–8.5, 13.4.
- CI/CD pipeline, smoke tests, isolation tests, backup restore tests, monitoring, alerting.
- Gate-CBD-ENRICH-003 bounded broker/runtime slice as prerequisite.

---

## 4. Non-Goals

The following are explicitly excluded unless separately approved:

- Kubernetes or multi-node Kubernetes clusters.
- Redesign of the CBD-Data application without documented reason.
- Direct public exposure of PostgreSQL, RabbitMQ, Qdrant, Coolify, Grafana, or internal admin tools.
- Storing secrets in Git, Docker images, plaintext backups, agent memory, logs, or issue comments.
- Sharing one unrestricted database user, queue user, API key, or backup credential across multiple projects.
- Allowing agents to change DNS, delete data, rotate production secrets, or destroy infrastructure without human approval.
- Live worker placement on AminoVPS as a v3 PRD production target — this is not authorized.
- PRD-wide platform CI/CD, observability, backup/DR, or isolation until shared platform blockers are resolved.
- Unreviewed migration of existing production data.
- Replacement of working application frameworks without a documented reason and ADR.
- Moving public websites or APIs to Hetzner.
- New data products, scraping targets, or enrichment vendors not proven necessary by Gate C.

---

## 5. Open Blockers (Domain-Specific)

### 5.1 End-to-End Job Flow — BLOCKED (UNKNOWN / DEPENDENCY)

**Status:** `UNKNOWN` — no accepted evidence proves the full Hostinger-to-Hetzner queue/isolation/restore/signoff chain.

**What would unblock it:** Implement the full job flow per v3 PRD §§7.1–7.2, 8.2–8.5: Hostinger API job record → publish to RabbitMQ `/cbddata` → Hetzner worker → scoped ingest → acknowledgment. Add project_id injection, idempotency key, durable persistence, and project isolation tests. Run end-to-end smoke test. Obtain signoff.

**Owner:** Implementation agent (Saad or approved HD2 agent); Eric and Dubz for architecture choice.

**Source:** [PER TRACEABILITY] PRD_DELIVERY_MAP.md CBD-Data row; `cbd-data-enrichment-gap`.

---

### 5.2 Enrichment Adapter Gap — BLOCKED (AUTHORIZATION)

**Status:** `BLOCKED` (AUTHORIZATION) — Gate-004 remains closed.

Gate-CBD-ENRICH-003 proves only the bounded broker/runtime slice (private RabbitMQ `/cbddata` bootstrap and local `cbd_initial_job_status()` helper). It does **not** prove:
- A publisher adapter
- A consumer adapter
- project_id injection into jobs
- An idempotency key
- Durable persistence or restore
- End-to-end Hostinger-to-Hetzner acceptance

**What would unblock it:** Implement Lane B durable job and isolation adapter per PRD_DELIVERY_MAP.md Lane B. Run duplicate-submission test proving no duplicate leads or charges. Obtain Gate-004 and explicit cutover authorization from Eric and Dubz.

**Owner:** Eric and Dubz (authorization); implementation agent (adapter implementation).

**Source:** [PER TRACEABILITY] `cbd-data-enrichment-gap`; Gate-CBD-ENRICH-003.

---

### 5.3 Canonical Application Architecture — BLOCKED (DEPENDENCY)

**Status:** `BLOCKED` (DEPENDENCY) — no accepted ADR maps existing CBD-Data software to the v3 PRD target.

Current evidence is PHP/MySQL and mixed deployment. The v3 target is Hostinger PostgreSQL/PgBouncer, project databases/roles, Hostinger APIs/files, Hetzner queues/workers. No single accepted source resolves this.

**What would unblock it:** ADR-CBD-001 choosing retention of PHP/MySQL where proven, or adoption of PostgreSQL/PgBouncer per project.

**Owner:** Eric and Dubz (architecture decision).

**Source:** [PER TRACEABILITY] PRD_DELIVERY_MAP.md unresolved area 2.

---

### 5.4 Worker Placement Authority — BLOCKED (AUTHORIZATION)

The 2026-09-15 service-catalogue record places `cbd-worker.service` on AminoVPS (`srv1137994-aminolifesciences`, Tailscale IP `100.69.211.43`), while the 2026-08-02 canary reconciliation reports it inactive/disabled as attested 2026-07-31 and records unavailable access. Current activity is **UNKNOWN**; neither record proves a live worker today. AminoVPS is not the v3 target (Hetzner compute plane); do not conflate historical placement with target delivery.

**What would unblock it:** ADR-CBD-002 and explicit authorization from Eric and Dubz for the chosen placement. A migration plan if Hetzner is selected.

**Owner:** Eric and Dubz (authorization).

**Source:** [PER TRACEABILITY] `cbd-worker-canary`; PRD_DELIVERY_MAP.md unresolved area 2; SERVICE_CATALOG.md `cbd-worker`.

---

### 5.5 Namecheap DR Target — BLOCKED (OPERATOR_INPUT)

**Status:** `BLOCKED` (OPERATOR_INPUT) — no live CBD-Data backup to Namecheap can be configured without operator input.

**What would unblock it:** Captain provides: Namecheap account/credentials for CBD-Data DR target, retention policy, accepted RPO/RTO, recovery-key custody. Then: assign one Namecheap target exclusively to CBD-Data per v3 PRD §7.3, configure encrypted backup transfer, run restore test, write `DR-CBD-DATA.md`, run drill.

**Owner:** Captain (operator input); implementation agent (backup configuration).

**Source:** [PER TRACEABILITY] `backup-dr`; PRD_DELIVERY_MAP.md unresolved area 6.

---

## 6. Shared Platform Blockers

These `UNKNOWN`/`BLOCKED` items gate CBD-Data regardless of its own progress. Source for all: [PER TRACEABILITY] PRD_DELIVERY_MAP.md lines 36–64.

| # | Blocker | Status | What would unblock it | Owner |
|---|---|---|---|---|
| 1 | **Project coverage gap — Whoosh coordinates missing** | `BLOCKED` (DEPENDENCY) | Captain or Brandon provides Whoosh repository/hosting/runtime/IP coordinates | Captain / Brandon |
| 2 | **Canonical application architecture unresolved** | `BLOCKED` (DEPENDENCY) | Accepted ADR choosing PHP/MySQL retention or PostgreSQL/PgBouncer adoption | Eric and Dubz |
| 3 | **Cross-project runtime isolation** | `UNKNOWN` | Accepted evidence for four RabbitMQ vhosts, worker denial tests, project-scoped ingest, file namespaces, database roles, Qdrant collection isolation | Implementation agent |
| 4 | **Hub application delivery** | `BLOCKED` (OPERATOR_INPUT) | Approved secret store, backup/restore, embedding/vector backend, per-project isolation, DNS/TLS gate; resolve AnythingLLM ownership | Captain (operator input) |
| 5 | **Release controls (CI/CD)** | `UNKNOWN` | Per-project CI/CD pipeline per v3 PRD §12 | Implementation agent |
| 6 | **Backup/DR** | `UNKNOWN` (OPERATOR_INPUT) | Operator supplies provider/account, retention, RPO/RTO, key custody; then live encrypted backup + restore rehearsal | Captain (operator input) |
| 7 | **Observability** | `UNKNOWN` | Metrics, logs, alerts deployed and tested per v3 PRD §14 | Implementation agent |
| 8 | **Canonical source provenance** | `BLOCKED` (DEPENDENCY) | Recover historical Git blob only if exact-byte signoff required; otherwise warehouse copy is authoritative | Captain (decision) |
| 9 | **Reusable HD2 client baseline incomplete** | `UNKNOWN` | Completed host-profile overlay + fresh admin login proof for Hetzner compute | Implementation agent |

---

## 7. Acceptance Criteria

Traceable to v3 PRD sections. Items not evidenced in current sources are marked `UNKNOWN — evidence needed`.

Evidence provenance labels: [VERIFIED TODAY], [PER v3], [PER TRACEABILITY].

### 7.1 Application Acceptance (v3 PRD §20.4)

| # | Criterion | Status | Provenance | Evidence needed |
|---|---|---|---|---|
| AC-1 | User can submit a permitted business search | `UNKNOWN` | — | Gate C audit + end-to-end test |
| AC-2 | Durable job record is created on Hostinger | `UNKNOWN` | — | PostgreSQL job table + test |
| AC-3 | Job is routed to the CBD-Data RabbitMQ virtual host `/cbddata` | `UNKNOWN` | — | Full job flow test (bounded slice proven; end-to-end not) |
| AC-4 | Hetzner worker processes the job within limits | `UNKNOWN` | — | Worker on Hetzner + smoke test (current placement is AminoVPS, not Hetzner) |
| AC-5 | Results return through the scoped ingest path | `UNKNOWN` | — | Scoped ingest API + test (no adapter proven) |
| AC-6 | CSV export is generated and served from Hostinger | `UNKNOWN` | — | Export flow test |
| AC-7 | Duplicate delivery does not duplicate leads or charges | `UNKNOWN` | — | Idempotency test (no idempotency key proven) |
| AC-8 | Rate limits and plan quotas work | `UNKNOWN` | — | Rate limit + quota test |
| AC-9 | Large runs produce backpressure rather than an outage | `UNKNOWN` | — | Backpressure test per v3 PRD §13.4 |
| AC-10 | CBD-Data backup restores database, files, queue definitions, and vector snapshot | `UNKNOWN` | — | Real restore test; current local restore/backup tests exist but no live Namecheap target |

### 7.2 Isolation Acceptance (v3 PRD §§7.2, 8.1, 8.3, 9, 11.5)

| # | Criterion | Status | Provenance | Evidence needed |
|---|---|---|---|---|
| AC-11 | CBD-Data RabbitMQ vhost and users are isolated from other projects | `UNKNOWN` | [PER TRACEABILITY] `platform-isolation` | Worker denial tests; four-vhost isolation proof |
| AC-12 | CBD-Data data does not appear in another project's database, logs, files, or backup | `UNKNOWN` | [PER TRACEABILITY] `platform-isolation` | Cross-project data leak test |
| AC-13 | CBD-Data files are in `/srv/brandon-files/cbddata/` and not in other project paths | `UNKNOWN` | [PER TRACEABILITY] `platform-isolation` | File namespace isolation test |
| AC-14 | CBD-Data jobs use CBD-Data credentials only | `UNKNOWN` | [PER TRACEABILITY] `platform-isolation` | Credential scope test |
| AC-15 | Qdrant collections are prefixed `cbddata_` with separate credentials | `UNKNOWN` | [PER TRACEABILITY] `platform-isolation` | Qdrant collection isolation test |

### 7.3 Infrastructure Acceptance (v3 PRD §§7.1–7.3, 12, 14, 15, 16, 21)

| # | Criterion | Status | Provenance | Evidence needed |
|---|---|---|---|---|
| AC-16 | `cbd-data.com` serves over valid HTTPS | `UNKNOWN` | — | Gate C + TLS check |
| AC-17 | Application frontend/API deployed on Hostinger per architecture ADR | `UNKNOWN` | — | Gate C + deployment evidence |
| AC-18 | PostgreSQL database and project roles deployed on Hostinger (or MySQL retained per ADR) | `UNKNOWN` | [PER TRACEABILITY] unresolved area 2 | ADR-CBD-001 + deployment evidence |
| AC-19 | PgBouncer connection pooling in front of database | `UNKNOWN` | [PER TRACEABILITY] unresolved area 2 | Deployment evidence |
| AC-20 | CI/CD pipeline passes per v3 PRD §12 | `UNKNOWN` | [PER TRACEABILITY] `platform-release-controls` | GitHub Actions workflow |
| AC-21 | Observability (metrics, logs, alerts) deployed for CBD-Data | `UNKNOWN` | [PER TRACEABILITY] `observability` | Metrics/logs/alerts evidence |
| AC-22 | One Namecheap target assigned exclusively to CBD-Data | `BLOCKED` (OPERATOR_INPUT) | [PER TRACEABILITY] `backup-dr` | Captain input + assignment |
| AC-23 | Encrypted backups sent to Namecheap CBD-Data target | `UNKNOWN` | [PER TRACEABILITY] `backup-dr` | Backup job evidence |
| AC-24 | Backup manifest, checksums, and retention enforced | `UNKNOWN` | — | Manifest evidence |
| AC-25 | Monthly backup restore test completed per v3 PRD §15.6 | `UNKNOWN` | [PER TRACEABILITY] `backup-dr` | Restore test record |
| AC-26 | Actual RPO and RTO measured and recorded | `UNKNOWN` | [PER TRACEABILITY] `backup-dr` | RPO/RTO measurement |
| AC-27 | `DR-CBD-DATA.md` written and approved per v3 PRD §16.2 | `UNKNOWN` | — | Approved runbook |
| AC-28 | One DR drill completed per v3 PRD §16.5 | `UNKNOWN` | [PER TRACEABILITY] `backup-dr` | Drill record |
| AC-29 | Worker is on Hetzner (not AminoVPS) with explicit AUTHORIZATION | `BLOCKED` (AUTHORIZATION) | [PER TRACEABILITY] `cbd-worker-canary` | ADR-CBD-002 + migration + authorization |
| AC-30 | End-to-end smoke test passes (public site → job → Hetzner → result → export) | `UNKNOWN` | — | Test evidence |

---

## 8. Rollout Sequence

CBD-Data is **last in Phase 5** per v3 PRD §19 Phase 5 ordering rationale (2026-08-04). Exit gates are defined per phase; none may be bypassed.

### Phase 0 — Freeze and Baseline

**Owner:** Captain  
**Source:** v3 PRD §19 Phase 0 (2026-08-04)

Tasks:
- Confirm CBD-Data source snapshot at `projects/cbd-data.com/`.
- Capture current `cbd-worker.service` configuration on AminoVPS.
- Export current RabbitMQ definitions if any.
- Back up existing data.
- Create infrastructure repository entries for CBD-Data.
- Record baseline metrics.

Exit gate: Complete baseline package exists. Rollback to current state is possible.

---

### Phase 1 — Inventory and Discovery

**Owner:** Captain / implementation agent  
**Source:** v3 PRD §19 Phase 1 (2026-08-04); Gates A–E

**Prerequisite ADR:** ADR-CBD-001 (canonical application architecture) must be accepted before Phase 3 begins.

Tasks:
- Complete Gate A (Server Inventory) for Hostinger and Hetzner CBD-Data workloads.
- Complete Gate B (Namecheap Capability Classification) for the CBD-Data DR target.
- Complete Gate C (Application Audit) for CBD-Data — full audit per v3 PRD §5 Gate C, including all eight product functions from §0.1.
- Complete Gate D (Data Classification) for all CBD-Data persistent data.
- Complete Gate E (Ownership and Access) for CBD-Data human and machine identities.

Exit gate: Eric and Dubz approve the inventory and placement plan. ADR-CBD-001 is accepted.

---

### Phase 2 — Shared Network and Security

**Owner:** implementation agent  
**Source:** v3 PRD §19 Phase 2 (2026-08-04)

Tasks:
- Validate Tailscale connectivity from Hostinger to Hetzner for CBD-Data queue path.
- Create CBD-Data-specific Docker networks per v3 PRD §10.4.
- Harden `cbd-worker.service` configuration.
- Review UFW rules for CBD-Data services.
- Establish CBD-Data-specific secret-management entries.

Exit gate: CBD-Data-specific network ACLs deny cross-project access by default. Cross-project denial tests pass for CBD-Data queue and database access.

---

### Phase 3 — Hostinger Shared Platform (CBD-Data Slice)

**Owner:** implementation agent  
**Source:** v3 PRD §19 Phase 3, §§7.1, 8.1, 9 (2026-08-04)  
**Blocked until:** ADR-CBD-001 accepted

Tasks:
- Deploy CBD-Data frontend container/service per accepted architecture ADR.
- Deploy CBD-Data API container/service.
- Deploy CBD-Data database and project roles (PostgreSQL/PgBouncer per ADR, or MySQL retained).
- Create `/srv/brandon-files/cbddata/` file namespaces per v3 PRD §9.2.
- Deploy internal ingest API pattern for CBD-Data scoped ingest per v3 PRD §8.2.
- Deploy CBD-Data monitoring collectors.
- Establish local backup staging.

Exit gate: Shared services healthy for CBD-Data slice. No public internal ports. CBD-Data-specific health endpoint responds. Test CBD-Data deploys end-to-end to Hostinger.

---

### Phase 4 — Hetzner Shared Compute (CBD-Data Slice)

**Owner:** implementation agent  
**Source:** v3 PRD §19 Phase 4, §§7.2, 13.2–13.4 (2026-08-04)  
**Blocked until:** ADR-CBD-002 (worker placement) and Gate-004 (enrichment authorization) are authorized

CBD-Data production scraping and enrichment is Hetzner priority 4 (source: v3 PRD §13.2 Hetzner Resource Priorities, 2026-08-04).

Tasks:
- Deploy or validate RabbitMQ on Hetzner.
- Create and fully configure virtual host `/cbddata` with project-specific user, exchange, queues, permissions, rate policies, and dead-letter queue.
- Implement CBD-Data queue naming per v3 PRD §7.2.
- Deploy CBD-Data scraper, enrichment, AI workers, export workers per accepted audit.
- Create CBD-Data workspace with disk quota, retention job, cleanup logs.
- Deploy Qdrant collection `cbddata_<dataset>_<embedding_version>` per v3 PRD §7.2.
- Establish CBD-Data result-ingest authentication per v3 PRD §8.2.
- Configure browser pool isolation with mandatory tenant identifier and per-domain rate limits.
- Apply explicit concurrency limits, queue prefetch limits, job timeouts, retry policies, and maximum job payload per v3 PRD §13.3.
- Implement backpressure controls per v3 PRD §13.4.

Exit gate: Test job flows from Hostinger to Hetzner RabbitMQ `/cbddata` and back. Cross-project queue access is denied. CBD-Data queue isolation is proven. Backpressure behavior validated.

---

### Phase 5 — CBD-Data Project Rollout (Last in Phase 5 Sequence)

**Owner:** implementation agent; approved by Captain, Eric, Brandon  
**Source:** v3 PRD §19 Phase 5, §20.4 (2026-08-04)  
**Blocked until:** Gate-004 authorized; all prior phases complete

CBD-Data is last in Phase 5 because it exercises the heaviest data and processing path and its rollout is the final capacity and backpressure validation (source: v3 PRD §19 Phase 5 ordering rationale). Whoosh must complete (or have its blocker resolved) before CBD-Data's turn.

Tasks (in order):
1. Deploy CBD-Data frontend.
2. Deploy CBD-Data API.
3. Deploy CBD-Data database and roles.
4. Deploy CBD-Data file namespaces.
5. Deploy CBD-Data queue namespace on Hetzner.
6. Deploy CBD-Data required workers only (per accepted audit; no speculative services).
7. Configure CBD-Data dedicated Namecheap backup target (requires operator input — ADR-CBD-004).
8. Configure CBD-Data monitoring.
9. Run CBD-Data-specific smoke test (business search → job record → queue → worker → ingest → export).
10. Run CBD-Data isolation test (deny access to other project queues/databases/files).
11. Run CBD-Data restore test.
12. Run CBD-Data backpressure test (verify backpressure rather than outage per v3 PRD §13.4).
13. Obtain signoff from Eric and Dubz.

Exit gate: All 30 acceptance criteria are satisfied or explicitly deferred with documented owners and dates. Eric and Dubz sign off.

---

### Phase 6 — CI/CD and Release Controls

**Owner:** implementation agent  
**Source:** v3 PRD §19 Phase 6, §12 (2026-08-04)

Tasks:
- Add CBD-Data CI workflow per v3 PRD §12.
- Add container image scanning.
- Add secret scanning.
- Add migration dry run.
- Add staging deployment for CBD-Data.
- Add CBD-Data-specific smoke tests.
- Add production approval gate.
- Add rollback action demonstrated.

Exit gate: A complete CBD-Data release and rollback has been demonstrated without manual configuration drift.

---

### Phase 7 — Backup and DR

**Owner:** implementation agent; requires operator input  
**Source:** v3 PRD §19 Phase 7, §§15, 16.2, 16.5 (2026-08-04)  
**Blocked until:** ADR-CBD-004 (Namecheap target assignment)

Tasks:
- Assign one Namecheap target exclusively to CBD-Data per v3 PRD §7.3.
- Deploy encrypted backup transfer to CBD-Data Namecheap target (requires operator input).
- Deploy manifests, checksums, and retention per v3 PRD §15.4.
- Run first restore test.
- Write `DR-CBD-DATA.md` per v3 PRD §16.2.
- Run CBD-Data DR drill.
- Record actual RPO and RTO.

Exit gate: CBD-Data has a recent verified backup and successful restore report. Shared-hosting limitations, if any, are explicitly documented.

---

### Phase 8 — Load and Failure Testing

**Owner:** implementation agent  
**Source:** v3 PRD §19 Phase 8, §13.4 (2026-08-04)

Tests (CBD-Data-specific):
- CBD-Data frontend load test.
- CBD-Data database connection saturation test.
- Hetzner CBD-Data worker saturation test.
- CBD-Data queue backlog test.
- CBD-Data worker crash and redelivery test (verify duplicate-safe behavior).
- CBD-Data browser leak test (if browser pool is used).
- CBD-Data disk-fill warning test.
- CBD-Data Tailscale interruption test.
- CBD-Data Hetzner outage simulation (verify Hostinger remains available).
- CBD-Data rollback test.
- CBD-Data backpressure test (verify backpressure rather than outage under heavy load per v3 PRD §13.4).

Exit gate: No critical unresolved failure. Capacity baseline and recommended CBD-Data worker defaults documented.

---

### Phase 9 — Production Handoff

**Owner:** Captain controls handoff; implementation agent delivers  
**Source:** v3 PRD §19 Phase 9 (2026-08-04)

Deliver:
- Architecture diagrams for CBD-Data.
- Service catalog entry for CBD-Data services.
- Inventory for CBD-Data.
- Access matrix for CBD-Data.
- DNS matrix for `cbd-data.com`.
- Deployment guide for CBD-Data.
- Backup guide for CBD-Data.
- Restore evidence for CBD-Data.
- `DR-CBD-DATA.md` runbook.
- Monitoring links for CBD-Data.
- Alert response guide for CBD-Data.
- Release manifest for CBD-Data.
- Known limitations for CBD-Data.
- Final signoff from Eric, Dubz, and Brandon.

Exit gate: All applicable acceptance boxes checked. Eric approves client and production acceptance. Brandon receives approved handoff summary.

---

## 9. Risks

### 9.1 Architecture Mismatch — HIGH (Named Blocker)

Current CBD-Data runs PHP/MySQL and mixed deployment. The v3 PRD targets Hostinger PostgreSQL/PgBouncer and Hetzner compute. No accepted ADR maps existing software to the target. Work may proceed on the current architecture but cannot be promoted to v3 production until ADR-CBD-001 is accepted.

**Mitigation:** Obtain canonical application architecture ADR before Phase 3. All CBD-Data implementation lanes must reference the ADR outcome.

**Source:** [PER TRACEABILITY] PRD_DELIVERY_MAP.md unresolved area 2.

---

### 9.2 Enrichment Adapter Gap — HIGH (Named Blocker)

Gate-CBD-ENRICH-003 proves only the bounded broker/runtime slice. Without a publisher/consumer adapter, project_id injection, idempotency key, durable persistence, and durable restore, Gate-004 and production cutover cannot proceed.

**Mitigation:** Implement Lane B durable job and isolation adapter per PRD_DELIVERY_MAP.md Lane B before Phase 5 cutover.

**Source:** [PER TRACEABILITY] `cbd-data-enrichment-gap`.

---

### 9.3 AminoVPS vs Hetzner Placement Ambiguity — MEDIUM (Named Blocker)

The service catalogue records `cbd-worker.service` on AminoVPS as of 2026-09-15; the dated canary report (2026-08-02) instead records the service inactive/disabled as attested 2026-07-31 and unavailable access. Current activity is UNKNOWN. Historical AminoVPS placement is not the v3 PRD target; do not conflate it with current service state or v3 target delivery.

**Mitigation:** Do not present AminoVPS placement as v3-compliant. Track migration to Hetzner as ADR-CBD-002 with explicit authorization.

**Source:** [PER TRACEABILITY] `cbd-worker-canary`; PRD_DELIVERY_MAP.md unresolved area 2; SERVICE_CATALOG.md `cbd-worker`.

---

### 9.4 Backup/DR Operator Input Dependency — MEDIUM

No live CBD-Data backup to Namecheap can be configured without operator input. This blocks Phase 7.

**Mitigation:** Captain provides the required input (ADR-CBD-004). Phase 7 is held until input is received.

**Source:** [PER TRACEABILITY] `backup-dr`; PRD_DELIVERY_MAP.md unresolved area 6.

---

### 9.5 Cross-Project Isolation Not Evidenced — MEDIUM (Platform Blocker)

No accepted evidence proves CBD-Data queue, database, file, or Qdrant isolation from other projects. A CBD-Data-specific incident could affect other projects or vice versa.

**Mitigation:** Implement and test cross-project isolation per v3 PRD §§7.2, 8.1, 8.3, 9, 10.4, 11.5. Do not deploy CBD-Data to production until isolation is proven.

**Source:** [PER TRACEABILITY] `platform-isolation`; PRD_DELIVERY_MAP.md unresolved area 3.

---

### 9.6 Hub Application Delivery Delay — LOW (Platform Blocker)

Hub application deployment is blocked on operator input, secret store, and DNS/TLS gates. CBD-Data ingest path must be verified as independent of unresolved hub services.

**Mitigation:** Verify CBD-Data ingest path does not depend on unresolved hub services before Phase 4. Escalate dependency to Captain if found.

**Source:** [PER TRACEABILITY] PRD_DELIVERY_MAP.md unresolved area 4.

---

### 9.7 Gate-004 Authorization Never Obtained — HIGH (Named Blocker)

Gate-004 and cutover remain unauthorized per PRD_TRACEABILITY.md `cbd-data-enrichment-gap`. Production cutover without explicit authorization is prohibited.

**Mitigation:** Do not proceed to production cutover without Gate-004 and explicit authorization from Eric and Dubz.

**Source:** [PER TRACEABILITY] `cbd-data-enrichment-gap`.

---

## 10. Required Evidence to Change Any Status Here

| Status to change | Evidence required | Owner |
|---|---|---|
| End-to-end job flow | Executable test: Hostinger API → PostgreSQL job record → RabbitMQ publish → Hetzner worker → scoped ingest → acknowledgment | Implementation agent |
| Publisher/consumer adapter | Working adapter code, tested against real or mock RabbitMQ, with project_id injection and idempotency key | Implementation agent |
| Idempotency key implementation | Test proving duplicate submission does not produce duplicate leads or charges | Implementation agent |
| Durable persistence/restore | Backup and restore test for job records, queue state, and export files | Implementation agent |
| Gate-004 authorization | Approved cutover plan with test evidence and explicit Eric/Dubz authorization | Eric and Dubz |
| Production backup to Namecheap | Live encrypted backup transfer, manifest, and successful restore test | Implementation agent (requires operator input) |
| CI/CD pipeline | Passing GitHub Actions workflow with all gates per v3 PRD §12 | Implementation agent |
| Observability | Metrics, logs, and alerts deployed and tested per v3 PRD §14 | Implementation agent |
| Cross-project isolation | Worker denial tests, project-scoped ingest test, database role isolation test, file namespace test | Implementation agent |
| Qdrant collection isolation | Named `cbddata_*` collection with separate credentials and snapshot test | Implementation agent |
| Hetzner target placement | ADR-CBD-002 + migration plan + explicit authorization + executed migration + acceptance test on Hetzner | Eric and Dubz (authorization); implementation agent (migration) |
| Canonical application architecture ADR | Accepted ADR document choosing PHP/MySQL retention or PostgreSQL/PgBouncer adoption | Eric and Dubz |
| End-to-end smoke test | Passing test covering public site → job submission → Hetzner processing → result → export | Implementation agent |
| `DR-CBD-DATA.md` | Approved runbook per v3 PRD §16.2 | Implementation agent |
| CBD-Data-specific observability | Project-scoped metrics, logs, and alerts | Implementation agent |
| Live production deployment | Full Phase 5 exit gate evidence and Eric/Dubz/Brandon signoff | Captain, Eric, Dubz, Brandon |

---

## 11. ADR / Decision Items Required

### ADR-CBD-001: Canonical Application Architecture

**Question:** Should CBD-Data retain its current PHP/MySQL/mixed deployment, or adopt the v3 PRD Hostinger PostgreSQL/PgBouncer / Hetzner compute target?

**Required before:** Phase 3. **Status:** Required; currently BLOCKED (DEPENDENCY: unresolved area 2).

**Decision owner:** Eric and Dubz.

**Input needed:** Gate C audit results, cost/complexity analysis of migration vs retention, Brandon's business priorities.

**Source:** [PER TRACEABILITY] PRD_DELIVERY_MAP.md unresolved area 2.

---

### ADR-CBD-002: Worker Placement — AminoVPS vs Hetzner

**Question:** Should CBD-Data workers remain on AminoVPS temporarily, or migrate to Hetzner?

**Required before:** Phase 4. **Status:** BLOCKED (AUTHORIZATION).

**Decision owner:** Eric and Dubz.

**Input needed:** Hetzner capacity assessment, AminoVPS risk profile, migration cost.

**Source:** [PER TRACEABILITY] `cbd-worker-canary`; PRD_DELIVERY_MAP.md unresolved area 2; SERVICE_CATALOG.md `cbd-worker`.

---

### ADR-CBD-003: Enrichment Adapter Scope for Gate-004

**Question:** What is the minimum viable enrichment adapter scope for Gate-004 authorization?

**Required before:** Phase 5 cutover. **Status:** BLOCKED (AUTHORIZATION).

**Decision owner:** Eric and Dubz.

**Input needed:** Lane B implementation evidence, idempotency test results, durable persistence evidence.

**Source:** [PER TRACEABILITY] `cbd-data-enrichment-gap`.

---

### ADR-CBD-004: CBD-Data Namecheap DR Target Assignment

**Question:** Which Namecheap account/target is assigned to CBD-Data? Retention policy, RPO/RTO, key custody arrangement?

**Required before:** Phase 7. **Status:** BLOCKED (OPERATOR_INPUT).

**Decision owner:** Captain (operator input).

**Input needed:** Namecheap account credentials for CBD-Data DR target, retention policy, accepted RPO/RTO targets, recovery key custody arrangement.

**Source:** [PER TRACEABILITY] `backup-dr`; PRD_DELIVERY_MAP.md unresolved area 6.

---

### ADR-CBD-005: AnythingLLM / Vector Store Relationship for CBD-Data

**Question:** Does CBD-Data use a vector store? If so, is it served from the hub Qdrant or a project-scoped collection? What is the embedding backend?

**Required before:** Phase 5 (if vector store is used). **Status:** Required; currently UNKNOWN.

**Decision owner:** Eric and Dubz.

**Input needed:** CBD-Data Gate C audit results, Brandon hub architecture decision.

**Source:** [PER TRACEABILITY] PRD_DELIVERY_MAP.md unresolved area 4; SERVICE_CATALOG.md `brandon-anythingllm`.

---

## Provenance Summary

| Label | Meaning | Applied where |
|---|---|---|
| **[VERIFIED TODAY]** | Fresh measurement with command and output cited | None; no live verification was performed for this PRD repair |
| **[PER v3]** | Scope or target requirement in canonical v3, dated 2026-08-04; not implementation evidence | §0.1 product scope, §0.2/§0.3 planning and placement, §3–§4 scope, rollout, and acceptance criteria |
| **[PER TRACEABILITY]** | Ledger status/date/scope only; not broader acceptance | Statuses and blocker references in §§1, 2, 5–7. Gate-003 details rely on retained 2026-09-18 `status.txt`; reconstructed evidence notes lost raw test/checker output and leaves TDD/check acceptance UNKNOWN. |

---

*This PRD is derived from `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (v3.0, 2026-08-04). It inherits all unresolved cross-cutting platform blockers from PRD_DELIVERY_MAP.md lines 36–64. Acceptance criteria marked `UNKNOWN` are not invented; they require evidence that is not currently cited in the authoritative sources. The enrichment gap is stated precisely: Gate-CBD-ENRICH-003 proves only the bounded broker/runtime slice — no adapter, project_id, idempotency, durable persistence, end-to-end chain, or Gate-004 authorization.*
