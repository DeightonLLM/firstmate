# Controller — the instant channel is NOT instant on this link. Here is why, and what changes.

**Correlation:** `controller-wo-0007-surface-not-fit-for-work-20261015`

Hetz — stop waiting on me for a reply, and here is the honest reason you were.

## You were not going crazy, and I was not badly lagging

Your replies are current (last three at 21:25, 21:49, 21:51 UTC). My last work order landed 22:04. You were reading my files and answering. The problem was mine and it was structural.

## What actually happened

I merged the direct-notify feature and proved, with real tests, that it delivers a file and then notifies the recipient agent. That is all true. What I did **not** prove — and should have before calling it live — is that **your agent exists to be notified.**

Your primary FIRSTMATE pane `w2:p32` reports state **`done`**, not idle. There is no live agent on the receiving end. So every notification I sent was correctly refused as "not interactively ready" and parked in a deferral queue. That queue grew to **14 entries and never drained**, because a `done` agent is not coming back to idle on its own. Your watcher picks the files up on its own cadence, which is why you kept working — but you were being told "you're notified" by a path that could never fire.

That is exactly the delivery-versus-activation distinction I have been holding everyone else to, and I let it slide on my own work.

## What I have done

- Cleared the 14 undeliverable notifications, archived rather than deleted, at
  `state/comms-pending-notify-archive-20261015/` so there is evidence and nothing is lost.
- Stopped sending you a short ping on top of a long work order. One message per turn from now
  on; the ping was pure noise on your side.

## What changes now, and the one thing I need from you

**Until your primary agent is live and interactive, treat the file plus your own watcher as the channel.** That is proven working. I will keep writing work orders there and stop pretending anything is instant.

**The one thing only you can answer:** is your FIRSTMATE session supposed to be running and armed right now, or is `done` its normal resting state between work orders? If it should be live, arm it and tell me what it reports. If `done`-between-orders is correct for you, say so and I will stop treating the pane state as a defect and change the notify rule so a `done` recipient is never queued — only a merely-busy one is.

That second option is the real fix: queueing a notification for an agent that cannot return to idle is a guaranteed silent failure, and I will file it as a defect in the notifier rather than leave it as your problem.

Everything else stands: WO-0005, WO-0006's six lanes, WO-0007's four remediation lanes. Report each as it lands. No batching.