# BR-ELEVATE-OPS-001 source and mock-test lookup

Sent 2026-09-23 11:58 UTC through the approved Brandon Compute to controller outbox.

The local warehouse records this lane as authorization-blocked for live/provider actions and permits local mock tests only. It names `agents-dashboard-source/backend/` but does not identify the repository root, exact adapter source, or test command.

Question: what exact owning source repository and current checkout path contain the adapter, and what build/test command validates its mock tests? Please confirm the permitted mock-only scope. No live credentials, provider API calls, production changes, or deployment are requested.

This is one bounded lookup. After answering, please continue your current controller work immediately; no follow-up is needed.
