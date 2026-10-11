# BR-INV-001: Brandon Campaign — Phase 0 Server Inventory

**Task:** BR-INV-001  
**Phase:** 0  
**Scope:** Campaign repository artifacts only  
**Status:** Discovery draft — awaiting M3 review  
**Repository:** `deightonllm-firstmate`  
**Branch:** `main`

---

## Executive Summary

This report inventories the server infrastructure allocated to Brandon's campaign per `Brandon-Multi-Project-Infrastructure-PRD-v3.md`. The PRD defines three infrastructure tiers:

| Tier | Per PRD v3 | Evidence status |
|------|:-----------|:---------------|
| Hostinger KVM8 | Public and control plane | **Partially evidenced** — AminoVPS (`srv1137994-aminolifesciences`) is documented; OS/CPU/RAM/disk specs not in workspace |
| Hetzner dedicated | Compute plane (scraping, workers, queues) | **No evidence** — zero references to Hetzner exist in the workspace |
| Four Namecheap accounts | One DR target per project | **Partially evidenced** — four accounts found; project assignments per PRD not evidenced |

**Critical finding: No Hetzner server is evidenced anywhere in the workspace.** The PRD names it `brandon-prod` or proposed hostname `bdn-compute-01`, but no IP, credentials, SSH path, or specifications are documented. This is a `COORDINATES_MISSING` blocker for any downstream task that depends on Hetzner (BR-ARCH-001, BR-GATE-001, and all compute-plane work).

The four Namecheap accounts documented here (`server401`, `business186`, `business125-5`, `hd2data`) are the general-purpose HD2Stack accounts; PRD v3 specifies they should serve as per-project DR targets, but the per-project assignment (Core, Elevate, Whoosh, CBD-Data) is not yet evidenced in the workspace.

> **Note on the prior draft:** The previous `report.md` at this path documented the HD2Stack infrastructure (Hostinger `srv797124`, Contabo `vmi3238503`). That inventory is **not** the Brandon campaign infrastructure. This report supersedes it with the correct Brandon scope.

---

## Inventory Schema

| Field | Description |
|:------|:------------|
| Provider | VPS/hosting provider name |
| Host identifier | Provider internal ID, hostname, or alias |
| Role | Documented function per PRD v3 |
| OS | Operating system ( distro and version) |
| CPU | Processor model and core count |
| RAM | Memory size |
| Disk | Storage type, size, and used/available capacity |
| Network | IPs (public and private/Tailscale), SSH path, domains |
| Docker/Coolify | Container runtime version, Coolify version and state |
| Firewall | Firewall configuration and exposed ports |
| Backup posture | Backup class and coverage |
| Unknown | Fields with no workspace evidence |
| Provenance | Source files that establish each field |

---

## Host 1 — Hostinger KVM8 VPS

**PRD v3 role:** Public and control plane — all customer-facing services, primary application control plane, and shared management services  
**PRD proposed hostname:** `bdn-edge-01`  
**Current documented identifier:** `srv1137994-aminolifesciences` (Hostinger internal ID), SSH alias `animovps`

