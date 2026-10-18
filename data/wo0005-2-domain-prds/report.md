# Seven domain PRDs and owner assignment

**Purpose and method.** I read the authoritative registry first, then compared its scope rows with the supplied 2026-10-15 measured-state snapshot and the current warehouse records. I made no network, browser, deployment, publish, merge, host, database, or project-tree calls; the live measurements below are supplied verified evidence, not measurements I independently repeated. No writes were made to `projects/` or any secondmate home. The seven registry entries comprise four client domains and three shared infrastructure workstreams; the latter have no public client website, which is stated rather than invented.

**Source of truth.** `/home/hd2admin/agent-work/deightonllm-firstmate/data/agent-scopes.tsv`, rows 2–8. The following are exact relevant row cells (read/write/exclusion/notes); no broader permission is inferred:

| Row | Registry quotation relied on |
|---|---|
| 2 | `core-ops` — read `core-distro.com,core-distro-saas-clean,core-distro-stage,...`; write `core-distro.stage,...`; excludes `core-distro.com.production,...,staging.core-distro.com.host-access,...`; note: `cannot reach the staging host (route is Controller-side), so it cannot finish staging publish despite owning Core.` |
| 3 | `whoosh-ops` — read `whooshperformance.com,whoosh.database,whoosh.api,...`; write `whoosh.stage,...`; excludes `whooshperformance.com.production,...`; note: `Previously reported unable to read its own data/charter.md; UNVERIFIED as to cause.` |
| 4 | `cbddata-ops` — read `cbd-data.com,cbd-data.scraper,...,warehouse`; write `cbd-data.pipeline,...`; excludes `cbd-data.com.production,...,warehouse.write`; note: `Documentation work for this domain is COMPLETE (2026-10-13); this is documentation completeness, NOT production validation.` |
| 5 | `elevate-p0-repair` — read `anythingllm-elevate-repair,agents.elevatesci.com`; write `anythingllm-elevate-repair`; excludes `elevatesci.com.production,...`; note: `AnythingLLM workspace repair only, idle by default after task.` |
| 6 | `hetzner-compute` — read/write `hetzner.compute,rabbitmq,qdrant,browser-pool,enrichment-workers,ai-workers`; excludes `PROJECT.APPLICATION.CODE,...,core-distro.com,...,elevatesci.com,...,staging.core-distro.com,...`; note: `Compute plane only. READ-ONLY ON PROJECT APPLICATION CODE. Correctly refused a WordPress publish on 2026-10-15 on exactly this basis; the refusal was right and the routing was mine.` |
| 7 | `backup-dr` — read `target`; write `backup-jobs,encrypted-namecheap-transfers,restore-scripts,backup-manifests,dr-runbooks,dr-drills`; excludes `backup-restore.drill,...`; note: `Restore drills are the only write path to a live site and require explicit Captain authority first.` |
| 8 | `system-ops` — read/write `system,host,os,disk,processes`; excludes `tmux.herdr.agent-restart,credentials,warehouse,project.application`; note: `Owns ONLY explicit system tickets handed off by the parent firstmate. Idle by default.` |

## Owner assignment

| Client domain / workstream | Exactly one owner | Assignment basis |
|---|---|---|
| Core Distro (`core-distro.com`, `data.core-distro.com`, staging) | `core-ops` | Registry row 2 owns Core project/staging read scope and staging writes; production and staging-host access are explicitly excluded. |
| Whoosh (`whooshperformance.com`) | `whoosh-ops` | Registry row 3 is the only Whoosh project owner. |
| CBD-Data (`cbd-data.com`) | `cbddata-ops` | Registry row 4 is the only CBD project owner; docs completion is not production acceptance. |
| Elevate (`elevatesci.com`, `agents.elevatesci.com`) | `elevate-p0-repair` | Registry row 5 grants the AnythingLLM workspace lane, including `agents.elevatesci.com`; it does not own the Elevate production site. |
| Brandon compute plane (no client-facing domain) | `hetzner-compute` | Registry row 6 owns compute services only, not client applications or publishing. |
| Backup and disaster recovery (no client-facing domain) | `backup-dr` | Registry row 7 owns backup/transfer/manifests/runbooks; live restore drills are gated. |
| Shared system operations (no client-facing domain) | `system-ops` | Registry row 8 accepts only explicit parent-issued system tickets. |

## PRD 1 — Core Distro

**Owner:** `core-ops`. **What done means:** (1) an authorized external GET to `https://core-distro.com` and `https://data.core-distro.com` returns HTTP 200; (2) the authorized staging check returns HTTP 200 with a valid certificate; (3) the private WordPress artifact has independent acceptance evidence, including its route/checksum results and an explicit record of what database/page/menu state is not established. Public production acceptance and staging-host remediation are not inferred from these checks.

