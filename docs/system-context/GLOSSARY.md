# System-Context Warehouse — Glossary

Plain-language definitions for terms used in the warehouse. Each definition
is bound to a source. If a term is not yet sourced, it is marked `UNSOURCED`
and must not be used in a `KNOWN` record.

## Hosts and tiers

| Term | Definition | Source |
|---|---|---|
| **HD2 in-house** | The HD2/Contabo infrastructure stack: the controller 1Panel host, the HD2stack 1Panel host, and the HD2.ai edge host. Operated under `panel.dubzai.com`, `dash.hd2.ai/hd2secure`, and `hd2.ai`. | `AGENTS.md` Management URL map |
| **Brandon legacy VPS** | The AminoVPS host `srv1137994-aminolifesciences` (alias `animovps`), originally used as Elevate / Brandon edge. Predates the PRD-v3 tier model. | `BR-INV-001/report.md` §Host 1 |
| **Brandon hub** | The provisioned Hostinger hub `srv1856614` (alias `brandon-hub`, public `2.25.197.26`) for Brandon's staged OnePanel/OpenResty and private platform services. Contabo HD2Stack `vmi3238503` is HD2 in-house and is not a Brandon service target. | `BRANDON_CAMPAIGN_CONTROL.md` §§2, 4; `BRANDON_HUB_SERVICE_MATRIX.md` §1 |
| **KVM1 Hostinger** | The Hostinger node hosting `hd2.ai` (canonical Hostinger hostname `srv797124`, alias `srv797124-hd2`). Used as HD2.ai edge/review host. | `AGENTS.md` Hostinger note |
| **Hetzner compute** | The provisioned Hetzner AX42-2 dedicated server `#3027423` / `HEL1-DC9`, canonical hostname and SSH alias `brandon-compute`, Tailscale `100.106.6.22`, public `157.180.99.39`. Current re-verification is temporarily blocked by the Tailscale interactive re-auth gate. | `BR-HERDR-HETZNER-ROUTE-001/agy-route-repair.md` §§1–7; `BR-COMPUTE-LLM-001/m3-runtime-preparation.md` §§1–2 |
| **Brandon compute runtime** | The private `brandon-compute` runner for llama.cpp/Qwen3.8:27B and bounded model/benchmark work; it is distinct from Hostinger hub `srv1856614`. | `PRD_DELIVERY_MAP.md` BR-COMPUTE-LLM-001; `BRANDON_VPS_COMPUTE_ROUTING_CONTRACT.md` |
| **Controller** | The local host (this machine) running FirstMate tooling, agents, and orchestration. | `AGENTS.md` |

## Services and platforms

| Term | Definition | Source |
|---|---|---|
| **AnythingLLM** | Historical inventory associates the HD2 instance and `llm.hd2.ai` with HD2Stack, but current DNS/origin is not verified. A separate Brandon instance is named by Hub task 9 and targeted to `srv1856614`; the product name itself is not in canonical PRD v3. Do not infer shared ownership or project isolation. | `BRANDON_HUB_COMPONENT_INVENTORY.md`; `BRANDON_HUB_TASKS.md` task 9; `WAREHOUSE_BOUNDARIES.md` |
| **LiteLLM** | Brandon Hub staging gateway installed on Hostinger `srv1856614` under BR-HUB-006 with placeholder keys; an older controller-host instance is separately recorded and not reconciled as a client service. | `BR-HUB-006` stage 2–4 evidence; `BRANDON_HUB_SERVICE_MATRIX.md` §3.4 |
| **Mattermost** | Service referenced by audit work; instance ownership and brand/domain relationship are **explicitly unresolved** in current evidence. | `PRD_DELIVERY_MAP.md` unresolved area 4 (cross-reference) |
| **Jitsi** | Service referenced by audit work; instance ownership and brand/domain relationship are **explicitly unresolved** in current evidence. | `PRD_DELIVERY_MAP.md` unresolved area 4 (cross-reference) |
| **Percona MySQL** | MySQL variant deployed on AminoVPS (Core-Distro production database). Version `8.4.10-10`. | `BR-INV-001/report.md` §Host 1 |
| **Qdrant** | A staged Qdrant instance was installed on Hostinger `srv1856614`; PRD v3 §§6.1 and 7.2 place Qdrant and temporary work data on Hetzner `brandon-compute`. Project collection isolation and AnythingLLM's backend remain unresolved. | `BR-HUB-006` stage 2–4 evidence; canonical PRD v3 §§6.1, 7.2; `BRANDON_HUB_SERVICE_MATRIX.md` §3.6 |
| **OpenResty/OnePanel** | Brandon Hub reverse proxy and panel on Hostinger `srv1856614`; not the HD2Stack `vmi3238503` proxy. DNS/TLS and public app cutover remain gated. | `BR-HUB-006` stage 2–4 evidence; `BRANDON_CAMPAIGN_CONTROL.md` |
| **cbd-worker.service** | CBD-Data worker systemd service running on AminoVPS. | `BR-INV-001/report.md` §Host 1 |

## Projects

| Term | Definition | Source |
|---|---|---|
| **Elevate Life Sci** | Brandon project delivering the ElevateSci customer-facing site and dashboard. Live apex/www site plus `agents.elevatesci.com` dashboard. | `PRD_DELIVERY_MAP.md` |
| **Core Distro** | Brandon project at `projects/core-distro.com/` with PHP production and Next.js staging. | `PRD_DELIVERY_MAP.md` |
| **CBD-Data** | Brandon project at `projects/cbd-data.com/` with scraping, enrichment, queue, export, storage. | `PRD_DELIVERY_MAP.md` |
| **Whoosh** | Brandon project; exact repository, hosting, runtime, and production IP are missing. | `PRD_DELIVERY_MAP.md` unresolved area 1 |
| **HD2.ai** | Live WordPress site on Hostinger `srv797124`. Distinct from HD2Stack. | `AGENTS.md` Management URL map |

## Operational classes

| Term | Definition | Source |
|---|---|---|
| **ALLOWED_ACTIONS** | Pre-flight action allowlist for a service: read / local-build / mock-test / staging-deploy / production-deploy / live-mutate. | `SCHEMA.md` |
| **RAW_HERDR_SENPI** | Legacy compatibility marker for an explicitly selected raw-Senpi lane. It is inactive by default, never inferred from an unknown pane, and never overrides the current Pi/GLM route. | `/root/docs/agent-policy/HERDR_AGENT_ROUTING.md` |
| **EVIDENCED** | PRD status meaning working software/runtime evidence exists but PRD-wide acceptance is not proven. Distinct from `DELIVERED`. | `SCHEMA.md` |

## Unsourced terms

The following terms are intentionally not yet defined because no current
source supports a stable definition. They must NOT appear in a `KNOWN` record:

- `bdn-edge-01` (proposed PRD-v3 hostname; not a documented live hostname)
- `bdn-compute-01` (proposed PRD-v3 rename; no evidence)
- `brandon-prod` (PRD-v3 proposed existing name; no evidence)
- Specific provider accounts for live off-host DR (Namecheap assignments per project)

If a future source grounds one of these terms, add it here with its source
and re-run the preflight.
