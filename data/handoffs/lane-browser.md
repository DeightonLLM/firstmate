# Lane 2 - Core Distro full-site browser sweep + chatbot proof (Luna 6, high)

Worktree /tmp/wt-lane-browser, branch lane/browser-sweep.
Parent holds the fleet lock; you will not acquire it. Expected. You may read and WRITE under your
worktree. No commit. No fm-session-start.

## Staging
https://staging.core-distro.com - currently release-20261016_201713, everything 200.

## CRITICAL tool detail
`chrome-devtools-axi navigate` DOES NOT EXIST. It silently no-ops and you will screenshot whatever
page is already open - this already caused one false "ACCESS DENIED" bug. Use:
     chrome-devtools-axi newpage "<url>"
Then CONFIRM with `chrome-devtools-axi eval "window.location.href"` before you trust any screenshot.

## Routes - all ten, desktop 1440x900 AND mobile 390x844
  /  /about  /products  /blog  /contact  /resources  /faq  /compliance  /admin  /register

## Deliverables
1. For every route at both sizes: screenshot, console errors/warnings, every image actually rendered.
2. Navigation and interactive controls actually work. Not just present - clicked.
3. **Chatbot proof.** On / click "ASK QUESTIONS", confirm the widget loads from
   https://staging.core-distro.com/llm/chat/ (not HD2, not http). Open it, send a real question,
   and RECORD THE ACTUAL ANSWER TEXT AND ANY SOURCE CITATIONS SHOWN.
   Question to ask: "What does Core Distro supply and who do you supply it to?"
4. **Confirm whether source citations appear.** The embed answered correctly but returned
   sources=[] from the API. Determine whether the widget shows any source attribution to the user.
   This decides whether the RAG is visible or invisible. Report exactly what you see.

## Output
  data/lane-browser/report.md      per-route table, both sizes, chatbot answer verbatim
  data/lane-browser/shots/         all screenshots, named <route>-<size>.png

No deploy. No nginx. No app edits. Report failures as failures - never dress one up.
