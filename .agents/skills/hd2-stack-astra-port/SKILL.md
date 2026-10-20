---
name: hd2-stack-astra-port
description: Autonomously port elevatesci.com and core-distro.com into Astra WordPress builds on the HD2 stack (controller + brandon + animovps), with HD2.ai chatbot embeds wired in. Use when the captain asks to port, migrate, rebuild or "make totally autonomous" the Elevate or Core-Distro sites on WordPress, or wants an Astra build of either site on our own infrastructure.
---

# HD2 stack — autonomous Astra port (elevatesci.com + core-distro.com)

Companion to `vite-astra-port` (same output contract: astra-tokens.css,
WP-ASTRA-SKIN-KIT.md, screenshots/, token-report.json, README). This skill adds
what makes the port AUTONOMOUS on our infrastructure: known hosts, existing crawl
data, chatbot embed integration, delegation rules, and the hard gates.

## Stack map (verified 2026-09-26)

- **controller** = Contabo vmi3196300 (100.117.47.27). Coordination, corpus, BOARD.md, CONTROLLER_STATE.md, /root/.secrets pointers.
- **brandon-compute** = Hetzner AX42 (100.106.6.22, hd2admin, sudo -n). Compute muscle: docker (mariadb/wp containers OK), the HD2 chatbot instance (port 3001, embed at agents.elevatesci.com), crawl data at /tmp/elevate-rag/ + /tmp/core-crawl/ (+ manifests.csv, hash-provenanced).
- **elevatesVPS** (formerly animovps, retired 2026-09-28) = Hostinger srv1137994 (root key). HOSTS the live sites: /var/www/elevatesci.com (84 pages), /var/www/core-distro-nextjs, staging.core-distro.com vhost (use for previews). nginx + certbot working.
- **namecheap cPanel** = production SaaS hosting (music/lawyer/cbd accounts). Core-Distro live chatbot embed currently serves from llm.hd2.ai (vmi3238503) — DO NOT touch that instance.
- Read `BOARD.md` + `CONTROLLER_STATE.md` first. UK time everywhere.

## Delegation (captain rule — deterministic)

- MiniMax 2.7 (`mcode exec`, headless) executes lanes; Gemini (`agy --print`) reviews deliverables; controller coordinates + handles captain-gated actions.
- Swarm: study → plot lanes → SHOW THE CAPTAIN → GO → run 2-4 lanes parallel. Todo lines tagged `[owner @ host]`. Backups before ANY live write (fail-closed, no `cd /` fallback).

## Port workflow (per site)

1. **Crawl + tokens (mode 2).** Reuse existing crawls when fresher than 7 days (brandon: /tmp/elevate-rag, /tmp/core-crawl — both have manifests with URL+SHA256+date). Otherwise re-crawl (cap 25 pages) and capture screenshots at 1440px + 390px per the vite-astra-port workflow.
2. **Tokens + kit.** Build astra-tokens.css + WP-ASTRA-SKIN-KIT.md into `/root/agent-work/sovereign-corpus/ports/<site>-<date>/`, staged + committed locally. Brand assets: core-distro logo = core-distro-mark-green.png / core-distro-logo-white_ce3460b1.webp; elevate logo = /images/amino_logo_transparent_7c8d8a91.png (yes, that filename IS the Elevate logo on the live site — verified).
3. **Staging target.** WordPress staging runs as docker containers on brandon (mariadb + wordpress:latest, throwaway names `<site>-wp-stage`). animovps `staging.core-distro.com` vhost may proxy preview. Never stage on animovps webroot directly.
4. **Chatbot embed is part of the kit.** Every ported page carries the HD2.ai widget snippet: base-api-url `https://agents.elevatesci.com/api/embed`, assistant name + brand image + assistant icon per site (core: core-distro-mark-green.png; elevate: the site logo), sponsor-text "Powered by HD2.ai". Embed IDs are minted in the brandon instance (admin or embed_configs row) — never invent IDs. When site content migrates, sync the RAG: re-crawl the WP site and update the matching workspace (core-distro / elevate) so the bot never lags the site.
5. **Content migration honesty.** Pages/posts: automatable from the crawl. WooCommerce/product data, forms, Stripe, legal pages: staged for captain review, never zero-touch.
6. **Cutover gate (captain).** Production cutover happens only on explicit captain GO, after: staging pixel-check vs screenshots, perf floor (inline critical CSS, WebP w/ dimensions, per-page titles/descriptions, llms.txt, AI crawlers allowed, full text in served HTML), backup of the current webroot + DB, and a rollback one-liner. Sites stay reachable throughout; DNS changes are captain-gated.

## Hard rules

- Live sites on elevatesVPS (formerly animovps) are production. Backups precede every mutation; vhost backups use dated `.pre-<task>` copies (see agents.elevatesci.com.pre-chatbot-* precedent).
- The captain is shown the lane plot before launch; reports route to the controller; deliverables are AGY/Gemini-reviewed.
- AnythingLLM references stay out of customer-facing surfaces (HD2.ai wording), per captain intent — same rule for the WP builds' front end.
