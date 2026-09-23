# System-Context Warehouse — PRD TRACEABILITY

Human-readable authority for every PRD item record in `prd_traceability.yaml`.
Each row is grounded in cited evidence under `data/`. Rows that are not
evidenced use `BLOCKED` or `UNKNOWN` instead of guessing.

> **Provenance:** The canonical PRD is now stored at
> `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`
> (v3.0, 2026-08-04). `data/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md`
> remains the authoritative status summary. The original historical Git blob
> is still absent, so exact-byte history remains a separate provenance gap.

> **Do not claim** that Brandon bot routing, Mattermost rebranding, or
> Amino/Elevate live placement is complete unless an accepted artifact
> proves it. Rows below reflect this rule.

## Status semantics (mirror of `SCHEMA.md`)

- `DELIVERED` — Customer-facing release is live and verified end-to-end.
- `EVIDENCED` — Working software/runtime evidence exists but PRD-wide
  acceptance is not proven.
- `IN_PROGRESS` — Active implementation or audit is underway.
- `BLOCKED` — A named blocker prevents further progress.
- `UNKNOWN` — Not enough source to classify; do not invent.

---

## Project: Elevate Life Sci

### `elevate-site-live` — Elevate customer-facing site

| Field | Value | Source |
|---|---|---|
| PRD section | Elevate customer-facing site | `PRD_DELIVERY_MAP.md` Elevate row |
| Scope | `elevate` | `PRD_DELIVERY_MAP.md` |
| Status | `DELIVERED` | `PRD_DELIVERY_MAP.md` Elevate row (working customer-facing release for the cited scope) |
| Blocker | NONE | n/a |
| Evidence | `BR-ELEVATE-IDENTITY-001`, `BR-ELEVATE-SEO-PERF-001`, manifest lines 42, 45 | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | PRD-wide app/API/queue/backup/isolation acceptance is not proven | `PRD_DELIVERY_MAP.md` |

### `elevate-ops-provider-adapter` — ElevateSci Ops provider adapter

| Field | Value | Source |
|---|---|---|
| PRD section | Elevate operations provider adapter | `SOFTWARE_LANES.md` Lane 1 |
| Scope | `elevate` | `SOFTWARE_LANES.md` |
| Status | `BLOCKED` | `SOFTWARE_LANES.md` |
| Blocker | `AUTHORIZATION` | `SOFTWARE_LANES.md` |
| Evidence | `BR-ELEVATE-OPS-001` | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Local mock-test implementation only; live/provider authority remains separate | `SOFTWARE_LANES.md` |

## Project: Core Distro

### `coredistro-source-runtime` — Core Distro PHP source and runtime

| Field | Value | Source |
|---|---|---|
| PRD section | Core Distro production source and runtime | `PRD_DELIVERY_MAP.md` Core Distro row |
| Scope | `core-distro` | `PRD_DELIVERY_MAP.md` |
| Status | `EVIDENCED` | `PRD_DELIVERY_MAP.md` Core Distro row |
| Blocker | NONE | n/a |
| Evidence | `BR-AUD-002` (PHP production, Next.js staging, MySQL/Percona, auth/lead-list, queue-like city jobs), manifest line 28 | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Deployment/hydration/auth gates still open; PRD-v3 application architecture decision pending | `PRD_DELIVERY_MAP.md` |

### `coredistro-route-qa` — Core Distro route QA

| Field | Value | Source |
|---|---|---|
| PRD section | Core Distro route QA | `PRD_DELIVERY_MAP.md` Core Distro row |
| Scope | `core-distro` | `PRD_DELIVERY_MAP.md` |
| Status | `EVIDENCED` | `PRD_DELIVERY_MAP.md` |
| Blocker | NONE | n/a |
| Evidence | `BR-CORE-001` (PASS/FAIL/NOT_RUNTIME_VERIFIABLE) | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Read-only route QA; deployment/hydration/auth gates still open | `PRD_DELIVERY_MAP.md` |

### `coredistro-canary` — Core Distro 1-job canary

