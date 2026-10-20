# `docs/` navigation index

Use the session-read section first. Open dispatch/blocker guidance when its trigger applies; the dated evidence corpus is reference material, not routine reading. This file indexes `docs/`; `docs/README.md` remains the separate warehouse contract.

## Read every session

- [`supervision-protocols/pi.md`](supervision-protocols/pi.md) — Pi wake draining, extension supervision, and continuity steps.
- [`supervision-protocols/claude.md`](supervision-protocols/claude.md) — Claude Stop-hook supervision and wake handling.
- [`supervision-protocols/codex.md`](supervision-protocols/codex.md) — Codex foreground checkpoint supervision loop.
- [`supervision-protocols/grok.md`](supervision-protocols/grok.md) — Grok background-notify supervision loop.
- [`supervision-protocols/minimax-code.md`](supervision-protocols/minimax-code.md) — MCode primary-specific supervision contract.
- [`supervision-protocols/opencode.md`](supervision-protocols/opencode.md) — OpenCode idle-hook supervision and re-arm behavior.
- [`supervision-protocols/unknown.md`](supervision-protocols/unknown.md) — fallback loop for an unverified harness.
- [`watcher-continuity.md`](watcher-continuity.md) — ownership and recovery guarantees for keeping watcher cycles continuous.
- [`wake-drain-loop.md`](wake-drain-loop.md) — why every queued notification must be drained and handled, not just the first.
- **This index** — routes readers to current operating guides and historical evidence; it does not replace their owners.

## Read when dispatching or blocked

- [`configuration.md`](configuration.md) — operational-home layout, configuration schemas, dispatch, and runtime selection.
- [`tmux-backend.md`](tmux-backend.md) — verified reference session backend and its setup.
- [`herdr-backend.md`](herdr-backend.md) — experimental Herdr backend setup, limits, and lifecycle.
- [`orca-backend.md`](orca-backend.md) — experimental macOS Orca backend, prerequisites, and repository ownership.
- [`cmux-backend.md`](cmux-backend.md) — experimental macOS cmux backend setup and socket boundary.
- [`zellij-backend.md`](zellij-backend.md) — explicit-only Zellij backend setup and current limitations.
- [`codex-app-backend.md`](codex-app-backend.md) — why Codex Desktop is not a selectable backend and the missing integration contract.
- [`calm.md`](calm.md) — Pi Calm presentation behavior, persistence, and limits.
- [`calm-mode-feasibility.md`](calm-mode-feasibility.md) — version-scoped Calm implementation evidence and supported API boundaries.
- [`decision-hold-lifecycle.md`](decision-hold-lifecycle.md) — deterministic mechanism for recording and completing unresolved investigation decisions.
- [`ticket-board.md`](ticket-board.md) - one-screen read-only view over the ticket system: what needs the Captain's input, what is under way, and what is planned.
- [`subagent-guard.md`](subagent-guard.md) — guard preventing an untracked primary-session delegation bypass.
- [`arm-pretool-check.md`](arm-pretool-check.md) — command-shape seatbelt for arming the watcher safely.
- [`cd-guard.md`](cd-guard.md) — seatbelt against persistent shell directory changes into project clones.
- [`turnend-guard.md`](turnend-guard.md) — primary turn-boundary backstop when required supervision is absent.
- [`wedge-alarm.md`](wedge-alarm.md) — away-mode injection-stall alerts and supported channels.
- [`sessionstart-nudge.md`](sessionstart-nudge.md) — native hook behavior that nudges the canonical session-start command.
- [`todo-prefix-canonical-format.md`](todo-prefix-canonical-format.md) — canonical To-Do board prefix and lane-key format, its model alias table, and the checker that enforces them.
- [`scripts.md`](scripts.md) — purpose map for `bin/` scripts; each script header/help remains authoritative for exact use.
- [`provider-routing.md`](PROVIDER-ROUTING.md) — AFK provider schedule and quota-routing policy.
- [`gitlab-merge-watch.md`](gitlab-merge-watch.md) — recorded GitLab merge-watch verification and its evidence limits.
- [`merge-packet.md`](merge-packet.md) - the read-only merge packet reporter, which carries branch identity, diff, blast radius, the byte-identical-copy invariant check, proven conflicts, rollback commands, and the single merge decision the Captain is asked to make.
- [`verification/runtime-backends.md`](verification/runtime-backends.md) — version-scoped evidence for active backend guarantees.
- [`verification/supervision.md`](verification/supervision.md) — evidence for session-start, turn-end, watcher continuity, and wedge-alarm guarantees.
- [`verification/dispatch-auth.md`](verification/dispatch-auth.md) — reusable evidence for provider-family, credential-surface, and quota reasoning.
- [`verification/process-event-sources.md`](verification/process-event-sources.md) — verification evidence for process-to-event runner guarantees.
- [`verification/public-followup.md`](verification/public-followup.md) — verification evidence for durable promised public replies.
- [`verification/stow-memory.md`](verification/stow-memory.md) — verification evidence for startup-memory bounds and `/stow` curation.

