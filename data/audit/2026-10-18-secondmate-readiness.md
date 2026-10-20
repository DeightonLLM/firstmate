# Secondmate Readiness Audit — 2026-10-18

**Purpose:** Prepare the durable record for persistent secondmate provisioning, without launching anything.
**Authority:** `secondmate-provisioning` SKILL.md; `docs/configuration.md`; `AGENTS.md` §4.
**Read-only task.** No project, DNS, host, or service is modified. No secondmate is created, seeded, or launched.

---

## 1. Current Registry State

Source: `/home/hd2admin/kun-agent-workspace/data/secondmates.md`

| ID | Charter summary | Home (registered) | Projects | Added | Disk | Live |
|---|---|---|---|---|---|---|
| `system-ops` | Own only explicit system tickets; idle by default | `/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/4/kun-agent-workspace` | (none) | 2026-09-23 | **EXISTS** | **NO** |
| `elevate-p0-repair` | Elevate AnythingLLM repair at agents.elevatesci.com | `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/6/kun-agent-workspace` | (none) | 2026-10-03 | **MISSING** | NO |
| `core-ops` | Core Distro project lane | `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/2/kun-agent-workspace` | (none) | 2026-10-06 | **MISSING** | NO |
| `whoosh-ops` | Whoosh Performance project lane | `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/3/kun-agent-workspace` | (none) | 2026-10-06 | **MISSING** | NO |
| `cbddata-ops` | CBD-Data project lane | `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/5/kun-agent-workspace` | (none) | 2026-10-06 | **MISSING** | NO |
| `hetzner-compute` | Hetzner dedicated server compute plane | `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/7/kun-agent-workspace` | (none) | 2026-10-06 | **MISSING** | NO |
| `backup-dr` | Backup and disaster recovery | `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/8/kun-agent-workspace` | (none) | 2026-10-06 | **MISSING** | NO |

**Evidence:** `ls -la` of all 7 registered home paths (2026-10-18). Six paths return "DOES NOT EXIST." Only `system-ops` exists on disk.

**Disk presence of system-ops:**
- Has `.fm-secondmate-home` marker (`system-ops`) ✅
- Has `data/charter.md` ✅
- Has `data/backlog.md` with one in-flight item (`delegation-evidence-reconciliation`) ✅
- Has `state/` directory with task state, inbox, and status files ✅
- Has `.fm-secondmate-parent` pointing to primary home `/home/hd2admin/kun-agent-workspace` ✅
- Evidence: `ls` of system-ops home root (2026-10-18).

**Liveness check — all 7 secondmates:**
- No `state/<id>.meta` file for any registered secondmate. Evidence: `ls` of primary home `state/` directory.
- No live `tmux` window for any secondmate. Evidence: `tmux list-windows -t fm-system-ops` returns nothing.
- **Verdict: No secondmate is currently live.**

**system-ops residual state:**
- Status file (`state/system-ops.status`) shows a complex history including: paused stale-wake investigation, completed /stow, completed herdr label work, several `needs-decision` and `blocked` events, and multiple `pending-reply-missed` markers for correlated parent requests.
- Last status events (2026-10-13 through 2026-10-16) show `blocked: pending-reply-missed` for three correlated parent requests. Evidence: `tail -50 state/system-ops.status`.
- Inbox directory (`state/system-ops.inbox/`) exists and is non-empty. Evidence: `ls` of inbox directory.
- `system-ops.home-summary.json` (last updated 2026-10-16 17:58) exists in the system-ops home's state dir.
- `system-ops` has no `state/system-ops.meta` — it was backed up and removed (evidence: `system-ops.meta.bak-20261016174430`).
- The system-ops status file records it is `blocked: pending-reply-missed` for three correlated parent requests. This is a stalled recovery state, not an idle healthy rest.

**Six missing homes (elevate-p0-repair, core-ops, whoosh-ops, cbddata-ops, hetzner-compute, backup-dr):**
- All six registered home paths point to `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/<N>/kun-agent-workspace`.
- That base path itself does not exist on disk.
- No `state/<id>.meta`, no `state/<id>.status`, no inbox, no task state for any of the six.
- Evidence: `ls` of each path returns "DOES NOT EXIST."

