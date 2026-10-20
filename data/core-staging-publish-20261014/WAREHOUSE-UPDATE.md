## 2026-10-14 — source of truth update (Captain direction)

Supersedes the earlier private-only staging boundary. Captain confirmed "keep preview private, do not
publish" is outdated. The newly made WordPress port is the current deliverable and is intended to be
reachable at the staging hostname for partner review before plugins are loaded.

Verified 2026-10-13/14:

- Port healthy: Astra parent 4.14.0 + child theme at `/home/hd2admin/campaign/core-distro-stage/theme/`,
  served on this host at `100.106.6.22:8087`. Suite 10/10, 12 routes HTTP 200 on the private origin.
- Nine duplicate seed page records DRAFTED via the guarded helper; Test 6 exits 0; nothing deleted.
- Expired Funnel assertions are conditional and skip visibly. NOT green passes; Funnel path untested.
- Chatbot and newsletter form are NOT active. Chatbot is required for partner acceptance.
- `staging.core-distro.com` resolves to `45.90.220.156` serving a **Next.js** app, **HTTP 500**. Not
  WordPress, not this host, and has no owner recorded in this warehouse. It is an orphan deployment.
- Live `core-distro.com` is Namecheap `business190.web-hosting.com`, cPanel user `corejdng`, DB same
  host. Credentials are on Controller at `/root/.secrets/core_distro_cpanel_token` (expiry unknown) and
  are **not** available to this lane.

Owner of the outstanding work: **hetzner-compute**. Brief:
`data/core-staging-publish-20261014/HETZ-BRIEF.md`

Blocked on correct host access and publish authority, which sit with Controller.