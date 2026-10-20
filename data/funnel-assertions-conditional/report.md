# Conditional Funnel assertions for Core Distro staging

## Change and expiry evidence

Only the two authorized test files were changed:

- `tests/funnel-canonical.mjs` always checks all 12 private-origin routes. It visibly prints 12 Funnel-route `SKIP` records by default and reports skipped checks separately from pass/fail counts. The existing Funnel requests/assertions remain available only with `CORE_DISTRO_FUNNEL_REVIEW=authorized` during a separately authorized review window.
- `tests/asset-origins.mjs` always checks private-origin asset URLs and all 14 private assets. Its Funnel-origin check is visibly `SKIP` by default, separately counted, and retains its existing assertions behind the same explicit opt-in. The private-origin check still rejects the Funnel hostname and remains a failure if broken.

The staging docs were read before relying on the expiry summary. `DEV_HANDOFF.md` says: “A Captain-approved public Tailscale Funnel was authorized temporarily and scheduled to turn off at **09:34 BST on 2026-10-10**. A read-only status check now reports no active Funnel configuration, so do not rely on it.” `README.md` likewise says: “A temporary public Funnel was authorized for two hours and scheduled to expire at 09:34 BST on 2026-10-10. A read-only status check now reports no active Funnel configuration; do not rely on or record its former URL as a permanent endpoint.” This implementation makes no Funnel, DNS, proxy, or production request and does not reactivate anything.

`tools/routes.manifest.json` was read; it is the source of the 12 route paths used by the canonical test.

## Targeted test outputs

Commands ran from `/home/hd2admin/campaign/core-distro-stage`. `COMMAND_EXIT_CODE` is the shell-observed exit code for each command.

### `node tests/funnel-canonical.mjs` — exit 0

```text
# Core-Distro staging Funnel-origin canonical/home_url regression test
# private=http://100.106.6.22:8087
# funnel=SKIPPED (temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window)
# routes=12 per active origin, method=GET only

PASS  http://100.106.6.22:8087                 /                              http=200 hops=0
PASS  http://100.106.6.22:8087                 /products/                     http=200 hops=0
PASS  http://100.106.6.22:8087                 /about/                        http=200 hops=0
PASS  http://100.106.6.22:8087                 /compliance/                   http=200 hops=0
PASS  http://100.106.6.22:8087                 /contact/                      http=200 hops=0
PASS  http://100.106.6.22:8087                 /resources/                    http=200 hops=0
PASS  http://100.106.6.22:8087                 /blog/                         http=200 hops=0
PASS  http://100.106.6.22:8087                 /faq/                          http=200 hops=0
PASS  http://100.106.6.22:8087                 /products/glass-vials/         http=200 hops=0
PASS  http://100.106.6.22:8087                 /products/rubber-stoppers/     http=200 hops=0
PASS  http://100.106.6.22:8087                 /products/aluminum-seals/      http=200 hops=0
PASS  http://100.106.6.22:8087                 /register/                     http=200 hops=0
SKIP  https://brandon-compute.tailddbb4d.ts.net /                              temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window
SKIP  https://brandon-compute.tailddbb4d.ts.net /products/                     temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window
SKIP  https://brandon-compute.tailddbb4d.ts.net /about/                        temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window
SKIP  https://brandon-compute.tailddbb4d.ts.net /compliance/                   temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window
SKIP  https://brandon-compute.tailddbb4d.ts.net /contact/                      temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window
SKIP  https://brandon-compute.tailddbb4d.ts.net /resources/                    temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window
SKIP  https://brandon-compute.tailddbb4d.ts.net /blog/                         temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window
SKIP  https://brandon-compute.tailddbb4d.ts.net /faq/                          temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window
SKIP  https://brandon-compute.tailddbb4d.ts.net /products/glass-vials/         temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window
SKIP  https://brandon-compute.tailddbb4d.ts.net /products/rubber-stoppers/     temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window
SKIP  https://brandon-compute.tailddbb4d.ts.net /products/aluminum-seals/      temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window
SKIP  https://brandon-compute.tailddbb4d.ts.net /register/                     temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window

SUMMARY  active-origins=1  routes=12 per active origin  total-checks=24  passed=12  skipped=12  failed=0  assertion-failures=0
EXIT_CODE 0
COMMAND_EXIT_CODE 0
```

### `node tests/asset-origins.mjs` — exit 0

```text
# Core-Distro staging asset-origin regression test
# private=http://100.106.6.22:8087
# funnel=SKIPPED (temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window)
# method=GET only; asserts correct scheme+host and HTTP 200 per asset

PASS  http://100.106.6.22:8087               private: 14 app asset URL(s) all on http://100.106.6.22:8087
PASS  http://100.106.6.22:8087               private: all 14 app asset(s) returned HTTP 200
SKIP  https://brandon-compute.tailddbb4d.ts.net temporary Funnel review window expired; set CORE_DISTRO_FUNNEL_REVIEW=authorized only for an authorized review window

SUMMARY  active-origins=2  passed=1  skipped=1  failed=0  assertion-failures=0
EXIT_CODE 0
COMMAND_EXIT_CODE 0
```

### `node tests/wp-page-records.mjs` — exit 0

