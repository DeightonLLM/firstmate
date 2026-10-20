# Core Distro private WordPress staging test baseline

Read-only baseline for `/home/hd2admin/campaign/core-distro-stage/`. No staging files were edited; no Docker Compose lifecycle command, database write, form submission, chatbot activation, or production request was made. All ten listed tests were executed. Seven exited 0; three exited 1. This is not a clean run. No listed test was skipped or masked.

## Stack status

Command: `cd /home/hd2admin/campaign/core-distro-stage && docker compose ps`

Exit status: 0

Output:

```text
NAME                            IMAGE              COMMAND                  SERVICE     CREATED      STATUS                PORTS
core-distro-stage-database-1    mariadb:11         "docker-entrypoint.s…"   database    4 days ago   Up 4 days (healthy)   3306/tcp
core-distro-stage-wordpress-1   wordpress:latest   "docker-entrypoint.s…"   wordpress   4 days ago   Up 4 days (healthy)   100.106.6.22:8087->80/tcp
```

## Test 1 — multipage smoke

Command: `cd /home/hd2admin/campaign/core-distro-stage && node tests/multipage-smoke.mjs`

Exit status: 0

Output:

```text
# Core-Distro staging multipage smoke
# origin=http://100.106.6.22:8087 routes=12 method=GET only

PASS  /                              http=200 hops=0 bytes=85324 title="Core Distro | Pharmaceutical Supply Distribution" h1="VIALS. STOPPERS. SEALS. DONE. ONE PARTNER."
PASS  /products/                     http=200 hops=0 bytes=61691 title="Pharmaceutical Packaging & Equipment | Core Distro" h1="EVERY COMPONENT. FULLY DOCUMENTED."
PASS  /about/                        http=200 hops=0 bytes=56815 title="About Core Distro | Pharmaceutical Supply Distribution" h1="THE INFRASTRUCTURE BEHIND EVERY DOSE."
PASS  /compliance/                   http=200 hops=0 bytes=59014 title="Compliance & Quality Assurance | Core Distro" h1="COMPLIANCE ISN'T A FEATURE. IT'S THE FOUNDATION."
PASS  /contact/                      http=200 hops=0 bytes=53730 title="Contact Core Distro | Pharmaceutical Supply Distribution" h1="LET'S BUILD YOUR SUPPLY CHAIN."
PASS  /resources/                    http=200 hops=0 bytes=50284 title="Resources & Documents | Core Distro" h1="PRODUCT DOCUMENTATION."
PASS  /blog/                         http=200 hops=0 bytes=48814 title="Industry Insights | Core Distro" h1="Industry Insights"
PASS  /faq/                          http=200 hops=0 bytes=65679 title="Frequently Asked Questions | Core Distro" h1="FREQUENTLY ASKED QUESTIONS"
PASS  /products/glass-vials/         http=200 hops=0 bytes=55141 title="Type I Borosilicate Glass Vials | Core Distro" h1="RTU GLASS VIALS"
PASS  /products/rubber-stoppers/     http=200 hops=0 bytes=52044 title="Bromobutyl Rubber Stoppers | Core Distro" h1="RUBBER STOPPERS"
PASS  /products/aluminum-seals/      http=200 hops=0 bytes=53334 title="Aluminum Flip-Off Seals | Core Distro" h1="ALUMINUM SEALS"
PASS  /register/                     http=200 hops=0 bytes=52886 title="Client Registration | Core Distro" h1="REQUEST FULL PRODUCT LIST"

SUMMARY  routes=12  passed=12  failed=0  assertion-failures=0
EXIT_CODE 0
```

## Test 2 — accessibility structure

Command: `cd /home/hd2admin/campaign/core-distro-stage && node tests/accessibility-structure.mjs`

Exit status: 0

Output:

