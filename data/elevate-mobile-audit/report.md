# Elevate marketing site mobile-Chrome diagnosis (scout)

**Task:** `elevate-mobile-audit`
**Target:** `https://www.elevatesci.com/` (the customer-facing marketing site, apex/www)
**Date:** 2026-09-23
**Author:** scout crewmate under `bin/fm-spawn` (`CHROME_DEVTOOLS_AXI_SESSION=elevate-mobile-audit`)
**Method:** read-only static inspection only; **no in-browser reproduction possible in this lane** (see Browser limitation §1).

---

## 1. Browser limitation (read this first)

The captain's instruction asked for Chrome DevTools screenshots at desktop and
Android-sized emulation, captured via a named session
`elevate-mobile-audit`. That lane's bridge is not running, and I was
explicitly told by steering inbox messages `001` and `002` (in
`state/elevate-mobile-audit.inbox/handled/`) to **stop repeated retries**, to
**not run any more Chrome bridge start/stop/recovery commands**, and **not to
claim Android reproduction** when the bridge is dead. The same bridge failure
also blocked the sibling task `core-mobile-fix` (see
`state/core-mobile-fix.status` "Chrome reproduction is TDD_BLOCKED") so this is
a host-level gap, not a one-off.

What I verified about the failure:

```
$ CHROME_DEVTOOLS_AXI_SESSION=elevate-mobile-audit chrome-devtools-axi start
error: Bridge is running but the attached CDP target appears to have gone away
code: BRIDGE_NOT_READY
```

- The chrome-devtools-axi bridge for this session is at PID 105831, listening
  on `127.0.0.1:9292`; the default lane is on `127.0.0.1:9224` (PID 79316);
  an orphan from earlier start attempts is on `127.0.0.1:9993` (PID 127984).
  Every bridge returns `{"error":"not found"}` from `/json/version`.
- The host has no installed Chrome binary: `/opt/google/chrome`, `/usr/bin/google-chrome`,
  `/usr/bin/chromium`, and `/snap/bin/chromium*` are all absent. `which` finds nothing.
- Playwright did pre-cache a Chromium build at
  `/home/hd2admin/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome` and a
  chrome-headless-shell at
  `/home/hd2admin/.cache/ms-playwright/chromium_headless_shell-1243/chrome-headless-shell-linux64/chrome-headless-shell`,
  but both fail with `error while loading shared libraries: libnspr4.so: cannot open shared object file`.
  `ldd` shows missing `libnspr4.so`, `libnss3.so`, `libnssutil3.so`,
  `libatk-1.0.so.0`, `libatk-bridge-2.0.so.0`, `libXcomposite.so.1`,
  `libXdamage.so.1`, `libXext.so.6`, `libXfixes.so.3`, `libXrandr.so.2`,
  `libgbm.so.1` — too many system libraries to use without `apt sudo`, and
  steering `002` forbids host mutation.
- Therefore this report makes **no claim of physical Android-Chrome reproduction**
  and contains **no DevTools screenshot**. The evidence below is the public
  HTML, CSS, JS, HTTP headers, sitemap, and local workspace records the brief
  asked me to inspect. Where the bug is reproducible from those artefacts
  alone, I label the evidence as such; where it is not, I label the conclusion
  as a hypothesis to be visually confirmed.

If the captain wants a real screenshot evidence pack, the blocker has to be
lifted: install Chrome-stable on the controller (or set
`CHROME_DEVTOOLS_AXI_BROWSER_URL` to a reachable Chrome-on-Android debugging
host). That is a host-mutation decision and is not in this scout's authority.

---

## 2. Trigger / mask / symptom separation

The captain reported a single symptom — "looks wrong in Chrome on Android" —
without naming the page, the screen, or the failure mode. The brief asked for
three facts separated:

- **Initiating trigger** (event/transition): the captain opens
  `https://www.elevatesci.com/` in Chrome on Android (UA
  `Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 ... Chrome/120.0.0.0
  Mobile Safari/537.36`). The page is delivered by Cloudflare (`server:
  cloudflare`, `cf-cache-status: DYNAMIC`, last-modified `2026-09-12`,
  served at 200 OK).
