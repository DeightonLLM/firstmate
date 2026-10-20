# Skill-name collision cleanup plan (plan only)

## Outcome and scope

I resumed the existing inventory, left all skill files and settings unchanged, and did not run or repeat the home-wide security scan. A fresh, read-only Pi startup still reports the same five collisions and selects the same winner paths as the previous audit. This report gives a reversible plan; **no move, rename, deletion, package read, or settings change was made**.

The winner is the copy Pi currently resolves in the requested project context, not whichever file has the newest mtime. Startup evidence is the live Pi `--verbose` resource listing and `[Skill conflicts]` section, captured with `script -q -c 'cd /home/hd2admin/kun-agent-workspace && timeout 4 pi --verbose --offline --no-session' /dev/null` (Pi 1.2.0). Pi displays the selected candidate with `✓ auto (project)` or `✓ auto (user)` and each duplicate with `✗ (skipped)`.

## Complete observed collision inventory

Hashes and byte counts for the eight files outside `node_modules` were freshly collected with `stat -c '%n|%s|%y'` and `sha256sum` before any proposed action. Package-file hashes/byte counts below are carried from the earlier evidence in `data/skill-collision-audit-20261015/report.md`; I did not read or hash package contents in this run because package contents are explicitly out of scope. I collected only read-only filesystem metadata (`stat`) for the two exact paths to satisfy the mtime inventory. Their current hashes are not revalidated here. No action on those package files is proposed.

| Skill | Absolute path | SHA-256 | Bytes | mtime (filesystem local time) | Runtime result |
|---|---|---|---:|---|---|
| `quota-axi` | `/home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi/SKILL.md` | `f51bb53644b4dbaf8c3596b8328a746a0b9a4b03a496822e16119ca92b5bce22` | 1861 | 2026-09-21 19:17:11 +0100 | **WINNER** — `✓ auto (project)` |
| `quota-axi` | `/home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006/SKILL.md` | `f51bb53644b4dbaf8c3596b8328a746a0b9a4b03a496822e16119ca92b5bce22` | 1861 | 2026-09-23 03:07:11.639331025 +0100 | Non-winner — `✗ (skipped)`; byte-identical to selected project file in the earlier `cmp` evidence and same hash now.
| `no-mistakes` | `/home/hd2admin/kun-agent-workspace/.agents/skills/no-mistakes/SKILL.md` | `b41d838c84bc00ca0c38c83385507bbc2afb284bc3d16f2bcf72eefdf9050725` | 27620 | 2026-09-24 06:05:37 +0100 | **WINNER** — `✓ auto (project)` |
| `no-mistakes` | `/home/hd2admin/.agents/skills/no-mistakes/SKILL.md` | `b41d838c84bc00ca0c38c83385507bbc2afb284bc3d16f2bcf72eefdf9050725` | 27620 | 2026-09-23 08:16:47.632317545 +0100 | Non-winner — `✗ (skipped)`; same hash/bytes as selected project copy.
| `tdd-red-green-refactor` | `/home/hd2admin/kun-agent-workspace/.agents/skills/tdd-red-green-refactor/SKILL.md` | `057a09977e716e3f895afc4d15e6266414b7d35fc054927abce3f3ce0f1738cb` | 4352 | 2026-09-21 19:17:11 +0100 | **WINNER** — `✓ auto (project)` |
| `tdd-red-green-refactor` | `/home/hd2admin/.agents/skills/tdd-red-green-refactor/SKILL.md` | `057a09977e716e3f895afc4d15e6266414b7d35fc054927abce3f3ce0f1738cb` | 4352 | 2026-09-15 14:22:59.463522554 +0100 | Non-winner — `✗ (skipped)`; same hash/bytes as selected project copy.
| `council-mode` | `/home/hd2admin/.pi/agent/skills/council-mode/SKILL.md` | `31be86e2177a283a53d9e36044cdb655a5060cf217fcc0594d163ea44e8642e4` | 4311 | 2026-09-15 16:44:39 +0100 | **WINNER** — `✓ auto (user)` |
| `council-mode` | `/home/hd2admin/.pi/agent/npm/node_modules/pi-subagents/skills/council-mode/SKILL.md` | `e998812debc33870e5324fba20d5fe48930708e0b1498a7971504d60064881de` | 4394 | 2026-10-13 20:20:39.064193566 +0100 | Non-winner — `✗ (skipped)`; prior report hash/bytes only, not re-read.
| `pi-subagents` | `/home/hd2admin/.pi/agent/skills/pi-subagents/SKILL.md` | `764929498b58dab2077b8730b901767ab18cac628379697206223189414ae8c8` | 8726 | 2026-09-30 01:45:18.616844766 +0100 | **WINNER** — `✓ auto (user)` |
| `pi-subagents` | `/home/hd2admin/.pi/agent/npm/node_modules/pi-subagents/skills/pi-subagents/SKILL.md` | `a0709573a1bfff1e2aa594cc4ec55a73bba6727073e791d4dea586c129bcf2cc` | 9403 | 2026-10-13 20:20:39.064193566 +0100 | Non-winner — `✗ (skipped)`; prior report hash/bytes only, not re-read.

