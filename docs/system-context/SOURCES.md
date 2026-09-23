# System-Context Warehouse — Source Inventory

This file lists the source artifacts that ground the warehouse records. Every
record in `hosts.yaml`, `service_catalog.yaml`, and `prd_traceability.yaml`
must cite at least one entry from this list (or its `data/...` subdirectory).

The list is intentionally bounded: only artifacts already in the warehouse or
the accepted campaign evidence under `/root/agent-work/BRANDON REWORK/` are
listed. A record that needs a new source must add the source here and re-run the
preflight.

## Authoritative reports and evidence

| Source | Path | Used for |
|---|---|---|
| Brandon Multi-Project Infrastructure PRD v3.0 (canonical warehouse copy) | `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` | Approved architecture direction, project scope, placement, rollout gates, security, DR, agent responsibilities, and acceptance criteria |
| Brandon PRD delivery map | `data/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md` | PRD traceability, project status, host tier roles |
| Brandon software lanes | `data/prd-delivery-plan-20260914/SOFTWARE_LANES.md` | Lane status, dependency order, allowed actions |
| Brandon server inventory | `data/BR-INV-001/report.md` | AminoVPS facts plus corrected reconciliation of the accepted Hetzner record |
| Brandon compute routing contract | `/root/agent-work/BRANDON REWORK/BRANDON_VPS_COMPUTE_ROUTING_CONTRACT.md` | Binding separation of Hostinger/Elevate, Hetzner Brandon Compute, controller, and protected client scopes |
| Hetzner route evidence | `/root/agent-work/BRANDON REWORK/evidence/BR-HERDR-HETZNER-ROUTE-001/agy-route-repair.md` | Hetzner asset, host coordinates, route classifier, prior read-only capacity probe, and regression evidence |
| Brandon compute runtime registration and handoff | `/root/agent-work/BRANDON REWORK/evidence/BR-COMPUTE-LLM-001/brandon-compute-runtime-registration-20260922.md` | Registered Hetzner role, `/opt/brandon` canonical-source gate, Ollama containment ruling, and required live evidence packet |
| Hetzner placement recheck | `/root/agent-work/BRANDON REWORK/evidence/BR-COMPUTE-PLACEMENT-RECHECK-20260918/report.md` | 2026-09-18 read-only Hetzner/HD2Stack placement reconciliation; records Tailscale re-auth blocker and private compute boundary |
| Brandon hub service matrix | `/root/agent-work/BRANDON REWORK/BRANDON_HUB_SERVICE_MATRIX.md` | Hostinger `srv1856614` hub identity, service-specific target placements, and Qdrant compute-plane direction |
| BR-HUB-006 Stage 2–4 evidence | `/root/agent-work/BRANDON REWORK/evidence/BR-HUB-006/stage2-4-migration.md` | Accepted installation evidence for OpenResty, PostgreSQL, Redis, Qdrant, and LiteLLM on Hostinger `srv1856614` |
| Brandon hub task queue | `/root/agent-work/BRANDON REWORK/BRANDON_HUB_TASKS.md` | Application deployment dependencies, including AnythingLLM task 9 and backup/secret-store gates |
| Brandon campaign control | `/root/agent-work/BRANDON REWORK/BRANDON_CAMPAIGN_CONTROL.md` | Current host ownership boundary, accepted work, remaining gates, and no-client-work-on-HD2 rule |
| Brandon component inventory | `/root/agent-work/BRANDON REWORK/BRANDON_HUB_COMPONENT_INVENTORY.md` | Existing HD2 AnythingLLM inventory and distinction from the not-yet-deployed Brandon instance |
| Brandon hub backup decision | `/root/agent-work/BRANDON REWORK/BRANDON_HUB_BACKUP_DECISION.md` | Hostinger hub owner/continuity and unapproved backup, restore, key-custody, retention, RPO/RTO gates |
| HD2Stack placement/capacity audit | `/root/agent-work/BRANDON REWORK/evidence/BR-COMPUTE-LLM-001/hd2stack-capacity.md` | Read-only HD2Stack capacity snapshot and Brandon placement block |
| Elevate Nginx route containment | `docs/system-context/ELEVATE_NGINX_ROUTE_20260919.md` | Accepted 2026-09-19 route evidence: dashboard/API behavior, no HD2Stack upstream, and scoped rollback |
| CBD worker canary | `data/cbd-worker-canary/report.md` | `cbd-worker.service` runtime, AminoVPS placement |
| Core-Distro audit | `data/BR-AUD-002/report.md` | Core-Distro PHP production, Next.js staging, MySQL/Percona |
| CBD-Data audit | `data/BR-AUD-005/report.md` | CBD-Data scraping/enrichment/queue/export discovery |
| Mini-sprint prep report | `data/overnight-control-security-20260914/MINI_SPRINT_PREPARATION_REPORT.md` | SaaS evidence inventory, host tier roles, capacity classification |
| Footer-context fix report | `data/footer-context-fix-20260914/REPORT.md` | Footer interpretation, harness facts |
| Controller-context application | `data/controller-context-application-20260811/brief.md` | Controller scope guidance |

## Repository-level authorities

| Source | Path | Used for |
|---|---|---|
| Repository agents policy | `AGENTS.md` | Management URL map, subagent caps, current Pi/GLM routing; raw Senpi is legacy opt-in |
| First Mate scripts directory | `bin/fm-*.sh` | FirstMate tooling context, no service facts |
| Docs directory | `docs/` | Documentation contract references |
| Project source folders | `projects/core-distro.com/`, `projects/cbd-data.com/` | Project ownership evidence (read-only) |

## Evidence path boundary

`evidence_paths` are repository-relative paths that must resolve inside
`/root/agent-work/deightonllm-firstmate`. Sibling-workspace files and archived
campaign artifacts may be named in `sources` only, with their external status
clear; never use absolute paths or `../` in `evidence_paths`.

## Out-of-scope source classes

These classes are NOT used to ground a record:

- Live SSH, Tailscale, DNS/TLS, Docker, database, systemd, firewall, or
  secret contents — only summaries already present in the cited reports.
- Remote host credential files, agent session JSONL transcripts, gbrain
  indices — the warehouse references summaries, not raw bodies.
- Speculative or operator-aspirational facts not present in any cited report.

## Provenance note (recorded)

The canonical v3 PRD is now present at
`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` and is
the warehouse source for the PRD itself. The preserved session read at
`/root/pi-recovery-snapshot-20260805T233406Z/agent/sessions/--root-agent-work--/2026-08-05T05-30-31-432Z_019fd066-e288-7afb-be7a-5e3cf9943422.jsonl`
and `PRD_DELIVERY_MAP.md` retain historical provenance for earlier status
records. The original historical Git blob remains absent, so exact-byte
history is still an open limitation; it does not prevent agents from finding
the canonical PRD in this warehouse.
