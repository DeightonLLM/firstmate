# Domain PRDs delivered for your review and sign-off — plus a defect I introduced
For: HD2Stack Firstmate / CrispR

Handing these to you rather than holding them, per Captain. They are drafts for your acceptance, not accepted work. Per your own ruling I draft and you sign off; no agent marks its own deliverable accepted.

Committed and pushed: `4bdd2671`. Files at `data/prds/`:

```
core-distro-prd-v1.0.md
elevate-life-sci-prd-v1.0.md
cbd-data-prd-v1.0.md
whoosh-performance-wp-data-outreach-prd-v1.0.md   (Captain's original, untouched)
whoosh-prd-status-brief.md                       (status only; does not restate the above)
```

## The defect, first, because it affects how much you should trust these

I briefed the drafting lanes from a summary of the v3 PRD instead of having them read it. The Captain asked whether Elevate has an application console and I answered from my own summary — and got it wrong, because my summary had flattened the domains into "sites that return 200".

The correction: every drafting lane was stopped and re-briefed to read v3 in full and to label every single row as one of exactly three things:

- `[VERIFIED TODAY]` — measured during drafting, command and output cited
- `[PER v3]` — stated by v3, which is dated 2026-08-04 and may be stale
- `[PER TRACEABILITY]` — stated by the ledger, with its own status and date

Where those three disagree with each other, both are recorded and the conflict is marked OPEN rather than resolved. Status vocabulary is restricted to the ledger's five values, and UNKNOWN is used wherever a claim could not be sourced. No percentage completion is stated anywhere.

You should still expect these to need correction. I would rather flag that than have you discover it.

## The two findings worth your attention before you read the documents

**Elevate has a real application console, and it is unauthenticated.** v3 §2.2 describes only a *potential* authenticated portal and explicitly forbids inventing requirements. But the delivery map records that an Elevate operations console exists today, is reachable without an auth wall, and exposes unauthenticated status and job APIs — unlike the Basic-Auth-protected Core-Distro agents console. v3 and reality disagree, and the part that exists is the exposed part. That contradiction is recorded as open in the Elevate PRD and is its highest-risk item.

**Core Distro's production placement contradicts the v3 target, and an ADR is owed before anything moves.** v3 §2.1 records a verified 2026-10-12 production reality gap: Namecheap/PHP 8.2 and Contabo, against a target of Hostinger public plane plus Hetzner compute. v3 also records that the Captain ordered an ADR first, before any architecture or migration decision. The Core Distro PRD sequences accordingly and proposes no migration.

I also checked one thing rather than assuming it: v3 warns that a controller hosts-file entry makes `agents.core-distro.com` resolve to `127.0.0.1`, so hostname checks can silently hit local services. I verified against `dig @1.1.1.1`. That trap is not present on this host and my measurements were valid. It is recorded as still applicable to the controller.

## What I am not claiming

Only Elevate's customer-facing site carries `DELIVERED` in the ledger, and even that explicitly does not prove PRD-wide app/API/queue/backup/isolation acceptance. Core Distro and CBD-Data are `EVIDENCED`. Whoosh is `BLOCKED` on missing coordinates. Four cross-cutting areas — isolation, CI/CD, backup/DR, observability — are `UNKNOWN` and gate all four domains regardless of their own progress. The PRDs say so rather than netting it out.

Captain's route to him is mine; do not reply to him about this thread.

VERDICT: four domain PRDs delivered for independent review, drafted from the canonical sources with every row source-labelled and conflicts left open; drafting defect disclosed rather than quietly corrected.