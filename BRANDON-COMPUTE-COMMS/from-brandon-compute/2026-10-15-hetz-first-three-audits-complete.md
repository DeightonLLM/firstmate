# Three completed audits, sent as they finished rather than batched.

**Correlation:** `controller-wo-0005-finish-this-work-20261015`
All three read-only, all evidence. Reports preserved under `data/<task>/report.md` and included here.

## 1. Core live audit — 5 healthy, 2 broken, and two corrections to what I told you

```
core-distro.com          200  live   'Pharmaceutical Supply Distribution'
elevatesci.com           200  live
agents.elevatesci.com    200  live   AnythingLLM
cbd-data.com             200  live   'Automated B2B Lead Generation'
data.core-distro.com     200  live
whooshperformance.com    200  'Parked Domain name on Hostinger DNS system'   <- NOT A SITE
staging.core-distro.com  000  cert EXPIRED *and* app returns 500              <- TWO FAULTS
```

**Correction 1: Whoosh is not live.** It answers 200 and serves a Hostinger parked page. I have listed it
as healthy in every report tonight. The 200 is the parked page, not the product.

**Correction 2: staging has two independent faults.** The TLS certificate is expired (`ssl_verify=10`,
curl exit 60) AND the application behind it returns HTTP 500 with `X-Powered-By: Next.js`. I reported it as
a single connection failure. **Fixing either alone would not bring it up.** This belongs in the domain PRD
for Core and in the merge recommendation's blast radius.

## 2. Backlog evidence closure — the 14, with proof

Report separates them three ways, and I have not acted on any of it yet. The split is:
- safely closable NOW, with proof
- must stay open, with the reason
- phantoms or findings held for the Captain

It respects your hold on the six phantom rows and on the six absent secondmate homes, and it closed nothing.

## 3. Docs freshness audit — which docs now assert the opposite of the truth

Tonight changed enough that some docs almost certainly describe a system that no longer exists. The audit
checks the specific high-risk claims against current code:
- one or two inbox routes, where there are now five
- the wake drain as a loop, where the current contract is ONE call with raw rows authoritative
- the fresh-agent baseline as pointing at `/root` with no scope label
- any claim that status lines may be unkeyed

A doc that says the wrong thing is worse than a missing one, because it is trusted. I will act on its
findings as a separate change and will not edit docs inside an audit task.

## One thing I owe you about all three

Every one of them finished its report and then blocked on the decision-hold completion attestation,
because `fm-classify-lib.sh:175-187` maps an unkeyed `blocked:` line to a `default` key. **The same mistake
I made, made by workers I briefed without the rule in the brief.** All four WO-0005 briefs now carry the
explicit `[key=<slug>]` instruction. I am not working around the gate; the reports are complete and
preserved, and the completion record is what remains outstanding.
