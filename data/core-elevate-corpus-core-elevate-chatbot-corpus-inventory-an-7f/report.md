# Core/Elevate Chatbot-Corpus Inventory

**Task:** core-elevate-corpus-core-elevate-chatbot-corpus-inventory-an-7f
**Date:** 2026-09-25
**Mode:** Read-only scout. No live AnythingLLM inspection, no credential access, no builds, no deploys.
**Baseline:** Prior benchmark report and handoff artifact (`local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1`) used as intake baseline; this inventory adds warehouse/source-map evidence and distinguishes new findings from already-documented unknowns.

---

## 1. Scope and Method

**Task:** Identify evidence-backed corpus sources for both tenants, assess whether the approved `public-elevatesci.com`-only decision is reflected in available records, and list blockers to creating separate workspaces. Do not modify or operate AnythingLLM.

**Evidence base:** Local warehouse documents (`docs/warehouse/anythingllm/`, `agent-work/firstmate/docs/system-context/SERVICE_CATALOG.md`, `PRD_TRACEABILITY.md`), the `elevate-public-rag-corpus-0923` and `elevate-rag-corpus-package-0923` corpus packages, the prior benchmark handoff artifact, and the controller chatbot-RAG decision file. No live AnythingLLM inspection was performed.

**What this inventory does not repeat:** The completed benchmark (verdict: inconclusive) and its raw latency/throughput observations are not re-examined.

---

## 2. Core Tenant — Corpus Inventory

### 2a. Known / Evidence-Backed

| Item | Value | Evidence |
|------|-------|----------|
| Embed ID (live) | `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2` | `current-core-distro/index.html:249` |
| API base (live) | `https://llm.hd2.ai/api/embed` | `current-core-distro/index.html:250` |
| Assistant name | `Core Distro Assistant` | `index.html:251` |
| Brand logo | `https://core-distro.com/core-distro-mark-green.png` | `index.html:252–253` |
| User accent | `#00d455` | `index.html:255` |
| Sponsor | `Powered by HD2.ai` / `https://hd2.ai` | `index.html:256–257` |
| Embed script | `https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js` (HTTP 200 confirmed) | Live HTTP check, prior benchmark |
| Instance host | Contabo `vmi3238503` / `llm.hd2.ai` | `SERVICE_CATALOG.md`; last verified 2026-09-15 |
| Widget mobile CSS | Full override block confirmed in `index.html:163–213` | `core-chatbot-reference-handoff-0924/report.md` |

### 2b. Unknown / Not in Available Evidence

| Item | Status | Evidence Gap |
|------|--------|-------------|
| AnythingLLM workspace name | **UNKNOWN** | No workspace config file found locally; `llm.hd2.ai` admin API requires credentials and returns HTML from public network |
| Workspace slug / opaque ID | **UNKNOWN** | Same as above |
| Document manifest (which pages/files are ingested) | **UNKNOWN** | No workspace export or config found locally |
| Document SHA-256 hashes | **NONE** | No manifest hashes available |
| Embedding model | **UNKNOWN** | Service owner has not provided this |
| Chunk size | **UNKNOWN** | Service owner has not provided this |
| Chunk overlap | **UNKNOWN** | Service owner has not provided this |
| Retrieval method (top-k, threshold, rerank) | **UNKNOWN** | Service owner has not provided this |
| System prompt / persona | **UNKNOWN** | No workspace config found |
| LLM model / provider for chat | **UNKNOWN** | Service owner has not provided this; Hetzner LFM2.5 on port 8081 is separate from AnythingLLM runtime |
| Production landing page source | **NOT IN REPO** | `core-distro-saas-clean` is a working copy; canonical production deploy path is unresolved |

**Summary:** Core's live AnythingLLM workspace has never been inspected via credentials. The embed is working in production (confirmed by prior live check), but the full document list, chunk/embedding settings, and system prompt are not in any local evidence.

### 2c. Source Files Inspected Locally

