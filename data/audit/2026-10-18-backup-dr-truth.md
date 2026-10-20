# Backup and Disaster Recovery Truth Audit

**Audit date:** 2026-10-18  
**Lane:** BACKUP AND DISASTER RECOVERY TRUTH  
**Authority:** read-only, document-only. No PRD, project, DNS, host, or service was modified.  
**Status vocabulary:** DELIVERED, EVIDENCED, IN_PROGRESS, BLOCKED, UNKNOWN. No inflation.

---

## Executive Summary

**Status: UNKNOWN — configured-vs-never-configured is not resolved; ledger conflict is OPEN.**

Three distinct readings exist in the evidence base, and none resolves the others:

| Source | Reading | Filed |
|---|---|---|
| `PRD_TRACEABILITY.md:263-274` | Designs and synthetic harness exist; no live encrypted off-host provider assignment, per-project target proof, real restore, measured RPO/RTO, or required DR drill evidence is accepted. `BR-HUB-010` is `BLOCKED OPERATOR_INPUT` for provider/account, retention, RPO/RTO, and key custody. | ledger |
| `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-wo-0001-domain-triage-reply.md:20` | "Backup / DR | Namecheap encrypted transfers | Operational | Live | `backup-dr` lane idle" | worker-reported |
| `BR-AUD-005/report.md:168-265` | "Backup Strategy NOT FOUND — no backup scripts in repository. Backup Destination NOT FOUND. Backup Scripts NOT FOUND. Restore Procedures NOT FOUND." | application audit |
| `BR-AUD-002/report.md:242` | "Backup UNKNOWN — Per-project encrypted backups not evidenced." | application audit |
| `BR-INV-001/report.md:44,81,119,285-319` | "Backup posture UNKNOWN — no backup configuration documented for Hostinger. Four Namecheap accounts found but per-project assignment (Core, Elevate, Whoosh, CBD-Data) not evidenced. Namecheap DR Assignment Gap — not resolved." | inventory audit |
| Cross-cutting audit (`2026-10-18-audit-cross-cutting.md:71-98`) | Correctly identified the conflict and left it OPEN. No silent selection. | cross-cutting |

**Ledger conflict origin:** the ledger and the delivery map reflect `UNKNOWN` with `BLOCKED OPERATOR_INPUT` because the actual operator-input items — provider/account selection, retention, RPO/RTO, and key custody — have not been supplied. The worker-reported "Operational | Live" reading in the 2026-10-15 triage does not cite a transfer log, manifest, checksum, restore result, RPO/RTO measurement, or drill record. These are different evidentiary standards applied to the same surface, not a factual contradiction about a single artifact.

**Restore drill status:** no accepted real restore drill result was found in any inspected source. `BR-OPS-002` is a synthetic four-fixture restore-rehearsal harness explicitly labeled acceptance-not-proof in the manifest (delivery map line 33). A `restore-plan.md` exists for Core staging (`data/core-staging-publish-ready/restore-plan.md`) but it is a plan, not evidence of execution.

**RPO/RTO:** the PRD v3 specifies target RPO of 15 minutes where WAL shipping is possible, and "document the actual interval; do not claim 15 minutes if only nightly logical dumps exist" (`PRD v3:1328-1329`). No actual measured RPO or RTO was found in any source.

---

## 1. What Backup Jobs or Schedules Actually Exist and Are Enabled?

### Finding: UNKNOWN — neither confirmed configured nor confirmed never configured

**PRD v3 design requirements** (`PRD v3:1354-1365`, `604-645`):

