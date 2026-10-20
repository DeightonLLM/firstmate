# Partial report — Pi startup skill collisions and M3.1 selection

**Status: PARTIAL / BLOCKED. Not complete. No correction applied. No validation run. No tests-passed claim.**

Task: `pi-startup-collisions-20261013`
Worker: native `minimax/MiniMax-M3.1-Flash-Preview` (medium), primary lane
Isolated working root: `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/9/kun-agent-workspace` (clean at `cf2a3db3287c2181a20ba9a3486183fd0377ced0`)
Report written: 2026-10-13
Amended: 2026-10-13 — (a) §2 baseline corrected from supplied warning evidence; (b) §3 hypothesis **refuted** by the primary's fresh evidence and rewritten.

---

## 0. Phase ledger

| Phase | State |
|---|---|
| 1. Preflight | complete |
| 2. Scoped discovery | **in progress — halted by permanent shell refusal and a second compaction** |
| 3. Bounded comparison | pending |
| 4. Validation | pending |
| 5. Postflight / report | partial — this document only; decision-hold gate **not** satisfied; status appended as `blocked` |

Nothing in this report authorises a source, configuration, or content change.

---

## 1. Unverified items (explicit)

| Item | State | Why |
|---|---|---|
| `env`-based read of `PI_*` session variables | **UNVERIFIED — permanently denied** | shell policy refusal, exit 126. Not retried, not bypassed. |
| `for`-loop enumeration across skill roots | **UNVERIFIED — permanently denied** | shell policy refusal, exit 126. Not retried, not bypassed. |
| Model reported by an ordinary fresh launch | **SUPPLIED — resolved** | fresh launch at 2026-10-13 19:51:53Z warns "No models match pattern" and "not found for provider minimax. Using custom model id" |
| Visibility in an ordinary interactive `/model` picker | **UNVERIFIED** | requires an interactive picker observation; not performed, and the denied `env` read cannot substitute for it |
| Effective per-name collision ordering for the **primary root** | **SUPPLIED — resolved** | the Captain-supplied startup warning identifies winners and skipped copies; recorded in §2.4. No new scan was run to establish it |
| Effective per-name collision ordering for the **isolated worktree root** | **UNVERIFIED** | a different root with a different scan set; recorded separately in §2.4 and never substituted for the primary root |
| Which copy is canonical for each duplicated name | **NOT ESCALATED — settled by evidence** | the supplied startup warning already identifies the winners for the primary root; preserved unchanged in §2.4 |
| Scope of the documented `-path` exclusion against **automatically scanned** roots | **UNVERIFIED** | `-path` is documented for resource arrays in settings and for package manifests; whether it also masks an auto-scanned root (`~/.agents/skills`, `~/.pi/agent/skills`, project `.agents/skills`) is untested |
| Observed context 204800 vs catalog 1000000 | **EXPLAINED as a consequence; root cause open** | the session resolves through the custom-ID fallback, so the catalog `contextWindow` never applies. *Why* the `minimax` provider list omits an ID the catalog carries is still **unidentified** |
| Whether a `minimax` entry under `models` in `~/.pi/agent/models.json` resolves it | **UNVERIFIED — not tested** | `docs/models.md:67`; `modelOverrides` is not a route (unknown override IDs are ignored). No settings write was made |
| Precedence of `defaultModel` vs `enabledModels` at startup | **MOOT** | `enabledModels` carries `minimax/MiniMax-M3.1-Flash-Preview` as its first entry; precedence is not the cause |
| Effect of any exclusion change | **NOT VALIDATED** | no change has been applied, so no change has been observed; every recommendation below is untested |
| Precedence of `defaultModel` vs `enabledModels` at startup — see the **MOOT** row above; the duplicate row is withdrawn. |

**Retraction:** the earlier finding that `enabledModels` omits `minimax/MiniMax-M3.1-Flash-Preview` is **refuted** by the primary's fresh evidence and is withdrawn in full. The configured enabled list is not the cause.

---

## 2. Symptom 1 — duplicate skill-name warnings

### 2.1 Mechanism (verified from loader source)

Pi processes skill paths **in order**, keeps the **first** skill registered for a given name, and records every later entry for that name as a collision (earlier = winner, later = loser). Collision records are grouped and surfaced as startup diagnostics.

- Loader: `dist/core/resource-loader.js` (skill-path processing, first-wins/collision recording)
- Diagnostic surfacing: `dist/modes/interactive/interactive-mode.js:1289-1309`
- Automatic skill roots: project `.pi/skills`, project `.agents/skills`, user `~/.pi/agent/skills`, user `~/.agents/skills`

### 2.2 Trigger / masking condition / symptom — separated

