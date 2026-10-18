# Whoosh Performance — Status Brief

**As of:** 2026-10-18
**Authoritative requirements:** [`whoosh-performance-wp-data-outreach-prd-v1.0.md`](whoosh-performance-wp-data-outreach-prd-v1.0.md), v1.0 (2026-10-17). This brief is not a second PRD; scope, non-goals, acceptance criteria, rollout, and decisions are defined only in v1.0.
**Overall:** `BLOCKED` — coordinates missing; no eligible implementation lane.

## Current status

| Item | Status | Evidence / limitation |
|---|---|---|
| `whoosh-audit` | `BLOCKED` (`COORDINATES_MISSING`) | `PRD_TRACEABILITY.md` row and `PRD_DELIVERY_MAP.md` unresolved area 1; exact repository, hosting, runtime, and production IP are required. |
| `whoosh-bot-routing` | `UNKNOWN` | No accepted completion artifact surfaced in `PRD_TRACEABILITY.md`; do not claim complete. |
| `whoosh-service` / `whoosh-runtime` | `BLOCKED` | Service catalogue / host inventory records; coordinates missing (runtime record dated 2026-09-12). |
| Apex and `www` | `EVIDENCED` (reported measurement, 2026-10-18) | Reported HTTP 200 parked-domain response; reported byte-identical body, no redirect. Raw measurement output was not independently re-run for this brief. |
| `data` and `lc` hostnames | `UNKNOWN` current DNS state; `OPEN CONFLICT` with v1.0 §2.5 | v1.0 §2.5 reports HTTPS 502 on 2026-10-17; a separate 2026-10-18 report says curl exited without an HTTP response. The latter lacks DNS query type, resolver, DNS response code, and raw output here. It does not establish NXDOMAIN, absent records, or absent origin. Settle with timestamped DNS queries against named resolvers and preserved raw output, plus HTTP probes if names resolve. |
| WordPress, data service, Aspire, repository, hosts, backup, inbox | `UNKNOWN` | No accepted implementation or measurement evidence is cited in this status brief. This is not evidence that these do not exist. |

## Open blocker and next evidence

- The exact project coordinates remain the blocker recorded by the traceability ledger. No implementation or remediation path should be inferred until they are supplied.
- Preserve the historical 502 and no-HTTP-response readings as separate dated evidence; neither supersedes the other. A curl failure alone cannot establish DNS-record absence or host absence.
- `whoosh-bot-routing` remains `UNKNOWN` until its accepted artifact is identified.

## Source boundary

The authoritative v1.0 PRD remains unchanged and owns project requirements and acceptance. Shared v3 Phase 5 ordering places Whoosh after Core Distro and Elevate and before CBD-Data; that ordering is a planning reference, not evidence that any Whoosh gate has passed.
