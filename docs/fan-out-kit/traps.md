# Traps — every failure measured on 2026-10-23, how it presents, how to detect it, how to fix it

Each entry is a **measurement**, not a theory. If you meet a symptom that is not here, measure it
and add it here — that is how this list stays true.

---

## 1. Alive but not working

**Presents**: every lane's process exists, the fleet looks busy, nothing is delivered.
**Measured**: six codex lanes sat on a *"Hooks need review — 7 hooks are new or changed"* modal for
**35 minutes with zero CPU time and no model call**. The Codex CLI opens that modal when hooks
changed since the last trust; an unattended lane never answers it.
**Detect**: `ps -o pid,etime,time,pcpu -C codex` — CPU time flat at `00:00:00`; or the thread's
`updated_at` in `~/.codex/state_5.sqlite` not moving.
**Fix**: launch with `--dangerously-bypass-hook-trust` (the CLI's own flag: *"for automation that
already vets hook sources"*). Proven both ways on the same host.

## 2. One cycle, six lanes, one row

**Presents**: a dry run prints the same task for every empty slot.
**Cause**: the in-flight set was built once at the start of the cycle and never refreshed after a
spawn, so every selection in that cycle saw the same queue.
**Detect**: the dry run itself — `fm-always-four.sh cycle` in dry-run mode.
**Fix**: rebuild the in-flight set inside the selection function. **Prove it**: the next real run
must show six lanes with six different planning ids in their metas.

## 3. The CLI accepted, the service refused

**Presents**: the CLI accepts a model id and exits 0 or prints an error the fleet ignores.
**Measured**: `codex exec --model openai-codex/gpt-6-luna` → **400** *"The 'openai-codex/gpt-6-luna'
model is not supported when using Codex with a ChatGPT account."* The same command with the bare
`gpt-6-luna` answered. Meanwhile `pi --model openai-codex/gpt-6-luna` answers the **qualified**
form correctly.
**Detect**: probe with a **distinctive token** (`Reply with exactly: TOKEN-1234`) and check the
reply. A catalog line is not evidence.
**Fix**: keep the canonical id in the meta, the lane key and the provider attribution; hand the
CLI the form that service accepts. The two adapters are different and must not be conflated.

## 4. Recorded failure, live worker

**Presents**: the spawn is logged FAILED, yet a worker exists and holds a worktree.
**Cause**: the worktree wait expired while `treehouse get` was still creating the worktree.
**Detect**: the pane exists with a worker, the lane slot still points at the old task.
**Fix**: make the settle window tunable (`FM_TREEHOUSE_SETTLE_SECS`, default unchanged) **and**
raise it only where it was measured.

## 5. Attempt cap spent by a defect that is already fixed

**Presents**: `no replacement needed (active=0, terminal=4)` while workers run; every lane at
`attempts=3/3`.
**Cause**: the cap counted spawn attempts from the era of the lane-key bug. The bug is fixed; the
counters are not.
**Detect**: `cat state/lane-00*.attempts`.
**Fix**: reset the stale counters (with per-file backups). The cap is a brake on *repeated
failure*, not a memorial to one.

## 6. The slot never frees

**Presents**: `herdr tab 'fm-<lane-key>' already exists in workspace w70` — the same lane key
cannot be re-spawned because the finished lane's tab is still open.
**Cause**: settled lanes are never reaped. The reaper is inert (trap 8) and `cap.sh` /
`herdr-pane-close-safe` are absent on that host.
**Detect**: the refusal message; `tmux list-panes` / the pane list.
**Fix**: for a lane whose artifact is **collected**, retire its meta (back it up first) so the slot
reuses; the tab can stay. Never close a pane that is provably working.

## 7. A default-configured daemon replaces the configured one

**Presents**: the fleet suddenly runs a retired model, or GLM on a surface where GLM is barred, or
a different lane ceiling.
**Measured**: a second always-four daemon started on the Hetz workspace with **no lane
configuration at all** — target 4, worker `MiniMax-M2.7` (retired), checker `GLM-5.3-Flash`
(**barred on Brandon's surface**), live-lane ceiling 15.
**Detect**: read the daemon's `/proc/<pid>/environ` — `fm-always-four.sh status` over a plain ssh
shows the **script defaults**, not what is running.
**Fix**: stop the stray daemon (SIGTERM to its own pid) and start the configured launcher through
`fm-afk-launch.sh`. Then check the environ again.

## 8. The classifier and the reaper are inert

**Presents**: a lane's busy state is always `unknown no-target`; settled panes are never closed.
**Cause**: `fm-always-four.sh` sources `fm-crew-state.sh` in a **sub-shell**, so the backend
library's functions are discarded.
**Detect**: the classifier's output for a known-busy lane.
**Fix**: source it in the current shell with a safe argument, or export the functions it defines.
This changes fleet-wide capacity accounting — report it, and get the word.

## 9. The active-lane counter skips every live lane

**Presents**: `active=0` while lanes demonstrably run.
**Cause**: the counter matches **only the retired M2.7 model strings**, so every M3.1 lane is skipped
before the classifier runs. An independent second cause of the same symptom as trap 8.
**Fix**: match the current model family too. Again: this changes how the fleet counts itself.

## 10. The project lock

**Presents**: `another spawn or cleanup holds the shared project lock … refusing to race its
capacity admission`.
**Cause**: a spawn holds the shared Treehouse project lock while it allocates a worktree. An
operator re-spawn and the daemon's own refill collide.
**Detect**: the message; the lock owner dir under `state/.treehouse-project-*.lock.owner.*` records
the holder's pid.
**Fix**: wait, do not bypass. The lock did its job. Read the holder's pid before assuming the lock
is stale — a stale-looking lock is often a live spawn.

## 11. lean-ctx blocks the tools you would verify with

**Presents**: `lean-ctx refused sha256sum and openssl because they are not allowlisted`.
**Effect**: a lane told to verify a baseline pointer **by hash** cannot, and must not fake it.
**Fix**: say `UNVERIFIED` and state why. Never widen an allowlist to make a verification pass.

## 12. The brief contradicts the completion gate

**Presents**: every package returns `VERDICT: FAIL` with a gate as the reason, even though the
analysis is complete and good.
**Cause**: the scaffolded brief requires the `decision-hold-lifecycle` completion gate (register
each unresolved decision with `bin/fm-decision-hold.sh hold`), while the task text said "read-only:
do not modify any repo file".
**Detect**: the failure reason names the gate.
**Fix**: the brief must say which wins. The working wording: the decision-hold registration
**inside the lane's own worktree** is required and is the only repo write authorised.

## 13. "Missing binary" that is only a PATH

**Presents**: `command -v mcode` → missing; `command -v codex` → missing.
**Cause**: non-login shells do not carry `~/.local/bin` or the node bin.
**Fix**: export the PATH in the launcher. Measure the PATH before believing the tool is missing.

## 14. A stale test that says the code is broken

**Presents**: `not ok - initial scheduler spawn must pass the guarded scheduler harness`.
**Cause**: the test greps for `local spawn_args=("$task_id"` and the code now says
`local spawn_args=("$lane_key" "$project" …`. The **test** was stale — the change was deliberate.
**Detect**: reproduce the failure against the **pre-change** file before touching anything. If it
fails there too, the test is the stale part.
**Fix**: repair the test's pattern, not the code.

## 15. Stopping the daemons kills the tmux server

**Presents**: after tearing both daemons down, `tmux ls` says *"no server running"* — the sessions
are gone, including any the fleet wanted to keep.
**Cause**: the tmux server dies with its last session.
**Fix**: start the daemon(s) again with `fm-afk-launch.sh start`; it reconciles a leaked terminal by
exact id and reports *"terminal close command failed, but exact absence was confirmed"*.
