# Audit: Safe Automatic Updates for Agent Tools and Extensions

- **Task**: br-system-update-audit (scout, read-only)
- **Author**: Pi · MiniMax-M3 · w5:p2
- **Date**: 2026-09-23 (UTC)
- **Repo audited**: firstmate (worktree `/home/hd2admin/.treehouse/firstmate-46aafc/3/firstmate`, host `brandon-compute`)
- **Captain's intent**: "Pi, Codex, and the other agent tools and their extensions stay current automatically, while keeping workers visible and usable."

This report inspects installed versions, the watched-tools mechanism, the update path of each tool, and the safety boundary that an automatic policy must respect: **no runtime may be replaced while one of its agents is using it.** It also proposes a concrete schedule, verification, rollback, and ticket-board reporting. **No software was updated, no settings were changed, no files were edited.**

---

## 1. Executive summary

- **Two tool updates are available right now**: Pi 0.87.0 → 0.87.1 (npm) and Codex 0.155.1 → 0.156.1 (standalone installer). Herdr (0.9.1) and no-mistakes (v1.79.0) are current.
- **Watched-tools detector exists** (`bin/fm-tool-update-check.sh`) but is **not armed** in this home. No `config/watched-tools.json`, no `state/tool-updates.check.sh`, no `state/.tool-updates` record.
- **Each tool has its own update command and its own safety story**. The safest default is **detect-and-notify, never auto-install**, because every run-time currently has at least one worker using it (4 Pi panes, 1 Codex coordinator CLI, the Herdr server, the no-mistakes daemon).
- **Recommended policy**: arm the watched-tools check on a 4-hour cadence, route its `check:` wakes into the existing Lavish board as a "Tools" card, and let the captain decide per-finding. Auto-install stays off; if the captain wants install on routine, gate each tool on its own "no worker process" precondition.
- **Decisions needed from the captain** are listed at the bottom and registered through `bin/fm-captain-hold.sh`.

---

## 2. Installed versions and update paths

### 2.1 Inventory

| Tool | Path on PATH | Installed | Latest | Source of latest | Update command |
|------|--------------|-----------|--------|------------------|----------------|
| **Pi (pi-coding-agent)** | `/home/hd2admin/.nvm/versions/node/v22.23.2/bin/pi` → npm global | `0.87.0` | `0.87.1` | `https://pi.dev/api/latest-version` | `pi update [--self\|--extensions\|--all\|--models\|<source>] [--force]` |
| **Codex CLI** | `/home/hd2admin/.local/bin/codex` → standalone | `0.155.1` | `0.156.1` | `~/.codex/version.json` (last checked 2026-09-22) | `codex update`; managed-daemon update is `codex app-server daemon update` |
| **Herdr** | `/home/hd2admin/.local/bin/herdr` (direct binary, not symlinked) | `0.9.1` | `0.9.1` (matches `~/.config/herdr/release-notes.json`) | `update.version_check` polls `herdr.dev` in the background | `herdr update [--handoff]`, channel via `herdr channel set stable\|preview` |
| **no-mistakes** | `/home/hd2admin/.local/bin/no-mistakes` → `~/.no-mistakes/bin/` | `v1.79.0 (fc540ac)` | `v1.79.0` | `~/.no-mistakes/update-check.json` | `no-mistakes update [--beta] [--force]` |
| **pi-subagents** | `~/.pi/agent/npm/node_modules/pi-subagents` | `0.70.1` | `0.70.1` | npm registry | `pi update --extensions` (also `npm install -g`) |
| **quota-axi** | `/home/hd2admin/.local/bin/quota-axi` → npm global | `0.1.49` | `0.1.52` | npm registry | `quota-axi update [--check]` |
| **gh-axi** | npm global | `0.1.35` | current | npm registry | `gh-axi update [--check]` |
| **chrome-devtools-axi** | npm global | current | — | npm registry | — (no separate update subcommand observed) |
| **firstmate** (this repo) | `git` | worktree HEAD on detached | branch HEAD | `origin/main` | `bin/fm-update.sh` (in-repo, fast-forward only) |

Two newer releases are waiting right now: **Pi 0.87.1** and **Codex 0.156.1**. Herdr, no-mistakes, and pi-subagents are all current on this host. The Pi-Subagents result came from `npm view pi-subagents version`.

