// Factory step 1 — three disjoint lanes, parallel, all on the cheap model.
// Keys ARE the lane names so the Captain's async panel shows them.
// Returns a compact index; each child's own API-bound artifact holds the detail.
const results = await runs.all([
  {
    key: "m2.7h-brandon-wiring-map",
    label: "Map what is actually wired where",
    agent: "worker",
    model: "minimax/MiniMax-M2.7-highspeed:high",
    cwd: "/home/hd2admin/kun-agent-workspace",
    output: "m27.1-wiring-map.md",
    task: "Ticket m27.1. The Captain's instruction: 'confirm what is wired where'. Tonight three separate sources gave three different answers about which machine hosts the AnythingLLM instance that serves client chat, and every confusion came from names lying. Produce ONE evidence-based map, and do not guess a single row. For every client-facing service and endpoint in play — staging.core-distro.com chat, agents.elevatesci.com chat, the HD2 test instance, llm.hd2.ai, the elevatesci VPS, brandon-compute, hd2stack — record: what the endpoint actually resolves to, which host serves it, which process or container answers, and the evidence you measured. Rules: read-only discovery, no writes anywhere except your report, no network mutation, no credentials, no configuration change, no deploy, and do not touch, probe, resolve, or route to the hard-gated host srv1137994 / elevatesci-vps — if a question can only be answered by going there, write 'unanswerable from this surface: requires the gated owner' and stop. Reachability and readability are separate facts: report both. If a name conflicts with a measurement, the measurement wins and you say so plainly. Include an explicit 'names that lie' section, because that is what caused tonight's failure. Write to /home/hd2admin/kun-agent-workspace/data/m27.1-wiring-map-20261017/report.md and end with a VERDICT listing every row you could not verify and exactly who owns it. Do not contact the Captain; the parent reports."
  },
  {
    key: "m2.7h-brandon-docs-programme",
    label: "Correct our docs as a tracked programme",
    agent: "worker",
    model: "minimax/MiniMax-M2.7-highspeed:medium",
    cwd: "/home/hd2admin/kun-agent-workspace",
    output: "m27.3-docs-correction-programme.md",
    task: "Ticket m27.3. The Captain has separated documentation correctness from running work: this lane does docs only and touches no running system. Read data/m27-docs-sweep-20261016/report.md and data/m27-docs-remediation.md first for measured findings; do not re-audit from scratch. Produce a single tracked programme document at docs/docs-correction-programme.md listing every false, moved, or stale claim in THIS repository's documentation, in severity order, each with: the exact file and line, what it currently claims, what it should claim, how you verified the correction, and whether it is fixed now or still open. Fix only what you can verify locally and only inside this repository — never edit a policy copy that belongs to another surface, and never edit dated incident evidence, because those are records of what was observed. Where a claim cannot be verified locally, mark it open with the owner who can settle it rather than guessing. No code, no config, no settings, no network, no credentials, no live state or ledger writes. End with a VERDICT giving counts of fixed versus open and naming the single most dangerous remaining false claim. Do not contact the Captain; the parent reports."
  },
  {
    key: "m2.7h-brandon-recurring-answers",
    label: "Publish durable answers to tonight's recurring failures",
    agent: "worker",
    model: "minimax/MiniMax-M2.7-highspeed:medium",
    cwd: "/home/hd2admin/kun-agent-workspace",
    output: "m27.4-recurring-failure-answers.md",
    task: "Ticket m27.4. The Captain wants durable answers to the failures that keep recurring, not another incident report. Write ONE document at docs/recurring-failure-answers.md that, for each failure below, states the durable rule, why it keeps happening, the mechanism that now enforces it, and honestly whether that enforcement is tested-and-blocking, tested-but-advisory, or convention-only. The failures: (1) writing a file into the outbox being treated as delivery when it was never transmitted; (2) a notification being treated as receipt; (3) two lanes reporting mutually exclusive measurements of the same page with neither checked; (4) lanes showing as anonymous 'worker' in the operator's async panel; (5) no model visible on a running lane; (6) work dispatched to the wrong repository or a repository that did not exist; (7) a hard gate written days earlier silently overriding today's new instruction, with nobody noticing the conflict; (8) a worker's summary being accepted without independent verification; (9) repeated worker restarts throwing away partial work. For each, cite the actual mechanism in this repository by file path where one exists, and say plainly where there is NO mechanism. Do not invent enforcement that does not exist. No code changes in this lane — this is the documentation of what is and is not enforced. No config, settings, network, credentials, or live state writes. End with a VERDICT naming the two failures with no enforcement at all, ranked by how much Captain time they have cost. Do not contact the Captain; the parent reports."
  }
]);
return results.map((r, i) => ({
  lane: ["wiring-map", "docs-programme", "recurring-answers"][i],
  ok: r.ok,
  runId: r.runId,
  outputReference: r.outputReference,
  output: r.output
}));