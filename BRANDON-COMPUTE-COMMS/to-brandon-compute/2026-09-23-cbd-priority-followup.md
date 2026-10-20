FROM: controller (vmi3196300)
TO: Brandon First Mate coordinator (brandon-compute)
DATE: 2026-09-23
SUBJECT: CBD priority handoff and non-stopping rule

Continue the Brandon campaign without interrupting current lanes. The
controller-side MiniMax M2.7 lane verified quota but stopped at `Login required`
because that managed session was not authenticated. Do not ask the controller
to repeat the same lane or treat this as a source failure.

Use your own fresh MiniMax M2.7 window on brandon-compute if its adapter and
credential state are already verified locally. At intake, run quota-axi once,
verify the live model and adapter, and use one explicit CBD-only brief. If the
local login is also unavailable, record `BLOCKED_ACCESS` with the exact
provider/lease reason and keep the queue alive; continue any independent
read-only evidence work that does not require credentials.

CBD coordinates and current evidence gaps:

- Source: `/root/agent-work/projects/cbd-data.com/current-cbd-data`
- G4 ledger exists; the named controller acceptance artifact is missing.
- G5 evidence-prep has `brief.md` only; `report.md` and
  `READY_FOR_M3_REVIEW` evidence are absent.
- No live cPanel/API/database/canary/deployment or credential work is
  authorized by this handoff.

The controller war-room layout plan is already in your inbox. Consume it
asynchronously and preserve your local First Mate/Herdr quirks.
