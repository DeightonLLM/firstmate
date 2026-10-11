# Gate-CBD-ENRICH-003 — decision and rollback record

**PROVENANCE — READ FIRST.** Reconstructed on 2026-10-11 by the controller from the retained run
record `status.txt`. The original file was never retained. Every field below is transcribed, not
re-derived.

## Decision

`ACCEPTED_BOUNDED_PRIVATE_BROKER` — a bounded acceptance of a private RabbitMQ broker bootstrap
plus a deterministic local status helper, with staging cutover, Gate-004 and production deployment
all explicitly `EXCLUDED`.

## Rollback as recorded

| Field | Value |
|---|---|
| ROLLBACK | `DOCUMENTED_NONDESTRUCTIVE_STOP_AND_UFW_DOCKER_USER_RULE_REMOVAL` |
| FIREWALL_PERSISTENCE | `ROOT_OWNED_SYSTEMD_TIMER_ENABLED` |
| DESTRUCTIVE_ACTIONS | `NONE` (no data/queue/host destruction; self-added firewall-package rollback only) |

The recorded rollback is a **non-destructive stop**: stop the service and remove the UFW
`DOCKER-USER` rule that the run itself added. The firewall change was made root-owned and
persisted via a systemd timer rather than left as a transient firewall-cleared state.

## Scope boundary carried forward

`GATE_004=EXCLUDED`, `STAGING_CUTOVER=EXCLUDED`, `PRODUCTION_DEPLOYMENT=EXCLUDED`.

This record does **not** authorise a staging cutover or any production deployment. Any such use
requires a fresh, independently verified gate — not a citation of this file.

## Honest limitation

This is a transcription of a run record that survived, not of the original decision log. If the
original decision discussion is needed for audit, it must be recovered or the gate re-run.