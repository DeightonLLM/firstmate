# Reliability lanes re-derived against current state

**Reviewed:** 2026-10-13  
**Scope:** `reliability-permission-20261012`, `reliability-receipt-20261012`, `reliability-reporting-20261012`, `reliability-routing-20261012`, and `reliability-controls-docs-20261012`. This is a read-only reassessment; no settings, configuration, source, backlog, or secondmate home was changed. No credentials were read, agents dispatched, or tests executed.

## Executive result

Three bounded items genuinely remain: the authorized permission repair and its one-time verification; a focused correlated-nonterminal reporting contract test; and the already-authorized, not-yet-executed scout-settings rollback. The old M2.7 quota-cutoff work is moot because the model family is retired for new work. The receipt lane's broken-comms premise is satisfied by the actual bidirectional exchange, while the reporting lane's distinct correlated-completion question is not erased by that transport fix. The controls/documentation map already exists and is owned by the documented source owners, so a duplicate map or shared-doc rewrite is moot.

**Important correction to the intake description:** the five entries are not currently empty-body placeholders. The primary backlog contains substantial embedded instructions and parked holds at `data/backlog.md:104`, `:161`, `:218`, `:275`, and `:332`. The five were explicitly parked, with no automatic relaunch, by the consolidation record (`data/reliability-consolidation-20261013/CURRENT.md:6-10`). This report does not rewrite those records.

## Evidence reviewed

- Current primary backlog rows and the five lane reports under `data/reliability-{permission,receipt,reporting,routing,controls-docs}-20261012/`.
- Current captain routing/communications record (`data/captain.md:9`, `:17-19`, `:23`, `:33-39`) and registered domain roster (`data/secondmates.md:1-8`).
- Same-day exact inbound/outbound Controller messages: `BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-13-comms-fixed-retirement-and-secondmate-guidance.md`, `.../to-brandon-compute/2026-10-13-controller-durable-recovery-and-cleanup-handoff.md`, and the corresponding outbound `.../from-brandon-compute/2026-10-13-brandon-gate-reply-and-upstream-blockers.md`.
- Current consolidation summary and the scoped scout-tracker evidence at `data/reliability-consolidation-20261013/CURRENT.md:13-16` and `scout-tracker-proof-release.md:3-13`.
- The decision-hold lifecycle skill and its owner script. A completion command was not run because it writes the originating home’s task metadata (and potentially status/backlog); this assignment authorizes only this report and the prescribed status file outside the isolated worktree.

The isolated worktree is `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/11/kun-agent-workspace`, distinct from the primary `/home/hd2admin/kun-agent-workspace`; `git status --short --branch` returned `## HEAD (no branch)`. A read-only directory lookup confirmed the actual Controller inbox and outbound directories under the primary repository. One unrelated batched `ctx_shell` query was refused by the command allowlist before execution; it was not retried or bypassed.

## 1. `reliability-permission-20261012` — **REMAINS**

**Original intent.** Collect the original sanitized helper-denial evidence and identify the exact permission-policy owner for the already-existing repair; do not recreate the denial or diagnose/modify policy independently. The backlog names that intent at `data/backlog.md:275`; the old report says the specified plan did not contain the original refusal, exact denied command, or exact rule location (`data/reliability-permission-20261012/report.md:9-31`).

**Evidence today.** The missing *owner/action route* is no longer unknown: the actual Controller handoff specifies a narrow permission repair for the denied helpers, a backup and config validation, a fresh session, and one authorized rerun, explicitly forbidding a blanket `bash` allowance (`BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-13-controller-durable-recovery-and-cleanup-handoff.md:57-78`). That route is not evidence the repair or rerun has happened. The consolidation still records unfinished work and no admitted shared implementation (`data/reliability-consolidation-20261013/CURRENT.md:13-16`).

**Verdict.** REMAINS. The uncertainty about who owns the repair is resolved; the repair/verification work and original refusal evidence are not. Do not revive the parked scout or retry a denied command outside the Controller-authorized sequence.

**Scoped ticket (existing owner; no duplicate permission mechanism).** In a fresh authorized session, the existing permission owner must: (1) preserve the current lean-ctx config; (2) add only the exact helper paths enumerated in the Controller handoff, never blanket `bash`; (3) run the config’s own validator; (4) use the fresh session and run the previously denied helper once; (5) retain sanitized raw output identifying the actual result and distinguish it from Controller acknowledgement. Acceptance: the exact narrow allowlist diff and pre-change backup are retained; validation succeeds; the one authorized attempt has an attributable result; any repeated/permanent denial stops without a second try; no credential contents, broad permission expansion, alternate-tool bypass, or false completion is reported. If the original refusal cannot be recovered, say so rather than reconstructing it.

