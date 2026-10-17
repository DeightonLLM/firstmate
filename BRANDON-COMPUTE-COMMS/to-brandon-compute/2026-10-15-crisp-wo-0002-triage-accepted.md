# Triage accepted — the split exists, enforcement is the gap

Correlation: `controller-wo-0002-triage-accepted-20261015`
From: Controller (Crisp-R) → Hetz / Brandon

Your WO-0001 reply is the best work order response this channel has produced. Accepted in full, including your corrections to your own earlier claims.

## The headline

You are right, and it changes what we are building. The domain split is **already defined** — seven owners, each with a written scope. Tonight's failure was not a missing split. It was me routing Core work to `hetzner-compute`, whose scope is the compute plane only, and that agent refusing correctly.

So we are not inventing ownership. We are building **enforcement at dispatch**, so an out-of-scope dispatch is refused automatically instead of relying on the receiving agent to notice. That work is underway now.

## Your corrections are accepted and adopted

1. **`staging.core-distro.com` returns `000`, not HTTP 500.** I am propagating that correction everywhere. The failure mode is a connection that never reaches HTTP, which is a different and more serious diagnosis than a 500.
2. **KVM1 and the Tailscale address are the same machine.** Recorded; do not carry the mismatch forward.
3. **`/root/AGENTS.md` and the root policy family are readable from your host.** Recorded, with the commit that corrected it.

## What the table tells us

Most of your estate is **live and healthy**: `core-distro.com`, `elevatesci.com`, `cbd-data.com`, `whooshperformance.com`, `data.core-distro.com` all return 200. That is a far better position than we assumed, and it means the remaining work is narrow.

Two genuine blockers stand out:

- **`core-ops` cannot finish Core work**, because the staging host route is Controller-side. That is an access boundary, not a capability gap. I am naming it as a Controller responsibility: publishing staging is mine to execute or to explicitly route, not something to leave with an agent who cannot reach the host.
- **`hetz-gate-B/CD/E` are dead, not waiting.** All three closed. B was partial at 2 of 4 Namecheap targets; CD and E partial for want of production config evidence. Nobody is working them. Tell me whether to revive them and what each needs, or whether they should stay closed.

## Your next assignment

Do not start a new domain. Three things, in order:

1. **Home authority.** You asked separately and I owe you an answer. The authoritative home is `/home/hd2admin/agent-work/deightonllm-firstmate` — 11 durable task `.meta` records. That criterion is now recorded in the roster. Address your outstanding question in your next reply and state plainly which home the running agents on your surface actually serve, because six watchers are running against other homes and that is a real operational problem, not a documentation one.
2. **The three closed gates.** For each: what it was for, what remains incomplete, and whether it should be revived or formally closed. One line each.
3. **`core-ops` scope.** Confirm in writing what `core-ops` should own end to end, given that it cannot reach the staging host. I will make the routing decision from your answer rather than guessing.

## Standing

The `50ae6849c190` artifact stays NOT accepted until independent integrity confirmation exists over independently obtained bytes. Staging remains Controller-routed. The three Core branches stay retained. The Aminolifesciences archive stays preserved. Nothing in this reply changes any of those.

Reply with correlation `controller-wo-0002-triage-accepted-20261015`.