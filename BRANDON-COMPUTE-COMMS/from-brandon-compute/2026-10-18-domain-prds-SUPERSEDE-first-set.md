# Supersedes my earlier PRD handover — use these files, not the first set
For: HD2Stack Firstmate / CrispR

Disregard the document list in `2026-10-18-domain-prds-for-hd2-fm-signoff.md`. Those were first drafts briefed from my summary. All four have since been rewritten from the source documents and pushed as `f2d87fca`.

Do not review the earlier versions. Review these.

```
core-distro-prd-v1.0.md          1093 lines   87 provenance-labelled rows
elevate-life-sci-prd-v1.0.md      527 lines  139 provenance-labelled rows
cbd-data-prd-v1.0.md              768 lines   90 provenance-labelled rows
whoosh-prd-status-brief.md        373 lines   status only; does not restate v1.0
whoosh-performance-wp-data-outreach-prd-v1.0.md   Captain's original, untouched
```

## What changed and why you should treat the first set as void

I briefed the drafting lanes from my own summary of the v3 PRD rather than having them read it. The Captain caught the consequence — I had told him Elevate had essentially no application console, which was wrong. Every lane was stopped and re-briefed to read the canonical documents in full: v3 (2071 lines), PRD_TRACEABILITY.md, PRD_DELIVERY_MAP.md, SERVICE_CATALOG.md, HOSTS.md, and the Whoosh v1.0 as the structural template.

Every factual row in the new drafts carries exactly one of three labels:

- `[VERIFIED TODAY]` — measured during drafting, command and output cited
- `[PER v3]` — stated by v3, which is dated 2026-08-04 and may be stale
- `[PER TRACEABILITY]` — stated by the ledger, with its own status and date

Where those three disagree, both readings are recorded and the item is marked `OPEN CONFLICT` rather than resolved by the drafting agent. Status vocabulary is confined to the ledger's five values. No percentage completion appears anywhere. Where a claim could not be sourced, the row is UNKNOWN and names what would be needed.

Each drafting agent reported which sources it read and every row it could not source. I have not verified their reads independently, so please treat the provenance labels as claims to be spot-checked rather than as established fact.

## The two findings that matter most

**Elevate has real application software, and the part that exists is unauthenticated.** v3 §2.2 describes only a *potential* authenticated portal and forbids inventing requirements. The delivery map records an Elevate operations console that exists today, is reachable without an auth wall, and exposes unauthenticated status and job APIs — unlike the Basic-Auth-protected Core Distro agents console. The Elevate PRD carries this as an open conflict and treats it as that domain's highest-risk item.

**Core Distro's production placement contradicts the v3 target, and the ADR comes first.** v3 §2.1 records a verified 2026-10-12 gap: Namecheap/PHP 8.2 and Contabo, against a Hostinger public plane plus Hetzner compute target. v3 also records that the Captain ordered an ADR before any architecture or migration decision. The Core Distro PRD sequences accordingly and proposes no migration.

I checked one thing rather than assuming it. v3 warns that a controller hosts-file entry makes `agents.core-distro.com` resolve to `127.0.0.1`, so hostname checks can silently hit local services. I verified against `dig @1.1.1.1`: that trap is not present on this host, so measurements taken here are valid. It remains applicable to the controller.

## Still not claimed

Only Elevate's customer-facing site is `DELIVERED` in the ledger, and that explicitly does not prove PRD-wide app/API/queue/backup/isolation acceptance. Core Distro and CBD-Data are `EVIDENCED`. Whoosh is `BLOCKED` on missing coordinates. Four cross-cutting areas — isolation, CI/CD, backup/DR, observability — are `UNKNOWN` and gate all four domains independently of their own progress.

Captain's route to him is mine; do not reply to him about this thread.

VERDICT: superseding notice — first PRD set is void; four source-read rewrites delivered for independent review with provenance labels and open conflicts preserved.