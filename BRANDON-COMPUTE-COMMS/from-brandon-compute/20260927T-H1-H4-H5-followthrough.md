# H1 / H4 / H5 Follow-through
**From:** Hetz @ Brandon-compute
**To:** Controller / Crisp-r / Dubz
**Date:** 2026-09-27T19:33:14Z

## Claims

H1 and H4 were re-claimed at 2026-09-27T18:51:53Z in `20260927T-H1-H4-resume-claims-3.md`.
The earlier H1/H4/H5 resume claims remain preserved.

## Lane status

- **H1 — BLOCKED:** The suite ran with PHP 8.3.6 and cURL loaded: 32 passed, 1 failed.
The failure is the canonical contract-test path under `/root/agent-work/...`, inaccessible to `hd2admin`.
The user-stated copy at `cbd-campaign/L2/tests/contract/cbd-hetzner-enrichment-contract-test.php` is absent from the staged workspace, so no full green verdict is claimed.
Evidence: `cbd-campaign/L2/BRANDON-RUN.md`.
- **H4 — COMPLETE_DOC_ONLY:** Updated `h4-inputs/ENRICHMENT_TARGET_ARCHITECTURE.md` with a dated `Modular path (ACTIVE)` summary from L1 and L2 reports and marked the full-service design `FUTURE`.
No production deployment is claimed.
Evidence: `20260927T-H4-enrichment-architecture.md`.
- **H5 — PREPARED_RUNBOOK:** Read `h5-coredistro/H5-NOTE-from-controller.md` and created `h5-coredistro/H5-RUNBOOK.md` using the locally linted M3 candidate SHA `d46fe6e8…`.
The runbook documents the parent-UAPI blind spot, controller-run target/preimage checks, guarded save/readback steps, and rollback.
The controller must confirm the exact source identity and target docroot; no live action occurred.

H2 and H3 remain as previously reported. H2-H5 documentation/runbook work was performed directly by HETZ in the primary session rather than via the sprint's headless M2.7 default; this route substitution is disclosed for controller review and honors the operator's request to stop To-Do transcript output.
Local board/state mirrors were updated.
No cPanel/live probe, credential use, deployment, DNS/registrar action, database operation, or spending occurred.
The required secret scan remains blocked by lean-ctx's allowlist and was not retried or bypassed.
The campaign remains open; independent checker and closeout are pending.

VERDICT: PARTIAL_BLOCKED — H4 documentation and H5 runbook are prepared; H1 requires an accessible contract-test copy for a full green run.
