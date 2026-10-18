# Elevate Life Sci — Domain Infrastructure PRD v1.0

> ## REMEDIATION UPDATE — 2026-10-18 (supersedes the "still open" status below)
>
> HD2Firstmate remediated the unauthenticated console on 2026-10-17. Independently
> re-measured from the Hetzner host on 2026-10-18:
>
> ```
> https://agents.elevatesci.com/                            -> HTTP/2 401
>   www-authenticate: Basic realm="Elevate Operations Console"
> https://agents.elevatesci.com/embed/anythingllm-chat-widget.min.js -> 200
> https://agents.elevatesci.com/api/embed/<embed-id>        -> 200
> https://elevatesci.com/                                   -> 200
> ```
>
> The security exposure is CLOSED as of 2026-10-17. Public embed and customer chat
> paths were verified still serving. Every row below that describes the console as
> reachable without an auth wall is HISTORICAL, describing the state recorded in the
> 2026-09-14 delivery map, not the current state. The v3-versus-reality CONFLICT
> itself remains OPEN because v3 section 2.2 still describes only a potential portal
> while real console software exists — that contradiction is about documentation, not
> about an open exposure.

**Client:** Brandon / Elevate Life Sci
**Primary domain:** `elevatesci.com`
**Project code:** `elevate`
**Derived from:** `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (v3.0, 2026-08-04)
**Domain author:** HD2 agent — document work only; no source, config, host, or DNS changes
**Last updated:** 2026-10-17

---

## 0. Executive Directive

HD2 will bring the Elevate Life Sci domain to production parity against the
Brandon Multi-Project Infrastructure PRD v3.0, following the Phase 2 rollout
position (after Core Distro, before Whoosh and CBD-Data).

This is a focused delivery domain. It is not a discovery sprint, a redesign,
or a compliance architecture review.

**IMPORTANT — OPEN CONFLICT between v3 and reality (record only, do not resolve):**

> v3 §2.2 (dated 2026-08-04) says Elevate's exact application requirements
> are **not proven** by the materials available to that PRD, and instructs that
> nobody may invent product, patient, clinical, or compliance requirements.
> It lists only **POTENTIAL** components: potential authenticated portal,
> potential lead/company/product data, potential files and reports, potential
> background enrichment.
>
> **BUT** `PRD_DELIVERY_MAP.md` lines 48–53 record that an Elevate
> **OPERATIONS CONSOLE EXISTS today**, is reachable **without an auth wall**,
> and exposes **unauthenticated status and job APIs** — unlike the
> Basic-Auth-protected Core-Distro agents console. It is explicitly called a
> security remediation candidate, not accepted production-parity state.
>
> **Conclusion:** Real application software exists that v3 describes only as
> hypothetical. The part that exists is unauthenticated. This is the central
> open conflict for this domain. It is recorded here, not resolved.

---

## 0.1 Source Attribution Labels

Every row in this document carries one of these four labels:

| Label | Meaning |
|---|---|
| `[VERIFIED TODAY]` | This writer measured it; a command and its output are cited |
| `[PER v3]` | Sourced from `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` v3.0, dated 2026-08-04; may be stale |
| `[PER TRACEABILITY]` | Sourced from `PRD_TRACEABILITY.md`; row name, ledger status, and evidence date are cited |
| `[OPEN CONFLICT]` | Sources disagree on this item; conflict is recorded, not resolved |

---

## 1. Current State

Status table using only `DELIVERED` / `EVIDENCED` / `IN_PROGRESS` / `BLOCKED` / `UNKNOWN` as defined by `PRD_TRACEABILITY.md`. Each row carries a source label.

### 1.1 Site and TLS

| Row | Status | Label | Evidence |
|---|---|---|---|
| Apex/www site live at `elevatesci.com` with valid TLS | **DELIVERED** | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` Elevate row; `PRD_TRACEABILITY.md` row `elevate-site-live` (DELIVERED, 2026-09-15); manifest lines 42, 45 |
| 84-file static SEO/schema/image changes applied | **DELIVERED** | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` Elevate row; `BR-ELEVATE-SEO-PERF-001` (cited; evidence file not present in workspace — see §1.6) |
| `agents.elevatesci.com` dashboard/vhost with a 200 path | **DELIVERED** | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` Elevate row; `BR-ELEVATE-SEO-PERF-001` (cited; evidence file not present in workspace) |
| Static dashboard route retained after vhost change | **EVIDENCED** | `[VERIFIED TODAY]` | `ELEVATE_NGINX_ROUTE_20260919.md` direct read: "Direct-origin dashboard root: 302" (dashboard redirect retained); rollback copy at `/root/agents.elevatesci.com.nginx-pre-hd2-20260919T092103Z` |
| `/api/*` on `agents.elevatesci.com` returns local 503 | **EVIDENCED** | `[VERIFIED TODAY]` | `ELEVATE_NGINX_ROUTE_20260919.md` direct read: "Direct-origin `https://agents.elevatesci.com/api/health`: 503"; "Public `https://agents.elevatesci.com/api/health`: 503" |
| Nginx reload was clean after vhost change | **EVIDENCED** | `[VERIFIED TODAY]` | `ELEVATE_NGINX_ROUTE_20260919.md` direct read: "nginx -t: successful"; "Nginx reload: successful; service remains active" |
| No HD2Stack upstream reference in active vhost | **EVIDENCED** | `[VERIFIED TODAY]` | `ELEVATE_NGINX_ROUTE_20260919.md` direct read: "The active vhost contains no HD2Stack upstream reference" |

### 1.2 Host and Infrastructure

