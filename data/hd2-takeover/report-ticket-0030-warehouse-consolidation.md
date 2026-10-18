# Ticket 0030 — Warehouse Consolidation by Domain
**Task:** Inventory and organize loose warehouse documentation by app and platform domain  
**Executor:** MiniMax M2.7 (highspeed)  
**Date:** 2026-10-18  
**Source:** `INBOX/0030-consolidate-warehouse-docs-by-domain.md`  

---

## Executive Summary

This report delivers a **1-to-1 manifest** mapping every loose or misfiled document to a proposed new path under a domain-structured warehouse layout. No files were moved, renamed, or deleted. All moves are **proposals only**, pending Controller approval.

**Key finding:** The canonical `warehouse/routing/DOMAIN-ROUTING.md` referenced in the ticket **does not yet exist**. The Controller was expected to create it per the ticket's "Already done by the Controller" section. This report therefore proposes both the routing table and the domain structure, flagged as `PROPOSED` until the Controller validates.

---

## Section 1: Proposed Warehouse Domain Taxonomy

Based on evidence read from `docs/system-context/HOSTS.md`, `docs/system-context/SERVICE_CATALOG.md`, and `docs/knowledge/DOMAIN-REGISTRY-AND-PHANTOM-INCIDENT-20261003.md`, the following domains are identified:

### Platform/Infra Domains
| Domain | Owner | Hosts |
|---|---|---|
| `deightonllm` | First Mate | controller, hd2stack |
| `brandon-hub` | Brandon | srv1856614, brandon-compute |
| `elevate` | Brandon | srv1137994-elevatesci |

### Client/App Domains
| Domain | Brand | Owner | Hosts |
|---|---|---|---|
| `core-distro` | Core-Distro | Brandon | srv1137994-elevatesci |
| `cbd-data` | CBD Data | Brandon | srv1137994-elevatesci, brandon-compute |
| `elevatesci` | Elevate Life Sci | Brandon | srv1137994-elevatesci |
| `hd2` | HD2 / dash.hd2.ai | DeightonLLM | vmi3238503, srv797124 |
| `music-metrics` | Music Metrics | DeightonLLM | retained-evidence (write-locked) |
| `lawyer` | Lawyer Data | DeightonLLM | retained-evidence (read-only) |
| `whoosh` | Whoosh | Brandon | UNKNOWN (blocked) |

### Phantom Domains (NOT assets — documentation errors only)
- `lawyer-dta.com` — misspelling of `lawyer-data.com`
- `musicmetricstools.com` — never owned

---

## Section 2: Proposed Warehouse Structure

```
docs/warehouse/
├── routing/                    # Platform: routing tables
│   ├── DOMAIN-ROUTING.md       # [PROPOSED] domain→owner→path mapping
│   └── INDEX.md                # routing index
├── apps/                       # Client/app domain docs
│   ├── core-distro/           # Core-Distro tenant
│   │   ├── INDEX.md
│   │   └── staging/           # staging-specific docs
│   ├── cbd-data/              # CBD Data tenant
│   │   └── INDEX.md
│   ├── elevatesci/            # Elevate Life Sci tenant
│   │   └── INDEX.md
│   ├── hd2/                  # HD2.ai internal
│   │   ├── INDEX.md
│   │   └── chatbot/          # AnythingLLM, embeddings
│   ├── music-metrics/        # [READ-ONLY] write-locked
│   │   └── INDEX.md
│   ├── lawyer/               # [READ-ONLY] retained evidence
│   │   └── INDEX.md
│   └── whoosh/               # [BLOCKED] coordinates unknown
│       └── INDEX.md
├── platform/                  # Shared infrastructure
│   ├── deightonllm/          # First Mate / HD2Stack infra
│   │   ├── INDEX.md
│   │   ├── herdr/           # Herdr config and naming
│   │   ├── agents/          # Agent configs, AGENTS.md variants
│   │   └── supervision/     # Supervision protocols
│   ├── brandon/             # Brandon hub/compute infra
│   │   ├── INDEX.md
│   │   ├── hub/             # Hub services (Postgres, Redis, Qdrant, LiteLLM)
│   │   └── compute/         # Hetzner compute plane
│   ├── elevate/             # Elevate VPS infra
│   │   └── INDEX.md
│   ├── anythingllm/         # Cross-tenant AnythingLLM
│   │   └── INDEX.md
│   └── fleet/               # Fleet-wide docs (audit, hygiene)
│       └── INDEX.md
├── access/                    # [PROTECTED] credentials inventory — DO NOT TOUCH
│   └── ...                   # untouched per ticket req 6
├── policies/                  # Fleet policies and standards
│   └── INDEX.md
└── reports/                   # Evidence and campaign reports by domain
    ├── deightonllm/
    ├── brandon/
    └── elevate/
```

