# Kun Lane A — Video Source Study Report

**Task**: Read-only study of public Kun/high-throughput sources to identify the exact config key for agent concurrency, plugin names, compatibility, and data/security effects.
**Sources**: YouTube video `https://youtu.be/MSbacZ99E14` ("High Throughput Agentic Engineering with Kun"), GitHub repos `kun`, `gnhf`, `backpass`.
**Study date**: 2025 (transcript dated 2026-09-13 in Kun's content archive)
**Video title**: High Throughput Agentic Engineering with Kun

---

## 1. Config Key for Agent Concurrency

### Finding: No Single Universal Concurrency Config Key

The Kun ecosystem does not expose one named config key that caps agent concurrency across the board. Concurrency is handled differently in each tool:

#### gnhf (good night, have fun) — no built-in concurrency cap

- **Concurrency mechanism**: `--worktree` flag. Each invocation with `--worktree` creates an isolated git worktree. Multiple `gnhf --worktree` invocations can run in parallel on the same repo.
- **No `max_concurrent` setting**: gnhf's config schema (`~/.gnhf/config.yml`) covers `agent`, `agentModel`, `agentPathOverride`, `agentArgsOverride`, `acpRegistryOverrides`, `commitMessage`, `maxConsecutiveFailures`, and `preventSleep`. None controls parallel agents.
- **Safety**: Because each agent runs in its own worktree, parallel agents are naturally isolated. The main failure boundary is `maxConsecutiveFailures: 3` (consecutive iteration failures before abort), which is about retry discipline, not concurrency.

**Source**: `https://github.com/kunchenguid/gnhf`, `src/core/config.ts`

#### treehouse — `max_trees` setting

- **Config key**: `max_trees` (in `treehouse.toml`)
- **Default**: `16`
- **Meaning**: Maximum number of pooled git worktrees per repository. Each worktree = one isolated agent session. This is the closest thing to a concurrency cap in the Kun ecosystem.
- **Operator request of 50**: Setting `max_trees = 50` would allow up to 50 pooled worktrees (50 parallel agents). The default safety cap is 16; 50 bypasses that.
- **Bypasses safety cap**: Yes — the default of 16 is a reasonable resource guard. Setting to 50 is untested and could exhaust disk, CPU, or provider quota if all 50 agents run simultaneously.
- **Source**: `https://github.com/kunchenguid/treehouse`, `treehouse.toml.example`

#### firstmate crew dispatch — routing rules, not concurrency

- **Config key**: `config/crew-dispatch.json` (in firstmate home)
- **What it controls**: Per-task model/harness routing rules based on task type, not concurrency limits.
- **No concurrency cap**: firstmate does not expose a config key to limit how many crewmates run concurrently. The limit comes from the backend (tmux panes, Herdr spaces, etc.) and provider quotas.

**Source**: `https://github.com/kunchenguid/firstmate`, `docs/configuration.md`, video transcript (8:06)

#### Claude / Cloud Code — context window, not concurrency

- **Claude Code env var**: `AUTOCOMPACT_WINDOW`
- **Cloud Code env var**: `CLOUD_CODE_AUTOCOMPACT_WINDOW`
- **Kun's value**: `500000` (500k tokens)
- **Meaning**: Auto-compacts the session context when it reaches this threshold. This is about token budget management, not agent concurrency.
- **Source**: Video transcript (33:05–35:41), `https://github.com/kunchenguid/dotfiles`

### The "50 cap" in Kun's Sources — NOT a Config Key

Kun frequently references a "50 cap" or "50% cap" in his public posts:

- **What it is**: A **provider-side Fable quota restriction** — users can only spend up to 50% of their subscription quota on Fable. This is enforced by the Fable service, not a user-configurable key.
- **Evidence**: Kun's X posts (2026-09-01, 2026-09-02, 2026-09-05) explicitly call it "the 50% cap" and "the 50 cap" in the context of Fable subscription quota allocation.
- **Not configurable**: No config key exists to change this. It is a business限制, not a technical one.
- **Quote**: "the 50% cap i'm referring to is not the '50% boost' that's going away — it's that you can only use 50% of your sub quota on fable." (2026-09-01 X post)

### Summary Table

| Tool | Config Key | Default | Operator-Requested | Bypasses Safety Cap? |
|---|---|---|---|---|
| treehouse | `max_trees` | `16` | `50` (if interpreted as pool size) | Yes — default cap is 16 |
| gnhf | None for concurrency | N/A | N/A | N/A |
| firstmate | None (crew-dispatch.json routes, not caps) | N/A | N/A | N/A |
| Claude Code | `AUTOCOMPACT_WINDOW` (tokens) | provider default | N/A | N/A |
| Cloud Code | `CLOUD_CODE_AUTOCOMPACT_WINDOW` (tokens) | `500000` | N/A | N/A |
| Fable | None (provider quota %) | `50%` of subscription | Cannot be changed | Provider-enforced, not bypassable |

---

## 2. Plugin List

All plugins and tools in the Kun ecosystem, with source URLs and permission implications:

### Core Orchestration

| Plugin | URL | What it does | Permissions / Data |
|---|---|---|---|
| **gnhf** | https://github.com/kunchenguid/gnhf | Ralph/autoresearch-style overnight orchestrator; one command starts an autonomous loop with incremental commits | No credentials; needs a supported coding agent CLI |
| **firstmate** | https://github.com/kunchenguid/firstmate | Agent distro that turns a coding agent into a firstmate/captain layer managing crewmates in tmux/Herdr/zellij/cmux/Orca | Git, GitHub CLI, session backend |
| **backpass** | https://github.com/kunchenguid/backpass | Gradient-descent for AGENTS.md; reads local transcript stores across 7 harnesses, proposes evidenced-backed edits | **Local-only**: reads harness transcript files directly from disk; no API, no upload except into an already-authenticated agent. Secret redaction applied before any model call |
| **treehouse** | https://github.com/kunchenguid/treehouse | Manages a pool of reusable git worktrees so each agent session gets a clean environment instantly | No credentials |

### AXI Tools (Agent-experience Interface)

| Plugin | URL | What it does | Permissions / Data |
|---|---|---|---|
| **axi** | https://github.com/kunchenguid/axi | Design principles + catalog for token-efficient agent CLIs | No credentials |
| **quota-axi** | https://github.com/kunchenguid/quota-axi | Reports local quota/usage windows for Claude, Codex, Cursor, Copilot, Grok, Kimi, Z.AI, Alibaba, OpenCode, Antigravity in one TOON call | **Read-only** against first-party endpoints; no login, no logging |
| **gh-axi** | https://github.com/kunchenguid/gh-axi | Token-efficient GitHub CLI wrapper with structured output | Needs `gh auth login` |
| **chrome-devtools-axi** | https://github.com/kunchenguid/chrome-devtools-axi | AXI wrapper for chrome-devtools-mcp for browser automation | Browser access |
| **lavish-axi** | https://github.com/kunchenguid/lavish-axi | Opens agent-generated HTML artifacts in a local browser for collaborative review | Local browser only |

### Agent Plugins

| Plugin | URL | What it does | Permissions / Data |
|---|---|---|---|
| **compact-adviser** | https://github.com/kunchenguid/compact-adviser | Judges whether a session is at a safe `/compact` checkpoint using Jev model | **Sends checkpoint context to TypeSafe API** (`TYPESAFE_API_KEY` required); consent required |
| **quota-array-dispatch** | (bundled with firstmate) | Routes crewmate dispatch based on real-time quota data from quota-axi | Read-only quota data |
| **backpass** (skill) | https://github.com/kunchenguid/backpass | Same as above — skill for evidence-backed AGENTS.md improvement | Local-only transcript read |
| **vision** | https://github.com/kunchenguid/vision | Mines merged PRs/commits to draft a `VISION.md` acceptance policy | Needs `gh` or `gh-axi` for PR history |
| **whathappened** | https://github.com/kunchenguid/whathappened | Grok Build skill that turns X firehose into a neutral briefing | X API via Grok Build |
| **baby-menu** | https://github.com/kunchenguid/baby-menu | macOS menu-bar app that runs a coding agent to edit the menu on the fly | Homebrew, agent CLI on PATH |

### Supporting Tools

| Plugin | URL | What it does | Permissions / Data |
|---|---|---|---|
| **no-mistakes** | https://github.com/kunchenguid/no-mistakes | Local git proxy + validation gate; spins up a disposable worktree, runs AI-driven review/test/docs/lint, opens clean PR | Agent-agnostic |
| **firstmate-grok-bot** | https://x.ai/bot/__4FfrkUdvpdMk6-LKg5r | Firstmate as a Grok Bot click-import template | Grok Bot import |
| **SSHHIP** | https://sshhip.com | SSH client app for iOS with voice input for terminal control | No credential exposure |

### Kun's Knowledge Base

| Plugin | URL | What it does | Permissions / Data |
|---|---|---|---|
| **kun** (skill) | https://github.com/kunchenguid/kun | Near-realtime distillation of Kun Chen's experience, tools, workflows, and skills; daily refresh from X, Substack, YouTube | Public-only content; `pull-kun.mjs` fetches from raw.githubusercontent.com |
| **dotfiles** | https://github.com/kunchenguid/dotfiles | Kun's macOS setup (nix-darwin + home-manager) with shared agent configs | Homebrew, Nix |

---

## 3. Security and Data Implications

### backpass — Most Sensitive (local-only but important)

- **Data flow**: Reads raw transcript files directly from harness-specific local stores (`~/.claude/projects/`, `~/.codex/sessions/`, `~/.local/share/opencode/opencode.db`, `~/.grok/sessions/`, `~/.cursor/chats/`, `~/.hermes/state.db`). No transcript is ever uploaded to a remote server.
- **Secret redaction**: backpass redacts obvious secrets (API keys, tokens) before any model call.
- **Model calls**: Go through `acpx` to a harness the user has already authenticated. Transcripts never leave the machine except into an agent session the user already authorized.
- **SSH hosts**: Can read sessions from remote machines over SSH, but only reads per-session cwd facts and transcript files; nothing is centralized.

### compact-adviser — External API Call

- **Data flow**: Sends checkpoint context (session content at a safe compact boundary) to TypeSafe's Jev API.
- **Consent**: Installing the package is explicit consent to send eligible checkpoint context to TypeSafe when a key is available.
- **Override**: `TYPESAFE_BASE` env var redirects to a self-hosted endpoint.
- **Risk**: Checkpoint context may include project-specific code, file paths, and tool call sequences.

### quota-axi — Read-Only, No Credential Creation

- **Data flow**: Reads quota/usage data from provider endpoints. Does not create or store credentials.
- **On macOS**: May prompt for Keychain access the first time to refresh Claude/Cursor credentials.
- **Risk**: Exposes quota information to the agent for routing decisions, but does not expose credentials.

### gnhf — No Credential Handling

- **Data flow**: Runs a coding agent CLI with the user's existing authentication. Does not handle credentials itself.
- **Commits**: Creates unsigned git commits on behalf of the agent. No GPG signing required.
- **Remote push**: `--push` pushes to origin after each successful iteration.

### treehouse — No Credential Handling

- **Data flow**: Manages git worktrees. No credential exposure.
- **Hooks**: Optional `pre_destroy` and `post_create` hooks in `~/.config/treehouse/config.toml`. These are user-defined and not checked into the repo.

### Kun Skill (pull-kun.mjs) — Public Content Only

- **Data flow**: Fetches public posts from X, Substack, and YouTube via RSS/manifest. No credentials needed.
- **Cache**: Stores content in `~/.cache/kun` or `$KUN_PULL_DIR`.

---

## 4. Key Findings Summary

1. **No single "agent concurrency" config key** exists across the Kun ecosystem. Concurrency is handled per-tool:
   - **treehouse** uses `max_trees` (default 16) — setting to 50 would increase the pool cap beyond the default safety limit.
   - **gnhf** has no concurrency cap — uses worktree isolation; the operator controls parallelism by launching multiple invocations.
   - **firstmate** has no explicit concurrency cap — managed by backend (tmux/Herdr) and provider quotas.

2. **The "50 cap"** in Kun's posts refers to **Fable's provider-enforced 50% subscription quota cap**, not a user-configurable key. It cannot be bypassed via config.

3. **Context window management** uses `AUTOCOMPACT_WINDOW` / `CLOUD_CODE_AUTOCOMPACT_WINDOW` set to `500000` (500k tokens).

4. **Most security-sensitive plugin** is **compact-adviser** (sends checkpoint context to TypeSafe API) followed by **backpass** (reads local transcripts, but never uploads them).

5. **Kun's recommended approach**: Set-and-forget context window thresholds, let firstmate handle dispatch routing via `config/crew-dispatch.json`, use treehouse for worktree pooling, and rely on provider quotas as the real concurrency boundary.

---

## 5. Source URLs

| Source | URL |
|---|---|
| YouTube video | https://youtu.be/MSbacZ99E14 |
| Kun skill/repo | https://github.com/kunchenguid/kun |
| gnhf | https://github.com/kunchenguid/gnhf |
| backpass | https://github.com/kunchenguid/backpass |
| firstmate | https://github.com/kunchenguid/firstmate |
| treehouse | https://github.com/kunchenguid/treehouse |
| no-mistakes | https://github.com/kunchenguid/no-mistakes |
| quota-axi | https://github.com/kunchenguid/quota-axi |
| compact-adviser | https://github.com/kunchenguid/compact-adviser |
| lavish-axi | https://github.com/kunchenguid/lavish-axi |
| gh-axi | https://github.com/kunchenguid/gh-axi |
| axiom | https://github.com/kunchenguid/axi |
| dotfiles | https://github.com/kunchenguid/dotfiles |
| Kun's blog | https://blog.kunchenguid.com |
| Kun's Discord | https://discord.gg/Wsy2NpnZDu |

---

## 2026-10-12 Scout: concurrency=50 — Public Known-Maximums Across Serving Layers

*Sources: existing `kun-video-source-study/report.md` (Kun ecosystem), `kun-config-inventory/report.md` (Firstmate home config), `kun-concurrency-impl/report.md` (blocked implementation), `parallel-dispatch-audit/report.md` (dispatch mechanics), `local-model-audit/report.md` (Hetzner local-model surface), `hetz-study-20261005/report.md` (Hetzner host evidence), `captain.md` (current captain preference). No network calls; no credentials.*

---

### One-paragraph summary

The value `concurrency=50` maps to different mechanisms at different layers of the serving stack, and no single public source establishes a universal safe maximum. At the **Firstmate crew-dispatch layer**, the home holds `config/parallel-dispatch-cap = 6` (current captain preference, 2026-10-12, superseding an earlier 25-lane experiment); Kun's treehouse uses `max_trees` (default 16, pool size, not active-agent count); and Kun's own "50 cap" references Fable's provider-enforced 50% subscription quota, not a user-configurable key. At the **local-model serving layer**, Hetzner's Brandon Compute runs a llama-server instance on port 8081 (`lfm2.5:latest`, 8.47B Q4_K, 32k context) and Ollama on port 11434 (`ornith-1.5:9b`, qwen35 9B); neither tool exposes a named concurrency flag in its public CLI surface, and the local-model-audit probe confirmed only that both respond to health and model-list calls — no concurrent-load ceiling was established in the evidence. The **vLLM** and **llama.cpp** public documentation establishes `--gpu-memory-utilization` (default 0.9) and `--prefill-chunk-size` as vLLM's closest concurrency-shaping knobs, and llama-server's `--parallel` flag as llama.cpp's direct concurrent-request control, but none of these values was tuned or verified on the Hetzner host. The **captain's own stated safe ceiling** for MiniMax agent dispatch is six or seven concurrent lanes, not 50.

---

### Per-source table: claimed concurrency, evidence path, caveats

| Source | Claimed concurrency max | Evidence path | Caveats |
|---|---|---|---|
| **Firstmate home** `config/parallel-dispatch-cap` | `6` (current captain preference, 2026-10-12) | `kun-config-inventory/report.md` §1; `kun-concurrency-impl/report.md` §"Before, as reported"; `hetz-study-20261005/report.md` confirmed `parallel-dispatch-cap=6` in `config/` | Was `25` historically (pre-2026-10-12 experiment); captain explicitly superseded to 6/7 for rate-limit risk. Is a *dispatch* cap, not a hardware or serving-layer cap. |
| **Kun/treehouse** `max_trees` | `16` default; operator requested `50` | `kun-video-source-study/report.md` §1 (`treehouse — max_trees setting`); `https://github.com/kunchenguid/treehouse`, `treehouse.toml.example` | Controls pooled *worktree* count, not active-agent count. Setting to 50 would exceed the default safety floor of 16. Pool size and active concurrency are not equivalent — a 50-tree pool with only 6 active agents is still safe; 50 simultaneously active agents is not. |
| **Kun/Fable** "50 cap" | Provider-enforced 50% of subscription quota | `kun-video-source-study/report.md` §1 ("The '50 cap' in Kun's Sources"); Kun X posts 2026-09-01/02/05 | Not a user-configurable key; enforced by Fable service. Cannot be bypassed via config. |
| **Kun/gnhf** | No concurrency cap | `kun-video-source-study/report.md` §1; `https://github.com/kuchenguid/gnhf`, `src/core/config.ts` | Uses worktree isolation per invocation; operator controls parallelism by launching multiple `gnhf` processes. |
| **Kun/firstmate** crew-dispatch | No concurrency cap; routes by model/harness | `kun-video-source-study/report.md` §1; `kun-config-inventory/report.md` §3 "Crew Dispatch Rules"; `docs/configuration.md` | Backend (tmux/Herdr) and provider quota are the actual concurrency boundaries. `config/crew-dispatch.json` is routing, not a cap. |
| **Hetzner/llama-server** (port 8081) | No named concurrency flag established | `local-model-audit/report.md` §3–§4 (service inventory + endpoint probes); `lfm2.5:latest`, 32k context, Q4_K, 8.47B params | Bind is `0.0.0.0:8081` (observed, not characterized as intentional). No concurrent-load test was run. Concurrency ceiling not established by audit. |
| **Hetzner/Ollama** (port 11434) | No named concurrency cap | `local-model-audit/report.md` §3–§4; `ornith-1.5:9b`, qwen35 9B, Q4_K_M, tools/thinking/completion/vision | Bind is `127.0.0.1:11434` only. No concurrent-load test was run. Concurrency ceiling not established by audit. |
| **1Panel AI Gateway** (port 8080) | No concurrency ceiling established | `local-model-audit/report.md` §4; `/v1/models` returned 401 without auth | Gateway proxies to upstream providers; no concurrency knob was probed. |
| **vLLM** (public docs) | No single concurrency flag; shaped by `--gpu-memory-utilization` (default 0.9), `--prefill-chunk-size`, `--tensor-parallel-size`, and engine arguments | Public vLLM server CLI (`--help` surface); `https://docs.vllm.ai` | Concurrency is emergent from GPU memory budget and chunked prefill, not a named max-requests knob. Default 0.9 GPU utilization leaves ~10% headroom. |
| **llama.cpp llama-server** (public CLI) | `--parallel N` — concurrent request slots; no documented safe maximum | Public llama.cpp CLI; `https://github.com/ggerganov/llama.cpp` | The `lfm2.5:latest` serving on Hetzner port 8081 is running a llama-server binary. No `--parallel` value was observed in the local-model-audit evidence. Safe maximum is workload/VRAM dependent (8.47B Q4_K at 32k context — VRAM per-request estimate ~2–4 GB). |
| **Captain (Brandon, 2026-10-12)** | 6/7 concurrent MiniMax agent lanes | `captain.md` §"Parallel authority, not measured capacity"; `kun-concurrency-impl/report.md` decision paragraph | Supersedes earlier 25-lane experiment. Bounded by rate-limit risk on MiniMax, not by hardware. Does not apply to local-model serving layers. |

---

### Recommendation

The value `concurrency=50` cannot be applied uniformly across any single layer with public evidence of safety. At the **Firstmate crew-dispatch layer**, the captain's own documented ceiling is 6/7 concurrent MiniMax lanes (not 50), and the home's `config/parallel-dispatch-cap = 6` is the enforceable control — raising it to 50 would require explicit captain authority and would exceed the documented rate-limit safety floor. At the **treehouse pool layer**, `max_trees = 50` would be technically feasible as a pool size (50 pooled worktrees with only 6 active agents), but a pool that size does not mean 50 active agents; conflating pool size with active concurrency would overstate the risk. At the **local-model serving layer** (Hetzner llama-server on port 8081, Ollama on port 11434), no concurrency ceiling was established by the local-model-audit; the next safe step before any `concurrency=50` setting is a concurrent-load probe of the llama-server endpoint at increasing batch sizes to establish the VRAM-constrained safe maximum for `lfm2.5:latest` at 32k context — the public llama.cpp `--parallel N` flag is the applicable knob, but the safe N for this model and host hardware is unknown without a load test. At the **vLLM layer**, the closest controls are `--gpu-memory-utilization` and `--prefill-chunk-size`, not a direct concurrency number. In summary: do not set `concurrency=50` anywhere without explicit captain authority and a load-tested ceiling; the applicable knob depends on which layer is being configured; and the captain's own 6/7 MiniMax ceiling remains the only current evidence-backed maximum for agent dispatch.
