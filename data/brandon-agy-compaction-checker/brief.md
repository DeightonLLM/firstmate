# Task: brandon-agy-compaction-checker

## Captain's intent
Independent AGY read-only checker dispatched by parent coordinator. Verify the effective `reserveTokens` value and the ACTIVE provider/model key for `gpt-6-luna` in the installed Pi on brandon-compute. Read-only only.

## Firstmate spec
- Role: Fresh AGY scout checker, visible pane
- Harness: agy with gemini-3.8-flash-medium
- Hard rules: No mutations, no credential access, no service changes

## Objective
1. Use the To-Do List extension — create exactly 5 dependent items: (a) preflight, (b) read models.json, (c) read Pi settings for reserveTokens, (d) verify provider key, (e) write report.
2. Read `~/.pi/agent/models.json` — extract ALL gpt-6-luna override entries (both `openai` and `openai-codex` namespaces) and their values.
3. Find and read the Pi compaction settings source — what is the `reserveTokens` default? Is it 16384 or a different value?
4. Determine which provider is ACTIVE for `gpt-6-luna` in the Pi runtime (look at provider composition code).
5. Compute: `compaction_fires_at = active_contextWindow - reserveTokens`.

## Key question
- Is `reserveTokens` = 16384 or different?
- Which provider key (`openai` or `openai-codex`) is actually consulted at runtime for `gpt-6-luna`?
- What is the ACTIVE `contextWindow` for `gpt-6-luna`?

## Report
Write to: `/home/hd2admin/kun-agent-workspace/data/brandon-pi-runtime-audit-20261002/agy-checker-report.md`
