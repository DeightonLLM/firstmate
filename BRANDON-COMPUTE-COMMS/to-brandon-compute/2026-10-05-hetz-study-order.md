# HETZ STUDY WORK ORDER (captain order 2026-10-05 — ready to dispatch; route pending)

OBJECTIVE: study the hetz situation end-to-end — what's there, what needs to be there, and
how the v3 PRD maps. Deliverable: gap report + remediation plan.

MODELS (captain-ordered): review/independent check = MiniMax M3.1 Flash Preview;
workhorse = Codex GPT-6 Luna at medium/high effort (your choice per subtask); subagents
allowed within your own surface rules.

INPUTS:
- v3 PRD: dubz:/root/agent-work/deightonllm-firstmate/docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md
  (+ PRD_TRACEABILITY.md, prd_traceability.yaml in the same dir — pull via the route when live).
- Queue guide: ~/kun-agent-workspace/controller-queue-guide.md (your side).
- Fleet context: NORTH STAR standard = docs/knowledge/STANDARD-SETUP-NORTHSTAR-20261005.md on dubz.

STUDY QUESTIONS:
1. What is actually on hetz right now (agents, treehouse instances, workspaces, versions, queues, stale processes)?
2. What SHOULD be there per the v3 PRD + fleet standard (roles, review model M3.1-preview, workhorse Luna med/high, subagent discipline, queue consumer)?
3. Gap list with severity + the smallest mechanical fix per gap.
4. PRD v3 status check: which PRD requirements are met / partial / missing on hetz.

RULES: read-only study (no service changes, no installs, no kills); evidence paths cited per
finding; end with VERDICT: PASS (study complete) + the gap table. Report back via the mirror
queue (.msg, format per controller-queue-guide.md) AND a workspace copy.

ROUTE BLOCKER (2026-10-05): mirror queue verified dead (test .msg unconsumed both ends —
see hd2stack:/root/agent-work/hetz-route-verify-20261005.md); no controller->hetzner ssh alias
exists. Dispatch fires the moment either is restored.

ROUTE (resolved): hetz = brandon-compute surface. This order dispatches via
BRANDON-COMPUTE-COMMS/to-brandon-compute + pane steer to w1E:p6. Review model MiniMax M3.1
Flash Preview, workhorse Codex Luna med/high, subagents allowed — all live on that surface.
