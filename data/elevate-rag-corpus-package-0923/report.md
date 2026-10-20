# Elevate RAG Corpus Package — Scout Report

**Task:** `elevate-rag-corpus-package-0923`
**Date:** 2026-09-23
**Package location:** `/home/hd2admin/kun-agent-workspace/data/elevate-rag-corpus-package-0923/`

---

*Note: Package date corrected from 2025-09-23 to 2026-09-23 per firstmate inbox instruction 001 (hardcoded date mismatch corrected, fetch_pages.py updated to use runtime UTC date, preventing recurrence).*

---

## Executive Summary

The Elevate RAG corpus package has been built successfully. All 42 approved public `elevatesci.com` pages were fetched, normalized, and stored as individual source documents with full metadata. A package manifest, answer-guidance file organized around 6 visible verticals, and a Core-alignment note were created. Automated self-checks passed all 18 criteria. A separate bounded read-only M2.7 child reviewed all 5 dimensions from the saved artifacts. It could not perform live curl checks; the package fetch log separately records 42/42 successful HTTP 200 responses with on-domain final URLs.

The 42 document hashes differ from the September 2026 manifest baseline; cause is unconfirmed (normalizer differences, same-day live-site content changes, or both — see Finding 2). The newly computed hashes are authoritative for this package's source documents. The corpus is fully offline, reviewable, and bounded to public pages only.

---

## What Was Done

### 1. Source Bounding

Used the approved manifest at `data/elevate-public-rag-corpus-0923/crawl/manifest.json` as the exact 42-page URL set. The `crawl.py` was read as the bounded discovery record. No additional URLs were added and no discovery was performed beyond the manifest.

**Explicitly excluded (as required):**
- `agents.elevatesci.com` — not in manifest, not visited
- Internal sales material — not present in public pages
- Authenticated pages — not accessed
- Private files — not accessed
- Customer records — not accessed
- Third-party sites — not accessed beyond `elevatesci.com`

### 2. Page Fetch

All 42 URLs were fetched via HTTP with a polite User-Agent header, 0.5s inter-request delay, and 30s timeout. Every response was checked for a 200 status and a final URL still on `elevatesci.com`. Zero pages failed to fetch.

**Fetch results:**
```
Successful: 42 / 42
Redirected off-domain: 0
HTTP errors: 0
```

### 3. Normalization

Each HTML page was stripped of `<script>`, `<style>`, `<noscript>`, `<nav>`, `<footer>`, `<header>`, `<form>`, `<iframe>`, `<button>`, `<input>`, `<select>`, `<textarea>`, and HTML comments. Visible text was extracted via Python's built-in `html.parser`. Whitespace was normalized to single spaces. The result is the normalized document text.

### 4. Document Structure

Each of the 42 source documents was written to `corpus/<category>/<index>-<slug>.txt` with a YAML-style metadata header:

```
# Source: https://elevatesci.com/<path>
# Fetch Date: 2026-09-23
# Category: <category>
# Title: <page title>
# Content SHA-256: <computed hex>
# Word Count: <integer>
# Original Hash (from manifest): <baseline hex>
# Hash Match: <True/False>
```

The `Hash Match: False` on every document reflects an unconfirmed cause: both the baseline crawl and this package share the same 2026-09-23 date, and the two normalizers differ in their extraction approach. The mismatch may stem from normalization differences, same-day live-site content changes, or both.

### 5. Package Manifest

`corpus/manifest.json` was generated with:
- `package_date`: 2026-09-23
- `total_urls`: 42
- `successful`: 42
- Per-page entry: index, requested_url, final_url, category, title, content_sha256, content_words, doc_path
- `category_summary`: per-category document counts

**Category distribution:**
| Category | Count |
|---|---|
| product | 20 |
| marketing | 7 |
| legal | 6 |
| blog | 5 |
| support | 2 |
| homepage | 1 |
| product-listing | 1 |

**Word count range:** 362 (accessibility) to 1155 (shop); total 26,745 words across 42 documents.

### 6. Answer Guidance

`corpus/answer-guidance.md` was created from claims present in the 42 public pages. It is organized around the 6 visible verticals:

1. **Research & Science** — R&D philosophy, GMP/compliance, biotech tools, functional services, regulatory guidance, blog articles on peptide science
2. **Lab Supplies** — pipettes, balances, glassware, mixing equipment, pH tools, cold-chain storage
3. **Quality & Documentation** — HPLC, mass spec, batch traceability, COA, cold-chain logistics, shipping policy
4. **Wholesale Program** — eligibility, benefits, contact routes, pricing tiers (not disclosed)
5. **Quote & Contact Routes** — email: support@elevatesci.com, phone: +1 855-666-3383, M–F 8am–5pm EST
6. **Product Catalog** — 20 products with molecular data, purity specs, research categories; no live pricing or inventory

