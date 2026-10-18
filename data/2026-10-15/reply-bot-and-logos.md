# Core Distro staging: bot break point located, logos fixed

**Correlation:** `2026-10-16-controller-URGENT-bot-silent-and-missing-logos.md`

## 1. Which of the four failure points the bot breaks at

**Point 4, and point 3 is a real defect underneath it. Points 1 and 2 are healthy.**

### Point 1 - proxy path live: YES

```
https://staging.core-distro.com/llm/chat/embed/anythingllm-chat-widget.min.js  200
location ^~ /llm/chat/ { proxy_pass http://100.106.6.22:3001/; }
nginx -t successful, reloaded, not restarted
```

Browser, verified not asserted - clicking "ASK QUESTIONS" loads:

```
src    https://staging.core-distro.com/llm/chat/embed/anythingllm-chat-widget.min.js
embed  fd029baa-22fd-4a3a-b074-40c7a00daf30
mixed-content console errors: 0
```

The old blocked `http://100.106.6.22:3001` script is gone.

### Point 2 - request reaches AnythingLLM: YES

```
POST /llm/chat/api/embed   200
```

It reaches the service. **But the response body is not a chat response.** It is the AnythingLLM
SPA HTML:

```
<!DOCTYPE html> ... <title>AnythingLLM | Your personal LLM trained on anything</title>
```

That HTML is what a 200 SPA catch-all returns for **any unmatched path**. I proved this is not a
proxy artefact by reproducing it with **no proxy in the path at all**, calling localhost directly:

```
curl http://127.0.0.1:3001/api/embed                 -> same SPA HTML
curl http://127.0.0.1:3001/api/embed/chat            -> same SPA HTML
curl http://127.0.0.1:3001/embed/api/chat            -> same SPA HTML
```

So the widget is posting to a path this AnythingLLM build does not serve. That is the actual break.

**Real error evidence, not a summary.** The one route that is genuinely the embed chat API answers
auth-first, which proves the API exists and is version-gated:

```
POST /api/v1/embed/chat  ->  403 {"error":"No valid api key found."}
```

The widget cannot present an API key. It authenticates by embed uuid on the `/api/embed/*` routes,
which is exactly the family returning HTML.

**This is the contract mismatch I should have found before I first told you the repoint was done.**
I verified the widget *loaded* and reported that as the fix. Loading is not replying.

### Point 3 - workspace answering: NO, and this is the deeper defect

```
Core-Distro   documents=0   threads=0
Elevate       documents=0   threads=0
```

**Our AnythingLLM has zero documents in both workspaces.** You asked me to say this plainly, so:
**the knowledge base is empty.** Even with a corrected endpoint, the bot has nothing to answer from.
It would answer from the raw model with no Core Distro knowledge.

Our instance previously had only an Elevate embed. Core-Distro's embed was created today. Neither
workspace was ever populated.

### Point 4 - model backend up: YES

```
ollama 127.0.0.1:11434  ->  models: ['ornith-1.5:9b']
```

Ornith is loaded and reachable. **The backend is not the problem.** Good to state plainly because it
rules out the layer you might have suspected.

## 2. Logo table

**Root cause: the logo files were never in the repository.** `public/` contained only `ai.txt`,
`images/`, `llms.txt`, `llms-full.txt`. No logo asset existed in source or in the build output.
These were absolute URLs to production, which is why they masked the gap.

```
core-distro-mark-green.png  -> https://core-distro.com/core-distro-mark-green.png  -> 404 staging
core-distro-logo-white.webp -> https://core-distro.com/core-distro-logo-white...   -> 404 staging
```

Not a staging-origin regression, and **not** an incomplete replacement of the 19 hardcoded URLs. The
replacement was complete; the files it pointed at were absent from this repo.

**Fixed** by retrieving the assets from production - they are Core Distro's own marks, not stock -
and placing them in source `public/`, then redeploying:

```
release-20261016_191709
mark      -> 200  (724,343 b, copied from production, byte-identical)
wordmark  -> 200  (146,940 b, copied from production, byte-identical)
```

Copies retained at `data/core-staging-logos/`. Source and build both updated, so this survives the
next deploy.

## 3. What I changed, and re-verification

```
nginx    added ^~ /llm/chat/ proxy to 100.106.6.22:3001, proxy_redirect off. reload only.
source   NEXT_PUBLIC_CHAT_API_URL=https://staging.core-distro.com/llm/chat
logos    copied into source public/, redeployed
backup   vhost .bak-llmproxy-*, ChatWidgetLoader.tsx .bak-20261016170957
```

Releases this session: `171018`, `171809`, `191709`, `192154`. All staging. Production untouched.

**Re-verification is partial and I will not overstate it.** Widget load, proxy reachability and both
logos are browser- and curl-verified. **A real question sent through the widget and a real answer
received is NOT verified**, because the endpoint above does not serve chat. One console
`SyntaxError: Unexpected token '<'` remains, which is consistent with an HTML body reaching code
expecting JSON - i.e. the same defect, not a separate one.

## What I need from you

1. **The exact embed-chat route for AnythingLLM 1.16.2.** I have exhausted the documented `/api/embed*`
   family empirically. I will not guess further. If you or the Captain want it fast, the container
   has the route table and it is one command to read.
2. **Content for the empty workspace**, or an explicit decision that the bot runs ungrounded. Loading
   Core Distro material is a content decision, not a config one.
3. **A deliberate answer on the 17:08 reboot.** Still unexplained. I did not restart it and cannot
   prove nobody else did.

## What I will not do without a decision

```
no customer-data inspection
no API key embedded in the widget or shipped to browsers
no change to core-distro.com
no spend, DNS, registrar, or credential change
no second reboot while unexplained - I will stop and report first
```

VERDICT: logos FIXED and verified. Bot endpoint UNRESOLVED - proven to be an AnythingLLM 1.16.2
embed-chat route mismatch plus an empty workspace, both still open. Widget load is confirmed; a real
reply is not.
