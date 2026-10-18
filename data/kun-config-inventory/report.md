# Brandon's Firstmate/Codex/Pi Configuration Inventory

**Date:** 2026-01-26
**Scope:** Read-only inventory of current concurrency settings, Codex config, Pi settings, installed plugins, and safety caps.
**Paths are sanitized — no secrets or credentials are reported.**

---

## 2026-10-12 Refresh

### Compaction Policy
**File:** `~/.pi/agent/settings.json`

| Setting | Value | Notes |
|---|---|---|
| `compaction.enabled` | `true` | Compaction active |
| `compaction.keepRecentTokens` | **20,000** | Always-retained tail on every compaction |
| `modelOverrides` | *(see below)* | Per-model reserve guard |

**Compaction reserve guards (modelOverrides):**

| Model | Reserve Tokens | Reserve % |
|---|---|---|
| `minimax/MiniMax-M3` | 500,000 | 50% of 1M context |
| `openai-codex/gpt-6.1-sol` | 122,400 | ~55% of 272K context |
| `openai-codex/gpt-6-luna` | 550,000 | ~50% of 1.05M override window |

### lean-ctx Bridge
**lean-ctx version:** `3.8.8` (official)
**Bridge state:** **OFF by default** — sessions use one-shot CLI path; embedded MCP bridge is opt-in (`LEAN_CTX_PI_ENABLE_MCP=1`)
**Config file:** `~/.config/lean-ctx/config.toml`

### Command Allowlist (lean-ctx shell guard)
**File:** `~/.config/lean-ctx/config.toml`

The following are the current `shell_allowlist_extra` entries on record — `pi` and `npm` CLIs are allowlisted; bash invocations of `fm-*` and `tasks-axi` are **permanently blocked**:

```
no-mistakes, herdr, fm-captain-hold.sh, fm-tasks-axi.sh, fm-crew-state.sh,
fm-send.sh, fm-watch-checkpoint.sh, fm-control.sh, ssh, scp, pi,
fm-brief.sh, fm-spawn.sh, agent-secret-scan, quota-axi, agy,
herdr-subagent-cap-check, sha256sum,
/home/hd2admin/kun-agent-workspace/bin/herdr-subagent-cap-check
```

*(Note: entries present in config.toml may not reflect the permanent block status described above — block enforcement is handled separately at the policy layer.)*

### Installed Pi Packages
**Pi version:** `1.0.4` | **pi-subagents:** `0.77.0` | **npm:** `10.9.8`

**Registered packages (`~/.pi/agent/settings.json`):**
| Package | Version | Status |
|---|---|---|
| `npm:pi-subagents` | 0.77.0 | active |
| `npm:pi-lean-ctx` | loaded | active — lean-ctx bridge off by default |
| `npm:@calesennett/pi-codex-fast` | — | `mode: off`, `enabled: false` |
| `npm:@juicesharp/rpiv-todo` | 2.12.0 | installed |

**pi list confirmed paths:**
```
~/.pi/agent/npm/node_modules/pi-subagents
~/.pi/agent/npm/node_modules/@calesennett/pi-codex-fast
~/.pi/agent/npm/node_modules/@juicesharp/rpiv-todo
~/.pi/agent/npm/node_modules/pi-lean-ctx
```

### Config Files of Record
| Component | Path |
|---|---|
| Pi agent settings | `~/.pi/agent/settings.json` |
| lean-ctx config | `~/.config/lean-ctx/config.toml` |
| lean-ctx CLI | `$NVM/.../lean-ctx` (v3.8.8) |
| Pi npm packages | `~/.pi/agent/npm/node_modules/` |
| Firstmate bin | `~/kun-agent-workspace/bin/` (top-level names only) |
| Firstmate backends | `~/kun-agent-workspace/bin/backends/` |