```text
PASS  A11Y_H1_NESTED_INTERACTIVE     theme/public-homepage-body.html: 0 <a><button> nestings
PASS  A11Y_H1_NESTED_INTERACTIVE     theme/partials/cd-page-header.php: 0 <a><button> nestings
PASS  A11Y_H1_NESTED_INTERACTIVE     theme/page.php: 0 <a><button> nestings
PASS  A11Y_H1_NESTED_INTERACTIVE     theme/front-page.php: 0 <a><button> nestings
PASS  A11Y_H2_MOBILE_NAV_INERT       theme/public-homepage-body.html: closed panel ships inert + aria-hidden="true"
PASS  A11Y_H2_MOBILE_NAV_OPEN_STYLE  theme/public-homepage-body.html: closed panel keeps its opacity/pointer-events inline style
PASS  A11Y_H2_MOBILE_NAV_INERT       theme/partials/cd-page-header.php: closed panel ships inert + aria-hidden="true"
PASS  A11Y_H2_MOBILE_NAV_OPEN_STYLE  theme/partials/cd-page-header.php: closed panel keeps its opacity/pointer-events inline style
PASS  A11Y_H2_MOBILE_NAV_INERT       setMenuOpen() syncs inert and aria-hidden with the open state
PASS  A11Y_H3_FAQ_PANEL_INERT        setExpanded() keeps the visual collapse and removes collapsed content from a11y exposure
PASS  A11Y_M1_MAIN_LANDMARK          theme/public-homepage-body.html: exactly one <main id="cd-main">
PASS  A11Y_M2_SKIP_LINK              theme/public-homepage-body.html: one .cd-skip-link -> #cd-main
PASS  A11Y_M1_MAIN_LANDMARK          theme/page.php: exactly one <main id="cd-main">
PASS  A11Y_M2_SKIP_LINK              theme/page.php: one .cd-skip-link -> #cd-main
PASS  A11Y_M2_SKIP_LINK_CSS          stage-compat.css: skip link is clipped until focused
PASS  A11Y_M3_MOBILE_NAV_LANDMARK    theme/public-homepage-body.html: mobile menu is a <nav> with an aria-label
PASS  A11Y_M3_MOBILE_NAV_LANDMARK    theme/partials/cd-page-header.php: mobile menu is a <nav> with an aria-label
PASS  A11Y_M4_MOBILE_ARIA_CURRENT    cd-page-header.php: the mobile nav loop emits aria-current
PASS  A11Y_M5_TOGGLE_STATE           homepage toggle ships aria-controls="cd-mobile-nav" and aria-expanded="false"
PASS  A11Y_M6_FILTER_ARIA_PRESSED    stage-interactions.js: paint() sets aria-pressed on the filter chips
PASS  A11Y_M7_MOBILE_LINK_TARGETS    public-homepage-body.html: all 8 mobile nav items resolve to distinct destinations
PASS  A11Y_D1_BLOG_FAQ_ROUTES        public-homepage-body.html: desktop header nav sends Blog -> /blog/ and FAQ -> /faq/
PASS  A11Y_D1_BLOG_FAQ_ROUTES        public-homepage-body.html: mobile header nav sends Blog -> /blog/ and FAQ -> /faq/
PASS  A11Y_D1_BLOG_FAQ_ROUTES        public-homepage-body.html: footer sends Blog -> /blog/ and FAQ -> /faq/
PASS  A11Y_L2_REDUCED_MOTION_CSS     stage-compat.css: reduced-motion covers .fade-in-up and .sticky-quote-bar
PASS  A11Y_L2_REDUCED_MOTION_JS      stage-interactions.js: the .fade-in-up path consults prefers-reduced-motion
PASS  A11Y_L3_FOCUS_RING_COVERAGE    stage-compat.css: the focus-visible outline covers input, textarea and select

SUMMARY  assertions=27  passed=27  failed=0
EXIT_CODE 0
```

## Test 3 — Funnel canonical/home URL

Command: `cd /home/hd2admin/campaign/core-distro-stage && node tests/funnel-canonical.mjs`

Exit status: 1

Private-origin routes passed; all twelve Funnel-origin route requests were refused (`ECONNREFUSED`). Actual output:

