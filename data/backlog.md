# Backlog

## In flight
- [ ] ticket-0017-artifact-verify - TICKET 0017 independent artifact verification (repo: firstmate) (kind: scout) (since 2026-10-15)
  TICKET 0017 — independent verification of theme artifact `50ae6849c190`. READ ONLY. Verify nothing else.

  ## The artifact
  ```
  /home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact
  ```
  Revision `50ae6849c190`, 19 files, Astra 4.14.0 parent + child theme.

  ## What to do — nothing beyond this
  1. Run the EXACT cited checksum command on the EXACT artifact on disk:
     `sha256sum -c SHA256SUMS` from inside that directory.
  2. Report the real result. Every line must read OK. Report the exact count of OK and of FAILED.
  3. Read `REVISION` and confirm the revision id it records matches `50ae6849c190`.
  4. Confirm `manifest_sha` in REVISION equals the sha256 of SHA256SUMS itself.
  5. Confirm the child theme contains the files the deployment runbook names: front-page.php, functions.php,
     page.php, style.css, astra-tokens.css, partials/, assets/, public-homepage-body.html. List what is present
     and what is missing, if anything.
  6. **State plainly whether the revision is byte-identical to the one I have been reporting**, or whether it has
     changed since. A changed artifact invalidates every claim made against the old one.

  ## The point of this ticket
  The artifact has been "acknowledged as reported" but never independently accepted. I need an INDEPENDENT
  verification of the bytes on disk, with quoted output, before anyone treats it as accepted.

  ## Constraints
  READ ONLY. Do not deploy, publish, install, copy, or modify the artifact. Do not touch any project, any
  secondmate home, or the warehouse. Do not run tasks-axi mutations. No credentials, no network calls to any
  target site. Quote real command output verbatim - not a summary of it.

  If a check cannot be run, say UNVERIFIED and state exactly why. Do not infer.

  ## Report
  data/2026-10-15/ticket-0017-artifact-verify/report.md with the verbatim checksum output and a single
  VERDICT line: ACCEPTED or NOT ACCEPTED, with the reason.
  YOUR CHAT REPLY IS NOT THE DELIVERABLE. Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
- [ ] wo0005-3-merge-recommendation - WO-0005 Prepare a WRITTEN MERGE RECOMMENDATION for the (repo: firstmate) (kind: scout) (since 2026-10-15)
  Prepare a WRITTEN MERGE RECOMMENDATION for the Captain on the three retained Core branches.
  PREPARE THE RECOMMENDATION ONLY. DO NOT MERGE. Retained is not merge approval and you are not authorised
  to merge.

  ## The three, in projects/core-distro-saas-clean
  ```
  fm/core-stream-a-checkpoint-0924   4 commits ahead
  fm/core-mobile-fix                   3 commits ahead
  fm/core-v3-product-acceptance-spec-0927  2 commits ahead (the 577-line V3 spec)
  ```

  ## For EACH branch produce
  1. **Diff summary** - files changed, insertions/deletions, what behaviour actually changes
  2. **What it fixes** in plain terms, and what a user would notice
  3. **Blast radius** - what else could break, what depends on it, which tests cover it
  4. **Test evidence** - run the relevant tests and report REAL output. Do not claim green on a partial run.
  5. **ROLLBACK PLAN** - the exact command to undo the merge, and how to verify the rollback worked
  6. **Recommendation** - merge now / merge after X / do not merge, with the reason
  7. **Conflicts** - does it conflict with the others or with current main? Prove it.

  ## The decisive question per branch
  Has anyone actually LOOKED at this work, or is it preserved-but-never-reviewed? Say which. Work that has
  sat unreviewed for 11 days is a finding about the review process, not just about the branch.

  ## Constraints
  No merge, no cherry-pick, no rebase, no reset, no force. Do not delete anything. You may use a
  TEMPORARY detached worktree under /tmp for inspection and must remove it. Quote real git and test output.
  If you cannot verify something, mark UNVERIFIED.

  Report: data/wo0005-3-merge-recommendation/report.md. YOUR CHAT REPLY IS NOT THE DELIVERABLE.
