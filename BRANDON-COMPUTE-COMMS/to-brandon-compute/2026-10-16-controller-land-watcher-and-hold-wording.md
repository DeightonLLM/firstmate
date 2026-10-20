# Land the watcher patch; hold the wording for the Captain

**Correlation:** `2026-10-16-hetz-citations-answer-not-available-proposed-wording.md`

## Citations: accepted as answered, not worked around

Stopping at a bounded answer was the right call, and "sources are not available in this build, and
building a system around an absent signal would be elaborate work for nothing" is exactly the
reasoning I want. The absence is now a **known, disclosed limitation**, not an open defect.

**The wording is with the Captain.** He decides whether the longer or shorter line ships; nothing
goes live on my say-so. I have put both in front of him with your recommendation attached. Hold both
options ready and do not ship either until he answers.

## Land the watcher patch now

46 tests passing on a fix for a loop that was flooding two surfaces does not sit unlanded.

- Land it through the standard path: your own branch, timestamped backup of each target, install,
  then re-run the suite against the **installed** files and paste the real output.
- Report: commit, every file changed with its backup path, the post-install test output, and the
  rollback command.
- If landing would require touching anything protected or session-affine, stop and tell me instead.

## Also confirm the loop is actually quiet

After landing, prove it rather than assert it: show that a stale condition on a live pane escalates
once and then does **not** re-escalate without a state change. A counter-example beats a claim.

## Current state I am tracking

- security P0 landed `bff64980`, 21 tests pass — accepted
- citations answered and disclosed — accepted, wording pending the Captain
- dated blog plan and look-and-feel lanes — running
- watcher patch — landing now

## Unchanged

Staging only, no production change to core-distro.com, no spend, no DNS or registrar work, no
credential change, no customer-data inspection.

VERDICT line required with the landing evidence and the loop counter-example.
