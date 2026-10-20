# Skill collision audit — plan only

## Result and boundaries

Read-only inventory completed for the five collisions shown by a fresh `pi --verbose --offline --no-session` start from `/home/hd2admin/kun-agent-workspace` (Pi 1.2.0). No skills, settings, installer files, or package contents were changed. Startup output directly marks each selected winner (`✓`) and skipped copy (`✗`). The previous attempted resource exclusion was unsuccessful per `data/skill-collisions-cleanup-20261013/report.md`; do not repeat that remedy.

**Winner means the copy Pi currently resolves, not a judgement that duplicate contents are interchangeable.** Hashes below are SHA-256 of exact current file bytes; sizes are bytes. All fingerprints were collected before any proposed action. The quota-axi files compare byte-for-byte equal (`cmp` exit 0).

## Collision inventory and exact evidence

| Skill | Location (all colliding copies) | Size | SHA-256 | Winner / evidence |
|---|---|---:|---|---|
| quota-axi | `/home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi/SKILL.md` | 1861 | `f51bb53644b4dbaf8c3596b8328a746a0b9a4b03a496822e16119ca92b5bce22` | **WINNER.** Startup labels `auto (project)` with `✓`; same project-scanned root and correct canonical skill directory. |
| quota-axi | `/home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006/SKILL.md` | 1861 | `f51bb53644b4dbaf8c3596b8328a746a0b9a4b03a496822e16119ca92b5bce22` | **Non-winner.** Startup labels it `✗ (skipped)`; byte-identical to winner. |
| no-mistakes | `/home/hd2admin/kun-agent-workspace/.agents/skills/no-mistakes/SKILL.md` | 27620 | `b41d838c84bc00ca0c38c83385507bbc2afb284bc3d16f2bcf72eefdf9050725` | **WINNER.** Startup selects `auto (project)` with `✓`. |
| no-mistakes | `/home/hd2admin/.agents/skills/no-mistakes/SKILL.md` | 27620 | `b41d838c84bc00ca0c38c83385507bbc2afb284bc3d16f2bcf72eefdf9050725` | **Non-winner.** Startup marks `✗ (skipped)`; bytes currently identical to project copy. |
| tdd-red-green-refactor | `/home/hd2admin/kun-agent-workspace/.agents/skills/tdd-red-green-refactor/SKILL.md` | 4352 | `057a09977e716e3f895afc4d15e6266414b7d35fc054927abce3f3ce0f1738cb` | **WINNER.** Startup selects `auto (project)` with `✓`. |
| tdd-red-green-refactor | `/home/hd2admin/.agents/skills/tdd-red-green-refactor/SKILL.md` | 4352 | `057a09977e716e3f895afc4d15e6266414b7d35fc054927abce3f3ce0f1738cb` | **Non-winner.** Startup marks `✗ (skipped)`; bytes currently identical to project copy. |
| council-mode | `/home/hd2admin/.pi/agent/skills/council-mode/SKILL.md` | 4311 | `31be86e2177a283a53d9e36044cdb655a5060cf217fcc0594d163ea44e8642e4` | **WINNER.** Startup selects `auto (user)` with `✓`. |
| council-mode | `/home/hd2admin/.pi/agent/npm/node_modules/pi-subagents/skills/council-mode/SKILL.md` | 4394 | `e998812debc33870e5324fba20d5fe48930708e0b1498a7971504d60064881de` | **Non-winner.** Startup marks package copy `✗ (skipped)`. It is inside `node_modules`; hard boundary prohibits action there. |
| pi-subagents | `/home/hd2admin/.pi/agent/skills/pi-subagents/SKILL.md` | 8726 | `764929498b58dab2077b8730b901767ab18cac628379697206223189414ae8c8` | **WINNER.** Startup selects `auto (user)` with `✓`. |
| pi-subagents | `/home/hd2admin/.pi/agent/npm/node_modules/pi-subagents/skills/pi-subagents/SKILL.md` | 9403 | `a0709573a1bfff1e2aa594cc4ec55a73bba6727073e791d4dea586c129bcf2cc` | **Non-winner.** Startup marks package copy `✗ (skipped)`. It is inside `node_modules`; hard boundary prohibits action there. |

The scan used `find` over project `.agents/skills`, account `~/.agents/skills`, user `~/.pi/agent/skills`, and the installed pi-subagents package skills. No other same-name `SKILL.md` was found in those roots. This inventory concerns the observed startup roots, not every skill directory on the machine.

## Exact reversible plan (not executed)

Before each individual move, archive an exact byte copy outside all scanned roots, record its byte count and hash, and require those values to match the table above. Then perform the listed rename. These commands are proposals only; none ran. The `.disabled` suffix removes the exact `SKILL.md` discovery filename while keeping content adjacent. To reverse, rename it back to `SKILL.md`; verify its recorded fingerprint first. `cp -p` archives preserve content and timestamps but cannot guarantee every filesystem metadata attribute, which is why the move-back is the exact restoration route.

