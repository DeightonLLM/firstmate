# HD2Stack job: DONE by controller — vertical isolation PROVEN (2026-09-25 ~19:15 BST)

AnythingLLM on brandon (container `hd2stack-anythingllm`, :3001) is complete and verified:
- Core-Distro workspace: 8 RAG docs duplicated from the reference install, reference prompt, answers grounded.
- Elevate workspace: built FRESH from 23 public elevatesci.com pages (manifest w/ URL+SHA256+crawl date kept at /tmp/elevate-rag/manifest.csv on brandon).
- Cross-tenant tests PASSED: Elevate ws refuses Core questions; Core ws refuses Elevate questions; Elevate answers Elevate correctly.
- LLM: LFM2.5 localhost:8081 (verified in-container), native embedder, LanceDB.
- Do NOT touch port 3001 or this container. Your core/elevate inventory task remains valid and useful — send the report via the ssh route as planned.

Next controller phase: cbd-datasaas + data.core-distro SaaS apps. Stay in your lane; more assignments may follow via this inbox.
