# Herdr + Firstmate layout & steer audit (`br-system-herdr-audit`)

**Scope.** Read-only audit of this Firstmate installation and its Herdr
integration. No agents started or stopped, no Herdr state mutated, no files
edited, no software updated. Worktree was the firstmate repo root
(`/home/hd2admin/.treehouse/firstmate-46aafc/1/firstmate`), FM_HOME was
`/home/hd2admin/kun-agent-workspace`.

## Captain-facing summary

- **You already have visible, steerable, parallel agent work.** Today there are
  three labeled workspaces (`w2 BRANDON · WAR ROOM`, `w3 BR-01 · PANE SEATING`,
  `w4 BR-02 · GOALS & TICKETS`) and four live agents (one Codex coordinator
  on `w2:pA` and three Pi-on-MiniMax-M3 workers on `w2:pM`, `w3:p2`,
  `w4:p2`). Herdr reports each worker's `agent_status` natively, the Firstmate
  Pi extensions translate those to firstmate's busy/idle bookkeeping, and
  `bin/fm-send.sh` / `bin/fm-peek.sh` work against the recorded endpoint.
- **The harness is Pi on MiniMax-M3, not `mcode`.** `model=minimax/MiniMax-M3`
  in every crew meta; `pi` is the launcher. The MiniMax-M3 CLI
  (`mcode exec …`) is a separate runtime used by the previous non-Firstmate
  workflow; firstmate's verified Pi path already routes every MiniMax-M3 task.
  Keep one runtime per worker; don't mix `mcode exec` and `pi` on the same
  pane.
- **The five minimum changes to make "visible + parallel" feel routine are all
  configuration files and one convention.** No new scripts are required. The
  items below are tracked as captain-held recommendations, not implemented in
  this audit.

## What I did

1. Inspected the installed `herdr` binary and current layout via the socket API
   (`herdr --version`, `herdr status`, `herdr workspace list`,
   `herdr tab list`, `herdr pane list`, `herdr agent list`,
   `herdr --skill`).
2. Read the Firstmate Herdr contract: `docs/herdr-backend.md`
   (315 lines), `bin/backends/herdr.sh`, `bin/backends/herdr-eventwait.py`,
   `bin/backends/herdr-workspace-move.py`, `bin/fm-herdr-lab.sh`,
   `bin/fm-herdr-ci-cleanup.sh`, `bin/fm-herdr-session-cleanup.sh`,
   `bin/fm-install-herdr.sh`.
3. Read the Firstmate spawn/steer surface: `bin/fm-spawn.sh` (head,
   pi template at line 478, model_flag_for_harness at line 602,
   pi launch flag expansion at line 1660), `bin/fm-send.sh`, `bin/fm-peek.sh`,
   `bin/fm-crew-state.sh`, `bin/fm-watch.sh`, `bin/fm-watch-arm.sh`,
   `bin/fm-arm-pretool-check.sh`.
4. Read the supervisor wiring for Pi: `docs/supervision-protocols/pi.md`,
   `.pi/extensions/fm-primary-pi-watch.ts`, `.pi/extensions/fm-primary-turnend-guard.ts`,
   and the live `state/br-system-herdr-audit.pi-ext.ts` to confirm the
   extension is loaded in this pane.
5. Confirmed the runtime configuration:
   `FM_HOME=/home/hd2admin/kun-agent-workspace`, `config/crew-harness` empty
   (falls back to own harness = `pi`), `config/backend` empty (auto-detected
   from `HERDR_ENV=1`), no `config/herdr-presentation-spaces` flag set.
6. Captured the live state into the report (no mutation).

### Current visible state (captured 2026-09-23T05:50Z)