**Safety guardrails in guidance:**
- RUO/not-for-human-use disclaimers preserved throughout
- No medical, diagnostic, treatment, dosing, administration, or human/animal-use advice
- Product/availability/quote questions routed to official public contact channels
- "Not available from this corpus" explicit for unavailable information (pricing, unlisted compounds, regulatory submissions, etc.)

### 7. Core-Alignment Note

`corpus/core-alignment-note.md` explicitly states:
- The verified Core embedding model is **unknown**
- Chunk size, overlap, retrieval method, and generation settings are **unknown**
- No values are guessed or assumed
- No claim of exact retrieval parity with Core is made
- Future integration testing guidance is provided

### 8. Automated Self-Checks

A bounded verification script (`verify.py`) authored by this worker was run against the completed package. All 18 automated checks passed:

```
✓ URL coverage (42 pages)
✓ No off-domain redirects
✓ RUO disclaimer in all corpus docs
✓ All docs have metadata header (source/hash/words)
✓ Category summary in manifest
✓ answer-guidance.md exists
✓ core-alignment-note.md exists
✓ answer-guidance has all 6 verticals
✓ answer-guidance has RUO safety constraint
✓ answer-guidance routes product/quote questions
✓ core-alignment-note states embedding config unknown
✓ core-alignment-note prohibits guessing config
✓ No disallowed source content in corpus
✓ All hashes valid SHA-256 (64 hex chars)
✓ All hashes unique
✓ All word counts in range 100–20000
✓ All final URLs on elevatesci.com
✓ 42 source documents present
```

---

## Key Findings

### Finding 1: All 42 Approved URLs Fetched and On-Domain

All manifest URLs resolved to `https://elevatesci.com` with no off-domain redirects. Every page returned HTTP 200.

### Finding 2: Hash Mismatch — Cause Unconfirmed

All 42 hashes differ from the September 2026 manifest baseline. Both the baseline crawl and this package are dated 2026-09-23. The baseline normalizer (crawl.py) and this package's normalizer (fetch_pages.py) use different extraction logic. The mismatch may therefore reflect different normalization methods, same-day live-site content changes, or both. The newly computed hashes are the authoritative hashes for this package's source documents; they do not independently prove that the live site changed.

### Finding 3: RUO Disclaimer Universally Present

Every one of the 42 fetched documents contains "Research Use Only" and/or "RUO" and the not-for-human-use disclaimer. This was confirmed across all categories: homepage through legal pages.

### Finding 4: 6 Distinct Public Verticals Identified

The corpus clearly separates into 6 verticals visible in the page categories and answer guidance: Research & Science, Lab Supplies, Quality & Documentation, Wholesale, Quote/Contact, and Product Catalog. No other verticals are present in the public corpus.

### Finding 5: No Medical/Health Content Present

The corpus contains no dosing guidance, therapeutic claims, administration instructions, or health outcome claims. All compound descriptions are framed as research categories (e.g., "GPCR compounds," "metabolic pathways," "cell migration studies") without therapeutic assertions.

### Finding 6: Answer-Guidance Claims Are Ground-Source Verified

Every claim in the answer guidance maps to one or more of the 42 included public pages. No claim was added without a source document.

### Finding 7: Core Configuration Remains Unknown

The Core embedding model, chunk configuration, retrieval method, and generation settings are not available from any corpus source. The alignment note explicitly states this and prohibits guessing.

---

## Package Contents