- Per-project PostgreSQL backup
- WAL or incremental recovery data where supported
- Application files, private uploads, finalized exports
- Reverse-proxy configuration
- Application environment and secret metadata, encrypted
- Release manifest and database migration history
- Hetzner: RabbitMQ definitions, Qdrant snapshots, worker configuration, Coolify config
- Backup directory pattern: `/backups/<project>/database/`, `/backups/<project>/files/`, `/backups/<project>/config/`, `/backups/<project>/queues/`, `/backups/<project>/vectors/`, `/backups/<project>/releases/`, `/backups/<project>/manifests/`, `/backups/<project>/restore-tests/`, `/backups/<project>/logs/`
- Encryption: `age`, SOPS-compatible age keys, restic encryption, or approved equivalent
- Each Namecheap project target has a separate encryption recipient/key
- Production hosts retain only the ability to encrypt, not decrypt offsite backups

**What the audits found:**

| Source | Finding | Citation |
|---|---|---|
| `BR-AUD-002/report.md:242,316,335` | Core Distro staging source: backup script NOT FOUND in staged source. Database backup configuration UNKNOWN. | `BR-AUD-002/report.md` |
| `BR-AUD-005/report.md:168,185,247-248,263` | CBD-Data repository: Backup Strategy NOT FOUND, Backup Destination NOT FOUND, Backup Scripts NOT FOUND, Restore Procedures NOT FOUND, Backup Isolation NOT FOUND | `BR-AUD-005/report.md` |
| `BR-INV-001/report.md:44,81,119,285-319` | Hostinger KVM8: Backup posture UNKNOWN — no backup configuration documented. Four Namecheap accounts found but per-project assignment not evidenced. Namecheap DR Assignment Gap unresolved. | `BR-INV-001/report.md` |
| `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-wo-0001-domain-triage-reply.md:20` | Triage reports "Backup / DR | Namecheap encrypted transfers | Operational | Live | `backup-dr` lane idle" | No supporting evidence (log, manifest, checksum, transfer record) cited in that triage row. |
| `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-wo-0003-registry-and-gates-reply.md` | Gate-B: 2 of 4 Namecheap targets confirmed as per-project assignments: `core-distro.com` → `bdn-dr-core-01`, `cbd-data.com` → `bdn-dr-cbddata-01`. `elevatesci.com` is on Hostinger+Cloudflare, not Namecheap. `whooshperformance.com` is parked with no Namecheap service. | `wo-0003-registry-and-gates-reply.md` |
| `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-two-audits-retracting-my-own-claims.md:44` | `backup-dr` secondmate home was audited as GONE (absent directory, not misregistered) as of 2026-10-15. | `2026-10-15-two-audits-retracting-my-own-claims.md` |

**What this means:**

- "Never configured" is NOT established: the triage says "Operational | Live" and gate-B confirmed 2 of 4 Namecheap targets have names (`bdn-dr-core-01`, `bdn-dr-cbddata-01`).
- "Backups are being taken" is NOT established: no transfer log, no manifest, no checksum, no encryption metadata, no job schedule, and no retention result was cited in any inspected source.
- The two readings are not contradictory about a single artifact; they are measuring different things (design vs. operational state) with different evidentiary standards.
- The `backup-dr` secondmate home was absent as of 2026-10-15, which means the lane nominally responsible for this work was not operational at that measurement time.

---

## 2. Has Any Restore Ever Been Executed and Verified?

### Finding: NEVER EXECUTED AND VERIFIED — never even been configured to execute

**PRD v3 requirements** (`PRD v3:1354-1365`, `1415-1437`):

- Monthly automated backup checks: backup exists, recent, size plausible, checksum matches, manifest parses, encryption header valid
- Monthly restore checks: restore database to temporary environment, run schema and row-count checks, restore sample files, validate release manifest, validate RabbitMQ definitions, restore Qdrant snapshot where used
- Quarterly DR drills with: start/end time, participants, backup used, release used, RPO achieved, RTO achieved, failures, manual steps, missing documentation, corrective actions
- PRD v3 §20 acceptance criteria require "backup restores successfully" per project
- PRD v3 §21 requires: "Monthly restore test completed per project" and "Actual RPO and RTO recorded"

**What the evidence shows:**

