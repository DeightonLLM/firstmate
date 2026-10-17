# Docs Correction Programme

**Scope:** This repository only. Dated evidence records and dated incident files are out of scope
(they are records of what was observed, not live policy). Policy copies belonging to other surfaces
are out of scope. No code, config, settings, network, credentials, or live-state writes.

**Source inputs used (read at start of run):**
- `data/m27-docs-sweep-20261016/report.md` — **ABSENT** (not found; path does not exist in this worktree)
- `data/m27-docs-remediation.md` — **ABSENT** (not found; path does not exist in this worktree)

No other input files were read. All findings below are derived from direct comparison of
documentation against source code already read in this session.

---

## Severity key

| Level | Meaning |
|-------|---------|
| CRITICAL | Could cause a captain or operator to attempt an action that fails or is silently wrong |
| HIGH | A documented contract is internally inconsistent across two files in this repo |
| MEDIUM | A file references another file that does not exist or whose content contradicts the reference |

---

## Finding 1 — CRITICAL

**File:** `AGENTS.md`
**Line:** 167
**Current claim:** `"claude`, `codex`, `opencode`, `pi`, `pi-signed`, `grok`, `kimi`, `agy`, and `minimax-code` are empirically verified"`
**Should claim:** `"claude`, `codex`, `opencode`, `pi`, `pi-signed`, `grok`, `kimi`, and `agy` are empirically verified" — `minimax-code` is NOT in the canonical verified list.

**Verification:** `bin/fm-harness.sh` line 31 defines `VERIFIED_HARNESSES=(claude codex opencode pi pi-signed grok kimi agy)` — 8 entries, no `minimax-code`. The `minimax-code` string appears in that file only in the ancestry-walk detection layer (lines 96, 109), not in the canonical array. `bin/fm-spawn.sh` lines 686–692 shows `minimax-code` accepted in the case statement, but that is a spawn-entry guard, not a verified-harness declaration. The canonical source is `bin/fm-harness.sh`.

**Status: OPEN** — cannot fix here; requires a code change to either (a) add `minimax-code` to `VERIFIED_HARNESSES` in `bin/fm-harness.sh` if it is genuinely verified, or (b) remove it from `AGENTS.md` line 167 if it is not. **Owner: harness-adapters skill / fm-harness.sh maintainer.**

---

## Finding 2 — HIGH (internal inconsistency)

**File:** `AGENTS.md`
**Line:** 167
**Current claim:** nine harnesses including `minimax-code` are verified.
**Should claim:** matches the bootstrap hardcode fallback (see Finding 3).

**Verification:** `bin/fm-bootstrap.sh` line 736 hardcodes a fallback JSON array with eight names and no `minimax-code`. AGENTS.md and bootstrap disagree. The bootstrap fallback is consulted when `fm-harness.sh verified-json` fails, so it is effectively part of the verified-harness contract.

**Status: OPEN** — same resolution path as Finding 1. **Owner: same.**

---

## Finding 3 — HIGH (internal inconsistency)

**File:** `bin/fm-bootstrap.sh`
**Line:** 736
**Current claim (in hardcoded fallback JSON string):** `["claude","codex","opencode","pi","pi-signed","grok","kimi","agy"]` — 8 entries, no `minimax-code`.
**Should claim:** either 9 entries including `minimax-code` (if it is verified) or the 8-entry list that matches `bin/fm-harness.sh`'s `VERIFIED_HARNESSES` array exactly.

**Verification:** `bin/fm-harness.sh` line 31 is the authoritative source; the bootstrap fallback must mirror it. Currently it does.

**Status: OPEN** — this file is correct as-is IF `minimax-code` is not verified. The issue is AGENTS.md being wrong, not bootstrap. If `minimax-code` is later verified, this line must be updated atomically with `bin/fm-harness.sh`. **Owner: bootstrap maintainer / harness-adapters.**

---

## Finding 4 — MEDIUM

**File:** `README.md`
**Section:** "Recommended harnesses"
**Current claim:** "Claude Code, Grok, and Pi are equal co-primary recommendations" — agy is not listed.
**Should claim:** "Claude Code, Grok, and Pi are equal co-primary recommendations; agy is also supported as a co-primary harness with the same turn-end guard path as Claude Code." (agy is in the canonical verified list and has a Stop-hook turn-end guard, matching the co-primary description.)

**Verification:** `bin/fm-harness.sh` includes `agy` in `VERIFIED_HARNESSES`. `bin/fm-spawn.sh` lines 503–506 show the agy launch template with `--dangerously-skip-permissions` and `--prompt-interactive`. AGENTS.md line 167 includes `agy` as verified. agy has the same Stop-hook turn-end guard as Claude Code (verified, agy 1.3.3 per the comment in `bin/fm-harness.sh` line 81).

**Status: OPEN** — README update is a docs-only change. **Owner: docs owner** (firstmate repo README is tracked material).

---

## Finding 5 — MEDIUM

