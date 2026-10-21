# System-Context Warehouse — SERVICE CATALOG

Human-readable authority for every service record in `service_catalog.yaml`.
Each record separates platform ownership from tenant/client and from brand or
domain. Where current evidence does not identify ownership, the field is
`UNKNOWN` and the record status reflects that.

> **AnythingLLM instances are separate services.**
> 1. **Internal properties** (`hd2.ai`, internal sites) run on **HD2Stack (`vmi3238503`)** via endpoint `llm.hd2.ai` (container `anythingllm` on port 3010, companion `ollama-hd2-1panel` on port 21434 with Gemini provider and no Ollama models pulled).
> 2. **Client sites** (Core-Distro, CBD, customer sites) run on **Hetzner host (`100.106.6.22:3001`)** (`elevate-anythingllm`), reached strictly through each client site's own hostname proxy, NEVER through `llm.hd2.ai`.
> 3. **The rule that was broken:** Core-Distro staging pointed its widget at `llm.hd2.ai/api/embed` (which returns 404), causing client chat outage. A client site must never depend on the internal HD2 instance.
> 4. **Brandon hub** task queue names a separate instance targeted to `srv1856614`; deployment and its backup, secret-store, vector-backend, and project-isolation gates remain open (`BLOCKED`).
> **Mattermost and Jitsi instance ownership is also unresolved** in current
> evidence; do not assign them to a brand or domain until an accepted source
> proves the assignment.

## Record fields (mirror of `SCHEMA.md`)

- `id` — stable identifier.
- `platform_owner` — `deightonllm`, `brandon`, `elevate`, or `UNKNOWN`.
- `tenant_or_client` — `core-distro`, `cbd-data`, `elevate`, `whoosh`, `hd2`,
  `brandon-hub`, `brandon-compute`, `music-metrics`, `lawyer`, or `UNKNOWN`.
- `brand_or_domain` — primary brand or domain, or `UNKNOWN`.
- `current_host` — host id from `hosts.yaml`, or `UNKNOWN`.
- `intended_host` — host id, or `UNKNOWN`.
- `runtime` — `container`, `systemd`, `php-fpm`, `node`, `python`,
  `static`, or `UNKNOWN`.
- `allowed_actions` — read / local-build / mock-test / staging-deploy /
  production-deploy / live-mutate.
- `evidence_paths`, `sources`, `last_verified`, `freshness_days`, `status`,
  `notes` — see `SCHEMA.md`.

---

## `hd2-anythingllm` — Existing HD2 AnythingLLM (Internal Only)

| Field | Value | Source |
|---|---|---|
| Platform owner | `deightonllm` | `BRANDON_HUB_COMPONENT_INVENTORY.md` |
| Tenant or client | `hd2` — internal HD2 properties only (`hd2.ai`, internal sites) | `BRANDON_HUB_COMPONENT_INVENTORY.md` |
| Brand or domain | `llm.hd2.ai` | `BRANDON_HUB_COMPONENT_INVENTORY.md` |
| Current host | `hd2stack` (`vmi3238503`) — measured live 2026-10-17: container `anythingllm` (`1.12.1`) published `127.0.0.1:3010 -> 3001` (healthy); companion `ollama-hd2-1panel` (`0.33.2`) published `127.0.0.1:21434 -> 11434` | Measured live 2026-10-17 |
| Intended host | `hd2stack` (`vmi3238503`) — internal properties only | `lane-docs-topology.md` |
| Runtime | `container` (Docker Compose, named volumes) | Measured live 2026-10-17 |
| Allowed actions | `read` | n/a |
| Status | `VERIFIED` — measured live 2026-10-17: endpoint `llm.hd2.ai` returns HTTP 200 via Cloudflare. Config: `LLM_PROVIDER=gemini`, `GEMINI_LLM_MODEL_PREF=gemini-3.1-flash-lite-preview`, `VECTOR_DB=lancedb`, `OLLAMA_MODEL_PREF=qwen2.5:0.5b` with no model actually pulled (empty `[]`). | Measured live 2026-10-17 |
| Last verified | 2026-10-17 | n/a |
| Notes | Dedicated strictly to internal HD2 properties (`hd2.ai`). Architecture rule: Client sites (Core-Distro, CBD, customer sites) must NEVER query or depend on `llm.hd2.ai`. Client sites are served by AnythingLLM on Hetzner host (`100.106.6.22:3001`) via each client site's own domain proxy. | `lane-docs-topology.md`; `WAREHOUSE_BOUNDARIES.md` |

