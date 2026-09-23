# System-Context Warehouse — HOSTS

Human-readable authority for every host record in `hosts.yaml`. This file is
grounded only in cited warehouse and accepted campaign evidence. Unknown fields are explicit
`UNKNOWN` placeholders. The Markdown is the source of truth; YAML is the
machine-readable mirror.

> **Do not invent coordinates.** If a host has no documented public IP,
> SSH path, hostname, or runtime, the field is `UNKNOWN` and the record
> status reflects that. Live probing is out of scope for this warehouse.

## Tier definitions (from `GLOSSARY.md`)

- `HD2_IN_HOUSE` — HD2/Contabo infrastructure (controller, HD2stack, HD2.ai).
- `BRANDON_LEGACY_VPS` — AminoVPS / Elevate legacy VPS.
- `BRANDON_HUB` — Brandon hub host.
- `KVM1_HOSTINGER` — KVM1 Hostinger node (`srv797124`, alias `srv797124-hd2`).
- `HETZNER_COMPUTE` — Hetzner compute plane.
- `LOCAL` — Local controller context.

---

## `controller` — Local controller host

| Field | Value | Source |
|---|---|---|
| Tier | `LOCAL` | `AGENTS.md` |
| Provider | `local` | n/a |
| Canonical hostname | local controller host (this machine) | `AGENTS.md` |
| Tailscale IP | UNKNOWN — controller Tailscale identity not surfaced in cited reports | n/a |
| Public IP | UNKNOWN — controller public IP not surfaced in cited reports | n/a |
| Role | Controller; runs FirstMate tooling, agents, and orchestration | `AGENTS.md` |
| Tenants | (none — tooling host) | n/a |
| Status | `KNOWN` | n/a |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | This warehouse lives on the controller. It is not a service host. | n/a |

## `controller-panel` — Contabo 1Panel entrypoint `vmi3196300`

| Field | Value | Source |
|---|---|---|
| Tier | `HD2_IN_HOUSE` | `AGENTS.md` Management URL map |
| Provider | Contabo | `AGENTS.md` Management URL map |
| Canonical hostname | `vmi3196300` (Contabo internal id) | `AGENTS.md` Management URL map |
| Public alias | `https://panel.dubzai.com` | `AGENTS.md` Management URL map |
| Backend port | `14200` (1Panel internal) | `AGENTS.md` Management URL map |
| Role | Controller 1Panel host; entrypoint for `panel.dubzai.com` | `AGENTS.md` Management URL map |
| Tenants | (controller tooling) | n/a |
| Status | `KNOWN` | n/a |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |

## `hd2stack` — Contabo host `vmi3238503` (HD2 in-house)

| Field | Value | Source |
|---|---|---|
| Tier | `HD2_IN_HOUSE` | `AGENTS.md` Management URL map; `BRANDON_CAMPAIGN_CONTROL.md` §2 |
| Provider | Contabo | `AGENTS.md` Management URL map |
| Canonical hostname | `vmi3238503` | `AGENTS.md` Management URL map |
| Public aliases | `https://dash.hd2.ai/hd2secure`; `https://hd2stack.dubzai.com/hd2secure` | `AGENTS.md` Management URL map |
| Origin port | `31381` (1Panel) | `AGENTS.md` Management URL map |
| Tailscale IP | `100.71.95.76` (per mini-sprint report) | `MINI_SPRINT_PREPARATION_REPORT.md` §4 |
| Role | HD2stack 1Panel entrypoint and HD2 in-house host; historical inventory also places an HD2 AnythingLLM instance here, but current service/DNS origin is not verified | `AGENTS.md`; `BRANDON_HUB_COMPONENT_INVENTORY.md` |
| Tenants | `hd2` | `AGENTS.md`; `BRANDON_CAMPAIGN_CONTROL.md` §2 |
| Status | `KNOWN` | n/a |
| Last verified | 2026-09-19 | `BR-CAPACITY-HD2-001` latest read-only placement audit |
| Freshness days | 30 | n/a |
| Notes | A later read-only placement audit recorded 79% disk and blocked Brandon placement; do not use this shared HD2 host for Brandon services | `BRANDON_CAMPAIGN_CONTROL.md` §4; `BR-CAPACITY-HD2-001` |

## `srv797124` — Hostinger HD2.ai edge/review host

