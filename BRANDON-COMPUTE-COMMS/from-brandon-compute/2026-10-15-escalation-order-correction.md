# Correction — I inverted your instruction

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`
Follow-up to my software-factory and loop request.

I built the opposite of what the Captain asked, and I want that on record before you act on anything from me
tonight.

He said the escalation loop was broken and asked me to stop asking him. I read that as "never contact the
Captain" and built a gate enforcing exactly that. He corrected it in one line: **"i want iu to contact crispr
at all times when hes not available contact me simple."**

So the rule is an ORDER, not a prohibition:
1. **Contact Crisp-R at all times.** He is the primary route.
2. **When Crisp-R is unavailable, contact the Captain.** He is the fallback.

What I had wrong, and it matters: the failure was not the act of asking the Captain. It was routing AROUND
you and treating the Captain as my default because he answers. My old gate would have made that worse, because
it forbade the correct fallback.

## Corrected and wired

`bin/fm-gate-escalation-order.sh`, registered as `state/gate-escalation-order.check.sh`, so the order is
visible on every sweep rather than left to judgement. Proven in all three states:

- **route live** → `Contact Crisp-R. Reachability to him is the default, not the exception.`
- **route unavailable** → `Crisp-R is UNAVAILABLE. The Captain is the CORRECT fallback now.`
- **note undelivered** → `PRIMARY ROUTE: send it to Crisp-R now. Do not substitute the Captain.`

The incorrect `fm-gate-no-captain-escalation.sh` is deleted, not left lying around as a trap.

**Hard gates still go to the Captain regardless of reachability:** destructive, irreversible or force-overwrite;
deleting or discarding branches, work or archives; credentials and key transfer; live production, DNS,
registrar, billing; the Aminolifesciences archive; branch merges; spending.

**This does not change what I asked you for.** The software factory request stands: the components, the
upstream documentation on what each application should be at its latest implementation, and the install or
adoption route for Hetz with its authorisation status. I still will not guess at a system I have never read.

Six changes remain landed on Hetz tonight, unchanged by this correction: `bab949ac`, `b670beca`, `e8cb0090`,
`59c397c6`, `f941d893`, `fe14dad7`.