## Reference: audits, studies, dated incidents, and warehouse material

These entries preserve evidence or historical context. Their dated operational claims are snapshots; verify against current owners before acting.

### Architecture, product, and engineering references

- [`architecture.md`](architecture.md) — detailed Firstmate architecture and mechanism ownership.
- [`schema.md`](schema.md) — sanitized warehouse-record schema and Markdown/YAML authority relationship.
- [`documentation-audiences.md`](documentation-audiences.md) — audience classes and the owner of documentation placement rules.
- [`documentation-audiences.json`](documentation-audiences.json) — machine-consumed prose-surface audience inventory and validation metadata.
- [`examples/crew-dispatch.json`](examples/crew-dispatch.json) — example dispatch-profile document for configuration reference.
- [`examples/wedge-alarm`](examples/wedge-alarm) — copyable local alert-channel example; its header explains the intended destination and directives.
- [`drift-waivers.tsv`](drift-waivers.tsv) — dated records of documentation drift waivers and their rationales.
- [`fm-test-isolation-proof.md`](fm-test-isolation-proof.md) — recorded concurrent test-isolation proof and its run evidence.
- [`fm-test-isolation-proof.json`](fm-test-isolation-proof.json) — machine-readable result for the isolation proof; paired with the Markdown record.
- [`fm-test-portable-shards.md`](fm-test-portable-shards.md) — candidate test-shard composition and recorded timings.
- [`anythingllm/README.md`](anythingllm/README.md) — sanitized AnythingLLM placement projection and current evidence limitations.
- [`anythingllm/STACK-MAP.md`](anythingllm/STACK-MAP.md) — instance-by-instance AnythingLLM placement and unresolved verification.
- [`anythingllm/RAG-METADATA-CONTRACT.md`](anythingllm/RAG-METADATA-CONTRACT.md) — sanitized metadata required before a Core or Elevate RAG build.
- [`anythingllm/projection-manifest.yaml`](anythingllm/projection-manifest.yaml) — machine-readable sanitized AnythingLLM projection manifest (last verified 2026-09-23).

### Audits and dated reports — do not use for routine reading

