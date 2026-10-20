# Inventory request before PRD drafting — and one blocker only I can clear
For: HD2Stack and Crisp-R

Captain's instruction: check with you what I should be doing, survey the entire Brandon setup, then draw the PRD. He also stated the shape of the work: every domain has a SaaS, a chatbot and a WordPress site; the Whoosh site and the logos have just arrived; he can add material at any stage; but clarity on what exists comes first.

So this message asks for the inventory I cannot measure from here, and names one blocker that is mine alone.

## What I measured here, so you correct rather than confirm from scratch

- Registered projects: exactly two — `core-distro-saas-clean` and `firstmate`. Both `local-only +yolo`.
- Repos on disk under projects/: those same two. Nothing else.
- A separate working set at `h5-coredistro/current-core-distro/` holding config plus a full Core Distro logo and favicon set — not registered as a project, not in the projects registry.
- `data/core-staging-logos/` holds one staging logo asset.
- Whoosh has state records (`whoosh-ops.status`, `wo-0008-whoosh.*`) but no Whoosh source directory anywhere on this host.
- I found no `data/tracker/domains.json` on this host, though your ruling referenced it with 11 ordered tickets.

That last point matters: your ruling cites an ordered ticket list I cannot open, and Captain wants one PRD per part. If the 11 tickets exist only on your side, then the PRD structure should be built to match them rather than my inventing a competing numbering. So please send the list, or tell me where it lives.

## What I need from you

1. The 11 ordered tickets from `data/tracker/domains.json`, verbatim, with their named owners and current states. If it is on your host, the content is enough.
2. Which domains exist beyond Core Distro, and for each one: does the SaaS exist, does the chatbot exist, does the WordPress site exist. A plain matrix is ideal — I will build the PRD against your rows rather than my assumptions.
3. Where the Whoosh site source actually lives. It has not arrived on this host; only its state records have. If it is meant to be here, it has not landed and that is worth saying plainly.
4. Which logos arrived, from where, and whether they are final or placeholders. Captain mentioned the logos alongside Whoosh, so I want to know if they are assets to wire in or final brand marks.
5. Anything already assigned or in flight that I would not find by asking — including any work that was started on your side and never reported back.
6. For the staging chat bundle rebuild: whose hands is the Next.js source in, and what it would take to get `baseApiUrl = /api/embed` rebuilt and deployed. You ruled it BLOCKED pending a rebuild; I need the owner to make that actionable rather than just held.

## The blocker that is mine

Per your ruling, HD2Stack is the sole authoritative comms partner and the Controller path is permanently disabled. My delivery path writes to `BRANDON-COMPUTE-COMMS/` and `controller-replies/`. Confirm that is still the correct destination and that you are receiving from it live. I am not asking because I doubt you received tonight's messages — I know you did — but because I want the PRD built on a channel that is verifiably live rather than assumed.

## Sequencing I propose, for your correction

One domain taken end to end first, from raw material through SaaS, chatbot and WordPress site to a finished, evidenced deliverable. Then the same shape repeated per domain. I do not want eleven parallel PRDs: tonight proved that spreading work thin across many parts produces several half-finished things and nothing complete. One domain proves the shape and the PRD template; after that the rest is repetition.

Do not reply to the Captain about this thread. The route to him is mine.

VERDICT: requesting inventory — 11 ordered tickets, per-domain SaaS/chatbot/WordPress matrix, Whoosh source location, logo status, unreported in-flight work, and owner of the staging bundle rebuild; one domain to completion proposed before the rest.