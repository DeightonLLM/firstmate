# Widget consent and reply-refresh fix — 2026-10-05

VERDICT: PASS

## Changes

Added an append-only guarded IIFE `consentfix-20261005` after the existing `widgetfix-20261005` and think-shim blocks. The original widgetfix block was preserved byte-for-byte.

1. Consent persistence: form groups with at least three checkbox inputs are treated as the three-tick consent flow. Once at least three are checked, acceptance is stored as `elevatesci-chat-consent=1+<timestamp>`. On subsequent render/mutation scans, a consent form is hidden when that key exists.
2. Reply refresh prevention: a document-level capture-phase submit listener calls `preventDefault()` before React's submit handler runs, preventing browser-native navigation/reload while leaving event propagation intact for widget handling. It does not stop propagation.

Representative appended code:

```js
var ID = "consentfix-20261005";
if (document.getElementById(ID)) return;
var KEY = "elevatesci-chat-consent";
...
if (checked >= 3) localStorage.setItem(KEY, "1+" + Date.now());
...
document.addEventListener("submit", function (event) {
  event.preventDefault();
  ...
}, true);
```

The minified bundle itself contains no consent-related strings, so the patch uses the three-checkbox form structure to identify the consent flow. Real-device interaction testing remains recommended.

## Existing widgetfix (part 3)

The pre-change backup matches the prior verified live widgetfix asset exactly: 669742 bytes, MD5 `600c9693a845885d1d6a1a0551d3027a`. Served bytes before this patch were independently fetched at the local and public URLs and matched that same size/hash. The existing `widgetfix-20261005` served marker count remains 4.

## Backup

`/home/hd2admin/hd2stack-anythingllm/branding/anythingllm-chat-widget.min.js.bak-consentfix-20261005`
- Original size: 669742 bytes
- SHA-256: `cdaff5c2beb9f2fb76230a68bc88e33d277d8ea1a10d8a09df0d8d33132bc72e`
- Original MD5: `600c9693a845885d1d6a1a0551d3027a`

## Served asset verification

Pre-change served baseline: 669742 bytes, MD5 `600c9693a845885d1d6a1a0551d3027a`.

Post-change host asset: 671596 bytes, MD5 `a86939d1b9926d76da51775e804fe49e`, SHA-256 `963d863759835546827ccdd5fad0961b909f45b3b363092d1f1b806221c337a7`.

| URL | Bytes | MD5 | Result |
|---|---:|---|---|
| `http://100.106.6.22:3001/embed/anythingllm-chat-widget.min.js` | 671596 | `a86939d1b9926d76da51775e804fe49e` | Matches host asset |
| `https://agents.elevatesci.com/embed/anythingllm-chat-widget.min.js` | 671596 | `a86939d1b9926d76da51775e804fe49e` | Matches host asset |

Size delta: +1854 bytes, append-only. `node --check` passed. Public served marker counts: `widgetfix-20261005` = 4; `consentfix-20261005` = 2. No container restart was attempted; prior deployment evidence recorded `RestartCount=0`. This task made no restart.

## Manual mobile test steps

1. Android: open a fresh visit, complete all three consent ticks and submit; verify acceptance is stored. Refresh/reopen and confirm the consent box does not reappear.
2. Android: send several replies and verify the chat frame does not reload and conversation state remains visible.
3. iPhone: test the send button at narrow viewport widths and with the keyboard open; confirm it stays visible and tappable above the home-indicator safe area.
4. Desktop: verify the logo remains circular and undistorted (existing `widgetfix-20261005` styling).

## Core-Distro disclosure

This is the shared widget on the same bind mount, served as the same JavaScript asset to Core-Distro; there is no Core-specific change. Only the shared asset was changed. No container internals, database, API, configuration, image, or restart was touched.

## HD2ai saved host-page sizing fix port (captain addition)

