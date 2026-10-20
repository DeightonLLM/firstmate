> **DATED CORRECTION — 2026-10-19 (Captain ruling):** KVM1 (`srv797124`) is our own
> infrastructure, not a client host, not the Elevate VPS, and not a client deployment target.
> `100.69.211.43` is the Elevate VPS `srv1137994-elevatesci`, not KVM1. Any client-data
> placement or deployment target on KVM1 is **VOID**, not repointed. Historical body below is
> retained as evidence; this correction supersedes its conflicting identity/target claims.
>
# Known sync gaps (2026-10-04)

**Source:** controller, operator-confirmed 2026-10-04. Written from the controller's point of view.

**Companion note:** `docs/knowledge/DOMAIN-REGISTRY-AND-PHANTOM-INCIDENT-20261003.md` (canonical domains, phantom-domain rules).

**Purpose:** every surface (brandon, elevatesVPS, hd2stack, KVM1) sees its own copy of these docs. Each line below is
tagged with its provenance so a surface owner knows whether the claim is a controller-observed fact or a claim that
must be re-verified on their own machine before it is trusted, corrected, or acted on.

## Tag meanings

- `[VERIFIED-CONTROLLER]` — observed directly on the controller. It is a fact about controller-owned state, cron, and
  scripts. It still does not prove the same state on any other surface.
- `[UNVERIFIED-PENDING-SURFACE]` — asserted, but only checkable on another surface. Do not treat as established, do not
  propagate, do not cite in a client or operator report until the owning surface has verified it.

No line below contains a secret value. Paths, script names, cron times, unit names, and the internal mirror address are
included deliberately because they are the evidence needed to verify each claim.

## Facts

### (a) firstmate-sync cron does not carry the warehouse tree
`[VERIFIED-CONTROLLER]` The `firstmate-sync` cron job at 04:40 rsyncs **only** `/root/agent-work/firstmate` to **brandon**
and **elevatesVPS**, with `--delete`. The warehouse tree is **NOT** synced by it. Consequence: any warehouse content
change is invisible on those two surfaces after the 04:40 run unless a separate pipeline moves it.

### (b) warehouse-sync.sh is a separate, manual-only, partial pipeline
`[VERIFIED-CONTROLLER]` `warehouse-sync.sh` is a **separate MANUAL-ONLY** pipeline. It pulls from the `100.71.95.76`
mirror, copies **only top-level** `.md` and `.yaml` files, and explicitly **excludes** `access/`, `recovery/`,
`reports/`, `evidence/`, and `projects/`. **brandon is not a target.** Consequence: it never runs on a schedule, and
even when run by hand it cannot deliver subdirectory material or reach brandon.

### (c) The warehouse README documents a brandon scp that does not exist
`[VERIFIED-CONTROLLER]` The warehouse README claims a brandon `scp` happens after every deploy. **No script does this.**
Consequence: the README overstates delivery; do not rely on it as evidence that brandon received a deploy.

### (d) system-context copies under firstmate-pi-glm53-* homes still carry the phantom spelling
`[UNVERIFIED-PENDING-SURFACE]` `system-context` copies under the `firstmate-pi-glm53-*` homes still carry the lawyer
phantom spelling (`lawyer-dta`). The spelling is confirmed to be a documentation error by the companion registry note;
which specific homes and files still carry it is **pending per-surface verification**. Correct only the copies on the
surface that owns them.

### (e) The `animovps` alias is deprecated for elevatesVPS
`[VERIFIED-CONTROLLER]` The alias `animovps` is **deprecated** for elevatesVPS; use the elevatesVPS name. This is a
controller-owned naming decision and is wrong-by-default on every surface. Residual uncertainty: the alias may still
physically exist in per-surface config; that per-surface alias state is unconfirmed and is surface work, not a
controller finding.

### (f) root-backups.mount has been failing since Oct 03
`[VERIFIED-CONTROLLER]` `root-backups.mount` has been **failing since Oct 03**; the hd2stack target was reported as
`Not-a-directory`. **INFERENCE ONLY:** any link between this failed mount and the doc mirror is inference, not an
established fact. Do not assert causation in an audit or an operator report without independent evidence on the mount
and on the mirror.

### (g) Two systemd units are failing
`[VERIFIED-CONTROLLER]` Failed systemd units: `core-distro-data-ssl-renew` (exit 203) and `herdr-freshness-check`.
Both are controller-observed failures. Neither is treated here as a cause of any sync gap above.

### (h) HANDOFF-LATEST.md is stale
`[VERIFIED-CONTROLLER]` `HANDOFF-LATEST.md` is **stale since Sep 29**: it states disk at 80 percent while the live
reading is 86 percent. Treat its state claims as unverified until refreshed.

## How a surface owner uses this note

1. Work **from your own surface only**. Do not copy another surface's answer into yours.
2. Re-verify each `[UNVERIFIED-PENDING-SURFACE]` line before repeating it anywhere.
3. Record a difference from your own state rather than overwriting the controller's record.
4. Correct the phantom-domain spelling (`lawyer-dta` -> `lawyer-data.com`) only in your own surface's doc replicas,
   citing `docs/knowledge/DOMAIN-REGISTRY-AND-PHANTOM-INCIDENT-20261003.md`.
5. Never cite a phantom domain as a client finding, asset, or outage.
