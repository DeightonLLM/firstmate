# Report — land the Brandon-compute (HETZ) corrections on the Controller side

- Lane key: `mcode-m3.1f-controller-hetzcorrections`
- Kind: ship (shared tracked material)
- Host: controller
- Branch: `lane/mcode-m3.1f-controller-hetzcorrections-1792615027`
- Date: 2026-10-21
- Source of truth for every corrected artefact: `origin/main` @ `71e8d91`

The peer report named in the brief
(`BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-21-hetz-to-controller-three-lanes-landed-with-four-deviations-20261021.md`)
is **not present in this worktree** — `BRANDON-COMPUTE-COMMS/from-brandon-compute/` holds no file
matching `*three-lanes*` or `*four-deviations*`. Every correction below was therefore ported from
`git show origin/main:<path>`, which the brief names as the source of truth, and every correction was
independently re-verified against this host's live behaviour before it was landed.

---

## What changed

### 1. `.agents/skills/harness-adapters/SKILL.md` — the minimax-code adapter's two wrong rows

Two rows in the `## minimax-code` table were factually wrong on this host. Both now carry the
corrected text verbatim, and both match `origin/main` byte-for-byte. Nothing else in the file was
touched — this side's section is richer than the forge's, and the port kept every other row.

#### 1a. The `Busy state` row — root cause of backlog row `m3.1f-firstmate-herdrbusyblind`

Old (wrong) row claimed the mcode pane "reports its own agent state to herdr, so `herdr pane list`
is the authoritative liveness read", and that `agent_status: unknown` means the status path is broken.

New row states that the self-report path only works where the session's mcode data dir can load the
local `mcode-herdr-agent` package; a per-task data dir carrying a **symlinked** `plugins` root cannot,
because the mcode CLI refuses a symlinked plugin root with `PLUGIN_ROOT_SYMLINK`; such a pane reports
`agent_status: unknown` **even while it is working**; `unknown` therefore means the self-report path is
unavailable for that pane, NEVER that the lane is idle; and the authoritative liveness read for a
spawned lane is the pane's own process state.

Evidence measured on this host:

- `bin/fm-spawn.sh:1691` symlinks every entry of the base mcode data dir into the per-task mcode dir
  (only `config.yaml` and `v2` are excluded). Live proof — every spawned lane's `plugins` root is a
  symlink:

  ```
  /tmp/fm-mcode-m3.1f-controller-hetzcorrections/mcode/plugins -> /root/.minimax/plugins
  /tmp/fm-mcode-m3.1f-controller-reclaim-disk/mcode/plugins      -> /root/.minimax/plugins
  /tmp/fm-mcode-m3.1f-controller-watchsupervise/mcode/plugins    -> /root/.minimax/plugins
  /tmp/fm-residual-queue-20261020/mcode/plugins                  -> /root/.minimax/plugins
  ```

- `herdr pane list` on this host: **all four panes report `agent_status: "unknown"`**, and three of
  them are titled `Working | ...`. So "unknown while working" is the observed state here, and the old
  row's reading was not merely imprecise — it pointed supervision at the wrong signal.

- The code path that carries it: `bin/fm-backend.sh:791` → `fm_backend_herdr_busy_state`
  (`bin/backends/herdr.sh:2908`) → `fm_backend_herdr_agent_status_raw` → `herdr agent get` →
  `.result.agent.agent_status` → `fm_backend_herdr_classify_agent_status`, which yields `unknown` for
  anything outside `working|blocked|idle|done`.

- `bin/fm-watch.sh:227 window_is_busy` only reports busy when the verdict is `busy`. `unknown` is not
  busy, so a live lane can never be proven working and is surfaced as stale. That is exactly backlog
  row `m3.1f-firstmate-herdrbusyblind` (confirmed present at `data/backlog.md:29`).

**The backend was NOT fixed here** — the brief assigns that to a separate lane and a separate
decision. This lane corrected the truth and recorded the root cause.

#### 1b. The `Headless` row — a false "FORBIDDEN"

Old (wrong) row claimed "there is no `mcode exec` path for a crewmate". That is false: the binary has
a headless path, and it is capped at one hour (3600000 ms), so a run that reaches the cap is killed
mid-flight and any long task must preserve its raw data as it is produced. A crewmate lane is still
spawned visibly through `bin/fm-spawn.sh`; the headless path is for a bounded measurement run, not a
supervised lane.

Evidence on this host (`/root/.minimax-code/bin/mcode`, version `0.6.12`):

```
$ mcode exec --help
Usage: mcode exec [options] [command] [prompt]

Run one prompt without starting the TUI
...
  --timeout <duration>                Run timeout, for example 30s or 2m
```

