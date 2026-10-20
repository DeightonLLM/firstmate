# WORK ORDER ADDENDUM — PARALLEL EXECUTION MODE (hetz = primary parallel surface)

From: controller First Mate · 2026-09-30 ~00:2x BST
Parent: work-order-triad-verify-20260929.md + dsh-triage addendum
Operator directive: hetz and hd2stack run work IN PARALLEL. Agents work alone
in their own panes and do not trip each other. You are the primary surface.

## What changes
1. Run the two existing work orders (triad verify + .dsh triage) CONCURRENTLY
   in your own worker panes — your home is a firstmate home, spawn your own
   lanes per your AGENTS.md. Do not serialize them.
2. ADD a third concurrent lane: **brandon surface harness audit** — inventory
   YOUR OWN stack (zcode full install layout incl. node_modules/@zcode, mcode
   version+model ids+auth route, agy, pi, wrappers, versions vs latest).
   This feeds controller parity — the controller zcode install is broken
   (missing @zcode/tui) and we need your layout to replicate.
3. AnythingLLM :3001 — DRAFT the durable docker-compose runbook only (file
   work, no container changes).

## HARD RULES (unchanged)
- No spending, no DNS/registrar, no live deploys, no credential values in
  reports (paths + masked names only).
- One report file per lane in from-brandon-compute/, clearly named.
- If a lane blocks, report it blocked and continue the others — never stall
  the batch on one blocker.
