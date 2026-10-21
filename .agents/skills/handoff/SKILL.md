---
name: handoff
description: Prepare or receive a complete firstmate handover when the Captain requests handoff, takeover, a replacement coordinator, or a startup prompt that preserves all jobs and gains the canonical session lock.
user-invocable: true
metadata:
  internal: true
---

# Complete coordinator handoff

Use the existing Firstmate startup, ownership, queue and delivery mechanisms.
This skill is model-agnostic; the current task packet supplies concrete model/runtime choices.
A handoff is not permission to bypass admission, discard unfinished work, or claim the underlying system is repaired.

## Task-supplied parameters

Record `HOME`, `PACKET`, `SUCCESSOR_RUNTIME`, `SUCCESSOR_MODEL`, `WORKER_RUNTIME`, `WORKER_MODEL`, `REVIEW_RUNTIME`, `REVIEW_MODEL`, `MAX_CONCURRENT_WORKERS`, and `REVIEW_INDEPENDENCE` in the packet.
These are descriptive handoff parameters, not invented CLI flags or authorization tokens.
Keep the model-specific assignment and temporary promotion dates out of this reusable skill.
Use the Captain's latest concrete routing and concurrency instruction; preserve a separately proposed alternate split explicitly rather than silently changing models.

## Outgoing coordinator

1. Reconcile `BOARD.md`, `CONTROLLER_STATE.md`, `data/backlog.md`, the numbered inbox, staged ticket records, pending captures and received owner messages.
Include overlooked requests, dependencies, original IDs/owners, evidence paths, unresolved decisions and completed work that must not be repeated.
A missing ticket number is not a missing task, and a task folder is not proof of eligible work.
Produce one jobs index, retaining links and exact original identities instead of maintaining a second competing status authority.
2. Use `stow` for memory curation, within its ownership and budget rules.
Capture measured lessons, failed attempts and the precise next evidence; distinguish reported, staged, installed, active and independently accepted results.
Never describe successful polling or file delivery as completed product work.
3. Inspect current pane/PID/task/model/credential-affinity and source ownership before any requested landing or cleanup.
Land only accepted exact changes under current authority, with rollback, through the owning delivery tools.
Then reap only attributable safe completed tasks through their existing guards.
Preserve protected panes, persistent secondmates, active or blocked tasks, dirty copies, unlanded work and unresolved decisions.
If nothing is safe to land or reap, record that and leave it intact; a clean-looking surface is not worth losing work.
4. Write one self-contained successor startup prompt in the packet.
It must carry the full objective, latest routing/concurrency, one complete jobs index, exact read-first order, original ownership, real blockers, allowed recovery, stop conditions, evidence/acceptance requirements and takeover receipt.
A two-line prompt that drops older tasks is not a complete handoff.
Keep secrets and bulk transcripts out; packet paths must be readable on the successor's actual surface.
5. Record the actual transfer state: prepared, predecessor exited, successor owns canonical lock, or successor receipt verified.
Do not claim the last state from a launch command or a prepared prompt.
Do not build a new wrapper, lease mechanism, duplicate lock or background controller to make this handoff appear automatic.

## Canonical lock and startup

`bin/fm-session-start.sh` owns startup composition; `bin/fm-lock.sh` and `bin/fm-session-lock-lib.sh` own exclusive session ownership.
Read their current headers and use the receiving runtime's measured launch/exit behavior.
A currently live predecessor must cease coordination and exit normally before the successor claims ownership, unless an already-supported verified transfer mechanism explicitly provides otherwise.
Do not delete, overwrite or manufacture a live lock, kill a protected conversation, or treat a second private lock as canonical ownership.
A normal process exit leaves the existing owner check to reclaim the stale record through the supported startup path.
The successor runs the composed startup exactly once, not its lock/bootstrap/drain components separately.
On refusal, remain read-only and report the concrete owner condition; never continue dispatch or shared-state mutation.
Do not inherit another runtime's identity markers or reuse the predecessor's conversation.

## Incoming coordinator

Read the packet startup prompt, this skill and current policy; acquire ownership through the composed startup and trust its complete digest once.
Recheck source freshness, current safety admission, target host and live model/route before ordinary work.
Import all unresolved jobs into the visible native To-Do extension, with the required metadata prefix and at least five dependency-aware phases.
Report the canonical ownership result, queue coverage, first eligible batch and precise residual blockers into a durable takeover receipt.
Only after that receipt is supported may the outgoing coordinator or Captain call the transfer complete.
Dispatch up to the requested concurrent worker count when genuine independent tasks and current host/resources/admission permit it.
Fewer eligible tasks means fewer workers, never filler audits or manufactured jobs.
Supervise visible original owners, inspect actual results, return scoped acceptance/corrections and close the loop without making the Captain relay messages.
Use a fresh independent review context and the requested independence standard; a same-family coordinator spot-check is not a different-family review.
Follow the receiving runtime's emitted supervision protocol, not the predecessor's hook assumptions.
Do not emit reassurance on unchanged refresh notices; speak only for verified outcomes, meaningful changes or actual decisions.

## Completion evidence

A prepared packet requires a full jobs index, missed-ticket coverage/limits, preserved lessons, current custody snapshot, safe-cleanup disposition and exact startup prompt.
A completed transfer additionally requires the successor's real canonical-lock ownership and substantive takeover receipt.
Shared skill changes remain subject to the repository's normal review and delivery path; a locally written skill is not a remotely installed, independently accepted or landed change.
