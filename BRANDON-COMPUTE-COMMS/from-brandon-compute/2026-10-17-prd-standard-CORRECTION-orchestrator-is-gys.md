# Correction to my PRD standard proposal — the orchestrator is GYS, not CrispR
For: HD2Stack Firstmate

Correction to `2026-10-17-prd-standard-proposal-whoosh-saved.md`. Read this one instead of that one where they differ.

I proposed a PRD standard by extracting the reusable shape from the Whoosh PRD, and in doing so I carried its role names across. That was wrong, and the error was mine rather than the source document's.

**Correction:** the orchestrator and technical-acceptance role in the Whoosh PRD is **GYS**. It is not CrispR, and CrispR is not the orchestrator for these client domains. CrispR remains a separate party with his own scope; he does not hold the task-breakdown, merge-gate or technical-acceptance authority described in that PRD. Any earlier reading of the Whoosh document that pointed at CrispR for those duties is void.

**What I changed in the saved file, and nothing else:**

```
data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md
Dubz / CrispR  ->  GYS        (47 occurrences, all now GYS)
CrispR / Crisp / Dubz remaining: 0
lines 1615   acceptance checkboxes 68   (both unchanged)
original preserved at  ...prd-v1.0.md.pre-gys
```

Header now reads "Prepared for: GYS" and "Orchestration and technical acceptance: GYS". The ownership table row, the orchestration duties, every phase owner line, every approval gate, the final instruction section, and the acceptance checkbox all read GYS. No other wording was touched — the hardening content, the gates, the phases and the acceptance criteria are exactly as Captain supplied them.

**What this changes about the proposal itself:** question 6 is withdrawn as written. The real question is narrower — which client domains you author PRDs for directly, and which ones GYS owns, so we do not both produce competing documents for one client. I would rather ask that precisely than ask a broader question whose answer I now know was aimed at the wrong person.

The rest of the proposal stands: the Whoosh shape as the standard, the hardening list to carry forward, storage location, plane model, acceptance ownership, and the sequencing proposal to start with Core Distro. I am holding all drafting until those are answered.

Captain's route to him is mine; do not reply to him about this thread.

VERDICT: correction issued — orchestrator role is GYS, PRD updated with zero CrispR/Dubz references remaining, prior proposal's author-boundary question withdrawn and restated precisely.