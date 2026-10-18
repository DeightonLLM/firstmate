# Elevate Public RAG Corpus Scout Report

**Task:** elevate-public-rag-corpus-0923
**Crawl date:** 2026-09-23
**Scope:** Public pages on `https://elevatesci.com` only — bounded by sitemap discovery
**Exclusions applied:** `agents.elevatesci.com`, authentication flows, dashboards, forms, third-party sites, internal files

---

## 1. Discovery Scope

| Source | Result |
|--------|--------|
| `robots.txt` | Allows all: `Allow: /` |
| Sitemap | `https://elevatesci.com/sitemap.xml` — 42 URLs listed |
| Sitemap index | Not present |
| Off-domain redirects | None |

**Discovery method:** sitemap-only. No link-crawl or spider. Agents subdomain and any auth/dashboard paths were not in the sitemap and are excluded by scope.

---

## 2. Page Inventory

All 42 sitemap URLs returned HTTP 200. Zero errors, zero duplicates (all SHA-256 hashes distinct).

### 2a. By Category

| Category | Pages | Normalized Words |
|----------|------:|----------------:|
| product | 20 | 11,635 |
| blog | 5 | 3,036 |
| marketing | 7 | 2,194 |
| legal | 6 | 1,421 |
| product-listing | 1 | 1,011 |
| homepage | 1 | 681 |
| support | 2 | 609 |
| **Total** | **42** | **20,587** |

### 2b. Full Manifest

| # | Path | Category | HTTP | Title | Words | Content SHA-256 |
|---|------|---------|------|-------|------:|-----------------|
| 1 | / | homepage | 200 | Elevate Life Sciences \| Research Peptides | 681 | `7828d3fc3a375849…` |
| 2 | /shop | product-listing | 200 | Research Peptide Catalog | 1,011 | `3cc51127ee558b09…` |
| 3 | /about | marketing | 200 | About Us | 352 | `1bd10b62d90920d9…` |
| 4 | /quality | marketing | 200 | Quality & Documentation | 355 | `8aafd1cb63f1e521…` |
| 5 | /research | marketing | 200 | Science & Research | 358 | `0a83d383ddbff238…` |
| 6 | /research-notes | blog | 200 | Research Notes | 248 | `1bc0d15de44192c7…` |
| 7 | /lab-supplies | marketing | 200 | Lab Supplies — Essential Tools | 361 | `944c4f3728623bf5…` |
| 8 | /faq | support | 200 | Frequently Asked Questions | 376 | `d2aeb4f1e7db5fab…` |
| 9 | /contact | marketing | 200 | Contact Elevate Life Sciences | 301 | `7f7f95cf2d784d9a…` |
| 10 | /quote | marketing | 200 | Request a Quote | 208 | `e8be4a220e1717b7…` |
| 11 | /wholesale | marketing | 200 | Wholesale Program | 259 | `d847fcc8630a7d32…` |
| 12 | /blog | blog | 200 | Blog — Peptide Research Insights | 318 | `f05972973165515f…` |
| 13 | /blog/gmp-peptide-manufacturing | blog | 200 | GMP Peptide Manufacturing | 866 | `6a23e8dd64f123d5…` |
| 14 | /blog/custom-peptide-synthesis-guide | blog | 200 | Custom Peptide Synthesis Guide | 806 | `701737a75f775ce0…` |
| 15 | /blog/the-future-of-peptide-research | blog | 200 | The Future of Peptide Research | 798 | `e4ee63e4ff3c32dd…` |
| 16 | /product/aod-9604 | product | 200 | AOD-9604 — Research Grade | 569 | `9ca4ce62d32ce31a…` |
| 17 | /product/bpc-157 | product | 200 | BPC-157 — Research Grade | 579 | `e8555e4c4d57abd7…` |
| 18 | /product/bpc-157-tb-500 | product | 200 | BPC-157 + TB-500 — Research Grade | 575 | `37a69638de0c8e6c…` |
| 19 | /product/b-12 | product | 200 | B-12 — Research Grade | 576 | `10a7b521afb7f69d…` |
| 20 | /product/cjc-1295-ipamorelin-no-dac | product | 200 | CJC-1295 + Ipamorelin — Research Grade | 621 | `b09d38d8a49a70a2…` |
| 21 | /product/cjc-1295-no-dac | product | 200 | CJC-1295 (No DAC) — Research Grade | 607 | `2a415467b21ecbaf…` |
| 22 | /product/epitalon | product | 200 | Epitalon — Research Grade | 596 | `ced75e2459f3a0b9…` |
| 23 | /product/glow | product | 200 | GLOW — Research Grade | 503 | `3f099004b920c043…` |
| 24 | /product/glutathione | product | 200 | Glutathione — Research Grade | 600 | `7f67864ecf83e2de…` |
| 25 | /product/igf-1-lr3 | product | 200 | IGF-1 LR3 — Research Grade | 624 | `b1f7390d661ce6eb…` |
| 26 | /product/ipamorelin | product | 200 | Ipamorelin — Research Grade | 603 | `a8ad05eba521da45…` |
| 27 | /product/klow | product | 200 | KLOW — Research Grade | 500 | `e0cf0be30b032325…` |
| 28 | /product/l-carnitine | product | 200 | L-Carnitine — Research Grade | 563 | `8a743e20de9728f4…` |
| 29 | /product/mots-c | product | 200 | MOTS-C — Research Grade | 619 | `ee4a94d7aa97a568…` |
| 30 | /product/mt-2 | product | 200 | MT-2 — Research Grade | 586 | `c8f091f999494838…` |
| 31 | /product/nad-plus | product | 200 | NAD+ — Research Grade | 598 | `d97d46a7fd36eaf0…` |
| 32 | /product/glp-3 | product | 200 | GLP-3 — Research Grade | 559 | `e7f1f8370b7a9b18…` |
| 33 | /product/selank | product | 200 | Selank — Research Grade | 595 | `f3e18e3b1833ee79…` |
| 34 | /product/tb-500 | product | 200 | TB-500 — Research Grade | 557 | `c21aabcff10b1c77…` |
| 35 | /product/tesamorelin | product | 200 | Tesamorelin — Research Grade | 605 | `d4479fcea103a37b…` |
| 36 | /privacy | legal | 200 | Privacy Policy | 250 | `95f3d6db55819640…` |
| 37 | /terms | legal | 200 | Terms of Service | 267 | `d04c192e6cd79544…` |
| 38 | /disclaimer | legal | 200 | Research Use Disclaimer | 226 | `e06f1b3e9b0ba347…` |
| 39 | /shipping | support | 200 | Shipping Policy | 233 | `fe1fc417b61842e7…` |
| 40 | /refund-policy | legal | 200 | Refund and Returns Policy | 234 | `7f7932f5660de5b8…` |
| 41 | /cookie-policy | legal | 200 | Cookie Policy | 227 | `51815696d5ff0e67…` |
| 42 | /accessibility | legal | 200 | Accessibility Statement | 217 | `e2f95eb6715d4da6…` |

