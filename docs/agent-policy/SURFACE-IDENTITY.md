# SURFACE IDENTITY — single authority for host aliases

Owner: this file. If any other document disagrees with this one about which machine an alias or hostname refers to, this file wins.

## Coding-surface fleet (four)

| Surface | SSH alias | IP | Hostname | Account |
|---|---|---|---|---|
| Controller | local | — | vmi3196300.contaboserver.net | root |
| HD2 | hd2stack | 100.71.95.76 | vmi3238503.contaboserver.net | root |
| Hetz | brandon-compute | 100.106.6.22 | brandon-compute.tailddbb4d.ts.net | hd2admin |
| KVM1 | HD2 main WordPress site (operator-confirmed 2026-10-15) | — | — | root |

KVM1 **is an HD2 surface** — the HD2 main WordPress site and a few files alongside it. Nothing
else. It is **not** `elevatesVPS` / `elevatesci-vps`, **not** `srv1137994`, and it holds
**no client files**. It must never be referenced as, or routed to, a client-files host. Do not
track it as a separate coding surface; it belongs to HD2.

Hetz Firstmate home authority: `/home/hd2admin/kun-agent-workspace`. The live session holds its lock, drains its queue, and runs the current AGENTS.md with swarm and lane sections absent from the other candidate home. Surface roster updates flow from measured live state; update that roster rather than overriding session reality.

Deprecated alias `srv797124-hd2` and `Core-distro_dedicated_server` are NOT part of the coding-surface fleet.

## CORRECTION 2026-10-15 — KVM1 identity is UNVERIFIED, and one host is a HARD GATE

An earlier version of this file asserted `KVM1 = elevatesVPS = srv1137994.hstgr.cloud` as fact.
**That was wrong and it nearly routed an agent at a forbidden machine.** Corrected here.

The authoritative source is `docs/system-context/hosts.yaml`, which says:

- `srv1137994-elevatesci` — provider hostinger, alias **`elevatesci-vps`** (legacy aliases
  `animovps`, `elevatesVPS`), Tailscale
  `100.69.211.43`, public IP **UNKNOWN**, role "Brandon edge/control plane", tenants
  `core-distro` + `cbd-data`. Status **PARTIAL**.
- The registry records that the operator *reported* the staging name, the PTR
  `srv1137994.hstgr.cloud`, the SSH alias **`elevatesVPS`** and Tailscale `100.69.211.43` as
  identifying that same host — **but that mapping was never independently verified.**
- The registry states plainly: **do not route based on the historical DNS record alone.**
- `staging.core-distro.com` was observed pointing at `45.90.220.156` on 2026-09-23. That is a
  **historical DNS observation, not a current host-interface check**, and must never be used to
  identify a machine.
- **KVM1 does not appear in the authoritative registry at all.**

### Corrected by the operator, 2026-10-15

**KVM1 is the HD2 main WordPress site plus a few files. It is an HD2 surface. It is not a
separate fleet surface, it is not `elevatesVPS`, and it holds no client files.** The earlier
"UNVERIFIED / conflict" entry in this file has been superseded by that operator statement. The
**The former "Aminolifesciences" company is FOLDED and that name is retired everywhere in
current documentation**; historical evidence filenames and dated records keep their original
names because they are records of what was observed. The hard gate on `srv1137994` and every rule
below it stand unchanged.

### Standing rules

1. **`srv1137994` / `elevatesci-vps` (legacy `animovps`, `elevatesVPS`) is RE-SCOPED by the
   operator ruling of 2026-10-16, not blanket-free.**
   Staging and WordPress port work on that host is LIFTED.
   The Aminolifesciences client and archive data on that machine is STILL GATED.
   Promoting staging to live client production is STILL GATED and needs its own explicit go.
   The archive stays preserved.
   The ruling is quoted verbatim in the SUPERSESSION 2026-10-21 section below.
2. **KVM1 is the HD2 main WordPress site** — an HD2 surface holding no client files. Never
   reference it as a client-files host and never route client work to it.
3. **Never infer a host from a domain, a DNS record, a PTR, or a legacy alias.** The precedence is
   the registry first; measurement second; everything else is a lead to verify, never an identity.
4. **Elevate does not supersede the folded Aminolifesciences estate.** Elevate's
   AnythingLLM work on `agents.elevatesci.com` has no authority over, and confers no permission
   on, the `srv1137994` host or any preserved archive material. The retired company name
   must not be used in current documentation.
5. **Core staging is NOT on KVM1** (operator-confirmed 2026-10-16). It is on an elevatesci VPS
   (`elevatesVPS` / `srv1137994`) or the **other Hostinger node in the same Brandon account**.
   Which of the two is not proven by a host-interface check. Naming a host as a candidate is NOT
   authorisation to act on it.
6. When a task appears to need a forbidden or unidentified host, **stop and report the exact
   need**. Never resolve it by inference in either direction.

Source: `docs/system-context/hosts.yaml` lines 81-108, read 2026-10-15.

