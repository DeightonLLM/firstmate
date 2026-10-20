# Core Alignment Note — Elevate RAG Corpus Package

**Package:** `elevate-rag-corpus-package-0923`
**Date:** 2026-09-23

---

## Embedding & Retrieval Configuration — Unknown

The verified Core embedding model, chunk size, chunk overlap, retrieval method, and generation settings for the Core chatbot are **not available in this corpus** and have **not been confirmed by the service owner**.

Do not guess, assume, or infer these values. Do not claim exact retrieval parity with Core.

---

## What Is Known vs. Unknown

### Known (from this package)

- **Source scope:** 42 public `elevatesci.com` pages, fetched and normalized on 2026-09-23.
- **All pages remain on `elevatesci.com`:** No redirects off-domain were observed.
- **All pages are public:** No login, authentication, or form-submitted data is included.
- **Corpus verticals:** Research & Science, Lab Supplies, Quality & Documentation, Wholesale, Quote/Contact, Product Catalog, Legal/Policies.
- **Document structure:** Each source document carries: title, canonical URL, fetch date, category, content SHA-256, word count.
- **Company framing:** Elevate Life Sciences is a research-grade peptide wholesale distributor serving verified research organizations (academic, biotech, CROs); products are strictly Research Use Only; all claims are bounded by site content.
- **Safety constraints:** No medical/diagnostic/treatment/dosing/administration guidance; RUO disclaimer preserved throughout.

### Unknown (not confirmed)

- Embedding model (e.g., text-embedding-3-small, ada-002, or another provider/model)
- Chunk size (e.g., 256, 512, 768, 1024 tokens)
- Chunk overlap (if any)
- Retrieval method (top-k, similarity threshold, reranking, hybrid)
- Generation model and settings
- Any post-processing applied to retrieved chunks before generation
- Whether any of the 42 source pages are excluded from the live Core index
- Whether the Core chatbot has been given custom system instructions not present in this corpus

---

## Guidance for Integration Testing

When integrating this corpus with Core or comparing corpus behavior:

1. **Do not assert parity** without the service owner confirming the Core configuration.
2. **Validate retrieval** by testing known factual queries against both the source documents and the Core chatbot response — compare grounding quality, not just raw output.
3. **Flag content drift** if future live fetches of the same URLs produce substantially different content. The 42 hashes differ from the September 2026 baseline, but both crawls used different extraction logic, so the mismatch alone does not establish site content drift; compare with the same normalizer before drawing that conclusion.
4. **Re-run this package build** if the Elevate site undergoes significant structural changes, new pages are added, or existing pages are substantially rewritten.

---

## Post-Integration Validation

After any Core configuration is confirmed by the service owner, validate:

- [ ] Responses stay within the 42-page source scope
- [ ] RUO/not-for-human-use disclaimers appear in product-adjacent answers
- [ ] Quote/availability questions route to official contact channels
- [ ] No ungrounded claims about mechanisms, dosing, or efficacy
- [ ] Queries outside the corpus are answered with "not available from our sources" rather than fabricated content
