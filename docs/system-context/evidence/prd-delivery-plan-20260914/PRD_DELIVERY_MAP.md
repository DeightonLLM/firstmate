# Brandon v3 PRD Delivery Map — 2026-09-14

## Executive verdict

The Brandon campaign has produced a substantial evidence and infrastructure base, but not the PRD’s finished multi-project software platform. The strongest customer-facing software completion is Elevate’s live site/dashboard cutover. Core Distro and CBD-Data have real source/runtime material and accepted audits, but their PRD target architecture and end-to-end release gates are not proven. Whoosh has no eligible implementation lane because its exact repository/host/runtime coordinates are missing. The hub and compute work is mostly infrastructure, specifications, tests, or bounded private runtime preparation; it must not be counted as delivered application software.

Do not use the manifest’s `ACCEPTED` status as a PRD checklist completion signal. The manifest is a task/evidence ledger: many accepted rows explicitly describe read-only audits, specifications, synthetic tests, or operator-gated work.

## Source proof and evidence boundary

The original source is identified as `Brandon-Multi-Project-Infrastructure-PRD-v3.md`, v3.0, last updated 2026-08-04. The canonical warehouse copy is now `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`. A preserved session read result also contains the title/directive and relevant historical sections: `/root/pi-recovery-snapshot-20260805T233406Z/agent/sessions/--root-agent-work--/2026-08-05T05-30-31-432Z_019fd066-e288-7afb-be7a-5e3cf9943422.jsonl` (decoded tool-result lines 995–1054: directive/goals; 1125–1151: success definition; 1271–1666: target architecture/server roles; 2017–2101: CI/CD; 2256–2419: backup/DR; 2669–2795: rollout). The requested historical blob `b98c887b8abdf0041d52faf2405ec5a76ec8fcf2` is not present in the current repository object database. Claims below cite the canonical warehouse copy plus preserved historical evidence and current campaign artifacts; exact-byte history remains a provenance limitation.

Authoritative current ledger: `BRANDON REWORK/BRANDON_CAMPAIGN_MANIFEST.tsv`. The ledger currently has 59 task rows: 52 `ACCEPTED`, one superseded row, and six unresolved rows (four dependency-blocked, one authorization-blocked, one operator-input-blocked). These counts describe task states only; they are task/evidence states, not PRD completion.

## PRD acceptance model

The PRD’s success definition requires all four public projects to operate on the public/control plane, durable job submission while compute is unavailable, project-scoped compute queues/data access, one backup target per project, documented complete-project restore, traceable Git/approval for production changes, and health/alerts/resource limits/rollback for critical services. The rollout adds exit gates for: baseline/rollback; inventory and application audit; cross-project network denial; shared platform health/no public internal ports/end-to-end test deployment; Hostinger↔Hetzner job flow and queue isolation; per-project smoke/isolation/restore/signoff; CI/CD and release controls; observability; backup/DR drills.

## Delivered working software (evidence-backed, but not full PRD completion)