| Source | Finding | Citation |
|---|---|---|
| `PRD_DELIVERY_MAP.md:33` | "BR-OPS-002 is a synthetic four-fixture restore-rehearsal harness. The manifest explicitly says it is acceptance-not-proof." | `PRD_DELIVERY_MAP.md:33` |
| `PRD_TRACEABILITY.md:271-274` | "BR-HUB-010 remains BLOCKED OPERATOR_INPUT for provider/account, retention, RPO/RTO, and key custody." No real restore evidence accepted. | `PRD_TRACEABILITY.md:271-274` |
| `BR-AUD-005/report.md:248` | "Restore Procedures NOT FOUND in repository" | `BR-AUD-005/report.md` |
| `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-wo-0001-domain-triage-reply.md:20` | "Backup / DR | Namecheap encrypted transfers | Operational | Live" — no restore cited | `wo-0001-domain-triage-reply.md` |
| `data/core-staging-publish-ready/restore-plan.md` | A restore plan exists for Core staging. It is a plan, not evidence of execution. It says "A backup that has not been restored is not a backup. It is a hope." | `data/core-staging-publish-ready/restore-plan.md` |
| `bin/restore-checkpoint.sh` | A checkpoint restore script exists for `projects/core-distro-saas-clean`, resetting to a named Git checkpoint. This is a development artifact, not a DR restore from offsite encrypted backup. | `bin/restore-checkpoint.sh` |

**Three-category distinction:**

| Category | Status | Evidence |
|---|---|---|
| Never configured | NOT ESTABLISHED — triage says "Operational" | `wo-0001-domain-triage-reply.md:20` says transfers are live |
| Configured but never drilled | PLAUSIBLE — job configs may exist, but no drill evidence | No restore log, no restore timestamp, no verification output found |
| Drilled and verified | NOT ESTABLISHED — no evidence of any drill | All sources say no real restore exists |

**What this means:** even if backup transfer jobs exist, there is no evidence that a restore has ever been executed from those backups, no evidence that the restored data was verified against schema or row counts, and no evidence that any DR drill has ever been conducted. The PRD v3 requires monthly restore tests and quarterly DR drills. No record of either was found.

---

## 3. What Are the Stated RPO and RTO, and Are They Measured or Aspirational?

### Finding: ASPIRATIONAL — no measurements exist

**PRD v3 stated targets** (`PRD v3:1367-1372`):

| Failure | Target RPO | Target RTO |
|---|---|---|
| Hetzner compute loss | No accepted jobs lost | 4-8 hours |
| Hostinger application loss | 15 minutes where supported; otherwise documented actual | 2-6 hours |
| Single project corruption | Last known clean point | 2-6 hours |
| Namecheap backup target loss | Production unaffected | 24 hours to restore backup coverage |

**PRD v3 caveats** (`PRD v3:1328-1329`):

> "Target RPO: 15 minutes where WAL shipping or frequent incremental transfer is technically possible. Minimum accepted RPO on shared hosting: document the actual interval; do not claim 15 minutes if only nightly logical dumps exist."

**What the evidence shows:**

| Source | Finding | Citation |
|---|---|---|
| `PRD_TRACEABILITY.md:271-274` | RPO and RTO are BLOCKED OPERATOR_INPUT — not yet established | `PRD_TRACEABILITY.md:271` |
| `PRD_DELIVERY_MAP.md:55` | "`BR-HUB-010` remains `BLOCKED_OPERATOR_INPUT` for provider/account, retention, RPO/RTO, and key custody." | `PRD_DELIVERY_MAP.md:55` |
| `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-wo-0001-domain-triage-reply.md:20` | Triage says "Operational | Live" but does not cite any RPO/RTO measurement | `wo-0001-domain-triage-reply.md` |
| `BR-AUD-002/report.md:335` | "Database backup configuration UNKNOWN — no backup script in staged source" | `BR-AUD-002/report.md` |
| `BR-AUD-005/report.md:168-265` | "Backup Strategy NOT FOUND. Backup Destination NOT FOUND." | `BR-AUD-005/report.md` |

