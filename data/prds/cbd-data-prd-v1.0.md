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

CBD-Data is placed **last** in the Phase 5 rollout sequence because it exercises the heaviest data and processing path of the four projects. Its rollout is the final capacity and backpressure validation of the platform (source: v3 PRD §19 Phase 5 rationale).

The required placement is:

- **Hostinger KVM8:** public website, API, authentication, customer dashboards, file delivery, finalized exports, primary application control plane, PostgreSQL/PgBouncer.
- **Hetzner dedicated server:** scraping, browser automation, enrichment, AI-agent execution, background jobs, compute-heavy transformations, queue consumers, temporary working data, RabbitMQ virtual host, Qdrant collections.
- **Namecheap:** encrypted backups and recovery material for the CBD-Data project only; one dedicated target per project per v3 PRD §7.3.

---

## 0.1 Honest Verdict

CBD-Data has real Next/PHP source at `projects/cbd-data.com/` and accepted local evidence for scraping, enrichment, queue, export, storage, and compute placement discovery (BR-AUD-005, manifest line 11). Local restore/backup documents and tests exist. No accepted end-to-end Hostinger-to-Hetzner queue/isolation/restore/signoff chain is present. Gate-CBD-ENRICH-003 proves only the bounded broker/runtime slice — a private RabbitMQ `/cbddata` bootstrap and a deterministic local status helper. Gate-004 and production cutover remain unauthorized. Live worker placement on AminoVPS is not the PRD-v3 target and is AUTHORIZATION-blocked. PRD-wide acceptance is not proven.

---

## 1. Current State

| Item | Status | Source |
|---|---|---|
| Source audit | `EVIDENCED` | PRD_TRACEABILITY.md `cbd-data-source-and-audit`; PRD_DELIVERY_MAP.md |
| Scraping, enrichment, queue, export, storage, compute placement discovery | `EVIDENCED` | BR-AUD-005, manifest line 11; PRD_DELIVERY_MAP.md CBD-Data row |
| Bounded broker/runtime slice (private RabbitMQ `/cbddata` bootstrap + deterministic local status helper) | `EVIDENCED` | Gate-CBD-ENRICH-003 evidence.md, decision-and-rollback.md, tdd-evidence.md; PRD_TRACEABILITY.md `cbd-data-enrichment-gap` |
| Publisher/consumer adapter | `UNKNOWN` | Gate-CBD-ENRICH-003 notes; PRD_TRACEABILITY.md `cbd-data-enrichment-gap` |
| Project_id injection into jobs | `UNKNOWN` | Gate-CBD-ENRICH-003 notes; PRD_TRACEABILITY.md `cbd-data-enrichment-gap` |
| Idempotency key implementation | `UNKNOWN` | Gate-CBD-ENRICH-003 notes; PRD_TRACEABILITY.md `cbd-data-enrichment-gap` |
| Durable persistence and restore | `UNKNOWN` | Gate-CBD-ENRICH-003 notes; PRD_TRACEABILITY.md `cbd-data-enrichment-gap` |
| Gate-004 (enrichment authorization/cutover) | `BLOCKED` (AUTHORIZATION) | PRD_TRACEABILITY.md `cbd-data-enrichment-gap`; PRD_DELIVERY_MAP.md unresolved area 2 |
| End-to-end Hostinger-to-Hetzner queue/isolation/restore/signoff chain | `UNKNOWN` | PRD_DELIVERY_MAP.md CBD-Data row; PRD_TRACEABILITY.md `cbd-data-source-and-audit` |
| Local worker canary | `EVIDENCED` (local) | PRD_TRACEABILITY.md `cbd-worker-canary`; `data/cbd-worker-canary/report.md` |
| Live worker placement | `BLOCKED` (AUTHORIZATION) | PRD_TRACEABILITY.md `cbd-worker-canary`; PRD_DELIVERY_MAP.md unresolved area 2 |
| Current live placement on AminoVPS | `EVIDENCED` | SERVICE_CATALOG.md `cbd-worker`; BR-INV-001/report.md §Host 1 |
| PRD-v3 target placement on Hetzner | `UNKNOWN` | PRD_DELIVERY_MAP.md unresolved area 2 |
| Live placement on AminoVPS is NOT v3 target | `CONFIRMED` | PRD_DELIVERY_MAP.md unresolved area 2; PRD_TRACEABILITY.md `cbd-worker-canary` |
| Local restore/backup documents and tests | `EVIDENCED` | PRD_DELIVERY_MAP.md CBD-Data row |
| Production backup to Namecheap target | `UNKNOWN` | PRD_DELIVERY_MAP.md unresolved area 6; PRD_TRACEABILITY.md `backup-dr` |
| Application frontend on Hostinger | `UNKNOWN` | v3 PRD §§7.1, 20.4; no cited evidence in current sources |
| Application API on Hostinger | `UNKNOWN` | v3 PRD §§7.1, 20.4; no cited evidence in current sources |
| PostgreSQL database and project roles | `UNKNOWN` | v3 PRD §8.1; PRD_DELIVERY_MAP.md unresolved area 2 |
| PgBouncer connection pooling | `UNKNOWN` | v3 PRD §8.1; PRD_DELIVERY_MAP.md unresolved area 2 |
| File namespaces on Hostinger | `UNKNOWN` | v3 PRD §9; no cited evidence in current sources |
| CBD-Data RabbitMQ virtual host `/cbddata` on Hetzner | `EVIDENCED` (private bounded slice; production placement TBD) | PRD_DELIVERY_MAP.md Lane B; Gate-CBD-ENRICH-003 |
| Qdrant collection isolation | `UNKNOWN` | PRD_DELIVERY_MAP.md unresolved area 3; PRD_TRACEABILITY.md `platform-isolation` |
| CI/CD and release controls | `UNKNOWN` | PRD_DELIVERY_MAP.md unresolved area 5; PRD_TRACEABILITY.md `platform-release-controls` |
| Observability (metrics/logs/alerts) | `UNKNOWN` | PRD_DELIVERY_MAP.md unresolved area 7; PRD_TRACEABILITY.md `observability` |
| Canonical application architecture (PHP/MySQL vs PostgreSQL target) | `UNKNOWN` | PRD_DELIVERY_MAP.md unresolved area 2; PRD_TRACEABILITY.md `coredistro-source-runtime` notes |
| Live end-to-end smoke test | `UNKNOWN` | v3 PRD §20.4; no cited evidence in current sources |
| DR runbook `DR-CBD-DATA.md` | `UNKNOWN` | v3 PRD §16.2 |
| End-to-end isolation test (cross-project denial) | `UNKNOWN` | PRD_DELIVERY_MAP.md unresolved area 3; PRD_TRACEABILITY.md `platform-isolation` |
| Reusable HD2 client baseline (host-profile overlay) | `UNKNOWN` | PRD_DELIVERY_MAP.md unresolved area 9 |
| Canonical source provenance (historical Git blob) | `BLOCKED` | PRD_TRACEABILITY.md `platform-source-provenance` |