| Field | Value | Source |
|---|---|---|
| PRD section | Core Distro 1-job canary execution | `MINI_SPRINT_PREPARATION_REPORT.md` §3 |
| Scope | `core-distro` | `MINI_SPRINT_PREPARATION_REPORT.md` |
| Status | `BLOCKED` | `MINI_SPRINT_PREPARATION_REPORT.md` |
| Blocker | `OPERATOR_INPUT` | `MINI_SPRINT_PREPARATION_REPORT.md` |
| Evidence | `leadlists.php` SHA-256 `6f91999dafae7f85951f31455e339c375030fb71eb6c1ad9f474bdf71bce83d3`; backlog 36,823 jobs paused | `MINI_SPRINT_PREPARATION_REPORT.md` §3 |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Synthetic 1-job canary execution awaits explicit operator signal | `MINI_SPRINT_PREPARATION_REPORT.md` |

## Project: CBD-Data

### `cbd-data-source-and-audit` — CBD-Data source and audit

| Field | Value | Source |
|---|---|---|
| PRD section | CBD-Data source and audit | `PRD_DELIVERY_MAP.md` CBD-Data row |
| Scope | `cbd-data` | `PRD_DELIVERY_MAP.md` |
| Status | `EVIDENCED` | `PRD_DELIVERY_MAP.md` CBD-Data row |
| Blocker | NONE | n/a |
| Evidence | `BR-AUD-005` (scraping, enrichment, queue, export, storage, compute placement discovery), manifest line 11 | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Local restore/backup documents and tests exist; no accepted end-to-end Hostinger↔Hetzner queue/isolation/restore/signoff chain | `PRD_DELIVERY_MAP.md` |

### `cbd-worker-canary` — CBD worker canary

| Field | Value | Source |
|---|---|---|
| PRD section | CBD worker canary | `data/cbd-worker-canary/report.md` |
| Scope | `cbd-data` | `data/cbd-worker-canary/report.md` |
| Status | `EVIDENCED` (local canary); live placement not in PRD-v3 target | `data/cbd-worker-canary/report.md` |
| Blocker | `AUTHORIZATION` (live placement) | `PRD_DELIVERY_MAP.md` unresolved area 2 |
| Evidence | `data/cbd-worker-canary/report.md` | n/a |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Live placement on AminoVPS is not the PRD-v3 target | `PRD_DELIVERY_MAP.md` |

### `cbd-data-enrichment-gap` — CBD-Data enrichment gap

| Field | Value | Source |
|---|---|---|
| PRD section | CBD-Data enrichment | `PRD_DELIVERY_MAP.md` CBD-Data row |
| Scope | `cbd-data` | `PRD_DELIVERY_MAP.md` |
| Status | `EVIDENCED` | Gate-CBD-ENRICH-003 proves the bounded broker/runtime slice only |
| Blocker | `AUTHORIZATION` | Gate-004 remains closed |
| Evidence | Gate-003 `evidence.md`, `decision-and-rollback.md`, `tdd-evidence.md`, and local adapter `CHECK_PASS` | E-067; Access Baseline Registry Gate-003 record |
| Last verified | 2026-09-18 | Gate-003 live evidence date |
| Freshness days | 30 | n/a |
| Notes | Private RabbitMQ bootstrap and deterministic local status helper are evidenced; no publisher/consumer adapter, project_id, idempotency key, durable persistence/restore, or end-to-end Hostinger-to-Hetzner acceptance. Gate-004 and cutover remain unauthorized. | Gate-CBD-ENRICH-003 |

## Project: Whoosh

### `whoosh-audit` — Whoosh audit

| Field | Value | Source |
|---|---|---|
| PRD section | Whoosh audit | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| Scope | `whoosh` | `PRD_DELIVERY_MAP.md` |
| Status | `BLOCKED` | `PRD_DELIVERY_MAP.md` |
| Blocker | `DEPENDENCY` (`COORDINATES_MISSING`) | `PRD_DELIVERY_MAP.md` |
| Evidence | `BR-AUD-004` status `BLOCKED_BY_DEPENDENCY` | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Exact repository, hosting, runtime, and production IP required | `PRD_DELIVERY_MAP.md` |

