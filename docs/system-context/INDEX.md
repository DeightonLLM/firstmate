# System-Context Warehouse — INDEX (entry point)

> **Stop and read this file first.** Every other warehouse document
> defers to this index. If a future agent or tool reads the warehouse in
> the wrong order, treat that as a protocol violation.

## Purpose

The System Context Warehouse is the control-plane index for HD2 operations
and sanitized cross-project status. Before dispatch or mutation, every
controller, worker, reviewer, or auditor must be able to resolve:

- **Host ownership** — who owns a host, what tier it belongs to, and
  whether it is in-house, legacy, hub, edge, or compute.
- **Service ownership** — which platform owns a service, which
  tenant/client it serves, and which brand/domain it represents.
- **Tenant / brand** — which project (Elevate, Core Distro, CBD-Data,
  Whoosh, HD2, Music Metrics, Lawyer) a service belongs to, distinct from
  infrastructure scopes `brandon-hub` and `brandon-compute`.
- **Intended placement** — where the service is supposed to live per
  PRD v3, and where it actually lives today.
- **PRD status** — whether a PRD item is delivered, evidenced,
  in-progress, blocked, or unknown, and what blocks it.

This warehouse is not a client-document or customer-data store. It is
authoritative only for the sanitized facts it cites. Client documents,
datasets, prompts, embeddings, transcripts, exports, and credentials belong
in that client's own warehouse. Keep only the minimum approved pointers and
operational metadata here. See `WAREHOUSE_BOUNDARIES.md`.

The fail-closed preflight `bin/fm-context-preflight.sh` enforces freshness,
schema, repository-local evidence paths, and the absence of secret material
on each machine-readable record.

## Authority and override rules

- **Markdown is the human-readable authority.** Every record exists in a
  `.md` file (`HOSTS.md`, `SERVICE_CATALOG.md`, `PRD_TRACEABILITY.md`).
- **YAML is the machine-readable mirror.** Every `.yaml` file
  (`hosts.yaml`, `service_catalog.yaml`, `prd_traceability.yaml`) is
  generated from and validated against the Markdown. YAML **never**
  overrides the Markdown; when they disagree, the Markdown wins.
- **gbrain may index the warehouse but cannot override it.** Any
  inference or summary produced by gbrain is read-only context; the
  authoritative answer always comes from the Markdown/YAML pair.
- **No record may claim completion without an evidence pointer.** A `KNOWN`
  or `DELIVERED` claim needs a repository-local evidence path that supports
  the specific field; aspirational or stale external pointers alone do not
  qualify.
- **Evidence paths stay inside this repository.** `evidence_paths` must be
  repository-relative and resolve under this repository root. Sibling-workspace
  references may appear in `sources`, clearly marked as external; never use
  absolute paths or `../` in `evidence_paths`.

## File map

| File | Purpose | Read when |
|---|---|---|
| `INDEX.md` (this file) | Mandatory entry point | Always first |
| `SCHEMA.md` | YAML record schema and field semantics | Before editing YAML |
| `SOURCES.md` | Source inventory that grounds records | Before adding evidence |
| `GLOSSARY.md` | Term definitions and unsourced term list | When a term is unfamiliar |
| `WAREHOUSE_BOUNDARIES.md` | System-vs-client data boundary and current AnythingLLM placement | Before moving or indexing client documents |
| `CLIENT_WAREHOUSE_ONBOARDING.md` | Reusable client-warehouse onboarding procedure | Before adding a client/project warehouse |
| `HOSTS.md` + `hosts.yaml` | Host inventory | Resolving host ownership |
| `SERVICE_CATALOG.md` + `service_catalog.yaml` | Service inventory | Resolving service ownership |
| `PRD_TRACEABILITY.md` + `prd_traceability.yaml` | PRD item status and blockers | Resolving PRD status |
| `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` | Canonical Brandon Multi-Project Infrastructure PRD v3.0 | Before Brandon architecture, rollout, or completion decisions |
| `../../bin/fm-context-preflight.sh` | Fail-closed validator (in `bin/`) | Before any lane depends on the warehouse |

The preflight script lives in `bin/fm-context-preflight.sh`. It is the
only safe way to check the warehouse programmatically.

## Tier model (preserve these distinctions)

Do not merge these tiers or invent new ones:

- `HD2_IN_HOUSE` — HD2/Contabo infrastructure (`vmi3196300`,
  `vmi3238503`, `srv797124`).
- `BRANDON_LEGACY_VPS` — Brandon legacy AminoVPS / Elevate legacy VPS
  (`srv1137994-aminolifesciences`).
- `BRANDON_HUB` — Brandon's Hostinger KVM8 hub host (`srv1856614`); distinct from HD2Stack.
- `KVM1_HOSTINGER` — KVM1 Hostinger node (`srv797124`).
- `HETZNER_COMPUTE` — Hetzner compute plane.
- `LOCAL` — Local controller context.

Any host whose tier is not one of these is rejected by the preflight.

## Project and tenant vocabulary (preserve these distinctions)

- `elevate` — Elevate Life Sci
- `core-distro` — Core Distro
- `cbd-data` — CBD-Data
- `whoosh` — Whoosh
- `hd2` — HD2.ai / HD2stack in-house
- `music-metrics` — Music Metrics (write-locked)
- `lawyer` — Lawyer services (read-only retained)
- `brandon-hub` — Brandon hub host group
- `brandon-compute` — Brandon compute runner group

Any tenant id that is not in this list is rejected unless explicitly
added by an accepted evidence path.

## Status and blocker vocabulary

Status values are `KNOWN`, `PARTIAL`, `UNKNOWN`, `BLOCKED`, `DELIVERED`,
`EVIDENCED`, `IN_PROGRESS`. See `SCHEMA.md` for full semantics.

Blocker values are `NONE`, `COORDINATES_MISSING`, `AUTHORIZATION`,
`OPERATOR_INPUT`, `DEPENDENCY`, `UNKNOWN`. Every `BLOCKED` or `UNKNOWN`
status must carry a non-`NONE` blocker.

## Acceptance rules (must remain true)

These are the rules that the warehouse must always honour; if any rule
is violated, the warehouse is rejected and a new accepted evidence is
required.

1. No record may claim `DELIVERED` without an evidence path.
2. No record may claim a brand/domain assignment that the cited source
   does not identify. This applies especially to Mattermost and Jitsi
   instance ownership and AnythingLLM Brandon-vs-HD2 boundary.
3. No record may claim that Brandon bot routing, Mattermost
   rebranding, Jitsi rebranding, or Amino/Elevate live placement is
   complete unless an accepted artifact proves it.
4. Any host whose coordinates are missing must be `UNKNOWN` or
   `BLOCKED` with `COORDINATES_MISSING`.
5. `last_verified` and `freshness_days` are required on every record;
   records older than their freshness window are rejected.

## Provenance note (recorded)

The canonical warehouse copy is
`BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (v3.0, last updated
2026-08-04) and is the source to read for the PRD itself. The recovered
session read and `data/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md` remain
historical evidence for how earlier status records were derived. The original
historical Git blob is still absent from the current checkout/object database;
that is an exact-byte provenance limitation, not a missing warehouse source.

## Workflow

1. Read this `INDEX.md`.
2. For each question, follow the file map to the relevant `.md`/`.yaml`
   pair.
3. To check the warehouse programmatically, run
   `bin/fm-context-preflight.sh` (fail-closed). The preflight enforces
   freshness, schema, source pointers, and the absence of secret
   material.
4. To add a record, edit the Markdown first, then mirror the change
   into YAML, then re-run the preflight. The preflight must return
   `PASS` before the change is considered valid.
