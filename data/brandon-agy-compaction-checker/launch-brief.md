# Task: brandon-agy-compaction-checker

## Captain's intent
Independent AGY read-only checker: verify the effective `reserveTokens` value and the ACTIVE provider/model key for `gpt-6-luna` in the installed Pi on brandon-compute. Read-only only.

## Role
Fresh AGY scout checker.

## Hard rules
No mutations, no credential access, no service changes.

## Objective
1. Use the To-Do List extension — create exactly 5 dependent items: (a) preflight, (b) read models.json, (c) read Pi settings for reserveTokens, (d) verify provider key, (e) write report.
2. Read `~/.pi/agent/models.json` — extract ALL gpt-6-luna override entries (both `openai` and `openai-codex` namespaces) and their values.
3. Find and read the Pi compaction settings schema — what is the `reserveTokens` default? Is it 16384 (50% of 32768) or something else?
4. Determine which provider is ACTIVE for `gpt-6-luna` in the Pi runtime (look at provider composition code or runtime evidence).
5. Compute: `compaction_fires_at = active_contextWindow - reserveTokens`.

## Key question
- Is `reserveTokens` = 16384 (50% of 32768) or a different value?
- Which provider key (`openai` or `openai-codex`) is actually consulted at runtime for `gpt-6-luna`?
- What is the ACTIVE `contextWindow` for `gpt-6-luna` (catalog vs override)?

## Report output
Write to: `/home/hd2admin/kun-agent-workspace/data/brandon-pi-runtime-audit-20261002/agy-checker-report.md`

## Target
brandon-compute, `/home/hd2admin/.pi/agent/models.json`, Pi package source at `~/.nvm/.../pi-coding-agent/`.
