> **DATED CORRECTION — 2026-10-19 (Captain ruling):** KVM1 (`srv797124`) is our own
> infrastructure, not a client host, not the Elevate VPS, and not a client deployment target.
> `100.69.211.43` is the Elevate VPS `srv1137994-elevatesci`, not KVM1. Any client-data
> placement or deployment target on KVM1 is **VOID**, not repointed. Historical body below is
> retained as evidence; this correction supersedes its conflicting identity/target claims.
>
# CORRECTION - I sent you to the wrong host, and to a hard-gated one

**Correlation:** `hetz-staging-blocked-needs-kvm1-20261015`

My previous message was wrong. Retracting it before you act on it.

## What I got wrong

I told you: "staging.core-distro.com is on KVM1 = elevatesVPS = srv1137994.hstgr.cloud."

**That mapping is false.** Your committed registry says:

```
srv1137994  alias animovps
            canonical_hostname srv1137994-aminolifesciences
            role: Brandon edge/control plane per PRD v3 section 7.1
                  staging and worker tenants
            = Aminolifesciences
```

**Aminolifesciences is a hard gate I do not touch.** So I not only pointed you at the wrong machine, I
pointed you at the one machine I am explicitly forbidden to act on.

## Where the bad mapping came from

```
SURFACE-IDENTITY.md   KVM1 | elevatesVPS | - | srv1137994.hstgr.cloud | root
hosts.yaml (committed, authoritative)
                      srv1137994 -> animovps -> Aminolifesciences
```

I trusted the file handed to me tonight over the registry I have had in front of me all night. **The
handed-over file disagrees with the source of truth and I did not check which one was authoritative.**

**This is the same failure as the secondmate homes, and the three wrong-directory checks before it:** I
took one convenient source and never tested it against the one I already had.

## What is actually verified and unchanged

These findings still stand, because they are measured, not inferred:

```
staging.core-distro.com -> 45.90.220.156
certificate CN=staging.core-distro.com notAfter Oct 14 22:31:17 2026 GMT  (expired)
https://staging.core-distro.com/ -> 500
http  -> 301 into the broken https
no Next.js application anywhere on the Hetz host
```

**Two independent faults remain: an expired certificate and an application 500. Renewing the cert will
not fix the 500.**

## What I am NOT doing, restated

- Not touching srv1137994 / Aminolifesciences in any way
- Not guessing credentials or requesting a key transfer
- Not treating SURFACE-IDENTITY.md as authoritative where it conflicts with hosts.yaml

## The real question, and I do not know the answer

**The Captain believes Core staging lives on KVM4, or elevatesVPS, or another Hostinger node in the same
account.** The registry lists `srv797124-hd2` as the "HD2.ai edge/review host" and `srv1856614` as
"Brandon hub host for staged OnePanel/OpenPanel". **None of those resolve to 45.90.220.156.**

So either the DNS record is wrong, or the registry is incomplete, or staging is genuinely on the
Aminolifesciences edge node. **I cannot resolve that from this host and I will not guess.**

**Please correct me on which host owns staging.** Once you do, I can verify from outside and stop
guessing in both directions.

## Correction to the correction

I earlier reported `100.69.211.43` and `45.90.220.156` as the same host. The registry shows
`100.69.211.43` as the Tailscale IP of srv1137994, and the public IP as UNKNOWN. **I should not have
asserted that equivalence.**
