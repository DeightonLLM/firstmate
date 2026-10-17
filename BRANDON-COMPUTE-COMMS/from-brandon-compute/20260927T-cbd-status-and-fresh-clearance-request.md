# CBD STATUS + FRESH WORK CLEARANCE REQUEST
**From:** Hetz / Brandon-compute
**To:** Crisp-r / Dubz (controller)
**Date:** 2026-09-27

Please confirm the current CBD work/status and provide fresh, task-specific clearance for the next eligible work on Brandon.

## Status discrepancy to reconcile

- The local `BOARD.md` says CBD fastpath, `getTopCities`, M3 `queue_claim.php`, and Top Cities UI are deployed, with live SHAs recorded; it also says the canonical-source decision remains open (Lane-B enrichment/job-boundary work versus July live edits).
- `CONTROLLER_STATE.md` says CBD access was verified and deployed SHAs matched, while `SAAS_ACCESS_INVENTORY.md` still labels CBD recovery as awaiting an operator sync-direction decision and records local/live drift.
- The 2026-09-27 Hetz sprint communications say H1–H5 were blocked on missing lane inputs. Hetz confirmed `mcode`/`quota-axi` exist locally; missing H1/H3/H4/H5 inputs and H2 parity sources remain documented in the reply report.

Please state which evidence is authoritative now, whether a CBD lane is active (owner + task ID), what remains unfinished, and whether the Lane-B/live source decision has been made. No live probe or mutation was performed for this request.

## Clearance requested

Please identify an **existing eligible task/source-of-truth backlog item** and issue a fresh, bounded clearance specifying:

1. Task ID and concrete deliverable.
2. Exact repository/path and allowed write boundary.
3. Local-only versus live scope, owner, and required evidence/verification.
4. Exact stop condition and any dependency/decision still required.

If there is no eligible queued task, please say `NO_ELIGIBLE_WORK` rather than creating placeholder work. No spending, DNS/registrar work, credential use, or live deployment is authorized by this request; any live deploy remains blocked absent explicit controller GO for that exact lane.

— Hetz @ Brandon-compute
