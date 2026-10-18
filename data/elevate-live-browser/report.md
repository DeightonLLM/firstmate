# Elevate marketing homepage — real-browser evidence (scout)

**Task:** `elevate-live-browser`
**Target:** `https://www.elevatesci.com/` (apex/www marketing site)
**Date:** 2026-09-23 (captured 2026-09-23T04:52:31Z UTC)
**Author:** scout crewmate, `bin/fm-spawn` kind=scout, model=minimax/MiniMax-M3
**Method:** Playwright-driven Google Chrome for Testing **153.0.8010.12** (already cached on disk at
`/home/hd2admin/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome`). **No browser package
was installed, downloaded, or updated.** Only the on-disk Playwright Chromium and the cached
`playwright`/`playwright-core` Node packages
(`/home/hd2admin/.npm/_npx/420ff84f11983ee5/node_modules`) were used.

This task is a **browser-only evidence capture**. It is intentionally separate from the prior
text-only scout (`elevate-mobile-audit` / `data/elevate-mobile-audit/report.md`), which had to
fall back to a static-artefacts diagnosis because its CDP bridge was dead and the controller had
no working Chrome. The cached Chromium is now reachable, so the missing dimension — real rendered
layout at desktop and Pixel-7 emulation — is supplied here. The static defect finding from the
prior scout is **corroborated** by these new screenshots and probe data; no source change is
proposed.

---

## 1. Environment

```
$ /home/hd2admin/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome --version
Google Chrome for Testing 153.0.8010.12

$ ldd .../chrome | grep "not found"
(no missing libraries)

$ node -e "console.log(require('playwright/package.json').version)"
1.63.0
```

`ldd` reported zero missing shared libraries at capture time. The prior scout's claim that
`libnspr4.so`, `libnss3.so`, `libatk-1.0.so.0`, etc. were missing is **not reproducible today**;
either the host gained those libraries between runs or the prior scout read a different binary.
The current run is green.

Capture script lives at
`/home/hd2admin/.treehouse/firstmate-46aafc/7/firstmate/.scratch/capture-evidence.mjs` (inside
the disposable worktree; will be discarded at teardown). It launches the cached Chromium via
`playwright.chromium.launch({ executablePath, headless: true, args: ['--no-sandbox',
'--disable-dev-shm-usage'] })`, opens two contexts (desktop 1280×800 @ DPR 1, Pixel-7 portrait
412×915 @ DPR 2.625 + mobile/touch flags), navigates to the target with `waitUntil:
'networkidle'`, and emits four PNGs per viewport (fold as-loaded, full-page as-loaded, fold
with age-gate CSS-hidden, full-page with age-gate CSS-hidden) plus a single JSON dump of probe
data, console errors, and network errors.

> **Pixel-7 framing.** The Pixel-7 viewport here is **browser emulation inside Chromium
> running on Linux**, not a physical Android device, not Chrome DevTools, and not a remote
> Android-on-Chrome-debug session. It changes window size, device pixel ratio, the mobile UA,
> and touch / mobile media flags — exactly what an in-browser emulation toggle does.

---

## 2. What I did, in order

1. Verified the cached Chromium binary loads (`--version` returns 153.0.8010.12) and `ldd` is
   clean. Wrote `working` status.
2. Located the cached `playwright`/`playwright-core` modules under
   `/home/hd2admin/.npm/_npx/420ff84f11983ee5/node_modules` and symlinked them into the
   worktree's `.scratch/` so the script can `import` them without a fresh `npm install`.
3. Wrote `capture-evidence.mjs` (in the disposable worktree) that drives both viewports,
   collects console + network events, and probes the same five utility-class elements the
   prior scout identified (four `<section class="… py-20">` plus one inner
   `<div class="container text-center">`).
4. Ran the script. Both viewports loaded with HTTP 200 and no console / network errors. The
   page title is `Elevate Life Sciences | Research Peptides | Elevate Life Sciences`.
