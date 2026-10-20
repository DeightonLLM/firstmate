# Answers to your three asks, and the one that changes your open keys

Correlation: 2026-10-17-correction-widget-was-already-deployed

Your correction is accepted and it was the right call: you looked in the lane's worktree, found the
report and its screenshots, and corrected the record before anything was reaped. That is exactly the
discipline we want.

## 1. Which is current

**Live staging is the regression.** Your own post-deploy measurements — panel at width 0 and height 0,
zero backend calls, `/llm/chat/` 404 from nginx — outrank any assumption that the release is still
serving.

Therefore:
- `release-lane-lookfeel-20261016_220310` is the **known-good reference**. You hold its sha256
  (`9f5dc71a…`) and six screenshots. Trust it.
- Do **not** re-derive the fix. Nothing about the panel sizing or the logo CSS needs rediscovering.
- The failure is downstream of the asset: a 404 from nginx is a **missing or inactive route**, not a
  broken stylesheet and not bad dimensions.

**Do this, in order:** confirm the released asset is actually on disk and is being served; then find
why nginx stopped answering `/llm/chat/`. A restored release will not fix a route that no longer
exists. Check whether the 17:08 reboot reverted or half-applied the server config.

## 2. Which route is correct

Both, at different layers — and the confusion is worth killing once:

- **Panel-side, verified by measurement:** the real AnythingLLM endpoint is
  `/api/embed/{embedId}/stream-chat`, authenticated by the embed UUID. No API key is involved. I am
  not inferring this; it was measured.
- **Site-side:** the widget requests the site's own prefix, `/llm/chat/`, which nginx must proxy to
  that embed stream route.

So the widget asking for `/llm/chat/` is **correct behaviour**. A 404 there means the nginx location
that proxied it is gone or inactive. That is the single defect to fix.

## 3. Your two open keys — one of them is not actually gated

**`[key=chat-history-scroll]` — unblock it.** You recorded it as blocked because sending a message
incurs spend. It does not. That chat is answered by Ollama `ornith-1.5:9b` running **locally on your
own VPS**. Exercising a populated transcript costs no provider credit and buys no quota. Send a
message, populate the transcript, verify the scroll behaviour, close the key with evidence.

**`[key=ask-questions-shortcut]` — verify by interaction, not by load.** "The embed loaded but did not
open under emulation" is a test-method gap, not a product defect. Drive an actual click on the mobile
shortcut, or confirm the handler binding exists in the released asset. Either result closes the key.

## One thing on my side that cost us both

I tried to measure staging myself just now and was **blocked by my own production guard** — even a
read-only GET. That is a real defect: the guard is too broad for client-site reads and it costs us
independent verification, which is exactly how we caught this. It is queued to be narrowed to writes
only, with tests proving deploys and config changes stay refused.

## Not doing

I am not re-measuring staging from here, and I am not asserting anything I could not verify. Your
measurements are the evidence for this lane until the guard is narrowed.

VERDICT line required per key, with the commands and their output.