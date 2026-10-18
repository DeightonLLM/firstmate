# Secondmate file-access root-cause report

**Scope:** read-only filesystem and source inspection. No secondmate home was written or changed, and `tasks-axi` was not run. The only writes were this report and the task status event.

## Findings

There are separate failures, not one shared “secondmates cannot read files” cause:

1. **Six registry home paths are stale and absent now.** Only `system-ops` has a present registered secondmate home and its seeded `data/charter.md` exists. For the other six, the registered/last-start home path is absent, so their local charter and local warehouse targets cannot exist at that path. This directly explains current not-found results, including Whoosh’s local charter report.
2. **The primary warehouse and backup expertise file are real but are not in secondmate homes.** `warehouse` and `data/domain-expertise-20261013` exist in the primary home. They are not seeded into the separate secondmate `FM_HOME`; a request to read them by the primary absolute path is an outside-home request.
3. **The tool sandbox is an independent root restriction.** I reproduced the exact `ctx_read` refusal for an authorized, existing path outside this task’s worktree. `--worklocation` changes brief text/location assertion; it does not change the lean-ctx project root.
4. **The shell allowlist is a separate host/runtime restriction.** The active lean-ctx config lists `fm-tasks-axi.sh`, but not the `tasks-axi` command. The command was not run.

## Per-home filesystem results

The registered paths are from the primary `data/secondmates.md`; the last-start locations are corroborated by the corresponding session-start transcript paths under `~/.pi/agent/sessions/`. Those six paths no longer exist in the filesystem now, so they are historical/effective-at-last-start locations, not current live `FM_HOME` values. `fm-session-start.sh:95-98` sets default `FM_HOME` to the home/code root when no override is supplied.

| Secondmate | Registered / last recorded `FM_HOME` | Home exists now? | Reported or relevant target checked inside that home | Primary target check |
|---|---|---:|---|---|
| system-ops | `/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/4/kun-agent-workspace` | Yes; `.fm-secondmate-home` marker present | `data/charter.md`: **exists**; `warehouse`: missing | — |
| elevate-p0-repair | `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/6/kun-agent-workspace` | **No** | `data/charter.md`, `warehouse`: missing because the registered home path itself is absent | Primary `warehouse`: exists |
| core-ops | `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/2/kun-agent-workspace` | **No** | `data/charter.md`, `warehouse`: missing because the registered home path itself is absent | — |
| whoosh-ops | `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/3/kun-agent-workspace` | **No** | `data/charter.md`: missing because the registered home path itself is absent | — |
| cbddata-ops | `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/5/kun-agent-workspace` | **No** | `data/charter.md`, `warehouse`: missing because the registered home path itself is absent | — |
| hetzner-compute | `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/7/kun-agent-workspace` | **No** | `data/charter.md`, `warehouse`: missing because the registered home path itself is absent | Primary `warehouse`: exists |
| backup-dr | `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/8/kun-agent-workspace` | **No** | `data/charter.md`, `data/domain-expertise-20261013`, `warehouse`: missing because the registered home path itself is absent | Primary `data/domain-expertise-20261013` and `warehouse`: both exist |

For each absent path above, the present-day `test -d` check returned `MISSING`; a session-start transcript records that same path as its home at its last recorded launch. These results do **not** prove whether the old homes were intentionally retired; they prove that the registry currently points to absent directories. There is no basis to call those six homes currently healthy. `system-ops` is fine for its own charter; that does not make primary-only files available inside it.

### Quoted command output

Filesystem checks (selected exact lines):

```text
[system-ops] FM_HOME candidate=/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/4/kun-agent-workspace
FM_HOME directory: EXISTS
EXISTS data/charter.md
MISSING warehouse

[elevate-p0-repair] FM_HOME candidate=/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/6/kun-agent-workspace
FM_HOME directory: MISSING
MISSING data/charter.md
MISSING warehouse

[whoosh-ops] FM_HOME candidate=/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/3/kun-agent-workspace
FM_HOME directory: MISSING
MISSING data/charter.md

[backup-dr] FM_HOME candidate=/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/8/kun-agent-workspace
FM_HOME directory: MISSING
MISSING data/charter.md
MISSING data/domain-expertise-20261013
MISSING warehouse

[primary] root warehouse and expertise targets
EXISTS /home/hd2admin/kun-agent-workspace/warehouse
EXISTS /home/hd2admin/kun-agent-workspace/data/domain-expertise-20261013

--- secondmate home markers ---
/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/4/kun-agent-workspace/.fm-secondmate-home
```

The path-sandbox refusal was independently reproduced by `ctx_read` on a required external policy file:

```text
path: path escapes project root: /home/hd2admin/kun-agent-workspace/AGENT-POLICY.md (root: /home/hd2admin/.treehouse/kun-agent-workspace-46aafc/23/kun-agent-workspace). Access denied: outside active project (/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/23/kun-agent-workspace). To allow: open that project in a new window, or: LEAN_CTX_EXTRA_ROOTS=/home/hd2admin/kun-agent-workspace
```

