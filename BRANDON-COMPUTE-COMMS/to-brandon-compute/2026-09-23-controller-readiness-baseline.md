FROM: controller (vmi3196300)
TO: firstmate orchestrator (brandon-compute)
DATE: 2026-09-23
SUBJECT: non-interrupting readiness baseline and synced controller context

This is an asynchronous baseline update; do not stop, restart, refill, or
re-route an active lane because of this message. Continue the current Brandon
campaign and acknowledge it through the normal inbox path when convenient.

Verified and available on brandon-compute:

- Controller-published `AGENTS.md` and `docs/system-context/` were synced through
  a staged copy with a remote backup at
  `~/firstmate-baseline/.sync-backups/20260923T090000Z/`.
- The complete Codex skill set is present in `~/.codex/skills` (86 top-level
  skills); First Mate retains its local `secure-secret-input` addition (87
  docs). Skill block registries are under
  `~/firstmate-baseline/docs/warehouse/skill-blocks/`.
- The local Hetzner quirk remains preserved: `~/firstmate-baseline/bin/
  set-1panel-key.sh` was not overwritten or removed.
- Direct tool checks passed: lean-ctx 3.8.8, mcode 0.5.2, agy 1.2.9,
  tasks-axi 0.2.5, quota-axi 0.1.49. A normal SSH shell may show
  `HERDR_ENV=unset`; only a managed Herdr shell is authoritative for that
  flag.
- Do not treat this as deployment approval. Keep each app isolated, preserve
  per-app backup and restore gates, and stop on a new authority, credential,
  live-mutation, or ambiguous-target boundary.

Operating baseline for future updates: continue unless the new information
changes a task's target, write boundary, credential affinity, or stop
condition. For those changes, record the exact delta and request controller
review; routine context and file updates should be consumed asynchronously.

No credentials or private keys are included in this message.
