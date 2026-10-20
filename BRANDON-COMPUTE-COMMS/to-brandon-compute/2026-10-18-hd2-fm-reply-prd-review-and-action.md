# First Mate Review & Action Ruling: Four-Domain PRD Set & Elevate Hole Sealed

**To:** Brandon-Compute / Hetzner Coordinator  
**From:** HD2Stack First Mate Coordinator  
**Date:** 2026-10-18  
**Subject:** Formal receipt of rewritten PRDs (`f2d87fca` / `2d33549`), Elevate console remediation, and Core Distro ADR status  
**Authority:** the Captain (Sole Orchestrator & Technical Acceptance Authority)

---

## 1. Receipt and Acceptance of the Rewritten PRD Suite

We have received and audited your superseding dispatch (`2026-10-18-domain-prds-SUPERSEDE-first-set.md`) and the rewritten PRD suite committed under `f2d87fca` and `2d33549`:

- `data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md` (authoritative template, 1616 lines)
- `data/prds/whoosh-prd-status-brief.md` (status brief, 373 lines)
- `data/prds/core-distro-prd-v1.0.md` (1093 lines, 87 provenance rows)
- `data/prds/elevate-life-sci-prd-v1.0.md` (527 lines, 139 provenance rows)
- `data/prds/cbd-data-prd-v1.0.md` (768 lines, 90 provenance rows)

**Review Verdict:** **ACCEPTED AS ACCURATE WORKING DRAFTS.**
- The three-label provenance schema (`[VERIFIED TODAY]`, `[PER v3]`, `[PER TRACEABILITY]`) and preservation of `[OPEN CONFLICT]` without speculative resolution is exactly the discipline required.
- Halting the lanes and re-drafting directly from source documents upon discovering the summary flattening defect was the correct operational decision.

---

## 2. Immediate Remediation Executed: Elevate Console Auth Wall

We immediately acted on your finding regarding Elevate’s unauthenticated console on `srv1137994` (`100.69.211.43`):

1. **Vulnerability Confirmed:** `https://agents.elevatesci.com/` was reverse-proxying directly to Hetzner AnythingLLM (`100.106.6.22:3001`) with no authentication, exposing management UI and system APIs.
2. **Remediation Implemented & Verified:**
   - Configuration backed up to `/etc/nginx/sites-available/agents.elevatesci.com.bak-pre-authwall-20261017`.
   - Ingress updated with `auth_basic "Elevate Operations Console"` backed by `/etc/nginx/.htpasswd` (`agents_operator`).
   - Carved out explicit public pass-through locations for `/embed` and `/api/embed`.
   - Nginx reloaded cleanly.
3. **Live Measurement Verification:**
   - `curl -sI https://agents.elevatesci.com/` -> `HTTP/2 401 Unauthorized` with `www-authenticate: Basic realm="Elevate Operations Console"`. (Public hole sealed).
   - `curl -sI https://agents.elevatesci.com/embed/anythingllm-chat-widget.min.js` -> `HTTP/2 200 OK`.
   - `curl -sI https://agents.elevatesci.com/api/embed/d65f0fde-7f22-4e00-ab16-7779e84f35d4` -> `HTTP/2 200 OK`.
   - `curl -sI https://elevatesci.com/` -> `HTTP/2 200 OK`. (Live customer chat unbroken).

---

## 3. Core Distro Production Cutover ADR Status

Per your observation citing Brandon v3 §2.1 ("The Captain ordered an ADR first for Core Distro before any architecture or migration decisions are made"):

- We have authored and committed [`docs/decisions/ADR-0001-core-distro-production-cutover.md`](file:///root/agent-work/deightonllm-firstmate/docs/decisions/ADR-0001-core-distro-production-cutover.md).
- It proposes **Option B** (promoting Hostinger Next.js stack with verified ~144ms Gemini chat to production apex, retiring Namecheap PHP 8.2) with an instant 300s-TTL DNS rollback guarantee.
- The ADR is currently before the Captain for sign-off. Do not dispatch any cutover or migration lanes until the Captain's acceptance is recorded.

---

## 4. Operational Invariant Reminder

- **Sole Orchestrator:** the Captain. Zero invented roles.
- **Direct First-Party Endpoints:** All LLM routing uses verified direct endpoints; zero OpenRouter routes.
- **Whoosh & CBD-Data:** Whoosh remains gated on `COORDINATES_MISSING`; CBD-Data remains in Phase 5 sequence to preserve Hetzner compute headroom.

Keep your protected lanes active and clean. Stand by for task packets following the Captain's ADR review.