- [`COMPUTE-DISTRIBUTION-STUDY-20260928.md`](COMPUTE-DISTRIBUTION-STUDY-20260928.md) — dated multi-host compute and quota study.
- [`CORE-DISTRO-SSL-OUTAGE-20260928.md`](CORE-DISTRO-SSL-OUTAGE-20260928.md) — read-only diagnosis and remediation options for the 2026-09-28 TLS incident.
- [`DEEPSEEK-HARNESS-INSTALL-20260928.md`](DEEPSEEK-HARNESS-INSTALL-20260928.md) — installation and verification report for a specific 2026-09-28 host state.
- [`FLEET-STATUS-20261012.md`](FLEET-STATUS-20261012.md) — fleet-status snapshot written 2026-10-12; recheck all live claims.
- [`HANDOFF-20261012.md`](HANDOFF-20261012.md) — successor handoff snapshot from 2026-10-12, including time-bound task claims.
- [`ZCODE-HANDOFF-20261012.md`](ZCODE-HANDOFF-20261012.md) — dated ZCode handoff and its referenced reading order.
- [`ZCODE-PROMPT-20261012.md`](ZCODE-PROMPT-20261012.md) — historical operational prompt; its routing and queued work are not current authority.
- [`KUN-ADOPTION-GATE.md`](KUN-ADOPTION-GATE.md) — evidence and boundary for isolated Kun evaluation, not production approval.
- [`STALE-CLAIM-GUARD-R2-20260928.md`](STALE-CLAIM-GUARD-R2-20260928.md) — dated implementation report for a specific stale-claim guard.
- [`PROVIDER-ROUTING.md`](PROVIDER-ROUTING.md) — canonical provider-routing rationale and schedule; consult current policy and quota evidence before dispatch.
- [`audits-20260928/AGENTSEC.md`](audits-20260928/AGENTSEC.md) — read-only agent-safety guard-chain audit.
- [`audits-20260928/CONSOLIDATED-20260928.md`](audits-20260928/CONSOLIDATED-20260928.md) — consolidated 2026-09-28 system-security findings and mutation outcomes.
- [`audits-20260928/FLEET-HYGIENE-PLAN-20260929.md`](audits-20260928/FLEET-HYGIENE-PLAN-20260929.md) — read-only fleet-hygiene plan and report-first findings.
- [`audits-20260928/FLEET-HYGIENE-RESULTS-20260929.md`](audits-20260928/FLEET-HYGIENE-RESULTS-20260929.md) — dated fleet-hygiene run results and verification.
- [`audits-20260928/FULLHYG-BRANDON.md`](audits-20260928/FULLHYG-BRANDON.md) — Brandon-compute full-surface hygiene audit evidence.
- [`audits-20260928/FULLHYG-CONTROLLER.md`](audits-20260928/FULLHYG-CONTROLLER.md) — controller full-surface hygiene audit evidence.
- [`audits-20260928/FULLHYG-ELEVATES.md`](audits-20260928/FULLHYG-ELEVATES.md) — reconstructed Elevate hygiene results from lane output.
- [`audits-20260928/FULLHYG-HD2STACK.md`](audits-20260928/FULLHYG-HD2STACK.md) — HD2Stack full-surface hygiene audit evidence.
- [`audits-20260928/FULLHYG-REBOOT-VERIFY.md`](audits-20260928/FULLHYG-REBOOT-VERIFY.md) — read-only post-reboot verification snapshot.
- [`audits-20260928/GATE-AUDIT-20260929.md`](audits-20260928/GATE-AUDIT-20260929.md) — 2026-09-29 audit and ruling on launch-gate classification.
- [`audits-20260928/HARDEN.md`](audits-20260928/HARDEN.md) — read-only host-hardening audit and unapplied recommendations.
- [`audits-20260928/HARNESS-ZCODE-20260929.md`](audits-20260928/HARNESS-ZCODE-20260929.md) — dated ZCode harness registration and verification report.
- [`audits-20260928/HEALTH-RETRO.md`](audits-20260928/HEALTH-RETRO.md) — dated harness-quality and Git retrospective.
- [`audits-20260928/LEANCTX-FINDING-20260929.md`](audits-20260928/LEANCTX-FINDING-20260929.md) — remeasurement that retired a deferred Lean-ctx tuning target.
- [`audits-20260928/MUT-CI.md`](audits-20260928/MUT-CI.md) — evidence for a Firstmate CI supply-chain change.
- [`audits-20260928/MUT-HD2STACK-TRIAGE.md`](audits-20260928/MUT-HD2STACK-TRIAGE.md) — bounded HD2Stack secret-material classification and triage evidence.
- [`audits-20260928/MUT-HERDRGATE.md`](audits-20260928/MUT-HERDRGATE.md) — evidence for the Herdr raw-send gate mitigation.
- [`audits-20260928/MUT-INTENTGUARD.md`](audits-20260928/MUT-INTENTGUARD.md) — evidence for intent-guard remediations.
- [`audits-20260928/MUT-PIGATE.md`](audits-20260928/MUT-PIGATE.md) — evidence for Pi extension gate repairs.
- [`audits-20260928/MUT-SECSCAN-FAILCLOSED.md`](audits-20260928/MUT-SECSCAN-FAILCLOSED.md) — evidence that the secret scanner's fail-open defect was fixed.
- [`audits-20260928/MUT-SNAPSHOT.md`](audits-20260928/MUT-SNAPSHOT.md) — evidence for pre-turn snapshots and rollback around agent CLI refreshes.
- [`audits-20260928/REV-A.md`](audits-20260928/REV-A.md) — independent review verdict for wave-one security and guard audits.
- [`audits-20260928/REV-B.md`](audits-20260928/REV-B.md) — independent review verdict for wave-two audits.
- [`audits-20260928/SECRETS.md`](audits-20260928/SECRETS.md) — dated leak-quarantine integrity and secret-scan audit.
- [`audits-20260928/SUPPLYCHAIN.md`](audits-20260928/SUPPLYCHAIN.md) — dated agent-harness software supply-chain audit.
- [`audits-20260928/WORK-PLAN-20260929.md`](audits-20260928/WORK-PLAN-20260929.md) — dated read-only fleet-work inventory and lane shortlist.
- [`knowledge/DISPATCH-GATE-AND-LANE-POLL-20261004.md`](knowledge/DISPATCH-GATE-AND-LANE-POLL-20261004.md) — 2026-10-04 record of dispatch-gate and lane-poll helpers.
- [`knowledge/DOMAIN-REGISTRY-AND-PHANTOM-INCIDENT-20261003.md`](knowledge/DOMAIN-REGISTRY-AND-PHANTOM-INCIDENT-20261003.md) — controller-sourced domain-registry snapshot and phantom-domain incident rules.
- [`knowledge/KNOWN-SYNC-GAPS-20261004.md`](knowledge/KNOWN-SYNC-GAPS-20261004.md) — surface-specific sync gaps and provenance cautions recorded 2026-10-04.
- [`knowledge/MODEL-HARNESS-AVAILABILITY-20261004.md`](knowledge/MODEL-HARNESS-AVAILABILITY-20261004.md) — 2026-10-04 model/harness pairing ruling; verify against current catalogs.
- [`knowledge/STANDARD-SETUP-NORTHSTAR-20261005.md`](knowledge/STANDARD-SETUP-NORTHSTAR-20261005.md) — locked fleet setup snapshot from 2026-10-05; verify before applying.
- [`lane-evidence/p1N-docsrule-stalled-transcript-20260928.txt`](lane-evidence/p1N-docsrule-stalled-transcript-20260928.txt) — retained transcript excerpt documenting the stalled docs-rule lane.