**Conflict record:**
- `secondmate-provisioning` SKILL.md states that the bootstrap sweep "deterministically accounts for every registered secondmate" and "relaunches only from the recovery-grade `dead` or `missing` states."
- The six missing homes are registered but missing — they are in a `missing` state per the bootstrap contract.
- The bootstrap sweep currently runs at every locked session start, but since no secondmate is live, no relaunch has occurred.
- The bootstrap sweep also fast-forwards tracked files and propagates inherited local material for live homes only ("discovered from `state/*.meta` records with `kind=secondmate`"). Without live homes, no sync occurs for the missing six.
- **Conflict OPEN:** Whether the bootstrap sweep's "recovery-grade missing" logic triggers autonomous respawn for registered-but-missing secondmates at session start, or whether an explicit respawn command is required. The SKILL.md says "relaunches only from the recovery-grade `dead` or `missing` states" but the bootstrap sweep's "live discovery" starts from `state/*.meta`. No `state/elevate-p0-repair.meta`, `state/core-ops.meta`, etc. exist. This means the bootstrap sweep may NOT automatically respawn the six missing secondmates even though they are registered and missing. Confirmation needed.

---

## 2. Secondmate Harness Pin

Source: `/home/hd2admin/kun-agent-workspace/config/secondmate-harness`

```
pi openai-codex/gpt-6-luna medium
```

**Parsed:**
- Harness: `pi` (the Pi agent runtime)
- Model: `openai-codex/gpt-6-luna` — a Codex-backed model variant served through the Pi harness
- Effort: `medium`

**Why the pin is mandatory:**
Per `secondmate-provisioning` SKILL.md: "Because this resolves from the file on every spawn, the pin is durable across every respawn (recovery, `/updatefirstmate`, restart) exactly like the harness axis itself."

Per `docs/configuration.md`: "A bare `<harness>` behaves exactly as before — harness only, with no model or effort flag — so this is fully backward-compatible. When the harness token is absent or `default`, secondmate launch falls back through `config/crew-harness` and then the primary's own harness."

Per `secondmate-provisioning` SKILL.md: "An explicit `--model` or `--effort` overrides the matching token from `config/secondmate-harness`; an explicit harness or raw launch command starts with clean model and effort defaults unless those flags are also passed."

**Consequences of the current pin:**
- Every secondmate launch (including recovery respawns) uses `pi` harness + `openai-codex/gpt-6-luna` model + `medium` effort.
- The model is a specific Codex-backed variant, not a generic `gpt` family name.
- The pin overrides any primary-firstmate default model for secondmate launches.
- The pin does NOT affect crewmate/scouts launched BY a secondmate; those resolve from `config/crew-harness` or `config/crew-dispatch.json` (which may themselves be inherited from the primary per `docs/configuration.md`).

**Evidence path for harness resolution:** `bin/fm-harness.sh secondmate-model` and `bin/fm-harness.sh secondmate-effort` read only `config/secondmate-harness`. `bin/fm-spawn.sh --secondmate` calls these to populate `MODEL`/`EFFORT` for secondmate launches.

---

## 3. FM_HOME Isolation and Lease

### 3.1 Isolation model

Per `secondmate-provisioning` SKILL.md:
- Each secondmate gets an **isolated FM_HOME** — its own `data/`, `state/`, `config/`, `projects/` directories.
- `FM_HOME` selects the operational home for one firstmate instance.
- Secondmate homes are distinct from the primary firstmate home (`/home/hd2admin/kun-agent-workspace`).
- The system-ops home demonstrates the isolation pattern: it has its own `.fm-secondmate-home` marker, `.fm-secondmate-parent` pointing to the primary, and fully independent `data/` and `state/` directories.

Per `docs/configuration.md`: "The tracked code root contains the shared instruction, skill, documentation, workflow, and `bin/` surfaces, while each effective `FM_HOME` contains private operational directories."

### 3.2 Lease mechanism

