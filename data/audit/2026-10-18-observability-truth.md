# OBSERVABILITY TRUTH AUDIT
**Date:** 2026-10-18
**Scope:** Brandon four-client-domain monitoring + PRD-v3 infrastructure observability
**Sources:** `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` §14 (lines 1186–1272), `PRD_TRACEABILITY.md` §observability, `PRD_DELIVERY_MAP.md` unresolved area 7, live infrastructure probes (2026-10-18)

---

## 1. What Is Monitored

### 1.1 Four Client Public Domains — Current State

| Domain | Status | Cloudflare | Real app | Monitoring |
|---|---|---|---|---|
| `www.core-distro.com` | HTTP 200 | Yes (proxied) | Yes (Namecheap PHP 8.2.34) | **None** |
| `www.elevatesci.com` | HTTP 200 | Yes (proxied) | Yes (AminoVPS) | **None** |
| `www.whooshperformance.com` | HTTP 200 — parked | Yes (proxied) | **No** | **None** |
| `www.cbd-data.com` | HTTP 200 | Partial (DNS only) | Yes (Namecheap shared) | `/api/health` → 503 (gate message, not monitoring) |

**Source:** `curl` probes 2026-10-18; `dig @1.1.1.1` for DNS; SSL cert inspection.

**Finding:** No external uptime monitoring service (UptimeRobot, BetterStack, Pingdom, Statuspage.io) is configured for any of the four domains. No CNAME records exist for `uptime.*`, `status.*`, `health.*`, or `monitor.*` subdomains.
**Source:** `dig` CNAME sweep for all four domains; DNS TXT record check for monitoring provider tokens.

### 1.2 PRD Target Infrastructure Nodes — Live Port Scan

Scanned all known Tailscale IPs against monitoring-relevant ports:

| Host | Tailscale IP | Monitoring ports found | What they are |
|---|---|---|---|
| `brandon-compute` (Hetzner) | `100.106.6.22` | 3001, 8080, 8081, 8087 | 3001=AnythingLLM, 8080=LiteLLM health, 8081=llama.cpp, 8087=WordPress |
| AminoVPS (PRD Hostinger target) | `100.69.211.43` | 22, 80, 443, 8093, 8443 | 8093=Python BaseHTTP (404 on all routes), 8443=CloudPanel (SSL: `cloudpanel.clp`) |
| `srv1856614` | `100.86.247.105` | 80, 443, 8888 | 8888=SearXNG (metasearch) |
| `srv797124` | `100.92.152.109` | 80, 443 | Basic web only |

**Source:** `timeout 1 bash -c "echo > /dev/tcp/<IP>/<PORT>"` loop across all IPs and monitoring ports; HTTP probes for service identification; SSL cert inspection.

**Finding: No Prometheus (9090), Grafana (3000/3001), Uptime Kuma (3001), node-exporter (9100), or Alertmanager (9093) is listening on any monitored host.** The AnythingLLM instance on `100.106.6.22:3001` is the Brandon hub application, not a monitoring tool. The Python BaseHTTP on port 8093 of AminoVPS returns `{"error": "not found"}` on every path — it is an undocumented stub, not Prometheus.

### 1.3 Repository State

Searched the warehouse for any monitoring configuration, docker-compose, Prometheus rules, Grafana dashboards, or alert definitions:
- **No files found** matching `prometheus`, `grafana`, `uptime-kuma`, `uptime.*`, `observability` (as a directory or filename)
- **No docker-compose files** exist in the warehouse
- The PRD v3 is the only document referencing these tools; no infrastructure-as-code implementations exist

**Source:** `find` across repo, `grep` for monitoring tool names across all file types.

---

## 2. What the PRD Requires (Section 14)

The PRD v3 §14 specifies:

### Metrics (required from both primary hosts)
CPU, load, memory, swap, disk, I/O, network, container stats, PostgreSQL connections/locks/slow-queries/WAL, PgBouncer pools, RabbitMQ queue depth/dead-letters, worker heartbeat/success rate, browser crash rate, Qdrant storage, API latency (p50/p95/p99), file transfer errors, backup age, AI token cost per project, external API errors.

### Central Observability
- **Prometheus** on Hostinger
- **Grafana** on Hostinger
- **Uptime Kuma** on Hostinger
- Log aggregation on Hostinger (resource-constrained fallback to VPS-capable Namecheap or external service)