```text
# Core-Distro staging Funnel-origin canonical/home_url regression test
# private=http://100.106.6.22:8087
# funnel=https://brandon-compute.tailddbb4d.ts.net
# routes=12 per origin, method=GET only

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
FAIL  https://brandon-compute.tailddbb4d.ts.net /                              E_NETWORK                 https://brandon-compute.tailddbb4d.ts.net/: ECONNREFUSED
FAIL  https://brandon-compute.tailddbb4d.ts.net /products/                     E_NETWORK                 https://brandon-compute.tailddbb4d.ts.net/products/: ECONNREFUSED
FAIL  https://brandon-compute.tailddbb4d.ts.net /about/                        E_NETWORK                 https://brandon-compute.tailddbb4d.ts.net/about/: ECONNREFUSED
FAIL  https://brandon-compute.tailddbb4d.ts.net /compliance/                   E_NETWORK                 https://brandon-compute.tailddbb4d.ts.net/compliance/: ECONNREFUSED
FAIL  https://brandon-compute.tailddbb4d.ts.net /contact/                      E_NETWORK                 https://brandon-compute.tailddbb4d.ts.net/contact/: ECONNREFUSED
FAIL  https://brandon-compute.tailddbb4d.ts.net /resources/                    E_NETWORK                 https://brandon-compute.tailddbb4d.ts.net/resources/: ECONNREFUSED
FAIL  https://brandon-compute.tailddbb4d.ts.net /blog/                         E_NETWORK                 https://brandon-compute.tailddbb4d.ts.net/blog/: ECONNREFUSED
FAIL  https://brandon-compute.tailddbb4d.ts.net /faq/                          E_NETWORK                 https://brandon-compute.tailddbb4d.ts.net/faq/: ECONNREFUSED
FAIL  https://brandon-compute.tailddbb4d.ts.net /products/glass-vials/         E_NETWORK                 https://brandon-compute.tailddbb4d.ts.net/products/glass-vials/: ECONNREFUSED
FAIL  https://brandon-compute.tailddbb4d.ts.net /products/rubber-stoppers/     E_NETWORK                 https://brandon-compute.tailddbb4d.ts.net/products/rubber-stoppers/: ECONNREFUSED
FAIL  https://brandon-compute.tailddbb4d.ts.net /products/aluminum-seals/      E_NETWORK                 https://brandon-compute.tailddbb4d.ts.net/products/aluminum-seals/: ECONNREFUSED
FAIL  https://brandon-compute.tailddbb4d.ts.net /register/                     E_NETWORK                 https://brandon-compute.tailddbb4d.ts.net/register/: ECONNREFUSED

SUMMARY  origins=2  routes=12 per origin  total-checks=24  passed=12  failed=12  assertion-failures=12
  FAILED https://brandon-compute.tailddbb4d.ts.net / :: E_NETWORK
  FAILED https://brandon-compute.tailddbb4d.ts.net /products/ :: E_NETWORK
  FAILED https://brandon-compute.tailddbb4d.ts.net /about/ :: E_NETWORK
  FAILED https://brandon-compute.tailddbb4d.ts.net /compliance/ :: E_NETWORK
  FAILED https://brandon-compute.tailddbb4d.ts.net /contact/ :: E_NETWORK
  FAILED https://brandon-compute.tailddbb4d.ts.net /resources/ :: E_NETWORK
  FAILED https://brandon-compute.tailddbb4d.ts.net /blog/ :: E_NETWORK
  FAILED https://brandon-compute.tailddbb4d.ts.net /faq/ :: E_NETWORK
  FAILED https://brandon-compute.tailddbb4d.ts.net /products/glass-vials/ :: E_NETWORK
  FAILED https://brandon-compute.tailddbb4d.ts.net /products/rubber-stoppers/ :: E_NETWORK
  FAILED https://brandon-compute.tailddbb4d.ts.net /products/aluminum-seals/ :: E_NETWORK
  FAILED https://brandon-compute.tailddbb4d.ts.net /register/ :: E_NETWORK
EXIT_CODE 1
```

## Test 4 — head metadata

Command: `cd /home/hd2admin/campaign/core-distro-stage && node tests/head-metadata.mjs`

Exit status: 0

Output:

