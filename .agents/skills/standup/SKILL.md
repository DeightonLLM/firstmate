---
name: standup
description: >-
  Conducts a synchronous or asynchronous fleet standup across active subagents,
  Herdr panes, and comms inboxes. Gathers current task status, active blockers,
  and interrogates agents for possible off-track thinking, scope drift, or ungrounded
  assumptions. Use when the user types /standup or asks for a standup, status check,
  blocker sweep, or drift review.
---

# Fleet Standup & Drift Guard Skill (/standup)

This skill coordinates and executes a fast, structured standup across all active subagents, Herdr panes, and cross-node communication channels (HD2Stack, Controller, and Hetzner Brandon Compute).

## Purpose & Core Pillars

Every standup enforces four mandatory pillars:
1. **Task & Coordinates**: Exact bounded ticket and repository/host coordinate.
2. **Current Progress**: What was just measured or landed with real command output.
3. **Blockers & Dependencies**: Technical, quota, lock, or approval blockers.
4. **Off-Track Thinking / Drift Guard**: Detection of scope expansion, ungrounded assumptions, reference-site confusion (e.g. treating Music Metrics as a product target rather than reference), or unapproved mutations.

---

## Execution Workflow

### Step 1: Sweep Active Subagents & Panes
1. Run `/root/bin/fleet-standup.sh` to capture live Herdr panes and recent comms.
2. Query active subagents via the subagent management tool (`manage_subagents` action: `list`).

### Step 2: Inbound Comms & ATO Audit
Check `/root/agent-work/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/`:
- Identify any pending **ATOs (Ask The Oracle)** or unanswered work orders.
- Check for incoming priority or blocker escalation files within the last 2 hours.

### Step 3: Standup Inquiry Template
When querying active worker subagents, send the standardized standup inquiry:
```text
STANDUP CHECK-IN:
1. [COORDINATES] Exact task, host, and working directory.
2. [PROGRESS] What was completed in the last turn? Include evidence artifact path.
3. [BLOCKERS] Any technical blockers, resource limits, or missing inputs?
4. [DRIFT CHECK] Confirm zero scope expansion, zero destructive actions, and that all reference architectures (e.g. Music Metrics) remain reference-only.
```

### Step 4: Standup Board Output
Compile all findings into a concise, readable Standup Board adhering to the left-hand metadata standard:

```markdown
### Fleet Standup Board (<Timestamp>)

| Agent / Lane | Host | Current Task / Coordinates | Status | Blockers | Drift Guard |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `[M3.1F m @ Hetz]` Second Mate | Hetzner | Ticket 0027 Worktree Audit | IDLE | None | PASS (Clean) |
| `[Pi M3.1 @ HD2]` Second Mate | HD2Stack | Herdr Pane wK:p18 | IDLE | None | PASS (Clean) |
| `[GLM 5.3 @ HD2]` Reviewer | HD2Stack | Review Gate | IDLE | None | PASS (Clean) |

#### Unanswered ATOs / Inbound Comms:
- `ato-hd2-delegation-prelaunch-20261018`: Brandon First Mate requesting child-lifecycle reservation guidance.
- `core-saas-reviewed-record-20261018`: Core SaaS definitive baseline & rubric alignment.
```
