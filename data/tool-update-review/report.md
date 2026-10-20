# Tool-update implementation review (fm/tool-auto-update)

Scope: read-only inspection of the two commits on `fm/tool-auto-update` in the
target worktree at `/home/hd2admin/.treehouse/firstmate-46aafc/4/firstmate`,
plus `docs/configuration.md` and `docs/examples/watched-tools.json`. No
tests, installs, or writes were performed; all behaviour claims below are
grounded in file:line evidence from the target tree. Where a claim requires
running the scripts to confirm, it is marked **unverified**.

## Commits under review

- `8f6216b` feat(bin): safe watched-tool update detector and staged-install
  orchestrator — adds `bin/fm-tool-update-check.sh`, `bin/fm-tool-install.sh`,
  `bin/fm-tool-live.sh`, the docs section, and the example registry.
- `70a8ca1` fix(tool-install): drive scheduled path through update detection
  and include pi extensions — wires the shim to actually pick one tool from
  the detector record, runs `pi update --extensions` after a successful
  `pi update --self`, and introduces the `partial` outcome / rc=126 sentinel.

## What the implementation actually does

### Tool detection — verified by reading

`bin/fm-tool-update-check.sh` reads the operator-owned
`config/watched-tools.json` (local, gitignored) and runs two parallel kinds
of probes inside a per-sweep budget that fits inside the watcher's
`FM_CHECK_TIMEOUT` (default 30s; `bin/fm-tool-update-check.sh:138-155`).

1. **PATH probes** (`bin/fm-tool-update-check.sh:418-510`): every executable
   copy of `command` on PATH is deduplicated by device/inode, each is asked
   for its version under a per-probe bound (`fm_run_timed`,
   `bin/fm-tool-update-check.sh:240-262`), and the highest version found is
   compared with what PATH actually resolves first. Two distinct findings
   are emitted: `update available` (via `announce_pattern` against
   `announce_args`, lines 466-487) and `update not in effect` (PATH skew,
   lines 497-499).
2. **Git probes** (`bin/fm-tool-update-check.sh:528-635`): read-only
   `rev-parse`, `symbolic-ref`, `ls-remote`, `cat-file`, `merge-base`,
   `rev-list` against the watched `repo`/`remote`/`branch`. Default branch
   is resolved via `refs/remotes/<remote>/HEAD` or `ls-remote --symref`
   when the symref is missing. Each probe goes through `git_probe`
   (lines 514-518), which checks the sweep budget before issuing the call,
   so a probe cannot run past the deadline.

Version parsing (`parse_version`, lines 277-279) returns the first dotted
number in the output; `version_newer` (lines 282-301) does numeric per-component
comparison with `10#` to strip leading zeros. Both work for `1.46.0` /
`v1.46.0` / `0.10.0 vs 0.9.0` (numeric not lexicographic), but **silently
return empty** for any tool that prints only a non-dotted version
("Pi 1.46 (build 12345)"), which is reported as a `check failed` finding
rather than silently treated as current (lines 502-504).

### Update application — verified by reading

`bin/fm-tool-install.sh` is gated by `bin/fm-tool-live.sh` (the only call
site, `bin/fm-tool-install.sh:218-235`). The live-worker detector returns
four states with fail-closed semantics
(`bin/fm-tool-live.sh:108-115`):

- `0` no live workers — install may proceed
- `1` workers present — install refused
- `2` unknown tool — `manual-required`
- `3` state cannot be established (herdr api unreachable, pgrep missing,
  codex daemon refusing, no-mistakes daemon missing) — orchestrator records
  `unverifiable`, install does NOT proceed

The explicit allowlist `install_rule_for` (`bin/fm-tool-install.sh:196-212`)
covers only `pi`, `codex`, `herdr`, `no-mistakes`. Everything else falls
through to `install_npm_tool` (lines 288-291) which always refuses and
records `manual-required` — `npm install -g` is never auto-invoked. No
`--force` flag is ever used; no shell `&` background job is ever launched
(verified by inspection: no `&` in either script); preview/beta channels
are never selected.

The per-tool install calls and bounds:

| Tool            | Command                              | Bound           | Notes |
|-----------------|--------------------------------------|-----------------|-------|
| pi self+ext     | `pi update --self` then `pi update --extensions` | 120s default, shim overrides to `FM_CHECK_TIMEOUT-5` (25s with defaults) | Partial rc=126 on ext failure (`bin/fm-tool-install.sh:363-369`) |
| codex           | `codex update`                       | 120s / shim 25s | Symlink flip in `~/.codex/packages/standalone/releases/<ver>-<arch>/current` |
| herdr           | `herdr update` (no `--handoff`)      | 120s / shim 25s | Client-only; live server kept running; server restart left as pending record |
| no-mistakes     | `no-mistakes update`                 | 120s / shim 25s | Daemon itself refuses when runs are active; gate is double-defense |
| npm             | (refused)                            | n/a             | Always recorded as `manual-required` |

