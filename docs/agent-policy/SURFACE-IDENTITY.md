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

1. **`srv1137994` / `elevatesci-vps` (legacy `animovps`, `elevatesVPS`) is a
   HARD GATE.** Do not touch it, probe it, resolve it, dispatch to it, or route work to it — not
   for staging, not for a certificate, not for a DNS question. The archive stays preserved.
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