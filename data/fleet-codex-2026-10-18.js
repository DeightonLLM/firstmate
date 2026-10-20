const HOME = "/home/hd2admin/kun-agent-workspace";
const SRC = `${HOME}/docs/system-context`;

const READ = `Read in FULL before claiming anything: ${SRC}/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PD_V3.md if present, else ${SRC}/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md (2071 lines, all of it); ${SRC}/PRD_TRACEABILITY.md; ${SRC}/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md; ${HOME}/data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md (the template).`;

const COMMON = `
${READ}

YOUR JOB IS ADVERSARIAL VERIFICATION, NOT SUMMARY. Assume the PRD under audit is probably wrong and prove it. A PRD that survives your attack is valuable; a PRD you praise is worthless.

Hard rules:
- Every claim cites a file path and line, or a command you ran with its output. If you cannot source it, write UNKNOWN and say what evidence would settle it.
- Use only these status words: DELIVERED, EVIDENCED, IN_PROGRESS, BLOCKED, UNKNOWN.
- v3 is dated 2026-08-04 and may be stale. That is not permission to invent.
- Where v3, the ledger, and the PRD disagree, record ALL readings and mark the conflict OPEN. Never silently pick a winner.
- Document-only and read-only. Do NOT edit the PRD you audit, do NOT touch any project, DNS, host or service, do NOT contact the Captain.
- Create ${HOME}/data/audit/ if it does not exist.`;

