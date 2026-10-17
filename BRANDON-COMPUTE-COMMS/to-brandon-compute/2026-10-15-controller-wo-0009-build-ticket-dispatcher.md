# Controller — WO-0009: BUILD the ticket dispatcher. This is the last manual step.

**Correlation:** `controller-wo-0008-prd-work-20261015`

Hetz — this is the highest-value thing in the queue, and it is why the Captain still has to push.
Right now a ticket lands in the Controller's inbox and waits for a human to notice it and hand it
to an owner. Build the thing that removes that human.

## What to build

A dispatcher that turns an inbox ticket into a work order for its owner, with no nudge.

**Input:** a ticket file from the Controller's ticket inbox.
**Output:** a work order addressed to the resolved owner, written to the Controller's comms
outbox and handed to the standard delivery path, plus a durable record of what it dispatched.

## Rules — these are the acceptance conditions

1. **Resolve ownership from the registry, never from prose.** The authority is
   `data/agent-scopes.tsv` (7 owner rows). You may consult `DOMAIN-ROUTING.md` for human
   context, but the TSV decides.
2. **Use the existing scope gate, do not re-implement scope logic.** Ticket 0025's
   `fm-domain-scope-gate.sh` already reads the registry and refuses correctly (30/30 tests,
   verified). Extend it; do not write a parallel implementation.
3. **Refuse closed, never guess.** Missing domain token, unknown owner, unreachable registry,
   malformed registry, a token in an exclusion, or a token outside the owner's writable set: emit
   a refusal naming the owner, the token, the declared writable tokens, the matching exclusion and
   the recovery action. Never invent an owner and never infer one from a hostname, a folder or a
   task's prose.
4. **An ambiguous ticket is not dispatched.** It goes to a holding queue with the reason, so a
   human sees it — it is never silently dropped and never silently routed.
5. **Exactly-once.** A dispatched ticket must not be dispatched again on a re-scan. Re-running the
   dispatcher over the same inbox must produce no new work orders. Idempotency is a hard
   requirement, not a nicety.
6. **Respect every hard gate.** A ticket that would require spend, registrar/DNS, credentials,
   live production change, the archive, or a merge is never dispatched as ordinary work. It is
   held with the named gate named.
7. **Report before you stop.** Every lane: native visible To-Do list with your host's required
   prefix, ≥5 items, real dependency chain, exactly one in progress. `data/<task>/report.md`, last
   line exactly `VERDICT: PASS <reason>` or `VERDICT: FAIL <reason>`. Send it to
   `controller-replies` as it lands, then start the next item — report and move on, never
   report-and-stop.

## Testing

RED then GREEN, with fixtures — no live host required for the test suite. Cover at minimum:
in-scope dispatch; the real Core-staging misroute refused; explicit exclusion refused; missing
token; unknown owner; unreachable registry; malformed registry; a held gate ticket; and
**double-scan idempotency**. ShellCheck clean.

## Where the artifact goes

You do not need write access to the Controller. Deliver the complete artifact — script, tests,
and a short integration note naming the exact smallest seam where it hooks into the Controller's
existing intake — into your own `data/<task>/`, report it, and I will review and land it. That is
the normal path; do not wait for permission to build.

Boundaries unchanged: no spending, no registrar/DNS, no credentials, no production change, no
destructive action, no merge, never Escape a live agent.