- **Trigger:** two scanned roots contain byte-level sibling skills declaring the *same* `name:`. Confirmed for four names. Plus one backup directory that was never moved out of a live skills folder and is therefore still discovered.
- **Masking condition:** the loader **de-duplicates rather than failing**. Nothing breaks, and the skipped copy
  is reported only as a collision warning at startup. The de-duplication is first-wins by scan order, so the
  winner is decided by root order — but the supplied startup warning does surface it, so which copy is in
  force is knowable without guessing.
- **Symptom:** the startup collision warnings themselves. The consequential part is that a skipped copy — a
  backup directory, or a package copy shadowed by a user-level copy — remains in the scanned surface on every
  launch, so the same collision is re-reported indefinitely and a later edit to the skipped copy would have no
  effect while reading as though it did.

### 2.3 Evidence

Duplicate-name pairs confirmed on disk:

| Name | Winner (in force, primary root) | Skipped duplicate |
|---|---|---|
| `quota-axi` | `/home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi/SKILL.md` (project) | `/home/hd2admin/kun-agent-workspace/.agents/skills/quota-axi.bak-20261006/SKILL.md` |
| `no-mistakes` | `/home/hd2admin/kun-agent-workspace/.agents/skills/no-mistakes/SKILL.md` (project) | `/home/hd2admin/.agents/skills/no-mistakes/SKILL.md` |
| `tdd-red-green-refactor` | `/home/hd2admin/kun-agent-workspace/.agents/skills/tdd-red-green-refactor/SKILL.md` (project) | `/home/hd2admin/.agents/skills/tdd-red-green-refactor/SKILL.md` |
| `council-mode` | `/home/hd2admin/.pi/agent/skills/council-mode/SKILL.md` (user) | `/home/hd2admin/.pi/agent/npm/node_modules/pi-subagents/skills/council-mode/SKILL.md` |
| `pi-subagents` | `/home/hd2admin/.pi/agent/skills/pi-subagents/SKILL.md` (user) | `/home/hd2admin/.pi/agent/npm/node_modules/pi-subagents/skills/pi-subagents/SKILL.md` |

Pattern: the **project** root wins for `quota-axi`, `no-mistakes`, and `tdd-red-green-refactor`; the **user** root
wins for `council-mode` and `pi-subagents`, shadowing the copies shipped inside the `pi-subagents` package.

Both `quota-axi` directories declare `name: quota-axi` — the backup is a full sibling skill, not inert.

Package copies verified present:
`~/.pi/agent/npm/node_modules/pi-subagents/skills/{pi-subagents,council-mode}/SKILL.md`

### 2.4 Baseline — winners, preserved unchanged

The supplied startup warning identifies the winners for the **primary root**. Those winners are the baseline
and are preserved as-is. **No recommendation in this report changes which copy is in force, and none escalates
a canonical-ownership question — the winners are already known.**

**Primary root — from the supplied startup warning (check-marked copies), authoritative:**

| Name | Winner (check-marked, in force) | Skipped duplicate |
|---|---|---|
| `quota-axi` | project `quota-axi` | project `quota-axi.bak-20261006` |
| `no-mistakes` | `/home/hd2admin/kun-agent-workspace/.agents/skills/no-mistakes/SKILL.md` | `/home/hd2admin/.agents/skills/no-mistakes/SKILL.md` |
| `tdd-red-green-refactor` | `/home/hd2admin/kun-agent-workspace/.agents/skills/tdd-red-green-refactor/SKILL.md` | `/home/hd2admin/.agents/skills/tdd-red-green-refactor/SKILL.md` |
| `council-mode` | `/home/hd2admin/.pi/agent/skills/council-mode/SKILL.md` | `pi-subagents` package copy |
| `pi-subagents` | `/home/hd2admin/.pi/agent/skills/pi-subagents/SKILL.md` | `pi-subagents` package copy |

Provenance: supplied by the Captain from the startup warning. This table was **corrected in place** — an earlier
draft had the `no-mistakes` and `tdd-red-green-refactor` rows reversed. The correction came from that supplied
evidence, not from a new scan; no discovery was re-run.

**Isolated root — this worker's own session, recorded separately and NOT substituted for the above.**

This worker runs from the detached worktree
`/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/9/kun-agent-workspace`, which is a different root with a
different scan set. Its listing is a separate observation; where it differs from the primary root's baseline it
does not override the table above. This distinction is recorded so the two baselines are never conflated.

### 2.5 Non-destructive exclusion recommendations

Recommendations only. None was performed, none was validated, and none changes a winner. Every option targets
the **skipped** copy only.