---

## 2. What Is Actually Proven vs. What Is Not

### 2.1 Proven (Working Evidence Exists)

The following have accepted evidence, but PRD-wide production acceptance is not proven:

- **Source exists and is audited.** Real Next/PHP project source at `projects/cbd-data.com/`. BR-AUD-005 covers scraping, enrichment, queue, export, storage, and compute placement discovery. Manifest line 11 is accepted. Source: PRD_TRACEABILITY.md `cbd-data-source-and-audit`; PRD_DELIVERY_MAP.md CBD-Data row.

- **Bounded broker/runtime slice is implemented locally.** Gate-CBD-ENRICH-003 proves a private RabbitMQ `/cbddata` virtual host bootstrap on `brandon-compute` and a deterministic `cbd_initial_job_status()` local status helper used at both import insert sites. RED/GREEN/REFACTOR evidence and a full local-suite `CHECK_PASS` are recorded in the Gate-003 evidence tree. Source: PRD_TRACEABILITY.md `cbd-data-enrichment-gap`; PRD_DELIVERY_MAP.md Lane B.

- **Local restore/backup documents and tests exist.** Source: PRD_DELIVERY_MAP.md CBD-Data row.

- **Current live worker placement is known.** A `cbd-worker.service` systemd unit runs on `srv1137994-aminolifesciences` (AminoVPS, Hostinger KVM8, Tailscale IP `100.69.211.43`). Source: SERVICE_CATALOG.md `cbd-worker`; BR-INV-001/report.md §Host 1.

### 2.2 Not Proven (PRD-Wide Acceptance Not Shown)

- **No publisher/consumer adapter.** Gate-CBD-ENRICH-003 proves only the bounded broker/runtime bootstrap and local status helper. No publisher adapter, consumer adapter, project_id injection, idempotency key, durable persistence, or durable restore path exists. Source: PRD_TRACEABILITY.md `cbd-data-enrichment-gap` notes.

- **No end-to-end Hostinger-to-Hetzner queue/isolation/restore/signoff chain.** The full job flow (Hostinger API → Hostinger PostgreSQL job record → publish to Hetzner RabbitMQ `/cbddata` → Hetzner worker → scoped ingest → acknowledgment) is not accepted end-to-end. Source: PRD_DELIVERY_MAP.md CBD-Data row; PRD_TRACEABILITY.md `cbd-data-source-and-audit`.

- **No production cutover authorization.** Gate-004 and cutover remain unauthorized. Source: PRD_TRACEABILITY.md `cbd-data-enrichment-gap`; PRD_DELIVERY_MAP.md unresolved area 2.

- **No PRD-v3 target placement.** Live placement on AminoVPS is not the PRD-v3 target (Hetzner compute plane). Migration requires separate authority. Source: PRD_TRACEABILITY.md `cbd-worker-canary`; PRD_DELIVERY_MAP.md unresolved area 2.

- **No application database, PgBouncer, file namespaces, frontend, or API on Hostinger.** The canonical application architecture is unresolved: current evidence shows PHP/MySQL and mixed deployment; the v3 target is Hostinger PostgreSQL/PgBouncer. No accepted ADR maps the existing software to that target. Source: PRD_DELIVERY_MAP.md unresolved area 2.