## `hetz-anythingllm` — Client-facing AnythingLLM on Hetzner

| Field | Value | Source |
|---|---|---|
| Platform owner | `brandon` / `elevate` | `BRANDON_HUB_SERVICE_MATRIX.md` |
| Tenant or client | `core-distro`, `cbd-data`, `elevate` — client sites | `2026-10-17-STOP-8081-is-client-dependency.md` |
| Brand or domain | Client site hostnames (e.g., `staging.core-distro.com`, `elevatesci.com`) — never `llm.hd2.ai` | `lane-docs-topology.md` |
| Current host | `brandon-compute` (`100.106.6.22`) | Measured live 2026-10-17: container `elevate-anythingllm` (`mintplexlabs/anythingllm:1.16.2`) bound to `127.0.0.1:3001` and `100.106.6.22:3001` (healthy) |
| Intended host | `brandon-compute` (`100.106.6.22`) | `HOSTS.md` |
| Runtime | `container` (Docker) | Measured live 2026-10-17 |
| Allowed actions | `read`, `mock-test` | n/a |
| Status | `VERIFIED` — measured live 2026-10-17. Healthy container serving client sites. Backed by llama-server on `http://host.docker.internal:8081/v1` (`generic-openai`, `lfm2.5`). | Measured live 2026-10-17 |
| Last verified | 2026-10-17 | n/a |
| Notes | Client sites reach this instance strictly through each site's own hostname proxy (e.g. `staging.core-distro.com/api/embed`), NEVER through `llm.hd2.ai`. Port 8081 on Hetz is a required client dependency and must not be stopped or rebound. | `2026-10-17-STOP-8081-is-client-dependency.md`; `lane-docs-topology.md` |

## `brandon-anythingllm` — Brandon Hub AnythingLLM (not deployed)

| Field | Value | Source |
|---|---|---|
| Platform owner | `brandon` | `BRANDON_HUB_TASKS.md` task 9 |
| Tenant or client | `brandon-hub` — project-level authorization/isolation still required | `BRANDON_HUB_TASKS.md` task 9; PRD v3 §11.5 |
| Brand or domain | UNKNOWN — no approved hostname | `BRANDON_HUB_SERVICE_MATRIX.md` §3.5 |
| Current host | UNKNOWN — no Brandon AnythingLLM deployment is evidenced | `BRANDON_HUB_TASKS.md` task 9 |
| Intended host | `srv1856614` (Hostinger KVM8 Brandon hub) | `BRANDON_HUB_SERVICE_MATRIX.md` §3.5 |
| Runtime | `container` (target design only) | `BRANDON_HUB_SERVICE_MATRIX.md` §3.5 |
| Allowed actions | `read`, `mock-test` | n/a |
| Status | `BLOCKED` — application deployment waits for the backup/restore and approved secret-store gates | `BRANDON_CAMPAIGN_CONTROL.md` §5; `BRANDON_HUB_TASKS.md` task 9 |
| Last verified | 2026-09-19 | n/a |
| Freshness days | 30 | n/a |
| Notes | AnythingLLM is named by the Hub task queue, not the canonical PRD itself. Existing `llm.hd2.ai` is a separate HD2 service. Do not index Brandon documents until approved auth, backup/restore, backend, and per-project isolation are proven. | `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`; `WAREHOUSE_BOUNDARIES.md` |

## `litellm-gateway` — LiteLLM gateway on Brandon hub

| Field | Value | Source |
|---|---|---|
| Platform owner | `brandon` | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Tenant or client | `brandon-hub` | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Brand or domain | UNKNOWN | n/a |
| Current host | `srv1856614` (`brandon-hub`) | `BR-HUB-006` stage 2–4 evidence |
| Intended host | `srv1856614` (`brandon-hub`) | `BRANDON_HUB_SERVICE_MATRIX.md` §3.4 |
| Runtime | `container` (1Panel service) | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Allowed actions | `read`, `mock-test` | n/a |
| Status | `PARTIAL` — installed on the Brandon hub; placeholder keys block model calls | `BR-HUB-006` stage 2–4 evidence |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Brandon staging instance is hub-only/private-bound; an older controller-host LiteLLM instance is separately recorded in BR-HUB-001 and its relation is unreconciled. Real model credentials, embedding route, and production secret store remain gated. | `BR-HUB-006` stage 2–4 evidence; `BRANDON_HUB_SERVICE_MATRIX.md` §3.4 |