**What this means:** the stated targets in PRD v3 are design intentions, not measurements. The PRD itself explicitly says not to claim 15-minute RPO unless WAL shipping is actually implemented. No actual interval has been documented because no backup configuration has been confirmed, no backup has been taken and measured, and no restore drill has been conducted to measure RTO. The operator-input items blocking RPO/RTO establishment have not been supplied.

---

## 4. Where Does the Ledger Conflict Originate?

### Finding: CONFLICT IS OPEN — two readings with different evidentiary standards, not a factual contradiction

**Reading A — the ledger:**

- Filed in: `PRD_TRACEABILITY.md:263-274`, `PRD_DELIVERY_MAP.md:55`
- Standard: accepted live evidence, drill records, measured RPO/RTO, authorized restore
- Conclusion: UNKNOWN, BLOCKED OPERATOR_INPUT (`BR-HUB-010` for provider/account, retention, RPO/RTO, key custody)
- Evidence: designs exist (BR-BACKUP-001, BR-OPS-001, BR-HUB-001), synthetic harness exists (BR-OPS-002), no live encrypted off-host provider assignment, no per-project target proof, no real restore, no measured RPO/RTO, no required DR drill evidence accepted

**Reading B — the worker-reported triage:**

- Filed in: `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-wo-0001-domain-triage-reply.md:20`
- Standard: operational self-report ("Backup / DR | Namecheap encrypted transfers | Operational | Live")
- Evidence cited: none (no log, manifest, checksum, transfer record, job schedule, or target assignment)
- Follow-up: same triage says `backup-dr` lane is idle

**Origin of the conflict:** these are not two measurements of the same artifact with contradictory results. The ledger applies a high evidentiary standard (accepted evidence, drill records, measurements). The triage applies a low standard (operational self-report with no supporting evidence). The triage does not disprove the ledger, and the ledger does not disprove the triage — they are answering different questions.

**Cross-cutting audit correctly left this OPEN** (`2026-10-18-audit-cross-cutting.md:71-98`):

> "Contrasting reading: the 2026-10-15 Hetz triage says 'Backup / DR | Namecheap encrypted transfers | Operational | Live'. This is a worker-reported state, but that row supplies no transfer run, project/target, manifest, checksum, restore result, RPO/RTO, or drill link; the same report labels the lane idle. This conflicts with the ledger's 'no accepted live encrypted off-host' reading. OPEN; neither reading is silently selected."

**Second conflict layer:** the `backup-dr` secondmate home was audited as absent (GONE, not misregistered) as of 2026-10-15 (`2026-10-15-two-audits-retracting-my-own-claims.md:44`), which means the lane nominally responsible for operating and evidencing backup/DR was not running at the measurement time. The triage's "lane idle" is consistent with a home that exists but is idle, but the audit found the home itself absent.

---

## 5. Per-Project Backup Status

| Project | PRD v3 target | Gate-B confirmation | Audit finding | Status |
|---|---|---|---|---|
| Core Distro | Namecheap per project | `core-distro.com` → `bdn-dr-core-01` (confirmed 2/4) | "Backup UNKNOWN" (`BR-AUD-002:242,316`) | UNKNOWN — target name confirmed, actual backup/restore not evidenced |
| Elevate Life Sci | Namecheap per project | NOT Namecheap — on Hostinger+Cloudflare | "Backup NOT evidenced" (`BR-AUD-002:316`) | UNKNOWN — PRD assumes Namecheap, but Elevate runs on Hostinger; DR for Elevate is unaddressed |
| Whoosh Performance | Namecheap per project | NOT confirmed — parked with no Namecheap service | "Backup NOT evidenced" (`PRD_TRACEABILITY.md`) | UNKNOWN — parked, no service to back up yet |
| CBD-Data | Namecheap per project | `cbd-data.com` → `bdn-dr-cbddata-01` (confirmed 2/4) | "Backup Strategy NOT FOUND. Restore Procedures NOT FOUND." (`BR-AUD-005:168,248`) | UNKNOWN — target name confirmed, actual backup/restore not evidenced |