- **No live production backup to Namecheap.** Designs and synthetic harness exist; no live encrypted off-host provider assignment, per-project target proof, real restore, measured RPO/RTO, or required DR drill evidence is accepted. Source: PRD_DELIVERY_MAP.md unresolved area 6; PRD_TRACEABILITY.md `backup-dr`.

- **No CI/CD release controls.** Accepted local hardening/self-tests are not the PRD's project CI/CD, container-build, dependency/vulnerability, migration-dry-run, staging, smoke, health, and rollback gates. Source: PRD_DELIVERY_MAP.md unresolved area 5; PRD_TRACEABILITY.md `platform-release-controls`.

- **No observability.** Inventory/design references metrics/logs/alerts, but no complete four-project SLO/alert/restore-age implementation is evidenced. Source: PRD_DELIVERY_MAP.md unresolved area 7; PRD_TRACEABILITY.md `observability`.

- **No cross-project isolation evidence.** No accepted evidence proves four production queue namespaces, worker denial tests, project-scoped ingest, file namespaces, database roles, or Qdrant collection isolation end-to-end. Source: PRD_DELIVERY_MAP.md unresolved area 3; PRD_TRACEABILITY.md `platform-isolation`.

---

## 3. Scope

This PRD covers:

- CBD-Data public application (`cbd-data.com`) on Hostinger: frontend, API, authentication, customer dashboards, file delivery, finalized CSV/report exports, PostgreSQL/PgBouncer.
- CBD-Data scraping, browser automation, enrichment, AI-agent execution, batch-processing, and worker workloads on Hetzner: RabbitMQ virtual host `/cbddata`, Qdrant collections, browser pools, compute workers, temporary workspace.
- CBD-Data dedicated Namecheap backup/DR target: encrypted off-host backups, manifests, restore tests, DR runbook.
- Queue-based job submission from Hostinger to Hetzner with durable job records, idempotency, scoped ingest, and project isolation.
- CI/CD pipeline, smoke tests, isolation tests, backup restore tests, monitoring, and alerting for CBD-Data.
- Gate-CBD-ENRICH-003 bounded broker/runtime slice as a prerequisite foundation.

---

## 4. Non-Goals

The following are explicitly excluded:

- Kubernetes or multi-node Kubernetes clusters.
- Redesign of the CBD-Data website or application without documented reason.
- Direct public exposure of PostgreSQL, RabbitMQ, Qdrant, Coolify, Grafana, or internal admin tools.
- Storing secrets in Git, Docker images, plaintext backups, agent memory, logs, or issue comments.
- Sharing one unrestricted database user, queue user, API key, or backup credential across multiple projects.
- Allowing agents to change DNS, delete data, rotate production secrets, or destroy infrastructure without human approval.
- Live worker placement on AminoVPS — this is not the PRD-v3 target and is not authorized.
- PRD-wide platform CI/CD, observability, backup/DR, or isolation until the shared platform blockers are resolved.
- Unreviewed migration of existing production data.
- Replacement of working application frameworks without a documented reason.
- Moving public websites or APIs to Hetzner.

---

## 5. Open Blockers (Domain-Specific)

### 5.1 No Accepted End-to-End Hostinger-to-Hetzner Job Flow

**Status:** `UNKNOWN` — no accepted evidence proves the full queue/isolation/restore/signoff chain.

**What would unblock it:** Implement the full job flow per v3 PRD §§7.1–7.2, 8.2–8.5: Hostinger API job record → RabbitMQ `/cbddata` publish → Hetzner worker → scoped ingest → acknowledgment. Add project_id injection, idempotency key, durable persistence, and project isolation tests. Run end-to-end smoke test. Obtain signoff.

**Owner:** Implementation agent (Saad or approved HD2 agent), with Eric/Dubz approval for architecture choice.

---

### 5.2 Canonical Application Architecture Unresolved

**Status:** `BLOCKED` (DEPENDENCY: unresolved area 2 from PRD_DELIVERY_MAP.md)

**What would unblock it:** An accepted ADR choosing retention of PHP/MySQL where proven, or adoption of PostgreSQL/PgBouncer per the v3 target. Until then, no accepted mapping exists between existing software and the PRD target. This affects the application database, file namespaces, and deployment architecture.

**Owner:** Eric and Dubz (architecture decision); implementation team (technical mapping).

---

### 5.3 AUTHORIZATION: Gate-004 and Enrichment Cutover Remains Closed

**Status:** `BLOCKED` (AUTHORIZATION)

**What would unblock it:** A publisher/consumer adapter, project_id injection, idempotency key, durable persistence/restore, and an accepted end-to-end acceptance test. Gate-004 and production cutover require an accepted cutover plan and explicit authorization.

**Owner:** Eric and Dubz (authorization); implementation team (technical implementation).

---

### 5.4 Live Worker Placement Requires PRD-V3 Target Authority

**Status:** `BLOCKED` (AUTHORIZATION)

The current `cbd-worker.service` on AminoVPS is documented and working (source: SERVICE_CATALOG.md `cbd-worker`), but it is not the PRD-v3 target. Migration to Hetzner requires separate authority and an accepted migration plan.

