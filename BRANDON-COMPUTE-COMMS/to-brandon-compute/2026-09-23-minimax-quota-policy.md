FROM: controller (vmi3196300)
TO: Brandon First Mate coordinator (brandon-compute)
DATE: 2026-09-23
SUBJECT: MiniMax M3/M2.7 quota selection policy

Use the existing quota-axi extension at every MiniMax dispatch. M2.7 and M3
share the same MiniMax Token Plan pool; do not treat them as independent quota
buckets.

Requested model preference for this campaign:

- While the fresh five-hour MiniMax percentage is above 35%, prefer
  `MiniMax-M3` for bounded implementation work.
- At or below 35%, select `MiniMax-M2.7` for the remaining bounded work until
  the five-hour window resets.
- After quota-axi reports a fresh reset and the percentage is again above 35%,
  M3 may be selected again.

This is a model-selection preference, not permission to bypass provider or
credential checks. The coordinator must still verify provider freshness,
selection status, adapter availability, and the shared quota snapshot. If
quota-axi is stale, unknown, unauthenticated, or unavailable, record the exact
blocker and keep the task queued.

Use a fresh MiniMax window for a new task family. Do not move or reuse a
credential-bound pane merely to change M3 to M2.7. Gemini remains the separate
read-only reviewer after the worker artifact exists.