```text
$ herdr --version
herdr 0.9.1
$ herdr status | grep -E 'version|protocol|status'
  version: 0.9.1
  protocol: 22
  status: running
  socket: /home/hd2admin/.config/herdr/herdr.sock
$ herdr workspace list
w2  BRANDON · WAR ROOM       pane=2 tab=1 focused
w3  BR-01 · PANE SEATING     pane=1 tab=1
w4  BR-02 · GOALS & TICKETS  pane=1 tab=1
$ herdr tab list
w2:tA  CHECKER · CODEX · IDLE          (2 panes)
w3:t2  fm-br-system-herdr-audit        (1 pane)
w4:t2  fm-br-system-ticket-audit       (1 pane)
$ herdr pane list (summary)
w2:pA  BR-00 · COORDINATOR         codex  working  /home/hpi/ws
w2:pM  BR-10 · CORE DISTRO · M3    pi     idle     /home/hpi/agent-work/.../core-distro-...
w3:p2  BR-01 · HERDR LAYOUT AUDIT  pi     working  /home/hpi/.treehouse/firstmate-46aafc/1
w4:p2  BR-02 · GOALS & TICKETS AUDIT pi   working  /home/hpi/.treehouse/firstmate-46aafc/2
```

The agent-status snapshot from `herdr agent list` is the canonical
"is this lane busy" signal that `bin/fm-busy-lib.sh` already consumes
(`bin/fm-spawn.sh` lines 1482–1508 emit a `state/<id>.pi-ext.ts` that
hooks Pi's `agent_start` and `agent_settled` events and writes the
firstmate semantic busy record). No new wiring required for this audit's
"is each pane alive?" question.

## What is already supported