### Safety Caps in Force
| Cap | Value | Source |
|---|---|---|
| Parallel dispatch | **6** | `config/parallel-dispatch-cap` |
| Startup memory budget | **7,500 tokens** | `config/startup-memory-budget` |
| Compaction keep-recent | **20,000 tokens** | `~/.pi/agent/settings.json` |
| Model reserve — `MiniMax-M3` | **500,000 tokens** | `~/.pi/agent/settings.json` |
| Model reserve — `gpt-6.1-sol` | **122,400 tokens** | `~/.pi/agent/settings.json` |
| Model reserve — `gpt-6-luna` | **550,000 tokens** | `~/.pi/agent/settings.json` |
| lean-ctx bridge | **off by default** | `~/.config/lean-ctx/config.toml` |
| `pi` CLI | **allowlisted** | `~/.config/lean-ctx/config.toml` |
| `npm` CLI | **allowlisted** | `~/.config/lean-ctx/config.toml` |
| `fm-*` / `tasks-axi` bash | **permanently blocked** | policy layer |
| Herdr presentation spaces | **off** | `config/herdr-presentation-spaces` |

---

*(Previous inventory sections follow — dated 2026-01-26.)*

---

## 1. Concurrency / Parallel-Dispatch Settings

### Firstmate (kun-agent-workspace primary home)

| Setting | Value | File | Enforced vs Advisory |
|---|---|---|---|
| `parallel-dispatch-cap` | **6** | `config/parallel-dispatch-cap` | **Enforced** — caps how many crewmates can be dispatched in parallel |
| `startup-memory-budget` | **7500** tokens | `config/startup-memory-budget` | **Enforced** — prompt-memory surface budget for captain preferences + learnings |
| `herdr-presentation-spaces` | **off** | `config/herdr-presentation-spaces` | **Enforced** — opts out of Herdr's default-off disposable single-task visual projection |

### Codex (primary harness for this home)

Codex is configured as the **primary** crewmate harness. Settings live in two locations:

| File | Purpose |
|---|---|
| `~/.codex/config.toml` | Global Codex defaults |
| `~/.claude/settings.json` | Claude Code hook registrations (SessionStart runs `gh-axi`, `chrome-devtools-axi`, `lavish-axi`) |

**Codex global `config.toml` key values:**

```toml
model = "gpt-5.6-luna"
model_reasoning_effort = "xhigh"
approval_policy = "never"        # <-- safety: never auto-approves; always asks
sandbox_mode = "danger-full-access"
service_tier = "default"
```

| Safety Setting | Value | Notes |
|---|---|---|
| `approval_policy = "never"` | **Enforced** | Codex never auto-approves edits/scripts; always surfaces to captain |
| `sandbox_mode = "danger-full-access"` | **Advisory/Danger** | Signals full filesystem + exec access; not a hard block |
| `trust_level` for `kun-agent-workspace` | **trusted** | Project-level trust for this worktree |

**Codex `hooks.json` in `kun-agent-workspace/.codex/`:**

- SessionStart: pipes payload into `bin/fm-sessionstart-run.sh`
- PreToolUse (Bash): runs `fm-arm-pretool-check.sh` + `fm-cd-pretool-check.sh`
- Stop: runs `fm-turnend-guard.sh`

---

## 2. Pi Settings

### Pi Settings File
**Path:** `~/.pi/agent/settings.json`

```json
{
  "lastChangelogVersion": "0.99.1",
  "theme": "firstmate-black",
  "defaultProvider": "minimax",
  "defaultModel": "MiniMax-M2.7",
  "packages": ["npm:pi-subagents"],
  "subagents": {
    "defaultModel": "MiniMax-M2.7",
    "agentOverrides": {
      "reviewer": { "model": "MiniMax-M2.7" }
    }
  },
  "tuiMode": "regular"
}
```

| Setting | Value | Notes |
|---|---|---|
| Default provider | `minimax` | |
| Default model | `MiniMax-M2.7` | |
| Theme | `firstmate-black` | |
| TUI mode | `regular` | |
| Subagent default model | `MiniMax-M2.7` | reviewer override also uses M2.7 |

### Pi Models Store
**Path:** `~/.pi/agent/models-store.json`

**Active providers and models:**

