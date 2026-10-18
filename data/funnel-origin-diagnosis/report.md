# Funnel origin and staging-test diagnosis

## Scope and method

Read-only diagnosis of the completed baseline at `/home/hd2admin/kun-agent-workspace/data/core-stage-chunk1-test-baseline/report.md` and the current staging sources/docs under `/home/hd2admin/campaign/core-distro-stage/`. No staging files were changed. No tests were rerun, and no Docker lifecycle, network, database, DNS, proxy, firewall, cPanel, credential, form, chatbot, or production-site operation was performed.

The baseline says all ten tests ran: seven passed and Tests 3, 6, and 7 failed. It records healthy MariaDB/WordPress containers and 12/12 private-origin routes passing. It records all 12 Funnel-route requests in Test 3 as `ECONNREFUSED`, and private-origin assets passing while the Funnel origin is refused in Test 7. Test 6 separately found nine published duplicate seed pages.

## 1. Funnel origin and its source

The literal origin is **`https://brandon-compute.tailddbb4d.ts.net`** (HTTPS, implicit port 443).

- `tests/funnel-canonical.mjs:15-16` hard-codes `ORIGIN_FUNNEL = 'https://brandon-compute.tailddbb4d.ts.net'`. The test reads only `tools/routes.manifest.json` for route paths (`:13-16`); it does not read an environment variable or Funnel config.
- `tests/asset-origins.mjs:66-67` hard-codes `FUNNEL_HOST = 'brandon-compute.tailddbb4d.ts.net'` and constructs the HTTPS origin. It runs that origin in its second check at `:313-319`.
- The staging `compose.yaml:32-36` sets `WP_HOME` and `WP_SITEURL` to `http://100.106.6.22:8087` and publishes only `100.106.6.22:8087:80`; it defines no Funnel service or Funnel target. `.env` provides database settings, not the test's Funnel URL.
- `theme/functions.php:99-115` recognizes that same exact host for request-time URL generation. That is application URL logic, not Funnel service configuration.

## 2. Is the Funnel supposed to be running?

**No—not according to the current staging operating notes.** It was a temporary, owner-approved public Tailscale Funnel for review, scheduled to turn off at 09:34 BST on 2026-10-10. `DEV_HANDOFF.md:8-10` says a subsequent read-only status check reported no active Funnel configuration and says not to rely on the URL. `README.md:9-10` independently describes the two-hour temporary authorization, scheduled expiry, and no-active-configuration status. The durable service is the private WordPress preview on the Tailnet at `http://100.106.6.22:8087`; the Funnel was an external ingress/proxy to that same WordPress instance, not a service in Compose (`tests/asset-origins.mjs:7-10`; `theme/functions.php:57-64`).

Thus the hostname's presence in tests and theme code does not mean its public listener remains provisioned. The source docs describe a decommissioned/disabled temporary endpoint, not a continuously running public origin.

## 3. Why the requests are refused

The evidence supports **the Funnel listener/configuration is inactive**, consistent with its documented scheduled expiry. The baseline's `ECONNREFUSED` is a connection-refusal result, not a DNS-resolution error: the request path got far enough to report a refused connection. It does not indicate an HTTP response or a WordPress route/canonical failure. WordPress and the private service are healthy and reachable, so their health does not restore the separate Funnel ingress.

The evidence does **not** support a wrong configured origin or port as the cause: both tests use the exact temporary hostname documented by the project, and HTTPS without an explicit port correctly targets 443 for the Funnel. Compose's `8087` is the private HTTP listener, not the public Funnel listener. A DNS failure is inconsistent with the reported `ECONNREFUSED` (a resolution failure would produce a DNS error such as `ENOTFOUND`). A network-policy rejection can in principle also manifest as a refused connection, so the error alone cannot prove there was no policy-generated reset; however, no policy change is evidenced, while the handoff explicitly records that no active Funnel configuration remains. The diagnosis is therefore **inactive/decommissioned Funnel**, with the caveat that current listener/network state was not independently probed under the read-only task limits.

