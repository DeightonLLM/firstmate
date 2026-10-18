# Adversarial audit — Elevate Life Sci PRD v1.0

**Target:** `data/prds/elevate-life-sci-prd-v1.0.md` (527 lines; claims 139 provenance rows).  
**Method:** document-only comparison against the complete requested source documents and targeted source/line checks. No project, DNS, host, or service was touched. The PRD itself was not edited.

## Verdict

The PRD does preserve the central historical contradiction and explicitly identifies it as the domain's highest-risk item. It does **not** preserve the current remediated state: it presents the pre-remediation unauthenticated console as current and marks the dashboard's HTTP-200 criterion `DELIVERED`, although the 2026-10-17 verification recorded HTTP 401 with a Basic realm. The status must be re-evaluated against that newer evidence, not silently inferred from the older ledger.

The PRD does not claim that the complete multi-project platform, APIs, queues, backups, or isolation are `DELIVERED`; it repeatedly says those are not proven. It does, however, inflate the narrowly-scoped site delivery into a separate currently-live 200 dashboard claim, which is contradicted by the newer measurement. Other errors are source-label mismatches and stale/unsupported assertions described below.

## Findings

### F1 — The key disagreement is correctly preserved, but its present-day conclusion is stale

- v3 §2.2 says exact Elevate requirements are not proven and lists only potential components: `/home/hd2admin/kun-agent-workspace/docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:92-106`.
- Delivery map says the Elevate operations console existed without an auth wall and exposed unauthenticated status/job APIs; it calls that a remediation candidate, not accepted parity: `/home/hd2admin/kun-agent-workspace/docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md:47-53`.
- PRD explicitly records these as an **OPEN CONFLICT**, names the conflict as highest risk, and does not claim the console is a v3-proven requirement: `/home/hd2admin/kun-agent-workspace/data/prds/elevate-life-sci-prd-v1.0.md:32-43,85-87,116-117,135-146,225-233,246-248`.
- Newer dated verification says the ingress was changed to Basic auth, `GET /` returned HTTP/2 401 with `Basic realm="Elevate Operations Console"`, while `/embed/...`, `/api/embed/...`, and the public client site returned 200: `/home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-18-hd2-fm-reply-prd-review-and-action.md:20-38`.

**Assessment:** The historical disagreement is appropriately recorded OPEN; do not remove it or reinterpret v3. But statements that the console *is currently unauthenticated* are stale. The current report documents remediation; this audit has not independently re-run those live curls. A current independent live check would settle whether the remediation remains deployed.

### F2 — DELIVERED scope is generally bounded, but dashboard criterion is inflated/stale

Traceability defines `DELIVERED` as a customer-facing release live and verified end-to-end, and expressly limits `elevate-site-live` to its cited scope; it says PRD-wide app/API/queue/backup/isolation acceptance is not proven: `/home/hd2admin/kun-agent-workspace/docs/system-context/PRD_TRACEABILITY.md:17-24,30-41`. The delivery map likewise says the Elevate release is for cited scope and not PRD-wide acceptance: `/home/hd2admin/kun-agent-workspace/docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md:1-6,20-27`.

The audited PRD correctly keeps queue, backup, isolation, CI/CD, and full app acceptance `UNKNOWN` in its criteria: `/home/hd2admin/kun-agent-workspace/data/prds/elevate-life-sci-prd-v1.0.md:272-352`. But it separately marks `agents.elevatesci.com` “dashboard with a 200 response” `[DELIVERED]` at line 279 and calls the dashboard/vhost with a 200 path delivered at lines 65 and 152. The latest cited verification instead records root HTTP 401 after Basic auth was enabled (`...2026-10-18-hd2-fm-reply-prd-review-and-action.md:29-38`). Thus this is not evidence of a currently public 200 dashboard; authenticated success would require credentials and an authenticated check, not a no-auth HEAD.

**Assessment:** No evidence of inflation to PRD-wide platform completion. The discrete public-dashboard-200 `DELIVERED` claim is stale/overbroad and contradicted by the newer report. Site delivery remains `DELIVERED` only for its narrow customer-facing site scope. The API 503 recorded in the 2026-09-19 route report (`.../ELEVATE_NGINX_ROUTE_20260919.md:10-22,35-38`) is a separate older route state and cannot establish current API behavior after the later proxy change.

### F3 — Material provenance-label defects in spot-check

The PRD's label definitions require `[VERIFIED TODAY]` to mean this writer measured a command and cites its output; `[PER v3]` means sourced from v3; `[PER TRACEABILITY]` means source row/status/evidence date cited; `[OPEN CONFLICT]` means sources disagree (`data/prds/elevate-life-sci-prd-v1.0.md:46-51`). The following labels fail or materially misstate that standard:

1. **Lines 66-69, 153-154 (`[VERIFIED TODAY]`):** citations are a historical narrative file, `ELEVATE_NGINX_ROUTE_20260919.md`, not commands run by this writer with output. They can support “the report recorded this on Sept 19,” not “verified today” on Oct 17/18. The PRD itself admits direct-read evidence rather than a command transcript at lines 153-154.
2. **Line 77 (`[PER v3]`):** Docker, Percona, PHP, Node, Python, Composer, and Nginx versions are explicitly sourced from `HOSTS.md` and the `BR-INV-001` inventory, not v3 §2.2. `HOSTS.md:86-100` provides these values; v3 §2.2 at `...BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:92-106` does not.
3. **Line 79 (`[PER v3]`):** DNS inventory absence is a current evidence gap, not a v3 fact. v3 Gate A specifies an inventory requirement (`...PRD_V3.md:135-151`); it cannot substantiate “not evidenced for Elevate.”
4. **Line 91 (`[PER v3]`):** “No approved discovery document is evidenced” is an evidence-search conclusion, not a source fact from v3. v3 §20.2 sets an acceptance criterion; it does not report whether an Elevate discovery document exists (`...PRD_V3.md:1997-2020`).
5. **Lines 161-165 (`[PER v3]`):** API 503/no backend, Gate C/D/E absence, and discovery-document approval absence are evidence findings. v3 supplies requirements and target intent, not current findings. API 503 is specifically evidenced by the 2026-09-19 route report, not v3 (`.../ELEVATE_NGINX_ROUTE_20260919.md:10-22,35-38`).
6. **Line 282 (`[VERIFIED TODAY]`):** 503 is based on the Sept 19 report and is superseded as a current-state assertion by the Oct 17/18 reported auth and embed routing changes. The newer report establishes public `/api/embed/...` 200, but not necessarily every `/api/*` path.
7. **Lines 66, 67, 68, 69 and 153-154:** these claims all cite the same dated route report but use `[VERIFIED TODAY]`; none gives the command itself or its execution output in this PRD, contrary to the label definition.
8. **Lines 85-87 (`[OPEN CONFLICT]`):** the label is correct for the historical v3-versus-ledger disagreement, but line 85 says “no auth model is approved” and lines 86-87 present unauthenticated exposure as current. Both are contradicted/updated by the Oct 17 remediation report; record the newer reading as a new conflict until independently measured.
9. **Line 87:** `[OPEN CONFLICT]` is valid for conflicting/historic evidence, but its parenthetical says the evidence file is absent “from the workspace.” The actual absence is asserted by PRD §1.6; this audit did not independently run the PRD's claimed find/bash search, so this remains `UNKNOWN` to this audit.
10. **Line 98 (`[PER TRACEABILITY]`):** the cited traceability row supports `BLOCKED` authorization, but mock test counts and provider-specific restrictions are attributed additionally to `SOFTWARE_LANES.md`, which is outside the label's stated source class. Cite that file directly as its own evidence source rather than attributing the whole claim to traceability.
11. **Line 106 (`[PER TRACEABILITY]`):** the row says ticket 0033 is “reported CLOSED,” but the source identified is the delivery-map Elevate row, not an accepted traceability row for ticket 0033. The claim appropriately says it lacks its own accepted artifact, but this source label must not imply the closure is accepted.
12. **Line 150 (`[PER TRACEABILITY]`):** the cited traceability row narrowly records a customer-facing site release, not an independent current live HTTPS measurement. The PRD notes absent underlying evidence at line 150; status is valid only as ledger-recorded, dated scope.
13. **Line 151 (`[PER TRACEABILITY]`):** 84-file static changes are not a distinct traceability row/status in `PRD_TRACEABILITY.md`; this is delivery-map evidence/cited campaign evidence. Source label is inaccurate unless the exact map row and source artifact are specified.
14. **Line 152 (`[PER TRACEABILITY]`):** dashboard/vhost 200 is not an independent traceability item; now contradicted for dashboard root by the latest HTTP 401 measurement.
15. **Lines 272-273 (`[PER TRACEABILITY]`):** section 20.2 of v3 specifies expected acceptance, it does not prove current 200/TLS/rendering. Delivery map/traceability supports only the cited delivered site scope, not each criterion's live current result.
16. **Line 274 (`[PER v3]`):** unknown exposure status is a lack-of-evidence finding; v3 §16.1 states a policy, not that Elevate passes or has been scanned.
17. **Line 279 (`[PER TRACEABILITY]`):** traceability does not define a currently-200 dashboard acceptance row. The delivery map's older cited scope is not current proof; newer verification reports root 401.
18. **Lines 302, 304-305, 309, 314, 324, 334 (`[PER TRACEABILITY]`):** the cited unresolved areas are relevant evidence boundaries, but are cross-project absence statements, not Elevate-specific measured audits. Keep the claimed `UNKNOWN` and explicitly describe it as “no accepted cross-project evidence surfaced,” not proof no Elevate implementation exists.
19. **Line 342 (`[PER v3]`):** v3 gives a discovery gate; it does not establish the present approval state. This repeats a source-versus-inference label error.
20. **Lines 358-444 (`[PER v3]`):** Phase ordering and broad rollout architecture are genuinely from v3, but the detailed host-specific tasks (e.g., validate `srv1137994` ACLs and create databases) are proposed domain adaptations, not quotations or requirements proven for an Elevate application. Mark the adaptations as proposed scope, not solely `PER v3`.
21. **Lines 484-485 (`[PER TRACEABILITY]`):** acceptance evidence requirement is prospective; traceability's September site row is not the live curl/HEAD output the table says is required. It supports a ledger status only.
22. **Lines 507-510 (`[PER TRACEABILITY]`):** decision options/status are PRD-generated ADR proposals, not traceability records. Only the architecture/placement unknown is source-backed by the map; ownership, alternatives, and “Pending/Blocked” require their own decision evidence.