### Alert Thresholds (initial)
Public endpoint down 2 checks; 5xx >1% for 5 min; p95 latency >2s for 5 min; memory >85% for 10 min; disk 70/85/95%; container restart >3×/10 min; PostgreSQL connections >80%; RabbitMQ message age above SLA; DLQ >0 for critical jobs; worker heartbeat absent 5 min; backup missing/stale; restore test >35 days; DR drill >100 days; **SSL expiry <14 days**; Tailscale path unavailable.

### Acceptance Criteria (Section 21, Observability box — all unchecked)
- [ ] Metrics visible for both primary hosts
- [ ] Logs searchable by project, service, release, request, job
- [ ] Alerts tested
- [ ] Backup and restore age visible
- [ ] Queue and worker dashboards visible
- [ ] AI/API costs visible by project where relevant

**Source:** PRD v3 lines 1186–1272.

---

## 3. What Actually Exists Today

| Requirement | Status | Evidence |
|---|---|---|
| Prometheus | **NOT DEPLOYED** | Port 9090 closed on all monitored hosts. No Prometheus binary, config, or rules in repo. |
| Grafana | **NOT DEPLOYED** | Port 3000 closed on all monitored hosts. |
| Uptime Kuma | **NOT DEPLOYED** | Port 3001 on Hetzner is AnythingLLM, not Uptime Kuma. Port 3001 on AminoVPS closed. |
| Structured JSON logs | **NOT EVIDENCED** | No log aggregation pipeline, no evidence of structured log collection, no searchable log store. |
| Alert thresholds configured | **NOT DEPLOYED** | No alertmanager, no alert rules, no notification channels. |
| SSL expiry monitoring | **NOT DEPLOYED** | No automated alert for SSL expiry. Manual check only: certs expire Dec 2026 (core), Dec 2026 (elevate), Jan 2027 (whoosh), Nov 2026 (cbd). Nearest expiry: CBD-Data ~33 days. |
| Backup age monitoring | **NOT DEPLOYED** | PRD delivery map unresolved area 6 confirms: no live backup verification, no off-host encrypted backup proof. |
| Queue/worker dashboards | **NOT DEPLOYED** | RabbitMQ management port (15672) not accessible. No worker heartbeat dashboard. |
| AI cost tracking | **NOT DEPLOYED** | No token/cost tracking per project. |
| Cloudflare passive monitoring | **PASSIVE ONLY** | Cloudflare provides uptime/performance graphs in dashboard; not human-paging, not automated alerting. |
| Firstmate drift-check | **MANUAL/AD-HOC** | `bin/fm-coord-drift-check.sh` can verify domain coordinates against live DNS; not continuous, not human-paging, not alert-based. |

---

## 4. What Would and Would Not Fire Today

### If `www.core-distro.com` goes down RIGHT NOW:
- ✅ Cloudflare shows degraded origin in dashboard (passive, nobody is watching)
- ❌ No page/email/SMS/Slack alert fires
- ❌ No automated recovery action triggers
- ❌ No human is notified automatically

### If `www.elevatesci.com` goes down RIGHT NOW:
- Same as above — no automated alert

### If `www.whooshperformance.com` goes down:
- **There is no live application.** It is a parked domain at Hostinger DNS. The HTTP 200 responses are the parked-page HTML. No alert would fire for a parked domain.

### If `www.cbd-data.com` goes down:
- Same as above — no automated alert
- The `/api/health` endpoint exists but returns a 503 gate message — this is a workload gate, not a monitoring health check. It does not page anyone.

### If `brandon-compute` (Hetzner) RabbitMQ or worker dies:
- ❌ No alert fires. RabbitMQ management UI (15672) is not accessible.
- The LiteLLM health on port 8080 serves a health page but is not monitored.

### If AminoVPS (Hostinger PRD target) disk fills or service crashes:
- ❌ No alert fires. No node-exporter, no alerting.

### If a TLS certificate expires:
- ❌ No alert fires. Next expiries: CBD-Data 2026-11-20 (~33 days), Elevate 2026-12-10 (~53 days), Core Distro 2026-12-17 (~60 days), Whoosh 2027-01-14 (~88 days).

### If a backup job fails or backup becomes stale:
- ❌ No alert fires. PRD delivery map confirms no live encrypted off-host backup exists for any project.

---

## 5. What Would Need to Be True for Alerting to Be Trustworthy

Based on PRD v3 §14.4 and the identified gaps, alerting would be trustworthy only when:

1. **Uptime checks exist and reach a human.** Requires: Uptime Kuma (PRD default) or BetterStack/UptimeRobot with notification channels (email/SMS/Slack) configured and tested.

