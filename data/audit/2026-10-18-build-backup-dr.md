# Backup and DR execution lane — evidence and blockers

**Date:** 2026-10-18 UTC  
**Scope:** local read-only inventory plus a byte-for-byte scratch copy test. No client host, live service, production data, backup configuration, or credentials were accessed or changed.  
**Result:** no client-domain backup/DR capability was proven. Do not treat this lane's local copy test as a client restore drill.

## Findings

| Client domain | Backup configuration / schedule / destination | Restore classification | Measured RPO / RTO |
|---|---|---|---|
| Core Distro | UNKNOWN. Prior audits report no backup script in staged source and unknown database configuration. No current source-host schedule or target evidence available here. | UNKNOWN whether never configured or configured-but-never-drilled; no real domain restore drill found. | No measured RPO or RTO. PRD targets are aspirational only. |
| Elevate Life Sci | UNKNOWN. Prior evidence places it on Hostinger+Cloudflare, but no current backup job, schedule, or destination evidence. | UNKNOWN whether never configured or configured-but-never-drilled; no real domain restore drill found. | No measured RPO or RTO. PRD targets are aspirational only. |
| Whoosh Performance | UNKNOWN. Prior evidence describes it as parked with no Namecheap service; no current backup job or target evidence. | UNKNOWN whether never configured or configured-but-never-drilled; no real domain restore drill found. | No measured RPO or RTO. PRD targets are aspirational only. |
| CBD-Data | UNKNOWN. Prior audit reports no backup strategy, destination, scripts, or restore procedures in the inspected repository. Current live host/configuration not accessed. | UNKNOWN whether never configured or configured-but-never-drilled; no real domain restore drill found. | No measured RPO or RTO. PRD targets are aspirational only. |

The exact operational statuses **never-configured**, **configured-but-never-drilled**, and **drilled-and-verified** cannot be responsibly assigned per domain from available evidence. None is proven drilled-and-verified. Previous reported PRD goals (including compute-loss 4–8 hours, application/project 2–6 hours, and backup-target coverage 24 hours) are targets, not measurements. There is no measured backup interval from which to calculate RPO, and no authorized domain restoration elapsed time from which to calculate RTO.

## Current local evidence

- `systemctl list-timers --all --no-pager` showed standard OS timers and `hd2-disk-space-check.timer`; none was established as a client backup schedule. A timer's presence is not backup evidence.
- `warehouse/backups/` contains six PHP source snapshots dated 2026-09-27 (CBD/Core lead-list code). These are local code artifacts, not database/files/config backups for a client domain, and have no evidenced scheduled or off-site destination.
- `data/core-staging-publish-ready/restore-plan.md` is a plan, not executed restore evidence.
- Prior audit evidence records two named Namecheap targets for Core Distro and CBD-Data, but no successful transfer, manifest, checksum, encryption, retention, or restore proof; Elevate's hosting differs from the assumed Namecheap target. Names alone do not prove an assigned working backup.

## Executed scratch-copy verification (not a client DR drill)

Source artifact: `warehouse/backups/cbd-leadlists-pre-20260927-sha_a019adc1.php` (520,727 bytes). This is an old source-code snapshot, explicitly not a client data backup. A copied restore was tested only to demonstrate local artifact readability/integrity.

Command run:

```sh
set -eu
src='warehouse/backups/cbd-leadlists-pre-20260927-sha_a019adc1.php'
scratch="/tmp/backup-dr-drill-20261018-$(date -u +%H%M%S)"
mkdir -m 700 "$scratch"
cp -- "$src" "$scratch/restored.php"
printf 'RESTORE_COPY=PASS\\n'
printf 'SOURCE='; sha256sum "$src"
printf 'RESTORED='; sha256sum "$scratch/restored.php"
cmp -s -- "$src" "$scratch/restored.php" && echo 'BYTE_COMPARE=PASS' || { echo 'BYTE_COMPARE=FAIL'; exit 1; }
archived="${scratch}.retained"
mv -- "$scratch" "$archived"
printf 'SCRATCH_RENAMED_TO=%s\\n' "$archived"
test -f "$archived/restored.php" && echo 'RETAINED_COPY=PASS'
```

Output:

```text
RESTORE_COPY=PASS
SOURCE=a019adc1b325e388d88860456d3e3e45e6648dfc0fc5097be2eea2f39cae51cb  warehouse/backups/cbd-leadlists-pre-20260927-sha_a019adc1.php
RESTORED=a019adc1b325e388d88860456d3e3e45e6648dfc0fc5097be2eea2f39cae51cb  /tmp/backup-dr-drill-20261018-013743/restored.php
BYTE_COMPARE=PASS
SCRATCH_RENAMED_TO=/tmp/backup-dr-drill-20261018-013743.retained
RETAINED_COPY=PASS
```

The scratch directory was renamed, not deleted, per the no-delete rule. This test does not satisfy the requested domain restore drill.

## Blockers and exact unblock conditions

1. **No current source/target inventory or host authority.** Need the domain owner/operator to provide read-only access/evidence for each domain's active backup job, schedule, source, destination/account assignment, latest run/log, manifest/checksum/encryption, and retention. No credentials were requested or handled.
2. **No approved backup policy inputs.** Provider/account, retention, encryption-key custody, and RPO/RTO remain operator inputs. Do not create a new client backup job or choose a provider/retention/key policy without that authorization.
3. **No authorized domain restore drill source.** After a verified backup artifact is identified and scratch isolation is approved/available, restore it only to a new isolated scratch target and verify database/schema/row counts and file checksums; record start/end times and source backup. Never use a live target.
4. **RPO/RTO require an observed successful backup and restore.** RPO needs backup/source data timestamps or equivalent representative write marker and successful backup time; RTO needs timed restore plus verification. Neither can be inferred from PRD targets.

No backup config was changed, so config-backup path: **N/A**. This audit report did not exist before creation, so no prior report backup existed. No other files were mutated. Existing unrelated untracked paths `core-distro-saas-clean` and `firstmate` were left untouched.