```text
# Core-Distro staging head-metadata regression test
# origin=http://100.106.6.22:8087 routes=12 method=GET only
# asserting exactly 1 robots meta + exactly 1 canonical link per route

PASS  /                              http=200 hops=0 robots=1 canonical=1 href="http://100.106.6.22:8087/"
PASS  /products/                     http=200 hops=0 robots=1 canonical=1 href="http://100.106.6.22:8087/products/"
PASS  /about/                        http=200 hops=0 robots=1 canonical=1 href="http://100.106.6.22:8087/about/"
PASS  /compliance/                   http=200 hops=0 robots=1 canonical=1 href="http://100.106.6.22:8087/compliance/"
PASS  /contact/                      http=200 hops=0 robots=1 canonical=1 href="http://100.106.6.22:8087/contact/"
PASS  /resources/                    http=200 hops=0 robots=1 canonical=1 href="http://100.106.6.22:8087/resources/"
PASS  /blog/                         http=200 hops=0 robots=1 canonical=1 href="http://100.106.6.22:8087/blog/"
PASS  /faq/                          http=200 hops=0 robots=1 canonical=1 href="http://100.106.6.22:8087/faq/"
PASS  /products/glass-vials/         http=200 hops=0 robots=1 canonical=1 href="http://100.106.6.22:8087/products/glass-vials/"
PASS  /products/rubber-stoppers/     http=200 hops=0 robots=1 canonical=1 href="http://100.106.6.22:8087/products/rubber-stoppers/"
PASS  /products/aluminum-seals/      http=200 hops=0 robots=1 canonical=1 href="http://100.106.6.22:8087/products/aluminum-seals/"
PASS  /register/                     http=200 hops=0 robots=1 canonical=1 href="http://100.106.6.22:8087/register/"

SUMMARY  routes=12  passed=12  failed=0  assertion-failures=0
EXIT_CODE 0
```

## Test 5 — homepage footer links

Command: `cd /home/hd2admin/campaign/core-distro-stage && node tests/homepage-footer-links.mjs`

Exit status: 0

Output:

```text
PASS  FOOTER_LINKS_001                    Footer element found
PASS  FOOTER_LINKS_002                    No dead fragment links in footer
PASS  FOOTER_LINKS_003                    Products -> /products/ (found)
PASS  FOOTER_LINKS_003                    About -> /about/ (found)
PASS  FOOTER_LINKS_003                    Compliance -> /compliance/ (found)
PASS  FOOTER_LINKS_003                    Contact -> /contact/ (found)

SUMMARY  assertions=6  passed=6  failed=0
EXIT_CODE 0
```

## Test 6 — WordPress page records

Command: `cd /home/hd2admin/campaign/core-distro-stage && node tests/wp-page-records.mjs`

Exit status: 1

The nine exact failing assertions identify published, routable seed-owned page duplicates:

```text
FAIL  E_PUBLISHED_SEED_DUPLICATE id=24 slug="glass-vials-2" (/products/glass-vials-2/) is a published seed-owned page outside the 12-route manifest and is routable as a duplicate
FAIL  E_PUBLISHED_SEED_DUPLICATE id=25 slug="rubber-stoppers-2" (/products/rubber-stoppers-2/) is a published seed-owned page outside the 12-route manifest and is routable as a duplicate
FAIL  E_PUBLISHED_SEED_DUPLICATE id=26 slug="aluminum-seals-2" (/products/aluminum-seals-2/) is a published seed-owned page outside the 12-route manifest and is routable as a duplicate
FAIL  E_PUBLISHED_SEED_DUPLICATE id=35 slug="glass-vials-3" (/products/glass-vials-3/) is a published seed-owned page outside the 12-route manifest and is routable as a duplicate
FAIL  E_PUBLISHED_SEED_DUPLICATE id=36 slug="rubber-stoppers-3" (/products/rubber-stoppers-3/) is a published seed-owned page outside the 12-route manifest and is routable as a duplicate
FAIL  E_PUBLISHED_SEED_DUPLICATE id=37 slug="aluminum-seals-3" (/products/aluminum-seals-3/) is a published seed-owned page outside the 12-route manifest and is routable as a duplicate
FAIL  E_PUBLISHED_SEED_DUPLICATE id=46 slug="glass-vials-4" (/products/glass-vials-4/) is a published seed-owned page outside the 12-route manifest and is routable as a duplicate
FAIL  E_PUBLISHED_SEED_DUPLICATE id=47 slug="rubber-stoppers-4" (/products/rubber-stoppers-4/) is a published seed-owned page outside the 12-route manifest and is routable as a duplicate
FAIL  E_PUBLISHED_SEED_DUPLICATE id=48 slug="aluminum-seals-4" (/products/aluminum-seals-4/) is a published seed-owned page outside the 12-route manifest and is routable as a duplicate
```

