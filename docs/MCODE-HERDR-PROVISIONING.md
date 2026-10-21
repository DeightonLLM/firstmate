# mcode on a surface - the recipe that made the lights come on

This is the long form of [`../.agents/skills/mcode-herdr-provisioning/SKILL.md`](../.agents/skills/mcode-herdr-provisioning/SKILL.md).
It records how an mcode (`minimax-code`) lane was brought up on the Controller, the four
things that silently broke it, and the exact commands and probes that prove each one is
fixed. Read it before installing mcode on a new surface; it is not a tutorial, it is a
list of traps that each cost a lane.

Provenance: every failure below was observed live on `vmi3196300` (Controller,
100.117.47.27) on 2026-10-20 and 2026-10-21, not reconstructed.

## Why the recipe exists

mcode is the fastest, cheapest lane worker on the fleet, and it is the one that most
easily looks alive while being broken. A lane that cannot read its home, cannot write
its status file, and cannot register its own agent state still paints a pane, still
answers a prompt, and still consumes a slot. From the outside it looks busy. It is
quietly doing nothing.

Every trap below produces that same shape.

## Trap 1 - the lean-ctx tool jail collapses onto the worktree

`allow_paths` in `/root/.config/lean-ctx/config.toml` must be one real TOML array of
strings. A single quoted string containing a JSON array parses as TOML but is not a list
of paths, and the tool jail then resolves against the lane's own worktree.

What shipped, and what broke every lane on 2026-10-20:

```toml
allow_paths = [
    '["/root"',
    '"/tmp"',
    '"/home"',
    '"/var/log"',
    '"/etc/letsencrypt"]',
]
```

The fixed form:

```toml
allow_paths = [
    "/root",
    "/tmp",
    "/home",
    "/var/log",
    "/etc/letsencrypt",
]
```

Consequence of the broken form: a lane cannot read its brief under `data/<id>/brief.md`,
cannot read the fleet's own `state/`, and cannot append to `state/<id>.status`. It also
cannot read `/root/backup`, so a brief that points at a backup receipt is unreadable.

Repair and probe:

```sh
cp /root/.config/lean-ctx/config.toml /root/backup/lean-ctx-config.toml.bak-jailfix-$(date -u +%Y%m%dT%H%M%SZ)
# edit allow_paths to the array form above
grep -A 8 '^allow_paths' /root/.config/lean-ctx/config.toml
```

One path per line, no nested brackets, no embedded quotes. Anything else is the trap.

Note the sibling lists in the same file: `extra_roots` and `read_only_roots` are real
TOML arrays already and need the same care if you add to them. A `read_only_roots` entry
is how a secondmate's home stays read-only to its own crews.

## Trap 2 - the herdr state hook crashes on a stdlib shadow

herdr manages `/root/.codex/herdr-agent-state.sh`. It runs an embedded
`python3 - <<'PY'`. For a script read from stdin, Python puts the current working
directory on `sys.path`. A lane whose cwd contains `bisect.py`, `random.py`, `json.py` or
`socket.py` therefore shadows a stdlib module.

Observed on 2026-10-20: a lane whose cwd contained `/tmp/bisect.py` failed its
SessionStart hook with rc=1 and a `KeyError: 'TRACKER_PAGE'` traceback raised from
`/tmp/bisect.py`. The lane then reported no agent state to herdr, so firstmate's
supervision saw a pane with no state - indistinguishable from a dead lane.

herdr owns its hook file and expects custom hooks beside it, so the fix is a wrapper,
not an edit:

```sh
cat > /root/.codex/hooks-herdr-agent-state.sh <<'EOF'
#!/usr/bin/env bash
# Custom codex SessionStart hook - safe wrapper around the herdr-managed hook.
#
# WHY THIS EXISTS
#   /root/.codex/herdr-agent-state.sh is installed and managed by herdr ("add
#   custom hooks beside this file instead of editing it"), and it runs an
#   embedded `python3 - <<'PY'`. For a script read from stdin, Python puts the
#   CURRENT WORKING DIRECTORY on sys.path. A lane's cwd that happens to contain
#   a file named bisect.py / random.py / json.py / socket.py therefore SHADOWS a
#   stdlib module and crashes the hook - reproduced on 2026-10-20 with
#   /tmp/bisect.py, which failed the SessionStart hook with rc=1 and a
#   KeyError: 'TRACKER_PAGE' traceback from /tmp/bisect.py.
#
# WHAT THIS DOES
#   Runs the herdr hook from a neutral cwd with PYTHONSAFEPATH set, so the
#   session's working directory can never shadow a stdlib module. It does not
#   change what the hook does, only where its interpreter resolves imports
#   from. stdin is passed straight through (the herdr hook reads the payload
#   from stdin), and every failure of the herdr hook stays a non-fatal, silent
#   no-op exactly as herdr intends.
#
# Install: this file must stay executable, and
#   /root/.codex/hooks.json
# must point its SessionStart entry at it instead of at the herdr script.
set -u

cd / 2>/dev/null || exit 0
export PYTHONSAFEPATH=1
exec bash /root/.codex/herdr-agent-state.sh "$@"
EOF
chmod 0755 /root/.codex/hooks-herdr-agent-state.sh
cp /root/.codex/hooks.json /root/backup/codex-hooks.json.bak-herdr-safe-$(date -u +%Y%m%dT%H%M%SZ)
```

