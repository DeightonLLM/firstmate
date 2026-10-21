# Provider routing policy

This document owns the provider schedule and quota-routing policy for AFK work.
The executable calendar gate is [`bin/fm-provider-window.sh`](../../bin/fm-provider-window.sh);
the one-snapshot decision gate is [`bin/fm-provider-route.sh`](../../bin/fm-provider-route.sh);
the bounded read-only observation helper is
[`bin/fm-provider-route-watch.sh`](../../bin/fm-provider-route-watch.sh).
Quota-axi remains the data-only source for live quota, authentication, model
support, and runway.

First Mate is the execution coordinator. The route label `agy` means the
verified AGY provider for Gemini 3.8 Flash Medium (model id
`gemini-3.8-flash-medium`); it is not a pane identity and may not be inferred
from a terminal title, harness, or stale model label. A caller must still
provide a separately verified AGY adapter before spawning.

## Per-provider quota scope

`bin/fm-provider-route.sh` resolves the per-provider
`quotaSemantics.effectiveAvailability` entry by a scope token that quota-axi
publishes per vendor. The mapping is deliberately small and explicit:

| Provider key | Quota scope token | Notes |
|---|---|---|
| `agy` | `gemini` | AGY publishes AGY's effective availability under its own `gemini` scope token, not the generic `all_models` token that legacy fixtures used. |
| `zai` (GLM) | `all_models` | Continues to use the legacy `all_models` scope. |
| `codex` | `all_models` | Continues to use the legacy `all_models` scope. |
| `minimax` (M3 / M3.1 Flash Preview) | `all_models` | See "MiniMax M3 quota semantics" below; absence is not eligibility. |
| anything else | `all_models` | Predictable no-match → existing `provider_missing` / `quota_unproven` decision. |

The mapping is owned by `provider_scope()` in the route script and exercised
end-to-end by `tests/fm-provider-route.test.sh`. Adding a new provider or
changing a scope requires updating that helper and its fixtures in the same
patch.

## Prohibited Providers and Endpoints

### OpenRouter Endpoints (Operator Policy 2026-10-17)

OpenRouter (`openrouter.ai`, `openrouter/*`, or any models proxied through OpenRouter) is **strictly prohibited across all internal and client infrastructure**. 
- Never configure, route, or execute tasks via OpenRouter endpoints.
- All requests must use direct first-party vendor credentials (`zai` direct, `minimax` direct, Google Gemini via AGY, OpenAI direct).
- OpenRouter API keys, model aliases (`openai/*` through OpenRouter), and proxy routes are banned in all environments, scripts, and agent settings.

## Published vendor facts

Z.AI currently lists GLM-5.3 and GLM-5.3-Flash in the Coding Plan. Its
individual plan credits are Lite 2,000 per five hours and 10,000 weekly, Pro
12,000 per five hours and 60,000 weekly, and Max 28,000 per five hours and
140,000 weekly.

Z.AI states that off-peak model usage is charged at 50% of the standard credit
rate and defines weekday peak as 14:00-18:00 Singapore Standard Time (UTC+8).
That is 07:00-11:00 UK local time during British Summer Time and 06:00-10:00
during Greenwich Mean Time.

Z.AI also publishes a temporary GLM-5.3-Flash campaign from 23:00-09:00
Singapore time on 2026-09-03 through 2026-09-20. The campaign is tool-specific
and is not used as a general routing assumption; the calendar gate therefore
continues to apply the normal schedule.

MiniMax currently documents Token Plan usage as a shared usage bar with a
five-hour rolling window and a weekly window. M3 and M3.1 Flash Preview usage therefore must
not be modeled as independent pools, and the console usage bar is the quota
source of truth.

MiniMax documents weekday peak traffic as typically 15:00-17:30 but does not
state a timezone on the current FAQ. The calendar gate uses Asia/Singapore as a
provisional UTC+8 interpretation and reports that uncertainty on every result.
If the vendor publishes a timezone or the operator records a different
approved source timezone, update the gate and its tests together.