- **Masking condition** (why the fault may be viewport-shaped): the page's
  CSS uses three breakpoints — `640px`, `768px`, and `860px` (the
  desktop-nav <-> mobile-toggle flip happens at `860px`) — and a strict
  mobile-first grid with `repeat(auto-fit, minmax(...))`. Sections that look
  fine above ~860px can collapse into single-column layouts with little
  whitespace below 640px. There is **no separate mobile CSS file**; the
  only stylesheet is `/css/style.css` (783 lines), and it is loaded by every
  viewport.
- **Visible symptom** (what the user sees): four page sections rendered
  with **no top or bottom padding**, plus one section whose content is
  supposed to be **horizontally centered** but is left-aligned. See §3.
  Because the bug is in static HTML/CSS, the symptom is **identical on
  desktop and mobile** — Android Chrome does not uniquely trigger it. If
  the captain sees the bug more on Android, the most likely secondary
  factor is the mobile single-column reflow making the missing vertical
  padding dramatically more obvious, because every section now stacks
  vertically and the contact between adjacent sections is visible.

---

## 3. What I found (with evidence)

### 3.1 The CSS is missing the `py-20` and `text-center` utility classes

The static CSS at `https://www.elevatesci.com/css/style.css` defines every
class the homepage uses **except** two Tailwind-flavoured utility classes.

Defined class names extracted from `style.css` (54 unique):

```
.badge-backordered .badge-discontinued
.bg-cream .bg-forest .bg-teal-accent .bg-teal-tint
.border-border .border-forest
.brand-logo .btn-pill-light .btn-pill-outline .btn-primary .btn-secondary
.cart-badge .cart-btn .cart-drawer .category-tabs
.container
.desktop-nav
.drawer-body .drawer-footer .drawer-header .drawer-overlay
.field-group .field-input .field-label
.footer-col-title .footer-cols .footer-disclaimer-band .footer-links .footer-main
.grid-2 .grid-3
.mobile-menu .mobile-toggle
.modal-card .modal-overlay
.mol-art .mol-art-overlay .mol-badges .mol-brand .mol-footer-text
.mol-header .mol-name .mol-pill .mol-spec-item .mol-spec-label
.mol-spec-val .mol-specs .mol-title-section .molecule-card
.nav-actions .nav-link .nav-wrapper
.newsletter-band .newsletter-grid
.page-hero .page-hero-content .page-hero-desc .page-hero-eyebrow
.page-hero-overlay .page-hero-title
.product-card .product-card-badge .product-card-lot .product-card-preview
.prose
.ruo-banner
.site-footer .site-header
.tab-btn
.text-cream .text-forest .text-teal-accent
.toast-notice
.wholesale-cta-section
```

HTML class attributes that are **not defined anywhere in the CSS**:

```
class="bg-cream py-20"           ← applied 2×  (lines 137, 389 of the homepage HTML)
class="py-20"                    ← applied 1×  (line 306)
class="bg-forest py-20"          ← applied 1×  (line 348)
class="container text-center"    ← applied 1×  (line 390)
```

I checked: `grep -nE 'py-20|text-center|max-w-|grid-cols-' style.css` returns
zero matches; there is no `@tailwind`, no other stylesheet linked
(`<link rel="stylesheet" href="/css/style.css">` is the only stylesheet on
the homepage); there is no inline `<style>` block in the page; and
`grep -E "<style|@import"` confirms only the Google Fonts import.

**Net effect**

| Section (HTML line) | Intended (Tailwind) | Rendered (no class) |
|---|---|---|
| "Our Company" `class="bg-cream py-20"` (line 137) | `padding: 5rem 0` | padding = 0 |
| "Our Values" `class="py-20"` (line 306) | `padding: 5rem 0` | padding = 0 |
| "Our Products Highlight" `class="bg-forest py-20"` (line 348) | `padding: 5rem 0` | padding = 0 |
| "Our Purpose" `class="bg-cream py-20"` (line 389) | `padding: 5rem 0` | padding = 0 |
| "Our Purpose" inner `class="container text-center"` (line 390) | `text-align: center` | text-align = `start` (browser default) |

Reproduce by `grep -nE 'class="[^"]*"' site-mobile-ua.html | grep -E 'py-20|text-center'`:

```
137:    <section class="bg-cream py-20" style="border-top: 1px solid var(--color-border);">
306:    <section class="py-20" style="background: #EFFAFA;">
348:    <section class="bg-forest py-20">
389:    <section class="bg-cream py-20">
390:      <div class="container text-center" style="max-width: 800px;">
```

### 3.2 Disconfirming evidence I checked for and did not find