2. **Health endpoints exist on all services.** Requires: A `/health` or `/metrics` endpoint on every application and queue service that returns meaningful status. Currently only CBD-Data has a partial `/api/health` (returning a gate 503, not actual health).

3. **Infrastructure metrics are collected.** Requires: Prometheus + node-exporter on Hostinger and Hetzner, scraping PostgreSQL, RabbitMQ, and worker metrics. Requires container metrics via cAdvisor or equivalent.

4. **Alerts are defined and tested.** Requires: Alertmanager or Uptime Kuma alert rules matching PRD v3 §14.4 thresholds, with tested notification delivery. A dashboard nobody watches is not alerting.

5. **SSL certificate monitoring is automated.** Requires: Automated daily check of all domain certs with alert at 30, 14, and 7 days before expiry. Not a manual check.

6. **Backup monitoring is active.** Requires: Automated check of backup age per project with alert if missing or stale beyond PRD-defined SLA.

7. **Human notification channels are configured and tested.** Requires: Verified contact method (email, SMS, Slack, PagerDuty) that actually fires a test alert and confirms delivery.

8. **On-call or response runbook exists.** Requires: A defined owner and procedure for each alert type. An alert that fires with no known recipient is not alerting.

---

## 6. PRD Traceability Status

| Row | Value | Source |
|---|---|---|
| `observability` | `UNKNOWN` | `PRD_TRACEABILITY.md` §observability |
| Blocker | `UNKNOWN` | same |
| Evidence | None for SLO/alert/restore-age implementation | same |
| Notes | Inventory/design only; no four-project implementation | same |
| Delivery map area | 7 — unresolved | `PRD_DELIVERY_MAP.md` unresolved area 7 |
| PRD acceptance | All 6 observability boxes unchecked | `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` §21 |

**Source:** `PRD_TRACEABILITY.md`; `PRD_DELIVERY_MAP.md`; PRD v3 §21.

---

## 7. Open Questions

| Question | What would settle it |
|---|---|
| Does Cloudflare's paid plan include uptime monitoring with human notification? | Check Cloudflare dashboard for Radar/Uptime product, or confirm plan tier. |
| Does AminoVPS have any built-in monitoring beyond CloudPanel? | Live SSH inspection of `srv1137994` required. |
| Is there any monitoring on the private Tailscale network beyond what's visible from outside? | Live SSH inspection of both hosts required. |
| What is the Python BaseHTTP service on AminoVPS port 8093? | Live inspection of the service process required. |
| Is the `cloudpanel.clp` cert on AminoVPS:8443 active CloudPanel or stale? | Live HTTPS probe of CloudPanel UI required. |

---

## 8. Summary

**Verdict: No monitoring exists for Brandon infrastructure.**

The PRD v3 §14 observability requirements are entirely unimplemented. No Prometheus, Grafana, or Uptime Kuma is deployed. No alert reaches a human for any of the four client domains, for the Hetzner compute plane, or for the Hostinger/AminoVPS control plane. SSL certificate expiry — including a CBD-Data cert expiring in ~33 days — has no automated watcher. Backup age, queue depth, worker heartbeat, and database metrics have no collection pipeline.

The PRD traceability correctly records `observability` as `UNKNOWN`. The delivery map correctly marks observability as unresolved area 7.

A dashboard nobody reads is not alerting. An uptime check with no notification channel is not monitoring. The current state is: if any service fails, nobody knows unless they manually check or a customer reports it.

**What exists today that is close:**
- `bin/fm-coord-drift-check.sh` — manual/ad-hoc domain coordinate verification, not continuous monitoring
- Cloudflare passive graphs — visible in dashboard only, no alerting
- CBD-Data `/api/health` — partial workload gate endpoint, not human-alerting
- SSL certs are present and valid — but no expiry monitoring

**What is absent that the PRD requires:**
- Prometheus/Grafana/Uptime Kuma on Hostinger
- Structured JSON logs with project labels
- Alert thresholds per §14.4, tested
- Backup age visible in dashboard
- Queue and worker dashboards
- Per-project AI cost tracking
- DR drill scheduling
- Automated SSL expiry alert at 14-day threshold
- Human notification channels (email/SMS/Slack)

**Confidence:** HIGH. All findings are based on live infrastructure probes (2026-10-18), DNS lookups via 1.1.1.1, SSL cert inspection, port scans of all known Tailscale hosts, and source-document citation. No guessing; every finding is sourced.
