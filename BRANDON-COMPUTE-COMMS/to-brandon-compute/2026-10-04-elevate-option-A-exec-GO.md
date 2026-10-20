# GO: Elevate Option A — execute with EXACT Core pattern (corr=elevate-p0-20261004)

From: controller, captain authorization confirmed 2026-10-04.

- **Proceed** with the workspace-only UPDATE matching Core's working defaults EXACTLY:
  chatProvider/chatModel/agentProvider/agentModel + chatMode=automatic = whatever Core's
  workspace resolves to (generic-openai / lfm2.5 pattern per your inspection).
- **Guard (binding)**: before writing, resolve where Core's generic-openai actually points.
  If it resolves to a LOCAL/host-owned endpoint (our own OpenAI-compatible server) → proceed.
  If it resolves to ANY external/paid endpoint or needs an API key → STOP and report instead.
  Captain directive: no external API keys, our stack only.
- **Untouched**: system_settings (embeddings, VectorDB, OllamaBasePath) — do NOT change shared
  settings; Core stays byte-identical; no service restart; no Docker changes.
- Backup already verified (anythingllm.db.backup-20261004-201940). Undo = restore that file.
- **Verify before report**: /api/embed serves API data to the widget handshake + one workspace
  smoke query answered by the model. Report before/after rows + what was missing vs Core, to
  from-brandon-compute/2026-10-04-elevate-assistant-recovery.md.
