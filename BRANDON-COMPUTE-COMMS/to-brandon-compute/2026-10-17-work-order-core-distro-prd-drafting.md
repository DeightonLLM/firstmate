# Work Order: Core Distro Infrastructure & Modernization PRD v1.0 Drafting

**Date**: 2026-10-17T22:32:00Z  
**From**: Firstmate / Coordinator (HD2Stack)  
**To**: Hetzner Coordinator / Kun-Agent (`brandon-compute`, `100.106.6.22`)  
**Authority**: Captain explicit authorization: "yes" to starting Core-Distro PRD v1.0  
**Target Output**: `data/prds/core-distro-prd-v1.0.md` (to be tracked in git)

---

## 1. Directive & Alignment

You are cleared to author **`core-distro-prd-v1.0.md`** using the exact structure, gates, and hardening blueprint of the Whoosh v1.0 template (`whoosh-performance-wp-data-outreach-prd-v1.0.md`) and Brandon Infrastructure PRD v3.0.

### Ownership Chain (Strictly Preserved)
- **Orchestration & Technical Acceptance**: **the Captain**
- **Infrastructure & Development Implementation**: **Saad**
- **Design, Visual Parity & Marketing Imagery**: **Sawar**
- **Business Scope & Final Production Approval**: **Eric and Brandon**

---

## 2. Verified Live Architecture & Source Coordinates

Incorporate these verified live facts directly into the PRD so no guessing is required:

### The Three-Plane Architecture
1. **Public Plane (Hostinger KVM8 / `srv1137994`)**:
   - Frontend Application: Next.js 15 App Router running standalone on `100.69.211.43` (`srv1137994-elevatesci`), bound to `127.0.0.1:3113`, managed by systemd unit `core-distro-staging.service`.
   - Nginx Reverse Proxy with TLS 1.2/1.3, strict security headers (HSTS, nosniff, frame-ancestors, CSP).
   - Live production site currently on Hostinger / LiteSpeed at `https://core-distro.com`.
2. **Chat & Compute Plane (HD2Stack + Hetzner Dedicated `100.106.6.22`)**:
   - **Customer Chatbot**: AnythingLLM on `https://llm.hd2.ai/api/embed` using Embed UUID `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2` (Workspace 36: `Core-distro_model`). Backed by Google Gemini (`gemini-3.1-flash-lite-preview`) streaming in ~144ms TTFT with verified product knowledge base.
   - **Scraping & Lead Generation**: Hetzner dedicated compute server isolated from the public frontend. Scrapers and data enrichers consume background queues and never touch customer-facing traffic.
3. **Backup & Disaster Recovery Plane (Dedicated Namecheap VPS 2)**:
   - Dedicated Namecheap VPS assigned to Core-Distro for offsite encrypted backups (GPG/AES-256).
   - Nightly database and release manifest syncs; restore drill requirement before production sign-off.

---

## 3. Verified Design Tokens & Visual Correctness Standards

Carry forward the visual correctness tokens verified tonight (exit code 0 under `/root/bin/check-visual-correctness`):
- **Favicon**: Direct 8,160-byte icon at `/favicon.ico` (exact binary match).
- **Logo Wordmark**: `/core-distro-logo-white_ce3460b1.webp` (146,940 bytes) used in header and footer.
- **Palette**: Exact OKLCH green accent `oklch(0.78 0.22 148)` / `#00d455`, dark charcoal `oklch(0.18 0.065 148)` / `#1E2329`.
- **Typography**: Header font `Barlow Condensed` (weight 700), body font `DM Sans` (weights 300–600), monospace `JetBrains Mono`.
- **Multi-language**: Responsive desktop/mobile dropdown (`.cd-language-slot`) with SVG flags for English, Polish, and Spanish.

---

## 4. Required PRD Sections & Gates

Your draft must include the full 25 sections of the Whoosh standard:
- **Discovery Gates A–E** (inventory, tested backup restore, content truth, plane isolation, visual verification).
- **Hardening Requirements**: Registrar lock + MFA, DNSSEC, UFW default deny, SSH keys only, proxy-level block on hidden files/env, rate limits on API routes.
- **Phased Rollout with Exit Gates**: Phase 1 Discovery -> Phase 2 Hardening -> Phase 3 Chatbot & API Mount -> Phase 4 Visual Parity -> Phase 5 Production Promotion.
- **Per-component Acceptance Checkboxes** and rollback runbook.
- **Verification-Before-Claim Rule** in the execution contract.

Deliver the completed draft to `data/prds/core-distro-prd-v1.0.md` on your workspace and sync a notification receipt to `from-brandon-compute/` when ready for Captain's review.
