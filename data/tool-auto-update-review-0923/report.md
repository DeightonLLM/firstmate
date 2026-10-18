# Review: Pi update on load

## Scope and method

Reviewed commit `dac9e8e8e547fcd3c84a696a491119bbb5a78cfd` (`feat(pi-ext): on-load Pi self+extension update check in session_start`) statically. Read the changed Pi primary extension, the Pi install and live-worker paths, Pi launch substitution in `fm-spawn.sh`, the watched-tool configuration docs, and searched the tests for direct on-load coverage. No files in the project worktree were changed; no tests or update commands were run. The checkout itself was at `2e61f527941216c6275a3d41995d3324856bf355`, so source inspection used `git show <target>:<path>`.

Commands: `git status --short --branch`; `git rev-parse HEAD`; `git show --stat ...`; `git show ... -- <changed paths>`; `git grep -n ... <target>`; and targeted `git show ...:<path> | nl -ba | sed -n ...` for line references. Test review was search-only, including `tests/fm-pi-primary-live-e2e.test.sh`, `tests/fm-session-start.test.sh`, `tests/fm-turnend-guard.test.sh`, and `tests/fm-pi-primary-types.test.sh`.

## Findings

### Medium: session-start live gate can count the Pi session that is invoking the update

`.pi/extensions/fm-primary-turnend-guard.ts:151-164,199-219` calls `fm-tool-live.sh pi` and only proceeds on exit 0. In the detector, `bin/fm-tool-live.sh:182-209` returns exit 1 whenever the Herdr snapshot contains any Pi pane, without distinguishing the current pane from other workers. Since this hook runs from Pi's `session_start`, if Herdr has already published the starting session in its snapshot, the gate rejects the update and reports that workers are present. The comment promises safety when “no other” Pi workers are active, but the gate's pane branch is an any-Pi-pane check. This may make the on-load path ineffective in precisely the normal Herdr-backed case; runtime timing of pane publication was not verified.

Recommendation: explicitly exclude the current session/pane from the gate or use this startup path only when the caller can prove it is outside the live-worker inventory. Preserve the existing fail-closed behavior for other Pi sessions.

### Medium: timeout timers are not cleared after child completion

The on-load gate schedules a TERM at 15 seconds (`.pi/extensions/fm-primary-turnend-guard.ts:160-163`). The self-update and extension-update children each schedule a TERM at 60 seconds (`:189-195`). None of these timers is cleared when the child closes or errors. A quick completion therefore leaves a delayed signal targeting the old PID; if the OS reuses that PID before the timer fires, it can terminate an unrelated process. The timers also do not escalate to KILL or report that the child was terminated, unlike the scheduled install's bounded runner (`bin/fm-tool-install.sh:176-185,384-402`).

Recommendation: clear each timer on close/error, and make timeout outcomes explicit. Consider process-group termination if the child can create descendants.

### Low: scheduled and on-load paths have no shared in-progress claim

`runOnLoadUpdate` only consults a recent `installed` record (`.pi/extensions/fm-primary-turnend-guard.ts:138-149,199-205`), then runs the gate and installer directly (`:221-235`). The scheduled orchestrator separately chooses a detected candidate and runs the same Pi update sequence (`bin/fm-tool-install.sh:243-269,466-529,582-596`). An on-load run does not write an install record, while the scheduled record is written only after installation (`:410-434`); therefore a watcher poll racing session startup can pass its own gate and launch a second installer. This is a narrow race, but duplicate package mutations are not idempotence guaranteed by the code shown.

Recommendation: use one atomic per-tool in-progress claim shared by both paths, or route on-load work through the existing orchestrator and its outcome recording.

## Other requested checks

- **Ordering:** on `session_start`, the nudge is synchronously generated and sent first, then `runOnLoadUpdate` is launched without awaiting it (`.pi/extensions/fm-primary-turnend-guard.ts:238-259`). The update check reads the detector record before running the live gate and does not hold up the hook. The two installer commands are sequential: `pi update --self`, then `pi update --extensions` (`:167-197`).
- **Preference/watcher gating:** this feature has no separate preference switch. It requires a detector record whose `reported=` line matches `/pi\s+update\s+available/` (`:124-136`), and recent successful installation suppresses the check for ten minutes (`:138-149`). The scheduled path is watcher-armed separately and uses the same detected-update record; docs describe `fm-tool-update-check.sh arm` and `fm-tool-install.sh --arm` in `docs/configuration.md:158-195`. The on-load path itself does not require watcher arming.
- **Idempotence/cooldowns:** successful scheduled runs record `installed`; partial scheduled failures record `partial`; timeout-bound scheduled outcomes use `deferred` and a short retry cooldown (`bin/fm-tool-install.sh:357-402,466-529`). The on-load path doesn't publish its own result record, so repeated session loads can retry after a failure. Its ten-minute suppression is status-based, not tied to the detector record's generation/version, so an already-installed record younger than ten minutes also suppresses a newly detected update.
- **Timeout/failure reporting:** gate errors are mapped to worker-present versus unverifiable messages (`.pi/extensions/fm-primary-turnend-guard.ts:204-218`). Self-update failure returns its exit code; extension failure is mapped to code 126 (`:175-197,222-234`). Errors from sending follow-up messages are swallowed. On-load timeout is not mapped to the scheduled `deferred` status and does not update install records, so on-load and watcher diagnostics/retry behavior differ.
- **Active-worker safety:** the shared gate fails closed when Herdr is unavailable and process inspection cannot establish the state (`bin/fm-tool-live.sh:43-46,182-200`). When Herdr returns a valid snapshot with zero Pi panes, however, that branch trusts the pane count and does not also scan Pi processes (`:187-209`); thus safety assumes the snapshot is complete for live Pi workers. The self-counting concern above is the principal operational risk.
- **Extension scope:** the feature invokes Pi's `update --self` followed by `update --extensions` (`.pi/extensions/fm-primary-turnend-guard.ts:167-197`). The orchestrator documents that this targets npm-managed Pi extensions (`bin/fm-tool-install.sh:32-39,243-269,296-302`). No evidence in the reviewed changes shows it updating Firstmate's tracked `.pi/extensions` source in place.
- **Running process:** this is an on-disk update. The code neither restarts nor re-execs Pi. The currently running Pi process will continue with its existing executable image and already-loaded extension code; newly installed binaries/extensions are available to a subsequent Pi process/session. The self-update may replace the executable on disk while the current process remains alive.
- **Tests and limitations:** the search found existing Pi extension loading and session-start tests, but no test reference to `runOnLoadUpdate`, `UPDATE_RUN_BOUNDS_SECS`, or the on-load outcome text. No test was run, per instruction. This is a static review; Herdr snapshot timing, Pi CLI behavior on a live invocation, and process/PID reuse behavior were not exercised.

