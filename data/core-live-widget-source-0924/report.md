# Mobile Clipping Diagnostic — core-distro.com
**Task:** core-live-widget-source-0924  
**Date:** 2026-09-24  
**Worker:** Hetzner Firstmate crewmate (read-only scout)  
**Status:** BOUNDED CLOSE-OUT — element and root cause remain UNCONFIRMED

---

## 1. What Was Investigated

The captain reported: an element near the **lower-left** is clipped or shifted on phones; on some Android devices it is difficult or impossible to move into view.

## 2. Live Site Evidence (HTTP fetch, no browser)

**URL inspected:** `https://core-distro.com/`

### 2.1 Platform identification

The live `core-distro.com` is a **Next.js SaaS application**, confirmed by:
- HTML structure matching a Next.js App Router page (script tags with `self.__next_f.push`, `__PAGE__`, `__R_`)
- Static asset paths: `/_next/static/chunks/...`
- CSS chunk: `/_next/static/css/1abc67f8aa6aa9ee.css`
- No PHP; not served from the `current-core-distro/` snapshot

### 2.2 AnythingLLM Widget present

The AnythingLLM embed script tag is in the live HTML:

```html
<script
  data-cfasync="false"
  data-embed-id="0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2"
  data-base-api-url="https://llm.hd2.ai/api/embed"
  data-assistant-name="Core Distro Assistant"
  data-brand-image-url="https://core-distro.com/core-distro-mark-green.png"
  data-chat-icon="chatBubble"
  data-user-bg-color="#00d455"
  data-sponsor-text="Powered by HD2.ai"
  data-sponsor-link="https://hd2.ai"
  src="https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js"
  defer=""
></script>
```

The embed script URL (`https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js`) returns HTTP 200 (confirmed).

### 2.3 Any thingLLM Chat Widget CSS (live site — inline `<style>` injected by Next.js layout)

Extracted verbatim from the live HTML response:

```css
#anything-llm-chat-widget-button {
  position: fixed !important;
  bottom: 20px !important;
  right: 20px !important;
  z-index: 9999 !important;
}

#anythingllm-chat-widget-window,
[id^="anythingllm-chat-widget"] {
  max-width: 100vw !important;
  max-height: 100dvh !important;
  right: 0 !important;
  bottom: 0 !important;
  z-index: 9998 !important;
  overflow: hidden !important;
}

@media (max-width: 768px) {
  #anythingllm-chat-widget-window,
  [id^="anythingllm-chat-widget"] {
    width: 100vw !important;
    left: 0 !important;
    border-radius: 0 !important;
  }
}
```

**Key finding:** The chat widget is anchored `bottom: 20px; right: 20px` — i.e. **lower-RIGHT**, not lower-left.

### 2.4 Widget script CDN reachable

```bash
$ curl -sI 'https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js'
HTTP/2 200
content-length: 658999
```

The widget JS itself is served and accessible. The `100dvh` values in the CSS are correctly `100dvh` (not `100vh`), which is the mobile-friendly unit.

## 3. Source Tree Evidence

### 3.1 `current-core-distro/index.html` (legacy/reference snapshot)

This file contains host-page override CSS for the AnythingLLM widget:

```css
footer {
  position: fixed;
  left: 0; right: 0; bottom: 0;
  padding: 10px 16px calc(10px + env(safe-area-inset-bottom));
  pointer-events: none;
  opacity: 0.55;
}

#anything-llm-chat {
  width: min(400px, calc(100vw - 24px)) !important;
  max-height: calc(100svh - 24px) !important;
  right: 12px !important;
  bottom: 12px !important;
}

@media (max-width: 720px) {
  #anything-llm-chat {
    left: 12px !important;   /* <-- mobile override */
    right: 12px !important;
  }
  #anything-llm-chat:focus-within {
    left: 6px !important;
    bottom: max(4px, env(safe-area-inset-bottom)) !important;
  }
}
```

This snapshot is **not** the live deployment (confirmed above: live is Next.js). It shows the same lower-RIGHT anchor (`right: 12px`).