The `herdr update` path explicitly does NOT restart the live server
(`bin/fm-tool-install.sh:278-281` comment) — the install record carries a
`installed` status with reason `"client installed via herdr update; live
server and panes kept running; server restart remains pending for a quiet
window"`, and the orchestrator never performs the restart itself.

### Failure and rollback — verified by reading

Every install writes one atomic JSON object per tool to
`state/.tool-installs/<tool>.json` via `record_outcome`
(`bin/fm-tool-install.sh:404-435`). Each record carries `schema`,
`tool`, `status`, `reason`, `epoch`. Outcome states are:

`installed`, `partial`, `blocked`, `unverifiable`, `manual-required`,
`refused`, `failed`, `staged`.

The shim scan (`bin/fm-tool-install.sh:553-588`) only surfaces
non-installable outcomes since the previous poll's `epoch_file`, so each
finding prints once and stays quiet until rewritten with a fresh epoch.
The detector's record at `state/.tool-updates` is similarly written
atomically via `record_write` (`bin/fm-tool-update-check.sh:660-672`)
with mode 0600.

There is no install rollback beyond what each tool's own staged path does.
The orchestrator never reverts an installed binary; it records the outcome
and waits for the next poll. This is the right boundary: a partial install
gets a fresh `partial` outcome that is re-attempted only after the
`FM_TOOL_INSTALL_RETRY_SECS` (default 3600s) cooldown
(`bin/fm-tool-install.sh:469-478`).

### Scheduled path includes Pi extensions — verified by reading

The fix in `70a8ca1` added `pi update --extensions` to the install
sequence (`bin/fm-tool-install.sh:235-261`) and introduces a separate
`partial` status (`bin/fm-tool-install.sh:357-370`) so a successful
self-update with a failing extensions update is recorded rather than
silently retried as a full failure. Without `70a8ca1`, the scheduled
shim only surfaced prior outcome records and never invoked any install
(`70a8ca1` commit message line 4), so the staged path was inert without
this fix.

### Configuration pinning vs. silent change — verified by reading

**Versions are not pinned.** `bin/fm-tool-update-check.sh` accepts any
newer version the detector can see; the orchestrator's `install_rule_for`
calls each tool's `update` subcommand with no version argument. The
operator can influence which channel is picked only by setting
`FM_TOOL_UPDATE_INTERVAL`, `FM_TOOL_UPDATE_PROBE_SECS`,
`FM_TOOL_UPDATE_BUDGET_SECS`, `FM_TOOL_INSTALL_RETRY_SECS`,
`FM_INSTALL_BOUND_SECS`, and `FM_TOOL_LIVE_BOUND_SECS` (env-var override
points documented in both script headers). None of these pin a version.

**Configuration is local-only.** `config/watched-tools.json` is read from
`$FM_CONFIG_OVERRIDE` then `$FM_HOME/config/`; the file is described as
"local and gitignored" (`bin/fm-tool-update-check.sh:55`,
`docs/configuration.md:152-153`). The detector's `record_read` accepts
`epoch=` and `reported=` lines without any other field, so a tampered
record is read but the install orchestrator only consults the `reported=`
line (`bin/fm-tool-install.sh:418-441`), making accidental schema
extension hard.

**State files are private.** Detector record at `state/.tool-updates`
is mode 0600 (`bin/fm-tool-update-check.sh:663-668`); per-tool install
records at `state/.tool-installs/<tool>.json` are mode 0600
(`bin/fm-tool-install.sh:425-428`); the trusted-check shims at
`state/tool-{updates,installs}.check.sh` are mode 0700 with their
`.check-trust` companion at mode 0600 (`bin/fm-tool-install.sh:613-617`
plus `bin/fm-check-register.sh:43-46`). The watcher validates shim bytes
against the trust hash before exec
(`bin/fm-check-lib.sh:48-72`); a hand-written shim with arbitrary content
is rejected because the hash mismatch causes
`fm_custom_check_snapshot_prepare` to refuse.

### Watcher wiring — verified by reading

