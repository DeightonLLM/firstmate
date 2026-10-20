# Provenance-label repair lane — 2026-10-18

## Changed

- `data/prds/core-distro-prd-v1.0.md`: removed the false implication that BR-AUD-002 proves all v3 product patterns are implemented; retained the product-identity conflict and marked unsupported application-pattern mapping UNKNOWN with settlement evidence. Replaced the invalid v3 §10.4 TLS attribution with a limited §11.4 target-requirement citation and explicit UNKNOWN for unsubstantiated controls.
- `data/prds/cbd-data-prd-v1.0.md`: changed disputed TDD/full-suite proof to UNKNOWN/OPEN CONFLICT and stated what evidence settles it; downgraded live AminoVPS activity to UNKNOWN while retaining dated placement evidence; normalized unsupported `CONFIRMED` to EVIDENCED and explicitly cited v3 for the target comparison; attached `[PER v3 §2.4]` to the product-scope heading.
- `data/prds/whoosh-prd-status-brief.md`: replaced the 373-line derivative with a short status brief pointing to authoritative v1.0; preserved the two dated 502/no-HTTP-response observations as OPEN CONFLICT; removed claims that curl failure proves NXDOMAIN, absent DNS records, or absent host. No Whoosh requirements or acceptance criteria were changed in authoritative v1.0.
- `data/prds/elevate-life-sci-prd-v1.0.md`: corrected sampled current-state issues: public dashboard-root 200 claim is UNKNOWN against the reported 401; Sept. 19 observations are historical rather than VERIFIED TODAY; `/api/health` is kept separate from other paths; runtime versions are attributed to HOSTS.md; DNS inventory absence is described as an evidence gap; and the 2026-10-18 reported internal :8000 Excalidraw UI exposure is distinguished from API exposure.

## Backups

Created before initial edits (each backup checksum matched its source at creation):
- `/home/hd2admin/kun-agent-workspace/data/prds/core-distro-prd-v1.0.md.bak-20261018T014511Z`
- `/home/hd2admin/kun-agent-workspace/data/prds/cbd-data-prd-v1.0.md.bak-20261018T014511Z`
- `/home/hd2admin/kun-agent-workspace/data/prds/whoosh-prd-status-brief.md.bak-20261018T014511Z`
- `/home/hd2admin/kun-agent-workspace/data/prds/elevate-life-sci-prd-v1.0.md.bak-20261018T014511Z`

Before subsequent Whoosh whitespace and Elevate prose edits, made additional current-version backups:
- `/home/hd2admin/kun-agent-workspace/data/prds/whoosh-prd-status-brief.md.bak-20261018T014558Z`
- `/home/hd2admin/kun-agent-workspace/data/prds/elevate-life-sci-prd-v1.0.md.bak-20261018T014558Z`

The authoritative Whoosh v1.0 PRD was not mutated.

## Verification commands and output

1. `sha256sum /home/hd2admin/kun-agent-workspace/data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md`
   - `ace333174d065c5c341a31ae34b7f8a6d2ee1b8a6c68634798aa26337e10a35d` (matches the audit's recorded pre-edit hash).
2. `git -C /home/hd2admin/kun-agent-workspace diff --check -- data/prds/core-distro-prd-v1.0.md data/prds/cbd-data-prd-v1.0.md data/prds/whoosh-prd-status-brief.md data/prds/elevate-life-sci-prd-v1.0.md`
   - `PASS` (no whitespace errors).
3. `grep -nE 'DNS records themselves do not exist|no host to repair|No DNS A/CNAME records' /home/hd2admin/kun-agent-workspace/data/prds/whoosh-prd-status-brief.md`
   - No matches; wrapper printed `PASS: unsupported DNS/origin assertions absent from brief`.
4. `git -C /home/hd2admin/kun-agent-workspace diff --cached --name-only`
   - Empty output; no staged files.
5. Source reads confirmed the structured CBD traceability YAML explicitly says TDD/checker output was unretained/unverified, whereas the human ledger reports CHECK_PASS; canonical v3 §2.4 places CBD compute on Hetzner; Core audit §F4 identifies the two failed assertions and §F2 documents the host conflict; Whoosh source audit describes the limits of curl evidence.

## Residual risks / incomplete correction

- This pass corrected the concrete failed labels called out for Core and the CBD sampled source-conflict labels, but did not re-audit all 87/139/15/22 claimed label populations row-by-row against every underlying source. The PRDs remain unsuitable as a verified implementation baseline.
- Elevate's 22 sampled-label audit includes additional mislabels outside the edited rows (including source attribution for absence-of-evidence, status evidence, and detailed proposed rollout claims). Those require a full claim-by-claim correction; they are not certified repaired here. Older body sections may retain stale prose, so the new route-specific update must not be read as a global all-API security claim.
- Whoosh's reported apex/`www` evidence remains un-reproduced in this lane; its brief explicitly marks it as reported evidence. DNS remains UNKNOWN until a timestamped query with named resolver and raw response is recorded.
- No tests apply; this is documentation-only work. No live infrastructure or production route was queried.