Sources: [Z.AI Coding Plan overview](https://docs.z.ai/devpack/overview), [Z.AI Flash campaign notice](https://docs.z.ai/devpack/notice/event-glm-5.3-flash), and [MiniMax Token Plan FAQ](https://platform.minimax.io/docs/token-plan/faq).

## MiniMax M3 quota semantics

`bin/fm-provider-route.sh` decides MiniMax eligibility purely from quota-axi's
fresh, in-process snapshot. Quota-axi proves five things about MiniMax in this
exact order:

1. the provider entry exists at all,
2. its `state.status` is `fresh`,
3. its `state.stale` is `false`,
4. its `quotaSemantics.status` is `known`, and
5. its `quotaSemantics.effectiveAvailability` for the matching scope token
   reports a positive numeric `effectivePercentRemaining` with
   `selection.status == known`.

Missing the entry surfaces `provider_missing`; a non-`fresh` state surfaces
`provider_<state>`; `stale: true` surfaces `provider_stale_true`; an unknown or
unmeasurable semantics surface `quota_semantics_unknown` / `quota_unproven`; a
non-positive percent surfaces `quota_exhausted`; an unknown selection surfaces
`selection_unproven`. None of these is silently converted into a healthy
eligibility verdict.

Quota-axi cannot prove the MiniMax vendor runtime itself is reachable, that an
M3 adapter is loaded, that a credential path is healthy end-to-end, or that a
Hetzner/Hostinger/MiniMax console session has not been re-authenticated out of
band. The route treats the absent entry as `provider_missing` and surfaces the
reviewer's `REVIEW_REASON=minimax_quota_unproven` decision; a coordinator that
needs the vendor runtime *itself* to be live must do that as a separate,
explicit verification against the Hetzner / MiniMax console adapter — not via
the route snapshot.

The MiniMax runtime can recover out of band (operator session re-auth,
provider quota restore) between two route snapshots that look identical. The
route does not detect that recovery itself; a safe-handoff observer such as
`fm-provider-route-watch.sh` only marks *the next handoff* as eligible once a
fresh quota-axi snapshot itself reports it. Live M3 vendor recovery remains a
separately authored check.

### Model vs CLI adapter distinction

MiniMax M3.1 Flash Preview and M3 are model designations; `mcode` is the MiniMax Code CLI
execution adapter. Quota and schedule eligibility do not imply that `mcode` is
installed in PATH or authenticated. Runtime availability, adapter presence,
authentication/quota, and environment capabilities must still be verified
independently before dispatch.

## Selection procedure

1. At intake, run `bin/fm-provider-route.sh` once. It reads one
   quota-axi snapshot (global executable preferred, bounded `npx -y quota-axi`
   fallback otherwise) and uses that same snapshot for every candidate; it
   passes `--no-credential-refresh --json`, never refreshes credentials, and
   never prints raw vendor output. Per-provider scope is resolved by
   `provider_scope()`; see "Per-provider quota scope" above.
2. The requested primary is Gemini 3.8 Flash Medium via AGY
   (`PRIMARY_PROVIDER=agy`, `PRIMARY_MODEL=gemini-3.8-flash-medium`). The route
   is ready only when AGY is fresh, its effective `gemini`-scoped availability
   and selection are known and positive, and its calendar result is allowed.
3. Outside MiniMax's provisional weekday peak, choose MiniMax M3 as reviewer
   when its shared quota is fresh, known, positive, and schedule-allowed.
4. During MiniMax peak, or when M3 quota/selection cannot be proven, choose the
   eligible Codex reviewer. The route records whether that choice was caused by
   peak timing or missing quota evidence (`REVIEW_REASON=minimax_peak` vs
   `minimax_quota_unproven`).
5. GLM-5.3-Flash schedule facts remain available for a future explicitly
   authorized candidate; the current Gemini-primary policy never silently uses
   GLM during the published Singapore peak window.
6. Missing, stale, duplicated, exhausted, or unmeasurable provider data blocks
   the decision; it is never converted into a healthy or exhausted guess. The
   absence of a MiniMax entry surfaces `MINIMAX_QUOTA_STATUS=provider_missing`
   and a `REVIEW_REASON=minimax_quota_unproven` decision; a working task that
   started against MiniMax keeps its run ID and lease, never silently re-routed.
7. The route command emits a decision only. It does not spawn a pane, move a
   queue item, change a lease, or authorize a provider fallback. A caller must
   verify the adapter, run/lease ownership, host boundary, and task fit before
   spawning.

The calendar helper is a transparent time gate, not a score. The route helper
is the deterministic policy layer around it and around quota-axi's data. The
existing quota-array procedure remains responsible for any richer candidate
fit or reasoning comparison outside this fixed AFK route.

The legacy `fm-always-four.sh` scheduler still requires an explicit verified
adapter before any queue movement or pane mutation; route output must not be
used to bypass that adapter check.

## Safe-handoff observer (read-only)

`bin/fm-provider-route-watch.sh` is a bounded read-only helper that records
the sanitized state of the most recent route decision into a caller-supplied
state directory. It exists so the next safe handoff can read a deterministic
"route changed since the last observation" signal without the active run
being auto-rerouted and without the supervisor daemon being broadened.

The helper is **deliberately not** wired into `bin/fm-supervise-daemon.sh`.
Wiring it into the supervisor loop would change the daemon's narrow
classification contract (currently it is per-task / per-window, not
per-policy-route) and would have no deterministic seam against the daemon's
test surface. Instead, the helper is invoked explicitly at a handoff
checkpoint by the coordinator, the operator, or another named tool.

For autonomous AFK observation, the helper is invoked by
`bin/fm-provider-route-supervise.sh` (see "AFK supervisor integration" below)
on a bounded cadence so the captain does not need to be present for the next
safe handoff to have a recent observation. That integration preserves the
explicit-call contract: the helper remains a passive recorder, never an
auto-reroute, and a working task keeps its provider, source-of-truth run ID,
and lease until an explicitly verified safe handoff.

Per invocation the helper:

1. reads `bin/fm-provider-route.sh --at <now>` exactly once, with the route
   getting its quota snapshot from `--quota-file` (or
   `FM_PROVIDER_ROUTE_QUOTA_FILE`); the helper never calls quota-axi, never
   refreshes credentials, never starts a process, and never mutates a queue or
   a lease;
2. extracts a closed allow-list of sanitized keys (route policy, route status,
   primary/review provider+model, all `*_QUOTA_STATUS` and `*_SCHEDULE_*`
   fields, and any `BLOCK_REASON`); raw quota JSON, secret headers, and tokens
   are never written;
3. computes a sha256 fingerprint over the alphabetically-sorted
   `key=value` pairs;
4. compares the new fingerprint to the prior fingerprint at
   `<state-dir>/.provider-route-watch.fingerprint`;
5. writes one of the following signals to
   `<state-dir>/.provider-route-watch.signal`:
   - `NO_PRIOR` — first observation; nothing to compare against;
   - `NO_CHANGE` — fingerprint identical to prior; the consumer can
     short-circuit the handoff logic;
   - `HANDOFF_PENDING` — route ready AND fingerprint changed; the consumer
     may adopt the new route at the next safe handoff;
   - `DEFER_ACTIVE_RUN` — route blocked OR fingerprint changed to blocked;
     the consumer must keep the active run on its current provider/lease
     until a safe handoff; and
6. writes the sanitized `key=value` list to
   `<state-dir>/.provider-route-watch.last-output` for audit. The consumer
   reads these files at its own discretion; nothing the helper does is a
   decision driver.

The integration boundary is therefore: the helper is a passive recorder, the
supervisor / operator is the consumer, and the active run keeps its existing
route until a handoff point explicitly consumes a `HANDOFF_PENDING` signal or
initiates its own route decision. A working MiniMax M3 lane whose coordinator
sees `DEFER_ACTIVE_RUN` continues unchanged; a fresh MiniMax M3 lane that
needs an immediate fresh decision calls `bin/fm-provider-route.sh` itself.

The non-goals of the helper are also explicit:

- it does not become a background daemon or timer;
- it does not subscribe to `bin/fm-watch.sh` wakes;
- it does not move queue rows, change leases, or refresh credentials;
- it does not sleep, retry, or schedule itself;
- it does not auto-reroute a working task, even when its signal is
  `HANDOFF_PENDING`.

`tests/fm-provider-route-watch.test.sh` exercises this contract end to end
(first observation, identical snapshot, blocked quota, ready-but-changed
snapshot, isolation of the state directory, usage errors).

## AFK supervisor integration (autonomous bounded observation)

`bin/fm-provider-route-supervise.sh` is a bounded, cadence-gated helper that
makes the AFK housekeeping path call the sanitized observer during a captain's
absence without ever broadening the supervisor daemon's per-task
classification contract. It exists so the next safe handoff always has a
recent observation in `state/.provider-route-watch.signal` without a
human-in-the-loop call.

Per housekeeping tick the helper does at most one of the following:

1. If `(now - state/.provider-route-supervise-last-run) < cadence` (default
   `FM_PROVIDER_ROUTE_SUPERVISE_CADENCE=3600s`), the helper returns 0 without
   touching anything. The supervisor never sees a duplicate digest and quota
   is never read.
2. Otherwise it invokes `quota-axi --no-credential-refresh --json </dev/null`
   under a bounded watchdog (default `FM_PROVIDER_ROUTE_SUPERVISE_TIMEOUT=20s`,
   `timeout` > `gtimeout` > perl alarm > last-resort unbounded fallback),
   saves the JSON to a private bounded temp file
   (`${TMPDIR:-/tmp}/fm-supervise-snap.XXXXXX`), invokes the existing
   `bin/fm-provider-route-watch.sh` with `--state-dir <state> --quota-file
   <temp> --at <now>`, then removes the temp file. The supervisor signal
   (`NO_PRIOR` / `NO_CHANGE` / `HANDOFF_PENDING` / `DEFER_ACTIVE_RUN`) is
   persisted as a coarse bounded token to
   `state/.provider-route-supervise-last-signal`.
3. On `quota-axi` failure (non-zero exit, empty output, mktemp failure,
   watch binary missing, watch failure) the helper writes a coarse observable
   error to `state/.provider-route-supervise-error`, does NOT advance the
   cadence marker (so the next tick can retry promptly), and returns 0 so the
   daemon loop is never aborted.

The helper is deliberately passive. The integration boundary is exactly the
same as the explicit-call helper above:

- it does NOT become a background daemon or timer (the daemon's existing
  `FM_HOUSEKEEPING_TICK` cadence governs when `housekeeping` runs);
- it does NOT subscribe to `bin/fm-watch.sh` wakes (it is invoked only from
  `housekeeping`, after the per-wake classifier and the existing
  batch-flush / stale-recheck / pause-resurface / heartbeat-scan phases);
- it does NOT move queue rows, change leases, or refresh credentials;
- it does NOT spawn a process, sleep, or schedule itself;
- it does NOT auto-reroute a working task, even when its signal is
  `HANDOFF_PENDING`;
- it does NOT auto-escalate to the supervisor pane — `NO_CHANGE` produces
  no digest at all, and the first `HANDOFF_PENDING` / `DEFER_ACTIVE_RUN` /
  `NO_PRIOR` is a passive recorder the supervisor / operator consumes at
  their own cadence.

The cadence, the temp file, the error marker, and the bounded signal names
are the entire state surface; nothing else is written under `<state>/` by
the helper.

`tests/fm-provider-route-supervise.test.sh` exercises this contract end to
end with a hermetic fake `quota-axi` and a real `jq` wrapper: the helper
exists, the function is defined after the daemon is sourced, one observation
equals exactly one quota-axi call per due cadence, the temp file is removed,
the sanitized signal is persisted, quota failure records a coarse error and
keeps the daemon alive, housekeeping invokes the tick when due, and the
helper creates no file outside its bounded naming convention.

## AFK behavior

The AFK supervisor may continue a bounded task after a provider switch only when
the task's canonical run ID and lease remain unchanged and the new provider is
within the original write and host boundaries. A new route decision is for a
new attempt at a safe handoff point; it never interrupts a working task.

An M3 quota exhaustion changes the worker model for a new attempt; it does not
interrupt or silently reroute a working task. A working task keeps its model and
credential affinity until it reaches a safe handoff point. A
`bin/fm-provider-route-watch.sh` signal of `DEFER_ACTIVE_RUN` or `NO_CHANGE`
is consistent with that contract; only a fresh `bin/fm-provider-route.sh`
decision at the next handoff point can authorize an attempt on a different
model or provider.

No provider switch authorizes production mutations, credential changes, live
deployment, or a new host. Those remain explicitly coordinated decisions.

## Active failover and the Hetzner / live-integration limitation

This document and the helpers it describes are limited to a controller-local
deterministic route decision and a deterministic read-only observation. They
do not claim live autonomous active failover against the Hetzner / Core /
Elevate / CBD production stack, and they cannot: a live vendor runtime or
adapter state is not visible from quota-axi alone, and the route supervisor
cannot reach the production host without an explicit, separately authorized
cable that does not exist in this controller charter. A future lane that
needs active failover must be a separate, operator-authorized campaign with
its own host, credential, and write boundary.

---

## Model Ladder & Section Review Gates (Operator Invariant 2026-10-17)

### Model Ladder
- **Retired**: `gpt-5.6-luna`.
- **Active Triage / Coordination Tier**: **Luna 6 latest** (`gpt-6-luna` / `gpt-luna-latest`).
- **Super High-Level Escalation**: **Sol (medium reasoning)** (`gpt-5.6-sol` / `gpt-sol-latest`) for cross-system architecture, deep debugging, and security refactors.

### Solid Review & Test Gate
- All worker deliverables must ultimately be reviewed before final acceptance (`CHECK_PASS`).
- Enforcement applies at **solid section-level milestones** (e.g. deliverable completion, test suite green, artifact creation) rather than micro-interrupting every intermediate command.
- Measurement gates believing: every review claim must cite real test commands and stdout.
