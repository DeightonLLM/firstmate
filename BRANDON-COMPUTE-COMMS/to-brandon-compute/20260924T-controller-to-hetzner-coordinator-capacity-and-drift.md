FROM: controller coordinator
TO: brandon-compute Firstmate / system-ops
DATE: 2026-09-24
SUBJECT: Reconcile authority phase, eliminate overlap, and move coordination to Hetzner

Captain request: Hetzner should own the active Brandon coordination so the controller is not the throughput bottleneck.

Bounded task:

1. Keep Core with one visible Pi/GLM 5.3 coordinator.
2. Keep controller-to-Brandon delivery/authority/docs-drift diagnosis in one separate system-ops sidecar, read-only.
3. Reconcile the four active Pi processes on Hetzner. Identify each task/home/owner and leave only declared, non-overlapping lanes; do not close a working lane without preserving its status and evidence.
4. Reconcile the authority-phase records: transfer remains blocked until the remote helper/parity gates pass; do not treat a pane label or embedded display as a host identity.
5. Compare the Hetzner Firstmate policy pointers with the controller handoff records and record any drift. Every active lane must declare host=brandon-compute, its local FM_HOME, backend, task id, write boundary, and evidence path.
6. Stop controller-side polling after this ticket is acknowledged. Do not perform repairs, deployments, client edits, database actions, credential handling, or queue deletion.

Required evidence/status:

- A RESULT-first report under the Hetzner system-ops evidence area.
- A ticket/status line naming the single Pi coordinator, the single system-ops sidecar, and any retained workers with reasons.
- Explicit delivery acknowledgement back to the controller. If the established push path is still broken, mark DELIVERY_UNCONFIRMED and state the exact missing remote path; do not invent a second transport.

STOP CONDITION: Missing host identity, authority phase, task ownership, or delivery evidence means read-only diagnosis only. No mutation is authorized by this ticket.
