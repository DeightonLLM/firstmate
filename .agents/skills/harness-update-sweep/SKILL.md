---
name: harness-update-sweep
description: >-
  One skill to version-read, compare, back up, update and verify every agent harness across every
  controller surface. Use when the Captain asks to "update the harnesses", "sweep for updates",
  "check for a new version", or names a surface and a harness together. Covers codex, pi, zcode and
  mcode on the Controller, HD2Stack and eVPS/KVM1. Default mode is READ-ONLY SWEEP; it only mutates
  when the Captain has given that exact surface the go.
metadata:
  internal: true
---

# Full-surface harness update sweep

**Trigger:** the Captain names harnesses, surfaces, or asks for an update sweep / "is anything out of
date". One owner, no per-surface improvisation.

## Scope

**Harnesses** (the Captain's list, 2026-10-14): `codex`, `pi`, `zcode`, `mcode`.

**Surfaces** (canonical names from [`docs/agent-policy/SURFACE-IDENTITY.md`](../../../docs/agent-policy/SURFACE-IDENTITY.md),
which is the single authority for machine identity — read it before naming any host):

| Surface | Host | How to reach |
|---|---|---|
| Controller | `vmi3196300` | local |
| HD2 | `vmi3238503` via `hd2stack` | herdr machine `d8b3aabca5b8c4dcaa54d4bba29f9396` (NO `host` prefix) |
| Hetz | `brandon-compute` `100.106.6.22` | `ssh brandon-compute` (account `hd2admin`) |
| KVM1 | HD2 main WordPress site | an HD2 surface — it holds **no client files** and is not a separate sweep target |

**Excluded host — HARD GATE.** `srv1137994` / `elevatesci-vps` (legacy `animovps`, `elevatesVPS`,
Tailscale `100.69.211.43`) is **not** a sweep surface. `docs/agent-policy/SURFACE-IDENTITY.md`
standing rule 1 puts it behind a hard gate: do not touch it, probe it, resolve it, dispatch to it,
or route work to it. Never name it as KVM1, and never infer a host from a domain, a DNS record, a
PTR, or a legacy alias (standing rules 3 and 6).

## Mode: SWEEP by default, UPDATE only on exact authority

**SWEEP** is read-only and safe: read installed versions, read published versions, diff, report.
Run it whenever asked. It never installs anything.

**UPDATE** mutates a live surface. It requires the Captain's explicit go **for that specific surface**.
Never inherit a go given for the Controller into eVPS or HD2, or the reverse.

- KVM1 is an HD2 surface holding no client files. It is not a production mutation target in its
  own right; treat any KVM1 change as an HD2 change under the HD2 rule below.
- The `srv1137994` / `elevatesci-vps` host is behind the hard gate above and is excluded from
  every sweep, including read-only probing. If a sweep is asked for that host, stop and report the
  exact need instead of resolving it by inference.
- HD2 is our own surface but carries live worker lanes. Back up before mutating and preserve every lane.

## Steps

1. **Record baseline.** For each surface × harness: installed version, or an explicit `not installed`
   / `not on PATH` / `not readable`. Never guess or omit a cell — "can't read it" is a real finding.
2. **Record published version.** `npm view <pkg> version`. If the published query is ambiguous or the
   harness is not npm-distributed, say so rather than substituting another package's version.
3. **Diff.** Report only surfaces/harnesses that are behind, plus anything missing entirely.
4. **Back up before any update.** Per harness, per surface: version, config path, install path. Prove
   the restore path before proceeding. Record the exact rollback command.
5. **Update one harness on one surface at a time.** Never batch across surfaces. After each, re-read
   the version and confirm the harness still launches.
6. **Verify.** Re-run the sweep. Report before/after per cell.
7. **Record.** Append the dated result to `CONTROLLER_STATE.md`. A sweep that is not recorded will be
   re-run next shift and drift again.

## Hard edges

- No spend, no credential or auth-file edits, no DNS/registrar.
- Never update while a lane on that surface is mid-flight without the Captain's word.
- Do not restart or stop a shared daemon to complete an update.
- If a harness's update mechanism is unknown, stop and report it — do not improvise an install path.
- Report a stale or unreachable surface plainly; never paper over a cell you could not read.

## Known findings, 2026-10-14 baseline — SUPERSEDED, re-measure, do not reuse

The table below was measured on 2026-10-14, **before** the 2026-10-15 KVM1 identity correction in
`docs/agent-policy/SURFACE-IDENTITY.md` and before the 2026-10-20 KVM8 cutover. Its "KVM1" row was
taken against a host that is now behind the hard gate above. It is retained as a dated record of
what was observed, not as a current fact: take no cell from it as current, and do not act on the
"KVM1 is the stalest surface" conclusion. Re-measure every cell in step 1 and report a cell you
could not read as a finding.

| Surface | mcode | herdr | treehouse |
|---|---|---|---|
| Controller | 0.6.10 | 0.9.1 | v3.1.2 (v3.1.3 published) |
| HD2 | not on PATH | reachable | not readable |
| KVM1 (mis-identified host, excluded) | 0.5.8 | 0.7.6 | absent |
