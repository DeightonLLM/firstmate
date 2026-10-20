// Four domain PRDs, each grounded in the authoritative warehouse record. No invention.
const AUTHORITATIVE = `AUTHORITATIVE SOURCES - read these before writing anything, in this order:
1. docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md  (canonical v3 PRD, 2071 lines, 25 sections - the house template)
2. docs/system-context/PRD_TRACEABILITY.md  (per-item status ledger, 339 lines - THE source of truth for status)
3. docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md  (136 lines - executive verdict, delivered vs spec-only, 9 unresolved acceptance areas)
4. docs/system-context/SERVICE_CATALOG.md and HOSTS.md  (service and host inventory)
The WHOOSH PRD already exists and is authoritative for that domain: data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md - do not contradict or rewrite it.

MANDATORY RULES - these come from the sources themselves and are not negotiable:
- Use ONLY these status values, exactly as PRD_TRACEABILITY.md defines them: DELIVERED (customer-facing release live and verified end-to-end), EVIDENCED (working evidence exists but PRD-wide acceptance not proven), IN_PROGRESS, BLOCKED (named blocker), UNKNOWN (not enough source; DO NOT INVENT).
- NEVER state or imply completion for: Brandon bot routing, Mattermost rebranding, Amino/Elevate live placement, or that the manifest ACCEPTED flag means PRD completion. PRD_DELIVERY_MAP.md line 7 says explicitly: do not use manifest ACCEPTED as a PRD checklist completion signal.
- Every claim must carry its source file. If you cannot cite a source, the row is UNKNOWN, not an estimate.
- Do not invent acceptance criteria, IPs, hostnames, owners, or test results. If it is not in the sources, write UNKNOWN and name what is needed.

THE FOUR UNRESOLVED CROSS-CUTTING AREAS that block every domain (from PRD_DELIVERY_MAP.md 36-64) - carry these into each domain PRD as shared blockers:
1. Project coverage gaps (Whoosh coordinates missing).
2. Canonical application architecture unresolved: current Core/CBD evidence is PHP/MySQL and mixed deployment, while v3 targets Hostinger PostgreSQL/PgBouncer + Hetzner queues/workers. No accepted ADR maps existing software to that target.
3. Cross-project runtime isolation: no accepted evidence for four queue namespaces, worker denial tests, project-scoped ingest, file namespaces, database roles, Qdrant collection isolation.
4. Hub application delivery: app deployment pending, LiteLLM placeholder keys, AnythingLLM backend/vector-store relationship and Brandon-vs-HD2 data boundary unknown.
5. Release controls (CI/CD) UNKNOWN.
6. Backup/DR UNKNOWN, blocked on operator input for provider/account, retention, RPO/RTO, key custody.
7. Observability UNKNOWN.
8. Canonical source provenance: historical Git blob absent (only matters if exact-byte signoff required).
9. Reusable HD2 client baseline incomplete.`;

