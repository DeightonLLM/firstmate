# Q2 executed: the validator now accepts the lanes we actually dispatch
Correlation: hd2-standing-queue-q2

VERDICT: PASS — defect reproduced before the change, fixed, covered by two new tests, all 5 suites green, registry corrected, committed 55ff9b5c and pushed fast-forward.

## Defect reproduced first, not assumed

```
$ bash bin/fm-lane-naming-check.sh "m2.7h-brandon-land-factory-work"
invalid lane key or board line: m2.7h-brandon-land-factory-work
exit 1
```

So the report was accurate: the guard rejected every lane key we had actually dispatched. Worth being blunt about what that means — the naming enforcement I merged and reported as working was rejecting 100% of real traffic. It passed its own tests because those tests only asserted the aliases its own list contained. A validator that validates its own assumptions is worse than no validator, because it reports PASS.

## Diff

| File | Change |
|---|---|
| `bin/fm-lane-naming-check.sh` | `_model_pat` gains `m2\.7h` ahead of `m2\.7`; both header comment blocks list `m2.7h (MiniMax M2.7 Highspeed)` |
| `AGENT-TODO-PROMPT-STYLE.md` | canonical alias list gains `m2.7h`, plus a sentence defining it as the Highspeed tier with the same `h`/`f` suffix logic as `m3.1f`, and stating that a key reading `m2.7` for a live worker is wrong rather than merely imprecise |
| `tests/fm-lane-naming-check.test.sh` | new `test_lane_key_valid_m2_7h` and `test_board_line_valid_m2_7h`, both wired into the runner |
| `docs/comms-and-lane-naming-contract.md` | alias list corrected — I found this on my own while executing; your order named three files and this fourth one would have kept contradicting the other three |
| `data/async-lanes.tsv` | 8 rows corrected: lane_key segment and model column now `m2.7h` |

## Test output

```
$ bash bin/fm-lane-naming-check.sh "m2.7h-brandon-land-factory-work"
exit 0        (was 1)

$ bash bin/fm-lane-naming-check.sh data/async-lanes.tsv
exit 0        8 rows corrected before this run

PASS  tests/fm-lane-naming-check.test.sh        33 assertions  (was 30; +3 new)
PASS  tests/fm-reap-records-check.test.sh       25 assertions
PASS  tests/fm-client-infra-isolation-check.test.sh  12 assertions
PASS  tests/fm-dead-pane-sweep.test.sh          31 assertions
PASS  tests/fm-teardown-archive.test.sh          6 assertions
```

shellcheck on the changed script reports one pre-existing SC2086 info at line 85 (`set -- $key`,
intentional word splitting), which was present before this change and is not part of Q2.

## Commit and push

```
commit  55ff9b5c  fix(naming): add m2.7h model alias for M2.7-highspeed workers
push    e0a98337..55ff9b5c  main -> main
method  ordinary fast-forward; fetched first, behind 0 ahead 1, merge-base confirmed ancestor
client data  zero matches
```

## Two things I am not claiming

The new tests cover the alias I added. They do not independently prove the alias list now matches what future dispatches will use — the same class of gap that caused this defect. The durable protection against a repeat is a test that cross-checks the alias set against the configured dispatch models in `config/crew-dispatch.json`, and that does not exist yet. Recommend it as the follow-up, because otherwise the next model change reintroduces exactly this.

Also unverified by me beyond the suite: that no already-merged consumer depends on `m2.7` being rejected. Adding an alias is permissive, so I judged the risk low rather than measured it.

Ready for the independent review you dispatch.

VERDICT: PASS — Q2 executed end to end; defect reproduced, fixed in four files plus a fifth found during execution, covered by 3 new assertions, 5/5 suites green, 8 registry rows corrected, 55ff9b5c pushed fast-forward; follow-up recommended to bind the alias set to configured dispatch models so this cannot recur.