The headless path exists. Stating plainly, because a false "FORBIDDEN" is what cost HETZ a
measurement lane: **the old row was wrong, and the corrected row is now on this side.**

### 2. `bin/fm-todo-prefix-check.sh` — restored the `--alias-table` mode

This side's lane-key rewrite dropped a read-only mode the shared repo carries. Ported:

- the `--alias-table` case block, and
- the `--alias-table` entry in the usage line.

The alias **table itself was not changed**: `_MODEL_ALIAS_TABLE` has no delta between the two sides
(identical at line 97 of both), so the port is the mode only. After the change
`git diff origin/main -- bin/fm-todo-prefix-check.sh` is empty — the script is byte-identical to the
forge.

Live output:

```
$ bash bin/fm-todo-prefix-check.sh --alias-table
m3.1f	minimax/MiniMax-M3.1-Flash
m3.1	minimax/MiniMax-M3.1
luna6	openai-codex/gpt-6-luna
glm5.3f	zai/glm-5.3-flash
gem38f	agy/gemini-3.8-flash-medium
pi	minimax/MiniMax-M3.1-Flash
m2.7h	minimax/MiniMax-M2.7-highspeed
m2.7	minimax/MiniMax-M2.7
exit=0
```

The retired M3.1 Flash Preview identifier appears nowhere in that output (checked mechanically; see
"How it was verified").

### 3. `tests/fm-todo-prefix-check.test.sh` — the colocated proof, and the registry case

- Ported `test_alias_table_binds_live_catalog_identifiers` and registered it in the case list. On the
  shared repo the test file merged cleanly and kept HETZ's copy while the implementation lost the
  mode, so the proof was orphaned from the thing it proves. On this side both the mode and the proof
  are now present.
- Ported the registry case's SKIP-when-absent behaviour (item 4 below).

This file deliberately keeps two of this side's pre-existing adaptations that are unrelated to this
lane and are not regressions: `test_legacy_model_surface_row_rejected` uses `[m2.7h @ brandon]` and
`test_self_check_all_models_aliased_passes` uses `minimax/MiniMax-M3.1-Flash` in its dispatch fixture.

### 4. `tests/fm-lane-naming-check.test.sh` — the registry case

`test_live_registry_validates` now SKIPs where the tracked registry is absent and still FAILS where a
registry is present and invalid. After the change this file is byte-identical to `origin/main`
(`git diff origin/main -- tests/fm-lane-naming-check.test.sh` is empty).

### 5. `tests/fm-lock-reclaim-disk.test.sh` — portable fixture

The fixture hard-required `/root`, so as an ordinary user the suite died before its first assertion
and reported every shape as touched — a false total, not a failure. Ported the forge's `work_base`
approach: compute the root filesystem's device, then pick the first **writable** directory on that
filesystem (`/root`, `/var/tmp`, `/tmp`, `$HOME`, `$ROOT`), keeping the root behaviour where it is
available so the `df` reading still sees the bytes the test creates.

