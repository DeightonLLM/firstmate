# Kun adoption gate

Status: **approved for isolated internal evaluation only - not approved for
production or customer-facing integration**.

## What was verified

The supplied DeightonLLM URL resolves to the current Kun project at
[`KunAgent/Kun`](https://github.com/KunAgent/Kun). Its documented concepts are
relevant to the warehouse design: a local agent runtime, append-only JSONL
thread/event/usage storage, cache-first execution, workspace project overlays,
MCP/Skills, and extension boundaries.

The useful ideas can be implemented as a First Mate adapter without making Kun
the source of truth. In particular, a workspace-local project overlay can
describe capabilities, while the controller still owns queue identity, leases,
credential affinity, and live-mutation approval.

## Hard gate

The repository currently declares a PolyForm Noncommercial license. It excludes
commercial use, hosted/SaaS use, resale, and integration into commercial
products without the applicable written permission/license. Therefore Kun code,
plugin, extension, or hosted runtime may be used only in a separately
marked internal test sandbox with synthetic or operator-owned non-client data,
no production credentials, no customer traffic, and no customer-facing
service. Nothing from that sandbox may be promoted into HD2.ai, client SaaS,
warehouse services, or production VPS workflows until the operator has
obtained and recorded a written commercial-use determination.

This gate is independent of technical quality. A fork does not remove the
license obligation.

## Plugin/extension gate

Do not mass-install Kun plugins. For each candidate, record a review manifest
containing:

- upstream URL, exact commit/tag, and content digest;
- license and redistribution status;
- files and runtime permissions;
- network destinations and credential requirements;
- whether it runs UI, background Node, agent tools, or a provider;
- test result, rollback path, and approved host scope.

Kun extensions can execute with the OS user's privileges and their signatures
are not a security audit. A provider may receive the complete model-visible
request. These are reasons to keep extensions opt-in, pinned, least-privilege,
and out of the production mirror until reviewed.

## Approved direction pending the hard gate

Build the warehouse contract in First Mate and/or a separate private GitHub
warehouse. Use Kun in the internal sandbox as an evaluation/reference runtime;
the client-facing implementation remains our own adapter and contract until
license, supply-chain, and compatibility gates pass. Agents should receive a
version-pinned, reviewed capability manifest and locally materialized tools;
they do not need identical optional plugins on every VPS.

Acceptance tests for any future adapter:

1. schema and content-addressed evidence validation;
2. secret scan and authenticated-URL redaction;
3. concurrent lease/ownership conflict rejection;
4. restart/replay idempotency;
5. model and credential-affinity preservation;
6. no propagation of warehouse merges into live mutations;
7. fresh-session and harness-parity verification on each host.
