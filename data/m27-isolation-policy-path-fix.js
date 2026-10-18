// Single-child bounded fix, dispatched via runs.all so the lane KEY is carried
// and therefore shows in the Captain's async panel. runs.run takes a positional
// string key; runs.all takes objects with a key field. Object form used here.
const results = await runs.all([
  {
    key: "m2.7h-brandon-isolation-policy-paths",
    label: "Move policy file to a tracked path",
    agent: "worker",
    model: "minimax/MiniMax-M2.7-highspeed:medium",
    cwd: "/home/hd2admin/kun-agent-workspace",
    output: "m27.2b-isolation-policy-path-fix.md",
    task: "A correctness fix to work you are inheriting, not the authority to redesign it. The client-infra isolation check puts its policy file at data/policy/client-infra-isolation.yaml, but data/ is gitignored in this repository, so that file can never be committed and the check would break for anyone who clones the repo. That is a real defect, not a preference. Do exactly this and nothing more: (1) move the policy file to docs/policy/client-infra-isolation.yaml, creating the directory, preserving its content byte for byte; (2) update the DEFAULT_POLICY path and the usage and help text inside bin/fm-client-infra-isolation-check.sh to the new location, and fix any --policy example in its comments; (3) update the test file only where it hardcodes the old default path, and add one test case proving the check's DEFAULT location exists and loads, so this exact defect cannot come back; (4) run bash tests/fm-client-infra-isolation-check.test.sh and confirm it passes, then run bash tests/fm-lane-naming-check.test.sh, bash tests/fm-lane-naming-spawn-integrity.test.sh and bash tests/fm-reap-records-check.test.sh to prove you broke nothing, and run shellcheck on the check script; (5) remove the old file under data/policy/ so exactly one copy exists. BOUNDARIES: you are already on branch m27.8-land-factory-work-20261017 in this checkout, which is the intended landing branch, so do NOT create another branch and do NOT check out, merge, or reset anything. Do not touch bin/fm-spawn.sh, bin/fm-classify-lib.sh, bin/fm-crew-visibility.sh, bin/fm-lane-naming-check.sh, or bin/fm-reap-records-check.sh. Do not stage or commit anything and do not push. Do not touch live state/, ledgers, config, settings, or any other lane's directory. No network, credentials, deployment, or delegation. Report the exact commands, exit codes, files changed, and a VERDICT confirming the policy file now sits in a tracked path and the check still fails correctly on a violating fixture. Do not contact the Captain; the parent commits and reports."
  }
]);
return results.map((r) => ({ lane: "isolation-policy-paths", ok: r.ok, runId: r.runId, outputReference: r.outputReference, output: r.output }));