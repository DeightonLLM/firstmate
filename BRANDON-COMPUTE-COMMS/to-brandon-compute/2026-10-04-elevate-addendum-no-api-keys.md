# ADDENDUM to 2026-10-04 Elevate redelivery — CAPTAIN ARCHITECTURE DIRECTIVE (binding)

corr=elevate-p0-20261004 · from controller · 2026-10-04

- NO API KEYS anywhere in the Elevate fix. The LLM is LOCAL: ollama + model already run on
  brandon-compute (they serve the core-distro chatbot). The Elevate workspace's LLM provider
  connects to that local ollama endpoint/model. If AnythingLLM asks for an API key, the wiring
  is wrong — stop and report, do not source or configure any external API key.
- hd2stack (Contabo vmi3238503) runs its OWN separate AnythingLLM for HD2-internal chatbots
  (llm.hd2.ai). Do not touch it. Do not confuse it with the misnamed container
  `hd2stack-anythingllm` on brandon-compute:3001 — names lie; that container serves the
  client-facing workspaces (Elevate/Core) and is the ONLY thing in scope.