`bin/fm-tool-install.sh --arm` and `bin/fm-tool-update-check.sh arm` write
their respective shims and bind them via `fm-check-register.sh`
(`bin/fm-tool-install.sh:649-678`, `bin/fm-tool-update-check.sh:805-839`).
Both registers call `fm_custom_check_registered` which validates the
shim's sha256 against the trust file. The watcher (`bin/fm-watch.sh:804`)
iterates `state/*.check.sh`, falls into `fm_custom_check_snapshot_prepare`
for each, and runs the snapshot under `CHECK_TIMEOUT` (default 30s). The
two new shims are picked up by the same mechanism as any other custom
check; no watcher changes were needed.

## Genuine gaps and concrete risks

These are ordered roughly by safety impact. Each item names the file:line
where the gap lives.

### 1. Shim-imposed 25s bound is too tight for `pi update --extensions`

`bin/fm-tool-install.sh:484-490` (the new `install_bound_secs`) sets the
shim-driven bound to `FM_CHECK_TIMEOUT - 5`, i.e. 25s with defaults. Both
`pi update --self` and `pi update --extensions` are then bounded to 25s
because `run_install_fn` honours `FM_INSTALL_BOUND_SECS`
(`bin/fm-tool-install.sh:154-180`). Pi's extension update is an npm-driven
install of every enabled extension; on a host with several extensions and
a slow npm registry this routinely exceeds 25s. When it does, the script
records `blocked` with reason `install hit the 25s shim-imposed bound`
(`bin/fm-tool-install.sh:374-385`), the shim surfaces it once
(`bin/fm-tool-install.sh:566-575`), and the next poll within the 3600s
cooldown skips the tool. **Result: a real Pi update can be silently
dropped for an hour after one slow poll.** The same applies to `codex
update` (downloads a release) and `no-mistakes update` (npm-driven) on a
slow network. **Unverified** for specific network speeds; the math is
visible.

**Recommendation:** cap only `pi update --extensions` (the npm half) with
the 25s bound, not the self-update; or lift the shim-imposed cap and let
the watcher's hard `CHECK_TIMEOUT` kill the install at 30s as the safety
net. The current per-call cap was added by `70a8ca1` precisely because
the shim did not bound before; the right size is closer to `FM_CHECK_TIMEOUT
- 1` than `- 5`.

### 2. Codex live-worker detector does not match its docstring

`bin/fm-tool-live.sh:25-29` claims that "the codex app-server daemon is
its own category: when it is running and bound to a known session, every
agent that shares that session is a live worker for codex, and the
`codex update` symlink flip is only safe between sessions." The
implementation (`bin/fm-tool-live.sh:209-234`) only checks Herdr panes
that report `agent == codex`, then falls back to `pgrep -f codex`. There
is no `codex app-server` daemon detection anywhere in the script. Per
`bin/fm-busy-lib.sh:108-114` the Codex app-server daemon cannot be
started outside the managed standalone install (`codex app-server daemon
start` refuses), so on a typical host this gap is dormant — but on a host
where the daemon IS running, the gate would falsely report `count=0`,
the install would proceed, and a symlink flip during an active daemon
session could break in-flight turns. **Verified by inspection.**

**Recommendation:** either remove the docstring claim or add a
process-level probe for the app-server daemon (e.g. `pgrep -f
"codex.*app-server"` as a third fallback). The current implementation
matches the more cautious header but contradicts the documented contract.

### 3. `update not in effect` findings have no remediation path

`bin/fm-tool-update-check.sh:497-499` emits the `update not in effect`
finding, and `docs/configuration.md:162-164` documents it. But
`update_available_tools` in `bin/fm-tool-install.sh:418-441` only matches
the `update available:` finding, not `update not in effect:`. So the
install orchestrator never acts on PATH skew, and the operator is left
to fix it manually. The detector itself never reorders PATH either
(`bin/fm-tool-update-check.sh:24-25` documents this as a deliberate
boundary). This is consistent design — but it means a permanent PATH
skew finding will re-surface forever until the operator edits PATH or
removes the older binary, with no install-side help.

**Recommendation:** the docstring's `update not in effect` claim should
either gain a one-line "no auto-fix; fix PATH manually" note in
`docs/configuration.md` or the orchestrator should expose a non-install
action that surfaces the skew with remediation instructions. As written,
the finding can wake firstmate indefinitely.

### 4. `no-mistakes` announce pattern is unverified

