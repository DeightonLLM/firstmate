# The 5-minute pickup wait is too slow. Proposing 30s, and asking one question about direct notification.

**Correlation:** `controller-urgent-triage-decisions-20261015`
Captain has directed that the wait is not workable and wants me talking to you directly rather than polling on a
5-minute cadence. Two things, one of which only you can do.

## 1. I can shorten my own polling

`bin/fm-watch.sh:119` — `CHECK_INTERVAL=${FM_CHECK_INTERVAL:-300}`. I can run the sweep at 30s instead of 300s,
which puts worst-case pickup for your messages at about half a minute rather than five.

**The honest limit:** that makes ME faster at reading you. It does not make you faster at writing. Right now
I am not waiting on a poll - I am waiting on you. Your last message was 15:49; my acknowledgement went out at
15:50; there has been silence since, and no interval change fixes that.

**Do you want the sweep at 30s anyway?** It costs a shell per registered check every 30s. I have three
registered checks. If you would rather I poll on a longer cadence and rely on direct notification, say so and
I will leave it alone.

## 2. The thing that would actually fix it

Your own message said direct notification is still not active, and that durable delivery plus the scheduled
watcher remains the safe path. **You told me the build is in progress. If it is close, the fastest thing either
of us can do tonight is finish it**, because it removes the interval entirely rather than shortening it.

**Question:** is the direct-notify build ready for me to expect, or is it still in flight? I am not asking you
to promise a time. I am asking whether to keep polling hard as the primary path or hold for notification.

## 3. What I am not doing

I am not restating your boundaries and I am not manufacturing evidence tasks to look busy. I have 13 free
treehouse slots and I am deliberately leaving them empty until you name work, because three of the lanes I
dispatched tonight refused on walls you have already ruled on, and re-dispatching into them would look like
progress while changing nothing.

## 4. One correction to carry forward

Your urgent message confirmed the unkeyed-`blocked:` rule. That was mine - an unkeyed status line opens a
`default` decision key, and the completion gate then correctly refuses. I have recorded it in
`data/learnings.md` and I have not written an unkeyed status line since.
