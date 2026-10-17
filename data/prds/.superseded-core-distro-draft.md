# Core Distro Domain Infrastructure PRD v1.0

**Client:** Brandon
**Domain:** `core-distro.com`
**Prepared for:** the Captain
**PRD baseline:** `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (v3.0, 2026-08-04), canonical copy at `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`
**Status:** UNKNOWN — architecture conflict requires Captain-ordered ADR before PRD-v3 scope is defined; production runs on Namecheap/PHP, not Hostinger/Hetzner as PRD v3 targets
**Last updated:** 2026-10-17

---

## 0. Status Header

| Field | Value | Source |
|---|---|---|
| Domain | `core-distro.com` | `PRD_TRACEABILITY.md` |
| Traceability items | `coredistro-source-runtime` (EVIDENCED), `coredistro-route-qa` (EVIDENCED), `coredistro-canary` (BLOCKED/OPERATOR_INPUT) | `PRD_TRACEABILITY.md` |
| Primary PRD | BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md §§2.1, 6.1, 7.1–7.2, 20.1 | `PRD_TRACEABILITY.md` |
| Production host | Namecheap `66.29.153.174` (PHP 8.2.34) + Contabo `161.97.120.4` (agents, nginx 401 Basic Auth); verified 2026-10-12 via `bin/fm-coord-drift-check.sh` | `PRD_DELIVERY_MAP.md` Core Distro row; `bin/fm-coord-drift-check.sh` |
| PRD-v3 target host | Hostinger KVM8 public/control plane + Hetzner dedicated compute plane | `PRD v3 §§7.1–7.2` |
| Architecture conflict | **PRODUCTION DIVERGES FROM PRD-v3 TARGET.** Resolution is pending Captain-ordered ADR. | `PRD v3 §2.1` production reality gap; `PRD_DELIVERY_MAP.md` Core Distro row |
| Verdict | Not ready for PRD-v3 rollout. Existing working software and accepted audit evidence exist; PRD-v3 acceptance criteria are BLOCKED/UNKNOWN. | `PRD_DELIVERY_MAP.md` executive verdict |

---

## 1. Current State

Status table using only `DELIVERED` / `EVIDENCED` / `IN_PROGRESS` / `BLOCKED` / `UNKNOWN`.

| Traceability item | Status | Evidence | Source |
|---|---|---|---|
| `coredistro-source-runtime` — PHP source and runtime | `EVIDENCED` | Real PHP SaaS source at `projects/core-distro.com/current-core-distro/`; BR-AUD-002 maps PHP production, Next.js staging, MySQL/Percona, auth/lead-list data, queue-like city jobs; production coordinates verified 2026-10-12: `core-distro.com` and `data.core-distro.com` on Namecheap `66.29.153.174` (PHP 8.2.34); `agents.core-distro.com` on Contabo `161.97.120.4` (nginx 401 Basic Auth); Controller `/etc/hosts` localhost trap noted; automated drift enforcement via `bin/fm-coord-drift-check.sh` | `PRD_DELIVERY_MAP.md` Core Distro row; `PRD_TRACEABILITY.md`; `bin/fm-coord-drift-check.sh` |
| `coredistro-route-qa` — route QA | `EVIDENCED` | BR-CORE-001 read-only route QA records PASS/FAIL/NOT_RUNTIME_VERIFIABLE per path; deployment/hydration/auth gates still open | `PRD_DELIVERY_MAP.md` Core Distro row; `PRD_TRACEABILITY.md` |
| `coredistro-canary` — 1-job canary execution | `BLOCKED` | Blocker: `OPERATOR_INPUT`; `leadlists.php` SHA-256 `6f91999dafae7f85951f31455e339c375030fb71eb6c1ad9f474bdf71bce83d3`; backlog of 36,823 jobs paused | `PRD_TRACEABILITY.md`; `MINI_SPRINT_PREPARATION_REPORT.md` §3 |
| Canonical application architecture | `BLOCKED` | No accepted ADR maps existing PHP/MySQL production to PRD-v3 Hostinger PostgreSQL/PgBouncer + Hetzner compute target | `PRD_DELIVERY_MAP.md` unresolved area 2 |
| Local staging parity | `EVIDENCED` | Canonical `staged-export-test/` slice updated with apple-touch parity declaration in 10 PHP source files; deterministic parity test PASS | `PRD_DELIVERY_MAP.md` Lane A continuation 2026-09-18 |
| PRD-v3 Hostinger public/control plane deployment | `UNKNOWN` | No evidence that Core Distro PHP or Next.js is deployed to Hostinger KVM8 `srv1856614` | `PRD v3 §7.1`; `PRD_DELIVERY_MAP.md` |
| PRD-v3 Hetzner compute deployment | `UNKNOWN` | No evidence that Core Distro background jobs, enrichment, or workers run on Hetzner `brandon-compute` | `PRD v3 §7.2`; `PRD_DELIVERY_MAP.md` |
| Project-scoped queue namespace | `UNKNOWN` | No evidence of a Core Distro RabbitMQ virtual host on Hetzner | `PRD v3 §7.2`; `PRD_DELIVERY_MAP.md` unresolved area 3 |
| Project-scoped database role isolation | `UNKNOWN` | No evidence of Core Distro-specific PostgreSQL database, roles, or PgBouncer pool on Hostinger | `PRD v3 §8.1`; `PRD_DELIVERY_MAP.md` unresolved area 3 |
| Project-scoped file namespace | `UNKNOWN` | No evidence of Core Distro `/srv/brandon-files/core/` on Hostinger | `PRD v3 §9`; `PRD_DELIVERY_MAP.md` unresolved area 3 |
| CI/CD and release controls | `UNKNOWN` | Accepted local hardening/self-tests are not the PRD's project CI/CD gates | `PRD_DELIVERY_MAP.md` unresolved area 5; `PRD_TRACEABILITY.md` |
| Backup/DR | `UNKNOWN` | No live encrypted off-host backup, per-project target proof, or restore test for Core Distro | `PRD_DELIVERY_MAP.md` unresolved area 6; `PRD_TRACEABILITY.md` |
| Observability | `UNKNOWN` | No complete Core Distro SLO/alert/dashboard implementation is evidenced | `PRD_DELIVERY_MAP.md` unresolved area 7; `PRD_TRACEABILITY.md` |
| ChatWidget/AnythingLLM streaming on staging Next.js | `UNKNOWN` | No source evidence found for the reported `stream-chat` returning "Invalid session ID" on the staging Next.js front. Measurement date not sourced. PRD disposition is UNKNOWN pending an owner assignment. See §6 Observation. | No source in cited evidence; see §6 |

---

## 2. What Is Actually Proven vs What Is Not

### 2.1 What Is Actually Proven

The following are grounded in cited evidence and are facts, not claims:

1. **Real PHP SaaS source exists.** Source at `projects/core-distro.com/current-core-distro/`. BR-AUD-002 maps PHP production (Contabo cPanel), Next.js staging (AminoVPS, `srv1137994-aminolifesciences`, Tailscale `100.69.211.43`), MySQL/Percona 8.4, auth/lead-list data, and queue-like city jobs. Source: `PRD_DELIVERY_MAP.md` Core Distro row; `BR-AUD-002/report.md`.

2. **Live production coordinates are verified (2026-10-12).** `core-distro.com` and `data.core-distro.com` at Namecheap `66.29.153.174` (PHP 8.2.34, LiteSpeed, AS22612). `agents.core-distro.com` at Contabo `161.97.120.4` (nginx 1.24.0, 401 Basic Auth). Drift enforcement via `bin/fm-coord-drift-check.sh`. Source: `PRD_DELIVERY_MAP.md` Core Distro row; `bin/fm-coord-drift-check.sh`.

3. **Controller localhost trap exists.** `/etc/hosts` contains `127.0.0.1 agents.core-distro.com`; checks without external DNS bypass hit local Controller services. Source: `PRD v3 §2.1`; `PRD_DELIVERY_MAP.md`.

4. **Read-only route QA is EVIDENCED.** BR-CORE-001 records PASS/FAIL/NOT_RUNTIME_VERIFIABLE per path. Deployment, hydration, and auth gates remain open. Source: `PRD_DELIVERY_MAP.md` Core Distro row; `PRD_TRACEABILITY.md`.

5. **Canary script is prepared.** `leadlists.php` SHA-256 `6f91999dafae7f85951f31455e339c375030fb71eb6c1ad9f474bdf71bce83d3`. 36,823-job backlog paused. Canary awaits explicit operator signal. Source: `MINI_SPRINT_PREPARATION_REPORT.md` §3; `PRD_TRACEABILITY.md`.

6. **Local staging parity update is EVIDENCED.** Apple-touch icon parity added to 10 PHP source files; deterministic test 11/11 PHP lint, boundary scan, diff scope, rollback, and `CHECK_PASS` independent. Source: `PRD_DELIVERY_MAP.md` Lane A continuation 2026-09-18.

7. **Architecture conflict is documented.** Production runs on Namecheap/PHP 8.2 and Contabo. PRD v3 targets Hostinger KVM8 public/control plane and Hetzner dedicated compute plane. The conflict is unresolved; the Captain ordered an ADR. Source: `PRD v3 §§2.1, 7.1–7.2`; `PRD_DELIVERY_MAP.md` Core Distro row.

### 2.2 What Is Not Proven

The following are absent from cited evidence. Each is listed so that acceptance is not silently assumed:

1. **PRD-v3 deployment.** No evidence that Core Distro PHP or Next.js runs on Hostinger KVM8 `srv1856614` or Hetzner `brandon-compute`.
2. **Queue namespace.** No evidence of a Core Distro RabbitMQ `/core` virtual host.
3. **Database isolation.** No evidence of PostgreSQL/PgBouncer database, roles, or pools scoped to Core Distro on Hostinger.
4. **File namespace.** No evidence of `/srv/brandon-files/core/` on Hostinger.
5. **Worker on Hetzner.** No evidence that Core Distro enrichment or background jobs run on Hetzner.
6. **CI/CD pipeline.** No evidence of GitHub workflows, container build, staging deploy, smoke tests, or rollback gates for Core Distro.
7. **Backup/DR.** No evidence of encrypted off-host backup, Namecheap target assignment, or restore test for Core Distro.
8. **Observability.** No evidence of Core Distro metrics, logs, alerts, or dashboards.
9. **Auth/hydration gates.** BR-CORE-001 notes deployment/hydration/auth gates are still open; no evidence these have closed.
10. **ChatWidget streaming.** No source evidence for the reported `stream-chat` "Invalid session ID" defect on the staging Next.js front. Measurement date not sourced.
11. **PRD-v3 target scope.** No evidence that the PRD-v3 scope for Core Distro (Hostinger/Hetzner migration) has been defined beyond the production reality gap note.

---

## 3. Scope

This domain PRD covers the infrastructure for `core-distro.com` and all subdomains (`data.core-distro.com`, `agents.core-distro.com`) under the Brandon multi-project infrastructure PRD v3 framework.

**Included in this domain:**

- PHP production application (`core-distro.com`, `data.core-distro.com`) — current Namecheap deployment
- Next.js staging application — current AminoVPS deployment (`srv1137994-aminolifesciences`)
- Authenticated lead-list and job queue functionality (`leadlists.php`)
- Database (MySQL/Percona 8.4) — current production state
- Namecheap backup/DR target assignment — one target per project per PRD v3
- PRD-v3 target deployment to Hostinger/Hetzner (pending architecture decision)
- CI/CD pipeline scoped to Core Distro
- Observability scoped to Core Distro
- Project isolation from Elevate, Whoosh, CBD-Data

**Canonical source repository:** `DeightonLLM/core-distro-saas-clean` (main branch, HEAD `ba233e1`).

**Shared codebase note:** Core Distro and CBD-Data PHP SaaS share `core-distro-saas-clean` with per-tenant branding constants. See `BR-AUD-002/report.md` §1a. Any architecture change must account for shared source.

---

## 4. Non-Goals

The following are explicitly out of scope for this domain PRD:

- Kubernetes or multi-node clusters
- Any deployment to or migration of Whoosh Performance, Elevate Life Sci, or the Brandon Hub
- Processing of PHI, prescription data, or regulated patient data (Core Distro is not a PHI/PHI platform per current evidence; see `BR-AUD-002/report.md`)
- Redesign of the public website or product catalog
- Database engine migration (MySQL → PostgreSQL) without an accepted ADR
- Any work that requires live credentials not currently evidenced
- Any changes to other tenants on shared AminoVPS host
- AnythingLLM, LiteLLM, Qdrant, or vector search functionality for Core Distro (no evidence these are required)
- Production migration without an approved architecture decision and human sign-off

---

## 5. Open Blockers

Each blocker is named with what would unblock it and the owning party.

### Blocker 1: Architecture Conflict — Production Runs on Namecheap/PHP, PRD v3 Targets Hostinger/Hetzner

| Field | Value |
|---|---|
| Status | `BLOCKED` |
| Owner | **Captain** (has ordered ADR) |
| Description | Production hosting (Namecheap `66.29.153.174` / PHP 8.2 / LiteSpeed / Contabo `161.97.120.4` / nginx 401) demonstrably diverges from the PRD v3 target (Hostinger KVM8 public/control plane + Hetzner dedicated compute plane). This is the single most important unresolved item for this domain. No ADR maps the current PHP/MySQL stack to the target PostgreSQL/PgBouncer + Hetzner architecture. | `PRD v3 §§2.1, 7.1–7.2`; `PRD_DELIVERY_MAP.md` Core Distro row; `PRD_DELIVERY_MAP.md` unresolved area 2 |
| What unblocks | Captain-ordered ADR deciding: (a) retain Namecheap/PHP for Core Distro production, (b) migrate Core Distro to Hostinger/Hetzner per PRD v3, or (c) define a hybrid model. Decision must be recorded as an ADR. |
| PRD disposition | PRD-v3 rollout cannot proceed until this is resolved. Existing working software remains operational. |

### Blocker 2: Canary Awaiting Operator Signal

| Field | Value |
|---|---|
| Status | `BLOCKED` |
| Owner | **Captain / Operator** |
| Description | The synthetic 1-job canary (`leadlists.php` SHA-256 `6f91999dafae7f85951f31455e339c375030fb71eb6c1ad9f474bdf71bce83d3`) is prepared and paused against a 36,823-job backlog. Canary execution requires an explicit operator signal. Source: `MINI_SPRINT_PREPARATION_REPORT.md` §3; `PRD_TRACEABILITY.md` |
| What unblocks | Operator sends explicit signal to run the 1-job canary without unpausing the 36,823-job backlog. |
| PRD disposition | Acceptance of the production job queue requires canary evidence. |

### Blocker 3: Deployment/Hydration/Auth Gates Still Open

| Field | Value |
|---|---|
| Status | `BLOCKED` |
| Owner | **Captain** (auth); **Implementation team** (hydration) |
| Description | BR-CORE-001 read-only route QA records deployment/hydration/auth gates as still open. Source: `PRD_DELIVERY_MAP.md` Core Distro row |
| What unblocks | Auth: Captain defines admin authentication requirements and approves deployment model. Hydration: implementation team demonstrates reproducible build and start path. |
| PRD disposition | PRD-v3 deployment acceptance requires these gates to close. |

### Blocker 4: PRD-v3 Target Scope Undefined

| Field | Value |
|---|---|
| Status | `BLOCKED` |
| Owner | **Captain / CrispR** |
| Description | The PRD v3 does not define the exact Core Distro target scope beyond the production reality gap note. No evidence defines which Core Distro components go to Hostinger vs Hetzner, what database engine to use, or what queue model applies. Source: `PRD v3 §2.1` production reality gap |
| What unblocks | A scoping session that defines Core Distro-specific: (a) Hostinger services, (b) Hetzner services, (c) database engine decision, (d) job queue model, (e) CI/CD requirements, (f) backup scope, (g) observability requirements. |
| PRD disposition | This domain PRD cannot be completed until the scope is defined. |

---

## 6. Shared Platform Blockers

These cross-cutting UNKNOWN/BLOCKED items from `PRD_DELIVERY_MAP.md` §§36–64 gate this domain regardless of its own work. They apply to all four Brandon projects.

| # | Shared blocker | Status | Source | Impact on Core Distro |
|---|---|---|---|---|
| 1 | Project coverage gaps — Whoosh coordinates missing | `BLOCKED` | `PRD_DELIVERY_MAP.md` unresolved area 1 | Indirect: Core Distro isolation testing requires all four projects' coordinates to be known for cross-project denial tests (PRD v3 Phase 2 exit gate) |
| 2 | Canonical application architecture unresolved | `BLOCKED` | `PRD_DELIVERY_MAP.md` unresolved area 2 | **Direct and primary blocker.** Current evidence is PHP/MySQL and mixed deployment; PRD v3 targets Hostinger PostgreSQL/PgBouncer + Hetzner queues/workers. No accepted ADR maps existing software to that target. |
| 3 | Cross-project runtime isolation | `UNKNOWN` | `PRD_DELIVERY_MAP.md` unresolved area 3 | Core Distro requires: four queue namespaces, worker denial tests, project-scoped ingest, file namespaces, database roles, Qdrant collection isolation. No accepted evidence proves these. |
| 4 | Hub application delivery | `BLOCKED` | `PRD_DELIVERY_MAP.md` unresolved area 4 | Indirect: Hub app (LiteLLM placeholder keys, AnythingLLM backend unknown) may affect Core Distro if AI enrichment or brand-adjacent features depend on it |
| 5 | Release controls (CI/CD) | `UNKNOWN` | `PRD_DELIVERY_MAP.md` unresolved area 5; `PRD_TRACEABILITY.md` | No Core Distro-specific CI/CD evidence. PRD v3 Phase 6 gates require: project CI workflows, container build, staging deploy, smoke tests, health gate, rollback |
| 6 | Backup/DR | `UNKNOWN` (blocked on OPERATOR_INPUT) | `PRD_DELIVERY_MAP.md` unresolved area 6; `PRD_TRACEABILITY.md` | No Core Distro backup evidence. Requires: operator to select provider/account, retention, RPO/RTO, key custody; then live encrypted backup + restore test |
| 7 | Observability | `UNKNOWN` | `PRD_DELIVERY_MAP.md` unresolved area 7; `PRD_TRACEABILITY.md` | No Core Distro observability evidence. Requires: metrics, logs, alerts, SLOs per PRD v3 §14 |
| 8 | Canonical source provenance | `BLOCKED` | `PRD_DELIVERY_MAP.md` unresolved area 8 | Historical Git blob `b98c887b8abdf0041d52faf2405ec5a76ec8fcf2` absent. Only matters if exact-byte signoff is required |
| 9 | Reusable HD2 client baseline | `INCOMPLETE` | `PRD_DELIVERY_MAP.md` unresolved area 9 | A future hardening pass must carry a host-profile overlay; no mutation implied |

### Observation: ChatWidget/AnythingLLM Streaming Chat Defect

| Field | Value |
|---|---|
| Reported defect | ChatWidget/AnythingLLM streaming chat returns "Invalid session ID" on the staging Next.js front |
| Source | None found in cited evidence (PRD v3, PRD_TRACEABILITY, PRD_DELIVERY_MAP, SERVICE_CATALOG, HOSTS, BR-AUD-002, MINI_SPRINT_PREPARATION_REPORT, BRANDON REWORK evidence, BOARD.md) |
| Related finding | BOARD.md line 16 records: "the shipped widget carries baseApiUrl=https://llm.hd2.ai and that stream-chat route returns 404" — but this references HD2's AnythingLLM at `llm.hd2.ai`, not Core Distro staging specifically, and reports a 404, not "Invalid session ID" |
| Measurement date | Not sourced |
| PRD disposition | `UNKNOWN` — defect is unconfirmed in cited sources. An owner must be assigned and the defect must be reproduced with evidence before it can be accepted as a PRD item. Do not treat as an accepted defect. |

---

## 7. Acceptance Criteria

Checkboxes, each traceable to a PRD v3 section. Any criterion not evidenced from sources is marked `UNKNOWN — source needed`.

### 7.1 Inventory and Ownership

- [ ] Actual Core Distro production host specifications documented (Provider, IP, OS, runtime, services, firewall) — **UNKNOWN.** Source: Gate A (`PRD v3 §5`); `PRD_DELIVERY_MAP.md` unresolved area 2
- [ ] Actual Core Distro staging host specifications documented — **EVIDENCED** for AminoVPS `srv1137994-aminolifesciences` per BR-INV-001. Source: `BR-INV-001/report.md` §Host 1
- [ ] DNS inventory complete for all Core Distro subdomains — **UNKNOWN.** Source: Gate A (`PRD v3 §5`)
- [ ] Human and service access matrix approved — **UNKNOWN.** Source: Gate E (`PRD v3 §5`)

### 7.2 Architecture Decision

- [ ] ADR decides production deployment model (Namecheap/PHP retention vs Hostinger/Hetzner migration) — **BLOCKED.** Owner: Captain. Source: `PRD v3 §2.1` production reality gap; `PRD_DELIVERY_MAP.md` unresolved area 2
- [ ] ADR decides database engine (MySQL/Percona retention vs PostgreSQL/PgBouncer adoption) — **BLOCKED.** Owner: Captain. Source: `PRD v3 §8.1`; `PRD_DELIVERY_MAP.md` unresolved area 2
- [ ] ADR decides background job model (current queue-like PHP jobs vs Hetzner RabbitMQ) — **BLOCKED.** Owner: Captain. Source: `PRD v3 §7.2`; `PRD_DELIVERY_MAP.md` unresolved area 2

### 7.3 Hostinger Deployment (PRD v3 §7.1)

- [ ] Core Distro routes correctly on Hostinger KVM8 — **UNKNOWN.** Source: `PRD v3 §7.1`
- [ ] Internal services are not public — **UNKNOWN.** Source: `PRD v3 §10.3`
- [ ] Project databases and credentials are isolated — **UNKNOWN.** Source: `PRD v3 §8.1`; `PRD_DELIVERY_MAP.md` unresolved area 3
- [ ] File namespaces are isolated — **UNKNOWN.** Source: `PRD v3 §9`; `PRD_DELIVERY_MAP.md` unresolved area 3
- [ ] Resource limits and health checks exist — **UNKNOWN.** Source: `PRD v3 §13`
- [ ] Public endpoints pass TLS and security-header checks — **UNKNOWN.** Source: `PRD v3 §11.4`
- [ ] Public services remain responsive during Hetzner load test — **UNKNOWN.** Source: `PRD v3 §13.1`

### 7.4 Hetzner Deployment (PRD v3 §7.2)

- [ ] Coolify is private and backed up on Hetzner — **UNKNOWN for Core Distro specifically.** Source: `PRD v3 §7.2`
- [ ] Core Distro RabbitMQ `/core` virtual host is isolated — **UNKNOWN.** Source: `PRD v3 §7.2` RabbitMQ isolation; `PRD_DELIVERY_MAP.md` unresolved area 3
- [ ] Worker services have limits and idempotency — **UNKNOWN.** Source: `PRD v3 §8.5`
- [ ] Cross-project queue access is denied — **UNKNOWN.** Source: `PRD v3 Phase 4 exit gate`

### 7.5 CI/CD and Release Controls (PRD v3 §12)

- [ ] Pull requests and required reviews enabled — **UNKNOWN.** Source: `PRD v3 §12.2`
- [ ] CI gates pass (lint, unit tests, build, scan) — **UNKNOWN.** Source: `PRD v3 §12.3`
- [ ] Staging deploy works — **UNKNOWN.** Source: `PRD v3 §12.4`
- [ ] Health gate works — **UNKNOWN.** Source: `PRD v3 §12.5`
- [ ] Production approval is manual — **UNKNOWN.** Source: `PRD v3 §12.5`
- [ ] Rollback demonstrated — **UNKNOWN.** Source: `PRD v3 §12.6`
- [ ] Database migration restore point demonstrated — **UNKNOWN.** Source: `PRD v3 §12.6`

### 7.6 Backup and DR (PRD v3 §15)

- [ ] One Namecheap target assigned to Core Distro — **UNKNOWN.** Source: `PRD v3 §7.3`
- [ ] Backups encrypted before transfer — **UNKNOWN.** Source: `PRD v3 §15.5`
- [ ] Retention automated — **UNKNOWN.** Source: `PRD v3 §15.4`
- [ ] Backup age monitored — **UNKNOWN.** Source: `PRD v3 §14.4`
- [ ] Monthly restore test completed — **UNKNOWN.** Source: `PRD v3 §15.6`
- [ ] Actual RPO and RTO recorded — **UNKNOWN.** Source: `PRD v3 §16.1`
- [ ] DR runbook written — **UNKNOWN.** Source: `PRD v3 §16.2`

### 7.7 Observability (PRD v3 §14)

- [ ] Core Distro metrics visible — **UNKNOWN.** Source: `PRD v3 §14.1`
- [ ] Core Distro logs searchable by project, service, release, request, job — **UNKNOWN.** Source: `PRD v3 §14.2`
- [ ] Core Distro alerts tested — **UNKNOWN.** Source: `PRD v3 §14.4`
- [ ] Queue and worker dashboards visible — **UNKNOWN.** Source: `PRD v3 §14.1`

### 7.8 Security (PRD v3 §11)

- [ ] Public SSH disabled after Tailscale validation — **UNKNOWN for Core Distro specifically.** Source: `PRD v3 §11.1`
- [ ] Secrets absent from repositories and logs — **UNKNOWN.** Source: `PRD v3 §11.2`
- [ ] Cross-project access tests fail as intended — **UNKNOWN.** Source: `PRD v3 §11.5`; `PRD_DELIVERY_MAP.md` unresolved area 3
- [ ] MFA required for admin/staff accounts — **UNKNOWN.** Source: `PRD v3 §11.4`

### 7.9 Project-Specific Tests (PRD v3 §20.1)

- [ ] Public site loads over HTTPS — **EVIDENCED** (Namecheap `66.29.153.174`, HTTPS HEAD 200). Source: `PRD_DELIVERY_MAP.md` Core Distro row
- [ ] Quote/contact submission is durable — **UNKNOWN.** Source: `PRD v3 §20.1`
- [ ] Uploaded or downloadable documents respect authorization — **UNKNOWN.** Source: `PRD v3 §20.1`
- [ ] Any lead-enrichment job uses the Core queue and Core credentials only — **UNKNOWN.** Source: `PRD v3 §20.1`; `PRD_DELIVERY_MAP.md` unresolved area 3
- [ ] Core data does not appear in another project's database, logs, files, or backup — **UNKNOWN.** Source: `PRD v3 §20.1`; `PRD_DELIVERY_MAP.md` unresolved area 3
- [ ] Core backup restores successfully — **UNKNOWN.** Source: `PRD v3 §20.1`; `PRD_DELIVERY_MAP.md` unresolved area 6

### 7.10 Final Approval (PRD v3 §21)

- [ ] QA agent evidence pack complete — **UNKNOWN.** Source: `PRD v3 §21`
- [ ] Saad confirms implementation reality — **UNKNOWN.** Source: `PRD v3 §21`
- [ ] CrispR approves technical acceptance — **UNKNOWN.** Source: `PRD v3 §21`
- [ ] Eric approves client and production acceptance — **UNKNOWN.** Source: `PRD v3 §21`
- [ ] Brandon receives approved handoff summary — **UNKNOWN.** Source: `PRD v3 §21`

---

## 8. Rollout Sequence

Consistent with PRD v3 Phase 5 ordering (Core Distro first, then Elevate, Whoosh, CBD-Data). Exact phase definitions depend on the architecture decision (§7.2).

### Phase 0 — Freeze and Baseline

**PRD v3 reference:** Phase 0 (§19)

- Freeze untracked infrastructure changes on Core Distro
- Export current Coolify configuration if any
- Capture current Docker state (staging host)
- Capture firewall and Tailscale state
- Capture DNS records for all Core Distro subdomains
- Back up existing data
- Create Core Distro-specific section in infrastructure repository
- Record baseline metrics

**Exit gate:** Complete baseline package exists. Rollback to current state is possible.

### Phase 1 — Inventory and Discovery

**PRD v3 reference:** Phase 1 (§19), Gates A–E (§5)

- Complete discovery gates A–E for Core Distro
- Classify Core Distro production host (Gate B: Namecheap capability classification — Category 2 shared/cPanel backup target is likely)
- Audit Core Distro application repository (`DeightonLLM/core-distro-saas-clean`)
- Build Core Distro dependency matrix
- Identify current secrets and ownership
- Identify data that already exists (auth, lead-list, job state)
- Classify data sensitivity (Gate D: Confidential — lead/business data; NOT PHI)

**Exit gate:** Eric and Dubz approve the inventory and placement plan. Architecture decision (§7.2) is resolved.

### Phase 2 — Shared Network and Security

**PRD v3 reference:** Phase 2 (§19)

- Validate Tailscale connectivity for Core Distro hosts
- Create Core Distro project Docker networks
- Harden SSH on Core Distro hosts
- Establish Core Distro-specific secrets management

**Exit gate:** Connectivity matrix passes. Cross-project denial tests pass for Core Distro scope.

### Phase 3 — Hostinger Shared Platform

**PRD v3 reference:** Phase 3 (§19)

- Deploy or validate reverse proxy
- Register Hostinger with Coolify if not already done
- Deploy PostgreSQL and PgBouncer if architecture decision adopts them; otherwise document MySQL/Percona retention rationale as ADR
- Create Core Distro database and roles
- Deploy Core Distro file namespaces
- Deploy internal ingest API pattern
- Deploy monitoring collectors for Core Distro
- Establish local backup staging

**Exit gate:** Shared services healthy. No public internal ports. Core Distro can deploy end to end.

### Phase 4 — Hetzner Shared Compute

**PRD v3 reference:** Phase 4 (§19)

- Deploy RabbitMQ shared instance (if not already done)
- Create Core Distro RabbitMQ `/core` virtual host with project-scoped credentials
- Deploy Core Distro browser image or worker base
- Create Core Distro workspace with quota and retention
- Establish result-ingest authentication

**Exit gate:** Test job flows Hostinger to Hetzner and back for Core Distro. Cross-project queue access is denied for Core Distro.

### Phase 5 — Core Distro Project Rollout

**PRD v3 reference:** Phase 5 (§19); PRD v3 §20.1

Recommended order (per PRD v3): Core Distro first.

For Core Distro specifically:

- Deploy PHP frontend
- Deploy API
- Deploy database and roles
- Deploy files
- Deploy queue namespace
- Deploy required workers only
- Configure backup target (Namecheap assignment per PRD v3 §7.3)
- Configure monitoring
- Run smoke test
- Run isolation test
- Run restore test
- Obtain signoff

**Exit gate:** All acceptance criteria in §7.9 are checked or marked UNKNOWN with named owner.

### Phase 6 — CI/CD and Release Controls

**PRD v3 reference:** Phase 6 (§19); `PRD_TRACEABILITY.md` `platform-release-controls`

- Add Core Distro CI workflows
- Add container scanning
- Add staging deployment
- Add smoke tests
- Add production approval gate
- Add rollback action
- Document release process

**Exit gate:** A complete release and rollback has been demonstrated without manual configuration drift.

### Phase 7 — Backup and DR

**PRD v3 reference:** Phase 7 (§19); `PRD_TRACEABILITY.md` `backup-dr`

- Assign one Namecheap target to Core Distro
- Deploy encrypted backup transfer
- Deploy manifests and retention
- Run first restore test
- Write `DR-CORE-DISTRO.md`
- Run one project drill
- Record actual RPO and RTO

**Exit gate:** Core Distro has a recent verified backup. The limitations of shared hosting, if any, are explicitly documented.

### Phase 8 — Load and Failure Testing

**PRD v3 reference:** Phase 8 (§19)

- Hostinger frontend load test
- Database connection saturation test
- Hetzner worker saturation test (if Hetzner deployment adopted)
- Queue backlog test
- Worker crash and redelivery test
- Duplicate job delivery test
- Browser leak test (if applicable)
- Disk-fill warning test
- Tailscale interruption test
- Hetzner outage simulation (if applicable)
- Rollback test

**Exit gate:** No critical unresolved failure. Capacity baseline and recommended worker defaults documented.

### Phase 9 — Production Handoff

**PRD v3 reference:** Phase 9 (§19)

- Architecture diagrams for Core Distro
- Service catalog update for Core Distro
- Inventory update for Core Distro
- Access matrix for Core Distro
- DNS matrix for Core Distro
- Deployment guide for Core Distro
- Backup guide for Core Distro
- Restore evidence for Core Distro
- `DR-CORE-DISTRO.md`
- Monitoring links for Core Distro
- Alert response guide for Core Distro
- Release manifest for Core Distro
- Known limitations for Core Distro
- Final signoff

---

## 9. Risks

| Risk | Severity | Likelihood | Mitigation | Source |
|---|---|---|---|---|
| Architecture conflict prevents any PRD-v3 rollout | HIGH | HIGH | Captain-ordered ADR resolves this. Existing production is unaffected by the conflict; it continues on Namecheap/PHP until a decision is made. | `PRD v3 §2.1`; `PRD_DELIVERY_MAP.md` Core Distro row |
| Controller `/etc/hosts` localhost trap causes incorrect production verification | HIGH | MEDIUM | Automated drift enforcement via `bin/fm-coord-drift-check.sh` is in place. All production checks must use external DNS (`dig @1.1.1.1`) or `curl --resolve`. | `PRD v3 §2.1` |
| PRD-v3 scope creep: PHP/MySQL retention requires an ADR, not a silent change | MEDIUM | MEDIUM | Each deviation from PRD v3 is recorded as an ADR and approved by Eric and Dubz before implementation. | `PRD v3 §1` |
| Shared codebase with CBD-Data causes cross-project contamination during isolation work | MEDIUM | LOW | Core Distro and CBD-Data share `core-distro-saas-clean`. Any isolation work must account for shared source. BR-AUD-002 documents this. | `BR-AUD-002/report.md` §1a |
| Canary execution with 36,823-job backlog causes accidental production load | HIGH | LOW | Backlog remains paused. Canary executes a single synthetic job. Operator signal is required. | `MINI_SPRINT_PREPARATION_REPORT.md` §3 |
| Namecheap backup target is Category 3 (unsuitable) | MEDIUM | MEDIUM | Gate B classification must run before placing unencrypted data on Namecheap. If Category 3, stop backup rollout and report. | `PRD v3 §5` Gate B |
| Observability and backup are blocked until operator provides input | HIGH | HIGH | Both are `UNKNOWN` with named blockers. Captain must route these to the operator. | `PRD_DELIVERY_MAP.md` unresolved areas 6, 7 |
| ChatWidget streaming defect is not in sources — unverified | LOW | UNKNOWN | Treated as UNKNOWN. Owner must be assigned and defect reproduced with evidence. | No source found; see §6 |

---

## 10. Required Evidence to Change Any Status Here

The following evidence, once accepted, would change the status of the corresponding items:

| Item | Current status | Required evidence | Owner |
|---|---|---|---|
| `coredistro-source-runtime` | `EVIDENCED` | Accepted implementation of PRD-v3 target architecture on Hostinger/Hetzner | Captain / Implementation |
| `coredistro-route-qa` | `EVIDENCED` | Accepted hydration, deployment, and auth gates from BR-CORE-001 | Captain / Implementation |
| `coredistro-canary` | `BLOCKED` | Operator signal and completed 1-job synthetic canary run with evidence | Captain / Operator |
| Canonical application architecture | `BLOCKED` | Accepted ADR mapping PHP/MySQL to PRD-v3 Hostinger PostgreSQL/PgBouncer + Hetzner target | Captain |
| PRD-v3 Hostinger deployment | `UNKNOWN` | Core Distro PHP/Next.js deployed to `srv1856614` with acceptance test | Implementation |
| PRD-v3 Hetzner deployment | `UNKNOWN` | Core Distro workers/Jobs running on `brandon-compute` with acceptance test | Implementation |
| Queue namespace | `UNKNOWN` | RabbitMQ `/core` virtual host created with project-scoped credentials and denial test | Implementation |
| Database isolation | `UNKNOWN` | PostgreSQL database and roles for Core Distro on Hostinger with isolation test | Implementation |
| File namespace | `UNKNOWN` | `/srv/brandon-files/core/` on Hostinger with isolation test | Implementation |
| CI/CD | `UNKNOWN` | GitHub workflows, container build, staging deploy, smoke tests, health gate, rollback for Core Distro | Implementation |
| Backup/DR | `UNKNOWN` | Live encrypted off-host backup, Namecheap target assignment, restore test, RPO/RTO recorded | Captain / Operator |
| Observability | `UNKNOWN` | Core Distro metrics, logs, alerts, SLOs visible in Grafana/Uptime Kuma | Implementation |
| ChatWidget streaming | `UNKNOWN` | Reproduction of "Invalid session ID" on staging Next.js with measurement date and owner assignment | Unassigned |

---

## 11. ADR / Decision Items Required

These decisions must be recorded as ADRs before PRD-v3 implementation can proceed. Source: `PRD v3 §23`.

| ADR | Decision required | Owner | Blocking |
|---|---|---|---|
| ADR-001 variant for Core Distro | Retain Namecheap/PHP 8.2 production, OR migrate to Hostinger KVM8 + Hetzner per PRD v3, OR define hybrid model | Captain | All PRD-v3 work |
| ADR-002 variant for Core Distro | Retain MySQL/Percona 8.4, OR adopt PostgreSQL/PgBouncer per PRD v3 | Captain | Database isolation work |
| ADR-003 | Core Distro background job model: retain queue-like PHP jobs on Namecheap, OR adopt Hetzner RabbitMQ per PRD v3 | Captain | Queue namespace work |
| ADR-004 | Core Distro Namecheap DR mode: Category 2 (shared/cPanel backup target) vs Category 1 (VPS-capable DR node) | Captain / Implementation | Backup/DR work |
| ADR-005 | Core Distro CI/CD stack: which pipeline, which container registry, which deployment target | Captain / Implementation | CI/CD work |
| ADR-006 | Core Distro observability stack: what metrics/logs/alerts tooling | Captain / Implementation | Observability work |
| ADR-007 | Shared codebase with CBD-Data: how to handle isolation during concurrent work on `core-distro-saas-clean` | Captain | Isolation work |

---

*This document is a domain-specific extension of `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`. It does not override or supersede the canonical PRD. Where this document is silent, the canonical PRD applies.*
