# Elevate origin + the elevateVPS / srv1137994 conflict. One question, please.

**Correlation:** `controller-staging-host-answer-20261015`

Captain believes Core staging is on elevatesVPS. **That collides directly with your standing hard gate,
and I will not resolve it by inference in either direction.** So I am asking rather than guessing.

## What I can verify, and cannot

```
elevatesci.com          -> 172.67.214.115   Cloudflare
agents.elevatesci.com   -> 104.21.61.204   Cloudflare
staging.core-distro.com -> 45.90.220.156   direct, no CDN
```

**Both Elevate sites are behind Cloudflare, so their origin host is invisible from DNS.** I cannot
determine where the live Elevate site runs without either the origin IP or Cloudflare access, and I
will not probe for it.

## The conflict, stated precisely

Your 2026-10-16 staging-host answer says:

> ElevateVPS is a Hostinger node in the Brandon account - that is `srv1137994`, reachable as
> `elevatesci-vps` / `elevatesVPS` (Tailscale `100.69.211.43`, public IP UNKNOWN).
> `srv1137994` / `elevatesci-vps` is a **HARD GATE**. Do not touch it, probe it, resolve it, deploy to it.

My committed registry says:

```
srv1137994   alias animovps
             canonical_hostname srv1137994-aminolifesciences
             tailscale_ip 100.69.211.43
             role: Brandon edge/control plane; staging and worker tenants
```

**Same address, three names: elevateVPS, elevatesci-vps, and animovps/Aminolifesciences.** The tailscale
IP matches exactly, so these are the same machine, not two.

**The consequence I need you to resolve:** if Core staging is on elevatesVPS, **then Core staging is on
the hard-gated host.** You already said naming a host is not authorising access to it - which I accept,
and which is precisely why I am asking instead of acting.

## Three questions

1. **Is the live `elevatesci.com` origin the same machine as `srv1137994` / elevatesVPS?** If yes, the
   live Elevate site runs on a hard-gated host. If no, name the origin so the registry can be corrected.
2. **Does Core staging run on elevateVPS, or on the second Hostinger node?** The Captain believes
   elevateVPS; your answer allowed either.
3. **If staging is genuinely on `srv1137994`, is that prohibition absolute for staging work too,** or is
   it scoped to Aminolifesciences client/archive data only? **I am not assuming the narrower reading.**

## What I am not doing

- Not probing, resolving, or touching `srv1137994` in any form
- Not inferring the staging host from DNS, PTR, or a legacy alias
- Not touching `srv1137994` even if the Captain names it as a candidate

## Current standing

- **`srv1137994` / animovps / Aminolifesciences: untouched.**
- KVM1 ruled out: it is the HD2 main WordPress site, holds no client files.
- The two Core staging faults stand: certificate expired 14 Oct, and an HTTP 500 behind it. **A
  certificate renewal will not fix the 500.** Both must be addressed, in that order, by whoever holds
  authority for that node.
- `elevatesci.com` and `agents.elevatesci.com` both answer HTTP 200 right now and were not altered.

Answering question 1 alone would let me correct the registry. Questions 2 and 3 decide whether staging
can be fixed at all, and by whom.

---

# FOLLOW-UP - unanswered, and this now blocks the Captain

Sent a second time because the first went unread. Re-stating only the decision, not the evidence,
which is unchanged and still stands above.

**One host, three names, one prohibition:**
```
srv1137994  =  elevatesVPS  =  elevatesci-vps  =  animovps / Aminolifesciences
tailscale 100.69.211.43 matches across all of them
```

**The Captain believes Core staging runs on elevatesVPS.** If that is correct, **Core staging runs on
the hard-gated host**, and the certificate plus the 500 cannot be fixed by me.

**Answer these three and staging moves:**

1. Is the live `elevatesci.com` origin that same machine as `srv1137994`?
2. Does staging run on elevatesVPS, or the second Hostinger node in that account?
3. If staging is `srv1137994`, is the prohibition **absolute for staging work**, or scoped to
   Aminolifesciences client/archive data only?

**Question 3 is the one that unblocks it, and I am explicitly not assuming the narrower reading.**
If the prohibition is absolute, staging needs a different owner and I will say so plainly to the
Captain rather than leave him expecting a site tonight.

**Unchanged and not at risk:** `srv1137994` remains untouched, unprobed and unrouted. KVM1 remains
ruled out. The two staging faults remain certificate-expiry plus an HTTP 500.
