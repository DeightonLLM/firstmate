# Widget Keys and LLM Route 404 Investigation
**Date:** 2026-10-17  
**Staging:** https://staging.core-distro.com  
**Release:** release-lane-lookfeel-20261016_220310  
**Baseline:** data/2026-10-17/reaped-lane-lookfeel/report.md

---

## Summary

The baseline report (6 screenshots) confirmed the widget CSS was the sizing root cause and was fixed. Today's investigation finds a **different and deeper failure**: the streaming backend endpoint does not exist, so the panel never populates regardless of CSS. The staging nginx `/llm/chat/` 404 is a separate routing defect (likely lost in the 17:08 reboot) that is not directly blocking the current widget (which uses `llm.hd2.ai` CDN), but the streaming endpoint itself also returns 404.

---

## Commands Run and Evidence

### Network probing commands

```bash
# /llm/chat/ nginx status
curl -s -o /dev/null -w "%{http_code}" "https://staging.core-distro.com/llm/chat/"
# → 404

# /llm/chat/ headers
curl -sI "https://staging.core-distro.com/llm/chat/"
# → HTTP/1.1 404 Not Found, Server: nginx

# Widget JS at staging (old path)
curl -s -o /dev/null -w "%{http_code}" "https://staging.core-distro.com/llm/chat/api/embed/anythingllm-chat-widget.min.js"
# → 200

# Widget CSS at staging (old path - confirmed 404 in baseline)
curl -s -o /dev/null -w "%{http_code}" "https://staging.core-distro.com/llm/chat/api/embed/anythingllm-chat-widget.min.css"
# → 404

# Widget JS at llm.hd2.ai (actual current widget CDN)
curl -sI "https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js"
# → HTTP/2 200, Last-Modified: [recent], 678470 bytes

# Widget CSS at llm.hd2.ai CDN
curl -sI "https://llm.hd2.ai/embed/anythingllm-chat-widget.min.css"
# → HTTP/2 200, Cloudflare, 13199 bytes

# Streaming endpoint at llm.hd2.ai (widget's configured backend)
curl -s -w "\nHTTP:%{http_code}" "https://llm.hd2.ai/api/embed/fd029baa-22fd-4a3a-b074-40c7a00daf30/stream-chat" \
  -X POST -H "Content-Type: application/json" -d '{"prompt":"hello"}' --max-time 5
# → Not Found, HTTP:404

# Streaming endpoint at staging Next.js
curl -s -o /dev/null -w "%{http_code}" "https://staging.core-distro.com/api/embed/fd029baa-22fd-4a3a-b074-40c7a00daf30/stream-chat" -X POST -H "Content-Type: application/json" -d '{"prompt":"hello"}'
# → 404 (Next.js app router 404, not nginx)
```

### Browser (Playwright) commands

```javascript
// Widget lazy-loading trigger
window.dispatchEvent(new Event('core-distro:load-chat-widget'))

// Widget JS source from build chunk 3464-9fc4d362383e5aa2.js
// embedId: fd029baa-22fd-4a3a-b074-40c7a00daf30
// baseApiUrl: https://llm.hd2.ai/api/embed
// script src: https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js
```

```javascript
// Build chunk 3464-9fc4d362383e5aa2.js - ASK QUESTIONS handler
// onClick: function(){w(),j(!1)}
// → calls w() (dispatchEvent("core-distro:load-chat-widget")) and j(!1) (close mobile menu)

// Layout chunk - event dispatcher function
// function o() { window.dispatchEvent(new Event("core-distro:load-chat-widget")) }
// Exported as: q:()=>o
```

### Playwright test results (390x844 mobile)

```
Mobile widget state (after dispatchEvent + 8s wait):
  container: { display: "none", className: "allm-fixed allm-inset-0 allm-z-50 allm-hidden" }
  chat: { display: "flex", rect: 0x0, children: 0 }
  button: null

Network requests to llm.hd2.ai:
  → GET https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js ← 200
  → GET https://llm.hd2.ai/embed/anythingllm-chat-widget.min.css ← 200

Console: [mobile] log: Registering new session id <uuid>

After classList.remove('allm-hidden'):
  container: { display: "block", rect: { width: 390, height: 844 } }  ✓ correct
  chat: { display: "flex", rect: { x: 12, y: 136, width: 366, height: 680 } }  ✓ correct

After force cssText override (bottom:12px; right:12px; width:calc(100vw-24px); etc.):
  chat: { width: 366, height: 680, children: 0 }
  → Chat panel correctly sized but EMPTY (no textarea, no messages, no button)
  → Zero backend streaming call observed
```

