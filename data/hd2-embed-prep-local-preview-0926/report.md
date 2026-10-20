# HD2 Embed Snippet Prep — Core Distro & Elevate Scientific

**Task:** hd2-embed-prep-local-preview-0926
**Date:** 2026-09-26
**Mode:** SCOUT — read-only; local files and workspace evidence only
**Live services:** NOT accessed; AnythingLLM instance NOT inspected

---

## 1. What I did

1. Read the steering inbox (empty — no pending messages).
2. Explored the `core-distro-saas-clean` worktree, `kun-agent-workspace/data/`, and `BRANDON-COMPUTE-COMMS/` for existing embed snippets, brand assets, crawl artifacts, and prior reports.
3. Located the Core Distro embed snippet in `current-core-distro/index.html:244–260`.
4. Located Brandon's 2026-09-26 handoff at `BRANDON-COMPUTE-COMMS/from-brandon-compute/20260926T-core-embed-snippet.md` which provides an alternative template using `agents.elevatesci.com` as the base URL.
5. Identified local Core Distro brand images in `current-core-distro/` (11 image files including `core-distro-mark-green.png`, `core-distro-logo-white.webp`, etc.).
6. Confirmed no local Elevate Scientific brand logo exists in any workspace evidence.
7. Identified Elevate brand colours from the site CSS capture: `#00388F` (forest/navy primary) and `#33D4CC` (teal accent) — source: `data/elevate-mobile-audit/evidence/site-style.css`.
8. Built an offline mock preview at `/tmp/embed-preview/preview.html` (and a readable copy at `data/hd2-embed-prep-local-preview-0926/preview.html`) showing both brands at desktop (1280px) and 390px mobile widths.
9. Wrote this report and the handoff copy.

---

## 2. Core Distro — Embed Snippet from Local Source

### 2a. Exact snippet as found in local source

Source: `core-distro-saas-clean/current-core-distro/index.html` lines 244–260

```html
<!-- AnythingLLM Chatbot Widget (DubzAi/HD2 standard embed) -->
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

**This snippet is present in the local source copy. This task did not verify whether it is currently deployed or whether the embed ID is still active. No live HTTP checks were performed.**

### 2b. Snippet template with `EMBED_ID_PENDING`

```html
<!-- HD2.ai AI Assistant Widget -->
<script
  data-cfasync="false"
  data-embed-id="EMBED_ID_PENDING"
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

**To activate:** replace `EMBED_ID_PENDING` with the embed slug from the Core Distro AnythingLLM workspace (requires admin access to the AnythingLLM instance).

### 2c. Brand asset sources

| Asset | Live URL (from local source) | Local copy in worktree |
|-------|------------------------------|----------------------|
| Logo mark (green, 1×) | `https://core-distro.com/core-distro-mark-green.png` | `current-core-distro/core-distro-mark-green.png` |
| Logo mark (navy, 1×) | `https://core-distro.com/core-distro-mark-navy.png` | `current-core-distro/core-distro-mark-navy.png` |
| Logo mark (light, 1×) | `https://core-distro.com/core-distro-mark-light.png` | `current-core-distro/core-distro-mark-light.png` |
| Main logo white (webp) | `https://core-distro.com/core-distro-logo-white_ce3460b1.webp` | `current-core-distro/core-distro-logo-white.webp` |
| Main logo (webp) | `https://core-distro.com/core-distro-mark-navy.webp` | `current-core-distro/core-distro-mark-navy.webp` |
| Mark green (webp) | (likely exists) | `current-core-distro/core-distro-mark-light.webp` |

All local copies confirmed present at:
`core-distro-saas-clean/current-core-distro/`

### 2d. Known snippet attributes

| Attribute | Value | Notes |
|-----------|-------|-------|
| `data-embed-id` | `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2` | As found in local source; must be verified from live AnythingLLM admin panel |
| `data-base-api-url` | `https://llm.hd2.ai/api/embed` | URL as recorded in local source; not verified reachable |
| `data-assistant-name` | `Core Distro Assistant` | |
| `data-brand-image-url` | `https://core-distro.com/core-distro-mark-green.png` | Local copy available |
| `data-assistant-icon` | `https://core-distro.com/core-distro-mark-green.png` | Same as brand image |
| `data-chat-icon` | `chatBubble` | Standard DubzAi/HD2 FAB icon |
| `data-user-bg-color` | `#00d455` | Bright green user-message bubble |
| `data-sponsor-text` | `Powered by HD2.ai` | Approved sponsor attribution |
| `data-sponsor-link` | `https://hd2.ai` | |
| Script src | `https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js` | URL as recorded in local source; not verified reachable |

---

## 3. Elevate Scientific — New Embed Template

**Status:** No embed exists in any local workspace evidence. No local brand logo found. Workspace creation, corpus ingestion, and deployment are future actions outside this task's authorization.

### 3a. Snippet template

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

**To activate:** Replace `EMBED_ID_PENDING` with the AnythingLLM workspace embed slug (requires admin access), and `ELEVATE_LOGO_URL_PENDING` with the approved Elevate Scientific logo URL. Both replacements require separate admin action outside this task's authorization.

