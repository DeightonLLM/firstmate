# FLEET-HYGIENE — results (2026-09-29 01:40 BST)

**Run:** update pass on controller, brandon-compute, elevatesVPS (hd2stack HELD pending 1,856-file secret-material triage) · **Engine:** /root/bin/fleet-hygiene (snapshot → update → verify → auto-rollback; 2 script bugs found+fixed during this run: empty-args iteration, IFS word-splitting)

## Controller — 8/8 VERIFY-PASS

| CLI | Before | After |
|---|---|---|
| pi | older | 0.87.1 |
| senpi | 2026.9.15-2 | 2026.9.28-7 |
| omp | 17.2.10 | **18.4.2** (major) |
| claude | 2.1.223 | **2.1.284** |
| codex | 0.158.0 | 0.158.0 (current) |
| agy | 1.2.12 | 1.2.12 (current) |
| mcode | 0.5.5 | 0.5.5 (current) |
| herdr | 0.9.1 | 0.9.1 (skip-by-design: refuses self-update inside live session; already current) |

## brandon-compute — 5/5 VERIFY-PASS

pi 0.87.1 (current) · codex **0.156.1 → 0.158.0** · agy 1.2.12 · mcode 0.5.5 · herdr 0.9.1 (current)

## elevatesVPS — 3/4 VERIFY-PASS, 1 pre-broken

pi **0.85.1 → 0.87.1** · codex **0.146.0 → 0.158.0** · herdr 0.7.6 (current on channel) · **claude VERIFY-FAIL — pre-existing INVALID_CONFIG** (untouched by hygiene; needs manual config repair, then re-run `/hygiene`)

## hd2stack — 6/6 VERIFY-PASS (ran 02:20 BST after triage resolved the hold)

senpi → 2026.9.x · omp **17.x → 18.4.2** · claude **2.1.185 → 2.1.284** · codex **0.147.0 → 0.158.0** · agy **1.2.0 → 1.2.12** · herdr **0.8.2 → 0.9.1** · **mcode 0.5.8 INSTALLED + AUTHED (AUTH_OK MiniMax-M3)** — node upgraded 20.20.2 → **22.23.3 LTS** (all node CLIs re-verified on 22) · pi per inventory · scanner note CORRECTED: the rg glob-parse errors were a corrupt `.gitignore` inside the backup tree (fixed by the sealed-store move — post-move scan: 0 glob errors, 130 stable runtime-class findings); no scanner config defect exists

## Reboots — APPLIED AND VERIFIED (2026-09-29 05:10–05:18 BST)

brandon-compute + KVM1 rebooted on operator GO; independent Gemini verification lane: **10 PASS / 0 FAIL** — reboot-required flags **CLEARED** on both, kernels applied, agent CLIs healthy post-boot (codex 0.158.0 both), `hd2.ai` 200 post-reboot. Controller reboot remains scheduled for the operator's quiet window (hosts this session). Evidence: FULLHYG-REBOOT-VERIFY.md.

## Holds / gaps (final)

- **hd2-repo-quarantine 6.2 G → MOVED to hd2stack (2026-09-29 03:55 BST):** Sept-8 root-recovery snapshot (untracked tars + stash bundles) rsynced to `hd2stack:/root/quarantine-archive/hd2-repo-quarantine/20260908T000000Z-r1/`, all 5 large artifacts **md5-verified OK**, local copy deleted. **Controller disk: 2.3 GB free (97%) → 15 GB free (80%)** across the campaign.
- **268 backup-credential files (hd2stack):** operator ruling = no rotation now; archives sealed at `/root/.secrets/controller-backups/` (symlink at old path). Rotation remains the only full neutralization — future window.
- **KVM1 (`srv797124-hd2`) JOINED the fleet:** ssh alias created, node v24.13.0, 1 CPU, codex **0.50.0 → 0.158.0** (npm path — old updater needs TTY). In `/hygiene` host list.
- **CI push DONE:** commit `53e473c` pushed to fleet main.
- **Known follow-ups:** hd2stack scanner has one corrupted excludes entry (charset-log glob — cleanup candidate); controller/brandon/KVM1 reboots staged (kernel updates — operator window); lane-stall-watch cron now active (`/root/bin/lane-stall-watch`, logs to /var/log/lane-stall-watch.log).
- **Rollbacks used:** none across the entire campaign.

- **268 backup-credential files (hd2stack):** operator ruling = no rotation now; **containment executed 2026-09-29 02:45 BST** — archives moved to sealed store `/root/.secrets/controller-backups/` (root-only, out of scan scope), symlink left at `/root/backups/controller-backups` so restore tooling still resolves; rescan improved 1,856 → 128 remaining runtime-class candidates (documented classes; future hygiene pass applies recommended globs). Rotation remains the only full neutralization — flagged for a future window.
- **KVM1 (`srv797124-hd2`) JOINED the fleet (2026-09-29 02:55 BST):** ssh alias created (Tailscale 100.92.152.109, fleet key, verified), node v24.13.0, 1 CPU, codex-only surface — **codex updated 0.50.0 → 0.158.0** (updater needed TTY; fixed via npm path). Inventory added to `/hygiene` host list.
- **CI push DONE:** commit `53e473c` (action SHA pinning, jq checksum, tasks-axi removal) pushed to fleet main (`2e61f52..53e473c`).
- **Rollbacks used:** none across the entire campaign.

- **hd2stack:** updates HELD until the 1,856-file secret-material triage is resolved (report-first, awaiting GO for a triage lane).
- **KVM1 (`srv797124`):** no ssh alias — one-time setup needed to join hygiene runs.
- **Plugin refresh:** `claude plugin update` requires a plugin argument in 2.1.x — dropped from the engine; run per-plugin manually if needed.
- **Rollbacks used:** none — no update required a rollback (all verify-passes clean).

## Skill

`/hygiene` → `/root/.claude/skills/hygiene/SKILL.md` + `/root/bin/fleet-hygiene`. Say "hygiene" to re-run the full cycle anytime.
