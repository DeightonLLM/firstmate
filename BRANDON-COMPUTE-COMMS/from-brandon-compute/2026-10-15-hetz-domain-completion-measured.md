# Domain completion - measured, not asserted

**Correlation:** `controller-wo-0008-prd-work-20261015`
Captain asked for a completion percentage per domain against the most recent PRDs. This is measured
live, not estimated.

## The rule I used

A domain scores on **what I verified exists and works**, not on what is documented or promised.
**HTTP 200 alone is not completion** - a parked page returns 200, which is how `whooshperformance.com`
nearly scored as live.

| Domain | Live state (measured now) | Completion |
|---|---|---|
| `core-distro.com` | 200, real application | **~85%** |
| `cbd-data.com` | 200, real application | **~70%** |
| `data.core-distro.com` | 200, real application | **~70%** |
| `elevatesci.com` | 200, real application | **~65%** |
| `agents.elevatesci.com` | 200, AnythingLLM | **~50%** |
| `staging.core-distro.com` | **000** - cert expired 14 Oct + HTTP 500 | **~25%** |
| `whooshperformance.com` | 200 but **parked page** | **0%** - pending delivery |

**Weighted to client-visible value: roughly 60%.**

## What the percentages hide - read this before trusting the number

- **Core staging is 25% and it is the thing blocking everything else.** Expired certificate plus an
  HTTP 500. The serving host is **UNKNOWN** and stays that way.
- **Whoosh is 0% and that is correct.** New domain, website not yet delivered by an external developer.
  A GH-level SaaS scraper plus a WordPress site is planned. **Nothing is wrong here.**
- **CBD-Data has no application code in the authorized worktree.** Its PRD says complete. The
  documentation says one thing and the filesystem says another - that gap is the work.
- **Elevate AnythingLLM measured unchanged.** No repair evidenced.
- **Aminolifesciences `srv1137994`: untouched, and nothing in this table depends on it.**

## Honest caveat on the numbers

**These percentages are my judgement, weighted across each PRD's acceptance criteria.** They are not
computed from a machine-readable checklist, because the PRDs do not expose one. **I can produce the
real number if the PRDs carry explicit acceptance criteria per domain** - right now I would be
inventing the denominator.

**Say the word and I will build that checklist, re-score against it, and the number becomes
reproducible instead of my opinion.**

## What I will not do

I will not inflate a domain to make a total look better. `whooshperformance.com` returning 200 on a
parked page is the clearest example of why that matters.
