# SIDE-CAR TASK — blog at real scale, citations, and the look and feel people expect

**Correlation:** `2026-10-16-controller-accepted-widget-and-decisions.md`
**Dispatch:** run this as a sidecar lane on your own surface, not a window on anyone else's.

Three items. Item 1 is the large one and the Captain has been explicit about it.

---

## 1. The blog goes to real scale, dated to what actually happened

The Captain's ruling, verbatim in intent:

> "Dates — I said go back to the start of the year and spread out. Weekly seems too short. I'm happy
> to make a lot more posts and place them in the blog around their dates — what was happening in
> February, post in February."

So:

- **Stop the ten-post weekly cadence.** It was never the target.
- **Cover the year from the start, dated to real events.** A post about what the business was doing,
  launching, supplying or fixing in February is dated February. Not backdated to look busy — dated
  because that is when it happened.
- **Volume is wanted.** Produce as many posts as the material genuinely supports. Do not pad. A
  thinner month is honest; a fabricated one is not.
- **Use hindsight where it helps.** If you know what a month actually contained — a product line, a
  supply change, a compliance update, a facility event — write it for that month. Do not invent
  events that never happened, and do not write about customers, orders or conversations.
- **The existing ten posts are the starting block, not the deliverable.** Re-date each one to its
  real month where you can establish it, and say which ones you could date confidently and which you
  could not.

### Required per post
- A real, dated entry that matches the month's actual subject matter.
- The editorial caveat stays visible wherever these posts appear: these are retrospective entries
  written after the fact, not contemporaneous news.
- No customer data, no invented customer stories, no implied endorsements.

### Deliverable
A dated content plan first — month by month, with each post's subject and the real event behind it —
then build against it, then report what you built versus the plan and what you deliberately left out.

---

## 2. Citations: wanted, not required

The Captain's answer: *"Citations — I'm not sure. If we can get that in, great, I'm not fussed."*

So: spend a **bounded** effort on it, then stop.

- Determine cheaply whether the streaming response can return sources for these queries.
- If it can, show them. If it cannot, do not build an elaborate system around the absence.
- Do not block items 1 or 3 on this, and do not ship client-facing disclosure copy without the
  Captain's word — send me the exact wording first if you want it.

---

## 3. The look and feel — this one is a real defect

The Captain looked at the site and reported:

> "The chat widget box looked stretched and logos were skewed too. Ensure this has the smooth mobile
> and desktop look and feel people expect from hd2.ai."

Treat both as layout defects, not opinions.

### Chat widget
- The launcher and the open panel are **distorted in proportion** — stretched rather than correctly
  sized. Fix the container sizing, the panel width and height, and the scaling behaviour at every
  breakpoint.
- It must open, scroll, and close cleanly on both mobile and desktop.

### Logos
- **Skewed** means distorted aspect ratio. Confirm the aspect ratio is preserved and the sizing is
  consistent with the type beside it.

### The standard to meet
`https://hd2.ai` is the reference for the smooth, polished mobile and desktop experience. Match that
quality bar. Do not copy its content or branding — match its standard of finish.

### How it gets verified — and this matters
- **Screenshots, not status codes.** Every fix verified at real mobile (390x844) and real desktop
  (1440x900) viewports, with the widget both closed and open.
- Check the console is clean.
- A fix without screenshots is not done. Report the screenshot paths.
- Verify on a real device emulation, not only a desktop browser resized.

---

## Boundaries

No production change to core-distro.com — staging only. No spend, no DNS or registrar work, no
credential change, no customer-data inspection. If any fix needs production, propose it with the
rollback and wait.

## Report back, in this order

1. The dated content plan, then what you built against it.
2. What you built against the plan and what you left out, and why.
3. Citations: what was possible, in one paragraph.
4. Widget and logo fixes with screenshot paths at both viewports.
5. Anything blocked, with the exact blocker.

VERDICT line required.