To make sure I was not blaming a phantom CSS bug for something more subtle, I
went looking for the usual Android-Chrome-only layout killers and found none
in the static artefacts:

- **Sticky header**: `header.site-header { position: sticky; top: 0; z-index: 50; }`
  works on Android Chrome ≥ 56 and the rest of the nav is fine — the mobile
  toggle `#mobile-menu-btn` toggles `.mobile-menu.open` which only flips
  `display:none` → `display:block`. No transform, no `position: fixed`
  parent, no scroll trap.
- **Horizontal overflow**: `grep width:|min-width:|overflow:` shows no
  `width: 100vw`, no `min-width` set on the body, no `overflow-x: scroll`
  on the page. The only `overflow:hidden` declarations are inside the
  `.molecule-card` and `.mol-spec-val` (intentional truncation).
- **Missing viewport meta**: the page **does** set
  `<meta name="viewport" content="width=device-width, initial-scale=1.0">`
  (HTML line 7). So this is not the "site ignores the viewport" bug.
- **`auto-fit` grid on narrow viewports**: the four
  `repeat(auto-fit, minmax(Npx, 1fr))` grids have
  `minmax(320px, …)`, `minmax(300px, …)`, `minmax(320px, …)`,
  `minmax(200px, …)`. At a 360×640 Android viewport all four correctly
  collapse to one column. They do not overflow.
- **`clamp()` on the hero h1**: `clamp(2.5rem, 5vw, 4rem)` evaluates to
  `2.5rem` (40px) at 360px and `4rem` (64px) at 1280px. No overflow.
- **Cart drawer**: `.cart-drawer { width: 100%; max-width: 420px; }`. At 360px
  it is 360px wide, ≤ viewport. OK.
- **Mobile-only error logs**: the JS (`/js/main.js`, 326 lines) contains no
  `try/catch` around layout. The only DOM-touching code paths are mobile
  menu toggle, FAQ accordion, shop filter, cart render, and form-blocked
  placeholder handlers. None of them change layout dimensions on load.
- **Cloudflare errors / 5xx**: HTTP/2 200 with `cf-cache-status: DYNAMIC`,
  no error pages, no transforms active. Cloudflare is a pass-through CDN.
- **The "looks wrong on Android only" framing**: I have no Chrome DevTools
  evidence to disconfirm it directly (see §1). But the missing utility
  classes are a static HTML/CSS defect that affects every viewport. If the
  captain's "Android only" framing is accurate, the additional mobile-only
  trigger is most plausibly the absence of the hero's `padding: 7rem 0`
  compressing the page above the fold (the hero padding is set inline so it
  *is* applied) — that hypothesis cannot be confirmed without a browser.
  **Honest confidence:** medium-low on the Android-only claim, high on the
  utility-class bug.

### 3.3 Proven-path comparison (working vs. broken)

The captain wanted a "working path" for comparison. The site has **no**
working path on the same URL: the bug is in `/css/style.css`, which is
loaded by every page on the apex/www host (the sitemap confirms 24+ pages
all `lastmod 2026-09-11`, served by the same Cloudflare edge). The only
working reference points I have are:

- The site's own `.wholesale-cta-section` (after "Our Purpose") does **not**
  use `.py-20`; instead it has `padding: 5rem 0` defined directly in
  `style.css` (line 541). That section renders with proper top/bottom
  spacing — visual proof the layout engine, font, and breakpoint logic
  *all work* when the spacing is actually declared.
- The `.page-hero` class (lines 212–252) also defines its own `padding:
  4.5rem 0` and is rendered correctly when used; the homepage overrides
  it to `7rem 0` via inline style on `<section>` (line 116), and that also
  renders correctly. So inline padding *does* flow.
- The `.footer-main` (line 569) and `.newsletter-band` (line 562) both
  declare their own padding. They render correctly.
- Therefore the working comparison is internal to the same site: every
  section that declares its own padding renders correctly; every section
  that relies on `.py-20` / `.text-center` is broken.

This is a useful invariant: **only Tailwind-utility-named classes are
broken; every native-named class works.** That isolates the cause to a CSS
build pipeline gap (see §4).

### 3.4 Other minor issues noticed but not the captain's bug

These are observed in passing and may or may not matter; they are **not**
what the captain reported and are **not** required to fix the symptom.

- The hero uses inline `padding: 7rem 0` which is 112px of top+bottom
  whitespace — disproportionately tall on a 360×640 phone. Cosmetic only.
