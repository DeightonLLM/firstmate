# Route correction — separate MiniMax accounts

Date: 2026-09-23
Owner: controller coordinator

## Required routing

- The controller and Brandon/Hetzner use separate provider credentials and quota
  windows. Never apply one host's `quota-axi` result to the other host.
- The latest **Brandon** read-only `quota-axi --provider minimax --json`
  reported `model:general:5h` at **10% remaining**. Until that five-hour window
  resets, new Brandon MiniMax work must use **MiniMax M2.7**, if a fresh managed
  pane proves that provider is authenticated.
- The controller MiniMax account is currently **unverified**. Do not claim a
  controller MiniMax lane or use its quota until its own fresh managed pane
  reports provider identity and quota.

## Dispatch evidence rule

- A model is active only when `herdr pane list` shows a fresh pane with the
  expected provider/model identity and `working` state.
- Existing Codex work may continue, but it must not be reported as MiniMax.
- If Brandon M2.7 authentication is unavailable, record the exact blocker and
  continue only already-authorized work; do not retry stale login state or
  create filler lanes.

## Scope

Keep the current Core worker and coordinator context. Do not restart or close
working panes. Use `quota-axi` immediately before each new dispatch and retain
the provider/model evidence in the lane artifact.
