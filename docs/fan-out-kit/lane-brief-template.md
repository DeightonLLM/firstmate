# Lane brief template — the contract that actually gets work out of an agent

Copy this into the lane's brief (or use it as the checklist when reviewing one). Every section
exists because leaving it out produced a measurable failure.

---

```markdown
# Objective

One sentence: what must exist afterwards that does not exist now.

# Boundary

What this lane may touch: <the exact paths, hosts, files>.
What this lane must not touch: <production, credentials, DNS, the backlog, the board,
the ledger, other lanes' worktrees>.

# Artifact

Two paths, both required:
1. <repo>/data/<lane-id>/report.md   - the worktree copy the fleet collects
2. /absolute/path/out/<lane-id>/DELIVERABLE.md - outside the worktree, so a worktree
   reclaim cannot destroy it

# Acceptance

The exact command that proves the work, and what its output must show:
`<command>` -> expect <what>.
Proof of the route, where a route is involved: a reply containing the exact token
<TOKEN> - a catalog line is not evidence.

# Stop condition

Stop and report (do not push on) when:
- the work needs a credential, a spend, a DNS or registrar change, a live deploy of
  client production, or any destructive or irreversible act;
- a decision is needed from the Captain that is not in the brief - register it with
  `bin/fm-decision-hold.sh hold` and keep going;
- the evidence needed for a claim cannot be obtained - say UNVERIFIED and finish the
  report, do not guess.

# Evidence rule

Cite the file and line you actually read for every claim. Where you could not verify
something, write UNVERIFIED and say why. A claim with no citation is a defect in the
report, not a fact.

# The decision-hold clause

Register each unresolved Captain decision with `bin/fm-decision-hold.sh hold` and pass
the shared completion gate of the `decision-hold-lifecycle` skill. That registration,
INSIDE YOUR OWN WORKTREE, is required and is the only repo write this lane is
authorised to make. If the brief elsewhere says "read-only", this clause is the
exception and this clause wins.

# Report shape

1. A summary table (item -> question -> recommendation -> cost of leaving it
   unanswered).
2. The detail per item, each claim cited.
3. Options with their risks, and one recommendation.
4. What you did NOT do, and why.
5. `NEXT:` the next action, one line.
6. The last line is the verdict:
   `VERDICT: PASS <reason>` or `VERDICT: FAIL <reason>`.

# Do not

- do not report a dispatch as a result;
- do not stop at a dialog or a composer - if a tool asks a question that the brief does
  not answer, say so in the report and choose the answer the brief implies;
- do not read, print, hash or measure a credential value (or any derived length, size,
  checksum or mtime);
- do not run `agent-secret-scan baseline`;
- do not copy a managed OAuth credential store between hosts;
- do not kill a pane that is provably working;
- do not touch client production without the Captain's word.
```

---

**Reviewing a brief before it spawns** — five questions, and any "no" is a stop:

1. Does the objective name one thing that must exist afterwards?
2. Is the artifact path **absolute as well as** in the worktree?
3. Does the boundary say which repo write (if any) is authorised, and does it agree with
   the completion gate the scaffold adds?
4. Is there an acceptance command, and does the route have a token proof?
5. Does the report shape end in a `VERDICT:` line?
