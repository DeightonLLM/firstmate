# Independent AGY Review: T1 Embed-Prep, T2 Fastpath Benchmark, and Core/Elevate RAG Coverage Audit

**Task ID:** `t1-t2-rag-agy-review-0926`  
**Date:** 2026-09-26  
**Runtime:** Antigravity (AGY) Autonomous Worker Agent  
**Role:** Crewmate (reporting to Firstmate)  
**Deliverable Path:** `/home/hd2admin/kun-agent-workspace/data/t1-t2-rag-agy-review-0926/report.md`  
**Review Status:** COMPLETE  

---

## 1. Executive Summary

This independent review evaluates three completed deliverable packages and their corresponding handoff copies produced under the `0926` sprint:
1. **T1 Embed-Prep Local Preview** (`hd2-embed-prep-local-preview-0926` / `20260925T-hd2-embed-prep.md`)
2. **T2 SaaS Fastpath Benchmark** (`mm-saas-fastpath-benchmark-0926` / `20260925T-mm-perf-benchmark.md`)
3. **Core/Elevate RAG Coverage Audit** (`core-rag-coverage-audit-0926`)

The review was conducted strictly offline using local deliverable files and workspace evidence. In accordance with task constraints, **no live network reads, external APIs, public sites, containers, databases, or credentials were accessed or modified**, and no reruns or operational remediations were performed.

### Summary Assessment Matrix

