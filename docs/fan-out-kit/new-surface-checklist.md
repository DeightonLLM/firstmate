# New-surface checklist — bring a host up as a lane surface

Each step closes on a **measurement**, not an opinion. If a step cannot be measured, stop there and
say so; do not proceed on a plausible reading.

## 0. Preconditions

- [ ] The host is **not** the dubz controller. Worker lanes are never spawned on the controller.
- [ ] You have **key-based** access and the account's credential store has **not** been copied from
      another host (copying a managed OAuth store between hosts revokes it).
- [ ] The provider account's quota is read with `quota-axi` **now**, and the reading is written into
      the artifact with the timestamp.

## 1. The adapter

- [ ] The worker adapter is on the **non-login shell's PATH** (`~/.local/bin`, the node bin). A
      "missing binary" reading is often just a PATH artefact — measure the PATH, not the tool.
- [ ] The adapter is launched through the fleet's own `bin/fm-spawn.sh` template, not by hand.

## 2. The route (prove by service)

- [ ] A **distinctive-token probe** returns the token verbatim:
      `codex exec --model <model> "Reply with exactly: TOKEN-1234"` → the reply must contain
      `TOKEN-1234`.
- [ ] The **canonical id** and the **CLI id** are both recorded. Some services refuse the
      provider-qualified form of their own id (measured: the codex service answers **400** for
      `openai-codex/gpt-6-luna` and serves `gpt-6-luna`). Keep the canonical id in the meta, the
      lane key and the provider attribution; reduce only the CLI argument.
- [ ] The scheduler **accepts** the harness. `bin/fm-always-four.sh`'s `scheduler_harness_guard()`
      refuses `pi` and `agy` by policy and accepts
      `claude|codex|grok|kimi|opencode|minimax-code`.

## 3. The scheduler

- [ ] Copy `launcher-template.sh`, fill in the four variables.
- [ ] The lane configuration lives in the **launcher**, in ENV. The scheduler source is unchanged.
- [ ] A **dry run** of one cycle prints the rows it would take. If every lane prints the **same**
      row, that is the duplicate-dispatch defect (traps §2) — stop and fix it before spawning.
- [ ] The lane key mints and passes `bin/fm-lane-naming-check.sh`:
      `<harness>-<model-alias>-<host>-<task>`, model alias from the naming owner's own
      `--alias-table`.

## 4. The first real lanes

- [ ] One lane spawned **by hand** end to end: brief → spawn → work → artifact → `VERDICT:` line.
- [ ] The worker is proven **working**: CPU time or thread timestamps advance. A live process with
      zero CPU is a lane stuck at a dialog (traps §1).
- [ ] The artifact is written to an **absolute path outside the worktree**, so a worktree reclaim
      cannot destroy it.

## 5. The half (if the surface runs more than one)

- [ ] The second half has its **own** `FM_DATA_OVERRIDE` and `FM_STATE_OVERRIDE` and its **own**
      queue file. Shared roots mean shared lane ids, shared briefs and shared in-flight sets.
- [ ] Each half's account ceiling is set to its **own account**, not the host's total.
- [ ] Any guard that refuses the second half's route (for example a "free route only" rule) is
      bypassed **only** for that half, with the bypass exported in its launcher and the reason
      written in the artifact. A bypass that is not scoped is a hidden policy change.

## 6. The daemon

- [ ] Started with `bin/fm-afk-launch.sh start` — tracked, non-visible terminal. Never `nohup`,
      `&`, `disown`.
- [ ] Its **environment** is read from `/proc/<pid>/environ`, not from the script defaults:
      `fm-always-four.sh status` over a plain ssh shows the defaults, not what is running.

## 7. Close the loop

- [ ] The lane is registered in `ops/lane-ledger.tsv` (state, owner, opened, updated, expiry,
      next, artifact, branch) and on `ops/LANE-CLAIMS.md` (exactly seven cells, lane id backticked,
      expiry `-` for DONE).
- [ ] `bash ops/bin/fm-todo-sync.sh` reports **CLEAR**.
- [ ] `docs/fan-out-kit/verify-fleet.sh` prints the census, and the census is what the board says.
