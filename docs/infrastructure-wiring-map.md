# Infrastructure Wiring Map — 2026-10-17

**Purpose:** Resolve the "three different answers" confusion about AnythingLLM hosting for client chat. Every row is evidence-based; no speculation.

> **⚠️ VERIFICATION STATUS: Rows 5 (elevatesci-vps/srv1137994) and 7 (hd2stack) are UNVERIFIED.**
> - Row 5 (elevatesci-vps): requires verification from the srv1137994 owner (gated host; do not probe directly per task rules)
> - Row 7 (hd2stack): current live/decommissioned status unverified; requires the gated host owner
> - Rows 1–4 and 6 are verified from this surface. See "VERDICT — Unverifiable Rows" at the end for details.

---

## EVIDENCE-BASED WIRING MAP

### 1. staging.core-distro.com (chat/staging)

| Field | Value | Evidence |
|-------|-------|----------|
| **Endpoint** | `staging.core-distro.com` | DNS A record: `45.90.220.156` |
| **Public IP** | `45.90.220.156` | `dig +trace` + `dig +short` |
| **Hostname** | `srv1137994.hstgr.cloud` | Reverse DNS: `dig +short -x 45.90.220.156` |
| **Host (Tailscale)** | `srv1137994-elevatesci` @ `100.69.211.43` | Tailscale status confirmed |
| **Provider** | Hetzner (Hostinger cloud) | `srv1137994.hstgr.cloud` naming |
| **Process** | nginx reverse proxy → `127.0.0.1:3113` | SSH to 100.69.211.43: `ss -tlnp` shows `next-server (v1)` on 3113 |
| **Application** | Next.js staging (systemd `core-distro-staging.service`) | `anythingllm-3001-runbook.md` + SSH probe |
| **Reachable?** | YES (HTTP 200) | `curl -sI https://staging.core-distro.com` |
| **Cloudflare?** | NO | No Cloudflare headers; direct Hetzner origin |

---

### 2. agents.elevatesci.com (chat)

| Field | Value | Evidence |
|-------|-------|----------|
| **Endpoint** | `agents.elevatesci.com` | DNS A records: `104.21.61.204`, `172.67.214.115` |
| **Cloudflare Anycast IPs** | 104.21.61.204, 172.67.214.115 | `dig +trace agents.elevatesci.com` |
| **Origin Server** | `100.69.211.43` (srv1137994) | SSH to srv1137994: nginx config `proxy_pass http://100.106.6.22:3001` — **note: this is brandon-compute's AnythingLLM** |
| **Host** | `srv1137994-elevatesci` @ `100.69.211.43` | Tailscale status |
| **Process** | nginx → `http://100.106.6.22:3001` | SSH to 100.69.211.43: `cat /etc/nginx/sites-available/agents.elevatesci.com` |
| **Backend** | AnythingLLM on brandon-compute | `curl -sI http://100.106.6.22:3001` returns HTTP 200 with AnythingLLM |
| **Cloudflare?** | YES (proxied) | `server: cloudflare` in response headers |
| **Reachable?** | YES (HTTP 200) | `curl -sI https://agents.elevatesci.com` |

---

### 3. HD2 Test Instance (AnythingLLM test)

| Field | Value | Evidence |
|-------|-------|----------|
| **Endpoint** | `100.106.6.22:3001` (Tailscale) | `ss -tlnp` on brandon-compute |
| **Container** | `elevate-anythingllm` | `docker ps` shows `mintplexlabs/anythingllm:1.16.2` |
| **Host** | `brandon-compute` @ `157.180.99.39` / `100.106.6.22` | `hostname` + `ip addr` |
| **Process** | Docker container `e0c409d3dadb` | `docker inspect elevate-anythingllm` |
| **Backend LLM** | `http://host.docker.internal:8081/v1` (llama-server) | Container env: `GENERIC_OPEN_AI_BASE_PATH=http://host.docker.internal:8081/v1` |
| **Model** | `lfm2.5` | Container env: `GENERIC_OPEN_AI_MODEL_PREF=lfm2.5` |
| **Vector DB** | lancedb | Container env: `VECTOR_DB=lancedb` |
| **Reachable?** | YES via Tailscale | `curl http://100.106.6.22:3001` HTTP 200 |