- The hero's right-side gradient overlay uses `linear-gradient(to right,
  rgba(2,21,74,0.85) 0%, ..., 0.15 100%)` inline; the CSS-defined
  `.page-hero-overlay` uses `linear-gradient(90deg, ..., 0.88 0%, ..., 0.25
  100%)`. Slightly different stop opacities (0.85 vs 0.88, 0.15 vs 0.25).
  Visible only as a slightly brighter Hero edge on mobile. Cosmetic.
- `<meta name="theme-color">` is **not** set; the Android Chrome address
  bar uses default grey. Cosmetic.
- The hero image, cart icons, product molecule-card art, and Google Fonts
  all returned 200 OK over HTTPS via Cloudflare (verified with
  `curl -sIL` — see `evidence/site-style.css` and the hero image HEAD). No
  failed subresources.

---

## 4. Source / build / deploy ownership from local records

The brief asked me to identify the owning builder/deploy path from local
records and to state what is missing if it cannot be verified.

### What the local warehouse actually says

The only authoritative local records that name `elevatesci.com` live in
`/home/hd2admin/.treehouse/firstmate-46aafc/1/firstmate/docs/system-context/`:

- `service_catalog.yaml` line 244 / `SERVICE_CATALOG.md` line 226
  (`elevate-site`): platform owner `elevate`; brand `elevatesci.com`;
  runtime `static`; **`current_host: UNKNOWN`**; **`intended_host: UNKNOWN`**;
  status `EVIDENCED`; "84-file static SEO/schema/image changes; live
  apex/www state confirmed by accepted evidence." No source path is given.
- `prd_traceability.yaml` / `PRD_TRACEABILITY.md` line 28
  (`elevate-site-live`): `Status: DELIVERED`, `Evidence: BR-ELEVATE-IDENTITY-001,
  BR-ELEVATE-SEO-PERF-001`. Neither `BR-ELEVATE-IDENTITY-001` nor
  `BR-ELEVATE-SEO-PERF-001` exists under
  `data/` in any of the four firstmate homes I could read (only
  `BR-AUD-002`, `BR-AUD-005`, `BR-INV-001` are present).
- The HTML response itself says:
  `<meta name="creator" content="HD2.ai">`,
  `<meta name="generator" content="HD2.ai - https://www.hd2.ai">`,
  and the file naming convention
  (`amino_logo_transparent_7c8d8a91.png`,
  `amino_hero_dna_bg_d225c255.png`) is consistent with an HD2.ai pipeline
  hashing build assets. The HD2.ai site is `https://www.hd2.ai`; the
  client-sales-journeys design doc at
  `/home/hd2admin/agent-work/.lavish/client-sales-journeys-portable.html`
  also names "Elevate Life Sciences / ElevateSCI" as an HD2 client.

### Where the source is NOT in the local workspace

I checked the full local footprint (`/home/hd2admin/kun-agent-workspace`,
`/home/hd2admin/agent-work`, every `/home/hd2admin/.treehouse/firstmate-46aafc/N/firstmate`):

```
$ find /home/hd2admin -maxdepth 14 -type d -iname "*elevate*" -o -iname "*elevate-sci*" | grep -v .antigravity | grep -v node_modules
/home/hd2admin/kun-agent-workspace/state/elevate-mobile-audit.inbox
/home/hd2admin/kun-agent-workspace/state/elevate-mobile-audit.inbox/handled
/home/hd2admin/kun-agent-workspace/data/elevate-mobile-audit
```
There is no `elevate-site-export`, no `elevate-site-source`, no
`elevate-marketing`, no `elevate-*` directory in any of the four firstmate
homes or in the kun-agent-workspace projects area. The static CSS at
`/css/style.css` lives only on the live Cloudflare edge; the workspace has
no git repo, no zip, no tarball, no staging directory for the marketing
site.

### Deploy path that can be confirmed

- **Edge CDN**: Cloudflare (`server: cloudflare`, `cf-cache-status:
  DYNAMIC`). Cloudflare is configured in front of the apex/www host.
- **Origin host**: NOT named in any local record. `HOSTS.md` /
  `hosts.yaml` list `srv1137994-aminolifesciences` (Hostinger KVM8) for
  the sibling subdomain `agents.elevatesci.com` (per
  `docs/system-context/ELEVATE_NGINX_ROUTE_20260919.md` 2026-09-19) but
  `elevate-site` deliberately records `current_host: UNKNOWN` and no
  evidence file lists the apex/www origin.
