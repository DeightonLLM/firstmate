# Pi startup skill-collision cleanup investigation

## Outcome

**Blocked; the requested warnings remain.** A documented exact `-path` exclusion in the user `skills` resource array did not mask a skill in the automatically scanned project `.agents/skills` root. The fresh Pi startup still showed the quota-axi collision. Per the explicit stop condition, I restored `settings.json` byte-for-byte and did not try another exclusion, a package-manifest workaround, or any file/directory changes. No skill files or package manifests were modified. Do not treat this task as done.

## Scope, documentation, and planned diff

Pi version was `1.2.0`, executable `/home/hd2admin/.nvm/versions/node/v22.23.2/bin/pi`; `PI_CODING_AGENT_DIR` was unset, so user settings were `/home/hd2admin/.pi/agent/settings.json`.

Read the installed Pi docs:

- `docs/settings.md` (“Resources”): resource paths accept absolute paths and `~`; resource arrays support exact exclusions using `-path`.
- `docs/packages.md` (“Select package resources”): package resource filters support `-path` for package-declared resources.
- `docs/configuration.md` (“Agent directory”): user settings live in `<agent-dir>/settings.json`.

Planned test diff, applied only temporarily: add `skills: ["-/home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006"]` to user `settings.json`. This tests one exact exclusion against one auto-scanned duplicate. After the negative result, the original file was restored from backup. Final size/hash matches baseline exactly. No later remedy was attempted.

## Backups and byte evidence

Before the settings edit, the original settings were copied to:
`/home/hd2admin/kun-agent-workspace/data/skill-collisions-cleanup-20261013/settings.json.baseline`.

`baseline-hashes.txt` in that directory records the baseline byte size and SHA-256 of the settings file and all ten listed winner/colliding skill files. Results, also rechecked after the test:

| File | Bytes | SHA-256 |
|---|---:|---|
| `/home/hd2admin/.pi/agent/settings.json` (baseline and restored) | 1626 | `c422f82b811c07c06bbf83c5b0eee961b65a682e9d4b3e21eabe925f9d23e437` |
| `/home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi/SKILL.md` | 1861 | `f51bb53644b4dbaf8c3596b8328a746a0b9a4b03a496822e16119ca92b5bce22` |
| `/home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006/SKILL.md` | 1861 | `f51bb53644b4dbaf8c3596b8328a746a0b9a4b03a496822e16119ca92b5bce22` |
| `/home/hd2admin/kun-agent-workspace/.agents/skills/no-mistakes/SKILL.md` | 27620 | `b41d838c84bc00ca0c38c83385507bbc2afb284bc3d16f2bcf72eefdf9050725` |
| `/home/hd2admin/.agents/skills/no-mistakes/SKILL.md` | 27620 | `b41d838c84bc00ca0c38c83385507bbc2afb284bc3d16f2bcf72eefdf9050725` |
| `/home/hd2admin/kun-agent-workspace/.agents/skills/tdd-red-green-refactor/SKILL.md` | 4352 | `057a09977e716e3f895afc4d15e6266414b7d35fc054927abce3f3ce0f1738cb` |
| `/home/hd2admin/.agents/skills/tdd-red-green-refactor/SKILL.md` | 4352 | `057a09977e716e3f895afc4d15e6266414b7d35fc054927abce3f3ce0f1738cb` |
| `/home/hd2admin/.pi/agent/skills/council-mode/SKILL.md` | 4311 | `31be86e2177a283a53d9e36044cdb655a5060cf217fcc0594d163ea44e8642e4` |
| `/home/hd2admin/.pi/agent/npm/node_modules/pi-subagents/skills/council-mode/SKILL.md` | 4394 | `e998812debc33870e5324fba20d5fe48930708e0b1498a7971504d60064881de` |
| `/home/hd2admin/.pi/agent/skills/pi-subagents/SKILL.md` | 8726 | `764929498b58dab2077b8730b901767ab18cac628379697206223189414ae8c8` |
| `/home/hd2admin/.pi/agent/npm/node_modules/pi-subagents/skills/pi-subagents/SKILL.md` | 9403 | `a0709573a1bfff1e2aa594cc4ec55a73bba6727073e791d4dea586c129bcf2cc` |
| `/home/hd2admin/.pi/agent/npm/node_modules/pi-subagents/package.json` (read-only; not edited) | 3563 | `51f45f9dc332010927c81f826ef38ae294633acd464832d010b5f96881dabf7c` |