**What would unblock it:** An accepted migration plan targeting Hetzner, with explicit authorization from Eric and Dubz.

**Owner:** Eric and Dubz (authorization); implementation team (migration).

---

### 5.5 No Live Production Backup to Namecheap

**Status:** `UNKNOWN` — blocked on operator input per PRD_DELIVERY_MAP.md unresolved area 6.

**What would unblock it:** Operator supplies provider/account for CBD-Data's Namecheap DR target, retention policy, accepted RPO/RTO, and recovery-key custody. Then: assign one Namecheap target per project per v3 PRD §7.3, configure encrypted backup transfer, run first restore test, write `DR-CBD-DATA.md`, run drill, record actual RPO/RTO.

**Owner:** Captain (operator input); implementation team (backup configuration).

---

## 6. Shared Platform Blockers

These UNKNOWN/BLOCKED items gate CBD-Data regardless of its own progress. Source for all: PRD_DELIVERY_MAP.md lines 36–64.

### 6.1 Project Coverage Gap — Whoosh Coordinates Missing

**Status:** `BLOCKED` (DEPENDENCY: COORDINATES_MISSING)

Whoosh audit `BR-AUD-004` is `BLOCKED_BY_DEPENDENCY`. Exact repository, hosting, runtime, and production IP are required before the placement and approval chain can close. This affects the sequencing of Phase 5 (CBD-Data is last; Whoosh is second).

**What would unblock it:** Captain or Brandon provides Whoosh repository/hosting/runtime/IP coordinates.

---

### 6.2 Canonical Application Architecture Unresolved

**Status:** `BLOCKED` (DEPENDENCY: architecture decision)

Current Core/CBD evidence is PHP/MySQL and mixed deployment. PRD v3 describes Hostinger PostgreSQL/PgBouncer, project databases/roles, Hostinger APIs/files, Hetzner queues/workers, and project-scoped ingest. No single accepted source/ADR maps existing software to that target.

**What would unblock it:** An accepted ADR choosing retention of PHP/MySQL where proven, or adoption of PostgreSQL/PgBouncer per project.

---

### 6.3 Cross-Project Runtime Isolation

**Status:** `UNKNOWN`

No accepted evidence proves four production queue namespaces, worker denial tests, project-scoped ingest, file namespaces, database roles, or Qdrant collection isolation end-to-end.

**What would unblock it:** Accepted evidence for four RabbitMQ vhosts, worker denial tests, project-scoped ingest, file namespaces, database roles, and Qdrant collection isolation.

---

### 6.4 Hub Application Delivery

**Status:** `BLOCKED` (OPERATOR_INPUT)

Hub host services (OpenResty/OnePanel, PostgreSQL, Redis, Qdrant, LiteLLM with placeholder keys) are installed. Application deployment remains separately queued. LiteLLM placeholder keys prevent a working gateway. AnythingLLM backend/vector-store relationship and Brandon-vs-HD2 data boundary remain unknown.

**What would unblock it:** Approved secret store, backup/restore, embedding/vector backend, per-project isolation, and DNS/TLS gate before customer documents. Resolve AnythingLLM backend/vector-store ownership.

---

### 6.5 Release Controls (CI/CD)

**Status:** `UNKNOWN`

Accepted local hardening/self-tests are not the PRD's project CI/CD, container-build, dependency/vulnerability, migration-dry-run, staging, smoke, health, and rollback gates for all four applications.

**What would unblock it:** Per-project CI/CD pipeline per v3 PRD §12, including container build, vulnerability scan, secret scan, migration dry run, staging deploy, smoke test, health gate, rollback demonstrated.

---

### 6.6 Backup/DR

**Status:** `UNKNOWN` (OPERATOR_INPUT)

Designs and synthetic harness exist. No live encrypted off-host provider assignment, per-project target proof, real restore, measured RPO/RTO, or required DR drill evidence is accepted. `BR-HUB-010` remains `BLOCKED_OPERATOR_INPUT` for provider/account, retention, RPO/RTO, and key custody.

**What would unblock it:** Operator supplies provider/account, retention, RPO/RTO, key custody; then live encrypted backup, restore rehearsal, actual RPO/RTO measurement.

---

### 6.7 Observability

**Status:** `UNKNOWN`

Inventory/design references metrics/logs/alerts, but no complete four-project SLO/alert/restore-age implementation is evidenced.

**What would unblock it:** Metrics collectors deployed on both primary hosts, logs aggregated and searchable by project/service/release/request/job, alerts tested, backup and restore age visible, queue and worker dashboards visible, AI/API costs visible by project where relevant.

---

### 6.8 Canonical Source Provenance

**Status:** `BLOCKED` (DEPENDENCY: historical Git blob absent)

The canonical PRD is restored in the warehouse at `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`. The historical Git blob `b98c887b8abdf0041d52faf2405ec5a76ec8fcf2` remains absent from the current object database. This matters only if exact-byte provenance is required for final signoff.

**What would unblock it:** Recover the historical Git blob only if exact-byte historical provenance is required. Otherwise, the warehouse copy is authoritative.