| Field | Value | Provenance |
|:------|:------|:----------|
| **Provider** | Hostinger | `L1_AMINOVPS_V2_REMOTE_INVENTORY_20260714.md` §2 |
| **Host identifier** | `srv1137994-aminolifesciences` (Hostinger); alias `animovps` | `AMINOVPS_COORDINATE_MAP_20260711.md`; `SOURCE_OF_TRUTH_COMPACT.md` §2.1 |
| **Tailscale IP** | `100.69.211.43` | `AMINOVPS_COORDINATE_MAP_20260711.md` |
| **SSH path** | `tailscale ssh animovps` (documented); direct Tailscale target `100.69.211.43` | `AMINOVPS_COORDINATE_MAP_20260711.md` |
| **Role** | Hostinger KVM8 — Brandon edge/control plane (per PRD v3 §7.1) | `Brandon-Multi-Project-Infrastructure-PRD-v3.md` §7.1 |
| **OS** | **UNKNOWN** — not documented in workspace | No source file records distro or version |
| **CPU** | **UNKNOWN** | No source file records CPU model or core count |
| **RAM** | **UNKNOWN** | No source file records RAM size |
| **Disk** | **UNKNOWN** — total size and usage not documented | No source file records disk capacity or current usage |
| **Docker** | Docker `29.1.3` — active | `L1_AMINOVPS_V2_REMOTE_INVENTORY_20260714.md` §2 |
| **Coolify** | **UNKNOWN** — not documented | No source file records Coolify presence or version |
| **Nginx** | Active | `L1_AMINOVPS_V2_REMOTE_INVENTORY_20260714.md` §2 |
| **MySQL** | Active — Percona Server `8.4.10-10` | `L1_AMINOVPS_V2_REMOTE_INVENTORY_20260714.md` §2 |
| **PHP CLI** | `8.4.22` | `L1_AMINOVPS_V2_REMOTE_INVENTORY_20260714.md` §2 |
| **Node.js** | `v22.19.0` | `L1_AMINOVPS_V2_REMOTE_INVENTORY_20260714.md` §2 |
| **Python** | `3.12.3` | `L1_AMINOVPS_V2_REMOTE_INVENTORY_20260714.md` §2 |
| **Composer** | `2.8.12` | `L1_AMINOVPS_V2_REMOTE_INVENTORY_20260714.md` §2 |
| **Core-Distro staging** | `127.0.0.1:3113` (Next.js, active) | `aminovps-ports.md`; `CORE_DISTRO_HETZNER_MIGRATION_READINESS.md` §2 |
| **Core-Distro production port** | `127.0.0.1:3117` (registered, not started) | `aminovps-ports.md` |
| **CBD-Data worker** | Active — `cbd-worker.service` running on AminoVPS | `CBD_RECOVERY_AMINOVPS_WORKER_HANDOFF_20260801T183000Z.md` |
| **Network — public IP** | **UNKNOWN** — no workspace source records the public IP of `srv1137994-aminolifesciences` | No source file |
| **Domains routed** | `staging.core-distro.com` (confirmed); other Brandon project domains not evidenced on this host | `CORE_DISTRO_HETZNER_MIGRATION_READINESS.md` §2; `aminovps-ports.md` |
| **Firewall** | **UNKNOWN** — no UFW or firewall rules documented for this host | No source file |
| **Backup posture** | **UNKNOWN** — no backup configuration documented for this host | No source file |
| **Disk usage** | **UNKNOWN** | No source file records current disk utilization |

**Provenance sources for Hostinger KVM8:**

| Source file | Information extracted |
|:------------|:---------------------|
| `L1_AMINOVPS_V2_REMOTE_INVENTORY_20260714.md` | Host ID, runtimes, Docker version, active services |
| `AMINOVPS_COORDINATE_MAP_20260711.md` | Tailscale IP, SSH alias, remote receive directory |
| `aminovps-ports.md` | Registered ports, staging/production port assignments |
| `SOURCE_OF_TRUTH_COMPACT.md` §2.1 | SSH path, confirmed Tailscale target |
| `CORE_DISTRO_HETZNER_MIGRATION_READINESS.md` §2 | Staging URL, verified staging state |
| `CORE_DISTRO_HETZNER_MIGRATION_READINESS.md` §3 | Explicit confirmation: zero Hetzner references in workspace |
| `CBD_RECOVERY_AMINOVPS_WORKER_HANDOFF_20260801T183000Z.md` | CBD worker service on AminoVPS |

**Hostname drift note:** PRD v3 §7.1 proposes hostname `bdn-edge-01`. The documented SSH alias and Hostinger internal ID are `animovps` and `srv1137994-aminolifesciences`. A formal hostname rename is outside Phase 0 scope and would require a separate architecture decision record.

---

## Host 2 — Hetzner Dedicated Server

**PRD v3 role:** Compute plane — scraping, browser automation, enrichment, AI execution, background jobs, queue consumers, temporary processing data  
**PRD proposed hostname:** `brandon-prod` (existing) or `bdn-compute-01` (if renamed)

| Field | Value | Provenance |
|:------|:------|:----------|
| **Provider** | Hetzner | Per PRD v3 §7.2; **no workspace evidence** |
| **Host identifier** | **UNKNOWN** — no hostname documented | No source file |
| **Public IP** | **UNKNOWN** | No source file |
| **Role** | Compute plane (per PRD v3 §7.2) | `Brandon-Multi-Project-Infrastructure-PRD-v3.md` §7.2 |
| **OS** | **UNKNOWN** — no workspace evidence | No source file |
| **CPU** | **UNKNOWN** | No source file |
| **RAM** | **UNKNOWN** | No source file |
| **Disk** | **UNKNOWN** | No source file |
| **Docker** | **UNKNOWN** | No source file |
| **Coolify** | **UNKNOWN** | No source file |
| **Network** | **UNKNOWN** | No source file |
| **Firewall** | **UNKNOWN** | No source file |
| **Backup posture** | **UNKNOWN** | No source file |

