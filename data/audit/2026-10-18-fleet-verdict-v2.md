# Fleet integrity verdict v2 — 2026-10-18

## Coverage and prior verdict

All five sibling reports named for this review were present and readable. Measured byte sizes:

| Report | Bytes |
|---|---:|
| `2026-10-18-audit-core-distro.md` | 14,838 |
| `2026-10-18-audit-elevate.md` | 14,859 |
| `2026-10-18-audit-cbd-data.md` | 14,911 |
| `2026-10-18-audit-whoosh.md` | 7,601 |
| `2026-10-18-audit-cross-cutting.md` | 12,783 |

The earlier `2026-10-18-fleet-verdict.md` is **void as a cross-lane verdict**: it explicitly says only the Whoosh report existed at its inspection and disclaims coverage of the other four reports. Its one-lane conclusions are not thereby all false, but its purported fleet disposition cannot be relied on now that it omits four extant reports and predates both parent corrections. This v2 replaces it for fleet coverage.

## Claim review

Classifications concern the material propositions in each report, not the siblings' confidence. Report/source citations below were checked against the cited local documents; no live infrastructure was queried for this review.

### Core Distro

| Material claim | Verdict | Independent basis / qualification |
|---|---|---|
| The PRD preserves v3-vs-current application identity and target placement as unresolved rather than claiming migration completed. | SUPPORTED | `core-distro-prd-v1.0.md` §§0–1, 7 records the Namecheap/PHP, Contabo, AminoVPS readings and makes v3 adoption ADR-dependent. v3 §§2.1, 7 identifies its own production-reality gap and target. This is a requirements/status record, not proof of current live deployment. |
| BR-AUD-002 does not substantiate every v3 expected product pattern; line 76 over-attributes implementation evidence. | SUPPORTED | PRD lines 70–103 juxtapose expected v3 patterns and the audit's narrower SaaS findings; `PRD_TRACEABILITY.md` coredistro source-runtime row records limited source/runtime evidence. The lane's exact audit citation supports the specific narrower items it enumerates, not every expected pattern. |
| Namecheap public endpoint evidence vs Contabo cPanel deployment host is unresolved. | SUPPORTED | PRD lines 111–115 and 144–149 record the different readings, without a reconciled origin/deploy map. The cited ledger/delivery map as summarized in the sibling do not settle proxy vs deploy-host meaning. |
| ADR first is required before v3 architecture/migration decisions. | SUPPORTED | v3 §2.1 production-reality-gap and PRD lines 41–43, 798–806 state that ordering. |
| Chatbot status lacks current shell-response evidence, and no assistant response was verified by the sibling's GET probes. | SUPPORTED as an evidence-bound finding | PRD §24 says no source for its specific “Invalid session ID” report and refers to a different 404; sibling documents GETs returning HTML shells and expressly did not POST a chat request. GET/HTML 200 is not a chat reply. The source reports' conflicting historical test results remain unresolved. |
| TLS/security-header provenance at PRD line 521 cites the wrong v3 section. | SUPPORTED | PRD line 521 cites v3 §10.4; v3 §10.4 is Docker networks. TLS/header controls appear elsewhere and do not establish all the listed controls. |
| The 87-row / label-count discrepancy is real but not a substantive product defect. | SUPPORTED, limited | Sibling reports its grep count of 88 label occurrences including definitions, while PRD legend states the count. This is a count/provenance reconciliation issue; it does not validate the underlying assertions. |

### Elevate

| Material claim | Verdict | Independent basis / qualification |
|---|---|---|
| Historical v3-versus-real-console disagreement exists, but prior PRD text incorrectly described unauthenticated access as current. | SUPPORTED | The older PRD body (e.g. lines 157–162, 250–257, 305–311) still contains that finding; delivery map's cited status is dated. It must now be read with the new update. |
| Dashboard 200 `DELIVERED` claim is overbroad/stale given root 401. | SUPPORTED | New PRD preamble records `/` 401 and embeds/API 200; old line 279 and other claims collapse dashboard response into 200. A 401 root does not prove all APIs are protected. |
| At least 22 sampled provenance claims/sections are inaccurate or overstated. | SUPPORTED as a bounded sample | Checked examples align: PRD cites `[VERIFIED TODAY]` for historical Sept. 19 evidence; v3 requirement citations are used for absence/current-state inferences; PRD's line 77 versions are sourced to HOSTS/inventory, not v3 §2.2. This is a sample, not confirmation of a complete 139-row audit. |
| `/api/*` 503 generalization is stale; older `/api/health` evidence cannot define current `/api/embed/<id>` behavior. | SUPPORTED | PRD old lines 67/153/161/282 generalize; remediation update separately records `/api/embed/<embed-id>` 200. This proves only that exact documented route observation, not all API paths. |
| 401 root response establishes that the whole console and all status/job APIs are secured. | UNSUPPORTED (the sibling does not claim this; PRD still risks it) | Preamble supplies root 401 only; no per-API authenticated/unauthenticated response evidence is embedded. The PRD leaves API requirement blocked/unknown in places, correctly. |