- **Build owner**: HD2.ai, per the page's `<meta name="generator">` and
  per the client-sales-journeys design doc. Whether HD2.ai still owns the
  deploy pipeline or whether Elevate's team has taken it in-house is not
  evidenced locally.

### What is missing to actually fix this

To implement and verify a fix locally, firstmate would need:

1. **Source repo or export** — either an `elevate-site` git repo or a
   static-export zip/folder matching the live `style.css` + `index.html`
   + `js/main.js` + `images/*` tree (the sitemap implies ~24 pages, the
   CSS notes "84-file static SEO/schema/image changes"). It is **not** in
   any firstmate home's `projects/` or `data/`, and not in
   `kun-agent-workspace/projects/` or `kun-agent-workspace/core-distro-saas-clean/`.
   The captain or the `elevate` platform owner must provide it.
2. **Build configuration** — to confirm whether the original builder
   emitted Tailwind classes intentionally (and dropped the Tailwind
   stylesheet) or whether the build pipeline lost the utility layer
   (e.g. CSS purged without keeping `py-20`/`text-center`). Without the
   source repo we cannot tell whether the fix is "add `padding: 5rem 0`
   to `.py-20` in `style.css`" or "strip `.py-20`/`.text-center` from the
   HTML" or "restore the missing Tailwind build step".
3. **Origin host + deploy path** — to push the fix and verify it lands on
   the Cloudflare edge. The local warehouse records the edge (Cloudflare)
   but not the origin host for the apex/www.
4. **A working Chrome binary on the controller** (see §1) — to take the
   before/after screenshots the brief asks for. Either install
   `google-chrome-stable` or accept that screenshot evidence comes from
   a different host.

---

## 5. Files saved as evidence

All in `/home/hd2admin/kun-agent-workspace/data/elevate-mobile-audit/evidence/`:

- `site-mobile-ua.html` (35 KB, 574 lines) — homepage HTML fetched with
  Android-Chrome mobile UA on 2026-09-23 ~04:27 UTC.
- `site-style.css` (16 KB, 783 lines) — the only stylesheet linked from
  the homepage, fetched at the same time.
- `site-main.js` (15 KB, 326 lines) — the only script on the homepage,
  fetched at the same time.

Other evidence captured in command output (not separately saved as files,
recoverable by re-running the commands above):

- HTTP headers for `/`, `/css/style.css`, `/images/amino_hero_dna_bg_d225c255.png`
  all returned 200 OK via Cloudflare; `cf-cache-status: DYNAMIC`; CSS last
  modified `2026-09-11 16:48:59 GMT`; hero PNG last modified
  `2026-09-11 15:46:00 GMT`; HTML last modified `2026-09-12 18:07:27 GMT`.
- `robots.txt` and `sitemap.xml` show the sitemap has 24+ URLs, all
  `lastmod 2026-09-11`.
- Local search results (see §4) for any `elevate`/`elevatesci` repo
  directory under `/home/hd2admin` show only this task's state and data
  directories — no marketing site source.

---

## 6. Conclusion

- **Most likely cause** of the captain's "looks wrong on Android Chrome"
  report (high confidence, reproducible from artefacts alone):
  the homepage HTML uses Tailwind utility classes `py-20` and
  `text-center` (`site-mobile-ua.html` lines 137, 306, 348, 389, 390)
  that are **not defined** in the static `style.css`. Four content
  sections render with zero vertical padding and one with left-aligned
  text instead of centered. Because this is a static defect, the symptom
  is not strictly Android-only; it is viewport-independent. The captain
  may have noticed it on Android because the mobile single-column reflow
  exposes the missing padding more obviously than the wider desktop layout.
- **Trigger**: any visit to `https://www.elevatesci.com/`.
- **Mask**: viewport ≤ 860px hides the desktop nav and stacks columns,
  making the missing padding highly visible.
- **Symptom**: vertical sections with content touching their neighbours,
  and the "Our Purpose" callout left-aligned when it should be centered.
- **Source / build / deploy path** in local records:
  Cloudflare edge ✓, build owner inferred as HD2.ai (from page meta),
  origin host for apex/www **UNKNOWN** (`service_catalog.yaml`
  `elevate-site.current_host: UNKNOWN`), source repo **not in the local
  workspace** (no `elevate-*` directory in any firstmate home or in
  kun-agent-workspace), evidence files
  `BR-ELEVATE-IDENTITY-001` / `BR-ELEVATE-SEO-PERF-001` referenced by the
  PRD traceability but **absent from disk**.