### 3b. Alternative API base URL

Brandon's 2026-09-26 handoff (`BRANDON-COMPUTE-COMMS/from-brandon-compute/20260926T-core-embed-snippet.md`) references an alternative base URL:

```
data-base-api-url="https://agents.elevatesci.com/api/embed"
```

This would route to `agents.elevatesci.com` rather than `llm.hd2.ai`. **Which base URL to use requires admin confirmation** — see Open Questions §7.

### 3c. Brand asset sources

| Asset | Status | Evidence |
|-------|--------|----------|
| Brand logo (primary) | **NOT FOUND locally** | No `.png`, `.webp`, or `.svg` for Elevate found in any workspace evidence |
| Brand primary colour | `#00388F` (forest/navy) | `data/elevate-mobile-audit/evidence/site-style.css` — `--color-forest: #00388F` |
| Brand accent colour | `#33D4CC` (teal) | `data/elevate-mobile-audit/evidence/site-style.css` — `--color-teal-accent: #33D4CC` |
| Host page bg | `#f0f7ff` (light blue tint) | Derived from mock page observation |

**The Elevate logo must be obtained from the brand owner or extracted from `elevatesci.com` before the embed can be fully configured.**

### 3d. Known snippet attributes (Elevate)

| Attribute | Value | Notes |
|-----------|-------|-------|
| `data-embed-id` | `EMBED_ID_PENDING` | Admin must create workspace and provide embed slug |
| `data-base-api-url` | `https://llm.hd2.ai/api/embed` OR `https://agents.elevatesci.com/api/embed` | Requires confirmation |
| `data-assistant-name` | `Elevate Scientific Assistant` | Suggested; subject to approval |
| `data-brand-image-url` | `ELEVATE_LOGO_URL_PENDING` | Admin must provide |
| `data-assistant-icon` | `ELEVATE_LOGO_URL_PENDING` | Same as brand image |
| `data-chat-icon` | `chatBubble` | Standard |
| `data-user-bg-color` | `#00388F` | Navy/forest — matches brand primary |
| `data-sponsor-text` | `Powered by HD2.ai` | Approved sponsor attribution |
| `data-sponsor-link` | `https://hd2.ai` | |

---

## 4. Mobile CSS Override

