# Agent To-Do prompt style — standing requirement

Status: ACTIVE. Applies to every dispatched lane and worker agent, on every surface.

## Lane naming — the Captain's only window into async work

Every dispatched lane key MUST be `<model>-<surface>-<task>`, lowercase, no spaces.

The async panel renders the lane key and nothing else. An opaque key like `hd2-comms`
leaves the Captain unable to tell model, surface or purpose without asking. That is a defect.

```
m3.1f-dubz-hd2comms      MiniMax M3.1 Flash on the Controller, repairing HD2 comms
glm5.3f-dubz-checker     GLM 5.3 Flash on the Controller, independent checking
gem38f-hd2-masterlist    Gemini 3.8 Flash on HD2, master task list
m3.1-brandon-wo0011      MiniMax M3.1 on Brandon, WO-0011
```

Model aliases: `m3.1f`, `m2.7`, `luna6`, `glm5.3f`, `gem38f`, `pi`.
Surface aliases: `dubz`, `hd2`, `brandon`, `evps`, `firstmate`.
Add a pane suffix only when the Captain must find or guide a live lane: `gem38f-hd2-wk-p2`.

Enforced on the To-Do board in the same format: `[<model> @ <surface>[/<pane>}] <action> — <state>`.
Update the board at every phase change. A board showing "running" for a finished lane is a defect.

## Required To-Do format

Every non-trivial worker creates a native To-Do list through the harness To-Do extension, before its first task action. Filesystem TODO trackers are forbidden.

## Required prefix

Every To-Do item begins with the Captain-locked prefix:

    [<harness>·<ModelAbbrev> <effort> @<Host>]

- `<harness>` — the agent harness, for example `pi`, `agy`, `codex`, `claude`.
- `<ModelAbbrev>` — short model name, for example `Luna6`, `G38F`, `M31`.
- `<effort>` — one of `h`, `m`, `l`, `xh`, `x`, using bare codes.
- `@Host` — identifies where the agent RUNS, not what it works on.

Worked example:

    [agy·G38F m @HD2] Test-first bounded implementation

## Required structure

- At least five visible items.
- A real dependency chain expressed in the item text, for example `(depends on t2, prerequisite for t4)`.
- Exactly one item `in_progress` at any moment.
- Preflight, scoped discovery, bounded work with evidence, validation, and postflight/closeout must all be represented.

## Compliance evidence

Acceptance requires the coordinator to see the worker's visible To-Do state, not merely a claim that one exists. A lane that reports completion without a compliant visible list is not accepted.

## Enforcement

This is not a preference. It is the same requirement expressed by the task brief scaffold, and it is enforced by the acceptance gate: a worker whose To-Do is missing, has fewer than five items, is prose-only, or substitutes a filesystem tracker fails verification regardless of the quality of its output.

Confirmed working in practice: the Gemini direct-notify worker on HD2 produced a compliant five-item list with the correct prefix and a `t1 → t2 → t3 → t4 → t5` dependency chain without being re-prompted.