Then point the `SessionStart` entry in `/root/.codex/hooks.json` at
`/root/.codex/hooks-herdr-agent-state.sh`.

Verify:

```sh
test -x /root/.codex/hooks-herdr-agent-state.sh && echo wrapper-ok
grep -n 'hooks-herdr-agent-state' /root/.codex/hooks.json
```

## Trap 3 - the status transport has to exist on the host

A crewmate reports phase changes by appending one line to its status file:

```sh
echo "<state>: <one short line>" >> state/<id>.status
```

A harness whose shell is mediated by the lean-ctx replace-mode deny hook cannot use that
native append: the PreToolUse hook denies the Bash call, the lane never writes a status
event, and firstmate cannot see whether the lane is alive. A denied mandate is a wedge,
not a safety net. The fix keeps the same command and changes only the transport - route
it through the lean-ctx MCP `ctx_shell` tool and name that exact call in the brief:

```
ctx_shell(command="echo \"{state}: {one short line}\" >> '<status file>'")
```

**mcode is not in the replace-mode set.** `bin/fm-brief.sh` carries
`FM_HARNESS_LEAN_CTX_REPLACE="codex"`, and that set deliberately excludes every other
verified harness - claude, opencode, pi, pi-signed, grok, kimi, agy and minimax-code -
because none of them is mediated by lean-ctx replace mode. So an mcode brief keeps the
native transport, and mcode lanes are never told to use `ctx_shell`.

`bin/fm-brief.sh` probes the host read-only before choosing: the deny hook has to be
registered in that harness's hook file and the lean-ctx MCP server that publishes
`ctx_shell` has to be registered for the same host. A host that registers neither keeps
the native transport, so a brief never names a tool the lane does not have.

## Trap 4 - three label formats, three owners

This is the trap that makes a correctly provisioned lane still fail to dispatch, and it
is the one most likely to be rediscovered on a new surface.

| What | Format | Owner |
|---|---|---|
| Preflight lane label | `<domain>-<surface>-<model>-<taskslug>`, exactly four lowercase segments | `/root/bin/fm-dispatch-preflight` |
| Spawn task id (lane key) | `<model>-<surface>-<task>` | `bin/fm-lane-naming-check.sh`, enforced by `bin/fm-spawn.sh` |
| To-Do board row | far-left `[<harness>·<ModelAbbrev> <effort> @<Host>]` | `bin/fm-todo-prefix-check.sh` |

All three are four-segment-shaped except the enforced lane key, which is three
segments. The three-segment lane key is what actually dispatches.

### Preflight lane label

```sh
/root/bin/fm-dispatch-preflight <domain-surface-model-taskslug> <scout|bounded-pi-worker|bounded-pi-checker>
```

The label must be exactly four non-empty lowercase segments, and the agent must be one
of the three approved names. Generic labels (`worker`, `agent`, `task`, `none`) are
refused on purpose.

### Lane key (the spawn task id)

`bin/fm-spawn.sh` gates the task id through `bin/fm-lane-naming-check.sh`:

```sh
bin/fm-lane-naming-check.sh "m3.1f-firstmate-disk"   # PASS
bin/fm-lane-naming-check.sh "mcode-m3.1f-firstmate-disk"   # FAIL, today
```

Model aliases: `m2.7h`, `m2.7`, `m3.1f`, `luna6`, `glm5.3f`, `gem38f`, `pi`.
Surface aliases: `dubz`, `hd2`, `brandon`, `evps`, `firstmate`.
Task: lowercase alphanumeric with hyphens.

