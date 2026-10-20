> **DATED CORRECTION — 2026-10-19 (Captain ruling):** KVM1 (`srv797124`) is our own
> infrastructure, not a client host, not the Elevate VPS, and not a client deployment target.
> `100.69.211.43` is the Elevate VPS `srv1137994-elevatesci`, not KVM1. Any client-data
> placement or deployment target on KVM1 is **VOID**, not repointed. Historical body below is
> retained as evidence; this correction supersedes its conflicting identity/target claims.
>
# FLEET-HYGIENE — lined-up update plan (inventory pass, read-only)

**Date:** 2026-09-29 01:15 BST · **Engine:** /root/bin/fleet-hygiene · **Skill:** /hygiene
**Reachable:** controller, brandon-compute (Hetzner), hd2stack, elevatesVPS · **KVM1 (`srv797124`): NO ssh alias — gap, needs one-time setup**

## 🔴 Report-first finding (no action taken)

**hd2stack:** a secret-material check at shell init reports **`FAILED: new possible secret material found in 1856 file(s)`** on that production host. Unverified class (likely session/transcript artifacts like brandon's, but 1,856 files is large). Per anomaly protocol: awaiting operator GO for a triage lane (classify paths → quarantine/baseline per this morning's workflow). Not counted as an update item.

## Lined-up inventory (versions as probed)

| CLI | controller | brandon-compute | hd2stack | elevatesVPS |
|---|---|---|---|---|
| pi | installed (version probe polluted by scanner msg) | 0.87.1 | ? (masked by same scanner msg) | 0.85.1 |
| senpi | 2026.9.15-2 | — | 2026.8.29 | — |
| omp | 17.2.10 | — | 18.1.3 | — |
| claude | 2.1.223 | — | 2.1.185 | 2.1.??? (bin present, version probe empty — suspect broken) |
| codex | 0.158.0 | 0.156.1 | 0.147.0 | 0.146.0 |
| agy | 1.2.12 | 1.2.12 | 1.2.0 | — |
| mcode | 0.5.5 | 0.5.5 | not installed | — |
| herdr | 0.9.1 | 0.9.1 | 0.8.2 | 0.7.6 |

## Update plan (on GO — engine handles snapshot → update → verify → auto-rollback per CLI)

1. controller: update all 8.
2. brandon-compute: update pi, codex, agy, mcode, herdr (login-shell PATH required — engine must run via `bash -lc`).
3. hd2stack: update senpi, omp, claude, codex, agy, herdr — **hold until the 1,856-file secret-material triage is resolved** (updates could churn scan baselines).
4. elevatesVPS: update pi, codex, herdr; **claude is broken on elevatesVPS** (version probe empty) — engine will snapshot → update → verify, auto-rollback if still broken; flag for manual review if update can't revive it.
5. KVM1: out of scope until ssh alias exists (one-time setup task).

## Known engine notes

- Remote hosts MUST run the engine through a login shell (`bash -lc`) or `~/.local/bin` CLIs are invisible.
- hd2stack login emits scanner output on stdout — inventory/version parsing on that host should filter scanner banner lines.