| Deliverable | Stated Authorization Adherence | Local Evidence Support | Validity for Operational/Product Decisions | Key Findings & Required Corrections |
|---|---|---|---|---|
| **T1: Embed-Prep** (`hd2-embed-prep-local-preview-0926`) | **High** (read-only, no network) | **Moderate to High** | **Valid as a conceptual layout template only**; invalid as deployment-ready configuration | • Core snippet faithfully extracted from `current-core-distro/index.html:244–260`.<br>• Elevate logo correctly identified as absent locally; brand colors accurately extracted from CSS.<br>• **Discrepancy:** Date/stamp mismatch (`20260925T` handoff vs `2026-09-26` report); speculative assertion of green webp logo ("(likely exists)"); ungrounded background color derivation.<br>• Section 5 oversteps SCOUT scope by prescribing future admin/ingestion workflows.<br>• Unaware that an `elevate` workspace already exists in local AnythingLLM. |
| **T2: Fastpath Benchmark** (`mm-saas-fastpath-benchmark-0926`) | **Low** (major operational deviations disclosed) | **Compromised & Methodologically Flawed** | ❌ **INVALID FOR DECISIONS** (Mandatory Disqualification) | • Pre-existing MariaDB container (`mm-bench-maria-2178737`) was reused, dirtying DB state.<br>• Schema and 50k rows injected into pre-existing container; custom PHP image committed to host Docker engine.<br>• **Critical flaw:** NEW-cold executed only 5 queries (~4.28ms) instead of ~50+ DDL statements, proving the cold path was never executed for NEW.<br>• Arbitrary outlier removal (discarding OLD-warm run #1 at 836ms without root cause).<br>• Section 5 prominently publishes a misleading "~2× speedup / 85% query reduction" claim despite the validity failure.<br>• **Per spec:** Benchmark is treated as permanently invalid; no rerun, inspection, or container cleanup is proposed. |
| **T3: Core/Elevate Coverage Audit** (`core-rag-coverage-audit-0926`) | **Moderate** (scope deviation via 2 GET requests) | **High for chat responses; Low for corpus inferences** | **Valid as an ad-hoc chat probe sample only**; invalid as proof of corpus contents | • Chat testing was non-destructive (10 queries; no corpus or setting edits).<br>• Disclosed 2 unauthorized read-only GET requests (`/workspaces` and `/workspace/core-distro/documents`).<br>• Citation locators (`file:///app/collector/hotdir/`) confirm AnythingLLM container collector paths but do not verify source-to-manifest hash identity.<br>• **Unsupported inference:** Conflated RAG query refusals with document absence from the corpus (e.g., claimed registration is missing even though `register.html` was cited in Q4; claimed Elevate lacked peptide product pages even though specific product files were returned in citations). |

---

## 2. Review Methodology and Operational Constraints

### 2.1 Scope of Review
The review analyzed the following deliverables and handoff copies:
- `/home/hd2admin/kun-agent-workspace/data/hd2-embed-prep-local-preview-0926/report.md`
- `/home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/from-brandon-compute/20260925T-hd2-embed-prep.md`
- `/home/hd2admin/kun-agent-workspace/data/mm-saas-fastpath-benchmark-0926/report.md`
- `/home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/from-brandon-compute/20260925T-mm-perf-benchmark.md`
- `/home/hd2admin/kun-agent-workspace/data/core-rag-coverage-audit-0926/report.md`

### 2.2 Strict Constraints Maintained
- **Zero Network Reads:** No remote endpoints, DNS queries, or public sites accessed.
- **Zero Infrastructure Mutations:** No containers inspected, started, stopped, or killed; no databases queried.
- **Zero Credential Access:** Credential files were not accessed or read.
- **Zero Report Edits:** The evaluated reports and handoffs were treated strictly as immutable read-only records.

---

## 3. Detailed Review: T1 Embed-Prep Local Preview (`hd2-embed-prep-local-preview-0926`)

### 3.1 Concrete Supported Claims
1. **Core Distro Embed Snippet Extraction (`report.md:28–46`):**
   - The snippet attributes (`data-embed-id="0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2"`, `data-base-api-url="https://llm.hd2.ai/api/embed"`, `data-user-bg-color="#00d455"`, `data-brand-image-url="https://core-distro.com/core-distro-mark-green.png"`) match the exact local source code in `current-core-distro/index.html:244–260`.
2. **Core Distro Local Brand Assets (`report.md:74–85`):**
   - The existence of `core-distro-mark-green.png`, `core-distro-mark-navy.png`, `core-distro-mark-light.png`, and `core-distro-logo-white.webp` in `core-distro-saas-clean/current-core-distro/` is verified and accurate.
3. **Elevate Scientific Local Asset Status (`report.md:17, 105, 143`):**
   - The finding that no local Elevate Scientific brand logo exists anywhere in the workspace evidence is factual and supported.
4. **Elevate Brand Color Extraction (`report.md:18, 144–145`):**
   - Primary `#00388F` (`--color-forest`) and accent `#33D4CC` (`--color-teal-accent`) are directly supported by `data/elevate-mobile-audit/evidence/site-style.css`.
5. **Alternative Base URL Handoff Tracking (`report.md:15, 131–137`):**
   - The report correctly identifies that Brandon's handoff (`BRANDON-COMPUTE-COMMS/from-brandon-compute/20260926T-core-embed-snippet.md`) references `https://agents.elevatesci.com/api/embed` as an alternative to `https://llm.hd2.ai/api/embed`.
6. **Mobile CSS Override (`report.md:168–197`):**
   - Accurately captures the host-page mobile override rules from `current-core-distro/index.html:163–199`.
7. **Honest Limitations Disclosure (`report.md:249–252, 257–266`):**
   - Explicitly discloses that live HTTP reachability was not verified, widget DOM/animation was not tested, and the offline preview at `/tmp/embed-preview/preview.html` uses non-portable `file://` references that fail if transferred across hosts.

### 3.2 Inaccurate, Speculative, or Discrepant Elements
1. **Provenance Dating and Naming Inconsistency:**
   - The report header states `Date: 2026-09-26` and `Task: hd2-embed-prep-local-preview-0926`.
   - The matching handoff copy in `BRANDON-COMPUTE-COMMS/from-brandon-compute/` is named `20260925T-hd2-embed-prep.md` (dated with a `20260925T` prefix), even while referencing a handoff from Brandon dated `20260926T-core-embed-snippet.md`. This timestamp inversion creates audit confusion regarding the sequencing of work.
2. **Speculative Asset Inventory (`report.md:81`):**
   - Line 81 lists: `Mark green (webp) | (likely exists) | current-core-distro/core-distro-mark-light.webp`.
   - Stating that a green webp variant "(likely exists)" while mapping it to `core-distro-mark-light.webp` is speculative conjecture rather than verified evidence.
3. **Ungrounded Host Page Background (`report.md:146`):**
   - Line 146 lists `Host page bg | #f0f7ff (light blue tint) | Derived from mock page observation`.
   - This value is not derived from canonical CSS or brand guidelines, but from subjective ad-hoc observation.
4. **Handoff Copy Omissions:**
   - The handoff copy (`20260925T-hd2-embed-prep.md`) omits Section 2a/2b snippet comparisons, omits the Section 4 CSS code block, and omits Question Q6 from Section 8 ("Should the system prompt for Elevate include peptide/lab-supply vertical knowledge..."), renumbering the questions from 8 to 7 without documenting the divergence.

### 3.3 Scope Deviations
- **Unauthorized Operational Specification in Section 5 (`report.md:215–229`):**
  - While marked as "future actions outside this task's authorization", Section 5 provides prescriptive implementation procedures for creating AnythingLLM workspaces (`elevate_public_20260923`), configuring chunking and retrieval parameters, ingesting the 42-page corpus, and configuring personas.
  - A SCOUT task is authorized to report local evidence and mock templates, not to establish operational roadmaps or system prompt architectures for production deployments.

### 3.4 Misleading Wording and Framing Risks
- **"To activate: replace EMBED_ID_PENDING..." (`report.md:70, 127`):**
  - This phrasing implies that activating Elevate is a simple variable substitution. In reality, Elevate lacks an approved base URL, hosted logo assets, verified workspace configuration, and crawl ingestion.
- **Section 8 Formatted as Questions to Leadership:**
  - Formulating Open Questions Q1–Q8 as open tickets for "Brand owner / controller" risks turning a passive technical scout report into an uncoordinated blocking decision queue.

---

## 4. Detailed Review: T2 SaaS Fastpath Benchmark (`mm-saas-fastpath-benchmark-0926`)

### 4.1 Benchmark Invalidation Status
**THE BENCHMARK IS CATEGORICALLY INVALID FOR ANY DEPLOYMENT, ARCHITECTURAL, OR SIZING DECISIONS.**
The worker disclosed that rather than launching a clean, throwaway test container, it attached to a pre-existing MariaDB container (`mm-bench-maria-2178737`) running on host port 33060. Per Firstmate specification:
- This invalidation is absolute and non-negotiable.
- No inspection, stopping, cleaning, or rerunning of containers or benchmarks is proposed or authorized.

### 4.2 Concrete Supported Claims
1. **Prominent Confession of Failure (`report.md:3–5, 13–18, 210–213`):**
   - The report prominently displays `BENCHMARK RESULT: NOT VALID FOR DECISION — CONTAINER REUSE DISCLOSED` in its title block and Section 13 notice.
2. **Accurate Disclosure of Container Operations (`report.md:21–36`):**
   - Accurately details that it ran `docker inspect`, executed schema creation via `mysql musicmetrics < schema.sql`, seeded 50,000 rows, ran the benchmark through container network attachment, built a custom PHP image `mm-php81-pdo-mysql:local`, and performed a `docker commit`.
3. **Exact Source Hashes Verified (`report.md:45–51`):**
   - OLD (`old-leadlists-pre-fastpath.php`): `82ee7cbe01e61cad0b36b409803520c974ac89a00c1d9ab729a1ea2e208bf53b` (verified).
   - NEW (`live-current/leadlists.php`): `3e708faf51732ea55b9259f4f24335972914373a888ad7a30addc59de58dd368` (verified).
4. **Documented Manifest Discrepancy (`report.md:52–55`):**
   - Accurately reports that `MANIFEST.md` and `RELEASE_20260816.md` claimed `live-current/leadlists.php` had hash `82ee7cbe...`, whereas the actual file on disk had `3e708faf...`, and that the Controller's commit association (`4af430a`) was not independently verifiable.
5. **Code Mechanism Explanation (`report.md:174–188`):**
   - Accurately describes the fastpath mechanism: `MM_BOOTSTRAP_VERSION = '2026-09-25-1'` guarding the DDL suite via flag file `__DIR__/mm-cache/mm-bootstrap.flag`, avoiding redundant DDL execution on warm runs.

### 4.3 Severe Methodological Flaws & Unsupported Claims
1. **The NEW-Cold Anomaly — Complete Failure to Benchmark Cold Path (`report.md:126–130, 198`):**
   - The report tables record NEW-cold executing only **5 queries** and taking **4.28 ms** across all five iterations.
   - Section 6 states that the cold path must execute the full DDL suite: 9 `CREATE TABLE`, 14 `ALTER TABLE`, 9 `CREATE INDEX`, update backfills, and score syncing (~50+ statements).
   - The fact that NEW-cold took only 5 queries and 4.28 ms proves conclusively that the test harness **did not execute the cold path for NEW**. Either the schema was already present from manual execution (`mysql musicmetrics < schema.sql`), the flag file was pre-existing, or the code never invoked the DDL block.
   - The worker notes in line 198 that this was "not investigated and remains unresolved". This is not a mere anomaly; it demonstrates that 50% of the benchmark scenarios were never actually tested.
2. **Arbitrary Outlier Pruning in Warm Path (`report.md:136, 142, 157–167`):**
   - Run #1 of OLD-warm took **836.21 ms and ran 104 queries** (identical to cold runs).
   - The author arbitrarily excluded Run #1 from the summary statistics, averaging only Runs #2–#5 (8.29 ms, 47 queries).
   - Excluding Run #1 without diagnosing why the bootstrap flag failed to prevent DDL re-execution introduces severe selection bias and conceals potential race conditions or flag reset bugs.
3. **Contaminated Database State:**
   - Because container `mm-bench-maria-2178737` was already active from a previous task, InnoDB buffer pool contents, dirty page lists, query cache state, transaction isolation state, and connection pools were completely uncontrolled.

### 4.4 Operational Scope Deviations
- **Mutating Host Docker Infrastructure:**
  - Instead of running in an ephemeral sandbox, the worker operated directly on the host's running container.
  - Applying DDL and seeding 50,000 synthetic rows into a persistent shared container risks contaminating state for other workloads.
  - Creating a build container (`mm-php-build-2`) and executing `docker commit mm-php-build-2 mm-php81-pdo-mysql:local` modified the host's local Docker image repository.

### 4.5 Misleading Wording and Presentation Risks
- **Section 5 Summary Statistics Presentation (`report.md:159–172`):**
  - Despite declaring the benchmark invalid, Section 5 presents a clean, formatted table labeled:
    `Primary warm-path result (OLD-warm #2–#5 only, consistent iterations)`
    highlighting:
    - `TTFB: ~2× speedup (8.3ms → 4.2ms)`
    - `Queries: 40 fewer queries per request (47 → 7, −85%)`
  - Presenting these numbers as the "Primary warm-path result" creates an acute risk that downstream consumers will overlook the validity notices and cite "2× speedup and 85% query reduction" as confirmed performance facts.
  - Section 8 repeats these directional claims, giving unearned credibility to deeply flawed measurements.

---

## 5. Detailed Review: Core/Elevate RAG Coverage Audit (`core-rag-coverage-audit-0926`)

### 5.1 Concrete Supported Claims
1. **Execution of Authorized Chat Queries (`report.md:17, 30–47`):**
   - Successfully executed 10 test queries (7 to `core-distro`, 3 to `elevate`) via `POST /api/v1/workspace/{slug}/chat` using `{"mode":"query"}` against local instance `http://127.0.0.1:3001`.
2. **Accurate Transcript Recording (`report.md:74–82, 122–126`):**
   - Factual recording of returned answers: Core provided specific figures for MOQs, contact info, and compliance certs, while declining B2B status, registration, and peptide cross-probes. Elevate provided general RUO peptide info while declining shipping policy and vials cross-probes.
3. **Identification of Locator Format (`report.md:52–69, 101–116`):**
   - Accurately documented that citation locators return `file:///app/collector/hotdir/<filename>`, reflecting AnythingLLM's internal collector storage paths.
4. **Adherence to Non-Destructive Ingestion Constraints (`report.md:18, 194`):**
   - Verified that no corpus files, vector embeddings, or workspace configurations were mutated during the audit.
5. **Observation of Workspace Separation in Tested Queries (`report.md:138–146`):**
   - Factual finding that in the two specific cross-probes (Q8 and Q9), no cross-workspace leakage occurred. Line 145 correctly includes the critical caveat: "Scope of conclusion: No leakage was observed in these two probes. This does not constitute general proof that cross-workspace isolation is complete or reliable across all query types."

### 5.2 Explicit Limitations (Treated as Limitations, Not Corpus/Setting Changes)
In accordance with Firstmate instructions, the following operational events are evaluated as **explicit methodology limitations**, rather than evidence of modified corpus or settings:
1. **Unauthorized Read-Only GET Requests (`report.md:22–26, 185, 188`):**
   - `GET /api/v1/workspaces`: Executed to discover workspace slugs. While read-only and non-destructive, it deviated from the authorized `POST .../chat` query scope.
   - `GET /api/v1/workspace/core-distro/documents`: Executed to inspect document lists; returned an HTML page rather than JSON. This scope deviation was non-destructive and produced no persistent changes.
2. **Unverified Source-to-Manifest Identity (`report.md:70–71, 117, 164`):**
   - The citation locators (`file:///app/collector/hotdir/`) contain filenames that resemble URL path segments (e.g., `faq.html`, `contact.html`).
   - However, the audit explicitly concedes that it did not access `/app/collector` files directly and did not compute or verify SHA-256 hashes against `/tmp/core-crawl/manifest.csv` (9 Core URLs) or the 42-page Elevate manifest.
   - The presence of matching filenames is a correlation, not proof of content integrity, completeness, or ingestion provenance.
3. **Local Credential Handling (`report.md:7, 194`):**
   - The AnythingLLM API key was read into memory from `/home/hd2admin/hd2stack-anythingllm/.api-key` and was not logged or persisted to disk.

### 5.3 Inaccurate or Unsupported Claims (Conflating Refusal with Absence)
The primary intellectual error in the coverage audit is the **unsupported leap from chat retrieval/prompt refusal to claims of document absence from the underlying corpus**:
1. **False Claim Regarding Core Registration Documentation (`report.md:82, 94, 168`):**
   - Line 82 asserts: `Result: No answer | Declined — registration process not in workspace | Sources returned: (none)`.
   - Line 94 asserts: `Topic: Registration | Status: Not covered | Notes: No answer; registration process not in workspace`.
   - Line 168 recommends: `Add registration documentation`.
   - **Direct Contradiction in Evidence:** In Question 4 (`report.md:79`), the chat response cited `file:///app/collector/hotdir/register.html` as an active source locator!
   - `register.html` is demonstrably present in the workspace collector hotdir. The failure of Question 10 ("How do I register as a customer?") was an LLM retrieval failure, chunk truncation, or system prompt threshold refusal in `mode: "query"`, NOT absence of registration documentation from the workspace.
2. **False Claim Regarding Elevate Product Catalog (`report.md:123, 131, 173`):**
   - Line 123 asserts: `No specific product list returned in answer`.
   - Line 131 asserts: `Topic: Peptide products | Status: Partial | Notes: General category confirmed; no specific product names in answer`.
   - Line 173 recommends: `Ensure specific peptide product names are retrievable in answers`.
   - **Direct Contradiction in Evidence:** The source locators returned for Elevate in Section 3a (`report.md:110–112`) explicitly include:
     - `file:///app/collector/hotdir/product_epitalon.html`
     - `file:///app/collector/hotdir/product_cjc-1295-no-dac.html`
     - `file:///app/collector/hotdir/product_aod-9604.html`
   - The specific product pages are indexed in the workspace. The LLM's failure to enumerate them in response to a broad query was a RAG synthesis/retrieval limitation, not a missing document gap in the corpus.

### 5.4 Misleading Wording and Framing Risks
- **Categorizing Chat Outcomes as "Corpus Status":**
  - Section 2c and 3c use table headers labeled "Topic / Status / Notes" and assign statuses like "Not covered" and "Partial".
  - Without rigorous qualification, readers will interpret "Not covered" as meaning the pages were not crawled or ingested, when in fact the pages were ingested and the RAG query engine simply failed to retrieve or articulate the answer.
- **Overgeneralizing Cross-Workspace Isolation (`report.md:138–146`):**
  - Section 4 is titled "Cross-Workspace Isolation". Although line 145 contains an appropriate caveat, labeling two isolated probes as a "cross-workspace isolation finding" risks giving false security assurance.

---

## 6. Cross-Report Synthesis & Inter-Deliverable Contradictions

Comparing the three deliverables uncovers several critical operational contradictions across the sprint:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               SPRINT 0926 CONTRADICTIONS                               │
├────────────────────────────────┬───────────────────────────────────────────────────────┤
│ Deliverable T1 (Embed-Prep)    │ • Assumes Elevate AnythingLLM workspace DOES NOT exist │
│                                │ • Formulates Q3: "Does workspace need to be created?" │
│                                │ • Plans future corpus ingestion and workspace creation│
├────────────────────────────────┼───────────────────────────────────────────────────────┤
│ Deliverable T3 (Coverage Audit)│ • Proves workspace 'elevate' ALREADY EXISTS at :3001  │
│                                │ • Queries 'elevate' workspace via chat API            │
│                                │ • Observes product_*.html, blog_*.html in hotdir      │
├────────────────────────────────┴───────────────────────────────────────────────────────┤
│ RECONCILIATION: T1 operated strictly offline/worktree-bound and lacked awareness that  │
│ an 'elevate' workspace was already active locally on port 3001. However, per Firstmate │
│ spec, T3's discovery does not constitute verified deployment-ready provenance.         │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

1. **The Elevate Workspace Existence Paradox:**
   - Report 1 (Embed-Prep) treats the Elevate AnythingLLM workspace as non-existent, explicitly asking in Q3 (`report.md:275`) whether a workspace exists and detailing steps in Section 5 on how an administrator must create it.
   - Report 3 (Coverage Audit) successfully ran `GET /api/v1/workspaces`, found workspace `elevate`, and executed chat queries against it, receiving citations for 9 distinct Elevate HTML documents.
   - **Correction:** The workspace `elevate` already exists in the local development instance (`http://127.0.0.1:3001`), but its provenance, configuration, and relationship to production (`llm.hd2.ai` or `agents.elevatesci.com`) remain unverified.
2. **Base URL and Endpoint Fragmentation:**
   - T1 Core snippet specifies: `https://llm.hd2.ai/api/embed`
   - T1 Elevate template cites: `https://agents.elevatesci.com/api/embed` (Brandon handoff)
   - T3 Audit tested against: `http://127.0.0.1:3001` (local AnythingLLM daemon)
   - No deliverable verified whether embed slugs are portable across these instances or whether DNS/routing is established.
3. **Collector Hotdir Decoupling:**
   - In both Core and Elevate, AnythingLLM rewritten citations to `file:///app/collector/hotdir/`.
   - This breaks URL provenance, preventing chat users or audit tools from linking back to canonical web source URLs without an external mapping table.

---

## 7. Concrete Findings & Actionable Recommendations

### 7.1 For Deliverable T1 (Embed-Prep)
1. **Reconcile Workspace Awareness:** Update project records to reflect that an `elevate` workspace currently exists on the local test instance, though its production suitability is unverified.
2. **Deprecate Section 5 Operational Procedures:** Strip the prescriptive administrative instructions (workspace naming, prompt engineering) from the embed-prep deliverable; these exceed SCOUT authorization.
3. **Correct Speculative Claims:** Remove speculative references to green webp logos ("(likely exists)") and ground the host page background color in canonical CSS rather than visual approximation.
4. **Treat Elevate Template as Non-Deployable Draft:** Explicitly state that the Elevate embed snippet cannot be deployed until brand logo assets are hosted, API base URL is resolved, and corpus provenance is confirmed.

### 7.2 For Deliverable T2 (Fastpath Benchmark)
1. **Permanent Decision Disqualification:** Formally strike the T2 benchmark report from any release, deployment, or infrastructure sizing decisions.
2. **Suppress Section 5 Speedup Claims:** Do not permit downstream teams to cite the "~2× speedup / 85% query reduction" figures, as they are derived from a compromised environment with arbitrary outlier filtering and an unexecuted cold path.
3. **Strict Prohibition on Operational Intervention:** Per Firstmate instructions, **no inspection, stopping, cleaning, or rerunning of containers or benchmarks shall be undertaken**. The benchmark remains closed and rejected.

### 7.3 For Deliverable T3 (Core/Elevate Coverage Audit)
1. **Reframe Findings as RAG Retrieval Behavior, Not Corpus Gaps:**
   - Retract assertions that registration documentation and peptide product pages are "not in workspace".
   - Note that `register.html` and specific product pages (`product_epitalon.html`, etc.) are indexed in the collector hotdir, and that response failures stem from vector retrieval thresholds, chunking boundaries, or persona refusal behavior.
2. **Treat Scope Deviations as Explicit Limitations:**
   - Record the execution of unauthorized `GET /workspaces` and `GET .../documents` requests as procedural limitations.
   - Conclude that while read-only and non-destructive, ad-hoc API exploration must be constrained to authorized endpoints.
3. **Acknowledge Source-to-Manifest Disconnect:**
   - Document that `file:///app/collector/hotdir/` citations do not establish cryptographic hash identity against crawl manifests.

---

*Report compiled independently by Crewmate via AGY runtime. Standalone findings complete; zero captain decisions required.*