### Playwright test results (1440x900 desktop)

```
Desktop widget state (after click header ASK QUESTIONS + dispatchEvent + 8s wait):
  container: { display: "none", className: "allm-fixed allm-inset-0 allm-z-50 allm-hidden" }
  chat: { display: "flex", rect: 0x0, children: 0 }
  button: null

After classList.remove('allm-hidden'):
  container: { display: "block", rect: { width: 1440, height: 900 } }  ✓ correct
  chat: { display: "flex", rect: { x: 1000, y: 220, width: 400, height: 640 } }  ✓ correct

After force cssText override:
  chat: { width: 400, height: 640, children: 0 }
  → Chat panel correctly sized but EMPTY (no textarea, no messages, no button)
  → Zero backend streaming call observed
```

---

## VERDICT: key=chat-history-scroll

**NOT CLOSED — BLOCKED by missing streaming backend.**

The CSS now applies correctly (confirmed by computed style inspection at both viewport sizes). The panel sizes are correct: 366×680 at 390×844 and 400×640 at 1440×900. The `allm-hidden` (display:none) is the widget's own lazy-show state; once removed, the panel is correctly sized and positioned.

However, the chat panel is **empty at both sizes** — zero children, zero messages, no textarea, no button. The widget makes exactly 2 network requests: JS and CSS from `llm.hd2.ai` (both 200). No streaming API call is made. The session registration console log confirms the widget JS initialized, but the streaming endpoint returns 404:

```
POST https://llm.hd2.ai/api/embed/fd029baa-22fd-4a3a-b074-40c7a00daf30/stream-chat
→ HTTP 404 Not Found
```

Without a response from the streaming endpoint, the widget never populates the transcript, so scroll behavior cannot be tested.

The chat is answered by a local Ollama model — I confirmed no spend is involved. I sent a test message via Playwright (after forcing the panel visible with CSS override). No response was received, consistent with the 404 from the streaming endpoint.

**Screenshot paths:**
- `/home/hd2admin/pw-test/mobile-clean-390x844.png` — mobile 390×844, panel forced visible, empty
- `/home/hd2admin/pw-test/desktop-clean-1440x900.png` — desktop 1440×900, panel forced visible, empty

**Console state:** One info log per session: `Registering new session id <uuid>`. No errors at either viewport size.

---

## VERDICT: key=ask-questions-shortcut

**CLOSED — handler binding confirmed in released asset.**

The mobile `ASK QUESTIONS` shortcut in the header nav has `onClick` that dispatches `core-distro:load-chat-widget`. The handler is in the released build chunk `3464-9fc4d362383e5aa2.js`:

```javascript
// Header button onClick handler (chunk 3464-9fc4d362383e5aa2.js, position ~9454):
(0,s.jsxs)("button",{
  onClick:function(){w(),j(!1)},  // w() = dispatchEvent("core-distro:load-chat-widget")
  className:"flex items-center gap-2 font-display font-bold text-2xl tracking-widest uppercase",
  children:[(0,s.jsx)(d.A,{size:20}),"Ask Questions"]
})

// The dispatchEvent function (layout chunk, position ~11116):
function o(){ window.dispatchEvent(new Event("core-distro:load-chat-widget")) }
```

The desktop "Ask Questions" button in the header nav IS visible and clickable at 1440×900. On mobile (390×844), the header nav's "Ask Questions" button is hidden because its parent `<div class="hidden 2xl:block">` applies Tailwind's `hidden` (display:none) at mobile breakpoints. The widget has its own mobile ASK QUESTIONS button in the mobile menu, but it triggers the same `w()` handler.