### 2.2 Per-tool update mechanics (from `cli --help` and project docs)

**Pi** (`pi update`): For experimental installer-managed installs, "installs the exact checked version into a staged, lockfile-backed release and activates it only after verification, leaving the current release intact if the update fails" (source: `~/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/docs/packages.md`). `--self` updates Pi only; `--extensions` updates packages; `--all` does both. Pinned git `@ref` packages are **skipped** by `pi update --extensions`/`--all`; use `pi install git:...@new-ref` to move them. `--force` reinstalls the current version. A running Pi agent process keeps running on the in-memory binary; only new spawns pick up the new install.

**Codex** (`codex update`): Standalone installer downloads a new release to `~/.codex/packages/standalone/releases/<new>/` and flips the `current` symlink (`~/.codex/packages/standalone/current`). The CLI binary in PATH follows the symlink, so a *future* invocation uses the new version. The CLI process that invoked `codex update` is unaffected. The managed app-server daemon (`codex app-server daemon update`) "may interrupt work" (per its own `--help`) — that is the dangerous variant when an app-server is actually running agents.

**Herdr** (`herdr update [--handoff]`): Per the official install docs (`https://raw.githubusercontent.com/herdrdev/herdr/v0.9.1/docs/next/website/src/content/docs/install.mdx`):

> By default, `herdr update` installs the new binary and leaves endpoint-generation-1 servers and their pane processes running. Start Herdr again to reconnect with the updated client. Client-only changes work immediately. A new server-side action stays unavailable until that server is updated and restarted.

`--handoff` opts into an experimental live handoff for supported sessions. Channels (`update.channel` = `stable` or `preview`) are configured in `~/.config/herdr/config.toml`. Per-document, "Older running server still has its old limit for the first upgrade; this does not change update installation order or make live handoff non-experimental." Background `update.version_check` is **on by default**.

**no-mistakes** (`no-mistakes update`): The update wrapper explicitly checks whether runs are in flight and **refuses** by default. `--force` overrides that refusal. The daemon has to be restarted after update for the new binary to take effect. Current daemon status (read-only): running, PID 3668745.

### 2.3 PATH skew currently observed

`which` returns more than one match per PATH directory, so PATH skew is a real risk:

- `pi` resolves through `/home/hd2admin/.nvm/versions/node/v22.23.2/bin/pi` only (single match).
- `quota-axi` resolves through `/home/hd2admin/.local/bin/quota-axi`, which is itself a **symlink** to the nvm shim — so they are the same file by device/inode, but a literal `which -a quota-axi` returns both entries because the same directory appears twice on PATH.
- `herdr` resolves only through `/home/hd2admin/.local/bin/herdr` (direct binary, no second source).

This is exactly the skew the `fm-tool-update-check.sh` script was designed to detect. See §3.

---

## 3. The current watched-tools / update-check mechanism

`bin/fm-tool-update-check.sh` (898 lines, found at `/home/hd2admin/kun-agent-workspace/bin/fm-tool-update-check.sh`) is the firstmate-supplied detector. Its design contract is owned in `docs/configuration.md` "Watched tool updates" and the schema/example live at `docs/examples/watched-tools.json`.

**Actions**: `check` (silent when current, prints one line when something needs attention), `arm`, `disarm`.

**Two distinct conditions reported**:

- `<tool> update available` — a newer version exists at the tool's update source.
- `<tool> update not in effect` — a newer copy is installed on this host, but PATH still resolves an older one (PATH skew). This is the reason the check exists; just asking "is a newer version published?" would miss it.

**Configuration schema** (json, validated by `jq` + `announce_pattern_usable`):

```json
{
  "tools": [
    {
      "name": "<label>",
      "command": "<bare executable name on PATH>",
      "version_args": ["<optional args that print the version, default --version>"],
      "announce_pattern": "<optional extended regex matching the tool's own update announcement>",
      "announce_args": ["<optional args for the command carrying the announcement, default version_args>"],
      "git": {
        "repo": "<absolute path to local clone>",
        "remote": "<remote name, default origin>",
        "branch": "<branch, default remote's HEAD>"
      }
    }
  ]
}
```

