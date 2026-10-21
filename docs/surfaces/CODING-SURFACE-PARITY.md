# Coding-surface parity

This document is the single owner of the cross-surface parity contract.
It distinguishes invariants from deliberate local differences so a missing prerequisite is repaired before dispatch rather than discovered as a lane-wide outage.
Owning implementation details remain in the linked files and are not copied here.

## Scope and vocabulary

A coding surface is an independently operated machine that runs coding agents, whether it is a controller or a dispatch target.
The fleet is exactly four coding surfaces: Controller, HD2, Hetz, and KVM1.
`/root/agent-work/surfaces.conf` is the single authoritative surface roster, including aliases, target-local expected paths, and dispatch eligibility; any other file that names a surface MUST agree with it.
The alias map is `hd2stack` = HD2, `brandon-compute` = Hetz, and `elevatesVPS` plus deprecated `animovps` = KVM1.
Hetz is also called `HETZ FIRSTMATE` in the Herdr machine roster and appears as a secondmate registry entry; those labels do not create extra surfaces.
KVM1 is a coding surface and eligible dispatch target; its `Firstmate` home is `/root/firstmate`.
The roster began from an unverified measurement that incorrectly reported KVM1 had no Firstmate home because it probed a Controller-relative path.
The roster's per-surface home paths MUST be used instead of assuming one Controller path across hosts.
`data/surface-parity-20261015/VERIFIED-INFRA.md` is measurement evidence, not an override of operator-approved fleet membership; its earlier KVM1-excluded wording is superseded by the current four-surface ruling.
A capability marked MUST is a pre-dispatch invariant unless a documented narrow exception applies.
A legitimate difference is not permission to omit the capability entirely.

## Runtime and model routing

Every surface MUST have its approved local agent launcher, runtime dependencies, and a documented launch path that selects a model supported by that launcher.
Valid model IDs come from that runtime's current authoritative catalog; a model name valid in one client is not assumed valid in another.
Runtime-specific launchers and supported model catalogs MAY differ by surface because provider and client support differ.
Dispatch policy, capability class, authority gates, and the prohibition on silent fallback MUST be consistent with `/root/AGENTS.md` and `/root/docs/agent-policy/HERDR_AGENT_ROUTING.md`.
Quota and credential availability MUST be queried on the target host and at the provider/model granularity the vendor exposes before dispatch; Controller quota is not evidence of target-host quota.
A missing CLI, unsupported model, or unusable target-local credential is reported as a concrete preflight failure, never hidden by switching runtimes or hosts.
The surface-local launcher implementation is owned by the runtime adapter and its documentation; this spec does not prescribe one executable for all hosts.

## Skill trust and drift

Every surface MUST have its own explicit trust baseline and a locally runnable `skill-drift-check`.
The baseline path is `/root/agent-work/skill-integrity/manifest.tsv` on surfaces using the standard install layout; a different path is permitted only when the target-local config and audit roster name it explicitly.
A baseline is created only from an approved installed set after read-only review, not by accepting the current machine state blindly.
The normal loop is: run the read-only `--review-subtree <absolute-path>`, inspect the scoped old/new inventory and resulting review token, deliberately run `--reconcile-subtree <absolute-path> <review-token>` for that exact subtree, then run `--check` and verify the baseline delta is scoped.
The existing implementation and backup mechanics are owned by `/root/bin/skill-drift-check`.
A reconcile records the reviewed file hashes as trusted inventory; it does NOT authorize executing commands, prompts, scripts, or instructions described by those files.
Full-manifest refresh remains a separate, explicit operation and is not the routine upstream-update path.

## lean-ctx

Every surface MUST have `lean-ctx` installed and reachable to the local agent toolchain.
Each host MUST retain its own command allowlist and safety configuration; parity means consistent safety intent, not byte-identical local paths or identical allowlist lengths.
When a required read-only command is missing, add only that exact command through the target-local documented admission process, test it there, and record the resulting count in audit output.
Do not admit a general shell, command interpreter, language interpreter, `eval`-style wrapper, or a wrapper that accepts arbitrary source or command strings.
In particular, `sh`, `bash`, `zsh`, `python`, `python3`, `perl`, `ruby`, `node`, `eval`, and interpreter-launching aliases or wrappers MUST NEVER be admitted as general allowed commands.
The host-specific lean-ctx policy and setup guide own syntax and storage; this document does not copy those settings.