Other output recorded all 25 page rows and these configuration values:

```text
show_on_front=page  page_on_front=4  permalinks="/%postname%/"
primary menu: Primary Navigation (8 items)
```

The test emitted a `DRAIN` notice listing those same nine IDs and suggested commands, but neither suggested command was run. Final output:

```text
SUMMARY  assertions-failures=9  EXIT_CODE 1
```

## Test 7 — asset origins

Command: `cd /home/hd2admin/campaign/core-distro-stage && node tests/asset-origins.mjs`

Exit status: 1

Private-origin assets passed. The Funnel origin was unreachable with `ECONNREFUSED`:

```text
# Core-Distro staging asset-origin regression test
# private=http://100.106.6.22:8087
# funnel=https://brandon-compute.tailddbb4d.ts.net
# method=GET only; asserts correct scheme+host and HTTP 200 per asset

PASS  http://100.106.6.22:8087               private: 14 app asset URL(s) all on http://100.106.6.22:8087
PASS  http://100.106.6.22:8087               private: all 14 app asset(s) returned HTTP 200
FAIL  https://brandon-compute.tailddbb4d.ts.net E_ORIGIN_UNREACHABLE   funnel: ECONNREFUSED

SUMMARY  origins=2  passed=1  failed=1  assertion-failures=1
  FAILED https://brandon-compute.tailddbb4d.ts.net
    - E_ORIGIN_UNREACHABLE:funnel: ECONNREFUSED
EXIT_CODE 1
```

## Test 8 — Lighthouse remediation

Command: `cd /home/hd2admin/campaign/core-distro-stage && node tests/lighthouse-remediation.mjs`

Exit status: 0

Output:

```text
PASS HOME_METRIC_CONTRAST_SOURCE: homepage metric labels no longer use the Lighthouse-failing green
PASS HOME_FOOTER_HEADING_LEVEL: homepage footer headings do not skip from the page heading outline to h4
PASS SHARED_FOOTER_HEADING_LEVEL: shared page footer uses sequential section headings
PASS NO_NESTED_INTERACTIVE_PRODUCTS: build/pages/products.html contains no <a><button> nesting
PASS BALANCED_TAGS_PRODUCTS: build/pages/products.html has matching non-void opening/closing tags
PASS NO_NESTED_INTERACTIVE_ABOUT: build/pages/about.html contains no <a><button> nesting
PASS BALANCED_TAGS_ABOUT: build/pages/about.html has matching non-void opening/closing tags
PASS NO_NESTED_INTERACTIVE_COMPLIANCE: build/pages/compliance.html contains no <a><button> nesting
PASS BALANCED_TAGS_COMPLIANCE: build/pages/compliance.html has matching non-void opening/closing tags
PASS NO_NESTED_INTERACTIVE_CONTACT: build/pages/contact.html contains no <a><button> nesting
PASS BALANCED_TAGS_CONTACT: build/pages/contact.html has matching non-void opening/closing tags
PASS HEADING_ORDER_CONTACT: build/pages/contact.html has no skipped heading level
PASS NO_NESTED_INTERACTIVE_RESOURCES: build/pages/resources.html contains no <a><button> nesting
PASS BALANCED_TAGS_RESOURCES: build/pages/resources.html has matching non-void opening/closing tags
PASS HEADING_ORDER_RESOURCES: build/pages/resources.html has no skipped heading level
PASS NO_NESTED_INTERACTIVE_BLOG: build/pages/blog.html contains no <a><button> nesting
PASS BALANCED_TAGS_BLOG: build/pages/blog.html has matching non-void opening/closing tags
PASS HEADING_ORDER_BLOG: build/pages/blog.html has no skipped heading level
PASS NO_NESTED_INTERACTIVE_FAQ: build/pages/faq.html contains no <a><button> nesting
PASS BALANCED_TAGS_FAQ: build/pages/faq.html has matching non-void opening/closing tags
PASS NO_NESTED_INTERACTIVE_GLASS-VIALS: build/pages/glass-vials.html contains no <a><button> nesting
PASS BALANCED_TAGS_GLASS-VIALS: build/pages/glass-vials.html has matching non-void opening/closing tags
PASS NO_NESTED_INTERACTIVE_RUBBER-STOPPERS: build/pages/rubber-stoppers.html contains no <a><button> nesting
PASS BALANCED_TAGS_RUBBER-STOPPERS: build/pages/rubber-stoppers.html has matching non-void opening/closing tags
PASS NO_NESTED_INTERACTIVE_ALUMINUM-SEALS: build/pages/aluminum-seals.html contains no <a><button> nesting
PASS BALANCED_TAGS_ALUMINUM-SEALS: build/pages/aluminum-seals.html has matching non-void opening/closing tags
PASS NO_NESTED_INTERACTIVE_REGISTER: build/pages/register.html contains no <a><button> nesting
PASS BALANCED_TAGS_REGISTER: build/pages/register.html has matching non-void opening/closing tags
PASS PRODUCTS_VIDEO_LOCAL_ASSETS: products content does not request the unavailable MP4 or root-relative poster
PASS PRODUCTS_CARD_CONTRAST: product card labels receive a light foreground on their dark surface
PASS RENDER_FIX_HELPER: a tested render-time helper exists for existing private staging page records
PASS RENDER_FIX_HOOK: the private staging theme applies the content fixes without writing page records
PASS ASTRA_SCROLL_FLAG: Astra scroll-to-top localization is disabled where its markup is intentionally absent
PASS ROUTE_CONTRAST_OVERRIDES: contrast fixes are scoped to the affected staging routes

SUMMARY passed=34 failed=0
```

