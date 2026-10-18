# Core → Elevate Chatbot Handoff Report
**Date:** 2026-09-24
**Worker:** crewmate (firstmate-managed)
**Source checkout:** `/home/hd2admin/agent-work/core-distro-saas-clean`
**Mode:** READ-ONLY scout — no edits, builds, deployments, or credential access

---

## 1. Confirmed Project Root, Branch, and File References

| Field | Value |
|---|---|
| **Project root** | `/home/hd2admin/agent-work/core-distro-saas-clean` |
| **Branch** | `main` |
| **HEAD commit** | `2eb4e12d33106a71f3e7439c053df9080c4adca6` |
| **Embed file** | `current-core-distro/index.html` |
| **Script tag** | lines 252–264 |
| **Host-page style block** | lines 26–213 (full `<style>` block; AnythingLLM overrides at ~183–213) |
| **Mobile base CSS** | `html, body { overflow-x: clip }` at ~line 31 |
| **Body mobile viewport** | `min-height: 100svh` at ~line 48 |

---

## 2. Exact Observed Widget Attributes

The script tag uses these `data-*` attributes (DubzAi/HD2 AnythingLLM standard):

```html
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
```

### Attribute purpose mapping

| Attribute | Purpose |
|---|---|
| `data-cfasync="false"` | Cloudflare async loading control |
| `data-embed-id` | Workspace-specific embed token (Core's only — do not reuse) |
| `data-base-api-url` | AnythingLLM embed API base (shared HD2 runtime) |
| `data-assistant-name` | Chat header label shown in the widget |
| `data-brand-image-url` | Header logo rendered by the widget (Core brand) |
| `data-assistant-icon` | Assistant avatar in the chat header (Core brand) |
| `data-chat-icon` | Closed-widget icon; `chatBubble` = HD2 default bubble |
| `data-user-bg-color` | Accent color `#00d455` matching Core's design system |
| `data-sponsor-text` | Footer sponsor label (`Powered by HD2.ai`) |
| `data-sponsor-link` | Sponsor footer URL (`https://hd2.ai`) |

---

## 3. Host-Page Mobile CSS Override (DubzAi/HD2 Standard)

All of the following is confirmed present in the `<style>` block (lines ~183–213). The `html, body { overflow-x: clip }` rule at line ~31 is also required:

```css
/* Base overflow guard */
html, body { overflow-x: clip; }

/* Container overflow clamp */
#anything-llm-embed-chat-container { overflow: hidden; }

/* Desktop/tablet fixed positioning */
#anything-llm-chat {
  width: min(400px, calc(100vw - 24px)) !important;
  max-width: calc(100vw - 24px) !important;
  max-height: calc(100svh - 24px) !important;
  right: 12px !important;
  bottom: 12px !important;
  margin: 0 !important;
}
#anything-llm-chat img { max-width: 100%; object-fit: contain; }

/* Header logo sizing */
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

/* Assistant icon sizing */
#anything-llm-chat img[alt="Assistant Icon"] {
  width: 32px !important;
  height: 32px !important;
  max-width: 32px !important;
  max-height: 32px !important;
}

/* Form input sizing (prevents iOS zoom) */
#anything-llm-chat textarea,
#anything-llm-chat input { font-size: 16px !important; }
#anything-llm-chat textarea { min-width: 0 !important; padding-right: 3.25rem !important; }

/* Submit button sizing (touch target) */
#anything-llm-chat button[type="submit"],
#anything-llm-chat form button:last-child {
  flex: 0 0 auto !important;
  min-width: 44px !important;
  margin-right: 0 !important;
}

/* Mobile breakpoint (≤720px) */
@media (max-width: 720px) {
  #anything-llm-chat {
    left: 12px !important;
    right: 12px !important;
    width: calc(100vw - 24px) !important;
    max-height: calc(100svh - 24px) !important;
    border-radius: 14px !important;
  }
  #anything-llm-chat:focus-within {
    left: 6px !important;
    right: 6px !important;
    bottom: max(4px, env(safe-area-inset-bottom)) !important;
    width: calc(100vw - 12px) !important;
    max-width: calc(100vw - 12px) !important;
    max-height: min(61svh, 500px) !important;
  }
}
```

---

## 4. Logo Assets and Attribute Names

| Asset | Attribute (on `<script>`) | URL (Core's — do not copy to Elevate) |
|---|---|---|
| Header brand logo | `data-brand-image-url` | `https://core-distro.com/core-distro-mark-green.png` |
| Assistant avatar | `data-assistant-icon` | `https://core-distro.com/core-distro-mark-green.png` |
| Page hero logo | `<img src>` inside `.logo-wrap` | `/core-distro-logo-white.webp` (relative) |
| OG/Twitter share image | `<meta property="og:image">` / `twitter:image` | `https://core-distro.com/core-distro-share-green.jpg` |
| Favicon | `<link rel="icon">` | `/favicon.ico` (relative) |
| Apple touch icon | `<link rel="apple-touch-icon">` | `/core-distro-apple-touch-icon-180.png` (relative) |

No Core brand images should be copied into Elevate recommendations. Elevate must use its own logo/avatar URLs once those assets are available.

---

## 5. Source / Evidence Gaps

The following information is **not** derivable from this checkout and is required before Elevate implementation can proceed:

| Gap | Description | Owner Decision Required |
|---|---|---|
| **Production deploy source** | This checkout at `core-distro-saas-clean` is a working copy; it has not been confirmed as the live deploy root or the canonical production source. | Identify the actual production deploy path/URL for Core before mirroring any pattern. |
| **AnythingLLM runtime owner** | The widget script and API at `llm.hd2.ai` are HD2-operated shared infrastructure. It is unclear whether Elevate has access to the same runtime, a separate workspace, or requires a new AnythingLLM installation. | HD2 runtime/workspace owner must confirm Elevate's workspace provisioning and API access. |
| **Workspace / embed ID** | Core's `data-embed-id` (`0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2`) and `data-base-api-url` are Core-specific. Elevate needs its own workspace with its own credentials. | AnythingLLM admin must provision an Elevate workspace and issue a new embed ID + API base URL. |
| **Prompt / RAG configuration** | No prompt template or RAG document set was visible in the inspected HTML. AnythingLLM workspace prompt, system prompt, and attached documents are configured server-side and not inspectable from the embed. | Determine if Elevate needs its own knowledge base or a shared HD2 knowledge base. |
| **Elevate identity assets** | No Elevate logo, assistant name, avatar, accent color, or domain was found in or adjacent to this checkout. | Elevate branding owner must supply `data-assistant-name`, `data-brand-image-url`, `data-assistant-icon`, `data-user-bg-color`, and any brand color tokens. |
| **Domain / URL mapping** | The `data-base-api-url` references `llm.hd2.ai`. If Elevate uses a different domain, the API base URL must be updated accordingly. | Confirm Elevate's intended chatbot domain and runtime endpoint. |

---

## 6. Proposed Adaptation Checklist (Elevate Identity Separation)

This checklist is **not** implementation authorization — it is a handoff record. Each item requires a runtime owner decision before work begins.

- [ ] **a. Elevate embed ID** — obtain a new `data-embed-id` from the AnythingLLM admin for the Elevate workspace. Do not reuse Core's `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2`.
- [ ] **b. Elevate API base URL** — confirm whether Elevate uses the shared HD2 runtime (`https://llm.hd2.ai/api/embed`) or a separate endpoint. Obtain the correct `data-base-api-url`.
- [ ] **c. Elevate assistant name** — decide on `data-assistant-name` value (e.g., "Elevate Assistant"). Core's "Core Distro Assistant" must not appear in Elevate's widget.
- [ ] **d. Elevate brand logo** — provide a logo URL for `data-brand-image-url` (widget header logo). Elevate must not use `core-distro-mark-green.png`.
- [ ] **e. Elevate assistant icon** — provide an avatar URL for `data-assistant-icon`. Elevate must not use Core's brand mark.
- [ ] **f. Elevate accent color** — decide on `data-user-bg-color` and CSS `--accent` / `--accent-glow` tokens that reflect Elevate's identity (not Core's `#00d455`).
- [ ] **g. Sponsor footer** — `data-sponsor-text="Powered by HD2.ai"` and `data-sponsor-link="https://hd2.ai"` are appropriate if HD2 powers Elevate's chatbot; confirm this remains correct for Elevate.
- [ ] **h. Mobile CSS** — adopt the full DubzAi/HD2 AnythingLLM mobile override block (section 3 above) verbatim in Elevate's host page `<style>`, including `html, body { overflow-x: clip }` and the `min-height: 100svh` body rule. Do not omit any rule.
- [ ] **i. Production source confirmation** — verify with the project owner that `core-distro-saas-clean` (or another path) is the canonical production deploy source before copying any pattern from it.
- [ ] **j. AnythingLLM workspace RAG/prompt** — coordinate with the AnythingLLM admin to set Elevate's workspace prompt and attach any required knowledge base documents.
- [ ] **k. Build / deploy pipeline** — confirm whether Elevate's embed is deployed through the same CI/CD pipeline as Core or a separate one, and whether a restore-point backup is required before the first edit.

---

*Report generated by crewmate worker. All findings are grounded in live file inspection of `/home/hd2admin/agent-work/core-distro-saas-clean` at `main` commit `2eb4e12`. No credentials, API keys, or live deployments were accessed. No project files were modified.*