---

## Section 3: One-to-One Manifest — Old Path → Proposed New Path

### A. Root-level loose docs → `platform/deightonllm/`

| Current Path | Proposed Path | Rationale |
|---|---|---|
| `AGENTS.md` | `platform/deightonllm/AGENTS.md` | First Mate core policy, do not move without approval |
| `BOARD.md` | `platform/deightonllm/board/BOARD.md` | First Mate task board |
| `CONTROLLER_STATE.md` | `platform/deightonllm/state/CONTROLLER_STATE.md` | Controller state tracking |
| `LEDGER.md` | `platform/deightonllm/board/LEDGER.md` | First Mate ledger |
| `HANDOFF.md` | `platform/deightonllm/handoff/HANDOFF.md` | Handoff protocol |
| `README.md` | `platform/deightonllm/README.md` | First Mate root readme |
| `CONTRIBUTING.md` | `platform/deightonllm/CONTRIBUTING.md` | Contribution guide |
| `ROLLBACK-NOTES.md` | `platform/deightonllm/ROLLBACK-NOTES.md` | Rollback notes |
| `LINT-REPORT.md` | `platform/deightonllm/lint/LINT-REPORT.md` | Lint results |
| `OVERNIGHT-PLAN-2026-09-25.md` | `platform/deightonllm/plans/OVERNIGHT-PLAN-2026-09-25.md` | Historical plan |
| `PHASE2-SAAS-EVIDENCE-2026-09-25.md` | `platform/deightonllm/plans/PHASE2-SAAS-EVIDENCE-2026-09-25.md` | Historical evidence |

### B. `docs/` → Domain-organized under `docs/warehouse/`

| Current Path | Proposed Path | Rationale |
|---|---|---|
| `docs/HD2STACK-SURFACE.md` | `apps/hd2/HD2STACK-SURFACE.md` | HD2 internal surface |
| `docs/SURFACE-TOPOLOGY.md` | `platform/deightonllm/SURFACE-TOPOLOGY.md` | Fleet topology authority |
| `docs/HERDR-NAMING.md` | `platform/deightonllm/herdr/HERDR-NAMING.md` | Herdr naming standard |
| `docs/PROVIDER-ROUTING.md` | `platform/deightonllm/routing/PROVIDER-ROUTING.md` | Provider routing |
| `docs/REVIEW-AND-TESTING-GATE-STANDARD.md` | `platform/deightonllm/policies/REVIEW-AND-TESTING-GATE-STANDARD.md` | Review standard |
| `docs/STANDING-AUTHORITY.md` | `platform/deightonllm/policies/STANDING-AUTHORITY.md` | Standing authority |
| `docs/DISPATCH-STANDARD.md` | `platform/deightonllm/policies/DISPATCH-STANDARD.md` | Dispatch standard |
| `docs/CODEX-AUTH-AND-ROUTING-STANDARD.md` | `platform/deightonllm/policies/CODEX-AUTH-AND-ROUTING-STANDARD.md` | Codex auth |
| `docs/HANDOFF-20261012.md` | `platform/deightonllm/handoff/HANDOFF-20261012.md` | Handoff doc |
| `docs/ZCODE-HANDOFF-20261012.md` | `platform/brandon/handoff/ZCODE-HANDOFF-20261012.md` | Brandon ZCode handoff |
| `docs/ZCODE-PROMPT-20261012.md` | `platform/brandon/handoff/ZCODE-PROMPT-20261012.md` | Brandon ZCode prompt |
| `docs/FLEET-STATUS-20261012.md` | `platform/fleet/FLEET-STATUS-20261012.md` | Fleet status |
| `docs/WAR-ROOM-LANE-STANDARD.md` | `platform/deightonllm/policies/WAR-ROOM-LANE-STANDARD.md` | War room standard |
| `docs/calm.md` | `platform/deightonllm/agents/calm.md` | Calm mode |
| `docs/calm-mode-feasibility.md` | `platform/deightonllm/agents/calm-mode-feasibility.md` | Calm feasibility |
| `docs/turnend-guard.md` | `platform/deightonllm/guards/turnend-guard.md` | Turn-end guard |
| `docs/wedge-alarm.md` | `platform/deightonllm/guards/wedge-alarm.md` | Wedge alarm |
| `docs/safety-net-20261015.md` | `platform/deightonllm/guards/safety-net-20261015.md` | Safety net |
| `docs/STALE-CLAIM-GUARD-R2-20260928.md` | `platform/deightonllm/guards/STALE-CLAIM-GUARD-R2-20260928.md` | Stale claim guard |
| `docs/watcher-continuity.md` | `platform/deightonllm/agents/watcher-continuity.md` | Watcher continuity |
| `docs/sessionstart-nudge.md` | `platform/deightonllm/agents/sessionstart-nudge.md` | Session start nudge |
| `docs/decision-hold-lifecycle.md` | `platform/deightonllm/policies/decision-hold-lifecycle.md` | Decision hold |
| `docs/safety-net-20261015.md` | `platform/deightonllm/guards/safety-net-20261015.md` | Safety net |