**Documented mechanisms (both confirmed in the installed docs):**

- `docs/settings.md:147-161` — **Resources.** Resource arrays (`extensions`, `skills`, `prompts`, `themes`)
  support glob exclusions with `!pattern`, exact inclusion with `+path`, and **exact exclusion with `-path`**.
  User-settings paths resolve from the agent directory; project-settings paths resolve from the project `.pi`
  directory; absolute paths and `~` are supported.
- `docs/packages.md:115-119,125` — package **filters** narrow a package's manifest: `!pattern` excludes glob
  matches, `+path` includes one exact allowed path, `-path` excludes one exact path. Filters do not expose
  resources the package did not declare, and a project entry with `autoload: false` acts as a filtering delta
  over the personal entry.

1. **`quota-axi.bak-20261006` — exclude the backup directory by exact path.** Add a `-path` entry naming that
   directory to the applicable `skills` resource array. A backup directory inside a live skills folder is
   discovered exactly like a real skill; the exclusion removes the duplicate while leaving the in-force
   `quota-axi` copy untouched.
2. **Skipped user-level `no-mistakes` / `tdd-red-green-refactor` copies — same mechanism.** The winners are the
   **project** copies (§2.4); the copies to exclude are the **skipped user-level** ones:
   `/home/hd2admin/.agents/skills/no-mistakes` and `/home/hd2admin/.agents/skills/tdd-red-green-refactor`.
   One exact `-path` entry per skipped copy in the applicable `skills` array.
   **The winning project copies are never an exclusion target.** An entry naming
   `/home/hd2admin/kun-agent-workspace/.agents/skills/no-mistakes` or
   `.../tdd-red-green-refactor` would remove the skill that is actually in force — that entry must not be
   written.
3. **`council-mode` / `pi-subagents` package copies — package manifest filters.** A `-path` filter on the
   `pi-subagents` package entry narrows its manifest so those two skills are not exposed, without editing any
   file inside `~/.pi/agent/npm/node_modules/pi-subagents/` and without touching the winning user-level copies.
4. **Scope caveat, applies to all three.** The `-path` syntax is documented for resource arrays and package
   manifests. The colliding copies live in **automatically scanned** roots (`~/.agents/skills`,
   `~/.pi/agent/skills`, project `.agents/skills`), which are discovered without being listed. Whether an
   exclusion entry masks an auto-scanned root is **untested** and is the first thing to verify.
5. **Every change above requires validation before it is treated as effective.** Nothing has been applied, so
   nothing has been observed. No "this removes the warning" claim is made for any item.

---

## 3. Symptom 2 — `MiniMax M3.1 Preview` missing from ordinary fresh launches

### 3.1 Evidence (corrected — the earlier §3.1 finding is refuted and withdrawn)

| Source | Finding |
|---|---|
| `~/.pi/agent/settings.json`, deliberately rewritten **2026-10-13T20:51:02+0100** (= **19:51:02Z**, epoch `1791921062`) | `enabledModels` **does contain `minimax/MiniMax-M3.1-Flash-Preview`, as its first entry**; list pruned **13 → 7** models; `defaultModel` = `MiniMax-M3.1-Flash-Preview`. A deliberate edit — **not** an auto-reset |
| Fresh launch probe **2026-10-13T19:51:53.630Z** — **51 seconds after** the rewrite | warns **"No models match pattern"** and **"not found for provider minimax. Using custom model id"**, emitted **against the rewritten state** |
| `models-store.json` | M3.1 **is** listed, `contextWindow: 1000000` |
| Observed session footer | **204800** |
| `~/.pi/agent/models.json` | no `minimax` provider entry; OpenAI / OpenAI-Codex overrides only |
| `docs/settings.md:18` | `enabledModels` governs startup model selection and cycling |
| `docs/models.md:67` | a `models` entry **adds or replaces** a model with the same ID on that provider; `modelOverrides` changes metadata for an **existing** model — **unknown override IDs are ignored** |
| `docs/models.md:195-197` | a model absent from `/model` usually means the provider lacks usable authentication; custom models can load from `models.json` yet stay unavailable in `/model` until credentials resolve |
| `dist/core/settings-manager.js:1045-1057` | reads and writes `enabledModels` |
| `dist/core/agent-session.js:2002-2008` | applies enabled-model patterns plus exact model-reference matching |

**Corrected ordering.** An earlier note in this report compared the two timestamps as if they shared a zone and
read the launch as preceding the rewrite by ~1 hour. **That was a timezone misread and is withdrawn.** The
settings mtime `20:51:02` is **+0100 local**, i.e. **19:51:02Z**; the probe at **19:51:53.630Z** therefore ran
**51 seconds after** the rewrite. Consequences, both now settled: the warnings were emitted **against the
rewritten state**, and the rewrite **does not narrow the symptom**.

