# Core Distro staging URL fix report

VERDICT: FIXED

## Root cause and correction

Staging rendered production-origin URLs because the app hardcoded `https://core-distro.com` instead of deriving the site origin from deployment configuration. Representative original locations were `app/sitemap.ts:4`, `app/layout.tsx:25,33,44`, and `components/ChatWidgetLoader.tsx:24-25`. The fix centralizes `NEXT_PUBLIC_SITE_URL` (safe production default) and URL/image helpers in `lib/site-url.ts:1-12`, then uses them for canonical/schema/breadcrumb/footer/robots/sitemap URLs and chatbot brand images. The staging build used `NEXT_PUBLIC_SITE_URL=https://staging.core-distro.com`. The `llm.hd2.ai` script and API endpoints were left unchanged.

The separate admin-denial observation came from `components/pages/AdminPage.tsx:42`: its existing guard denies when `!user || user.role !== "admin"`. The isolated browser session had no recognized admin identity. The public `/` homepage rendered normally; `/admin` showed the denial. The origin commit did not change the admin route, guard, or auth hook, so the evidence does not attribute that guard response to the URL fix. I could not diagnose the captain's authenticated session.

## Commits and staging release

- `df77630` — `fix: use configured site origin for production URLs`
- `4cb6086` — `fix: improve responsive navbar layout`
- Staging release: `release-20261016_160054`
- Typecheck passed; tests passed 4/4; app-directory secret scan passed.

## Browser verification

- Desktop 1440x900: staging-loaded images included `https://staging.core-distro.com/images/hero-lab-v2.webp` and `https://staging.core-distro.com/images/about-pharma-700.webp`; both loaded. Screenshot: `data/fix-urls/screenshots/staging-desktop-1440x900.png`.
- Mobile 390x844: staging-loaded images included `https://staging.core-distro.com/images/hero-lab-mobile-640.webp` and `https://staging.core-distro.com/images/about-pharma-700.webp`; both loaded. Screenshot: `data/fix-urls/screenshots/staging-mobile-390x844.png`.
- Homepage links remained on staging. Browser-rendered `https://staging.core-distro.com/sitemap.xml` listed staging-origin URLs.

No deployment occurred after the stop-deploy instruction.