**Current measured state:** both public Core domains return 200 at the supplied measurement; `core-distro.com` is titled “Pharmaceutical Supply Distribution” and resolves to Namecheap `66.29.153.174`. `staging.core-distro.com` returns 000 with an expired certificate and separately the application returns 500. Private WordPress origin is reported healthy (Astra 4.14.0 + child theme, 10/10 suite, 12 routes 200); artifact `50ae6849c190` has 19/19 checksums, but is acknowledged as reported and not independently accepted. It has never been published; chatbot inactive; artifact has no DB/page/menu state. Therefore criteria (1) observed pass; (2) fail; (3) not accepted.

**Next single action:** `core-ops` independently inspect and record acceptance or rejection of artifact `50ae6849c190` against its existing 19-checksum and 12-route evidence, without publishing. **Out of scope:** production changes to `core-distro.com`, DNS/credentials, and staging host access; in particular `core-ops` cannot finish the staging publish without the Controller-side route. **Blocked-on:** staging restoration requires authorized Controller-side staging-host access; its certificate and app faults are separate, and neither is cleared by the other. Artifact acceptance is separately blocked on independent review and absent DB/page/menu evidence.

## PRD 2 — Whoosh Performance

**Owner:** `whoosh-ops`. **What done means:** (1) the domain serves an identified, approved Whoosh application rather than a parked-domain response; (2) the authorized application health check succeeds; (3) repository/runtime/hosting coordinates and owner-approved acceptance checks are recorded. A DNS-resolving parked domain is not an application.

**Current measured state:** `whooshperformance.com` is a parked domain on Hostinger DNS, not a site. No live application surface is evidenced; no application-health criterion passes. The warehouse independently records Whoosh coordinates as unresolved (`PRD_TRACEABILITY.md`, `whoosh-audit`, lines 138–151; `PRD_DELIVERY_MAP.md` unresolved area 1 per that record).

**Next single action:** `whoosh-ops` obtain the exact repository, runtime, and hosting coordinates from the parent/authorized domain contact and record them before proposing any site action. **Out of scope:** production site changes, DNS, credentials, and workarounds that treat the parked domain as a functioning site. **Blocked-on:** exact repo + hosting/runtime + production IP coordinates; no live surface exists to test until those are supplied and an application is identified.

## PRD 3 — CBD-Data

**Owner:** `cbddata-ops`. **What done means:** (1) the customer-facing domain returns HTTP 200 and identifies the expected CBD-Data application; (2) separately, an authorized acceptance record proves the actual customer workflow and production data path; (3) domain documentation and test evidence identify which assertions are documentation-only versus production-validated. A 200 response or completed documentation alone does not satisfy (2).

**Current measured state:** `cbd-data.com` returns 200 with title “Automated B2B Lead Generation”; criterion (1) passes. CBD documentation was marked complete 2026-10-13, but the registry explicitly says this is not production validation; criterion (2) remains unproven. Warehouse traceability records prior audit evidence but no accepted end-to-end Hostinger↔Hetzner queue/isolation/restore/sign-off chain (`PRD_TRACEABILITY.md`, lines 97–114).

**Next single action:** `cbddata-ops` prepare the exact production-acceptance evidence checklist and identify the already-authorized evidence source, explicitly marking unavailable items; do not access production. **Out of scope:** `cbd-data.com` production changes, DNS, credentials, and warehouse writes. **Blocked-on:** independent authorized production-validation evidence; the current owner is expressly excluded from production, and documentation completion cannot substitute.

## PRD 4 — Elevate Life Sci

**Owner:** `elevate-p0-repair`. **What done means:** (1) the public site returns HTTP 200; (2) `agents.elevatesci.com` returns HTTP 200 and the approved AnythingLLM workspace state is independently evidenced; (3) chatbot behavior is only called active after an authorized functional check proves it. Site availability is not proof of workspace repair or chatbot activation.

**Current measured state:** `elevatesci.com` returns 200 (Hostinger + Cloudflare); `agents.elevatesci.com` returns 200 and identifies AnythingLLM. Chatbot is inactive. The WordPress origin evidence is private and unpublished, and does not establish Elevate database/page/menu state. Criteria (1) and endpoint portion of (2) pass; workspace acceptance and (3) do not.

**Next single action:** `elevate-p0-repair` document the existing authorized, read-only AnythingLLM workspace acceptance evidence for `agents.elevatesci.com`, distinguishing endpoint reachability from workspace/chatbot functionality. **Out of scope:** `elevatesci.com` production, Core/CBD/Whoosh, DNS, credentials, and publishing the private WordPress artifact. **Blocked-on:** accepted workspace-state evidence; chatbot remains inactive and no authorized functional result is supplied.

