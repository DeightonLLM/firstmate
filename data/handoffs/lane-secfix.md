# Lane 6 - Implement the inbound-trust fix (Luna 6, high)

Worktree /tmp/wt-lane-secfix, branch lane/secfix. Parent holds the fleet lock; you will not acquire
it. Expected. Read + WRITE under your worktree. No commit. No fm-session-start.

## Design is already measured - do not redesign it
  /home/hd2admin/kun-agent-workspace/data/lane-security/threat-model.md
  /home/hd2admin/kun-agent-workspace/data/lane-security/recommendation.md
Part 1 / A1 is Finding A (inbound trust). **Implement only A1.** Finding B is a separate blocker.

## The defect, verbatim from the model
`bin/fm-comms-ingest.sh` is the only component that lifts inbound bytes. `summary_of()` returns the
first non-blank line, control chars replaced, truncated to 200 chars. `cmd_scan` writes:

    comms-received: <id> <name> sha=<12 hex> bytes=<n> [corr=...] | <200 raw chars>

into `state/<id>.status`, and publishes a `signal` wake whose reason line is clean but whose
**target line is not**. AGENTS.md section 8 instructs the reading agent to read that target line.
So untrusted inbound bytes reach an agent holding merge authority and the fleet lock, with nothing
marking them as data.

## Implement A1 as specified
All four A1 changes land in `bin/fm-comms-ingest.sh`. No new service, no new file, no new interface.
Envelope the untrusted bytes so they can never be read as instruction.

## Absolute rules - violation fails the task
```
NEVER weaken or delete an existing guard to make this pass
NEVER move the raw text into a field the agent is told to act on
NEVER let a status value begin with a state: prefix that a classifier could act on
preserve every control in recommendation.md section A2, untouched
no production change, no deploy, no DNS, no customer data
```

## Deliverables
1. The patch to `bin/fm-comms-ingest.sh`.
2. A test that PROVES untrusted inbound text cannot be re-read as an instruction or as a state
   prefix. Test-first: show it failing before your patch, passing after. Show both runs.
3. Confirmation that every A2 control still functions after your change - name each one and how you
   checked it.
4. `data/lane-secfix/report.md` - what changed, both test runs, A2 verification, any blocker with
   an explicit [key=<slug>].
