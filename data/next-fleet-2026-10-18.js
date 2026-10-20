const HOME = "/home/hd2admin/kun-agent-workspace";
const AUD = `${HOME}/data/audit`;

const RULES = `
GROUND RULES for every lane:
- EXECUTE. Make the change or produce the real artifact. A lane that returns a plan where a build was possible has failed.
- BACKUP BEFORE EVERY MUTATION. Timestamped .bak sibling, path recorded. Never mutate without one.
- VERIFY AFTER EVERY MUTATION with the exact command and its output. Unverified is not done.
- NEVER fabricate. A missing test, a stub that passes, or a claim without a citation is a failure, not a shortcut. Absence of evidence is not evidence of absence.
- If a step needs authorization you do not hold, STOP that step, leave the backup, and record the exact unblocking command. Do not improvise around a boundary.
- Do NOT weaken or skip a test to obtain green.
- Do NOT contact the Captain. Report to the parent.
- Record in ${AUD}/2026-10-18-next-<lane>.md: what changed, backup paths, verification output, and anything blocked.
- Reversible beats clever. Never delete; move aside with a timestamp.`;

const steps = [
  {
    id: "fix-core-distro-chat",
    task: `LANE: FIX THE CORE DISTRO CLIENT CHATBOT. This is a live client-facing defect.

Measured today and still true: core-distro.com serves its chatbot configuration from an HD2-internal endpoint, and both the client hostname and the direct upstream 100.106.6.22:3001 return the AnythingLLM SPA HTML shell instead of a stream payload. No real assistant reply has ever been observed. The widget is repointed on staging and clean; production apex was the miss.

Your job:
1. Establish the actual chat request the widget makes: the exact path, method, headers and body the real browser sends. Inspect the served widget script rather than assuming the API shape.
2. Compare that against what the AnythingLLM instance actually serves at that path. The mismatch is why the SPA shell comes back.
3. Back up every file before changing anything.
4. Fix the routing so the chat request reaches the embed stream API and returns a stream payload rather than the SPA fallback. Match the configuration staging already uses, which is known to be correct.
5. VERIFY WITH A REAL REQUEST: POST an actual message and show the response is a stream payload or a real reply, not HTML. Quote the response.
6. Confirm the public widget still loads and the embed config still returns 200.

Do NOT repoint production to llm.hd2.ai or any HD2-internal endpoint. Do NOT change DNS. If the remaining blocker requires authorization you do not hold, stage the exact change with its backup and record precisely what is blocking it.`,
  },
  {
    id: "build-cbd-pipeline",
    task: `LANE: CLOSE THE CBD-DATA ENRICHMENT SLICE. The product currently has a bounded slice and nothing else.

The ledger proves ONLY a bounded broker and runtime slice. There is no publisher, no consumer adapter, no project_id, no idempotency key, and no durable persistence or restore. Gate-004 and cutover remain BLOCKED (AUTHORIZATION) - so you are NOT authorized to cut over. You ARE authorized to build the missing components so the gate can eventually be evaluated.

Read ${AUD}/2026-10-18-audit-cbd-data.md and ${AUD}/2026-10-18-build-cbd-placement.md first, plus the CBD-Data PRD.

Your job - build the missing pieces, each independently testable:
1. Locate the existing broker and runtime slice. Establish exactly what exists today, measured not assumed.
2. Build a PUBLISHER adapter that can emit enrichment jobs, and a CONSUMER adapter that can process them, against the existing slice's real interface.
3. Add project_id and idempotency key handling so a redelivered job cannot produce duplicate enrichment work, duplicate exports, duplicate emails or duplicate CRM records.
4. Add durable persistence for job state, with a real restore path you actually exercise, not merely configure.
5. Write tests that PROVE each component works, including a redelivery test that demonstrates idempotency. Run them and show they pass for real.

Do NOT enable cutover, do NOT touch production, do NOT authorize Gate-004 yourself. Building the components so the gate CAN be evaluated is in scope; passing the gate is not.`,
  },
  {
    id: "elevate-discovery",
    task: `LANE: RUN REAL DISCOVERY FOR ELEVATE LIFE SCIENCES.

v3 section 2.2 says explicitly that Elevate's exact application requirements are NOT proven by the available materials, and that nobody may invent product, patient, clinical or compliance requirements. Until discovery completes it assumes only a POTENTIAL authenticated portal, POTENTIAL lead/company/product data, POTENTIAL files and reports, and POTENTIAL background enrichment.

Your job is to actually discover, from evidence rather than assumption:
1. Inventory what software and endpoints demonstrably exist for this domain. You already know agents.elevatesci.com serves an Excalidraw console on internal port 8000 and that /embed/ and /api/embed/ are public. Find what else is real.
2. Examine the deployed site and its served assets for actual product surface - pages, forms, API routes, integrations. Report what is demonstrably there versus absent.
3. Establish the data classification reality: what data actually exists, where it lives, and whether anything resembling PHI, clinical records, prescription data or payment-card data is present. This matters because v3 forbids introducing those without a separate approved decision.
4. Produce a DISCOVERY REPORT that states what is proven, what is assumed, and what remains unknown - each with its evidence.

CRITICAL: You must NOT invent product, patient, clinical or compliance requirements. If the evidence does not support a capability, write UNKNOWN and say what evidence would settle it. A thin, truthful discovery report is the deliverable. A confident fictional product spec is a serious failure.`,
  },
  {
    id: "client-visitor-qa",
    task: `LANE: QA THE FOUR CLIENT SITES AS AN ACTUAL VISITOR, NOT AS A HEALTH CHECK.

Every prior check in this programme has been a status code. A site returning 200 can still be broken for a real person. Your job is to find what a visitor would experience.

For each of core-distro.com, elevatesci.com, whooshperformance.com and cbd-data.com:
1. Load the apex and www as a browser would. Follow the real navigation. Record what a first-time visitor actually sees - is it a real product, a parked page, a maintenance page, a redirect loop?
2. Test the forms that exist: submit one if safe and read-only-compatible, or determine precisely what submitting would do and state that instead. Never submit anything that would send mail, charge, or create a real record.
3. Check mobile viewport rendering and whether the chat widget overlaps or breaks the layout.
4. Check accessibility basics that a real user hits: does the page work with images off, is there a visible heading structure, does the chat widget trap focus.
5. Identify the single most damaging thing a real visitor would encounter on each domain, ranked.

Report findings per domain with evidence. A finding you can reproduce is worth ten you inferred. Do not fix anything - this lane diagnoses, another lane fixes.`,
  },
  {
    id: "secondmate-workload",
    task: `LANE: PUT THE SEEDED FLEET TO WORK.

Seven secondmates are registered in ${HOME}/data/secondmates.md. The six missing homes have now been seeded and validated. Each has an isolated FM_HOME, its own state, backlog, charter and session lock. They are idle by default, and an empty queue is healthy - so this lane's job is to give them REAL work, not to invent filler.

Read ${AUD}/2026-10-18-secondmate-readiness.md and ${AUD}/2026-10-18-build-secondmates.md first, plus each home's charter and the scope fields in the registry.

Your job:
1. Determine each registered secondmate's declared SCOPE. Work is routed by scope, not by which clone it happens to have.
2. Identify genuinely eligible work per scope from the audit findings and build-lane results already on disk in ${AUD}/. Only work that is actually within scope and actually needed.
3. Write each secondmate's backlog with concrete, bounded, evidence-producing items. Every item must name its evidence path and stop condition.
4. Respect the idle-by-default contract: a secondmate acts only on work routed to it. Do NOT invent work that does not exist, and do NOT fill a queue just because an empty one feels wrong.
5. Do NOT launch anything into speculative work and do NOT hand-hold anything the parent home owns.

If a scope genuinely has no eligible work, say so plainly. An honest empty queue is a correct outcome, not a failure to fill.`,
  },
  {
    id: "repair-prd-labels",
    task: `LANE: REPAIR THE FAILED PROVENANCE LABELS THE AUDIT FOUND.

The audits found real defects: Core Distro had 2 failed provenance labels; Elevate had 22 sampled label defects; CBD-Data had 15 label checks with conflicts recorded; Whoosh duplicated the authoritative PRD despite being told not to. The independent integrity reviewer concluded the four PRDs are NOT safe as a verified implementation baseline.

Read ${AUD}/2026-10-18-audit-core-distro.md, ${AUD}/2026-10-18-audit-elevate.md, ${AUD}/2026-10-18-audit-cbd-data.md, ${AUD}/2026-10-18-audit-whoosh.md and ${AUD}/2026-10-18-fleet-verdict-v2.md.

Your job:
1. For each failed or defective provenance label, determine what is actually true by reading the cited source yourself.
2. Correct the label to match reality, or mark it UNKNOWN with what evidence would settle it. Never make a label look clean without checking.
3. Reduce the Whoosh brief's duplication of the authoritative PRD - it should be a status brief that points to v1.0, not a second partial copy of it.
4. Apply the Elevate and Whoosh corrections already made in this session and confirm they are complete and introduced no new error.

CRITICAL: You are fixing labels, not deleting findings. Do NOT weaken a caveat, soften a risk, or drop a contradiction to make a document look tidier. A PRD that honestly says UNKNOWN is more valuable than one that appears complete. Do NOT alter ${HOME}/data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md - it is the Captain's authoritative document and must stay byte-identical.`,
  },
];

return runs.all(
  steps.map((s) => ({ key: s.id, agent: "worker", model: "openai-codex/gpt-6-luna", task: RULES + "\n\n" + s.task }))
);
