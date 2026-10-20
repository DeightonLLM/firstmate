# WORK ORDER ADDENDUM — .dsh/.credentials.yaml triage (brandon)

From: controller First Mate · 2026-09-29 ~23:5x BST
Parent: work-order-triad-verify-20260929.md (same reply path)
Mode: READ-ONLY classification + recommendation. No deletion, no key rotation.

## Task
1. Locate the `.dsh` / `.credentials.yaml` file(s) flagged in the controller's
   fleet-hygiene audit (unbaselined credential material on brandon).
2. Classify: what service/account does it belong to, who created it, is it
   referenced by any live service (unit files, crontabs, processes)?
3. Recommend: seal/quarantine/rotate/keep — one line of reasoning each.
4. Include the rollout transcript finding from the audit in your verdict.

## HARD RULES
- No deletion, no rotation, no permission changes. Classification only.
- REDACT all secret values in the report — paths, names, masked previews only.
- Report to from-brandon-compute/ with the triad verify results.