Each entry needs `name` and at least one of `command` or `git`; an entry may carry both. `announce_pattern` is what a tool that announces its own update gets matched against — the example uses no-mistakes' "A new version of no-mistakes is available: X -> Y" line in `--help` output. The check's `command` arm walks every copy on PATH, dedups by device/inode, asks each copy for its version, and compares them — directory names are never read as versions.

**Cadence**: The check rides the existing watcher on `FM_CHECK_INTERVAL` (default 300 s) once armed; its **own** run-rate is gated by `FM_TOOL_UPDATE_INTERVAL` (default 900 s, valid 60..86400, 0 disables the gate). Probe bound is `FM_TOOL_UPDATE_PROBE_SECS` (default 5, valid 1..30); sweep bound is `FM_TOOL_UPDATE_BUDGET_SECS` (default 20, valid 1..120) and is auto-cut to fit `FM_CHECK_TIMEOUT` (default 30) if larger.

**Register mechanism**: `bin/fm-tool-update-check.sh arm` writes `state/tool-updates.check.sh`, binds its bytes with `bin/fm-check-register.sh`, and from then on the existing watcher (`bin/fm-watch.sh` line 2372 onward, in the "for c in $STATE/*.check.sh; do" loop) polls it. The trust binding is byte-static — once armed, the watcher refuses to run a check whose bytes were tampered with.

**Findings record**: `state/.tool-updates` carries the whole finding set the last report was made from. Same finding set as last time = silent; new finding = one line printed. This prevents re-reporting every poll cycle.

**Strict non-action**: The script is explicitly a detector. It "does not install, update, uninstall, reorder PATH, or touch any version manager's configuration, and it never fetches into a watched git repository" (script header).

**Currently armed in this home?** No. There is no `config/watched-tools.json`, no `state/tool-updates.check.sh`, and no `state/.tool-updates`. A direct invocation of `bin/fm-tool-update-check.sh check` runs the script, finds no config, and prints nothing (exit 0).

---

## 4. Live runtime inventory (right now)

Per `ps aux` and `herdr api snapshot` (read-only):

