# Captain Decision — Controller Watcher TDD

**Decision: Option 1 approved.** Extend the existing identity-, home-, and watcher-path-checked stale-owner recovery into the `--restart` pre-start path used by the Pi and OpenCode callers.

This approval is limited to the exact stale watcher owner when its lock identity matches this Firstmate home and watcher path and its heartbeat is stale. Preserve the exactly-one-cycle invariant; do not clear a live valid owner, signal unrelated processes, or broaden cleanup beyond this recovery path.

This is required to close the accepted recurring watcher-recovery defect; shipping only the direct-child case leaves the actual `--restart` path vulnerable. Continue through the same parked no-mistakes run using its supported decision-response flow. Do not merge. The task's required PR validation must still be satisfied before reporting completion; skipped push/PR/CI stages are not a green PR outcome.
