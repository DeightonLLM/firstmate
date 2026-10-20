# WO-0012 - durably enforce: never mistake one signal for the whole state

**Model:** openai-codex/gpt-6-luna, effort **high**. Worktree: /tmp/wt-wo0012-refactor, branch wo-0012/refactor.

## THE PROBLEM (real, measured, recurring, expensive)
This home repeatedly promoted ONE convenient signal into a verdict about the whole state. Every
occurrence below is a documented, evidenced failure - not a hypothesis.

```
1. tmux `ls` empty      -> 17 workers were live (Herdr is the surface)
2. a note file existed  -> it was never transmitted (39 notes actually undelivered)
3. branch had N commits -> none landed (merge-base --is-ancestor said NO)
4. pane idle            -> worker had finished (status file + pane disagreed)
5. wake annotations     -> the raw rows were authoritative
6. 27 slot dirs         -> the 40 ceiling was never established; reported "13 free" anyway
7. 18 commits landed    -> not 18 features
8. `done:` status line  -> report file did not exist
9. backlog row existed  -> six rows implied work that never happened
10. backlog label       -> a label, not progress
11. .meta file exists   -> 17 stale metas, ZERO live tasks, board said "Under Way"
12. HTTP 200            -> a parked Hostinger page (whooshperformance.com)
13. pane status "working" -> worker had been dead 9 minutes on the bash allowlist
14. secret scan "passed" -> 419 candidates flagged elsewhere
```

## Your job
Turn this into an ENFORCED mechanism, not a document nobody reads.

### Required
1. **`bin/fm-second-signal.sh`** - given a claim about fleet/project state, require and check a
   SECOND, INDEPENDENT signal. Refuse to return CONFIRMED without one. Returns UNVERIFIED when no
   second signal exists. Never guesses.
2. **A concrete table of signal pairs** for the cases above, derived from the real code paths -
   e.g. "meta file + endpoint probe", "branch + merge-base --is-ancestor", "site + page title/body,
   never status alone", "status line + report file".
3. **Wire it into the check scripts that currently lie**: `fm-fleet-view.sh`,
   `fm-crew-visibility.sh`, and `controller-pending.check.sh`. A check must be silent unless its
   claim survives a second signal.
4. **A regression test** proving each of the 14 cases above would now be caught. At minimum, prove
   cases 11, 12 and 13 fail before your change and pass after - those are the ones that bit hardest.

### Constraints
- Extend existing code. No second source of truth, no parallel system.
- Do not weaken any existing guard. Fail closed.
- RED then GREEN: the test must fail on today's code and pass after. Show both runs.
- Report the FULL suite counts honestly. Known baseline is roughly 41 failures of 143 - do not make
  it worse and do not pretend it is better.
- `bash <script>` RUNS; `bash -c` and `python3 -c` are BLOCKED. Use script paths.

## Documentation (Captain asked for this explicitly)
**`docs/verification-discipline.md`** - rewrite it so it is short, specific and enforceable, and
point at the enforcing script rather than restating the rule. Include the paired-signal table and the
recovery condition for each. It must be usable by someone who was not here tonight.

## Rules
- Work ONLY in /tmp/wt-wo0012-refactor. Commit on branch wo-0012/refactor.
- **No merge, no push, no rebase of main.** The Captain owns merges.
- Never touch srv1137994 / elevatesVPS / Aminolifesciences.

## Report
data/wo-0012-refactor/report.md with RED output, GREEN output, full-suite counts, and one line
stating which of the 14 cases are now mechanically caught.