## Test 9 — Lighthouse content-fix PHP tests

Command: `cd /home/hd2admin/campaign/core-distro-stage && php tests/lighthouse-content-fixes.php`

Exit status: 0

Output:

```text
PASS actual wpautop product card stays inside one named link
PASS product card paragraph boundary is balanced
PASS optional leading wpautop paragraph is removed without imbalance
PASS nested disabled CTA button becomes one named navigational link
PASS missing product video source is removed
PASS unclosed product video is explicitly closed before overlay content
PASS product poster is rewritten to the local staged asset
PASS breadcrumb nav receives its missing closing tag
PASS contact heading level is corrected without changing its wording
PASS contact card text stays inside its named phone link
PASS contact renderer emits no empty phone link after paragraph repair
PASS contact low-contrast text color is corrected
PASS contact duplicate textarea closer is removed
PASS resources inert PDF closer is repaired
PASS already-correct inert span leaves the following CTA close intact
PASS resources repair is idempotent on correct generated content and preserves its CTA
PASS render helper preserves balanced about source fragment
PASS render helper preserves balanced aluminum-seals source fragment
PASS render helper preserves balanced blog source fragment
PASS render helper preserves balanced compliance source fragment
PASS render helper preserves balanced contact source fragment
PASS render helper preserves balanced faq source fragment
PASS render helper preserves balanced glass-vials source fragment
PASS render helper preserves balanced products source fragment
PASS render helper preserves balanced register source fragment
PASS render helper preserves balanced resources source fragment
PASS render helper preserves balanced rubber-stoppers source fragment
PASS blog section heading is sequential
PASS blog helper text has the audited readable color
PASS resources heading level is sequential
PASS register helper text has the audited readable color
PASS unrelated route content is left unchanged
PASS homepage disables only Astra scroll-to-top
PASS other pages retain Astra scroll-to-top setting
PASS closed drawer overlay receives inert and aria-hidden
PASS drawer exclusion attributes are applied exactly once
PASS closed drawer markup and links are preserved, not stripped
PASS header breadcrumb nav is left unchanged by the drawer fix
PASS unrelated overlay elements are left unchanged
PASS drawer fix preserves authored body copy verbatim
PASS drawer fix does not mutate its input string
PASS drawer exclusion is idempotent across repeated render passes
PASS open drawer panel receives no focus exclusion
PASS canonical about fragment excludes its closed drawer exactly once
PASS canonical about differs from stored content only by the drawer exclusion
PASS canonical aluminum-seals fragment excludes its closed drawer exactly once
PASS canonical aluminum-seals differs from stored content only by the drawer exclusion
PASS canonical blog fragment excludes its closed drawer exactly once
PASS canonical blog keeps its stored anchor and heading content
PASS canonical compliance fragment excludes its closed drawer exactly once
PASS canonical compliance differs from stored content only by the drawer exclusion
PASS canonical contact fragment excludes its closed drawer exactly once
PASS canonical contact keeps its stored anchor and heading content
PASS canonical faq fragment excludes its closed drawer exactly once
PASS canonical faq differs from stored content only by the drawer exclusion
PASS canonical glass-vials fragment excludes its closed drawer exactly once
PASS canonical glass-vials differs from stored content only by the drawer exclusion
PASS canonical products fragment excludes its closed drawer exactly once
PASS canonical products keeps its stored anchor and heading content
PASS canonical register fragment excludes its closed drawer exactly once
PASS canonical register keeps its stored anchor and heading content
PASS canonical resources fragment excludes its closed drawer exactly once
PASS canonical resources keeps its stored anchor and heading content
PASS canonical rubber-stoppers fragment excludes its closed drawer exactly once
PASS canonical rubber-stoppers differs from stored content only by the drawer exclusion
PASS protected duplicate route glass-vials-2 receives no new drawer transform
PASS protected duplicate route rubber-stoppers-2 receives no new drawer transform
PASS protected duplicate route aluminum-seals-2 receives no new drawer transform
PASS protected duplicate route glass-vials-3 receives no new drawer transform
PASS protected duplicate route rubber-stoppers-3 receives no new drawer transform
PASS protected duplicate route aluminum-seals-3 receives no new drawer transform
PASS protected duplicate route glass-vials-4 receives no new drawer transform
PASS protected duplicate route rubber-stoppers-4 receives no new drawer transform
PASS protected duplicate route aluminum-seals-4 receives no new drawer transform
PASS unrelated hidden fixed overlay is not excluded in place of the drawer
PASS substring class match does not trigger the drawer exclusion

SUMMARY failures=0
```

