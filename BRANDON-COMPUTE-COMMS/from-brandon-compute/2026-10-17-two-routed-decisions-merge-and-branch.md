# Two decisions I stopped for instead of routing — both are yours to settle, not the Captain's
Correlation: factory-loop-20261017

I stopped mid-queue twice tonight and asked the Captain for decisions that were not his to make. Both were ownership or sequencing calls that sit with you. The Captain noticed the pattern before I did. Correcting it here rather than asking him a third time.

DECISION ONE — the merge of tonight's two commits. Both sit on branch m27.8-land-factory-work-20261017, ready and verified:
  983dfee8  lane naming check + spawn gate, reap-records check, four docs including the wiring map
  6af1d70d  client-infra isolation check, policy in docs/policy/ so a service move is a deliberate edit
All four test suites pass and shellcheck is clean; I re-ran them myself rather than trusting the lanes' reports.

My recommendation: yes, merge it, because every mechanism in it is a guard that currently exists only as an unlanded branch. The naming gate in particular is already in my working spawn path, so the enforcement is half-real until it lands. This repository is local-only, so the merge is local and reversible, and nothing pushes. Your call because it is your repo's default branch and you said merge authority is not mine.

DECISION TWO — the primary checkout is still on that feature branch, which trips the worktree-tangle guard. I did not switch it, because there is uncommitted pre-existing work in bin/fm-classify-lib.sh and bin/fm-crew-visibility.sh that is not mine and that I will not gamble. Two options, and I recommend the second: (a) I attempt the switch and git refuses if it would clobber that work, then I report what it protected; or (b) you or the lane that owns those two files land or stash them first, then I switch cleanly. I lean to (b) because those files are not mine to touch and (a) risks a half-switched tree at the worst hour.

WHATEVER YOU DECIDE ON ONE, TELL ME AND I KEEP GOING — I am not parking the queue for either answer. The llm.hd2.ai sweep is already running on my side regardless.

VERDICT: two decisions routed to their owner with a recommendation and evidence; queue continues in parallel; no merge and no branch switch performed by me.