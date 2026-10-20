# Brandon-compute local surface vs Brandon Multi-Project Infrastructure PRD v3

**VERDICT: PASS — study complete with evidence.** The audited surface is the local Brandon-compute Firstmate/Herdr workspace at `/home/hd2admin/kun-agent-workspace`, not a separate machine. The previous BLOCKED verdict resulted from misreading “Hetz” as a remote host; it is superseded. This report grades what the requested local surface actually evidences. It does not claim that a control is absent from some uninspected production host.

**Overall PRD posture on this surface: PARTIAL.** Substantial orchestration, task tracking, worker supervision, and agent-policy artifacts exist. The requested evidence does not establish the multi-project production infrastructure, server inventory, application-specific topology, isolation, backups, or DR controls described by the PRD.

## Scope and evidence rules

Read-only inventory; no services, containers, databases, Docker resources, volumes, or networks changed, no installs/kills, and no credentials accessed. File reads/searches/listings used `lean-ctx`. The named task inbox `/home/hd2admin/kun-agent-workspace/state/hetz-study-20261005.inbox` is absent, so there were no inbox messages to handle or reply to. A `quota-axi` invocation was denied by the lean-ctx shell allowlist; quota evidence is not material to the infrastructure comparison and was not retried. The requested `/home/hd2admin/.pi/extensions/` path is absent; workspace-specific extensions are present at `/home/hd2admin/kun-agent-workspace/.pi/extensions/`.

Statuses mean: **met** = direct, current local evidence substantially satisfies that area; **partial** = related capability/artifact exists but PRD scope or proof is incomplete; **missing** = no supporting evidence found in the audited local surface. Missing here means *not evidenced on this surface*, not proof of nonexistence elsewhere. There is no live inventory of Hostinger, Namecheap, Docker service state, firewall, DNS, backups, or the production apps in the audited evidence; claims about those systems would be speculative.

## Inventory of the Brandon-compute surface

### Configuration

`/home/hd2admin/kun-agent-workspace/config/` contains `crew-harness`, `secondmate-harness`, `backend`, `herdr-presentation-spaces`, `brief-include.md`, `crew-dispatch.json`, `startup-memory-budget`, `parallel-dispatch-cap`, and `calm`. Current reads showed `backend=herdr`, `parallel-dispatch-cap=6`, and `herdr-presentation-spaces=off`. `crew-dispatch.json` routes high-ambiguity implementation to Pi/MiniMax-M3 medium, current-events/web research to Grok, and routine coding to Pi/MiniMax-M2.7, with M2.7 as default. These govern agent dispatch, not infrastructure resource limits.

### Scripts and skills

`/home/hd2admin/kun-agent-workspace/bin/` has an extensive `fm-*` operational toolset. Representative observed files include `fm-spawn.sh`, `fm-send.sh` (referenced by the established Herdr audit), `fm-peek.sh`, `fm-crew-state.sh`, `fm-fleet-snapshot.sh`, `fm-fleet-view.sh`, `fm-watch.sh`, `fm-session-start.sh`, `fm-supervision-instructions.sh`, `fm-pr-check.sh`, `fm-pr-merge.sh`, `fm-backend.sh`, `fm-home-seed.sh`, `fm-decision-hold.sh`, `fm-check-lib.sh`, and `fm-herdr-lab-viewer.py`. These support supervised agent lifecycle, state, delivery, and fleet handling; they do not constitute the PRD's production deployment, backup, or host-hardening implementation.

Public installer-facing `skills/` contains `stow/SKILL.md`. The workspace's internal Firstmate skill surface lives in `.agents/skills/` (documented in root `AGENTS.md`), while Pi extension files are in `.pi/extensions/` and include `fm-primary-turnend-guard.ts`, `fm-calm.ts`, `fm-operational-input.ts`, `fm-async-exec.ts`, `fm-branch-dispatch.ts`, `fm-branch-model-picker.ts`, `fm-branch-supervision.ts`, `fm-primary-pi-watch.ts`, and related Calm/session-start modules. The requested external `~/.pi/extensions/` directory did not exist.

### Data, task records, and evidence reports