The alias derivation rule is in `bin/fm-lane-naming-check.sh` and is single-stated there:
a MiniMax model id like `minimax/MiniMax-M3.1-Flash-Preview` derives to `m3.1f` (family
plus a tier marker - `highspeed` -> `h`, `flash` -> `f`). Model ids from other providers
have no programmatic rule; any alias claimed for them must be verified explicitly.

### To-Do board row

The badge sits at the far left of the row:

```
[mcode·M31F m @Cont] Preflight - confirm you are in an isolated worktree
[mcode·M31F m @Cont] Validation - reconcile the buckets against df
```

The harness token must be one of `pi`, `codex`, `claude`, `opencode`, `mcode`, `grok`,
`kimi`, `agy`. `bin/fm-spawn.sh` extracts the far-left rows of the brief and pipes them
to `bin/fm-todo-prefix-check.sh --stdin`; a brief with no To-Do rows is tolerated.

### The known drift, stated once

`bin/fm-todo-prefix-check.sh --lane-key` documents the lane key as
`<harness>-<model>-<host>-<task>` - four segments, harness first, renewed by the
Captain on 2026-10-18. `bin/fm-lane-naming-check.sh` defines that same four-segment
pattern in `_lane_key_pat` but never wires it into `check_one`, so in practice it accepts
the older three-segment `<model>-<surface>-<task>` form, and `bin/fm-spawn.sh` gates on
it. The comment in `bin/fm-lane-naming-check.sh` says the harness segment "is NOT
optional", which is the intent; the implementation does not enforce it yet.

Two checkers, two owners, one contradiction. Until that is reconciled, probe both
before dispatching:

```sh
bin/fm-lane-naming-check.sh "<candidate>"
bin/fm-todo-prefix-check.sh --lane-key "<candidate>"
```

If they disagree, the spawn-time checker wins, because that is the one on the dispatch
path.

## Dispatch

```sh
FM_DISPATCH_GUARD_LOAD_BYPASS=1 bin/fm-spawn.sh <lane-key> <project-dir> \
  --harness minimax-code --model minimax/MiniMax-M3.1-Flash-Preview --backend herdr [--scout]
```

`--scout` makes it a knowledge-only lane: its deliverable is
`data/<id>/report.md`, never a PR.

`FM_DISPATCH_GUARD_LOAD_BYPASS=1` bypasses the placement guard on a host whose load is
already saturated. It never bypasses a missing dependency, an authentication failure, an
unsupported backend or a version refusal - those are blockers, and the correct response
is to report them, not to retry on another backend.

mcode lanes are visible and supervised. There is no headless mcode path for real task
work: `mcode exec` is not a way to run a crewmate.

## Supervision

```sh
bash bin/fm-watch-arm.sh
```

Arm it as a **tracked background task**. The watcher exits on a wake and must be
re-armed each turn. A lane that is running and unwatched is unsupervised work, and the
failure mode is exactly the quiet one this document is about.

`herdr` pane state is the second supervision signal:

```sh
herdr pane list --workspace <ws>
```

An mcode pane reports its own agent state (`idle` / `working` / `blocked`), so a pane
with `agent_status: unknown` is a pane whose session hook or status path is broken -
go back to Trap 2.

## Verification checklist

```sh
# gate 1 - the jail
grep -A 8 '^allow_paths' /root/.config/lean-ctx/config.toml

# gate 2 - the hook
test -x /root/.codex/hooks-herdr-agent-state.sh && echo wrapper-ok
grep -n 'hooks-herdr-agent-state' /root/.codex/hooks.json

# gate 3 - the transport
grep -n 'FM_HARNESS_LEAN_CTX_REPLACE' bin/fm-brief.sh

# gate 4 - the labels
bin/fm-lane-naming-check.sh "<lane-key>"
bin/fm-todo-prefix-check.sh --stdin <<< '[mcode·M31F m @Cont] a row'

# gate 5 - supervision
herdr pane list --workspace <ws>
tail -5 state/<id>.status
```

## Owners

- `harness-adapters` owns the adapter contract mcode inherits.
- `secondmate-provisioning` owns persistent secondmate homes and inherited material.
- `bin/fm-harness.sh` owns static harness resolution.
- `bin/fm-spawn.sh` owns launch flags and fail-closed validation.
- `bin/fm-brief.sh` owns the brief scaffold, including the status transport choice.
- `docs/herdr-backend.md` owns the herdr runtime, including MCode pane agent state.
- `docs/turnend-guard.md` owns the status-report transport contract.
