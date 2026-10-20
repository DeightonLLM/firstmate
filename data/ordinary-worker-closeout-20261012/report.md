# Ordinary-worker cleanup and landing pass

Captain explicitly requested cleanup and landing of ordinary workers, excluding secondmates.
All secondmate homes/endpoints and the six unfinished reliability scouts were preserved.

## Actual result

`mm-saas-fastpath-benchmark-0926` passed guarded cleanup: clean isolated copy returned to the pool and task runtime records cleared.
Its report remains at `data/mm-saas-fastpath-benchmark-0926/report.md` and is explicitly INVALID for release/deployment decisions because a pre-existing database container was reused.
No database/container removal or benchmark rerun occurred.
Its recorded endpoint was already gone; this removed stale task/copy occupancy, not a live secondmate or a verified running worker.
Cleanup's automatic backlog update found no original task row, so the missing original-ID row was reconstructed through supported tasks-axi and closed solely as archived invalid evidence plus successful cleanup, with the explicit invalid-result limitation.

## Landing not performed

The recorded PR https://github.com/DeightonLLM/firstmate/pull/3 is OPEN, with six passing and four failing current checks.
Its recorded head differs from the pipeline attestation head, and crew-state says unknown/passed-with-override, not a proven current-head green result.
It was not merged or cleaned up.
`tool-auto-update` has no current-state source and its recorded endpoint is gone; its old project/base remains unreconciled. No local merge was attempted.

## Unsafe stale inventory preserved

`context-continuity-audit` points to the preserved dirty Pi TODO branch at `1d3846b3...` with modified `tests/fm-brief.test.sh`; no cleanup was attempted.
`window-cleanup-inventory-0923` shares a recorded copy with the old repair ship and its historic pane corresponds to the previous primary; its stale report is not current removal authority.
Old `hetz-study-20261005` and `kun-video-source-study` records point to the current core-ops secondmate copy; `kun-config-inventory` points to the Whoosh secondmate copy. These are excluded from cleanup until original-task custody is reconciled.
The historical cleanup report's claims that old queue-pump/status-dir work was safe are contradicted by later evidence. Their unlanded work remains intact.

## Operational blocker

The supported fleet view failed before rendering:
`fm-fleet-snapshot.sh: line 567: /usr/local/bin/jq: Argument list too long`
`fm-fleet-snapshot: main inventory summary failed`
No retry or source edit was performed. Targeted task metadata, current-state, git cleanliness and public PR checks were used for this bounded pass.
Task #30 remains in progress: additional ordinary-worker candidates and landing require trustworthy current ownership/gates; no blanket success claim.