## `openresty-onepanel-upstream` — OpenResty/OnePanel upstream

| Field | Value | Source |
|---|---|---|
| Platform owner | `brandon` | `BR-HUB-006` stage 2–4 evidence |
| Tenant or client | `brandon-hub` | `BRANDON_CAMPAIGN_CONTROL.md` §2 |
| Brand or domain | UNKNOWN | n/a |
| Current host | `srv1856614` (`brandon-hub`) | `BR-HUB-006` stage 2–4 evidence |
| Intended host | `srv1856614` (`brandon-hub`) | `BRANDON_HUB_SERVICE_MATRIX.md` §3.2 |
| Runtime | `container` (OnePanel upstream) | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Allowed actions | `read` | n/a |
| Status | `PARTIAL` — hub proxy/panel staged; app and DNS/TLS cutover remain gated | `BR-HUB-006` stage 2–4 evidence |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Hostinger hub only; HD2Stack `vmi3238503` is separate in-house infrastructure and is not a Brandon proxy upstream target. | `BRANDON_CAMPAIGN_CONTROL.md` §2; `BRANDON_HUB_SERVICE_MATRIX.md` §3.2 |

## `brandon-postgres` — PostgreSQL on Brandon hub

| Field | Value | Source |
|---|---|---|
| Platform owner | `brandon` | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Tenant or client | `brandon-hub` | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Brand or domain | UNKNOWN | n/a |
| Current host | `srv1856614` (`brandon-hub`) | `BR-HUB-006` stage 2–4 evidence |
| Intended host | `srv1856614` (`brandon-hub`) | `BRANDON_HUB_SERVICE_MATRIX.md` §3.8 |
| Runtime | `container` | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Allowed actions | `read` | n/a |
| Status | `PARTIAL` — installed/configured; project-scoped databases/roles not proven | `BR-HUB-006` stage 2–4 evidence; PRD v3 §8.1 |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Host placement matches the PRD's Hostinger hub role; project database/role isolation and the PgBouncer front end still need acceptance evidence. | PRD v3 §8.1; `BRANDON_HUB_SERVICE_MATRIX.md` §3.8 |

## `brandon-redis` — Redis on Brandon hub

| Field | Value | Source |
|---|---|---|
| Platform owner | `brandon` | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Tenant or client | `brandon-hub` | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Brand or domain | UNKNOWN | n/a |
| Current host | `srv1856614` (`brandon-hub`) | `BR-HUB-006` stage 2–4 evidence |
| Intended host | `srv1856614` (`brandon-hub`) | `BRANDON_HUB_SERVICE_MATRIX.md` §3.9 |
| Runtime | `container` | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Allowed actions | `read` | n/a |
| Status | `PARTIAL` — installed; service necessity and project namespace isolation are not accepted | `BR-HUB-006` stage 2–4 evidence; `BRANDON_HUB_SERVICE_MATRIX.md` §3.9 |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Installed on Hostinger hub; current service necessity and project-scoped namespace isolation are not accepted. | `BRANDON_HUB_SERVICE_MATRIX.md` §3.9 |

## `brandon-qdrant` — Qdrant vector store (staged on hub; target on compute)

