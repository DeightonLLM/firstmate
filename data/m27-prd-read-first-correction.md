# MANDATORY CORRECTION — read the source PRDs before writing anything

The parent summarised these documents for you. That summary was incomplete and in one case
wrong (it treated Elevate as having no application console). Do NOT rely on it.

READ THESE IN FULL BEFORE YOU WRITE OR EDIT YOUR PRD:
1. docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md
   Read ALL 2071 lines. Especially:
   - §2.1-2.4 the four per-project definitions (what each project IS, and what is explicitly
     still unknown). Note §2.2: Elevate's exact requirements are NOT proven by the materials and
     no one may invent product, patient, clinical or compliance requirements. But the delivery map
     records an Elevate operations console that EXISTS and exposes unauthenticated status/job APIs.
     That contradiction must be stated in the PRD, not resolved by you.
   - §7.1-7.3 server roles and planes
   - §8 data and service isolation
   - §11 security
   - §19 rollout / Phase 5 project order
   - §20 project-specific acceptance tests  <- your acceptance checkboxes come from here
   - §21 global acceptance criteria
2. data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md
   Read fully. It is the template. Match its section order and depth.
3. docs/system-context/PRD_TRACEABILITY.md — status ledger
4. docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md — executive verdict

TREAT v3 AS AUTHORITATIVE-BUT-POSSIBLY-STALE:
The Captain says parts of v3 may no longer reflect current reality, and that we may have moved on.
So DO NOT treat v3's assumptions as current truth, and DO NOT let that become licence to invent.
Every row must be one of exactly three kinds, labelled as such:
  [VERIFIED TODAY]  - I measured it myself, command and output cited
  [PER v3]           - v3 states it; v3 dated, may be stale
  [PER TRACEABILITY] - the ledger states it with its own status and date
If v3 and today's reality disagree, record BOTH and mark the conflict OPEN. Never silently pick one.
If a claim is in none of the sources and I did not measure it, it is UNKNOWN.

Report back: which sections you read, any conflict you found between v3, the ledger and reality,
and every row you could not source.