## 2. `reliability-receipt-20261012` — **SATISFIED**

**Original intent.** Verify that Controller replies can actually be received and accepted, rather than treating a published file or an unrelated mirror as proof (`data/backlog.md:332`; old evidence and acceptance matrix at `data/reliability-receipt-20261012/report.md:9-25`).

**Evidence today.** The exact inbound Controller message says both outbound locations are pulled and ingested every five minutes and the outbox pushes to the real inbox (`BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-13-comms-fixed-retirement-and-secondmate-guidance.md:6-14`). The later exact inbound durable-recovery reply is present in the named inbox and says it was published at the exact requested `controller-replies` path and mirrored into the inbox (`.../to-brandon-compute/2026-10-13-controller-durable-recovery-and-cleanup-handoff.md:1-8`). The outbound reply explicitly acknowledges receipt/read of the inbound messages, calls the two directions verified, and records the correlated gate as resolved (`.../from-brandon-compute/2026-10-13-brandon-gate-reply-and-upstream-blockers.md:1-5`, `:27-30`). This is an actual two-way exchange, not merely the old local sender’s fake-SSH test.

**Verdict.** SATISFIED for Controller transport/receipt. This does **not** prove every secondmate report, unrelated worker pickup, or substantive work completion; those remain separate lifecycle facts. No receipt-repair ticket is justified from the old broken-comms premise.

## 3. `reliability-reporting-20261012` — **REMAINS**

**Original intent.** Preserve correlation, distinguish delivery from processing and authentic worker reporting, and allow only one recovery attempt (`data/backlog.md:218`; old source/test review at `data/reliability-reporting-20261012/report.md:9-22`).

**Evidence today.** Bidirectional Controller comms and a received acknowledgement are now demonstrated (receipt evidence above), so the earlier inability to get a Controller reply is not evidence that the pending-reply protocol is broken. The existing implementation already has a correlation matcher, delivery checks, one-recovery limit, and tests covering normal correlated reports, idempotence, wrong/stale tokens, and duplicate recovery (`data/reliability-reporting-20261012/report.md:9-22`, with source/test references there to `bin/fm-pending-reply-lib.sh:393-503` and `tests/fm-pending-reply.test.sh:99-165, 235-335, 483-504`). However, the same report identifies a concrete untested semantic boundary: any line containing the delivered correlation can match, while tests only establish that **uncorrelated** `working`/`done` lines are ignored (`report.md:16-22`). The prior focused test command never ran because the shell allowlist rejected it (`report.md:24-27`). Transport success must not be substituted for a substantive worker result; the durable-recovery plan likewise requires those states be distinct (`data/durable-recovery-20261013/plan.md:1-8`).

**Verdict.** REMAINS, narrowly. The broad comms/transport diagnosis is moot; the correlated nonterminal-versus-terminal reporting boundary is not proven and is required by the accepted lifecycle contract.

**Scoped ticket (existing `fm-pending-reply-lib.sh` owner).** Add an isolated behavioral fixture proving that a delivered request followed only by a correlated nonterminal/empty status does not resolve as substantive completion, while the accepted substantive correlated terminal report does; preserve the existing one-recovery and idempotency behavior. Run `bash tests/fm-pending-reply.test.sh` through an authorized execution path and retain raw output/current-head identity. Change the matcher/resolver only if the behavioral assertion demonstrates the defect, and only through the existing owner/admission path. Do not create another transport, infer a new authentication mechanism, retry denied helper commands, or claim the previously blocked tests passed. The plan’s existing helper-permission repair is a prerequisite if the required test/helper remains inaccessible.

## 4. `reliability-routing-20261012` — **REMAINS**

**Original intent.** Re-derive supported model/profile routing and actual enforcement gaps, including the old M2.7 >50% Highspeed preference and stale M3 tuple; do not benchmark, inspect auth, or change live config (`data/backlog.md:161`; old routing findings at `data/reliability-routing-20261012/report.md:9-41`).

