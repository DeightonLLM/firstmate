# Task
## Captain's intent
Prepare a grounded, safety-aware evaluation set for the approved public Elevate RAG corpus so the future chatbot workspace can be evaluated as soon as runtime access is available.

## Firstmate spec
Use only the already-built local package at `/home/hd2admin/kun-agent-workspace/data/elevate-rag-corpus-package-0923/corpus/` and its `manifest.json` and `answer-guidance.md`. Do not crawl the web or add new source material. Do not edit any project or package file, ingest documents, contact an API, call the local model, or route traffic.

Create 8–10 compact synthetic test cases in `/home/hd2admin/kun-agent-workspace/data/elevate-rag-eval-0924/golden-set.json`, with a companion `report.md` explaining the rubric and limits. Cover all six approved verticals: Research & Science, Lab Supplies, Quality & Documentation, Wholesale, Quote & Contact, and Product Catalog. Include at least two out-of-corpus or safety-boundary cases, such as a dosing/treatment request and a price/inventory question that the public corpus cannot answer. Each case must include:
- stable case id and query;
- case type (grounded-answer, abstain, or safe-redirect);
- expected answer constraints as short paraphrases, never long source quotations;
- exact supporting source URL(s) from the manifest, or `none` for abstentions;
- observable pass/fail criteria for source support, citation correctness, company framing, RUO language where applicable, and safe handling;
- an explicit note when the corpus cannot answer the query.

All statements in the expected answers must be traceable to the cited local document. Do not invent pricing, availability, regulatory approval, health outcomes, or internal company details. Preserve the existing RUO/not-for-human-use boundary; expected answers must not include dosing, diagnosis, treatment, administration, or human/animal-use advice. Keep output suitable for later review before it is used as a benchmark.

Use one concise live Pi `todo` checklist; print the full list in the visible pane, keep exactly one step active, and update the same list at milestones. Before any long review or child call, print a short progress note. After the set is drafted, one bounded MiniMax-M2.7 child may independently check source URL existence and safety labels against the local corpus only; no recursive delegation, web requests, tests, or model/API calls. Inspect child status before retrying. Firstmate/Codex owns final review.

Use `lean-ctx` for routine local reads if available, and preserve exact source URLs and hashes. Append only phase-change and terminal status events. This is a private evaluation artifact, not implementation or deployment approval.
