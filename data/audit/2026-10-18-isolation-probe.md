# Platform Isolation Probe — 2026-10-18

**Lane:** PLATFORM ISOLATION  
**Source documents:** PRD v3 (2026-08-04), PRD_TRACEABILITY.md, PRD_DELIVERY_MAP.md  
**Status vocabulary:** DELIVERED | EVIDENCED | IN_PROGRESS | BLOCKED | UNKNOWN

---

## Executive Summary

| Finding | Status | Severity |
|---------|--------|----------|
| Client domains resolved to measured IPs | EVIDENCED | — |
| No client domain proxies to HD2-internal endpoint (DNS level) | EVIDENCED | — |
| **llm.hd2.ai referenced in live client-delivered asset (core-distro.com)** | EVIDENCED | **HIGH** |
| Port 8081 closed on all production IPs | EVIDENCED | — |
| Port 8081 open on brandon-compute (PRD target) | EVIDENCED | INFO |
| Per-domain isolation evidence vs claims | UNKNOWN | **CRITICAL** |

---

## 1. Client Domain DNS Resolution

Measured via `dig @1.1.1.1` to bypass localhost `/etc/hosts` trap.

| Domain | Measured IP | Provider/AS | Cloudflare? |
|--------|------------|-------------|-------------|
| `www.core-distro.com` | 172.67.221.192 | Cloudflare | YES |
| `www.elevatesci.com` | 172.67.214.115 | Cloudflare | YES |
| `www.whooshperformance.com` | 2.57.91.91 | Hostinger (AS47583) | NO |
| `www.cbd-data.com` | 68.65.123.217 | Namecheap (AS22612) | NO |

**Source:** `dig @1.1.1.1` commands, `ipinfo.io` for AS lookup (lines 1-4)

---

## 2. PRD Target Infrastructure vs Actual

| Role | PRD v3 Name | PRD Target IP | Actual Production IP | Match? |
|------|-------------|---------------|---------------------|--------|
| Hostinger edge | `bdn-edge-01` / `srv1856614` | 2.25.197.26 | See above | NO |
| Hetzner compute | `brandon-prod` / `bdn-compute-01` | 100.106.6.22 | N/A (not live) | NO |

**PRD v3 §7.1** claims Hostinger hosts public/control plane; **PRD v3 §7.2** claims Hetzner hosts compute plane.

**Evidence:**
- `PRD_TRACEABILITY.md` lines 192-193: "Existing HD2 `llm.hd2.ai` does not satisfy Brandon delivery"
- `PRD_DELIVERY_MAP.md` line 40: "No accepted evidence proves four production queue namespaces, worker denial tests, project-scoped ingest, file namespaces, database roles, or Qdrant collection isolation"
- `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-hetz-WHO-OWNS-STAGING-exact-question.md` line 14: Hostinger `srv1856614` IP listed as 2.25.197.26

---

## 3. HD2-Internal Service Exposure Check

### 3.1 llm.hd2.ai Reference in Live Assets

**FINDING: EVIDENCED — Client domain loads internal HD2 service**

The `www.core-distro.com` page contains:

```html
<script data-cfasync="false" data-embed-id="0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2" 
  data-base-api-url="https://llm.hd2.ai/api/embed" 
  data-assistant-name="Core Distro Assistant" 
  data-sponsor-text="Powered by HD2.ai" 
  src="https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js" defer="">
```

**Source:** `curl -s https://www.core-distro.com` output, grep for `llm.hd2.ai`

**Contrast:** `www.elevatesci.com` loads its widget from `agents.elevatesci.com` (client-scoped):

```html
src="https://agents.elevatesci.com/embed/anythingllm-chat-widget.min.js"
```

**Policy conflict:** `docs/policy/client-infra-isolation.yaml` declares:
- `llm.hd2.ai`: "HD2 internal LLM service - not for client use"
- `hd2stack` (vmi3238503): "TEST ONLY, never client-facing"

**Severity:** HIGH — Core Distro (a client project) depends on an HD2-internal service for its chatbot functionality. If `llm.hd2.ai` is degraded, the client site chatbot breaks.

### 3.2 DNS-Level Isolation Check

The existing `bin/fm-client-infra-isolation-check.sh` validates that client domains do not resolve to test-only hosts.

| Check | Result |
|-------|--------|
| Client endpoint DNS resolution | PASS — no client domain resolves to hd2stack or srv797124 |
| Host classification alignment | PASS — domains resolve to non-test-only infrastructure |