const domains = [
  {
    key: "m2.7h-brandon-prd-core-distro",
    file: "data/prds/core-distro-prd-v1.0.md",
    domain: "Core Distro (core-distro.com)",
    focus: `Traceability items: coredistro-source-runtime (EVIDENCED), coredistro-route-qa (EVIDENCED), coredistro-canary (BLOCKED / OPERATOR_INPUT).
Key facts to carry accurately: real PHP SaaS source at projects/core-distro.com/current-core-distro/; BR-AUD-002 maps PHP production, Next.js staging, MySQL/Percona, auth/lead-list data, queue-like city jobs. Production coordinates verified 2026-10-12: core-distro.com and data.core-distro.com on Namecheap 66.29.153.174 (PHP 8.2.34); agents.core-distro.com on Contabo 161.97.120.4 (nginx 401 Basic Auth). Controller /etc/hosts localhost trap noted; drift enforcement via bin/fm-coord-drift-check.sh. Canary awaits operator signal with a 36,823-job backlog paused; leadlists.php SHA-256 6f91999dafae7f85951f31455e339c375030fb71eb6c1ad9f474bdf71bce83d3.
ARCHITECTURE CONFLICT you must state plainly, not smooth over: production hosting (Namecheap/PHP 8.2) DIVERGES from the v3 target (Hostinger public/control plane, Hetzner compute plane). An architecture conflict is pending a Captain-ordered ADR. This is the single most important unresolved item for this domain.
NOTE: a ChatWidget/AnythingLLM streaming chat defect exists on the staging Next.js front (stream-chat returns 'Invalid session ID'). If it is not in the sources, record it as an observation with its measurement date and mark its PRD disposition UNKNOWN pending an owner, not as an accepted defect.`,
  },
  {
    key: "m2.7h-brandon-prd-elevate",
    file: "data/prds/elevate-life-sci-prd-v1.0.md",
    domain: "Elevate Life Sci (elevatesci.com)",
    focus: `Traceability items: elevate-site-live (DELIVERED), elevate-ops-provider-adapter (BLOCKED / AUTHORIZATION).
Key facts: BR-ELEVATE-IDENTITY-001 and BR-ELEVATE-SEO-PERF-001 evidence a live apex/www site, valid TLS, 84-file static SEO/schema/image changes, and agents.elevatesci.com dashboard/vhost with a 200 path. Source: BRANDON REWORK/evidence/BR-ELEVATE-SEO-PERF-001/elevate-client-closeout-m3.md sections 1-3, manifest lines 42 and 45. Ops provider-version upgrade remains BLOCKED_AUTHORIZATION (local mock-test implementation only; live/provider authority separate). Ticket 0033 (aminolifesciences sweep, 314 occurrences across 42 files replaced with elevatesci-vps/ElevateSci) is reported CLOSED by HD2Stack - record as reported, with the traceability row still needing its own accepted artifact.
SECURITY ITEM you must carry prominently: PRD_DELIVERY_MAP.md lines 48-53 record that the Elevate operations console is reachable WITHOUT an auth wall and exposes unauthenticated status/job APIs, unlike the Basic-Auth-protected Core-Distro agents console. It is explicitly called a security remediation candidate, NOT an accepted production-parity state. This is the highest-risk open item for this domain.
This is the only domain whose customer-facing site is DELIVERED. Say so accurately and do not inflate it into PRD-wide completion - PRD-wide app/API/queue/backup/isolation acceptance is explicitly NOT proven.
Amino/Elevate live placement is UNKNOWN and legacy, not v3 target. Do not claim it complete.`,
  },
  {
    key: "m2.7h-brandon-prd-cbd-data",
    file: "data/prds/cbd-data-prd-v1.0.md",
    domain: "CBD-Data (cbd-data.com)",
    focus: `Traceability items: cbd-data-source-and-audit (EVIDENCED), cbd-worker-canary (EVIDENCED local; live placement not in PRD-v3 target; AUTHORIZATION blocker), cbd-data-enrichment-gap (EVIDENCED for the bounded broker/runtime slice only; Gate-004 CLOSED on AUTHORIZATION).
Key facts: real Next/PHP project source at projects/cbd-data.com/; BR-AUD-005 accepted for scraping, enrichment, queue, export, storage, and compute placement discovery (manifest line 11). Local restore/backup documents and tests exist. No accepted end-to-end Hostinger-to-Hetzner queue/isolation/restore/signoff chain.
The enrichment gap detail matters: Gate-CBD-ENRICH-003 proves ONLY the bounded broker/runtime slice - private RabbitMQ bootstrap and a deterministic local status helper. There is NO publisher/consumer adapter, project_id, idempotency key, durable persistence/restore, or end-to-end Hostinger-to-Hetzner acceptance. Gate-004 and cutover remain unauthorized. State that precisely; do not round it up to 'enrichment done'.
v3 Phase 5 places CBD-Data LAST because it exercises the heaviest data and processing path, and its rollout is the final capacity and backpressure validation. Reflect that ordering rationale.
Live worker placement on AminoVPS is NOT the v3 target. Do not present it as compliant.`,
  },
  {
    key: "m2.7h-brandon-prd-whoosh",
    file: "data/prds/whoosh-prd-status-brief.md",
    domain: "Whoosh Performance (whooshperformance.com)",
    focus: `This domain has an authoritative full PRD already written by the Captain at data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md. DO NOT rewrite it and DO NOT create a competing plan.
Your deliverable is a SHORT STATUS BRIEF (target 200-350 lines) that says: the v1.0 PRD is the authority and where it lives; what its current measured reality is; and what must be true before Phase 0 can start.
Traceability: whoosh-audit is BLOCKED / DEPENDENCY (COORDINATES_MISSING) - exact repository, hosting, runtime, and production IP are required. Until those exist, BR-ARCH-001 placement and BR-GATE-001 approval cannot close (manifest lines 10-13). whoosh-bot-routing is UNKNOWN, and the sources carry an explicit instruction: do not claim Brandon bot routing is complete without an accepted artifact.
Measured 2026-10-18 by the parent, from an external vantage point: whooshperformance.com and www.whooshperformance.com both return HTTP 200 serving a Hostinger PARKED DOMAIN page (page title 'Parked Domain name on Hostinger DNS system'); apex and www bodies are byte-identical (md5 f474cd3131bc962cb57256dab5741d34) meaning NO canonical redirect; plain HTTP returns 200 with no redirect to HTTPS; data.whooshperformance.com and lc.whooshperformance.com do NOT RESOLVE (curl exit, no HTTP response at all - record this as NOT RESOLVING, never as a 502).
Note that v1.0 section 2.5 recorded data and lc as '502 Bad Gateway'. That is now contradicted by direct measurement. Record the discrepancy explicitly rather than silently overwriting the Captain's text: v1.0 says 502, measurement says not resolving, and the difference matters because a non-resolving host has no origin to repair while a 502 does.
Everything else must come from the sources or be UNKNOWN.`,
  }
];