1. **Project backup directory** — preserve the byte-identical backup content, then remove the discovery filename. Content stays under the project skills tree; no bytes are lost, but the duplicate skill ceases to be discoverable.
   ```sh
   mkdir -p /home/hd2admin/.local/share/skill-collision-audit-20261015-archive
   cp -p -- /home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006/SKILL.md /home/hd2admin/.local/share/skill-collision-audit-20261015-archive/quota-axi.bak-20261006-SKILL.md
   sha256sum /home/hd2admin/.local/share/skill-collision-audit-20261015-archive/quota-axi.bak-20261006-SKILL.md
   mv -- /home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006/SKILL.md /home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006/SKILL.md.disabled
   ```
   Reversal: `mv -- .../SKILL.md.disabled .../SKILL.md` (and optionally remove the archive only after verifying equality). Do not remove the directory or archive in this plan.
2. **Project/global duplicates** — the project copies remain the runtime winners. Preserve and rename only the global copies; global copies are identical today. This removes the redundant global availability, while retaining their exact content in both `.disabled` locations and the pre-move archive.
   ```sh
   mkdir -p /home/hd2admin/.local/share/skill-collision-audit-20261015-archive
   cp -p -- /home/hd2admin/.agents/skills/no-mistakes/SKILL.md /home/hd2admin/.local/share/skill-collision-audit-20261015-archive/global-no-mistakes-SKILL.md
   cp -p -- /home/hd2admin/.agents/skills/tdd-red-green-refactor/SKILL.md /home/hd2admin/.local/share/skill-collision-audit-20261015-archive/global-tdd-red-green-refactor-SKILL.md
   sha256sum /home/hd2admin/.local/share/skill-collision-audit-20261015-archive/global-*-SKILL.md
   mv -- /home/hd2admin/.agents/skills/no-mistakes/SKILL.md /home/hd2admin/.agents/skills/no-mistakes/SKILL.md.disabled
   mv -- /home/hd2admin/.agents/skills/tdd-red-green-refactor/SKILL.md /home/hd2admin/.agents/skills/tdd-red-green-refactor/SKILL.md.disabled
   ```
   Reversal is the corresponding `mv <file>.disabled <file>`. Lost if not reversed: global discovery of those copies; their content remains in place under ignored filenames and archive files. The project winners are unaffected.
3. **User/package collisions (`council-mode`, `pi-subagents`) — no permitted action can be recommended under the current hard boundary.** The observed nonwinner is in `node_modules`, which must not be touched. Renaming the winning user copy would make Pi resolve the different package copy (whose hash and size differ), changing the active skill implementation; that is not a content-neutral duplicate cleanup and risks replacing current behavior. Therefore leave both pairs untouched. The skipped package content remains at its original path; the user copy remains runtime winner. A future authorized change to package installation/filtering policy is needed to suppress these warnings without editing package contents. Do not edit package manifests or remove package files as a workaround.

### Byte-exact restoration record

The SHA-256 and byte size for **every** colliding file are recorded in the table above. For any future execution, first run the archive `cp -p`, then verify both `wc -c` and `sha256sum` against that table before changing the name. If either differs, stop and regenerate the plan from current bytes. The two quota copies were confirmed equal using `cmp`. No copy, rename, deletion, or settings change was performed in this audit.

## Commands and evidence

Read-only evidence commands executed:

```sh
find /home/hd2admin/kun-agent-workspace/.agents/skills /home/hd2admin/.agents/skills /home/hd2admin/.pi/agent/skills /home/hd2admin/.pi/agent/npm/node_modules/pi-subagents/skills -type f -name SKILL.md -print
# same roots: sha256sum of files, then wc -c of files
script -q -c 'cd /home/hd2admin/kun-agent-workspace && timeout 4 pi --verbose --offline --no-session' /dev/null
cmp -s /home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi/SKILL.md /home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006/SKILL.md
```

The startup transcript contained `[Skill conflicts]` and all five collision entries, with the winners and skipped copies exactly as recorded above. Settings evidence: `/home/hd2admin/.pi/agent/settings.json` contains `npm:pi-subagents` (line 7); it does not establish a per-skill override and was not changed. Earlier experiment documented in `data/skill-collisions-cleanup-20261013/report.md` confirms the attempted exact `-path` resource exclusion failed to suppress auto-scanning the project root and settings were restored byte-for-byte. This audit did not repeat or alter that experiment.

## Completion note

No unresolved captain choice is required to report this bounded inventory; the two package-contained copies have an explicit safe stop rather than an implied permission. The completion gate procedure was read from `.agents/skills/decision-hold-lifecycle/SKILL.md`, but its required `fm-decision-hold.sh complete ... --none` attestation was not run: the brief permits writes outside this disposable worktree only to the report and status file, and that gate writes additional durable state. Therefore the shared completion gate remains outstanding for Firstmate to complete in the authoritative home. The report is a plan, not authorization to enact it. Proposed project/global renames would remove duplicate discovery, but package collisions remain unresolved under the stated prohibition.