| Field | Value | Source |
|---|---|---|
| Platform owner | `brandon` | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Tenant or client | `brandon-hub` | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Brand or domain | UNKNOWN | n/a |
| Current host | `srv1856614` (`brandon-hub`) — staged install, not accepted production placement | `BR-HUB-006` stage 2–4 evidence |
| Intended host | `brandon-compute` (`hetzner-compute`) per PRD v3 §§6.1, 7.2 | `BRANDON_HUB_SERVICE_MATRIX.md` §3.6; canonical PRD v3 |
| Runtime | `container` | `PRD_DELIVERY_MAP.md` BR-HUB-006 |
| Allowed actions | `read` | n/a |
| Status | `PARTIAL` — staged install exists; target compute placement and per-project collection isolation are not accepted | `BR-HUB-006` stage 2–4 evidence; PRD v3 §§6.1, 7.2 |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Current staged Qdrant is on Hostinger, but PRD v3 assigns Qdrant and temporary work data to Hetzner compute; AnyLLM's internal vector backend is still unknown. Do not use HD2Stack or migrate data until target access, backup, and isolation gates are explicitly accepted. | `BRANDON_HUB_SERVICE_MATRIX.md` §3.6; `WAREHOUSE_BOUNDARIES.md` |

## `mattermost-instance` — Mattermost service

| Field | Value | Source |
|---|---|---|
| Platform owner | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 4 |
| Tenant or client | UNKNOWN | n/a |
| Brand or domain | UNKNOWN | n/a |
| Current host | UNKNOWN — no live host surfaced | `PRD_DELIVERY_MAP.md` unresolved area 4 |
| Intended host | UNKNOWN | n/a |
| Runtime | UNKNOWN | n/a |
| Allowed actions | `read` | n/a |
| Status | `BLOCKED` — instance ownership and brand/domain relationship explicitly unresolved | `PRD_DELIVERY_MAP.md` unresolved area 4 |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | **Do not claim Mattermost rebranding is complete**; no accepted artifact proves current instance ownership | `PRD_DELIVERY_MAP.md` unresolved area 4 |

## `jitsi-instance` — Jitsi service

| Field | Value | Source |
|---|---|---|
| Platform owner | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 4 |
| Tenant or client | UNKNOWN | n/a |
| Brand or domain | UNKNOWN | n/a |
| Current host | UNKNOWN — no live host surfaced | `PRD_DELIVERY_MAP.md` unresolved area 4 |
| Intended host | UNKNOWN | n/a |
| Runtime | UNKNOWN | n/a |
| Allowed actions | `read` | n/a |
| Status | `BLOCKED` — instance ownership and brand/domain relationship explicitly unresolved | `PRD_DELIVERY_MAP.md` unresolved area 4 |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | **Do not claim Jitsi rebranding is complete**; no accepted artifact proves current instance ownership | `PRD_DELIVERY_MAP.md` unresolved area 4 |

## `coredistro-staging` — Core-Distro WordPress Staging (Next.js Decommissioned)

| Field | Value | Source |
|---|---|---|
| Platform owner | `brandon` | `PRD_DELIVERY_MAP.md` |
| Tenant or client | `core-distro` | `PRD_DELIVERY_MAP.md` |
| Brand or domain | `staging.core-distro.com` | `report-staging-retirement-option-a.md` |
| Current host | `brandon-compute` (`100.106.6.22:8087` via `srv1137994-elevatesci` Nginx reverse proxy) | `report-staging-retirement-option-a.md` |
| Intended host | `brandon-compute` (`100.106.6.22`) | `HOSTS.md` |
| Runtime | `container` (Docker `core-distro-stage-wordpress-1`, WordPress 7.1.3 / PHP 8.3.35) | Measured live 2026-10-18 |
| Allowed actions | `read`, `mock-test`, `staging-deploy` | n/a |
| Status | `VERIFIED` — live WordPress staging container on Hetzner compute `100.106.6.22:8087` proxied via ElevateSci Nginx at `https://staging.core-distro.com`. Next.js staging systemd service `core-distro-staging.service` stopped, disabled, and archived at `/opt/core-distro-staging-pre-retire-20261018.tar.gz`. | `report-staging-retirement-option-a.md` |
| Last verified | 2026-10-18 | n/a |
| Freshness days | 30 | n/a |
| Notes | Legacy Next.js staging retired per Captain Option A mandate 2026-10-18. Reverse proxy points `location /` to Hetzner Docker origin `http://100.106.6.22:8087`. AnythingLLM `/llm/chat/` and `/api/embed/` routes preserved. | `report-staging-retirement-option-a.md` |

## `coredistro-production` — Core-Distro PHP production

