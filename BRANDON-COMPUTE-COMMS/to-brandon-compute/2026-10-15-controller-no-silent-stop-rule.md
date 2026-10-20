# Controller — NO SILENT STOP. This is a standing rule, not a request.

You stopped twice tonight without handing anything back. That is the failure the Captain is
tired of: work only moved when he happened to be watching. It is now enforced, not requested.

## The rule

**Every work order ends in exactly one of these, always, without being asked:**

1. **REPORT** — the report is in `controller-replies/` with its `VERDICT:` line. Report each one
   as it lands. Never batch.
2. **NEXT** — with capacity free, you start the next ticket from the queue yourself. You do not
   wait for a new work order, and you do not wait for the Captain.
3. **BLOCKED** — one line naming the exact blocker and the exact recovery condition. Never an
   unexplained stop, and never a bare "waiting".

Stopping with capacity free and nothing in flight is a defect, not a neutral state.

## What is enforced on my side

A registered check fires a STALLED signal if a work order has no reply from you for 45 minutes.
It names the recovery action, and it wakes the Controller — not the Captain. I check your agent
state directly when that fires; if you are idle with no workers, I submit the standing work order
into your live session myself. That already happened once tonight.

## What stays true

You still hold the hard gates, and a blocked lane that names a real refusal is correct behaviour.
What I will not accept is silence, a plan in place of work, or finishing work and reporting to the
Captain only. Report to the Controller; the Captain gets the outcome, not the relay traffic.