**Provenance — NONE:**

The workspace contains **zero references to any Hetzner server**. A targeted scan was conducted across:

| Scope | Command / method | Result |
|:------|:----------------|:-------|
| `/root/agent-work/` | `grep -ri "hetzner"` | 0 results |
| `/root/docs/operations/` | `grep -ri "hetzner"` | 0 results |
| `/root/.secrets/` | `grep -ri "hetzner"` | 0 results |
| `/root/.env*` | `grep -ri "hetzner"` | 0 results |
| `/root/.ssh/config` | `grep -i "hetzner"` | 0 results |
| ACCESS_BASELINE_REGISTRY.md | Host Roles table | Lists Contabo + Hostinger `srv797124` only; no Hetzner |
| AminovPS_SSH_RUNBOOK.md | Full document | Documents Contabo Tailscale mesh only; no Hetzner references |
| AminovPS_CAPABILITIES.md | Full document | Documents Contabo + AminoVPS scope; no Hetzner references |

Source: `CORE_DISTRO_HETZNER_MIGRATION_READINESS_20260729_205350Z.md` §3 — this document explicitly performed the scan and recorded `COORDINATES_MISSING`.

**PRD guidance vs. workspace reality:**

| PRD v3 §7.2 assumption | Workspace finding |
|:-----------------------|:------------------|
| Server already provisioned | No evidence of provisioning |
| Existing hostname `brandon-prod` | No `brandon-prod` found anywhere |
| Ubuntu Server 24.04 LTS | No OS evidence |
| Docker Engine present | No Docker evidence |
| Docker Compose present | No Docker Compose evidence |
| UFW configured | No firewall evidence |
| Tailscale joined | No Tailscale evidence |
| Coolify present | No Coolify evidence |
| Prepared RabbitMQ, Redis, Qdrant configs | No service evidence |

**Blocker classification:** `COORDINATES_MISSING`  
**Impact:** All downstream tasks requiring Hetzner access (BR-ARCH-001, BR-GATE-001, all compute-plane work) are blocked.  
**Recovery condition:** Operator must supply: Hetzner server public IP, hostname, OS, approved SSH access path, and confirmation of whether the server is bare or already has workloads.

---

## Host 3 — Namecheap Account `server401`

**PRD v3 intended role:** One of four per-project DR/backup targets  
**Current evidenced role:** Shared hosting for `cbd-data.com` (HD2Stack account, not yet assigned per PRD v3)

| Field | Value | Provenance |
|:------|:------|:----------|
| **Provider** | Namecheap | `VPS_STATE_REPORT.md` (via existing `report.md`) |
| **Host identifier** | `server401` (hostname `server401-3.web-hosting.com`) | `ACCESS_BASELINE_REGISTRY.md` Host Roles |
| **IP** | `68.65.123.217` | `ACCESS_BASELINE_REGISTRY.md` |
| **Role (evidenced)** | Shared hosting — `cbd-data.com` | `ACCESS_BASELINE_REGISTRY.md` |
| **Role (PRD v3 intent)** | One of four per-project DR targets — specific project assignment not evidenced | `Brandon-Multi-Project-Infrastructure-PRD-v3.md` §7.3; no workspace evidence of per-project assignment |
| **OS** | Linux (shared hosting, unspecified distro) | Not documented |
| **PHP version** | Not documented for this account specifically | No source file |
| **cPanel user** | `cbddpolp` | `ACCESS_BASELINE_REGISTRY.md` |
| **Document root** | `/home/cbddpolp/public_html/` | `ACCESS_BASELINE_REGISTRY.md` |
| **SSL** | Active (expiry November 2026) | `ACCESS_BASELINE_REGISTRY.md` |
| **SSH access** | BLOCKED — `Permission denied (publickey)` | `ACCESS_BASELINE_REGISTRY.md` |
| **cPanel UAPI** | Fallback path (token pending rotation) | `ACCESS_BASELINE_REGISTRY.md` |
| **Docker/Coolify** | Not applicable (shared hosting) | N/A |
| **Firewall** | Provider-managed | Namecheap infrastructure |
| **Backup/Image** | BLOCKED — `RAPIDAPI_KEY` and `REPLICATE_API_KEY` exposed in prior transcript; secret rotation required before backup can proceed | `ACCESS_BASELINE_REGISTRY.md`; `report.md` (prior draft) |
| **App health** | Restored 2026-05-09; HTTP 200 confirmed | `ACCESS_BASELINE_REGISTRY.md` |
| **Cron** | `*/5 * * * * /usr/local/bin/php /home/cbddpolp/public_html/cron_drip.php` | `ACCESS_BASELINE_REGISTRY.md` |
| **CPU/RAM/Disk** | Shared hosting limits not exposed by cPanel | cPanel environment |

