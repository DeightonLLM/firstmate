# HD2 Embed Snippet Prep — Core Distro & Elevate Scientific

**Task:** hd2-embed-prep-local-preview-0926
**Date:** 2026-09-26
**Mode:** SCOUT — read-only; local files and workspace evidence only
**Live services:** NOT accessed; AnythingLLM instance NOT inspected

---

## Summary

Prepared HD2-branded embed snippet templates for **Core Distro** (from local source) and **Elevate Scientific** (pending admin action). The Core Distro snippet is present in `current-core-distro/index.html`; this task did not verify it is currently live or that the embed ID is still active. Elevate requires admin action to create the workspace and provide the logo URL and embed ID. An offline mock preview showing both brands at desktop and 390px mobile widths is at `/tmp/embed-preview/preview.html` (workspace copy: `data/hd2-embed-prep-local-preview-0926/preview.html`).

---

## Core Distro — Snippet from Local Source

```html
<!-- HD2.ai AI Assistant Widget -->
<script
  data-cfasync="false"
  data-embed-id="0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2"
  data-base-api-url="https://llm.hd2.ai/api/embed"
  data-assistant-name="Core Distro Assistant"
  data-brand-image-url="https://core-distro.com/core-distro-mark-green.png"
  data-assistant-icon="https://core-distro.com/core-distro-mark-green.png"
  data-chat-icon="chatBubble"
  data-user-bg-color="#00d455"
  data-sponsor-text="Powered by HD2.ai"
  data-sponsor-link="https://hd2.ai"
  src="https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js">
</script>
<!-- HD2ai (https://hd2.ai) -->
```

**This snippet is present in the local source copy. This task did not verify whether it is currently deployed or whether the embed ID is still active.**

---

## Elevate Scientific — Snippet (future actions outside this task's authorization)

```html
<!-- HD2.ai AI Assistant Widget -->
<script
  data-cfasync="false"
  data-embed-id="EMBED_ID_PENDING"
  data-base-api-url="https://llm.hd2.ai/api/embed"
  data-assistant-name="Elevate Scientific Assistant"
  data-brand-image-url="ELEVATE_LOGO_URL_PENDING"
  data-assistant-icon="ELEVATE_LOGO_URL_PENDING"
  data-chat-icon="chatBubble"
  data-user-bg-color="#00388F"
  data-sponsor-text="Powered by HD2.ai"
  data-sponsor-link="https://hd2.ai"
  src="https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js">
</script>
<!-- HD2ai (https://hd2.ai) -->
```

**Brand colours:** `#00388F` (forest/navy primary), `#33D4CC` (teal accent) — from `data/elevate-mobile-audit/evidence/site-style.css`.

**To activate:** Replace `EMBED_ID_PENDING` with the AnythingLLM workspace embed slug (requires admin access), and `ELEVATE_LOGO_URL_PENDING` with the approved Elevate Scientific logo URL. Both require separate admin action outside this task's authorization.

**Note:** An alternative `data-base-api-url="https://agents.elevatesci.com/api/embed"` appears in Brandon's 2026-09-26 handoff. Which base URL to use requires admin confirmation.

---

## Admin Steps to Provision Elevate Embed (future actions)

**Note:** Workspace creation, corpus/embedding changes, logo uploads, deployment, and live testing are future actions outside this task's authorization.

1. **Obtain brand logo** — Get official Elevate Scientific logo (`.png` or `.webp`) from brand owner. Upload to a public URL.
2. **Create AnythingLLM workspace** — e.g., `elevate_public_20260923`. Ingest the 42 approved public pages (SHA-256 hashes in `data/elevate-public-rag-corpus-0923/crawl/manifest.json`). **Corpus ingestion requires separate approval and a read-only coverage audit.**
3. **Enable embed chatbot** in workspace settings.
4. **Copy embed slug** (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
5. **Confirm API base URL** — `https://llm.hd2.ai/api/embed` or `https://agents.elevatesci.com/api/embed`.
6. **Replace `EMBED_ID_PENDING` and `ELEVATE_LOGO_URL_PENDING`** in the snippet above.
7. **Deploy** the snippet before `</body>` and add the mobile CSS override (see report). **Deployment is outside this task's authorization.**
8. **Test** on `elevatesci.com`. **Live testing is outside this task's authorization.**

---

## Local Preview

| File | Purpose |
|------|---------|
| `/tmp/embed-preview/preview.html` | Primary offline mock |
| `data/hd2-embed-prep-local-preview-0926/preview.html` | Readable workspace copy |

The preview shows all four viewport/brand combinations with brand colour swatches. **⚠ This is a layout/colour mock only — it does not verify actual widget appearance, rendering, or latency.**

**Preview portability:** The offline preview uses `file://` URLs to load local brand assets. It makes no network requests. As delivered, logo images will not render when the file is opened on a different machine or served from a different path. The preview is not self-contained.

---

## Local Brand Asset Sources (Core Distro)

All confirmed present in `core-distro-saas-clean/current-core-distro/`:
- `core-distro-mark-green.png` — primary assistant icon
- `core-distro-mark-navy.png`
- `core-distro-mark-light.png`
- `core-distro-logo-white.webp`
- `core-distro-mark-navy.webp`
- `core-distro-mark-light.webp`

No local Elevate logo found in any workspace evidence.

---

## Limitations

- No live AnythingLLM inspection — embed IDs, workspace settings, RAG corpus, and system prompt are unverified locally.
- No live HTTP checks — service reachability not confirmed.
- No local Elevate logo — preview uses neutral placeholder.
- API base URL ambiguity for Elevate requires admin decision.
- Widget appearance unverifiable without live execution.
- Workspace creation, corpus ingestion, deployment, and live testing are outside this task's authorization.

---

## Open Questions for Admin

| # | Question |
|---|----------|
| Q1 | What is the Elevate Scientific logo URL? |
| Q2 | Which API base URL for Elevate: `llm.hd2.ai` or `agents.elevatesci.com`? |
| Q3 | Does an Elevate AnythingLLM workspace already exist? |
| Q4 | What is the Elevate embed slug? |
| Q5 | Embedding model, chunk size, retrieval settings for Elevate? |
| Q6 | Which `elevatesci.com` page(s) should receive the embed? |
| Q7 | Is the Core Distro embed ID `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2` still valid and current? |

Full report with evidence references: `data/hd2-embed-prep-local-preview-0926/report.md`
