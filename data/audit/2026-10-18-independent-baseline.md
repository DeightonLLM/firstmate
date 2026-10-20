# Independent baseline — 2026-10-18

**Sequence commitment:** This baseline was derived from the four requested source documents before inspecting any sibling audit output. The requested `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PD_V3.md` is absent; I used the fallback `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (2,071 lines, read in full). I also read `PRD_TRACEABILITY.md` (339 lines), `PRD_DELIVERY_MAP.md` (136 lines), and the Whoosh domain PRD template (1,615 lines) in full.

## Baseline rule

These sources describe different things and must not be flattened into one completion label. The infrastructure PRD is an approved target architecture whose implementation is gated by inventory validation. The delivery map is a campaign-level evidence/status synthesis dated 2026-09-14 and updated with later notes. Traceability records item-level claims but often points back to that same map; it is not an independent second proof. The Whoosh PRD is an approved, gated implementation direction updated 2026-10-17, not evidence that its planned system exists. `ACCEPTED` in a task manifest is explicitly not equivalent to PRD acceptance. A stated architecture, acceptance test, plan, synthetic test, task prompt, or audit is not a live end-to-end deployment.

The map's 2026-09-15/18 campaign evidence is older than the verified 2026-10-12 Core coordinates and the 2026-10-17 Whoosh public observations. These dates constrain freshness; no current live checks were made for this baseline.

## Four domains

| Domain | Correct source-supported status | Evidence and limits |
|---|---|---|
| Core Distro | **EVIDENCED, not delivered against PRD v3; target-architecture conflict unresolved.** | The map and traceability report real PHP production/Next staging, MySQL/Percona, auth/lead-list and queue-like job evidence, plus 2026-10-12 DNS/HEAD coordinates: Namecheap PHP and Contabo agents. The PRD explicitly records those facts as a production reality gap from its Hostinger public/control plane + Hetzner compute target and says an ADR is required before decisions. Route QA is not full deployment acceptance; hydration/auth and other gates remain open. Do not call the four-project PRD rollout complete. |
| Elevate Life Sci | **Narrow customer-facing site DELIVERED; overall PRD domain status incomplete/unproven.** | Map/traceability cite BR-ELEVATE-IDENTITY-001 and BR-ELEVATE-SEO-PERF-001 for a working site/dashboard scope, last verified 2026-09-15. They explicitly say PRD-wide app/API/queue/backup/isolation acceptance is unproven. Ops-provider work is authorization-blocked. The infrastructure PRD's life-sciences discovery gate prohibits inventing requirements or assuming PHI. |
| Whoosh Performance | **Implementation status UNKNOWN / discovery-gated; no accepted campaign delivery evidence in these sources.** | The delivery map/traceability mark audit blocked by missing repository/hosting/runtime/IP coordinates and warn against claiming bot routing complete. The separate Whoosh PRD is a current approved direction, not an as-built record: it requires inventory and backup validation before production changes. Its Oct 17 public checks saw a parked root site and 502s on `data`/`lc`, while explicitly warning these observations do not prove the underlying systems absent and `lc` may not be a public site. Source location and expected behavior remain to be confirmed. |
| CBD-Data | **EVIDENCED source/audit and bounded local/private slices; not delivered as the PRD platform.** | The map cites real Next/PHP source and accepted BR-AUD-005 discovery, plus local restore docs/tests. Traceability adds a local canary, bounded enrichment slice, and private `/cbddata` RabbitMQ bootstrap, but explicitly notes absent publisher/consumer adapter, project identity/idempotency, durable persistence/restore, and end-to-end Hostinger-to-Hetzner acceptance; Gate-004/cutover remain unauthorized. No completed production rollout is evidenced. |

## Four cross-cutting areas

For an auditable four-area summary, related map gaps are grouped here; grouping is mine, not a source's new status scheme.

| Area | Baseline status | Evidence and limits |
|---|---|---|
| Shared platform, hub, and compute runtime | **Partial evidence; application/runtime delivery unknown or blocked.** | Host installation (BR-HUB-006) and private setup/gateway specifications are evidenced, but placeholder keys, deferred app deployment/live gateway, and missing accepted compute execution/restore evidence prevent calling the Brandon hub or compute runtime delivered. Offline gateway spec/tests are not executable live service proof. |
| Project isolation and job/data path | **UNKNOWN / no accepted end-to-end proof.** | Delivery map says no production proof of four queue namespaces, worker denial tests, scoped ingest, file namespaces, DB roles, or Qdrant isolation. The PRD mandates these as acceptance requirements; requirements are not implementation evidence. CBD's private queue bootstrap is bounded prerequisite evidence only. |
| Release controls and observability | **UNKNOWN / not accepted as platform-wide implementation.** | Map says local hardening/self-tests do not establish each project's CI/build/security/migration/staging/smoke/health/rollback gates; no complete four-project SLO/alert/restore-age deployment is evidenced. PRD's CI/CD and monitoring sections remain target requirements. |
| Backup, disaster recovery, and provenance | **UNKNOWN / blocked; designs and synthetic tests are not proof.** | No accepted live encrypted off-host assignment per project, real restore, measured RPO/RTO, or required DR drill. BR-OPS-002 is explicitly synthetic acceptance-not-proof; BR-HUB-010 awaits provider/account, retention, RPO/RTO, and key-custody input. Historical source blob is reported absent, while the canonical warehouse PRD is present; exact-byte historical provenance remains distinct from implementation status. |

## Correlated-error checks to apply to sibling claims

1. **Do not inherit status from a source's citation of another source.** Traceability frequently derives status/evidence from the delivery map; agreement between them is not independent corroboration.
2. **Do not convert task acceptance or evidence existence into product delivery.** The map explicitly warns that manifest `ACCEPTED` includes audits, offline specs, synthetic tests, and operator-gated tasks.
3. **Do not treat target requirements as observed infrastructure.** PRD architecture diagrams, service layouts, acceptance lists, and Whoosh plans are not proof of deployment.
4. **Do not generalize narrow releases.** Elevate site/dashboard release is not PRD-wide acceptance; the CBD queue bootstrap/local adapter is not end-to-end delivery; a Core route QA PASS is not target rollout.
5. **Do not treat absence of surfaced evidence as proof of absence.** Especially for Whoosh, the evidence says coordinates/source are unknown, not that the repository or service does not exist. The Whoosh 502s do not establish the expected `lc` HTTP behavior.
6. **Do not treat stale evidence as current.** Most map rows are verified 2026-09-15, with some 2026-09-18 notes; Whoosh's separate observations are 2026-10-17. Freshness labels do not refresh evidence.

## Provenance hazards observed before sibling review

- The traceability and delivery map cite a preserved session path under `/root/pi-recovery-snapshot-20260805T233406Z/...` for historical PRD source reading. The current checkout cannot independently inspect that external path; it is a provenance pointer, not independently reproducible evidence here.
- The source says the historical Git blob `b98c887b8abdf0041d52faf2405ec5a76ec8fcf2` is absent from the current object database, while the canonical warehouse PRD is present. A sibling must not call current canonical-file reading proof that the historical blob or exact original bytes were checked.
- Labels such as `Last verified: 2026-09-15` and `Freshness days: 30` in traceability rows appear alongside October 2026 review context. They describe the cited evidence's age, not a current verification. Treating them as fresh/live checks is a fabrication risk.
- PRD labels such as “approved architecture direction,” “approved direction,” or “required” describe authorization/specification of intended work, not implementation state.

## Baseline verdict

**These four domain PRDs are not safe to treat as a working baseline for implementation without qualification.** The Whoosh document is a useful, current, inventory-gated project direction, but it is not an as-built baseline. The Brandon v3 infrastructure PRD is a target architecture with a material known Core production divergence and multiple explicitly unproven project/platform gates. It is safe to use as a requirements/decision baseline only if each planned item is kept separate from measured deployment facts and the listed blockers/unknowns remain visible. No source supports claiming all four domains or cross-project acceptance complete.