## PRD 5 — Brandon compute plane

**Owner:** `hetzner-compute`. This is an infrastructure workstream, not a client website. **What done means:** (1) a dated, accepted inventory identifies the Hetzner compute host/runtime and enabled services; (2) each enabled queue/worker/vector/browser component has service-health evidence and project isolation evidence; (3) any application publish is performed only by its project owner. Registry exclusions bar application code and client-domain ownership.

**Current measured state:** no public client surface is assigned to this owner. The supplied WordPress private-origin report is not evidence of Hetzner service health. The warehouse labels Brandon compute runtime status UNKNOWN and says accepted live execution evidence is absent (`PRD_TRACEABILITY.md`, lines 194–210). No compute health/isolation measurements were provided.

**Next single action:** `hetzner-compute` produce an accepted read-only inventory of the specifically registered compute runtime and enabled services, without touching project application code. **Out of scope:** all client websites/application code, including WordPress publication; DNS, credentials, and client production. **Blocked-on:** accepted host/runtime inventory and per-service evidence; current registration/handoff evidence alone is insufficient.

## PRD 6 — Backup and DR

**Owner:** `backup-dr`. This is a shared recovery workstream, not a client website. **What done means:** for each assigned project target, an encrypted backup manifest identifies target, project, timestamp, checksum, and retention; an authorized restore test produces a recorded result and measured recovery point/time. No backup is called validated merely because a job or manifest exists. These are acceptance criteria, not authorization to run a live restore.

**Current measured state:** no backup/transfer/restore measurement was included in the supplied live-state snapshot. Warehouse traceability says no accepted live encrypted off-host target assignment, per-project target proof, real restore, measured RPO/RTO, or DR drill evidence (`PRD_TRACEABILITY.md`, lines 263–278). The PRD proposes one isolated Namecheap target per project but does not establish the present capability of any target (`BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`, §§7.3, 15–16).

**Next single action:** `backup-dr` inventory the existing approved target assignment and capability evidence and report missing fields; do not transfer data or execute a restore. **Out of scope:** client-site changes, DNS/credentials, and live restore drills without explicit Captain authority. **Blocked-on:** exact target/account and capability evidence; a live restore/drill additionally requires explicit Captain authorization.

## PRD 7 — Shared system operations

**Owner:** `system-ops`. This is an explicit-ticket-only systems workstream, not a client website. **What done means:** each system ticket names the host/system and allowed operation; its acceptance record contains the before/after observable state and command output for that exact operation. No ticket means no system operation.

**Current measured state:** no public domain/site or explicit system ticket is established by the supplied snapshot. The snapshot's domain availability and private WordPress details do not establish host/OS/disk/process status. Registry row 8 limits this owner to explicit parent-issued system tickets.

**Next single action:** parent Firstmate issue one bounded system ticket only if a specific host-level deliverable is identified; otherwise keep this owner idle. **Out of scope:** client application/code, credentials, warehouse, and Herdr/tmux agent restarts or replacement. **Blocked-on:** a parent-issued ticket naming exact host, system, acceptance observation, and allowed operation.

## Evidence and references

- **Registry read first:** `/home/hd2admin/agent-work/deightonllm-firstmate/data/agent-scopes.tsv`, rows 2–8 (quoted above). The complete source rows, including every domain exclusion, were read; only relevant cells are reproduced in the table.
- **Measured live-state source:** dispatch brief, “Measured live state, 2026-10-15,” including all seven supplied surfaces and private WordPress artifact facts. These measurements were not re-run in this report.
- **Warehouse cross-check:** `/home/hd2admin/kun-agent-workspace/docs/system-context/PRD_TRACEABILITY.md`: Whoosh § lines 138–151; CBD lines 97–114; compute lines 194–210; backup/DR lines 263–278. `/home/hd2admin/kun-agent-workspace/docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`: project split and target architecture; Namecheap capability gate §5, lines 211 onward; compute §7.2; DR targets §7.3 and §§15–16.
- **Commands run:** none against domains, hosts, services, projects, or GitHub. Tool actions were file reads, visible To-Do List updates, and appends of `working` and keyed `blocked` events to the prescribed task status file. No browser or live-system operation was performed.

**Completion-gate inventory:** this report records bounded next steps and evidence gaps; it makes no new product, destructive, deployment, or authorization choice and poses no unresolved captain decision. The inventory is therefore `--none`. No visual review was performed. I read `decision-hold-lifecycle/SKILL.md`, but did not run `bin/fm-decision-hold.sh complete wo0005-2-domain-prds --none`: the script records its attestation in the originating home’s task metadata, while the brief permits outside-worktree writes only to this report and the prescribed status file. The shared completion gate remains unpassed pending an authorized way to record that attestation.
