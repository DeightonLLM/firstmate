# Lane 7 - Prove the chat widget replies end to end (Luna 6, medium)

Worktree /tmp/wt-lane-widget, branch lane/widget. Parent holds the fleet lock; you will not acquire
it. Expected. You may read and WRITE under your worktree. No commit. No fm-session-start.

## What is already proven - do not redo it
- widget JS serves correctly: 200 application/javascript, 678KB
- chat API answers via direct call:
    POST https://staging.core-distro.com/llm/chat/api/embed/fd029baa-22fd-4a3a-b074-40c7a00daf30/stream-chat
  returns real SSE text from ornith.
- the widget UI mounts: #anything-llm-chat, #anything-llm-embed-chat-container exist
- a message sent from the widget renders the user bubble with timestamp and
  "Core Distro Assistant" label

## The single open question
**Does an assistant reply ever appear in the widget UI?** That is all. Prove it or disprove it.

## Known gotcha
An EMPTY or invalid session id makes AnythingLLM abort quietly:
    {"type":"abort","error":"Invalid session ID."}
The session id lives at localStorage key
    allm_fd029baa-22fd-4a3a-b074-40c7a00daf30_session_id
A stale session id reproduces the exact symptom: user message appears, no reply, no visible error.
**That is the leading suspect. Confirm or eliminate it.**

## Tool notes
`chrome-devtools-axi navigate` DOES NOT EXIST - it silently no-ops and you will screenshot a stale
page. Use `newpage "<url>"` and confirm with `eval "window.location.href"`.
Shared browser: always start from a clean session - clear localStorage, open a new page.
React inputs need the native value setter plus an input event, or fill/uid clicks.

## Deliverable
data/lane-widget/report.md
  - VERDICT: replies / does not reply
  - the exact request the widget makes: URL, status, response body or abort reason
  - the actual reply text if it replies
  - whether any source citation is displayed to the user
  - root cause and smallest fix if it does not reply

## Rules
No deploy. No nginx changes. No app edits. No DNS. No production. Report honestly - a clean
"does not reply, here is the abort reason" is a good outcome. Never dress a failure up.
