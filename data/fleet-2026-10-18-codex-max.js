const HOME = "/home/hd2admin/kun-agent-workspace";


  const SRC = `${HOME}/docs/system-context`;
  const READ = `Read these in FULL before you claim anything:
- ${SRC}/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md (2071 lines - all of it)
- ${SRC}/PRD_TRACEABILITY.md
- ${SRC}/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md
- ${HOME}/data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md (the template)`;

  const COMMON = `
${READ}

YOUR JOB IS ADVERSARIAL VERIFICATION, NOT SUMMARY. Assume the PRD you are given is
probably wrong and prove it. A PRD that survives your attack is valuable; a PRD you
praise is worthless.

Hard rules:
- Every claim you make must cite a file path and line, or a command you ran with its
  output. If you cannot source it, write UNKNOWN and say what evidence would settle it.
- Use only these status words: DELIVERED, EVIDENCED, IN_PROGRESS, BLOCKED, UNKNOWN.
- v3 is dated 2026-08-04 and may be stale. That is not permission to invent.
- Where v3, the ledger, and the PRD disagree, record ALL readings and mark the conflict
  OPEN. Never silently pick a winner.
- Do NOT contact the Captain. Do NOT write to any project, DNS, host or service.
  Document-only, read-only. Your output is a file plus a short report.
- Do NOT edit the PRD you are auditing. You produce a findings document, not a rewrite.`;