Full SHA-256 hashes are in `crawl/manifest.json`.

---

## 3. RAG Coverage Assessment

### 3a. Content Quality by Category

**Product pages (20 pages, ~580w each avg):** Each product page includes the peptide name, formula/molecular weight, CAS number, purity claim (≥98% HPLC), research use statement, and a short description. Content is consistent and structured — a clear candidate for RAG. CAS numbers and chemical data are particularly useful for factual Q&A.

**Blog posts (5 pages):** Three substantive long-form articles (GMP manufacturing, custom synthesis guide, future of peptide research; ~800–866w each) plus two listing pages (/blog, /research-notes; ~250–318w). The long-form posts are the highest-value RAG sources by word count and depth.

**Marketing pages (7 pages):** Short descriptive content (~200–360w). Useful for top-of-funnel chatbot questions about the company, quality standards, research focus, lab supplies, wholesale, and contact/quote routes.

**Legal pages (6 pages):** ~220–270w each. Required for compliance-adjacent Q&A (shipping, refunds, privacy, terms, disclaimer, accessibility). Low RAG value individually but needed for policy questions.

**Support pages (2 pages):** /faq (~376w) and /shipping (~233w). /faq is useful for common researcher questions. /shipping overlaps partially with legal.

**Homepage + shop:** Homepage (~681w) is a broad brand overview; /shop (~1,011w) is a catalog listing. Both add context for general navigation queries.

### 3b. No Duplicates or Off-Domain Redirects

All 42 pages have unique content hashes. No HTTP redirects to off-domain targets were observed. All canonical URLs resolve to the requested URL.

### 3c. Notable Content Observations

- Every page carries a `For Research Use Only · Not for human use` banner.
- All product pages follow a consistent template: name, purity, LOT code, formula, M.W., CAS number, brief description.
- The `/blog/gmp-peptide-manufacturing` article is dated 2026-02-18, indicating active content publishing.
- No user-generated content, comment sections, or dynamic community features found (consistent with a marketing-only public surface).
- No AnythingLLM, agents, or dashboard paths appear in the sitemap — excluded paths were already out of scope.

---

## 4. Comparison with Core Artifact (anythingllm-rag-handoff-artifact.md)