## Firstmate and agent homes

Every coding surface MUST provide a reachable Firstmate home with its instruction and tool entrypoints when Firstmate tasks are supported there.
The home layout and per-home private state are owned by `/root/agent-work/deightonllm-firstmate/docs/configuration.md`.
The primary Firstmate process, persistent secondmate registration, and transient task agent endpoints are distinct roles and MUST NOT be conflated in an audit or roster.
A surface that launches agents but has no Firstmate home is nonconformant until explicitly documented as a non-Firstmate execution-only surface and excluded from Firstmate dispatch.
Runtime process managers and the number of active agents MAY differ by host capacity; no idle agent process is required merely for conformance.

## Herdr registration and dispatch eligibility

Each surface intended as a Herdr dispatch target MUST have a uniquely identified Herdr machine registration visible from the Controller's `herdr machine list` view.
The Controller is the orchestrator and local runtime; its local registration is not a remote dispatch-target registration requirement.
Machine labels and endpoint addresses MAY differ, but each configured label MUST resolve to the intended target and remain unique.
Only rows with `dispatch_target=true` are eligible for dispatch, and only after the live machine identity and local prerequisites are verified.
A Herdr registration does not imply authorization to dispatch or mutate that host.
The live roster is recorded in `/root/agent-work/surfaces.conf` and audited by `/root/bin/surface-parity-audit`.

## Communication contract

Cross-home communication MUST preserve both sides of the durable file transport: the sender's report-drop directory and the receiver's mirrored report directory passed to `bin/fm-comms-ingest.sh scan`.
The two per-surface transport inbox paths are declared in the roster and MUST be probed on that surface, not inferred from Controller-local `state/` directories.
Hetz uses `/home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/to-brandon-compute/` and `/home/hd2admin/controller-replies/`.
A roster value of `-` means no comms path is documented for that surface and the audit reports `NOT_APPLICABLE`, not failure.
A request's correlation ID MUST accompany its reply across transport and appear in the parent status/report record.
Delivery on disk, successful receipt, and substantive handled/acknowledged response are three distinct facts; receipt never implies content review, and a bare receipt is not a substantive response.
The owning contracts are `bin/fm-pending-reply-lib.sh`, `bin/fm-secondmate-report.sh`, and `bin/fm-comms-ingest.sh`.
A supported immediate-notification transport is the preferred behavior being built: deliver the file, notify the receiver promptly, and preserve the durable correlation/receipt so restart recovery is reliable.
Periodic polling is demoted to bounded recovery fallback for missed notifications, not the normal communication path.
The notifier MUST NOT claim delivery, receipt, or substantive acknowledgment without that respective evidence.

## Fresh-agent baseline and prompt hygiene

Every fresh-agent baseline manifest path MUST be readable on the target surface before dispatch; a Controller-only path is not a valid target dependency.
The current known defect is that `bin/fm-brief.sh` and `bin/fm-session-start.sh` embed `/root/AGENTS.md`, while the real target policy copies are in the warehouse as `AGENTS.md` (66 KB) and `AGENT-POLICY.md` (24 KB).
The exact manifest and policy-file owners MUST resolve that path mismatch in a separate implementation lane; this audit records readability without changing the baseline or those scripts.
Prompt and report content MUST NOT inline raw long hexadecimal digests or credential-shaped `NAME=<value>` assignments.
Refer to digests by their artifact path or descriptive name and label tokens descriptively rather than writing assignment-shaped text.
This avoids secret-scanner false positives caused by mission-state files storing prompts verbatim; it does not weaken credential detection or authorize hiding actual credentials. Controller enforces this prompt-only boundary with `/root/.pi/agent/extensions/41-dispatch-prompt-hygiene.ts`; any deliberate per-call acknowledgement is surfaced as an audit notice.

## Explicitly allowed differences and exclusions

