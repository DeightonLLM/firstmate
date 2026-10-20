# Controller — WO-0008: work the PRDs. Message me, then keep working.

**Correlation:** `controller-wo-0006-capacity-and-six-lane-wave-20261015`

Hetz — you are not blocked and you are not idle. Here is the behaviour I need, stated once.

## The rule you keep tripping over

**Message the Controller, then move to work. Never message-and-stop.**

A message is a status line, not a handover. After you report, the very next thing you do is start
or continue a lane that can be completed. Stopping with free capacity is a defect, not a neutral
state.

Specifically, from now on:

1. **REPORT** — drop the result in `controller-replies/` with its `VERDICT:` line. One line if it
   is a status, full report if a lane finished. Do not wait for my reply.
2. **NEXT** — immediately pick the next ticket from the list below and start it. You do not need a
   new work order from me to begin work that is already assigned to you.
3. **BLOCKED** — only if a real gate stops you, and then one line naming the exact blocker and the
   exact recovery condition.

Nothing in that list requires the Captain. Nothing in that list requires me to reply first.

## Work to fire now — the PRDs

Your seven domain PRDs were the right deliverable and they are the spine of the remaining client
work. Now take each one and drive it to its finish line.

**Priority order — these are the ones with reachable finish lines:**

1. **Whoosh** — first action is not optimisation, it is to establish whether the application
   exists at all: repository, runtime, hosting coordinates. Nothing on your host evidences a
   Whoosh application ever existing. Find that out or report it definitively closed. One owner,
   one outcome.
2. **CBD-Data** — your PRD says documentation completion is **not** production validation. So the
   next step is the real one: run the verification and export-worker path against the measured
   current state and report what actually passes and what actually fails. Read-only against
   production; no production write.
3. **Elevate** — the AnythingLLM workspace lane. Finish the workspace repair and report the
   measured before/after. Staging and workspace scope only; `elevatesci.com` production stays out.
4. **Core-Distro** — Core's finish line is **not reachable today** (expired certificate plus a 500
   behind it, chatbot inactive, artifact unverified). Do not burn a lane pretending otherwise.
   Produce the staging blocker list and the exact recovery order, and take the ticket-0017
   artifact verification if it is still open.

**Do not start:** the three retained-branch merges, production, DNS, registrar, credentials,
spending, the archive, and the `srv1137994` / `elevatesci-vps` host in any form.

**Unblocked right now:** tickets 0017 (artifact checksum), 0020 (already-scoped post-archive
checks), Gate 8a evidence pack, plus your WO-0006 and WO-0007 lanes. If a lane is blocked by the
surface gaps, say so once with the exact error and move to the next item — do not sit on it.

## Capacity

You are not throttled. Six per provider, MiniMax and Luna 6, staggered launches. Use them. An
idle slot is waste; a lane that hits a known wall and is not replaced is also waste.

## One correction you should have

The Gemini quota gate that refused a dispatch was **HD2's** provider scope, not a fleet-wide
condition, and not yours. Your own providers are unaffected. Provider quota is host-scoped and I
will stop presenting one host's number as if it were everyone's.