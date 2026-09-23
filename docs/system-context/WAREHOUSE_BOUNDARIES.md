# Warehouse Boundaries: HD2 System and Client Data

**Purpose:** define where operational knowledge and client documents belong.
This is a documentation and data-boundary rule; it does not provision a
warehouse, move documents, or authorize service deployment.

## Target model

Maintain one HD2 system/control warehouse and one separately governed
warehouse per client or project. The client side is not a shared bucket.

```text
HD2 system/control warehouse
  - HD2 hosts, services, security posture, and sanitized cross-project status
  - minimal references to client-owned systems and accepted evidence
  - no raw client documents, datasets, prompts, transcripts, embeddings, or keys

Client/project warehouses (separate access, storage, and recovery boundaries)
  - Core Distro
  - Elevate
  - Whoosh
  - CBD-Data
  - any later client or project
```

Brandon is the owner of four projects, not a reason to merge their data.
PRD v3 §§2 and 11.5 require the four projects to be treated as separate
tenants. Each request, job, file, queue message, database connection, log
event, and backup manifest must carry a project identity; a missing identity
is an error, not a shared default.

## Current state in the source of truth

| Area | What is evidenced | What is not evidenced |
|---|---|---|
| System Context warehouse | A central metadata catalog exists at `docs/system-context`; FirstMate `data/` is private controller state. | Neither is an isolated document warehouse for a client. Current controller records span multiple projects. |
| Core Distro and CBD-Data | Separate project source trees are recorded in the Brandon delivery map. | Separate document-store permissions, backup keys, retention, and restore acceptance are not proven by separate source trees alone. |
| Elevate and Whoosh | Both appear in the Brandon portfolio records. | A separately verified document warehouse per project is not identified here; Whoosh's repo/host coordinates remain incomplete. |
| Brandon campaign workspace | `BRANDON REWORK` holds multi-project planning and evidence. | It is not a client document warehouse or a place to merge customer datasets. |
| HD2 AnythingLLM | Historical inventory associates the HD2 AnythingLLM instance and `llm.hd2.ai` with Contabo `vmi3238503`, using Docker Compose and named volumes. | This review did not live-check the service, DNS, or origin; client/workspace assignments, vector backend, and per-client isolation are unproven. |

A separate source repository is useful organization, but it is not by itself
a security boundary. A client warehouse is not considered isolated until its
owner, storage root, access controls, recovery scope, and negative cross-tenant
tests are evidenced.

## AnythingLLM placement for Brandon

The canonical PRD v3 does not name the AnythingLLM product. It places
customer-facing applications and the control plane on the Hostinger KVM8
(§7.1), while the Hetzner server is the compute plane for scraping,
enrichment, AI execution, background work, and temporary processing data
(§7.2). The separate Brandon Hub task queue names AnythingLLM as a future
platform dependency, and the hub service matrix identifies Hostinger
`srv1856614` as its target.

| Instance | Source-backed placement | Safe interpretation |
|---|---|---|
| Existing HD2 AnythingLLM | Historical inventory associates `llm.hd2.ai` with HD2Stack/Contabo `vmi3238503`; current DNS/origin is not verified | Existing HD2 service record; not evidence of a Brandon instance or per-client isolation. Do not route client apps or place Brandon documents there by inference. |
| Brandon AnythingLLM | Target: Hostinger KVM8 `srv1856614` | No Brandon AnythingLLM deployment is evidenced. The target is not cut over or ready for customer documents. |
| Brandon compute/model runtime | Hetzner `brandon-compute` | Compute/worker plane, not the documented user-facing AnythingLLM host. Any gateway integration remains separately gated. |

The operator's routing constraint is that no app should resolve to HD2Stack.
The 2026-09-19 Elevate route-containment report verifies one specific Nginx
vhost has no HD2Stack upstream and returns `503` for its API path. It did not
verify DNS, and it must not be generalized to other domains. The old HD2
AnythingLLM inventory is a host association, not proof of the current DNS
target; revalidate its origin before relying on it.

The Brandon Hub queue places application deployment after a restore rehearsal
and an approved secret store. `BR-HUB-010` still requires backup provider/account,
encryption and key custody, retention, RPO/RTO, and live restore proof. A
production secret-store pointer and DNS/TLS approval are also absent. No
credential, backend, vector store, DNS record, backup, deployment, or migration
was changed by this documentation update.

Before a Brandon instance receives documents, record whether each project will
use a separate instance or a demonstrably isolated workspace/collection.
Verify authentication and authorization, retrieval boundaries, embedding
backend, vector-store scope, backups, deletion, and restore behavior per
project. Workspace names alone do not prove isolation.

## Operating rule

System records may contain a client/project identifier, classification, owner,
status, freshness, and a pointer to approved evidence. They must not replicate
the client's document corpus or secrets. Keep client prompts, source documents,
embeddings, exports, and transcripts in their own access-controlled store.

When a per-client root or evidence artifact is missing, record it as unknown
and stop any move, indexing, or cross-tenant service assignment. Do not invent
a warehouse path to make the catalog appear complete.

## Related

- [System Context index](INDEX.md)
- [Client warehouse onboarding](CLIENT_WAREHOUSE_ONBOARDING.md)
- [Canonical Brandon V3 PRD](BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md)
- [Service catalog](SERVICE_CATALOG.md)