`docs/examples/watched-tools.json:18-22` configures no-mistakes with
`announce_args: ["--help"]` and `announce_pattern: "A new version of
no-mistakes is available: [^ ]+ -> [^ ]+"`. The detector comment at
`bin/fm-tool-update-check.sh:413` says "no-mistakes announces its update
on stderr". `docs/configuration.md:162` describes this as "no-mistakes'
`--help` line". These three sources disagree on the surface (stderr vs
help vs help-line) — `announce_args` only changes the command, not the
stream. The detector does combine stdout and stderr
(`bin/fm-tool-update-check.sh:419-422`), so a stderr announcement is
captured. But if no-mistakes does NOT print the announcement on `--help`
at all, the detector will silently never emit `update available` for
no-mistakes, and the auto-install path will never trigger. **Unverified**
without running no-mistakes.

**Recommendation:** the example should be tested by running
`no-mistakes --help` against a known-newer no-mistakes install, or the
example should be removed and replaced with a no-mistakes entry that
relies on version-only detection (no `announce_args`/`announce_pattern`).

### 5. `--disarm` does not match its help text

`bin/fm-tool-install.sh:73` and the `usage` block at `bin/fm-tool-install.sh:101-107`
advertise `--disarm` as "remove that shim, its trust binding, and the
per-tool install record directory". The implementation at
`bin/fm-tool-install.sh:669-674` only removes the shim and the trust
file. The `state/.tool-installs/` directory, the `.last-attempted-tool`,
`.last-seen-epoch`, and any leftover `.candidates.*` files all persist.
By contrast, `bin/fm-tool-update-check.sh:872-876` removes the shim, the
trust file, AND the detector record (`$RECORD`). The two disarms are
inconsistent.

**Recommendation:** `--disarm` should either rm -rf the per-tool install
directory (with a clear "destructive: clears history" warning), or its
help text should be tightened to "remove the shim and its trust binding;
records remain for operator inspection".

### 6. Missing config produces silent failure on the shim path

`bin/fm-install.sh` and `bin/fm-tool-install.sh:147-148` both exit 1 with
a stderr message when `config/watched-tools.json` is missing. The shim
runs under `run_check_capture` (`bin/fm-watch.sh:553-590`) which discards
stderr and only surfaces non-empty stdout. So a missing config (e.g. a
home where the operator never copied the example) yields no wake line,
and the operator sees a permanently idle shim. Same for a jq-missing
host (`bin/fm-tool-install.sh:148`). **Verified by inspection.**

**Recommendation:** the shim path should print a one-line "no
config/watched-tools.json" finding to stdout when the config is missing,
so firstmate wakes on the misconfiguration.

### 7. Pi install path does not propagate `FM_INSTALL_BOUND_SECS` to per-half rc reporting

`install_pi_tool` (`bin/fm-tool-install.sh:235-261`) returns `126` when
extensions fail after a successful self-update. The `126` case is mapped
to `partial` only for `kind=pi` (`bin/fm-tool-install.sh:357-369`). Any
future code path that returns 126 (e.g. a multi-step install for another
tool) would be misrecorded as `failed` because the default 126 branch
falls through to `record_outcome ... failed`. The sentinel is documented
in `bin/fm-tool-install.sh:78-82` and is correct for the current single
caller; the gap is that adding a second `126`-returning tool would need
a matching `pi`-style case arm.

**Recommendation:** treat `126` as `partial` for any kind, not just `pi`,
or guard it more explicitly.

### 8. No test coverage

`tests/` contains no `fm-tool-install`, `fm-tool-update-check`, or
`fm-tool-live` tests. The repo's own `bin/fm-lint.sh` runs ShellCheck 0.11
in CI but cannot be exercised here (ShellCheck is not installed in this
inspection environment; `bash -n` syntax checks pass on all three
scripts). The detector's PATH-probe logic, the orchestrator's
allowlist/cooldown/rotation, and the live worker's four exit states are
all complex enough to warrant unit tests, especially the `parse_version`
regex and the round-robin cooldown math. **Verified by listing
`tests/*tool*` and `tests/*update*` — only `fm-update.test.sh` (firstmate
self-update) exists, plus pretool-check tests.**

### 9. Single-tool-per-poll rotation can starve failing tools

`shim_pick_tool` (`bin/fm-tool-install.sh:443-510`) advances
`last_attempted-tool` to the picked tool regardless of install success.
Combined with the cooldown filter (`bin/fm-tool-install.sh:469-478`),
this is OK — a failing tool is excluded from candidates within its
cooldown. But between cooldowns, the rotation only wraps when every
tool has been attempted; on a 5-min poll cadence and 4 tools with
updates, a pi failure at poll N is re-attempted no sooner than poll
N+4 (≈20 min later) plus the cooldown if applicable. This is fair but
slow. Not a safety gap; just a latency observation. **Verified by
reading.**