const steps = [
  {
    id: "audit-core-distro",
    task: `AUDIT ${HOME}/data/prds/core-distro-prd-v1.0.md (1093 lines, claims 87 provenance rows). ${COMMON}

Attack these specific points:
1. Does it represent Core Distro as a full SaaS per v3 section 2.1 - internal lead and account dashboards, product and supplier records, file uploads and downloads, background lead enrichment, CRM and workflow integrations? If it treats this as a marketing site, that is a MAJOR finding.
2. The section 2.1 production reality gap: Namecheap/PHP 8.2 and Contabo against a v3 target of Hostinger public plane plus Hetzner compute. Is it recorded accurately, and does it sequence an ADR BEFORE any architecture or migration decision?
3. Chatbot honesty. Measured today: apex 200, staging 200, embed config 200, but BOTH the client hostname AND direct upstream 100.106.6.22:3001 return the AnythingLLM SPA HTML shell instead of a stream payload. Does the PRD reflect that, and does it avoid claiming any assistant reply was verified?
4. Spot-check at least 15 of the 87 provenance labels against their cited sources. Report every label that fails.

Write findings to ${HOME}/data/audit/2026-10-18-audit-core-distro.md`,
  },
  {
    id: "audit-elevate",
    task: `AUDIT ${HOME}/data/prds/elevate-life-sci-prd-v1.0.md (527 lines, claims 139 provenance rows). ${COMMON}

Attack these specific points:
1. THE CENTRAL CONTRADICTION. v3 section 2.2 says Elevate's exact application requirements are NOT proven and forbids inventing product, patient, clinical or compliance requirements, assuming only a POTENTIAL authenticated portal. But the delivery map records that an Elevate OPERATIONS CONSOLE EXISTS today, is reachable WITHOUT an auth wall, and exposed unauthenticated status and job APIs. Is that recorded as an OPEN CONFLICT rather than smoothed over, and flagged as that domain's highest-risk item?
2. The ledger marks only elevate-site-live as DELIVERED and explicitly says that does NOT prove PRD-wide app, API, queue, backup or isolation acceptance. Does the PRD inflate DELIVERED anywhere? That inflation is a serious finding.
3. HD2 remediated on 2026-10-17: the console now returns HTTP 401 with Basic realm "Elevate Operations Console", while /embed/ and /api/embed/ still return 200 and the client site returns 200. Does the PRD reflect the remediated state or a stale pre-remediation state?
4. Spot-check at least 20 of the 139 provenance labels. Report every label that fails.

Write findings to ${HOME}/data/audit/2026-10-18-audit-elevate.md`,
  },
  {
    id: "audit-cbd-data",
    task: `AUDIT ${HOME}/data/prds/cbd-data-prd-v1.0.md (768 lines, claims 90 provenance rows). ${COMMON}

Attack these specific points:
1. Does it round the enrichment gate up? The ledger proves ONLY a bounded broker and runtime slice - no publisher, no consumer adapter, no project_id, no idempotency key, no durable persistence or restore, and no accepted end-to-end Hostinger-to-Hetzner chain. Gate-004 and cutover remain UNAUTHORISED. Any claim beyond the bounded slice is a finding.
2. Does it carry the real v3 section 2.4 product scope - B2B business search by keyword and location, automated website visits and data acquisition, email, phone, social and contact enrichment, lead-list management, CSV export, public share links, CRM integration, and API access for larger plans?
3. v3 section 2.4 makes CBD-Data the heaviest scraping, enrichment, queue, export and data-volume workload of the four, with the public application on Hostinger and scraping, enrichment, AI and batch on Hetzner. The service catalogue shows cbd-worker ACTIVE on AminoVPS instead. Is that conflict recorded?
4. Spot-check at least 15 of the 90 provenance labels. Report every label that fails.

Write findings to ${HOME}/data/audit/2026-10-18-audit-cbd-data.md`,
  },
  {
    id: "audit-whoosh",
    task: `AUDIT ${HOME}/data/prds/whoosh-prd-status-brief.md (373 lines). ${COMMON}

DO NOT ALTER ${HOME}/data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md - it is the Captain's authoritative document and must remain byte-identical. Verify that it is unmodified and report its size and hash.

Attack these specific points:
1. Is the status BLOCKED with COORDINATES_MISSING per the ledger, and is bot routing recorded as UNKNOWN rather than claimed complete?
2. A CONTRADICTION MUST BE PRESERVED, NOT RESOLVED. The Captain's v1.0 records data.whooshperformance.com and lc.whooshperformance.com as returning HTTP 502. Direct measurement on 2026-10-18 recorded them as NOT RESOLVING AT ALL. These are different faults: a 502 has an origin to repair, a non-resolving hostname does not. Does the brief record BOTH readings and mark the conflict OPEN? Quietly picking one is a finding.
3. Is the brief honest that it does NOT restate v1.0, and does it avoid duplicating or contradicting the authoritative PRD?
4. Is the Phase 5 ordering - Core Distro, Elevate, Whoosh, CBD-Data - represented accurately?

Write findings to ${HOME}/data/audit/2026-10-18-audit-whoosh.md`,
  },
  {
    id: "audit-cross-cutting",
    task: `ESTABLISH WHAT IS ACTUALLY KNOWABLE about the four cross-cutting UNKNOWNs that gate all four domains. ${COMMON}

The ledger marks these UNKNOWN and they gate platform-wide acceptance regardless of any individual domain's own progress. For EACH of the four, report: current measurable state, what evidence exists and where, what remains unproven, and the smallest concrete action that would move it off UNKNOWN.

1. PLATFORM ISOLATION - are client domains actually isolated from HD2-internal infrastructure, including anythingllm endpoints? Measure it. Do not assume it.
2. CI/CD - does any real pipeline exist for any of the four domains? Evidence, not assumption.
3. BACKUP/DR - are backups actually taken, and has any restore ever been DRILLED as opposed to merely configured? The ledger marks this UNKNOWN OPERATOR_INPUT. Distinguish "never configured" from "configured but never drilled".
4. OBSERVABILITY - what monitoring actually exists, and what alerts actually fire.

ALSO verify by measurement: port 8081 is the client-facing AnythingLLM dependency and must remain untouched; main is in sync with origin/main; both git stash entries are still present and untouched.

Write findings to ${HOME}/data/audit/2026-10-18-audit-cross-cutting.md`,
  },
  {
    id: "audit-fleet-integrity",
    task: `YOU ARE THE FLEET'S OWN INTEGRITY LANE. Your job is to stop this fleet producing confident nonsense. ${READ}

Five sibling lanes are auditing four domain PRDs plus the cross-cutting unknowns, all dispatched simultaneously. Six lanes running in parallel against the same source documents is precisely the condition under which they independently reproduce the SAME shared error. Find that error.

1. FIRST, before reading any sibling output, independently derive from the sources alone the correct status of each of the four domains and the four cross-cutting areas. Write your own answer to ${HOME}/data/audit/2026-10-18-independent-baseline.md and commit to it.
2. THEN read the sibling findings in ${HOME}/data/audit/. For each claim mark SUPPORTED, UNSUPPORTED or UNCERTAIN with your evidence. Call out shared assumptions that multiple lanes made without checking - those are the correlated failure mode.
3. Flag any provenance label pattern that is a fabrication risk, for example a label asserting a source was read where the underlying claim is not independently checkable.
4. State plainly whether these four PRDs are safe to treat as a working baseline. You are the reviewer; the other lanes are authors and have no stake in being believed.

Write your verdict to ${HOME}/data/audit/2026-10-18-fleet-verdict.md`,
  },
];

const results = await runs.all(steps.map((s) => ({
  key: s.id,
  agent: "worker",
  model: "openai-codex/gpt-6-luna",
  task: s.task,
})));
return results.map((r, i) => ({
  lane: steps[i].id,
  ok: r.ok,
  runId: r.runId,
  outputReference: r.outputReference,
  error: r.error,
}));