| File | What it contains | Relevance |
|------|-----------------|----------|
| `agent-work/core-distro-saas-clean/current-core-distro/index.html` | Live embed snippet | Evidence-backed: embed attributes confirmed |
| `agent-work/core-distro-saas-clean/staged-export-test/llms.txt` | Public product description | Local file present; ingestion state into AnythingLLM workspace UNKNOWN |
| `agent-work/core-distro-saas-clean/staged-export-test/` PHP files | SaaS app public pages | Local source exists; ingestion state UNKNOWN |
| Warehouse `anythingllm/README.md` | Boundary statement, source pointers | Evidence: confirms separate workspace requirement for Elevate |

---

## 3. Elevate Tenant — Corpus Inventory

### 3a. Known / Evidence-Backed

| Item | Value | Evidence |
|------|-------|----------|
| Approved corpus scope | Public `elevatesci.com` pages only | Controller decision file (see §4); `warehouse/anythingllm/README.md:14`; `RAG-METADATA-CONTRACT.md:18` |
| Crawl date | 2026-09-23 | `manifest.json` package_date |
| Total pages | **42** | All returned HTTP 200; 42/42 successful |
| All SHA-256 hashes | **Available** | Full hash inventory in `manifest.json` |
| Page inventory | Complete sitemap-sourced list | `elevate-public-rag-corpus-0923/report.md` Table 2b |

**42-page corpus breakdown:**

| Category | Pages | Notes |
|----------|------:|-------|
| Product | 20 | 20 peptide product pages; ~580–768 words each |
| Blog | 5 | 3 long-form (~800–1010 words: GMP manufacturing, custom synthesis, future of peptide research) + 2 listing pages |
| Marketing | 7 | About, Quality, Research, Lab Supplies, Contact, Quote, Wholesale |
| Legal | 6 | Privacy, Terms, Disclaimer, Refund Policy, Cookie Policy, Accessibility |
| Product-listing | 1 | `/shop` catalog page |
| Support | 2 | FAQ, Shipping |
| Homepage | 1 | Brand overview |
| **Total** | **42** | ~20,587 normalized words |

**Excluded material (not in corpus):**

| Source | Reason excluded |
|--------|----------------|
| `agent-work/.lavish/client-sales-journeys.html` | Internal sales material; not public; excluded by the approved scope decision |
| GHL workflow modules M01–M04 | Internal sales material; not in scope |
| `agents.elevatesci.com` | Static dashboard; not in sitemap; not a public corpus source |
| Authenticated / form-submitted content | Not in sitemap; not accessible |
| Any other internal document | Not public |

### 3b. Unknown / Not in Available Evidence

| Item | Status | Evidence Gap |
|------|--------|-------------|
| Elevate AnythingLLM workspace name | **NOT FOUND** | No workspace has been created or documented in available evidence |
| Elevate workspace embed ID | **NOT FOUND** | No workspace exists yet to assign an ID |
| Embedding model (to use for Elevate) | **UNKNOWN** | Must match Core once Core settings are confirmed by service owner |
| Chunk size / overlap (to use for Elevate) | **UNKNOWN** | Must match Core; blocked on Core settings |
| Retrieval settings (to use for Elevate) | **UNKNOWN** | Must match Core; blocked on Core settings |
| System prompt / Elevate persona | **NOT DEFINED** | Answer guidance exists (`corpus/answer-guidance.md`); workspace prompt not set |
| LLM model / provider for Elevate chat | **UNKNOWN** | Blocked on Core runtime confirmation |
| Any proof of workspace isolation | **NOT AVAILABLE** | Requires live AnythingLLM inspection with credentials |

### 3c. Corpus Package Readiness

The `elevate-rag-corpus-package-0923` contains:
- Full 42-page static corpus at `corpus/` (normalized text, organized by category)
- `answer-guidance.md`: vertical-aware answer rubric (Research, Lab Supplies, Quality, Wholesale, Quote/Contact, Product Catalog) + RUO safety constraints
- `core-alignment-note.md`: explicit note that Core settings are unknown; do not claim parity without service owner confirmation
- `golden-set.json` / `elevate-rag-eval-0924/report.md`: 9-case pre-deployment evaluation rubric (grounded-answer, abstain, safe-redirect; RUO boundary is a hard failure)

