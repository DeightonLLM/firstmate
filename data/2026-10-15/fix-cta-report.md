# Core Distro staging navbar fix

VERDICT: FIXED

## Change and cause

- Commit: `4cb6086` — `fix: improve responsive navbar layout` on branch `fix/urls` (verified current HEAD).
- Root cause: `components/Navbar.tsx:98` sized the fixed header with `w-[100dvw]`; `components/Navbar.tsx:143` enabled the full-width desktop navigation/actions at `lg` without fitting the available viewport. At 1024px, browser measurement showed the header extending to x=1311.97 and the quote CTA extending to x=1400.78, outside the viewport.
- CTA fix: `components/Navbar.tsx:98,143,227,276` uses `w-full max-w-full`, retains the quote CTA in the compact header, and moves secondary desktop navigation/actions behind the `2xl` breakpoint.
- Admin contrast fix: `components/Navbar.tsx:66,100-105,151` identifies `/admin`, gives its header an opaque deep-green background, and uses near-white navigation text.
- The original 1440x900 screenshot showed the CTA within the viewport, but the 1024px geometry reproduced the underlying overflow.

## Deployment and browser verification

- The staging host currently serves release `/opt/core-distro-staging/releases/release-20261016_160054`; deployment was completed by the other lane before this verification. No production site or nginx service was touched in this turn.
- Exact browser URLs were opened before screenshots.
- Desktop screenshot (1440x900): `data/fix-cta/after-desktop-1440x900.png`. Browser measurement: viewport width 1440; header width 1440; Request a Quote CTA bounds x=770.52–940.72, fully inside the viewport; document width 1440.
- Mobile screenshot (390x844): `data/fix-cta/after-mobile-390x844.png`. Browser measurement: document width 390, no horizontal overflow, header width 390, hamburger present.
- Admin contrast screenshot (1600x900): `data/fix-cta/after-admin-1600x900.png`. On `/admin`, desktop nav is visible against the dark header. Browser-computed/canvas-measured contrast: near-white nav text on the composited header background **16.23:1**; green logo mark **9.29:1**; white wordmark **17.20:1**. These exceed WCAG AA 4.5:1 text and 3:1 large-logo thresholds.
- External request: `curl -sS -I --max-time 20 https://staging.core-distro.com/` returned `HTTP/1.1 200 OK`, `Server: nginx`, `Content-Type: text/html; charset=utf-8`, `Content-Length: 383569`, `X-Powered-By: Next.js`, and `X-Robots-Tag: noindex, nofollow` at 2026-10-16 16:04:14 GMT.

## Validation and secret scan

- `npm run typecheck`: passed.
- `npm test`: passed, 4 tests.
- App-scoped scan: `/tmp/agent-secret-scan check "$PWD"` from the app directory returned `SUCCESS: no obvious leaked secret files found`. The scanner was copied to the host's `/tmp` because it was not on the host's PATH; scan scope was only the app directory.
- Earlier baseline screenshots: `data/fix-cta/before-desktop.png`, `data/fix-cta/before-1024.png`, and `data/fix-cta/before-admin-1440.png`.