**Provenance sources:**

| Source file | Information extracted |
|:------------|:----------------------|
| `ACCESS_BASELINE_REGISTRY.md` | Host ID, IP, cPanel user, document root, SSH status, SSL, cron |
| `report.md` (prior draft) | Backup blocked status, exposed secrets classification |

---

## Host 4 — Namecheap Account `business186`

**PRD v3 intended role:** One of four per-project DR/backup targets  
**Current evidenced role:** Shared hosting for `music-metrics.com` (HD2Stack SaaS account)

| Field | Value | Provenance |
|:------|:------|:----------|
| **Provider** | Namecheap | `ACCESS_BASELINE_REGISTRY.md` |
| **Host identifier** | `business186` | `ACCESS_BASELINE_REGISTRY.md` |
| **IP** | `199.188.201.116` | `ACCESS_BASELINE_REGISTRY.md` |
| **Role (evidenced)** | Shared hosting — `music-metrics.com` | `ACCESS_BASELINE_REGISTRY.md` |
| **Role (PRD v3 intent)** | Per-project DR target — specific assignment not evidenced | No workspace evidence |
| **OS** | Linux (shared hosting) | Not documented |
| **PHP version** | `8.2.30` (confirmed for this account) | `ACCESS_BASELINE_REGISTRY.md` |
| **Composer** | `2.6.5` (confirmed for this account) | `ACCESS_BASELINE_REGISTRY.md` |
| **cPanel user** | `musilnsy` | `ACCESS_BASELINE_REGISTRY.md` |
| **Document root** | `/home/musilnsy/public_html/` | `ACCESS_BASELINE_REGISTRY.md` |
| **SSL** | Active (expiry November 2026) | `ACCESS_BASELINE_REGISTRY.md` |
| **SSH access** | OK — key verified 2026-05-07; port `21098` | `ACCESS_BASELINE_REGISTRY.md` |
| **cPanel UAPI** | BLOCKED — 403 Access Denied | `ACCESS_BASELINE_REGISTRY.md` |
| **Docker/Coolify** | Not applicable (shared hosting) | N/A |
| **Firewall** | Provider-managed | Namecheap infrastructure |
| **Backup/Image** | BLOCKED — cPanel API returns 403 Access Denied | `ACCESS_BASELINE_REGISTRY.md` |
| **App health** | HTTP 200; logo HTTP 200; `install.php` HTTP 404 | `ACCESS_BASELINE_REGISTRY.md` |
| **Cron** | `*/5 * * * * /usr/local/bin/php /home/musilnsy/public_html/cron_drip.php >/dev/null 2>&1` | `ACCESS_BASELINE_REGISTRY.md` |
| **CPU/RAM/Disk** | Shared hosting limits not exposed | cPanel environment |

---

## Host 5 — Namecheap Account `business125-5`

**PRD v3 intended role:** One of four per-project DR/backup targets  
**Current evidenced role:** Shared hosting for `amino-data.net`

| Field | Value | Provenance |
|:------|:------|:----------|
| **Provider** | Namecheap | `ACCESS_BASELINE_REGISTRY.md` |
| **Host identifier** | `business125-5` | `ACCESS_BASELINE_REGISTRY.md` |
| **IP** | `192.64.117.169` | `ACCESS_BASELINE_REGISTRY.md` |
| **Role (evidenced)** | Shared hosting — `amino-data.net` | `ACCESS_BASELINE_REGISTRY.md` |
| **Role (PRD v3 intent)** | Per-project DR target — specific assignment not evidenced | No workspace evidence |
| **OS** | Linux (shared hosting) | Not documented |
| **PHP version** | Not documented for this account specifically | No source file |
| **cPanel user** | `aminzxrl` | `ACCESS_BASELINE_REGISTRY.md` |
| **Document root** | `/home/aminzxrl/public_html/` | `ACCESS_BASELINE_REGISTRY.md` |
| **SSL** | Active (expiry October 2026) | `ACCESS_BASELINE_REGISTRY.md` |
| **SSH access** | OK — key verified 2026-05-08; port `21098` | `ACCESS_BASELINE_REGISTRY.md` |
| **cPanel UAPI** | OK | `ACCESS_BASELINE_REGISTRY.md` |
| **Docker/Coolify** | Not applicable (shared hosting) | N/A |
| **Firewall** | Provider-managed | Namecheap infrastructure |
| **Backup/Image** | HOLD — App health check required before backup classification | `ACCESS_BASELINE_REGISTRY.md` |
| **App health** | HTTP 200 (held for backup classification) | `ACCESS_BASELINE_REGISTRY.md` |
| **Cron** | `*/5 * * * * /usr/local/bin/php /home/aminzxrl/public_html/cron_drip.php` | `ACCESS_BASELINE_REGISTRY.md` |

