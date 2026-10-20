ROUTE: Brandon Compute / Hetz Firstmate system-ops Secondmate | Existing host session only

ROLE: Host-local capacity and cap-policy audit with a bounded documentation sync.
HOST: `brandon-compute` / Hetz, `100.106.6.22`, in the existing Hetz Firstmate home.
OBJECTIVE: Reconcile the Captain's instruction that Hetz has substantially greater parallel capacity than the Controller with the host's own current warehouse, hardware, and enforcement settings. Correct the Hetz-owned documentation so physical capacity, Firstmate dispatch caps, Herdr pane caps, provider quota, and Treehouse worktree limits are not conflated.
OWNER: Captain Crisp-R; coordinator: Firstmate on Controller. Route through the existing Hetz Firstmate/system-ops responsibility; do not create a new pane.

COORDINATES: Captain says the Controller's 6/7 gate must not be treated as Hetz's physical/resource capacity and that Hetz should be the preferred parallel worker surface. Local evidence is stale and contradictory: controller mirror has a 6/7 Herdr cap; an older Brandon report says `config/parallel-dispatch-cap=6`; `treehouse.max_trees` is a separate pool limit. The live Brandon pane list shows the existing Hetz Secondmate and six idle child Secondmates; preserve all of them. First read the Hetz warehouse README banner and its own `data/captain.md`, `AGENTS.md`, `data/secondmates.md`, `config/parallel-dispatch-cap`, relevant Firstmate cap helpers, Herdr cap helper, Treehouse configuration, and current host hardware/load. Compute a resource-backed, host-local recommendation with explicit overhead/reserve; do not simply copy the Captain's approximate 5x estimate or the Controller's 6/7 gate.

TASK: Use the existing idle `system-ops` Secondmate/session only if its Hetz-local charter permits; otherwise report `NO_ELIGIBLE_WORK` and the exact routing blocker. Before any task read, create at least five checkable items in the visible To-Do List extension. Inventory CPU/RAM/load/disk and all distinct cap sources; show which setting gates which backend; cite exact paths, values, and commands; compare with the Controller without treating its cap as a hardware limit. Update only Hetz-owned documentation and the local Captain preference if the evidence confirms a missing or stale statement, with a verified backup and post-edit checks. Do not change runtime config, cap constants, helper code, Treehouse settings, or provider limits in this task. In particular, do not bypass the currently installed Herdr safety gate. If the documentation cannot be reconciled without changing that higher-level gate, state the exact conflict and proposed mechanical change for Captain review.

WRITE_BOUNDARY: Hetz-owned documentation only, limited to its local `data/captain.md` and the canonical Hetz capacity/warehouse document that the README designates. Report copy to the established `BRANDON-COMPUTE-COMMS/from-brandon-compute/` channel and local evidence path. No code/config changes, installs, service changes, credentials, DNS, spending, data deletion, asset transfer, or pane lifecycle action. Preserve all current Hetz files and panes.

MODEL/CREDENTIAL LANE: Use the existing Hetz system-ops Secondmate's configured runtime only; do not change model or credential. No credential refresh. If it cannot proceed without spawning a new pane or changing provider/model, stop and report the gate.
EVIDENCE_PATH: Hetz-owned `data/hetz-capacity-policy-audit-20261007/report.md`; controller reply in `BRANDON-COMPUTE-COMMS/from-brandon-compute/hetz-capacity-policy-audit-20261007.md`.
STOP_CONDITION: Stop if the canonical Hetz warehouse/charter cannot be read through its approved lean-ctx route, if the existing Secondmate is outside scope, or if the only route requires closing/restarting a session-affine pane or exceeding a hard gate. Never delete files or silently reap panes.

BROWSER_WORK: NO
MUTATION: Bounded documentation only, backup-first and evidence-backed; no enforcement/config changes.

Use the To-Do List extension before first action, with dependencies: (1) preflight/host identity; (2) hardware and cap-source inventory; (3) resource calculation and gate mapping; (4) documentation correction with verified backup if justified; (5) validation, report, and stop. Keep the list visible and update each phase. No filesystem TODO.

PROGRESSIVE_DISCLOSURE: Read Hetz authority docs and host measurements first; separate physical capacity from software gates; calculate sustainable parallelism; update only verified documentation; report exact blockers without spawning children.

LANE_MODE: EXECUTE_BOUNDED_TASK
DISPATCH_PROVENANCE: CONTROLLER_BOUND_TASK
