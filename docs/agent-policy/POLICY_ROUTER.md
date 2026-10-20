# Policy Router

Load only the modules whose trigger matches the current task. Do not preload the whole index.

| Trigger | Required module |
|---|---|
| Classifying whether text authorizes action | `INTENT_CLASSIFIER.md` |
| Producing a prompt, handoff, plan, runbook, or operator-facing report | `OUTPUT_CONTRACT.md` |
| Producing an execution prompt, multi-lane prompt, subagent plan, or browser-routed prompt | `PROMPT_ORCHESTRATION.md` |
| Cross-host work, delegation, agent spawning, or an actual handoff | `HANDOFFS_AND_LANES.md` and `docs/operations/HANDOFF_SOP.md` |
| Network, API, SSH, cPanel, DNS, or host access | `NETWORK_AND_ACCESS_FAILURE_POLICY.md` |
| SaaS, live-site, cPanel, deploy, or browser work | `SAAS_SAFETY.md` plus the specific SOP named there |
| Secrets, credentials, auth artifacts, quarantine, or security work | `SECRET_SECURITY.md` and `docs/operations/SECURITY_SOP.md` |
| VPS port allocation | `docs/operations/PORTS.md` |
| Live mutation or incident closeout | `DOCS_CLOSEOUT.md` |
| Context engineering, Lean-ctx setup, or repository mapping | `LEAN_CTX_MAPPING_STRATEGY.md` |

Rules:

- Read `/root/AGENTS.md` first, then select the minimum matching row set.
- Follow direct links one level deep only when the selected module explicitly requires them.
- Do not load unrelated product histories, roadmaps, closeouts, or the legacy snapshot.
- Search named task artifacts first. Broaden only when they are missing or contradicted.
- If multiple modules apply, merge their requirements into one execution or one deliverable; never expose policy fragmentation as operator workflow.
