---
name: mcode-herdr-provisioning
description: >-
  Agent-only reference for installing and running mcode (minimax-code) lanes on a surface.
  Use before installing mcode on a new host or surface, when an mcode lane is stuck,
  silent, or reports no agent state, and when naming an mcode lane or its To-Do rows.
  Covers the lean-ctx tool jail, the herdr state-hook stdlib shadow, the status transport,
  the three label formats, dispatch, and the supervision arm.
user-invocable: false
metadata:
  internal: true
---

# mcode-herdr-provisioning

Use this reference before installing mcode on any surface, and when an mcode lane is not
behaving. The long form with every command and the evidence behind each claim is
[`docs/MCODE-HERDR-PROVISIONING.md`](../../docs/MCODE-HERDR-PROVISIONING.md).

mcode is the `minimax-code` adapter. On the Controller it runs under the `herdr` runtime
backend and reports its own agent state from the pane, so firstmate can see a lane's
working/idle/blocked state without reading its transcript.

## What "the lights are on" means

A provisioned mcode surface passes all five gates. Check them in order; each gate has a
cheap read-only probe.

1. **The lane can read its home and write its status.** The lean-ctx tool jail is not
   collapsed onto the worktree.
2. **The session hook does not crash.** The herdr state hook resolves stdlib imports
   from a neutral directory, not from the lane's cwd.
3. **The lane can report phase changes.** Its status transport is one it actually has.
4. **The lane is named in every format at once,** and each format is the one its own
   checker expects.
5. **The lane is supervised.** The current session's supervision protocol is healthy and the pane reports an agent state.

A lane that fails gate 1 or gate 2 still *runs*, and still looks alive in the pane, while
being unable to read its brief or report progress. That is the failure this skill exists
to prevent.

## Gate 1 - the lean-ctx tool jail

`allow_paths` in `/root/.config/lean-ctx/config.toml` must be **one real TOML array of
strings**. A single quoted string that happens to contain a JSON array is not a list of
paths. The reported consequence (the jail collapsing onto the lane's worktree and blocking
home, brief, fleet-state, and status access) is historical incident evidence; this checker
confirmed the malformed backup text but did not recreate that runtime effect.

The following malformed form is preserved in the pre-jailfix backup dated
2026-10-20. The original incident is recorded by the author; this checker did not
reproduce its historical lane failure:

```toml
allow_paths = [
    '["/root"',
    '"/tmp"',
    '"/home"',
    '"/var/log"',
    '"/etc/letsencrypt"]',
]
```

Correct:

```toml
allow_paths = [
    "/root",
    "/tmp",
    "/home",
    "/var/log",
    "/etc/letsencrypt",
]
```

Back the file up before editing it and keep the backup outside the jail:
`/root/backup/lean-ctx-config.toml.bak-jailfix-<timestamp>`.

Probe: `grep -A 8 '^allow_paths' /root/.config/lean-ctx/config.toml` shows one path per
line with no nested brackets or embedded quotes.

## Gate 2 - the herdr state hook and the stdlib shadow

The current `/root/.codex/herdr-agent-state.sh` contains an embedded
`python3 - <<'PY'`. A script read from stdin can put the **current working directory** on
`sys.path`, so a lane whose cwd contains `bisect.py`, `random.py`, `json.py` or
`socket.py` can shadow a stdlib module. The reported 2026-10-20 reproduction (rc=1,
`KeyError: 'TRACKER_PAGE'` from `/tmp/bisect.py`) is historical evidence from the
original author and was not independently recreated by this checker.

herdr owns its own hook file and expects custom hooks beside it, so do not edit it.
Install a wrapper instead, keep it executable, and point the host's hook registration at
it:

```sh
cat > /root/.codex/hooks-herdr-agent-state.sh <<'EOF'
#!/usr/bin/env bash
# Safe wrapper around the herdr-managed state hook.
# Runs it from a neutral cwd with PYTHONSAFEPATH set so the session's working
# directory can never shadow a stdlib module. stdin passes straight through and
# every herdr-hook failure stays a silent no-op, exactly as herdr intends.
set -u
cd / 2>/dev/null || exit 0
export PYTHONSAFEPATH=1
exec bash /root/.codex/herdr-agent-state.sh "$@"
EOF
chmod 0755 /root/.codex/hooks-herdr-agent-state.sh
```

Register it in `/root/.codex/hooks.json` as the `SessionStart` entry, and back that file
up first: `/root/backup/codex-hooks.json.bak-herdr-safe-<timestamp>`.

## Gate 3 - the status transport

A crewmate reports phase changes by appending one line to its status file:

```sh
echo "<state>: <one short line>" >> state/<id>.status
```

