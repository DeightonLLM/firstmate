# Gate E — Production isolation, queue, database, and file boundaries

**Capture date:** 2026-10-05 (UTC; exact time unavailable)  
**VERDICT: PARTIAL** — PRD requirements and available local evidence were reviewed, but live production configuration and denial tests could not be verified. This is not a production-isolation approval.

## Scope and method

Read-only study of the Brandon-compute surface and the available PRD/report artifacts. No service was changed, no credentials were accessed, and no isolation test was run. The requested task inbox path `/home/hd2admin/kun-agent-workspace/state/hetz-gate-E-20261005.inbox` did not exist; there were no messages to handle. An attempted `docker ps` through `lean-ctx -c` was rejected because Docker is not in the shell allowlist; the tool explicitly instructed not to retry. This was not retried and no allowlist was changed.

Evidence sources: `deightonllm-firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (target requirements); `.../from-brandon-compute/2026-10-05-hetz-study-report.md` (prior local-surface boundary); `.../from-brandon-compute/2026-10-05-hetz-gate-A-host-inventory.md` (Docker access limitation). Historical mentions of a `brandon-cbd-rabbitmq` container are not current configuration evidence.

## Inventory findings

| Area | Current observed inventory | Isolation evidence / result |
|---|---|---|
| RabbitMQ | **Unknown.** No live vhost, user, permission, queue, binding, or DLQ definitions captured. Prior report mentions a `brandon-cbd-rabbitmq` container; its existence/configuration was not independently verified. | No cross-project publish/consume denial test was run. PRD §7 requires separate project vhosts and prohibits multi-vhost worker credentials absent documented approval. |
| Qdrant | **Unknown whether used.** No live collection list, API key scope, network policy, or snapshot evidence available. | No cross-project query denial test run. PRD §7 specifies project-separated collections and restricted access if Qdrant is required. |
| Project databases | **Unknown.** No production database endpoint or catalog was inspected; project databases, roles, schemas, grants, PgBouncer mappings, and ingest API are not evidenced by this study. | No cross-project database query/write attempt. PRD §8.1 calls for one database per project and distinct least-privilege read/write, migration, API, ingest, and reporting roles as needed; workers must not receive unrestricted database credentials. Ingest should validate project identity and stage/promote through trusted service boundaries. |
| File/object namespaces | **Unknown.** No production object store, bucket/prefix policy, upload/download API, retention rule, or project namespace was inventoried. | No cross-project path traversal/object access test run. PRD §9.2 requires project file namespaces, generated object IDs, and cross-project path-traversal testing. |
| Network/service boundary | **Unknown.** Current production topology, service network membership, firewall rules, and endpoint exposure were not evidenced. Gate A reports Docker and listening-port inspection were denied by its active allowlist. | No network reachability or tenant-boundary test run. |

## Isolation test record

| Test | Result | Evidence |
|---|---|---|
| Project A allowed to access its own queue/database/files | Not run; no authorized, non-mutating test identity/endpoints supplied. | No positive allow evidence. |
| Project A denied access to Project B queue/vhost | Not run. | No denial evidence. |
| Project A denied access to Project B database/schema/rows or ingest scope | Not run. | No denial evidence. |
| Project A denied access to Project B Qdrant collection | Not run; whether Qdrant is used is unknown. | No denial evidence. |
| Project A denied access to Project B file namespace / traversal | Not run. | No denial evidence. |

Tests were intentionally not improvised: production access was not established, and a meaningful denial test requires approved scoped test credentials and endpoints. No commands capable of modifying services or data were run.

## PRD assessment and gaps

The PRD defines intended safeguards, not proof that production implements them. Current evidence is insufficient to establish any production queue, vector, database, or file isolation control. To close this gate, obtain dated sanitized read-only exports/configuration for each production service and record the identity/role used, exact allowed scope, and paired same-project allow / cross-project deny outcomes. Include queues and DLQs, database schemas and grants plus ingest validation, Qdrant scope if deployed, and object storage policy/path checks. Explicitly state “not deployed” where a service is unused rather than inferring absence from this local workspace.

**Conclusion:** No observed evidence proves a production boundary is broken, but there is also no current evidence demonstrating these boundaries or their denial behavior. Gate E remains PARTIAL pending authorized production evidence and cross-project tests.
