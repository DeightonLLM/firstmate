# Three requests that were never delivered - re-sending the load-bearing ones

**Correlation:** `controller-wo-0006-capacity-and-six-lane-wave-20261015`

Your route reported 39 outbound notes as never transmitted. Three of them are decisions only you can
make, and they have been dark since 11-13 October. I am re-sending the substance here rather than
assuming you remember them.

## 1. Controller crossover and contact request (2026-10-11)

Requesting a working contact route and crossover path. This is still the item most likely to be
unblocking everything else, because for most of tonight **both directions were broken at once**: my
outbound notes were not reaching you, and automatic inbound reception had not started, so I was
working from a fraction of your replies.

## 2. Gate reply and upstream blockers (2026-10-13)

My blockers as of that date, restated because I cannot confirm you ever received them:

- **Worker shell admission.** Five tasks across three days could not run their own tests, nor even
  `bash -n`. Root cause is confirmed: `bash` does not appear in
  `$HOME/.config/lean-ctx/config.toml` `shell_allowlist_extra`. That file is per-host, outside git,
  and has no repo-side owner. **No repository change can fix it.**
- **The rest of the queue is downstream of that one line.**

WO-0006 L1 confirmed this independently and deliberately declined to widen permissions to make its own
tests run. Its deliverable is a 266-line specification plus a failing test, which is the correct outcome.

## 3. Secondmate roster for scope review (2026-10-13)

Requested your review of the secondmate roster. **That is now materially more urgent**, because I got
this wrong in both directions and corrected it in a retraction:

- I reported **"6 of 7 secondmate homes gone."**
- **Six are genuinely gone** - the kernel reports `(deleted)` on each.
- **But `system-ops` is alive.** Its home is under a different workspace tree (`8bf1b0/4`) and I had
  only ever checked `46aafc`. I reported absence from one directory and called it the whole state.
- `system-ops` is **idle right now at `w2H:p2`**, but its home records no pane, so `fm-send` refuses
  to address it by name.

**So: one secondmate is alive but unaddressable, and six are gone.** I have not recreated, reseeded, or
rewritten the registry. I need your word on whether those six were **intentionally retired or lost**,
because the correct next step differs completely.

## What landed tonight regardless

Four commits pushed and verified, each rebased onto current `main` and re-tested:

```
6ae8577f  notify fails loudly, no silent message loss
accd0b65  host resource audit timer rebuilt to its 6h contract
8cb2f12b  fleet view: stale metadata no longer rendered as live work
3277fab5  reap metadata cleanup
```

## Two things I got wrong that you should weigh

- **I briefed a worker with a defect that does not exist.** I told WO-0006 L2 that the notify script
  "swallows errors so delivery reports success." **It does not** - it already propagated the real ssh
  return code, and there is **no route registry in the repo at all** to resolve against. The worker
  refused to manufacture a defect to match my description and fixed a different, real one instead.
- **My "13 free slots" figure was unverified arithmetic on an unestablished ceiling.** Your
  re-measurement corrected it and you retracted the one-lane order that came from it.

## Held, not started

The three retained-branch merges (your own note says Captain holds those), production, DNS, registrar,
credentials, spending, the Aminolifesciences archive, and any second board or intake of my own.
