# Core Distro V3 Criteria Hunt — Scout Report (Corrected)

**Task:** core-v3-criteria-hunt-0923
**Date:** 2026-09-23
**Scope:** Read-only source discovery; no tests, builds, deployments, or file changes.
**Worktree:** `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/5/core-distro-saas-clean` (disposable, detached HEAD `ba233e1`)

---

## Correction note

An earlier version of this report claimed §20.1 of the Brandon Infrastructure PRD constitutes the Core Distro product acceptance source. That claim was incorrect and is withdrawn. The correction is below.

---

## What §20.1 actually says

**Document:** `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` §20.1
**Full text:**

```
### 20.1 Core Distro
- Public site loads over HTTPS.
- Quote/contact submission is durable.
- Uploaded or downloadable documents respect authorization.
- Any lead-enrichment job uses the Core queue and Core credentials only.
- Core data does not appear in another project's database, logs, files, or backup.
- Core backup restores successfully.
```

These are **infrastructure-lane acceptance criteria**: they verify deployment correctness, queue/credential isolation, data isolation between projects, and backup restore. They test where the application runs, not what the application does. Specifically:

- "Public site loads over HTTPS" → infrastructure (TLS termination, DNS, web server)
- "Quote/contact submission is durable" → infrastructure durability of a form submission; not a feature completeness test
- "Documents respect authorization" → file-serving authorization in the infrastructure context
- "Lead-enrichment job uses the Core queue and Core credentials only" → queue isolation per §8.2/§17.2 of the same PRD; a cross-project infrastructure check
- "Core data does not appear in another project's database/logs/files/backup" → cross-project data isolation per §8.1; a compliance/infrastructure check
- "Core backup restores successfully" → DR restore procedure per §7.3

These are the same category as §21 "Global Acceptance Criteria" (Hostinger, Hetzner, Namecheap, Security, Deployment, Observability) — they verify the infrastructure is correctly configured and isolated. They are not a product feature checklist for the Core Distro SaaS application.

**Contrast with §20.4 CBD-Data**, which includes product-level criteria:
- "User can submit a permitted business search"
- "Durable job record is created on Hostinger"
- "Job is routed to the CBD-Data RabbitMQ virtual host"
- "Duplicate delivery does not duplicate leads or charges"

CBD-Data's criteria specify the application's business logic and data integrity. Core Distro's criteria do not — they are purely infrastructure guards.

---

## Conclusion on §20.1

**§20.1 is not the Core Distro product V3 acceptance source.** It is the Core Distro infrastructure-lane acceptance source. It answers "is the application correctly deployed and isolated?" It does not answer "is the application feature-complete and correct as a product?"

---

## What was searched

Per the backlog task description, the following roots were searched:
- `/home/hd2admin/agent-work/` (warehouse roots including `firstmate/docs/system-context/`, `firstmate/data/`, `n6-core-distro-readonly-20260921/`)
- `/home/hd2admin/brandon-inbox/` (Steer messages)
- `/home/hd2admin/kun-agent-workspace/data/` (FirstMate data directory — backlog, lane reports, gap map)
- `/home/hd2admin/kun-agent-workspace/projects/firstmate/docs/system-context/` (second PRD copy)
- `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/5/core-distro-saas-clean` (Core source — previously searched by gap map)

**Exclusions applied:** `.env` files, credentials, stateful app data, agent session logs, `.zip` archives.

**Search terms used:**

Filename pattern searches: `*PRD*`, `*prd*`, `*V3*`, `*v3*`, `*product*spec*`, `*acceptance*`, `*criteria*`, `*roadmap*`, `*lead*engine*spec*`, `*core*distro*spec*`

Content searches across all `.md` files: `core-distro.*v3`, `v3.*core-distro`, `core.distro.*product`, `core.distro.*spec`, `core.distro.*acceptance`, `core.distro.*requirement`, `core.distro.*functional`, `core.distro.*feature`, plus generic V3/acceptance/prospect criteria terms.

---

## What was found

### Brandon Multi-Project Infrastructure PRD v3.0