The Pi package manifest was not changed. The quota-axi backup remains readable at its original path and its bytes/hash match the winner as shown above. All other listed skill files also retain their baseline sizes and hashes.

## Test evidence

Temporary test edit was made only after the backup/hash baseline above. Fresh-process startup command:

```sh
script -q -c 'cd /home/hd2admin/kun-agent-workspace && timeout 5 pi --verbose --offline --no-session' /dev/null
```

The startup output showed all five intended winner paths under `[Skills]` and then `[Skill conflicts]` for all five names. Relevant output (ANSI formatting removed):

```text
"quota-axi" collision:
  ✓ auto (project) ~/kun-agent-workspace/.agents/skills/quota-axi/SKILL.md
  ✗ ~/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006/SKILL.md (skipped)
"no-mistakes" collision:
  ✓ auto (project) ~/kun-agent-workspace/.agents/skills/no-mistakes/SKILL.md
  ✗ ~/.agents/skills/no-mistakes/SKILL.md (skipped)
"tdd-red-green-refactor" collision:
  ✓ auto (project) ~/kun-agent-workspace/.agents/skills/tdd-red-green-refactor/SKILL.md
  ✗ ~/.agents/skills/tdd-red-green-refactor/SKILL.md (skipped)
"council-mode" collision:
  ✓ auto (user) ~/.pi/agent/skills/council-mode/SKILL.md
  ✗ ~/.pi/agent/npm/node_modules/pi-subagents/skills/council-mode/SKILL.md (skipped)
"pi-subagents" collision:
  ✓ auto (user) ~/.pi/agent/skills/pi-subagents/SKILL.md
  ✗ ~/.pi/agent/npm/node_modules/pi-subagents/skills/pi-subagents/SKILL.md (skipped)
```

Thus the test exclusion did not suppress the automatically scanned quota-axi backup; it did not change the winner. The startup view showed the five expected winner skills and the same five collisions; no additional skill-collision warning appeared. The settings backup was then restored with `cp`; both restored settings and backup are 1626 bytes and have the same SHA-256 recorded above.

## Checks denied, skipped, or unrun

- `ctx_shell` denied a read-only hash command because its `command` executable is not allowlisted. That exact command was not retried; the inventory was instead completed with the native Bash tool.
- Exclusion behavior test: **run; negative**. It did not work for the auto-scanned root.
- Applied all-five exclusion change and clean-startup validation: **not run**, because the task explicitly requires stopping after the negative test and forbids fallback mechanisms.
- `pi-subagents/package.json` exclusion: **not attempted**; the task forbids fallback after the negative test. The manifest was read and hashed only.
- Fresh startup after restoring settings: **not run**; restoration is verified byte-for-byte by size and SHA-256.
- No change to skill files, directory names, or package manifest was attempted. No file was deleted or moved.

## Recommendation and completion gate

Do not add more exclusions or edit skills, rename/move/delete files, or change `node_modules` under this task. The requested warnings are not eliminated. A separate authorized investigation would be needed to establish a documented way to filter automatically scanned roots without altering skill files.

I read `.agents/skills/decision-hold-lifecycle/SKILL.md` in full and found no unresolved captain choice in this report: the bounded test failed and the task itself directs a stop, rather than asking the captain to select among remedies. The shared completion gate passed: `bash /home/hd2admin/kun-agent-workspace/bin/fm-decision-hold.sh complete skill-collisions-cleanup-20261013 --none` printed `complete: skill-collisions-cleanup-20261013 decision inventory reviewed`. This report is a blocked result, not a `done` result.