There are five collision names and ten observed locations. Pi's live scan provides the winner evidence for each pair. `/home/hd2admin/.pi/agent/settings.json` lists `npm:pi-subagents` in its `packages` array (line 7), confirming why the package supplies resources; it does not supersede Pi's observed winner selections. The package rows are intentionally left untouched.

## Root cause

The backup directory is not excluded by its `.bak-` name. It contains a file literally named `SKILL.md`, and Pi's live startup confirms that it recognizes `/home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006/SKILL.md` as a `quota-axi` candidate, then skips it only after name-collision resolution. Thus a backup folder nested under an automatically scanned skill root is still in the discovery namespace; suffixing the directory name does not make it inert.

A related repository helper has the same recursive-discovery weakness: `bin/skill-drift-check` lines 42–50 defines `collect_root`, then line 49 uses `find "$root" -type f -name 'SKILL.md' -print0` without pruning backup directories. This is direct source evidence for that helper's mechanism, not proof that Pi uses that script internally. The Pi loader's implementation was not inspected because it is outside the allowed project/package boundaries. An earlier settings-exclusion experiment recorded in `data/skill-collisions-cleanup-20261013/report.md` failed to suppress this auto-scanned project root; it was restored byte-for-byte, and this task did not repeat it.

**Recurrence fix recommendation:** the owner of the discovery mechanism should exclude backup directories before descending, rather than relying on the directory basename to be ignored. For the Firstmate `skill-drift-check` walker, the intended `find` expression is:

```sh
find "$root" -type d -name '*.bak-*' -prune -o -type f -name 'SKILL.md' -print0
```

The Pi runtime needs equivalent backup-directory pruning or explicit resource-root filtering in its supported loader. The source for that runtime change is not available within the permitted surfaces, and the tested settings exclusion did not work for Pi's auto-scanned project root. Treat the runtime change as a separate upstream/maintainer fix; do not modify package contents or settings as a workaround.

## Ordered reversible action plan (not executed)

Before any future action, re-check all affected source hashes against the table; if any differs, stop and refresh this plan. `sha256sum` and `wc -c` must match before moving. The archive root below is outside Pi's observed project and user skill roots. Do not use `cp` as a substitute for preserving the source: moving the original tree is the reversible operation and retains the original bytes and metadata on the same filesystem.

1. **Move the backup directory out of the project skill root.** This removes the accidental candidate while retaining its complete content. Planned command:
   ```sh
   mkdir -p /home/hd2admin/.local/share/skill-collision-archive/wo0005-1-20261015
   sha256sum /home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006/SKILL.md
   wc -c /home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006/SKILL.md
   mv -- /home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006 /home/hd2admin/.local/share/skill-collision-archive/wo0005-1-20261015/quota-axi.bak-20261006
   sha256sum /home/hd2admin/.local/share/skill-collision-archive/wo0005-1-20261015/quota-axi.bak-20261006/SKILL.md
   ```
   Expected hash remains `f51bb53644b4dbaf8c3596b8328a746a0b9a4b03a496822e16119ca92b5bce22`, size 1861. Reverse with `mv -- /home/hd2admin/.local/share/skill-collision-archive/wo0005-1-20261015/quota-axi.bak-20261006 /home/hd2admin/kun-agent-workspace/.agents/skills/`; this restores the prior project-root path. Lost by the forward move: none of the bytes; the backup merely stops being discoverable as a skill.