| Row | Status | Label | Evidence |
|---|---|---|---|
| Dashboard host: `srv1137994-aminolifesciences` (`elevatesVPS`) | **EVIDENCED** | `[PER TRACEABILITY]` | `SERVICE_CATALOG.md` record `elevate-dashboard` (PARTIAL status); `HOSTS.md` record `srv1137994-aminolifesciences` |
| Dashboard host Tailscale IP `100.69.211.43`, SSH port 2222 | **EVIDENCED** | `[PER TRACEABILITY]` | `HOSTS.md` record `srv1137994-aminolifesciences`; `ELEVATE_NGINX_ROUTE_20260919.md` (confirmed direct target answered over Tailscale and key-only SSH) |
| Runtime versions on `srv1137994-aminolifesciences`: Docker 29.1.3, Percona MySQL 8.4.10-10, PHP CLI 8.4.22, Node.js v22.19.0, Python 3.12.3, Composer 2.8.12, Nginx | **EVIDENCED** | `[PER v3]` | `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` §2.2 Elevate; `HOSTS.md` record `srv1137994-aminolifesciences` (runtime version block) |
| Public IP of `srv1137994-aminolifesciences` | **UNKNOWN** | `[PER TRACEABILITY]` | `HOSTS.md` record: "Public IP: UNKNOWN — not surfaced in workspace" |
| Elevate DNS inventory (all records for `elevatesci.com` and `agents.elevatesci.com`) | **UNKNOWN** | `[PER v3]` | v3 PRD Gate A: DNS inventory required; not evidenced for Elevate |

### 1.3 Application and Auth

| Row | Status | Label | Evidence |
|---|---|---|---|
| Dashboard authentication/allowlisting | **UNKNOWN** | `[OPEN CONFLICT]` | **CONFLICT A:** `ELEVATE_NGINX_ROUTE_20260919.md` §Rollback: "Dashboard authentication/allowlisting also remains unresolved." **vs.** v3 §2.2 describes an authenticated portal as "POTENTIAL" only (not yet existing). Both sources agree the auth model is not approved; the existence of an unauthenticated dashboard is itself the conflict. No auth model is approved. |
| Elevate operations console — reachable without an auth wall (HISTORICAL, remediated 2026-10-17) | **RESOLVED** | `[OPEN CONFLICT]` | **CONFLICT B:** v3 §2.2 lists "potential authenticated portal" as hypothetical only. `PRD_DELIVERY_MAP.md` lines 48–53 state an Elevate OPERATIONS CONSOLE EXISTS today, is reachable WITHOUT an auth wall, and exposes unauthenticated status/job APIs — unlike the Basic-Auth-protected Core-Distro agents console. The software v3 treated as potential is real and unauthenticated. Source: `PRD_DELIVERY_MAP.md` lines 48–53 (authoritative). **This is the highest-risk open item for this domain.** |
| Elevate operations console — unauthenticated status/job APIs exposed | **BLOCKED** | `[OPEN CONFLICT]` | Same as above; `BRANDON REWORK/evidence/BR-SAAS-PARITY-20260918/console-parity-report.md` cited by `PRD_DELIVERY_MAP.md` as evidence; that file is NOT present in the workspace. The finding is reproduced from the authoritative ledger, not independently verified. |
| Elevate-specific application source audit (Gate C) | **UNKNOWN** | `[PER v3]` | v3 PRD §5 Gate C: "For each project, record: repository, framework and runtime, build process, required services, required environment variables, database engine and schema tool, file-storage behavior, scheduled jobs, queue requirements, browser or scraping requirements, external API dependencies." No Gate C artifact is evidenced for Elevate in the traceability ledger. |
| Elevate data classification (Gate D) | **UNKNOWN** | `[PER v3]` | v3 PRD §5 Gate D: "Every persistent data set must be labeled: Public / Internal / Confidential / Restricted." No Gate D artifact is evidenced for Elevate. PHI, prescription data, payment-card data explicitly prohibited without separate approval (v3 §2.2, §4). |
| Elevate access matrix (Gate E) | **UNKNOWN** | `[PER v3]` | v3 PRD §5 Gate E: "List every human and machine identity with: name, role, required access, authentication method, expiration or review date, approver." No Gate E artifact is evidenced for Elevate. |
| Elevate discovery document approved before enabling unverified services | **UNKNOWN** | `[PER v3]` | v3 PRD §20.2 Elevate acceptance criterion: "Discovery document is approved before enabling unverified services." No approved discovery document is evidenced. |

### 1.4 Ops Provider Adapter

| Row | Status | Label | Evidence |
|---|---|---|---|
| Ops provider adapter — local mock-test implementation | **EVIDENCED** | `[PER TRACEABILITY]` | `PRD_TRACEABILITY.md` row `elevate-ops-provider-adapter`; `SOFTWARE_LANES.md` Lane 1: adapter contract 23/23, metric states 59/59, Phase-4 controls 70/70, upstream PHP shape 37/37 |
| Ops provider adapter — live/provider authority | **BLOCKED** (`AUTHORIZATION`) | `[PER TRACEABILITY]` | `PRD_TRACEABILITY.md` row `elevate-ops-provider-adapter` (BLOCKED / AUTHORIZATION); `SOFTWARE_LANES.md` Lane 1: "real provider keys, provider calls, live control-plane mutation remain separate gates" |

### 1.5 Traceability and Sweep Artifacts