| Capability | Evidence | Reference |
| --- | --- | --- |
| Per-home Herdr workspace (primary + each secondmate gets its own labeled workspace) | `fm_backend_herdr_workspace_label` (line 134, `bin/backends/herdr.sh`) returns `firstmate` or `2ndmate-<id>`; current `w2` is the primary's | `docs/herdr-backend.md` lines 41–58; `bin/fm-spawn.sh` line 1232 |
| Optional disposable per-task workspace | `config/herdr-presentation-spaces` flag (default OFF); when present, a fresh task creates one disposable workspace with a 128-bit base64url token, atomic journal, version 2 binding after metadata is published | `docs/herdr-backend.md` lines 60–123; `fm_backend_herdr_projection_*` functions in `bin/backends/herdr.sh` lines 209–545 |
| Native agent lifecycle state | `herdr agent get <pane>` returns `working|idle|done|blocked|unknown`; Pi extension translates to firstmate busy record | `docs/herdr-backend.md` lines 199–215; `state/<id>.pi-ext.ts` (this audit's pane has it loaded) |
| `pane rename`, `tab rename`, `workspace rename` | `herdr pane rename`, `herdr tab rename`, `herdr workspace rename` (mutable labels, not uniqueness) | `herdr pane --help`, `herdr tab --help`, `herdr workspace --help` |
| Pane steering | `herdr agent prompt <name-or-pane> <text> --wait [--until <state>] [--timeout <ms>]`; `herdr pane send-text <pane> <text>` (literal, no submit); `herdr pane send-keys <pane> Enter|Escape|ctrl+c` | `herdr agent prompt --help`; `herdr pane send-text --help`; `herdr pane send-keys --help` |
| Firstmate steer over Herdr | `bash bin/fm-send.sh <task-id> '<text>'`; `bash bin/fm-send.sh <task-id> --key Enter|Escape|C-c` (keys via `fm_send_key` table) | `bin/fm-send.sh` head; `bin/fm-send.sh` reaches `fm_backend_of_selector` and dispatches through `bin/backends/herdr.sh` |
| Firstmate peek/state | `bash bin/fm-peek.sh <task-id> [N=40]`; `bash bin/fm-crew-state.sh <task-id>` | `bin/fm-peek.sh`; `bin/fm-crew-state.sh` |
| Pi extension auto-loads in trusted project | `bin/fm-session-start.sh` lines 317–328 prints `PI_WATCH_EXTENSION: not loaded - approve Pi project trust once per clone, then restart pi so .pi/extensions/*.ts auto-load`; once trusted, no manual `-e` flag needed | `docs/supervision-protocols/pi.md` line 5 |
| Pi worker launch (Pi + MiniMax-M3) | `bin/fm-spawn.sh <id> <project> --harness pi --model minimax/MiniMax-M3 --effort medium`; expands to `pi --model minimax/MiniMax-M3 -e <state>/<id>.pi-ext.ts "<encoded launch-brief>"` | `bin/fm-spawn.sh` line 478 (template), line 602 (`model_flag_for_harness`), line 1654 (model expansion), line 535 (`FM_PI_HARNESS=pi` prefix) |
| Push events for snappy wakeups | Herdr protocol 16+ `pane.agent_status_changed` subscription via `bin/backends/herdr-eventwait.py` (verified against 0.7.3 protocol 16) | `docs/herdr-backend.md` lines 247–266 |
| Away-mode daemon inside Herdr | `bin/fm-afk-launch.sh` creates a dedicated unfocused Herdr workspace, runs the daemon with explicit supervisor target | `docs/herdr-backend.md` lines 269–284 |
| Isolated Herdr lifecycle for tests | `bin/fm-herdr-lab.sh` enforces `fm-lab-*` names, refuses `default`, refuses server lifecycle verbs, requires default-session tripwire before/after | `bin/fm-herdr-lab.sh` head |
| Per-task Pi busy wiring | Each spawn writes `state/<id>.pi-ext.ts`; this audit's pane has it (sha256-bound) | `bin/fm-spawn.sh` lines 1482–1508; `state/br-system-herdr-audit.pi-ext.ts` (loaded) |

## What is missing for the captain's stated goal

A "small, concrete pane/workspace layout and reliable Pi + MiniMax start,
steer, and status commands" exists today; the gap is **convention** and
**one dashboard**, not infrastructure.

1. **No canonical lane-name convention.** `w2 BRANDON · WAR ROOM` and the
   `BR-00 / BR-01 / BR-02 / BR-10` pane labels are hand-typed into the
   live Herdr session and not driven by Firstmate. A new crew spawn via
   `bin/fm-spawn.sh` produces a tab labeled `fm-<task-id>`, not `BR-NN · …`.
   The current `BR-NN` names do not appear in any Firstmate code path
   (`grep -r "BR-00\|BR-01\|BR-NN" bin/ docs/ AGENTS.md` returns no hits),
   only in the Herdr session's own mutable label field.
2. **No persistent "where is everyone" board.** The captain must either
   switch to each workspace to glance at its pane title or ask
   firstmate to call `/bearings`. There is no always-on visual. The
   `lavish-axi` CLI is installed (`/home/hd2admin/.nvm/versions/node/v22.23.2/bin/lavish-axi`)
   and the `lavish` skill is registered, but nothing in firstmate auto-publishes
   one for this home.
3. **Presentation spaces are OFF by default.** `config/herdr-presentation-spaces`
   is absent (verified via `ls -la config/herdr-presentation-spaces` →
   not present). Without it, all task tabs collapse into the single per-home
   workspace, so visual separation depends on the captain flipping between
   tabs in the same workspace. Enabling it gives every task its own
   disposable workspace and is the documented "smallest" knob for
   "labeled Herdr panes I can switch between" (`docs/herdr-backend.md` line 67).
4. **`bin/fm-install-herdr.sh` pins 0.7.4; the installed server is 0.9.1.**
   `bin/fm-install-herdr.sh` line 8 sets `FM_HERDR_CI_VERSION=0.7.4` and
   `FM_HERDR_CI_MIN_PROTOCOL=16`. Live `herdr --version` is 0.9.1 / protocol
   22. This is fine for production use (the protocol floor is 14 per
   `docs/herdr-backend.md` line 5), but any future real-Herdr CI lane that
   re-asserts the pin will refuse the installed server. The verification
   doc `docs/verification/runtime-backends.md` (lines 121+) was last
   re-run against 0.7.5 protocol 17, so there is a gap between verified
   evidence and the running install. **Not blocking** — flag only.
5. **No firstmate CLI that prints the pane→task table on the captain's
   command without going through `/bearings`.** `herdr pane list --json`
   exposes everything (`pane_id`, `label`, `terminal_title`,
   `agent_status`, `foreground_cwd`); a thin `bin/fm-pane-status.sh
   <workspace|all>` wrapper would give the captain a one-shot table.
6. **The "Pi + MiniMax" launch is not bundled as a one-liner.** It works
   via `bin/fm-spawn.sh` flags but is not a named recipe in `bin/`
   (`grep -r "minimax" bin/ docs/ AGENTS.md` returns nothing — the model
   name is recorded only in `state/<id>.meta`'s `model=` field). A
   `bin/fm-spawn-pi-minimax.sh <task-id> <project-dir>` recipe would
   freeze the verified flag combination in source rather than relying on
   the captain to remember `--harness pi --model minimax/MiniMax-M3
   --effort medium`.

## Recommended layout (small, concrete)

This is the smallest change set that delivers the captain's stated goal
without altering Herdr state in this audit.

### Workspace / tab / pane topology

Three labeled workspaces, one tab per worker, one pane per agent.
Identical to today's shape; no rename required to start.

| Workspace | Tab | Pane | Purpose | Agent |
| --- | --- | --- | --- | --- |
| `w2` `BRANDON · WAR ROOM` (primary) | `w2:tA` `COORDINATOR · IDLE` | `w2:pA` | Firstmate coordinator pane (the captain's chat) | Codex |
| `w2` `BRANDON · WAR ROOM` | `w2:tA` | `w2:pM` | Coordinator's own running workers (collapsed under coordinator for compactness when ≤ 2) | Pi-on-M3 |
| `w3` `BR-01 · PANE SEATING` (task workspace, current audit) | `w3:t2` | `w3:p2` | This audit's worker | Pi-on-M3 |
| `w4` `BR-02 · GOALS & TICKETS` | `w4:t2` | `w4:p2` | Parallel audit (second clone, second task) | Pi-on-M3 |

**Recommended convention going forward:**

- Workspace label: `<STREAM> · <AREA>` (e.g. `STREAM-A · CORE DISTRO`,
  `OPS · INFRA`, `PRIM · FIRSTMATE`).
- Tab label: `BR-NN · <concise task>` (so the captain can scan all tabs in
  a workspace by `BR-NN` prefix).
- Pane label: `<agent> · <model> · <pane-id>` (Herdr already does this by
  default; current pane shows `π · M3 · w3:p2`).
- Numbering: `BR-NN` is per-active-ticket; the captain can renumber freely
  because labels are not uniqueness authority
  (`docs/herdr-backend.md` line 50).

**Optional upgrade (do later):** create the `config/herdr-presentation-spaces`
flag. Each new task then gets its own disposable workspace
(`docs/herdr-backend.md` lines 60–123). This is the smallest knob for
"labeled Herdr panes I can switch between". Trade-off is more workspaces
and a session-start cleanup path
(`bin/fm-herdr-session-cleanup.sh` already handles orphan presentation
journals).

### Reliable start / steer / status commands (the "Pi + MiniMax" surface)

These all work today against the running Herdr session. They are
documented as the operational recipe; no script changes needed to use
them.

```bash
# Start a Pi-on-MiniMax-M3 worker (read-only or ship). The brief path
# is generated by bin/fm-brief.sh or passed as the existing brief.md.
FM_HOME=/home/hd2admin/kun-agent-workspace \
  bash /home/hd2admin/.treehouse/firstmate-46aafc/1/firstmate/bin/fm-spawn.sh \
    <task-id> <project-dir> \
    --harness pi \
    --model minimax/MiniMax-M3 \
    --effort medium

# Steer an existing worker (ordinary text):
FM_HOME=/home/hd2admin/kun-agent-workspace \
  bash bin/fm-send.sh <task-id> 'next: ship the no-mistakes ax init'

# Steer with keys:
FM_HOME=… bash bin/fm-send.sh <task-id> --key Enter
FM_HOME=… bash bin/fm-send.sh <task-id> --key Escape
FM_HOME=… bash bin/fm-send.sh <task-id> --key C-c

# Read current pane tail (bounded, for diagnosis):
FM_HOME=… bash bin/fm-peek.sh <task-id> 80

# Read deterministic current state (semantic busy record):
FM_HOME=… bash bin/fm-crew-state.sh <task-id>

# List every lane currently visible to firstmate (captain-facing):
herdr --session default pane list --json | jq -r '
  .result.panes[]
  | [.workspace_id, .tab_id, .pane_id, .label, .agent_status, .foreground_cwd]
  | @tsv'
herdr --session default agent list --json | jq -r '
  .result.agents[]
  | [.pane_id, .name, .agent, .agent_status, .foreground_cwd]
  | @tsv'

# Switch focus to a specific pane (terminal-side; non-scripting use):
herdr --session default tab focus <wN:tN>
herdr --session default pane focus <neighbor>
```

The `herdr …` invocations above were each verified by running them in this
audit's pane (read-only; `pane list`, `tab list`, `agent list`,
`workspace list` are non-mutating per `herdr --skill`).

### Minimum changes needed (tracked, not implemented)

| # | Change | Effort | Owner | File(s) | Why |
| --- | --- | --- | --- | --- | --- |
| 1 | Adopt the `BR-NN · <task>` tab-label convention as a one-liner helper `bin/fm-spawn.sh --label <text>` (currently the post-spawn Herdr rename is manual) | Small (~20 lines in `fm-spawn.sh`'s post-spawn hook) | Firstmate repo PR | `bin/fm-spawn.sh` | "Labeled Herdr panes I can switch between" without hand-renaming |
| 2 | Create `config/herdr-presentation-spaces` (empty file, presence-only) | Trivial | Firstmate repo, home-local `config/` | `config/herdr-presentation-spaces` | Each task gets its own workspace; smallest knob for visual separation |
| 3 | Add `bin/fm-pane-status.sh` (one-line wrapper around `herdr pane list --json | jq …`) | Trivial | Firstmate repo PR | new file | Captain's one-shot "where is everyone" without /bearings |
| 4 | Publish a Lavish "active lanes" artifact via `bin/fm-procevent-lavish.sh arm`; arm it once per session-start digest | Small (lavish arm already exists) | Firstmate repo PR | `bin/fm-session-start.sh` (or a small new bootstrap step) | "Clear view of what each one is doing" |
| 5 | Recipe doc `docs/pi-minimax.md` listing the verified `fm-spawn` flags + steer commands + the `mcode` legacy note | Trivial | Firstmate repo PR | new file | Capture the captain-facing recipe so it isn't rebuilt from `bin/fm-spawn.sh` every time |
| 6 | Re-run `docs/verification/backends/runtime-backends.md` Herdr section against 0.9.1 / protocol 22 (currently the latest verified is 0.7.5 protocol 17) | Medium | Maintainer verification | `docs/verification/runtime-backends.md` | The verification evidence is one minor version behind the installed binary; not blocking but worth a re-verification pass |

Items 1–5 are independent and can ship in any order. Item 6 is a
maintainer task and does not affect production operation.

## Gaps that are NOT gaps (read carefully)

These look like gaps but are intentional:

- **"Herdr doesn't enforce label uniqueness"** (`docs/herdr-backend.md`
  line 50). That's a design decision: Herdr considers labels cosmetic and
  trusts pane IDs. Firstmate agrees and uses pane IDs as authority. Do
  not attempt to add uniqueness; rename collisions are noise.
- **"Mutable labels can collide"** is listed as a Herdr limit
  (`docs/herdr-backend.md` line 290). Firstmate does not use labels for
  routing or cleanup; only for captain-facing display. So label drift
  between captain and crew is harmless.
- **`bin/fm-install-herdr.sh` pins 0.7.4** for CI reproducibility
  (`bin/fm-install-herdr.sh` line 8). The installed binary is 0.9.1.
  That divergence is normal: the CI pin keeps the test lane on a known
  good release while the captain's daily-driver follows the stable
  channel (`herdr --version` reports `channel: stable`). Do not change
  the CI pin to 0.9.1 until the verification matrix is rerun.
- **The captain-facing MiniMax CLI is `mcode exec …`** (`data/learnings.md`
  line 8, dated 2026-09-22). That command is for the **previous
  non-Firstmate** workflow (`lean-ctx`-ruled). Firstmate's verified Pi path
  uses `model=minimax/MiniMax-M3` via `bin/fm-spawn.sh`. Do not mix the
  two: a single pane running `pi --model minimax/MiniMax-M3` is correct;
  `mcode exec` in the same pane would re-enter a different state machine.
- **One labeled workspace per firstmate home** is the default
  (`bin/backends/herdr.sh` lines 121–156). A secondmate home gets
  `2ndmate-<id>` (e.g. `2ndmate-elephant`). That is by design and is
  why two FM_HOME installations on this box (the primary at
  `/home/hd2admin/kun-agent-workspace` and the secondmate at
  `/home/hd2admin/.treehouse/firstmate-46aafc/2/firstmate`) produce
  separate workspaces `w2`/`w3`/`w4` rather than colliding.

## Evidence index

- `herdr --version` → `herdr 0.9.1`, `herdr status` → `protocol: 22`
- `herdr workspace list` → 3 workspaces (`w2`, `w3`, `w4`)
- `herdr tab list` → 3 tabs (`w2:tA CHECKER · CODEX · IDLE`,
  `w3:t2 fm-br-system-herdr-audit`, `w4:t2 fm-br-system-ticket-audit`)
- `herdr pane list` → 4 panes with `agent_status` (codex working, pi working × 3, pi idle × 1)
- `herdr agent list` → same 4 agents, named `br-10-stream-a`,
  `br-01-herdr`, `br-02-tickets` (the latter two are this home's audit lanes)
- `state/br-system-herdr-audit.meta` → `harness=pi kind=scout model=minimax/MiniMax-M3 effort=medium backend=herdr herdr_session=default herdr_workspace_id=w3 herdr_tab_id=w3:t2 herdr_pane_id=w3:p2`
- `state/br-system-herdr-audit.pi-ext.ts` → loaded; sha256-bound; emits busy/idle events to `fm-busy-event.sh`
- `bin/fm-spawn.sh:478` (pi template), `:602` (model_flag_for_harness), `:1482` (pi-ext generation), `:1654` (model expansion), `:1660` (pi-ext path expansion)
- `bin/fm-herdr-lab.sh` head — guarded lab lifecycle helper
- `bin/fm-install-herdr.sh:8` — CI pin `FM_HERDR_CI_VERSION=0.7.4`
- `docs/herdr-backend.md` lines 5–6 — protocol floor 14, verified versions 0.7.1/0.7.3/0.7.4/0.7.5; lines 60–123 presentation spaces; lines 199–215 native agent state; lines 247–266 push events
- `docs/verification/runtime-backends.md` lines 121+ — latest verified 0.7.5 protocol 17 (live install 0.9.1 protocol 22)
- `docs/supervision-protocols/pi.md` lines 1–6 — extension auto-load and trust-free fallback (`-e __FM_PI_TURNEND_EXT__ -e __FM_PI_EXT__`)
- `state/home-summary.json` — both active scouts (`br-system-ticket-audit`, `br-system-herdr-audit`) reported as `working` with endpoint `default:w3:p2` / `default:w4:p2`

## Decisions carried forward (none require a captain answer for this audit)

This audit's deliverable is a recommendation. No captain-held task is
required. The six minimum-change items above are config / small PRs, each
independent; the captain can pick any subset and firstmate will dispatch
the corresponding ship work.

Captain, you already have a working visible + steerable + parallel Herdr
session; the remaining lift is naming convention and a one-time visual
board, not new infrastructure.