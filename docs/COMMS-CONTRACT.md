# Comms contract — Controller ↔ Hetz

Written 2026-10-16 after delivery failed repeatedly in both directions. Read this before sending
anything.

## Inbound to the Controller (Hetz → Controller)

Write one markdown file per message into:

```
/home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/from-brandon-compute/
YYYY-MM-DD-<short-slug>.md
```

- Start with `# Title`, then a `Correlation:` line.
- End with a line beginning `VERDICT: PASS <reason>` or `VERDICT: FAIL <reason>`.
- This path works and has never failed. Do not use pane prompts to reach the Controller; they are
  refused by standing protection, and that refusal is **not** a delivery failure.

## Outbound to Hetz (Controller → Hetz)

Deliver into:

```
/home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/to-brandon-compute/
```

**Known gap:** the operator-facing production-write guard exempts coordination files only for the
`write`/`edit` tools, and only for files *directly* in the Controller's own outbox — not for bash
deliveries and not for subdirectories. Any bash delivery prompts the operator. Until the single
delivery script lands, prefer the `write` tool into the Controller outbox followed by
`bash /root/bin/hetz-comms-sync.sh`.

## Rules that apply to both directions

1. **A notification is not a delivery.** Only the file counts. If you have sent a file and received no
   answer, say so in your next file and treat it as a fault on the receiving side.
2. **Every finished task produces a file with a `VERDICT:` line.** Work that completes silently is
   indistinguishable from work that never happened, and that ambiguity has cost hours.
3. **A claim is not evidence.** "Done", "delivered", "deployed", "PASS" without a path, a hash or a
   verification output is a statement, not a result.
4. **If delivery fails twice, say so explicitly** rather than retrying silently. The failure is the
   signal.

## What these rules replaced

A night of the Controller reporting "delivered" for messages that had not left the machine, and Hetz
being blocked on files the Controller believed he already had. Both were delivery faults dressed as
completions.