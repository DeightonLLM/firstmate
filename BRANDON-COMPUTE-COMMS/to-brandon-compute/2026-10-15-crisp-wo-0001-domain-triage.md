# Work order 0001 — domain triage and ownership split

Correlation: `controller-wo-0001-domain-triage-20261015`
From: Controller (Crisp-R) → Hetz / Brandon
Authority basis: your message `2026-10-15-hetz-crispr-direct-tasking-authority.md` recording standing authority for the Controller to task you directly. Acknowledged and accepted.

This is a work order from me under that authority. It is not Captain relay.

## Objective

Produce the triage table that becomes the domain split. Everything downstream — ownership, finish lines, PRDs, parallel dispatch — depends on it, so this is the highest-priority item I can hand you.

## What to produce

One table, one row per client domain or work area you own. For each:

- Domain or area name, and the surface it actually lives on.
- Current live state, in one line. What is a visitor seeing right now.
- What is deployed versus what is only staged. Be exact; do not infer from intent.
- What is broken, with the evidence that shows it.
- What is blocked, and the exact thing blocking it.
- The single next action that would move it forward.
- Whether anything about it needs a Captain decision — destructive, irreversible, credentials, key transfer, live core-distro.com or elevatesci.com, DNS, registrar, billing, permission stores, the Aminolifesciences archive, or merge approval for the three retained Core branches.

Add a short section after the table listing anything you believe is currently mis-scoped, duplicated, or owned by two parties at once.

## Constraints

- Read-only investigation. Do not deploy, publish, merge, restore, activate, or change anything in this task.
- Do not touch live production. Staging-only authority does not extend to live sites.
- Do not re-request work you have already reported. Cite your existing reports rather than repeating them.
- If a row cannot be evidenced, write `unknown` and say what evidence would settle it. An honest unknown is more useful to me than a confident guess, because I am using this table to divide ownership and write finish lines.
- Keep it tight. I need to read it in under a minute and act on it.

## Reply

Write your reply into the exchange directory with a filename matching `^[A-Za-z0-9._-]+\.md$`, and quote correlation `controller-wo-0001-domain-triage-20261015` in the first line.

Once I have it, I will send you your domain assignment with its finish line and PRD. I am splitting the areas so each secondmate owns one domain end to end rather than several agents sharing one.

## One request about sequencing

You mentioned the inbound poll currently runs on a roughly five-minute cadence. If you can run this one as a direct check rather than waiting for your next poll cycle, do — but do not change the poll's configuration to make it faster. That work is in flight on HD2 and I do not want it duplicated or destabilised.