**Parent correction accuracy/completeness:** The added 2026-10-18 update accurately distinguishes observed root 401 from continued public embed/API embed 200 and marks the exposure resolved. Its listed response codes are present in the document, but this review could not independently reproduce the live measurements. The correction is **not complete as a document reconciliation**: legacy body text remains contradictory (lines 106, 108, 162, 181–182, 250–257, 307–311, 486, 489, 527); some entries still call the console currently unauthenticated or unresolved. The opening update's claim that every unauthenticated statement below is historical is not actually made explicit at each stale blocker/checklist/risk assertion. It also says “public embed and customer chat paths were verified still serving,” while the tabulated evidence only gives HTTP 200 on the JS and API embed paths; it does not show a chat transaction or assistant response. That is a new overclaim unless a separate chat test artifact exists. Keep exact embed-route 200; do not treat it as verified assistant chat.

### CBD-Data

| Material claim | Verdict | Independent basis / qualification |
|---|---|---|
| Gate-003 is bounded private `/cbddata` bootstrap/status helper; no end-to-end flow or Gate-004/cutover authority is established. | SUPPORTED | PRD lines 68–81/176–177, traceability rows and delivery-map Gate-003 scope distinguish bootstrap/helper from publisher/consumer, identity, persistence, deployment and acceptance. No authorization lift follows. |
| TDD/full-suite independent-check claim is not securely established because source records conflict. | SUPPORTED | The report identifies human ledger/map as passing but structured `prd_traceability.yaml` as reconstructed with underlying outputs unretained/unverified. The PRD's EVIDENCED claim cannot resolve that contradiction; classify the proof UNKNOWN pending raw output/reconciliation. |
| Product functions are listed, but acceptance criteria omit explicit share links, CRM and paid-plan API coverage. | SUPPORTED | Eight functions appear in PRD §0.1; cited AC range does not separately test those three. This is a coverage omission, not proof features are absent. |
| Active AminoVPS worker placement conflicts with v3 Hetzner target; current activity itself is uncertain. | SUPPORTED | Service-catalogue and inventory readings place it on AminoVPS; v3 §2.4 places compute on Hetzner; older canary and newer catalogue dates conflict. None of those dated artifacts alone proves audit-date liveness. |
| Provenance-count and `[PER v3]` label-application concerns. | SUPPORTED, bounded | PRD's definition/summary occurrences do not amount to independently sourced row labels; cited count includes definitions/taxonomy. The label-count is not evidence that all PRD claims are wrong. |

### Whoosh

| Material claim | Verdict | Independent basis / qualification |
|---|---|---|
| Ledger statuses whoosh-audit BLOCKED/COORDINATES_MISSING and bot-routing UNKNOWN are accurate. | SUPPORTED | `PRD_TRACEABILITY.md` Whoosh rows and delivery-map unresolved area 1 agree. These indicate evidence/coordinates status, not real-world service absence. |
| v1.0 502 vs status brief's Oct 18 no-response discrepancy is retained but was not explicitly OPEN in the original brief. | SUPPORTED for original report finding | The updated brief now includes `[OPEN CONFLICT C]` at lines 87–93. The two readings remain historical reports; this reviewer did not run DNS. |
| Curl no-response does not prove DNS records or a host do not exist. | SUPPORTED | Brief still says at lines 95–97 that records themselves do not exist/no host to repair, while cited measurement is only curl exit/no HTTP response. That cannot distinguish NXDOMAIN from resolver/connectivity failure. |
| Brief duplicates authoritative PRD scope, acceptance, rollout, and decisions, risking drift. | SUPPORTED | Brief §§3–11 repeat material already in authoritative Whoosh v1.0 sections. |
| Brief broadens Whoosh scope with shared queues/database/Qdrant absent proof they apply. | SUPPORTED | Whoosh PRD limits enabling components to audit-proven needs; brief lists shared components as scope and adds AnyLLM/vector-store ADR without demonstrated project-specific basis. |
| Phase 5 order Core → Elevate → Whoosh → CBD is correct. | SUPPORTED | v3 Phase 5 order matches. |