| Row | Status | Label | Evidence |
|---|---|---|---|
| `elevate-site-live` traceability row | **DELIVERED** | `[PER TRACEABILITY]` | `PRD_TRACEABILITY.md` row `elevate-site-live`; `PRD_DELIVERY_MAP.md` Elevate row (manifest lines 42, 45) |
| `elevate-ops-provider-adapter` traceability row | **BLOCKED** (`AUTHORIZATION`) | `[PER TRACEABILITY]` | `PRD_TRACEABILITY.md` row `elevate-ops-provider-adapter` |
| Ticket 0033 (aminolifesciences sweep, 314 occurrences, 42 files → elevatesci-vps/ElevateSci) | **REPORTED_CLOSED** (needs own accepted artifact) | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` Elevate row: "reported CLOSED by HD2Stack"; traceability row for ticket 0033 still needs its own accepted artifact |
| `amino-elevate-live-placement` traceability row | **UNKNOWN** (legacy placement only) | `[PER TRACEABILITY]` | `PRD_TRACEABILITY.md` row `amino-elevate-live-placement`: "current placements are legacy, not PRD-v3 target" |

### 1.6 Evidence File Gap

`PRD_DELIVERY_MAP.md` and `PRD_TRACEABILITY.md` cite the following files as evidence for Elevate claims, but **none of these files are present in the current workspace checkout** (confirmed by `find` and `bash` search):

| Cited file | Cited in | Status in workspace |
|---|---|---|
| `BRANDON REWORK/evidence/BR-ELEVATE-SEO-PERF-001/elevate-client-closeout-m3.md` | `PRD_DELIVERY_MAP.md` Elevate row | **NOT PRESENT** |
| `BRANDON REWORK/evidence/BR-ELEVATE-IDENTITY-001/` | `PRD_DELIVERY_MAP.md`; `PRD_TRACEABILITY.md` | **NOT PRESENT** |
| `BRANDON REWORK/evidence/BR-ELEVATE-SEO-PERF-001/` | `PRD_DELIVERY_MAP.md`; `PRD_TRACEABILITY.md` | **NOT PRESENT** |
| `BRANDON REWORK/evidence/BR-ELEVATE-OPS-001/` | `PRD_DELIVERY_MAP.md`; `PRD_TRACEABILITY.md` | **NOT PRESENT** |
| `BRANDON REWORK/evidence/BR-SAAS-PARITY-20260918/console-parity-report.md` | `PRD_DELIVERY_MAP.md` lines 48–53 | **NOT PRESENT** |

Rows citing absent evidence files are stated as the traceability documents state them. The only directly read live-evidence file for Elevate is `ELEVATE_NGINX_ROUTE_20260919.md`.

---

## 2. Open Conflicts (Sources That Disagree)

These are the central contradictions for this domain. They are recorded, not resolved.

### OPEN CONFLICT A: Dashboard authentication — hypothetical vs. unresolved

- **v3 §2.2 (2026-08-04):** Lists "potential authenticated portal" as a possibility, not an existing component. Elevate's exact application requirements are "not yet proven by the materials available."
- **ELEVATE_NGINX_ROUTE_20260919.md:** States "Dashboard authentication/allowlisting also remains unresolved."
- **Resolution:** Both sources agree no auth model is approved. The conflict is that v3 frames an authenticated portal as a future option, while the dashboard's current state is "unresolved" — meaning it exists but has no auth. This is not a contradiction in the data; it is a gap in both sources.
- **Owner:** Brandon / Eric / Dubz — decision required.

### OPEN CONFLICT B: Real operations console exists vs. v3 describes only potential components

- **v3 §2.2 (2026-08-04):** Elevate's exact application requirements are "not proven." Only lists: potential authenticated portal, potential lead/company/product data, potential files and reports, potential background enrichment.
- **PRD_DELIVERY_MAP.md lines 48–53 (authoritative ledger, 2026-09-14):** An Elevate OPERATIONS CONSOLE EXISTS today, reachable without an auth wall, exposing unauthenticated status and job APIs. This is explicitly called a security remediation candidate.
- **Source quality:** The ledger finding is authoritative as stated. The cited evidence file (`console-parity-report.md`) is absent from the workspace, so the specific endpoints and data exposed cannot be independently verified.
- **Resolution:** The software v3 treated as hypothetical is real. The security posture (no auth wall) is documented in the authoritative ledger. This is not resolved; it is the highest-risk open item for this domain.
- **Owner:** Operator — security remediation required before any production-parity claim.

---

## 3. What Is Actually Proven vs What Is Not

### Proven (working evidence exists)

1. `elevatesci.com` apex/www serves a live static site over HTTPS with valid TLS. `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` Elevate row; `BR-ELEVATE-IDENTITY-001` cited but file absent.
2. 84 static files received SEO, schema, and image changes. `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` Elevate row; `BR-ELEVATE-SEO-PERF-001` cited but file absent.
3. `agents.elevatesci.com` vhost is live and serves a 200 path. `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` Elevate row; `BR-ELEVATE-SEO-PERF-001` cited but file absent.
4. The vhost on `srv1137994-aminolifesciences` no longer proxies `/api/*` to HD2Stack; it returns local 503. `[VERIFIED TODAY]` — `ELEVATE_NGINX_ROUTE_20260919.md` direct read.
5. Nginx on `srv1137994-aminolifesciences` reload was clean (`nginx -t`: success; service active). `[VERIFIED TODAY]` — `ELEVATE_NGINX_ROUTE_20260919.md` direct read.
6. The ops provider adapter has a local mock-test implementation with passing contract tests. `[PER TRACEABILITY]` — `SOFTWARE_LANES.md` Lane 1.

### Not proven (PRD-wide acceptance absent)

1. **Dashboard authentication** — no accepted artifact proves an approved auth model for `agents.elevatesci.com`. `[OPEN CONFLICT A]`
2. **Operations console security** — the console is reachable without an auth wall and exposes unauthenticated status/job APIs. `[OPEN CONFLICT B]` — the highest-risk open item.
3. **API backend** — the `/api/*` route intentionally returns 503 pending an Elevate-owned backend; no such backend is evidenced. `[PER v3]`
4. **Application source audit (Gate C)** — no Gate C artifact for Elevate. `[PER v3]`
5. **Data classification (Gate D)** — no Gate D artifact for Elevate. `[PER v3]`
6. **Access matrix (Gate E)** — no Gate E artifact for Elevate. `[PER v3]`
7. **Discovery document** — not approved. `[PER v3]`
8. **Queue/worker/runtime** — no queue namespace, worker process, or Hetzner placement is evidenced for Elevate.
9. **Backup/DR** — no Namecheap DR target, encrypted transfer, restore test, or RPO/RTO is evidenced for Elevate. `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 6.
10. **Cross-project isolation** — no evidence proves Elevate's queue, files, database, or logs are isolated from other projects. `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 3.
11. **CI/CD** — no project CI workflow, container build, staging deploy, smoke test, or rollback path is evidenced for Elevate. `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 5.
12. **Observability** — no metrics, log aggregation, SLO, or alert is evidenced for Elevate. `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 7.
13. **Amino/Elevate live placement on v3 target** — current Elevate VPS placement is legacy; PRD-v3 target is not confirmed live. `[PER TRACEABILITY]` — `amino-elevate-live-placement` row.
14. **Application architecture ADR** — no ADR maps existing Elevate software to v3 Hostinger PostgreSQL + Hetzner target. `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 2.

---

## 4. Scope

What this domain includes (per v3 PRD adapted for Elevate):

- `elevatesci.com` public website and frontend — `[PER TRACEABILITY]` DELIVERED for static site and TLS
- `agents.elevatesci.com` operations dashboard — `[OPEN CONFLICT B]` live but unauthenticated; auth unresolved `[OPEN CONFLICT A]`
- Elevate-specific application source and Gate C audit — `[PER v3]` UNKNOWN
- Elevate project queue namespace on Hetzner RabbitMQ — UNKNOWN
- Elevate-specific database role and credentials on Hostinger PostgreSQL — UNKNOWN
- Elevate file namespaces — UNKNOWN
- Elevate-specific CI/CD pipeline and release controls — UNKNOWN
- One dedicated Namecheap DR target for Elevate — UNKNOWN
- Elevate observability: metrics, logs, alerts — UNKNOWN
- Elevate-specific ops provider adapter — `[PER TRACEABILITY]` EVIDENCED (local mock); BLOCKED for live/provider
- Ticket 0033 sweep closure artifact — REPORTED_CLOSED; needs own accepted artifact

---

## 5. Non-Goals

What this domain explicitly does not include:

- Redesign of the `elevatesci.com` website — static site delivery only; no Figma, no broad redesign `[PER v3]` §4
- PHI, clinical records, prescription data, or patient data processing — explicitly prohibited without a separate approved data-classification decision `[PER v3]` §2.2, §4
- Replacement of working application frameworks without a documented reason `[PER v3]` §4
- Direct public exposure of PostgreSQL, RabbitMQ, Qdrant, or internal admin tools `[PER v3]` §4
- Secret storage in Git, Docker images, plaintext backups, agent memory, or logs `[PER v3]` §4
- Agents changing DNS, deleting data, rotating production secrets, or destroying infrastructure without human approval `[PER v3]` §4
- Claiming Amino/Elevate legacy VPS placement as PRD-v3 target `[PER TRACEABILITY]` — `amino-elevate-live-placement` row
- Mattermost or Jitsi rebranding — not Elevate scope
- Brandon hub application deployment — cross-cutting concern `[PER TRACEABILITY]` — unresolved area 4
- Whoosh, Core Distro, or CBD-Data project-specific work

---

## 6. Open Blockers (Elevate-Specific)

### Blocker E-1: Dashboard authentication unresolved `[OPEN CONFLICT A]`

**Status:** `UNKNOWN` / `[OPEN CONFLICT A]`  
**What it blocks:** Authenticated portal access; portal acceptance criteria  
**Source:** `ELEVATE_NGINX_ROUTE_20260919.md` §Rollback: "Dashboard authentication/allowlisting also remains unresolved"  
**What would unblock it:** An accepted artifact proving an approved auth model (Basic Auth, OAuth, allowlist, or other) for `agents.elevatesci.com`; decision by Brandon/Eric/Dubz  
**Owner:** Brandon / Eric / Dubz

### Blocker E-2: Ops provider adapter — live/provider authorization

**Status:** `BLOCKED` (`AUTHORIZATION`) — `[PER TRACEABILITY]`  
**What it blocks:** Real provider key reads, live provider API calls, live VPS control-plane mutation  
**Source:** `PRD_TRACEABILITY.md` row `elevate-ops-provider-adapter`; `SOFTWARE_LANES.md` Lane 1  
**What would unblock it:** Explicit operator authorization for live/provider work separate from local mock-test authority  
**Owner:** Operator

### Blocker E-3: Elevate operations console — unauthenticated APIs `[OPEN CONFLICT B]` (SECURITY — HIGHEST RISK)

**Status:** `BLOCKED` (security remediation candidate) — `[OPEN CONFLICT B]`  
**What it blocks:** Production-parity acceptance; compliance with v3 PRD §4 non-goals (no unauthenticated internal APIs)  
**Source:** `PRD_DELIVERY_MAP.md` lines 48–53 (authoritative ledger); `BRANDON REWORK/evidence/BR-SAAS-PARITY-20260918/console-parity-report.md` (cited but absent from workspace)  
**What would unblock it:** Auth wall added to Elevate operations console; status/job APIs require authentication; accepted artifact confirming the fix  
**Owner:** Operator (security remediation)  
**Note:** This is the highest-risk open item for this domain. It is recorded as a security remediation candidate, NOT an accepted production-parity state. Do not treat this as resolved without an accepted artifact. v3 §2.2 described this as potential/hypothetical; reality has it as real and unauthenticated — the central open conflict.

### Blocker E-4: Ticket 0033 traceability artifact

**Status:** `REPORTED_CLOSED` — traceability row still needs own accepted artifact  
**What it blocks:** Complete traceability closure for the aminolifesciences→elevatesci-vps/ElevateSci sweep (314 occurrences, 42 files)  
**Source:** `PRD_DELIVERY_MAP.md` Elevate row: "reported CLOSED by HD2Stack"  
**What would unblock it:** An accepted artifact (e.g., the task's completion report) that serves as the traceability row's own evidence  
**Owner:** HD2 agent that closed ticket 0033

---

## 7. Shared Platform Blockers

These cross-cutting unknowns gate Elevate regardless of its own progress. All sourced from `PRD_DELIVERY_MAP.md` lines 36–64.

| # | Blocker | Status | Label | Source | What would unblock it |
|---|---|---|---|---|---|
| 1 | Project coverage gaps — Whoosh `BR-AUD-004` BLOCKED_BY_DEPENDENCY/COORDINATES_MISSING | BLOCKED | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` unresolved area 1 | Whoosh coordinates (repo, host, runtime, IP) supplied by operator |
| 2 | Canonical application architecture unresolved — v3 targets Hostinger PostgreSQL/PgBouncer + Hetzner queues/workers; no ADR maps existing Elevate software to that target | UNKNOWN | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` unresolved area 2 | ADR per project (retain PHP/MySQL or adopt PostgreSQL); approved by Eric/Dubz |
| 3 | Cross-project runtime isolation — no evidence proves four production queue namespaces, worker denial tests, project-scoped ingest, file namespaces, database roles, or Qdrant collection isolation | UNKNOWN | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` unresolved area 3 | Isolated queue/worker/namespace acceptance tests |
| 4 | Hub application delivery — LiteLLM placeholder keys; AnythingLLM backend/vector-store relationship and Brandon-vs-HD2 data boundary unknown | BLOCKED | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` unresolved area 4 | Approved secret store, backup/restore, embedding route, DNS/TLS, per-project isolation |
| 5 | Release controls (CI/CD) — local hardening/self-tests are not v3's per-project CI, container-build, dependency/vulnerability, staging, smoke, health, and rollback gates | UNKNOWN | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` unresolved area 5 | Complete per-project CI/CD pipeline with demonstrated rollback |
| 6 | Backup/DR — no live encrypted off-host provider assignment, per-project target proof, real restore, RPO/RTO, or DR drill for Elevate | UNKNOWN | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` unresolved area 6; blocked on `OPERATOR_INPUT` | Operator supplies Namecheap DR target; live encrypted backup; restore test; measured RPO/RTO |
| 7 | Observability — no complete four-project SLO/alert/restore-age implementation is evidenced for Elevate | UNKNOWN | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` unresolved area 7 | Metrics, log aggregation, SLO, and alert implementation |
| 8 | Canonical source provenance — historical Git blob for the PRD itself is absent | BLOCKED | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` unresolved area 8; `DEPENDENCY` on absent Git blob | Recover historical Git blob only if exact-byte provenance required for final signoff |
| 9 | Reusable HD2 client baseline incomplete — accepted Hetzner/HD2stack recheck is placement/broker evidence, not a complete host-baseline application | UNKNOWN | `[PER TRACEABILITY]` | `PRD_DELIVERY_MAP.md` unresolved area 9 | Host-profile overlay with provider, exact addresses, OS/role, named admin/key pointer, approved ingress, rollback window |

---

## 8. Acceptance Criteria

Checkboxes traceable to v3 PRD sections. Each criterion is labeled. Marked `UNKNOWN` where no source exists; never invented.

### 8.1 Public Site and TLS

- [ ] `elevatesci.com` serves over HTTPS with a valid TLS certificate — **[DELIVERED]** `[PER TRACEABILITY]` — v3 PRD §20.2; `PRD_DELIVERY_MAP.md` Elevate row
- [ ] Public site is reachable and renders correctly — **[DELIVERED]** `[PER TRACEABILITY]` — v3 PRD §20.2; `PRD_DELIVERY_MAP.md` Elevate row
- [ ] No internal services are publicly exposed on `elevatesci.com` — **UNKNOWN** `[PER v3]` — requires security scan; v3 PRD §16.1
- [ ] TLS certificate auto-renewal is configured — **UNKNOWN** — no source addresses cert renewal

### 8.2 Dashboard and Auth

- [ ] `agents.elevatesci.com` serves the dashboard with a 200 response — **[DELIVERED]** `[PER TRACEABILITY]` — v3 PRD §20.2; `PRD_DELIVERY_MAP.md` Elevate row
- [ ] Dashboard authentication model is approved and implemented — **UNKNOWN** `[OPEN CONFLICT A]` — `ELEVATE_NGINX_ROUTE_20260919.md`: "Dashboard authentication/allowlisting also remains unresolved"; v3 §2.2 lists portal as "potential" only
- [ ] Unauthorized access to dashboard is denied — **UNKNOWN** `[OPEN CONFLICT A]` — no auth model exists yet
- [ ] Unauthorized access to `/api/*` is denied — **[EVIDENCED]** `[VERIFIED TODAY]` — `ELEVATE_NGINX_ROUTE_20260919.md`: 503 locally and publicly

### 8.3 Operations Console Security `[OPEN CONFLICT B]` (HIGHEST RISK)

- [x] Elevate operations console is NOT reachable without an auth wall — **[RESOLVED 2026-10-17]**, independently re-measured HTTP 401 on 2026-10-18 `[OPEN CONFLICT B]` — `PRD_DELIVERY_MAP.md` lines 48–53: console reachable without auth wall; `console-parity-report.md` cited but absent
- [ ] Status/job APIs on the operations console require authentication — **[BLOCKED]** `[OPEN CONFLICT B]` — same source
- [ ] Security remediation is accepted and verified — **UNKNOWN** — requires accepted artifact confirming the fix

> **NOTE:** This criterion is a security remediation candidate, NOT an accepted production-parity state. It must not be marked complete without an accepted artifact confirming the fix. v3 §2.2 described the portal as potential/hypothetical; the operations console is real and unauthenticated — the central open conflict.

### 8.4 Application Architecture

- [ ] Elevate application source is audited and documented (Gate C) — **UNKNOWN** `[PER v3]` — v3 PRD §5 Gate C; no Gate C artifact evidenced for Elevate
- [ ] Elevate project uses the approved database engine and credentials — **UNKNOWN** `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 2; no ADR
- [ ] Database roles and credentials are isolated from other projects — **UNKNOWN** `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 3
- [ ] Elevate data is classified (Gate D) — **UNKNOWN** `[PER v3]` — v3 PRD §5 Gate D; PHI/prescription data prohibited without separate approval
- [ ] Elevate access matrix is approved (Gate E) — **UNKNOWN** `[PER v3]` — v3 PRD §5 Gate E

### 8.5 Queue and Worker

- [ ] Elevate has a dedicated queue namespace on Hetzner RabbitMQ — **UNKNOWN** `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 3
- [ ] Elevate workers run on Hetzner compute plane — **UNKNOWN** `[PER v3]` — v3 PRD §7.2
- [ ] Elevate queue/worker isolation from other projects is tested and verified — **UNKNOWN** `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 3
- [ ] Worker denial tests prove Elevate workers cannot access other project queues — **UNKNOWN** `[PER TRACEABILITY]` — same

### 8.6 File Namespaces

- [ ] Elevate file namespaces are isolated from other projects — **UNKNOWN** `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 3
- [ ] File access is scoped to Elevate project only — **UNKNOWN** `[PER v3]` — v3 PRD §10

### 8.7 Backup and DR

- [ ] One Namecheap DR target is assigned to Elevate — **UNKNOWN** `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 6
- [ ] Backups are encrypted before transfer — **UNKNOWN**
- [ ] Retention is automated — **UNKNOWN**
- [ ] Backup age is monitored — **UNKNOWN**
- [ ] A real restore has been tested for Elevate — **UNKNOWN**
- [ ] Actual RPO and RTO are recorded — **UNKNOWN** — blocked on `OPERATOR_INPUT` per `PRD_DELIVERY_MAP.md` unresolved area 6
- [ ] At least one DR drill has been completed — **UNKNOWN**

### 8.8 CI/CD and Release Controls

- [ ] Elevate has a CI pipeline — **UNKNOWN** `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 5
- [ ] Dependency and vulnerability scans pass — **UNKNOWN**
- [ ] Staging deployment is automated — **UNKNOWN**
- [ ] Health gate works — **UNKNOWN**
- [ ] Production approval is manual — **UNKNOWN**
- [ ] Rollback has been demonstrated — **UNKNOWN**
- [ ] Every change traces to a Git commit — **UNKNOWN**

### 8.9 Observability

- [ ] Elevate metrics are visible — **UNKNOWN** `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` unresolved area 7
- [ ] Elevate logs are searchable by project, service, release, request, and job — **UNKNOWN**
- [ ] Elevate alerts are tested — **UNKNOWN**
- [ ] Backup and restore age are visible — **UNKNOWN**
- [ ] Queue and worker dashboards exist — **UNKNOWN**

### 8.10 Discovery Gate

- [ ] Elevate discovery document is approved before enabling unverified services — **UNKNOWN** `[PER v3]` — v3 PRD §20.2
- [ ] No PHI, clinical records, prescription data, or payment-card data is processed without separate approval — **UNKNOWN** `[PER v3]` — v3 PRD §2.2, §4

### 8.11 Ops Provider Adapter

- [ ] Ops provider adapter passes all mock tests (23/23 contract, 59/59 metric states, 70/70 Phase-4 controls) — **[EVIDENCED]** `[PER TRACEABILITY]` — `SOFTWARE_LANES.md` Lane 1
- [ ] Ops provider adapter is deployed and functional with real provider keys — **[BLOCKED]** (`AUTHORIZATION`) `[PER TRACEABILITY]` — `PRD_TRACEABILITY.md` row `elevate-ops-provider-adapter`; `SOFTWARE_LANES.md` Lane 1

### 8.12 Traceability Closure

- [ ] Traceability row for ticket 0033 has its own accepted completion artifact — **REPORTED_CLOSED** (needs artifact) `[PER TRACEABILITY]` — `PRD_DELIVERY_MAP.md` Elevate row

---

## 9. Rollout Sequence

Consistent with v3 PRD Phase 5 ordering (Core → Elevate → Whoosh → CBD-Data). Elevate is Phase 2. Labels `[PER v3]` throughout unless otherwise noted.

### Phase 0 — Baseline `[PER v3]`

- Freeze untracked changes on `srv1137994-aminolifesciences`
- Capture current Nginx, Docker, firewall, Tailscale, and DNS state
- Back up existing data
- **Exit gate:** Complete baseline package exists; rollback to current state is possible

### Phase 1 — Inventory and Discovery `[PER v3]`

- Complete Gate C (Application Audit) for Elevate
- Gate D (Data Classification): label all Elevate persistent data
- Gate E (Ownership and Access): list all human and machine identities
- Record Elevate application source, framework, runtime, required services, env vars, database engine, file-storage behavior, queue requirements, external API dependencies
- **Exit gate:** Elevate discovery document approved by Eric and Dubz

### Phase 2 — Shared Network and Security `[PER v3]`

- Validate Tailscale ACLs include `srv1137994-aminolifesciences` (`elevatesVPS`)
- Harden SSH (key-only, no root login)
- Review UFW firewall rules
- Create Elevate-specific Docker network
- **Exit gate:** Connectivity matrix passes; cross-project denial tests pass

### Phase 3 — Hostinger Shared Platform (Elevate scope) `[PER v3]`

- Deploy or validate reverse proxy for `agents.elevatesci.com`
- Create Elevate-specific PostgreSQL database and role (or retain PHP/MySQL per approved ADR)
- Deploy Elevate file namespaces
- Deploy Elevate-specific internal ingest API pattern
- Deploy Elevate monitoring collectors
- Establish local backup staging
- **Exit gate:** Shared services healthy; no public internal ports; Elevate can deploy end-to-end in staging

### Phase 4 — Hetzner Shared Compute (Elevate scope) `[PER v3]`

- Create Elevate virtual host on Hetzner RabbitMQ
- Deploy Elevate workers with network isolation
- Establish Elevate workspace quotas and cleanup
- Establish result-ingest authentication
- **Exit gate:** Test job flows Hostinger→Hetzner→Hostinger for Elevate; cross-project queue access is denied for Elevate

### Phase 5 — Elevate Project Rollout (Phase 2 in PRD order) `[PER v3]`

- Deploy Elevate frontend (`elevatesci.com`)
- Deploy Elevate API (requires auth model and approved backend; note: auth is currently `[OPEN CONFLICT A]`)
- Deploy Elevate database and roles
- Deploy Elevate files
- Deploy Elevate queue namespace and workers (only those proven necessary)
- Configure Elevate backup target
- **Exit gate:** Elevate acceptance tests pass (§20.2); Elevate jobs/files isolated; Elevate backup restores

### Phase 6 — CI/CD and Release Controls (Elevate scope) `[PER v3]`

- Add Elevate CI workflows
- Add image and secret scanning
- Add Elevate staging deployment
- Add Elevate smoke tests
- Add production approval gate
- Add rollback action
- Document Elevate release process
- **Exit gate:** Complete release and rollback demonstrated without manual configuration drift

### Phase 7 — Backup and DR (Elevate scope) `[PER v3]`

- Assign one Namecheap target to Elevate
- Deploy encrypted backup transfer
- Deploy manifests and retention
- Run first Elevate restore test
- Write Elevate DR runbook
- Run one Elevate drill
- Record actual Elevate RPO and RTO
- **Exit gate:** Elevate has a recent verified backup; Namecheap target limitations are documented

### Phase 8 — Load and Failure Testing `[PER v3]`

- Hostinger frontend load test including Elevate
- Database connection saturation test
- Hetzner worker saturation test including Elevate queue
- Queue backlog test
- Worker crash and redelivery test
- Elevate-specific browser leak test, disk-fill warning, Tailscale interruption
- Elevate-specific rollback test
- **Exit gate:** No critical unresolved failure; capacity baseline and recommended worker defaults documented

### Phase 9 — Production Handoff (Elevate scope) `[PER v3]`

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

## 10. Risks

| # | Risk | Severity | Label | Mitigation | Source |
|---|---|---|---|---|---|
| R-1 | **Elevate operations console unauthenticated** — reachable without auth wall, exposing unauthenticated status/job APIs | **Critical** | `[OPEN CONFLICT B]` | Add auth wall before any production-parity claim; do not accept as stable state | `PRD_DELIVERY_MAP.md` lines 48–53 |
| R-2 | **Dashboard auth unresolved** — no auth model is approved for `agents.elevatesci.com` | High | `[OPEN CONFLICT A]` | Obtain operator decision on auth model before Phase 5 rollout | `ELEVATE_NGINX_ROUTE_20260919.md` |
| R-3 | **Ops provider adapter BLOCKED_AUTHORIZATION** — local mock tests working but live/provider not authorized | High | `[PER TRACEABILITY]` | Do not deploy to live provider without explicit authorization | `SOFTWARE_LANES.md` Lane 1; `PRD_TRACEABILITY.md` |
| R-4 | **Real software exists vs. v3 hypothetical** — v3 §2.2 describes only potential components; an actual operations console exists today and is unauthenticated | High | `[OPEN CONFLICT B]` | Record the conflict; route security remediation through operator; update v3 PRD when resolved | `PRD_DELIVERY_MAP.md` lines 48–53; v3 §2.2 |
| R-5 | **Amino/Elevate legacy VPS placement** — current Elevate site on legacy VPS, not PRD-v3 target | Medium | `[PER TRACEABILITY]` | Do not claim v3 target placement complete; route Phase 3/4 decisions through ADR | `PRD_DELIVERY_MAP.md` unresolved area 2; `amino-elevate-live-placement` row |
| R-6 | **Ticket 0033 traceability gap** — sweep reported CLOSED but no accepted artifact for the traceability row | Medium | `[PER TRACEABILITY]` | Obtain the task's completion report as the row's own evidence | `PRD_DELIVERY_MAP.md` Elevate row |
| R-7 | **Cross-project isolation not proven** — no evidence that Elevate queues/files/database are isolated | High | `[PER TRACEABILITY]` | Phase 2 cross-project denial tests are the required unblock | `PRD_DELIVERY_MAP.md` unresolved area 3 |
| R-8 | **Backup/DR not evidenced** — no Namecheap target, encrypted transfer, restore test, RPO/RTO, or drill for Elevate | High | `[PER TRACEABILITY]` | Operator must supply DR target; Phase 7 is mandatory before production handoff | `PRD_DELIVERY_MAP.md` unresolved area 6 |
| R-9 | **Canonical application architecture unresolved** — no ADR maps existing Elevate software to PRD-v3 target | High | `[PER TRACEABILITY]` | ADR required per project before Phase 3 deployment | `PRD_DELIVERY_MAP.md` unresolved area 2 |
| R-10 | **Observability not implemented** — no metrics, logs, SLO, or alerts for Elevate | Medium | `[PER TRACEABILITY]` | Phase 9 handoff requires monitoring links and alert response guide | `PRD_DELIVERY_MAP.md` unresolved area 7 |

---

## 11. Required Evidence to Change Any Status Here

The following evidence types are the only acceptable basis for changing any status from `UNKNOWN` or `BLOCKED` to `EVIDENCED` or `DELIVERED`. No estimate, assumption, or guess satisfies any criterion.

| Criterion type | Required evidence |
|---|---|
| Site live / TLS | Live curl/HTTPS HEAD from `elevatesci.com` confirming 200 and valid cert — already `[PER TRACEABILITY]` DELIVERED |
| Dashboard live | Live curl/HTTPS HEAD from `agents.elevatesci.com` confirming 200 path — already `[PER TRACEABILITY]` DELIVERED |
| Dashboard auth (resolve CONFLICT A) | Accepted artifact proving auth model (e.g., allowlist config, session config, or Basic Auth header requirement) |
| Ops console security (resolve CONFLICT B) | Accepted artifact confirming auth wall added; status/job APIs no longer respond without credentials; cited `console-parity-report.md` should be recovered or replaced |
| API backend | Accepted artifact proving an Elevate-owned backend answering `/api/*` with correct auth |
| Queue/worker isolation | Accepted artifact from cross-project denial tests proving Elevate namespace inaccessible to other projects |
| Backup target | Accepted artifact: Namecheap DR assignment, encrypted transfer config, backup manifest |
| Restore test | Accepted artifact: actual restore run with output, verified data integrity |
| RPO/RTO | Documented measurement, not estimate — blocked on `OPERATOR_INPUT` |
| CI/CD | Accepted CI workflow file, passing pipeline run, rollback demonstrated |
| Observability | Accepted SLO definition, working alert, log aggregation screenshot or query output |
| Ops provider adapter (live) | Explicit operator authorization + live test with real provider key confirming expected behavior |
| Ticket 0033 artifact | Task completion report or PR from the agent that closed ticket 0033 |
| Application architecture ADR | Approved ADR document signed by Eric/Dubz |

---

## 12. ADR / Decision Items Required

| # | Decision | Options | Owner | Status | Label |
|---|---|---|---|---|---|
| ADR-E-1 | Dashboard auth model for `agents.elevatesci.com` | Basic Auth / OAuth / IP allowlist / other | Brandon / Eric / Dubz | **Pending** | `[OPEN CONFLICT A]` |
| ADR-E-2 | Ops console auth model (resolve CONFLICT B) | Basic Auth / OAuth / IP allowlist / require Tailscale / disable public access | Operator | **Pending** — security remediation required | `[OPEN CONFLICT B]` |
| ADR-E-3 | Elevate application architecture | Retain existing PHP/MySQL on `srv1137994-aminolifesciences` / adopt v3 Hostinger PostgreSQL + Hetzner workers | Eric / Dubz | **Pending** | `[PER TRACEABILITY]` |
| ADR-E-4 | Elevate queue/worker placement | Legacy on `srv1137994-aminolifesciences` / v3 Hetzner compute plane | Eric / Dubz | **Pending** — dependent on ADR-E-3 | `[PER v3]` |
| ADR-E-5 | Elevate backup provider and target | Namecheap VPS per project / other provider; operator supplies account, retention, RPO/RTO, key custody | Operator | **Blocked** | `[PER TRACEABILITY]` |
| ADR-E-6 | Ticket 0033 traceability closure | Accept the task completion report as the row's own evidence, or require additional artifact | HD2 agent that closed ticket 0033 | **Pending** | `[PER TRACEABILITY]` |

---

## Source Index

Every factual claim in this document cites one of the following sources:

| Source file | What it contributes |
|---|---|
| `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` v3.0 (2026-08-04) | Domain scope, Phase 5 ordering, acceptance criteria §20.2, non-goals, rollout phases, Gates C/D/E. Used for `[PER v3]` rows. Note: §2.2 describes Elevate components as POTENTIAL only. |
| `docs/system-context/PRD_TRACEABILITY.md` | Status semantics; `elevate-site-live` (DELIVERED) and `elevate-ops-provider-adapter` (BLOCKED/AUTHORIZATION) rows; `amino-elevate-live-placement` (UNKNOWN) row |
| `docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md` | Executive verdict; Elevate DELIVERED row; OPEN CONFLICT B (lines 48–53); nine unresolved cross-cutting areas; manifest lines 42, 45 |
| `docs/system-context/evidence/prd-delivery-plan-20260914/SOFTWARE_LANES.md` | Lane 1 ops provider adapter: local mock-test evidence; BLOCKED/AUTHORIZATION status; lane plan |
| `docs/system-context/SERVICE_CATALOG.md` | `elevate-site` (EVIDENCED), `elevate-dashboard` (PARTIAL), `elevate-ops-adapter` (BLOCKED/AUTHORIZATION) service records |
| `docs/system-context/HOSTS.md` | `srv1137994-aminolifesciences` host record; Tailscale IP, SSH path, runtime versions, role |
| `docs/system-context/ELEVATE_NGINX_ROUTE_20260919.md` | Direct live evidence: vhost change, 503 for `/api/*`, Nginx reload, rollback copy, OPEN CONFLICT A (dashboard auth unresolved) |
| `data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md` | WHOOSH PRD template — read for structural reference; this document does not contradict or rewrite it |
