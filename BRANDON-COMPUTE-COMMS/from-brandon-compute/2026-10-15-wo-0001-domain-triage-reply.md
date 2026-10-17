# WO-0001 reply — domain triage and ownership split

**Correlation:** `controller-wo-0001-domain-triage-20261015`
**Task:** read-only investigation. Nothing was deployed, published, merged, restored or activated.
**Measured:** 2026-10-15, from Hetz (`brandon-compute`, 100.106.6.22). HTTP status codes are live probes.

## Triage table

| Domain / area | Surface | Live state | Deployed vs staged | Broken | Evidence | Blocked on | Next action | Captain decision needed |
|---|---|---|---|---|---|---|---|---|
| **core-distro.com** | Namecheap `business190.web-hosting.com`, cPanel `corejdng`, 66.29.153.174 | **200** | **Live, untouched** | Not verified broken | `curl` 200 at 2026-10-15; unchanged all session | Nothing blocking the live site | None — it works | **Yes, if anything touches live** |
| **staging.core-distro.com** | `45.90.220.156` (= KVM1 `srv1137994.hstgr.cloud`, same host as 100.69.211.43) | **000 — unreachable, connection fails before HTTP** | **Neither.** Serves an orphaned Next.js app, not our port | Site down | `curl` returns `000`, `remote_ip=45.90.220.156`, no status code; the 500 seen earlier is no longer even returning an HTTP response | No authorized route from Hetz; `ssh elevatesVPS` is Controller-side, no key transfer authorized | Controller decides: publish the WP artifact, or retire the orphaned Next.js deployment | **Yes** |
| **Core WordPress port** | `100.106.6.22:8087`, Astra 4.14.0 + child theme, this host | **Healthy, private Tailnet only** | **Staged, never published** | Chatbot inactive; no DB/page/menu state in artifact | Suite 10/10, 12 routes HTTP 200 on private origin; artifact `50ae6849c190`, 19/19 checksums | Independent integrity acceptance (yours, outstanding) | Independent integrity confirmation, then Controller publishes | No |
| **elevatesci.com** | Hostinger + Cloudflare, same box as staging | **200** | **Live, untouched** | AnythingLLM workspace was a P0 repair lane | `curl` 200 at 2026-10-15 | Nothing blocking the live site | None — it works | **Yes, if anything touches live** |
| **cbd-data.com** | Warehouse records `✅ DEPLOYED / ✅ LIVE` | **200** | **Live** | Not verified broken | `curl` 200; `SAAS_STATE_MAP.md` records deployed | — | Confirm the warehouse record still matches reality | No |
| **whooshperformance.com** | — | **200** | **Live** | Not verified broken | `curl` 200 | — | None | No |
| **data.core-distro.com** | Warehouse: `business190` | **200** | **Live** | `getTopCities` unverified in staging | `curl` 200; `SAAS_STATE_MAP.md` notes ❌ MISSING on one column | — | Verify `getTopCities` against staging | No |
| **Aminolifesciences** | Archive | **Preserved** | Archived | Post-archive protected-site checks incomplete | Your standing order | — | **Do not retire or delete** without a separate explicit order | **Yes — hard boundary** |
| **Hetz compute plane** | RabbitMQ, Qdrant, enrichment/AI workers, browser pools | Operational | Live | — | `hetzner-compute` lane idle, no open fault | — | — | No |
| **Backup / DR** | Namecheap encrypted transfers | Operational | Live | — | `backup-dr` lane idle | — | — | No |
| **System ops** | Host | Operational | Live | — | `system-ops` lane idle | — | — | No |

## Corrections to my own earlier claims

1. **staging.core-distro.com is no longer returning HTTP 500.** It now returns `000` — connection fails before
   any HTTP response. That is a *different* failure from the 500 I reported and verified twice earlier. Do not
   carry my "500" forward as current.
2. **I compared a DNS address with a Tailscale address and called them different hosts.** They are the same
   machine. Already corrected to you; recorded here so the triage carries the true state.
3. **`/root/AGENTS.md` and the root policy family ARE readable from this host.** I had reported them as
   unavailable in shipped commit `d89b84d7`. Corrected in `f941d893` with explicit scope labels.

## Mis-scoped, duplicated, or double-owned

1. **Domain ownership is already one-agent-per-domain in the registry** — `core-ops`, `whoosh-ops`,
   `cbddata-ops`, `elevate-p0-repair`, `hetzner-compute`, `backup-dr`, `system-ops` each have a written scope.
   **The split you are planning already exists on paper.** The failure tonight was not the split; it was me
   routing Core work to `hetzner-compute`, whose scope is compute-plane only. He refused correctly. **The gap
   is enforcement at dispatch, not ownership definition.** A scope check in the dispatch guard would have
   stopped it.
2. **`core-ops` cannot do the staging publish**, because the host route is Controller-side. It is blocked on
   access, not on capability. So Core has an owner who cannot finish the Core work. That needs naming.
3. **`hetz-gate-B/CD/E` are dead, not waiting.** All three panes closed. Gate B was PARTIAL 2/4 Namecheap
   targets; CD and E were PARTIAL for want of production config evidence. Nobody is working them.
4. **Five domain experts reportedly cannot read their own files.** Unverified — I withdraw the single-cause
   claim and have not re-investigated.
5. **Home authority is unresolved.** `/home/hd2admin/agent-work/deightonllm-firstmate` holds 11 durable
   records but no backlog or secondmate registry; `/home/hd2admin/kun-agent-workspace` holds 16 plus both.
   Question sent separately.

## What I did not do

No deploy, publish, merge, restore, activation, DNS, credential or live-site action. No branch discarded or
merged. The three retained Core branches remain retained. The Aminolifesciences archive untouched. Warehouse
written to by me earlier today is preserved for your reconciliation, not deleted.