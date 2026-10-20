# Hetzner Gate A — Host/Server Inventory Report
**Date**: 2026-10-12 (captured)
**Scope**: Read-only inventory of Hetzner dedicated host(s) used by Brandon-Compose
**Status**: PARTIAL — live Docker enumeration included; host hardware from prior audit

---

## 1. Hosts

| Field | Value |
|-------|-------|
| **Host alias** | `brandon-compute` (also `hetzner-compute`) |
| **Provider** | Hetzner |
| **Asset type** | Dedicated server |
| **Server model** | AX42-2 |
| **Datacenter** | HEL1-DC9 |
| **Tailscale IP** | `100.106.6.22` |
| **Public IP (last octet)** | `.39` |
| **SSH target** | Tailscale-only, key auth as `hd2admin` |
| **Role** | Compute plane for Brandon local LLM/model testing, benchmarks, scraping, enrichment, Qdrant, and bounded worker preparation |

### Hardware Specs (from 2026-10-07 audit)

| Metric | Value |
|--------|-------|
| CPU | 16 cores AMD Ryzen 7 PRO 8700GE |
| RAM Total | 61 GiB |
| RAM Available | ~47 GiB |
| Disk Total | 437 GiB |
| Disk Used | ~100 GiB (24%) |
| Uptime | ~12+ days |

---

## 2. VMs / Running Containers

Enumeration via `docker ps` on host (live output, 2026-10-12).

| Container Name | Image | Role | Port(s) | Status |
|----------------|-------|------|---------|--------|
| `core-distro-stage-wordpress-1` | wordpress:latest | web | `100.106.6.22:8087->80` | Up 2d (healthy) |
| `core-distro-stage-database-1` | mariadb:11 | db | `3306/tcp` | Up 2d (healthy) |
| `elevate-anythingllm` | mintplexlabs/anythingllm:1.16.2 | web | `100.106.6.22:3001->3001`, `127.0.0.1:3001->3001` | Up 7d (healthy) |
| `1Panel-ai-gateway-sVzj` | 1panel/ai-gateway:v1.3.0 | web | `0.0.0.0:8080->8080` | Up 12d (healthy) |
| `ollama` | ollama/ollama:latest | worker | `127.0.0.1:11434->11434` | Up 13d |
| `brandon-cbd-rabbitmq` | rabbitmq:4.3.6-management-alpine | worker | `100.106.6.22:5672->5672`, `127.0.0.1:15672->15672` | Up 13d (unhealthy) |

**Running container count**: 6

### Role Summary

| Role | Count | Containers |
|------|-------|------------|
| web | 3 | wordpress, anythingllm, ai-gateway |
| db | 1 | mariadb |
| worker | 2 | ollama, rabbitmq |

---

## 3. Stacks

### Compose Stacks (top-level `/home/hd2admin/campaign/`)

| Stack Name | Path | Services |
|------------|------|----------|
| `core-distro-stage` | `/home/hd2admin/campaign/core-distro-stage/compose.yaml` | wordpress, database (mariadb) |
| `hd2stack-anythingllm` | `/home/hd2admin/hd2stack-anythingllm/docker-compose.yml` | anythingllm |

### Candidate Stacks (inventoried but NOT installed)

These stacks are documented in `/home/hd2admin/vps-ops/brandon-lab/inventories/` but verified NOT running on the host:

| Stack | Version | Status |
|-------|---------|--------|
| kestra | v2.0.0 (LTS) | NOT installed |
| multica | v0.5.1 | NOT installed |
| paperclip | v2026.916.0 | NOT installed |
| rowboat | v0.8.3 | NOT installed |

---

## 4. Open Questions

1. **Additional Hetzner hosts?** Evidence reviewed points to `brandon-compute` as the sole Hetzner dedicated server. No other Hetzner assets documented in HOSTS.md.

2. **AI gateway version mismatch**: Inventory shows `v1.3.0` running; prior audit recorded `v1.2.0`. Version was upgraded between audits.

3. **RabbitMQ health**: `brandon-cbd-rabbitmq` shows "unhealthy" status for 13 days. Impact on dependent services (cbd-data) unknown.

4. **Backup posture**: No backup configuration documented for Docker volumes (mariadb, anythingllm storage, ai-gateway storage).

5. **Firewall rules**: Public ports (`.39:8087`, `.39:3001`, `.39:5672`) not verified against firewall configuration.

---

## Evidence Sources

| Source | Location |
|--------|----------|
| HOSTS.md | `/home/hd2admin/kun-agent-workspace/docs/system-context/HOSTS.md` |
| Capacity audit | `/home/hd2admin/controller-replies/hetz-capacity-policy-audit-20261007-report.md` |
| Docker enumeration | `docker ps` (live, 2026-10-12) |
| Compose stacks | `/home/hd2admin/campaign/core-distro-stage/compose.yaml`, `/home/hd2admin/hd2stack-anythingllm/docker-compose.yml` |
| Candidate inventories | `/home/hd2admin/vps-ops/brandon-lab/inventories/` |

---

*Report generated 2026-10-12. Sanitized: IPs show last octet only, no credentials, no API keys.*
