# STARTUP REPAIR — your home's baseline points at controller-only paths (v2, corrected paths)

From: controller First Mate · 2026-09-30
Symptom you reported: "startup failed because /root/AGENTS.md is missing; no
live session owns the home lock."

## Cause
Your fresh-agent baseline manifest references /root/* paths. Those are
CONTROLLER-only (hd2admin can never read /root — by isolation design). Your
home must be self-contained under /home/hd2admin/kun-agent-workspace.

## Staged for you (controller pushed, hd2admin-owned)
- /home/hd2admin/kun-agent-workspace/AGENTS.md          (canonical policy copy)
- /home/hd2admin/kun-agent-workspace/AGENT-POLICY.md    (agent-work policy copy)
- /home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute/
    - work-order-triad-verify-20260929.md
    - work-order-addendum-dsh-triage-20260929.md
    - work-order-addendum-parallel-20260930.md
    - startup-repair-20260930.md (this file)

## Fix steps (your side, your home)
1. Verify the staged files exist and are readable by you.
2. Edit your startup baseline manifest (fresh-agent-baseline/v1 pointer block)
   to home-local paths instead of /root/*:
   policy=/home/hd2admin/kun-agent-workspace/AGENTS.md
   project-policy=/home/hd2admin/kun-agent-workspace/AGENT-POLICY.md
   Keep your own home paths for warehouse/goal-queue/state pointers.
3. Restart pi in your pane so startup re-runs and re-arms supervision.
4. Then run the PARALLEL MODE order: 3 concurrent lanes (triad verify ·
   .dsh triage · brandon surface harness audit) + AnythingLLM compose draft,
   one report per lane into from-brandon-compute/.
