# HETZ CAPACITY / POLICY AUDIT — CAPTAIN-ORDERED

ROUTE: Existing Hetz Firstmate `system-ops` responsibility; use the already-open idle Hetz Secondmate only if its local charter permits. Do not create a pane.

CAPTAIN: Crisp-R clarified that Crisp-R is the operator, not an agent name. This is a direct Captain task to Firstmate/Hetz.

OBJECTIVE: Reconcile Hetz's actual hardware capacity and its own parallel-dispatch policy with the Controller's separate 6/7 Herdr gate. The Captain says Hetz has materially greater capacity (roughly five times Controller) and must be treated as its own surface. Do not assume that estimate; verify it from Hetz's own measurements and canonical warehouse, then correct the Hetz-owned documentation so physical capacity, Firstmate dispatch cap, Herdr pane cap, provider quota, and Treehouse pool size are distinct.

KNOWN EVIDENCE TO RECHECK: Controller's live Herdr machine list shows `w2:p32` plus `w21:p2`–`w26:p2` idle. An older Brandon report says `config/parallel-dispatch-cap=6`; an older controller cap helper reports 6/7. These are software settings, not proof of Hetz's physical capacity. Captain explicitly says not to close/delete Hetz files or panes blindly.

TASK: Read Hetz's own warehouse README banner and authoritative `data/captain.md`, `AGENTS.md`, `data/secondmates.md`, `config/parallel-dispatch-cap`, cap helper/docs, Treehouse config, and current CPU/RAM/load/disk using Hetz's approved lean-ctx path. Compute a resource-backed, conservative parallelism recommendation including OS/runtime overhead and reserve. Use the To-Do List extension before first read and maintain five dependency-aware items: preflight/host identity; host measurements and cap-source inventory; resource calculation and gate mapping; bounded documentation correction with verified backup if facts justify it; validation/report/postflight.

WRITE BOUNDARY: Hetz-owned documentation only, limited to the canonical capacity/warehouse document and local Captain preference after inspect-then-update. Back up any file before editing and verify its exact backup and final bytes. Do not change runtime config, `parallel-dispatch-cap`, Herdr cap constants, cap hooks, Treehouse settings, model/credential routing, services, or any pane lifecycle in this audit. If a policy/code change is necessary to raise a limit, stop and return the exact proposed change, tests, and policy conflict for Captain review; do not bypass the installed hard gate. No deletion, cleanup, transfer, credentials, DNS, spending, or production work.

STOP CONDITION: If the existing Secondmate is outside scope or the approved lean-ctx route cannot read its own canonical files, report `NO_ELIGIBLE_WORK`/the exact blocker; no raw shell fallback and no new pane. Preserve all existing Hetz workspaces and files.

DELIVERABLE: Hetz-local `data/hetz-capacity-policy-audit-20261007/report.md` plus a response in `BRANDON-COMPUTE-COMMS/from-brandon-compute/hetz-capacity-policy-audit-20261007.md`, ending `VERDICT: PASS|FAIL <reason>`. Include hardware evidence, cap-source mapping, exact changes/backups if any, tests, and whether the global Herdr cap still blocks additional panes.

LANE_MODE: EXECUTE_BOUNDED_TASK
DISPATCH_PROVENANCE: CONTROLLER_BOUND_TASK