### `whoosh-bot-routing` — Whoosh bot routing

| Field | Value | Source |
|---|---|---|
| PRD section | Whoosh bot routing | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| Scope | `whoosh` | `PRD_DELIVERY_MAP.md` |
| Status | `UNKNOWN` | n/a |
| Blocker | `DEPENDENCY` (`COORDINATES_MISSING`) | `PRD_DELIVERY_MAP.md` |
| Evidence | none surfaced for routing completion | n/a |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | **Do not claim Brandon bot routing is complete** without an accepted artifact | task acceptance rule 7 |

## Project: Brandon hub

### `hub-host-install` — Brandon hub host installation

| Field | Value | Source |
|---|---|---|
| PRD section | Brandon hub Stage 2–4 installation | `PRD_DELIVERY_MAP.md` BR-HUB-006 row |
| Scope | `hub` | `PRD_DELIVERY_MAP.md` |
| Status | `EVIDENCED` | `PRD_DELIVERY_MAP.md` |
| Blocker | NONE | n/a |
| Evidence | `BR-HUB-006` (OpenResty/OnePanel upstream, PostgreSQL, Redis, Qdrant, LiteLLM with placeholder keys), manifest line 33; `evidence/BR-HUB-006/stage2-4-migration.md` | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Application deployment remains separately queued; DNS/TLS/real credentials remain gated | `PRD_DELIVERY_MAP.md` |

### `hub-application-deployment` — Brandon hub application deployment

| Field | Value | Source |
|---|---|---|
| PRD section | Brandon hub application deployment | `PRD_DELIVERY_MAP.md` BR-HUB-006 row |
| Scope | `hub` | `PRD_DELIVERY_MAP.md` |
| Status | `BLOCKED` — Brandon app deployment has named backup/restore and secret-store gates; it is not currently deployed | `BRANDON_CAMPAIGN_CONTROL.md` §5; `BRANDON_HUB_TASKS.md` task 9 |
| Blocker | `OPERATOR_INPUT` | `PRD_DELIVERY_MAP.md` |
| Evidence | `PRD_DELIVERY_MAP.md` unresolved area 4; canonical PRD v3 §§6.1, 7.1–7.2, 11.5 | n/a |
| Last verified | 2026-09-19 | n/a |
| Freshness days | 30 | n/a |
| Notes | AnythingLLM is named by the Brandon Hub task queue, not the canonical PRD by product name; the app target is Hostinger `srv1856614`, while compute/Qdrant work belongs on Hetzner `brandon-compute`. Existing HD2 `llm.hd2.ai` does not satisfy Brandon delivery. Resolve approved secret store, backup/restore, embedding/vector backend, per-project isolation, and DNS/TLS gate before customer documents. | `BRANDON_HUB_TASKS.md` task 9; `WAREHOUSE_BOUNDARIES.md` |

## Project: Brandon compute

### `brandon-compute-runtime` — Brandon compute runtime

| Field | Value | Source |
|---|---|---|
| PRD section | Brandon compute runtime | `PRD_DELIVERY_MAP.md` BR-COMPUTE-LLM-001 row |
| Scope | `compute` | `PRD_DELIVERY_MAP.md` |
| Status | `UNKNOWN` — controller records identify a target runtime, but accepted live execution evidence is absent | `brandon-compute-runtime-registration-20260922.md` |
| Blocker | `EVIDENCE_MISSING` — source/build identity, exact runtime state, backup, and isolated restore test are not established | same as source |
| Evidence | Registration and handoff only; the prior `BR-COMPUTE-LLM-001` files are task prompts, not an accepted runtime result | `brandon-compute-runtime-registration-20260922.md` |
| Last verified | 2026-09-22 (operator-supplied host key verified; bounded read-only SSH probe confirmed `brandon-compute`/`hd2admin`/`100.106.6.22`; source/build and backup/restore evidence remain missing) | same as source |
| Freshness days | 30 | n/a |
| Notes | Treat `/opt/brandon` as a runtime copy/target and keep Ollama contained without install/removal until the Brandon evidence packet is accepted; no staging, cutover, public exposure, or client-data work is cleared | same as source |

