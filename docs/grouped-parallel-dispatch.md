# Grouped parallel dispatch - the required working pattern

Captain directive 2026-10-16. Recurring, enforced. Source of truth for how work leaves this home.

## The rule

Group, record once, dispatch in parallel. Never one at a time.

## Why

The Captain works by domain, not by item. A backlog of 29 unrelated items is not 29 decisions, it
is roughly three dispatches plus whatever has no owner. Working items serially wastes the fleet and
stalls domains that could have run concurrently.

## Procedure

1. **Group** the entire open to-do list against registered secondmate scopes in
   `data/secondmates.md`. Scope ownership decides the destination, never availability.
2. **One task** on the to-do list represents the whole grouped dispatch. Not one task per item.
3. **Dispatch in parallel** - every ready domain goes out in the same action.
4. **Update that single task** at each phase change: grouped, dispatched, landed, blocked.
5. Items fitting no scope stay with the primary firstmate, and the grouping records why.
6. A domain with nothing open stays idle. Idle is the healthy default, never an excuse for filler.

## Prohibited

- Serial dispatch of independently scoped work
- Leaving authorized ready work idle because another lane is still running
- One to-do task per grouped item
- Selecting a lane because it is free rather than because it owns the scope
- Inventing work to keep an idle domain busy

## Evidence of the pattern working

- 2026-10-16: 29 open items grouped into core-ops 3, system-ops 9, primary 5, idle 5.
  Recorded as single to-do task #41 and dispatched in parallel.

## Related standing rules

- Output discipline: an empty-queue drain produces silence, not a status line
- To-Do list gate: 5+ dependency-aware items, one in progress, updated at every phase change
- Decision gate: installs, commits, kills, restarts and config writes need one named line and the
  Captain's word first

## Reference

- Grouping artifact: `data/2026-10-15/todo-grouping-20261016.md`
- Scope registry: `data/secondmates.md`
- Standing rules: `data/captain.md`