**Corpus is ingestion-ready** once: (a) a separate Elevate workspace is created, (b) Core's embedding/chunk settings are obtained from the service owner, and (c) Elevate's system prompt/answer rubric is configured from `answer-guidance.md`.

---

## 4. Approved `elevatesci.com`-Only Policy — Record Reflection

**The decision:** On 2026-09-23, the approved decision set public `elevatesci.com` pages only as the initial Elevate RAG corpus, and instructed that sites use RAG similar to Core's. Internal sales-journey material and GHL modules are excluded.

**Source of record:**

| Document | What it records | Path |
|----------|----------------|------|
| Controller chatbot-RAG decision (external record) | The 2026-09-23 decision record approves public elevatesci.com pages only. | `overnight-20260924/repo/BRANDON-COMPUTE-COMMS/from-brandon-compute/20260923T1840Z-controller-chatbot-rag-decision.md` |
| Warehouse README | "Elevate requires a separate workspace/index seeded only from approved public elevatesci.com pages; Core documents/index must not be copied" | `docs/warehouse/anythingllm/README.md:14` |
| RAG metadata contract | "approved public elevatesci.com URL inventory, crawl date, and content hashes; … proof that Core documents/index were not copied" | `docs/warehouse/anythingllm/RAG-METADATA-CONTRACT.md:18, 21` |
| Handoff artifact (corrected) | "Elevate's approved corpus is public elevatesci.com pages only. The internal sales-journey material described below is excluded." | `anythingllm-rag-handoff-artifact.md` (2026-09-23 correction) |
| Answer guidance | All 42 pages crawled from public `elevatesci.com` sitemap; internal material explicitly absent | `elevate-rag-corpus-package-0923/corpus/answer-guidance.md` |

**Assessment:** The `public-elevatesci.com`-only decision is reflected in multiple independent local records:
1. The original 2026-09-23 decision record (authoritative)
2. The warehouse boundary statement (permanent record)
3. The RAG metadata contract (enforceable metadata requirement)
4. The corrected handoff artifact (supersedes the draft that included internal material)
5. The answer guidance (`corpus/answer-guidance.md`) — built from only the 42 public pages, with internal material structurally absent

The decision is well-documented and has propagated into the warehouse, the corpus package, and the evaluation rubric. No local record contradicts it.

**External statements (not locally corroborated):** The live AnythingLLM service on `llm.hd2.ai` has not been inspected with credentials, so this inventory cannot independently verify whether the currently active Core workspace contains only approved material or whether any Elevate workspace exists at all.

---

## 5. Blockers to Creating Separate Workspaces

### 5a. Core Workspace — Blocker Summary

**Blocker C1: Core workspace name and settings unknown.**
The Core AnythingLLM workspace has never been inspected with credentials. The following are genuinely unknown and block any attempt to replicate settings for a new Elevate workspace:

- Workspace name / slug / opaque ID
- Document manifest and SHA-256 hashes (what is currently indexed)
- Embedding model, chunk size, chunk overlap
- Retrieval method, top-k, rerank settings
- System prompt / answer persona
- LLM provider and model for chat generation

**Required safe input:** AnythingLLM admin or service owner provides: (1) workspace name, (2) document list with content hashes, (3) screenshot or export of embedding/chunk/retrieval settings, (4) system prompt text (secrets/redacted allowed but structure needed).

**Blocker C2: Live service unreachable for admin inspection.**
`llm.hd2.ai` admin/API endpoints return HTML ( AnythingLLM landing page) from the public network; no workspace data is exposed without credentials. Live inspection requires access that is not available to this read-only inventory.

**Required safe input:** Credentials or a read-only admin export for `hd2-anythingllm` that does not require sharing secrets.

### 5b. Elevate Workspace — Blocker Summary

**Blocker E1: No Elevate AnythingLLM workspace exists in available evidence.**
No workspace creation, no embed ID assignment, and no corpus ingestion has been documented for Elevate. The `elevate-public-rag-corpus-0923` corpus package exists locally and is ready, but no destination workspace exists to receive it.

**Required safe input:** AnythingLLM admin creates a new `elevate_<dataset>_<version>` workspace and provides the new embed ID and (if different) API base URL.

