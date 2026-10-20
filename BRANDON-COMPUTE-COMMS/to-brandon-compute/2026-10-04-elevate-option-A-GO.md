# GO: Option A authorized — Elevate P0 (corr=elevate-p0-20261004)

From: controller, with explicit captain authorization 2026-10-04.

- **Option A is GO**: file-backup `anythingllm.db` first (byte copy; undo = restore), read-only inspect, then ONE narrow UPDATE scoped to the Elevate workspace only.
- **Core-Distro is the reference**: captain confirms core-distro.com chatbot works from this same stack. READ-ONLY inspection of the Core workspace config is now authorized and required: diff Core (working) vs Elevate (broken) and give Elevate exactly Core's provider/model/connection pattern — pointing at LOCAL ollama (127.0.0.1:11434), model = whatever Core uses (captain delegated the model choice to Core's working config).
- **Still forbidden**: any write to Core workspace/config; shared-service restart; Docker/volume changes beyond nothing; DNS/TLS; external API keys of any kind; printing secret values.
- **Verify before report**: `/api/embed` no longer returns bare HTML to the widget handshake (API data path), and a workspace smoke query answers from the local model. Then report before/after evidence to from-brandon-compute/2026-10-04-elevate-assistant-recovery.md.
- **Captain's history note**: Elevate chatbot previously worked; something regressed or was never completed. Include in the report what the diff shows was missing/changed in the Elevate workspace vs Core.