---

### 6.9 Reusable HD2 Client Baseline Incomplete

**Status:** `UNKNOWN`

The accepted Hetzner/HD2stack recheck is placement and broker evidence, not a complete `/hard` host-baseline application. A future hardening pass must carry a host-profile overlay (provider, exact addresses, OS/role, named admin/key pointer, approved ingress, break-glass route, rollback window, and exceptions) and prove a fresh admin login before SSH finalization.

**What would unblock it:** A completed host-profile overlay and fresh-admin-login proof for the Hetzner compute host.

---

## 7. Acceptance Criteria

Each criterion is traceable to a v3 PRD section. Marked UNKNOWN where no cited evidence exists in the current sources.

- [ ] **AC-1:** Real Next/PHP project source exists at `projects/cbd-data.com/` and is version-controlled — `EVIDENCED` (BR-AUD-005; manifest line 11; PRD_DELIVERY_MAP.md). Source: PRD_TRACEABILITY.md `cbd-data-source-and-audit`.
- [ ] **AC-2:** Public site (`cbd-data.com`) serves over valid HTTPS with correct routing — `UNKNOWN` (no cited evidence in current sources; v3 PRD §20.4 requires this).
- [ ] **AC-3:** User can submit a permitted business search and receive a durable job record on Hostinger — `UNKNOWN` (v3 PRD §20.4; no cited evidence).
- [ ] **AC-4:** Job is routed to the CBD-Data RabbitMQ virtual host `/cbddata` — `EVIDENCED` for bounded local slice (Gate-CBD-ENRICH-003); full end-to-end `UNKNOWN`. Source: PRD_TRACEABILITY.md `cbd-data-enrichment-gap`.
- [ ] **AC-5:** Hetzner worker processes the job within limits — `UNKNOWN` (live placement is on AminoVPS, not Hetzner; PRD-v3 target placement not evidenced). Source: PRD_TRACEABILITY.md `cbd-worker-canary`.
- [ ] **AC-6:** Results return through the scoped ingest path with project_id and idempotency — `UNKNOWN` (Gate-CBD-ENRICH-003 proves local status helper only; publisher/consumer adapter, project_id, idempotency key not evidenced). Source: PRD_TRACEABILITY.md `cbd-data-enrichment-gap`.
- [ ] **AC-7:** CSV export is generated and served from Hostinger — `UNKNOWN` (v3 PRD §20.4; no cited evidence in current sources).
- [ ] **AC-8:** Duplicate delivery does not duplicate leads or charges — `UNKNOWN` (idempotency not evidenced). Source: PRD_TRACEABILITY.md `cbd-data-enrichment-gap`; v3 PRD §8.5.
- [ ] **AC-9:** Rate limits and plan quotas work — `UNKNOWN` (no cited evidence in current sources).
- [ ] **AC-10:** Large runs produce backpressure rather than an outage — `UNKNOWN` (v3 PRD §13.4; no cited evidence in current sources).
- [ ] **AC-11:** CBD-Data backup restores database, files, queue definitions, and vector snapshot where used — `UNKNOWN` (local restore/backup documents and tests exist; live Namecheap backup target and real restore not evidenced). Source: PRD_DELIVERY_MAP.md CBD-Data row.
- [ ] **AC-12:** CBD-Data RabbitMQ vhost and users are isolated from other projects — `UNKNOWN` (private `/cbddata` bootstrap is locally evidenced; four-vhost isolation and denial tests not evidenced). Source: PRD_DELIVERY_MAP.md unresolved area 3; PRD_TRACEABILITY.md `platform-isolation`.
- [ ] **AC-13:** CBD-Data data does not appear in another project's database, logs, files, or backup — `UNKNOWN` (cross-project isolation not evidenced). Source: PRD_DELIVERY_MAP.md unresolved area 3; PRD_TRACEABILITY.md `platform-isolation`.
- [ ] **AC-14:** `DR-CBD-DATA.md` exists and is approved — `UNKNOWN` (v3 PRD §16.2 lists this as required; no cited evidence in current sources).
- [ ] **AC-15:** CBD-Data CI/CD pipeline passes lint, tests, build, vulnerability scan, secret scan, migration dry run, staging deploy, smoke test, health gate, and rollback — `UNKNOWN` (v3 PRD §§12, 20.4; PRD_DELIVERY_MAP.md unresolved area 5).
- [ ] **AC-16:** CBD-Data observability (metrics, logs, alerts) is deployed and tested — `UNKNOWN` (PRD_DELIVERY_MAP.md unresolved area 7; PRD_TRACEABILITY.md `observability`).
- [ ] **AC-17:** One Namecheap target is assigned exclusively to CBD-Data with encrypted off-host backups — `UNKNOWN` (PRD_DELIVERY_MAP.md unresolved area 6; PRD_TRACEABILITY.md `backup-dr`).
- [ ] **AC-18:** Monthly backup restore test completed and recorded — `UNKNOWN` (v3 PRD §15.6; no cited evidence).
- [ ] **AC-19:** End-to-end smoke test passes (public site → job submission → Hetzner processing → result → export) — `UNKNOWN` (v3 PRD §20.4; no cited evidence).
- [ ] **AC-20:** Canonical application architecture ADR accepted — `BLOCKED` (DEPENDENCY: PRD_DELIVERY_MAP.md unresolved area 2).
- [ ] **AC-21:** Worker is migrated from AminoVPS to Hetzner with AUTHORIZATION — `BLOCKED` (AUTHORIZATION; current placement is on AminoVPS, not Hetzner). Source: PRD_TRACEABILITY.md `cbd-worker-canary`; PRD_DELIVERY_MAP.md unresolved area 2.