**Source:** `bin/fm-client-infra-isolation-check.sh` output (lines 1-47)

**Limitation:** This check validates DNS resolution, not resource loading. The llm.hd2.ai finding above is NOT caught by this check.

---

## 4. Port 8081 Status

| Host | IP | Port 8081 | Notes |
|------|----|-----------|-------|
| core-distro.com production | 66.29.153.174 | CLOSED | Namecheap |
| agents.core-distro.com | 161.97.120.4 | CLOSED | Contabo |
| whooshperformance.com | 2.57.91.91 | CLOSED | Hostinger |
| cbd-data.com | 68.65.123.217 | CLOSED | Namecheap |
| brandon-compute (PRD target) | 100.106.6.22 | **OPEN** | Returns "gzip is not supported" (Metabase signature) |
| srv1856614 (PRD target) | 2.25.197.26 | CLOSED | Hostinger |

**Source:** `timeout 3 bash -c "echo > /dev/tcp/$ip/8081"` commands (lines 14-18)

**PRD v3 §10.3** says Hetzner should have "ideally none" public ports. Port 8081 on brandon-compute appears to be a Metabase or analytics service.

---

## 5. Per-Domain Isolation Table

Measured column shows what was verified; Claimed column shows what PRD v3 requires.

| Domain | Measured | Claimed (PRD v3) | Delta | Finding |
|--------|----------|-------------------|-------|---------|
| **Core Distro** | | | | |
| DNS resolution | 172.67.221.192 (Cloudflare) / 66.29.153.174 (Namecheap per PRD notes) | Hostinger `srv1856614` (2.25.197.26) | **MISMATCH** | Production NOT on PRD target |
| Database | UNKNOWN — PHP 8.2.34 / LiteSpeed (per PRD notes) | PostgreSQL + PgBouncer, project database per §8.1 | **MISMATCH** | UNKNOWN |
| Worker queue | UNKNOWN | Hetzner RabbitMQ `/core` vhost per §7.2 | **MISMATCH** | UNKNOWN |
| Chatbot | Loads from `llm.hd2.ai` (HD2-internal) | Should use Brandon-scoped LLM per PRD v3 | **VIOLATION** | Architecture boundary breach |
| **Elevate Life Sci** | | | | |
| DNS resolution | 172.67.214.115 (Cloudflare) | Hostinger `srv1856614` per §7.1 | **MISMATCH** | Production NOT on PRD target |
| Database | UNKNOWN | PostgreSQL, `brandon_elevate` database per §8.1 | **UNKNOWN** | UNKNOWN |
| Worker queue | UNKNOWN | Hetzner RabbitMQ `/elevate` vhost per §7.2 | **UNKNOWN** | UNKNOWN |
| Chatbot | Loads from `agents.elevatesci.com` (client-scoped) | Should use Brandon-scoped LLM per PRD v3 | Neutral | Widget scoped to client domain |
| **Whoosh Performance** | | | | |
| DNS resolution | 2.57.91.91 (Hostinger) | Hostinger `srv1856614` per §7.1 | **MISMATCH** | Hostinger, but NOT the PRD target instance |
| Database | UNKNOWN | PostgreSQL, `brandon_whoosh` database per §8.1 | **UNKNOWN** | UNKNOWN |
| Worker queue | UNKNOWN | Hetzner RabbitMQ `/whoosh` vhost per §7.2 | **UNKNOWN** | UNKNOWN |
| Chatbot | NOT FOUND | Should have scoped chatbot per PRD v3 | Neutral | No chatbot detected |
| **CBD-Data** | | | | |
| DNS resolution | 68.65.123.217 (Namecheap) | Hostinger `srv1856614` per §7.1 | **MISMATCH** | Production NOT on PRD target |
| Database | UNKNOWN | PostgreSQL, `brandon_cbddata` database per §8.1 | **UNKNOWN** | UNKNOWN |
| Worker queue | UNKNOWN | Hetzner RabbitMQ `/cbddata` vhost per §7.2 | **UNKNOWN** | UNKNOWN |
| Chatbot | NOT FOUND | Should have scoped chatbot per PRD v3 | Neutral | No chatbot detected |

---

## 6. Isolation Evidence Assessment

