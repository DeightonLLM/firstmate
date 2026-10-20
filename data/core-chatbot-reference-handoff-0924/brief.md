# Task
## Captain's intent
Prepare a source-grounded handoff for copying the working Core Distro chatbot experience to Elevate, while keeping all project sources unchanged until the production source and owner are established.

## Firstmate spec
In the registered Core project checkout `/home/hd2admin/agent-work/core-distro-saas-clean`, inspect the exact `current-core-distro/index.html` implementation and its adjacent styles/assets only as needed to identify the existing chatbot integration. The prior report locates the embed near line 246. Confirm the current branch and file lines yourself. Read the DubzAi AnythingLLM chatbot skill at `/home/hd2admin/.codex/skills/dubzai-anythingllm-chatbot/SKILL.md` as the operational reference.

This is a READ-ONLY scout. Do not edit Core, Elevate, or any project file; do not run build/tests; do not call admin APIs or read credentials; do not make live changes or deployments. Do not copy the Core workspace ID, embed ID, company text, or RAG content into a proposed Elevate snippet. Do not infer that Core's source checkout is the production deploy source.

Write `/home/hd2admin/kun-agent-workspace/data/core-chatbot-reference-handoff-0924/report.md` containing:
- Confirmed project root, branch/HEAD, file and line references for the current Core embed.
- Exact observed widget attributes and surrounding script/style needed to reproduce the layout, including whether mobile open-chat CSS is present and any `Powered by HD2.ai` sponsor attributes.
- Any logo assets used and the attribute names that reference them; do not copy Core brand images into Elevate recommendations.
- Source/evidence gaps that prevent direct implementation: production source/deploy owner, live AnythingLLM runtime/workspace and prompt configuration, and Elevate-specific identity/assets/workspace values.
- A short proposed adaptation checklist that keeps Elevate identity separate and calls out any required runtime owner decisions. Treat this as a handoff, not implementation approval.

Use a single live Pi `todo` checklist. Print its entire list in the pane at task start and update that same checklist in place at milestones, with exactly one active step. Print a short progress note before a long read or any child review. Use `lean-ctx` for routine reads if available; preserve raw output for exact source lines. No child is needed for this narrow extraction; Firstmate/Codex performs final review. Append only phase-change and terminal status events.