Both snippets should include the standard host-page mobile override in the page `<style>` block (present in Core Distro's local source at `current-core-distro/index.html:163–199`):

```css
/* ── HD2.ai chat widget host-page mobile override ── */
#anything-llm-embed-chat-container { overflow: hidden; }
#anything-llm-chat {
  width: min(400px, calc(100vw - 24px)) !important;
  max-width: calc(100vw - 24px) !important;
  max-height: calc(100svh - 24px) !important;
  right: 12px !important;
  bottom: 12px !important;
  margin: 0 !important;
}
#anything-llm-chat img { max-width: 100%; object-fit: contain; }
html body #anything-llm-chat [class*="header"] img,
html body    #anything-llm-chat img[alt="Logo"] {
  height: 80px !important;
  max-height: 80px !important;
  width: auto !important;
}
html body #anything-llm-chat [class*="header"],
html body #anything-llm-chat > div > div:first-child {
  height: auto !important;
  min-height: 90px !important;
}
#anything-llm-chat img[alt="Assistant Icon"] {
  width: 32px !important;
  height: 32px !important;
}
```

---

## 5. Admin Steps to Create Embed IDs

**Note:** Workspace creation, corpus/embedding changes, logo uploads, deployment, and live testing are future actions that require separate authorization and are outside the scope of this task.

### For Core Distro (admin action required)

1. Log in to the AnythingLLM admin panel at the controller host (Contabo `vmi3238503` / `llm.hd2.ai`).
2. Navigate to the **Workspace** for Core Distro.
3. Under workspace settings, locate the **Embed Chatbot** section.
4. Copy the **embed slug / ID** (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
5. Insert the slug into the snippet as `data-embed-id`.
6. Place the snippet before `</body>` on the target page.
7. Verify by opening the page in a browser and confirming the chat bubble appears and responds.

### For Elevate Scientific (future actions — outside this task's authorization)

1. **Obtain brand logo** — Request the official Elevate Scientific logo from the brand owner. Preferred format: `.png` or `.webp`, square-ish aspect ratio suitable for 36×36 px assistant icon. Upload to a publicly accessible URL.
2. **Create AnythingLLM workspace** — Log in to the AnythingLLM admin panel. Create a new workspace named `elevate_<dataset>_<version>` (per PRD v3 convention), e.g., `elevate_public_20260923`.
3. **Configure the workspace:**
   - Set the **system prompt / persona** for the Elevate Scientific Assistant.
   - Ingest the approved corpus: 42 public `elevatesci.com` pages (SHA-256 hashes available in `data/elevate-public-rag-corpus-0923/crawl/manifest.json`). **Corpus ingestion requires separate approval and a read-only coverage audit before this task's authorization extends to recommending or performing it.**
   - Configure embedding model, chunk size, and retrieval settings (values not yet in local evidence).
4. **Enable embed chatbot** — In workspace settings, enable the embed chatbot feature.
5. **Copy the embed slug** — Obtain the workspace embed ID (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
6. **Choose API base URL** — Decide between `https://llm.hd2.ai/api/embed` (shared AnythingLLM instance) or `https://agents.elevatesci.com/api/embed` (dedicated Elevate instance — requires separate deployment confirmation).
7. **Populate the snippet** — Replace `EMBED_ID_PENDING` with the actual embed slug and `ELEVATE_LOGO_URL_PENDING` with the logo URL.
8. **Deploy** — Add the snippet before `</body>` on the target `elevatesci.com` page(s). Add the mobile CSS override `<style>` block. **Deployment is outside this task's authorization.**
9. **Test** — Open `elevatesci.com` in a browser, confirm the chat bubble appears, and verify a response is returned. **Live testing is outside this task's authorization.**

---

## 6. Local Preview

**Primary preview file:** `/tmp/embed-preview/preview.html`
**Readable workspace copy:** `data/hd2-embed-prep-local-preview-0926/preview.html`

The preview shows four mockups:
1. Core Distro — Desktop (1280px) — local logo used
2. Core Distro — Mobile (390px) — local logo used
3. Elevate Scientific — Desktop (1280px) — neutral placeholder (no local logo)
4. Elevate Scientific — Mobile (390px) — neutral placeholder (no local logo)

Each mockup shows:
- A simulated host page with brand colours
- A mock widget in the open state with header, conversation, and input
- Brand colour swatches
- Sponsor line

**⚠ This mock does not verify actual widget appearance, layout, CSS rendering, animation, or network latency. It is a static layout/colour approximation only.**

**Preview portability:** The offline preview uses `file://` URLs to load local brand assets. It makes no network requests. As delivered, the logo images will not render when the file is opened on a different machine or served from a different path. The preview is not self-contained and is not portable in its current form.

---

## 7. Limitations

| Limitation | Impact |
|------------|--------|
| No live AnythingLLM inspection performed | Embed ID, workspace settings, RAG corpus, and system prompt are not locally verified |
| No live HTTP checks | Cannot confirm `llm.hd2.ai` or `agents.elevatesci.com` are currently reachable |
| No local Elevate logo | The preview uses a neutral placeholder; the actual logo must be sourced from the brand owner |
| API base URL ambiguity | `https://llm.hd2.ai/api/embed` vs `https://agents.elevatesci.com/api/embed` requires admin decision |
| No deployment authorization | Snippets cannot be deployed by this task; admin must deploy |
| Mobile CSS override untested | The override block is copied from Core's local source; Elevate's page structure may differ |
| Widget appearance unverifiable | The AnythingLLM widget's actual DOM structure, fonts, and interactive states cannot be confirmed without live execution |

---

## 8. Open Questions

| # | Question | Who answers |
|---|----------|-------------|
| Q1 | What is the Elevate Scientific logo URL? Is there a preferred file format or size? | Brand owner / controller |
| Q2 | Which API base URL should Elevate use: `https://llm.hd2.ai/api/embed` (shared AnythingLLM) or `https://agents.elevatesci.com/api/embed` (dedicated instance)? | Controller / operator |
| Q3 | Does a dedicated AnythingLLM workspace for Elevate already exist, or does it need to be created from scratch? | Controller / operator |
| Q4 | What is the Elevate AnythingLLM workspace name and embed slug? | Controller / operator |
| Q5 | What embedding model, chunk size, and retrieval settings should be used for the Elevate workspace? | Controller / operator |
| Q6 | Should the system prompt for Elevate include peptide/lab-supply vertical knowledge (from `client-sales-journeys.html`) and what specific persona wording is approved? | Product / controller |
| Q7 | Which `elevatesci.com` page(s) should receive the embed snippet — homepage only, all pages, or a specific subset? | Product / controller |
| Q8 | Is the Core Distro embed ID `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2` still valid and current? | Controller / operator |

---

## 9. Evidence References

| Evidence | Path |
|----------|------|
| Core Distro embed snippet | `core-distro-saas-clean/current-core-distro/index.html:244–260` |
| Core Distro mobile CSS override | `core-distro-saas-clean/current-core-distro/index.html:163–199` |
| Core Distro local brand images | `core-distro-saas-clean/current-core-distro/*.png`, `*.webp` |
| Brandon's 2026-09-26 snippet handoff | `BRANDON-COMPUTE-COMMS/from-brandon-compute/20260926T-core-embed-snippet.md` |
| Elevate brand colours (site CSS) | `data/elevate-mobile-audit/evidence/site-style.css` |
| Elevate crawl manifest (42 pages) | `data/elevate-public-rag-corpus-0923/crawl/manifest.json` |
| Prior chatbot trial map & benchmark | `data/local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1/report.md` |
| Offline mock preview | `/tmp/embed-preview/preview.html` (primary); `data/hd2-embed-prep-local-preview-0926/preview.html` (workspace copy) |
| Handoff copy | `BRANDON-COMPUTE-COMMS/from-brandon-compute/20260925T-hd2-embed-prep.md` |

---

*Report written read-only. No live services accessed, no production configuration changed, no deploys executed.*
