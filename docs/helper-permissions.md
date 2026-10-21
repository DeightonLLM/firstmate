# Helper Permission Rules & Containment Architecture

This document defines the canonical helper permission rules, shell allowlists, and path containment boundaries enforced across the host for Firstmate lanes, workers, and background agents.

The machine-readable companion definition lives in [`docs/helper-permissions.json`](helper-permissions.json) and is continuously validated against live host configurations via [`bin/fm-helper-permissions-check.sh`](../bin/fm-helper-permissions-check.sh) and [`tests/fm-helper-permissions.test.sh`](../tests/fm-helper-permissions.test.sh).

---

## 1. Live Files on Host

Helper permissions and containment policies are configured across four live locations on this host:

1. **`/root/.config/lean-ctx/config.toml`**: Host-wide lean-ctx context engine configuration. Defines `shell_allowlist_extra`, which extends the built-in 200-command allowlist for MCP tools (`ctx_shell`).
2. **`/root/.config/lean-ctx-contabo/config.toml`**: Contabo-environment profile for lean-ctx. Declares `tool_profile = "minimal"`, `memory_profile = "balanced"`, `exclude_paths`, and profile-specific `shell_allowlist_extra`.
3. **`/root/.minimax/permission.json`**: MiniMax-Code tool execution and filesystem permission store (`version: 2`). Governs permitted `bash`, `fs`, `read`, and `web_fetch` matchers.
4. **`/root/.pi/rules/lean-ctx.md`**: Prompt-level agent instructions enforcing `ctx_*` tool usage over raw shell execution inside Pi sessions.

---

## 2. Bash Admission Policy (Admit vs Deny)

| Category | Policy | Admitted / Denied Patterns | Rationale |
| :--- | :--- | :--- | :--- |
| **Direct Script Invocations** | **ADMIT** | Direct executable paths (e.g., `bin/fm-*.sh`, `/root/bin/*`, `lane-hygiene`) | Direct script-file execution allows leaf command auditing, deterministic execution, and prevents shell-wrapping injection vulnerabilities. |
| **Allowlisted Binaries** | **ADMIT** | Binaries explicitly present in `shell_allowlist` or `shell_allowlist_extra` | Safe everyday operations (git status, reading resource limits, running test suites). |
| **Inline Interpreters** | **PERMANENT DENY** | `bash -c`, `sh -c`, `python3 -c`, `node -e`, `perl -e` | Inline code flags bypass leaf permission checking by embedding uninspected script strings into command arguments. |
| **Shell Substitutions & Evals** | **PERMANENT DENY** | `eval`, `exec`, `source`, `$(...)`, backticks, `case/esac` in restricted mode | Dynamic expansion obscures the executed program from security monitors. Denials are final: workers must change invocation form rather than retrying. |

---

## 3. Read Roots: Pi & MiniMax-Code

### Permitted Read Roots

- **Pi Agent**:
  - `/root/.pi/agent/**`: Pi agent configuration, installed extensions, and npm packages (e.g., `@calesennett/pi-codex-fast`, `@juicesharp/rpiv-todo`, `pi-goal-list-loop-audit`).
- **MiniMax Code (`/root/.minimax/permission.json`)**:
  - `/etc/**`: System configurations, cron jobs, and service unit definitions.
  - `/root/.agent-work/handoff/**`: Handoff queues and inter-worker brief exchange.
  - `/root/.cache/quota-axi/**`: Provider quota cache inspection.
  - `/root/.config/herdr/**`: Herdr session and pane layout state.
  - `/root/.gemini/**`: Gemini runtime state.
  - `/root/.pi/agent/**`: Pi packages and extension runtime inspection.
  - `/root/.ssh/**`: SSH host configuration and `known_hosts` (public host keys only).
  - `/root/.zcode/cli/rollout/**`: Zcode rollout configuration.
  - `/root/bin/**`: Firstmate executable toolbelt and utility scripts.
  - `/root/firstmate-hd2stack/firstmate/**`: Firstmate workspace files.
  - `/usr/lib/node_modules/@minimax-ai/code/**`: MCode internal package dependencies.
  - `/usr/local/bin/**`: Host utility scripts (e.g., lane starve detectors).
  - `/var/log/**`: Host and lane service logs.

### Prohibited Secret Roots (Zero Secret Values)

Under repository policy and containment rules, the following paths **must never** be admitted as plaintext read roots or exposed to worker contexts:
- `/root/.ssh/id_*`: Private SSH keys.
- `/root/.secrets/**`: Secret keys, API tokens, and credentials.
- `/root/secret-quarantine/**`: Quarantined credentials.
- `/root/.codex/auth.json`: Codex authentication tokens.
- `/root/.pi/agent/auth.json`: Pi authentication tokens.
- `/root/.pi/sessions/**`: Pi raw conversation transcripts.
- `/root/.bash_history`: Interactive shell history containing potential credentials.

---

## 4. Shell Allowlist Categories & Rationale

Commands in `shell_allowlist_extra` are grouped into five strict categories:

1. **System Telemetry & Resources** (`df`, `free`, `uptime`, `nproc`, `ps`, `ls`, `cat`)
   - *Why*: Automated lane-hygiene sweeps and health detectors require non-invasive reads of RAM, CPU core count, disk usage, and process status to detect phantom capacity holders and host saturation.
2. **Version Control & Repository State** (`git`, `read`)
   - *Why*: Workers and coordinators require git worktree management, commit log inspections, diff reviews, and porcelain status checks to perform code delivery without pushing.
3. **Agent & Orchestration Toolchain** (`pi`, `quota-axi`, `agent-secret-scan`, `npm`, `node`, `ssh`, `chmod`, `command`, `xargs`)
   - *Why*: Enables multi-agent dispatch, provider quota checks before launch, secret verification scans, test dependency resolution, and remote host telemetry.
4. **Firstmate Lifecycle Scripts** (`bin/fm-session-start.sh`, `fm-session-start.sh`, `fm-test-run.sh`, `fm-lint.sh`, `fm-install-shellcheck.sh`)
   - *Why*: Allows agents and automated timers to initialize sessions, run test suites (`fm-test-run.sh`), lint changes, and install required tools without containment denials.
5. **Lean-CTX Builtins** (`ctx_session`, `ctx_tree`, `ctx_read`, `ctx_search`)
   - *Why*: Core tool calls for the lean context compression engine, providing compressed reads, repository tree overviews, and AST symbol search.

---

## 5. Drift Detection & Verification

Drift detection is automated by [`bin/fm-helper-permissions-check.sh`](../bin/fm-helper-permissions-check.sh):

```bash
# Check live host containment vs tracked definition
bin/fm-helper-permissions-check.sh

# Run behavioral test suite (including mutation and safety tests)
tests/fm-helper-permissions.test.sh
```

When any entry is added to or removed from the live host configurations without being reconciled in `docs/helper-permissions.json`, the check exits with code `1` and details the exact mismatch.