### `brandon-compute-pi-1panel` — Brandon compute Pi/1Panel setup

| Field | Value | Source |
|---|---|---|
| PRD section | Brandon compute Pi/1Panel setup | `PRD_DELIVERY_MAP.md` BR-COMPUTE-PI-1PANEL-001 row |
| Scope | `compute` | `PRD_DELIVERY_MAP.md` |
| Status | `EVIDENCED` | `PRD_DELIVERY_MAP.md` |
| Blocker | NONE | n/a |
| Evidence | `BR-COMPUTE-PI-1PANEL-001`, manifest line 43 | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Private 1Panel/Pi setup; not exposed | `PRD_DELIVERY_MAP.md` |

## Cross-project: gateway, platform, isolation

### `gateway-spec` — Brandon gateway Phase 1 spec

| Field | Value | Source |
|---|---|---|
| PRD section | Brandon gateway Phase 1 specification | `PRD_DELIVERY_MAP.md` BR-COMPUTE-GATEWAY-SPEC-001 row |
| Scope | `cross-project` | `PRD_DELIVERY_MAP.md` |
| Status | `EVIDENCED` (offline spec; not executable on target until runtime work performed) | `PRD_DELIVERY_MAP.md` |
| Blocker | NONE | n/a |
| Evidence | `BR-COMPUTE-GATEWAY-SPEC-001` (8 offline tests); `evidence/BR-COMPUTE-GATEWAY-SPEC-001/M3_REVIEW.md` lines 39–44, 74–91; manifest line 51 | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Phase 2 live deployment is deferred | `PRD_DELIVERY_MAP.md` |

### `platform-isolation` — Cross-project runtime isolation

| Field | Value | Source |
|---|---|---|
| PRD section | Cross-project runtime isolation | `PRD_DELIVERY_MAP.md` unresolved area 3 |
| Scope | `cross-project` | `PRD_DELIVERY_MAP.md` |
| Status | `UNKNOWN` | `PRD_DELIVERY_MAP.md` |
| Blocker | `UNKNOWN` | n/a |
| Evidence | none surfaced for end-to-end isolation | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | No accepted evidence proves four production queue namespaces, worker denial tests, project-scoped ingest, file namespaces, database roles, or Qdrant collection isolation | `PRD_DELIVERY_MAP.md` |

### `platform-release-controls` — CI/CD and release controls

| Field | Value | Source |
|---|---|---|
| PRD section | Project CI/CD and release controls | `PRD_DELIVERY_MAP.md` unresolved area 5 |
| Scope | `platform` | `PRD_DELIVERY_MAP.md` |
| Status | `UNKNOWN` | `PRD_DELIVERY_MAP.md` |
| Blocker | `UNKNOWN` | n/a |
| Evidence | Accepted local hardening/self-tests are not the PRD project CI/CD, container-build, dependency/vulnerability, migration-dry-run, staging, smoke, health, and rollback gates | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Local controls do not satisfy the PRD's per-project gates | `PRD_DELIVERY_MAP.md` |

### `backup-dr` — Backup/DR

| Field | Value | Source |
|---|---|---|
| PRD section | Backup/DR (PRD v3 §backup/DR) | `PRD_DELIVERY_MAP.md` unresolved area 6 |
| Scope | `platform` | `PRD_DELIVERY_MAP.md` |
| Status | `UNKNOWN` | `PRD_DELIVERY_MAP.md` |
| Blocker | `OPERATOR_INPUT` (`BR-HUB-010` provider/account, retention, RPO/RTO, key custody) | `PRD_DELIVERY_MAP.md` |
| Evidence | Designs and synthetic harness exist; no live encrypted off-host provider assignment, per-project target proof, real restore, measured RPO/RTO, or required DR drill evidence is accepted | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | `BR-OPS-002` is a synthetic four-fixture restore-rehearsal harness; the manifest explicitly says it is acceptance-not-proof | `PRD_DELIVERY_MAP.md` |