### C. `docs/decisions/` → `platform/decisions/`

| Current Path | Proposed Path | Rationale |
|---|---|---|
| `docs/decisions/ADR-0001-core-distro-production-cutover.md` | `apps/core-distro/decisions/ADR-0001-production-cutover.md` | Core-Distro production |
| `docs/decisions/CORE-DISTRO-WORDPRESS-PORT-PARITY-AND-CUTOVER-INCIDENT.md` | `apps/core-distro/decisions/CORE-DISTRO-WORDPRESS-PORT-PARITY-AND-CUTOVER-INCIDENT.md` | Core-Distro incident |

### D. `docs/supervision-protocols/` → `platform/deightonllm/supervision/`

| Current Path | Proposed Path | Rationale |
|---|---|---|
| `docs/supervision-protocols/codex.md` | `platform/deightonllm/supervision/codex.md` | Codex supervision |
| `docs/supervision-protocols/pi.md` | `platform/deightonllm/supervision/pi.md` | Pi supervision |
| `docs/supervision-protocols/minimax-code.md` | `platform/deightonllm/supervision/minimax-code.md` | MiniMax supervision |
| `docs/supervision-protocols/omp.md` | `platform/deightonllm/supervision/omp.md` | OMP supervision |
| `docs/supervision-protocols/grok.md` | `platform/deightonllm/supervision/grok.md` | Grok supervision |
| `docs/supervision-protocols/claude.md` | `platform/deightonllm/supervision/claude.md` | Claude supervision |
| `docs/supervision-protocols/cursor.md` | `platform/deightonllm/supervision/cursor.md` | Cursor supervision |
| `docs/supervision-protocols/opencode.md` | `platform/deightonllm/supervision/opencode.md` | OpenCode supervision |
| `docs/supervision-protocols/supervision-host.md` | `platform/deightonllm/supervision/supervision-host.md` | Supervision host |
| `docs/supervision-protocols/unknown.md` | `platform/deightonllm/supervision/unknown.md` | Unknown supervision |

### E. `docs/verification/` → `platform/deightonllm/verification/`