This is a spot-check of 22 distinct label-bearing claims/sections, not an exhaustive recount or validation of all claimed 139 provenance rows. The report does not label every instance of a repeated issue as an independent defect.

### F4 — Other factual precision gaps

- The PRD describes `/api/*` returning 503 as an intentional current route at lines 67, 153, and 161. The cited evidence is explicitly dated Sept 19 and documents only `/api/health` returning 503. The newer report documents `/api/embed/<id>` 200 and the continued public embed route; avoid generalizing from one API path or carrying Sept routing forward as current.
- The report says `curl -sI` for root returned 401. That is a HEAD result, not evidence that all dashboard/API paths are protected. It records the configured auth wall, with explicit carve-outs for `/embed` and `/api/embed`; the scope and authorization behavior of other API routes remain `UNKNOWN` pending direct checks.
- PRD §1.6 claims a find/bash search established several missing evidence directories/files (lines 123-132), but no command/output is embedded. Those absent source files weaken independent verification of the old ledger's specific claims, though the PRD candidly discloses this limitation.

## Provenance label sample outcome

**Failed or materially misapplied:** at least 22 sampled claims/sections listed under F3.  
**Clearly appropriate in sampled high-risk rows:** `[OPEN CONFLICT]` for the historical v3-versus-ledger dispute (with stale-current-state caveat); `[PER v3]` where used for actual v3 text such as the potential-component list and explicit non-goals; `[PER TRACEABILITY]` for the narrow ledger-recorded `elevate-site-live` and blocked adapter status, if explicitly framed as ledger assertions and not fresh measurements.

## Required corrections before treating this PRD as current

1. Keep the v3 §2.2 versus delivery-map disagreement OPEN and retain its high-risk history; append the newer auth-remediation reading rather than erasing either source.
2. Remove/reclassify the currently-public dashboard 200 `DELIVERED` assertions and update current access findings using authenticated/unauthenticated route measurements with exact paths and outputs. Do not treat 401 as proof all APIs are protected.
3. Re-evaluate `/api/*` assertions path-by-path; differentiate `/api/health` (Sept 19 evidence) from `/api/embed/...` (Oct 17/18 evidence).
4. Correct provenance labels: separate source-recorded historical fact, v3 requirement, inference/absence-of-evidence, and genuinely executed command measurements. Date each observation.
5. Keep `elevate-site-live` `DELIVERED` scoped to the customer-facing site release only; do not promote it to PRD-wide app/API/queue/backup/isolation acceptance.

## Evidence and validation record

- Full reads completed for the requested v3 (canonical `...PRD_V3.md`, 2071 lines; alternate `...PD_V3.md` absent), `PRD_TRACEABILITY.md` (339 lines), delivery map (136 lines), Whoosh template (1615 lines), and target PRD (527 lines). These counts were measured with `wc -l`.
- Source line excerpts: `nl -ba ... | sed ...` and `nl -ba ... | grep ...`; outputs summarized/cited above.
- Newer remediation evidence read in full at `/home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-18-hd2-fm-reply-prd-review-and-action.md:20-38`.
- `git status --short` showed pre-existing unrelated changes/untracked paths (`data/async-lanes.tsv`, `core-distro-saas-clean`, `firstmate`); this audit created only `data/audit/2026-10-18-audit-elevate.md` and did not stage anything. No status output showed staged files.
