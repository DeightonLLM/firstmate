# HD2ai saved fix port — 2026-10-05

Ported the complete CSS override from `/home/hd2admin/agent-work/core-distro-saas-clean/current-core-distro/index.html` lines 163–199 into the shared widget as a guarded `hdsizingfix-20261005` style-injecting IIFE. The source CSS is reproduced verbatim below.

```css
/* ── AnythingLLM host-page mobile override (DubzAi/HD2 standard) ── */
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
  max-width: 32px !important;
  max-height: 32px !important;
}
#anything-llm-chat textarea,
#anything-llm-chat input { font-size: 16px !important; }
#anything-llm-chat textarea { min-width: 0 !important; padding-right: 3.25rem !important; }
#anything-llm-chat button[type="submit"],
#anything-llm-chat form button:last-child {
  flex: 0 0 auto !important;
  min-width: 44px !important;
  margin-right: 0 !important;
}
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

IIFE guard is `var ID = "hdsizingfix-20261005"; if (document.getElementById(ID)) return;`; injected style element has that ID. The existing widgetfix and consentfix prefix was byte-identical to its backup before this append, verified by SHA-256.

## Diff versus existing widgetfix

This port adds host-frame width constraints, `100svh` maximum sizing and 12px gutters; rectangular 80px logo treatment and 32px assistant icon; 720px breakpoint/focus-within resizing; input font-size 16px; and submit-row flex sizing. Existing widgetfix retains its `100dvh`, safe-area padding, sticky form, circular logo and 768px/coarse-pointer behavior. Both IIFEs remain present and unchanged; they target complementary rules.

## Verification

Backup `/home/hd2admin/hd2stack-anythingllm/branding/anythingllm-chat-widget.min.js.bak-hdsizingfix-20261005`: 671596 bytes, MD5 `a86939d1b9926d76da51775e804fe49e`, SHA-256 `963d863759835546827ccdd5fad0961b909f45b3b363092d1f1b806221c337a7`.

Current asset: 674287 bytes, MD5 `7129d0e48a4ad8d261336ded80278642`, SHA-256 `1f1bb8c45b5d717ac7b6c51c8b167f34005d01d0a06e67fcf57499a4ae002a2d`. Local `http://100.106.6.22:3001/embed/anythingllm-chat-widget.min.js` and public `https://agents.elevatesci.com/embed/anythingllm-chat-widget.min.js` both returned 674287 bytes and the same MD5. Marker counts in public response: hdsizingfix 2, consentfix 2, widgetfix 4. `node --check` passed. No restart attempted.

VERDICT: PASS