## Verified safety properties (positive findings)

These are the things the implementation actually does well:

- **No `--force` flag, no shell `&` background job, no preview channel,
  no live Herdr server restart by this path** — verified by grep across
  all three scripts.
- **Live-worker gate fails closed** with `exit 3` whenever state cannot
  be established (herdr api unreachable, pgrep missing, codex daemon
  refusing, no-mistakes daemon missing). Verified by reading all four
  `case "$KIND"` arms in `bin/fm-tool-live.sh:179-289`.
- **Allowlist is narrow and explicit** — `install_rule_for` returns
  empty for everything except `pi|codex|herdr|no-mistakes`. npm-managed
  tools (`gh-axi`, `chrome-devtools-axi`, `quota-axi`) are always
  `manual-required`. Verified by reading `bin/fm-tool-install.sh:196-212`.
- **Detector is read-only** — no install, no PATH reorder, no `git fetch`
  into a watched repository. Every git probe is in the documented
  read-only set (`bin/fm-tool-update-check.sh:51-54`).
- **Shim bytes are validated against a trust hash** before exec
  (`bin/fm-check-lib.sh:48-72`). A hand-written `state/tool-installs.check.sh`
  is rejected because `fm_custom_check_registered` returns false.
- **Sweep is bounded to fit inside the watcher timeout**
  (`bin/fm-tool-update-check.sh:147-156`). A budget larger than
  `FM_CHECK_TIMEOUT - 3` is cut, not refused, with the cut reported on
  the line so the operator sees it (lines 158-164).
- **Cooldown prevents repeated hammering** of blocked/manual-required
  outcomes (`bin/fm-tool-install.sh:469-478`). Default 3600s; tunable.
- **Records are atomic** — both the detector record
  (`bin/fm-tool-update-check.sh:660-672`) and per-tool install records
  (`bin/fm-tool-install.sh:404-435`) are written via mktemp + mv with
  mode 0600.
- **Path skew is measured, not inferred** — every executable copy on
  PATH is asked for its version; a directory name is never read as a
  version (`bin/fm-tool-update-check.sh:13-22`).
- **`pi update --extensions` is included** in the scheduled path
  (post-`70a8ca1`) with its own partial outcome so a successful
  self-update plus failed extensions does not look like a clean install.

## Captain-owned decisions

The following items are not gaps to fix unilaterally; they need explicit
captain authorization:

1. **Allowlist widening.** The example config ships `gh-axi`,
   `chrome-devtools-axi`, `quota-axi` as watched-but-manual-required.
   Auto-installing any npm-managed global requires adding an
   `install_rule_for` arm and a `live_specs` kind. The current policy
   keeps these manual; that is a deliberate captain boundary, not a bug.
2. **Detector interval default of 900s.** Tighter polling would catch
   new versions faster at the cost of more PATH and git probes per
   home. The default is conservative; operators can lower it.
3. **Cooldown default of 3600s for non-installable outcomes.** Shorter
   cooldowns would re-attempt faster but could mask a persistent
   misconfiguration. The current default is operator-friendly.
4. **`update not in effect` has no auto-fix.** PATH reordering is
   invasive and tool-specific; the orchestrator deliberately does not
   touch PATH. The captain may decide this needs an automated remediation
   path (e.g. `fm-tool-install.sh --fix-path <tool>`).

## Recommended next actions

In priority order, with the smallest blast radius first:

1. **Lift the per-call 25s bound for `pi update --extensions`** or split
   the self-update and extensions halves so the npm half gets the full
   `FM_CHECK_TIMEOUT - 1` budget. (Gap #1.)
2. **Add Codex app-server daemon detection** or remove the docstring
   claim. (Gap #2.)
3. **Align `fm-tool-install.sh --disarm` behavior with its help text.**
   Either rm-rf the install directory with a warning or tighten the
   help. (Gap #5.)
4. **Surface "missing config" / "missing jq" as a shim finding** so
   firstmate wakes on the misconfiguration. (Gap #6.)
5. **Verify the no-mistakes announce pattern by hand** and either keep
   the example or remove the announce fields. (Gap #4.)
6. **Add behavioral tests** for `parse_version`, `version_newer`, the
   `install_rule_for` allowlist, and `shim_pick_tool` rotation/cooldown.
   (Gap #8.)

No immediate blocker to landing — the implementation is materially safer
than the no-script status quo, and the gaps above are fixable in follow-up
commits.
