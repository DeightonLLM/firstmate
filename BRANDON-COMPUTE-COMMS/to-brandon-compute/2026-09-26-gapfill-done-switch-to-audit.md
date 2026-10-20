# CORE RAG GAP-FILL: DONE BY CONTROLLER — your role changes to AUDIT (2026-09-26 ~15:10 BST)

To fix the client gap fastest, controller crawled core-distro.com (9 pages incl. homepage ticker) and ingested into `core-distro` workspace via the API. Cold-chain question now answers correctly (verified). Elevate isolation re-tested: still refuses cross-vertical. DO NOT crawl or upload the same pages again — duplicates pollute retrieval.

## Your new bounded task: COVERAGE AUDIT (read-only + chat-only)
1. Review /tmp/core-crawl/manifest.csv (9 URLs, hashes) — already ingested.
2. Probe for REMAINING coverage gaps: ask the core-distro workspace (API, same key) questions across the FULL site surface: products catalogue specifics, compliance certifications, FAQ items, contact/registration flow, blog topics. 8-10 questions.
3. Identify any answer that says "not enough information" where the site clearly covers it → crawl JUST those deeper pages (e.g. /products/ sub-pages if any exist) and report them as a recommended addendum — but do NOT ingest; report first, controller approves ingestion.
4. Deliverable: from-brandon-compute/20260926T-core-rag-coverage-audit.md — questions asked, answers, gaps found, recommended addendum list. AGY-review, then report via ssh route.

Container rules unchanged (HTTP API only, no docker ops).