#### minimax provider
| Model | Context Window | Max Tokens | Reasoning |
|---|---|---|---|
| `MiniMax-M2.7` | 204,800 | 131,072 | ✅ |
| `MiniMax-M2.7-highspeed` | 204,800 | 131,072 | ✅ |
| `MiniMax-M3` | 1,000,000 | 512,000 | ✅ |

#### zai provider
| Model | Context Window | Max Tokens |
|---|---|---|
| `glm-4.7` | 204,800 | 131,072 |
| `glm-5-turbo` | 200,000 | 131,072 |
| `glm-5.2` | 1,000,000 | 131,072 |
| `glm-5.2-highspeed` | 1,000,000 | 131,072 |
| `glm-5.3` | 1,000,000 | 131,072 |
| `glm-5.3-flash` | 1,000,000 | 131,072 |
| `glm-5.3-highspeed` | 1,000,000 | 131,072 |

#### openai-codex provider (Codex models via Pi)
| Model | Context Window | Max Tokens |
|---|---|---|
| `gpt-5.3-codex-spark` | 128,000 | 128,000 |
| `gpt-5.5` | 272,000 | 128,000 |
| `gpt-5.6-luna` | 272,000 | 128,000 |
| `gpt-5.6-sol` | 272,000 | 128,000 |
| `gpt-5.6-terra` | 272,000 | 128,000 |
| `gpt-6-astra` | 272,000 | 128,000 |
| `gpt-6-luna` | 272,000 | 128,000 |
| `gpt-6-sol` | 272,000 | 128,000 |
| `gpt-6.1-sol` | 272,000 | 128,000 |

### Pi Models Override File
**Path:** `~/.pi/agent/models.json`

Overridden models (contextWindow + maxTokens override for openai and openai-codex providers):

| Model Override | Context Window | Max Tokens |
|---|---|---|
| `gpt-6-luna` | 1,050,000 | 128,000 |
| `gpt-5.6-luna` | 1,050,000 | 128,000 |
| `gpt-5.6-terra` | 1,050,000 | 128,000 |
| `gpt-5.6-sol` | 1,050,000 | 128,000 |

