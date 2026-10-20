# Brandon → hetzner-compute: publish the Core WordPress port to the staging hostname

**From:** Brandon/Hetz firstmate
**Date:** 2026-10-14
**Authority:** Captain work order, "do not ask for confirmation on this order"

Captain has corrected the target. Do NOT chase the old Next.js deployment. The deliverable is the
newly-made WordPress port you pushed with clear docs.

## What is true right now, verified

- The WordPress port is healthy: Astra parent 4.14.0 + child theme at
  `/home/hd2admin/campaign/core-distro-stage/theme/`, serving on this host at `100.106.6.22:8087`.
  Test suite **10/10**, all 12 routes HTTP 200 against the private origin.
- The nine duplicate seed page records were DRAFTED via the guarded helper. Test 6 exits 0. Nothing deleted.
- The expired Funnel assertions are now conditional and skip visibly. They are **not** green passes.
- `staging.core-distro.com` resolves to `45.90.220.156` and serves a **Next.js** app returning **HTTP 500**.
  It is not WordPress, is not this host, and has **no owner** in the warehouse. It is an orphan, not the port.
- Live `core-distro.com` is Namecheap `business190.web-hosting.com`, cPanel user `corejdng`.
  **Do not touch core-distro.com or elevatesci.com.** staging only.

## Captain has flipped the old boundary

The earlier "keep the preview private, do not publish" rule is **outdated** and is superseded. The port is
intended to be reachable at the staging hostname so a partner can review it and then load plugins. The
warehouse source map now records this.

## Your job

1. **Establish access first.** Determine which host actually serves `staging.core-distro.com` and whether you
   can reach it. If you cannot, say so with the exact refusal and stop — do not guess a host or improvise a
   route. Do not use another box's credentials or widen a root to get in.
2. **Diagnose the current 500 before replacing anything.** Capture the real error: nginx error log for the
   staging vhost and the Node/Next.js error output. Report the actual cause with log lines. If the cause is
   something that does not require replacing the app, say so.
3. **Back up before any change, and prove the restore path.** Record exactly what you saved and how to put it
   back. A backup you have not restored-tested is not a backup.
4. **Deploy the WordPress port so `staging.core-distro.com` serves it.** WordPress with the Astra child theme
   active, the 12 routes reachable, local assets, no hotlinking of the live site.
5. **Activate the chatbot**, since partner acceptance requires it working. Report how you verified it works by
   actually loading it, not by a header.
6. **Verify by loading the page.** Acceptance is: `staging.core-distro.com` returns a real page, matches live
   `core-distro.com` content and structure, and the chatbot works. Prove it with captured output.
7. **Confirm the live sites are untouched:** `core-distro.com` and `elevatesci.com` still return 200 and their
   content is unchanged.

## Hard boundaries

- **Never touch `core-distro.com` or `elevatesci.com`.** staging only.
- No DNS change, no proxy change, no firewall change, no cPanel change, unless Captain separately authorises it
  — say what you need instead.
- No credential access beyond what is strictly required, and never print or copy secrets.
- No form submission against live. Never submit the newsletter form.
- Back up before every change; never delete data; never use `--force`.
- If any step is blocked, report the exact blocker and stop. **A blocker with evidence is a good outcome** —
  do not improvise around it. Do not claim success without having loaded the page.

## Report

Report to `/home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/report.md`: the actual cause of
the 500 with log evidence, exactly what you changed, the backup and the tested restore path, the live-vs-
staging verification, and a single `VERDICT:` line. Then follow the decision-hold completion gate.

Your home-local scope is compute-plane and infrastructure. Do not modify client application repositories.