```text
# Core-Distro staging WordPress page records
# read-only: no HTTP request, no POST, no /api/trpc

  id=2    /sample-page/                    1345B  (no document title)
  id=3    /privacy-policy/                 5536B  (no document title)
  id=4    /home/                          53167B  Core Distro | Pharmaceutical Supply Distribution
  id=5    /products/                      20003B  Pharmaceutical Packaging & Equipment | Core Distro
  id=6    /about/                         15057B  About Core Distro | Pharmaceutical Supply Distribution
  id=7    /compliance/                    17279B  Compliance & Quality Assurance | Core Distro
  id=8    /contact/                       12221B  Contact Core Distro | Pharmaceutical Supply Distribution
  id=9    /resources/                      8721B  Resources & Documents | Core Distro
  id=10   /blog/                           7170B  Industry Insights | Core Distro
  id=11   /faq/                           24143B  Frequently Asked Questions | Core Distro
  id=12   /products/glass-vials/          13456B  Type I Borosilicate Glass Vials | Core Distro
  id=13   /products/rubber-stoppers/      10365B  Bromobutyl Rubber Stoppers | Core Distro
  id=14   /products/aluminum-seals/       11635B  Aluminum Flip-Off Seals | Core Distro
  id=15   /register/                      11455B  Client Registration | Core Distro
  id=24   /products/glass-vials-2/         9835B  Type I Borosilicate Glass Vials | Core Distro
  id=25   /products/rubber-stoppers-2/     8033B  Bromobutyl Rubber Stoppers | Core Distro
  id=26   /products/aluminum-seals-2/      8819B  Aluminum Flip-Off Seals | Core Distro
  id=35   /products/glass-vials-3/         9835B  Type I Borosilicate Glass Vials | Core Distro
  id=36   /products/rubber-stoppers-3/     8033B  Bromobutyl Rubber Stoppers | Core Distro
  id=37   /products/aluminum-seals-3/      8819B  Type I Borosilicate Glass Vials | Core Distro
  id=46   /products/glass-vials-4/         9835B  Type I Borosilicate Glass Vials | Core Distro
  id=47   /products/rubber-stoppers-4/     8033B  Bromobutyl Rubber Stoppers | Core Distro
  id=48   /products/aluminum-seals-4/      8819B  Aluminum Flip-Off Seals | Core Distro

show_on_front=page  page_on_front=4  permalinks="/%postname%/"
primary menu: Primary Navigation (8 items)

NOTE  9 drained seed duplicate(s) retained as drafts (IDs 24, 25, 26, 35, 36, 37, 46, 47, 48). Not routable; content preserved.

SUMMARY  assertions-failures=0  EXIT_CODE 0
COMMAND_EXIT_CODE 0
```

## Full ten-test suite

The same full suite was re-run in the following order; every listed command's observed process exit code was **0**:

1. `node tests/multipage-smoke.mjs` — 12 routes passed, 0 failed.
2. `node tests/accessibility-structure.mjs` — 27 assertions passed, 0 failed.
3. `node tests/funnel-canonical.mjs` — 12 private route checks passed; 12 Funnel route checks skipped; 0 failed.
4. `node tests/head-metadata.mjs` — 12 routes passed, 0 failed.
5. `node tests/homepage-footer-links.mjs` — 6 assertions passed, 0 failed.
6. `node tests/wp-page-records.mjs` — 0 assertion failures; output reports the nine duplicate records retained as drafts, with content preserved.
7. `node tests/asset-origins.mjs` — private origin and 14 private assets passed; Funnel origin skipped; 0 failed.
8. `node tests/lighthouse-remediation.mjs` — 34 checks passed, 0 failed.
9. `php tests/lighthouse-content-fixes.php` — 0 failures.
10. `PYTHONDONTWRITEBYTECODE=1 python3 tests/test_extract_lighthouse_fixes.py` — 8 tests passed.

Observed overall result: **10/10 commands exited 0**. The Funnel checks were not green passes: canonical had 12 explicit skips and asset-origin had one explicit skip. All active checks reported no failures.

## What this does and does not establish

The passing private-origin canonical checks verify HTTP 200, no redirects, and canonical origin/path for all 12 routes. The asset check verifies the private page's app-asset origins and HTTP 200 for all 14 assets. The other suite checks genuinely exercised their reported local route, markup, page-record, PHP-helper, and Python-extractor assertions.

**The Funnel path was not tested.** No Funnel listener was probed or contacted; the suite result is not evidence that Funnel canonical URLs, Funnel assets, or public reachability work. Those retained checks can run only after a separate review window is authorized and the operator explicitly enables `CORE_DISTRO_FUNNEL_REVIEW=authorized`. No authorized Funnel check was run here. No visual review was run; it is outside this ten-test suite.

No tests outside the ten enumerated staging tests were represented as passing. No Compose lifecycle command, production request, database write, DNS/proxy change, or public-listener operation was performed by this task.

## Decision-hold completion and delivery limitation

Reviewed the complete result for unresolved captain decisions; none remain from this authorized change. Completed the required decision-hold gate with:

`bash /home/hd2admin/kun-agent-workspace/bin/fm-decision-hold.sh complete funnel-assertions-conditional --none`

Output: `complete: funnel-assertions-conditional decision inventory reviewed`.

The live staging directory is not a Git repository (`git rev-parse --is-inside-work-tree` reported `fatal: not a git repository`). Therefore no branch or commit can be created there, and no no-mistakes delivery run was started. Test edits are limited to the two requested files; this report is at `/home/hd2admin/kun-agent-workspace/data/funnel-assertions-conditional/report.md`.