*(All override contextWindow to 1,050,000 vs. the catalog's 272,000 — effectively doubling the context window for these models.)*

---

## 3. Crew Dispatch Rules

**Path:** `config/crew-dispatch.json`

Three named dispatch rules plus a default:

| Trigger | Harness | Model | Effort |
|---|---|---|---|
| Difficult/multi-component implementation | `pi` | `MiniMax-M3` | `medium` |
| Live news/web/X research | `grok` | `grok-4.5` | `high` |
| Routine coding/bug fix/refactor | `pi` | `MiniMax-M2.7` | `medium` |
| *(default)* | `pi` | `MiniMax-M2.7` | `medium` |

**Default crewmate harness:** `pi` (from `config/crew-harness`)
**Default runtime backend:** `herdr` (from `config/backend`)
**Secondmate harness:** `pi` (from `config/secondmate-harness`)

---

## 4. Installed Plugins / Skills

### Pi Built-in Skills (`~/.pi/agent/skills/`)
| Skill | Source | Notes |
|---|---|---|
| `council-mode` | pi builtin | Advisor council |
| `gbrain-herdr-loop` | pi builtin | GBrain-backed Herdr/Pi dispatch loop |
| `pi-subagents` | pi builtin | Subagent delegation |
| `roadmap-manager` | pi builtin | Project roadmap/TODO |
| `vps-operations` | pi builtin | VPS health/logs |

### Firstmate Local Skills (`kun-agent-workspace/.agents/skills/`)
| Skill | Source | Type |
|---|---|---|
| `afk` | local | Firstmate internal |
| `ahoy` | local | Firstmate internal |
| `ask-user-authority` | local | Firstmate internal |
| `bearings` | local | Firstmate internal |
| `bootstrap-diagnostics` | local | Firstmate internal |
| `captain-hold-lifecycle` | local | Firstmate internal |
| `decision-hold-lifecycle` | local | Firstmate internal |
| `diagnostic-reasoning` | local | Firstmate internal |
| `firstmate-calm` | symlink → `~/.claude/mods/firstmate-calm` | Claude Code Calm mod |
| `firstmate-codexapp` | local | Firstmate Codex Desktop coordination |
| `firstmate-coding-guidelines` | local | Firstmate internal |
| `firstmate-orca` | local | Firstmate Orca backend |
| `fmx-respond` | local | X-mode reply handler |
| `harness-adapters` | local | Firstmate internal |
| `process-event-sources` | local | Firstmate internal |
| `project-management` | local | Firstmate internal |
| `quota-array-dispatch` | local | Firstmate internal |
| `quota-axi` | local | Firstmate internal |
| `secondmate-provisioning` | local | Firstmate internal |
| `stow` | local | Firstmate internal |
| `stuck-crewmate-recovery` | local | Firstmate internal |
| `updatefirstmate` | local | Firstmate self-update |
| `quiet` | local | Firstmate internal |

### Firstmate Installed Global Skills (`~/.agents/skills/`)
| Skill | Installer Source |
|---|---|
| `axi` | npm:pi-subagents (via firstmate-coded) |
| `google-agents-cli-adk-code` | npm package |
| `google-agents-cli-deploy` | npm package |
| `google-agents-cli-eval` | npm package |
| `google-agents-cli-observability` | npm package |
| `google-agents-cli-publish` | npm package |
| `google-agents-cli-scaffold` | npm package |
| `google-agents-cli-workflow` | npm package |
| `herdr` | firstmate-coded (herdr backend) |
| `lavish` | firstmate-coded |
| `no-mistakes` | firstmate-coded |
| `tdd-red-green-refactor` | firstmate-coded |

### Pi Package Registration
**Registered in `~/.pi/agent/settings.json`:**
- `npm:pi-subagents` — subagent delegation package

---

## 5. Safety Caps Summary

| Cap | Value | Where Enforced | Notes |
|---|---|---|---|
| Parallel crew dispatch | **6** | `config/parallel-dispatch-cap` (Firstmate) | Hard cap on concurrent crewmates |
| Startup memory budget | **7500 tokens** | `config/startup-memory-budget` (Firstmate) | Captain prefs + learnings at session start |
| Codex approval policy | **`never`** | `~/.codex/config.toml` | Codex never auto-approves; always asks |
| Herdr presentation spaces | **off** | `config/herdr-presentation-spaces` | Disposable single-task projection disabled |
| Codex sandbox mode | `danger-full-access` | `~/.codex/config.toml` | Advisory only; signals full access scope |
| `fm-arm-pretool-check.sh` | Gate on Bash | `.claude/settings.json` / `.codex/hooks.json` | Pre-tool guard on dangerous commands |
| `fm-cd-pretool-check.sh` | Gate on cd | `.claude/settings.json` / `.codex/hooks.json` | Pre-tool guard on directory changes |
| `fm-turnend-guard.sh` | Gate on Stop | `.claude/settings.json` / `.codex/hooks.json` | Turn-end guard to prevent lost work |
| `fm-claude-stop-autoarm.sh` | Auto-arm on stop | `.claude/settings.json` | Arms next session automatically after stop |

---

## 6. Key File Paths Summary

| Component | Path |
|---|---|
| Firstmate config dir | `~/.kun-agent-workspace/config/` |
| Firstmate skills | `~/.kun-agent-workspace/.agents/skills/` |
| Pi settings | `~/.pi/agent/settings.json` |
| Pi models store | `~/.pi/agent/models-store.json` |
| Pi models overrides | `~/.pi/agent/models.json` |
| Pi trust | `~/.pi/agent/trust.json` |
| Codex global config | `~/.codex/config.toml` |
| Codex hooks (workspace) | `~/.kun-agent-workspace/.codex/hooks.json` |
| Claude Code global settings | `~/.claude/settings.json` |
| Claude Code workspace hooks | `~/.kun-agent-workspace/.claude/settings.json` |
| Herdr config | `~/.config/herdr/` |
| OpenCode config | `~/.config/opencode/` |
| Installed global skills | `~/.agents/skills/` |
| Pi builtin skills | `~/.pi/agent/skills/` |

---

*Report generated by scout task `kun-config-inventory` — read-only, no credentials accessed.*
