# `docs/` index write-up — 2026-10-15

## Result

Created `docs/README-index.md` as an audience- and urgency-oriented guide, with one concise purpose statement per listed document. It puts harness-specific supervision, watcher continuity, and itself in the every-session group; dispatch/blocker material in the conditional group; and audits, studies, incident records, examples, and warehouse evidence in reference groups. The index marks the three YAML mirrors as generated based on their own file headers, labels dated backups as backups, and points readers to current owner documents rather than treating historical evidence as operating instructions.

The initial inventory was `ls -la docs` (120 files before adding the index) and `find docs -type f | sort`. I inspected the opening/header of each existing docs file before describing it. A local-link check after drafting found and corrected a bad warehouse README link; the final validation found all local targets present, and a path-set comparison confirmed all 120 preexisting docs files are indexed. `git status --short` showed only `?? docs/README-index.md` in the worktree. I did not edit `docs/README.md`.

## Findings, exclusions, and stale material

- `docs/README.md` begins `# HD2 Agent Warehouse Contract` and defines the GitHub-backed warehouse projection (lines 1–6). It is not a navigation index; it is linked and explicitly distinguished in the new index.
- The inventory contains `docs/wake-drain-loop.md` (its header says the owning protocol is `docs/supervision-protocols/pi.md`, lines 1–4), but does **not** contain `docs/operating-decisions-2026-10-14-15.md` or `docs/verification-discipline.md`. I excluded those two from links because they are absent from this worktree snapshot; I did not infer their content. The user-provided names are the evidence for the expected names, not evidence that the files exist here.
- No extant docs file was excluded from the index. The four `.bak-*` warehouse YAML files are indexed only as dated backups, not represented as active source-of-truth files. The active `hosts.yaml`, `service_catalog.yaml`, and `prd_traceability.yaml` headers each call them generated mirrors and identify their corresponding Markdown authority.
- I treated dated operational claims as stale for decision-making until rechecked, rather than silently presenting them as current. In particular, `FLEET-STATUS-20261012.md` (lines 1–8) is a dated fleet snapshot; `HANDOFF-20261012.md` (lines 1–17) and `ZCODE-HANDOFF-20261012.md` (lines 1–18) are dated handoffs; and `ZCODE-PROMPT-20261012.md` (lines 1–18) is explicitly a historical prompt. The handoff says `minimax-code` cannot yet be dispatched (HANDOFF lines 14–17), while current `AGENTS.md` section 4 lists `minimax-code` among verified harnesses; do not use the old assertion as current.
- The active warehouse YAML mirrors expose old verification dates in their headers: `hosts.yaml` and `service_catalog.yaml` say `last_verified: 2026-09-15`; `prd_traceability.yaml` says `2026-09-19`. `system-context/SCHEMA.md` lines 1–11 says stale records are rejected beyond the freshness window, but I did not run the warehouse preflight or claim a specific pass/fail. Revalidate these records before relying on their currentness. The AnythingLLM projection manifest says `last_verified: 2026-09-23` (header lines 1–4), also a dated snapshot.
- `system-context/PRD_TRACEABILITY.md` lines 7–10 names a 2026-09-14 delivery map as its status summary. The evidence corpus also contains reconstructed Gate-CBD documents: their headers explicitly disclose reconstruction from retained `status.txt` on 2026-10-11 and missing original checker/TDD output. The index preserves those provenance limits in the descriptions rather than presenting reconstructed material as original contemporaneous evidence.
- Other clearly dated historical records (for example the 2026-09-28 audit set and 2026-10-03–05 knowledge notes) are categorized as reference. I did not assert those are substantively wrong; their findings need current evidence before operational use.

There is no independent decision requiring a captain choice in this report; recommendations are to add a cross-reference and revalidate dated claims.

## Recommendation for `docs/README.md`

Leave the warehouse contract intact. Add a short sentence near its opening, e.g. “For a navigation guide to the repository’s `docs/` material, see [`README-index.md`](README-index.md).” That would make the new index discoverable without replacing or changing the contract’s warehouse purpose. I did not make this suggested edit.

## Evidence and validation

- `ls -la docs` — confirmed the root contents, including `README.md`, the backends and guards, and `wake-drain-loop.md`.
- `find docs -type f | sort` — inventoried nested material, including audits, examples, verification records, protocols, warehouse evidence, and backups; the two named missing files were not in the output.
- Openings read with `ctx_read` across the inventory. Examples: `docs/README.md:1-6` establishes warehouse-contract purpose; `docs/supervision-protocols/pi.md:1-13` establishes the Pi drain contract; `docs/wake-drain-loop.md:1-4` names its owning protocol; `docs/system-context/hosts.yaml:1-5`, `service_catalog.yaml:1-4`, and `prd_traceability.yaml:1-4` identify generated mirrors; `docs/system-context/evidence/BR-CBD-LANE-B-20260918-GATE003-MUTATION-20260918/evidence.md:1-8` discloses reconstruction and provenance.
- Local-link validation script — `PASS`, no missing local targets. A set comparison found 120 indexed preexisting docs files and no omitted extant file.
- `git status --short` — only the new `docs/README-index.md` was present as an untracked worktree change at validation time.