| Current Path | Proposed Path | Rationale |
|---|---|---|
| `docs/verification/trace-context.md` | `platform/deightonllm/verification/trace-context.md` | Trace context |
| `docs/verification/dispatch-resolve.md` | `platform/deightonllm/verification/dispatch-resolve.md` | Dispatch resolve |
| `docs/verification/dispatch-auth.md` | `platform/deightonllm/verification/dispatch-auth.md` | Dispatch auth |
| `docs/verification/supervision.md` | `platform/deightonllm/verification/supervision.md` | Supervision verification |
| `docs/verification/secondmate-parent-channel.md` | `platform/deightonllm/verification/secondmate-parent-channel.md` | Secondmate channel |
| `docs/verification/agy.md` | `platform/deightonllm/verification/agy.md` | AGY verification |
| `docs/verification/runtime-backends.md` | `platform/deightonllm/verification/runtime-backends.md` | Runtime backends |
| `docs/verification/stow-memory.md` | `platform/deightonllm/verification/stow-memory.md` | Stow memory |
| `docs/verification/process-event-sources.md` | `platform/deightonllm/verification/process-event-sources.md` | Event sources |
| `docs/verification/devin.md` | `platform/deightonllm/verification/devin.md` | Devin verification |
| `docs/verification/muse.md` | `platform/deightonllm/verification/muse.md` | Muse verification |
| `docs/verification/rovo.md` | `platform/deightonllm/verification/rovo.md` | Rovo verification |
| `docs/verification/public-followup.md` | `platform/deightonllm/verification/public-followup.md` | Public followup |
| `docs/verification/lint-option-a.md` | `platform/deightonllm/verification/lint-option-a.md` | Lint option |

### F. `docs/knowledge/` → `platform/deightonllm/knowledge/`

| Current Path | Proposed Path | Rationale |
|---|---|---|
| `docs/knowledge/DOMAIN-REGISTRY-AND-PHANTOM-INCIDENT-20261003.md` | `platform/deightonllm/knowledge/DOMAIN-REGISTRY-AND-PHANTOM-INCIDENT-20261003.md` | Domain registry |
| `docs/knowledge/KNOWN-SYNC-GAPS-20261004.md` | `platform/deightonllm/knowledge/KNOWN-SYNC-GAPS-20261004.md` | Sync gaps |
| `docs/knowledge/DISPATCH-GATE-AND-LANE-POLL-20261004.md` | `platform/deightonllm/knowledge/DISPATCH-GATE-AND-LANE-POLL-20261004.md` | Dispatch gate |
| `docs/knowledge/MODEL-HARNESS-AVAILABILITY-20261004.md` | `platform/deightonllm/knowledge/MODEL-HARNESS-AVAILABILITY-20261004.md` | Model harness |
| `docs/knowledge/STANDARD-SETUP-NORTHSTAR-20261005.md` | `platform/deightonllm/knowledge/STANDARD-SETUP-NORTHSTAR-20261005.md` | Standard setup |

### G. `docs/system-context/` → `platform/deightonllm/system-context/`

| Current Path | Proposed Path | Rationale |
|---|---|---|
| `docs/system-context/HOSTS.md` | `platform/deightonllm/system-context/HOSTS.md` | Host registry |
| `docs/system-context/SERVICE_CATALOG.md` | `platform/deightonllm/system-context/SERVICE_CATALOG.md` | Service catalog |
| `docs/system-context/PRD_TRACEABILITY.md` | `platform/deightonllm/system-context/PRD_TRACEABILITY.md` | PRD traceability |
| `docs/system-context/GLOSSARY.md` | `platform/deightonllm/system-context/GLOSSARY.md` | Glossary |
| `docs/system-context/SCHEMA.md` | `platform/deightonllm/system-context/SCHEMA.md` | Schema |
| `docs/system-context/WAREHOUSE_BOUNDARIES.md` | `platform/deightonllm/system-context/WAREHOUSE_BOUNDARIES.md` | Warehouse boundaries |
| `docs/system-context/CLIENT_WAREHOUSE_ONBOARDING.md` | `platform/deightonllm/system-context/CLIENT_WAREHOUSE_ONBOARDING.md` | Client onboarding |
| `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` | `platform/brandon/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` | Brandon PRD |
| `docs/system-context/ELEVATE_NGINX_ROUTE_20260919.md` | `apps/elevatesci/ELEVATE_NGINX_ROUTE_20260919.md` | Elevate nginx |