2. **Move the two identical global fallback directories out of the user skill root only if losing projectless/global discovery is accepted.** Project startup selects the project files, but these user copies could serve another project/session; that consequence is nontrivial, so this remains a plan and is not executed. Planned commands:
   ```sh
   mkdir -p /home/hd2admin/.local/share/skill-collision-archive/wo0005-1-20261015/global
   sha256sum /home/hd2admin/.agents/skills/no-mistakes/SKILL.md /home/hd2admin/.agents/skills/tdd-red-green-refactor/SKILL.md
   wc -c /home/hd2admin/.agents/skills/no-mistakes/SKILL.md /home/hd2admin/.agents/skills/tdd-red-green-refactor/SKILL.md
   mv -- /home/hd2admin/.agents/skills/no-mistakes /home/hd2admin/.local/share/skill-collision-archive/wo0005-1-20261015/global/no-mistakes
   mv -- /home/hd2admin/.agents/skills/tdd-red-green-refactor /home/hd2admin/.local/share/skill-collision-archive/wo0005-1-20261015/global/tdd-red-green-refactor
   ```
   Expected hashes/bytes are the table values. Content remains in the archive. Reverse by moving each named directory back under `/home/hd2admin/.agents/skills/`. Lost by the forward moves: these two global fallbacks cease to load in contexts without the project copies; project winners remain unchanged.
3. **`council-mode` and `pi-subagents` package candidates: no filesystem action is permitted.** Their nonwinning package copies are inside `node_modules`; moving, renaming, copying, hashing again, or editing them would violate the explicit boundary. Leave them at their original package paths and rely on the current user-copy winners. Their content remains in place. No exact package-file move command is proposed. Suppressing these warnings requires a supported Pi loader change or package-maintainer change that leaves installed package contents untouched; the package rows above remain unaltered.
4. **Fix recurring scanner behavior through its owning code path.** In a separately authorized Firstmate code change, amend `bin/skill-drift-check`'s `find` expression at line 49 to prune `*.bak-*` directories using the expression shown above, with a regression test proving a backup-contained `SKILL.md` is excluded while ordinary skills remain indexed. For Pi's startup loader, request equivalent upstream pruning/allowlist behavior; do not try another unsupported settings exclusion. No code patch is included in this scout, and no runtime source/package was touched.

## Evidence and validation

- Read-only runtime command: `script -q -c 'cd /home/hd2admin/kun-agent-workspace && timeout 4 pi --verbose --offline --no-session' /dev/null`. It printed the five collision pairs, the selected `✓` copies, and skipped `✗` copies listed above. It also showed project/user skill roots and `npm:pi-subagents` resources.
- Read-only metadata command over the eight non-package paths: `stat -c '%n|%s|%y' "$f"; sha256sum "$f"`. Read-only `stat -c '%n|%s|%y'` over the two exact package paths supplied their size/mtime only; package content was not opened or hashed in this run. Package hashes are prior-report evidence and remain unverified in this run.
- Read source: `/home/hd2admin/kun-agent-workspace/bin/skill-drift-check`, `collect_root`/recursive discovery lines 42–50; relevant unfiltered `find` at line 49.
- Read config: `/home/hd2admin/.pi/agent/settings.json`, line 7 contains `npm:pi-subagents`.
- Reviewed prior audit and failed exclusion evidence at `/home/hd2admin/kun-agent-workspace/data/skill-collisions-cleanup-20261013/report.md` and prior collision audit `/home/hd2admin/kun-agent-workspace/data/skill-collision-audit-20261015/report.md`.
- No setting, installer surface (`skills/`), package content, skill file, or directory was changed.

## Completion-gate note

I read `/home/hd2admin/kun-agent-workspace/.agents/skills/decision-hold-lifecycle/SKILL.md`. The inventory contains recommendations and a conditional future action, not an unresolved captain decision to execute this plan. However, the required shared `fm-decision-hold.sh complete ... --none` attestation would write durable state outside the two explicitly permitted external output files (this report and the task status). I did not run it because the brief prohibits any other external writes. The report is therefore delivered, but the shared completion gate is not attested here; Firstmate must complete that gate in the authoritative home before treating the scout as fully closed.
