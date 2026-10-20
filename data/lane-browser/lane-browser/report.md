# Core Distro staging browser sweep

- Target: `https://staging.core-distro.com` (observed 2026-10-17).
- Viewports: desktop 1440×900 and mobile 390×844.
- Screenshots: `data/lane-browser/shots/<route>-<size>.png` (20 files; `home` represents `/`).
- Each route was opened in Chrome and its `window.location.href` checked. Every screenshot below is the resulting viewport capture.

## Route results

| Route | Desktop | Mobile | Console errors / warnings (both sizes unless noted) | Rendered image elements (alt — observed `src`; result after scrolling) |
|---|---|---|---|---|
| `/` | [home-desktop.png](shots/home-desktop.png) | [home-mobile.png](shots/home-mobile.png) | No JS errors. Chrome issue: two form fields lack `id` or `name`. | Pharmaceutical laboratory — `https://staging.core-distro.com/images/hero-lab-v2.webp` (loaded); Pharmaceutical API research — `https://staging.core-distro.com/images/about-pharma-700.webp` (loaded); Sterile pharmaceutical vials — `https://d2xsxph8kpxj0f.cloudfront.net/310519663704493629/gW496Yb3TdmRhrkcieiR6Z/vials-packaging-v2-FtC8yx2YBeCk6KMQG7aQaT.webp` (not loaded); Pharmaceutical automation equipment — `https://d2xsxph8kpxj0f.cloudfront.net/310519663704493629/gW496Yb3TdmRhrkcieiR6Z/automation-machine-v2-2tkCd2A5buQzp5NiPCK3mF.webp` (not loaded); Quality assurance and compliance — `https://d2xsxph8kpxj0f.cloudfront.net/310519663704493629/gW496Yb3TdmRhrkcieiR6Z/compliance-quality-v2-dGjmfHRCo2LWgPapJcNkMe.webp` (loaded). The two unloaded items remained incomplete after scrolling to page bottom and waiting 5s; their image requests did not appear in the captured network list, so broken-image status is not established. |
| `/about` | [about-desktop.png](shots/about-desktop.png) | [about-mobile.png](shots/about-mobile.png) | No console messages. | Core Distro laboratory — `https://d2xsxph8kpxj0f.cloudfront.net/310519663704493629/gW496Yb3TdmRhrkcieiR6Z/hero-lab-v2-CEX4ZupLmGvsQeHosrNp5d.webp` (loaded); Core Distro quality — `https://d2xsxph8kpxj0f.cloudfront.net/310519663704493629/gW496Yb3TdmRhrkcieiR6Z/compliance-quality-v2-dGjmfHRCo2LWgPapJcNkMe.webp` (loaded). |
| `/products` | [products-desktop.png](shots/products-desktop.png) | [products-mobile.png](shots/products-mobile.png) | No console messages. | Sterile pharmaceutical vials — `https://d2xsxph8kpxj0f.cloudfront.net/310519663704493629/gW496Yb3TdmRhrkcieiR6Z/vials-packaging-v2-FtC8yx2YBeCk6KMQG7aQaT.webp` (loaded). |
| `/blog` | [blog-desktop.png](shots/blog-desktop.png) | [blog-mobile.png](shots/blog-mobile.png) | Both sizes: `GET /api/trpc/blog.list?...` returned HTTP 500 (two requests); also two form fields lack `id` or `name`. Blog posts/images consequently did not render. | None. |
| `/contact` | [contact-desktop.png](shots/contact-desktop.png) | [contact-mobile.png](shots/contact-mobile.png) | No JS errors. Chrome issues: six fields lack associated labels; four lack `autocomplete`. | None. |
| `/resources` | [resources-desktop.png](shots/resources-desktop.png) | [resources-mobile.png](shots/resources-mobile.png) | No console messages. | None. |
| `/faq` | [faq-desktop.png](shots/faq-desktop.png) | [faq-mobile.png](shots/faq-mobile.png) | No console messages. | None. |
| `/compliance` | [compliance-desktop.png](shots/compliance-desktop.png) | [compliance-mobile.png](shots/compliance-mobile.png) | No console messages. | Quality compliance documentation — `https://d2xsxph8kpxj0f.cloudfront.net/310519663704493629/gW496Yb3TdmRhrkcieiR6Z/compliance-quality-v2-dGjmfHRCo2LWgPapJcNkMe.webp` (loaded). |
| `/admin` | [admin-desktop.png](shots/admin-desktop.png) | [admin-mobile.png](shots/admin-mobile.png) | No console messages. Route renders “ACCESS DENIED — This page is restricted to administrators only.” | None. |
| `/register` | [register-desktop.png](shots/register-desktop.png) | [register-mobile.png](shots/register-mobile.png) | No JS errors. Chrome issues: seven fields lack associated labels; two lack `autocomplete`. | None. |

## Click / interaction checks

- Mobile navigation: on `/about`, clicked “Toggle menu”; it changed to expanded and exposed the navigation. Clicked “FAQ”; the browser reached `https://staging.core-distro.com/faq`.
- FAQ category: clicked “LEAD TIMES & SHIPPING”; the FAQ list filtered to the matching three questions. A question control was also clicked; its answer text was present, but no separate expand/collapse state was exposed.
- Contact form: clicked “SEND MESSAGE” empty. Native required-field validation stopped submission and focused “Full Name” with “Please fill out this field.” No message was sent.
- Blog: its category controls are present, but blog list data fails with HTTP 500, so a meaningful filter result cannot be verified.
- `/admin` access restriction is rendered as described above; it was not bypassed.

## Chatbot proof — BLOCKED / FAILED

On `/`, clicked “ASK QUESTIONS” in the rendered page. The page did not navigate, add an iframe/widget, or make a chat request; the visible UI remained unchanged. The button’s click was also invoked through the DOM, with the same result. Thus the requested embed could not be opened from the site.

As a separate URL check, opened `https://staging.core-distro.com/llm/chat/` over HTTPS. It displayed **404 Not Found (nginx)**. No chat interface or question field loaded. Consequently I could not submit “What does Core Distro supply and who do you supply it to?”, and there is no actual answer text to quote. No source citation/attribution appeared because the widget did not render; citation visibility is **undetermined**, not evidence that the user-facing answer has no citations. No HTTP or HD2-hosted chat widget was observed.

The full per-size URL/image/console captures are retained in `data/lane-browser/raw-sweep.txt`; image loading checks after scrolling are in `data/lane-browser/images-after-scroll.txt`.