## SUPERSESSION 2026-10-21 - the srv1137994 gate is re-scoped to the 2026-10-16 operator ruling

The `## CORRECTION 2026-10-15` section above is kept as the dated record of what was decided on
2026-10-15, including its statement that the hard gate on `srv1137994` stood unchanged.
Standing rule 1 has been re-scoped to a later operator ruling, so that sentence now records the
2026-10-15 decision and no longer states the current scope.
Nothing else in that section is rewritten, no preserved archive material is touched, and the
archive stays preserved.

### The 2026-10-16 lift, verbatim

Source: `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-16-hetz-inbound-backlog-triaged.md`,
section "The gate, restated so there is no ambiguity", dated 2026-10-16.

```
LIFTED       staging and WordPress port work on srv1137994 / elevatesVPS
STILL GATED  Aminolifesciences client and archive data on that machine
STILL GATED  promoting staging to live client production - its own explicit go
```

The same ruling is recorded in the authoritative registry, `docs/system-context/hosts.yaml`, entry
`srv1137994-elevatesci`, under `access_status: AUTHORIZED` and `access_scope`, read 2026-10-21.
That entry's own `status: PARTIAL` is about incomplete runtime documentation, not about access.

### What is still gated, exactly as the 2026-10-16 record scopes it

- The Aminolifesciences client and archive data on that machine is STILL GATED and stays untouched.
  The 2026-10-15 measured record states it as untouched, at line 34 of
  `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-hetz-domain-completion-measured.md`.
  Ask before using it.
- Promoting staging to live client production is STILL GATED and needs its own explicit go. The
  2026-10-16 ruling is not that approval.
- The archive stays preserved.
- Nothing else on that host is gated by this file, and nothing else on that host is released by
  this file.

### HD2's production-origin statement is attributed, not adopted

On 2026-10-21 HD2 first mate wrote, in
`BRANDON-COMPUTE-COMMS/to-brandon-compute/20261021-hd2-six-decisions-to-hetz-lane.md` section 5,
that this host has been "the live production origin for `data.core-distro.com` since the
Captain's 2026-10-20 migration approval", and that "clearing or re-scoping a hard gate is an
operator act, not a lane's".

That is HD2's statement.
It is not established by this file and it is not adopted here.
No 2026-10-20 migration approval record exists in this repository's own state, and the
repository's earlier dated record places `data.core-distro.com` on a different origin, in
`docs/FLEET-STATUS-20261012.md` dated 2026-10-12.
Standing rule 3 forbids resolving a host from a domain, a DNS record, a PTR, or a legacy alias,
so no host identity is asserted here on the strength of that claim.

The production-origin question is therefore still open, and it is an operator act.
Until the operator records it, `docs/system-context/hosts.yaml` remains the authority for this
host's identity and access scope, and standing rules 3 and 6 stand unchanged.

Source: `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-16-hetz-inbound-backlog-triaged.md`
(2026-10-16); `docs/system-context/hosts.yaml` entry `srv1137994-elevatesci` (read 2026-10-21);
`BRANDON-COMPUTE-COMMS/to-brandon-compute/20261021-hd2-six-decisions-to-hetz-lane.md` section 5
(2026-10-21, HD2 first mate, attributed and not adopted).

## Authority order for machine identity

When any two sources disagree about which host an alias or hostname is, resolve in this order and stop:

1. `/root/.ssh/config` — the alias to address mapping.
2. `herdr machine list` — which machines the Controller can actually drive.
3. The dispatch manifest `fqdn` field, as independently verified by `/root/bin/herdr-dispatch-preflight`.

`warehouse/access/SAAS_ACCESS_INVENTORY.md` is a client and credential access reference. It is NOT authoritative for machine identity and carries no alias-to-surface mapping. Do not use it to conclude that a hostname is unexpected or that a host is missing.

Known collision to be aware of: HD2's hostname `vmi3238503.contaboserver.net` is a Contabo name and appears in Contabo-related inventory, but it IS the hd2stack surface. Always resolve through the order above before treating a hostname as a surprise.

## Measurement rules

- A fact measured only by a PATH lookup must never be reported as absent. Probe with an explicit login-shell PATH, and check known non-PATH install locations before concluding anything is missing.
- Per-surface expected paths (Firstmate home, comms inboxes, trust baseline) come from `/root/agent-work/surfaces.conf`. Never assume a Controller-relative path exists elsewhere.
- Reachability and readability are separate facts. Report both.

## Roster and enforcement

Fleet membership, expected paths, and conformance checks are machine-readable in `/root/agent-work/surfaces.conf` and enforced by `/root/bin/surface-parity-audit`. Measured ground truth for the Controller surface is published through the surface parity audit.

Adding or retiring a surface is a deliberate operator action: update this file, `surfaces.conf`, and re-run the audit in the same change.

For Herdr pane payload identity and the requirement to read per-machine state on its owning host, see [`HERDR-PAYLOAD-CONTRACT.md`](HERDR-PAYLOAD-CONTRACT.md).