| Field | Value | Source |
|---|---|---|
| Platform owner | `brandon` | `PRD_DELIVERY_MAP.md` |
| Tenant or client | `core-distro` | `PRD_DELIVERY_MAP.md` |
| Brand or domain | `core-distro.com` | `BR-AUD-002/report.md` |
| Current host | `srv1137994-elevatesci` | `BR-AUD-002/report.md` |
| Intended host | UNKNOWN — PRD-v3 application architecture decision pending | `PRD_DELIVERY_MAP.md` unresolved area 2 |
| Runtime | `php-fpm` | `BR-AUD-002/report.md` |
| Allowed actions | `read`, `mock-test` | n/a |
| Status | `PARTIAL` — running PHP/MySQL; deployment/hydration/auth gates still open | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Architecture decision (PHP/MySQL retention vs PRD PostgreSQL) requires ADR | `PRD_DELIVERY_MAP.md` unresolved area 2 |

## `cbd-worker` — CBD-Data systemd worker

| Field | Value | Source |
|---|---|---|
| Platform owner | `brandon` | `BR-INV-001/report.md` §Host 1 |
| Tenant or client | `cbd-data` | `BR-INV-001/report.md` §Host 1 |
| Brand or domain | `cbd-data.com` | `BR-AUD-005/report.md` |
| Current host | `srv1137994-elevatesci` | `BR-INV-001/report.md` §Host 1 |
| Intended host | `hetzner-compute` (per PRD-v3 compute plane) | `PRD_DELIVERY_MAP.md` |
| Runtime | `systemd` (`cbd-worker.service`) | `BR-INV-001/report.md` §Host 1 |
| Allowed actions | `read`, `local-build`, `mock-test` | n/a |
| Status | `KNOWN` (active on Elevatesci VPS) | `BR-INV-001/report.md` §Host 1 |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Live placement on Elevatesci VPS is not the PRD-v3 target; migration requires separate authority | `PRD_DELIVERY_MAP.md` unresolved area 2 |

## `elevate-site` — Elevate Life Sci customer-facing site

| Field | Value | Source |
|---|---|---|
| Platform owner | `elevate` | `PRD_DELIVERY_MAP.md` |
| Tenant or client | `elevate` | `PRD_DELIVERY_MAP.md` |
| Brand or domain | `elevatesci.com` | `PRD_DELIVERY_MAP.md` |
| Current host | UNKNOWN — apex/www host not in workspace evidence; live state confirmed by `BR-ELEVATE-IDENTITY-001` and `BR-ELEVATE-SEO-PERF-001` evidence | `PRD_DELIVERY_MAP.md` |
| Intended host | UNKNOWN | n/a |
| Runtime | `static` (per cited SEO/schema/image changes, 84 files) | `PRD_DELIVERY_MAP.md` |
| Allowed actions | `read` | n/a |
| Status | `EVIDENCED` — working customer-facing release for cited scope | `PRD_DELIVERY_MAP.md` |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |

## `elevate-dashboard` — Elevate Life Sci dashboard

| Field | Value | Source |
|---|---|---|
| Platform owner | `elevate` | `PRD_DELIVERY_MAP.md` |
| Tenant or client | `elevate` | `PRD_DELIVERY_MAP.md` |
| Brand or domain | `agents.elevatesci.com` | `PRD_DELIVERY_MAP.md` |
| Current host | `srv1137994-elevatesci` (Hostinger KVM8; direct host verified 2026-09-19) | `hosts.yaml`; `ELEVATE_NGINX_ROUTE_20260919.md` |
| Intended host | UNKNOWN — an Elevate-owned API backend target is not approved | `ELEVATE_NGINX_ROUTE_20260919.md` |
| Runtime | `static` dashboard via Nginx; `/api/*` fails closed locally | `ELEVATE_NGINX_ROUTE_20260919.md` |
| Allowed actions | `read` | n/a |
| Status | `PARTIAL` — static dashboard route retained; API disabled pending Elevate-owned backend and auth | `ELEVATE_NGINX_ROUTE_20260919.md` |
| Last verified | 2026-09-19 | `ELEVATE_NGINX_ROUTE_20260919.md` |
| Freshness days | 30 | n/a |
| Notes | Active vhost no longer proxies to HD2Stack; direct `/api/health` returns 503, dashboard root returns 302. Dashboard authentication remains unresolved. | `ELEVATE_NGINX_ROUTE_20260919.md` |