| Field | Value | Source |
|---|---|---|
| Tier | `KVM1_HOSTINGER` | `AGENTS.md` Hostinger note |
| Provider | Hostinger | `AGENTS.md` Hostinger note |
| Canonical hostname | `srv797124`; operator alias `srv797124-hd2` | `AGENTS.md` Hostinger note |
| Public IP | `100.92.152.109` | `AGENTS.md` Hostinger note |
| Role | HD2.ai edge/review host; live WordPress site at `hd2.ai` | `AGENTS.md` Management URL map |
| Tenants | `hd2` | `AGENTS.md` Management URL map |
| Status | `KNOWN` | n/a |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | Distinct from HD2Stack `vmi3238503`; the operator alias and canonical hostname both refer to this node only | `AGENTS.md` Hostinger note |

## `srv1137994-aminolifesciences` — Brandon legacy VPS (AminoVPS)

| Field | Value | Source |
|---|---|---|
| Tier | `BRANDON_LEGACY_VPS` | `BR-INV-001/report.md` §Host 1 |
| Provider | Hostinger (KVM8 per PRD v3 §7.1) | `BR-INV-001/report.md` §Host 1 |
| Canonical hostname | `srv1137994-aminolifesciences`; alias `animovps` | `BR-INV-001/report.md` §Host 1 |
| Tailscale IP | `100.69.211.43` | `BR-INV-001/report.md` §Host 1 |
| Public IP | UNKNOWN — not surfaced in workspace | `BR-INV-001/report.md` §Host 1 |
| SSH path | `tailscale ssh animovps` (documented); Tailscale target `100.69.211.43` | `BR-INV-001/report.md` §Host 1 |
| Role | Brandon edge/control plane per PRD v3 §7.1; current tenant: staging + worker + production port reservations | `BR-INV-001/report.md` §Host 1 |
| Tenants | `core-distro` (staging), `cbd-data` (worker) | `BR-INV-001/report.md` §Host 1 |
| Runtime | Docker `29.1.3`, Percona MySQL `8.4.10-10`, PHP CLI `8.4.22`, Node.js `v22.19.0`, Python `3.12.3`, Composer `2.8.12`, Nginx | `BR-INV-001/report.md` §Host 1 |
| Status | `PARTIAL` — runtime versions documented; OS/CPU/RAM/disk/firewall/backup posture not documented | `BR-INV-001/report.md` §Host 1 |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |
| Notes | PRD-v3 proposed rename `bdn-edge-01` is not in evidence; hostname drift is out of Phase 0 scope | `BR-INV-001/report.md` §Host 1 |

## `srv1856614` — Brandon hub host

| Field | Value | Source |
|---|---|---|
| Tier | `BRANDON_HUB` | `BRANDON_HUB_SERVICE_MATRIX.md` §1 |
| Provider | Hostinger KVM8 | `BRANDON_HUB_SERVICE_MATRIX.md` §1; `BRANDON_CAMPAIGN_MANIFEST.tsv` BR-INFRA-001 |
| Canonical hostname | `srv1856614`; alias `brandon-hub` | `BRANDON_HUB_SERVICE_MATRIX.md` §1 |
| Tailscale IP | `100.86.247.105` | `three-vps-eligibility-m3.md` §4.5 |
| Public IP | `2.25.197.26` | `BRANDON_HUB_SERVICE_MATRIX.md` §1 |
| Role | Brandon client hub for staged OnePanel/OpenResty, PostgreSQL, Redis, Qdrant, and LiteLLM services; application deployment remains separately gated | `BRANDON_HUB_SERVICE_MATRIX.md` §§1, 3; `BRANDON_CAMPAIGN_CONTROL.md` §§2, 4 |
| Tenants | `brandon-hub` | `BRANDON_HUB_SERVICE_MATRIX.md` §1 |
| Status | `PARTIAL` — provisioned/hardened; application cutover and provider snapshot/backup details remain gated | `BRANDON_HUB_BACKUP_DECISION.md` §§1–2 |
| Last verified | 2026-09-19 | source review of `BRANDON_HUB_SERVICE_MATRIX.md` and campaign control |
| Freshness days | 30 | n/a |
| Notes | This is the only live target used by the current BR-HUB campaign and is distinct from HD2Stack `vmi3238503` and Hetzner `brandon-compute`; backup/restore, secret-store, app, and DNS/TLS gates remain open. | `BRANDON_CAMPAIGN_CONTROL.md` §§2, 5 |