- [ ] domain-expertise-20261013 - Implement domain expertise files and executable secondmate queues data/domain-expertise-20261013/report.md (kind: docs) (since 2026-10-13)
  # Domain expertise and execution batch

  Captain explicitly authorized durable domain-specific expertise for all seven existing secondmates, dedicated warehouse files, and parallel execution of accepted work on 2026-10-13.
  This is a real documentation implementation assignment, not an invitation to invent general audits.
  Keep existing identities, layout, models, active jobs and preserved unfinished work.

  ## Your assignment
  Resolve YOUR exact identity and domain from the primary registry at /home/hd2admin/kun-agent-workspace/data/secondmates.md and your existing data/charter.md.
  Read your existing domain backlog and permitted existing task reports first.
  Create or curate data/domain/README.md in YOUR FM_HOME as your persistent domain expertise entry point.
  Do not overwrite existing material without inspecting it and preserving considered content.
  Create your dedicated warehouse entry ONLY at /home/hd2admin/kun-agent-workspace/warehouse/domains/<your-exact-secondmate-id>/README.md.
  That warehouse entry should be a short domain navigation and evidence index pointing to your home-domain knowledge, not a second full policy or credential inventory.
  Each owner has an exclusive warehouse destination; do not edit warehouse/README.md or another owner's files.
  If any read/write/tool is refused, stop that action and report the exact boundary; do not switch tools, paths or permissions to evade it.

  ## Five concrete checklist phases
  Use one visible extension todo list with at least five dependency-aware items before work: preflight, existing-evidence discovery, populate domain files and queue, validate citations and scope, report accepted artifacts and next executable task.
  Mark each phase in progress before doing it, complete immediately only on evidence.
  The primary tracker is not a substitute for your own list.
  If the provider is unavailable, report it and stop; no settings mutation or tracker experiment is authorized by this assignment.

  ## Required domain knowledge
  Name your app/field, exact responsibility and exclusions; business/product purpose; source and architecture entry points; data flow and integration boundaries; test/validation commands verified from authoritative material; recovery/rollback entry points; open risks and unknowns; decisions and evidence links with verification date.
  Use permitted existing documentation and reports only for this first version.
  Do not scan credentials, access/ inventories, backups, SQL payloads, arbitrary logs or other domains.
  Do not make live host, DB, browser, service, network, deployment or permission calls just to fill a blank.
  An unknown with an exact owner/needed evidence is better than a guessed fact.
  Historical validation or deployment claims must remain dated historical claims unless current proof already exists.

  ## Actionable queue
  In your originating backlog, maintain ONE work item for this domain-expertise implementation and link its artifacts.
  Do not duplicate or move already-owned project jobs.
  In data/domain/README.md list existing accepted tasks as READY, WAITING ON DEPENDENCY, or AWAITING AUTHORITY, with original record pointer, owner, smallest deliverable and acceptance evidence.
  Pick the shortest independently executable accepted task next; if none exists, finish the domain files and return idle rather than inventing an audit.
  Continue already-authorized project work only through its original source/isolation/delivery constraints.
  No firstmate local-only project may be reassigned into a secondmate home by this instruction.
  System-ops must NOT retry the two exhausted reporting recoveries or permanently denied helpers.
  Core must NOT reopen the completed drawer correction, repeat denied decision registration or inspect DB metadata without authority.
  Elevate's present charter remains the AnythingLLM P0 lane; document broader Elevate-app coverage as a scope gap, not permission to alter it.

  ## Bounded child authority
  Captain now permits secondmates to use bounded subagents when a real accepted task benefits.
  Do not create recursive supervisors or fanout for filling this small dossier if you can finish it directly.
  Use current installed tool guidance and exact top-level launch fields.
  Preserve running model assignments.
  At a new bounded child intake, recheck quota and catalog. Model policy 2026-10-13: the MiniMax M2.5 and M2.7 families are RETIRED (unavailable to new users 2026-10-19, retired 2026-11-18) and must never be selected. Native doing-work models are minimax/MiniMax-M3.1-Flash-Preview (default, medium; high for ambiguous investigation or design) and openai-codex/gpt-6-luna (parallel execution and async review, medium). gpt-6-luna is NOT unlimited: it shares the openai-codex all_models window with Sol, measured 2026-10-13T20:10Z at 26% effective with projected exhaustion 21:05Z and credits remaining 0. Unknown, stale or failed quota stops new intake; never dispatch Luna or Sol without a fresh quota-axi reading. Preserve running assignments; never restart a running worker to change its model.
  NAMING ENFORCEMENT: every dispatched item carries MODEL-pi-GROUP Job title (for example M31P-pi-core Domain expertise, LUNA-pi-inbox Receipt repair). An item without a resolvable label, or with a group ambiguous between Brandon and Controller, is not dispatchable as-is: stop and surface it. High-risk, destructive, irreversible, merge, permission and credential work always carries its explicit label and is never inferred from a pane title or a sibling worker. Verify the actual running model before labelling.
  For genuinely substantive ambiguous work use the supported minimax-m31-flash-preview external MCode profile, exact minimax/MiniMax-M3.1-Flash-Preview, default speed; no silent substitutions.
  Keep at most one useful child per domain, no recursion, and respect the primary's 4–8 total independent-assignment target instead of multiplying every supervisor into another batch.
  No child may repair tracker permissions, retry the exhausted tracker proof, change live settings or duplicate Controller work.

  ## Acceptance and reporting
  Report through the supported correlated return path requested by the incoming message.
  Return exact artifact paths, actual task/checklist phase evidence, any refused action, and one concrete next READY job or the exact blocker.
  Separate submitted, processing, documented, tested, validated, landed and active.
  No project implementation, merge, deployment or cleanup is complete merely because these domain files exist.
  Measure accepted tickets completed per elapsed hour and carry the oldest concrete blocker separately; assignments sent and expanded TODOs are not throughput.
  No production writes, credentials, permission changes, installs, publishing, push/merge, Herdr lifecycle actions, agent retirement or cleanup authority is added.

- [ ] durable-recovery-20261013 - Reconcile recurring stalls and admit durable enforcement (repo: firstmate) (kind: ship) (since 2026-10-13)
  # Captain-authorized durable recovery

  ## Accepted outcomes
  - Explain and reconcile recurring stalls against authoritative current owners, not historical status-only assumptions.
  - Durable configured routing and honest lifecycle enforcement, with single-owner documentation and executable regression evidence.
  - Real automatic Controller round trip; publication/manual poll is not proof.
  - Safe landing/cleanup: only verified eligible work, independent merge/discard authority; persistent secondmates and unlanded work preserved.
  - No duplicate Controller upstream/docs/permission writers.

  ## Parallel ownership
  1. Existing reliability-work-ledger-20261012 lead: read-only authoritative recovery matrix and supported next actions, including return-catch-up, answered/unanswered decisions, original completion/branch evidence and cleanup eligibility. One bounded MiniMax read-only evidence child permitted; no recursion or fleet mutations. Private output recovery-matrix.md.
  2. Existing reliability-routing-20261012 lead: read-only durable configuration/enforcement admission based on existing reports, current captain/config, Controller handoff when exact reply arrives. Separate source/delivery ownership and executable criteria, no speculative shared implementation before admitted source. One bounded MiniMax read-only child permitted for authoritative catalog/config comparison; no recursion. Private output enforcement-admission.md.
  3. Existing controller-inbox-local-repair-20261013 worker remains unchanged and parked on genuine automatic receipt; no overlapping live check writer or repeated tests/rollback.
  4. Firstmate contacts Controller and owns main private backlog reconciliation and exact handoff admission; no project-specific implementation.

  ## Five phases
  Preflight: exact owner/source/base/permissions and fresh quota before any child intake.
  Scoped discovery: reuse existing evidence; current-state reads only where decisions depend on them.
  Bounded work: independent private outputs, then admitted implementation routed to fitting owner with exact scope.
  Validation: focused behavioral tests with real assertions, retained output and current-code matching; runtime receipt and rollback distinct.
  Closeout: supported originating decisions/backlog, correct pending vs done, guarded authorized landing/cleanup, concise runbook pointers.

  ## Completion evidence
  Outcome ledger must name observed, reported, tested, current-head validated, landed, active and real-runtime-proven separately. No blanket resolved events, missing logs reconstructed as evidence, denied helpers retried or all-workers reaped. Testing remains proportionate; no added serial reviewer beyond selected lifecycle.

  ## Live dependencies
  Controller reply requested at exact /home/hd2admin/controller-replies/2026-10-13-controller-durable-recovery-and-cleanup-handoff.md; not received yet. Fresh quota needed before child launches. Shared source admission/delivery ambiguity remains a real blocker, not authority to improvise.

