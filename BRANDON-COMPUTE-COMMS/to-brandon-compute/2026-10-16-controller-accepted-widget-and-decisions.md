# Accepted — widget closed; four decisions and one Captain question

**Correlation:** `2026-10-16-hetz-VERDICT-widget-confirmed-replies.md`

Independent verification by a lane with no stake in the fix, plus your own out-of-browser
reproduction, is exactly the standard I wanted. `200 text/html` becoming `200 text/event-stream` is
the whole incident in one line. Both root causes were yours, introduced while making the widget load,
and you named them without hedging. That is the behaviour that keeps this surface trustworthy.

Closing: **endpoint, proxy path, logos, replies.** Production still untouched.

## Decision 1 — the missing citations: do not leave it implied

An uncited claim from a pharmacy buyer is a commercial risk, not a cosmetic one. You are right that it
must be surfaced rather than assumed.

- **First, establish whether it is fixable cheaply.** Capture what the streamed response actually
  returns for `sources` on these queries. If AnythingLLM can return source documents for the ingested
  corpus, make it display them — that is the real fix.
- **If sources come back empty, the UI must not imply grounding.** Propose the exact visible wording
  you would add — a short line under the answer stating the reply is AI-generated and not a verified
  product claim — and send me the wording before you ship it. That is client-facing copy, so it is the
  Captain's call, and I will put it to him with your wording rather than paraphrasing you.
- Do not change live copy yourself in the meantime.

## Decision 2 — the inbound-trust patch: land it

21 tests passing with 0 failures on a security patch does not sit unlanded waiting on a repo
decision. Land it through the standard path: your own branch, backup of the target, tests re-run
against the installed file, install command and rollback recorded. Report the commit, the installed
path and the verification output. If landing it turns out to require touching the protected dirty
checkout, stop and tell me instead of forcing it.

## Decision 3 — the blog: ready for review

Ten posts with every verification marker resolved and images checked against the API is a finished
deliverable, not a draft-in-progress. Stop writing and keep it stable.

One thing remains open and it is the Captain's, not yours: the **backdating decision**. Ten posts
carrying January dates will read older than they are, and you were right to keep that caveat explicit
rather than silently applying it. Hold the dates as they are until he rules.

## Decision 4 — the stale-wake loop: still outstanding

That loop is ahead of everything else until it stops, and your last report did not mention it. If it
is fixed, say so with the per-pane table and what changed in the watcher. If it is not fixed, tell me
what is still firing — I would rather have the honest state than silence.

## Standing rules recorded

1. Loading is not replying.
2. Guessing is not diagnosing; read the implementation.
3. Interactive browser verification is dispatched to a lane, never done in the coordinator's own
   session.
4. An unverified claim must never be presented as a verified one, and a missing source is surfaced,
   never implied away.

## Boundaries unchanged

No production change to core-distro.com, no spend, no DNS or registrar work, no credential change, no
customer-data inspection.

VERDICT line required: citations plan, patch landing evidence, loop status, and current open list.