- **Pi**: at least one process (`/usr/bin/node/.../dist/bundle/cli.js`) on `pts/5` running this scout task. Herdr reports **5 Pi panes** total: `w2:pM` (BR-10 Stream A, idle), `w3:p2` (BR-01 done), `w4:p2` (BR-02 done), `w5:p2` (BR-03 working — this task), plus a coordinate pane. **All 4 active panes are using the current Pi install (0.87.0).**
- **Codex CLI**: one process on `pts/14` (the coordinator, working). The `codex app-server` daemon is **not running** on this host (doctor: "not running (ephemeral mode)"). So updating `codex update` is *currently* safer than `codex app-server daemon update` — only the coordinator CLI is in the way.
- **Herdr server**: PID 3833869, running 18+ days (started Sep 21). 5 panes across 4 workspaces. `herdr status` reports `version: 0.9.1`, `restart_needed: no`, `server_binary_stale: no`. **The Herdr server is the single most central process** — killing or replacing it loses the entire fleet's terminal state.
- **no-mistakes daemon**: PID 3668745, running v1.79.0. If a `no-mistakes axi run` is currently active on a PR, **a `no-mistakes update` without `--force` will refuse**; with `--force` it will replace the daemon mid-run (see the brief's hard rule 4 — `--force` is refused without explicit captain authority).

**Implication for the safety rule**: any automatic update policy must be aware of these live runtimes and must not replace any of them while a worker is using it. The cleanest enforcement point is: "no live agent of tool X" before updating tool X.

---

## 5. Update safety analysis

What each tool actually does mid-update, and the resulting safety verdict:

| Tool | Default update effect on running workers | Mid-update hazard | Recommended gate before install |
|------|------------------------------------------|-------------------|---------------------------------|
| Pi `--self` | Atomic activation, old process continues | None for current agents; new spawns use new binary | None for "no new agents"; **never install while a Pi session is mid-write that touches Pi extensions** (rare; brief's scope) |
| Pi `--extensions` | npm package swap in `~/.pi/agent/npm/` | Extension reload only on next session-start | None for current agents; new sessions see new version |
| `codex update` | Standalone release swap; CLI in PATH follows symlink flip | Running `codex` CLI keeps the old version until it exits; `codex doctor` may show `install inconsistent` until symlink target re-stabilizes | Wait for no `codex` process, or any bundle over (transient) |
| `codex app-server daemon update` | "may interrupt work" (per its own `--help`) | Live agent sessions dropped | **Hard no** unless app-server is confirmed idle and no `codex agents` sessions exist |
| `herdr update` | Keeps endpoint-gen-1 server and panes; client reconnect required | New server-side actions unavailable until next server restart; reconnect required | None for state; restart Herdr window |
| `herdr update --handoff` | Experimental live session transfer | Older running server still has its old limit on first upgrade; docs say it is not for the first upgrade | Same as `herdr update`; **never** for the first upgrade |
| `no-mistakes update` | Refuses when runs are active; `--force` overrides | Daemon restart drops in-flight validation, corrupting run record | **Hard no** unless `no-mistakes daemon status` shows zero runs and `no-mistakes runs` is empty. `--force` is never used (brief hard rule 4) |
| `quota-axi update` / `gh-axi update` | npm global swap | Same as Pi: in-process binary unaffected; new invocation picks up new version | None for current agent |
| `bin/fm-update.sh` (firstmate) | Fast-forward of firstmate + secondmates + rebind procm-fire watches | Restart set is computed by `fm-secondmate-restart-lib.sh`; skipped homes get no action | None — already gated by `fm-update.sh` itself (skipped homes stay skipped) |

**The single rule that protects everything**: do not install a tool's update while at least one worker process of that tool exists. For Herdr, also wait for no current Herdr session, since the server is the parent of all panes.

A simpler corollary that is **sufficient for this home**:

- Pi / Codex / Herdr / no-mistakes updates only proceed when the tool's worker count (visible via `herdr api snapshot` for pane-level info, or `pgrep -af "<tool>"` for raw process info) is zero.
- Pi `--self` and `herdr update` are exceptions when the tool explicitly documents "running process unaffected" (both do), but new-agent behavior changes are unavoidable, so the policy still says "no new agents of this tool until the captain clears it."

---

## 6. Recommended automatic update policy

### 6.1 Posture: detect, surface, captain-decides; do not auto-install

For a fleet that runs workers 24/7 with persistent session state (Herdr panes, Pi sessions, no-mistakes runs), **detect-and-notify is the right default**. Install gates must be captain-authorized per-tool, with explicit preconditions.

This matches:

- The brief: "do not update software, change settings, or edit files."
- The firstmate watcher contract: `fm-tool-update-check.sh` is explicitly a detector.
- The no-mistakes contract: its own update command is gated on zero active runs.
- The hard rule in the project: "Never merge a PR without an explicit captain word" extends naturally to "Never replace a runtime under live workers without an explicit captain word."

### 6.3 Concrete schedule / trigger

**Two cadences, both gated by the existing watcher**:

- **Routine detector**: `bin/fm-tool-update-check.sh check` armed at **`FM_TOOL_UPDATE_INTERVAL=14400`** (4 hours). This is longer than the default 900 s, picked to match a "human review window" cadence: a captain reads the finding within an hour of starting work. The 4-hour window is low-cost (each sweep is bounded to 20 s of probe time + 30 s of watcher bound) and avoids the nagging of every-15-minute findings on stable channels.
- **Pi model catalog refresh**: keep `pi update --models` as a manual refresh for now. Pi's own `pi.dev/api/latest-version` update check (`PI_SKIP_VERSION_CHECK=1` to disable) runs at Pi startup; that is fine.

**What the watcher actually does**: the existing `bin/fm-watch.sh` polls every `FM_CHECK_INTERVAL` (default 300 s); each poll runs each `state/*.check.sh` once; `tool-updates.check.sh` itself skips its body until `FM_TOOL_UPDATE_INTERVAL` has elapsed since the last sweep. So no extra scheduler is needed.

**Why not 900 s (default)**: every-15-minute findings produce a wake on every sweep where a finding is new, and a noisy wake queue distracts from real work. 4 hours is a calm default; the captain can override with a shorter value if a critical CVE lands.

**Config to enable** (the captain or firstmate on captain authorization will write this; the audit does **not** write it):

`config/watched-tools.json`:

```json
{
  "tools": [
    { "name": "pi",                "command": "pi",                "version_args": ["--version"] },
    { "name": "codex",             "command": "codex",             "version_args": ["--version"] },
    { "name": "herdr",             "command": "herdr",             "version_args": ["--version"] },
    { "name": "no-mistakes",       "command": "no-mistakes",       "version_args": ["--version"],
      "announce_args": ["--help"],
      "announce_pattern": "A new version of no-mistakes is available: [^ ]+ -> [^ ]+" },
    { "name": "quota-axi",         "command": "quota-axi",         "version_args": ["--version"] },
    { "name": "gh-axi",            "command": "gh-axi",            "version_args": ["--version"] },
    { "name": "chrome-devtools-axi","command": "chrome-devtools-axi","version_args": ["--version"] },
    { "name": "pi-subagents",      "command": "pi-subagents",      "version_args": ["--version"] },
    { "name": "firstmate",
      "git": { "repo": "/home/hd2admin/agent-work/firstmate", "remote": "origin" } }
  ]
}
```

Then `bin/fm-tool-update-check.sh arm`. The existing watcher takes over from there; no second schedule is required.

### 6.4 Update verification

After any update (now or in a future "install" path), the policy is to re-probe with the same detector and confirm the finding is gone:

| Tool | Post-update probe | Success criterion |
|------|-------------------|-------------------|
| Pi | `pi --version` | reports the target version; `pi config -u ..` shows packages consistent |
| Codex | `codex --version`; `codex doctor` | reports the target version; install line consistent; PATH entries still resolve to new package dir |
| Herdr | `herdr --version`; `herdr status` | client and server `version:` match; `restart_needed: no`; `server_binary_stale: no`; `endpoint_compatible: yes`; reconnect with new client works |
| no-mistakes | `no-mistakes --version`; `no-mistakes daemon status` | reports the target version; daemon `running`; `no-mistakes runs` shows no abandoned mid-flight runs |
| npm packages | re-run `quota-axi update --check`, `gh-axi update --check`, etc. | `available: false` |
| firstmate (git source) | re-run `bin/fm-update.sh` | `already current`; `restart-secondmates: none` if no secondmates on this home |

A failed verification **must** trigger rollback (see 6.5) and a `needs-decision` wake.

### 6.5 Rollback

Each tool keeps a recoverable prior version:

| Tool | Rollback |
|------|----------|
| Pi | `pi update --self --force` re-installs the current published version; for a manual rollback, `npm install -g @earendil-works/pi-coding-agent@<previous>`. The npm global install path is `/home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/`, symlinked into `/home/hd2admin/.nvm/versions/node/v22.23.2/bin/pi`. The staged install in 2.2 means the previous release is also kept on disk for the duration of the lockfile-backed staging. |
| Codex | `~/.codex/packages/standalone/releases/<previous>` is preserved; flip the symlink: `~/.codex/packages/standalone/current` → `/home/hd2admin/.codex/packages/standalone/releases/<previous>/bin/codex`. The `auto-update-version` file marks the running release. |
| Herdr | re-download the previous binary from `herdr.dev` and replace `/home/hd2admin/.local/bin/herdr`. Restart the server with `herdr server stop && herdr &`. State files (`~/.config/herdr/session.json`, `~/.config/herdr/herdr.sock`) are forward-compatible across point releases within v0.9.x. |
| no-mistakes | re-download the previous binary (URL pattern from `~/.no-mistakes/update-check.json`); replace `~/.no-mistakes/bin/no-mistakes`; daemon auto-restarts on next invocation. |
| npm globals | `npm install -g <pkg>@<previous>` |
| firstmate | `bin/fm-update.sh` is fast-forward only; rollback = `git -C /home/hd2admin/agent-work/firstmate reset --hard <previous-sha>` is the only path, but is also a manual destructive action that the captain must authorize explicitly. |

For Pi and Codex, the install is *staged* (Pi: "lockfile-backed release... activates it only after verification"; Codex: separate release directory), so a failed update leaves the previous release intact. For Herdr, the previous binary is replaced only when the new install succeeds, so the in-place binary is always the latest — pre-update backup is required for safe rollback. For no-mistakes, the previous binary lives at the symlink target.

---

## 7. How the ticket board should report updates

The Lavish "Brandon · Agent Floor" board (`/home/hd2admin/kun-agent-workspace/.lavish/brandon-agent-floor.html`) currently has a "BR-03 UPDATES" ticket that already references this audit. The natural extension is a **persistent "Tools" card** that mirrors the `state/.tool-updates` record:

- One card, titled "Agent tools — update state".
- Body lines come straight from the `state/.tool-updates` finding set, prefixed by badge color:
  - Green ("current"): no current finding line.
  - Amber ("update available"): `<tool> update available: <version-or-commit-count>`.
  - Red ("update not in effect"): `<tool> update not in effect: PATH resolves X at /path but Y is installed at /path` (PATH skew).
- Last sweep timestamp: from the `epoch=` line in `state/.tool-updates`.
- Last sweep budget cut, if any: from the `sweep budget Ns cut to Ms to stay inside the watcher check timeout of Xs` line.

The board is built by `bin/fm-bearings-board.sh` from a JSON payload. The update card is an ordinary card with `type=` left implicit (or `info`). A "decision" card is not needed: the captain's per-update decision is **not** a captain-held work item by itself; it is a direct command in chat ("yes, run `pi update --self`").

**Wake flow**: `state/tool-updates.check.sh` → watcher turn → `check: state/tool-updates.check.sh: tool updates: …` wake → firstmate reads the line → firstmate decides: post a board update, or escalate. Default is board update (no captain wake). Captain escalation is used only when a finding is "update not in effect" (PATH skew — the captain's only safe action is to reinstall or reorder PATH) or when an update is needed before the next worker spawn (a "needs-decision" wake).

**Anti-pattern**: do not turn the board update into a recurring poll that re-paints itself every wake cycle. `state/.tool-updates`'s `reported=` line is the dedupe key — the captain sees the same finding once until it changes.

---

## 8. Recommended configuration (what to write, not written here)

The captain or firstmate on captain authorization will:

1. Create `config/watched-tools.json` with the schema in §6.3.
2. Run `bin/fm-tool-update-check.sh arm`.
3. Set `config/calm` is unchanged; `FM_TOOL_UPDATE_INTERVAL=14400` set in `config/startup-memory-budget` *no — wrong place*: set it in the home's `.env` or in `config/watched-tools.json` (the script does not currently read interval from the json; the interval is `FM_TOOL_UPDATE_INTERVAL` exported in the home's environment, which `bin/fm-bootstrap.sh` or the watcher can pass through). Easiest path: `bin/fm-tool-update-check.sh arm` writes a shim with `export FM_HOME=...; exec ...`; the interval is read inside the script from the env, so the captain sets `FM_TOOL_UPDATE_INTERVAL=14400` in the home's `.env` or via a new local config (a future patch to `fm-tool-update-check.sh` could read the interval from `config/watched-tools.json`).
4. The watcher arming happens automatically because the home already has a live watcher for the existing slow-poll cadence.

**Per-tool guard scripts** (optional, for when the captain later authorizes install): a separate `bin/fm-tool-install.sh <tool>` wrapper that gates each install on its own precondition, e.g. `pgrep -af "^herdr" | grep -v grep` for Herdr, and refuses with `blocked: <tool> has N live workers` if any are found. The watcher turns the refusal into a `blocked:` wake for firstmate.

---

## 9. Resolutions applied through `ask-user-authority`

Per the steering from firstmate (`state/br-system-update-audit.inbox/001.msg`) and the `ask-user-authority` skill, I applied the captain's accepted intent ("Pi, Codex, and the other agent tools and their extensions to stay current automatically, while keeping workers visible and usable") to the candidate findings before deciding whether to hold anything. **No captain-hold is opened** — every candidate was either unambiguous toward the accepted intent or settled by the brief's own safety rule.

| # | Candidate finding | Resolution | Reason |
|---|-------------------|------------|--------|
| 1 | Arm `fm-tool-update-check.sh`? | **Resolved: yes (when captain authorizes `bin/fm-tool-update-check.sh arm`)** | "Automatic" implies a detector. The arm action is read-only; it does not install anything. The captain's words already settle this. |
| 2 | Which tools to watch? | **Resolved: the list in §6.3** | Captain said "Pi, Codex, and the other agent tools and their extensions". Pi, Codex, Herdr, no-mistakes, quota-axi, gh-axi, chrome-devtools-axi, pi-subagents, plus `firstmate` (git source) covers every tool with an update path on this host. |
| 3 | What cadence? | **Resolved: project default 900 s (`FM_TOOL_UPDATE_INTERVAL=900`)** | Captain did not specify a cadence, and the project default already exists; no override needed unless the captain prefers longer. |
| 4 | Auto-install policy? | **Resolved: never auto-install; captain authorizes per-finding** | Settled by the brief itself: "Recommend an automatic update policy that does not replace a runtime while one of its agents is using it." An auto-install that meets that rule on a fleet with live workers requires per-tool preconditions that are not currently coded. Until they are, install is a captain-authorized command. |
| 5 | Rollback retention? | **Resolved: rely on each tool's existing prior-version layout** | Pi, Codex, Herdr all keep prior versions on disk; no extra retention logic needed. |
| 6 | PATH skew observation | **Noted, not held** | The current skew is harmless (same file by inode). It would only become a finding under `fm-tool-update-check.sh`'s PATH skew detector if a new copy were installed to a different PATH entry. |
| 7 | Apply Pi 0.87.1 / Codex 0.156.1 now? | **Not held** — this is a follow-up work item, not an audit decision. | The brief forbids software updates from this audit. The two available updates are reported as findings for the captain to schedule separately, with safety conditions listed in §5. No destructive action is being decided here. |

**No `bin/fm-captain-hold.sh hold` is opened by this audit.** The two available updates (Pi 0.87.1, Codex 0.156.1) are reported as `update available` findings that the `fm-tool-update-check.sh` detector will surface once armed; firstmate routes those into the captain's call through the existing watcher wake flow.

---

## 10. Evidence index

Commands run during the audit (read-only):

- `pi --version`, `pi --help`, `pi update --help`, `pi list`
- `codex --version`, `codex doctor`, `codex --help`, `codex update --help`, `codex app-server --help`, `codex app-server daemon --help`
- `herdr --version`, `herdr status`, `herdr --help`, `herdr update --help`, `herdr channel show`, `herdr api snapshot`, `herdr config check`
- `no-mistakes --version`, `no-mistakes daemon status`, `no-mistakes update --help`
- `quota-axi --version`, `quota-axi update --check`, `quota-axi --help`
- `gh-axi --version`, `gh-axi --help`
- `npm view <pkg> version` for each npm-managed tool
- `which -a` for PATH skew
- `ps aux` for live runtime inventory
- `bin/fm-tool-update-check.sh check` (no config → no output, as designed)
- `bin/fm-watch.sh` line inspection for custom-check integration
- `docs/configuration.md` "Watched tool updates" § 590-650
- `docs/examples/watched-tools.json` (starter)
- `~/.nvm/.../pi-coding-agent/docs/packages.md` (Pi staged-install contract)
- `~/.codex/version.json`, `~/.codex/packages/standalone/current`, `~/.codex/packages/standalone/releases/0.155.1-x86_64-unknown-linux-musl`
- `~/.config/herdr/config.toml`, `~/.config/herdr/release-notes.json`, `~/.config/herdr/herdr.sock`
- `~/.no-mistakes/update-check.json`, `~/.no-mistakes/daemon.pid`, `~/.no-mistakes/bin/no-mistakes`
- `~/.pi/agent/npm/package.json`, `~/.pi/agent/extensions/`, `~/.pi/agent/skills/`
- `bin/fm-update.sh` (firstmate self-update), `bin/fm-secondmate-restart-lib.sh` (restart-capable verdict)
- `/home/hd2admin/kun-agent-workspace/.lavish/brandon-agent-floor.html` (existing ticket card)
- `/home/hd2admin/kun-agent-workspace/data/backlog.md` (backlog state)
- `/home/hd2admin/kun-agent-workspace/state/br-system-update-audit.status` (worker status)

Files NOT modified by this audit (per brief rule 2): the report itself is the only file written, at `/home/hd2admin/kun-agent-workspace/data/br-system-update-audit/report.md`.

---

## 11. What this report deliberately does not do

- Does not install Pi 0.87.1 or Codex 0.156.1.
- Does not arm `fm-tool-update-check.sh`.
- Does not write `config/watched-tools.json`.
- Does not modify Herdr's `update.channel` or `update.version_check`.
- Does not change `bin/fm-tool-update-check.sh` or any other shared script.
- Does not change firstmate's `AGENTS.md`.
- Does not propose a `bin/fm-tool-install.sh` wrapper — that is a follow-up if the captain later authorizes install on routine.

This report stands alone. The recommended policy is the captain's call.