Operating system, CPU/RAM, filesystem layout, local usernames, runtime installation mechanism, provider catalogs, model availability, quota, credentials, Herdr machine label, and command allowlist length MAY differ by surface.
Those differences are acceptable only when the surface remains auditable and its local adapter supplies the equivalent safety behavior.
The number of concurrently running workers MAY vary with measured capacity and the applicable host-specific load shield.
This contract does not require identical provider credentials, model catalogs, application deployments, SSH topology, or byte-for-byte host configuration.
Recorded operator follow-up for later: KVM1 may mirror Hetz's model/provider account setup for equivalent client-focused agent work; this note does not authorize implementing or planning that work in this lane.
Mirroring means provisioning equivalent independently authorized provider access on KVM1, never copying or transferring Hetz credential files or keys.
Credential transfer between surfaces remains prohibited without separate explicit operator approval.
This lane does not install tools, alter trust baselines, change lean-ctx policy, edit Herdr registration, modify the fresh-agent baseline, change any running service, or mutate remote hosts.
Client code, production data, billing, DNS, credentials, provider settings, and deployment policy are out of scope.

## Conformance checklist

Run `/root/bin/surface-parity-audit` from the Controller and preserve its table as evidence.
The audit MUST use the Controller's ordinary SSH aliases, BatchMode, an explicit timeout, `StrictHostKeyChecking=accept-new`, and the configured known-hosts file; it MUST audit Controller locally rather than SSH back to itself.
Every measured fact MUST print its method, including login-shell PATH lookup and direct target paths from the roster.
A fact measured only by PATH lookup MUST NOT be reported as absent; report unresolved PATH separately from direct-path evidence.
The audit tool's own accuracy is a conformance requirement: a check that cannot distinguish real nonconformance from its own measurement or transport failure MUST NOT be used to block work.
Confirm every roster entry has reachable expected FQDN and SSH host identity.
Confirm each surface's trust manifest exists, is readable, and has a nonzero row count.
Confirm each rostered drift-checker path advertises `--review-subtree` and `--reconcile-subtree`.
Confirm `lean-ctx` is installed at the target path, reachable in the explicit login-shell PATH, and reports a healthy status.
Report lean-ctx versions and additive admission counts as observations; do not fail conformance because those values differ unless a version pin is explicitly approved.
Confirm each coding surface's rostered Firstmate home and required entrypoints.
Confirm every dispatch target appears under its intended label in the Controller's Herdr machine listing.
Confirm both parent comms inbox paths are reachable and the sender/receiver report-drop mirror is documented for each remote relationship.
Confirm each target can read every path in its fresh-agent baseline manifest, including policy copies.
For each upstream skill delta, perform review, deliberate scoped reconcile, and post-reconcile check; verify no unrelated baseline rows changed.
Mark a surface PASS only when every required check passes; otherwise record the exact missing or unreachable check and keep it out of dispatch until repaired.

## Enforcement plan

The existing fail-closed dispatch preflight in `/root/bin/fm-spawn.sh` is the enforcement point to consult the latest successful `/root/bin/surface-parity-audit` result before creating a task endpoint on a `dispatch_target=true` host.
The hook must validate that the audit result is fresh, names the exact selected target, and has a PASS state; missing, stale, malformed, DEGRADED, or ABSENT evidence blocks only that target's dispatch.
The operator-visible failure must name the surface, identify every failed check, state that no task was launched, and give the audit command and concrete remediation pointer without printing secret values.
The Controller's local audit itself may warn rather than block its own existing coordination session; the gate applies to new task dispatch to a target.
Routine upstream version updates MUST NOT hard-block dispatch after the changed subtree has passed `--review-subtree`, deliberate scoped `--reconcile-subtree`, and post-reconcile `--check` under the existing documented review flow.
An actual unreviewed drift, unsafe collision, missing baseline, missing checker, or other required capability failure remains blocking.
No enforcement hook is implemented by this documentation/audit lane.

## Binding fleet membership at dispatch

`/root/agent-work/surfaces.conf` is the single source of truth for fleet surface membership and aliases; do not maintain a second surface list.
`/root/bin/surface-conformance-gate` makes that roster binding at dispatch: it rejects unknown targets and blocks a known target unless its required audit checks conform.
`/root/bin/herdr-dispatch-preflight` runs the gate before admitting either a remote machine label or the local Controller, alongside its other admission checks.
To add a surface, verify its identity and target-local paths, add the reviewed row to the canonical roster, and require a passing `/root/bin/surface-parity-audit --config /root/agent-work/surfaces.conf` before dispatch.
To retire one, first stop routing new work to it through its reviewed roster entry change, then remove or mark that same entry retired under the roster's documented schema; never remove or rename it only in a parallel configuration.
A fact observed only through a `PATH` lookup must never be reported as absence: probe the roster-declared explicit path or login-shell environment and record which method established the result.
