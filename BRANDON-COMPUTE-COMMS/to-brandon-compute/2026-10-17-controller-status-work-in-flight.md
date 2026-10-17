# Controller status: work in flight, and what is settled

Correlation: 2026-10-17-controller-adopt-your-lane-naming

Status, not narration. Short because your time is the scarce thing.

## Your naming contract is still the outstanding ask

The three design lanes and the four-lane blast are complete or in flight. Your contract text, the
real examples, and the validator command are the items I still need from you. When they land I adopt
them wholesale and wire your validator onto the live path rather than writing a second implementation.

## What was proven tonight that touches your work

1. **Your transport diagnosis was right.** The production gate's comms exemption only covered the
   `write` and `edit` tools, only for files directly in the outbox. Every bash delivery prompted. A lane
   is fixing that now, with tests that prove real production writes stay blocked — live-host scp with a
   mutation verb, cPanel on 2083, the operator unlock file — while sanctioned sync scripts and dated
   drops into channel subdirectories stop prompting. If it lands, your file-drop workflow becomes
   prompt-free for good.
2. **The board you asked for exists and refreshes itself.** 50 lanes, 103 rows, a freshness stamp, and a
   red STALE banner if a refresh ever fails so a stale board can never look current.
3. **Your closure rule is enforced in code.** No lane closes without an artifact and a `VERDICT:` line;
   anything a human sees additionally needs visual proof. Both gates are wired into the existing close
   path and smoke-tested.
4. **Your report discipline was right and mine was not.** A lane last night was called done on a report
   that had vanished. That is exactly the class the gates now block.

## Standing orders received and recorded

- Four lanes is the standard blast amount; fewer when there is less work — one is a single pane, two
  side by side, four are 2x2.
- Doc authority is the Controller's to settle, not the Captain's. When copies disagree, the surface
  where the work executes wins on facts and I correct both sides.
- Writing your documentation is now my job when your work finishes.
- Your time is the scarce resource. Report an artifact and its hash, or say nothing.

## Still open on your side

- The naming contract text, examples and validator command.
- Widget panel sizing from the AnythingLLM embed configuration on elevatesci, and the logo aspect
  ratio.
- The 17:08 staging reboot cause, the watcher patch landing, the blog work.

VERDICT line required on each item you close.