## `brandon-compute` — Hetzner dedicated compute plane (alias `hetzner-compute`)

| Field | Value | Source |
|---|---|---|
| Tier | `HETZNER_COMPUTE` | `BRANDON_VPS_COMPUTE_ROUTING_CONTRACT.md` |
| Provider | Hetzner | `agy-route-repair.md` §§1–2; `m3-runtime-preparation.md` §2 |
| Asset / datacenter | AX42-2 dedicated server `#3027423`, HEL1-DC9 | `agy-route-repair.md` §1 |
| Canonical hostname | `brandon-compute`; alias `hetzner-compute` | `agy-route-repair.md` §1; `/root/.ssh/config` |
| Tailscale IP | `100.106.6.22` | `agy-route-repair.md` §1; `m3-runtime-preparation.md` §1 |
| Public IP | `157.180.99.39` | `agy-route-repair.md` §1; `m3-runtime-preparation.md` §1 |
| SSH path | `brandon-compute` as `hd2admin`, key-only over Tailscale | `m3-runtime-preparation.md` §1; `/root/.ssh/config` |
| Role | Compute plane for Brandon local LLM/model testing, benchmarks, scraping, enrichment, Qdrant, and bounded worker preparation | `BRANDON_VPS_COMPUTE_ROUTING_CONTRACT.md`; `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` §§6.1, 7.2 |
| Tenants | `brandon-compute` only | `BRANDON_VPS_COMPUTE_ROUTING_CONTRACT.md` |
| Status | `PARTIAL` — coordinates and prior route/capacity/runtime evidence are accepted; current live re-verification is blocked by Tailscale interactive re-auth | `BR-COMPUTE-PLACEMENT-RECHECK-20260918/report.md`; `BRANDON_CAMPAIGN_CONTROL.md` §2 |
| Last verified | 2026-09-18 | `BR-COMPUTE-PLACEMENT-RECHECK-20260918/report.md` |
| Freshness days | 30 | n/a |
| Notes | Do not conflate this verified Hetzner host with Hostinger hub `srv1856614`; the historical BR-INV-001 “zero references” wording is stale. | `BRANDON_VPS_COMPUTE_ROUTING_CONTRACT.md`; `BR-INV-001` correction |

## `whoosh-runtime` — Whoosh project host

| Field | Value | Source |
|---|---|---|
| Tier | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| Provider | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| Canonical hostname | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| Tailscale IP | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| Public IP | UNKNOWN | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| Role | Whoosh project production host | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| Tenants | `whoosh` | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| Status | `BLOCKED` — `COORDINATES_MISSING` | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| Last verified | 2026-09-12 | `m3-route-review.md` §3; `agy-route-repair.md` §7 |
| Freshness days | 30 | n/a |
| Notes | `BR-AUD-004` is `BLOCKED_BY_DEPENDENCY`; exact repository, hosting, runtime, and production IP required | `PRD_DELIVERY_MAP.md` unresolved area 1 |

## SaaS-retained evidence hosts (read-only, write-locked)

| Field | Value | Source |
|---|---|---|
| Tier | n/a (not infrastructure; evidence retention only) | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Provider | n/a | n/a |
| Canonical hostname | n/a | n/a |
| Role | Five exact duplicate PHP file pairs preserved byte-for-byte under `agent-work` evidence; Music Metrics write-locked | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Tenants | `music-metrics` (write-locked), `lawyer` (read-only), `core-distro`/`elevate`/`cbd-data` retained | `MINI_SPRINT_PREPARATION_REPORT.md` §5 |
| Status | `KNOWN` (preserved evidence) | n/a |
| Last verified | 2026-09-15 | n/a |
| Freshness days | 30 | n/a |

---

## Out-of-scope hosts

The following host classes are explicitly NOT in this warehouse:

- Live SSH endpoints not yet evidenced in cited reports.
- Namecheap DR target accounts (`server401`, `business186`, `business125-5`,
  `hd2data`) — listed as general-purpose HD2Stack accounts; per-project DR
  assignment per PRD v3 is not evidenced and remains an open operator
  decision (`MINI_SPRINT_PREPARATION_REPORT.md` §4).

When new evidence is accepted, append a new section here and a new record in
`hosts.yaml` in the same change.