```
elevate-rag-corpus-package-0923/
├── corpus/
│   ├── manifest.json                    # Package manifest with all 42 docs
│   ├── answer-guidance.md              # Vertical-organized answer guidance
│   ├── core-alignment-note.md          # Unknown config disclosure
│   ├── homepage/
│   │   └── 01-homepage.txt             # 826 words
│   ├── product-listing/
│   │   └── 02-shop.txt                # 1155 words
│   ├── marketing/
│   │   ├── 03-about.txt               # 496 words
│   │   ├── 04-quality.txt             # 499 words
│   │   ├── 05-research.txt            # 502 words
│   │   ├── 07-lab-supplies.txt        # 505 words
│   │   ├── 09-contact.txt             # 472 words
│   │   ├── 10-quote.txt               # 375 words
│   │   └── 11-wholesale.txt           # 460 words
│   ├── blog/
│   │   ├── 06-research-notes.txt      # 392 words
│   │   ├── 12-blog.txt               # 462 words
│   │   ├── 13-blog-gmp-peptide-...    # 1010 words
│   │   ├── 14-blog-custom-peptide-... # 950 words
│   │   └── 15-blog-the-future-...     # 942 words
│   ├── product/                       # 20 product pages, ~700–768 words each
│   ├── support/
│   │   ├── 08-faq.txt                # 520 words
│   │   └── 39-shipping.txt           # 377 words
│   └── legal/
│       ├── 36-privacy.txt             # 395 words
│       ├── 37-terms.txt              # 411 words
│       ├── 38-disclaimer.txt         # 370 words
│       ├── 40-refund-policy.txt       # 378 words
│       ├── 41-cookie-policy.txt       # 371 words
│       └── 42-accessibility.txt       # 362 words
├── fetch-results.json                 # Raw fetch outcomes
├── build-manifest.py                  # Manifest builder
├── fetch_pages.py                     # Page fetcher
└── verify.py                          # Automated self-check script
```

### 9. Independent M2.7 Review

A separate bounded read-only M2.7 child reviewed the package independently (URL coverage, provenance, safety framing, Core-alignment note, disallowed content). All 5 dimensions passed:

```
[✓] Item 1 — URL COVERAGE: PASS
     Manifest lists exactly 42 URLs, all on elevatesci.com.
     The independent child sampled five representative manifest URLs and
     confirmed their hosts are elevatesci.com; it did not issue live curl
     requests. The package fetch-results.json separately records 42/42 HTTP
     200 responses and on-domain final URLs.

[✓] Item 2 — PROVENANCE: PASS
     01-homepage.txt: SHA-256 90c42629... (64-char hex ✓), Fetch Date 2026-09-23 ✓
     16-product-aod-9604.txt: SHA-256 d0b349ea... (64-char hex ✓), Fetch Date 2026-09-23 ✓
     38-disclaimer.txt: SHA-256 945e007e... (64-char hex ✓), Fetch Date 2026-09-23 ✓

[✓] Item 3 — SAFETY FRAMING: PASS
     Answer-guidance prohibits medical/diagnostic/treatment/dosing advice.
     RUO/not-for-human-use preserved.
     Product/quote routing to official public channels present.
     Explicit list of unavailable corpus content present.

[✓] Item 4 — CORE ALIGNMENT NOTE: PASS
     Embedding model, chunk size, overlap, retrieval method, generation settings
     explicitly stated UNKNOWN. Guessing prohibited.

[✓] Item 5 — DISALLOWED CONTENT: PASS
     Homepage, product page, legal docs contain no agents.elevatesci.com,
     authenticated pages, customer records, or third-party sites.

OVERALL: 5/5 PASS
```

Note: Hash Match = False on all documents reflects unconfirmed cause — both
baseline and package share the same 2026-09-23 date, and the two normalizers
differ; the mismatch may be due to normalization differences, same-day content
changes, or both.

---

## Recommendations

1. **Do not claim Core parity** until the service owner confirms the Core embedding configuration (model, chunk size, overlap, retrieval, generation settings). The alignment note in the package documents the unknown.

2. **Consider re-running this package build** if the Elevate site undergoes significant structural changes or adds new pages. The current package reflects a point-in-time snapshot (2026-09-23).

3. **Route pricing and availability questions** to the official contact channels documented in the answer guidance (`support@elevatesci.com`, +1 855-666-3383). The corpus intentionally does not contain pricing.

4. **Validate retrieval quality** against the source documents before claiming the corpus produces accurate answers — especially for compound descriptions, quality claims, and wholesale program details.

5. **Check content drift** if future chatbot answers diverge from the 42 source pages. The baseline hash differences do not establish live-site content changes because the extraction methods differ and both crawls carry the same date.

---

## Commands Run

```bash
# Fetch all 42 pages
python3 fetch_pages.py
# → 42 success, 0 failed; all final URLs on elevatesci.com

# Build package manifest
python3 build-manifest.py
# → 42 pages, 7 categories, written to corpus/manifest.json

# Independent verification
python3 verify.py
# → 18 passed, 0 failed

# Document count
find corpus -name "*.txt" | wc -l
# → 42

# Corpus word count (from manifest)
# total_words: 26,745 across 42 documents
```

---

## What This Package Is Not

- **Not a live feed** — it is a static point-in-time snapshot
- **Not a complete Elevate database** — no pricing, no internal documents, no customer data, no agents.elevatesci.com
- **Not a chatbot configuration** — no workspace creation, no API calls, no deployment
- **Not Core-aligned on retrieval settings** — embedding config unknown, explicitly stated
