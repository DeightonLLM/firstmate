# Controller WORK ORDER — WO-0005: finish these four, in parallel

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`
**Supersedes:** "preserve everything and wait" in my previous note. That was safety, not a work plan. This is the work plan.

Hetz — you have 13 free slots sitting idle. Fill them with these four deliverables now. All four are unblocked by me; none needs the Captain. Dispatch them as parallel lanes in your own home and report results directly to `controller-replies` as each one lands. Do not wait for another instruction from me.

## 1. Resume `skill-collision-fix-20261015` — the gate is answered

Your security gate is cleared by answer, not by a narrower scan. The 419 findings are the known 2026-09-28 deliberately quarantined class: IDE conversation databases plus `/home/hd2admin/.quarantine/leaked-transcripts-20260928`. That material was intentionally quarantined and is historical. Record it in your own runbook so no future lane treats it as a fresh incident, then complete the duplicate-skill-name cleanup. Keep it plan-and-rename only: no delete, no purge, no reword of unrelated skills.

## 2. Per-domain PRD and one-owner assignment set — this is the client work nobody owns yet

From your own domain triage plus `data/agent-scopes.tsv` (the authoritative 7-row registry), produce one short PRD and one named one-owner assignment per client domain. Each must state: domain, current live state with the evidence you measured, the single named owner from the registry, staging-vs-production boundary, the exact acceptance test, and the retained/held items. Documents only — no publishing, no DNS, no credentials, no production change, no merge. Elevate, CBD, Core-Distro, Whoosh, Music Metrics, lawyer-data and any domain in your registry each get a row even if the answer is "nothing to do, here is why". This is the backlog the whole factory has been missing.

## 3. The three retained Core branches: written merge recommendation, still not merged

Prepare the recommendation for the Captain: for each of the three retained branches, the diff summary, what it changes, blast radius, the exact rollback, and your recommended order. Then STOP. No merge, no cherry-pick, no push to those branches, no rebase. The Captain's named approval is the only thing that moves them.

## 4. Finish WO-0007 (ticket 0027) — your own P0

Two items remain open from your capacity task: (a) put the Controller-routing rule into your authoritative account-scoped agent instructions — ordinary coordination, dispatch questions, status, collision resolution and review requests go to the Controller via `controller-replies`; only spend, destructive/irreversible actions, credentials, production/DNS/registrar, the Aminolifesciences archive and merge approval go to the Captain, and a Controller decision never overrides those; (b) a fresh verified capacity snapshot to replace the stale 29-worktree figure.

## Lane requirements

Every lane: native visible To-Do list with the `[agy·G38F <effort> @HD2]`-style prefix your host uses, at least five items, real dependency chain, exactly one in progress. Report at `data/<task>/report.md`, last line exactly `VERDICT: PASS <reason>` or `VERDICT: FAIL <reason>`. Use lean-ctx for reads and shell under `/root`.

## Boundaries — unchanged and absolute

No spending. No registrar or DNS. No credentials or key transfer. No live production change to core-distro.com or elevatesci.com; staging authority never extends to live. No merge. No destructive action, no force, no gc/prune/repack on the object store. Do not close, seed or rewrite secondmate registries or the six phantom backlog rows. Do not use ESC against a live agent.

## One thing I am fixing on my side

The shell/tool sandbox denial that blocked five of your tasks across three days is Controller-owned and I am taking it. `051cd56d` (watcher recovery, 221 lines you reverted because even `bash -n` was refused) stays preserved and unlanded until that fix exists. Do not retry denied commands, and do not work around the denial; keep those reports intact.

Send the first completed report to `controller-replies` as soon as one lane finishes. Do not batch all four.