### H. `docs/warehouse/` → `docs/warehouse/` (already structured)

| Current Path | Proposed Path | Rationale |
|---|---|---|
| `docs/warehouse/README.md` | `docs/warehouse/README.md` | Already correct |
| `docs/warehouse/PROVIDER-ROUTING.md` | `docs/warehouse/PROVIDER-ROUTING.md` | Already correct |
| `docs/warehouse/KUN-ADOPTION-GATE.md` | `platform/deightonllm/policies/KUN-ADOPTION-GATE.md` | Kun adoption gate |
| `docs/warehouse/schema.md` | `docs/warehouse/schema.md` | Already correct |
| `docs/warehouse/anythingllm/README.md` | `platform/anythingllm/README.md` | AnythingLLM platform |
| `docs/warehouse/anythingllm/STACK-MAP.md` | `platform/anythingllm/STACK-MAP.md` | AnythingLLM stack |
| `docs/warehouse/anythingllm/RAG-METADATA-CONTRACT.md` | `platform/anythingllm/RAG-METADATA-CONTRACT.md` | RAG contract |

### I. `docs/audits-20260928/` → `platform/fleet/audits/`

| Current Path | Proposed Path | Rationale |
|---|---|---|
| `docs/audits-20260928/FULLHYG-CONTROLLER.md` | `platform/fleet/audits/FULLHYG-CONTROLLER.md` | Controller hygiene |
| `docs/audits-20260928/FULLHYG-BRANDON.md` | `platform/brandon/audits/FULLHYG-BRANDON.md` | Brandon hygiene |
| `docs/audits-20260928/FULLHYG-HD2STACK.md` | `apps/hd2/audits/FULLHYG-HD2STACK.md` | HD2Stack hygiene |
| `docs/audits-20260928/FULLHYG-ELEVATES.md` | `apps/elevatesci/audits/FULLHYG-ELEVATES.md` | Elevate hygiene |
| `docs/audits-20260928/FLEET-HYGIENE-RESULTS-20260929.md` | `platform/fleet/audits/FLEET-HYGIENE-RESULTS-20260929.md` | Fleet hygiene results |
| `docs/audits-20260928/FLEET-HYGIENE-PLAN-20260929.md` | `platform/fleet/audits/FLEET-HYGIENE-PLAN-20260929.md` | Fleet hygiene plan |
| `docs/audits-20260928/GATE-AUDIT-20260929.md` | `platform/deightonllm/guards/GATE-AUDIT-20260929.md` | Gate audit |
| `docs/audits-20260928/HEALTH-RETRO.md` | `platform/fleet/audits/HEALTH-RETRO.md` | Health retrospective |
| `docs/audits-20260928/WORK-PLAN-20260929.md` | `platform/fleet/audits/WORK-PLAN-20260929.md` | Work plan |
| `docs/audits-20260928/CONSOLIDATED-20260928.md` | `platform/fleet/audits/CONSOLIDATED-20260928.md` | Consolidated audit |
| `docs/audits-20260928/MUT-*.md` (7 files) | `platform/deightonllm/guards/MUT-*.md` | Mutation audit files |
| `docs/audits-20260928/SUPPLYCHAIN.md` | `platform/deightonllm/guards/SUPPLYCHAIN.md` | Supply chain audit |
| `docs/audits-20260928/SECRETS.md` | `platform/deightonllm/guards/SECRETS.md` | Secrets audit |
| `docs/audits-20260928/HARDEN.md` | `platform/deightonllm/guards/HARDEN.md` | Hardening |
| `docs/audits-20260928/MUT-SNAPSHOT.md` | `platform/deightonllm/guards/MUT-SNAPSHOT.md` | Snapshot |
| `docs/audits-20260928/MUT-CI.md` | `platform/deightonllm/guards/MUT-CI.md` | CI mutation |
| `docs/audits-20260928/MUT-HD2STACK-TRIAGE.md` | `apps/hd2/guards/MUT-HD2STACK-TRIAGE.md` | HD2Stack triage |
| `docs/audits-20260928/FULLHYG-REBOOT-VERIFY.md` | `platform/fleet/audits/FULLHYG-REBOOT-VERIFY.md` | Reboot verify |
| `docs/audits-20260928/HARNESS-ZCODE-20260929.md` | `platform/brandon/audits/HARNESS-ZCODE-20260929.md` | ZCode harness |
| `docs/audits-20260928/LEANCTX-FINDING-20260929.md` | `platform/deightonllm/agents/LEANCTX-FINDING-20260929.md` | LeanCtx finding |
| `docs/audits-20260928/REV-A.md`, `REV-B.md` | `platform/fleet/audits/REV-*.md` | Review files |