---

## 8. Rollout Sequence

CBD-Data is last in the Phase 5 rollout per the v3 PRD §19 Phase 5 ordering rationale: it exercises the heaviest data and processing path and its rollout is the final capacity and backpressure validation of the platform.

Exit gates are defined per phase; none may be bypassed.

### Phase 0 — Freeze and Baseline

**Owner:** Captain

Tasks:
- Confirm CBD-Data source snapshot at `projects/cbd-data.com/`.
- Capture current Docker/service state on `srv1137994-aminolifesciences`.
- Record current `cbd-worker.service` configuration.
- Export current RabbitMQ definitions if any.
- Back up existing data.
- Create infrastructure repository entries for CBD-Data.
- Record baseline metrics.

Exit gate: Complete baseline package exists. Rollback to current state is possible.

---

### Phase 1 — Inventory and Discovery

**Owner:** Captain / implementation agent

Tasks:
- Complete Gate A (Server Inventory) for Hostinger and Hetzner CBD-Data workloads.
- Complete Gate B (Namecheap Capability Classification) for the CBD-Data DR target.
- Complete Gate C (Application Audit) for CBD-Data — repository, runtime, dependencies, environment variables (names only), data stores, queues, file behavior, scheduled jobs, health checks, migration requirements, security concerns.
- Complete Gate D (Data Classification): label all persistent CBD-Data data sets.
- Complete Gate E (Ownership and Access): list all human and machine identities, required access, authentication method, MFA status.
- **Pre-requisite ADR:** Obtain accepted architecture decision (PHP/MySQL retention vs PostgreSQL/PgBouncer adoption) before Phase 3 begins.

Exit gate: Eric and Dubz approve the inventory and placement plan. Canonical application architecture ADR is accepted.

---

### Phase 2 — Shared Network and Security

**Owner:** implementation agent

Tasks (CBD-Data specific):
- Validate Tailscale connectivity from Hostinger to Hetzner for CBD-Data queue path.
- Create CBD-Data-specific Docker networks.
- Harden `cbd-worker.service` configuration.
- Review UFW rules for CBD-Data services.
- Establish CBD-Data-specific secret-management entries.

Exit gate: CBD-Data-specific network ACLs deny cross-project access by default. Cross-project denial tests pass for CBD-Data queue and database access.

---

### Phase 3 — Hostinger Shared Platform (CBD-Data Slice)

**Owner:** implementation agent

Tasks (CBD-Data project-specific):
- Deploy CBD-Data frontend container/service per accepted architecture ADR.
- Deploy CBD-Data API container/service.
- Deploy CBD-Data PostgreSQL database and project roles (or retain MySQL per architecture ADR).
- Deploy PgBouncer connection pooling if PostgreSQL is chosen.
- Create `/srv/brandon-files/cbddata/` file namespaces per v3 PRD §9.2.
- Deploy internal ingest API pattern for CBD-Data scoped ingest.
- Deploy CBD-Data monitoring collectors.
- Establish local backup staging.

Exit gate: Shared services healthy for CBD-Data slice. No public internal ports exposed. CBD-Data-specific health endpoint responds. Test CBD-Data can deploy end-to-end to Hostinger.

---

### Phase 4 — Hetzner Shared Compute (CBD-Data Slice)

**Owner:** implementation agent

Tasks (CBD-Data project-specific):
- Deploy or validate RabbitMQ on Hetzner.
- Create and configure virtual host `/cbddata` with project-specific user, exchange, queues, permissions, rate policies, and dead-letter queue per v3 PRD §7.2.
- Implement CBD-Data queue naming per v3 PRD §7.2 (`cbddata.scrape.jobs`, `cbddata.enrich.jobs`, `cbddata.export.jobs`, `cbddata.deadletter`, etc.).
- Deploy CBD-Data scraper, enrichment, AI workers, export workers per accepted audit.
- Create CBD-Data workspace with disk quota, retention job, and cleanup logs.
- Deploy Qdrant collection `cbddata_<dataset>_<embedding_version>` per v3 PRD §7.2.
- Establish CBD-Data result-ingest authentication per v3 PRD §8.2.
- Configure browser pool isolation with mandatory tenant identifier and per-domain rate limits.

Exit gate: Test job flows from Hostinger to Hetzner RabbitMQ `/cbddata` and back. Cross-project queue access is denied. CBD-Data queue isolation is proven.

---

### Phase 5 — CBD-Data Project Rollout (Last in Phase 5 sequence)

**Owner:** implementation agent; approved by Captain, Eric, and Brandon