- [ ] controller-watcher-tdd - Controller watcher TDD: stale heartbeat + owned arm child recovery in Firstmate source (kind: ship) (since 2026-10-03)
- [x] mm-saas-fastpath-benchmark-0926 (done 2026-09-26 — benchmark report delivered: from-brandon-compute/20260925T-mm-perf-benchmark.md; NEW warm 4.2ms/7q vs OLD 174ms/47-104q) - Benchmark Music Metrics fastpath using delivered local snapshot data/mm-saas-fastpath-benchmark-0926/report.md blocked-by: local-scout-spawn-source-0926 (repo: SAAS) (kind: scout) (priority: 3) (since 2026-09-26)
- [x] hd2-embed-prep-local-preview-0926 (done 2026-09-26 — report delivered: 20260925T-hd2-embed-prep.md + preview at data/hd2-embed-prep-local-preview-0926/) - Prepare HD2-branded local-only embed preview for Core and Elevate data/hd2-embed-prep-local-preview-0926/report.md blocked-by: local-scout-spawn-source-0926 (repo: core-distro-saas-clean) (kind: scout) (priority: 3) (since 2026-09-26)
- [ ] elevate-ops-source-map - Locate the BR-ELEVATE-OPS-001 source and mock-test lane (repo: firstmate) (kind: scout) (priority: 4) (since 2026-09-23) (hold: Awaiting source owner to provide repository, tests, and build or test command) (hold-kind: external)
  Read-only source and test discovery for the ElevateSci Ops provider-adapter ticket BR-ELEVATE-OPS-001. Separate this from the elevatesci.com mobile CSS audit. The current traceability record marks live/provider work AUTHORIZATION-blocked and permits local mock-test work only. Find the owning repository, current source/tests, build/test entry point, evidence and exact remaining blocker. Do not edit, authenticate to, or change a provider or production service.