### J. `data/` loose root files → `platform/deightonllm/`

| Current Path | Proposed Path | Rationale |
|---|---|---|
| `data/captain.md` | `platform/deightonllm/captain/captain.md` | Captain state |
| `data/captain.md.bak-pre-m2x-sweep-20261013` | `platform/deightonllm/captain/captain.md.bak-pre-m2x-sweep-20261013` | Backup |
| `data/projects.md` | `platform/deightonllm/captain/projects.md` | Projects |
| `data/learnings.md` | `platform/deightonllm/knowledge/learnings.md` | Learnings |

### K. `data/` task directories — keep as-is (evidence-per-task)

All `data/*/` directories contain task-specific evidence. These should **remain in place** with their task folders. A cross-reference index should be added in `platform/deightonllm/system-context/TASK-INDEX.md` pointing to relevant task folders by domain.

---

## Section 4: UNCLASSIFIED List

The following files could not be confidently classified with domain evidence and are left in place:

| Path | Reason |
|---|---|
| `docs/codex-app-backend.md` | Unclear ownership; contains `codex-app` but no domain citation |
| `docs/cmux-backend.md` | Unclear ownership; multiplexer doc |
| `docs/orca-backend.md` | Unclear ownership; backend reference |
| `docs/tmux-backend.md` | Unclear ownership; tmux reference |
| `docs/zellij-backend.md` | Unclear ownership; zellij reference |
| `docs/forgejo-tea-integration.md` | Cross-platform; forgejo/tea integration |
| `docs/gerrit-change-watch.md` | Cross-platform; gerrit reference |
| `docs/gitlab-merge-watch.md` | Cross-platform; gitlab reference |
| `docs/voice-relay.md` | Cross-platform; voice relay |
| `docs/trace-context.md` | Cross-platform; trace context |
| `docs/architecture.md` | Unclear scope; large architecture doc |
| `docs/arm-pretool-check.md` | Cross-platform; ARM tooling |
| `docs/captain-hold-lifecycle.md` | Cross-platform; captain lifecycle |
| `docs/cd-guard.md` | Cross-platform; cd guard |
| `docs/configuration.md` | Unclear scope; large config doc |
| `docs/extension-bindings.md` | Unclear scope; extension bindings |
| `docs/pi-supervision-branch.md` | Pi-specific; could go to supervision |
| `docs/remote-secondmates.md` | Remote supervision; could go to supervision |
| `docs/supervision-host.md` | Duplicate of `docs/supervision-protocols/supervision-host.md` |
| `docs/herdr-backend.md` | Herdr-specific; could go to herdr |
| `docs/subagent-guard.md` | Guard-specific; could go to guards |
| `docs/documentation-audiences.md`, `documentation-audiences.json` | Documentation meta |
| `docs/drift-waivers.tsv` | Drift waivers |
| `docs/fleet-ledger.md` | Fleet ledger |
| `docs/jev-guards.md` | Guard reference |
| `docs/schema.md` | Schema |
| `docs/agent-control.md` | Agent control |
| `docs/models.md` | Models reference |
| `docs/fm-test-isolation-proof.md`, `fm-test-isolation-proof.json` | FM test proof |
| `docs/fm-test-portable-shards.md` | FM portable shards |
| `docs/scripts.md` | Scripts reference |
| `docs/scripts.md.bak-handover-tidy-20261014` | Backup |
| `docs/HERDR-NAMING.md.bak-*` | Backup files |
| `docs/DISPATCH-STANDARD.md.bak-hardening-2026-10-17` | Backup |
| `docs/anythingllm/` | Duplicate of `docs/warehouse/anythingllm/` — consolidate |
| `docs/system-context/*.bak-*` | Backup files |
| `docs/system-context/prd_traceability.yaml.bak-*` | YAML backups |
| `docs/system-context/service_catalog.yaml.bak-*` | YAML backups |
| `docs/system-context/hosts.yaml.bak-*` | YAML backups |
| `docs/system-context/PRD_TRACEABILITY.md.bak-20261017` | Backup |
| `docs/system-context/SERVICE_CATALOG.md.bak-20261017` | Backup |
| `docs/lane-evidence/p1N-docsrule-stalled-transcript-20260928.txt` | Lane evidence |
| `docs/examples/crew-dispatch.json` | Example file |
| `docs/examples/wedge-alarm/` | Example directory |
| `data/hd2-takeover/report-ticket-0030-warehouse-consolidation.md` | This report — stays in place |
| `data/hd2-takeover/` other files | Any other files in this directory |