## Recommendation

Address the current-pane gate mismatch and clear timeout timers before relying on automatic update-on-load. Add focused tests for a live snapshot containing the invoking Pi pane, watcher/on-load overlap, timeout cleanup, and the successful/partial outcome paths. Keep update failures visible when message delivery is unavailable; currently follow-up delivery errors are intentionally ignored.

## Follow-up review: commit `3aa352a8d6127f292601ee49ee5008dfd01b8dea`

Reviewed this fix commit and related source/tests statically with `git diff <parent> <commit>` and `git show <commit>:<path> | nl -ba`; did not run tests or change project files. The fix clears child timeout timers and removes the on-load call to `runPiUpdate`, eliminating the delayed-PID-signal issue and the direct overlap of two installer processes noted above. The following issues remain or were introduced:

### High: on-load no longer performs an automatic update when the scheduled poll is absent or unarmed

At `.pi/extensions/fm-primary-turnend-guard.ts:261-274`, after the live gate passes, `runOnLoadUpdate` only sends a follow-up saying the scheduled poll will install later; it no longer calls `runPiUpdate` or otherwise invokes the install orchestrator. The scheduled install shim is separately armed by `fm-tool-install.sh --arm` (`bin/fm-tool-install.sh:10,638-655,820`), and the detector is separately armed by `fm-tool-update-check.sh arm` (`bin/fm-tool-update-check.sh:7,86`, with the documented commands in `docs/configuration.md:171-195`). If the scheduled poll is not armed, the update is not applied on load; the notice even offers manual install as an alternative (`.pi/extensions/fm-primary-turnend-guard.ts:268-271`). This no longer meets the stated intent to update Pi and its extensions automatically on load.

Recommendation: retain a safe automatic install-on-load path with shared serialization/recording, or make the task's intended contract explicitly depend on an armed scheduled poll and ensure arming is a required, verified setup condition.

### Medium: `--exclude-pid` still does not exclude the caller in the normal Herdr pane-count path

The extension passes its PID (`.pi/extensions/fm-primary-turnend-guard.ts:243-245`), and `bin/fm-tool-live.sh:206-214` filters it only after entering the pgrep fallback. When Herdr returns a valid snapshot, the earlier branch counts every Pi pane (`bin/fm-tool-live.sh:197-202`) and returns exit 1 for any nonzero count (`:217-224`); that branch never looks at `EXCLUDE_PID`. Thus the ordinary valid-Herdr-snapshot case can still count the initiating Pi session and block the on-load path. The option is implemented only for process-level fallback, not the normal pane-count path.

Recommendation: identify the current pane and exclude it from the Herdr snapshot, or use a process-level exclusion policy that still accounts for every other worker.

### Medium: `installInProgress()` treats every historical successful install as current

`.pi/extensions/fm-primary-turnend-guard.ts:221-224` returns `true` for any record with status `installed`, without checking its epoch. `runOnLoadUpdate` calls this helper after `recentInstallHandled()` (`:237-245`); although the latter only suppresses successful records younger than 600 seconds (`:138-149`), the subsequent helper makes the suppression permanent for any existing successful record. A later detector update can therefore be ignored indefinitely after the first scheduled successful install, with no notice and no on-load action.

Recommendation: compare the record epoch to the detector finding/version or bound successful-install suppression to a finite time window; better, record which update was handled.

### Tests do not establish the key behavioral claims

`tests/fm-tool-live-exclude-pid.test.sh:41-65,68-112` does not simulate a valid Herdr snapshot containing the caller's pane. Its process-filter case only checks that `--exclude-pid` is accepted and that output lacks a usage error (`:97-111`); it never asserts that the target PID is removed from a count. It therefore cannot substantiate the comment that the “current-pane gate no longer blocks” the loading session, and misses the unfiltered Herdr path.

`tests/fm-tool-timer-cleanup.test.sh:12-39,42-73` statically searches for `clearTimeout` text in handler regions, rather than exercising timeout/close ordering. Its other assertions only check that `runPiUpdate` is absent in the on-load function and that the strings `deferred` and `partial` occur in the helper (`:75-93`). It does not test armed/unarmed behavior, whether an `installed` record ages out, or whether a scheduled poll actually runs. These are static assertions and the tests were not run for this review.

## Follow-up conclusion

The timer cleanup is present. Duplicate installer execution is addressed by making the scheduled path the only install authority, but that changes the feature from automatic-on-load installation to a notice plus eventual scheduled installation. The revised path still has an ineffective PID exclusion for valid Herdr snapshots and permanently suppresses the on-load check after any historical `installed` record. The added tests do not detect these defects.