### 3.2 `staged-export-test/` (canonical editable source)

The `staged-export-test/` directory contains PHP files. The AnythingLLM embed does **not** appear in any of the staged PHP source files — the widget is only injected into the Next.js deployment. No `0ec57bfa` string exists in `staged-export-test/`.

## 4. Browser Reproduction — BLOCKED

The Chrome DevTools bridge returned `BRIDGE_NOT_READY` on three sequential attempts (two prior recorded in brief, one confirmed this session). No browser-based visual inspection was possible.

**Recorded limitation:** visual confirmation of which on-screen element is clipped, and the actual rendered position at mobile viewport, could not be performed.

## 5. Diagnosis

### 5.1 The AnythingLLM chat widget is anchored LOWER-RIGHT, not lower-left

All confirmed CSS for the widget shows `right: 20px` (desktop) and `left: 0; right: 0` (mobile full-width), anchored to the bottom edge. This is the **opposite corner** from the reported "lower-left" symptom.

### 5.2 Disconfirming the chat widget as the reported element

Evidence that would disconfirm the chat widget as the cause:
- The widget CSS has `right: 20px` as its horizontal anchor — lower-right.
- The mobile full-width rule (`left: 0; right: 0`) places the widget spanning the full bottom of the screen, not bottom-left.
- A "clipped bottom-left" symptom on the chat widget would require the widget's left edge to be positive (off screen to the right), but the CSS explicitly sets `left: 0` in mobile.

### 5.3 Possible alternative candidates (unconfirmed, no browser evidence)

Without mobile rendering, other lower-corner elements that could match "lower-left, clipped":
- The fixed `footer` in `current-core-distro/index.html` (full-width strip, bottom: 0, pointer-events: none, opacity: 0.55)
- The language picker dropdown menu (desktop/mobile trigger)
- A mobile nav overlay
- An off-canvas menu that anchors to the bottom-left

### 5.4 What the `100dvh` value in the live CSS means (descriptive only, not causal attribution)

The widget's `max-height: 100dvh` uses the `dvh` (dynamic viewport height) unit, which in Android Chrome resolves to the actual visible browser area excluding the address bar. This is the correct modern unit for mobile. However, without a browser counterfactual, I cannot confirm whether this unit causes or fails to prevent clipping on any specific device.

## 6. Smallest Next Action

**Request from captain or controller:**
A screenshot or exact element name from a phone that reproduces the bug, so this scout can narrow the candidate list. The chat widget is anchored lower-right by all confirmed CSS and is unlikely to be the reported element.

**If a screenshot is unavailable:** the controller should confirm whether the AnythingLLM widget itself is the element being reported (lower-left vs lower-right is a material discrepancy that changes the entire investigation).

## 7. Commands Run

| Command | Output |
|---|---|
| `curl -s 'https://core-distro.com/'` | Next.js HTML (66KB), inline AnythingLLM CSS found |
| `curl -sI 'https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js'` | HTTP 200, script reachable |
| `rg '0ec57bfa' /home/hd2admin/agent-work/core-distro-saas-clean/ -l` | `current-core-distro/index.html` only |
| `rg 'anythingllm' /home/hd2admin/agent-work/core-distro-saas-clean/staged-export-test/ -l` | No matches (widget not in PHP source) |
| `chrome-devtools-axi start` | `BRIDGE_NOT_READY` — blocked |
| `chrome-devtools-axi newpage` | `BRIDGE_NOT_READY` — blocked |

## 8. Files Referenced

| File | Relevance |
|---|---|
| Live HTML from `https://core-distro.com/` | AnythingLLM widget CSS (inline `<style>` tag, lower-right anchor) |
| `current-core-distro/index.html` lines 152–211 | Legacy snapshot widget CSS override, lower-right anchor |
| `staged-export-test/` | Canonical editable source — widget NOT present in PHP |
| `https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js` | External widget JS (HTTP 200, not modified by host) |