| Area | What is actually delivered | PRD disposition |
|---|---|---|
| Elevate Life Sci | `BR-ELEVATE-IDENTITY-001` and `BR-ELEVATE-SEO-PERF-001` evidence a live apex/www site, valid TLS, 84-file static SEO/schema/image changes, and `agents.elevatesci.com` dashboard/vhost with a 200 path. See `BRANDON REWORK/evidence/BR-ELEVATE-SEO-PERF-001/elevate-client-closeout-m3.md` §§1–3 and manifest lines 42, 45. | Working customer-facing release for the cited scope. PRD-wide app/API/queue/backup/isolation acceptance is not proven. Ops provider-version upgrade remains `BLOCKED_AUTHORIZATION`. |
| Core Distro | Real PHP SaaS source exists at `projects/core-distro.com/current-core-distro/`; accepted BR-AUD-002 maps PHP production, Next.js staging, MySQL/Percona, auth/lead-list data, and queue-like city jobs. BR-CORE-001 performed read-only route QA and records PASS/FAIL/NOT_RUNTIME_VERIFIABLE, with deployment/hydration/auth gates still open (manifest line 28). | Existing working software/runtime evidence, not a completed PRD rollout. The PRD target (Hostinger public/control plane, project isolation, durable cross-host job path, CI/release/restore gates) remains unproven. |
| CBD-Data | Real Next/PHP project source exists at `projects/cbd-data.com/`; BR-AUD-005 is accepted for scraping, enrichment, queue, export, storage, and compute placement discovery (manifest line 11). Local restore/backup documents and tests exist. | Working source and audit evidence, not a finished production PRD implementation. No accepted end-to-end Hostinger↔Hetzner queue/isolation/restore/signoff chain is present. |
| Brandon compute runtime | Controller records register the private `brandon-compute` target and bounded runtime paths, but the accepted execution and Pi/1Panel result artifacts are absent; the current handoff marks `/opt/brandon` as runtime-copy-unverified and Ollama keep-contained pending live evidence. | `UNKNOWN` until host/source identity, exact runtime state, backup, and isolated restore test are accepted; no exposed project worker/API or project queue path is cleared. |

## Specs, tests, and infrastructure — not delivered application software

- `BR-INFRA-001` is accepted hardening/evidence for `srv1856614`; it explicitly defers ACL, secret-store, isolation, deployment, and related gates (manifest line 18).
- `BR-HUB-006` is accepted Stage 2–4 host installation/configuration: OpenResty/OnePanel upstream, PostgreSQL, Redis, Qdrant, and LiteLLM with placeholder keys; application deployment remains separately queued and DNS/TLS/real credentials remain gated (manifest line 33; `evidence/BR-HUB-006/stage2-4-migration.md` lines 21, 146–218).
- `BR-COMPUTE-GATEWAY-SPEC-001` is an offline Phase 1 gateway specification with 8 offline tests. Its M3 review says Phase 2 live deployment is deferred and the proposed runner path is not executable on the target until runtime work is performed (`evidence/BR-COMPUTE-GATEWAY-SPEC-001/M3_REVIEW.md` lines 39–44, 74–91; manifest line 51).
- `BR-OPS-002` is a synthetic four-fixture restore-rehearsal harness. The manifest explicitly says it is acceptance-not-proof and that live backup/restore remains operator/provider-gated (manifest line 24).
- `BR-HUB-001`, `BR-BACKUP-001`, `BR-OPS-001`, and related matrices are inventories/designs. They define desired components, retention, encryption, and restore acceptance; they do not prove a live Brandon application hub or off-host backup/restore.

## Unresolved PRD acceptance areas

1. **Project coverage:** Whoosh audit `BR-AUD-004` is `BLOCKED_BY_DEPENDENCY`/`COORDINATES_MISSING`; exact repo, hosting, runtime, and production IP are required. Until then, `BR-ARCH-001` placement and `BR-GATE-001` Eric/Dubz approval cannot close (manifest lines 10–13).
2. **Canonical application architecture:** Current Core/CBD evidence is PHP/MySQL and mixed deployment; PRD v3 describes Hostinger PostgreSQL/PgBouncer, project databases/roles, Hostinger APIs/files, Hetzner queues/workers, and project-scoped ingest. No single accepted source/ADR maps the existing software to that target.
3. **Cross-project runtime isolation:** No accepted evidence proves four production queue namespaces, worker denial tests, project-scoped ingest, file namespaces, database roles, or Qdrant collection isolation end to end.
4. **Hub application delivery:** Hub host services were installed/configured, but app deployment is explicitly pending; LiteLLM placeholder keys prevent a working gateway. AnyLLM backend/vector-store relationship and Brandon-vs-HD2 data boundary remain unknown.
   The 2026-09-18 read-only placement recheck confirms `brandon-compute`
   remains the dedicated private broker/compute plane and HD2stack placement
   remains blocked at 77% disk use; it also records a new Tailscale-bound
   `100.71.95.76:8092` listener as report-only drift, with no action taken.
   Evidence: `BRANDON REWORK/evidence/BR-COMPUTE-PLACEMENT-RECHECK-20260918/report.md`.
   A same-day console comparison found the public Core-Distro and Music Metrics
   shells structurally equivalent, with both dashboard routes redirecting to
   login. The Elevate operations console is reachable without an auth wall and
   exposes unauthenticated status/job APIs, unlike the Basic-Auth-protected
   Core-Distro agents console; this is a security remediation candidate, not an
   accepted production-parity state. Evidence:
   `BRANDON REWORK/evidence/BR-SAAS-PARITY-20260918/console-parity-report.md`.