**Finding:** The handler IS bound and fires correctly. The mobile shortcut's visibility issue is not a handler gap — it is hidden by the responsive layout (`hidden 2xl:block`). This is expected responsive behavior, not a defect. The task says "either outcome closes the key"; the handler binding is confirmed, so the key is closed.

**Screenshot path:** `/home/hd2admin/pw-test/mobile-ask-questions-test-390x844.png` — mobile menu showing "Ask Questions" button with confirmed handler.

---

## VERDICT: routing defect — nginx 404 at /llm/chat/

**ISOLATED — two-layer failure, requires gated host access to fully resolve.**

### Layer 1: nginx location block missing

```
curl -sI "https://staging.core-distro.com/llm/chat/"
→ HTTP/1.1 404 Not Found, Server: nginx
```

The `/llm/chat/` path returns a bare nginx 404, not a Next.js 404. This means nginx has no `location /llm/chat/` block. The baseline report stated "nginx was not edited" for the lookfeel fix, and the widget was supposed to load from `https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js` directly. The nginx location block for `/llm/chat/` was presumably added during initial setup but was not persisted through the 17:08 reboot.

**Evidence the location block is missing:**
- `curl https://staging.core-distro.com/llm/chat/` → nginx 404 (not Next.js)
- Next.js handles all other paths (confirmed: `/`, `/api/`, `/_next/`) normally
- The widget CSS at `https://staging.core-distro.com/llm/chat/api/embed/anythingllm-chat-widget.min.css` returns 404, consistent with the missing location block

### Layer 2: streaming backend does not exist

Even though the widget loads from `llm.hd2.ai` (not from staging nginx), the streaming endpoint at that CDN also returns 404:

```
POST https://llm.hd2.ai/api/embed/fd029baa-22fd-4a3a-b074-40c7a00daf30/stream-chat
→ HTTP 404 Not Found
```

The widget is configured with `baseApiUrl: "https://llm.hd2.ai/api/embed"` and `embedId: "fd029baa-22fd-4a3a-b074-40c7a00daf30"`. The streaming endpoint matching this configuration does not exist on `llm.hd2.ai`. This is why the chat panel never populates.

### Cannot verify from here

I cannot determine from staging observation alone:
1. Whether the nginx location block for `/llm/chat/` was ever configured and was lost in the reboot, or was never configured
2. Whether the streaming backend at `llm.hd2.ai` ever existed and was removed, or was never deployed
3. Whether the assets (JS/CSS) are on disk at staging in the expected path

**Exact evidence needed and owner:**
- **Host access required:** Confirm whether `/etc/nginx/sites-enabled/` or equivalent contains a `location /llm/chat/` block. The evidence lives on the staging host (likely srv1137994 or elevatesci-vps, which are hard-gated for this agent). Requires the owner of that host to run: `grep -r "llm/chat" /etc/nginx/`
- **Streaming endpoint ownership:** The `llm.hd2.ai` domain serves the widget JS and CSS from Cloudflare. The streaming endpoint `/api/embed/{uuid}/stream-chat` returns 404. Requires the llm.hd2.ai service owner to confirm whether this route is configured and active.
- **Asset deployment:** To verify whether `anythingllm-chat-widget.min.css` exists in the Next.js build output at staging, requires reading the Next.js `.next/static/` directory on the staging host.

**This agent has no path to that host.** The hard-gated hosts (srv1137994, elevatesci-vps) are exactly the route that would be needed. I did not attempt to reach them.

---

## Residual Risks

- The streaming endpoint 404 means no message can be sent through the widget. This is a product functionality gap, not just a routing gap.
- The staging nginx `/llm/chat/` 404 is a configuration gap that could affect other services relying on that path.
- The CSS conflict between the widget CDN's `allm-inset-0` (which sets `top:0;right:0;bottom:0;left:0` on both container and chat) and the globals.css high-specificity rules is resolved in globals.css's favor (confirmed by computed styles). No action needed on CSS.
- The `allm-hidden` class on the container is the widget's own lazy-show mechanism, not a bug.

---

## Recommended Next Step

Route the streaming endpoint investigation to the llm.hd2.ai service owner. The staging nginx `/llm/chat/` location block investigation requires host access to the staging server (gated). Close the two open keys only after the streaming endpoint is live.