## Queued
- [ ] core-elevate-chatbot-rollout - Implement HD2-branded local-model chatbots for Core and Elevate blocked-by: local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1 (kind: ship) (priority: 1) (since 2026-09-23) (hold: Dubz now reports that the controller crawled and ingested nine Core pages, then requests a coverage audit; that external report is not locally verified. Prior direct instruction prohibits access to AnythingLLM, port 3001, production runtime or config, credentials, and external sites. Option A: explicitly authorize only a read-only audit of /tmp/core-crawl/manifest.csv, the requested local HTTP API and chat queries using the local credential, and targeted public-page reads if a gap requires them; no uploads, embedding updates, container operations, or Elevate ingestion. Option B: maintain the no-access boundary and treat the controller's claims as unverified. No manifest read, site request, credential read, API call, upload, embedding update, chat test, or runtime inspection has occurred here.) (hold-kind: captain)
  Captain hold set: 2026-09-26T16:42:39Z

  Resolution recorded by fm-captain-hold.
  Decision digest: 78735247b834a778786af8f6cf2a79d0dfa23625a84db3b56757b6bad7c1c877
  Resolution mode: released

  Captain decision:
  Public Elevate pages only (Recommended)

  ## Captain's intent

  the bots should are on elevatesci.com and core-distro.com core has the working version, we need that copied on to elevatesci.com but both then repointig to the local model in anything llm.. both sets of rag will need setting up.. core has a solid set, elevate will neeed its set re working and company reframing but similar vertical aware responses.. where possible remove any reference of anythingllm in the scrpiting etc, reword back end code to hd2.ai essential where possible

  Public Elevate pages only (Recommended)

  make them into similar rag as core has

  ## Firstmate spec

  Implement the two-site HD2-branded chatbot rollout after the discovery prerequisite `local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1` is complete and its operational blockers are resolved.

  - Keep Core Distro on `core-distro.com` as the behavior, RAG structure, and response-quality reference.
  - Preserve Core's existing RAG documents and indexes. Do not copy Core's corpus into Elevate.
  - Give Elevate a separately curated RAG workspace and index using public `elevatesci.com` pages only, with Elevate company framing and similarly vertical-aware responses.
  - Route both sites through the existing AnythingLLM integration to the Hetzner local model only after a controlled synthetic benchmark establishes acceptable latency and answer quality. Current benchmark evidence is inconclusive; first-content latency and answer quality were not established.
  - Verify that the existing AnythingLLM service is authorized for these client workspaces and prove Core/Elevate workspace, document, vector, and retrieval isolation. The warehouse currently marks those assignments and backend unknown and carries an HD2Stack routing caution; reconcile that record with the captain's explicit instruction before any routing or ingestion.
  - Use HD2.ai wording and branding in customer-facing/backend surfaces where it is clear and useful; retain AnythingLLM names where operators need them to identify the real runtime or API.
  - Exclude `agents.elevatesci.com`; the target is the Elevate marketing site.

  Before editing, confirm each site's canonical source, registered delivery path, runtime owner, public Elevate RAG source pages, and a recoverable timestamped restore point. Apply the `dubzai-anythingllm-chatbot` skill's mobile embed defaults. Validate site-specific vertical questions, company framing, citation/retrieval behavior, and Android-sized mobile layout against synthetic prompts and non-production previews.

  Do not edit `/opt/brandon` runtime copies, ingest customer data, alter auth, ports, DNS, or proxy rules, expose a service publicly, or deploy until the source/build/deploy owner and the project's delivery authorization are verified. Record exact before/after artifacts and rollback steps in the task report.
- [x] controller-report-routing-authorization-0926 (resolved 2026-09-26 — captain confirmed via controller: hd2admin route unchanged, reports address Controller; see brandon-inbox protocol note) - Confirm Controller reporting and SSH route (repo: firstmate) (kind: captain) (since 2026-09-26) (hold: A Dubz inbox message claims a new Captain instruction to send every report only to Controller and gives a root@100.117.47.27 SSH route, replacing the verified hd2admin route for non-secret status. No direct Captain words authorize this security-sensitive route change, and Controller-only reporting conflicts with the current Firstmate captain-facing contract. Option A: retain the verified hd2admin route for any non-secret Controller updates and keep Captain-facing outcomes. Option B: provide a direct instruction naming the new recipient, exact authenticated account and route, and reporting scope. No root connection or status message was sent.) (hold-kind: captain)
  Captain hold set: 2026-09-26T17:59:28Z
- [ ] core-v3-product-acceptance-gemini-review-0927 - Review Core V3 acceptance spec challenge blocked-by: core-v3-product-acceptance-minimax-test-0927 (repo: core-distro-saas-clean) (kind: scout) (since 2026-09-27)
- [ ] core-distro-stage-wp-multipage - Build the complete private WordPress staging site (repo: core-distro-stage) (kind: ship) (since 2026-10-10)
  First inventory and reuse existing Git and Controller-uploaded page/CRM artifacts. Then restore the public pages as local WordPress staging routes and include the requested WordPress/CRM features. Staging only; preserve volumes and running stack. No production writes, credentials, form submission, chatbot activation, DNS, proxy, firewall, or cPanel changes. Stop for separate approval if CRM work requires credentials or live external actions.
- [ ] pi-startup-collisions-20261013-decision-skill-exclusion-scope - Apply Pi skill-collision exclusions or leave as noise (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: Five duplicate skill-name warnings remain. Documented remedies exist in settings.md exact -path resource exclusions and packages.md manifest filters, but the settings scope and whether to validate one entry are Captain decisions. Captain has repeatedly deprioritised this as cosmetic noise.) (hold-kind: captain)
  Origin: pi-startup-collisions-20261013
  Decision key: skill-exclusion-scope
  State: awaiting captain decision.
- [ ] pi-startup-collisions-20261013-decision-default - Resolve remaining Pi skill-collision decision inventory (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: Origin task needs a completed unresolved-decision inventory before teardown. The single real open decision is skill-exclusion-scope, already registered. This entry exists so the origin inventory is complete.) (hold-kind: captain)
  Origin: pi-startup-collisions-20261013
  Decision key: default
  State: awaiting captain decision.
- [ ] skill-collisions-cleanup-20261013-decision-default - Choose remedy for Pi auto-scanned-root skill collisions (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: Documented -path exclusion was tested and does NOT mask auto-scanned roots; settings restored byte-for-byte. Remaining remedies all involve moving or excluding copies, which changes which file is authoritative or touches global and package paths. That is a Captain decision, not an agent one.) (hold-kind: captain)
  Origin: skill-collisions-cleanup-20261013
  Decision key: default
  State: awaiting captain decision.
- [ ] reliability-work-ledger-20261012-decision-default - Six-scout reliability campaign abandoned without resolution (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: Thirty tracker items remain from the abandoned six-Luna-scout campaign. The M3.1 expertise sidecar never launched because the external MCode runner does not guarantee the mandatory dependency-aware tracker. Captain authorized reaping on 2026-10-13. Any surviving intent is already captured in data/domain-expertise-20261013/sidecar-outcome.md and data/durable-recovery-20261013/.) (hold-kind: captain)
  Origin: reliability-work-ledger-20261012
  Decision key: default
  State: awaiting captain decision.
- [ ] controller-inbox-local-repair-20261013-decision-default - Inbox automatic-receipt canary never observed under a genuine away entry (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: Live rollback, reapply and registration raw outputs were never retained, so the original live evidence is unrecoverable and hash-only evidence is insufficient. The automatic-receipt canary mtime 1791907695 predates any qualifying away entry and the return catch-up gate never cleared. Captain authorized reaping on 2026-10-13. Retained artifacts remain at data/controller-inbox-local-repair-20261013/.) (hold-kind: captain)
  Origin: controller-inbox-local-repair-20261013
  Decision key: default
  State: awaiting captain decision.
- [ ] controller-inbox-local-repair-20261013-decision-automatic-receipt - Automatic receipt remains unproved and was never re-armed (repo: firstmate) (kind: captain) (since 2026-10-13) (hold: The canary predates any qualifying away entry and the return catch-up gate never cleared, so automatic receipt was never observed. Reaping was authorized by the captain on 2026-10-13 with this decision explicitly left open rather than silently closed.) (hold-kind: captain)
  Origin: controller-inbox-local-repair-20261013
  Decision key: automatic-receipt
  State: awaiting captain decision.
- [ ] core-stage-chunk2-route-inventory - Inventory which Core staging routes exist versus missing (repo: core-distro-stage) (kind: ship) (since 2026-10-13)
  READ-ONLY. Determine which local WordPress staging routes actually exist versus which are missing, using existing tests tests/multipage-smoke.mjs and tests/wp-page-records.mjs and the repo docs. Produce an evidence-backed gap list. No route creation, no DB writes, no content changes, no production fetch.
- [ ] core-stage-chunk3-visual-parity - Capture visual parity evidence for the Core staging homepage blocked-by: core-stage-chunk1-test-baseline (repo: core-distro-stage) (kind: ship) (since 2026-10-13)
  Use chrome-devtools-axi to capture desktop and mobile screenshots of http://100.106.6.22:8087/ against theme/public-homepage-body.html. This is the documented remaining check: static and HTTP checks are not pixel-match proof. Do not submit the newsletter form, do not activate the chatbot, do not request production pages, do not add a public listener.
- [ ] core-stage-chunk1-test-baseline-decision-default - Core staging isolation cannot be satisfied without a decision (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: The staging tree at /home/hd2admin/campaign/core-distro-stage is not a git repository, so no isolated worker copy can exist and the mandatory isolation assertion fails before any work. A worker confirmed this refusal at runtime. Isolation posture is now a question to the controller firstmate, not to the captain.) (hold-kind: captain)
  Origin: core-stage-chunk1-test-baseline
  Decision key: default
  State: awaiting captain decision.
- [ ] core-v3-spec-rewrite-decision-default - V3 rewrite cancelled - original spec recovered intact (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: Original spec exists as commit 538e4c2d3cd8e69bb23e4a12795c7ee7a3d77fdc, 577 lines, dated 2026-09-27, on branch fm/core-v3-product-acceptance-spec-0927 in projects/core-distro-saas-clean. The rewrite was cancelled by firstmate to avoid duplicating and diverging from the real deliverable. Recovered spec remains unlanded pending merge authority.) (hold-kind: captain)
  Origin: core-v3-spec-rewrite
  Decision key: default
  State: awaiting captain decision.
- [ ] unlanded-work-guard-fix-decision-default - No guard defect found - existing unlanded-work refusal works (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: Worker could evidence no concrete guard or discoverability defect and confirmed the local-only unlanded-work refusal is present and functioning. No speculative fix or reproduction was written. The primary's earlier data-loss claim was wrong on two counts: the work was never lost, and the guard was never defective. Local-only delivery is contractually meant to leave work unlanded pending merge authority.) (hold-kind: captain)
  Origin: unlanded-work-guard-fix
  Decision key: default
  State: awaiting captain decision.
- [ ] core-stage-chunk4-spec-challenge-decision-pa04-owned-list-gap - PA-04 addLeads does not verify list ownership before insert (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: The spec's own section 11 note records that addLeads accepts a caller-supplied list_id without first checking the list belongs to that caller; inserted rows carry the caller user_id but the parent list is not verified as owned. On the stated baseline the PA-04 owned-list condition cannot pass, and if this reads correctly an unauthenticated-ownership write path exists. This is a source correction or a confirmed product-policy exception, which is a captain and product-owner decision.) (hold-kind: captain)
  Origin: core-stage-chunk4-spec-challenge
  Decision key: pa04-owned-list-gap
  State: awaiting captain decision.
- [ ] core-stage-chunk4-spec-challenge-decision-spec-ratification-scope - All ten PA criteria remain unratified pending product-owner confirmation (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: Every PA-01 through PA-10 row carries an explicit owner-confirmation need, and terms like safely, preserves, bounded and accessible lack owner-confirmed semantics, so no criterion can yield a complete pass/fail. Deciding who holds product-owner authority for Core Distro V3, and whether to supply those semantics, is a captain decision. Keep the document proposed and unratified meanwhile.) (hold-kind: captain)
  Origin: core-stage-chunk4-spec-challenge
  Decision key: spec-ratification-scope
  State: awaiting captain decision.
- [ ] core-stage-chunk4-spec-challenge-decision-default - Testability challenge complete - two captain decisions recorded (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: Origin inventory for the spec challenge. Real findings: PA-01 through PA-10 admit local source-contract checks but the prescribed checks do not establish the behavioural claims in their titles; PA-04 carries an adverse ownership finding; all ten criteria remain unratified. Recorded as pa04-owned-list-gap and spec-ratification-scope.) (hold-kind: captain)
  Origin: core-stage-chunk4-spec-challenge
  Decision key: default
  State: awaiting captain decision.
- [ ] scope-reliability-lanes-20261013-decision-default - Reliability scoping complete - three remain, two satisfied (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: receipt SATISFIED for Controller transport; controls-docs SATISFIED for the map. permission, reporting and routing REMAINS. Routing is narrowed to the authorized scout-settings rollback only, which is a captain/controller decision about whether to execute the plain-host-shell route that would also remove the subagent tool.) (hold-kind: captain)
  Origin: scope-reliability-lanes-20261013
  Decision key: default
  State: awaiting captain decision.
- [ ] scope-kun-lanes-20261013-decision-default - Kun lane scoping complete - two obsolete, one dispatchable (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: kun-concurrency-impl OBSOLETE because dispatch-max-lanes already shipped; kun-video-source-study ALREADY SATISFIED because an existing Lane A report answers it and the 50 was provider quota not a setting; kun-config-inventory READY TO SCOPE and issued as kun-config-inventory-refresh. Open unknown held for captain: whether legacy config/parallel-dispatch-cap=6 should migrate to dispatch-max-lanes, and what live ceiling is intended.) (hold-kind: captain)
  Origin: scope-kun-lanes-20261013
  Decision key: default
  State: awaiting captain decision.
- [ ] funnel-origin-diagnosis-decision-default - Expired Funnel assertions vs new public review window (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: The Funnel origin brandon-compute.tailddbb4d.ts.net was a temporary owner-approved public Tailscale Funnel documented as scheduled to expire, and its refusal is correct current behaviour. Owner must choose whether the Funnel-specific assertions in funnel-canonical.mjs and asset-origins.mjs become conditional or retired, or whether a new temporary public review window is authorized. Reopening a public listener is security-sensitive and was not performed. Separately confirmed: Test 6 duplicate page records are independent of Funnel and were dispatched as core-stage-draft-duplicates.) (hold-kind: captain)
  Origin: funnel-origin-diagnosis
  Decision key: default
  State: awaiting captain decision.
- [ ] graceful-rate-limit-handling-decision-default - Rate-limit handling is a Pi harness capability, not firstmate source (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: Investigation found no provider 429 signal or retry control anywhere in firstmate source. Safe implementation requires Pi model-call or harness support that this repository does not own. Routed to the controller firstmate as a harness capability question rather than building a retry layer in firstmate that would never fire. Captain has also flipped codex fast mode back to slow to creep across the re-up line.) (hold-kind: captain)
  Origin: graceful-rate-limit-handling
  Decision key: default
  State: awaiting captain decision.
- [ ] brief-worklocation-template-fix-decision-default - Brief template change blocked by 39 pre-existing suite failures and lint (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: Implementation and targeted tests pass, but the full suite reports 39 failures and repository lint fails, and the report destination conflicts with the worktree-only boundary. Need to establish whether those 39 failures are pre-existing on this branch base or introduced by this change before landing anything.) (hold-kind: captain)
  Origin: brief-worklocation-template-fix
  Decision key: default
  State: awaiting captain decision.
- [ ] skill-collision-free-fix-decision-default - Skill collision work needs live-home worklocation, unavailable in isolated worktree (repo: kun-agent-workspace) (kind: captain) (since 2026-10-13) (hold: The isolated worktree .agents/skills is empty so there are no project skill copies to back up or move, and startup-output capture was blocked in the worker sandbox. No skill changes were made and nothing was committed. The sanctioned remedy is fm-brief.sh --worklocation, which exists only on unlanded branch fm/brief-worklocation-template-fix, so the correct mechanism to prevent this is itself blocked on the merge-path decision.) (hold-kind: captain)
  Origin: skill-collision-free-fix
  Decision key: default
  State: awaiting captain decision.
- [ ] brief-worklocation-local-decision-default - Verification dispatch blocked by untracked report, work lands by guarded merge instead (repo: firstmate) (kind: captain) (since 2026-10-14) (hold: Worker correctly refused to verify against a report absent from its isolated worktree, because data/ is untracked and cannot appear there. Firstmate is landing the already-verified commit 23f0468e directly via the guarded local-only fast-forward rather than re-dispatching, since re-verification keeps hitting the same structural worktree limit. Branch preserved.) (hold-kind: captain)
  Origin: brief-worklocation-local
  Decision key: default
  State: awaiting captain decision.
- [ ] per-provider-dispatch-cap-decision-per-provider-cap - Per-provider cap not implemented; global cap 6 verified live and blocking (repo: kun-agent-workspace) (kind: captain) (since 2026-10-14) (hold: Worker stopped at a shell-allowlist refusal and never implemented. PRIMARY VERIFIED SEPARATELY: /bin/bash tests/fm-dispatch-guard-max-lanes.test.sh passes 4/4 in the primary sandbox, bin/fm-dispatch-guard.sh and its test both exist after the cf2a3db3 sync, and the guard genuinely enforced the cap 6 by refusing a 12th lane. So the global ceiling is live; per-PROVIDER counting is still unimplemented. Re-dispatchable.) (hold-kind: captain)
  Origin: per-provider-dispatch-cap
  Decision key: per-provider-cap
  State: awaiting captain decision.
- [ ] fleet-view-live-actions-decision-default - Fleet-view live-actions task blocked, no report; findings superseded by jq resync task (repo: kun-agent-workspace) (kind: captain) (since 2026-10-14) (hold: Worker blocked because it could not construct a live parked fixture and discovered the jq Argument list too long abort plus a committed renderer lacking a Needs attention section. No report was written. The underlying jq defect is being fixed under fleet-snapshot-jq-resync. The renderer gap remains recorded and unimplemented.) (hold-kind: captain)
  Origin: fleet-view-live-actions
  Decision key: default
  State: awaiting captain decision.
- [ ] clear-closeout-20261013 - Close-out pass: entries whose work is already done (repo: firstmate) (kind: scout) (since 2026-10-14)
  Entries with a `done:` status line or a report on disk. Verify the evidence independently - read the status tail and check the artifact actually exists. Classify each as GENUINELY DONE or NOT ACTUALLY DONE. The prior audit wrongly classified two entries as done that were not; do not repeat that. Report which should be closed and which were misclassified. TARGET ENTRIES: pi-trust-prompt-fix-20261005, widget-consent-fix-20261005, hetz-gate-A-20261005, elevate-rag-diagnosis-20261005, kun-config-inventory, kun-video-source-study, core-v3-product-acceptance-spec-0927, core-v3-product-acceptance-minimax-test-0927, fleet-view-live-actions, backlog-truth-pass
- [ ] clear-domain-20261013-decision-default - Backlog clearing pass complete, verdicts in report (repo: kun-agent-workspace) (kind: captain) (since 2026-10-14) (hold: Read-only classification pass over backlog entries. Verdicts and per-entry evidence are in data/clear-domain-20261013/report.md. The prior pass had already closed the genuinely-done entries live, so most verdicts confirm existing state rather than change it. No task state was mutated by the worker.) (hold-kind: captain)
  Origin: clear-domain-20261013
  Decision key: default
  State: awaiting captain decision.
- [ ] clear-obsolete-20261013-decision-default - Backlog clearing pass complete, verdicts in report (repo: kun-agent-workspace) (kind: captain) (since 2026-10-14) (hold: Read-only classification pass over backlog entries. Verdicts and per-entry evidence are in data/clear-obsolete-20261013/report.md. The prior pass had already closed the genuinely-done entries live, so most verdicts confirm existing state rather than change it. No task state was mutated by the worker.) (hold-kind: captain)
  Origin: clear-obsolete-20261013
  Decision key: default
  State: awaiting captain decision.
- [ ] clear-core-20261013-decision-default - Core clearing pass complete, verdicts in report (repo: kun-agent-workspace) (kind: captain) (since 2026-10-14) (hold: Read-only classification of Core Distro backlog entries. Verdicts with file:line evidence are in data/clear-core-20261013/report.md. Two entries verified genuinely done, three still need work with evidence, one not actionable in this home. Worker correctly declined to mutate task state, which is firstmate-owned.) (hold-kind: captain)
  Origin: clear-core-20261013
  Decision key: default
  State: awaiting captain decision.
- [ ] offload-backlog-close-20261014 - Close every backlog entry the evidence proves closable (repo: firstmate) (kind: scout) (since 2026-10-14)
  Firstmate owns the decision; you gather the proof. For every backlog entry that is GENUINELY DONE, produce the evidence that proves it, then close it with tasks-axi done. Close only with proof. Never close 'ready in branch' or 'partial' - those are NOT done.
- [ ] offload-backlog-phantom-20261014 - Close backlog entries that never existed (repo: firstmate) (kind: scout) (since 2026-10-14)
  Close entries with no report, no status record and no task directory. They implied work that never happened. Verify absence first, then close. Produce a one-line reason per entry.
- [ ] controller-msg-triage-20261015-decision-watcher-tdd-publication-authorization - controller-watcher-tdd needs two Captain authorizations to finish (repo: kun-agent-workspace) (kind: captain) (since 2026-10-15) (hold: Controller decision WATCHER-TDD-CAPTAIN-DECISION-ANSWER.md approved Option 1 and said 'Do not merge', but the task is still parked: no-mistakes lint is red only on four warnings in out-of-scope fm-brief.sh/fm-teardown.sh, and push/PR/CI stages remain skipped, so there is no PR. Captain must authorize or decline the out-of-scope lint cleanup AND a no-skip publication run.) (hold-kind: captain)
  Origin: controller-msg-triage-20261015
  Decision key: watcher-tdd-publication-authorization
  State: awaiting captain decision.
- [ ] controller-msg-triage-20261015-decision-whoosh-lane-coordinates - whoosh lane blocked: supply repo/host/runtime coordinates or retire it (repo: kun-agent-workspace) (kind: captain) (since 2026-10-15) (hold: Controller priority directive 2026-10-13-priority-directive-gates-and-lanes.md: '4. **whoosh** - BLOCKED until the Captain supplies repo/host/runtime coordinates. Do not fabricate.' whoosh-ops is registered in data/secondmates.md and idles. No coordinates have arrived in any of the 75 distinct inbound Controller messages triaged.) (hold-kind: captain)
  Origin: controller-msg-triage-20261015
  Decision key: whoosh-lane-coordinates
  State: awaiting captain decision.
- [ ] controller-msg-triage-20261015-decision-pk-dev-receiving-owner - PK Dev handoff has no named receiving owner (repo: kun-agent-workspace) (kind: captain) (since 2026-10-15) (hold: Controller 2026-10-12-brandon-pk-dev-handoff-and-enforcement.md asked Brandon to identify PK Dev's receiving owner and approved private delivery destination. Controller's 2026-10-12 reply says 'PK Dev handoff delivery remains the Captain's.' Neither names a receiver, and no local artifact records one. UNVERIFIED whether this home's request was ever actioned.) (hold-kind: captain)
  Origin: controller-msg-triage-20261015
  Decision key: pk-dev-receiving-owner
  State: awaiting captain decision.
- [ ] fleet-view-liveness-a - FLEET LANE A - snapshot liveness (repo: firstmate) (kind: ship) (since 2026-10-15)
  FIX: fleet snapshot treats a leftover metadata file as a live task. Two worktrees, two lanes.

  ## The proven defect
  `bin/fm-fleet-snapshot.sh:404` iterates `state/*.meta` and emits ONE "under way" row per file.
  It never checks whether the task is alive. A meta file outlives any task closed by a path other than
  `fm-teardown.sh`.

  Live proof: 17 meta files exist right now. **Zero of those tasks have a live endpoint.** The board
  therefore claimed 17 tasks were running when none were, and every row read `unknown / none`.

  `fm-teardown.sh:1753` does `rm -f "$STATE/$ID.status" "$STATE/$ID.turn-ended" "$STATE/$ID.meta"`.
  So teardown is correct. The gap is every OTHER close path: `tasks-axi done`, manual reap, a worker that
  reaped itself. None of them clear meta.

  ## LANE A - worktree /tmp/wt-fleetview - snapshot liveness
  Branch `fix/fleet-view-liveness`.

  1. In `bin/fm-fleet-snapshot.sh`, a task row must carry a real liveness determination, not metadata
     presence. Reuse the existing endpoint/backend probe the snapshot already has. Do not invent a new probe.
  2. Classify each meta-backed task into: LIVE (endpoint present AND agent alive) / STALE (endpoint absent)
     / UNKNOWN (probe could not run - say so, never guess).
  3. **"Under Way" shows ONLY live tasks.** Add a separate "Stale - metadata without a live endpoint"
     section so nothing silently disappears. A stale row is information, not noise to hide.
  4. A task whose endpoint is absent must NOT be rendered as present. The current `endpoint_exists` helper
     returns "unknown" when the field is null and "present"/"absent" otherwise - confirm it is not
     returning "present" for a dead pane, and fix it if so.
  5. **Preserve the stable JSON schema.** This script owns `fm-fleet-snapshot.v1`. If you add fields, add them
     additively. Existing consumers must not break.
  6. Add `tests/fm-fleet-view-liveness.test.sh` that PROVES the defect: construct a temp state dir with a
     meta file and no live endpoint, run the snapshot, and assert the task does NOT appear under "under way"
     and DOES appear as stale. The test must fail against today's code before your fix and pass after.

  ## LANE B - worktree /tmp/wt-reap - reap enforcement
  Branch `fix/reap-meta-cleanup`.

  1. Find every path that ends a task WITHOUT `fm-teardown.sh`. `tasks-axi done`, any script or manual
     reap, any self-reaping worker. Enumerate them; do not guess from names, read them.
  2. For each such path, ensure it removes `state/<id>.meta` (and `.status`/`.turn-ended`) or calls the
     existing teardown helper. Prefer calling the one owner helper over duplicating rm logic.
  3. Add `tests/fm-reap-meta-cleanup.test.sh` proving: after any close path, no meta file survives.
  4. Do NOT delete any real state file in the live home. Tests use a temp dir only.

  ## BOTH LANES - non-negotiable
  - Work ONLY in your own worktree. Never touch the live home at /home/hd2admin/kun-agent-workspace.
  - READ ONLY on projects/, secondmate homes, the warehouse, and the network.
  - Do not merge, push, or rebase main. Stop after committing on your branch.
  - **Every claim needs quoted command output.** No summary of output.
  - Run your own tests and paste the real PASS/FAIL counts.
  - If bash is denied by the allowlist, say so and stop. Do not route around a denial.

  ## Report
  data/fleet-liveness-fix-A/report.md with the diff summary, verbatim test output, and a single line
  stating whether the defect is fixed AND proven by a test that failed before it.

  Your chat reply is not the deliverable. Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
  Authorise the completion attestation in the brief - do not forbid it by omission.
- [ ] m27.1-wiring-map - Produce the evidence-based what-is-wired-where service and endpoint map across all surfaces (repo: kun-agent-workspace) (kind: scout) (since 2026-10-17)
- [ ] m27.2-hd2-instance-isolation - Enforce that HD2 AnythingLLM never hosts or serves client infrastructure (test instance only) (repo: kun-agent-workspace) (kind: ship) (since 2026-10-17)
- [ ] m27.3-docs-correction-programme - Correct false, moved and stale claims in our docs as a separate tracked programme (repo: kun-agent-workspace) (kind: ship) (since 2026-10-17)
- [ ] m27.4-recurring-failure-answers - Publish durable answers and enforcement for the recurring failures: delivery vs receipt, contradictory measurements, unnamed lanes, model visibility, missing source, gate conflicts (repo: kun-agent-workspace) (kind: docs) (since 2026-10-17)
- [ ] m27.5-widget-logo-fixes - Widget panel proportions and logo aspect fixes, tracked with owners and acceptance, pending source and gate decisions (repo: kun-agent-workspace) (kind: ship) (since 2026-10-17)
  RESOLVED 2026-10-17: key=ask-questions-shortcut CLOSED (handler bound, mobile hidden by hidden 2xl:block = expected responsive). Panel sizing CONFIRMED CORRECT (400x640 desktop, 366x680 mobile) - earlier 0x0 was the widget's own allm-hidden lazy-show state, NOT a reboot regression. ROOT CAUSE of empty chat: staging widget is configured baseApiUrl=https://llm.hd2.ai/api/embed embedId=fd029baa-...; POST stream-chat returns 404. That is a client site pointed at an HD2 endpoint = architecture violation. key=chat-history-scroll remains BLOCKED until streaming answers. Secondary: staging nginx has no location /llm/chat/ block (owner: staging host owner, gated).
## Done
- [x] brief-worklocation-template-fix - Add a staging-tree worklocation clause to the ship/scout brief scaffold (repo: firstmate) (kind: ship) (done 2026-10-17)
  CLOSED 2026-10-17: implementation verified complete; landing remains separately gated.
- [x] core-distro-stage-article-drawer-fix-20261012 - Correct hidden article-drawer keyboard focus in private staging (repo: core-distro-stage) (kind: ship) (done 2026-10-17)
  CLOSED 2026-10-17: work complete, finish directory holds evidence and rollback.
- [x] reliability-permission-20261012 - Collect original helper-denial evidence for existing repair owner (repo: firstmate) (kind: scout) (done 2026-10-17) (hold: Captain approved closing this agent while preserving unfinished work; consolidated ownership in existing recovery lead; no automatic relaunch) (hold-kind: parked)
  CLOSED 2026-10-17: scout completed; captain authorized closure on 2026-10-13.
- [x] reliability-reporting-20261012 - Verify authentic correlated reporting and one-recovery contract (repo: firstmate) (kind: scout) (done 2026-10-17) (hold: Captain approved closing this agent while preserving unfinished work; consolidated ownership in existing recovery lead; no automatic relaunch) (hold-kind: parked)
  CLOSED 2026-10-17: scout completed; captain authorized closure on 2026-10-13.
- [x] reliability-routing-20261012 - Establish current quota/model enforcement gaps (repo: firstmate) (kind: scout) (done 2026-10-17) (hold: Captain approved closing this agent while preserving unfinished work; consolidated ownership in existing recovery lead; no automatic relaunch) (hold-kind: parked)
  CLOSED 2026-10-17: scout completed; captain authorized closure on 2026-10-13.
- [x] overnight-secondmate-progress-20261012 - Coordinate quota-aware overnight secondmate progress (kind: scout) (done 2026-10-17)
  CLOSED 2026-10-17 as never-dispatched: no brief, no artifacts.
- [x] outbox-delivery-tdd - Firstmate outbox delivery TDD fix — establish checksum-verifiable outbound path (kind: scout) (done 2026-10-17)
  CLOSED 2026-10-17 as never-dispatched: no brief, no task directory, no artifacts.
- [x] elevate-anythingllm-repair - Elevate AnythingLLM repair: restore agents.elevatesci.com workspace (kind: ship) (done 2026-10-17)
  CLOSED 2026-10-17 as never-dispatched: no brief, no task directory, no artifacts.
- [x] core-distro-stage-scale-100pct - Match full staging page at 100% browser zoom (repo: core-distro-stage) (kind: ship) (done 2026-10-17)
  CLOSED 2026-10-17 as never-dispatched: no brief, no task directory, no artifacts.
- [x] skill-collision-fix-20261015 - SCOUT. Produce an exact, reversible cleanup plan for the d (repo: firstmate) (done 2026-10-17)
  CLOSED 2026-10-17 as never-dispatched: no brief, no artifacts.
