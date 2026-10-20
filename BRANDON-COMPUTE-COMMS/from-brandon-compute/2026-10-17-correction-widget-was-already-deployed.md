# Correction: the widget fix was already deployed. Current staging is a regression AFTER it.
Correlation: comms-lane-naming-contract-20261017

I was wrong twice tonight about this lane and both errors were mine, not the evidence's. Correcting the record before anything is reaped.

WHAT ACTUALLY HAPPENED, from the lane's own report, which I had wrongly recorded as missing because I looked for it in the firstmate home instead of the lane's worktree (`data/2026-10-17/reaped-lane-lookfeel/report.md`, sha256 9f5dc71ac2684f0613fe265a0823920d5fec68f5984a7b7125628b6d53430c0c, with six screenshots preserved beside it):

- The widget stylesheet was returning 404, so the overlay never positioned. That was the real cause of the stretched panel, not the panel dimensions themselves.
- The fix restored the stylesheet route and added bounded host sizing: 400x640 desktop, a viewport-bounded mobile panel, safe-area spacing, and fixed positioning that survived page scroll.
- Logos were fixed by replacing a forced `aspect-ratio: 1/1` with `object-fit: contain`, which matches the 1568x940 intrinsic ratio my later lane measured independently.
- Console was cleaned, including two accessibility issues in the newsletter inputs.
- It was DEPLOYED to staging as release `release-lane-lookfeel-20261016_220310`, with the previous release retained as `backup-lane-lookfeel-20261016_220310`. Typecheck, 4/4 tests and build passed.

WHAT MY LATER LANES MEASURED, after that deploy: the panel renders at width 0 and height 0, makes zero backend calls, and `/llm/chat/` returns 404 from nginx.

So this is a REGRESSION AFTER DEPLOY, not unfinished work. The most likely candidate is the 17:08 staging reboot you mentioned, but I am not asserting that without your evidence.

Three asks:
1. Which is current: the deployed release, or what is live now? If the reboot reverted or half-applied it, tell me and I will treat the backup release as the known-good reference rather than re-deriving the fix.
2. Confirm whether `/llm/chat/` should answer on that host. My lanes measured 404 from nginx there; your note says the verified streaming route is `/api/embed/{embedId}/stream-chat`. Those are different paths, and the widget requests the former. Which is correct for the embed?
3. Two keys remain open from that lane and neither was closed by measurement, only by constraint: `[key=chat-history-scroll]` (a populated transcript was never exercised because sending a message incurs spend) and `[key=ask-questions-shortcut]` (the mobile shortcut loaded the embed but did not open it in emulated interaction; opening was verified via the floating launcher instead).

Also correcting myself on process: I nearly reaped a pane whose deliverable was deployed and whose report I had declared missing. The lesson is recorded, and the report plus screenshots are now preserved in this home rather than in /tmp where they could vanish.

VERDICT: widget fix deployed with evidence and preserved; current staging is a post-deploy regression; two named keys still open; no re-prod work started and nothing discarded.