---

## Host 6 — Namecheap Account `hd2data`

**PRD v3 intended role:** One of four per-project DR/backup targets (fourth account per PRD v3)  
**Current evidenced role:** New Namecheap account — no active services, no SSL

| Field | Value | Provenance |
|:------|:------|:----------|
| **Provider** | Namecheap | `ACCESS_BASELINE_REGISTRY.md` |
| **Host identifier** | `hd2data` | `ACCESS_BASELINE_REGISTRY.md` |
| **IP** | `68.65.123.213` | `ACCESS_BASELINE_REGISTRY.md` |
| **Role (evidenced)** | New account — no active services | `ACCESS_BASELINE_REGISTRY.md` |
| **Role (PRD v3 intent)** | Per-project DR target — specific assignment not evidenced | No workspace evidence |
| **OS** | Linux (shared hosting) | Not documented |
| **SSL** | None — not yet configured | `ACCESS_BASELINE_REGISTRY.md` |
| **SSH access** | SSH key pair `id_ed25519_hd2data` generated 2026-05-10; port `21098` | `ACCESS_BASELINE_REGISTRY.md` |
| **cPanel user** | `uobldmqj` | `ACCESS_BASELINE_REGISTRY.md` |
| **Docker/Coolify** | Not applicable (shared hosting) | N/A |
| **Firewall** | Provider-managed | Namecheap infrastructure |
| **Backup/Image** | No active service to back up | N/A — account is new |
| **CPU/RAM/Disk** | Shared hosting limits not exposed | cPanel environment |

---

## Consolidated Unknown Fields

| Host | Unknown fields |
|:-----|:---------------|
| Hostinger KVM8 | OS distro and version, CPU model, RAM size, disk total, disk usage, public IP, Coolify presence/version, firewall rules, backup configuration, Docker/Coolify container count |
| Hetzner | All fields — no evidence exists for this server |
| Namecheap `server401` | OS distro, PHP version, specific resource limits |
| Namecheap `business186` | OS distro, specific resource limits |
| Namecheap `business125-5` | OS distro, PHP version, specific resource limits |
| Namecheap `hd2data` | OS distro, resource limits, intended service |

---

## Namecheap DR Assignment Gap

PRD v3 §7.3 specifies the following DR target assignments:

| Proposed logical name | Intended project | Workspace evidence |
|:---------------------|:-----------------|:-------------------|
| `bdn-dr-core-01` | Core Distro | No workspace evidence of this DR target |
| `bdn-dr-elevate-01` | Elevate Life Sci | No workspace evidence of this DR target |
| `bdn-dr-whoosh-01` | Whoosh Performance | No workspace evidence of this DR target |
| `bdn-dr-cbddata-01` | CBD-Data | No workspace evidence of this DR target |

The four evidenced Namecheap accounts (`server401`, `business186`, `business125-5`, `hd2data`) are not explicitly assigned to these four projects in any workspace document. The account-to-project mapping is an **unresolved operator decision** that must be recorded before BR-INV-003 (Namecheap capability matrix) can proceed.

---

## Secrets Redaction Confirmation

All credentials and secret values are redacted per policy. No raw secret values appear in this report:

- SSH keys: represented as pointer paths or names (`id_ed25519_hd2data`, `id_ed25519`)
- API tokens: not printed; referenced only by pointer name
- Exposed secrets on `server401`: blocked status noted without values (`RAPIDAPI_KEY`, `REPLICATE_API_KEY`)
- Passwords: not printed

---

## Stop Condition

This discovery pass stops after one bounded discovery pass as required. No live SSH, API access, DNS lookup, or server inspection was performed. No infrastructure mutation occurred.

---

*Report generated: BR-INV-001 Phase 0 discovery pass*  
*Source artifacts: Brandon campaign repository evidence only*  
*Next action: M3 review of report, operator supply of Hetzner coordinates, and resolution of Namecheap DR project assignment*