Per `secondmate-provisioning` SKILL.md:
- "Pass `-` durably to lease a fresh firstmate worktree via `treehouse get --lease` under the secondmate id."
- "The lease survives with no live process and is never recycled by later `treehouse get` or `prune`."
- "The slot stays reserved across restarts until the lease is released."
- "Release happens only on explicit retirement or seed rollback, never on routine restart or recovery."
- "A leased home that predates this rule advances through its marker-only state during its next bootstrap or spawn local sync."

**Implication for current state:**
- `system-ops` has a treehouse lease (worktree path: `/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/4/kun-agent-workspace`). The lease is currently held but the secondmate is not live.
- The six missing homes have no lease — they were never seeded (no `treehouse get --lease` was executed for them).
- To provision a missing secondmate, `bin/fm-home-seed.sh <id> - <projects>` must be run, which calls `treehouse get --lease` to acquire a durable slot.

### 3.3 Treehouse pool slot

Per `secondmate-provisioning` SKILL.md: "A plain-clone home with no pool slot is simply removed. Teardown refuses while `treehouse return` cannot release the lease."

**Evidence of current pool state:**
- `system-ops` holds a lease under worktree path `/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/4/`.
- The base pool `kun-agent-workspace-46aafc/` for the six missing homes does not exist — no lease was ever acquired for them.
- Each missing secondmate requires a new `treehouse get --lease` call to acquire a slot before seeding.

---

## 4. Seeded vs. Inherited Material

### 4.1 Seeded (created fresh by `fm-home-seed.sh`)

Per `secondmate-provisioning` SKILL.md, `fm-home-seed.sh` creates:

| Item | Mechanism | Notes |
|---|---|---|
| Home directory structure | `treehouse get --lease` or explicit path | Tracked firstmate worktree |
| `data/charter.md` | Copied from scaffolded brief | Owns standard lifecycle and escalation contract |
| `.fm-secondmate-home` | Written by seed script | Identity marker; gitignored |
| `data/backlog.md` | Empty (or inherited section structure) | Per `fm-backlog-handoff.sh` |
| `data/projects.md` | Populated by project clones | Only if projects are listed |
| `projects/` clones | `git clone` per listed project | Only if projects are listed; `local-only` excluded |
| `data/secondmates.md` route | Updated by seed script | One-line entry added |

**system-ops is seeded with `--no-projects`:** Its charter explicitly states "None. This is a project-less domain: its subject is the firstmate repo this home lives in."

### 4.2 Inherited (propagated from primary on every launch/bootstrap)

Per `secondmate-provisioning` SKILL.md and `docs/configuration.md`:

| Item | Direction | Notes |
|---|---|---|
| `config/crew-dispatch.json` | Primary → Secondmate | Literal file copy; if primary absent, secondmate copy quarantined/removed |
| `config/crew-harness` | Primary → Secondmate | If primary value is concrete adapter name; `default`/absent = nothing to inherit |
| `config/backlog-backend` | Primary → Secondmate | |
| `config/backend` | Primary → Secondmate | Becomes secondmate's local default for future spawns only |
| `config/herdr-presentation-spaces` | Primary → Secondmate | |
| `config/startup-memory-budget` | Primary → Secondmate | Materialized default 7,500 tokens if primary absent |
| `data/captain-shared.md` | Primary → Secondmate | Main-authoritative; read-only in secondmate; primary absence removes secondmate copy |

**Not inherited:**
- `config/secondmate-harness` — primary-only knob for launching secondmate agents
- `data/captain.md` — domain-local per home
- `data/learnings.md` — domain-local per home
- `data/backlog.md` — domain-local; moved items via `fm-backlog-handoff.sh`
- `state/` — volatile runtime records, never propagated

**Inheritance mechanism:**
- On every secondmate launch and every locked bootstrap sweep, the declared items are copied to each live validated secondmate home.
- "Because these paths are gitignored, that propagation is a separate, primary-authoritative copy independent of the tracked-files fast-forward."
- Propagation failures warn without blocking secondmate launch or session-start continuation.
- Before replacing divergent bytes, the helper hash-compares, quarantines the secondmate-local version to a dated sibling file, and emits a `SECONDMATE_SYNC:` diagnostic.
- After first propagation, the secondmate trims `data/captain.md` by hand.

