# Browser check - Core staging, EVERY page, desktop AND mobile (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort **high**. Worktree: /tmp/wt-browser1, branch fix/browser-check.

## WHY THIS LANE EXISTS
Firstmate reported staging as "200, all routes" and Captain opened it to find **a broken chatbot and
broken logos**. A 200 only proves the server answered. **Do not repeat that mistake.**

## Tooling
`chrome-devtools-axi` is on PATH. Use it. READ ONLY against the site.

## Pages - check EVERY one
```
https://staging.core-distro.com/            desktop + mobile
https://staging.core-distro.com/about
https://staging.core-distro.com/products
https://staging.core-distro.com/blog
https://staging.core-distro.com/contact
https://staging.core-distro.com/resources
https://staging.core-distro.com/faq
https://staging.core-distro.com/compliance
https://staging.core-distro.com/admin
https://staging.core-distro.com/register
```

## For EACH page report
1. **Screenshot** - desktop 1440x900 AND mobile 390x844. Save under data/browser-check/.
2. **Console errors** - every error and warning, verbatim.
3. **Images** - for EVERY image: does it RENDER at the right size, or is it a broken/placeholder icon?
   An image returning HTTP 200 can still render wrong. **State what each image actually shows.**
4. **Layout** - overlapping text, missing CSS, unstyled content, broken grid, text too small to read.
5. **Chatbot** - is a chat widget present, and does it open and send? If absent, say ABSENT.
   Captain specifically reported it not working.
6. **Nav** - does the menu work, are all links live?

## Known facts - build on these, do not rediscover
- Cert is valid to Jan 2027.
- Site is deployed from `/root/core distro brNDON EDIT/Core Distro Web` at commit 4f44f50 via
  `/root/bin/deploy-core-distro-staging`. Do NOT redeploy. Do NOT edit that source. **You are
  reporting only.**
- The deployed app has a `ChatWidgetLoader` component in source but no chatbot files in
  `public/`. Verify whether the widget renders and what it does.

## Hard rules
- **READ ONLY.** No edits, no deploys, no restarts, no nginx, no DNS.
- **Never touch `srv1137994` Aminolifesciences sites** or anything outside staging.core-distro.com.
- Do not fix anything. Diagnose and report precisely. **A precise report is the deliverable.**

## Deliverable
data/browser-check/report.md with:
- a per-page table: page, desktop ok?, mobile ok?, console errors, images broken, chatbot state
- every screenshot path
- a single VERDICT line per page: USABLE or BROKEN, with the specific reason
- the top 5 defects ranked by what Captain would notice first

Be blunt. If it is broken, say it is broken. Do not soften it.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