const results = await runs.all(domains.map((d) => ({
  key: d.key,
  label: `PRD ${d.domain}`,
  agent: "worker",
  model: "minimax/MiniMax-M2.7-highspeed:high",
  cwd: "/home/hd2admin/kun-agent-workspace",
  output: `${d.key}.md`,
  task: `WRITE A DOMAIN PRD for ${d.domain}. Document work only - change no source, no config, no host, no DNS. Your ONLY write target is ${d.file} plus your own report.

${AUTHORITATIVE}

DOMAIN-SPECIFIC FACTS AND INSTRUCTIONS:
${d.focus}

REQUIRED STRUCTURE - follow the v3 PRD's own shape, since it is the house standard. Use these sections, adapting only where noted:
0. Status header (domain, date, PRD version this derives from, and a one-line honest verdict)
1. Current State - a status table using only DELIVERED/EVIDENCED/IN_PROGRESS/BLOCKED/UNKNOWN, each row citing its source file
2. What Is Actually Proven vs What Is Not (explicitly separate working evidence from PRD-wide acceptance)
3. Scope - what this domain includes
4. Non-Goals - what it explicitly does not include
5. Open Blockers - named, each with what would unblock it and who owns it
6. Shared Platform Blockers - the cross-cutting UNKNOWNs above that gate this domain regardless of its own work
7. Acceptance Criteria - checkboxes, each traceable to a v3 PRD section. Mark any criterion you cannot source as UNKNOWN rather than inventing a test.
8. Rollout Sequence - phases with exit gates, consistent with v3 Phase 5 ordering
9. Risks
10. Required Evidence to Change Any Status Here
11. ADR / Decision Items Required

Write it so a reader who was not in the work can check each claim. Cite the source file for every factual row. Where the sources are silent, write UNKNOWN and name exactly what is needed - never a guess, never a plausible-sounding completion, and never a percentage.

Then write your run report to /home/hd2admin/kun-agent-workspace/data/${d.key}.md listing: the file you wrote with its line count, the sources you actually read, every row you had to mark UNKNOWN and why, and any place where the sources contradict each other. If you find a contradiction in the sources, REPORT it rather than resolving it yourself.

Do not contact the Captain; the parent reports.`
})));

return results.map((r, i) => ({ lane: domains[i].domain, ok: r.ok, runId: r.runId, outputReference: r.outputReference, output: r.output }));