**Layer confirmed.** With enablement ruled out, the gap is **provider registration, not enablement**: the
enabled list carries the pattern, and resolution still fails because the `minimax` provider's model list lacks
the ID.

**Refuted and withdrawn:** the earlier claim that `enabledModels` omits `minimax/MiniMax-M3.1-Flash-Preview`.
The configured enabled list is **not** the cause. The prior `models-store.json:85-86` citation is superseded by
the `contextWindow: 1000000` value in the row above; the `models-store.json.bak-pre-m31-and-retire-20261013`
comparison is retained only as a note that the catalog registration is recent and deliberate.

### 3.2 Reading — resolution runs against the provider list, not the cached catalog

Sequence supported by the evidence above:

1. `enabledModels` matches — the pattern is present, as the **first** entry. **Enablement is confirmed working.**
2. The **`minimax` provider's own model list** does not carry the ID → **"No models match pattern"**.
   **Registration is the confirmed gap layer.**
3. Lookup fails for provider `minimax` → **"Using custom model id"**.
4. The session therefore runs a **custom-ID fallback**, which carries the default context rather than the
   catalog's, yielding **204800** against a catalog `contextWindow` of **1000000**.

Because the probe ran 51 s after the rewrite (§3.1), steps 1–4 all describe the **current** configured state.
Nothing here is explained away by the rewrite.

This **explains the 204800/1000000 metadata gap as a consequence rather than a separate fault**: the session is
not running under the catalog identity, so the catalog's context window cannot apply. The remaining open
question is confined to registration: **why** the `minimax` provider list lacks an ID the cached catalog
carries. That is **not** answered by anything in this report.

### 3.3 What remains unverified

- **Interactive picker visibility.** Whether `minimax/MiniMax-M3.1-Flash-Preview` appears in an ordinary
  interactive `/model` picker. Per `docs/models.md:195-197` a model can be missing from `/model` for an
  authentication reason even when it loads, so picker absence and provider-list absence are **different
  observations** and only the first has not been made.
- **Whether a `minimax` entry under `models` in `~/.pi/agent/models.json` resolves it.** `docs/models.md:67`
  indicates such an entry adds or replaces a model on that provider. `modelOverrides` is **not** a viable
  route: unknown override IDs are ignored, and no `minimax` provider entry exists today. **Untested — no
  settings write was made and none is authorised by this report.**
- Why the `minimax` provider list omits an ID the catalog carries — the sole remaining gap, at the
  **registration** layer. Enablement is ruled out (§3.2).
- Which catalog source the provider list is built from when the cached catalog already contains the model.

---

## 4. Blockers and smallest missing owner input

| # | Missing input | Unblocks |
|---|---|---|
| ~~A~~ | ~~The model line an ordinary fresh launch reports~~ | **CLOSED** — answered by the 19:51:53Z fresh-launch warnings; §3 rewritten |
| **A** | **Interactive picker visibility** — one observation of whether `minimax/MiniMax-M3.1-Flash-Preview` appears in an ordinary `/model` picker. Distinct from provider-list absence (`docs/models.md:195-197`) | phase 3, §3.3 |
| **B** | Whether a `models` entry for `minimax` in `~/.pi/agent/models.json` is authorised to be added, then validated (`docs/models.md:67`). `modelOverrides` is **not** an available route — unknown override IDs are ignored | phase 3 → 4 |
| **C** | Which settings scope the exclusion entries belong in for the primary root — user (agent directory) or project (project `.pi`), since paths resolve from different bases per `docs/settings.md:147-161` | phase 4, §2.5 |
| **D** | Authorisation to validate one exclusion entry and observe the result — no change may be called effective without it | phase 4 |

No canonical-choice input is outstanding: the winners are identified by the supplied warning (§2.4).
Input **B** is a settings write and is therefore outside this task's authority until explicitly authorised.

---

## 5. What was deliberately not done

- No retry or bypass of either denied command; the shell policy was not modified.
- No settings, models, package, shared-source, backup, production, or credential writes of any kind.
- No new child, model switch, alternate pane, fallback path, or repeat connectivity probe.
- No deletion, rename, move, or content edit anywhere — including the backup skill directory.
- No `-path` exclusion entry was added to any settings file or package manifest; the recommendations in §2.5 are unwritten.
- No exclusion is claimed to be effective; each one remains unvalidated.
- No claim that any correction is validated, and no tests-passed or done claim.
- Report is partial; the decision-hold completion gate is not satisfied and must not be treated as satisfied.