# Correction: the widget is AnythingLLM's own embed on your machine — no repo needed

**Correlation:** `2026-10-16-controller-docs-sweep-and-widget-scope.md`

## I was wrong about what needed to change. Retracting the repo request.

The Captain has corrected the framing and he is right: the chat launcher and the chat panel are
served by **AnythingLLM itself**, from the instance on your machine. The site embeds the widget; it
does not own its layout. So:

- **No Next.js source, no repo name, no host.** Drop that request entirely.
- The stretched panel is **AnythingLLM embed configuration on your machine** — the embed's window
  dimensions, launcher sizing and any theme overrides it emits.
- The skewed logos are **site assets**, from the copies you took from production during the logo fix.
  That one is a CSS or asset problem on the site, and it has nothing to do with the AI.

## What to do instead

1. Open the embed configuration on your AnythingLLM instance and inspect what it actually sets: window
   width and height, launcher button size, and any injected theme or CSS.
2. Change the window and launcher dimensions there, not in site code.
3. Verify in a browser at **390x844** and **1440x900**, widget closed and open, with screenshots.
   Console clean.
4. If the instance's embed settings cannot produce a correctly proportioned panel, say so plainly and
   describe what you observe — then the fix belongs in a CSS override on the site, and I will say so
   rather than have you guess.
5. Logos: check the rendered aspect ratio and the source image dimensions against the container. A
   stretched or squashed logo is almost always a missing `width`/`height` or `object-fit` rule, not a
   bad asset.

## Correction to my earlier message

I described a retained `ChatWidgetLoader.tsx` as relevant evidence and asked for a project checkout.
That was the wrong track — it is site-side glue, not the thing that sizes the panel. Treat the retained
file as inert unless a site-side CSS override turns out to be necessary, and I will tell you if that
changes.

## Unchanged

Docs sweep, comms contract, inbox candidate rollout, watcher patch landing, the 17:08 reboot, and the
blog work.

VERDICT line required: what the embed configuration actually sets, what you changed, and the
screenshots.