5. **Release controls:** Accepted local hardening/self-tests are not the PRD’s project CI/CD, container-build, dependency/vulnerability, migration-dry-run, staging, smoke, health, and rollback gates for all four applications.
6. **Backup/DR:** Designs and synthetic harness exist; no live encrypted off-host provider assignment, per-project target proof, real restore, measured RPO/RTO, or required DR drill evidence is accepted. `BR-HUB-010` remains `BLOCKED_OPERATOR_INPUT` for provider/account, retention, RPO/RTO, and key custody.
7. **Observability:** Inventory/design references metrics/logs/alerts, but no complete four-project SLO/alert/restore-age implementation is evidenced.
8. **Canonical source provenance:** The canonical PRD is restored in the system-context warehouse at `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`. The historical Git blob remains absent; recover it only if final signoff requires exact-byte historical provenance.
9. **Reusable HD2 client baseline:** the accepted Hetzner/HD2stack recheck is
   placement and broker evidence, not a complete `/hard` host-baseline
   application. A future hardening pass must carry a host-profile overlay
   (provider, exact addresses, OS/role, named admin/key pointer, approved
   ingress, break-glass route, rollback window, and exceptions) and prove a
   fresh admin login before SSH finalization. No hardening mutation is implied
   by the current campaign.

## Immediate disjoint coding lanes

These are local/software lanes and should not wait on production credentials. Live deployment, DNS, provider keys, and data migration remain separate gates.

### Lane A — Core Distro canonical release and parity

**Scope:** `projects/core-distro.com/` plus its canonical source repository only. Reconcile PHP/Next.js ownership, make one reproducible build/start path, and close the already evidenced route/localization/chat/accessibility defects from BR-CORE-001. Add deterministic smoke/integration tests for auth, lead-list/job states, export, health, and rollback metadata.

**Dependencies:** BR-AUD-002 and BR-CORE-001 (available); architecture decision for PHP/MySQL versus PRD PostgreSQL placement (record, do not silently migrate); authenticated/live promotion remains separate.

**Done means:** local source, build, tests, and release manifest agree; no claim of production deployment until the operator names the target and supplies the live gate.

**Local continuation (2026-09-18):** the canonical `staged-export-test/` slice
was updated with the missing apple-touch parity declaration in 10 PHP source
files (12 `<head>` blocks) and a deterministic parity test. RED/GREEN/REFACTOR,
11/11 PHP lint, boundary scan, diff scope, rollback, and an independent
`CHECK_PASS` are recorded in `BRANDON REWORK/evidence/BR-CORE-LOCAL-PARITY-20260918/`
(`lane-a-worker.md`, `lane-a-checker.md`). This remains local-only; promotion,
hydration, auth, and production gates are unchanged.

### Lane B — CBD-Data durable job and isolation adapter

**Scope:** `projects/cbd-data.com/` only. Convert the existing scraping/enrichment/export flow into a PRD-shaped project boundary: explicit job identity/idempotency/status, project-scoped queue/ingest adapter, bounded workspace/export retention, and local synthetic queue/isolation/restore tests. Do not alter Music Metrics or shared HD2 services.