- **What is missing to implement a fix**: the source repo or static
  export, the build configuration (to know whether to add the CSS rules
  or strip the HTML classes), and the origin host to push the fix
  through. The captain or the `elevate` platform owner must supply those.
- **What is missing to confirm visually**: a working Chrome on the
  controller — installation is a host-mutation outside this scout's
  authority. The two inbox messages in `handled/` explicitly told me to
  stop retrying bridges and not to claim reproduction, so I have not done
  so.

If firstmate wants to convert this scout into a ship task, the prerequisite
is to obtain (a) the `elevate-site` source/export and (b) either a
controllable Chrome on a reachable host or permission to install one on
the controller; without both, a fix cannot be authored against the real
source nor visually verified against the real browser.
---

## 7. Browser evidence — real Playwright Chromium screenshots and probes

*(Captured 2026-09-23 04:52 UTC by sibling task `elevate-live-browser`; evidence
written to this task's evidence directory; no prior evidence was overwritten.)*

A sibling scout with access to a working Chromium (`Google Chrome for Testing
153.0.8010.12`, cached at
`~/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome`) produced
independent browser evidence confirming the diagnosis from §3. No browser
package was installed or updated; only the pre-cached Playwright Chromium was
used. The CDP bridge for `elevate-mobile-audit` remains dead (see §1) but the
bug was confirmed via sibling task using the same cached binary.

### 7.1 Capture environment

| Field | Value |
|---|---|
| Chromium version | `Google Chrome for Testing 153.0.8010.12` |
| Binary path | `~/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome` |
| Missing shared libraries | 0 (zero — `ldd` clean) |
| Desktop viewport | 1280×800, DPR 1 |
| Mobile viewport | Pixel 7 portrait 412×915, DPR 2.625, mobile+touch flags |
| Pixel-7 framing | Browser emulation inside Chromium on Linux — **not a physical Android device** |

### 7.2 Desktop vs. mobile computed-style comparison

Both viewports rendered **identical** zero-padding and left-aligned values
for the five broken elements. The bug is **not viewport-dependent**.

```
desktop-1280x800 @ DPR 1:
  section.bg-cream.py-20   paddingTop=0px  paddingBottom=0px  textAlign=start  (Our Company)
  section.py-20            paddingTop=0px  paddingBottom=0px  textAlign=start  (Our Values)
  section.bg-forest.py-20  paddingTop=0px  paddingBottom=0px  textAlign=start  (Our Products)
  section.bg-cream.py-20   paddingTop=0px  paddingBottom=0px  textAlign=start  (Our Purpose)
  .container.text-center   paddingTop=0px  paddingBottom=0px  textAlign=start  (Our Purpose inner)
  .wholesale-cta-section   paddingTop=80px paddingBottom=80px                (working path)

pixel7-portrait-412x915 @ DPR 2.625, mobile+touch:
  section.bg-cream.py-20   paddingTop=0px  paddingBottom=0px  textAlign=start  (Our Company)
  section.py-20            paddingTop=0px  paddingBottom=0px  textAlign=start  (Our Values)
  section.bg-forest.py-20  paddingTop=0px  paddingBottom=0px  textAlign=start  (Our Products)
  section.bg-cream.py-20   paddingTop=0px  paddingBottom=0px  textAlign=start  (Our Purpose)
  .container.text-center   paddingTop=0px  paddingBottom=0px  textAlign=start  (Our Purpose inner)
  .wholesale-cta-section   paddingTop=80px paddingBottom=80px                (working path)
```

Console errors: **0** at both viewports. Network errors: **0** at both viewports.

### 7.3 Disconfirming observation (browser)

The captain's original symptom report said "looks wrong in Chrome on Android." The
computed-style evidence at **both** 1280×800 and 412×915 shows identical zeros —
disconfirming a strictly Android-specific cause. The likely reason the captain
noticed it more on mobile: the single-column stacking at ≤412px makes adjacent
zero-padding sections visibly touch each other (header bottom → "Our Company"
top with no gap; "Our Company" bottom → "Our Values" top with no gap, etc.).

The age-gate modal also partially masks the symptom on first paint — at both
viewports a `.modal-overlay` (Research Use Confirmation card) covers the page
on first load. Without dismissing it (ticketing three checkboxes + "Enter the
catalog"), the broken sections are heavily dimmed. A returning visitor with a
localStorage age-gate flag bypasses the modal immediately and sees the broken
layout without any overlay.

### 7.4 Evidence files

All 8 PNGs + 1 JSON written to
`/home/hd2admin/kun-agent-workspace/data/elevate-mobile-audit/evidence/`:

| File | Description |
|---|---|
| `elevate-home-desktop-1280x800-fold.png` | Desktop fold, modal visible |
| `elevate-home-desktop-1280x800-fold-nomodal.png` | Desktop fold, modal CSS-hidden |
| `elevate-home-desktop-1280x800-full.png` | Desktop full-page, modal at top |
| `elevate-home-desktop-1280x800-full-nomodal.png` | **Canonical desktop evidence** |
| `elevate-home-pixel7-portrait-412x915-fold.png` | Pixel-7 fold, modal visible |
| `elevate-home-pixel7-portrait-412x915-fold-nomodal.png` | Pixel-7 fold, modal CSS-hidden; "Our Company" touches hero bottom edge |
| `elevate-home-pixel7-portrait-412x915-full.png` | Pixel-7 full-page, modal at top |
| `elevate-home-pixel7-portrait-412x915-full-nomodal.png` | **Canonical mobile evidence** |
| `elevate-home-evidence.json` | Full probe dump: browser version, viewport sizes, console/network errors, per-element computed styles at both viewports |

*(Pixel-7 viewport here is browser emulation in Chromium on Linux; not a physical Android device.)*

---

## 8. Source / build / deploy ownership — final findings

*(Warehouse search completed across all 10 firstmate homes, kun-agent-workspace, agent-work, and GitHub.)*

### 8.1 What local records confirm

| Item | Value | Source |
|---|---|---|
| Platform owner | `elevate` | `SERVICE_CATALOG.md` (field `platform_owner`) |
| Brand/domain | `elevatesci.com` | `SERVICE_CATALOG.md` |
| Runtime | `static` (84-file SEO/schema/image release) | `SERVICE_CATALOG.md` |
| CDN edge | Cloudflare (`cf-cache-status: DYNAMIC`) | Live HTTP evidence |
| Apex/www origin host | **UNKNOWN** — not in any firstmate home's hosts.yaml | `SERVICE_CATALOG.md` `elevate-site.current_host: UNKNOWN` |
| Intended host | **UNKNOWN** | `SERVICE_CATALOG.md` `elevate-site.intended_host: UNKNOWN` |
| Evidence records | `BR-ELEVATE-IDENTITY-001`, `BR-ELEVATE-SEO-PERF-001` | Cited in `SERVICE_CATALOG.md`; **absent from disk** in all 10 firstmate homes |
| Source document | `PRD_DELIVERY_MAP.md` | Cited in `SERVICE_CATALOG.md`, `SOURCES.md`; **absent from disk** |
| Dashboard origin host | `srv1137994-aminolifesciences` (Hostinger KVM8) | `SERVICE_CATALOG.md`; `ELEVATE_NGINX_ROUTE_20260919.md` |
| Original builder | **HD2.ai** | `<meta name="generator" content="HD2.ai">` on live page; `client-sales-journeys-portable.html` |
| PRD v3 planned domain | `www.elevatelifesci.com` (note: **different from live `www.elevatesci.com`**) | `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` |
| PRD v3 planned structure | `elevate/web/`, `elevate/api/`, `elevate/files/`, `elevate/cache/` | `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` |
| Client warehouse | **NOT registered** — `CLIENT_WAREHOUSE_ONBOARDING.md` procedure not completed for Elevate | `WAREHOUSE_BOUNDARIES.md` |
| GitHub HD2.ai repos searched | `DeightonLLM_Infrastructure` (private), all other GH accounts — **no `elevate-*` or `elevatesci-*` repo found** | `gh-axi search repos` (0 results for both queries) |
| `projects/` search | No `elevate-*` directory in any firstmate home or kun-agent-workspace | `find` across all homes |

### 8.2 What local records leave as a gap

The warehouse confirms the **builder** (HD2.ai) but has no record of:
1. **The actual source repo or export** — no `elevate-site`, `elevate-marketing`, or `elevate-export` directory exists in any firstmate home or in GitHub under HD2.ai or any known account. The PRD v3 shows planned directory names but these are planned, not actual source paths.
2. **The build pipeline** — the HTML uses Tailwind-utility class names but `style.css` lacks a Tailwind layer. The fix strategy (add CSS rules vs. strip HTML classes vs. restore Tailwind build) cannot be determined without the source.
3. **The apex/www origin host** — Cloudflare CDN is confirmed as the edge but the origin server (where static files are served from) is `UNKNOWN`. This is needed to push and verify any fix.
4. **The evidence files** — `BR-ELEVATE-IDENTITY-001` and `BR-ELEVATE-SEO-PERF-001` are referenced in the service catalog but absent from disk; `PRD_DELIVERY_MAP.md` is also absent. Without them, the canonical intent and prior work cannot be reviewed locally.

### 8.3 Controller question and answer

**Question sent to controller (owner):** What is the exact source repository URL, deploy pipeline, and origin host for the `elevatesci.com` apex/www marketing site? Which HD2.ai or Elevate team member owns the current deploy credentials?

**Answer received:** The controller confirmed that no `elevate-site` source repo or static export is registered in any firstmate home or in the HD2.ai GitHub organization. The apex/www origin host is not recorded. The `PRD_DELIVERY_MAP.md` and evidence files `BR-ELEVATE-IDENTITY-001` / `BR-ELEVATE-SEO-PERF-001` are also absent from disk. The `elevate` platform owner must supply the source location and deploy path before a fix can be authored or pushed.

### 8.4 Concrete access still needed

To implement a fix, the captain or `elevate` platform owner must supply:

1. **Source repo or static export** — a git repo or zip/tarball matching the live `style.css` + `index.html` + `js/main.js` + `images/*` tree. Not present in any firstmate home, kun-agent-workspace, or GitHub HD2.ai org.
2. **Build configuration confirmation** — is the missing Tailwind layer an accidental purge, an intentionally omitted step, or a different CSS architecture? This determines the correct fix.
3. **Apex/www origin host or deploy endpoint** — Cloudflare is the CDN edge; the origin server (Nginx/Apache/Coolify/etc. on the actual host) must be accessible to push updated files and purge the CDN cache.
4. **Evidence files** — `PRD_DELIVERY_MAP.md`, `BR-ELEVATE-IDENTITY-001`, and `BR-ELEVATE-SEO-PERF-001` would allow a prior-art review; they are not blocking but are gaps in institutional knowledge.

---

## 9. Captain-hold gate — decision inventory

This scout surfaced the following question for the captain:

> **Who can provide the Elevate marketing site source repo, deploy path, and origin host credentials?**

This is a **captain-level decision**, not a crewmate decision. The bug is
confirmed, the fix is clear in principle (add `.py-20 { padding: 5rem 0 }` and
`.text-center { text-align: center }` to `style.css`, or strip those classes
from the HTML once the build pipeline is understood), but the captain or the
`elevate` platform owner must supply the three items in §8.4 before any fix
can be authored against real source or pushed through the deploy pipeline.

No other unresolved captain calls were discovered in this investigation.

---

## 10. Updated conclusion

- **Confirmed cause** (high confidence, corroborated by real browser at both
  viewports): the homepage HTML uses Tailwind utility classes `py-20` (×4)
  and `text-center` (×1) that are **not defined in `style.css`**. Four content
  sections render with `padding: 0` and one with `text-align: left`. The age-gate
  modal partially masks the symptom on first load; returning visitors see the
  broken layout immediately.
- **The "Android-only" framing is disconfirmed.** Identical computed-style
  zeros at 1280×800 desktop and 412×915 Pixel-7 portrait prove the defect is
  viewport-independent. Mobile stacking makes the missing padding more obvious,
  which is the likely reason the captain noticed it on a phone.
- **Source/build/deploy status**: HD2.ai is the original builder (per page meta
  and design docs). The apex/www origin host is `UNKNOWN` in the local
  warehouse. The `elevate-site` source repo and evidence files are **absent from
  all 10 firstmate homes, kun-agent-workspace, and GitHub HD2.ai org**. The
  `elevate` platform owner must supply the source location and deploy path.
- **The fix is straightforward** once the source is in hand: add two CSS rules
  to `style.css`, or strip the undefined utility classes from the HTML once the
  build pipeline is confirmed. A ship task can proceed immediately after the
  source access question is answered.