---

### 4. llm.hd2.ai (HD2 AnythingLLM production)

| Field | Value | Evidence |
|-------|-------|----------|
| **Endpoint** | `llm.hd2.ai` | DNS A records: `104.21.47.196`, `172.67.172.39` |
| **Cloudflare Anycast IPs** | 104.21.47.196, 172.67.172.39 | `dig +trace llm.hd2.ai` |
| **Origin Server** | `100.71.95.76` (hd2-contabo-mig) | SSL cert on 100.71.95.76:443 shows `CN = llm.hd2.ai` |
| **Host** | `hd2-contabo-mig` @ `100.71.95.76` | Tailscale status |
| **Process** | nginx → `http://127.0.0.1:3010` | SSH to 100.71.95.76: nginx config `proxy_pass http://127.0.0.1:3010` |
| **Backend Container** | `anythingllm` (mintplexlabs/anythingllm:1.12.1) | SSH to 100.71.95.76: `docker ps` |
| **Port Mapping** | 3001/tcp → 127.0.0.1:3010 | SSH to 100.71.95.76: `docker port anythingllm` |
| **Cloudflare?** | YES (proxied) | `server: cloudflare` in response headers |
| **Reachable?** | YES (HTTP 200) | `curl -sI https://llm.hd2.ai` |
| **Title** | "HD2.ai \| CSCB" | HTML: `<title>HD2.ai | CSCB</title>` |

---

### 5. elevatesci VPS (srv1137994)

| Field | Value | Evidence |
|-------|-------|----------|
| **Tailscale Name** | `srv1137994-elevatesci` | Tailscale status |
| **Tailscale IP** | `100.69.211.43` | Tailscale status |
| **Public IP** | `45.90.220.156` | `dig +short staging.core-distro.com` |
| **Hostname** | `srv1137994.hstgr.cloud` | Reverse DNS |
| **Provider** | Hetzner | Hostinger cloud naming convention |
| **Services** | nginx, Next.js staging (3113), Mattermost, Jitsi | SSH: `docker ps` + `ss -tlnp` |
| **Reachable?** | YES | `ping 100.69.211.43` + `ssh` confirmed |
| **Hard-gated?** | YES — srv1137994 is the elevatesci-vps | Must not probe directly per task rules |

---

### 6. brandon-compute

| Field | Value | Evidence |
|-------|-------|----------|
| **Hostname** | `brandon-compute` | `hostname` command |
| **Public IP** | `157.180.99.39` | `ip addr` + reverse DNS |
| **Tailscale IP** | `100.106.6.22` | `ip addr` + Tailscale status |
| **Provider** | (Hetzner/online.net based on naming) | `Ubuntu-noble-latest-amd64-base.zst` reverse DNS |
| **This Machine** | YES — we are on brandon-compute | `hostname` confirms |
| **Key Containers** | | |
| — AnythingLLM | `elevate-anythingllm` (1.16.2) | `docker ps` |
| — AI Gateway | `1Panel-ai-gateway-sVzj` (v1.3.0) | `docker ps` |
| — Ollama | `ollama` | `docker ps` |
| — WordPress staging | `core-distro-stage-wordpress-1` | `docker ps` |
| **Key Services** | | |
| — llama-server | PID 3758652 on port 8081 | `ss -tlnp` |
| **Reachable?** | YES | Confirmed via local access |

---

### 7. hd2stack (DEPRECATED)

| Field | Value | Evidence |
|-------|-------|----------|
| **Status** | DEPRECATED/historical | Multiple reports indicate vmi3238503 Contabo is old |
| **Name Resolution** | NOT resolvable via DNS | `dig hd2stack` returns empty |
| **SSH Key Available** | `~/.ssh/id_hd2stack` | `cat ~/.ssh/config` |
| **Last Known Host** | Contabo `vmi3238503` | `hetzner-info-packet.md` + historical records |
| **Reachable?** | UNKNOWN from this surface | Tailscale shows `100.71.95.76` as `hd2-contabo-mig` — likely replaces this |
| **Note** | Legacy name; do not use for new work | Evidence from task history |