Appended guarded IIFE `hdsizingfix-20261005` after the existing `widgetfix-20261005` and `consentfix-20261005` IIFEs. The previous bytes are unchanged: SHA-256 of the new asset's first 671596 bytes exactly matches the `.bak-hdsizingfix-20261005` backup. The imported CSS is the complete 35-line block from the saved HD2/DubzAi host-page override; it layers container width/max-height, rectangular logo dimensions and contain behavior, 720px mobile sizing, 16px input text, 44px submit control, and focus-within safe-area positioning alongside the existing widgetfix styles.

New backup: `/home/hd2admin/hd2stack-anythingllm/branding/anythingllm-chat-widget.min.js.bak-hdsizingfix-20261005`, 671596 bytes, SHA-256 `963d863759835546827ccdd5fad0961b909f45b3b363092d1f1b806221c337a7`, MD5 `a86939d1b9926d76da51775e804fe49e`.

After port: 674287 bytes, MD5 `7129d0e48a4ad8d261336ded80278642`, SHA-256 `1f1bb8c45b5d717ac7b6c51c8b167f34005d01d0a06e67fcf57499a4ae002a2d`. Local HTTP and public HTTPS each serve 674287 bytes with matching MD5. Markers remain present: widgetfix=4, consentfix=2, hdsizingfix=2. `node --check` passed. No container restart was attempted.

The exact CSS and diff summary are in `hd2ai-saved-fix-port.md` at both report/captain-copy destinations listed below. No API, database, configuration, image, or container changes.

## FOCUSFIX-20261005 KEYBOARD-RESIZE FIX

Appended a guarded `focusfix-20261005` IIFE after the three prior IIFEs. It watches `window.visualViewport` resize/scroll with passive listeners and schedules geometry updates via `requestAnimationFrame`; delegated capture focusin/focusout listeners track chat input focus. While focused, the chat panel uses the visual viewport pixel height (retaining 100dvh/100svh fallback units) and the composer form is fixed to the calculated visual-viewport bottom with safe-area subtraction. It records scrollY and restores it on blur, and applies `overscroll-behavior: contain`. If no `visualViewport` exists, it leaves the previous widget sizing in place. On focus it adds `interactive-widget=resizes-content` to an existing viewport meta only if no `interactive-widget=` value is already present; it preserves all current meta content.

### Evidence

Pre-change: 674287 bytes; MD5 `7129d0e48a4ad8d261336ded80278642`; SHA-256 `1f1bb8c45b5d717ac7b6c51c8b167f34005d01d0a06e67fcf57499a4ae002a2d`.

Backup `/home/hd2admin/hd2stack-anythingllm/branding/anythingllm-chat-widget.min.js.bak-focusfix-20261005`: 674287 bytes; SHA-256 `1f1bb8c45b5d717ac7b6c51c8b167f34005d01d0a06e67fcf57499a4ae002a2d`.

Post-change: 677858 bytes; MD5 `1dbcfea8ac5d49225bd5a9a9eaa0112a`; SHA-256 `1b87875d0a74a0966738d1d02a1cb5425893e1bd8246cdc1d98f72dd329daffe`. Both local HTTP and public HTTPS served 677858 bytes with the same MD5. `node --check` passed. Markers: widgetfix 4, consentfix 2, hdsizingfix 2, focusfix 2. `docker inspect` reports RestartCount 0, StartedAt unchanged at `2026-10-04T22:47:24.582825856Z`; no restart was performed.

### Captain's mobile test steps

1. On iPhone Safari (including a 320px-wide viewport), open the chat, tap the message input, and confirm the panel shrinks to the visible viewport and the composer/send button remains above the keyboard and home-indicator area. Scroll the visual viewport while the keyboard is open and confirm the composer tracks it.
2. Repeat on Android Chrome with the keyboard open; confirm the send button remains visible and tappable through viewport resize and scroll.
3. Dismiss the keyboard and confirm the prior page scroll position returns and the normal chat sizing resumes.

The full IIFE and verification details are in `focusfix-20261005.md` at both task report and captain-copy paths. This shared widget change does not touch Core-Distro separately, container internals, database, API, config, or image.

VERDICT: PASS
