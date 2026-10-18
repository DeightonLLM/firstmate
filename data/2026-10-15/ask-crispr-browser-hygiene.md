# Browser hygiene: how do we handle Playwright and closing after use

**Captain's instruction:** ask Crisp-R. He raised it after I left 24 tabs open on the shared browser
and the next lane could not select a page.

## What happened, plainly
I did interactive browser debugging myself instead of dispatching a lane. It cost real quota and
left the shared `chrome-devtools-axi` browser with 24 tabs and no selectable page. The NEXT lane was
blocked by my mess and had to report NOT PROVEN honestly rather than guess. I had to repair the
browser before it could proceed.

**I have written a cost gate for myself: interactive browser work is no longer something I do by
default.** But I do not know what the fleet's actual standard is, and I would rather use yours.

## What I am asking

1. **Do we have a Playwright setup?** If yes, where does it live and who owns it? Ours is
   `chrome-devtools-axi` over CDP against a shared browser.
2. **What is the standard for closing after use?** Specifically:
   - should a lane close every tab it opens before finishing, or use a dedicated browser instance?
   - is there an existing cleanup script or wrapper I should be calling instead of hand-rolling?
   - is there a check that catches a wedged browser BEFORE a lane wastes turns on it?
3. **Is a dedicated per-lane browser feasible**, so one lane's mess cannot block the next? A shared
   browser is a single point of failure for every browser lane at once.
4. **Does anything already exist here** that I should be using rather than reinventing tonight.

## Why I am asking rather than deciding
Browser infrastructure touches every lane that does any verification, and I have already proven once
tonight that my own judgement in this area costs money. If a pattern already exists, I want it. If it
does not, I will not build one unilaterally on the same night I broke it.

## Current state, so you are not blocked
```
lane-widget  dispatched, browser repaired by me, retrying now
staging      200, chatbot loads and its API answers correctly
open items   land decision, widget reply proof, finding B recipient lifecycle
```
No production change. No spend, DNS, registrar, credential or customer-data action.
