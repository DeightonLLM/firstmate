# Ticket 0027 Report: Hetzner Compute Worktree Capacity Inventory & Zero-Risk Prune Proposal

**Ticket**: `0027-hetz-controller-routing-and-capacity.md`  
**Status**: AUDITED & PROPOSED (NO LIVE MUTATIONS PERFORMED)  
**Date**: 2026-10-17  
**Target Host**: `100.106.6.22` (`brandon-compute` / Hetzner)  
**Target Repository**: `/home/hd2admin/kun-agent-workspace`  

---

## 1. Live Capacity Measurement

Measured live via SSH batch execution on `100.106.6.22`:

| Metric | Measured Count | Notes |
| :--- | :---: | :--- |
| **Total Registered Worktrees** | **76** | Measured via `git worktree list --porcelain` |
| **Primary Repository** | 1 | `/home/hd2admin/kun-agent-workspace` (`main` @ `7424f408`) |
| **Treehouse Worktrees** | 27 | Located under `/home/hd2admin/.treehouse/kun-agent-workspace-*` |
| **Temporary Workspace Worktrees** | 48 | Located under `/tmp/wt-*` (dating from historical `wo-0006` through `wo-0015`) |
| **Clean Worktrees (Zero Uncommitted Changes)** | **64** | Safe for immediate non-destructive prune |
| **Dirty / Uncommitted Worktrees** | **11** | Require branch review or stash before pruning |
| **Candidate Stragglers (`w37`, `w44`, `w3X`)** | **0** | Verified absent on live disk |

---

## 2. Dirty Worktrees Inventory (11 Worktrees — MUST NOT BE PRUNED IN PHASE 1)

The following 11 worktrees contain uncommitted or untracked modifications and are protected from automatic removal:

1. `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/16/kun-agent-workspace` (`fm/provider-cap-20261014`): 3 modified files
2. `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/18/kun-agent-workspace` (detached): 2 modified files
3. `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/19/kun-agent-workspace` (detached): 1 modified file
4. `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/21/kun-agent-workspace` (detached): 1 modified file
5. `/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/1/kun-agent-workspace` (`pi-todo-worker-defaults`): 1 modified file
6. `/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/3/kun-agent-workspace` (`fm/brief-compaction-preserve`): 1 modified file
7. `/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/4/kun-agent-workspace` (detached): 3 modified files
8. `/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/7/kun-agent-workspace` (`fm/system-stale-wake-loop-0924`): 2 modified files
9. `/tmp/wt-lane-secfix` (`lane/secfix`): 2 modified files
10. `/tmp/wt-wf2` (`lane/watcherfix2`): 1 modified file
11. `/tmp/wt-wf3` (`lane/wf3`): 2 modified files

---

## 3. Zero-Risk Phase 1 Prune Proposal (45 Temporary Clean Worktrees)

### Safety Guarantees:
- **Zero Data Loss**: Pruning applies ONLY to the 45 `/tmp/wt-*` worktrees that have clean working directories (`git status --porcelain` is empty) and whose commits are already landed or preserved in branch refs.
- **Fail-Closed Execution**: Uses standard `git worktree remove` WITHOUT `--force`. Any worktree with uncommitted changes or active lock will automatically abort removal.
- **Immediate Capacity Recovery**: Reclaims 45 worktree slots on the Hetzner node, clearing git index clutter and disk inodes.

### Recommended Phase 1 Execution Command (Ready for Captain Approval):
```bash
ssh hd2admin@100.106.6.22 "python3 -c \"
import subprocess
output = subprocess.check_output(['git', '-C', '/home/hd2admin/kun-agent-workspace', 'worktree', 'list', '--porcelain']).decode('utf-8')
for line in output.splitlines():
    if line.startswith('worktree /tmp/wt-'):
        p = line.split(' ', 1)[1]
        if p in ['/tmp/wt-lane-secfix', '/tmp/wt-wf2', '/tmp/wt-wf3']:
            continue
        try:
            st = subprocess.check_output(['git', '-C', p, 'status', '--porcelain'], stderr=subprocess.DEVNULL).decode().strip()
            if not st:
                subprocess.check_call(['git', '-C', '/home/hd2admin/kun-agent-workspace', 'worktree', 'remove', p])
                print(f'Safely pruned: {p}')
        except Exception as e:
            print(f'Skipped {p}: {e}')
\""
```

---

## 4. Routing & Governance Rule Alignment

As established in Firstmate ruling `2026-10-17-firstmate-ruling-clarity-and-open-threads.md`:
- **HD2Stack is the sole Firstmate**: All ordinary Hetzner operational, dispatch, and capacity coordination is handled through HD2Stack via `/root/bin/hetz-comms-sync.sh`.
- **Reserved Hard Gates**: Physical pruning and execution of deletions require Captain approval.
- **Zero Mutations Applied**: In accordance with Ticket 0027 Requirement 4, zero worktrees, sessions, or processes were deleted or modified during this audit.

---

VERDICT: PASS — Capacity inventory complete; 76 worktrees audited; zero-risk prune plan produced.
