# Adversarial verification — cross-cutting PRD UNKNOWNs

**Audit date:** 2026-10-18
**Scope:** document-only and read-only checks. No client project, DNS, host/service configuration, or running service was modified.
**Authority labels:** status values below use only `DELIVERED`, `EVIDENCED`, `IN_PROGRESS`, `BLOCKED`, `UNKNOWN`. A ledger status is not upgraded by design text or an isolated component observation.

## Executive result

The four platform-wide ledger rows remain `UNKNOWN`. Current evidence narrows what the UNKNOWNs mean, but does not close any PRD-wide gate. The most important counterevidence to a simple “nothing exists” conclusion is: a private CBD RabbitMQ prerequisite was provisioned and locally tested; a controller-side 8081 listener and system disk timer exist; and one dated remote triage report asserts backup transfers are operational. None proves cross-project acceptance, a real project release pipeline, or a completed restore drill. The backup assertion conflicts with the ledger and is not backed by an accepted live backup/restore artifact in the sources inspected; it stays OPEN.

## 1. PLATFORM ISOLATION

**Status: `UNKNOWN`.**

**Current measurable state:** the evidence base includes at least one project-scoped private RabbitMQ bootstrap: the delivery map says Gate-CBD-ENRICH-003 closed for a bounded `/cbddata` bootstrap on `brandon-compute`, but explicitly says application cutover, worker rollout, staging, and production acceptance remain out of scope (`docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md:92-98`). A separate audit records no end-to-end proof of four production queue namespaces, worker denial tests, project-scoped ingest, file namespaces, database roles, or Qdrant isolation (`docs/system-context/PRD_TRACEABILITY.md:237-248`).

**AnythingLLM/client-boundary check:**
- The current controller-host measurement: `ss -ltnp '( sport = :8081 )'` returned `LISTEN 0 512 0.0.0.0:8081 ... llama-server,pid=4143126`; `ps` identified `/opt/brandon/llm/runner/llama-server ... --host 0.0.0.0 --port 8081`; read-only `curl http://127.0.0.1:8081/v1/models` returned model `lfm2.5:latest`. This proves a listener/model endpoint on the audited machine, not client-vs-HD2 isolation.
- The wiring map says the Brandon-compute AnythingLLM container's `GENERIC_OPEN_AI_BASE_PATH` is `http://host.docker.internal:8081/v1`, and identifies its endpoint as `agents.elevatesci.com` (`docs/infrastructure-wiring-map.md:45-58`). The 2026-10-17 remote reply independently states this is the client-facing instance and that stopping/rebinding the backend would break its chat (`BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-17-STOP-8081-is-client-dependency.md:6-23`). This is strong documented dependency evidence, but it is not a fresh read of the running container environment or a tenant-denial test. The port was not changed.
- The board likewise records 8081 as an active client AnythingLLM dependency (`BOARD.md:36-37`).

**What remains unproven:** no measured end-to-end matrix establishes that every client's app, AnythingLLM endpoint/backend, queues, workers, credentials, databases, ingest, files, logs, and backup are isolated from HD2-internal and other-client resources. In particular, neither a single CBD queue setup nor a client-facing service wired to 8081 proves isolation. The canonical v3 plan defines controls/tests but is design, not observed enforcement (`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:452-571`, `:1094-1160`).

**Smallest concrete move off UNKNOWN:** obtain a read-only, current placement/config inventory for each domain and the HD2/AnythingLLM endpoints, then run one authorized cross-tenant denial test per boundary (client-to-HD2/internal, project worker-to-other-project queue/data, and client ingest scope), with raw command/output and owner/date. Do not stop or rebind 8081; first verify current consumer wiring and only change it under separate authority.

## 2. CI/CD

**Status: `UNKNOWN`.**

**Current measurable state:** the traceability ledger expressly says accepted local hardening/self-tests do not constitute project CI/CD gates (container build, dependency/vulnerability scans, migration dry-run, staging, smoke, health, rollback) and marks the shared gate `UNKNOWN` (`docs/system-context/PRD_TRACEABILITY.md:250-261`). The v3 PRD specifies the desired PR→CI→review→staging→approval→deploy→health/rollback flow and minimum CI gates (`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:1285-1363`); that is normative design, not proof of a running pipeline.

**Measured repository boundary:** `find .github/workflows -maxdepth 2 -type f` on this checkout returned only `.github/workflows/no-mistakes-required.yml` and `.github/workflows/ci.yml`; `git ls-files` for workflow/build manifests likewise showed only those two controller-repository workflows and no tracked four-domain repository workflow paths. They are workflows for this Firstmate repository, not evidence of pipeline execution for Core Distro, Elevate, Whoosh, or CBD-Data. The PRD's infrastructure-repository outline is a recommendation, not evidence (`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:1760-1800`).

**What remains unproven:** whether any of the four actual source repositories has an enabled CI/CD pipeline, what it runs, whether the provider has a successful recent run, whether deployments reach staging/production, and whether rollback has been demonstrated. The checkout-level file search cannot establish absence from separately hosted repositories or provider settings. No successful run evidence for any domain was located in the specified traceability/delivery-map sources.

**Smallest concrete move off UNKNOWN:** for each actual canonical repository, capture the remote URL/default branch and enabled workflow/pipeline configuration plus the provider's latest run identifier, commit, result, and deployed target. At minimum, a real successful build/test run proves pipeline existence; full gate status requires staged deploy, smoke/health, approval, and rollback evidence as the PRD specifies.

## 3. BACKUP/DR

**Status: `UNKNOWN` — configured-vs-never-configured is not resolved.**