Tasks (in order):
1. Deploy CBD-Data frontend.
2. Deploy CBD-Data API.
3. Deploy CBD-Data database and roles.
4. Deploy CBD-Data file namespaces.
5. Deploy CBD-Data queue namespace on Hetzner.
6. Deploy CBD-Data required workers only (per accepted audit; no speculative services).
7. Configure CBD-Data dedicated Namecheap backup target (requires operator input on account/credentials).
8. Configure CBD-Data monitoring.
9. Run CBD-Data-specific smoke test (business search → job record → queue → worker → ingest → export).
10. Run CBD-Data isolation test (deny access to other project queues/databases/files).
11. Run CBD-Data restore test.
12. Obtain signoff from Eric and Dubz.

**CBD-Data is placed last in Phase 5.** The v3 PRD explicitly states: "CBD-Data is last because it exercises the heaviest data and processing path. Its rollout becomes the final capacity and backpressure validation." (source: v3 PRD §19 Phase 5). The Whoosh project must complete (or have its blocker resolved) before CBD-Data's turn.

Exit gate: All 21 acceptance criteria are satisfied or explicitly deferred with documented owners and dates. Eric and Dubz sign off.

---

### Phase 6 — CI/CD and Release Controls

**Owner:** implementation agent

Tasks (CBD-Data project-specific):
- Add CBD-Data CI workflow per v3 PRD §12.
- Add container image scanning.
- Add secret scanning.
- Add staging deployment for CBD-Data.
- Add CBD-Data-specific smoke tests.
- Add production approval gate.
- Add rollback action demonstrated.
- Document CBD-Data release process.

Exit gate: A complete CBD-Data release and rollback has been demonstrated without manual configuration drift.

---

### Phase 7 — Backup and DR

**Owner:** implementation agent; requires operator input

Tasks:
- Assign one Namecheap target exclusively to CBD-Data per v3 PRD §7.3.
- Deploy encrypted backup transfer to CBD-Data Namecheap target (requires operator to supply account/credentials).
- Deploy manifests and retention per v3 PRD §15.4.
- Run first restore test.
- Write `DR-CBD-DATA.md` per v3 PRD §16.2.
- Run CBD-Data DR drill.
- Record actual RPO and RTO.

Exit gate: CBD-Data has a recent verified backup and successful restore report. Shared-hosting limitations, if any, are explicitly documented.

---

### Phase 8 — Load and Failure Testing

**Owner:** implementation agent

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

### 9.1 Architecture Mismatch (HIGH — Named Blocker)

Current CBD-Data runs PHP/MySQL and mixed deployment on Namecheap/AminoVPS. The v3 PRD targets Hostinger PostgreSQL/PgBouncer and Hetzner compute. No accepted ADR maps the existing software to the target. Work may proceed on the current architecture but cannot be promoted to PRD-v3 production until the ADR is accepted.

**Mitigation:** Obtain canonical application architecture ADR before Phase 3 begins. All CBD-Data implementation lanes must reference the ADR outcome.

---

### 9.2 Enrichment Adapter Gap (HIGH — Named Blocker)

Gate-CBD-ENRICH-003 proves only the bounded broker/runtime slice. Without a publisher/consumer adapter, project_id injection, idempotency key, durable persistence, and durable restore, Gate-004 and production cutover cannot proceed.

**Mitigation:** Implement Lane B durable job and isolation adapter per PRD_DELIVERY_MAP.md Lane B before Phase 5 cutover.

---

### 9.3 AminoVPS vs Hetzner Placement Ambiguity (MEDIUM — Named Blocker)

Current `cbd-worker.service` runs on AminoVPS (`srv1137994-aminolifesciences`). This is not the PRD-v3 target. Live placement authority must not be confused with PRD-v3 compliance.

**Mitigation:** Do not present AminoVPS placement as v3-compliant. Track migration to Hetzner as a separate authorized task with explicit authorization.

---

### 9.4 Backup/DR Operator Input Dependency (MEDIUM)

No live CBD-Data backup to Namecheap can be configured without operator input for the target account, credentials, retention, RPO/RTO, and key custody. This blocks Phase 7.

**Mitigation:** Captain provides the required input. Phase 7 is held until input is received.

---

### 9.5 Cross-Project Isolation Not Evidenced (MEDIUM — Platform Blocker)

No accepted evidence proves CBD-Data queue, database, file, or Qdrant isolation from other projects. A CBD-Data-specific incident could affect other projects or vice versa.

**Mitigation:** Implement and test cross-project isolation per v3 PRD §§7.2, 8.1, 8.3, 9, 10.4. Do not deploy CBD-Data to production until isolation is proven.

---

### 9.6 Hub Application Delivery Delay (LOW — Platform Blocker)

Hub application deployment is blocked on operator input, secret store, and DNS/TLS gates. CBD-Data's scoped ingest path may depend on hub services.

**Mitigation:** Verify CBD-Data ingest path does not depend on unresolved hub services before Phase 4. Escalate dependency to Captain if found.

---

### 9.7 Gate-004 Authorization Never Obtained (HIGH — Named Blocker)

