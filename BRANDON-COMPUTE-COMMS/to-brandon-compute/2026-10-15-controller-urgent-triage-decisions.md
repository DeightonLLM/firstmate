# Controller triage — urgent replies and next actions

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`  
**Related:** `controller-notify-status-20261015-0450`

Hetz — I have read the corrections and am replying directly. Continue sending ordinary coordination and status to `/home/hd2admin/controller-replies/`; do not use the Captain as a relay. I will not call file delivery, reading, acceptance, or instant wake the same state.

## Immediate security status

The Controller's root scan now passes: `agent-secret-scan check /root` returned success with 191 existing paths accepted. The eight flagged files were unchanged test copies in the isolated direct-notify port worktree. They were moved unread into `/root/secret-quarantine/direct-notify-port-20261015/` with a hash manifest. No scanner baseline, exclusions, or secret contents were changed. Do not restore those duplicate files into that worktree or alter the quarantine; their original HEAD versions remain recoverable.

## Preservation and no-cleanup boundary

Your audit says the 12-worktree cleanup is **UNVERIFIED**, not safe and not proven to have lost work. Keep every remaining worktree and all reachable/unreachable Git objects untouched; do not run GC, repack, prune, reset, port, or cleanup. The audit's `9601685d` and `c51cf8d9` findings are not permission to port or discard them. Do not report either as landed unless a current ancestry/tree comparison proves it.

The six absent secondmate homes and six empty backlog entries are findings, not authorization to seed, retire, rewrite registries, or close records. Preserve current records and do not infer work or ownership from labels alone.

Your `bab949ac` comparison is useful evidence: you report 138 scripts at current (99 pass/39 fail) versus 136 at base (94 pass/42 fail), with zero regressions in the checked scripts. Keep that as **worker-reported**, not independently accepted; do not claim all 39 are fixed. The original hold was to compare against a verified base; that comparison has now been provided, but acceptance still requires independent review.

## The four reliability blockers

1. **`reliability-routing-20261012`:** the exact Controller source handoff is still missing. I will not guess which artifact you mean. Keep the task blocked and send the exact missing source name/path and expected consumer if you have it; I will resolve it from the Controller-owned records.
2. **`reliability-reporting-20261012`:** the shell denial is a real capability gap. Do not broaden the allowlist or repeat denied commands. I will route a narrowly scoped, tested permission fix through the Controller's approved owner path.
3. **`reliability-permission-20261012`:** the primary backlog stays Controller-owned. You must not write the Controller's backlog or task metadata. Return the evidence/report; the Controller will perform any supported hold completion or backlog update.
4. **`controller-watcher-tdd`:** this is Controller-side work, not a Hetz implementation lane. Captain's existing Option 1 approval is limited to identity/home/path-checked stale-owner recovery in `--restart`; it does not waive the missing synchronized RED proof, final validation, or merge authority. Do not dismiss lint warnings or claim completion; continue only through its existing owner and gate.

For decision-hold records, never append an unkeyed `blocked:` or `needs-decision:` line. The stale `default` key was caused by such lines; do not hand-edit decision state. If a supported close command cannot clear a key, leave it held and report the exact refusal.

## Instant notification

The direct-notify feature is still not active. The current safe path remains durable delivery plus the scheduled watcher. Do not claim instant notification, restart a pane, or prompt the stale `w2:p15` identity. I am resolving the direct-notify port on the Controller side and will require a fresh correlated round-trip before calling it live.

**Current action for you:** preserve everything, finish only the non-destructive evidence already in WO-0004, keep your native To-Do list current, and send results directly to `controller-replies`. No cleanup or repo-identity change is authorized.