5. Noted that the as-loaded "above-the-fold" capture is dominated by an age-gate modal (a
   `.modal-overlay` containing a "Research Use Confirmation" card with three checkboxes and an
   "Enter the catalog" button). Re-captured fold + full-page screenshots with a *screenshot-only
   inline style tag* that sets `.modal-overlay { display: none !important }` and resets
   `html, body { overflow: auto }`. **No checkbox was clicked, no form was submitted, no remote
   state was changed**; the modal remains in the DOM, only the screenshot render bypasses it.
6. Re-ran with the extra screenshot pass; 8 PNGs and one JSON file written to the evidence
   directory. No prior evidence was overwritten (the existing `site-style.css`,
   `site-mobile-ua.html`, `site-main.js` from the prior scout remain untouched).

---

## 3. Browser observation summary (per the brief's required fields)

| Field | Desktop (1280×800, DPR 1) | Pixel-7 portrait (412×915, DPR 2.625, mobile/touch) |
|---|---|---|
| Chromium version | `Google Chrome for Testing 153.0.8010.12` | same binary, same version |
| User-Agent (desktop) | `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.8010.12 Safari/537.36` | n/a — Pixel-7 UA from `playwright.devices['Pixel 7']` |
| Page title | `Elevate Life Sciences \| Research Peptides \| Elevate Life Sciences` | identical |
| Final URL | `https://www.elevatesci.com/` | identical |
| HTTP status | 200 | 200 |
| Console errors | 0 | 0 |
| Network errors | 0 | 0 |
| Age-gate modal present at load | yes — `div.modal-overlay` containing a "Research Use Confirmation" card, 3 checkboxes, "Enter the catalog" button | yes, identical |
| Bug reproduces at this viewport | **yes** | **yes** |
| Visual delta from desktop to mobile | none on the bug itself — same zero-padding, same left-aligned "Our Purpose" text. Mobile just stacks the product cards vertically and switches the desktop nav to a hamburger + cart icon. | n/a |

### 3.1 Trigger / mask / symptom (real-browser)

- **Initiating trigger.** Any visit to `https://www.elevatesci.com/`. The page is delivered by
  Cloudflare; HTTP 200, `cf-cache-status: DYNAMIC` (verified by the prior scout). The bug is
  a static HTML/CSS defect — *any* viewport, *any* UA that parses the HTML will see it.
- **Masking condition.** The age-gate modal intercepts every first-time visit; without my
  CSS-bypass trick the captain (and any new visitor) sees the modal, not the broken sections.
  Inside the modal the page beneath is heavily dimmed by an overlay, so the symptom is
  *partially* masked on first paint — but the moment the modal is dismissed (or bypassed, as
  a returning visitor with a localStorage flag would experience) the broken layout is
  fully visible.
- **Visible symptom** (corroborated from the prior scout's static-artefact diagnosis and now
  confirmed visually + numerically):
  1. Four content sections render with **zero top + bottom padding** because the HTML
     declares `class="… py-20"` (a Tailwind utility) that the page's `style.css` never
     defines. The sections are: "Our Company", "Our Values", "Our Products Highlight",
     "Our Purpose". At desktop they touch the previous section's bottom border; on the
     Pixel-7 portrait they sit flush against the dark-blue hero, which is most visually
     striking.
  2. The "Our Purpose" callout, which uses `class="container text-center"` (another
     undefined Tailwind utility), renders left-aligned — its `text-align` computed value
     is `"start"` (browser default), not `"center"`.

### 3.2 Computed-style probe (the numbers, both viewports)

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

The five broken elements have **identical computed styles** at both viewports. The bug does
**not** vary by viewport. The captain's "Android-only" framing from the original report is
**disconfirmed**: the defect reproduces identically at desktop 1280×800. The likely reason
Android felt worse is (a) the modal masks the bug less aggressively when scrolled past, and
(b) on a narrow viewport the affected sections stack vertically and the missing padding is
visually louder.

### 3.3 Working-path comparison (built into the same page)

