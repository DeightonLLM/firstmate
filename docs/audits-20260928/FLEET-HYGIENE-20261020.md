# FLEET HYGIENE — 2026-10-20 (HD2stack parity pass)

**Scope:** bring HD2stack to parity with the Controller's agent tooling and plugin surface, because HD2stack is becoming the primary controller node.
**Engine:** `/root/bin/fleet-hygiene` (read-only `inventory` mode; no CLI was updated, only installed where absent).
**Rule honoured:** no credential, auth file, token or API key was read, copied, created or rotated. The one config file touched (`~/.claude/settings.json`) was copied key-by-key, excluding `env` and `mcpServers`.
**Rollback paths:** `/root/backup/lean-ctx-bin-3.8.11-*`, `/root/backup/lean-ctx-config.toml-*`, `/root/backup/agent-secret-scan.pre-parity-*`, `/usr/lib/node_modules/lean-ctx-bin.old-3.8.11-*` (all on HD2stack).

## 1. Engine defects fixed first (they made the fleet blind)

| Defect | Effect | Fix |
|---|---|---|
| `#!/usr/bin/env bash` sat on line 15 of `/root/bin/fleet-hygiene` | The documented local invocation ran under `/bin/sh` (dash) and crashed: `[[: not found`, `Syntax error: redirection unexpected` | Shebang moved to line 1 |
| `cli_version_line` executed `"$1"` (the whole `pi --version` string as one word) | **Every** CLI version read as empty on every host, so the inventory could not see drift | Now `"$@"`, and the caller passes `$vcmd` unquoted so the command splits correctly |

After the fix, the Controller inventory reads: `pi 1.3.0`, `senpi 2026.9.28-7`, `omp 18.4.2`, `claude 2.1.284`, `codex 0.163.0`, `agy 1.4.3`, `mcode 0.6.12`, `herdr 0.9.5`, `zcode 0.16.9`.

## 2. CLI inventory — Controller vs HD2stack (after the pass)

