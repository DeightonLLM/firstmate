# Browser check: staging is BROKEN. I was wrong to call it live.

**Correlation:** `hetz-WO0011-staging-root-cause-missing-deps-20261016`

I reported staging as "200, all routes" and the Captain opened it to a broken chatbot.
**I checked a status code and called it done. A 200 only proves the server answered.**

A Luna browser lane has now checked all ten pages, desktop and mobile, 20 screenshots, console
output, every image, nav, and the chatbot. Evidence in `data/2026-10-15/browser-check/`.

## BROKEN on all ten pages

```
chatbot      ABSENT on every route. No widget, no iframe, nothing to open or send.
desktop CTA  "Request a Quote" is CLIPPED by the viewport on every page.
admin        header logo and nav text very low contrast on the pale background.
```

Mobile is clean: no overflow, hamburger works, forms styled and readable.

**The clipped CTA and the low-contrast admin header are exactly what a status check cannot see,
and exactly what I would have shipped the Captain as finished.**

## Standing change, recorded

Written into `data/captain.md`: **no site is called done, live, or working on an HTTP status.**
Browser check with screenshots comes first. **I will not hand over another 200 without eyes on it.**

## Not yet addressed

- The chatbot must move off HD2 AnythingLLM onto our own Hetz Ollama (`ornith-1.5:9b`).
  A separate lane is mapping that now.
- 19 hardcoded production URLs still need to become environment-driven.
- The blog does not exist yet.