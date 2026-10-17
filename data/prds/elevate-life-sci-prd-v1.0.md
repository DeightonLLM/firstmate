# Elevate Life Sci — Domain Infrastructure PRD v1.0

**Client:** Brandon / Elevate Life Sci
**Primary domain:** `elevatesci.com`
**Project code:** `elevate`
**Derived from:** `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (v3.0, 2026-08-04)
**Domain author:** HD2 agent — document work only; no source, config, host, or DNS changes
**Status:** Partially evidenced; customer-facing site is DELIVERED; PRD-wide acceptance is NOT proven
**Last updated:** 2026-10-17

---

## 0. Status Header

| Field | Value |
|---|---|
| Domain | Elevate Life Sci (`elevatesci.com`) |
| PRD version this derives from | `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` v3.0 |
| Date | 2026-10-17 |
| Honest one-line verdict | Only the static customer-facing site and TLS are DELIVERED; the API, queue, backup, isolation, and ops-console security acceptance are UNKNOWN or BLOCKED; this is NOT a completed PRD rollout. |

---

## 1. Current State

Status table using only `DELIVERED` / `EVIDENCED` / `IN_PROGRESS` / `BLOCKED` / `UNKNOWN` as defined by `PRD_TRACEABILITY.md`.

| Row | Status | Evidence source |
|---|---|---|
| Elevate customer-facing site (`elevate-site-live`) | **DELIVERED** | `PRD_DELIVERY_MAP.md` Elevate row; `PRD_TRACEABILITY.md` row `elevate-site-live`; manifest lines 42, 45 |
| Apex/www site live at `elevatesci.com` with valid TLS | **DELIVERED** | `PRD_DELIVERY_MAP.md` Elevate row; `BR-ELEVATE-IDENTITY-001` / `BR-ELEVATE-SEO-PERF-001` (cited in `PRD_DELIVERY_MAP.md`; evidence files not present in workspace — see §1 note) |
| 84-file static SEO/schema/image changes applied | **DELIVERED** | `PRD_DELIVERY_MAP.md` Elevate row; `BR-ELEVATE-SEO-PERF-001` (cited; evidence files not present in workspace) |
| `agents.elevatesci.com` dashboard/vhost with 200 path | **DELIVERED** | `PRD_DELIVERY_MAP.md` Elevate row; `BR-ELEVATE-SEO-PERF-001` (cited; evidence files not present in workspace) |
| Dashboard static route retained; `/api/*` returns local 503 | **EVIDENCED** | `ELEVATE_NGINX_ROUTE_20260919.md` §Verification (live Nginx test, 2026-09-19) |
| Dashboard host: `srv1137994-aminolifesciences` (`elevatesVPS`) | **EVIDENCED** | `SERVICE_CATALOG.md` record `elevate-dashboard`; `ELEVATE_NGINX_ROUTE_20260919.md` |
| Dashboard host Tailscale IP `100.69.211.43`, port 2222 | **EVIDENCED** | `HOSTS.md` record `srv1137994-aminolifesciences` |
| Dashboard authentication/allowlisting | **UNKNOWN** | `ELEVATE_NGINX_ROUTE_20260919.md` §Rollback: "Dashboard authentication/allowlisting also remains unresolved" |
| Ops provider adapter (`elevate-ops-provider-adapter`) | **BLOCKED** | `PRD_TRACEABILITY.md` row `elevate-ops-provider-adapter`; `SOFTWARE_LANES.md` Lane 1; `PRD_DELIVERY_MAP.md` Elevate row |
| Ops provider adapter — local mock-test implementation only | **EVIDENCED** | `SOFTWARE_LANES.md` Lane 1: adapter contract 23/23, metric states 59/59, Phase-4 controls 70/70, upstream PHP shape 37/37; `PRD_DELIVERY_MAP.md` Elevate row |
| Ops provider adapter — live/provider authority | **BLOCKED** (`AUTHORIZATION`) | `PRD_TRACEABILITY.md` row `elevate-ops-provider-adapter`; `SOFTWARE_LANES.md` Lane 1: "real provider keys, provider calls, live control-plane mutation remain separate gates" |
| Elevate operations console — unauthenticated status/job APIs exposed | **BLOCKED** (security remediation candidate) | `PRD_DELIVERY_MAP.md` lines 48–53; `console-parity-report.md` (file not present in workspace — see §1 note) |
| Ticket 0033 — aminolifesciences sweep (314 occurrences, 42 files → elevatesci-vps/ElevateSci) | **REPORTED_CLOSED** (needs own accepted artifact) | `PRD_DELIVERY_MAP.md` Elevate row: "reported CLOSED by HD2Stack"; traceability row for ticket 0033 itself still needs an accepted artifact |
| Elevate application architecture (target: Hostinger PostgreSQL/PgBouncer + Hetzner workers) | **UNKNOWN** | `PRD_DELIVERY_MAP.md` unresolved area 2; canonical ADR mapping existing software to v3 target is absent |
| Elevate queue namespace, worker isolation | **UNKNOWN** | `PRD_DELIVERY_MAP.md` unresolved area 3; cross-project runtime isolation not evidenced |
| Elevate backup target (Namecheap DR node per project) | **UNKNOWN** | `PRD_DELIVERY_MAP.md` unresolved area 6; no live encrypted off-host provider assignment for Elevate |
| Elevate CI/CD and release controls | **UNKNOWN** | `PRD_DELIVERY_MAP.md` unresolved area 5 |
| Elevate observability (metrics/logs/alerts) | **UNKNOWN** | `PRD_DELIVERY_MAP.md` unresolved area 7 |
| Amino/Elevate live placement on PRD-v3 target infrastructure | **UNKNOWN** | `PRD_TRACEABILITY.md` row `amino-elevate-live-placement`: "current placements are legacy, not PRD-v3 target" |
| Hub application delivery (LiteLLM placeholder keys; AnythingLLM backend/vector-store) | **BLOCKED** (cross-cutting) | `PRD_DELIVERY_MAP.md` unresolved area 4 |

> **§1 note on evidence files:** `PRD_DELIVERY_MAP.md` and `PRD_TRACEABILITY.md` cite `BRANDON REWORK/evidence/BR-ELEVATE-SEO-PERF-001/elevate-client-closeout-m3.md`, `BR-ELEVATE-IDENTITY-001`, `BR-ELEVATE-SEO-PERF-001`, `BR-ELEVATE-OPS-001`, and `BRANDON REWORK/evidence/BR-SAAS-PARITY-20260918/console-parity-report.md`. None of these files are present in the current workspace checkout. All DELIVERED/EVIDENCED rows above are grounded in the traceability documents' citations, not in direct file reads. The workspace has `ELEVATE_NGINX_ROUTE_20260919.md` (direct read, 2026-09-19) as the sole live-evidence file for Elevate. Rows citing absent evidence files are stated as the traceability documents state them and are NOT independently verified by this writer.

---

## 2. What Is Actually Proven vs What Is Not

### Proven (working evidence exists)

1. `elevatesci.com` apex/www serves a live static site over HTTPS with valid TLS. (Source: `PRD_DELIVERY_MAP.md` Elevate row; `BR-ELEVATE-IDENTITY-001` cited)
2. 84 static files received SEO, schema, and image changes. (Source: `PRD_DELIVERY_MAP.md` Elevate row; `BR-ELEVATE-SEO-PERF-001` cited)
3. `agents.elevatesci.com` vhost is live and serves a 200 path. (Source: `PRD_DELIVERY_MAP.md` Elevate row; `BR-ELEVATE-SEO-PERF-001` cited)
4. The vhost on `srv1137994-aminolifesciences` no longer proxies `/api/*` to HD2Stack; it returns local 503. (Source: `ELEVATE_NGINX_ROUTE_20260919.md` direct read)
5. Nginx on `srv1137994-aminolifesciences` reload was clean (nginx -t: success; service active). (Source: `ELEVATE_NGINX_ROUTE_20260919.md` direct read)
6. The ops provider adapter has a local mock-test implementation with passing contract tests. (Source: `SOFTWARE_LANES.md` Lane 1 direct read)

### Not proven (PRD-wide acceptance absent)

1. **Dashboard authentication** — no accepted artifact proves an auth wall, allowlisting, or session model for `agents.elevatesci.com`. (Source: `ELEVATE_NGINX_ROUTE_20260919.md` explicitly states "Dashboard authentication/allowlisting also remains unresolved")
2. **API backend** — the `/api/*` route intentionally returns 503 pending an Elevate-owned backend; no such backend exists in evidence. (Source: `ELEVATE_NGINX_ROUTE_20260919.md`)
3. **Elevate operations console security** — the console is reachable WITHOUT an auth wall and exposes unauthenticated status/job APIs. This is recorded as a security remediation candidate, NOT an accepted production-parity state. (Source: `PRD_DELIVERY_MAP.md` lines 48–53)
4. **Queue/worker/runtime** — no queue namespace, worker process, or Hetzner placement is evidenced for Elevate.
5. **Backup/DR** — no Namecheap DR target assignment, encrypted transfer, restore test, or RPO/RTO is evidenced for Elevate.
6. **Application architecture** — the PRD-v3 target (Hostinger PostgreSQL/PgBouncer + Hetzner queues/workers) is not mapped to existing Elevate software.
7. **Cross-project isolation** — no evidence proves Elevate's queue, files, database, or logs are isolated from other projects.
8. **CI/CD** — no project CI workflow, container build, staging deploy, smoke test, or rollback path is evidenced for Elevate.
9. **Observability** — no metrics, log aggregation, SLO, or alert is evidenced for Elevate.
10. **Amino/Elevate live placement on v3 target** — current Elevate VPS placement is legacy; PRD-v3 target is not confirmed live.

---

## 3. Scope

What this domain includes (per v3 PRD §5, adapted for Elevate):

- `elevatesci.com` public website and frontend — DELIVERED (static site and TLS)
- `agents.elevatesci.com` authenticated operations dashboard (vhost live; auth unresolved)
- Elevate-specific application source, if/when discovered
- Elevate project queue namespace on Hetzner (UNKNOWN — not deployed)
- Elevate-specific database role and credentials on Hostinger PostgreSQL (UNKNOWN — not provisioned)
- Elevate file namespaces (UNKNOWN)
- Elevate-specific CI/CD pipeline and release controls (UNKNOWN)
- One dedicated Namecheap DR target for Elevate (UNKNOWN)
- Elevate observability: metrics, logs, alerts (UNKNOWN)
- Elevate-specific ops provider adapter (BLOCKED_AUTHORIZATION; local mock-test EVIDENCED)
- Ticket 0033 sweep acceptance artifact (REPORTED_CLOSED; traceability row still open)

---

## 4. Non-Goals

What this domain explicitly does not include:

- Redesign of the `elevatesci.com` website — static site delivery only; no Figma, no broad redesign
- Clinical, PHI, prescription, or patient data processing — explicitly prohibited without a separate approved data-classification decision (v3 PRD §2.2)
- Replacement of working application frameworks without a documented reason (v3 PRD §4)
- Direct public exposure of PostgreSQL, RabbitMQ, Qdrant, or internal admin tools (v3 PRD §4)
- Secret storage in Git, Docker images, plaintext backups, agent memory, or logs (v3 PRD §4)
- Agents changing DNS, deleting data, rotating production secrets, or destroying infrastructure without human approval (v3 PRD §4)
- Live placement on Amino/Elevate legacy VPS being claimed as PRD-v3 target (v3 PRD; `amino-elevate-live-placement` traceability row)
- Mattermost or Jitsi rebranding — not Elevate domain scope
- Brandon hub application deployment — separate cross-cutting concern (v3 PRD §6.1, `PRD_DELIVERY_MAP.md` unresolved area 4)
- Whoosh or Core Distro or CBD-Data project-specific work

---

## 5. Open Blockers (Elevate-specific)

### Blocker E-1: Dashboard authentication unresolved

**Status:** `UNKNOWN`  
**What it blocks:** Authenticated portal access; portal acceptance criteria  
**Source:** `ELEVATE_NGINX_ROUTE_20260919.md` §Rollback: "Dashboard authentication/allowlisting also remains unresolved"  
**What would unblock it:** An accepted artifact proving an approved auth model (Basic Auth, OAuth, allowlist, or other) for `agents.elevatesci.com`; decision by Brandon/Eric/Dubz  
**Owner:** Brandon / Eric / Dubz

### Blocker E-2: Ops provider adapter — live/provider authorization

**Status:** `BLOCKED` (`AUTHORIZATION`)  
**What it blocks:** Real provider key reads, live provider API calls, live VPS control-plane mutation  
**Source:** `PRD_TRACEABILITY.md` row `elevate-ops-provider-adapter`; `SOFTWARE_LANES.md` Lane 1  
**What would unblock it:** Explicit operator authorization for live/provider work separate from local mock-test authority  
**Owner:** Operator

### Blocker E-3: Elevate operations console — unauthenticated API exposure (SECURITY)

**Status:** `BLOCKED` (security remediation candidate — highest risk open item)  
**What it blocks:** Production-parity acceptance; compliance with PRD v3 §4 non-goals (no unauthenticated internal APIs)  
**Source:** `PRD_DELIVERY_MAP.md` lines 48–53; `BRANDON REWORK/evidence/BR-SAAS-PARITY-20260918/console-parity-report.md` (file not present in workspace)  
**What would unblock it:** Auth wall added to Elevate operations console; status/job APIs require authentication; accepted artifact confirming the fix  
**Owner:** Operator (security remediation)  
**Note:** This is recorded as a security remediation candidate, NOT an accepted production-parity state. Do not treat this as resolved without an accepted artifact.

### Blocker E-4: Ticket 0033 traceability artifact

**Status:** `REPORTED_CLOSED` — traceability row still needs own accepted artifact  
**What it blocks:** Complete traceability closure for the aminolifesciences→elevatesci-vps/ElevateSci sweep (314 occurrences, 42 files)  
**Source:** `PRD_DELIVERY_MAP.md` Elevate row: "reported CLOSED by HD2Stack"  
**What would unblock it:** An accepted artifact (e.g., the task's completion report) that serves as the traceability row's own evidence  
**Owner:** HD2 agent that closed ticket 0033

---

## 6. Shared Platform Blockers

These cross-cutting unknowns gate the Elevate domain regardless of its own progress. Source for all: `PRD_DELIVERY_MAP.md` lines 36–64.

| # | Blocker | Status | Source | What would unblock it |
|---|---|---|---|---|
| 1 | **Project coverage gaps** — Whoosh `BR-AUD-004` BLOCKED_BY_DEPENDENCY/COORDINATES_MISSING; Elevate cannot be Phase 2 in PRD rollout order until Whoosh is unblocked or skipped | BLOCKED | `PRD_DELIVERY_MAP.md` unresolved area 1 | Whoosh coordinates (repo, host, runtime, IP) supplied by operator |
| 2 | **Canonical application architecture unresolved** — Current evidence is PHP/MySQL and mixed deployment; v3 targets Hostinger PostgreSQL/PgBouncer + Hetzner queues/workers; no accepted ADR maps existing Elevate software to that target | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 2 | ADR per project (retain PHP/MySQL or adopt PostgreSQL); approved by Eric/Dubz |
| 3 | **Cross-project runtime isolation** — No accepted evidence proves four production queue namespaces, worker denial tests, project-scoped ingest, file namespaces, database roles, or Qdrant collection isolation for Elevate | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 3 | Isolated queue/worker/namespace acceptance tests for all four projects |
| 4 | **Hub application delivery** — LiteLLM placeholder keys; AnythingLLM backend/vector-store relationship and Brandon-vs-HD2 data boundary unknown; app deployment pending | BLOCKED | `PRD_DELIVERY_MAP.md` unresolved area 4 | Approved secret store, backup/restore, embedding route, DNS/TLS, per-project isolation |
| 5 | **Release controls (CI/CD)** — Accepted local hardening/self-tests are not the PRD's per-project CI, container-build, dependency/vulnerability, staging, smoke, health, and rollback gates | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 5 | Complete per-project CI/CD pipeline with demonstrated rollback |
| 6 | **Backup/DR** — Designs and synthetic harness exist; no live encrypted off-host provider assignment, per-project target proof, real restore, RPO/RTO, or DR drill for Elevate | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 6; blocked on `OPERATOR_INPUT` for provider/account, retention, RPO/RTO, key custody | Operator supplies Namecheap DR target; live encrypted backup; restore test; measured RPO/RTO |
| 7 | **Observability** — Inventory/design references metrics/logs/alerts; no complete four-project SLO/alert/restore-age implementation is evidenced for Elevate | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 7 | Metrics, log aggregation, SLO, and alert implementation for Elevate |
| 8 | **Canonical source provenance** — Historical Git blob for the PRD itself is absent; exact-byte provenance not available | BLOCKED | `PRD_DELIVERY_MAP.md` unresolved area 8; `DEPENDENCY` on absent Git blob | Recover historical Git blob only if exact-byte provenance required for final signoff |
| 9 | **Reusable HD2 client baseline incomplete** — Accepted Hetzner/HD2stack recheck is placement/broker evidence, not a complete host-baseline application for Elevate | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 9 | Host-profile overlay with provider, exact addresses, OS/role, named admin/key pointer, approved ingress, rollback window |

---

## 7. Acceptance Criteria

Checkboxes traceable to v3 PRD sections. Criteria without a source are marked `UNKNOWN` rather than invented.

### 1. Public Site and TLS

- [ ] `elevatesci.com` serves over HTTPS with a valid TLS certificate — **DELIVERED** (v3 PRD §20.2; `PRD_DELIVERY_MAP.md` Elevate row)
- [ ] Public site is reachable and renders correctly — **DELIVERED** (v3 PRD §20.2; `PRD_DELIVERY_MAP.md` Elevate row)
- [ ] No internal services are publicly exposed on `elevatesci.com` — **UNKNOWN** (requires security scan; v3 PRD §16.1)
- [ ] TLS certificate auto-renewal is configured — **UNKNOWN**

### 2. Dashboard and Auth

- [ ] `agents.elevatesci.com` serves the dashboard with a 200 response — **DELIVERED** (v3 PRD §20.2; `PRD_DELIVERY_MAP.md` Elevate row)
- [ ] Dashboard authentication model is approved and implemented — **UNKNOWN** (source: `ELEVATE_NGINX_ROUTE_20260919.md`: "Dashboard authentication/allowlisting also remains unresolved")
- [ ] Unauthorized access to dashboard is denied — **UNKNOWN**
- [ ] Unauthorized access to `/api/*` is denied — **EVIDENCED** (503 locally; source: `ELEVATE_NGINX_ROUTE_20260919.md`)

### 3. Operations Console Security (HIGHEST RISK)

- [ ] Elevate operations console is NOT reachable without an auth wall — **BLOCKED** (source: `PRD_DELIVERY_MAP.md` lines 48–53; `BR-SAAS-PARITY-20260918/console-parity-report.md` cited but file not present)
- [ ] Status/job APIs on the operations console require authentication — **BLOCKED** (same source as above)
- [ ] Security remediation is accepted and verified — **UNKNOWN** (requires accepted artifact)
- **Note:** This criterion is a security remediation candidate, NOT an accepted production-parity state. It must not be marked complete without an accepted artifact confirming the fix.

### 4. Application Architecture

- [ ] Elevate application source is audited and documented — **UNKNOWN** (v3 PRD Gate C)
- [ ] Elevate project uses the approved database engine and credentials — **UNKNOWN** (v3 PRD §8.1; `PRD_DELIVERY_MAP.md` unresolved area 2)
- [ ] Database roles and credentials are isolated from other projects — **UNKNOWN** (v3 PRD §8.1; `PRD_DELIVERY_MAP.md` unresolved area 3)

### 5. Queue and Worker

- [ ] Elevate has a dedicated queue namespace on Hetzner RabbitMQ — **UNKNOWN** (v3 PRD §9; `PRD_DELIVERY_MAP.md` unresolved area 3)
- [ ] Elevate workers run on Hetzner compute plane — **UNKNOWN** (v3 PRD §7.2)
- [ ] Elevate queue/worker isolation from other projects is tested and verified — **UNKNOWN** (v3 PRD §9; cross-project denial tests)
- [ ] Worker denial tests prove Elevate workers cannot access other project queues — **UNKNOWN** (v3 PRD §9; `PRD_DELIVERY_MAP.md` unresolved area 3)

### 6. File Namespaces

- [ ] Elevate file namespaces are isolated from other projects — **UNKNOWN** (v3 PRD §10; `PRD_DELIVERY_MAP.md` unresolved area 3)
- [ ] File access is scoped to Elevate project only — **UNKNOWN**

### 7. Backup and DR

- [ ] One Namecheap DR target is assigned to Elevate — **UNKNOWN** (v3 PRD §11.3; `PRD_DELIVERY_MAP.md` unresolved area 6)
- [ ] Backups are encrypted before transfer — **UNKNOWN**
- [ ] Retention is automated — **UNKNOWN**
- [ ] Backup age is monitored — **UNKNOWN**
- [ ] A real restore has been tested for Elevate — **UNKNOWN**
- [ ] Actual RPO and RTO are recorded — **UNKNOWN** (blocked on `OPERATOR_INPUT` per `PRD_DELIVERY_MAP.md` unresolved area 6)
- [ ] At least one DR drill has been completed — **UNKNOWN**

### 8. CI/CD and Release Controls

- [ ] Elevate has a CI pipeline — **UNKNOWN** (v3 PRD §14; `PRD_DELIVERY_MAP.md` unresolved area 5)
- [ ] Dependency and vulnerability scans pass — **UNKNOWN**
- [ ] Staging deployment is automated — **UNKNOWN**
- [ ] Health gate works — **UNKNOWN**
- [ ] Production approval is manual — **UNKNOWN**
- [ ] Rollback has been demonstrated — **UNKNOWN**
- [ ] Every change traces to a Git commit — **UNKNOWN**

### 9. Observability

- [ ] Elevate metrics are visible — **UNKNOWN** (v3 PRD §15; `PRD_DELIVERY_MAP.md` unresolved area 7)
- [ ] Elevate logs are searchable by project, service, release, request, and job — **UNKNOWN**
- [ ] Elevate alerts are tested — **UNKNOWN**
- [ ] Backup and restore age are visible — **UNKNOWN**
- [ ] Queue and worker dashboards exist — **UNKNOWN**

### 10. Discovery Gate

- [ ] Elevate discovery document is approved before enabling unverified services — **UNKNOWN** (v3 PRD §20.2)
- [ ] No PHI, clinical records, prescription data, or payment-card data is processed without separate approval — **UNKNOWN** (v3 PRD §2.2, §4)

### 11. Ops Provider Adapter

- [ ] Ops provider adapter passes all mock tests (23/23 contract, 59/59 metric states, 70/70 Phase-4 controls) — **EVIDENCED** (source: `SOFTWARE_LANES.md` Lane 1)
- [ ] Ops provider adapter is deployed and functional with real provider keys — **BLOCKED** (`AUTHORIZATION`; source: `SOFTWARE_LANES.md` Lane 1; `PRD_TRACEABILITY.md` row `elevate-ops-provider-adapter`)

### 12. Ticket 0033 Acceptance Artifact

- [ ] Traceability row for ticket 0033 has its own accepted completion artifact — **REPORTED_CLOSED** (needs artifact; source: `PRD_DELIVERY_MAP.md` Elevate row)

---

## 8. Rollout Sequence

Consistent with v3 PRD Phase 5 ordering (Core → Elevate → Whoosh → CBD-Data). Elevate is Phase 2.

### Phase 0 — Baseline (precondition for all projects)

- Freeze untracked changes on `srv1137994-aminolifesciences`
- Capture current Nginx, Docker, firewall, Tailscale, and DNS state
- Back up existing data
- **Exit gate:** Complete baseline package exists; rollback to current state is possible

### Phase 1 — Inventory and Discovery (Elevate-specific)

- Complete Gate C (Application Audit) for Elevate
- Gate D (Data Classification): label all Elevate persistent data
- Gate E (Ownership and Access): list all human and machine identities with access to Elevate
- Record Elevate application source, framework, runtime, required services, env vars, database engine, file-storage behavior, queue requirements, external API dependencies
- **Exit gate:** Elevate discovery document approved by Eric and Dubz

### Phase 2 — Shared Network and Security

- Validate Tailscale ACLs include `srv1137994-aminolifesciences` (`elevatesVPS`)
- Harden SSH (key-only, no root login)
- Review UFW firewall rules
- Create Elevate-specific Docker network
- **Exit gate:** Connectivity matrix passes; cross-project denial tests pass

### Phase 3 — Hostinger Shared Platform (Elevate scope)

- Deploy or validate reverse proxy for `agents.elevatesci.com`
- Create Elevate-specific PostgreSQL database and role (or retain PHP/MySQL per approved ADR)
- Deploy Elevate file namespaces
- Deploy Elevate-specific internal ingest API pattern
- Deploy Elevate monitoring collectors
- Establish local backup staging
- **Exit gate:** Shared services healthy; no public internal ports; Elevate can deploy end-to-end in staging

### Phase 4 — Hetzner Shared Compute (Elevate scope)

- Create Elevate virtual host on Hetzner RabbitMQ
- Deploy Elevate workers with network isolation
- Establish Elevate workspace quotas and cleanup
- Establish result-ingest authentication
- **Exit gate:** Test job flows Hostinger→Hetzner→Hostinger for Elevate; cross-project queue access is denied for Elevate

### Phase 5 — Elevate Project Rollout (Phase 2 in PRD order)

- Deploy Elevate frontend (`elevatesci.com`)
- Deploy Elevate API (requires auth model and approved backend)
- Deploy Elevate database and roles
- Deploy Elevate files
- Deploy Elevate queue namespace and workers (only those proven necessary)
- Configure Elevate backup target
- **Exit gate:** Elevate acceptance tests pass (§20.2); Elevate jobs/files isolated; Elevate backup restores

### Phase 6 — CI/CD and Release Controls (Elevate scope)

- Add Elevate CI workflows
- Add image and secret scanning
- Add Elevate staging deployment
- Add Elevate smoke tests
- Add production approval gate
- Add rollback action
- Document Elevate release process
- **Exit gate:** Complete release and rollback demonstrated without manual configuration drift

### Phase 7 — Backup and DR (Elevate scope)

- Assign one Namecheap target to Elevate
- Deploy encrypted backup transfer
- Deploy manifests and retention
- Run first Elevate restore test
- Write Elevate DR runbook
- Run one Elevate drill
- Record actual Elevate RPO and RTO
- **Exit gate:** Elevate has a recent verified backup; Namecheap target limitations are documented

### Phase 8 — Load and Failure Testing

- Hostinger frontend load test including Elevate
- Database connection saturation test
- Hetzner worker saturation test including Elevate queue
- Queue backlog test
- Worker crash and redelivery test
- Elevate-specific browser leak test, disk-fill warning, Tailscale interruption
- Elevate-specific rollback test
- **Exit gate:** No critical unresolved failure; capacity baseline and recommended worker defaults documented

### Phase 9 — Production Handoff (Elevate scope)

- Deliver Elevate architecture diagrams
- Deliver Elevate service catalog entry
- Deliver Elevate inventory
- Deliver Elevate access matrix
- Deliver Elevate DNS matrix
- Deliver Elevate deployment guide
- Deliver Elevate backup guide and restore evidence
- Deliver Elevate DR runbook
- Deliver Elevate monitoring links and alert response guide
- Deliver Elevate release manifest and known limitations
- Obtain final Elevate signoff
- **Exit gate:** Final signoff from Brandon and Eric

---

## 9. Risks

| # | Risk | Severity | Mitigation | Source |
|---|---|---|---|---|
| R-1 | **Elevate operations console unauthenticated** — status and job APIs are exposed without an auth wall. This is the highest-risk open item for this domain. | **Critical** | Add auth wall before any production-parity claim; do not accept as a stable state | `PRD_DELIVERY_MAP.md` lines 48–53 |
| R-2 | **Dashboard auth unresolved** — no auth model is approved for `agents.elevatesci.com` | High | Obtain operator decision on auth model before Phase 5 rollout | `ELEVATE_NGINX_ROUTE_20260919.md` |
| R-3 | **Ops provider adapter BLOCKED_AUTHORIZATION** — local mock tests are working but live/provider work is not authorized | High | Do not deploy to live provider without explicit authorization; keep local mock-test path as the safe lane | `SOFTWARE_LANES.md` Lane 1; `PRD_TRACEABILITY.md` |
| R-4 | **Amino/Elevate legacy VPS placement** — current Elevate site is on legacy VPS, not PRD-v3 target | Medium | Do not claim PRD-v3 target placement is complete; route Phase 3/4 deployment decisions through ADR | `PRD_DELIVERY_MAP.md` unresolved area 2; `amino-elevate-live-placement` traceability row |
| R-5 | **Ticket 0033 traceability gap** — sweep reported CLOSED but no accepted artifact for the traceability row | Medium | Obtain the task's completion report as the row's own evidence | `PRD_DELIVERY_MAP.md` Elevate row |
| R-6 | **Cross-project isolation not proven** — no evidence that Elevate queues/files/database are isolated from Core Distro, Whoosh, or CBD-Data | High | Phase 2 cross-project denial tests are the required unblock | `PRD_DELIVERY_MAP.md` unresolved area 3 |
| R-7 | **Backup/DR not evidenced** — no Namecheap target, encrypted transfer, restore test, RPO/RTO, or drill for Elevate | High | Operator must supply DR target; Phase 7 is mandatory before production handoff | `PRD_DELIVERY_MAP.md` unresolved area 6 |
| R-8 | **Canonical application architecture unresolved** — no ADR maps existing Elevate software to PRD-v3 Hostinger PostgreSQL/PgBouncer + Hetzner target | High | ADR required per project before Phase 3 deployment | `PRD_DELIVERY_MAP.md` unresolved area 2 |
| R-9 | **Observability not implemented** — no metrics, logs, SLO, or alerts for Elevate | Medium | Phase 9 handoff requires monitoring links and alert response guide | `PRD_DELIVERY_MAP.md` unresolved area 7 |

---

## 10. Required Evidence to Change Any Status Here

The following evidence types are the only acceptable basis for changing any status in this PRD from `UNKNOWN` or `BLOCKED` to `EVIDENCED` or `DELIVERED`. No estimate, assumption, or guess satisfies any criterion.

| Criterion type | Required evidence |
|---|---|
| Site live / TLS | Live curl/HTTPS HEAD from `elevatesci.com` confirming 200 and valid cert (already DELIVERED) |
| Dashboard live | Live curl/HTTPS HEAD from `agents.elevatesci.com` confirming 200 path |
| Dashboard auth | Accepted artifact proving auth model (e.g., allowlist config, session config, or Basic Auth header requirement) |
| Ops console security | Accepted artifact confirming auth wall added; status/job APIs no longer respond without credentials |
| API backend | Accepted artifact proving an Elevate-owned backend answering `/api/*` with correct auth |
| Queue/worker isolation | Accepted artifact from cross-project denial tests proving Elevate namespace inaccessible to other projects |
| Backup target | Accepted artifact: Namecheap DR assignment, encrypted transfer config, backup manifest |
| Restore test | Accepted artifact: actual restore run with output, verified data integrity |
| RPO/RTO | Documented measurement, not estimate |
| CI/CD | Accepted CI workflow file, passing pipeline run, rollback demonstrated |
| Observability | Accepted SLO definition, working alert, log aggregation screenshot or query output |
| Ops provider adapter (live) | Explicit operator authorization + live test with real provider key confirming expected behavior |
| Ticket 0033 artifact | Task completion report or PR from the agent that closed ticket 0033 |
| Application architecture ADR | Approved ADR document signed by Eric/Dubz |

---

## 11. ADR / Decision Items Required

The following decisions must be recorded as Architecture Decision Records and approved before the relevant phase proceeds.

| # | Decision | Options | Owner | Status |
|---|---|---|---|---|
| ADR-E-1 | **Dashboard auth model for `agents.elevatesci.com`** | Basic Auth / OAuth / IP allowlist / other | Brandon / Eric / Dubz | **Pending** — `ELEVATE_NGINX_ROUTE_20260919.md` explicitly marks this unresolved |
| ADR-E-2 | **Ops console auth model** | Basic Auth / OAuth / IP allowlist / require Tailscale / disable public access | Operator | **Pending** — `PRD_DELIVERY_MAP.md` lines 48–53 mark this as a security remediation candidate |
| ADR-E-3 | **Elevate application architecture** | Retain existing PHP/MySQL on `srv1137994-aminolifesciences` / adopt PRD-v3 Hostinger PostgreSQL + Hetzner workers | Eric / Dubz | **Pending** — `PRD_DELIVERY_MAP.md` unresolved area 2; no ADR exists |
| ADR-E-4 | **Elevate queue/worker placement** | Legacy on `srv1137994-aminolifesciences` / PRD-v3 Hetzner compute plane | Eric / Dubz | **Pending** — dependent on ADR-E-3 |
| ADR-E-5 | **Elevate backup provider and target** | Namecheap VPS per project / other provider; operator must supply account, retention, RPO/RTO, key custody | Operator | **Blocked** — `OPERATOR_INPUT` required per `PRD_DELIVERY_MAP.md` unresolved area 6 |
| ADR-E-6 | **Ticket 0033 traceability closure** | Accept the task completion report as the row's own evidence, or require additional artifact | HD2 agent that closed ticket 0033 | **Pending** |

---

## Source Index

Every factual claim in this document cites one of the following sources:

| Source file | What it contributes to this PRD |
|---|---|
| `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` | Domain scope, Phase 5 ordering, acceptance criteria (§20.2), non-goals, rollout phases, ADR requirements |
| `docs/system-context/PRD_TRACEABILITY.md` | Status values semantics; `elevate-site-live` (DELIVERED) and `elevate-ops-provider-adapter` (BLOCKED/AUTHORIZATION) rows; `amino-elevate-live-placement` (UNKNOWN) row |
| `docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md` | Executive verdict; Elevate DELIVERED status; security issue lines 48–53; nine unresolved cross-cutting areas; manifest lines 42, 45 |
| `docs/system-context/evidence/prd-delivery-plan-20260914/SOFTWARE_LANES.md` | Lane 1 ops provider adapter: local mock-test evidence (23/23, 59/59, 70/70, 37/37); BLOCKED_AUTHORIZATION for live/provider |
| `docs/system-context/SERVICE_CATALOG.md` | `elevate-site` (EVIDENCED), `elevate-dashboard` (PARTIAL), `elevate-ops-adapter` (BLOCKED/AUTHORIZATION) service records |
| `docs/system-context/HOSTS.md` | `srv1137994-aminolifesciences` host record (Tailscale IP, SSH path, role, runtime versions) |
| `docs/system-context/ELEVATE_NGINX_ROUTE_20260919.md` | Direct live evidence: vhost change, 503 for `/api/*`, Nginx reload, rollback copy, dashboard auth unresolved statement |

> **Evidence file gap:** `BRANDON REWORK/evidence/BR-ELEVATE-SEO-PERF-001/elevate-client-closeout-m3.md`, `BR-ELEVATE-IDENTITY-001`, `BR-ELEVATE-SEO-PERF-001`, `BR-ELEVATE-OPS-001`, and `BRANDON REWORK/evidence/BR-SAAS-PARITY-20260918/console-parity-report.md` are cited in `PRD_DELIVERY_MAP.md` and `PRD_TRACEABILITY.md` but are not present in the current workspace checkout. Their cited content is reproduced as the traceability documents state it; none of those files were independently read by this writer.
