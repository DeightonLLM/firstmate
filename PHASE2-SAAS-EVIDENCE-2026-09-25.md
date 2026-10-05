# PHASE 2 EVIDENCE — CBD + core-distro SaaS (started 2026-09-25 ~19:20 BST)

## PHASE 1 CLOSED: AnythingLLM on brandon = 100% functional (see 2026-09-25-anythingllm-done-isolation-proven.md)

- URL: http://100.106.6.22:3001 (container `hd2stack-anythingllm`, healthy, restart-safe)
- Secrets on brandon: /home/hd2admin/hd2stack-anythingllm/.auth-token, .jwt-secret, .api-key (all chmod 600)
- Isolation proven: Elevate ws refuses Core; Core ws refuses Elevate; Elevate answers Elevate (transcripts in container chat log, chatIds 1+)
- Elevate corpus manifest: /tmp/elevate-rag/manifest.csv on brandon (23 URLs + SHA256 + crawl date 2026-09-25)

## PHASE 2 STATE (read-only assessment)

### cbd-data (cbd-datasaas)
- Source: /root/agent-work/projects/cbd-data.com/current-cbd-data (Next.js + `Leads gen saas/` PHP layer)
- Git: detached HEAD; 2 modified files: `Leads gen saas/source/lead-gen-saas/admin.php`, `cron_drip.php` (uncommitted — inspect before anything)
- node_modules MISSING → needs pnpm install before build/test
- Live surface: Namecheap/cPanel `cbddpolp` (PHP: install/login/leadlists/stripe_webhook) — DO NOT TOUCH without operator authorization
- Governing doc: BRANDON REWORK/handoff/20260923-cbd-long-term-recovery-plan.md — status HOLD_FOR_EVIDENCE, mandatory sequence:
  1. identity packet (read-only) 2. backup gate 3. canonical-source decision (PHP live vs Next.js tree) 4. staging lead-flow test

### core-distro SaaS
- Source: /root/agent-work/projects/core-distro.com/current-core-distro (static site; embed points at llm.hd2.ai today)
- Future wiring: once operator approves cutover, embed data-base-api-url can point at brandon :3001 embed endpoint (embed widget must be created in the new instance first)

## NEXT ACTIONS (in order, per recovery plan)
1. pnpm install + next build + tests in CBD tree (local, safe) → RED/GREEN evidence
2. Identity packet for cbddpolp (read-only) — needs cPanel access verification first
3. Backup gate + canonical-source decision → operator sign-off before ANY live change
4. Core-distro: create embed in new instance, wire test page, UAT before pointing real site

## GATES (hard)
- No live/cPanel/Namecheap mutations without explicit operator authorization
- No production cutover of the chatbot until operator approves (benchmark gate per 20260923 decision doc)

## PHASE 2 EXECUTION RESULTS (2026-09-25 ~19:20-19:40 BST)

- pnpm install: OK (node_modules restored)
- next build: PASS — routes compile (/, about, courses, tools, sitemap; static+dynamic mix)
- Local PHP suite: 7/7 PASS (tests/local/ — enrichment contract, job boundary x4, isolation fixture, initial status)
- Lint: skipped (interactive ESLint config prompt; needs non-interactive setup — minor)
- Uncommitted work identified as COHERENT Lane-B feature set: ADR-001 (ACCEPTED, RabbitMQ transport) + new includes/cbd_hetzner_enrichment_contract.php, includes/cbd_job_boundary.php + edits to admin/cron_drip/install/leadlists.php. 5 modified + 3 untracked files, ~557 insertions.
- Key dependency for 100%: brandon-cbd-rabbitmq container on brandon is Exited(137) — the ADR-001 transport. Restart + health check is the next infra step (bounded, reversible; queued pending operator go since it's a service mutation on brandon).
- BACKUP RULE confirmed in force: no live (cPanel/cbddpolp) edits without fresh backup + restore drill + operator authorization (recovery plan step 2). Nothing live was touched.