**Blocker E2: Elevate branding assets not provided.**
The embed snippet template in the handoff artifact requires per-tenant values that have not been supplied:

| Asset | Core value (reference) | Elevate value |
|-------|----------------------|----------------|
| Assistant name | `Core Distro Assistant` | **NOT PROVIDED** |
| Brand logo URL | `core-distro.com/core-distro-mark-green.png` | **NOT PROVIDED** |
| Assistant icon URL | `core-distro.com/core-distro-mark-green.png` | **NOT PROVIDED** |
| Accent color | `#00d455` | **NOT PROVIDED** |

**Required safe input:** Elevate branding owner provides the four values above.

**Blocker E3: Elevate system prompt not defined.**
The `answer-guidance.md` in the corpus package is an answer-rubric document, not an AnythingLLM system prompt. A workspace prompt that encodes the RUO boundary, vertical framing, safe-redirect behavior, and contact routing must be created and configured. This is a content/configuration decision, not a code blocker.

**Required safe input:** Product/copy owner reviews `answer-guidance.md` and approves the Elevate workspace prompt content, or provides revised copy.

### 5c. Cross-Tenant Isolation — Blocker Summary

**Blocker I1: No proof of workspace isolation exists in available evidence.**
The warehouse RAG metadata contract explicitly requires "explicit proof that Core documents/index were not copied" before an Elevate workspace can be considered isolated. No such proof is available locally. This is not a code or credential issue — it is an operational verification requirement that can only be satisfied by live inspection once a workspace exists.

**Required safe input:** AnythingLLM admin confirms (a) that a separate workspace has been created for Elevate, (b) that its document set matches the 42-page corpus and nothing else, and (c) that retrieval returns only Elevate documents.

---

## 6. New Evidence vs. Already-Documented Unknowns

This inventory confirms and extends the prior benchmark baseline as follows:

| Item | Status in prior report | Status in this inventory |
|------|------------------------|--------------------------|
| Core workspace name | UNKNOWN | **UNKNOWN — unchanged** |
| Core document manifest | UNKNOWN | **UNKNOWN — unchanged** |
| Core embedding/chunk settings | UNKNOWN | **UNKNOWN — unchanged** |
| Core LLM model for chat | UNKNOWN | **UNKNOWN — unchanged** |
| Core production source path | NOT IN REPO | **NOT IN REPO — unchanged** |
| Elevate workspace existence | NOT FOUND | **NOT FOUND — unchanged** |
| Elevate embed ID | UNKNOWN | **UNKNOWN — unchanged** |
| Elevate corpus | NOT INGESTED | **READY: 42-page static corpus with full hashes** (new) |
| `public-elevatesci.com`-only policy | Not explicitly in prior report | **REFLECTED IN 5 LOCAL RECORDS** (documented) |
| Elevate answer rubric | Not present | **READY: answer-guidance.md + golden-set eval rubric** (new) |
| Elevate branding assets | Not provided | **NOT PROVIDED — unchanged** |
| Cross-tenant isolation proof | Not available | **BLOCKED — requires live inspection** (unchanged) |

**What is new vs. prior baseline:**
- The `elevate-rag-corpus-package-0923` (42 pages, full SHA-256 hashes, answer guidance, core-alignment note) was built after the prior report and constitutes the ingestion-ready corpus.
- The `elevate-rag-eval-0924` (9-case evaluation rubric) was built alongside it.
- The `public-elevatesci.com`-only policy has been explicitly traced across 5 local records including the controller decision file.
- No new information about Core's workspace was found; it remains fully unknown.

---

## 7. Summary and Recommendations

### Corpus readiness

| Tenant | Corpus source | Local evidence | Ready to ingest? |
|--------|--------------|----------------|-----------------|
| Core | Unknown — workspace not inspected | Embed snippet only | **No** — workspace settings unknown |
| Elevate | 42 public elevatesci.com pages | Full corpus package with hashes | **Ready** — once workspace created and settings aligned |

### Immediate next steps (no additional product/scope decision required)

