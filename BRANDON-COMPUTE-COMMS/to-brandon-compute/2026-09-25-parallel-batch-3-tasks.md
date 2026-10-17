# PARALLEL BATCH — run these as simultaneous sub-lanes (2026-09-25 ~20:15 BST)

Captain directive: hetz compute is to be used for parallel execution. You already have embed-prep running (T1). Add these as separate sub-lanes with MiniMax 2.7 workers; AGY-review each deliverable on YOUR side before reporting.

## T2 — Music Metrics perf benchmark (docker, local to you)
Bounded: docker on brandon only; no live services.
1. Spin up a throwaway `mariadb:10.6` container (random root pw, port 33060) + `php:8.1-cli` container.
2. Create a fixture DB with lead_lists/lead_list_items (seed ~50k synthetic rows; schema auto-creates by the page itself).
3. Serve the CURRENT leadlists.php from branch perf/request-fastpath-20260925 (github.com/DeightonLLM/SAAS, private — report if you need access) AND the prior version from the release branch. Measure: time-to-first-byte of a logged-in-style GET + query count (session/SQL audit) OLD vs NEW, 5 runs each.
4. Deliverable: benchmark report (numbers + method) to from-brandon-compute/20260925T-mm-perf-benchmark.md. Report via ssh route.
Note: you may need SAAS repo read access — if git clone fails, say so in the report; controller will mint a fine-grained token or hand you a tarball via inbox.

## T3 — core-v3-prd-gap-map: UNBLOCKED, coordinates provided
Your backlog hold is released. Canonical coordinates (read-only):
- Live static source: /home/hd2admin (check ~/kun-agent-workspace/projects/ for core-distro-saas-clean/current-core-distro; if absent, request via route)
- Controller-side truth (mirrored to you via warehouse docs/): anythingllm/STACK-MAP.md, PRD anchor docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md
- Completed Stream A artifacts + checkpoint baseline: look under your workspace projects/core-distro.com/
Produce the gap map: what's evidenced done vs missing for Core Distro V3 acceptance, no edits/tests/merges. Same evidence path convention, suffix -gapmap.

## T1 — embed-prep: continue as assigned (check inbox 2026-09-25-task-hd2-embed-prep.md)

## Standing
- Parallelism authorized by captain tonight. Three lanes max concurrent. AGY-review before reporting. Anything live/production stays captain-gated.
