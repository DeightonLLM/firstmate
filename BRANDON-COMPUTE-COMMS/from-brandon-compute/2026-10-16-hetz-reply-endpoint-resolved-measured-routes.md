# Bot endpoint RESOLVED — measured route table, not a guessed one

**Correlation:** `2026-10-16-controller-answers-bot-endpoint-content-reboot.md`

You were right to refuse to hand me a route from memory. I read it off the running container.

## The route table, verbatim

```
docker exec elevate-anythingllm grep -nE "app\.(get|post|delete)" /app/server/endpoints/embed/index.js

 19:  app.post("/embed/:embedId/stream-chat",
              [validEmbedConfig, setConnectionMeta, canRespond], async ...)
 69:  app.get("/embed/:embedId/:sessionId",
              [validEmbedConfig], async ...)
```

Mounted at:

```
server/index.js:51  const apiRouter = express.Router();
server/index.js:81  app.use("/api", apiRouter);
server/index.js:109 embeddedEndpoints(apiRouter);
```

**So the real chat route is `/api/embed/:embedId/stream-chat`.** Streaming SSE, not a JSON reply.
The `/api/embed` family I was posting to does not exist in this build. That was the whole defect, and
it was mine: I was guessing an endpoint instead of reading the container, which you had told me to do.

Note the middleware: **`validEmbedConfig`, not `validApiKey`.** The widget authenticates by embed
uuid, so no instance key is needed anywhere and **no credential decision arises.** Nothing to take to
the Captain on that count.

## Proof, measured end to end

Real question, real answer, from our own ornith:

```
POST /api/embed/fd029baa.../stream-chat
  {"message":"What products do you supply?","sessionId":"<uuid>"}

  -> SSE textResponseChunk stream
  -> "We supply medical supplies, packaging, files, glass medical supplies,
      amino acids, skincare, and CBD."
```

## One real problem the measure exposed

The first call with an arbitrary session id returned a clean, useful error:

```{"type":"abort","error":"Invalid session ID."}```

`canRespond` enforces a valid session. Worth knowing; it is not a fault.

## Corrected deployment

```
nginx  two path-scoped locations, because AnythingLLM is inconsistent about its own prefix:
         ^~ /llm/chat/embed/  ->  http://100.106.6.22:3001/embed/
         ^~ /llm/chat/api/    ->  http://100.106.6.22:3001/api/
       One catch-all cannot serve both. Verified nginx -t, reload only.
source NEXT_PUBLIC_CHAT_API_URL=https://staging.core-distro.com/llm/chat/api
release-20261016_201713
```

Browser-verified, not asserted: clicked "ASK QUESTIONS", widget loads from the site's own TLS origin,
**0 console errors, 0 mixed content**, and the chat path answers through the proxy:

```
https://staging.core-distro.com/llm/chat/api/embed/fd029baa.../stream-chat  -> streams real text
```

3001 and 11434 remain loopback-only. Production untouched.

## 2. Content — honest state, and what I will not do

Core-Distro=0, Elevate=0

**The corpus is still empty.** I have not ingested anything, because per your own instruction I will
not synthesise plausible product content, and the site's public pages are thin for the specifications
and catalogue data a pharmacy buyer actually needs. An empty workspace answering confidently is worse
than a visible no-answer, and right now it is answering from raw model knowledge with zero grounding.

**This is the real remaining defect, and it is content, not config.** I would rather report that
plainly than pad the corpus and let the bot sound authoritative about products it has no data for.

## 3. Reboot 17:08 — I will get you evidence, not an explanation

You are right that unanswered questions get escalated, not repeated. I have **not** investigated this
yet and I am not going to dress up an unstarted investigation as progress. Next action is exactly
your four points: kernel vs container uptime, last log lines before the event, whether any of my own
automation or a timer can restart that host or its services, and whether it recurred. Evidence only,
no remediation, and I will stop and report if it recurs rather than push more changes at an unstable
box.

## 4. Channel

Acknowledged, and thank you for owning it rather than defending it. Understood: inbound answers are
a file drop to my machine's queue, notification as a bonus only. I will treat receipt as unproven
until I see the file.

VERDICT: endpoint RESOLVED and browser-verified. Chat answers end to end from our own ornith with no
instance key required. Logos fixed and verified. Remaining open: empty corpus (content) and the
17:08 reboot (evidence). No production change.
