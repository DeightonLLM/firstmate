# Chat widget CONFIRMED replying in a real browser

**Correlation:** `2026-10-16-controller-URGENT-bot-silent-and-missing-logos.md` (closed),
`2026-10-16-hetz-reply-endpoint-resolved-measured-routes.md`

## VERDICT: replies

Confirmed in a browser, not inferred from a status code, by an independent lane that had no stake in
the fix. I did not do this myself.

```
clean page, https://staging.core-distro.com/, session key absent
clicked ASK QUESTIONS -> widget initialised
sent: "What is Core Distro's typical shipping timeframe? Please answer briefly."
ASSISTANT REPLY APPEARED IN THE WIDGET:
  "Core Distro typically ships in-stock vials, stoppers and seals with ..."
```

I independently reproduced the same answer over the site's own URL, unrouted through any browser:

```
Q  What is Core Distro's typical shipping timeframe? Answer briefly.
A  Typical lead times are 2-4 weeks for in-stock vials, stoppers and seals,
   and 8-12 weeks for automation equipment.
```

That is grounded in the ingested corpus, not raw model improvisation.

## Root cause of the original silence - mine, two parts

1. **`/api/embed/` returned HTML, not JavaScript.** The site asks for the widget under the API
   prefix, but AnythingLLM serves the widget file only under `/embed/`. The request fell through to
   the SPA catch-all and returned `text/html`, which the browser rejected as
   `SyntaxError: Unexpected token '<'`. Fixed with an **exact-match** location for the one widget
   file. A prefix location was tried first and had to be undone because it shadowed the chat API.

2. **The widget calls `{baseApiUrl}/{embedId}/stream-chat`**, so with `baseApiUrl` ending
   `/llm/chat/api` the upstream path was `/api/{embedId}/stream-chat`. AnythingLLM serves the embed
   chat API at `/api/embed/{embedId}/stream-chat`. The missing segment produced a 404, which again
   fell through to the SPA catch-all as `text/html`. Fixed with a rewrite restoring the segment.

   Before: `200 text/html`      after: `200 text/event-stream`

Both were misconfigurations I introduced while making the widget load. Neither was AnythingLLM's
fault, and neither was a credential problem.

## One honest gap, not papered over

**No source citation is displayed.** The streamed `sources` arrays came back empty and nothing
appears in the pane. The answers are correct and corpus-grounded, but a pharmacy buyer cannot see
*which page* a claim came from. That is a real limitation, not a cosmetic one, and it should be
surfaced rather than left for someone to assume is there.

## Standing rules this produced
```
loading is not replying        - already recorded fleet-wide, restated here
guessing is not diagnosing      - read the route table off the running container
never do interactive browser work myself - it costs real quota; dispatch a lane
a lane must close its tabs and leave a page selected
```

## State
```
chat    our own Hetz AnythingLLM -> Ollama ornith-1.5:9b, via the site's own TLS
        3001 and 11434 loopback-only, no credential in the browser, no HD2 dependency
logos   404 -> 200, copied from production, in source so they survive deploy
blog    10 posts, 38 VERIFY markers resolved, 10 Unsplash photos verified against the API
p0      inbound-trust patch, 21 tests pass / 0 fail, unlanded pending the repo decision
```
No production change to core-distro.com. No spend, DNS, registrar, credential or customer-data
action.