**Elevate DR gap:** PRD v3 assigns Elevate to a Namecheap DR target, but the triage found Elevate running on Hostinger+Cloudflare, not Namecheap. The DR assignment for Elevate has not been reconciled with its actual hosting.

---

## 6. What Evidence Would Settle the Conflict

To move from UNKNOWN, the following must be produced:

| Item | Evidence required | Who can produce |
|---|---|---|
| Backup job existence | Sanitized job configuration (cron/systemd timer) with schedule, source paths, destination, and encryption method | `backup-dr` secondmate or operator with host access |
| Transfer evidence | Recent transfer log, manifest, checksum, size, and encryption metadata for each project | Same |
| Target assignment proof | Namecheap account credentials (sanitized) confirming per-project isolation for all four projects | Operator |
| Actual RPO | Timestamp of last successful backup + measurement of data loss window for a representative dataset | `backup-dr` lane |
| Actual RTO | Start/end time from a real restore drill, including time to verify schema, row counts, and file integrity | `backup-dr` lane with operator authorization |
| DR drill record | PRD v3 §16.5 format: start/end time, participants, backup used, release used, RPO achieved, RTO achieved, failures, manual steps, missing documentation, corrective actions | `backup-dr` lane with operator authorization |
| `backup-dr` secondmate home | Home must exist and be operational to own this work | Operator |

---

## 7. Summary

| Question | Answer | Confidence |
|---|---|---|
| Do live backup jobs exist? | UNKNOWN — triage says "Operational," audits found no backup scripts or configurations | Low |
| Have any restores been executed and verified? | NOT ESTABLISHED — no drill record, no restore log, no verification output found in any source | None |
| Are RPO/RTO measured? | NO — targets are aspirational; no measurement exists; blocked on operator input | None |
| Where does the ledger conflict originate? | Two different evidentiary standards (ledger = high threshold, triage = low threshold); not a factual contradiction about a single artifact | Confirmed |
| Is the backup/DR capability operational? | CANNOT DETERMINE — `backup-dr` lane home was absent as of 2026-10-15; triage reports "live transfers" without supporting evidence | None |

**The audit explicitly does NOT conclude that no backups exist.** The triage's "Operational | Live" reading is recorded and not dismissed. The audit concludes that the evidence to confirm backups exist, are configured correctly, are encrypted, are transferring to isolated per-project targets, and have been verified through restore testing is absent from the inspected sources. The ledger conflict is OPEN.

---

## 8. Sources Consulted

1. `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` — PRD v3.0, 2026-08-04
2. `docs/system-context/PRD_TRACEABILITY.md` — ledger row `backup-dr` lines 263-274
3. `docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md` — delivery map lines 11, 33, 53-56, 131
4. `data/audit/2026-10-18-audit-cross-cutting.md` — cross-cutting backup/DR conflict analysis
5. `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-wo-0001-domain-triage-reply.md` — triage row for backup/DR
6. `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-wo-0003-registry-and-gates-reply.md` — gate-B results, Namecheap target confirmations
7. `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-15-two-audits-retracting-my-own-claims.md` — `backup-dr` home absent audit
8. `data/BR-AUD-002/report.md` — Core Distro audit findings on backup
9. `data/BR-AUD-005/report.md` — CBD-Data audit findings on backup
10. `data/BR-INV-001/report.md` — inventory audit, Namecheap DR assignment gap
11. `data/backup-dr/brief.md` — `backup-dr` secondmate charter
12. `data/core-staging-publish-ready/restore-plan.md` — Core staging restore plan (plan, not execution)
13. `bin/restore-checkpoint.sh` — development checkpoint script (not DR restore)
14. `data/dead-lane-triage-20261014/restore-manifest.tsv` — lane registry, not restore evidence