No current DNS lookup, TCP probe, `tailscale funnel` status command, or host-level listener inspection was run. Those are explicitly unrun checks, not hidden assumptions.

## 4. Test 6 is independent

**The duplicate pages are not caused by the Funnel.** Test 6 (`tests/wp-page-records.mjs:158-184`) reads WordPress records with the local dumper and flags published seed-owned slugs outside the route manifest. It does not request the Funnel; its header and `dumpWordPress()` path (`:1-14`, `:31-46`) perform a local `docker compose exec ... php` read.

The baseline lists IDs 24-26, 35-37, and 46-48 (`glass-vials`, `rubber-stoppers`, and `aluminum-seals` suffixed `-2`, `-3`, and `-4`) as published. `tools/seed-pages.php:75-83` documents the independent historical cause: the earlier lookup used hierarchical `get_page_by_path()` for a bare child slug, so repeat seeding generated suffixed duplicates; it now queries by slug. `DEV_HANDOFF.md:43-45,64-66` states the same nine duplicates remain and are intentionally held unchanged pending explicit approval. `tools/draft-seed-duplicates.php:1-20` describes the separate non-destructive way to draft the exact owned duplicates, but its application writes WordPress records and is not authorized here.

Therefore, changing or restoring Funnel service alone cannot clear Test 6. A single fix cannot clear all three failures.

## 5. Smallest correct fix and authority

- **Tests 3 and 7:** The narrowest change consistent with the written deployment contract is to stop requiring this *expired, optional* public Funnel during ordinary private-stage test runs: update `tests/funnel-canonical.mjs` and `tests/asset-origins.mjs` to run the Funnel assertions only when a currently authorized/available Funnel test target is explicitly configured, while retaining the private-origin checks. The exact current files hard-code the stale target (`tests/funnel-canonical.mjs:15-16`; `tests/asset-origins.mjs:66-67,313-319`). This requires **staging-tree edit authority**. If the owner instead wants public Funnel coverage, that is not a test-only fix: the owner must explicitly reauthorize the temporary public ingress and an authorized operator must configure/start the Tailscale Funnel to forward to the private WordPress service. That requires **owner decision plus container/host-level service lifecycle authority**; do not treat test presence as authorization to reactivate a public endpoint.
- **Test 6:** The smallest remediation is to draft only the nine seed-owned duplicate records, using the guarded target already documented at `tools/draft-seed-duplicates.php` and verifying the exact candidate IDs. This requires **explicit owner approval for the database mutation and an approved database/runtime execution path**. `DEV_HANDOFF.md:64-66` explicitly says to leave these nine unchanged pending that approval. No database operation was attempted.

The recommendation is to first ask the owner whether the Funnel-specific assertions should be conditional/retired for the expired temporary origin or whether a new temporary public review window is wanted. Do not start Funnel or change tests as part of this diagnosis. Independently, keep the duplicate records untouched until explicit approval. These are separate decisions and separate authorities.

## Checks not run

- No staging test was rerun; baseline results were read as supplied.
- No `docker compose ps`, `exec`, `up`, `down`, `restart`, `pull`, or `build` was run by this diagnosis. The existing baseline's recorded `docker compose ps` is evidence only.
- No DNS query, TCP/HTTPS probe, Tailscale status/config inspection, or host listener inspection was run.
- No DB query, credentials access, form submission, chatbot activation, proxy/firewall/DNS/cPanel change, or production request was made.
- No screenshot/visual review was run; it was not needed to identify these test failures.

## Decision-hold completion gate

The diagnosis identifies an unresolved owner choice about whether the expired Funnel is to remain out of routine test requirements or receive a newly authorized public review window. The required `decision-hold-lifecycle` policy was read. Its structured completion command would mutate the owning home's backlog/state, but this task authorizes writes outside the staging worktree **only** to this report and the task status file. I therefore did not create or complete a backlog hold and cannot truthfully claim that the shared completion gate passed. Firstmate must register the owner decision and run the completion gate in the authoritative home, or provide explicit additional authorization for that specific backlog operation. The report is complete; the required decision lifecycle remains outstanding.
