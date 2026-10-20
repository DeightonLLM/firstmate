# WO-0010 — Core staging repair on the authorized host. Execute in order.

**Correlation:** `wo-0010-staging-repair`
**Priority: top of the queue.** Your panes are idle with no workers. This is the work.

## Why you have it now

The operator ruled today that `srv1137994` / `elevatesVPS` / `elevatesci-vps` / `animovps`
is one machine (Tailscale `100.69.211.43` on every alias), that the live `elevatesci.com`
origin **is** that host, and that the standing prohibition is **lifted for Elevate/Core
staging and the staged WordPress port on it**. That is why this order exists: the two
staging faults you reported have an owner for the first time.

## Task, in this order — do not reorder

**1. Expired certificate on `staging.core-distro.com` (expired 14 Oct).**
Renew or replace it so staging serves a valid chain.

**2. The HTTP 500 behind it.**
You are right that a renewal will not fix this. Treat them as two separate faults.
Find the ACTUAL cause of the 500 before changing anything — read the error and the
service state, do not guess. Report the real cause, then fix it.

**Order matters: certificate first, then the 500.** If fixing the 500 requires touching
the certificate, stop and say so instead of improvising.

## Boundaries — precise, so you do not have to ask

**In scope, proceed without asking:**
- Read and change files on `srv1137994` / `elevatesVPS` for staging work.
- Service restart / reload needed to apply a staging fix, on that host.
- Read-only diagnosis anywhere, including logs.

**Out of scope, stop and report instead:**
- **Live client production.** `elevatesci.com` and `agents.elevatesci.com` are NOT in
  scope. The gate lift covers **staging**. Do not promote staging to live, and do not
  touch the live sites' config, data, or processes.
- **Aminolifesciences client or archive data** on that machine. Not released by this
  order. One line to ask if you need it.
- Registrar, DNS, or anything that spends money. Ever.
- Credentials you were not already given.

If any of those turn out to be genuinely required, **stop and name the blocker**. A named
blocker is a success for this order, not a failure. Do not widen scope to get unstuck.

## Definition of done

- Certificate valid on `staging.core-distro.com`, with the expiry you obtained.
- HTTP 500 gone, with the **real** cause named — not a certificate-shaped explanation.
- A report file at your usual path, ending with a single line:
  `VERDICT: PASS <one-line reason>` or `VERDICT: FAIL <named blocker>`.
- Then stop and report. Do not continue to another task unprompted.

## Still true, unchanged

`srv1137994` was never probed, resolved, or touched while it was gated. KVM1 remains
ruled out (it is the HD2 main WordPress site). Both Elevate hostnames answered HTTP 200 at
your last check and were not altered — keep them that way.

Controller out. This is the priority lane; the factory is standing behind it.