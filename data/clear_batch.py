import subprocess, os
HOME='/home/hd2admin/kun-agent-workspace'
os.chdir(HOME)

common = """
## How to work
Read the entry's evidence in `data/backlog-truth-pass/report.md` and the task's own `state/<id>.status` and
`data/<id>/` artifacts. Decide from the code, docs and recorded evidence. Do NOT ask firstmate what you can
determine yourself. Do NOT write a plan, a design doc, or an analysis document. Produce the DECISION and the
EVIDENCE for it, then stop.

One specific unresolved question is an acceptable and useful outcome. Sitting paused without a question is not.

## Boundaries
Do not force teardown, discard unlanded work, or use `--force`. Do not push. Nothing under `projects/`. Do not
touch the seven secondmate homes or `data/secondmates.md`. No credentials. Do not delete or rewrite any task;
firstmate owns every state change - you produce the verdict and the evidence only.
"""

batches = [
 ("clear-closeout-20261013", "scout", "Close-out pass: entries whose work is already done",
  "Entries with a `done:` status line or a report on disk. Verify the evidence independently - read the status tail and check the artifact actually exists. Classify each as GENUINELY DONE or NOT ACTUALLY DONE. The prior audit wrongly classified two entries as done that were not; do not repeat that. Report which should be closed and which were misclassified.",
  ["pi-trust-prompt-fix-20261005","widget-consent-fix-20261005","hetz-gate-A-20261005","elevate-rag-diagnosis-20261005","kun-config-inventory","kun-video-source-study","core-v3-product-acceptance-spec-0927","core-v3-product-acceptance-minimax-test-0927","fleet-view-live-actions","backlog-truth-pass"]),
 ("clear-obsolete-20261013", "scout", "Obsolete pass: entries superseded by landed work",
  "Entries whose premise was overtaken by work that has since landed. Establish what landed and when, then say whether the entry is obsolete, still needed, or partially done. Cite the landed commit or artifact.",
  ["kun-concurrency-impl","reliability-receipt-20261012","reliability-controls-docs-20261012","graceful-rate-limit-handling","skill-collisions-cleanup-20261013","core-stage-chunk1-test-baseline","funnel-origin-diagnosis","core-stage-chunk4-spec-challenge","funnel-assertions-conditional","core-stage-draft-duplicates"]),
 ("clear-domain-20261013", "scout", "Domain pass: entries belonging to a secondmate expert",
  "Entries that are domain work rather than firstmate work. For each, name the correct domain expert by scope, state whether that expert's access refusals still apply, and give the exact brief the expert could execute now. Do not dispatch them yourself.",
  ["domain-expertise-20261013","elevate-ops-source-map","overnight-secondmate-progress-20261012","hetz-study-20261005","cbd-g5-source-refresh-0924","context-continuity-audit","kun-config-inventory"]),
 ("clear-infra-20261013", "scout", "Infra pass: firstmate tooling entries with a determinable answer",
  "firstmate tooling entries where the answer is in the code, the CI config, or tonight's landed work. Read the actual source and report what is still true, what is fixed, and what genuinely remains. Do not implement anything.",
  ["controller-watcher-tdd","status-dir-validate","quota-aware-queue-pump","pi-live-todo-default","afk-return-dir-fix","brief-compaction-preserve","calm-worker-version-consistency","controller-inbox-local-repair-20261013"]),
 ("clear-reliability-20261013", "scout", "Reliability pass: remaining narrow reliability entries",
  "The reliability entries the scoping pass narrowed to still-remaining work. For each, state the smallest concrete next action, who owns it, and what evidence is already sufficient. Where Controller firstmate owns it, say so plainly.",
  ["reliability-permission-20261012","reliability-reporting-20261012","reliability-routing-20261012","reliability-controls-docs-20261012","per-provider-dispatch-cap","durable-recovery-20261013","brief-worklocation-template-fix"]),
 ("clear-core-20261013", "scout", "Core pass: Core Distro entries and staging state",
  "Core Distro entries plus the staging tree state. Establish what is actually deployed in the staging site now, which Core entries are genuinely open, and what the PA-04 ownership gap means for the acceptance spec. Read only; no writes.",
  ["core-distro-stage-wp-multipage","core-distro-stage-scale-100pct","core-distro-stage-article-drawer-fix-20261012","core-mobile-fix","core-stream-a-checkpoint-0924","core-live-widget-source-0924"]),
]

for tid, kind, title, body, targets in batches:
    subprocess.run(['tasks-axi','add',tid,title,'--kind',kind,'--repo','firstmate','--queue',
                    '--body', body + ' TARGET ENTRIES: ' + ', '.join(targets)],
                   capture_output=True)
    subprocess.run(['bash','bin/fm-brief.sh',tid,'firstmate','--'+kind], capture_output=True)
    p = f'data/{tid}/brief.md'
    s = open(p).read()
    task = f"{title}.\n\n{body}\n\nTARGET ENTRIES: " + ", ".join(targets) + """\n
For EACH target entry, produce a table row: entry | verdict | evidence path | one specific next action or one
specific question. Verdicts: GENUINELY DONE / OBSOLETE / STILL NEEDS WORK / NOT ACTIONABLE HERE.
Then a prioritised list of what firstmate should act on, highest value first, with at most one question per item.""" + common
    open(p,'w').write(s.replace('{TASK}', task, 1))
    print('prepared', tid)