**Dependencies:** accepted BR-AUD-005; current source coordinates are available. Final database/queue placement and any live credential use require an ADR/operator gate; no need to block local implementation on those credentials.

**Gate update (2026-09-18):** ADR-001 was approved under
GATE-CBD-ENRICH-002 and the bounded private RabbitMQ `/cbddata` bootstrap
closed GATE-CBD-ENRICH-003 on `brandon-compute`. Evidence and rollback are in
`BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/`. This advances the private
queue prerequisite only; application cutover, worker rollout, staging, and
production acceptance remain out of scope and the Lane B “Done means” rule is
unchanged.

**Local continuation (2026-09-18):** the eligible status-boundary slice is now
implemented and independently checked: a shared `cbd_initial_job_status()`
resolver is used by both import insert sites, with genuine RED/GREEN/REFACTOR
evidence and a full local-suite `CHECK_PASS`. See
`BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/tdd-evidence.md`,
`lane-b-local-adapter-worker.md`, and `lane-b-local-adapter-checker.md`.

**Done means:** local tests prove duplicate-safe job/result handling and project scoping; the adapter is deployable from version-controlled config; live worker rollout remains pending the architecture/target decision.

### Lane C — Private Brandon gateway and hub application integration

**Scope:** gateway source/spec workspace and hub integration code only; no public exposure. Replace the gateway spec’s missing/non-executable runner assumption with the accepted `/opt/brandon/llm/runner` contract, implement token-file/private-bind runtime checks, and add a local/mock AnyLLM↔LiteLLM/embedding contract test. Keep project namespaces explicit and keep HD2-only services out of Brandon scope.

**Dependencies:** BR-COMPUTE-LLM-001, BR-COMPUTE-PI-1PANEL-001, BR-HUB-006, and BR-COMPUTE-GATEWAY-SPEC-001 are available; valid model/API credentials, DNS/TLS, and Phase 2 live deployment remain operator-gated. Resolve AnyLLM backend/vector-store ownership before migration.

**Done means:** private runtime and integration tests pass against a real runner or a clearly bounded mock; no claim of a working public hub until real-key, data-boundary, and restore gates pass.

**Local continuation (2026-09-18):** the gateway contract slice now has a
private-bind/token-file mock and 9-check executable contract test, with the
existing 8-check hardening suite still green. Independent verification recorded
`CHECK_PASS`, reconciled RED/GREEN/REFACTOR and rollback, and confirmed no
listener or live runner was started. The checker corrected the actual evidence
tree location to `BRANDON REWORK/evidence/BR-COMPUTE-GATEWAY-SPEC-001/`; live
Phase 2 gateway deployment remains explicitly unauthorized. See
`BRANDON REWORK/evidence/BR-COMPUTE-GATEWAY-LOCAL-20260918/`.

## Operator decisions required (only where not inferable)

- Supply Whoosh repository/hosting/runtime/IP coordinates so its audit and the placement/approval chain can resume.
- Choose/approve the canonical application architecture (retain PHP/MySQL where proven, or adopt PRD PostgreSQL/PgBouncer) per project; record deviations as ADRs.
- For hub/gateway: identify whether AnythingLLM is Brandon-scoped or HD2-only, choose its vector backend/embedding path, and authorize real-key/runtime deployment when ready.
- For backup/DR: select provider/account, target assignment, retention, accepted RPO/RTO, and recovery-key custody; then authorize a live encrypted backup and restore rehearsal.
- Keep the canonical warehouse copy as the source of truth; recover the historical PRD blob only if exact-byte historical provenance is required for final acceptance.

## Bottom line

The campaign has delivered one clearly working customer-facing release (Elevate), existing Core/CBD software with accepted discovery/QA evidence, and a working private compute foundation. It has not delivered the four-project PRD platform, hub application, queue/isolation fabric, CI/CD release system, or live backup/DR. The three lanes above are the shortest disjoint path to finished software while preserving the existing operator gates.