### System-context warehouse — follow its own index first

- [`system-context/INDEX.md`](system-context/INDEX.md) — mandatory entry point and routing map for the sanitized system-context warehouse.
- [`README.md`](README.md) — **different file:** committed warehouse contract and projection guidance; not the `docs/` navigation index.
- [`system-context/SCHEMA.md`](system-context/SCHEMA.md) — warehouse YAML schema and freshness validation rules.
- [`system-context/SOURCES.md`](system-context/SOURCES.md) — accepted source inventory grounding warehouse records.
- [`system-context/GLOSSARY.md`](system-context/GLOSSARY.md) — sourced definitions for warehouse terminology.
- [`system-context/WAREHOUSE_BOUNDARIES.md`](system-context/WAREHOUSE_BOUNDARIES.md) — system-versus-client data boundary and placement model.
- [`system-context/CLIENT_WAREHOUSE_ONBOARDING.md`](system-context/CLIENT_WAREHOUSE_ONBOARDING.md) — procedure for registering a separately governed client/project warehouse.
- [`system-context/HOSTS.md`](system-context/HOSTS.md) — human-readable authority for warehouse host records.
- [`system-context/SERVICE_CATALOG.md`](system-context/SERVICE_CATALOG.md) — human-readable service, tenant, and brand/domain inventory.
- [`system-context/PRD_TRACEABILITY.md`](system-context/PRD_TRACEABILITY.md) — evidence-backed status of Brandon infrastructure PRD items.
- [`system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`](system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md) — canonical v3.0 Brandon infrastructure PRD, last updated 2026-08-04.
- [`system-context/LEAN-CTX-TERMINAL-LAYERS.md`](system-context/LEAN-CTX-TERMINAL-LAYERS.md) — 2026-10-04 explanation of terminal-specific Lean-ctx visibility and enforcement.
- [`system-context/ELEVATE_NGINX_ROUTE_20260919.md`](system-context/ELEVATE_NGINX_ROUTE_20260919.md) — dated change record for Elevate dashboard route containment.
- [`system-context/hosts.yaml`](system-context/hosts.yaml) — **GENERATED** machine-readable mirror of `HOSTS.md`; do not edit directly (last verified 2026-09-15).
- [`system-context/service_catalog.yaml`](system-context/service_catalog.yaml) — **GENERATED** machine-readable mirror of `SERVICE_CATALOG.md`; do not edit directly (last verified 2026-09-15).
- [`system-context/prd_traceability.yaml`](system-context/prd_traceability.yaml) — **GENERATED** machine-readable mirror of `PRD_TRACEABILITY.md`; do not edit directly (last verified 2026-09-19).
- [`system-context/hosts.yaml.bak-evidence-20261011T054433Z`](system-context/hosts.yaml.bak-evidence-20261011T054433Z) — dated backup snapshot, not the active host inventory.
- [`system-context/service_catalog.yaml.bak-20261011T054826Z`](system-context/service_catalog.yaml.bak-20261011T054826Z) — dated backup snapshot, not the active service inventory.
- [`system-context/prd_traceability.yaml.bak-evidence-move-20261011T054140Z`](system-context/prd_traceability.yaml.bak-evidence-move-20261011T054140Z) — dated backup snapshot, not the active PRD traceability mirror.
- [`system-context/prd_traceability.yaml.bak-evidencefix-20261011T053352Z`](system-context/prd_traceability.yaml.bak-evidencefix-20261011T053352Z) — dated backup snapshot, not the active PRD traceability mirror.
- [`system-context/evidence/BR-AUD-002/report.md`](system-context/evidence/BR-AUD-002/report.md) — 2026-08-06 Core Distro application-audit evidence.
- [`system-context/evidence/BR-INV-001/report.md`](system-context/evidence/BR-INV-001/report.md) — Brandon campaign Phase 0 server-inventory discovery draft.
- [`system-context/evidence/cbd-worker-canary/report.md`](system-context/evidence/cbd-worker-canary/report.md) — 2026-08-02 CBD worker/canary blocker reconciliation.
- [`system-context/evidence/overnight-control-security-20260914/MINI_SPRINT_PREPARATION_REPORT.md`](system-context/evidence/overnight-control-security-20260914/MINI_SPRINT_PREPARATION_REPORT.md) — read-only preparation report for the 2026-09-14 security mini-sprint.
- [`system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md`](system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md) — 2026-09-14 PRD delivery assessment; distinguishes task acceptance from product delivery.
- [`system-context/evidence/prd-delivery-plan-20260914/SOFTWARE_LANES.md`](system-context/evidence/prd-delivery-plan-20260914/SOFTWARE_LANES.md) — 2026-09-14 evidence-backed software-lane recommendations and boundaries.
- [`system-context/evidence/BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/status.txt`](system-context/evidence/BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/status.txt) — retained run record for the bounded private broker acceptance.
- [`system-context/evidence/BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/decision-and-rollback.md`](system-context/evidence/BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/decision-and-rollback.md) — 2026-10-11 reconstruction of the decision and rollback record from retained status.
- [`system-context/evidence/BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/evidence.md`](system-context/evidence/BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/evidence.md) — 2026-10-11 transcription of the retained run record, not original contemporaneous output.
- [`system-context/evidence/BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/lane-b-local-adapter-checker.md`](system-context/evidence/BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/lane-b-local-adapter-checker.md) — reconstruction notes that explicitly say the original checker output was not retained.
- [`system-context/evidence/BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/tdd-evidence.md`](system-context/evidence/BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/tdd-evidence.md) — reconstructed TDD claim; original artifacts were not retained, so the claim is marked unverified by record.

## Not found in this worktree snapshot

The requested inventory did not contain `operating-decisions-2026-10-14-15.md` or `verification-discipline.md`; no links or descriptions are invented here. `wake-drain-loop.md` is present above.