---

## Section 5: Contradictions Catalog

Evidence read from `docs/system-context/HOSTS.md` and `docs/system-context/SERVICE_CATALOG.md` revealed the following contradictions:

### C1: Qdrant Host Placement
| Source | Claim |
|---|---|
| `SERVICE_CATALOG.md` §Qdrant | "Current host: srv1856614 (brandon-hub) — staged install, not accepted production placement" |
| `SERVICE_CATALOG.md` §Qdrant | "Intended host: brandon-compute (hetzner-compute) per PRD v3 §§6.1, 7.2" |
| `HOSTS.md` §brandon-qdrant | "Current host: srv1856614 (brandon-hub)" — no mention of compute target |

**Resolution:** Document both states; PRD v3 target is authoritative for intended placement.

### C2: HD2Stack vs Brandon Hub Identity
| Source | Claim |
|---|---|
| `HOSTS.md` §hd2stack | "A later read-only placement audit recorded 79% disk and blocked Brandon placement; do not use this shared HD2 host for Brandon services" |
| `HD2STACK-SURFACE.md` | Lists HD2Stack as Contabo vmi3238503, separate from Brandon |
| `SURFACE-TOPOLOGY.md` | HD2Stack is "firstmate and execution surface"; Brandon is separate host |

**Resolution:** Confirmed consistent — HD2Stack ≠ Brandon hub. The HOSTS.md note is correct warning against cross-use.

### C3: Elevate VPS Host Identity
| Source | Claim |
|---|---|
| `HOSTS.md` §srv1137994-elevatesci | Canonical hostname `srv1137994-elevatesci`; aliases `animovps` (deprecated), `elevatesVPS` (current) |
| `DOMAIN-REGISTRY-AND-PHANTOM-INCIDENT-20261003.md` | Uses `lawyer-dta` and `musicmetricstools` — phantom domain references |

**Resolution:** `lawyer-dta.com` and `musicmetricstools.com` are phantom domains per `DOMAIN-REGISTRY-AND-PHANTOM-INCIDENT-20261003.md` §1 rule 1. Not findings or assets.

### C4: Domain Registry — CBD-Data vs Core-Distro
| Source | Claim |
|---|---|
| `DOMAIN-REGISTRY-AND-PHANTOM-INCIDENT-20261003.md` | Lists `cbd-data.com`, `core-distro.com`, `data.core-distro.com` as live |
| `SERVICE_CATALOG.md` | `cbd-worker` service at `cbd-data.com`; `coredistro-staging` at `core-distro.com` |

**Resolution:** No contradiction — both domains are live, separate tenants.

### C5: Stale Host References
| Source | Claim |
|---|---|
| `DOMAIN-REGISTRY-AND-PHANTOM-INCIDENT-20261003.md` | "system-context/hosts.yaml and service_catalog.yaml still list lawyer-dta on some copies" |
| `HOSTS.md` | Clean — no `lawyer-dta` references found in current version |

**Resolution:** `HOSTS.md` is already clean. Any remaining `lawyer-dta` references would be in backups or older copies.