The Core artifact (dated 2026-09-23) documents the Core chatbot's AnythingLLM workspace and planned Elevate workspace. Key comparisons:

| Field | Core Artifact | This Crawl |
|-------|--------------|------------|
| Embedding model | **UNKNOWN** | Must match Core once confirmed |
| Chunk size | **UNKNOWN** | Must match Core once confirmed |
| Chunk overlap | **UNKNOWN** | Must match Core once confirmed |
| Retrieval top-k | **UNKNOWN** | Must match Core once confirmed |
| Source type | `llms.txt` + PHP pages | Full HTML sitemap pages |
| Document manifest hashes | **NONE** | All 42 SHA-256 hashes available |
| Elevate corpus | **NOT INGESTED** | 42 pages ready for ingestion |
| Product page count | not stated | 20 products |
| Blog posts | not stated | 3 substantive + 2 listing pages |
| Total words | not stated | 20,587 (normalized) |
| Duplicate detection | not available | Unique across all 42 pages |

**Finding:** Core's workspace settings (embedding model, chunk strategy, retrieval) remain genuinely unknown and are blocking replication. The Core artifact explicitly marks these as UNKNOWN. Once the captain or operator provides those settings (screenshot or config), Elevate's chunk/retrieval can be aligned.

The Elevate corpus here is a clean, bounded set with full hash verification — structurally more auditable than Core's inferred document list.

---

## 5. Recommendations

### 5a. Immediate (ready to ingest)

1. **Ingest all 20 product pages** — highest RAG value per page, consistent structure, ~580 words each. These answer "what is X peptide", "what purity", "what CAS number" queries.
2. **Ingest 3 long-form blog posts** — `/blog/gmp-peptide-manufacturing`, `/blog/custom-peptide-synthesis-guide`, `/blog/the-future-of-peptide-research`. Substantive, 800–866 words, useful for detailed technical Q&A.
3. **Ingest /shop and /faq** — catalog overview and common researcher questions.
4. **Ingest marketing pages** (`/about`, `/quality`, `/research`, `/lab-supplies`, `/wholesale`, `/contact`) for brand/procedure queries.

### 5b. Defer / review

5. **Legal pages** — /privacy, /terms, /disclaimer, /refund-policy, /cookie-policy, /accessibility. Useful for compliance Q&A but low word count. Ingest if chatbot will handle policy questions.
6. **Legal/shipping overlap** — /shipping overlaps with /refund-policy in scope. Consider deduplicating at chunk level.

### 5c. Blocked on Core settings

7. **Chunk/embedding alignment** — embedding model, chunk size, overlap, and retrieval top-k must be obtained from the Core AnythingLLM workspace (operator screenshot or config export). Without these, Elevate cannot replicate Core's retrieval behavior.

### 5d. Optional expansion

8. **Blog pagination** — the /blog and /research-notes listing pages show the crawl captured only 3 blog posts. If there are more posts not in the sitemap, a link-follow crawl of those two pages would surface them. Recommend a targeted follow-crawl of `/blog` and `/research-notes` listing pages only, staying within `elevatesci.com/blog*` and `elevatesci.com/research-notes*`.
9. **COA/technical documentation** — if Elevate publishes Certificate of Analysis documents publicly, those would add high-value factual content. Check `/quality` page for links.

---

## 6. Exclusion Audit

| Path | Included? | Reason |
|------|-----------|--------|
| `agents.elevatesci.com` | ❌ Not crawled | Excluded by scope |
| Auth/login paths | ❌ Not crawled | Not in sitemap |
| Dashboard paths | ❌ Not crawled | Not in sitemap |
| Forms requiring submission | ❌ Not crawled | Not in sitemap |
| Third-party sites | ❌ Not crawled | Out of domain |
| `.lavish/client-sales-journeys.html` | ❌ Not crawled | Internal file, not public |
| AnythingLLM admin/API | ❌ Not accessed | Not public |
| Customer data | ❌ Not accessed | Not in scope |

---

## 7. Artifact Locations

| File | Path |
|------|------|
| Raw manifest (JSON) | `data/elevate-public-rag-corpus-0923/crawl/manifest.json` |
| Crawl script | `data/elevate-public-rag-corpus-0923/crawl/crawl.py` |
| This report | `data/elevate-public-rag-corpus-0923/report.md` |

---

*Scout task `elevate-public-rag-corpus-0923`. Evidence: `robots.txt` (Allow: /, sitemap: `https://elevatesci.com/sitemap.xml`), 42/42 HTTP 200, 0 errors, 0 duplicates, 20,587 normalized words across 7 categories. Core workspace settings remain UNKNOWN — ingestion chunk/retrieval alignment blocked until operator provides screenshot or config.*