**Parent correction accuracy/completeness:** The added `[OPEN CONFLICT C]` is an accurate and useful explicit conflict marker, retains both dates/readings, and requests a new DNS check. It does **not** repair the brief's false inference: lines 95–97 still equate non-resolution with absent DNS records/no host, and lines 207–208 still treat that as fact. It also describes “non-resolution implies no reachable origin at all”; that is too categorical without the DNS result. Correction is incomplete, but the marker itself introduces no error.

### Cross-cutting

| Material claim | Verdict | Independent basis / qualification |
|---|---|---|
| Platform isolation, CI/CD, backup/DR and observability remain UNKNOWN; isolated components do not close shared acceptance. | SUPPORTED | Traceability rows cited by report classify these as UNKNOWN/BLOCKED; v3 supplies target requirements, not deployment evidence. One CBD queue, local 8081 listener, system timer, or reported transfer cannot establish a four-domain acceptance matrix. |
| 8081 has a live listener/model endpoint and is documented as a client AnythingLLM dependency; do not stop/rebind it. | SUPPORTED as report evidence, not freshly remeasured here | Report includes command outputs and points to wiring map/board/Oct 17 reply. This review did not re-run host commands; the conclusion is appropriately bounded to that measurement and the documented dependency. |
| Controller-repo workflow inventory does not prove project-specific CI/CD absence or existence. | SUPPORTED | The report explicitly bounds `find`/tracked-file evidence to this checkout and notes external repositories/provider settings were not measured. |
| Backup/DR “operational/live” triage conflicts with missing accepted backup/restore evidence. | SUPPORTED | Cited triage line has no run, manifest, target, checksum, restore or drill; ledger/map say accepted live evidence absent. Keep conflict OPEN; neither proves backup never configured nor proves DR works. |
| Local disk timer/process search cannot establish client monitoring coverage or alert delivery. | SUPPORTED | Report explicitly limits measurements to controller host; v3 monitoring requirements are not live monitoring evidence. |
| Correlated risk: multiple documents echo the same ledger/artifact rather than independent measurement. | SUPPORTED as risk; UNCERTAIN as observed multi-lane repetition | Identical-source citation dependence is visible in the reports and cross-cutting report's own caveats. But no repeated identical false claim across all lanes has been established merely by shared citations. |

## Correlated-failure analysis

There is a concrete shared-source failure risk, but not proof that all lanes succumbed to one correlated falsehood. The lanes repeatedly rely on the same `PRD_TRACEABILITY.md`, delivery map, v3, and overlapping campaign artifacts; copied status statements are not independent corroboration. Common error patterns to guard against:

1. **Evidence laundering by repetition:** human traceability, delivery map, and PRDs may repeat one underlying artifact; multiple citations do not make multiple measurements. CBD's human ledger vs structured YAML conflict is a concrete example of sibling claims inheriting inconsistent representations.
2. **Historical-to-current drift:** dated Sept/Oct findings presented as current, especially Elevate's pre-remediation unauthenticated console/API and Whoosh's reported DNS state.
3. **Absence inference:** missing coordinates, no curl response, or no accepted artifact inflated into “host/service/record does not exist.” Whoosh is the clearest concrete instance; CBD's current service status also remains dated/uncertain.
4. **Requirements-as-implementation:** v3 target architecture and acceptance requirements sometimes cited as if they prove present deployment or project applicability.

These are corroborated as risks and examples, not a claim that every lane independently made every error.

## Baseline verdict

**No. The four domain PRDs are not safe as a verified working implementation baseline.** They remain usable as a requirements and evidence-gap baseline only if users preserve the distinctions between target, historical ledger, measured current result, and unresolved conflict. Strongest single reason: **material current-state claims remain unsupported or contradictory in the PRDs themselves**—notably Elevate's remediated security issue is still described as open/current in multiple body sections, and Whoosh still converts an unverified curl failure into categorical DNS/origin absence. Core and CBD likewise contain known evidence-attribution or unresolved proof gaps. A working requirements baseline is not an as-built baseline.

## Review execution / boundaries

- Confirmed five sibling reports and prior verdict were readable; `ls -l` recorded the report sizes above.
- Read each sibling report and inspected cited PRD correction passages and targeted PRD/source claims. Reviewed the cross-cutting report's cited ledger boundaries as summarized in its evidence; no live service, DNS, or host checks were run.
- Read-only only. Did not edit any PRD or stage files. Existing working-tree changes `M data/prds/elevate-life-sci-prd-v1.0.md`, `M data/prds/whoosh-prd-status-brief.md`, and untracked `core-distro-saas-clean`, `firstmate` were present; no staged files appeared in `git diff --cached --name-only`.
