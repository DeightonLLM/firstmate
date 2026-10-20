# Child-tool readiness: visible dependency-aware tracker

Date: 2026-10-13. Correction to the prior provider-absence conclusion: the package is present and exact source reads confirm its contract; the earlier empty listing was not absence evidence. This private readiness/config record is for retained `reliability-work-ledger-20261012`, separate from Controller's source/update/permission/landing handoff. Primary applied and validated a scoped scout-only config override; the one released native async tracker-only proof completed. This lead made no config/plugin/installation/permission/backlog/fleet changes. No source investigation or denied-helper retry is authorized.

## Finding: precise capability mismatch

The prior child failure is explained by two independent facts:

1. **The parent tracker is a host tool, not automatically a Pi child tool.** The primary's pre-change `scout` allowlist omitted `todo`; the released scoped override added it. The completed child's session transcript records `todo` in `toolsAdded`, proving the provider/tool was actually registered in that child. Child tools come from the pi-subagents agent contract and loaded extension, not inheritance of the parent API namespace.
2. **The provider is installed and the scoped child configuration was applied.** Exact read of `/home/hd2admin/.pi/agent/npm/node_modules/@juicesharp/rpiv-todo/package.json` identifies version `2.12.0`, with `pi.extensions: ["./index.ts"]`. Exact reads of `index.ts`, `todo.ts`, `state/task-graph.ts`, `state/state-reducer.ts`, `tool/types.ts`, `tool/response-envelope.ts`, `state/store.ts`, and `todo-overlay.ts` establish the `blockedBy` graph, cycle checks, per-session state and textual tool responses. Primary's release records the array-valued `scout` allowlist and `subagentOnlyExtensions` path; the actual child registry confirms load.

The earlier child result `.../outputs/948283ff-3ebf-4654-a370-4ce1fc3ed8bc/core-elevate-decision-evidence.md` remains a tracker-capability failure and contains no Core/Elevate evidence. The later released proof used a distinct single run and inspected no source files.

## Minimal supported configuration - primary-applied scoped override

Current pi-subagents docs support per-agent `subagentOnlyExtensions` and a strict tool allowlist. The exact installed provider is `/home/hd2admin/.pi/agent/npm/node_modules/@juicesharp/rpiv-todo/index.ts`. Primary reports applying this minimal override under `/home/hd2admin/.pi/agent/settings.json` → `subagents.agentOverrides.scout`, preserving the existing reviewer override:

```json
{
  "subagents": {
    "agentOverrides": {
      "scout": {
        "tools": [
          "read",
          "grep",
          "find",
          "ls",
          "bash",
          "write",
          "contact_supervisor",
          "todo"
        ],
        "subagentOnlyExtensions": ["/home/hd2admin/.pi/agent/npm/node_modules/@juicesharp/rpiv-todo/index.ts"]
      }
    }
  }
}
```

This was applied as a merge into `/home/hd2admin/.pi/agent/settings.json` under `subagents.agentOverrides.scout`, preserving the existing `reviewer` override. It is a private per-agent override, not a per-call `tools` field or a global default extension change. `subagentOnlyExtensions` loads the provider only for child sessions of that agent; adding `todo` to `tools` allowlists the registered name but does not load its provider. Both pieces are required. Keep all existing scout capabilities; add only the tool name and provider path.

**Runtime tracker proof completed; no source work was performed.** The actual child session's `toolsAdded` includes `todo`; its transcript contains only `todo` operations and one managed-artifact `write`. Textual list/get tool results displayed statuses and dependency edges in the noninteractive child transcript. The live TUI overlay is not claimed. This proves the tool loaded and the tested dependency/cycle behavior, not completion of the original reliability scout.

## Supported mechanism and acceptance evidence

Current pi-subagents docs (`~/.pi/agent/npm/node_modules/pi-subagents/docs/agents.md`, frontmatter around lines 403-447 and Tool and extension selection around lines 520-580; `docs/models.md` Extension defaults around lines 142-170) establish:

- `tools` is a strict child-tool allowlist; an allowlisted extension tool does not load its provider.
- `subagentOnlyExtensions` loads a provider in that agent's child sessions only.
- `agentOverrides.<name>.subagentOnlyExtensions` is supported; it must point to an existing extension path.
- The package manifest's `./index.ts` registers `todo`; the exact `todo.ts` tool schema includes `create/update/list/get/delete/clear`, four task statuses, `blockedBy`, `addBlockedBy`, and `removeBlockedBy`.
- `state-reducer.ts` checks dangling/deleted dependencies and graph cycles; `task-graph.ts` derives inverse `blocks` edges.
- `response-envelope.ts` returns text for tool results: `list` renders each status and `⛓` dependency; `get` renders both `blockedBy` and `blocks`. `index.ts` registers the tool independent of UI, while its overlay path requires UI context. Thus noninteractive textual tracker evidence is supported; live TUI widget display is not established for a headless child.
- The runtime checks explicit tool names against the final filtered registry before the first model turn; a missing provider should reject launch with concrete extension guidance. A successful agent listing/config display is not proof that a child actually loaded the provider.

## Actual released proof - one attempt