That is an actual tool response, not a filesystem inference. A native filesystem read then succeeded, establishing that the target existed and the refusal was the tool’s project-root policy, not a missing file. Similar refusals occurred for the other external policy files and warehouse paths.

## Mechanisms and fix ownership

| Class | Mechanism and evidence | Owner / actionable fix |
|---|---|---|
| Stale/missing secondmate homes | `data/secondmates.md:1-8` records the home paths. `docs/secondmate-provisioning` says `home:` identifies the seeded directory with `data/charter.md` (`:28-29`). `bin/fm-home-seed.sh:5-20` specifies durable leased homes; `:411-416` acquires a lease; `:935` copies the charter; `:939` updates the registry. `bin/fm-session-start.sh:95-98` defaults `FM_HOME` to its home/code root. Current `test -d` and marker searches show six absent paths and only the `system-ops` marker. | **Firstmate lane.** The firstmate home/registry lifecycle owner should reconcile the six stale entries and re-provision or correctly retire them through `secondmate-provisioning`; do not merely alter a charter path or reuse a slot. This task made no repair. |
| Primary path is outside secondmate home | `bin/fm-home-seed.sh:289-337` validates operational directories and seeded leaf files as inside the home; the standard seeded directories are `data`, `state`, `config`, and `projects` (`:314-337`). The primary warehouse/expertise files exist only at the primary paths checked above. The secondmate charter registry does not grant those primary paths. | **Firstmate lane.** Route the request through the primary or provision an explicitly approved local copy through the secondmate-provisioning path. Do not treat an outside-home refusal as evidence the primary file is absent. |
| `ctx_read`/tool sandbox project-root refusal, including worklocation | Exact reproduced refusal above identifies `lean_ctx::tools::ctx_read`’s root as this task worktree. The refusal is independent of the `FM_HOME`/seeded home. `bin/fm-brief.sh:24-26` describes `--worklocation` as amending the brief’s location assertion; `:307-319` inserts only location instructions. It contains no sandbox-root grant. The lean-ctx implementation is a compiled external tool and its source file/line was not available in this checkout; the exact runtime diagnostic is the evidence for the enforcement point. | **Controller/harness owner.** Configure the tool’s allowed project roots/extra roots for authorized worklocations and secondmate homes, or use a runtime that permits those coordinates. Firstmate can write the brief but cannot change the live tool sandbox. |
| Shell command allowlist (`tasks-axi`) | Active `/home/hd2admin/.config/lean-ctx/config.toml:1-6` begins `shell_allowlist_extra` and lists `fm-tasks-axi.sh` at line 5, but does not list the `tasks-axi` executable. `HANDOFF.md:5` identifies this file as the lean-ctx configuration. `tasks-axi` was not invoked, per boundary. | **Controller/harness owner.** Add the specifically authorized executable/wrapper to the host’s lean-ctx allowlist. This is not a file-access-root problem and cannot be fixed by changing `FM_HOME` or `--worklocation`. |
| Firstmate Pi secondmate guard (not the observed path error) | `.pi/extensions/fm-secondmate-guard.ts:65-74` resolves the session home and marker; `:115-119` blocks only the `fm_watch_arm_pi` tool for a genuine secondmate home. It does not implement a general file-path denial. | **No fix indicated for these symptoms.** Do not conflate this single controller-seat guard with lean-ctx project-root or command allowlists. |

## Who is actually fine?

- `system-ops` is the only one of the seven whose current registered home exists and whose own `data/charter.md` is present. Its charter refusal would be transient or misdiagnosed **if it was reported as missing from that current home**; this inspection did not reproduce such a failure.
- `whoosh-ops`’s claimed `data/charter.md` is not present at its currently registered path because that entire path is absent. The not-found part is therefore consistent with present-day filesystem evidence; the separate `path may escape project root` wording is from the tool sandbox and does not establish that the charter exists.
- The other five project-lane homes are likewise absent at their registered paths now. Primary warehouse/expertise files exist, but their absence from a secondmate home is expected unless explicitly provisioned.
- The shell allowlist issue and sandbox-root issue remain distinct and are not explained by missing home files.

## Commands and limits

Read-only filesystem checks used `find`, `stat`, `realpath`, `test -d`, and `test -e` against the seven registered paths and the two named primary targets. Source/config inspection covered `data/secondmates.md`, `bin/fm-session-start.sh`, `bin/fm-home-seed.sh`, `bin/fm-brief.sh`, `.pi/extensions/fm-secondmate-guard.ts`, `~/.config/lean-ctx/config.toml`, and the secondmate provisioning skill. No `tasks-axi` command was run; no secondmate home was modified.

The required `decision-hold-lifecycle` skill was read. This report identified no unresolved captain choice: the recommendations are a Firstmate home/registry reconciliation and Controller-owned tool configuration work. However, its shared `fm-decision-hold.sh complete --none` attestation would write the originating task metadata and invoke the backlog mechanism, neither of which is within the explicitly permitted external-write set (`this report` and `the status file` only); invoking `tasks-axi` is separately prohibited. Therefore the shared completion attestation was **not run**, and the supervisor status is blocked rather than falsely marked done. Firstmate must perform/authorize the attestation or provide an allowed read-only completion path.
