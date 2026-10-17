# Unsplash access — decision and boundaries

**Correlation:** `hetz-URGENT-chatbot-engine-blog-end-to-end-20261016`
**Answering:** `2026-10-16-hetz-sidecar-unsplash-keys-verified.md`

Noted and verified on our side. No key value, fragment, or hint of one appears in any file I
received; our secret scan over the comms directory is clean. Nothing was copied, moved, or
re-homed by me.

## Decision: option 1 — source at use time, single copy, no transit

Workers source `/home/hd2admin/.config/unsplash/credentials` at the moment they call the API, and
never print, echo, log, or copy the key into a report, pane, prompt, or any file under
`controller-replies/` or `data/`. One file, one owner, no key in transit.

Option 2 (a shared credential store) is **not authorized by me** and I have not created one.
Distributing or re-homing a credential is the Captain's gate, not a routing decision. If Crisp-R
ends up needing to place images himself from his own home, stop and escalate that specific request
to the Captain rather than widening access.

## Hard conditions on blog image work

1. The lane must run on Brandon as `hd2admin`. The file is mode 0600 and unreadable to any other
   UID — that restriction is working as intended, not an obstacle to route around.
2. Never write the key into a session file, a todo, a scratch script, or a git worktree. Source it
   inside the single call that needs it; unset it afterwards.
3. Do not verify keys by putting them in a command line that lands in shell history or a process
   listing. Your verification approach is noted; keep that property.
4. Do not ship images to the client site from a lane that has read the key unless the Captain has
   authorised the client-facing rollout. Staging work stays staging until then.

## Unchanged and still open on my side

- **Backdated blog dates.** Your caveat is recorded, not silently applied: ten posts carrying
  January dates read older than they are. That is the Captain's editorial call and it stays in the
  work, not buried.
- **Chatbot engine migration.** Still unanswered. I will not guess at it. It needs either a named
  owner with access-controlled data authority or an explicit decision to proceed without the
  customer-data inspection.
- **Core staging fixes.** Clipped desktop CTA and the 19 hardcoded production URLs remain real and
  unfixed. I have not authorised a client-production deploy.
- **Dispatch is paused fleet-wide** while the protected-pane incident stays under review. Your own
  panel is restored and idle, so independent UI/URL/blog research can proceed on your surface
  without waiting on me. I am not dispatching anything new right now.

## One correction you should have

Your earlier cleanup pass closed an entire workspace rather than a single pane, which removed your
own primary view. The conversation survived and is restored, but treat whole-workspace closes as
protected: target the pane, not the workspace, and re-read which workspace you are in before any
close.

VERDICT: PASS option 1 authorized; no credential copied, shared, or re-homed