Fresh intake at 2026-10-13 18:51:38Z: `quota-axi --json` reported MiniMax general effective availability 93%, fresh/through-reset; the Pi registry listed exact `minimax/MiniMax-M2.7-highspeed` and regular `minimax/MiniMax-M2.7`; `subagent get scout` returned the applied array-valued tool allowlist plus the exact child-only extension path. The selected exact model was `minimax/MiniMax-M2.7-highspeed:medium` (>50% policy). One native async run was launched: `47684d72-d504-4268-a896-5e71f8481a7a`.

- Managed output: `/home/hd2admin/.pi/agent/sessions/--home-hd2admin-.treehouse-kun-agent-workspace-46aafc-12-kun-agent-workspace--/subagent-artifacts/outputs/47684d72-d504-4268-a896-5e71f8481a7a/tracker-only-proof.md` (9.6 KB, 349 lines).
- Actual child transcript: `/home/hd2admin/.pi/agent/sessions/--home-hd2admin-.treehouse-kun-agent-workspace-46aafc-12-kun-agent-workspace--/2026-10-12T19-35-23-619Z_01a1319c-d2e2-7327-aaba-5645e7af909a/eb1653ed-fbfb-4ff5-a715-5d098a18c9ad/run-0/session.jsonl`. Its session header records `provider=minimax`, `modelId=MiniMax-M2.7-highspeed`, `thinkingLevel=medium`, and `toolsAdded` includes `todo`. The only child tool names called are `todo` and the managed-output `write`; no read/grep/find/ls/bash/source access occurred.
- Actual tracker: five tasks #1-#5. `blockedBy` edges were #2→#1, #3→#2, #4→#3, #5→#4. List/get results displayed both `blockedBy` and inverse `blocks`.
- Cycle test: update task #1 with `addBlockedBy:[2]` while #2 already had `blockedBy:[1]`. Exact tool content was `Error: addBlockedBy would create a cycle in the blockedBy graph`; result details carried the same error and the unchanged task snapshot. Post-rejection list/get confirmed #1 still had no `blockedBy` and `blocks:#2`, while #2 still had only `blockedBy:#1` and `blocks:#3`. This was the expected negative result, not a runtime failure.
- Actual transcript contains 27 `todo` calls: five creates, twelve updates (four dependency updates and eight status/cycle updates, including one rejected cycle update), three lists, and seven gets. The managed artifact's acceptance summary says `todo get (6 times)`; the transcript shows seven get calls, so this report uses transcript count. Artifact and transcript agree on the exact cycle error and graph preservation.
- Status flow: #1 and #2 were each moved pending→in_progress→completed. #3-#5 remained pending during evidence collection and were then changed directly pending→completed; they were not individually marked in_progress before their work. Thus the proof demonstrates provider loading, dependency creation/list/get, cycle rejection and graph integrity, but does not prove every phase item followed a per-item start-before-work discipline. Exactly one item was in_progress at a time; final list showed all five completed.
- Noninteractive visibility is proved only as textual tool results/transcript output. The live interactive overlay and TUI widget are not claimed.

No second attempt, source investigation, CLI fallback or original scout completion was made. The one authorized child run is complete; remaining unproven cases include long cycles, concurrent updates, self-reference, removal semantics and individual start-before-work discipline for tasks #3-#5.

## Rollback and authority

No rollback was performed. Primary owns rollback if the one proof fails: restore only the `scout` override to the pre-change value after checking current content, and verify `subagent get scout`; never replace the full settings file from backup or change package/global extension state. Do not uninstall packages, edit extension source, change permissions, or retry prior denied commands.

## Evidence checked

- Primary release `scout-tracker-proof-release.md`: records the actual `subagent get scout` result with array-valued tools and exact child-only extension path, plus before/after settings snapshots and scoped validator output; no child load evidence is claimed from those config artifacts.
- `subagent({action:"list", options:{capabilities:true}})`: scout remains builtin; confirms declared tool ceiling, not actual per-run extension loading.
- `~/.pi/agent/settings.json`: package declaration is `npm:@juicesharp/rpiv-todo@2.12.0`; the primary release adds only the scoped `scout` override.
- Post-change `subagent get scout` (as recorded in the primary release): the effective tools array includes `todo` and `Subagent-only extensions` names the package's `index.ts`.
- Although `ctx_ls`/`ctx_find` did not enumerate package files, the exact manifest and module reads named above succeeded; those exact reads supersede the empty listing as package-presence evidence.
- Read current pi-subagents `agents.md`/`models.md` and Pi `docs/extensions.md`, `docs/packages.md`, `docs/configuration.md`, and `docs/settings.md`. They establish the supported per-agent child-only extension path and that an explicit tools allowlist must include the registered extension tool.
- The released proof was launched once as async Pi scout run `47684d72-d504-4268-a896-5e71f8481a7a` using `minimax/MiniMax-M2.7-highspeed:medium` after fresh quota/catalog/get checks. The child used only `todo` tool calls plus its managed artifact write; this lead did not modify config, run package commands, install, test, edit plugins, or inspect source in the child.

## Decision / next owner

The scoped config correction is applied by primary and the single released tracker-only proof confirms actual `todo` registration and textual dependency/cycle behavior in the child. This does not complete the original reliability scout: no source investigation occurred, and the proof does not establish interactive overlay display, longer/concurrent graph cases, or that every task phase was individually started before work. Keep the original completion gate open; no additional child attempt or config rollback is authorized or required by this proof.