**mcode is not in the lean-ctx replace-mode set.** Only `codex` is mediated by the
lean-ctx replace-mode deny hook, so mcode briefs keep the native transport above. A
brief never names a tool the lane does not have: if a harness *is* mediated, the brief
routes the same command through the lean-ctx MCP `ctx_shell` tool instead, and
`bin/fm-brief.sh` probes the host read-only to decide which transport to write.

## Gate 4 - three label formats, three owners

These are genuinely three different things. Confusing them is the most common reason a
correctly-provisioned lane still fails to dispatch.

| What | Format | Owner |
|---|---|---|
| Preflight lane label | `<domain>-<surface>-<model>-<taskslug>`, exactly four lowercase segments | `/root/bin/fm-dispatch-preflight` |
| Spawn task id (lane key) | `<model>-<surface>-<task>` | `bin/fm-lane-naming-check.sh`, enforced by `bin/fm-spawn.sh` |
| To-Do board row | far-left `[<harness>·<ModelAbbrev> <effort> @<Host>]` | `bin/fm-todo-prefix-check.sh` |

Lane key segments: model aliases `m2.7h`, `m2.7`, `m3.1f`, `luna6`, `glm5.3f`, `gem38f`,
`pi`; surface aliases `dubz`, `hd2`, `brandon`, `evps`, `firstmate`; task is lowercase
alphanumeric with hyphens.

To-Do prefix: the harness token must be one of `pi`, `codex`, `claude`, `opencode`,
`mcode`, `grok`, `kimi`, `agy`, and the badge must sit at the far left of the row.

Known drift, stated so it is not rediscovered: `bin/fm-todo-prefix-check.sh --lane-key`
documents the lane key as `<harness>-<model>-<host>-<task>` (four segments, harness
first), while `bin/fm-lane-naming-check.sh` accepts the three-segment
`<model>-<surface>-<task>` form. `bin/fm-spawn.sh` gates the task id through the latter,
so **the three-segment form is the one that dispatches**. Probe both before assuming:

```sh
bin/fm-lane-naming-check.sh "<candidate-lane-key>"
bin/fm-todo-prefix-check.sh --lane-key "<candidate-lane-key>"
```

## Dispatch and supervision

```sh
/root/bin/fm-dispatch-preflight <domain-surface-model-taskslug> <scout|bounded-pi-worker|bounded-pi-checker>
FM_DISPATCH_GUARD_LOAD_BYPASS=1 bin/fm-spawn.sh <lane-key> <project-dir> \
  --harness minimax-code --model minimax/MiniMax-M3.1-Flash-Preview --backend herdr [--scout]
```

The bypass flag is only for a host whose load is already saturated; it bypasses the
placement guard, never a missing dependency or an authentication failure.

The visible-pane and no-headless-mcode-work statements are the recorded Firstmate
adapter contract, not independently exercised here. Do not treat the dispatch example
above as verified: running it would spawn a worker, outside this read-only verification.

Use the Firstmate session's emitted supervision protocol for its primary harness.
Do not manually run `bin/fm-watch-arm.sh` or start a second watcher: the Pi extension
owns arming and re-arming, and manual arming is reserved for a notification that the
cycle is missing, failed, or unhealthy. Watcher lifecycle is surface- and
harness-dependent; follow that surface's current session instructions.

## Verification checklist

```sh
grep -A 8 '^allow_paths' /root/.config/lean-ctx/config.toml   # gate 1: one path per line
test -x /root/.codex/hooks-herdr-agent-state.sh && echo ok        # gate 2: wrapper executable
grep -n 'hooks-herdr-agent-state' /root/.codex/hooks.json        # gate 2: registered
herdr pane list --workspace <known-ws>                           # gate 5: inspect pane state
tail -5 state/<known-id>.status                                  # gate 3: inspect lane reports
```

## Durable sources

- [`docs/MCODE-HERDR-PROVISIONING.md`](../../docs/MCODE-HERDR-PROVISIONING.md) - long form
- [`docs/herdr-backend.md`](../../docs/herdr-backend.md) - herdr runtime and MCode pane state
- [`docs/turnend-guard.md`](../../docs/turnend-guard.md) - status-report transport
- [`docs/AGENT-TODO-PROMPT-STYLE.md`](../../docs/AGENT-TODO-PROMPT-STYLE.md) - the board prefix standard
- `bin/fm-lane-naming-check.sh`, `bin/fm-todo-prefix-check.sh`, `bin/fm-spawn.sh` - the checkers
- `harness-adapters` - the adapter contract mcode inherits
- `secondmate-provisioning` - persistent secondmate homes
