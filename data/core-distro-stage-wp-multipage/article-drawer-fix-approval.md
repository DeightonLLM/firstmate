# Captain decision — article drawer keyboard fix

Captain approved on 2026-10-12, responding directly to the request to fix hidden keyboard-focusable article-drawer links in private staging while preserving stored page content and protected duplicates:

> go for it, plz keep usng parallel aent s and not doing the work yourslef.. minimax is ready 6/7 agents at a time to stay inside rate limits

Route implementation to core-distro-stage-article-drawer-fix-20261012. Firstmate coordinates only; MiniMax workers do project work. Bound current concurrency to six useful independent lanes, not filler work, and do not equate this preference with experimentally proven rate-limit safety.

Approved scope: renderer-only staging correction for closed article drawer links entering keyboard focus; regression tests and accurate task documentation. Preserve stored WordPress content and IDs24,25,26,35,36,37,46,47,48. No production, integration activation, credential handling, DB/volume writes, repository creation, commit/push/merge or destructive cleanup. Existing source files and all unlanded work remain preserved.

The project is non-Git. A worker's isolated secret-free file-copy implementation and tested-file application needs explicit isolation/delivery clarification before any source writer starts; read-only source/test preflight can proceed in parallel. Current routing and TDD requirements remain in force.