**Current measurable state and conflict OPEN:**
- The traceability row says designs and a synthetic harness exist, while no accepted live encrypted off-host provider assignment, per-project target proof, real restore, measured RPO/RTO, or required DR drill is accepted; `BR-HUB-010` is `BLOCKED` on provider/account, retention, RPO/RTO, and key custody (`docs/system-context/PRD_TRACEABILITY.md:263-274`). The delivery map repeats that account and live-restore evidence is missing and describes `BR-OPS-002` as a synthetic four-fixture harness, explicitly acceptance-not-proof (`docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md:53-56`; also `PRD_TRACEABILITY.md:271-274`).
- Contradictory reading: the 2026-10-15 Hetz triage says “Backup / DR | Namecheap encrypted transfers | Operational | Live” (`BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-wo-0001-domain-triage-reply.md:20`). This is a worker-reported state, but that row supplies no transfer run, project/target, manifest, checksum, restore result, RPO/RTO, or drill link; the same report labels the lane idle. This conflicts with the ledger's “no accepted live encrypted off-host ...” reading. **OPEN; neither reading is silently selected.**
- PRD v3 requires encrypted backups, verified restore, monthly project restore tests, and recorded drill timings (`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:1370-1547`). Requirements and synthetic exercises do not establish that an actual backup was ever taken or restored.

**Configured vs never configured:** `UNKNOWN`. The inspected sources do not distinguish “no live backup configuration exists” from “backup configuration exists/runs but lacks accepted evidence.” Given the operational report, “never configured” is not justified; given the ledger, “backups are being taken” is also not established. Restore-drill history is likewise `UNKNOWN`; no accepted real drill result was surfaced. Do not conflate a transfer/job configured, a backup file created, a successful restore, and a DRILL.

**What remains unproven:** current job configuration and last successful execution for each project; target/account ownership and isolation; encrypted artifact existence/integrity/retention; actual restore of application/database/files/config; measured RPO/RTO; and an authorized drill record. No live backup inventory or restore was attempted in this read-only audit.

**Smallest concrete move off UNKNOWN:** collect a read-only per-domain evidence packet: approved target assignment/capability, sanitized job configuration, latest successful run timestamp, destination manifest/checksum/size/encryption metadata, and retention result. That resolves whether backups are actually taken/configured. Separately, after explicit authorization, restore one project's artifact into an isolated temporary destination, run app/data checks, and record start/end, source backup, achieved RPO/RTO, and failures. A backup alone cannot establish a drilled DR capability.

## 4. OBSERVABILITY

**Status: `UNKNOWN`.**

**Current measurable state:** the ledger says design/inventory references metrics/logs/alerts exist but no complete four-project SLO/alert/restore-age implementation is evidenced (`docs/system-context/PRD_TRACEABILITY.md:276-287`). v3 defines desired host/application/queue/worker/database metrics and thresholded alerts, including missing/stale backups and drills (`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:1200-1284`); this is not evidence those collectors or alerts run.

Read-only local measurement on this controller found a systemd timer `hd2-disk-space-check.timer` due every 15 minutes, last run 9 minutes earlier (`systemctl list-timers --all --no-pager`); standard OS timers/sysstat were also present. The process search for Prometheus, Grafana, Uptime Kuma, Blackbox Exporter, Alertmanager, Zabbix, or Nagios found no matching process. This is controller-local evidence only: it neither proves nor disproves monitoring on client hosts or external monitoring services. No alert-delivery or fired-alert record was found in the audited sources. The 8081 request was a functional model-list probe, not a monitoring alert test.

**What remains unproven:** which client services are monitored now; per-domain metrics/log availability and retention; actual checks/thresholds; whether alerts are routed to an owner; whether alerts fire for real/synthetic faults; and backup/restore-age visibility. The mere presence of timers, system metrics, health endpoints, or monitoring specifications does not establish firing alerts.

**Smallest concrete move off UNKNOWN:** inventory active monitoring/check configuration per domain and produce one timestamped run/event for each critical alert class; trigger a harmless controlled test notification and retain the delivery receipt at the designated recipient. Include service coverage, thresholds, last-run/last-alert, receiver, and an alert response owner. A single controller disk timer cannot close the shared gate.

## Required independent measurements

Commands run (read-only):

- `git status --short --branch; git rev-parse HEAD; git rev-parse origin/main; git stash list --format='%gd %H %gs'`
- `ss -ltnp '( sport = :8081 )'`; `ps -p 4143126 -o pid,ppid,lstart,args`; `curl --max-time 3 -sS http://127.0.0.1:8081/v1/models`
- `find .github/workflows -maxdepth 2 -type f`; tracked workflow/build-manifest search; `systemctl list-timers --all --no-pager`; monitoring-process `pgrep` search.

Results:

- Branch is `main`; HEAD and `origin/main` both equal `ed43b43c84792eddb228036924b7dfe3a8d59ae6`, so main was in sync at measurement time.
- Two stash entries were present: `stash@{0}` = `66031cf8d5f67a2a605d3a6f8aa7679201107c81`; `stash@{1}` = `908c2319670bb6cdabfadb38ab633a3fdb13c89e`. These read-only measurements do not establish that no external actor changed them before the audit; this audit ran no stash mutation.
- The working tree was already not clean: `M data/async-lanes.tsv`, `?? core-distro-saas-clean`, `?? firstmate`. These pre-existing paths were not changed by this audit. No staging command was run; no staged changes were created.
- Port 8081 is actively listening on `0.0.0.0`, serves an OpenAI-compatible model-list response, and remains untouched. The client-facing AnythingLLM consumer dependency is documented in the wiring map and 2026-10-17 reply cited above. No stop, bind, config, or service command was run.
