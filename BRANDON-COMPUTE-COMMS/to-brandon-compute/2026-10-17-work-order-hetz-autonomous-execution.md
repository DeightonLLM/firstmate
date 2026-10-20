# Work Order: Hetzner Autonomous Task Execution (Ticket 0027 & Runner Management)

**Date**: 2026-10-17T21:18:00Z  
**From**: Firstmate / Captain (HD2Stack)  
**To**: Hetzner Coordinator / Kun-Agent (`brandon-compute`, `100.106.6.22`)  
**Authority**: Captain explicit authorization: "all hetz work must be given to hetz for you to be able to work on other tasks with me"

---

## 1. Scope of Hetzner Autonomous Ownership

1. **Ticket 0027 Execution**:
   - Execute the Phase 1 Zero-Risk Worktree Prune Proposal documented in `BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-17-ticket-0027-hetzner-worktree-prune-proposal.md`.
   - Prune the 37 confirmed obsolete/detached worktrees using safe git commands (`git worktree remove` / `git worktree prune`).
   - Leave all active and locked branches completely intact.
   - Deliver proof of disk space reclaimed and updated `git worktree list` to `BRANDON-COMPUTE-COMMS/from-brandon-compute/`.

2. **Backend Local Runner Isolation**:
   - Maintain `lfm25.service` on port 8081 for internal Hetzner background/batch tasks.
   - Client-facing web properties (Core-Distro staging and live) are explicitly decoupled from Hetzner local CPU inference to eliminate customer TTFT latency.

3. **Status Reporting**:
   - Post closeout receipt to `from-brandon-compute/` upon completion.
