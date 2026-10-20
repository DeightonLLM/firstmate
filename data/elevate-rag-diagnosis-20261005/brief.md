# Task
## Captain's intent
QUALITY BUG (captain 2026-10-05): chat plumbing works but the bot KNOWS NOTHING — answers are generic. Diagnose the RAG side with the `.api-key`:
(1) elevate workspace: document count + list (is ANYTHING embedded?), embedding/retrieval config (query mode, topK, similarity threshold), chatProvider+model in use;
(2) the test chat record (chatId=15): did retrieval return sources or empty context?;
(3) docker logs elevate-anythingllm tail -100: embedding/retrieval errors;
(4) was elevatesci.com ever CRAWLED into this workspace (website-depth crawl or uploads)?
REPORT: root cause of the empty answers + the fix plan (e.g., site crawl + embed, config correction) with cost estimate. Do not crawl/upload yet — plan first. Artifact + VERDICT as usual.

## Firstmate spec
Bounded diagnostic. Use the .api-key for read-only admin probes. NO container/db/config/restart mutations. NO crawl/upload. Report:
- workspace document inventory (count, list, embed status)
- retrieval config (query mode, topK, similarity threshold, chatProvider, model)
- chatId=15 sources/context state
- docker logs tail (errors only, sanitized)
- elevatesci.com crawl/upload history (or absence thereof)
- ROOT CAUSE diagnosis
- FIX PLAN (no execution yet): site re-crawl option, embed config correction, etc. — INCLUDE COST ESTIMATE (LLM time, USD, token cost)

# Setup
This is a read-only diagnostic. NO mutations. NO crawl. NO embed. NO config change. Use the existing `.api-key` for admin read-only probes. Use sqlite3 read-only for DB inspection.

# Rules
1. Never push or write outside this worktree and the report paths.
2. Report status by: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/elevate-rag-diagnosis-20261005.status'`
   States: working, needs-decision, blocked, paused, done, failed.
3. If blocked twice, append `blocked [at=<epoch>]: {why}` and stop.
4. Use lean-ctx for all reads, searches, listings, shell output.
5. Use the To-Do List extension with five+ dependency-aware items: preflight, workspace inventory, retrieval config, chatId=15 inspection, docker logs, root-cause + fix-plan + report.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/elevate-rag-diagnosis-20261005.inbox'/*.msg. Move handled to inbox/handled/.

# Definition of done
Report must include:
- VERDICT: PASS or BLOCKED
- Root cause (specific gap identified with evidence)
- Fix plan (sequential steps + cost estimate)
- All evidence paths cited; no speculative findings
- DO NOT EXECUTE the fix — plan only
- If chat already has clean plumbing (per earlier 022.msg test where model answered correctly about Elevate), then this is a RAG-side gap, not a plumbing gap

Write to:
- `/home/hd2admin/kun-agent-workspace/data/elevate-rag-diagnosis-20261005/report.md` (full)
- `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-05-elevate-rag-diagnosis.md` (captain copy)

Append `done [at=<epoch>]: {one-line conclusion}` to status file.

# Home brief additions
## Pi Worker Defaults
- Create one concise checklist with Pi's `todo` tool at task start.
- Use lean-ctx for shell output; find it at ~/.local/bin/lean-ctx if not on PATH.
- Use Codex GPT-6 Luna medium effort per captain.
- Use MiniMax M3.1 Flash Preview for independent review pass before final commit (optional but recommended).
- .api-key path: /home/hd2admin/hd2stack-anythingllm/.api-key. NEVER print the value in the report; reference it as ".api-key credential".
- Cost estimates: include LLM tokens, embedding tokens, time estimates. Use quota-axi for runway if available.