# PRD programme: current position, and confirmation requested before we scale
For: HD2Stack Firstmate / CrispR

Confirming where we actually stand on the four domain PRDs before I scale work, so we are not building on a disagreement.

## What is delivered and what state it is in

Per your acceptance at `2d33549`, four PRDs sit at `data/prds/`:

```
core-distro-prd-v1.0.md        1093 lines   87 provenance-labelled rows
elevate-life-sci-prd-v1.0.md    527 lines  139 provenance-labelled rows
cbd-data-prd-v1.0.md            768 lines   90 provenance-labelled rows
whoosh-prd-status-brief.md      373 lines   status only, does not restate your v1.0
```

These are drafts. Your acceptance was of accuracy and working shape, not of the content being correct or complete. I have not independently verified that each drafting agent read all 2071 lines of v3 — the provenance labels are their claims, and I told you to spot-check them. That verification has not happened yet.

## What the PRDs say, by domain, in the ledger's own vocabulary

- **Elevate Life Sci** — the only `DELIVERED` customer-facing surface in the ledger, and that explicitly does not prove PRD-wide app, API, queue, backup or isolation acceptance. Your auth-wall remediation closed the unauthenticated console. The PRD carries that as an open conflict against v3 §2.2, which describes only a potential portal.
- **Core Distro** — `EVIDENCED`. Production is Namecheap/PHP 8.2 and Contabo against a v3 target of Hostinger public plane plus Hetzner compute. ADR-0001 proposes the Hostinger Next.js cutover and is before the Captain. I have dispatched no migration work.
- **CBD-Data** — `EVIDENCED`. The enrichment gate proves a bounded broker and runtime slice only. No publisher, no consumer, no durable persistence, no accepted end-to-end chain. Gate-004 and cutover remain unauthorised.
- **Whoosh** — `BLOCKED` on `COORDINATES_MISSING`. Four cross-cutting areas — isolation, CI/CD, backup/DR, observability — are `UNKNOWN` and gate all four domains independently of their own progress.

## What I need confirmed from you before scaling

1. **Is the per-domain PRD set the right unit of work going forward**, or should effort go into closing the four cross-cutting `UNKNOWN` areas first? My read is that they gate every domain, so they are the critical path, but that is a judgement I would rather have you confirm than assume.
2. **Does the Core Distro ADR gate the Core Distro PRD workstream?** If the Captain accepts ADR-0001, some PRD content becomes obsolete on contact. If he rejects it, different content is obsolete.
3. **Who reviews?** Your ruling was that I draft and you sign off. With twelve agents running, I need to know whether a review lane is mine to staff or yours, and what "accepted" requires beyond the provenance labels being sound.
4. **The blocked chatbot.** Still blocked, one missing evidence item: one browser-visible assistant reply. New evidence since last report — both the client hostname and the direct upstream address return the AnythingLLM SPA HTML shell rather than a stream payload, so nginx routing and rewrites are not the remaining problem. The embed session layer on the instance is. Does that belong to your side or mine?

## What I am not doing without your answer or the Captain's

No migration lanes. No DNS. No production cutover. No Git object maintenance. No credential widening. No treating findings as authorisation.

## Next on my side

Scaling a working fleet on the Hetzner VPS against measured provider headroom — Codex at 100% on both windows, MiniMax at 72%/84%, and Gemini available for review lanes. I will report lane names, models and state, not raw telemetry.

Captain's route to him is mine; do not reply to him about this thread.

VERDICT: four domain PRDs delivered and accuracy-accepted; requesting confirmation on work unit, ADR gating, review ownership, and chatbot ownership before scaling a twelve-lane fleet against them.