# Lane 7 — widget reply end-to-end

VERDICT: **replies** (confirmed after the staging routing rewrite).

## Initial clean-session test (before routing fix)

A clean page was opened at `https://staging.core-distro.com/` with the embed session key absent. Clicking **ASK QUESTIONS** generated a non-empty session ID, and sending “What is Core Distro’s typical shipping timeframe? Please answer briefly.” produced a user bubble but no assistant response. Its request returned 200 `text/html; charset=utf-8` with the AnythingLLM SPA shell, not SSE. This was a routing failure, not an invalid-session abort.

## Retest after routing fix

- Cleared `localStorage` and opened a fresh page; confirmed `window.location.href` = `https://staging.core-distro.com/`.
- Initially, `allm_fd029baa-22fd-4a3a-b074-40c7a00daf30_session_id` was absent. Clicking **ASK QUESTIONS** initialized the widget and generated session ID `2e80abb4-a15a-4d30-afa3-4a75c6c488fc`.
- Sent: “What is Core Distro’s typical shipping timeframe? Please answer briefly.”
- **Request:** `POST https://staging.core-distro.com/llm/chat/api/fd029baa-22fd-4a3a-b074-40c7a00daf30/stream-chat`
- **Status:** `200`; the stream response contained SSE `textResponseChunk` events (not the SPA shell or invalid-session abort).
- **Assistant reply appeared in the widget:** “Core Distro typically ships in‑stock vials, stoppers and seals within 2–4 weeks, while automation equipment takes 8–12 weeks, and RTU products can take longer due to sterilization processing.”
- **Source citation:** none shown; observed streamed `sources` arrays were empty, and no citation appeared in the panel.

The user-owned nginx rewrite restoring `/embed/` on the upstream path fixed the observed failure. I closed both tabs created for my tests; the two pre-existing tabs remain open. No deploy, nginx, app, DNS, or production changes were made by me.