1. **Service owner provides Core workspace settings** — workspace name, embedding model, chunk size, chunk overlap, retrieval top-k, system prompt. Without this, Elevate cannot align its chunk/retrieval to match Core's behavior.
2. **AnythingLLM admin creates Elevate workspace** — new workspace with a distinct name (`elevate_<dataset>_<version>` per PRD v3 convention) and provides the new embed ID.
3. **Elevate branding owner provides asset values** — assistant name, brand logo URL, assistant icon URL, accent color.
4. **Product/copy owner approves Elevate workspace prompt** — based on `corpus/answer-guidance.md` or revised copy.
5. **Ingest the 42-page corpus** into the new Elevate workspace using Core's confirmed settings (once available).
6. **Run the 9-case evaluation rubric** against the configured workspace before going live.
7. **Obtain cross-tenant isolation proof** — admin confirms Elevate workspace document set matches only the 42 approved pages and retrieves correctly.

## 8. Unverified Handoff Claims

Received notes (not produced by this inventory) contain the following claims that are not corroborated by local evidence:

| Claim | Local evidence | Discrepancy / Flag |
|-------|---------------|---------------------|
| Core has 8 copied RAG documents in its workspace | No Core document manifest exists in any local record; `SERVICE_CATALOG.md` marks vector backend as `UNKNOWN`; no workspace export or config file found | **Cannot verify.** Core workspace has never been locally inspected. The 8-document figure is not in any local warehouse, corpus, or service-catalog document. |
| Elevate has 23 public pages in a manifest on Brandon | The locally documented Elevate corpus is **42 pages** from the 2026-09-23 sitemap crawl, with full SHA-256 hashes in `manifest.json` | **23 vs. 42 discrepancy.** The local record documents 42 pages; the received claim of 23 pages is not locally corroborated. This inventory did not access any remote manifest. |
| Cross-tenant isolation checks passed | No proof of workspace isolation exists in any local record; the `RAG-METADATA-CONTRACT` explicitly requires such proof as a requirement, not a completed check | **Active workspace ingestion and cross-tenant isolation are not locally verified.** No AnythingLLM admin inspection has occurred; no retrieval test, document inventory comparison, or negative cross-tenant check is documented locally. |

**This inventory did not access any remote manifest or live AnythingLLM service.** All local findings are grounded in the evidence listed in §8. The three claims above are recorded here as received notes only; they do not alter the evidence-backed findings in §§2–5.

---

## 9. Evidence References

| Evidence | Path |
|----------|------|
| Controller chatbot-RAG decision (authoritative) | `overnight-20260924/repo/BRANDON-COMPUTE-COMMS/from-brandon-compute/20260923T1840Z-controller-chatbot-rag-decision.md` |
| Warehouse AnythingLLM README | `docs/warehouse/anythingllm/README.md` |
| RAG metadata contract | `docs/warehouse/anythingllm/RAG-METADATA-CONTRACT.md` |
| Prior benchmark report | `data/local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1/report.md` |
| Prior handoff artifact | `data/local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1/anythingllm-rag-handoff-artifact.md` |
| Core chatbot handoff | `data/core-chatbot-reference-handoff-0924/report.md` |
| Elevate corpus scout | `data/elevate-public-rag-corpus-0923/report.md` |
| Elevate corpus package manifest | `data/elevate-rag-corpus-package-0923/corpus/manifest.json` |
| Elevate answer guidance | `data/elevate-rag-corpus-package-0923/corpus/answer-guidance.md` |
| Elevate core alignment note | `data/elevate-rag-corpus-package-0923/corpus/core-alignment-note.md` |
| Elevate RAG eval rubric | `data/elevate-rag-eval-0924/report.md` |
| Service catalog (AnythingLLM) | `agent-work/firstmate/docs/system-context/SERVICE_CATALOG.md:34–50, 257–270` |
| Core embed snippet | `agent-work/core-distro-saas-clean/current-core-distro/index.html:246–260` |
| Core mobile CSS | `agent-work/core-distro-saas-clean/current-core-distro/index.html:163–213` |

---

*Scout task complete. Read-only evidence gathering only. No production systems accessed, no credentials used, no changes made.*