| CLI | Controller | HD2stack | Result |
|---|---|---|---|
| pi | 1.3.0 | 1.3.0 (version unreadable: its wrapper's scan still fails on this host) | **GAP — see §5** |
| senpi | 2026.9.28-7 | 2026.9.28-7 | PASS |
| omp | 18.4.2 | 17.2.12 | older on HD2 — **not** downgraded or changed |
| claude | 2.1.284 | 2.1.284 | PASS |
| codex | 0.163.0 | 0.163.0 | PASS |
| agy | 1.4.3 | 1.4.3 | PASS |
| mcode | 0.6.12 | 0.6.12 | PASS |
| herdr | 0.9.5 | 0.9.5 | PASS |
| zcode | 0.16.9 | not installed | recorded, not installed (out of scope) |
| opencode / grok / kimi | not installed | not installed | n/a on both hosts |

## 3. Plugin and skill surface — Controller vs HD2stack (after the pass)

| Surface | Controller | HD2stack | Result |
|---|---|---|---|
| mcode built-ins `~/.minimax/.builtin-skills` | 17 | 17 | identical |
| user `~/.claude/skills` | 68 | **68** (was 1: `lean-ctx` only) | PASS — 0 missing, 0 extra; `SKILL.md` count 59 on both |
| user `~/.codex/skills` | 87 | **87** (was 83) | PASS — 0 missing, 0 extra; `SKILL.md` count 34 on both |
| firstmate project skills `.agents/skills` | 23 | **27** (union) | PASS — Controller's 23 all present; HD2's 2 untracked local skills (`ai-infra-benchmark`, `standup`) and its `plan-page`/`handover` untouched |
| fleet plugin glue `~/.config/opencode/plugins` | 4 files | 4 files | PASS (inert on both hosts: opencode is not installed) |
| Claude plugin manifest `~/.claude/plugins/` | present | present | PASS |
| `~/.minimax/integrations/mcode-tools` | present | present | PASS |
| Claude settings (non-secret keys) | `permissions` (70 allow entries), `enabledPlugins`, `model`, `theme`, `effortLevel`, `statusLine` | **now identical** | PASS — HD2's own `hooks` preserved; `env` (holds `ANTHROPIC_AUTH_TOKEN`) and `mcpServers` (gbrain, not installed there) deliberately not copied; `statusLine` re-pointed to PATH-resolved `lean-ctx statusline` |
| npm globals | 12 packages | **16 packages** | PASS — added `chrome-devtools-axi@0.1.35`, `acpx@0.15.1`, `backpass@0.1.22`, `mmx-cli@1.0.26`; `chrome-devtools-axi --version` verified on HD2 |
| lean-ctx | 3.10.5 | **3.10.5** (was 3.8.11) | PASS — npm could not fetch the release asset on HD2 (SIGTERM during fetch), so the Controller's proven package was copied instead; old version preserved for rollback |
| secret scanner | fixed build, registry, test, docs | **same build** (hash `a6a2c77e4c324225` matches the Controller) | PASS — HD2's new regression test passes there |

## 4. Propagation paths repaired

| Script | Defect | Fix |
|---|---|---|
| `/root/bin/warehouse-sync.sh` | Pull source pointed at the retired `/opt/overnight-mirror/repo/docs/` — the pipeline could not pull at all | Re-pointed at the live HD2stack tree `/root/agent-work/deightonllm-firstmate/docs/`; re-run succeeded: 15 files to the Controller's `docs/warehouse`, 13 to Hetz's `docs/warehouse` |
| `/root/bin/firstmate-sync` | Not broken, but it pushes the master clone to brandon-compute and elevatesVPS **only** — hd2stack is not in the propagation path | Recorded as a gap; a host becoming the controller node must be added explicitly |
| `BRANDON-COMPUTE-COMMS/to-hd2stack/` + `bin/hd2-comms-sync.sh` | working | Situation memo pushed, `push to-hd2stack rc=0`, receipt confirmed on the host |
| `BRANDON-COMPUTE-COMMS/to-brandon-compute/` + `bin/hetz-comms-sync.sh` | working | Situation memo pushed, receipt confirmed in brandon's inbox |

## 5. Open items (not defects, but they block HD2stack as controller)

1. **HD2stack's own secret scan still exits 1** with 8 findings of its own: `/root/agent-work/usage-ledger-20261016/tests/*` (6 files), `/root/migration-0043/p1_verify_user.php`, and paths inside the live `p1-leadlists-unify-20261020` lane worktree. Until they are classified the same way the Controller's were (value-free triage, compensating control, rotation prepared but not performed), the `pi` wrapper keeps gating launches on that host.
2. **HD2stack's firstmate checkout is stale and very dirty** — HEAD `f678f62` against origin `2d33549`, 253 dirty tracked paths. Reconciliation is the same Captain-gated merge question as the Controller's own divergence.
3. **HD2stack is absent from `bin/firstmate-sync`**, so it does not receive repo-level fleet updates.
4. **The canonical session lock and firstmate home remain on the Controller.** Making HD2stack the controller node means migrating those, with rollback — a Captain decision, not a configuration change.
5. `omp` on HD2stack is older than the Controller's (17.2.12 vs 18.4.2); left as-is rather than downgraded.

## 6. Where the situation was published

`docs/FLEET-SITUATION-2026-10-20.md` (canonical) and copies, each receipt-checked:

| Member | Location | Receipt |
|---|---|---|
| Controller | `docs/FLEET-SITUATION-2026-10-20.md` (tracked) + `docs/warehouse/` | present (11,078 bytes) |
| Controller master clone (fleet-sync source) | `/root/agent-work/firstmate/docs/` | present |
| HD2stack | `/root/agent-work/deightonllm-firstmate/docs/`, `docs/warehouse/`, `BRANDON-COMPUTE-COMMS/to-hd2stack/` | present on all three |
| brandon-compute | `kun-agent-workspace/docs/`, `kun-agent-workspace/warehouse/`, `kun-agent-workspace/BRANDON-COMPUTE-COMMS/to-brandon-compute/` | present on all three |
| elevatesVPS | `/root/agent-work/inbox/`, `/root/firstmate/docs/` | present on both |
| warehouse host (srv797124) | `/root/`, `/root/docs/operations/` + pointer appended to `SOURCE_OF_TRUTH_COMPACT.md` | present + 1 pointer marker |