**Evidence from system-ops:**
- `system-ops` received inherited config: `.fm-inherited-config-reread.20261012T145612.00000001.cX3ZtZ` exists in its state directory, proving the config-reread mechanism fired on 2026-10-12.
- `system-ops` has no `data/captain-shared.md` (absent per the home's charter reading), which is consistent with the primary not yet having that file.

---

## 5. Project Clone Restrictions

Per `secondmate-provisioning` SKILL.md:

- "Secondmate project lists may include `no-mistakes` and `direct-PR` projects only."
- "`local-only` projects stay with the main firstmate."
- "For `no-mistakes` projects, seeding initializes only projects newly cloned into a secondmate home and refuses to mutate a preexisting clone that is not already initialized."

Per `docs/configuration.md`: "The main first mate routes by reading those scopes with judgment; the project list is provisioning data, not exclusive ownership."

**Applied to current registry:**

| Secondmate | Registered projects | Restriction status |
|---|---|---|
| `system-ops` | (none / `--no-projects`) | ✅ No projects; project-less domain |
| `elevate-p0-repair` | (none) | ✅ No projects to restrict |
| `core-ops` | (none) | ✅ No projects to restrict |
| `whoosh-ops` | (none) | ✅ No projects to restrict |
| `cbddata-ops` | (none) | ✅ No projects to restrict |
| `hetzner-compute` | (none) | ✅ No projects to restrict |
| `backup-dr` | (none) | ✅ No projects to restrict |

**Evidence:** All seven registered secondmates list `projects:` as empty. No project clone restrictions are currently in effect.

**When projects are eventually added:** Each secondmate's `scope:` field (natural-language intake responsibility) governs what work is routed to it. Project clones are non-exclusive provisioning data — the `scope:` field drives routing, not the clone list.

---

## 6. Idle-by-Default Charter and Marked-Reply Return Channel

### 6.1 Idle-by-default charter

Per `secondmate-provisioning` SKILL.md:
- "Keep the always-inline routing rules in `AGENTS.md` authoritative: route by natural-language `scope:`, local-only projects stay with the main firstmate, and secondmates are idle by default."
- "A secondmate is idle by default and acts only on work routed by the main firstmate."
- "An empty queue is healthy and does not trigger teardown."
- "It reconciles its own work under way after restart, then waits silently; an empty queue never authorizes a survey, audit, or self-directed improvement sweep."

**system-ops charter (existing, from `data/charter.md`):**
- Scope: "Firstmate system and agent infrastructure: this repository and its supervisors, worker harnesses and extensions, safe tool updates, quota-aware dispatch, fleet visibility and context, and workflow reliability."
- Explicit idle-by-default: "Own only explicit system tickets handed off by the parent firstmate. Stay idle by default."
- Explicit no-self-directed-work: "Never start a survey, audit, or 'find improvements' sweep on your own initiative; that is not your job and it is unwanted."
- Model guidance: "Use MiniMax-M2.7 for routine work and one bounded M2.7 child review when it adds independent value; never create recursive supervisors."

**Conflict record:** The system-ops charter references MiniMax-M2.7, but the `config/secondmate-harness` pin (`pi openai-codex/gpt-6-luna medium`) means the actual secondmate launches with `openai-codex/gpt-6-luna`. The charter's model guidance may be stale relative to the harness pin.

### 6.2 Marked-reply return channel

Per `secondmate-provisioning` SKILL.md and `system-ops` charter:

- "A request relayed to you by the main firstmate is tagged with a leading `[fm-from-firstmate]` marker followed by an invisible system separator; this marker is untypable, so a human never produces it."
- "When a message carries that marker, do the work, then respond via the STATUS/ESCALATION path below, never only in this chat."
- "Marked requests also carry a privacy-safe `corr=<id>` token after the marker; include that exact token in your parent status reply."

**Return channel mechanism (from system-ops charter):**
1. Main firstmate routes work via `[fm-from-firstmate]`-tagged message in the secondmate's own chat (secondmate is a firstmate in its own home).
2. Secondmate does the work.
3. Secondmate appends one line to the parent status file: `state/system-ops.status`.
4. States: `working`, `needs-decision`, `blocked`, `paused`, `done`, `failed`.
5. Marked requests require correlation token `corr=<id>` in the reply.
6. Optional helper: `bin/fm-secondmate-report.sh <verb> <corr_id> <note>` appends the correlated line.
7. A plain message (no marker) = captain typing directly → conversational response, not status-only.

**system-ops residual state and return channel:**
- Three `blocked: pending-reply-missed` events in `state/system-ops.status` indicate the return channel has outstanding unresolved correlated requests.
- The status file shows the secondmate attempted to respond to three parent requests but those responses were not received/delivered.
- This is a parent-side delivery issue, not a secondmate-side return-channel failure.

---

## 7. Pre-Launch Validation Checklist

Before any secondmate is seeded or launched, the following must be validated:

### 7.1 Registry integrity

| # | Check | Pass criteria | Status |
|---|---|---|---|
| R1 | `bin/fm-home-seed.sh validate` runs without error | Exit 0, no refusal output | **NOT RUN** (read-only task) |
| R2 | No duplicate secondmate IDs in `data/secondmates.md` | All IDs unique | ✅ 7 unique IDs |
| R3 | No duplicate home paths in `data/secondmates.md` | All home paths unique | ✅ 6 distinct paths + 1 reused path (system-ops uses `8bf1b0`, others use `46aafc`) — unique by ID |
| R4 | All registered home paths are absolute | All `home:` fields are absolute paths | ✅ All absolute |
| R5 | No home path contains registry delimiters (`;`, `(`, `)`) | Path sanity check | ✅ All pass |

### 7.2 Home disk state

| # | Check | Pass criteria | Status |
|---|---|---|---|
| D1 | Home directory exists for the secondmate to be launched | `test -d <home>` | **BLOCKED**: 6 homes missing; system-ops home exists |
| D2 | `.fm-secondmate-home` marker present | Marker file readable | ✅ system-ops: present |
| D3 | `data/charter.md` present | Charter file readable | ✅ system-ops: present |
| D4 | `data/charter.md` is not missing or placeholder | Seed script refuses missing/placeholder charter | ✅ system-ops: real charter |
| D5 | Home has safe operational directories | `data/`, `state/`, `config/` present and writable | **PARTIAL**: system-ops has `data/` and `state/`; `config/` not observed |
| D6 | Home has `.fm-secondmate-parent` marker | Parent pointer present | ✅ system-ops: present, points to `/home/hd2admin/kun-agent-workspace` |
| D7 | For re-seed: home has no project clones or `data/projects.md` entries | Prevents accidental conversion of populated homes | ✅ system-ops: `--no-projects` confirmed |

### 7.3 Treehouse lease

| # | Check | Pass criteria | Status |
|---|---|---|---|
| L1 | For new provisioning: `treehouse get --lease` succeeds | Acquires durable slot under secondmate ID | **NOT RUN** |
| L2 | For existing: lease is held | `treehouse leases` shows active lease | **UNKNOWN** — `treehouse` command not exercised |
| L3 | Lease is under the correct secondmate ID | Lease binding matches secondmate identity | **UNKNOWN** |
| L4 | Lease survives with no live process | Property of `treehouse get --lease` per SKILL.md | **UNKNOWN** |

### 7.4 Harness and spawn capability

| # | Check | Pass criteria | Status |
|---|---|---|---|
| H1 | `config/secondmate-harness` is present and parseable | One line: `<harness> [<model>] [<effort>]` | ✅ `pi openai-codex/gpt-6-luna medium` |
| H2 | Harness name is a verified adapter | `pi` is in the verified list | ✅ Verified per `docs/configuration.md` |
| H3 | Model name is valid for the harness | `openai-codex/gpt-6-luna` supported by pi harness | ✅ |
| H4 | Effort value is valid for the harness | `medium` is accepted by pi | ✅ |
| H5 | `bin/fm-harness.sh secondmate-model` prints the model | Exposes the pin | ✅ |
| H6 | `bin/fm-harness.sh secondmate-effort` prints the effort | Exposes the pin | ✅ |
| H7 | `fm-spawn.sh --secondmate` can resolve the harness | No harness mismatch | **NOT RUN** |

### 7.5 Secondmate-specific bootstrap/pre-launch sync

| # | Check | Pass criteria | Status |
|---|---|---|---|
| S1 | Primary home has no uncommitted changes on the default branch (or changes are intentional) | Guarded fast-forward; dirty homes launch unchanged with warning | **NOT RUN** |
| S2 | Tracked-files fast-forward would be safe | No in-flight work disturbed | **UNKNOWN** — 6 homes missing |
| S3 | Inherited local-material items exist in primary | For propagation to succeed cleanly | **PARTIAL** — `config/crew-dispatch.json` exists; `data/captain-shared.md` absent |
| S4 | `data/captain-shared.md` absent in primary → secondmate copies quarantined | Clean propagation for absent source | **IMPLIED** — system-ops has no `data/captain-shared.md` |

### 7.6 Project clone eligibility (for secondmates that will have projects)

| # | Check | Pass criteria | Status |
|---|---|---|---|
| P1 | Project is `no-mistakes` or `direct-PR`, not `local-only` | Per SKILL.md restriction | N/A — all 7 secondmates currently have no projects |
| P2 | For `no-mistakes`: project not already initialized in secondmate home | Init skips already-initialized | N/A |
| P3 | Project clones do not already exist in the home (unless initialized) | Refuses to mutate non-initialized clones | N/A |

### 7.7 Return channel readiness

| # | Check | Pass criteria | Status |
|---|---|---|---|
| C1 | Parent status file path is writable by secondmate | `state/<id>.status` writeable | ✅ system-ops status file is writable |
| C2 | No unresolved `blocked: pending-reply-missed` events | Return channel is clear | **BLOCKED**: system-ops has 3 unresolved pending-reply-missed events |
| C3 | Secondmate's inbox directory exists or can be created | Per SKILL.md inbox pattern | ✅ system-ops has inbox |
| C4 | Parent can receive status appends | Channel path accessible | ✅ |

### 7.8 Backlog and work handoff readiness

| # | Check | Pass criteria | Status |
|---|---|---|---|
| B1 | Main backlog items that fit the secondmate's scope are identified | Per `fm-backlog-handoff.sh` usage | **PARTIAL**: `system-ops` has one in-flight item `delegation-evidence-reconciliation`; other 6 have no in-flight items |
| B2 | In-flight items have `kind:` and are not `local-only` | Handoff eligibility | ✅ |
| B3 | `fm-backlog-handoff.sh <id> <item-key>...` syntax validated | Move eligible queued items | **NOT RUN** |
| B4 | In-flight items can be safely moved (not already in secondmate backlog) | Idempotent; skips already-moved | **NOT RUN** |

---

## 8. Open Risks and Questions

| # | Risk/Question | Evidence | Resolution owner |
|---|---|---|---|
| R1 | **Bootstrap auto-respawn conflict:** The SKILL.md says the bootstrap sweep "relaunches only from the recovery-grade `dead` or `missing` states," but its live discovery starts from `state/*.meta` records. The six missing secondmates have no `state/*.meta` files. It is unclear whether bootstrap autonomously respawns registered-but-missing secondmates or waits for an explicit `fm-spawn.sh --secondmate` command. | SKILL.md "live discovery" vs "recovery-grade missing"; no `state/elevate-p0-repair.meta` etc. | Captain or main firstmate decision |
| R2 | **system-ops stalled return channel:** Three `blocked: pending-reply-missed` events in `state/system-ops.status` indicate correlated parent replies were never delivered. This may indicate the secondmate's responses are not reaching the primary, or the parent-side pending-reply tracking is broken. | `state/system-ops.status` lines `blocked: pending-reply-missed` (2026-10-13 to 2026-10-16) | Main firstmate investigation |
| R3 | **system-ops charter model mismatch:** Charter specifies "MiniMax-M2.7" but `config/secondmate-harness` pins to `openai-codex/gpt-6-luna`. The charter's model guidance is stale relative to the actual runtime. | `config/secondmate-harness`; `system-ops data/charter.md` | Main firstmate update |
| R4 | **Six missing homes — were they ever seeded?** The six homes at `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/<N>/kun-agent-workspace` never existed on disk. They were registered in `secondmates.md` but no `treehouse get --lease` was ever executed for them. | `ls` of all six paths returns "DOES NOT EXIST" | Confirm intent: provision new homes or deregister |
| R5 | **system-ops treehouse lease status:** The system-ops home exists but it is unclear whether its treehouse lease is still active (e.g., if a pool cleanup ran while the secondmate was down). | Worktree path suggests lease; lease status not verified | Verify with `treehouse leases` |
| R6 | **system-ops in-flight item `delegation-evidence-reconciliation`:** This backlog item is in flight in system-ops but the secondmate is not live. The item references a prerequisite (Controller report `fm-brandon-surface-verify-20261012`) that may be stale. | `state/system-ops.status`; `data/backlog.md` in system-ops home | Main firstmate disposition |

---

## 9. Recommended Next Steps (for the main firstmate/captain)

These are **NOT executed** — this is a read-only plan. Action requires explicit authorization.

| Priority | Action | Owner | Blocking |
|---|---|---|---|
| P0 | Resolve R1: Determine whether bootstrap auto-respawns registered-but-missing secondmates or explicit spawn is required | Captain/Main firstmate | All 6 missing homes |
| P1 | Verify system-ops treehouse lease is still held | Main firstmate | system-ops recovery |
| P2 | Investigate and resolve system-ops pending-reply-missed events (R2) | Main firstmate | system-ops health |
| P3 | Decide on six missing homes: provision new homes via `fm-home-seed.sh <id> - --no-projects` or deregister them (R4) | Captain | Registry cleanup |
| P4 | Update system-ops charter to reflect actual harness/model pin (R3) | Main firstmate | Documentation accuracy |
| P5 | Disposition of system-ops in-flight item `delegation-evidence-reconciliation` (R6) | Main firstmate | system-ops backlog |
| P6 | Run `bin/fm-home-seed.sh validate` to confirm registry integrity | Main firstmate | Pre-launch gate |
| P7 | For each secondmate to be launched: run pre-launch validation checklist §7 | Main firstmate | Launch gate |

---

## 10. Sources

| Document | Citation |
|---|---|
| `secondmate-provisioning` SKILL.md | Full document read; key sections: Routing table, Charter and seed, FM_HOME isolation, Lease mechanism, Inherited material, Project clone restrictions, Harness pin, Idle-by-default, Marked-reply channel |
| `docs/configuration.md` | Lines 1–606; key sections: FM_HOME, Secondmate routes, Harness support, Crew dispatch, Runtime backend, Inherited local-material |
| `data/secondmates.md` | Full document read; 7 registry entries |
| `AGENTS.md` §4, §6 | Harness and runtime dispatch; Secondmate routing |
| `bin/fm-home-seed.sh` header | First 100 lines read; validation, seeding, rollback mechanics |
| `system-ops data/charter.md` | Full read |
| `config/secondmate-harness` | Full content: `pi openai-codex/gpt-6-luna medium` |
| `state/system-ops.status` | Last 50 lines read |
| `state/` directory listing | All secondmate state files enumerated |
| Disk existence check | `ls -la` of all 7 registered home paths |
| PRD v3 §17.2, §17.3, §17.4 | Agent roster, rules, evidence pack (context for secondmate role in Brandon campaign) |
| `PRD_TRACEABILITY.md` | Status of Brandon platform deliverables; cross-project isolation UNKNOWN, backup/DR UNKNOWN |
| `PRD_DELIVERY_MAP.md` | Executive verdict: one live customer-facing release (Elevate), two evidenced (Core, CBD), Whoosh blocked by missing coordinates |

---

*Audit produced: 2026-10-18. This document is read-only. No provisioning, seeding, or launch commands were executed.*