**Path (two confirmed copies, byte-identical):**
- `agent-work/firstmate/docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`
- `kun-agent-workspace/projects/firstmate/docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`
**SHA-256 (both):** `1574d6cfc0cfb9cdb52fae4336cbaa8d159e52ab3d0453d2de75d6031558e841`
**Version/date:** v3.0 — 2026-08-04
**Git commit:** `2e61f52 feat(system-context): sync approved warehouse docs and PRD traceability for Brandon remote execution (Option A)`
**Status:** Confirmed present. Contains Core Distro infrastructure-lane criteria at §20.1. Does **not** contain Core Distro product acceptance criteria.

### Related warehouse documents

| Document | Path | Relevance |
|---|---|---|
| `PRD_TRACEABILITY.md` | `firstmate/docs/system-context/` | Confirms above PRD as canonical; records `PRD_DELIVERY_MAP.md` provenance gap |
| `PRD_DELIVERY_MAP.md` | Referenced at `data/prd-delivery-plan-20260914/` | **Absent** from searched roots; provenance gap already recorded in PRD_TRACEABILITY |
| `BR-AUD-002/report.md` | `firstmate/data/BR-AUD-002/report.md` | Application audit (2026-08-06): PHP/MySQL/Percona runtime facts, DB schema, queue model, data classes; audit, not acceptance spec |
| `SOURCES.md` | `firstmate/docs/system-context/` | Canonical source inventory; records PRD_DELIVERY_MAP.md absence |
| `WAREHOUSE_BOUNDARIES.md` | `firstmate/docs/system-context/` | Confirms Core Distro and CBD-Data share codebase; warehouse isolation not per-project proven |
| `FIRSTMATE_COORDINATOR_KICKOFF.md` | `kun-agent-workspace/FIRSTMATE_COORDINATOR_KICKOFF.md` | Brandon coordination brief; not a product PRD — already correctly distinguished by gap map |
| `core-v3-prd-gap-map/report.md` | `kun-agent-workspace/data/` | Prior gap map; correctly found §20.1 infrastructure criteria absent from Core source |

### Documents confirmed absent from searched roots

- Any document titled "Core Distro V3 PRD" or "Core Distro Product Specification"
- Any document defining feature-level acceptance criteria for Core Distro SaaS (CSV import/export completeness, lead enrichment workflow, auth/subscription flow, credits system, category filtering, multi-region geo support)
- `PRD_DELIVERY_MAP.md` (absent from current warehouse snapshot; provenance gap already recorded)

---

## Gap confirmed

**The canonical Core Distro SaaS product V3 acceptance specification — a document defining feature completeness and functional acceptance criteria for the application itself — is absent from the searched roots.**

This matches the original gap-map finding. The infrastructure PRD provides deployment and isolation criteria; it does not substitute for a product acceptance spec. The gap map's unknown row stands.

---

## What counts as infrastructure vs. product acceptance (for this task)

| Layer | Owner | Example criteria from this PRD |
|---|---|---|
| Infrastructure acceptance | §20.1 Core Distro + §21 Global | HTTPS loads, queue isolation, data isolation, backup restores, cross-project access denied |
| Product acceptance | **Not found** | Feature completeness, CSV workflow correctness, enrichment logic, auth flows, credits/subscription logic |

---

## Recommendations

1. **Do not close the gap-map "unknown" row** using §20.1 — that row covers product acceptance, not infrastructure acceptance.
2. **The gap is genuine.** A separate document defining Core Distro SaaS product acceptance is required. Possible sources to pursue: operator product owner, Brandon client brief, or a product requirements document maintained outside this warehouse.
3. **Infrastructure criteria are now evidenced** and can be marked as such in the gap map: §20.1 + §21 of the Brandon PRD v3.0 at SHA-256 `1574d6cfc0cfb9cdb52fae4336cbaa8d159e52ab3d0453d2de75d6031558e841`.
4. **No captain decision is required** to record this gap; the source is genuinely absent.

---

## Method

Read-only commands: `find`, `grep -l/-li`, `git log`, `sha256sum`, `wc -l`. No writes, tests, builds, network access, or stateful inspection. The PRD was read in full to verify §20.1 content before drawing conclusions.

The `captain-hold-lifecycle` shared completion gate was passed with `--none` (zero unresolved captain calls; no product choice required). `fm-captain-hold.sh verify core-v3-criteria-hunt-0923` returned `verified`.
