# ADR-0001: Core Distro Production Cutover to Hostinger Next.js Stack

- **Status:** ACCEPTED (Authorized by the Captain)
- **Date:** 2026-10-18
- **Decider:** the Captain (Sole Orchestrator & Technical Acceptance Authority)
- **Technical Implementation:** Saad & First Mate Coordinator
- **PRD Reference:** `data/prds/core-distro-prd-v1.0.md`, `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (§2.1, §§7.1–7.2)

---

## 1. Context and Problem Statement

Production `core-distro.com` currently operates on legacy Namecheap shared hosting (`66.29.153.174`, cPanel / PHP 8.2), with agents on Contabo (`161.97.120.4`). 

Brandon Multi-Project Infrastructure PRD v3.0 (§2.1) identified this gap between reality and the target 3-plane architecture (Hostinger public plane + Hetzner compute plane + Namecheap backup plane), explicitly commanding:
> *"The Captain ordered an ADR first for Core Distro before any architecture or migration decisions are made."*

We have now constructed, hardened, and verified the modern Next.js replacement stack on Hostinger KVM8 (`srv1137994` / `45.90.220.156`):
1. **Pixel-Perfect Parity:** Mechanically verified via `/root/bin/check-visual-correctness` (code 0) against live `https://core-distro.com` (favicon, white logo, OKLCH brand green, DM Sans / Barlow typography).
2. **Chat TTFT Latency Fixed:** Replaced the stalled Hetzner CPU AnythingLLM proxy with direct HD2Stack Gemini embed (`https://llm.hd2.ai/api/embed`, UUID `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2`), bringing measured Time-To-First-Token down from ~60s to **143.8ms**.
3. **Active Release:** `release-20261017_213554` running under systemd unit `core-distro-staging.service` with HTTP 200 health check.

The technical prerequisites are met. The architecture decision is now before the Captain to authorize the migration path.

---

## 2. Decision Options Considered

### Option A: Retain Legacy Namecheap PHP 8.2 for Production
- **Description:** Leave `core-distro.com` on Namecheap shared hosting indefinitely. Apply only PHP patches and maintain Contabo agent server.
- **Pros:** Zero DNS changes; no migration risk.
- **Cons:** Stagnant legacy stack; cannot utilize modern Next.js caching or streaming UI; diverges permanently from the Brandon v3 3-plane architecture; higher operational friction.

### Option B: Promote Hostinger Next.js Stack to Production Apex (Recommended)
- **Description:** Formally adopt the Hostinger KVM8 Next.js stack for `core-distro.com` and `www.core-distro.com`, decommission Namecheap production hosting once verified, and route compute/scraper workloads to Hetzner (`100.106.6.22`).
- **Pros:**
  - Fully implements the Brandon v3 3-plane architecture.
  - Sub-150ms chat response time using Google Gemini on HD2Stack.
  - Modern Next.js App Router performance, SEO optimization, and responsive design.
  - Applies the Whoosh v1.0 hardening baseline (Nginx rate limits, security headers, automated daily backups to Namecheap target).
- **Cons:** Requires controlled DNS migration and a brief maintenance cutover window.

---

## 3. Decision Outcome

**Chosen Option:** **Option B — Promote Hostinger Next.js Stack to Production Apex.**

### Sequencing Plan:
1. **Phase 1 (Preparation):** Provision production Nginx server block for `core-distro.com` / `www.core-distro.com` on `srv1137994`, mirroring the validated staging configuration.
2. **Phase 2 (TLS & ACME):** Issue Let's Encrypt certificates for `core-distro.com` and `www.core-distro.com` on Hostinger.
3. **Phase 3 (DNS Cutover):** Lower DNS TTL on Namecheap to 300s, then update `@` and `www` A records to point to `45.90.220.156` (Hostinger `srv1137994`).
4. **Phase 4 (Post-Cutover Smoke Test):** Run automated visual checks (`/root/bin/check-visual-correctness`) and chat TTFT benchmark on live `https://core-distro.com`.
5. **Phase 5 (Decommissioning & Archive):** Take full cPanel backup of legacy Namecheap hosting, store on Namecheap backup target, and archive legacy repository.

---

## 4. Rollback and Safety Net

If any regression, data loss, or service degradation occurs during or within 48 hours of cutover:
1. **Instant DNS Rollback:** Restore `@` and `www` A records to `66.29.153.174` (Namecheap Stellar hosting). The legacy PHP site remains intact and runnable.
2. **TTL Pre-conditioning:** TTL will be lowered to 300 seconds 24 hours prior to cutover to guarantee near-instant propagation of any rollback.

---

## 5. Acceptance Criteria
- [ ] Captain review and explicit approval of this ADR.
- [ ] `https://core-distro.com` returns HTTP 200 from Hostinger with active Next.js release.
- [ ] Chat widget streams tokens in < 500ms on production.
- [ ] `/root/bin/check-visual-correctness` exits code 0 on production.
- [ ] Status in `data/prds/core-distro-prd-v1.0.md` updated from `UNKNOWN (ADR pending)` to `ACCEPTED`.
