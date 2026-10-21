# TODO Prefix Enforcement Evidence

## What this is
Durable evidence of the mechanical To-Do prefix enforcement implementation per
Captain-locked format (bin/fm-brief.sh line 237):
  Each item must begin at the far left with
  [<harness>·<ModelAbbrev> <effort> @<Host>],
  before any state verb or task text.
  Use bare effort codes h, m, l, xh, or x.

## Before
- Prose rule only: TODO_PREFIX_REQUIREMENT defined in bin/fm-brief.sh line 237
  but no script mechanically validated a worker's actual To-Do list items.
- Backlog item todo-naming-enforcement-20261013 (data/backlog.md line 161) had
  drifted text using "think:<level>" instead of bare effort codes.
- Fleet rule: prose rules are documentation ONLY unless a deterministic hook enforces them.

## After
- bin/fm-todo-prefix-check.sh: standalone script that fails closed on non-compliant
  items, accepts compliant items, tolerates empty lists, never rewrites files.
  Uses the authoritative regex from tests/fm-brief.test.sh validate_todo_item_prefix().
- Wired into fm-spawn.sh line 935+ (brief acceptance path, smallest existing seam):
  runs after brief existence check, before worker launches. Non-compliant brief =
  spawn refused.
- Backlog item corrected to bare effort codes (h/m/l/xh/x), matching authoritative format.

## RED/GREEN Evidence
- RED: Non-compliant items (think:h, missing effort, wrong effort 'q', bogus harness,
  unknown model) all cause exit 1.
- GREEN: Compliant items (all 8 harness·ModelAbbrev combos, all 5 effort codes,
  all 3 hosts, mixed file) all cause exit 0.
- Empty and comment-only lists tolerated (exit 0).

## Test Coverage
- Existing tests/fm-brief.test.sh: 24/24 tests preserved, no weakening.
- New tests in tests/fm-todo-prefix-check.test.sh (TDD RED/GREEN cycle completed).
