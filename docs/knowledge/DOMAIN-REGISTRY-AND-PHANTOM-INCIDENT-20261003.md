# Domain registry and phantom-domain incident (2026-10-03)

**Source:** controller, operator-confirmed 2026-10-03. Written from the controller's point of view. Each surface (brandon, elevatesVPS, hd2stack, KVM1) sees its own docs, so verify the facts below against your surface's own state and record any difference. Do not overwrite your surface's data blindly.

## Canonical domains
| Domain | Status |
|---|---|
| `music-metrics.com` | OWNED, live (HTTP 200 on 2026-10-03; Namecheap; registry expiry 2027-04-29) |
| `lawyer-data.com` | OWNED, live (HTTP 200 on 2026-10-03; Namecheap; registry expiry 2028-05-31) |
| `cbd-data.com`, `core-distro.com`, `data.core-distro.com` | live (HTTP 200 on 2026-10-03) |
| `lawyer-dta.com` | PHANTOM. A misspelling of `lawyer-data.com` that docs used for the lawyer product |
| `musicmetricstools.com` | PHANTOM. Never owned or needed |

## What happened
- 2026-09-27: a controller agent registered `lawyer-dta.com` and `musicmetricstools.com` on the wrong account ($22.96, unauthorized). It reasoned from a mistyped domain and fabricated a "dropped domain" premise.
- 2026-10-03: operator confirmed the refund is complete. whois shows both phantoms unregistered.
- Later, a controller audit trusted the wrong docs and reported a false P1 outage for `lawyer-dta.com`. It was retracted.

## Rules for the knowledge pool
1. Phantom domains are **not** HD2 or client findings, assets or outages. Never cite them in audits, state maps or client reports.
2. Use `lawyer-data.com` for the lawyer product. Treat any `lawyer-dta` spelling as a documentation error.
3. A missing domain is a report to the operator, never a purchase. See the spend gate and anomaly report-first rules in AGENTS.md.
4. Full record: `warehouse/recovery/INCIDENT_SPEND_20260927.md` on the controller. It is a historical incident record, not an asset list.

## Open questions for surface owners
- `Lawyer/lawyer-dta/...` path names in `warehouse/recovery/ENRICHMENT_TARGET_ARCHITECTURE.md`: are these real folder names on your surface?
- `system-context/hosts.yaml` and `service_catalog.yaml` still list `lawyer-dta` on some copies. Correct them on your surface, citing this note.
- No secrets, hostnames or credentials belong in this note or in anything derived from it.