**Collateral fix (in scope, same file, pre-existing):** the file was missing the repo's own
`# shellcheck disable=SC2329` directive for indirectly-invoked functions, so the canonical per-file
lint failed on `cleanup()` — a finding that was already present at `HEAD` (line 39 before this
lane's change, line 57 after) and that also exists in the forge's copy. Added the directive using the
same wording and placement as its two sibling suites
(`tests/fm-todo-prefix-check.test.sh`, `tests/fm-lane-naming-check.test.sh`). The file's canonical lint
is now clean.

---

## How it was verified

### Per-file lint (the whole-repo `bin/fm-lint.sh` was NOT run, per the brief)

```
$ bash bin/fm-lint.sh bin/fm-todo-prefix-check.sh \
    tests/fm-todo-prefix-check.test.sh \
    tests/fm-lane-naming-check.test.sh \
    tests/fm-lock-reclaim-disk.test.sh
fm-lint.sh: ShellCheck 0.11.0 (pinned 0.11.0)
lint exit=0
```

Before the collateral fix the same command reported one pre-existing finding and exited 1:

```
In tests/fm-lock-reclaim-disk.test.sh line 57:
cleanup() {
^-- SC2329 (info): This function is never invoked. ...
lint exit=1
```

Confirmed pre-existing, not introduced here: linting the `HEAD` version of that file reproduces the
identical diagnostic at its line 39.

### Suites — final run

```
$ bash tests/fm-todo-prefix-check.test.sh
# SUMMARY: total 27, passed 27, failed 0
# RESULT: PASSED
exit=0

$ bash tests/fm-lane-naming-check.test.sh
# fm-lane-naming-check.test.sh: all assertions passed
exit=0          (45 "ok - " assertions, 0 "not ok - ")

$ bash tests/fm-lane-naming-spawn-integrity.test.sh
# fm-lane-naming-spawn-integrity.test.sh: all assertions passed
exit=0          (8 "ok - " assertions, 0 "not ok - ")
```

The spawn-integrity suite is included because it is a third consumer of the alias table's owning
script (`grep -rl "fm-todo-prefix-check\|fm-lane-naming-check" tests/` returns it); it was already
green and is still green.

The new alias-table case ran and passed inside the todo-prefix suite:

```
# CASE: test_alias_table_binds_live_catalog_identifiers
PASS: test_alias_table_binds_live_catalog_identifiers
```

The registry case ran and passed on this side, where the registry IS tracked:

```
# CASE: test_live_registry_validates_with_zero_errors
PASS: test_live_registry_validates_with_zero_errors
```

### Lock-reclaim suite — the real count

```
$ bash tests/fm-lock-reclaim-disk.test.sh
...
== summary ==
PASS 33  FAIL 0
exit=0
```

**The count is 33 PASS / 0 FAIL, unchanged from this side's pre-change baseline (also 33/0).** It
differs from HETZ's 30 PASS / 0 FAIL on their host, and the reason is host-dependent conditional
assertions, not the fixture change:

- The suite has 30 `ok` call sites. The executed count moves with (a) the `keep` loop, which runs 6
  times from one call site (+5), and (b) mutually exclusive or conditional blocks.
- The `OLD_REF` block (3 assertions: "the previous reclaimer had no lock handling at all", "the
  previous reclaimer LEFT THE DEAD LOCK OWNER DIR BEHIND even with --apply", "the previous
  reclaimer's report never mentioned the lock owner dir") runs only when a pre-tier-1b reclaimer is
  found within the last 20 commits of git history. It **ran here** — the search resolved
  `HEAD~1~1~1~1~1~1~1` to `13aca99d`. A clone whose history does not reach that far skips all three,
  which is exactly a 3-assertion drop from 33 to 30.
- The "GENUINELY recycled kernel pid" assertion is conditional on being able to simulate a pid
  recycle; it did **not** fire on this host.

The fixture change itself altered nothing: baseline 33 PASS / 0 FAIL → after the change 33 PASS /
0 FAIL.

### Criterion 4 proven in both directions (registry absent → SKIP, registry present and invalid → FAIL)

Proven in a throwaway sandbox under `/tmp` (a copy of `bin/`, `tests/lib.sh` and the two suites, with
an empty `data/`), so the live repo was never mutated. The sandbox was removed afterwards.

Registry ABSENT (the shared repo's shape):

```
--- fm-todo-prefix-check: suite exit=0
  skip: no tracked registry at /tmp/regtest/data/async-lanes.tsv in this clone
# SUMMARY: total 27, passed 27, failed 0
# RESULT: PASSED
--- fm-lane-naming-check: suite exit=0
  skip: no tracked registry at /tmp/regtest/data/async-lanes.tsv in this clone
# fm-lane-naming-check.test.sh: all assertions passed
```

Registry PRESENT and INVALID (`run_id` is not a UUID):

```
--- fm-todo-prefix-check: suite exit=1  (expect NON-ZERO)
  no skip line (correct: it ran)
FAIL: test_live_registry_validates_with_zero_errors
# SUMMARY: total 27, passed 26, failed 1
# RESULT: FAILED

--- fm-lane-naming-check: suite exit=1  (expect NON-ZERO)
  no skip line (correct: it ran)
not ok - the tracked registry must validate, got exit 1:  /tmp/regtest/data/async-lanes.tsv: line 2: run_id is not a valid UUID: not-a-uuid
```

### Retired identifier absent from the alias-table output

```
$ out=$(bash bin/fm-todo-prefix-check.sh --alias-table)
$ case "$out" in *'MiniMax-M3.1-Flash-Preview'*) echo "PRESENT (BAD)";; *) echo "absent (good)";; esac
absent (good)
```

### Ported deltas are exactly the deltas

```
$ git diff origin/main -- bin/fm-todo-prefix-check.sh
(empty)
$ git diff origin/main -- tests/fm-lane-naming-check.test.sh
(empty)
$ git diff origin/main -- tests/fm-lock-reclaim-disk.test.sh
(only the added SC2329 directive block)
```

The complete remaining delta on the lock-reclaim suite is the collateral lint fix, nothing else:

```
$ git diff origin/main -- tests/fm-lock-reclaim-disk.test.sh
@@ -20,6 +20,12 @@
 # pid that is REALLY alive, so the naive test really would have kept it.
 #
 # Usage: tests/fm-lock-reclaim-disk.test.sh
+#
+# The cleanup function below is invoked by the EXIT trap, and every case
+# helper is invoked indirectly by the case list, which shellcheck cannot
+# resolve. The repo's own convention for indirectly invoked functions is the
+# SC2329 directive (tests/fm-pending-reply.test.sh).
+# shellcheck disable=SC2329
 set -u
```

`tests/fm-todo-prefix-check.test.sh` also keeps a non-empty delta against the forge: this side's two
pre-existing adaptations named in section 3 above, which this lane did not touch.

Both corrected skill rows were compared line-for-line against the forge and matched exactly; the
count of stale rows is zero:

```
MATCH: ^| Busy state | PARTIAL
MATCH: ^| Headless | The binary DOES
$ grep -c "FORBIDDEN for real task work\|CREDITS a real semantic source" .agents/skills/harness-adapters/SKILL.md
0
```

---

## What remains open

1. **The herdr busy-detection gap itself is NOT fixed here, by design.** The root cause is now
   recorded in the skill file and in this report: `bin/fm-spawn.sh` symlinks `plugins` into the
   per-task mcode data dir, the mcode CLI refuses a symlinked plugin root
   (`PLUGIN_ROOT_SYMLINK: Plugin root must be a physical directory`), so the `mcode-herdr-agent`
   package never loads in a spawned lane and the pane reports `agent_status: unknown` even while
   working. Consequently `fm_backend_busy_state herdr <pane>` returns `unknown` for every spawned
   pane on this host, `bin/fm-watch.sh`'s `window_is_busy` can never prove a spawned lane is working,
   and every live lane is surfaced as stale — backlog row `m3.1f-firstmate-herdrbusyblind`
   (`data/backlog.md:29`). Fixing it is a separate lane and a separate decision (the options are a
   physical plugin root per lane, a non-symlinked `plugins` materialisation, or a different liveness
   read), and was explicitly out of scope here.

2. **The brief's inline alias-table block disagrees with the forge on two rows.** The brief lists
   `m2.7h -> minimax/MiniMax-M3.2.7-highspeed` and `m2.7 -> minimax/MiniMax-M3.2.7`; the forge's
   merged file — the source of truth the brief designates — produces `minimax/MiniMax-M2.7-highspeed`
   and `minimax/MiniMax-M2.7`. The alias table has **no delta** between the two sides (identical
   `_MODEL_ALIAS_TABLE` at line 97 of both), and the forge's own colocated test asserts only that
   `m3.1f` and `pi` name the live id and that the retired M3.1 Flash Preview id is absent — it makes
   no assertion about the two retired rows. Retargeting `m2.7h`/`m2.7` at the M3.2.7 ids would also
   break the script's own `derive_alias` rule (which derives `minimax/MiniMax-M2.7-highspeed` ->
   `m2.7h`) and would orphan a `m3.2.7h` alias in `--self-check`. I therefore ported the forge's
   behaviour unchanged and am flagging the discrepancy rather than silently resolving it either way.
   If the retired aliases are meant to point at the live M3.2.7 models, that is a separate
   alias-table change with its own test, not a mode restoration.

3. **The peer report was not readable in this worktree** (see the top of this report). The
   corrections were ported from `origin/main` and re-verified against this host's live behaviour, but
   HETZ's original measurements were not re-read here.

4. **`mcode exec`'s one-hour cap was taken from the corrected row, not measured here.** The headless
   path's existence was verified directly (`mcode exec --help`); the 3600000 ms cap was not
   reproduced on this host, so that specific number rests on the peer's report.

5. **The whole-repo `bin/fm-lint.sh` was not run** (the brief forbids it on this 4-core host). Lint
   was run per file over the four touched shell files and is clean. The 476-file canonical set was
   not exercised as a whole, so lint findings in files this lane did not touch remain unmeasured
   here.

6. **The `mcode-herdr-agent` package was not located on this host's interactive home.** It was found
   under worktree `extensions/` directories, not under the base mcode data dir's `plugins/` root
   (which on this host contains only a self-referential `plugins -> /root/.minimax/plugins`
   symlink). The exact plugin-root resolution that the mcode CLI performs was therefore not traced
   end to end here; the symlink fact, the `PLUGIN_ROOT_SYMLINK` refusal, and the resulting `unknown`
   agent status are all independently confirmed, but the final link in that chain rests on the peer
   report.

---

VERDICT: PASS
