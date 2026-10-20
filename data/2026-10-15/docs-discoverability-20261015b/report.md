# Docs discoverability scout — 2026-10-15

## Outcome

Created [`docs/README-index.md`](../../.treehouse/kun-agent-workspace-46aafc/21/kun-agent-workspace/docs/README-index.md), a separate reading guide grouped by session urgency, dispatch/blocker use, maintained references, dated historical records, and system-context archives.

The existing `docs/README.md` was left completely untouched. Its first lines identify it as the “HD2 Agent Warehouse Contract,” defining the warehouse's purpose and topology (`docs/README.md:1-10`); adding a cross-reference was not necessary to preserve its meaning, and the captain explicitly directed preservation. No other existing documentation was edited.

## Inventory and evidence

Commands run:

- `ls -la docs` — confirmed an existing `docs/README.md` and nested directories.
- `find docs -maxdepth 1 -type f -printf '%f\\n' | sort` — enumerated the root documentation files.
- `find docs -type f -printf '%p\\n' | sort` — enumerated nested supervision protocols, audits, verification records, examples, knowledge notes, and system-context evidence.
- `git status --short --branch` — clean detached worktree before writing.

Header/leading-content reads relevant to index placement:

- `docs/supervision-protocols/pi.md:1-18` — Pi's current protocol; step 1 says drain the wake queue and explicitly disallows looping until empty.
- `docs/supervision-protocols/claude.md:1-12`, `codex.md:1-12`, `grok.md:1-12`, `opencode.md:1-12`, `minimax-code.md:1-12`, and `unknown.md:1-12` — each identifies its harness-specific supervision procedure or fallback.
- `docs/watcher-continuity.md:1-9` — describes one-shot watcher ownership and automatic continuation.
- `docs/wake-drain-loop.md:1-5, 8-14` — dated 2026-10-15; says the Pi protocol step 1 owns the procedure and this document provides rationale/evidence.
- `docs/README.md:1-10` — existing warehouse contract, so it is not the index.
- `docs/configuration.md:1-10`, `docs/decision-hold-lifecycle.md:1-9`, and `docs/subagent-guard.md:1-7` — respectively establish configuration ownership, decision-hold mechanism, and delegation guard purpose.
- `docs/herdr-backend.md:1-6`, `tmux-backend.md:1-4`, `orca-backend.md:1-5`, `cmux-backend.md:1-5`, and `zellij-backend.md:1-5` — establish each backend's status and configuration ownership.
- `docs/calm.md:1-5` and `calm-mode-feasibility.md:1-5` — distinguish current Calm usage from version-scoped feasibility evidence.
- `docs/documentation-audiences.md:1-5` — identifies `documentation-audiences.json` as the machine-consumed classification owner.
- `docs/fm-test-isolation-proof.md:1-5` names `fm-test-isolation-proof.json` as machine-readable output; the JSON begins with a completed isolation-proof record (`fm-test-isolation-proof.json:1-8`).
- `docs/verification/supervision.md:1-7`, `runtime-backends.md:1-7`, and `dispatch-auth.md:1-9` identify those records as maintainer verification, not operator setup guides.
- `docs/anythingllm/README.md:1-10` identifies its directory as a sanitized projection map; `docs/system-context/INDEX.md:1-11` identifies itself as the entry point/order contract for that warehouse.
- `docs/FLEET-STATUS-20261012.md:1-8`, `HANDOFF-20261012.md:1-5`, `ZCODE-HANDOFF-20261012.md:1-10`, and `ZCODE-PROMPT-20261012.md:1-7` are dated, session-specific fleet/harness handoffs.
- `docs/COMPUTE-DISTRIBUTION-STUDY-20260928.md:1-5`, `CORE-DISTRO-SSL-OUTAGE-20260928.md:1-5`, `DEEPSEEK-HARNESS-INSTALL-20260928.md:1-7`, and `STALE-CLAIM-GUARD-R2-20260928.md:1-6` identify dated study, incident, installation, and verification records.

The listed paths `docs/operating-decisions-2026-10-14-15.md` and `docs/verification-discipline.md` were absent from the recursive inventory. `docs/wake-drain-loop.md` was present. Thus the brief's “Two landed tonight” sentence is inconsistent with its three named paths; inventory found only one of those three.

## What the index includes and leaves out

The index links routine session supervision references first, puts backend/configuration and blocker-facing references next, and segregates maintainer evidence and dated incident/handoff material as reference-only. It links nested archive directories and their established entry points instead of turning every task-specific evidence file, example, or machine-readable artifact into routine reading.

It marks the isolation-proof JSON as generated test evidence and audience JSON as machine-consumed classification data; the index does not assert that every data file has an authored/generated header. No generated document was edited.

## Staleness flags

These inspected titles/headers are point-in-time or explicitly dated and should not be mistaken for current session guidance:

- `docs/FLEET-STATUS-20261012.md`, `docs/HANDOFF-20261012.md`, `docs/ZCODE-HANDOFF-20261012.md`, and `docs/ZCODE-PROMPT-20261012.md` are dated 2026-10-12 session records.
- `docs/COMPUTE-DISTRIBUTION-STUDY-20260928.md`, `docs/CORE-DISTRO-SSL-OUTAGE-20260928.md`, `docs/DEEPSEEK-HARNESS-INSTALL-20260928.md`, and `docs/STALE-CLAIM-GUARD-R2-20260928.md` are dated 2026-09-28 reports/studies.
- `docs/wake-drain-loop.md` is current-dated 2026-10-15 but explicitly defers procedure ownership to `docs/supervision-protocols/pi.md`; its title could otherwise suggest it is the operating procedure.
- The two absent named 2026-10-14/15 docs cannot be assessed for staleness from this inventory.

No existing documentation was changed. No branch, commit, or push was made. The required no-decisions attestation was attempted with `FM_HOME=/home/hd2admin/kun-agent-workspace bin/fm-decision-hold.sh complete docs-discoverability-20261015b --none` and failed with exit code 1: `fm-decision-hold: open structured decision docs-discoverability-20261015b/default has no captain-held inventory entry`. Per instruction, I did not retry or work around this error; the shared completion gate remains unverified.