Gate-004 and cutover remain unauthorized per PRD_TRACEABILITY.md. Production cutover without explicit authorization is prohibited.

**Mitigation:** Do not proceed to production cutover without Gate-004 and explicit authorization from Eric and Dubz.

---

## 10. Required Evidence to Change Any Status Here

To change any `UNKNOWN` to `EVIDENCED` or `DELIVERED`:

| Status to change | Evidence required | Owner |
|---|---|---|
| End-to-end Hostinger-to-Hetzner job flow | Executable test proving Hostinger API → PostgreSQL job record → RabbitMQ publish → Hetzner worker → scoped ingest → acknowledgment | Implementation agent |
| Publisher/consumer adapter | Working adapter code, tested against real or mock RabbitMQ, with project_id injection and idempotency key | Implementation agent |
| Idempotency key implementation | Test proving duplicate submission does not produce duplicate leads or charges | Implementation agent |
| Durable persistence/restore | Backup and restore test for job records, queue state, and export files | Implementation agent |
| Gate-004 authorization | Approved cutover plan with test evidence and explicit Eric/Dubz authorization | Eric and Dubz |
| Production backup to Namecheap | Live encrypted backup transfer, manifest, and successful restore test | Implementation agent (requires operator input) |
| CI/CD pipeline | Passing GitHub Actions workflow with all gates per v3 PRD §12 | Implementation agent |
| Observability | Metrics, logs, and alerts deployed and tested per v3 PRD §14 | Implementation agent |
| Cross-project isolation | Worker denial tests, project-scoped ingest test, database role isolation test, file namespace test | Implementation agent |
| Qdrant collection isolation | Named `cbddata_*` collection with separate credentials and snapshot test | Implementation agent |
| Hetzner target placement | Migration plan with explicit authorization, executed migration, acceptance test on Hetzner | Eric and Dubz (authorization); implementation agent (migration) |
| Canonical application architecture ADR | Accepted ADR document choosing PHP/MySQL retention or PostgreSQL/PgBouncer adoption per project | Eric and Dubz |
| End-to-end smoke test | Passing test covering public site → job submission → Hetzner processing → result → export | Implementation agent |
| DR-CBD-DATA.md | Approved runbook per v3 PRD §16.2 | Implementation agent |
| CBD-Data-specific observability | Project-scoped metrics, logs, and alerts | Implementation agent |
| Live production deployment | Full Phase 5 exit gate evidence and Eric/Dubz/Brandon signoff | Captain, Eric, Dubz, Brandon |

---

## 11. ADR / Decision Items Required

### ADR-CBD-001: Canonical Application Architecture

**Question:** Should CBD-Data retain its current PHP/MySQL/mixed deployment, or adopt the v3 PRD Hostinger PostgreSQL/PgBouncer / Hetzner compute target?

**Status:** Required before Phase 3. Currently UNKNOWN.

**Decision owner:** Eric and Dubz.

**Input needed:** Application audit results from Phase 1 (Gate C), cost/complexity analysis of migration vs retention, Brandon's business priorities.

---

### ADR-CBD-002: Worker Placement — AminoVPS vs Hetzner

**Question:** Should CBD-Data workers remain on AminoVPS (`srv1137994-aminolifesciences`) temporarily, or migrate directly to Hetzner (`brandon-compute`)?

**Status:** Required before Phase 4. Currently BLOCKED (AUTHORIZATION).

**Decision owner:** Eric and Dubz.

**Input needed:** Hetzner capacity assessment, AminoVPS risk profile, migration cost.

---

### ADR-CBD-003: Enrichment Adapter Scope (Gate-004)

**Question:** What is the minimum viable enrichment adapter scope for Gate-004 authorization?

**Status:** Required before Phase 5 cutover. Currently BLOCKED (AUTHORIZATION).

**Decision owner:** Eric and Dubz.

**Input needed:** Lane B implementation evidence, idempotency test results, durable persistence evidence.

---

### ADR-CBD-004: CBD-Data Namecheap DR Target Assignment

**Question:** Which Namecheap account/target is assigned to CBD-Data? What is the retention policy, RPO/RTO, and key custody arrangement?

**Status:** Required before Phase 7. Currently BLOCKED (OPERATOR_INPUT).

**Decision owner:** Captain (operator input).

**Input needed:** Namecheap account credentials for CBD-Data DR target, retention policy, accepted RPO/RTO targets, recovery key custody arrangement.

---

### ADR-CBD-005: AnythingLLM / Vector Store Relationship for CBD-Data Enrichment

**Question:** Does CBD-Data use a vector store? If so, is it served from the hub Qdrant or a project-scoped collection? What is the embedding backend?

**Status:** Required before Phase 5. Currently UNKNOWN.

**Decision owner:** Eric and Dubz.

**Input needed:** CBD-Data application audit (Gate C), Brandon hub architecture decision.

---

*This PRD is derived from `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (v3.0, 2026-08-04). It inherits all unresolved cross-cutting platform blockers from PRD_DELIVERY_MAP.md lines 36–64. Acceptance criteria marked UNKNOWN are not invented; they require evidence that is not currently cited in the authoritative sources.*
