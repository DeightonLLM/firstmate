# Lean-ctx terminal layers — why some terminals show it and some don't

*2026-10-04 · canonical companion to `/root/.codex/LEAN-CTX.md` (mechanics) ·
written at the captain's request after he spotted the visible difference*

## The one-paragraph version

`lean-ctx` is a token-saving command layer: it compresses tool output (often
>95%), caches results, and enforces safety policy (interpreter blocklist,
project-root fencing). A terminal or agent that runs commands **through
lean-ctx** shows the `lean-ctx` prefix and truncated/redacted output. A
terminal that runs a **raw shell** shows full output and has no policy layer.
Both are the same machine — the difference is which wrapper launched the
command, not a different tool install.

## The four layers you will actually see

| Layer | What it looks like | Who uses it | Policy/compression |
|---|---|---|---|
| **lean-ctx wrapped** | `lean-ctx -c "…"` prefix; output compressed, sometimes with `[lean-ctx: full output → …]` teasers | Firstmate controller turns; pi/codex agents configured for it; AGY lanes under `/root` (enforced fail-closed since 2026-09-29) | YES — compression + allowlist + project fencing |
| **Raw shell (controller)** | Full raw output, no prefix | Captain's own interactive shells; anything whose PATH/launch bypasses the wrapper | NO compression; standard shell |
| **Agent-enforced lean-ctx (AGY)** | AGY's native `view_file`/`run_command` **refuse** under `/root` unless the command goes through lean-ctx | AGY/Gemini lanes on this controller | YES — deterministic, fail-closed |
| **Other surfaces (hd2stack, brandon, kvm1)** | Each host has its OWN lean-ctx config/allowlist; hd2stack's allowlist was still active 2026-10-04 while the controller's was disabled to save tokens | Lanes on those hosts | Per-host config — check before assuming |

## Why a command can work for the factory but "not be found" for a human

PATH, not intelligence. Controller root shells historically had
`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` — **no
`/root/.local/bin`**. Tools installed there (`herdr`, `mcode`, `quota-axi`,
several gates) were invisible to ordinary root shells while factory tooling
(explicit paths or different environments) used them fine. This exact defect
also starved the watcher (fixed 2026-10-04, commit history: watcher PATH
fallback + `/etc/profile.d/local-bin.sh` + `/root/.bashrc` export).

Rule of thumb now: **login shells get `/root/.local/bin` via
`/etc/profile.d/local-bin.sh`**; non-login non-interactive shells may still
not — factory scripts must never assume it and should use absolute paths.

## Agent enforcement matrix (controller, 2026-10-04)

| Agent | Reads under /root | Shell under /root | Notes |
|---|---|---|---|
| Firstmate (pi/codex controller) | lean-ctx tools | lean-ctx wrapped (allowlist blocklist active for interpreters) | `shell_allowlist=[]` disabled the allow hard-block 2026-10-03; compression stays |
| AGY / Gemini lanes | native tools fail-closed → lean-ctx required | `run_command` must start with lean-ctx | enforced by `agy-coordinate-guard-hook` + `agent-intent-guard`, never bypassed by `--dangerously-skip-permissions` |
| mcode (MiniMax) lanes | own tools; `lean-ctx -c` recommended but not hard-enforced | raw or wrapped | quota gate sits at the launcher, not inside mcode |
| hd2stack workers | host has its own lean-ctx (allowlist ACTIVE) | per-host | same distinction applies one level down |

## When you SEE lean-ctx in a terminal title/prefix, it means

The command you're watching was (a) compressed to save tokens, (b) checked
against the safety allowlist, and (c) fenced to the project root. When you
DON'T see it, the command ran raw: full output, no policy layer — fine for the
captain's own hands, expected for simple lane plumbing, and the thing to check
first when output looks different between two terminals.
