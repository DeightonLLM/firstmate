# HD2 Agent Warehouse Contract

This directory defines the versioned contract for a GitHub-backed projection of
First Mate work. It is a durable memory and provenance layer, not the live
queue, a credential store, or a shared mutable database.

## Recommended topology

Keep the First Mate source, policy, and automation in their existing code
repository. Keep operational warehouse projections in a separate **private**
GitHub repository when they may contain client names, host names, run history,
or internal decisions. A public code repository must contain only sanitized
contracts, fixtures, and documentation.

Each VPS materializes the pinned policy/skill/plugin manifest locally. Agents do
not need every optional plugin installed. They need the same approved manifest,
the required local adapter, and scoped connector pointers. Credentials,
authenticated URLs, raw chats, live session state, and tenant records remain in
their existing private stores and are never copied into GitHub.

Kun is an evaluation input, not an approved dependency. Its project overlay
and append-only event ideas are useful for isolated internal testing, but
adoption is gated by
[`KUN-ADOPTION-GATE.md`](KUN-ADOPTION-GATE.md), including license and supply
chain review.

The time and provider handoff policy is owned by
[`PROVIDER-ROUTING.md`](PROVIDER-ROUTING.md).

## Source-of-truth hierarchy

1. The controller-registered queue and run manifest own task identity.
2. A lease owns a task's host, pane/session, model/credential affinity, and
   write boundary.
3. A task branch and pull request own proposed warehouse changes.
4. Immutable evidence manifests own the digest and location of outputs.
5. GitHub is the durable, reviewable projection of those records after commit.

GitHub must not be treated as the live lock service. Before a worker writes, it
must hold the canonical lease. A task may write only its own branch and
namespace. Replays are safe because records are keyed by stable IDs and writes
are upserts or content-addressed files; no worker may update another worker's
rows, branch, or evidence.

## Record rules

- Every run has one stable `run_id` and a source queue reference.
- Every task has one stable `task_id`, `run_id`, host, owner, lease, and explicit
  write boundary.
- Evidence is immutable after publication and is referenced by digest.
- Decisions cite an evidence or review reference and an authority.
- Raw prompts, raw chats, secrets, tokens, credential material, and
  authenticated connector URLs are excluded. Store only redacted summaries and
  pointers.
- Timestamps are UTC ISO-8601. IDs are lowercase, stable, and collision-safe.
- A task branch/PR is the normal promotion path. Direct writes to the default
  branch are reserved for approved documentation-only changes.

See [`schema.md`](schema.md) for the minimum record shape.

## Mirroring policy

The mirror is layered, not a blind filesystem clone:

- **Policy layer:** pinned `AGENTS.md` and required SOP/routing documents.
- **Capability layer:** reviewed skills, extension manifests, MCP connector
  declarations, and runtime compatibility metadata.
- **Execution layer:** local sessions, leases, queue state, and host-specific
  adapters.
- **Evidence layer:** sanitized reports, digests, checker verdicts, and PR
  links.

Only the first, second, and sanitized fourth layers may be projected to a
warehouse. The execution layer stays local or in an explicitly private control
plane. A new VPS must pass the read-only parity gate before receiving a task;
`HARNESS_MISMATCH` is fail-closed.

## Promotion gates

1. Pin the source commit and license for every imported skill, extension, or
   adapter.
2. Run secret scanning and a permission/network/runtime review.
3. Validate schema, IDs, lease ownership, replay/idempotency, and redaction.
4. Test on the lowest-risk compute target first (currently Brandon, subject to
   a fresh connectivity and harness receipt).
5. Use a reviewed PR to promote the projection.
6. Coordinate production/live mutations separately; a warehouse merge never
   authorizes a live change.

The Amino lane remains blocked until its existing `HARNESS_MISMATCH` is
resolved and independently checked. Controller, HD2, and Hostinger remain
capacity-gated according to the current resource policy.

## Projections

- [AnythingLLM sanitized control-plane projection](anythingllm/README.md)