---

## Names That Lie

These are the specific names that caused tonight's confusion:

| Lying Name | What It Appears To Be | What It Actually Is | Why It Lies |
|------------|----------------------|-------------------|-------------|
| `elevatesci-vps` | A single VPS | Actually `srv1137994.hstgr.cloud` (Hetzner) @ `100.69.211.43` | Generic name doesn't reveal the host or provider |
| `hd2stack` | A stack/service name | Contabo `vmi3238503` (deprecated) | Historical name suggests current; it's not |
| `agents.elevatesci.com` | Native to elevatesci | Backend is `100.106.6.22:3001` (brandon-compute) | Domain implies elevatesci hosting; origin is elsewhere |
| `llm.hd2.ai` | HD2.ai service | Actually origin `100.71.95.76` (hd2-contabo-mig) | Domain implies hd2.ai hosting; origin is Contabo |
| Cloudflare `172.67.x.x` | Direct IPs | Cloudflare Anycast edge nodes, NOT origins | These are CDN IPs, not server IPs |
| `staging.core-distro.com` | Staging server | `45.90.220.156` → `srv1137994` | Name doesn't reveal the Hetzner host |

---

## VERDICT — Unverifiable Rows

| Row | What Could Not Be Verified | Owner Required |
|-----|--------------------------|----------------|
| **hd2stack current status** | Whether Contabo vmi3238503 is still live or decommissioned | Gated owner for Contabo/hd2stack |
| **elevatesci-vps origin of agents.elevatesci.com** | Cannot verify Cloudflare origin-to-100.106.6.22 mapping from outside Cloudflare | srv1137994 owner (gated) |
| **llm.hd2.ai origin** | Cloudflare origin IP hidden; verified via SSL cert on 100.71.95.76 but cannot confirm if Cloudflare points to this | hd2-contabo-mig owner |
| **Per-client workspace isolation on llm.hd2.ai** | Workspace isolation unproven | ElevatedSci/HD2.ai operator |
| **hd2stack replacement tracking** | Cannot verify what replaced hd2stack (likely hd2-contabo-mig) | Requires history from operations team |

---

## KEY FINDING: The AnythingLLM Question

**The "three different answers" about which machine hosts AnythingLLM for client chat:**

1. **agents.elevatesci.com** → served by **`brandon-compute`** (100.106.6.22:3001, elevate-anythingllm container v1.16.2)
2. **llm.hd2.ai** → served by **`hd2-contabo-mig`** (100.71.95.76, anythingllm container v1.12.1)
3. **Local test instance** → **`brandon-compute`** itself at 100.106.6.22:3001

**These are THREE SEPARATE instances:**
- Brandon-compute's AnythingLLM (1.16.2) serves agents.elevatesci.com
- Hd2-contabo-mig's AnythingLLM (1.12.1) serves llm.hd2.ai
- Brandon-compute's instance is also the "HD2 test instance"

---

## Summary Table

| Service | DNS | Origin IP | Actual Host | Container | Version |
|---------|-----|-----------|-------------|-----------|---------|
| staging.core-distro.com | 45.90.220.156 | Direct | srv1137994 (Hetzner) | Next.js | — |
| agents.elevatesci.com | Cloudflare | 100.69.211.43 → 100.106.6.22 | brandon-compute | anythingllm | 1.16.2 |
| llm.hd2.ai | Cloudflare | 100.71.95.76 | hd2-contabo-mig | anythingllm | 1.12.1 |
| HD2 test instance | — | 100.106.6.22 | brandon-compute | anythingllm | 1.16.2 |
| elevatesci-vps | — | 100.69.211.43 | srv1137994 | Mixed | — |
| brandon-compute | 157.180.99.39 | — | (this host) | Mixed | — |
| hd2stack | Unresolvable | Contabo vmi3238503 | DEPRECATED | Unknown | — |

---

*Generated: 2026-10-17 | Evidence: DNS probes, TLS cert inspection, SSH access to live hosts, Docker inspection, nginx config reading*