### `observability` — Observability

| Field | Value | Source |
|---|---|---|
| PRD section | Observability (metrics/logs/alerts) | `PRD_DELIVERY_MAP.md` unresolved area 7 |
| Scope | `platform` | `PRD_DELIVERY_MAP.md` |
| Status | `UNKNOWN` | `PRD_DELIVERY_MAP.md` |
| Blocker | `UNKNOWN` | n/a |
| Evidence | Inventory/design references metrics/logs/alerts, but no complete four-project SLO/alert/restore-age implementation is evidenced | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Inventory only | `PRD_DELIVERY_MAP.md` |

### `platform-source-provenance` — Canonical source provenance

| Field | Value | Source |
|---|---|---|
| PRD section | Canonical source provenance | `PRD_DELIVERY_MAP.md` unresolved area 8 |
| Scope | `platform` | `PRD_DELIVERY_MAP.md` |
| Status | `BLOCKED` | `PRD_DELIVERY_MAP.md` |
| Blocker | `DEPENDENCY` (historical PRD Git blob absent from current checkout/object database) | `PRD_DELIVERY_MAP.md` |
| Evidence | `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` plus preserved session read at `/root/pi-recovery-snapshot-20260805T233406Z/agent/sessions/--root-agent-work--/2026-08-05T05-30-31-432Z_019fd066-e288-7afb-be7a-5e3cf9943422.jsonl` | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Canonical PRD is present in the warehouse; recover the historical Git blob only if exact-byte provenance is required before final signoff | `PRD_DELIVERY_MAP.md` |

### `mattermost-instance` — Mattermost instance ownership

| Field | Value | Source |
|---|---|---|
| PRD section | Mattermost instance ownership and rebrand | `PRD_DELIVERY_MAP.md` unresolved area 4 |
| Scope | `platform` | `PRD_DELIVERY_MAP.md` |
| Status | `BLOCKED` | `PRD_DELIVERY_MAP.md` |
| Blocker | `OPERATOR_INPUT` | `PRD_DELIVERY_MAP.md` |
| Evidence | none surfaced for live instance ownership | n/a |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | **Do not claim Mattermost rebranding is complete** without an accepted artifact | task acceptance rule 7 |

### `jitsi-instance` — Jitsi instance ownership

| Field | Value | Source |
|---|---|---|
| PRD section | Jitsi instance ownership and rebrand | `PRD_DELIVERY_MAP.md` unresolved area 4 |
| Scope | `platform` | `PRD_DELIVERY_MAP.md` |
| Status | `BLOCKED` | `PRD_DELIVERY_MAP.md` |
| Blocker | `OPERATOR_INPUT` | `PRD_DELIVERY_MAP.md` |
| Evidence | none surfaced for live instance ownership | n/a |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | **Do not claim Jitsi rebranding is complete** without an accepted artifact | task acceptance rule 7 |

### `amino-elevate-live-placement` — Amino/Elevate live placement

| Field | Value | Source |
|---|---|---|
| PRD section | Brandon live placement on Amino/Elevate legacy VPS | `PRD_DELIVERY_MAP.md` unresolved area 2 |
| Scope | `platform` | `PRD_DELIVERY_MAP.md` |
| Status | `UNKNOWN` | `PRD_DELIVERY_MAP.md` |
| Blocker | `AUTHORIZATION` (PRD-v3 target is Hostinger PostgreSQL/PgBouncer, Hetzner compute plane) | `PRD_DELIVERY_MAP.md` |
| Evidence | None surfaced for PRD-v3-compliant live placement; only legacy placements cited | n/a |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | **Do not claim Amino/Elevate live placement is complete**; current placements are legacy, not PRD-v3 target | task acceptance rule 7 |