**File:** `README.md`
**Section:** "Requirements" / "Install and launch" → Pi subsection
**Current claim:** Documents only `pi` and `pi-signed` with no mention of `agy`.
**Should claim:** Include a brief agy launch example: `agy --dangerously-skip-permissions` (matching the launch template in `bin/fm-spawn.sh` line 505).

**Verification:** Same as Finding 4. The README Install section currently covers Claude, Grok, Pi, and pi-signed but omits agy despite agy being a co-primary harness with a verified Stop-hook path.

**Status: OPEN** — docs-only change. **Owner: docs owner.**

---

## Finding 6 — MEDIUM

**File:** `README.md`
**Section:** "Quick Start" → "More backends"
**Current claim:** Links only to tmux, herdr, zellij, Orca, and cmux backend guides.
**Should claim:** Adds a pointer to the agy harness setup if agy requires any setup beyond being on PATH. (If agy requires no special setup, the section may be accurate as-is; this is listed here as OPEN pending verification of whether agy has any setup steps that should be documented.)

**Verification:** No agy setup guide link exists in the docs index. `bin/fm-spawn.sh` shows agy launches from PATH with no extra adapter dependency.

**Status: OPEN** — unclear whether agy setup documentation is needed. **Owner: harness-adapters skill** to determine if a setup doc is required.

---

## Finding 7 — MEDIUM (symlink reference accuracy)

**File:** `CONTRIBUTING.md`
**Line:** 18
**Current claim (verification commands):** `[ "$(readlink CLAUDE.md)" = "AGENTS.md" ]` and `[ "$(readlink .claude/skills)" = "../.agents/skills" ]`
**Should claim:** Both are **correct as written** in the current worktree state. Verified by direct `readlink` of both paths.

**Status: FIXED** — no action needed. This finding is retained for audit completeness.

---

## Finding 8 — LOW

**File:** `docs/README-index.md`
**Section:** "Reference: audits, dated reports — do not use for routine reading"
**Current claim:** The whole section includes a "Not found in this worktree snapshot" trailing paragraph listing `operating-decisions-2026-10-14-15.md` and `verification-discipline.md` as absent.
**Should claim:** This is accurate — those files are absent. However, the paragraph format (a separate trailing block rather than inline per-file markers) makes it easy to miss that specific files are unresolvable. This is a documentation-style observation, not a false claim about current state.

**Status: OPEN (style note)** — not a correctness error. Recommend converting the trailing block to per-file inline markers in the index entries themselves, so absence is visible at the point of reference rather than at the bottom of the file. **Owner: docs owner.**

---

## Unverifiable claims — marked OPEN with responsible owner

| Claim | Why unverifiable locally | Owner who can settle |
|-------|-------------------------|----------------------|
| Whether `minimax-code` is genuinely a verified, shippable harness (AGENTS.md says yes; fm-harness.sh says no) | Requires live test of `minimax-code` on PATH, a brief dispatch, and confirmation of working busy-state, turn-end, and teardown | `fm-harness.sh` / `harness-adapters` maintainer — must either add it to `VERIFIED_HARNESSES` or confirm it is not supported and remove it from AGENTS.md |
| Whether agy requires any non-PATH setup beyond what is documented | No agy setup guide exists; whether one is needed cannot be determined from docs alone | `harness-adapters` skill owner |
| Whether `docs/docs-correction-programme.md` should exist as a tracked document (it is the output of this task; whether it belongs in `docs/` or `data/` is a routing decision) | This is the document being written; its final resting place (tracked `docs/` vs gitignored `data/`) is a policy call | Captain or `firstmate-coding-guidelines` skill |

---

## VERDICT

| Category | Count |
|----------|-------|
| Fixed in this run | 1 (Finding 7 — symlink check is correct) |
| Open, docs-only fix | 4 (Findings 4, 5, 6, 8) |
| Open, requires code+docs coordination | 3 (Findings 1, 2, 3 — all the `minimax-code` / verified-harness list inconsistency) |

**Total actionable items: 7**
**Fixed: 1**
**Open: 6**

### Most dangerous remaining false claim

**AGENTS.md line 167** — declares `minimax-code` a verified harness when it is absent from the canonical `VERIFIED_HARNESSES` array in `bin/fm-harness.sh`.

This is the most dangerous because it is a hard rule in the distro's operating contract that directly governs dispatch authorization. A captain reading this line could attempt to dispatch on `minimax-code` believing it is supported, and the dispatch would either fail silently (if the harness is on PATH but not in the verified list) or behave unexpectedly. The false claim also infects the bootstrap fallback (`bin/fm-bootstrap.sh` line 736), creating an internal inconsistency between AGENTS.md's documented policy and the bootstrap enforcement layer.

**Resolution path:** `bin/fm-harness.sh` line 31 and `bin/fm-bootstrap.sh` line 736 must agree; AGENTS.md must be corrected to match. If `minimax-code` is genuinely verified, add it to the array in both places atomically. If it is not verified, remove it from AGENTS.md and close Findings 1 and 2 as FIXED.
