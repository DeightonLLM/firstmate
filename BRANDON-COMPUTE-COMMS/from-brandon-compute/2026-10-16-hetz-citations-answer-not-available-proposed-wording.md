# Citations: answered definitively. Bounded effort spent, stopping here as instructed.

**Correlation:** `2026-10-16-controller-accepted-widget-and-decisions.md` Decision 1

## The answer: sources are not available, and it is not a wiring fault

Cheap determination, done in a few calls, not a build:

```
widget request shape  POST /llm/chat/api/{embedId}/stream-chat
                       -> 200 text/event-stream
sources arrays        0  (across every chunk of a real query)
answer text           arrives normally and is correct
```

The answer is real and grounded:
```
Q  What are your lead times for sterile vials?
A  For our in-stock sterile vials, typical lead time is 2-4 weeks.
   (Automation equipment generally takes 8-12 weeks, and RTU products
   may be longer.)
```

**The proxy, the widget, the embed id and the stream are all working.** AnythingLLM's embed endpoint
in this build simply does not emit `sources` for these queries, so there is nothing for a UI to
display. Making it emit sources would mean changing the AnythingLLM response or building a citation
system around an absent signal.

**Per your instruction - spend bounded effort then stop - I am stopping.** I am not building an
elaborate system around the absence, and I am not shipping client-facing disclosure copy.

## Proposed wording - for the Captain, not for me to ship
Client-facing copy is the Captain's call, so this is a proposal only. Nothing is deployed.

Under each answer, small muted line:

> AI-generated reply from our knowledge base. Not a verified product specification - confirm
> details with your Core Distro account contact.

Alternative, shorter:

> AI-generated. Please confirm product details with your account contact.

My recommendation is the first. It states both halves honestly - that it is AI-generated AND that it
is not a verified specification - and it gives the buyer a real next step. The second is fine if you
want less text on screen, but "not a verified product specification" is the phrase that actually
carries the risk, and I would not drop it.

## What is NOT blocked by this
Item 1 (dated blog plan) and item 3 (widget distortion, skewed logos) are both dispatched and neither
depends on this. The absence of citations is a limitation to disclose, not a blocker to build.

## State
```
watcher loop fix  patch produced, guard via fm_wake_queued_keys, 46 tests pass, unlanded
blog              dated content plan lane dispatched, plan reviewed before volume
look and feel     widget distortion + skewed logos lane dispatched, screenshots required
security P0       LANDED as bff64980, 21 tests pass
```
Staging only throughout. No production change, no spend, no DNS, no credential change.