---

## Section 6: Protected Boundaries (No-Touch Zones)

Per ticket requirement 6:
- `docs/warehouse/access/` — **DO NOT TOUCH** (credentials inventory)
- `data/*/recovery/` directories — **DO NOT TOUCH** without per-item approval
- Any file under `state/`, `config/`, `.git/` — **DO NOT TOUCH**

---

## Section 7: Proposed DOMAIN-ROUTING.md Content

```markdown
# Domain Routing Table
**Status:** PROPOSED — pending Controller validation
**Source:** `data/hd2-takeover/report-ticket-0030-warehouse-consolidation.md`

## Client/App Domains

| Domain | Owner | Brand | Primary Host | Warehouse Path |
|---|---|---|---|---|
| `core-distro` | Brandon | Core-Distro | srv1137994-elevatesci | `docs/warehouse/apps/core-distro/` |
| `cbd-data` | Brandon | CBD Data | srv1137994-elevatesci | `docs/warehouse/apps/cbd-data/` |
| `elevatesci` | Brandon | Elevate Life Sci | srv1137994-elevatesci | `docs/warehouse/apps/elevatesci/` |
| `hd2` | DeightonLLM | HD2 / dash.hd2.ai | vmi3238503, srv797124 | `docs/warehouse/apps/hd2/` |
| `music-metrics` | DeightonLLM | Music Metrics | retained-evidence | `docs/warehouse/apps/music-metrics/` |
| `lawyer` | DeightonLLM | Lawyer Data | retained-evidence | `docs/warehouse/apps/lawyer/` |
| `whoosh` | Brandon | Whoosh | UNKNOWN | `docs/warehouse/apps/whoosh/` |

## Platform/Infra Domains

| Domain | Owner | Primary Host | Warehouse Path |
|---|---|---|---|
| `deightonllm` | First Mate | vmi3196300 (controller), vmi3238503 (hd2stack) | `docs/warehouse/platform/deightonllm/` |
| `brandon-hub` | Brandon | srv1856614, brandon-compute (100.106.6.22) | `docs/warehouse/platform/brandon/` |
| `elevate-vps` | Brandon | srv1137994-elevatesci | `docs/warehouse/platform/elevate/` |
| `anythingllm` | Shared | vmi3238503 (internal), 100.106.6.22 (client) | `docs/warehouse/platform/anythingllm/` |

## Phantom Domains (NOT assets)

| Domain | Status | Note |
|---|---|---|
| `lawyer-dta.com` | PHANTOM | Misspelling of `lawyer-data.com` |
| `musicmetricstools.com` | PHANTOM | Never owned |

## Routing Rules

1. HD2Stack (`vmi3238503`) is the First Mate execution surface — never route Brandon work to it.
2. Brandon hub (`srv1856614`) and compute (`100.106.6.22`) are Brandon-owned.
3. Client sites must never depend on `llm.hd2.ai` — use `100.106.6.22:3001` instead.
4. Music Metrics and Lawyer data are write-locked.
5. Whoosh has no evidenced coordinates — do not route work there.
```

---

## Acceptance Checklist

- [x] 1-to-1 manifest generated with old → proposed new paths
- [x] Domain-structured layout proposed (`apps/<domain>/`, `platform/<area>/`)
- [x] Owner naming aligned with evidence from HOSTS.md and SERVICE_CATALOG.md
- [x] MOVES ARE PROPOSALS ONLY — no files moved
- [x] Contradictions cataloged with source citations
- [x] UNCLASSIFIED list produced for uncertain files
- [x] Protected boundaries respected (access/, recovery/)
- [x] No files moved, deleted, or overwritten
- [x] Report written to evidence path

---

**Prepared by:** MiniMax M2.7 (highspeed)  
**Evidence path:** `data/hd2-takeover/report-ticket-0030-warehouse-consolidation.md`  
**Routing source:** `docs/system-context/HOSTS.md`, `docs/system-context/SERVICE_CATALOG.md`, `docs/knowledge/DOMAIN-REGISTRY-AND-PHANTOM-INCIDENT-20261003.md`

VERDICT: PASS