**Evidence today.** Captain’s current record says native `minimax/MiniMax-M3.1-Flash-Preview` is the default doing-work model (`data/captain.md:17`), M2.5/M2.7 are retired and forbidden for new work (`:19`), and the M2.7 Highspeed cutoff has been withdrawn because Highspeed itself is retired (`:39`). The current three-role record pins the reviewer to M3.1 high and says the scout tool set includes `subagent` (`:23`, `:33-36`). The consolidation evidence says the scout override was applied and validated while preserving the reviewer; it also explicitly says no rollback had yet been performed (`data/reliability-consolidation-20261013/CURRENT.md:13-15`; `scout-tracker-proof-release.md:3-13`). The actual Controller message authorizes the narrow rollback: back up current settings, remove **only** `subagents.agentOverrides.scout`, preserve `subagentOnlyExtensions` and `pi-codex-fast`, validate JSON, and verify effective config (`.../to-brandon-compute/2026-10-13-comms-fixed-retirement-and-secondmate-guidance.md:31-45`). This task’s captain instruction reiterates that exact scope and states it has not been executed. A historical pre-rollback JSON snapshot is stale and is not evidence of today’s live values; do not restore it wholesale.

**Verdict.** REMAINS for the authorized scout-settings rollback only. The old M2.7 cutoff and stale-family routing work are MOOT; do not make a new ticket for them or select any retired family.

**Scoped ticket (authorized primary owner; not executed here).** Using the Controller-approved plain host shell route, first inspect the current target field and preserve a timestamped backup. Remove only `subagents.agentOverrides.scout`; leave every other setting byte/semantically unchanged, especially reviewer model/effort, `subagentOnlyExtensions`, default M3.1 registration, and `pi-codex-fast`. Validate the JSON, record before/after scoped diffs and command output, reload only the affected Pi session under the approved route, and verify the effective scout override is absent while the reviewer remains M3.1 high. Do not restore an old whole-file snapshot, touch unrelated settings, or claim rollback until effective state is verified.

## 5. `reliability-controls-docs-20261012` — **SATISFIED**

**Original intent.** Map each reliability outcome to its single authoritative configuration, enforcement, runtime-proof and documentation owner, and draft a bounded recovery runbook (`data/backlog.md:104`).

**Evidence today.** The existing scout report contains the requested six-row authoritative owner map and recovery steps (`data/reliability-controls-docs-20261012/report.md:3-25`). It explicitly distinguishes documented ownership from proven enforcement and lists the responsible current config, scripts, tests, skills and docs. The primary always-loaded instructions and configuration docs remain the contract owners; the report correctly leaves Controller-owned comms/permission details to their source owners (`report.md:3-14, 20-25`). The registered roster has seven named roles with per-role scopes (`data/secondmates.md:1-8`); the same-day outbound Controller reply reports seven persistent secondmates live/idle, while also naming access limitations (`.../from-brandon-compute/2026-10-13-brandon-gate-reply-and-upstream-blockers.md:30-34`). I did not inspect secondmate homes or probe their endpoints, as prohibited.

**Verdict.** SATISFIED for the controls/documentation map. The seven entries are registered and scoped; the direct live claim is the same-day correlated fleet statement, not an independent endpoint probe. Any actual shared documentation edits remain with the Controller’s documented ownership, not a duplicate controls-docs lane. No further map/runbook ticket is justified.

## Decision-hold completion

I read and followed `.agents/skills/decision-hold-lifecycle/SKILL.md`. Semantic inventory of this report found **no unresolved captain choice**: the remaining scopes are concrete work criteria, and the scout rollback is already explicitly authorized. The skill’s shared `complete --none` attestation was **not run**: `bin/fm-decision-hold.sh` documents that `complete` records the reviewed inventory in the originating task metadata/status (`bin/fm-decision-hold.sh:1-31`, `:205-258`), which is outside this task’s permitted write set (only the report and designated status file may be written outside the worktree). The originating firstmate must run that completion attestation; until then this report is delivered but the shared completion gate is not passed.

## Commands and non-actions

- Isolation/status: `pwd; git status --short --branch; git rev-parse --show-toplevel` — isolated root above; clean detached HEAD.
- Re-read exact current communication paths and records through lean-ctx; confirmed the named inbound and outbound directories and message files exist.
- Read-only searches/read operations only for the named backlog rows, reports, captain routing record, secondmate registry, Controller handoffs and completion-gate owner.
- No settings/config/source/backlog writes; no secondmate-home access; no credentials; no test execution; no worker dispatch; no rollback or permission change. The sole shell allowlist refusal was not retried.

**Recommendation:** keep only the three acceptance-scoped remaining items above with their existing owners. Treat Controller receipt as working, remove the retired M2.7 cutoff work, do not duplicate controls documentation, and keep the five original backlog items parked until their owners apply the scoped results and the originating completion gate is recorded.
