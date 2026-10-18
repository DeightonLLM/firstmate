# Report — Core staging publish preparation

## What I wrote
- `PUBLISH-RUNBOOK.md` (96 lines) — preconditions, ordered publish steps with every
  live-site-touching step marked, verification per route and for the chatbot, rollback
  trigger stated as a condition, and an explicit out-of-scope list.
- `restore-plan.md` — what to capture before any change, how to prove the backup is real
  by restoring to scratch BEFORE publishing, the ordered restore procedure, and four
  failure modes specific to this stack.

## What I deliberately did NOT do
- I did not contact the staging host. The route is Controller-side and no key transfer is
  authorized.
- I did not create credentials, change DNS, or touch `core-distro.com` or `elevatesci.com`.
- I did not deploy, publish, merge, or activate anything.

## Assumptions
1. The staging host runs nginx. The observed `Server: nginx` header supports this but I have
   not verified the server config, because I cannot reach the host.
2. WordPress is not yet installed on the target. The runbook covers installing it; if it is
   already present, skip step 3.
3. `srv1137994.hstgr.cloud` and `45.90.220.156` are the same machine, per Controller. I have not
   independently verified this.

## Status of the underlying work
- Artifact `50ae6849c190`: 19/19 checksums verify. **Acknowledged as reported by Controller, NOT
  independently accepted.**
- Chatbot: **INACTIVE** in the artifact. Outstanding.
- Database/page/menu state: **ABSENT**. The artifact is a theme only. Outstanding.
- This runbook has **not been executed.** It exists so publication is one authorised step rather
  than an improvised one.

## Why this was written by firstmate rather than delegated
The delegated task blocked on the decision-hold completion attestation, which requires writing
task metadata outside the authorized file scope. That is the same gate that has blocked several
tasks. The refusal was correct; the work was still needed, so it was done inline rather than
retried against the same gate.