const STEPS = [
      {
        id: "code-distro",
        task: `AUDIT ${HOME}/data/prds/core-distro-prd-v1.0.md (1093 lines, claims 87 provenance rows).
${COMMON}
Focus your attack on:
1. Does the PRD correctly represent Core Distro as a full SaaS application per v3 §2.1?
   v3 lists internal lead and account dashboards, product/supplier records, file uploads and
   downloads, background lead enrichment, and CRM/workflow integrations. If the PRD treats it
   as a marketing site, that is a major finding.
2. The §2.1 production reality gap: Namecheap/PHP 8.2 and Contabo against a v3 target of
   Hostinger public plane plus Hetzner compute. Is that gap recorded accurately, and does the
   PRD correctly sequence an ADR BEFORE any architecture or migration decision?
3. Is the chatbot status honest? Measured 2026-10-18: apex 200, staging 200, embed config 200,
   but BOTH the client hostname and the direct upstream 100.106.6.22:3001 return the
   AnythingLLM SPA HTML shell instead of a stream payload. Does the PRD reflect that, and does it
   avoid claiming any assistant reply was ever verified?
4. Spot-check at least 15 of the 87 provenance labels against their cited sources. Report any
   label that does not survive.
Write findings to ${HOME}/data/audit/2026-10-18-audit-core-distro.md`,
      },
      {
        id: "elevate",
        task: `AUDIT ${HOME}/data/prds/elevate-life-sci-prd-v1.0.md (527 lines, claims 139 provenance rows).
${COMMON}
Focus your attack on:
1. THE CENTRAL CONTRADICTION. v3 §2.2 says Elevate's exact application requirements are NOT
   proven and forbids inventing product, patient, clinical or compliance requirements, assuming
   only a POTENTIAL authenticated portal and POTENTIAL data. But the delivery map records that an
   Elevate OPERATIONS CONSOLE EXISTS today, is reachable WITHOUT an auth wall, and exposed
   unauthenticated status and job APIs. Does the PRD record this as an OPEN CONFLICT rather than
   smoothing it over? Is it flagged as that domain's highest-risk item?
2. The ledger marks only elevate-site-live as DELIVERED and explicitly says that does NOT prove
   PRD-wide app/API/queue/backup/isolation acceptance. Does the PRD inflate DELIVERED into broader
   acceptance anywhere? That inflation would be a serious finding.
3. HD2 remediated the auth wall on 2026-10-17: console now returns HTTP 401 with Basic realm
   "Elevate Operations Console", while /embed/ and /api/embed/ still return 200 and the client
   site returns 200. Does the PRD reflect the remediated state, or a stale pre-remediation state?
4. Spot-check at least 20 of the 139 provenance labels. Report any that do not survive.
Write findings to ${HOME}/data/audit/2026-10-18-audit-elevate.md`,
      },
      {
        id: "cbd-data",
        task: `AUDIT ${HOME}/data/prds/cbd-data-prd-v1.0.md (768 lines, claims 90 provenance rows).
${COMMON}
Focus your attack on:
1. Does the PRD round the enrichment gate up? The ledger proves only a bounded broker/runtime
   slice. There is no publisher, no consumer adapter, no project_id, no idempotency key, no
   durable persistence or restore, and no accepted end-to-end Hostinger-to-Hetzner chain.
   Gate-004 and cutover remain UNAUTHORISED. Any claim beyond the bounded slice is a finding.
2. Does the PRD represent the real product scope from v3 §2.4: B2B business search by keyword
   and location, automated website visits and data acquisition, email/phone/social/contact
   enrichment, lead-list management, CSV export, public share links, CRM integration, and API
   access for larger plans?
3. v3 §2.4 states CBD-Data is the heaviest scraping/enrichment/queue/export/data-volume workload
   of the four, with the public application on Hostinger and scraping/enrichment/AI/batch on
   Hetzner. Does the PRD carry that architecture split, and does it conflict with the service
   catalogue record showing cbd-worker ACTIVE on AminoVPS rather than the v3 target? Record that
   conflict if present.
4. Spot-check at least 15 of the 90 provenance labels. Report any that do not survive.
Write findings to ${HOME}/data/audit/2026-10-18-audit-cbd-data.md`,
      },
      {
        id: "whoosh",
        task: `AUDIT ${HOME}/data/prds/whoosh-prd-status-brief.md (373 lines).
${COMMON}
DO NOT REWRITE OR ALTER ${HOME}/data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md - it is
the Captain's authoritative document and must remain byte-identical. Verify it is unmodified.
Focus your attack on:
1. Is the status BLOCKED / COORDINATES_MISSING per the ledger, and is bot routing recorded as
   UNKNOWN rather than claimed complete?
2. A CONTRADICTION MUST BE PRESERVED, NOT RESOLVED. The Captain's v1.0 records
   data.whooshperformance.com and lc.whooshperformance.com as returning HTTP 502. Direct
   measurement on 2026-10-18 recorded them as NOT RESOLVING AT ALL. These are different faults:
   a 502 has an origin to repair, a non-resolving hostname does not. Does the brief record BOTH
   readings and mark the conflict OPEN? A brief that quietly picks one is a finding.
3. Is the brief honest that it does NOT restate v1.0, and does it avoid duplicating or
   contradicting the authoritative PRD?
4. Is Phase 5 ordering (Core Distro, Elevate, Whoosh, CBD-Data) represented accurately?
Write findings to ${HOME}/data/audit/2026-10-18-audit-whoosh.md`,
      },
      {
        id: "cross-cutting",
        task: `AUDIT THE FOUR CROSS-CUTTING UNKNOWNS THAT GATE ALL FOUR DOMAINS.
${COMMON}
The ledger marks these UNKNOWN, and they gate platform-wide acceptance regardless of any
individual domain's progress. Your job is to establish what is actually knowable, not to fix
anything. For EACH of the four, report: current measurable state, what evidence exists and where,
what remains unproven, and the smallest concrete action that would move it from UNKNOWN.
1. PLATFORM ISOLATION - are client domains actually isolated from HD2-internal infrastructure,
   including anythingllm endpoints? Measure it. Do not assume it.
2. CI/CD - is there any real pipeline for any of the four domains? Evidence, not assumption.
3. BACKUP/DR - are backups actually taken, and has any restore ever been DRILLED as opposed to
   configured? Note the ledger marks this UNKNOWN OPERATOR_INPUT - distinguish "never configured"
   from "configured but no drill".
4. OBSERVABILITY - what monitoring actually exists and what alerts actually fire?
ALSO: verify these cross-cutting facts still hold as of today, by measurement:
   - port 8081 is the client-facing AnythingLLM dependency and must remain untouched
   - main branch is in sync with origin/main
   - both git stash entries are still present and untouched
Write findings to ${HOME}/data/audit/2026-10-18-audit-cross-cutting.md`,
      },
      {
        id: "fleet-integrity",
        task: `YOU ARE THE FLEET'S OWN INTEGRITY LANE. Your job is to make sure this fleet is not
producing confident nonsense. ${READ}

Six other lanes are auditing four domain PRDs plus the cross-cutting unknowns, all dispatched at
the same moment. Six lanes running in parallel against the same source documents is precisely the
condition under which six agents independently reproduce the SAME shared error. Find that error.

Do this:
1. Independently derive, FROM THE SOURCES ALONE and before reading any other lane's output, the
   correct status of each of the four domains and the four cross-cutting areas. Write your own
   answer to ${HOME}/data/audit/2026-10-18-independent-baseline.md FIRST. Commit to it.
2. Then read the sibling findings in ${HOME}/data/audit/ (elevate, core-distro, cbd-data,
   whoosh, cross-cutting). For each, mark every claim SUPPORTED, UNSUPPORTED, or UNCERTAIN with
   your evidence. Call out shared assumptions that multiple lanes made without checking - those
   are the correlated failure mode.
3. Flag any provenance label used across lanes that is actually a fabrication risk, e.g. a label
   that asserts a source was read without the claim being checkable.
4. State plainly whether you believe the four PRDs are safe to treat as a working baseline.
You are the reviewer; the other lanes are the authors. You have no stake in them being right.
Write your verdict to ${HOME}/data/audit/2026-10-18-fleet-verdict.md`,
      },
  ];
  };

return { model: "openai-codex/gpt-6-luna", fast: true, steps: STEPS };
