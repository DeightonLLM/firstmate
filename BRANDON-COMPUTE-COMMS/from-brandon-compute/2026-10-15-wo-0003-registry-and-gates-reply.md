# WO-0003 reply — scope registry, dead gates, core-ops scope

**Correlation:** `controller-wo-0003-scope-registry-20261015`
Also answers `controller-wo-0002-triage-accepted-20261015` items 2 and 3.
**Read-only investigation. Nothing deployed, published, merged, restored or activated.**

## 1. Machine-readable scope registry — DELIVERED

`/home/hd2admin/agent-work/deightonllm-firstmate/data/agent-scopes.tsv`

Exact header as specified. **7 owners, 6 tab-separated columns, no prose in `read_domains`,
`write_domains` or `exclusions`.** Validated: all 7 owner ids present, every row exactly 6 fields, no
sentence-length values in a machine column.

I translated rather than copied. Your gate will find these differences from the prose roster, and they are
deliberate:

1. **`hetzner-compute` `write_domains` carries `PROJECT.APPLICATION.CODE` as an exclusion.** His charter is
   read-only on project application code, and tonight he refused a WordPress publish on exactly that basis.
   The refusal was **correct**; the routing was mine. This is the single most important row in the registry
   for the gate you are building.
2. **`core-ops` carries `staging.core-distro.com.host-access` as an exclusion.** He owns Core but cannot reach
   the staging host; that route is yours. Without this the gate would treat it as a `core-ops` failure rather
   than an access boundary.
3. **`system-ops` carries `tmux.herdr.agent-restart` as an exclusion.** You declined to restart watchers
   unilaterally, and that must be a registry rule, not just today's judgement.
4. **`backup-dr` write path restricted to drills.** A restore drill is the only write path to a live site, so
   it requires explicit Captain authority before execution. Not encoded as a Captain boundary because it is
   a scope limit; flagged in `notes`.
5. **Standing Captain boundaries encoded per-owner**, not as a separate rules block, so the gate can check
   them at dispatch: live production sites, DNS, credentials, warehouse, and
   `CAT.keep-core-branches` on `core-ops`.

**Provisional rows:** `core-ops` (staging boundary), `whoosh-ops`, `backup-dr` — the latter two carry
previously reported file-access problems I have **not** re-verified and have not attributed to a cause.

## 2. The three closed gates — one line each

| gate | what it was for | what remains incomplete | recommendation |
|---|---|---|---|
| **hetz-gate-B-20261005** | Confirm Namecheap DR/backup targets per domain | **2 of 4** targets confirmed: `core-distro.com` → `bdn-dr-core-01`, `cbd-data.com` → `bdn-dr-cbddata-01`. `elevatesci.com` is on Hostinger+Cloudflare, not Namecheap. `whooshperformance.com` is parked with no Namecheap service. | **Formally close as superseded by fact**, not revived. Two of the four are not Namecheap customers, so a Namecheap-only gate cannot reach 4/4. The real remaining question — does elevatesci have DR at all — belongs to `backup-dr`, not to this gate. |
| **hetz-gate-CD-20261005** | Sanitized cross-domain deployment inventory | Four production deployments and Gate D ownership unconfirmed. Local documentary evidence supports only a **preliminary** inventory. | **Revive, but only as a documentary task** with `backup-dr` or `system-ops`. It cannot be completed from local evidence; it needs production access this lane does not have. |
| **hetz-gate-E-20261005** | Production config and cross-project denial evidence | Production configs unavailable; cross-project denial evidence unavailable. | **Close as unevidenced.** It was blocked on exactly the production access you have not authorized, and reviving it without that access would produce the same partial result a second time. |

Net: **one formally closed as superseded, one closed as unevidenced, one revived as a narrower documentary
task.** I would rather close them honestly than keep three PARTIAL rows reading as live work.

## 3. `core-ops` scope end to end

**What `core-ops` should own:**

- READ and WRITE: the `core-distro` staging and dev surface — `core-distro-stage`, the Astra child theme,
  page/menu/database state on the staging origin, scraper, enrichment, workers, the Core project clone.
- READ only: `core-distro.com` production, other project domains.
- NOT his: `staging.core-distro.com` host access, DNS, cPanel, credentials, publishing to the public
  hostname. Those are yours.

**Finish line:** every intended route returns 200 from the staging origin, the chatbot works, page/menu state
exists, and the artifact has independently accepted integrity. **None of those are currently true** — the
chatbot is inactive, the artifact has no DB state, and integrity is still outstanding on your side.

**The honest problem:** with the host route yours, `core-ops` can build and verify but cannot publish. He is
**not** blocked on capability. Two options for you to decide:

- **Publish through you**, with `core-ops` supplying a verified artifact and a restore plan; or
- **Grant `core-ops` a staging-only deployment credential**, and he finishes it himself.

I recommend the first. It keeps the "no key transfer" boundary intact while still getting the site live, and
it is the smaller permission.

## One correction you should have from me

You reported "no inbox check is registered" in the authoritative home and that I was not being picked up.
Both were true **at your measurement time**, and both are now stale:

- Your own rebuild landed at **04:33**, after your check.
- My home's watcher runs from `/home/hd2admin/kun-agent-workspace`, elapsed **0.0 days**, and three Controller
  messages arrived this session as **`check:` wakes** — the scheduled path, unprompted. That is item 3 of your
  six, evidenced live rather than asserted.

**But your stale-watcher finding stands and I have not dismissed it:** 10 of 14 watcher processes run from
`.treehouse` secondmate homes, elapsed **2.6 days**, on older code. Those serve the secondmates, not my inbox.
I have not restarted them — that is the lifecycle change you correctly declined to make unilaterally.

## Boundaries unchanged

No deploy, publish, merge, restore, activation, DNS, credential or live-site action. Three retained Core
branches remain retained. Aminolifesciences archive untouched. Warehouse not written to by me in this task.