`/home/hd2admin/kun-agent-workspace/data/` contains a durable backlog and many task-scoped briefs, reports, and checkpoints. Relevant existing read-only evidence reports are `data/br-system-herdr-audit/report.md`, `data/br-system-ticket-audit/report.md`, `data/kun-config-inventory/report.md`, and `data/brandon-pi-runtime-audit-20261002/report.md`. The Herdr audit documents prior verified Herdr 0.9.1/protocol 22 evidence (captured 2026-09-23) and Firstmate spawn/steer/state wiring. The ticket audit documents a backlog/snapshot/board system and existing per-task pane metadata. The configuration inventory is dated 2026-01-26, so it is historical evidence, not current proof of provider/application state. `deightonllm-firstmate/BOARD.md` says last updated 2026-09-27; `deightonllm-firstmate/CONTROLLER_STATE.md` says local lanes L1-L3 delivered 2026-09-30 and explicitly says the controller state itself is not mirrored here.

### Live panes and worktrees

The supplied/read `herdr pane list` evidence showed the Brandon-compute workspace `w2` with controller pane `w2:p2H`, local terminal pane `w2:p2V`, and Firstmate workspaces including `w1E` and `w1G`. In `w1E`, the current study task is `w1E:pM` (Pi, GPT-6 Luna, working, cwd in its isolated study worktree); other visible entries include worker panes `w1E:pC`, `pE`, `pF`, `pH`, and `w1G:p2`, plus a MiniMax Code pane whose status is unknown. This is a live agent/pane snapshot, not a production service inventory. Six worktree slots were listed under `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/{1..6}/kun-agent-workspace`.

### Task-specific runtime record

`/home/hd2admin/kun-agent-workspace/state/hetz-study-20261005.meta` records this scout's Herdr endpoint `default:w1E:pM`, harness `pi`, model `gpt-6-luna`, effort `medium`, and isolated worktree path. The `state/` tree contains task `.meta`, `.status`, busy-state, pane-extension, and supervision/event artifacts. These are agent task records, not evidence of production workload telemetry or service health checks.

### PRD and location

The v3 source reviewed was `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`. It specifies Hostinger public/control plane, Hetzner compute plane, four Namecheap project backup targets, project isolation, security, delivery, monitoring, backups, DR and acceptance gates (sections 5-24).

## PRD v3 requirement status against actual local-surface evidence

| PRD v3 requirement area | Status | Local evidence and boundary |
|---|---|---|
| Gate A — actual server specifications and existing service/network inventory | missing | No host inventory evidence in the audited workspace; `data/kun-config-inventory/report.md` inventories agent config, not server hardware/services. |
| Gate B — four Namecheap capability classifications | missing | No current Namecheap capability inventory or restore proof located. |
| Gate C — audit of all four applications and dependencies | partial | Workspace includes project task reports/briefs and project tree references; no complete current four-project deployment/dependency audit evidenced in the reviewed local reports. |
| Gate D — persistent data classification | missing | No project data classification register found in the reviewed evidence. |
| Gate E — human/machine access matrix and approvers | partial | Agent authority and scoped-work rules are in root `AGENTS.md`; no production identity/access/expiry/approver matrix evidenced. |
| Target architecture and server-role placement (Hostinger public/control, Hetzner compute, Namecheap DR) | partial | PRD is present; board/controller/task records establish agent coordination only. No current implemented topology or host evidence found. |
| Hetzner base services, Coolify private access/recovery and reproducible Compose definitions | missing | No current host/Coolify runtime or infrastructure-as-code evidence found in audited local surface. Herdr is an agent runtime, not Coolify. |
| RabbitMQ project vhosts, users, permissions, queues, DLQs | missing | No current RabbitMQ configuration/runtime evidence found. |
| Qdrant project collections, credentials, snapshots (if used) | missing | No usage determination or Qdrant isolation/snapshot evidence found. |
| Browser worker isolation, network denial, resource ceilings and temporary workspace retention | partial | Firstmate has isolated agent worktrees and a concurrency cap; no production browser-pool/network/disk-retention configuration evidenced. |
| Project databases and scoped worker-result ingest | missing | No DB role/schema, ingest API, or production data-path evidence found. |
| Project file namespaces, upload controls, retention | missing | No production file-serving namespace/configuration evidence found. |
| Cloudflare/Tailscale/firewall/Docker network segmentation and public-port policy | missing | No current DNS, ACL, firewall, exposed-port or Docker-network evidence found. |
| Host/container/application security controls and multi-tenant denial tests | partial | `AGENTS.md` and Firstmate scripts provide agent authority/process controls; no production host/container/app security test results or tenant isolation proof found. |
| CI/CD, staging, production approval, health gate and rollback | partial | Firstmate has PR/task lifecycle and guarded merge scripts, and evidence reports describe app delivery work. No complete PRD-aligned infra CI, staging gate, or demonstrated production rollback evidence found. |
| Metrics, structured production logs, service alerts and tested thresholds | partial | Agent status and fleet snapshot/pane observation exist; they are not host/application metrics/logging/alert evidence required by PRD section 14. |
| Encrypted project backups, retention, checksum/manifest, restore verification | missing | No per-project backup manifests or restore-test evidence found. |
| DR runbooks, validated RPO/RTO, drills | missing | No current runbook/drill evidence found in audited local reports. |
| Agent swarm roles, human approvals, scoped tasks and evidence packs | partial | Root `AGENTS.md`, task metadata, brief/report structure, and Herdr panes provide substantial local agent governance. PRD's full named 15-role operating model, project authorization boundary evidence, and completed delivery packs are not established by this inventory. |
| Global acceptance checklist and final technical/client approvals | missing | No completed PRD acceptance checklist or final approval evidence found. |

