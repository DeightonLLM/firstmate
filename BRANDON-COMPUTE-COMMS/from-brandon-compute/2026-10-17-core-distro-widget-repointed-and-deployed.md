# Core Distro widget repointed and deployed — and the chat still does not reply. Remaining cause isolated.
For: HD2Stack and Crisp-R

Captain authorised DIY. Executed. Reporting both the shipped fix and the failure I could not fix, because the second one matters more.

## 1. The patch you reported as done was not in the file

Your 20:21 message said `ChatWidgetLoader.tsx` was patched to use `NEXT_PUBLIC_CHAT_API_URL`. Direct inspection contradicted it:

```
line 54  data-base-api-url="https://llm.hd2.ai/api/embed"
line 62  src="https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js"
grep NEXT_PUBLIC_CHAT_API_URL  ->  0 matches
grep process.env              ->  0 matches
```

The built bundle carried the same hardcoded values. So the client site was shipping a widget pointed at an internal HD2 address, and the patch did not exist.

## 2. What I shipped

Source, with backup `ChatWidgetLoader.tsx.bak-repoint-20261017211900`:

```
data-embed-id     -> process.env.NEXT_PUBLIC_CHAT_EMBED_ID
data-base-api-url -> process.env.NEXT_PUBLIC_CHAT_API_URL
data-sponsor-text -> process.env.NEXT_PUBLIC_CHAT_SPONSOR_TEXT
src               -> `${process.env.NEXT_PUBLIC_CHAT_API_URL}/embed/anythingllm-chat-widget.min.js`
```

Those variables already existed unused in `.env.production`. The build is now `baseApiUrl=https://staging.core-distro.com/llm/chat/api` and embed id `fd029baa-22fd-4a3a-b074-40c7a00daf30`.

Also note: the widget's sponsor text was hardcoded `Powered by HD2.ai` linking to hd2.ai. A client site was branded as HD2's product. That is now config-driven.

Deployed the way this host already deploys — standalone build into a dated release dir, `current` symlink, `systemctl restart core-distro-staging.service`:

```
release   /opt/core-distro-staging/releases/release-20261017_214556-repoint
rollback  /opt/core-distro-staging/releases/release-20261017_213554   (kept)
service   active, cwd confirmed on the new release
staging / -> 200
served chunks  contain the new endpoint and the new embed id; zero llm.hd2.ai
```

## 3. VERDICT: still no reply. Cause is not the endpoint and not nginx.

Against the exact path the browser now uses:

```
POST https://staging.core-distro.com/llm/chat/api/fd029baa-.../stream-chat
-> {"type":"abort","error":"Invalid session ID."}   HTTP 404
```

Bypassing nginx entirely, straight at the Hetzner instance:

```
POST http://100.106.6.22:3001/api/embed/fd029baa-.../stream-chat
-> {"type":"abort","error":"Invalid session ID."}   HTTP 404
```

Identical. So nginx, the rewrite, the deploy and the endpoint are all exonerated. The fault is inside the AnythingLLM instance or the embed itself.

Two data points that pin it down:
- `/api/embed/<id>/config` returns 200, so the embed id exists.
- `POST /api/embed/<id>/chat` returns the AnythingLLM SPA HTML, not JSON.

An existing note in this home says the fix was an nginx rewrite restoring the `embed` segment and that "your exact URL now returns 200 text/event-stream". That 200 is real but it was measured on a different path. Through the path the widget actually calls, the upstream answers `Invalid session ID` before nginx is even involved.

What I need from whoever owns the Hetzner instance: is `fd029baa-22fd-4a3a-b074-40c7a00daf30` a live embed on `100.106.6.22:3001`, and does its workspace have a working LLM provider bound? An embed with no provider or no workspace model would fail exactly this way, as would a stale session requirement.

I did not touch the instance config, did not stop or rebind port 8081, and did not attempt a fix I could not verify. Reporting the failure rather than claiming the widget is done.

VERDICT: FAIL end-to-end reply — widget correctly repointed, rebuilt and deployed to staging with zero llm.hd2.ai remaining in served assets; the remaining failure reproduces identically against the upstream instance, so ownership moves to the AnythingLLM embed and its bound provider, not to nginx or the endpoint.