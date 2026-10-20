# Domain acceptance checklist scoring

**Evidence-coverage score (not a domain-readiness percentage).** The requested acceptance sources are not present in this worktree: `data/wo0005-2-domain-prds/report.md` and `data/2026-10-15/`. Therefore domain-specific PRD requirements could not be authored or verified without inventing criteria. The checklist records this as `UNVERIFIED`, never as `PASS`.

Machine-readable source of truth: [`acceptance-checklist.json`](acceptance-checklist.json).

## Scoring

Reproduce from the JSON: for each domain, count `PASS`, `FAIL`, and `UNVERIFIED`; exclude `N/A`; compute `100 × PASS / (PASS + FAIL + UNVERIFIED)`, rounded to one decimal. `UNVERIFIED` remains in the denominator and earns no pass credit. This measures confirmed checklist evidence only; it is not a claim that a domain is 0% ready.

| Domain | PASS | FAIL | UNVERIFIED | N/A | Evidence coverage |
|---|---:|---:|---:|---:|---:|
| core-distro.com | 0 | 0 | 3 | 0 | 0.0% |
| cbd-data.com | 0 | 0 | 3 | 0 | 0.0% |
| data.core-distro.com | 0 | 0 | 3 | 0 | 0.0% |
| elevatesci.com | 0 | 0 | 3 | 0 | 0.0% |
| agents.elevatesci.com | 0 | 0 | 3 | 0 | 0.0% |
| staging.core-distro.com | 1 | 0 | 2 | 0 | 33.3% |
| whooshperformance.com | 0 | 0 | 2 | 1 | 0.0% |
| **Total** | **1** | **0** | **19** | **1** | **5.0% (1/20)** |

The staging PASS is only the auditable constraint that its serving host remains exactly `UNKNOWN`; it is not a site-health pass. Whoosh external website delivery is `N/A` while it is pending, and its expected parked state is not scored as a failure. No DNS, PTR, credentials, or live-site requests were used. No project application directories were inspected.

## What would move the scores

1. Make the seven-domain PRD and the 2026-10-15 audit reports available in the authorized worktree; extract their measurable acceptance conditions, owners, and expected outcomes into domain-specific checklist entries.
2. For each live criterion, provide an allowed observation path that does not contact the expressly prohibited host. Collect repeatable response/content/TLS observations against explicitly authorized safe endpoints. HTTP status alone is insufficient.
3. Keep `staging.core-distro.com`'s serving host `UNKNOWN` until an allowed authoritative record says otherwise; do not use DNS, PTR, or legacy aliases to fill it in.
4. For Whoosh, change delivery from `N/A` only after external developer delivery is evidenced; then verify the delivered acceptance criteria. A parked page remains correct before that event.

**Single biggest blocker:** required PRDs and dated audit evidence are absent, so a reproducible domain-readiness denominator cannot be defined without fabrication.

blocked: [key=required-evidence-absent] Required PRD and 2026-10-15 audit files are missing from this worktree; consequently these are evidence-coverage scores only, not readiness scores.
