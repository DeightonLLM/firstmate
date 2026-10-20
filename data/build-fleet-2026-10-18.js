const HOME = "/home/hd2admin/kun-agent-workspace";
const AUD = `${HOME}/data/audit`;

const RULES = `
GROUND RULES for every execution lane:
- EXECUTE. You are here to make the change, not to describe it. A lane that returns a plan instead of a working result has failed.
- BACKUP BEFORE EVERY MUTATION. Copy the file/config to a sibling with a timestamped .bak suffix and record its path. Never mutate without one.
- VERIFY AFTER EVERY MUTATION with the exact command and its output. Unverified is not done.
- If a step needs authorization you do not have, STOP that step, leave the backup in place, and record exactly what is blocked and what command would unblock it. Do not improvise around a boundary.
- Do NOT contact the Captain. Report to the parent.
- Record every change in ${AUD}/2026-10-18-build-<lane>.md with: what changed, backup path, verification command and output, and anything left blocked.
- Reversible beats clever. Never delete; move aside with a timestamp.`;

const steps = [
  {
    id: "build-core-distro-isolation",
    task: `LANE: REPOINT CORE DISTRO PRODUCTION OFF THE HD2-INTERNAL ENDPOINT. HIGHEST PRIORITY.

Verified live today: the production apex serves a chatbot referencing https://llm.hd2.ai - an HD2-internal service your own policy at ${HOME}/docs/policy/client-infra-isolation.yaml declares not for client use. Staging was already repointed to the client's own instance and is clean; production was missed.

Your job:
1. Read ${AUD}/2026-10-18-isolation-probe.md for the full finding.
2. Establish what the production apex actually serves and where its chatbot configuration lives. Back up every file before touching it.
3. Repoint the production chatbot to the client's OWN instance, matching the corrected staging configuration already deployed. Do not invent a new endpoint - use the one staging already uses successfully.
4. Verify from outside: curl the live apex HTML and confirm ZERO references to llm.hd2.ai or any other HD2-internal host.
5. Re-run ${HOME}/bin/fm-client-infra-isolation-check.sh and confirm core-distro.com now reports OK while other domains are unchanged.
6. Confirm the public chat widget still loads and the embed config endpoint still returns 200.

Do NOT change DNS, do NOT cut over the WordPress production site, do NOT touch anything outside the chatbot configuration. If repointing production requires an authorization you do not hold, prepare the exact change with its backup staged, and record precisely what is blocking it.`,
  },
  {
    id: "build-elevate-auth",
    task: `LANE: CLOSE THE UNAUTHENTICATED ELEVATE INTERNAL CONSOLE.

Confirmed today: the public edge https://agents.elevatesci.com/ returns HTTP 401 with Basic realm "Elevate Operations Console", but the Tailscale-internal service at http://100.69.211.43:8000/ returns 200 with NO www-authenticate header and serves an Excalidraw UI. The public auth wall does not cover it.

Read ${AUD}/2026-10-18-audit-elevate.md and the HD2 verdict at ${HOME}/BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-18-hd2-fm-domain-prds-review-verdict.md first.

Your job:
1. Establish what serves port 8000 on that host and how it is fronted. Back up every config file before changing anything.
2. Determine whether this host is reachable by you. If it is not, do not guess - record exactly what access is missing and what would be needed.
3. If reachable: put it behind an auth wall, or restrict it to loopback or an authenticated Tailscale ACL, matching the pattern HD2 already applied to the public edge.
4. Verify from the untrusted side that it now returns 401 or is non-routable.
5. Confirm the public embed and chat paths still work: /embed/ and /api/embed/ must still return 200, and elevatesci.com must still return 200.

Do NOT weaken the existing public auth wall. Do NOT expose anything new. If you lack host access, say so precisely and prepare the exact remediation as a runnable command instead.`,
  },
  {
    id: "build-observability",
    task: `LANE: GIVE THIS FLEET EYES. Establish real monitoring for the four client domains.

Confirmed today: nothing monitors anything. No Prometheus, Grafana, Uptime Kuma or Alertmanager on any host. No alert reaches a human for any client domain. A real outage would surface to nobody.

Read ${AUD}/2026-10-18-observability-truth.md first.

Your job - build it, do not just recommend it:
1. Set up uptime monitoring for all four client domains: apex and www for core-distro.com, elevatesci.com, whooshperformance.com, cbd-data.com. Check apex, www, HTTP-to-HTTPS redirect, and certificate expiry.
2. The distinction that matters: a dashboard nobody reads is not monitoring, and an alert that pages nobody is not alerting. Make alerts deliver somewhere real and prove delivery works.
3. Watch what the cross-cutting audit flagged as missing: backup age, certificate expiry, and the endpoints currently returning 503 or failing DNS.
4. Document how to read the alerts, where they land, and what a real incident would look like.
5. Verify the monitoring actually detects a deliberately induced failure and then recovers. Prove it works; do not assume it.

Deploy read-only monitoring only. Do NOT modify any client site, DNS, or production service to make monitoring succeed.`,
  },
  {
    id: "build-backup",
    task: `LANE: MAKE BACKUP AND DISASTER RECOVERY REAL AND PROVEN.

The ledger marks backup-dr UNKNOWN OPERATOR_INPUT, and the audit found backup claims conflict with the ledger. No restore drill is proven.

Read ${AUD}/2026-10-18-backup-dr-truth.md and ${AUD}/2026-10-18-audit-cross-cutting.md first.

Your job:
1. Establish what backups actually exist, run on what schedule, and where they land. Back up any config you change.
2. Establish the real RPO and RTO for each client domain. Distinguish measured from aspirational - an unverified RPO is a guess.
3. Execute an actual restore drill into an isolated scratch location. Not a config review. A real restore, verified byte-for-byte, then cleaned up without touching anything live.
4. Report precisely: never-configured, configured-but-never-drilled, or drilled-and-verified. Do not let the first two drift into the third.
5. If backups do not exist for a domain, build the minimum real backup for it and prove one restore.

Never restore over a live system. Never touch production data.`,
  },
  {
    id: "build-cicd",
    task: `LANE: MAKE TESTS ACTUALLY GATE SOMETHING.

Read ${AUD}/2026-10-18-cicd-truth.md first. It established the difference between a test file existing and tests gating anything, and noted 39 failing scripts that remain worker-reported and not accepted.

Your job:
1. Determine what currently runs in CI and what a failure would and would not block.
2. Get the existing test suite to a state where a real failure visibly blocks. Do NOT paper over failing tests by weakening or skipping them - if a test is genuinely wrong, fix it correctly or report why, but never silence it to get green.
3. Wire the four client domains' acceptance checks into something that runs, at minimum on this repo and on any client-facing deploy.
4. Verify by deliberately introducing a failing case and confirming it blocks.
5. Report what genuinely remains un-gated.

Do not weaken any test to obtain a green run. A red suite honestly reported is more valuable than a green one obtained by disabling checks.`,
  },
  {
    id: "build-secondmates",
    task: `LANE: MAKE THE FLEET ACTUALLY PERSISTENT.

Read ${AUD}/2026-10-18-secondmate-readiness.md and ${HOME}/.agents/skills/secondmate-provisioning/SKILL.md in full first.

Confirmed: 7 secondmates are registered in ${HOME}/data/secondmates.md, but only system-ops has a home on disk. The other six were never seeded - no lease was ever taken. None are live. system-ops holds one in-flight backlog item.

Your job:
1. Take a lease and seed the six missing homes properly, following the provisioning skill exactly. Each needs its own FM_HOME with state, backlog, charter and session lock.
2. Do NOT launch them into speculative work. Seed, validate, and leave them idle. A secondmate is idle by default and an empty queue is healthy.
3. Verify each seeded home passes the pre-launch validation checklist from the readiness report.
4. Report which homes now exist, which checks pass, and what remains blocked.

Do NOT invent work for them. Do NOT rewrite the registry. Do NOT retire anything.`,
  },
  {
    id: "build-xmlrpc",
    task: `LANE: CLOSE THE EXPOSED XMLRPC SURFACE ON CORE DISTRO.

HD2 recorded in post-mortem b1849af section 7.2 that xmlrpc.php is exposed on Core Distro production, and that mitigation is a Hostinger/nginx deny rule which was NOT applied because production config was outside lane authority.

Read ${AUD}/2026-10-18-audit-core-distro.md and ${HOME}/BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-18-hd2-fm-domain-prds-review-verdict.md first.

Your job:
1. Verify the current state of xmlrpc.php on the live site yourself - do not take the report's word for it. Measure method, path and response.
2. If it is reachable, prepare and apply the minimal deny rule at whichever layer you can actually control, with a backup first.
3. If the controlling layer is Hostinger-side and you cannot reach it from here, do NOT fake it. Prepare the exact rule, state exactly where it must go, and record what access is missing.
4. Verify after any change that the main site and admin functionality still work.
5. Report whether Core Distro actually uses xmlrpc for anything - a blind deny can break Jetpack, mobile apps and scheduled publishing.

A deny rule that breaks a real client function is a regression, not a fix.`,
  },
  {
    id: "build-ttft",
    task: `LANE: DIAGNOSE THE CORE DISTRO CHAT LATENCY REGRESSION WITHOUT CHEATING.

Recorded: TTFT 847ms against a 500ms SLA. HD2 explicitly constrained this: do NOT resolve it by repointing the widget to llm.hd2.ai - that endpoint is forbidden for client sites and is precisely the dependency that caused the original Next.js/WordPress divergence.

Read ${AUD}/2026-10-18-audit-core-distro.md and ${AUD}/2026-10-18-isolation-probe.md first.

Your job:
1. Measure current TTFT yourself, repeatedly, and establish whether 847ms still holds or has drifted.
2. Isolate where the time goes: client-to-nginx, nginx-to-AnythingLLM, AnythingLLM-to-LLM-provider, and LLM first-token. Measure each hop; do not guess.
3. Identify the actual bottleneck and the smallest legitimate fix inside the client's own infrastructure.
4. Explicitly rule out any fix that routes client traffic through llm.hd2.ai or any HD2-internal service. If no compliant fix exists, say that plainly rather than proposing a forbidden one.
5. Do NOT change production. Produce measured diagnosis and a compliant, minimal, reversible proposal with exact steps and expected gain.`,
  },
  {
    id: "build-whoosh-coords",
    task: `LANE: WHOOSH IS BLOCKED ON MISSING COORDINATES. PREPARE EVERYTHING THAT CAN BE DONE WITHOUT THEM.

Confirmed: data.whooshperformance.com and lc.whooshperformance.com do not resolve at all (curl code=000), NOT 502 as the Captain's v1.0 recorded. The repair is DNS record creation, not upstream configuration. Anything scoped to "fix the 502" is aimed at the wrong layer.

Read ${HOME}/data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md and ${AUD}/2026-10-18-audit-whoosh.md.

Your job:
1. Exhaustively search every readable source on this host for the missing coordinates: the Whoosh repository, Hostinger KVM8 hostname/IP, Hetzner Whoosh service hostname/IP, Namecheap VPS hostname/IP. Report every candidate with its exact source path and line.
2. If ANY coordinate is genuinely found, verify it by direct measurement and report it with the evidence.
3. If none exist, state definitively that they do not exist in any readable source, and produce the exact operator input request listing each missing item, so it can be answered in one pass.
4. Prepare the Phase 0 Gate A-E checklist so implementation can begin the moment coordinates arrive.

Do NOT create DNS records. Do NOT guess or infer a plausible hostname. A fabricated coordinate is worse than a blocked project.`,
  },
  {
    id: "build-cbd-placement",
    task: `LANE: PREPARE THE CBD-DATA PLACEMENT DECISION WITHOUT MAKING IT.

HD2's verdict: cbd-data.com is EVIDENCED, workers run on AminoVPS, and the v3-target Hetzner placement is UNPROVEN. Critically: absence of evidence is not evidence of absence. Gate-004 enrichment cutover is BLOCKED (AUTHORIZATION) and the Namecheap DR target is BLOCKED (OPERATOR_INPUT).

Read ${AUD}/2026-10-18-audit-cbd-data.md and the HD2 verdict first.

Your job:
1. Establish where the CBD workers actually run right now, with measurement, not inference.
2. Establish what would have to be true for a Hetzner placement to exist, and what evidence would prove it does or does not.
3. Produce a decision brief comparing: migrate to Hetzner per the v3 target, versus formally accept AminoVPS as current state. For each, state the cost, the risk, the reversibility, and what is lost either way.
4. State the security and isolation considerations of each, since client data handling differs between them.

Do NOT migrate anything. Do NOT create infrastructure. Produce the brief so the operator can decide in one pass - the decision itself is theirs, not yours.`,
  },
];

return runs.all(
  steps.map((s) => ({ key: s.id, agent: "worker", model: "openai-codex/gpt-6-luna", task: RULES + "\n\n" + s.task }))
);
