# YOUR THREE ASKS — answered + T2 source snapshot DELIVERED (2026-09-26 ~14:55 BST)

## 1. Canonical product-spec paths (Core V3)
What exists (verified paths):
- SaaS v3 first-install canonical source (git-locked): controller `/root/lead-gen-saas-v3-first-install-ready-20260710/` — lock commit `c0dde36` 2026-07-17; post-lock `pkg/login.php` + `pkg/SHA256SUMS` modifications documented in `agent-work/FIRST_INSTALL_RELEASE_INTEGRITY_DECISION_20260720.md`
- Site source: controller `/root/agent-work/projects/core-distro.com/current-core-distro/`
- Source-of-truth doc: controller `deightonllm-firstmate/projects/core-distro.com/SOURCE_OF_TRUTH.md`
- PRD anchor: `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`
HONEST STATUS: no standalone product ACCEPTANCE spec exists — your gap-map finding stands; that document has never been written. Awaiting captain to either ratify the PRD+acceptance-matrix as the spec or commission one. Record that as the terminal state of your finding.

## 2. T1 (hd2-embed-prep) — OWNER: YOU. RE-AUTHORIZED.
The assignment note (brandon-inbox 2026-09-25-task-hd2-embed-prep.md) is yours; re-read it. Local-only preview on brandon explicitly authorized. Deliverable + evidence path unchanged. If the note is missing from your inbox, say so and controller re-drops it.

## 3. T2 — SOURCE SNAPSHOT DELIVERED (no credentials needed)
- Tarball extracted at: `/home/hd2admin/kun-agent-workspace/data/mm-saas-snapshot-20260925/`
- Contents: live-current/ (incl. perf fastpath leadlists.php), m3-protected-20260809/ (worker+queue_claim), tests/ (php + python suites), csv-city-coverage-20260818/, MANIFEST/RELEASE docs
- Provenance: controller /root/agent-work/music-metrics-source-of-truth @ branch perf/request-fastpath-20260925 commit 4af430a (also mirrored on private GitHub DeightonLLM/SAAS)
- Benchmark as originally briefed: throwaway mariadb:10.6 + php:8.1-cli, ~50k synthetic rows, OLD (release baseline) vs NEW (fastpath) TBT + query counts, 5 runs each, report to from-brandon-compute/20260925T-mm-perf-benchmark.md
- Docker use for throwaway benchmark containers is authorized by the captain tonight.

## Standing
- Rollout: still queued (captain gate). Nothing live touched.
