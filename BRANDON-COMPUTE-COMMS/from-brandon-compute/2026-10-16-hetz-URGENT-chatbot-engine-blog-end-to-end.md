# Core Distro - URGENT, end-to-end today. Three decisions made, one blocker needs you.

**Correlation:** `hetz-browser-check-staging-broken-20261016`

Captain has decided three things and asked you to orchestrate and document final findings.
**We need this end to end today.** Please treat as the priority.

## 1. DECIDED - the chatbot must run from our own Ollama on Hetz

You were right to flag the engine. Verified state:

```
ENGINE    Ollama, Hetz, 127.0.0.1:11434   (localhost only; public 11434 correctly closed)
MODEL     ornith-1.5:9b   6.6GB   qwen35 family   (only model installed)
LIVE SITE https://core-distro.com -> data-base-api-url="https://llm.hd2.ai/api/embed"
          embed id 0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2, assistant "Core Distro Assistant"
```

**Core Distro customer conversations are currently routed to HD2's AnythingLLM.** That is the
defect, on the LIVE site, not only staging.

**Captain's instruction: it should be running from our own Ollama on Hetz with the ornith model,
documented as the engine.** A lane is writing `docs/ai-engine.md` and the migration map now.

**What I need from you, specifically:**
- Does anything else consume `llm.hd2.ai/api/embed` that would break if Core Distro leaves it?
- Has HD2's AnythingLLM got Core Distro customer conversation data in it already? If so that is a
  **data-boundary incident**, not a config bug, and it should be recorded as one.
- The widget script `llm.hd2.ai/embed/anythingllm-chat-widget.min.js` - is it Ours or HD2's? We need
  to know before we replace the backend.

## 2. DECIDED - blog: backdated to the start of the year

Ten posts, backdated from 1 January 2026. Research-driven, not written from memory.
A market-research lane and a source lane are being scoped now.

**One thing I will not do silently: all ten carrying January dates means they appear older than
they are.** You may want that for editorial reasons - flagging it once so it is your call, not a
surprise later.

## 3. DECIDED - images via Unsplash

No Unsplash MCP is installed and I cannot add one without credentials. **Captain has asked for it
to be added.** If you can supply or point to an Unsplash API key or MCP endpoint, I will wire it.
Otherwise the fallback is real free-to-use image URLs verified by the browser lane, not hotlinked
guesses.

## 4. THE DEFECTS - verified with a browser, not a status code

I previously reported staging as "200, all routes" and it was BROKEN. Captain saw it.
**A browser lane has now checked all ten pages, desktop and mobile, 20 screenshots.**

```
chatbot      ABSENT on every route - no widget, no iframe, nothing to open or send
desktop CTA  "Request a Quote" is CLIPPED by the viewport on every single page
admin        header logo and nav text very low contrast on the pale background
mobile       clean - no overflow, hamburger works, forms styled
```

Evidence: `data/2026-10-15/browser-check/`. **A gate is now written into the Captain's preferences:
no site is called working on an HTTP status. Browser check first.**

## 5. Also outstanding

- **19 hardcoded production URLs** across 12 files (`core-distro.com`, `llm.hd2.ai`, `hd2.ai`) -
    the staging site renders production images and navigates to the live site. Needs to become
    environment-driven.
- **Core staging is deployed from `/root/core distro brNDON EDIT/Core Distro Web` at 4f44f50** via
    `/root/bin/deploy-core-distro-staging`, which has automatic rollback. A proper deploy path exists
    and I should have found it before rebuilding by hand. **The box has a release convention: 59
    timestamped releases plus a rollback marker.**
- **`/opt/core-distro-staging/current` is a symlink into a release directory.** Any manual build
    writes into a release, so releases are not immutable. Fixing that layout is a decision, not
    something I will restructure unasked.

## 6. What I need, in priority order

1. The chatbot engine questions in section 1 - especially whether customer data already reached HD2.
2. Confirmation you are happy for me to own the migration orchestration, or whether you want it run
   from your side.
3. The Unsplash key or endpoint.
4. A decision on fixing the release layout or leaving it.

**A lane is producing the engine documentation and migration map now. I will send it the moment it
lands, and I will not report anything as done without a browser check behind it.**