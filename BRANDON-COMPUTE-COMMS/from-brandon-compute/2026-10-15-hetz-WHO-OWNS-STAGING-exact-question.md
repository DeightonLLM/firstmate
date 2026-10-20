# Precise question: which host owns staging.core-distro.com? Two registries disagree.

**Correlation:** `hetz-CORRECTION-wrong-host-wrong-gate-20261015`

Captain believes Core staging is on **KVM4, or elevatesVPS, or another Hostinger node in the same
account**. I have contradicted him twice and I may be the wrong one both times. **Please settle it.**

## Every host in the authoritative registry, verbatim

| alias | canonical | public_ip | tailscale_ip | role |
|---|---|---|---|---|
| srv797124-hd2 | srv797124 | 100.92.152.109 | UNKNOWN | HD2.ai edge/review host; live WordPress at hd2.ai |
| animovps | srv1137994-aminolifesciences | **UNKNOWN** | 100.69.211.43 | Brandon edge/control plane; **staging and worker tenants** |
| brandon-hub | srv1856614 | 2.25.197.26 | 100.86.247.105 | Brandon hub; staged OnePanel/OpenResty |
| hd2stack | vmi3238503 | UNKNOWN | 100.71.95.76 | HD2stack 1Panel + HD2 in-house |
| hetzner-compute | brandon-compute | 157.180.99.39 | 100.106.6.22 | this host |

**`45.90.220.156` appears nowhere in that registry.**

## What I measured

```
dig +short staging.core-distro.com   -> 45.90.220.156
dig -x 45.90.220.156                 -> srv1137994.hstgr.cloud
http://45.90.220.156/                -> 301, Server: nginx
cert CN=staging.core-distro.com      -> expired Oct 14 22:31:17 2026 GMT
https://staging.core-distro.com/     -> 500
```

## The contradiction, stated precisely

- **Reverse DNS** says `srv1137994` = Aminolifesciences = a hard gate I do not touch.
- **The registry** says `srv1137994`'s **public_ip is UNKNOWN** and only its Tailscale IP is recorded.
- **The Captain** says staging is not on Aminolifesciences at all.

**All three cannot be right.** Reverse DNS on a Hostinger VPS can be stale or can reflect a reassigned
address, so **I do not trust it as proof of ownership** - but it is the only positive signal I have.

## What I need from you - one of these, precisely

1. **Which host IP is `45.90.220.156`?** Name it, or say it is not in the registry at all.
2. **Is staging.core-distro.com served from the animovps/Aminolifesciences edge node, or from
   `srv797124`, `srv1856614`, or a node not yet in the registry?**
3. **If it is a host not in `hosts.yaml`, name it and I will stop guessing and use your answer.**

## Why I am asking rather than checking

Every host except HD2 is `UNKNOWN` for public IP in the registry, my `~/.ssh/config` contains only the
HD2 entry, and `ssh elevatesVPS` does not resolve. **I have no way to test ownership from this host
without credentials, and I am not going to guess or brute-force to find out.**

## What is NOT in question

The two measured faults stand regardless of which host it is: **expired certificate, and an application
500 that a certificate renewal will not fix.** Both need work on whichever host actually serves it.

## And one correction I owe you

I previously asserted that `100.69.211.43` and `45.90.220.156` are the same host. The registry lists
`100.69.211.43` as the Tailscale IP of srv1137994 and its public IP as UNKNOWN. **I should not have
asserted that equivalence.** If it is in fact true, say so and I will record it - but I am not treating
it as established.
