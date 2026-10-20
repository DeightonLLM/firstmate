# Lane 7 — widget reply end-to-end

VERDICT: **does not reply** (in the clean-session test).

## Reproduction

1. Cleared `localStorage` on the selected staging page. A new page was opened; `window.location.href` verified as `https://staging.core-distro.com/`.
2. The embed session key was initially absent: `allm_fd029baa-22fd-4a3a-b074-40c7a00daf30_session_id` = `null`.
3. Clicked **ASK QUESTIONS**. The widget initialized and wrote session ID `47a6e5a0-f5ba-4ee5-8e58-96df2bc74043` to that key.
4. Sent: “What is Core Distro’s typical shipping timeframe? Please answer briefly.” The user turn appeared; after 30 seconds no assistant response or visible error appeared.

## Exact widget request and response

- **Request:** `POST https://staging.core-distro.com/llm/chat/api/fd029baa-22fd-4a3a-b074-40c7a00daf30/stream-chat`
- **Status:** `200`
- **Request body:** `{"message":"What is Core Distro’s typical shipping timeframe? Please answer briefly.","sessionId":"47a6e5a0-f5ba-4ee5-8e58-96df2bc74043","username":null,"prompt":null,"model":null,"temperature":null}`
- **Response content-type:** `text/html; charset=utf-8` (not `text/event-stream`).
- **Response body:** HTML AnythingLLM app shell (`<!DOCTYPE html>…<title>AnythingLLM | Your personal LLM trained on anything</title>…`), not SSE, assistant text, or the cited `Invalid session ID` abort.

The chat panel contained only the user question and controls; no assistant message appeared. **No source citation was displayed** because there was no assistant response.

## Finding / smallest fix

The leading invalid-session-ID theory is **not supported** by this run: the widget generated and sent a non-empty session ID, and the observed response was an HTML app shell, not the invalid-session abort. The response indicates the widget's stream-chat request is reaching a route/fallback that serves the AnythingLLM UI instead of the chat API. Smallest likely fix: correct the staging proxy/routing for the exact widget URL so it reaches the embed stream-chat API and returns its SSE response (`text/event-stream`); confirm the intended upstream path before changing routing. No routing or other service changes were made in this test.

No deploy, nginx, app, DNS, or production changes were made.