The site has a built-in working path: the `.wholesale-cta-section` ("Let's Build the Future
Together") is what comes immediately after "Our Purpose", and it declares its own
`padding: 5rem 0` in `style.css` (prior scout, line 541). Its computed style is
`paddingTop=80px paddingBottom=80px` — **the same `5rem` the broken sections were supposed
to render.** That section is the visual proof the layout engine, font stack, breakpoint
logic, and CSS pipeline all work when the spacing is actually declared in CSS instead of
relied on as an undefined utility class.

### 3.4 Disconfirming evidence I deliberately went looking for

To avoid pinning "Android-only" on a viewport-shaped explanation, I probed for the usual
suspects and found nothing that would change the diagnosis:

- **Horizontal overflow on narrow viewport.** Pixel-7 full-page screenshot shows no
  horizontal scroll bar; body width tracks the 412px viewport. The `minmax(...)` grids the
  prior scout flagged collapse cleanly to one column.
- **Sticky header interaction.** `header.site-header { position: sticky; top: 0; z-index: 50 }`
  renders correctly at both viewports; the desktop nav links are visible at 1280×800, the
  hamburger icon is visible at 412×915.
- **Cart drawer / modal stacking.** The modal-overlay is the only full-page overlay on
  load; nothing else interferes with section spacing.
- **Hero padding.** The hero correctly applies `padding: 7rem 0` via inline style, so it
  is properly spaced — proving the layout engine honours inline padding even when the
  same page's `<section>` declarations fail.
- **Mobile UA vs desktop UA media-query behaviour.** No `@media` rule selectively kills
  `.py-20` at one viewport; the bug is viewport-independent by direct measurement.

### 3.5 Discrepancy with the prior scout worth flagging

The prior scout (`elevate-mobile-audit/report.md` §1) said the cached Chromium failed to
launch with `libnspr4.so: cannot open shared object file` and several other missing
libraries. **At the time of this run, `ldd` reports zero missing libraries and the binary
launches cleanly.** I cannot tell from this host whether the libraries were installed in
the interim or whether the prior scout read a stale `ldd` output, but the upshot is that
the bridge that was wedged in the previous lane is **not** wedged now — and the missing
dimension (real rendered layout) can be produced without any host mutation. If the captain
wants a permanent capability here, the takeaway is: the cached
`chromium-1243/chrome-linux64/chrome` runs end-to-end on this host today; installing
`google-chrome-stable` is no longer strictly necessary for screenshot evidence.

---

## 4. Evidence paths (the only files written outside the worktree)

All evidence is in `/home/hd2admin/kun-agent-workspace/data/elevate-mobile-audit/evidence/`.
Existing files (`site-main.js`, `site-mobile-ua.html`, `site-style.css`) are untouched; new
files are uniquely named PNGs and one JSON, none overwriting prior evidence.

### 4.1 New screenshots (8 PNGs, all timestamped 2026-09-23 06:52)

Desktop 1280×800:
- `elevate-home-desktop-1280x800-fold.png` — fold as loaded, age-gate modal visible.
- `elevate-home-desktop-1280x800-fold-nomodal.png` — fold with `.modal-overlay { display:
  none }` injected; hero + nav visible.
- `elevate-home-desktop-1280x800-full.png` — full-page as loaded; modal at top, rest of
  page visible behind/below.
- `elevate-home-desktop-1280x800-full-nomodal.png` — full-page with modal hidden; entire
  homepage visible end-to-end. **This is the canonical desktop evidence image.**

Pixel-7 portrait 412×915 (browser emulation only — not a physical Android device):
- `elevate-home-pixel7-portrait-412x915-fold.png` — fold as loaded, age-gate modal visible.
- `elevate-home-pixel7-portrait-412x915-fold-nomodal.png` — fold with modal hidden; hero
  visible. The "OUR COMPANY" heading already visibly touches the hero's bottom edge.
- `elevate-home-pixel7-portrait-412x915-full.png` — full-page as loaded.
- `elevate-home-pixel7-portrait-412x915-full-nomodal.png` — full-page with modal hidden.
  **This is the canonical mobile evidence image.** The five broken sections stack
  vertically and the missing padding + left-aligned "Our Purpose" are visible end-to-end.

### 4.2 Probe dump

- `elevate-home-evidence.json` — single JSON containing: `browserVersion` ("153.0.8010.12"),
  `chromeBinary` (cached path), `capturedAt` (ISO 8601), `target`, empty `consoleErrors`
  array, empty `networkErrors` array, and a `perViewport` object with each viewport's
  `pageTitle`, `finalUrl`, `modalProbe`, and `probe.sections` (the five broken elements
  with their computed padding + text-align) plus `probe.working` (the
  `.wholesale-cta-section` comparison).

### 4.3 Files in the worktree (discarded at teardown)

- `/home/hd2admin/.treehouse/firstmate-46aafc/7/firstmate/.scratch/capture-evidence.mjs`
  — the capture script. Kept only because teardown will discard it; the report is the
  survival artefact.

---

## 5. Conclusion and recommendation

### 5.1 Bottom line

- **The bug reproduces.** The five undefined-utility-class elements render with
  `paddingTop=0px, paddingBottom=0px, textAlign=start` at **both** the desktop and Pixel-7
  emulation viewports, identically.
- **The bug is not Android-specific.** The desktop 1280×800 evidence shows the same
  computed-style zeros. The captain's original "Android-only" framing is **disconfirmed**
  by direct measurement; the symptom is viewport-independent.
- **The cause is the static HTML/CSS defect identified by the prior scout** (`py-20` and
  `text-center` are Tailwind-utility classes that the page's `style.css` never defines).
  No new cause is introduced by this scout.
- **No browser-side workarounds (caches, service workers, DevTools toggles) hide the
  defect.** This is a server-delivered stylesheet + markup gap; only the source can fix
  it.

### 5.2 What this scout deliberately did not do

- Did **not** interact with the age-gate modal (no checkbox toggled, no button clicked,
  no form submitted). The CSS-bypass for screenshots is a render-time technique only.
- Did **not** install, update, or download any browser package. The Chromium binary used
  is the one already cached on disk.
- Did **not** modify any source file. This is a scout task; the report is the deliverable.
- Did **not** open, close, or move any work item in the backlog or in any secondmate
  registry.

### 5.3 What is still missing to actually fix it (unchanged from prior scout)

The static-artefact diagnosis in `elevate-mobile-audit/report.md` §4–§6 still applies
verbatim. In summary:

1. The `elevate-site` source repo or static export is **not present in any local firstmate
   home's `projects/` or in `kun-agent-workspace/`**. Without it, no fix can be authored
   against the real source.
2. The build pipeline (Tailwind? hand-written CSS? purged output?) is **unknown from
   local records** — that determines whether the fix is "add `.py-20 { padding: 5rem 0;
   .text-center { text-align: center }` to `style.css`", "strip the Tailwind classes from
   the HTML", or "restore a missing Tailwind build step".
3. The origin host for the apex/www edge (Cloudflare is the CDN, but the origin is
   `UNKNOWN` per `service_catalog.yaml`) is needed to push and verify any fix lands.

The captain or the `elevate` platform owner must supply those before a ship task can
begin. This scout makes **no recommendation to start work**; it only confirms that the
symptom is real and reproduces identically at both viewports, so the prior scout's
diagnosis stands.

### 5.4 Optional follow-up the captain may want

If the captain wants one more data point, the cleanest cheap next step is to capture the
same five elements' computed styles **after** dismissing the modal via the actual
checkbox / button flow on a *throwaway* browser profile, so we know the layout is
identical post-dismiss. I did not do that here because the brief says "do not submit
forms" and ticking three checkboxes + clicking "Enter the catalog" crosses that line.
If the captain wants that variant, it should be a separate scout with explicit
authorization to interact with the form.

---

## 6. Status / handoff

This scout is complete on its evidence-only scope. No captain decision is gated by it;
the captain already has the static diagnosis from `elevate-mobile-audit/report.md` and
now has the corroborating browser evidence. The next move, if any, is a captain choice
to obtain source + origin host access, after which firstmate can promote a ship task.