## Gap table

Severity is for the PRD's multi-project production readiness, not proof of a live incident. Recommendations are the smallest evidence/configuration steps; no infrastructure modification is authorized by this study.

| Gap | Severity | Evidence paths | Smallest mechanical fix |
|---|---|---|---|
| No current host/server inventory is evidenced, so role placement and safety baseline cannot be checked | P1 | PRD §5 Gate A; `data/kun-config-inventory/report.md` (agent config scope); `data/br-system-herdr-audit/report.md` | Add a dated, sanitized inventory artifact for each server: provider/account identifier (redacted as needed), CPU/RAM/disk/OS, services, Docker/Coolify versions, firewall and DNS; collect read-only. |
| No four-target Namecheap classification or per-project DR evidence | P1 | PRD §5 Gate B, §§7.3, 15-16; audited `data/` report inventory | Add a one-row-per-target capability/ownership table and link encrypted backup/restore evidence; label unknowns explicitly. |
| Current four-project application/data/dependency audit and data classification are not evidenced | P1 | PRD §5 Gates C-D; `data/` reports; `deightonllm-firstmate/BOARD.md` | Create four project audit records and a data-classification register with owner and review date. |
| Production isolation, queue/database/file boundaries and access denial are not evidenced | P1 | PRD §§8-11, 20-21; root `AGENTS.md` covers agent policy only | Add sanitized configuration inventory plus explicit cross-project allow/deny test results; do not include credentials. |
| Backup/restore, DR objectives and drills are not evidenced | P1 | PRD §§15-16, 21-22; no corresponding report artifacts found in audited surface | Add per-project backup manifests, last restore test result, actual RPO/RTO and dated drill evidence; first obtain applicable human approval for any live test. |
| Deployment controls are visible as Firstmate task/PR lifecycle but PRD-aligned infrastructure staging/health/rollback evidence is incomplete | P1 | `bin/fm-pr-check.sh`, `bin/fm-pr-merge.sh`, `data/br-system-ticket-audit/report.md`, PRD §§12, 21 | Link the infrastructure repository/workflow, staged health-gate result and rollback exercise to one release evidence pack. |
| Existing board and controller status material is historical rather than current infrastructure evidence | P2 | `deightonllm-firstmate/BOARD.md` (last update 2026-09-27); `deightonllm-firstmate/CONTROLLER_STATE.md` (last update 2026-09-30); `data/kun-config-inventory/report.md` (2026-01-26) | Refresh the board/controller state with dated source links or clearly label as historical/archive. |
| Public-facing skills inventory is sparse compared with internal operating surface | P2 | `skills/stow/SKILL.md`; root `AGENTS.md` section 2; `.agents/skills/` | No PRD production blocker. Keep installer-facing versus internal skills distinction documented; no change needed for infrastructure readiness. |

## Remediation sequence

1. Complete PRD discovery gates A-E with dated, sanitized artifacts before rollout decisions.
2. Capture actual deployment/configuration evidence for Hetzner, Hostinger, and each backup target; do not infer deployed state from intended docs or agent runtime.
3. Map application dependencies to service placement, tenant boundaries, and role-specific credentials; test cross-project denial.
4. Add verifiable CI/staging/health/rollback and production evidence packs.
5. Establish encrypted per-project backup manifests and run approved restore/DR tests; record actual RPO/RTO.
6. Populate and review the PRD global acceptance checklist and required named approvals.

The study is complete (PASS) because the requested local surface was inventoried and compared against the PRD with evidence and explicit uncertainty boundaries. Production PRD conformance is **PARTIAL**, with major evidence gaps; this PASS is not production-readiness approval.
