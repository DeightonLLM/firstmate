const HOME = "/home/hd2admin/kun-agent-workspace";
const A = `${HOME}/data/audit`;

const INTEGRITY = `YOU ARE THE FLEET'S INDEPENDENT INTEGRITY REVIEWER. Your job is to decide whether six sibling lanes produced trustworthy findings, or confident nonsense.

ALL SIX sibling reports now exist. Verify that first - if any are missing, say so and stop claiming cross-lane coverage.

${A}/2026-10-18-audit-core-distro.md
${A}/2026-10-18-audit-elevate.md
${A}/2026-10-18-audit-cbd-data.md
${A}/2026-10-18-audit-whoosh.md
${A}/2026-10-18-audit-cross-cutting.md

Your earlier attempt at this ran before the siblings existed and could not verify anything. Do not repeat that. A previous verdict exists at ${A}/2026-10-18-fleet-verdict.md - read it, and state explicitly why the earlier one was void.

Do this:
1. Confirm all five sibling reports are present and readable. Record sizes.
2. For EVERY material claim in each sibling report, mark SUPPORTED, UNSUPPORTED, or UNCERTAIN with your own evidence. A sibling's confidence is not evidence. Where a sibling claims a defect in a PRD, independently confirm that defect exists before you report it - a false accusation is as bad as a missed one.
3. Two PRD defects have ALREADY been corrected by the parent after the audits: the Elevate PRD now carries a 2026-10-18 remediation update marking the console RESOLVED, and the Whoosh brief now carries an explicit [OPEN CONFLICT C] on the 502-versus-non-resolving discrepancy. Verify both corrections are accurate and complete, and check whether either correction introduced a new error.
4. Identify CORRELATED FAILURE: assumptions multiple lanes made without independently checking. This is the specific risk of running six agents against identical sources at the same moment.
5. Give a clear verdict: are the four domain PRDs safe to treat as a working baseline, yes or no, with the single strongest reason either way.

Document-only and read-only. Do not edit the PRDs. Do not contact the Captain.
Write to ${A}/2026-10-18-fleet-verdict-v2.md`;

const M27 = `Read in FULL before claiming anything: ${HOME}/docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md (2071 lines); ${HOME}/docs/system-context/PRD_TRACEABILITY.md; ${HOME}/docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md.

Hard rules for every lane:
- Every claim cites a file path and line, or a command you ran with its output. Unsourced means UNKNOWN, plus what evidence would settle it.
- Status vocabulary is restricted to DELIVERED, EVIDENCED, IN_PROGRESS, BLOCKED, UNKNOWN. Never inflate.
- v3 is dated 2026-08-04 and may be stale. That is not permission to invent.
- Where sources disagree, record ALL readings and mark the conflict OPEN. Never silently pick a winner.
- Read-only and document-only. Do NOT edit any PRD, project, DNS, host or service. Do NOT contact the Captain.
- Create ${HOME}/data/audit/ if needed.`;

const steps = [
  { id: "integrity-v2", model: "openai-codex/gpt-6-luna", task: INTEGRITY },
  {
    id: "isolation-probe",
    model: "minimax/MiniMax-M2.7-highspeed",
    task: `${M27}

LANE: PLATFORM ISOLATION. Establish by measurement whether client domains are genuinely isolated from HD2-internal infrastructure, especially anythingllm endpoints.
Determine: which client hostname resolves to which address; whether any client domain proxies to an HD2-internal endpoint; whether llm.hd2.ai is referenced anywhere in live client-delivered assets; whether port 8081 is still listening and must stay untouched; and what per-domain isolation evidence exists versus what is assumed.
Produce a per-domain isolation table with a measured column and a claimed column, so assumptions are visible. Any domain where the two differ is a finding.
Write to ${A}/2026-10-18-isolation-probe.md`,
  },
  {
    id: "backup-dr-truth",
    model: "minimax/MiniMax-M2.7-highspeed",
    task: `${M27}

LANE: BACKUP AND DISASTER RECOVERY TRUTH. The ledger marks backup-dr UNKNOWN OPERATOR_INPUT, and the cross-cutting audit reports that backup claims conflict with the ledger and that no restore drill is proven.
Establish: what backup jobs or schedules actually exist and are enabled; whether any restore has ever been EXECUTED and verified as opposed to merely configured; what the stated RPO and RTO actually are and whether they are measured or aspirational; and exactly where the ledger conflict originates.
Distinguish precisely between "never configured", "configured but never drilled", and "drilled and verified". Do not treat the first two as the third.
Write to ${A}/2026-10-18-backup-dr-truth.md`,
  },
  {
    id: "cicd-truth",
    model: "minimax/MiniMax-M2.7-highspeed",
    task: `${M27}

LANE: CI/CD TRUTH. Establish whether any real delivery pipeline exists for any of the four client domains, or for the firstmate repo itself.
Determine: what workflow definitions exist and what they actually do; whether any pipeline has ever run green end to end for a client domain; what is deployed to production by hand versus by pipeline; and whether any test suite actually gates a merge.
Be concrete about the difference between a test file existing and tests gating anything. The cross-cutting audit flagged 39 failing scripts that remain worker-reported and not accepted - determine what currently runs in CI and whether those failures would block anything.
Write to ${A}/2026-10-18-cicd-truth.md`,
  },
  {
    id: "observability-truth",
    model: "minimax/MiniMax-M2.7-highspeed",
    task: `${M27}

LANE: OBSERVABILITY TRUTH. Establish what monitoring actually exists for the four client domains and this infrastructure, and what alerts would genuinely fire.
Determine: what is monitored, at what interval; which alerts are enabled and where they deliver; whether anything pages a human; whether there is uptime or certificate-expiry monitoring on the client domains; and what a real outage today would and would not surface.
Distinguish a dashboard nobody reads from an alert that reaches a human. Record what would need to be true for alerting to be trustworthy.
Write to ${A}/2026-10-18-observability-truth.md`,
  },
  {
    id: "secondmate-supervisor",
    model: "minimax/MiniMax-M2.7-highspeed",
    task: `${M27}

LANE: SECONDMATE READINESS. Prepare the durable record for a persistent secondmate on this host, without launching anything yet.
Read ${HOME}/.agents/skills/secondmate-provisioning/SKILL.md in full and ${HOME}/docs/configuration.md, then produce a provisioning plan covering: required FM_HOME isolation and lease; what must be seeded versus inherited; the project clone restrictions; the secondmate harness pin and why it must be pinned; its idle-by-default charter and marked-reply return channel; and the exact pre-launch validation steps.
Also read ${HOME}/data/secondmates.md and report what is currently registered, whether any registered secondmate is live, and whether any home exists on disk.
Do NOT create, seed or launch a secondmate. Produce the plan and the validation checklist only.
Write to ${A}/2026-10-18-secondmate-readiness.md`,
  },
];

return runs.all(steps.map((s) => ({ key: s.id, agent: "worker", model: s.model, task: s.task })));
