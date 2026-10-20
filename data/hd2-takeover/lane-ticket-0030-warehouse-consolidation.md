✅ NO BROWSER WORK — SAFE FOR GEMINI
ROLE: Documentation and Warehouse Consolidation Worker
HOST: hd2stack (vmi3238503)
OWNER: First Mate Coordinator
EXECUTOR: MiniMax M2.7 (highspeed)
HANDOFF: Second Mate Supervisor
MUTATION: Propose warehouse structure and write report artifact
BROWSER_WORK: NO
MODEL_CREDENTIAL_LANE: minimax / MiniMax-M2.7-highspeed
OBJECTIVE: Inventory and organize loose warehouse documents by app and platform domain per Ticket 0030
TARGET_BOUNDARY: /root/agent-work/deightonllm-firstmate/warehouse/
WRITE_BOUNDARY: Only generate proposed manifest and indexes in report artifact. Denials: AGENTS.md, protected M3, credentials, Herdr pane state, client application code, databases, Docker, production services.
EVIDENCE_PATH: /root/agent-work/deightonllm-firstmate/data/hd2-takeover/report-ticket-0030-warehouse-consolidation.md
STOP_CONDITION: Complete 1-to-1 manifest generated, contradictions cataloged, zero files moved or deleted, report ended with VERDICT: PASS
LANE_MODE: BOUNDED_WORKER
DISPATCH_PROVENANCE: Operator Ticket 0030 Captain Authorized
PROGRESSIVE_DISCLOSURE: warehouse/routing/DOMAIN-ROUTING.md, INBOX/0030-consolidate-warehouse-docs-by-domain.md, warehouse/README.md

Use the To-Do List extension to create and update a 5-step task breakdown before starting work.
Use lean-ctx for every read, search, listing, and shell command under /root.

Task Scope:
Execute Ticket 0030 (INBOX/0030-consolidate-warehouse-docs-by-domain.md).
1. Inventory all loose and misfiled documentation in /root/agent-work/deightonllm-firstmate/warehouse/ (reports, recovery, chatbots, policies, access, sources, root level).
2. Propose a domain-structured layout under warehouse/apps/<domain>/ for client domains and warehouse/platform/<area>/ for shared infra.
3. Align owner naming with warehouse/routing/DOMAIN-ROUTING.md.
4. MOVES ARE PROPOSALS ONLY — do not move, rename, delete, or overwrite any files in this pass.
5. Catalog any contradictions where documents assert conflicting facts about the same domain.
6. Deliver evidence report to EVIDENCE_PATH ending with exact line:
VERDICT: PASS
