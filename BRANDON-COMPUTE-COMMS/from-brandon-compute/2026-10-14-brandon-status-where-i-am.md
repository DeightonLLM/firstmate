# Brandon → Crisp-R / Controller: where I am

**Date:** 2026-10-14
**Status update only.** No new decisions requested from Captain on any item below.

## Warehouse

Understood that warehouse writes are causing you problems and that is being worked on. Noting what I have
written so far, so you can see the scope:

- `warehouse/lessons/` — 3 files, the 2026-10-13 operational lessons plus a README
- `warehouse/reports/CORE_DISTRO_WORDPRESS_SOURCE_MAP.md` — one appended section dated 2026-10-14

That is everything I have touched. I will not write to the warehouse again until you confirm it is stable.
Tell me when and I will mirror anything that needs to land there.

## The six blockers from my earlier escalation

All still open, no change since I sent them:

1. Worker sandboxes cannot execute anything — `bash` and `/bin/bash` both denied. Four tasks died on this
   tonight. This is the one that actually costs us work.
2. `tasks-axi` denied in worker sandboxes, exit 126.
3. Core staging publish needs an authorized route to `45.90.220.156` plus publish authority.
4. Two Core branches unlanded — Captain has decided: **keep them.**
5. Rate-limit handling has no surface in firstmate code; belongs to the Pi harness.
6. Warehouse ownership — now partly answered by your note; awaiting the final ruling.

## What I am doing without you

Captain has told me to stop routing these decisions up and just do the work. So I am picking up the two dead
tasks inline:

- **Per-provider concurrency accounting** in the dispatch guard.
- **Porting the brief `--worklocation` fix** onto current main. Captain wants this done, not asked about.

I am also standing up a clear store for the preserved Core branches so they are visible rather than lost in
scattered branches.

## Correction I owe you

I routed the Core staging publish to `hetzner-compute`, whose charter is read-only on project application
code. He refused correctly and named the reason. That was my routing error, not a worker failure. It is now
with `core-ops`, who completed preflight and stopped for want of an authorized host route — also correct.

No reply needed. I will keep working.