## `elevate-ops-adapter` — ElevateSci Ops provider adapter

| Field | Value | Source |
|---|---|---|
| Platform owner | `elevate` | `SOFTWARE_LANES.md` Lane 1 |
| Tenant or client | `elevate` | `SOFTWARE_LANES.md` Lane 1 |
| Brand or domain | `elevatesci.com` | `SOFTWARE_LANES.md` Lane 1 |
| Current host | UNKNOWN — implementation is local mock-test only | `SOFTWARE_LANES.md` Lane 1 |
| Intended host | UNKNOWN — live provider authority remains separate | `SOFTWARE_LANES.md` Lane 1 |
| Runtime | UNKNOWN (PHP backend adapter module under `agents-dashboard-source/backend/`) | `SOFTWARE_LANES.md` Lane 1 |
| Allowed actions | `read`, `local-build`, `mock-test` | n/a |
| Status | `BLOCKED` — `BLOCKED_AUTHORIZATION` for live/provider work | `SOFTWARE_LANES.md` Lane 1 |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Local mock-test implementation only; no real key reads or live calls | `SOFTWARE_LANES.md` Lane 1 |

## `music-metrics` — Music Metrics (write-locked)

| Field | Value | Source |
|---|---|---|
| Platform owner | `deightonllm` | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Tenant or client | `music-metrics` | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Brand or domain | UNKNOWN | n/a |
| Current host | `retained-evidence` (read-only retention) | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Intended host | UNKNOWN | n/a |
| Runtime | `php-fpm` | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Allowed actions | `read` (write-locked) | n/a |
| Status | `KNOWN` (preserved byte-for-byte) | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Music Metrics write-locked unless explicitly named | `AGENTS.md` Always-on safety |

## `lawyer` — Lawyer services (read-only retained)

| Field | Value | Source |
|---|---|---|
| Platform owner | `deightonllm` | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Tenant or client | `lawyer` | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Brand or domain | UNKNOWN | n/a |
| Current host | `retained-evidence` (read-only retention) | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Intended host | UNKNOWN | n/a |
| Runtime | `php-fpm` | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Allowed actions | `read` | n/a |
| Status | `KNOWN` (preserved byte-for-byte) | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |

## `whoosh-service` — Whoosh application service

| Field | Value | Source |
|---|---|---|
| Platform owner | `brandon` | `PRD_DELIVERY_MAP.md` |
| Tenant or client | `whoosh` | `PRD_DELIVERY_MAP.md` |
| Brand or domain | UNKNOWN | n/a |
| Current host | `whoosh-runtime` (unknown coordinates) | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| Intended host | UNKNOWN | n/a |
| Runtime | UNKNOWN | n/a |
| Allowed actions | `read` | n/a |
| Status | `BLOCKED` — `COORDINATES_MISSING` | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | `BR-AUD-004` is `BLOCKED_BY_DEPENDENCY`; do not claim live placement | `PRD_DELIVERY_MAP.md` unresolved area 1 |

## `hd2ai-edge` — HD2.ai edge site

| Field | Value | Source |
|---|---|---|
| Platform owner | `deightonllm` | `AGENTS.md` Management URL map |
| Tenant or client | `hd2` | `AGENTS.md` Management URL map |
| Brand or domain | `hd2.ai` | `AGENTS.md` Management URL map |
| Current host | `srv797124` | `AGENTS.md` Hostinger note |
| Intended host | `srv797124` | `AGENTS.md` Hostinger note |
| Runtime | UNKNOWN (live WordPress site) | `AGENTS.md` |
| Allowed actions | `read` | n/a |
| Status | `KNOWN` (live WordPress site) | `AGENTS.md` Management URL map |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Distinct from HD2Stack `vmi3238503` | `AGENTS.md` Hostinger note |

---

## Out-of-scope services

The following service classes are explicitly NOT in this catalog:

- Live provider API keys, model download endpoints, or remote worker
  credentials — only references in cited reports.
- SaaS customer data stores (lawyer leads, music metrics) — references
  only; no data motion.
- Production deployment pipelines that have not been accepted in cited
  reports.

When a new accepted evidence lands, append a new section here and a new
record in `service_catalog.yaml` in the same change.
