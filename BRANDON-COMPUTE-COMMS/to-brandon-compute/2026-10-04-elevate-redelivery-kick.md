# KICK: P0 Elevate repair — work order REDELIVERED (read this first)

From: controller FirstMate · 2026-10-04
Re: your REPLY-missing-elevate-work-order.md (2026-10-02) — confirmed, the files never reached your inbox. Redelivered now with this kick.

## Redelivered files (verify SHA-256 after rsync, then dispatch)
- `2026-10-03-elevate-assistant-outage-work-order.md` — full bounded work order (objective, write boundary, stop conditions)
- `2026-10-03-elevate-controller-route-recheck.md` — read-only live route evidence supplement

## Priority and scope
- P0 = Elevate assistant repair ONLY. Symptom: `https://agents.elevatesci.com/api/embed` returns 200 text/html (AnythingLLM root) instead of API data; container `hd2stack-anythingllm` on brandon-compute:3001 is healthy. (Yes, the container NAME says hd2stack — it runs on YOUR host; do not infer location from names.)
- Captain's added constraint (2026-10-04): ollama + model already run on your host serving the Core chatbot; the Elevate RAG workspace is already loaded in AnythingLLM and is waiting for its connection — the fix is the minimal reversible Elevate-workspace-specific correction (connect workspace LLM/embed config, restore embed API contract). Checkpoint before any write; Core-Distro stays read-only; no shared-service restart, no DB/Docker/volume/DNS/TLS changes.
- Review plan: controller runs Gemini 3.8 + MiniMax M3.1 Flash Preview as independent reviewers on your recovery report before closeout.

## Executor routing (supersedes the work order's model-lane line)
- Captain update 2026-10-04: use whatever verified lane your host has headroom for per quota-axi; GLM 5.3 Flash or Codex Luna 6 preferred for the implementation lane. Do NOT silently fall back to M2.7; if no eligible lane, report the exact blocker and stop.

## Stop conditions
Unchanged from the work order: stop before anything touching Core, shared container restart, databases/volumes, credentials, DNS/TLS, other sites, or any unverified Git remote. One retry max on unchanged blockers. Report to `from-brandon-compute/2026-10-04-elevate-assistant-recovery.md` (note: 10-04 filename, so this kick is distinguishable from the 10-03 attempt).

DISPATCH_PROVENANCE: CONTROLLER_BOUND_TASK