## Test 10 — Lighthouse extractor Python tests

Command: `cd /home/hd2admin/campaign/core-distro-stage && python3 tests/test_extract_lighthouse_fixes.py`

Exit status: 0

Output:

```text
test_button_inside_link_becomes_one_styled_link (__main__.LighthouseMarkupFixesTest.test_button_inside_link_becomes_one_styled_link) ... ok
test_extract_pipeline_emits_balanced_inert_markup (__main__.LighthouseMarkupFixesTest.test_extract_pipeline_emits_balanced_inert_markup) ... ok
test_pdf_neutralization_replaces_the_complete_link (__main__.LighthouseMarkupFixesTest.test_pdf_neutralization_replaces_the_complete_link) ... ok
test_product_media_and_empty_links_are_local_or_removed (__main__.LighthouseMarkupFixesTest.test_product_media_and_empty_links_are_local_or_removed) ... ok
test_route_heading_and_contrast_fixes_preserve_words (__main__.LighthouseMarkupFixesTest.test_route_heading_and_contrast_fixes_preserve_words) ... ok
test_textarea_is_emitted_once_and_source_text_is_not_exposed (__main__.LighthouseMarkupFixesTest.test_textarea_is_emitted_once_and_source_text_is_not_exposed) ... ok
test_verifier_rejects_nested_and_empty_links (__main__.LighthouseMarkupFixesTest.test_verifier_rejects_nested_and_empty_links) ... ok
test_verifier_rejects_unbalanced_tags (__main__.LighthouseMarkupFixesTest.test_verifier_rejects_unbalanced_tags) ... ok

----------------------------------------------------------------------
Ran 8 tests in 0.005s

OK
```

## Separate visual review

The test-plan's screenshot/visual review was not run. It is not one of the ten tests listed for this baseline; no screenshot was captured, so there is no current visual-match result.