| Isolation Layer | PRD v3 Requirement | Evidence Status | Gap |
|-----------------|-------------------|----------------|-----|
| Network (DNS) | Client domains resolve to client infrastructure | PARTIAL | Whoosh on Hostinger but not the PRD instance |
| Database | One PostgreSQL database per project | **UNKNOWN** | No access to verify |
| Queue | RabbitMQ vhost per project | **UNKNOWN** | No access to verify |
| Worker | Hetzner workers per project | **UNKNOWN** | No access to verify |
| File | `/srv/brandon-files/<project>/` namespace | **UNKNOWN** | No access to verify |
| Qdrant | Project-prefixed collections | **UNKNOWN** | No access to verify |
| Secrets | Separate per-project credentials | **UNKNOWN** | No access to verify |

**Source:** PRD v3 §8 (Data and Service Isolation); PRD_TRACEABILITY.md `platform-isolation` row

**PRD_TRACEABILITY.md** `platform-isolation` row states:
> Status: UNKNOWN  
> Evidence: none surfaced for end-to-end isolation  
> Notes: No accepted evidence proves four production queue namespaces, worker denial tests, project-scoped ingest, file namespaces, database roles, or Qdrant collection isolation

---

## 7. Findings Summary

| ID | Severity | Domain | Finding | Evidence |
|----|----------|--------|---------|----------|
| ISO-001 | **CRITICAL** | Cross-project | **Per-domain isolation is UNKNOWN** — no accepted evidence proves any isolation layer | PRD_TRACEABILITY.md `platform-isolation` row; PRD v3 §8 |
| ISO-002 | **HIGH** | Core Distro | **Client domain loads HD2-internal service** — `www.core-distro.com` embeds `llm.hd2.ai` widget | `curl https://www.core-distro.com` output |
| ISO-003 | MEDIUM | Cross-project | **Production NOT on PRD target infrastructure** — all four projects on non-PRD hosts | `dig @1.1.1.1` resolution; `ipinfo.io` AS lookup |
| ISO-004 | LOW | Brandon compute | **Port 8081 open on brandon-compute** — Metabase or similar service | `timeout 3 bash -c "echo > /dev/tcp/100.106.6.22/8081"` |
| ISO-005 | INFO | Cross-project | PRD target Hostinger (srv1856614, 2.25.197.26) not serving any client domains | `dig` resolution results |

---

## 8. Commands Run

| Command | Output | Source Line |
|---------|--------|-------------|
| `dig +short @1.1.1.1 A www.core-distro.com` | 172.67.221.192 | This probe |
| `dig +short @1.1.1.1 A www.elevatesci.com` | 172.67.214.115 | This probe |
| `dig +short @1.1.1.1 A www.whooshperformance.com` | 2.57.91.91 | This probe |
| `dig +short @1.1.1.1 A www.cbd-data.com` | 68.65.123.217 | This probe |
| `curl -sI https://llm.hd2.ai` | HTTP/2 200, Cloudflare, Express | This probe |
| `curl -s https://www.core-distro.com \| grep llm.hd2.ai` | Widget script and API URL found | This probe |
| `curl -s https://www.elevatesci.com \| grep anythingllm` | Widget from agents.elevatesci.com | This probe |
| `ipinfo.io/2.57.91.91` | Hostinger (AS47583) | This probe |
| `timeout 3 bash -c "echo > /dev/tcp/100.106.6.22/8081"` | OPEN | This probe |
| `timeout 3 bash -c "echo > /dev/tcp/66.29.153.174/8081"` | CLOSED | This probe |
| `bash bin/fm-client-infra-isolation-check.sh` | PASS (DNS-level only) | This probe |

---

## 9. Open Risks / Questions

| Risk | What Would Settle It |
|------|---------------------|
| No evidence of database isolation | Direct database query access to production PostgreSQL |
| No evidence of queue isolation | Direct RabbitMQ vhost inspection on brandon-compute |
| No evidence of worker isolation | Host access to Hetzner compute plane |
| Core Distro llm.hd2.ai dependency | Source code audit of core-distro.com deployment |
| PRD target hosts not in production use | Live access to srv1856614 and brandon-compute |

---

## 10. Recommended Next Steps

1. **ISO-002 remediation:** Repoint Core Distro chatbot to Brandon-scoped AnythingLLM (not llm.hd2.ai)
2. **Isolation audit:** Obtain production database and queue access to verify isolation layers
3. **Architecture ADR:** Resolve PRD target vs actual hosting discrepancy
4. **Expand isolation check:** Add resource-loading validation to `fm-client-infra-isolation-check.sh`

---

*Report generated: 2026-10-18*  
*Source PRD: docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md (v3.0, 2026-08-04)*  
*PRD traceability status as of: PRD_TRACEABILITY.md*
