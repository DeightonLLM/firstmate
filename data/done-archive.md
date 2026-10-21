
## Archived 2026-09-23
- [x] br-system-herdr-audit - Map visible Herdr panes and worker steering data/br-system-herdr-audit/report.md (repo: firstmate) (kind: scout) (priority: 4) (reported 2026-09-23)
  Read-only audit. Report a concrete, low-confusion layout for visible, steerable parallel agents in this home, including pane naming, workspace/tab grouping, and supported Pi+MiniMax launch/control paths. Do not edit files.

## Archived 2026-09-23
- [x] br-system-update-audit - Audit safe updates for agent CLIs and extensions data/br-system-update-audit/report.md (repo: firstmate) (kind: scout) (priority: 4) (reported 2026-09-23)
  Read-only audit. Determine current installed Pi, Codex, Herdr, and extension versions; inspect the local watched-tools/update mechanism and each tool's supported update path. Recommend a safe automatic-update policy that avoids replacing runtimes while their agents are active, with evidence and rollback/verification steps. Do not update software or edit files.
- [x] br-system-ticket-audit - Map goals, tickets, and visual status board data/br-system-ticket-audit/report.md (repo: firstmate) (kind: scout) (priority: 4) (reported 2026-09-23)
  Read-only audit. Inspect the existing goals, tasks-axi backlog, Firstmate task lifecycle, and Lavish options. Recommend a minimal ticket workflow and visible status board that clearly maps tickets to worker panes and goals. Do not edit files.

## Archived 2026-09-23
- [x] agent-floor-audit - Check the live agent floor for readable, steerable task visibility data/agent-floor-audit/report.md (repo: firstmate) (kind: scout) (reported 2026-09-23)
  Read-only audit of the current Lavish agent-floor board and Firstmate fleet snapshot. Report whether the captain can see each active task, worker identity, state, project/worktree, and next action, and whether a ticket can be selected or steered without leaving the board. Compare the current board with live Herdr and Firstmate sources; list concrete gaps and a minimal next change. Do not modify the board, config, backlog, task state, panes, agents, or projects. Do not create a secondmate or launch agents. Do not inspect secrets or run tests.

## Archived 2026-09-23
- [x] elevate-live-browser - Capture live Android and desktop browser evidence for Elevate marketing site data/elevate-live-browser/report.md (repo: firstmate) (kind: scout) (reported 2026-09-23)
  Read-only browser reproduction of https://www.elevatesci.com/ marketing homepage at Android Pixel 7 portrait and desktop 1280x800. Use the already-installed cached Playwright Chromium only; do not install anything. Record real Chromium version and label Android emulation as a proxy. Compare heading/section padding/alignment and any overlap, console/network errors, and working path. Save screenshots with new filenames only under data/elevate-mobile-audit/evidence/; preserve existing report and evidence. No source repo edits, remote state changes, forms, login, deployment, or secrets. Report findings and link exact evidence.

## Archived 2026-09-23
- [x] tool-update-review - Review staged watched-tool auto-update implementation data/tool-update-review/report.md (repo: firstmate) (kind: scout) (reported 2026-09-23)
  Read-only review of the pending auto-update branch at /home/hd2admin/.treehouse/firstmate-46aafc/4/firstmate, commits 8f6216b and 70a8ca1 on fm/tool-auto-update. Inspect only those diffs and directly related docs. Assess whether update detection and staged install are safe, repeatable, rollback-aware, and include Pi extensions; identify concrete blockers or missing evidence. Do not edit files, run tests, install/update tools, touch backlog or task metadata, push, open PR, merge, or contact anyone. Write findings to the report only. The target worktree is read-only and is outside your own disposable worktree.
  Read-only implementation audit complete; captain-hold completion gate verified with --none.

## Archived 2026-09-23
- [x] local-model-audit - Diagnose Brandon Compute local model stack data/local-model-audit/report.md (repo: firstmate) (kind: scout) (priority: 4) (reported 2026-09-23)
  goal:visible-parallel-firstmate. Captain wants the local models working reliably and asks for a safe repeatable workflow. Diagnose the current Brandon Compute inference stack and identify the concrete failure or uncertainty and fastest safe next action. Read the current local registration and evidence records. Check only non-secret process, listener, health, and model-list signals for the pre-existing llama-server on loopback :8081, Ollama on loopback :11434, and 1Panel AI Gateway :8080. Do not print environment values, credentials, raw docker inspect output, or secret-named files. Treat /opt/brandon as a runtime copy, not source. Do not install or remove software or models, download models, change configuration, restart/stop services, change public exposure, or submit inference prompts. Return exact read-only commands and sanitized results, symptom versus cause, confidence, and a minimal checkpointed repair plan with explicit approval boundaries if a change is needed.
  Read-only audit and requested report revision complete; captain-call inventory verified with --none.

## Archived 2026-09-23
- [x] orchestration-map - Recommend visible Firstmate parallel-work structure data/orchestration-map/report.md (repo: firstmate) (kind: scout) (priority: 4) (reported 2026-09-23)
  goal:visible-parallel-firstmate. Captain asks whether every worker pane needs a child supervisor, whether to use secondmates, and how Firstmate can supervise parallel work while keeping each worker visible. Audit the current Firstmate task, pane, supervision, quota, and secondmate contracts; recommend a repeatable visible workflow and identify when a persistent secondmate is justified. Do not provision agents or change host/project state.
  Read-only recommendation complete; captain-call inventory verified with --none.

## Archived 2026-09-23
- [x] core-mobile-fix - Diagnose and fix Core Distro mobile Chrome layout (repo: core-distro-saas-clean) (kind: ship) (priority: 4) (done 2026-09-23)
  goal:visible-parallel-firstmate. Captain reports that Core Distro looks wrong in Chrome on Android. Reproduce the real mobile viewport behavior, separate trigger/masking condition/visible symptom, compare a proven desktop or working path, and find disconfirming evidence before assigning cause. Before code edits, record exact HEAD and create a checkpoint ref in the task worktree so the starting state can be restored without touching unrelated work. Follow red-green-refactor: add the narrow regression test, prove it fails for the reproduced mobile issue, make the smallest fix, then run the targeted checks and capture a Chrome Android-sized screenshot. No production deploy, push, PR, or merge.
  Footer contrast fix and test-runner diagnostic complete in local-only branch fm/core-mobile-fix; independently verified tests/run.sh 4/4, missing-Chromium path 3/1 exit 1, evidence preserved; no commit or merge.

## Archived 2026-09-23
- [x] stream-a-language-nav - Validate Core Distro language navigation and prepare Stream A artifact data/stream-a-language-nav/report.md (repo: core-distro-saas-clean) (kind: ship) (priority: 4) (reported 2026-09-23)
  Stream A from FIRSTMATE_COORDINATOR_KICKOFF.md: validate EN/PL/ES language navigation, toast and category filtering smoke checks, and prepare a sanitized deployment artifact. Work is complete in the visible M3 pane w2:pM; artifact remains local and is not deployed.
  Artifact checksum and reproducible build independently verified; 65 smoke checks passed; no deployment.

## Archived 2026-09-23
- [x] stream-a-deploy-artifact - Prepare Core Distro deployment artifact (repo: core-distro-saas-clean) (kind: ship) (priority: 4) (done 2026-09-23)
  In progress in visible Herdr pane w2:pM with Pi on MiniMax-M3. Existing branch/worktree: stream-a-language-nav. Preserve its existing uncommitted changes. Prepare a local artifact only; do not publish, deploy, push, or commit. This ticket is a visibility record; the current manually relaunched pane has no Firstmate task metadata.
  Completed local-only artifact at /home/hd2admin/agent-work/core-distro-saas-clean-stream-a-nav/lead-engine-saas-export-20260923_stream-a-lang-nav.zip; SHA-256 ea241ddf0eebfa7c5cb078e18227d55d55881e477b5338a5f3bdcecdd75a52cf. Pane w2:pM is idle and ready. No deploy, commit, or push.

## Archived 2026-09-23
- [x] calm-worker-version-consistency - Use one Crisp-R Calm version in Pi worker launches (repo: firstmate) (kind: ship) (priority: 4) (done 2026-09-23)
  Goal: visible-parallel-firstmate

  Ensure every newly launched Pi worker displays the same current HD2.ai/Crisp-R Calm presentation, regardless of which Firstmate worktree or repository revision owns its task.

  Observed reproduction and evidence:
  - `config/calm` in the active Firstmate home is `on`.
  - The three Pi task sessions used the same installed Pi CLI family, but two different checked-out Firstmate snapshots.
  - The `herdr-pane-board-context` tree at commit `2e61f527941216c6275a3d41995d3324856bf355` has `CALM_WORKING_SHIP_BRAND = "HD2.ai/Crisp-R"` in `.pi/extensions/lib/fm-calm-working-ship.ts`.
  - The `fleet-view-live-actions` tree at `697d94d9434a0675ef588d9b5aa41a716f727551` and the `brief-compaction-preserve` tree at `d723e16b531723e32816e90bc5a3ee5546faf671` have older Calm files without that brand constant.
  - Do not interrupt or rewrite those existing worker trees; the fleet-view worker is still editing its branch.

  Acceptance criteria:
  - Reproduce the mismatch through the real Pi launch and render path; record expected, observed, initiating trigger, masking condition, and visible symptom separately.
  - Make future Pi ship/scout launches use one canonical Firstmate Calm implementation and the launching home's `config/calm`, even when the task's project tree has an older or absent Calm extension.
  - Avoid loading two copies of Calm in one Pi process. Preserve other project extensions, the task turn-end extension, and existing Firstmate supervision behavior.
  - Calm remains opt-in per effective home; do not turn it on for a secondmate or project that has no `config/calm=on`.
  - Add a portable regression and an opt-in real-Pi check proving the branded presentation appears for both a current Firstmate worktree and a different project/worktree, while an off preference stays off.
  - Inspect relevant history and compare a known-good current worktree with the stale worktree. Include a counterfactual and disconfirming check in the private task report.
  - Follow `.agents/skills/firstmate-coding-guidelines/SKILL.md`, `.agents/skills/diagnostic-reasoning/SKILL.md`, and `.agents/skills/tdd-red-green-refactor/SKILL.md`.
  - Keep a live Pi todo list, use one bounded read-only Pi subagent review with no child edits or recursive delegation, and include focused lint/test evidence.
  - Preserve existing edits, worktrees, and commits. Use Firstmate's no-mistakes delivery path; do not merge, force, discard, deploy, or restart an active worker mid-edit.
  Canceled by user; no further implementation or review. Preserved the branch, worktree, report artifacts, pane, and existing composer text; this is an administrative cancellation close, not a completed code-delivery claim.

## Archived 2026-09-23
- [x] core-v3-criteria-hunt-0923 - Locate Core Distro product V3 acceptance source data/core-v3-criteria-hunt-0923/report.md (repo: core-distro-saas-clean) (kind: scout) (priority: 4) (reported 2026-09-23)
  Read-only source discovery: find the authoritative Core Distro SaaS product V3 PRD and its acceptance criteria in the local warehouse and approved workspace documentation. The existing gap map searched the Core repository and selected Firstmate artifacts only. Search markdown and text documentation under /home/hd2admin/agent-work, /home/hd2admin/brandon-inbox, /home/hd2admin/kun-agent-workspace/data, and the Core source. Exclude .env files, credentials, stateful app data, and agent session logs. Do not SSH or contact anyone. Report exact path, title/version/date, source-of-truth evidence, criteria headings, checksum or git identity, and explicitly distinguish it from BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md. If no document is found, record exact searched roots and filename/content terms.

## Archived 2026-09-23
- [x] core-footer-fresh-qa-0923 - Rerun Core footer contrast acceptance checks data/core-footer-fresh-qa-0923/report.md (repo: core-distro-saas-clean) (kind: scout) (priority: 4) (reported 2026-09-23)
  Fresh repeatable verification of the saved uncommitted Core Distro footer contrast fix. The prior review passed from saved evidence but did not rerun tests. Use the exact existing worktree /home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/1/core-distro-saas-clean and inspect its status before reading. Reproduce in an isolated temporary copy; do not write to or overwrite evidence in the original worktree. Run the official footer contrast test and check all footer links in light and dark themes at 360, 390, 412, 430, 768, and 1280 CSS-pixel widths. Capture exact commands, computed contrast, console/network errors, screenshots, and environment in the report. Do not edit source, commit, merge, deploy, or navigate production. Report a concrete blocker if isolated reproduction cannot run.

## Archived 2026-09-24
- [x] core-offline-suite-audit-0923 - Audit safe offline Core Distro regression checks data/core-offline-suite-audit-0923/report.md (repo: core-distro-saas-clean) (kind: scout) (priority: 3) (reported 2026-09-23)
  Independent regression audit of safe offline Core Distro checks outside the already verified footer assertions. Use the exact saved change in /home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/1/core-distro-saas-clean as the source, and keep the original worktree untouched. Inspect documented runners first, copy required source and tests to a fresh isolated temporary directory, then run every test or lint check that does not use credentials, external services, production, or a persistent database. Report exact commands, pass/fail output, skipped tests with concrete reasons, and any regression outside the footer. This audit does not claim product V3 completeness. Make no source edits, commits, merges, or deployments.

## Archived 2026-09-24
- [x] tool-auto-update-review-0923 - Review Pi auto-update launch behavior data/tool-auto-update-review-0923/report.md (repo: firstmate) (kind: scout) (priority: 3) (reported 2026-09-23)
  Read-only independent review of the current fm/tool-auto-update branch at commit dac9e8e8e547fcd3c84a696a491119bbb5a78cfd. Review the Pi process-start self and extension update behavior against the requested automatic update on load. Do not edit files, add or run tests, install or upgrade tools, alter machine state, push, create a PR, or merge. Inspect the branch diff and related launch/configuration paths statically. Check ordering and idempotence, config and watcher gating, timeout/failure behavior, active-worker safety, extension scope, and whether running processes are changed. Preserve the branch. Write findings with severity and exact file/line to the scout report; if none, state what was reviewed and the limits of static review. Keep a visible checklist current in the pane and send short progress lines before review and after each major phase. One owner; no children for this bounded independent review.

## Archived 2026-09-24
- [x] trace-dir-probe - Probe status dir (kind: ship) (done 2026-09-23)
  local main

## Archived 2026-09-24
- [x] parallel-dispatch-audit - Audit quota-aware parallel ticket flow and refill data/parallel-dispatch-audit/report.md (repo: firstmate) (kind: scout) (priority: 4) (reported 2026-09-23)
  goal:visible-parallel-firstmate

  Read-only audit: determine how Firstmate can keep the maximum safe number of independent, ready ticket lanes active and visible without giving every pane a separate supervisor.

  Inspect current `tasks-axi`, `fm-spawn`, watcher/wake, `quota-axi`, dispatch-profile, and Herdr state from this home. Read `data/orchestration-map/report.md` and `data/br-system-ticket-audit/report.md` first; do not repeat their generic topology or live-pane visibility findings.

  Deliver `data/parallel-dispatch-audit/report.md` with:
  - The current exact dispatch path and the point where a queued ticket must be started by firstmate.
  - Whether the watcher or any existing helper automatically refills idle capacity; cite current code and command evidence.
  - A concrete safe queue-pump design or manual operating cadence that scales up to the captain's stated concurrency ceiling only when independent unblocked tickets and measurable quota permit.
  - How it prevents two writers from owning the same files/worktree, avoids duplicate audits, preserves captain holds and delivery modes, and exposes each lane's task id, Herdr pane, model, busy state, and live checklist.
  - A minimal implementation breakdown into separate tickets with exact file ownership and dependencies; reuse existing goal tags and backlog rather than inventing parallel state.
  - Any capability that needs an explicit captain decision, separated from decisions already authorized in `data/goals.md` and `data/captain.md`.

  Do not edit shared tracked code, do not mutate project or host state, do not dispatch or steer another worker, and do not provision a secondmate. Use a Pi todo checklist with live updates and lean-ctx; one bounded child review is allowed only if it adds independent evidence, with no recursive delegation.

## Archived 2026-09-24
- [x] cbd-acceptance-map-0923 - Map CBD-data G4/G5 acceptance evidence data/cbd-acceptance-map-0923/report.md (repo: firstmate) (kind: scout) (priority: 1) (reported 2026-09-23)
  You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

  # Task
  ## Captain's intent
  Continue CBD-data work from the Controller-provided source and establish which G4/G5 acceptance evidence is present, missing, or blocked.

  ## Firstmate spec
  Perform a bounded, read-only audit of `/root/agent-work/projects/cbd-data.com/current-cbd-data` on the Controller host, using the already approved SSH route `root@100.117.47.27`. First check whether that exact path is accessible. Inspect only repository documentation, acceptance/evidence manifests, git identity/status, test names, and package/build command declarations. Do not read `.env`, credential files, customer records/exports, databases, model data, or runtime service state. Do not run tests, edit files, or make remote changes. Report the exact source path and git identity; map each available G4/G5 artifact to its stated acceptance criterion; distinguish absent artifacts from access failures; list the smallest next action needed to resume delivery. Include checksums for relevant small documentation artifacts. If access is blocked, report `BLOCKED_ACCESS` with the exact safe diagnostic and stop. Keep a visible live TODO list current in the pane, use lean-ctx for routine repository reading, and append only phase-change or terminal status events. This narrow report has no independent work split, so do not spawn child agents.

  # Herdr lifecycle declaration - NOT ENABLED
  **HARD SAFETY GATE:** this scaffold cannot inspect the task text filled in above.
  If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
  Do not add Herdr lifecycle commands to this unguarded brief by hand.

  # Setup
  You are in a disposable git worktree of firstmate, at a detached HEAD on a clean default branch.
  This is a SCOUT task: the deliverable is a written report, not a PR.
  The worktree is your laboratory - install, run, edit, and make scratch commits freely; all of it is discarded at teardown.
  The report is the only thing that survives, so anything worth keeping must be in it.

  # Rules
  1. Never push to any remote and never open a PR.
  2. Stay inside this worktree; the only files you may write outside it are the report and the status file below.
  3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
  4. Report status by appending one line:
     `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/cbd-acceptance-map-0923.status'`
     States: working, needs-decision, blocked, paused, done, failed.
     Substitute `<epoch>` with the current Unix time in seconds - run `date +%s` and write the number it printed; a stamp that is not plain digits records no time at all.
     Each append wakes firstmate, so report sparingly: only phase changes a supervisor
     would act on and the needs-decision/blocked/paused/done/failed states. No step-by-step
     FYI progress lines; firstmate reads your pane for that.
     Whenever you mention a PR anywhere - a status line, your terminal, a summary - write its full
     https:// URL exactly as the forge printed it, never a bare number such as "PR 108"; firstmate
     copies that URL from your line rather than assembling one.
     Use `paused: {why}` - distinct from `blocked:` - ONLY when you are deliberately idling on a
     known external wait you expect to clear on its own (an upstream release, a rate-limit reset, a scheduled window, or your own validation round):
     firstmate then leaves your idle pane alone and rechecks it on a long cadence instead of
     treating it as a possible wedge. When you know when the wait clears, say so in the line with
     `until <YYYY-MM-DDTHH:MMZ>` (UTC) and firstmate rechecks at that time instead.
     Use `blocked:` when you are stuck and need help.
  5. If you hit the same obstacle twice, append `blocked [at=<epoch>]: {why}` and stop; firstmate will help.
  6. If a decision belongs to a human (product choices, destructive actions),
     append `needs-decision [at=<epoch>]: {summary of options}` and stop. Firstmate will reply with the decision.
     A decision or blocker you opened stays open until a `resolved` line carrying its exact key lands; a later `done:` or `working:` line never closes it, even when the answer is what started that work.
     Firstmate's reply normally writes that closing line at answer time; when a blocker or wait clears WITHOUT a firstmate reply, append `resolved [at=<epoch>]: {how it cleared}` yourself (same `[key=<slug>]` if you opened it with one) as you resume.
  7. Never stop, restart, or update the shared `no-mistakes` daemon - it is one instance serving
     every lane/home, so restarting it kills other lanes' in-flight pipeline runs; only firstmate
     manages the daemon.
     Before you append `blocked:` about the pipeline, run `no-mistakes daemon status` and
     `no-mistakes axi status`. If the daemon socket refuses connections or is missing, append
     `blocked [at=<epoch>]: {the daemon error}` and stop even when the local run record still says running or
     fixing, because that record can be stale after the daemon exits. A run record failed with a
     daemon error is also a real block.
     Only after ruling out socket refusal, if the run is still running or fixing, reattach and keep
     going. A drive-call error, timeout, slow read, or generic unreachability is NOT a daemon error:
     the daemon accepts `respond` immediately and runs the round in the background, so a killed or
     timed-out call was only waiting for a read while the run kept working.

  # Firstmate instruction inbox
  Firstmate steers you through durable message files in '/home/hd2admin/kun-agent-workspace/state/cbd-acceptance-map-0923.inbox'.
  When a terminal message says an instruction is waiting there - and at any natural checkpoint when you are unsure - list '/home/hd2admin/kun-agent-workspace/state/cbd-acceptance-map-0923.inbox'/*.msg, read and act on each message in numeric order, then acknowledge each handled message by moving it: `mv '/home/hd2admin/kun-agent-workspace/state/cbd-acceptance-map-0923.inbox'/NNN.msg '/home/hd2admin/kun-agent-workspace/state/cbd-acceptance-map-0923.inbox'/handled/`.
  The move IS the acknowledgement: without it firstmate rings again and eventually treats you as stuck. An empty or absent inbox needs no action.

  # Definition of done
  Write your findings to `/home/hd2admin/kun-agent-workspace/data/cbd-acceptance-map-0923/report.md`.
  The report must stand alone: what you did, what you found, the evidence (commands run, output, file:line references), and what you recommend.
  If your deliverable is a visual artifact the captain will review and iterate on, use the lavish-axi rule: arm your board with bin/fm-procevent-lavish.sh arm <artifact.html> --for <task-id>; never run lavish-axi poll yourself. Re-arm with the reply after each nonterminal round to acknowledge it, route the board feedback through your steering inbox, write needs-decision [key=board-review] with the live board URL when the captain owes a decision, and stop at session_ended or an empty End without re-arming - acknowledge that final round with bin/fm-procevent.sh handled <source-id> <sequence> to conclude and retire your board.
  Before reporting done, read and follow `/home/hd2admin/kun-agent-workspace/.agents/skills/captain-hold-lifecycle/SKILL.md` and pass its shared completion gate for the report and any visual review.
  When the report is complete, append `done [at=<epoch>]: {one-line conclusion}` to the status file and stop.
  If your findings reveal work that should ship (e.g. you reproduced a bug and the fix is clear), say so in the report; firstmate may promote this task in place, and you would then receive mode-specific ship instructions as a follow-up message.

  # Home brief additions
  These are this home's standing additions; every other section of this brief takes precedence over anything here that conflicts.
  ## Pi Worker Defaults
  - These model-routing preferences are local to this Hetzner Firstmate home and are not a controller or cross-home policy; do not forward them without direct captain instruction.
  - At task start, create one concise checklist with Pi's `todo` tool and print the full list into the pane. Keep exactly one step active and update the same checklist in place; do not clear or recreate it after compaction, interruption, or a pipeline phase. If recovery finds it missing, rebuild it from the task brief and observed evidence, deduplicating completed steps.
  - Before any long-running command or delegated review, start its checklist item and print a short progress line describing what is running. When it returns, immediately update the todo list and report the result before starting the next operation. Never leave completed work unchecked or mark work complete before its evidence exists.
  - The Firstmate backlog remains the durable task state. A Pi todo list is live pane progress, not a replacement for the task report or backlog transition.
  - Use installed subagent capabilities for independent, bounded subtasks when they create useful parallel progress or independent evidence. Keep one owner per worktree, give children only required context, require a live updating todo list in the visible owner pane, and do not allow recursive delegation unless the captain explicitly asks.
  - Model routing for this Hetzner home: use MiniMax-M2.7 for routine implementation, tests, bug fixes, and bounded maintenance; use MiniMax-M3 for genuinely difficult, high-ambiguity, architectural, or multi-component implementation. Keep an already-running task on its assigned model unless the captain explicitly asks to switch; never interrupt a live edit or test just to change models. The primary Firstmate/Codex owns the review pass; do not use M3 for review-only work or launch a separate M3 reviewer unless the captain asks for independent review. Codex coordinates and reviews; use a suitable MiniMax lane for implementation. Use Gemini only if MiniMax and Codex are near exhaustion and important work cannot wait; check its live quota first and do not invent a fixed percentage threshold.
  - Before each worker or child dispatch, check quota-axi and require known runway for the likely task horizon. Use its live reset times as authoritative; never reuse a remembered reset timestamp.
  - For a single Pi child, use a top-level `workflowScript` returning `runs.run(...)`; first query `{action:"models"}` and pass the exact provider/id. Never combine `workflowScript` with top-level `agent` or `task`. Inspect child status before retrying a failed-looking launch, consult the installed tool guide instead of guessing, and report the exact capability gap if it cannot run.
  - Use `lean-ctx` for shell output, search, and reading when available; if it is missing from `PATH`, try `~/.local/bin/lean-ctx`. Use raw output for exact diffs, source tokens, errors, and validation evidence when compression could lose detail.
  - If a requested capability is unavailable, report the exact gap and continue the useful work in the visible pane.

## Archived 2026-09-24
- [x] elevate-public-rag-corpus-0923 - Inventory public Elevate RAG corpus data/elevate-public-rag-corpus-0923/report.md (repo: firstmate) (kind: scout) (priority: 1) (reported 2026-09-23)
  You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

  # Task
  ## Captain's intent
  Prepare the Elevate chatbot's RAG source from public `elevatesci.com` pages only, shaped for comparison with Core's RAG once its actual structure is known.

  ## Firstmate spec
  Create a read-only candidate corpus inventory from public pages on `https://elevatesci.com`. Use the `crawl4ai` skill for bounded same-domain discovery. Inspect the sitemap and robots file, then crawl only public marketing/product/help pages; exclude `agents.elevatesci.com`, authentication, dashboards, forms requiring submission, and third-party sites. Do not access internal files such as `.lavish/client-sales-journeys.html`, private business material, AnythingLLM admin/API endpoints, or customer data. Do not ingest documents, change site code, create a workspace, or alter routing. Report the exact crawl date, canonical URLs, titles, page categories, normalized-content SHA-256 hashes, duplicate/redirect handling, and any public page errors. Include concise normalized content excerpts only where they establish useful RAG coverage; keep the report small and useful for later ingestion planning. Compare the resulting manifest fields with the Core artifact at `data/local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1/anythingllm-rag-handoff-artifact.md`, treating Core's workspace and chunk settings as unknown until evidence is supplied. Keep a visible live TODO list current in the pane, use lean-ctx for routine reads, and append only phase-change or terminal status events. This bounded public crawl has one owner; do not spawn child agents.

  # Herdr lifecycle declaration - NOT ENABLED
  **HARD SAFETY GATE:** this scaffold cannot inspect the task text filled in above.
  If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
  Do not add Herdr lifecycle commands to this unguarded brief by hand.

  # Setup
  You are in a disposable git worktree of firstmate, at a detached HEAD on a clean default branch.
  This is a SCOUT task: the deliverable is a written report, not a PR.
  The worktree is your laboratory - install, run, edit, and make scratch commits freely; all of it is discarded at teardown.
  The report is the only thing that survives, so anything worth keeping must be in it.

  # Rules
  1. Never push to any remote and never open a PR.
  2. Stay inside this worktree; the only files you may write outside it are the report and the status file below.
  3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
  4. Report status by appending one line:
     `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/elevate-public-rag-corpus-0923.status'`
     States: working, needs-decision, blocked, paused, done, failed.
     Substitute `<epoch>` with the current Unix time in seconds - run `date +%s` and write the number it printed; a stamp that is not plain digits records no time at all.
     Each append wakes firstmate, so report sparingly: only phase changes a supervisor
     would act on and the needs-decision/blocked/paused/done/failed states. No step-by-step
     FYI progress lines; firstmate reads your pane for that.
     Whenever you mention a PR anywhere - a status line, your terminal, a summary - write its full
     https:// URL exactly as the forge printed it, never a bare number such as "PR 108"; firstmate
     copies that URL from your line rather than assembling one.
     Use `paused: {why}` - distinct from `blocked:` - ONLY when you are deliberately idling on a
     known external wait you expect to clear on its own (an upstream release, a rate-limit reset, a scheduled window, or your own validation round):
     firstmate then leaves your idle pane alone and rechecks it on a long cadence instead of
     treating it as a possible wedge. When you know when the wait clears, say so in the line with
     `until <YYYY-MM-DDTHH:MMZ>` (UTC) and firstmate rechecks at that time instead.
     Use `blocked:` when you are stuck and need help.
  5. If you hit the same obstacle twice, append `blocked [at=<epoch>]: {why}` and stop; firstmate will help.
  6. If a decision belongs to a human (product choices, destructive actions),
     append `needs-decision [at=<epoch>]: {summary of options}` and stop. Firstmate will reply with the decision.
     A decision or blocker you opened stays open until a `resolved` line carrying its exact key lands; a later `done:` or `working:` line never closes it, even when the answer is what started that work.
     Firstmate's reply normally writes that closing line at answer time; when a blocker or wait clears WITHOUT a firstmate reply, append `resolved [at=<epoch>]: {how it cleared}` yourself (same `[key=<slug>]` if you opened it with one) as you resume.
  7. Never stop, restart, or update the shared `no-mistakes` daemon - it is one instance serving
     every lane/home, so restarting it kills other lanes' in-flight pipeline runs; only firstmate
     manages the daemon.
     Before you append `blocked:` about the pipeline, run `no-mistakes daemon status` and
     `no-mistakes axi status`. If the daemon socket refuses connections or is missing, append
     `blocked [at=<epoch>]: {the daemon error}` and stop even when the local run record still says running or
     fixing, because that record can be stale after the daemon exits. A run record failed with a
     daemon error is also a real block.
     Only after ruling out socket refusal, if the run is still running or fixing, reattach and keep
     going. A drive-call error, timeout, slow read, or generic unreachability is NOT a daemon error:
     the daemon accepts `respond` immediately and runs the round in the background, so a killed or
     timed-out call was only waiting for a read while the run kept working.

  # Firstmate instruction inbox
  Firstmate steers you through durable message files in '/home/hd2admin/kun-agent-workspace/state/elevate-public-rag-corpus-0923.inbox'.
  When a terminal message says an instruction is waiting there - and at any natural checkpoint when you are unsure - list '/home/hd2admin/kun-agent-workspace/state/elevate-public-rag-corpus-0923.inbox'/*.msg, read and act on each message in numeric order, then acknowledge each handled message by moving it: `mv '/home/hd2admin/kun-agent-workspace/state/elevate-public-rag-corpus-0923.inbox'/NNN.msg '/home/hd2admin/kun-agent-workspace/state/elevate-public-rag-corpus-0923.inbox'/handled/`.
  The move IS the acknowledgement: without it firstmate rings again and eventually treats you as stuck. An empty or absent inbox needs no action.

  # Definition of done
  Write your findings to `/home/hd2admin/kun-agent-workspace/data/elevate-public-rag-corpus-0923/report.md`.
  The report must stand alone: what you did, what you found, the evidence (commands run, output, file:line references), and what you recommend.
  If your deliverable is a visual artifact the captain will review and iterate on, use the lavish-axi rule: arm your board with bin/fm-procevent-lavish.sh arm <artifact.html> --for <task-id>; never run lavish-axi poll yourself. Re-arm with the reply after each nonterminal round to acknowledge it, route the board feedback through your steering inbox, write needs-decision [key=board-review] with the live board URL when the captain owes a decision, and stop at session_ended or an empty End without re-arming - acknowledge that final round with bin/fm-procevent.sh handled <source-id> <sequence> to conclude and retire your board.
  Before reporting done, read and follow `/home/hd2admin/kun-agent-workspace/.agents/skills/captain-hold-lifecycle/SKILL.md` and pass its shared completion gate for the report and any visual review.
  When the report is complete, append `done [at=<epoch>]: {one-line conclusion}` to the status file and stop.
  If your findings reveal work that should ship (e.g. you reproduced a bug and the fix is clear), say so in the report; firstmate may promote this task in place, and you would then receive mode-specific ship instructions as a follow-up message.

  # Home brief additions
  These are this home's standing additions; every other section of this brief takes precedence over anything here that conflicts.
  ## Pi Worker Defaults
  - These model-routing preferences are local to this Hetzner Firstmate home and are not a controller or cross-home policy; do not forward them without direct captain instruction.
  - At task start, create one concise checklist with Pi's `todo` tool and print the full list into the pane. Keep exactly one step active and update the same checklist in place; do not clear or recreate it after compaction, interruption, or a pipeline phase. If recovery finds it missing, rebuild it from the task brief and observed evidence, deduplicating completed steps.
  - Before any long-running command or delegated review, start its checklist item and print a short progress line describing what is running. When it returns, immediately update the todo list and report the result before starting the next operation. Never leave completed work unchecked or mark work complete before its evidence exists.
  - The Firstmate backlog remains the durable task state. A Pi todo list is live pane progress, not a replacement for the task report or backlog transition.
  - Use installed subagent capabilities for independent, bounded subtasks when they create useful parallel progress or independent evidence. Keep one owner per worktree, give children only required context, require a live updating todo list in the visible owner pane, and do not allow recursive delegation unless the captain explicitly asks.
  - Model routing for this Hetzner home: use MiniMax-M2.7 for routine implementation, tests, bug fixes, and bounded maintenance; use MiniMax-M3 for genuinely difficult, high-ambiguity, architectural, or multi-component implementation. Keep an already-running task on its assigned model unless the captain explicitly asks to switch; never interrupt a live edit or test just to change models. The primary Firstmate/Codex owns the review pass; do not use M3 for review-only work or launch a separate M3 reviewer unless the captain asks for independent review. Codex coordinates and reviews; use a suitable MiniMax lane for implementation. Use Gemini only if MiniMax and Codex are near exhaustion and important work cannot wait; check its live quota first and do not invent a fixed percentage threshold.
  - Before each worker or child dispatch, check quota-axi and require known runway for the likely task horizon. Use its live reset times as authoritative; never reuse a remembered reset timestamp.
  - For a single Pi child, use a top-level `workflowScript` returning `runs.run(...)`; first query `{action:"models"}` and pass the exact provider/id. Never combine `workflowScript` with top-level `agent` or `task`. Inspect child status before retrying a failed-looking launch, consult the installed tool guide instead of guessing, and report the exact capability gap if it cannot run.
  - Use `lean-ctx` for shell output, search, and reading when available; if it is missing from `PATH`, try `~/.local/bin/lean-ctx`. Use raw output for exact diffs, source tokens, errors, and validation evidence when compression could lose detail.
  - If a requested capability is unavailable, report the exact gap and continue the useful work in the visible pane.

## Archived 2026-09-24
- [x] core-v3-lane-a-review-0923 - Independently review Core V3 Lane A acceptance evidence data/core-v3-lane-a-review-0923/report.md (repo: core-distro-saas-clean) (kind: scout) (priority: 1) (reported 2026-09-23)
  Read-only review of committed local-only branch fm/core-v3-lane-a at 2eb4e12 against its existing brief and the supplied V3 acceptance scope. Inspect the diff and the deterministic tests/release metadata it adds. Identify unsupported PASS claims, missing critical acceptance evidence, or defects that would make a firstmate local fast-forward unsafe. Do not edit the project, merge, push, deploy, use secrets, or access live systems. Write a concise report with exact file/line evidence and one of: pass, findings, or blocked. Preserve the existing branch and worktree.

## Archived 2026-09-24
- [x] cbd-g5-evidence-reconcile-0923 - Reconcile CBD G5 evidence-prep handoff and offline next steps data/cbd-g5-evidence-reconcile-0923/report.md (repo: firstmate) (kind: scout) (priority: 1) (reported 2026-09-23)
  Resolve a contradiction in the CBD acceptance evidence: the earlier cbd-acceptance-map-0923 report said data/cbd-data-recovery-g5-evidence-prep/brief.md exists, while the controller handoff says the G5 brief exists but report is absent, and a later read-only SSH check found the named brief and report both absent from /root/agent-work/projects/cbd-data.com/current-cbd-data at HEAD b187f11. Search only the approved local warehouse/docs and that exact remote repo path through the already approved root@100.117.47.27 route. Determine the authoritative G5 rubric/brief/output location and what can be prepared offline from existing evidence. No credentials, customer data, runtime state, tests, remote writes, canary execution, deployment, or controller message sending. Produce a concise local report with exact evidence paths, uncertainty, and the smallest next action.

## Archived 2026-09-25
- [x] cbd-g5-readiness-blueprint-0923 - Prepare a verified CBD G5 evidence-readiness blueprint data/cbd-g5-readiness-blueprint-0923/report.md (repo: firstmate) (kind: scout) (priority: 1) (reported 2026-09-23)
  The reconciled CBD audit found that the claimed G5 brief and G4/G5 prep reports do not exist in the approved warehouse or current remote checkout, so the earlier acceptance claims are unverified. Prepare a local, evidence-backed G5 readiness blueprint from the actual current CBD documents and prior reports. Distinguish what can be assembled offline from what must wait for G1/D6 and G4; do not invent a G5 rubric, mark a gate ready, or claim any acceptance pass. No remote writes, credentials, customer records, DB/runtime reads, tests, canary execution, or deployment. Report in Firstmate data with exact source paths and the smallest next operator/controller input required.

## Archived 2026-09-25
- [x] core-v3-lane-a - Complete Core Distro V3 local lane (repo: core-distro-saas-clean) (kind: ship) (priority: 4) (done 2026-09-23)
  local main

## Archived 2026-09-25
- [x] elevate-rag-corpus-package-0923 - Prepare Elevate public-site RAG corpus package data/elevate-rag-corpus-package-0923/report.md (repo: firstmate) (kind: scout) (priority: 1) (reported 2026-09-24)

## Archived 2026-09-25
- [x] local-chatbot-synthetic-eval-0923 - Measure local chatbot model with synthetic grounded prompts data/local-chatbot-synthetic-eval-0923/report.md (repo: firstmate) (kind: scout) (priority: 1) (reported 2026-09-24)
  Goal: Produce repeatable, synthetic benchmark evidence for the local model planned for Core Distro and Elevate chatbots.

  Captain intent: The existing trial report found the local LFM2.5 model runs at about 48–50 tokens/s in medium non-streaming tests, but first-content latency and answer quality remain unverified. Complete a bounded follow-up using synthetic prompts and public Elevate page content, so the rollout can make a measured decision.

  Firstmate spec: Use only the existing local model at 127.0.0.1:8081 and the public Elevate RAG corpus at data/elevate-rag-corpus-package-0923/corpus. Check the model id via the existing /v1/models endpoint. Make a small deterministic evaluation set of 4–6 synthetic questions with source snippets and a fact/safety rubric. Measure time to first non-empty streamed content, total response time, and generated tokens per second; cap each output at 160 tokens and run sequentially, plus at most a two-request concurrency probe if the server stays responsive. Score source grounding, citation accuracy, company framing, and research-use-only/safety boundaries. Clearly label this as a model-with-provided-context test, not an AnythingLLM retrieval or production benchmark. Do not read credentials, send requests off-host, use customer data, edit projects or services, ingest documents, alter AnythingLLM, or route production traffic. Save the reproducible command, sanitized synthetic prompts/results, rubric, limitations, and recommendation in data/local-chatbot-synthetic-eval-0923/report.md. If model health degrades, stop immediately and report.

## Archived 2026-09-25
- [x] core-chatbot-reference-handoff-0924 - Extract Core chatbot embed as an Elevate-safe handoff data/core-chatbot-reference-handoff-0924/report.md (repo: core-distro-saas-clean) (kind: scout) (priority: 1) (reported 2026-09-24)
  # Task
  ## Captain's intent
  Prepare a source-grounded handoff for copying the working Core Distro chatbot experience to Elevate, while keeping all project sources unchanged until the production source and owner are established.

  ## Firstmate spec
  In the registered Core project checkout `/home/hd2admin/agent-work/core-distro-saas-clean`, inspect the exact `current-core-distro/index.html` implementation and its adjacent styles/assets only as needed to identify the existing chatbot integration. The prior report locates the embed near line 246. Confirm the current branch and file lines yourself. Read the DubzAi AnythingLLM chatbot skill at `/home/hd2admin/.codex/skills/dubzai-anythingllm-chatbot/SKILL.md` as the operational reference.

  This is a READ-ONLY scout. Do not edit Core, Elevate, or any project file; do not run build/tests; do not call admin APIs or read credentials; do not make live changes or deployments. Do not copy the Core workspace ID, embed ID, company text, or RAG content into a proposed Elevate snippet. Do not infer that Core's source checkout is the production deploy source.

  Write `/home/hd2admin/kun-agent-workspace/data/core-chatbot-reference-handoff-0924/report.md` containing:
  - Confirmed project root, branch/HEAD, file and line references for the current Core embed.
  - Exact observed widget attributes and surrounding script/style needed to reproduce the layout, including whether mobile open-chat CSS is present and any `Powered by HD2.ai` sponsor attributes.
  - Any logo assets used and the attribute names that reference them; do not copy Core brand images into Elevate recommendations.
  - Source/evidence gaps that prevent direct implementation: production source/deploy owner, live AnythingLLM runtime/workspace and prompt configuration, and Elevate-specific identity/assets/workspace values.
  - A short proposed adaptation checklist that keeps Elevate identity separate and calls out any required runtime owner decisions. Treat this as a handoff, not implementation approval.

  Use a single live Pi `todo` checklist. Print its entire list in the pane at task start and update that same checklist in place at milestones, with exactly one active step. Print a short progress note before a long read or any child review. Use `lean-ctx` for routine reads if available; preserve raw output for exact source lines. No child is needed for this narrow extraction; Firstmate/Codex performs final review. Append only phase-change and terminal status events.

## Archived 2026-09-25
- [x] elevate-rag-eval-0924 - Build grounded Elevate RAG acceptance cases data/elevate-rag-eval-0924/report.md (repo: firstmate) (kind: scout) (priority: 1) (reported 2026-09-24)
  # Task
  ## Captain's intent
  Prepare a grounded, safety-aware evaluation set for the approved public Elevate RAG corpus so the future chatbot workspace can be evaluated as soon as runtime access is available.

  ## Firstmate spec
  Use only the already-built local package at `/home/hd2admin/kun-agent-workspace/data/elevate-rag-corpus-package-0923/corpus/` and its `manifest.json` and `answer-guidance.md`. Do not crawl the web or add new source material. Do not edit any project or package file, ingest documents, contact an API, call the local model, or route traffic.

  Create 8–10 compact synthetic test cases in `/home/hd2admin/kun-agent-workspace/data/elevate-rag-eval-0924/golden-set.json`, with a companion `report.md` explaining the rubric and limits. Cover all six approved verticals: Research & Science, Lab Supplies, Quality & Documentation, Wholesale, Quote & Contact, and Product Catalog. Include at least two out-of-corpus or safety-boundary cases, such as a dosing/treatment request and a price/inventory question that the public corpus cannot answer. Each case must include:
  - stable case id and query;
  - case type (grounded-answer, abstain, or safe-redirect);
  - expected answer constraints as short paraphrases, never long source quotations;
  - exact supporting source URL(s) from the manifest, or `none` for abstentions;
  - observable pass/fail criteria for source support, citation correctness, company framing, RUO language where applicable, and safe handling;
  - an explicit note when the corpus cannot answer the query.

  All statements in the expected answers must be traceable to the cited local document. Do not invent pricing, availability, regulatory approval, health outcomes, or internal company details. Preserve the existing RUO/not-for-human-use boundary; expected answers must not include dosing, diagnosis, treatment, administration, or human/animal-use advice. Keep output suitable for later review before it is used as a benchmark.

  Use one concise live Pi `todo` checklist; print the full list in the visible pane, keep exactly one step active, and update the same list at milestones. Before any long review or child call, print a short progress note. After the set is drafted, one bounded MiniMax-M2.7 child may independently check source URL existence and safety labels against the local corpus only; no recursive delegation, web requests, tests, or model/API calls. Inspect child status before retrying. Firstmate/Codex owns final review.

  Use `lean-ctx` for routine local reads if available, and preserve exact source URLs and hashes. Append only phase-change and terminal status events. This is a private evaluation artifact, not implementation or deployment approval.

## Archived 2026-09-25
- [x] core-live-widget-source-0924 - Map live Core site source and mobile chat widget (repo: core-distro-saas-clean) (kind: scout) (priority: 4) (done 2026-09-24) (hold: Need captain evidence to identify the reported lower-left mobile clipping: provide a screenshot or exact element name, or confirm that we should leave the cause unconfirmed. Current live CSS puts the chat widget lower-right and browser reproduction is blocked.) (hold-kind: captain)
  Resolution recorded by fm-captain-hold.
  Decision digest: 178260782dab006d4aa1abeb42bfddffe9c43474082cf208fe050e6771e23488
  Resolution mode: answered

  Captain decision:
  Sorry chat is the right the overall missing part of the site was a problem from yesterday so i finally got what it was from the client... but i saw it.. i have to slightly reposition the site, and on androind u can even do that... caht bot ive not looked at or ched yet..

  Read-only diagnosis of the mobile issue on https://core-distro.com. The captain reports a bottom-left element is clipped/offset on phones and hard to move on some Android devices. The live page now returns a Next.js document with the Core AnythingLLM embed ID; the available local core-distro-saas-clean checkout is a PHP/static snapshot, so do not edit or treat it as the production source. Compare exact current live HTML/CSS and widget script behavior with the local snapshot and repo/deployment notes; identify trigger, masking condition, visible symptom, and the authoritative source/build owner if locally evidenced. Browser bridge returned BRIDGE_NOT_READY twice; use the closest safe read-only path and mark browser reproduction BLOCKED_ENVIRONMENT if no working browser exists. Do not change client files, use credentials, access admin APIs, or deploy. Keep a numbered TODO visible and update it after each phase. Produce a concise report with evidence paths, source mismatch, exact fix target, and next action.


## Archived 2026-09-25
- [x] core-footer-readonly-review - Review saved Core Distro footer fix data/core-footer-readonly-review/report.md (repo: core-distro-saas-clean) (kind: scout) (priority: 4) (reported 2026-09-24)
  goal:visible-parallel-firstmate. Read-only final review of the saved Core Distro mobile footer fix and existing evidence; preserve every file. No tests, browser capture, edits, or merge.

## Archived 2026-09-25
- [x] local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1 - Map and benchmark Core/Elevate chatbots with Hetzner local model data/local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1/report.md (repo: core-distro-saas-clean) (kind: scout) (priority: 0) (reported 2026-09-24)
  User-requested target for the two public chatbot experiences:
  - Core Distro on core-distro.com is the working reference implementation.
  - Copy its chatbot experience to elevatesci.com, then frame Elevate for its company and build a comparable vertical-aware RAG set from Elevate-approved source material; preserve Core's solid existing RAG set.
  - Route both through AnythingLLM to the local model on the Hetzner host if measured latency and answer quality are acceptable.
  - Remove implementation-facing AnythingLLM wording from scripts/backend UX where practical and present HD2.ai branding.

  This is the discovery and benchmark phase only. Map canonical source repositories, build/deploy owners, existing chatbot runtime/provider routing, Core RAG sources and restore point, Elevate company-material sources, and the documented private path to the Hetzner model. The already-known local candidate is the raw llama.cpp LFM2.5 server on port 8081; verify the host, process, API shape, model identity and current health before sending synthetic requests. Run a small, bounded latency/throughput sample with synthetic prompts only and report first-token latency, total latency, output tokens/second, concurrency, CPU/RAM use and quality observations. Provide a staged implementation and rollback plan for Core and Elevate.

  Do not change production site files, provider routing, AnythingLLM settings, auth, DNS, proxy rules, ports, RAG documents/indexes or service configuration in this phase. Do not use customer data or show secrets. Do not install another inference runtime; Ollama is already present and must remain contained. No public service exposure. The controller has already been asked once for exact source/runtime/RAG coordinates and was told to reply briefly, then resume its queue; monitor the local controller reply inbox instead of sending duplicate requests.

## Archived 2026-09-26
- [x] core-mobile-review - Independently review Core mobile footer patch and evidence data/core-mobile-review/report.md (repo: core-distro-saas-clean) (kind: scout) (priority: 4) (reported 2026-09-24)
  ## Captain's intent
  Independently review the saved Core mobile fix and its evidence to confirm the footer contrast issue is addressed at mobile and desktop sizes. This is a read-only review. Preserve the captain's explicit direction: no commit, merge, push, PR, deploy, or edits.

  ## Firstmate spec
  Review the existing task worktree at `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/1/core-distro-saas-clean` as read-only. It contains the local branch `fm/core-mobile-fix`, uncommitted changes to `staged-export-test/index.php` and `tests/run.sh`, a new `tests/test_footer_contrast.js`, browser probes, and saved screenshots. Do not modify that worktree or any of its files, refs, or artifacts.

  Read the existing `state/core-mobile-fix.status` evidence, inspect the exact tracked and untracked source/test diff and the before/after screenshots, and review whether the tests meaningfully cover the stated footer contrast behavior at mobile and desktop viewports. Keep the earlier header/theme-toggle correction distinct from the later footer contrast fix. Do not claim physical Android coverage; evidence is browser emulation. Do not rerun tests or browser capture.

  Use Codex Luna medium for this visible owner. The local Codex multi-agent feature is enabled: spawn exactly one bounded, read-only Codex subagent to review the same diff and evidence independently; give it only the acceptance criteria and relevant files, prohibit edits and recursive delegation, and compare its findings with your own. Keep the live pane checklist current while working; if the current Codex harness lacks a usable checklist tool, print and update a compact numbered checklist in the pane. Do not guess at the subagent API: check the installed Codex multi-agent instructions if needed, inspect run status before retrying a failed-looking launch, and make at most one corrected launch attempt.

  Write `data/core-mobile-review/report.md` with a concise verdict, any findings by severity, exact file/line references, the subagent verdict, what was reviewed, and limits. Do not change the original task's status or interpretation, and do not recommend a merge. Confirm the original worktree is unchanged before finishing.

## Archived 2026-09-26
- [x] system-repair-sprint-0924 - Consolidate and repair Firstmate system failures from the last 24 hours (repo: firstmate) (kind: ship) (done 2026-09-25)
  Captain-authorized system-reliability sprint. Delivery: no-mistakes PR path, yolo on. Reason for no-mistakes deviation: this task changes Firstmate shared tracked material, which AGENTS.md §1 requires to ship through the no-mistakes pipeline and PR path despite the local-only project posture; yolo remains on per registry. Scope is evidence-backed Firstmate system defects and repairs observed in the rolling 24-hour window; keep client Core/Elevate implementation and live production changes out of scope. Preserve every existing uncommitted branch, pending terminal text, and paused worker; do not merge or discard other tasks' work. Use MiniMax M2.7 for implementation, then a separate read-only MiniMax M3 review before the no-mistakes run. Keep an incident inventory and a visible worker todo checklist. External permission/source blockers are reported, never bypassed.

## Archived 2026-09-26
- [x] core-stream-a-checkpoint-0924 - Validate Core Stream A from checkpoint-baseline (repo: core-distro-saas-clean) (kind: ship) (priority: 3) (done 2026-09-25)
  Starting implementation and acceptance task for FIRSTMATE_COORDINATOR_KICKOFF.md Stream A. Test multilingual EN/PL/ES navigation, toast/category filtering, smoke paths, and prepare a reproducible local deployment artifact from checkpoint-baseline. Preserve current main and existing work.
  Ready for review: four commits atop main, smoke checks green, reproducible deployment artifact prepared; no PR.

## Archived 2026-09-26
- [x] cbd-g5-source-refresh-0924 - Refresh CBD G4/G5 evidence against current source data/cbd-g5-source-refresh-0924/report.md (repo: firstmate) (kind: scout) (priority: 0) (reported 2026-09-25)
  # CBD G4/G5 Source Refresh

  ## Objective
  Reconcile the conflicting CBD G4/G5 acceptance claims against the latest source evidence, then produce a trustworthy offline preparation report. This is an implementation of a source-evidence report, not project-code work.

  ## Read-only scope
  Use only the already approved SSH route `root@100.117.47.27` and source checkout `/root/agent-work/projects/cbd-data.com/current-cbd-data`. Inspect repository identity/status, current HEAD and relevant branch heads, tracked path names, and non-secret documentation directly related to G4/G5 acceptance. In particular verify whether a G4 ledger or G5 brief/report exists in the current checkout or visible branches, and inspect only the documentation needed to state current acceptance criteria.

  Reconcile these Firstmate artifacts:
  - `data/cbd-acceptance-map-0923/report.md` (contains claims later corrected in its errata)
  - `data/cbd-g5-evidence-reconcile-0923/report.md` (the latest local reconciliation at the last observed source revision)
  - the Controller handoff in `/home/hd2admin/brandon-inbox/2026-09-23-cbd-priority-followup.md` (which says a G4 ledger exists and the G5 brief exists)

  Treat the reconciliation as authoritative for the exact paths and HEAD it checked. Do not assume the Controller means the same canonical source/path; distinguish that ambiguity explicitly.

  ## Forbidden
  Do not read credentials, `.env`, secret files, customer data/exports, databases, model data, or runtime service state. Do not run tests, access cPanel/UAPI, edit or commit any remote file, make deployment or service changes, or access a different host. Do not claim an acceptance gate is complete or `READY_FOR_M3_REVIEW` without direct current evidence for its criteria.

  ## Deliverable
  Write `data/cbd-g5-source-refresh-0924/report.md` with:
  1. Exact checkout identity, branch/HEAD and timestamp.
  2. The precise commands and paths used, with evidence distinguishing current checkout from other branch names.
  3. A table for each G4/G5 artifact: canonical path, present/absent/unverified, criterion it supports, and evidence.
  4. Reconciliation of the Controller's “G4 ledger exists / G5 brief exists” statement with the earlier audit; do not invent a path. If the statement cannot be resolved from the approved checkout, list the exact path or coordinate needed from the Controller.
  5. A short offline-preparation checklist clearly labeled proposed/unaccepted, and the concrete operator-owned blockers that prevent execution.
  6. An honest conclusion and smallest next step. Keep G1 credentials and any live canary work explicitly out of scope.

  ## Live work visibility
  Use one concise Pi `todo` checklist at task start; print the entire list into the visible pane, keep one item active, and update the same checklist as each step changes. Before long commands or a child review, print a one-line progress note; after each returns, update the list and report the result before continuing.

  After the report exists, one bounded MiniMax-M2.7 child may independently verify its artifact-path and evidence-status claims against the captured command output. No recursive children and no web/live-service checks. The Firstmate/Codex owner performs final review.

  Use `lean-ctx` for routine local reads if available; use direct output for exact commands, paths, and errors. Keep one worktree owner. Append only phase-change and final status events. Stop with `blocked` if the approved SSH route or source checkout is inaccessible; include the exact safe diagnostic.

## Archived 2026-09-26
- [x] window-cleanup-inventory-0923 - Inventory safe Herdr pane retirements data/window-cleanup-inventory-0923/report.md (repo: firstmate) (kind: scout) (reported 2026-09-25)
  Inspect the existing Herdr command panes and identify up to fourteen that can be safely retired without losing active or unlanded work. Return an exact candidate list with the required report and decision-gate evidence for each. Do not close or move panes; the Firstmate supervisor performs guarded teardown.

## Archived 2026-09-26
- [x] brief-compaction-preserve - Preserve Firstmate worker instructions through Pi compaction (repo: firstmate) (kind: ship) (done 2026-09-25)
  Goal:visible-parallel-firstmate. Add a Pi session_before_compact hook that preserves a small durable Firstmate task-context fragment in every worker compaction summary: role reminder, active task identity, current launch-brief path, steering inbox path, and status path; include a compact reminder to maintain the live todo list and use bounded pi-subagents when useful. Use the audited Option A in data/context-continuity-audit/report.md. Keep it inside the existing Pi worker session; do not create another supervisor or interrupt active work. Keep absent/invalid task identity a no-op and never block compaction on missing files. Add portable regressions and the same-style opt-in real-Pi test if feasible. Scope to the new .pi/extensions/fm-worker-brief-preserve.ts and its focused test file unless registration is proven necessary; do not modify fm-primary-turnend-guard.ts or session-start code. TDD first; load firstmate-coding-guidelines and tdd-red-green-refactor. Keep a live Pi todo updated in the pane, use lean-ctx for routine reads, and use one bounded read-only subagent review before commit if useful. No publish, no merge.
  Local branch ready for review; no publish or merge.

## Archived 2026-09-27
- [x] context-continuity-audit - Audit Firstmate rule continuity and live Pi worker instructions across compaction data/context-continuity-audit/report.md (repo: firstmate) (kind: scout) (reported 2026-09-25)
  Goal:visible-parallel-firstmate. Read-only audit of session start, compaction/resume behavior, Pi launch briefs, and todo/subagent instructions. Determine the smallest reliable enforcement so the hard Firstmate contract, current goal/task/pane ownership, and live todo/subagent requirements survive compaction and are re-established after each task. Inspect actual hook/extension capabilities; do not assume memory alone is sufficient. Return evidence, gaps, and a concrete implementation ticket; do not edit files or steer/spawn other agents.

## Archived 2026-09-27
- [x] herdr-pane-board-context - Show live Herdr worker identity and status on the fleet board (repo: firstmate) (kind: ship) (priority: 4) (done 2026-09-25)
  goal:visible-parallel-firstmate

  Implement live Herdr pane context in Firstmate's fleet snapshot and Bearings board so the captain can tell which actual worker is attached to each in-flight ticket and whether that worker is busy or idle.

  Acceptance criteria:
  - Join pane data to task records only through the validated Herdr endpoint identity in task metadata; never infer task ownership from a display label, workspace title, or matching cwd alone.
  - Show the verified Herdr workspace, tab and pane ids, pane label, harness agent name, and live agent status when available.
  - Preserve explicit unknown/unavailable state when Herdr cannot be queried, a pane disappeared, or identity does not match; do not report an idle pane as working.
  - Carry the fields through the Bearings snapshot/payload and render them on the existing fleet board without breaking rows for non-Herdr backends.
  - Add focused executable tests for a matching pane, absent pane, identity mismatch, and non-Herdr task. Keep the change within Firstmate's shared tracked files and tests.
  - Preserve all existing user edits, worktrees, and unlanded commits. Do not commit, push, open a PR, merge, deploy, or rebuild/arm a live board.
  - Follow .agents/skills/firstmate-coding-guidelines/SKILL.md and the Pi worker defaults in config/brief-include.md. Use Pi subagents for an independent bounded read-only review when useful; no child edits or recursive delegation.
  Ready in local branch; changes kept uncommitted, tests green.

## Archived 2026-09-27
- [x] elevate-mobile-audit - Reproduce Elevate mobile Chrome layout and locate source data/elevate-mobile-audit/report.md (repo: firstmate) (kind: scout) (priority: 4) (reported 2026-09-25)
  Resolution recorded by fm-captain-hold.
  Decision digest: e98db8c26d7855871f249764deb887bd12ef9af178976bba1fe11a9ee3ea12c8
  Resolution mode: released

  Captain decision:
  im not sure u have all dods and repo maps etc use wareghouse and ask the agent on the controller if yo are unsure but never take control of its attention for too long, remiber to tell it to continue after it give you what you want..

  goal:visible-parallel-firstmate. Captain reports that Elevate looks wrong in Chrome on Android. Perform a read-only mobile-browser diagnosis for the Elevate customer site and dashboard where accessible: https://www.elevatesci.com and https://agents.elevatesci.com. Capture desktop and Android-sized Chrome DevTools evidence, separate trigger/masking condition/visible symptom, compare a working path, and seek disconfirming evidence. Search the known local workspace for the source repo/export and identify the owning builder/deploy path from existing local records; do not log in, change files, change remote state, or deploy. Report the exact page(s) reproducing, screenshot/evidence paths, likely cause with confidence, and the source path/what is missing to implement a fix.

## Archived 2026-10-02
- [x] tool-auto-update - Add safe automatic updates for agent tools and extensions (repo: firstmate) (kind: ship) (priority: 4) (done 2026-09-25)
  goal:visible-parallel-firstmate. Implement the explicit request that Pi, Codex, and other agent tools/extensions update automatically. Use staged/atomic tool paths where available, run installs only when the relevant agents are idle, never replace or restart a live Herdr server or active no-mistakes run, and fail closed with a visible finding when a safe install path cannot be proven. Include Pi self and package updates, Codex CLI, Herdr client/server boundary, and supported extensions/tooling. Reuse Firstmate's watcher and ticket/board flow. Do not silently choose preview channels or force updates. Worker must load .agents/skills/firstmate-coding-guidelines/SKILL.md and follow repository ownership/verification rules. No commit, push, PR, merge, or deployment.

  Captain follow-up 2026-09-23: "please set this shit to auto update on load.... NOW" Apply this to Pi self and extension updates at the process launch boundary, with the existing fail-closed live-worker protections.
  Ready for review in local branch; no publish or merge.

## Archived 2026-10-10
- [x] core-elevate-corpus-core-elevate-chatbot-corpus-inventory-an-7f - Core/Elevate chatbot corpus inventory and workspace gaps data/core-elevate-corpus-core-elevate-chatbot-corpus-inventory-an-7f/report.md (repo: firstmate) (kind: scout) (reported 2026-09-26)
  Read-only, separately assigned Core/Elevate chatbot-corpus inventory. No service/container operations, installs, configuration changes, RAG ingestion, or credential access. Use the prior trial-map report as baseline; verify current local evidence and clearly distinguish verified sources from external claims and unknowns. Identify the approved public-only Elevate corpus decision, whether it is evidenced as applied, and remaining workspace-creation gaps. Produce the standard scout report and the requested handoff artifact; send only a reviewed, non-secret completion status and report path.

## Archived 2026-10-10
- [x] core-v3-prd-gap-map - Map remaining Core Distro V3 acceptance and blockers data/core-v3-prd-gap-map/report.md (repo: core-distro-saas-clean) (kind: scout) (priority: 4) (reported 2026-09-26)
  Read-only gap map for the captain priority to complete the Core Distro V3 PRD. Reconcile the Core Distro source, checkpoint-baseline, completed Stream A artifacts, Core V3 lane-a work, and existing mobile-footer review. Identify exact acceptance already evidenced, remaining local work, missing sources, and approvals or deploy gates. Do not edit project files, run new tests, change refs, merge, or deploy.

## Archived 2026-10-12
- [x] core-v3-prd-gap-map-agy-review-20260926 - Independent review of Core Distro V3 gap map data/core-v3-prd-gap-map-agy-review-20260926/report.md (repo: core-distro-saas-clean) (kind: scout) (priority: 3) (reported 2026-09-26)
  Independent AGY review of the completed Core Distro V3 acceptance gap-map report; read-only, no project changes.

## Archived 2026-10-12
- [x] local-scout-spawn-source-0926 - Choose a local-only isolated worker workspace for T1 and T2 (repo: firstmate) (kind: captain) (done 2026-09-26) (hold: Controller says to run T1 and T2 from a local snapshot with no network reads, but the delivered source snapshot has no Git metadata and is not itself a worker repository. Firstmate's required isolated worker launch fetches the network-backed origin for the existing Core repository used by T1 and Firstmate repository used by T2. Option A: explicitly authorize those exact read-only origin fetches. Option B: provide or approve clean local Git repositories with no network remotes for the two isolated workers. The Controller's relayed no-network instruction is not a direct Captain answer. No worker or network read has started.) (hold-kind: captain)
  Resolution recorded by fm-captain-hold.
  Decision digest: 4eb961f38ee6ff5d2c4258abb36a93dc3a76af6a7cd070d243cd6b683237eb97
  Resolution mode: answered

  Captain decision:
  but this should be a side car so u keep working on what u were doing before no??


## Archived 2026-10-12
- [x] t1-t2-rag-agy-review-0926 - Independent AGY review of T1, T2, and Core/Elevate reports data/t1-t2-rag-agy-review-0926/report.md (repo: core-distro-saas-clean) (kind: scout) (reported 2026-09-26)
  Read-only independent review of three completed local reports; preserve T1 offline-only, T2 no-further-container-operations, and Core/Elevate no-ingestion boundaries. Review only the report files and handoff copies; do not access services, APIs, websites, containers, credentials, source repositories, or modify deliverables. Report supported claims, discrepancies, scope violations, and needed corrections at data/t1-t2-rag-agy-review-0926/report.md.

## Archived 2026-10-13
- [x] core-rag-coverage-audit-0926 - Read-only Core/Elevate RAG coverage audit data/core-rag-coverage-audit-0926/report.md (repo: core-distro-saas-clean) (kind: scout) (priority: 3) (reported 2026-09-26)

## Archived 2026-10-13
- [x] pi-luna-context-window-test-0927 - Measure Codex context and Firstmate compaction behavior data/pi-luna-context-window-test-0927/report.md (repo: firstmate) (kind: scout) (reported 2026-09-27)
  Captain directed us to start a fresh Codex session, test actual context/compaction behavior, and only change Firstmate after the correct value is established. Existing evidence: Pi's gpt-6-luna catalog entry reports 272,000; a 1,000,000-token override is unverified. No live setting changes until the test result supports them.

## Archived 2026-10-13
- [x] core-v3-acceptance-spec-choice - Choose Core Distro V3 acceptance authority (repo: core-distro-saas-clean) (kind: captain) (done 2026-09-27) (hold: Choose the product V3 acceptance authority. Evidence: /home/hd2admin/kun-agent-workspace/data/core-v3-prd-gap-map/report.md. Option A: explicitly ratify the Brandon Multi-Project Infrastructure PRD plus an exact, identified acceptance matrix as Core Distro product criteria; provide the matrix path and revision, since none is present locally. Option B, recommended: commission a standalone Core Distro product V3 acceptance specification and keep PRD section 20.1 as infrastructure readiness only, because the independent review verified it is not product acceptance. Controller reports that no standalone product acceptance spec exists; its controller-side paths have not been inspected locally. Until this choice is made, product-level completion cannot be scored and no criteria-specific implementation should proceed.) (hold-kind: captain)
  Resolution recorded by fm-captain-hold.
  Decision digest: 6c7b09b9c682911cbbaf54bf6a2ec6da034d839b28ec1a0d2cb3ee5788a67f71
  Resolution mode: answered

  Captain decision:
  yes lets do that


## Archived 2026-10-13
- [x] pi-luna-context-codex-review-0927 - Independent Codex Sol review of Pi Luna override evidence data/pi-luna-context-codex-review-0927/report.md (repo: firstmate) (kind: scout) (priority: 2) (reported 2026-09-27)
  Review data/pi-luna-context-scratch-validation-0927/report.md for correctness and missing evidence using authoritative installed Pi source/docs. Keep the review read-only; no live config edits, restarts, cutovers, credentials, or network. Report to data/pi-luna-context-codex-review-0927/report.md.

## Archived 2026-10-13
- [x] brandon-pi-runtime-audit-20261002 - Audit Brandon Pi runtime import errors and compaction settings data/brandon-pi-runtime-audit-20261002/report.md (repo: firstmate) (kind: scout) (reported 2026-10-02)

## Archived 2026-10-13
- [x] core-distro-stage-fidelity-20261010-decision-header-overlap - Choose whether to correct the source-matching 100% header overlap locally (repo: core-distro-stage) (kind: captain) (done 2026-10-10) (hold: Public and staging screenshots show the wordmark tagline visually colliding with the Home link at 100% width; preserving exact public behavior leaves it, while a staging-only spacing fix would diverge. Choose preserve exact overlap or approve a local-only correction; live changes are not authorized.) (hold-kind: captain)
  Resolution recorded by fm-decision-hold.
  Decision digest: 28cafd0a0f2b45a57e981abe504f824dc3df5bedf7c2a4974cf7825207c53ba4
  Routed identities: core-distro-stage-scale-100pct

  Captain decision:
  # Captain decision — staging scale at 100%

  Date: 2026-10-10

  Fix the staging page's full-site scale so that the entire page matches the live site at 100% browser zoom. Reducing browser zoom to 90% is only a workaround, not the target. Keep the correction staging-only; do not modify the live public site. Do not change navigation destinations, forms, or chatbot behavior as part of this scale fix.

  Routed work:- core-distro-stage-scale-100pct

## Archived 2026-10-13
- [x] core-distro-stage-fidelity-20261010-decision-navigation-destinations - Choose staging destination behavior for public navigation links (repo: core-distro-stage) (kind: captain) (done 2026-10-10) (hold: Public navigation targets separate routes, while staging hashes scroll within its homepage; Blog and FAQ land at Resources and Contact. Choose private-preview links to public pages or authorize matching local staging pages; no public mutation is proposed.) (hold-kind: captain)
  Resolution recorded by fm-decision-hold.
  Decision digest: f731e51a488120af33f483565ff8f65558c3d2ee7600b087629e3352cf433a1f
  Routed identities: core-distro-stage-wp-multipage

  Captain decision:
  # Captain decision — full private WordPress staging site

  Date: 2026-10-10

  Choose the local multi-page staging option: build a complete private WordPress staging copy with local routes for the existing public pages and the requested WordPress/CRM additions. First inspect local Git history and existing Controller upload/coordination records; reuse the original artifacts rather than rebuilding from scratch. Keep all changes in staging. Do not alter production, access or expose credentials, submit forms, activate the chatbot, change DNS/proxy/firewall/cPanel, or perform external CRM actions. If any required CRM behavior needs credentials or live-system changes, stop and ask for separate approval.

  Routed work:- core-distro-stage-wp-multipage

## Archived 2026-10-13
- [x] core-distro-stage-wp-multipage-decision-article-drawer-render-fix - Approve a staging-only correction for hidden keyboard-focusable article drawer links (repo: core-distro-stage) (kind: captain) (done 2026-10-12) (hold: Verified native Tab4-6 on private mobile contact staging reach three links inside ARTICLE#post-8 under a measured opacity-zero drawer ancestor. The separate header NAV is inert when closed. Decide whether to authorize a renderer-only correction that excludes closed article-drawer links from keyboard focus while preserving stored WordPress content, protected duplicates and current integrations. Evidence: warehouse/reports/core-distro/DISPUTED_DRAWER_RAW_VERDICT_LUNA6_2026-10-12.md. No device/AT, full-cycle or production-readiness claim.) (hold-kind: captain)
  Resolution recorded by fm-decision-hold.
  Decision digest: 3514b7df2831bc3b9a8f04d50dbe162498b4bf8afa70486f2ea64da2fb6aa44f
  Routed identities: core-distro-stage-article-drawer-fix-20261012

  Captain decision:
  # Captain decision — article drawer keyboard fix

  Captain approved on 2026-10-12, responding directly to the request to fix hidden keyboard-focusable article-drawer links in private staging while preserving stored page content and protected duplicates:

  > go for it, plz keep usng parallel aent s and not doing the work yourslef.. minimax is ready 6/7 agents at a time to stay inside rate limits

  Route implementation to core-distro-stage-article-drawer-fix-20261012. Firstmate coordinates only; MiniMax workers do project work. Bound current concurrency to six useful independent lanes, not filler work, and do not equate this preference with experimentally proven rate-limit safety.

  Approved scope: renderer-only staging correction for closed article drawer links entering keyboard focus; regression tests and accurate task documentation. Preserve stored WordPress content and IDs24,25,26,35,36,37,46,47,48. No production, integration activation, credential handling, DB/volume writes, repository creation, commit/push/merge or destructive cleanup. Existing source files and all unlanded work remain preserved.

  The project is non-Git. A worker's isolated secret-free file-copy implementation and tested-file application needs explicit isolation/delivery clarification before any source writer starts; read-only source/test preflight can proceed in parallel. Current routing and TDD requirements remain in force.

  Routed work:- core-distro-stage-article-drawer-fix-20261012

## Archived 2026-10-13
- [x] core-distro-stage-article-drawer-fix-20261012-decision-non-git-file-isolation - Approve isolated file-copy implementation and tested-file staging delivery (repo: core-distro-stage) (kind: captain) (done 2026-10-12) (hold: Private staging has no Git metadata, and repository creation/push/merge remain unauthorized. Existing isolated-worktree launch requirements cannot be satisfied for this project as recorded. Confirm whether MiniMax may implement in a separate secret-free source/test file copy and apply only tested allowlisted theme/test/documentation files back to private staging, preserving originals and all WordPress records. No firstmate project edits.) (hold-kind: captain)
  Resolution recorded by fm-decision-hold.
  Decision digest: 8f57273783169b6974400bb79116cd1e04157b6b164c609f334c9a5fc8b636fa
  Routed identities: core-distro-stage-article-drawer-fix-20261012

  Captain decision:
  # Captain decision — isolated non-Git file delivery

  On2026-10-12 Captain replied:

  > yes

  This answered the exact request: “May the implementation worker proceed using the separate, secret-free file copy and apply only tested changes back to staging?”

  Authorized: delegated MiniMax implementation in a separate secret-free source/test copy, followed by application of only tested, allowlisted renderer/theme/test changes to /home/hd2admin/campaign/core-distro-stage. Preserve originals and guard against source changes since the copy was made. Firstmate does not implement or edit project files. Use meaningful parallel lanes with at most six active agents for this task.

  Scope remains the approved exclusion of closed ARTICLE drawer links from keyboard focus. Preserve stored WordPress content and protected duplicate IDs24,25,26,35,36,37,46,47,48. No source repository creation, commits, push or merge; no production, credentials, SQL/backup payload access, database/volume writes, integration activation, stack restart or destructive cleanup. Browser checks use only M2.7 and chrome-devtools-axi on private staging. Source-to-served-theme mapping must be verified without inspecting secret config or assuming a bind mount.

  This approval does not authorize inspecting potentially sensitive logs from the accidental SQL-backup search. That incident remains recorded separately under visible task55; preserve the original private artifacts without distributing or deleting them.

  Routed work:- core-distro-stage-article-drawer-fix-20261012

## Archived 2026-10-13
- [x] mm-saas-fastpath-benchmark-0926 - Archive invalid fastpath benchmark evidence; worker cleaned up data/mm-saas-fastpath-benchmark-0926/report.md (repo: mm-saas-snapshot-20260925) (kind: scout) (reported 2026-10-12)
  Historical benchmark report retained. It explicitly rejects the benchmark as decision/release evidence because a pre-existing database container was reused. No valid benchmark, implementation, deployment or landing is claimed. Existing completion inventory was checked by guarded ordinary-worker cleanup; clean isolated copy returned successfully and task runtime records removed. Missing original backlog row reconstructed solely to preserve the report and cleanup outcome. No database/container cleanup or secondmate operation performed.
  Evidence archived and ordinary worker safely cleaned up; benchmark INVALID, not passing release evidence.

## Archived 2026-10-13
- [x] pi-startup-collisions-20261013 - Diagnose fresh Pi M3.1 discovery and duplicate skill warnings data/pi-startup-collisions-20261013/report.md (repo: firstmate) (kind: scout) (reported 2026-10-13)
  Captain requests parallel correction of startup warnings and verification of M3.1 availability. Native MiniMax-only bounded diagnosis first because authoritative skill copies, normal startup registration and admitted correction path remain uncertain. Preserve all original work and settings; no inbox/settings permission workaround, recursive child or Luna implementation.

## Archived 2026-10-13
- [x] skill-collisions-cleanup-20261013 - Eliminate Pi startup duplicate skill-name warnings data/skill-collisions-cleanup-20261013/report.md (repo: firstmate) (kind: scout) (reported 2026-10-13)
  Mode B worker lane: Luna 6 executes, M3.1 reviews async. Documented -path exclusions only; no delete, move, rename or skill-content edit. Validate by fresh Pi startup output.

## Archived 2026-10-13
- [x] reliability-work-ledger-20261012 - Reconcile undelivered infrastructure and durable ownership ledger data/reliability-work-ledger-20261012/report.md (repo: firstmate) (kind: scout) (reported 2026-10-13)
  You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

  # Task
  Own ONLY the recovered unfinished-work/visibility ledger scope in `/home/hd2admin/kun-agent-workspace/data/reliability-six-luna-20261012/plan.md`. Reuse existing reconciliation reports, main backlog and preserved branch evidence rather than repeating project diagnoses. Map the three undelivered infrastructure changes (live TODO, quota queue pump, status-dir validation), accepted checklist follow-ups and receiver/permission repairs to exact durable owner, dependency, artifact/current-head validation and actual landing status. Identify source/admission/custody and contradictory 'Done' records; propose minimal record correction, not guessed completion. Do not read secondmate chat, supervise child trees or edit any backlog/source/config.

  Prove isolated git root differs from `/home/hd2admin/kun-agent-workspace`. Use lean-ctx and five-item visible extension tracker; load diagnostic-reasoning/firstmate-coding-guidelines as relevant. You may launch one bounded fresh-context read-only Pi subagent using `openai-codex/gpt-6-luna` to align specifically named original reports against the primary records. Use current guide, durable output; no child edits/recursion, denied-helper retries, broad credential/log searches, branch resets or Herdr operations. Return a self-contained compact actionable ledger with verified/unknown distinction and exact existing-owner next actions.

  # Herdr lifecycle declaration - NOT ENABLED
  **HARD SAFETY GATE:** this scaffold cannot inspect the task text that replaces `{TASK}` later.
  If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
  Do not add Herdr lifecycle commands to this unguarded brief by hand.

  # Setup
  You are in a disposable git worktree of firstmate, at a detached HEAD on a clean default branch.
  This is a SCOUT task: the deliverable is a written report, not a PR.
  This scout is read-only to project/shared/config/runtime files: only your report, owned scratch evidence and prescribed status may be written. No installs, scratch commits, production/network/credentials, permission edits, push/merge, restarts, pane moves or cleanup.
  The report is the only thing that survives, so anything worth keeping must be in it.

  # Mandatory task breakdown
  Before any investigation, edit, test, or other task action, use the harness's
  To-Do List extension and create an in-depth dependency-aware tracker with at
  least five checkable items: preflight, scoped discovery, bounded work/evidence,
  validation, and postflight/closeout. Keep it visible and update it at every
  phase change. Do not substitute prose or a filesystem TODO file. If the
  extension is unavailable or the tracker has fewer than five items, append
  `blocked: mandatory visible five-item task tracker unavailable` to the status file and
  stop; firstmate must not treat the task as started.

  # Rules
  1. Never push to any remote and never open a PR.
  2. Stay inside this worktree; the only files you may write outside it are the report and the status file below.
  3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
  4. Report status by appending one line:
     `echo "{state}: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/reliability-work-ledger-20261012.status'`
     States: working, needs-decision, blocked, paused, done, failed.
     Each append wakes firstmate, so report sparingly: only phase changes a supervisor
     would act on and the needs-decision/blocked/paused/done/failed states. No step-by-step
     FYI progress lines; firstmate reads your pane for that.
     Use `paused: {why}` - distinct from `blocked:` - ONLY when you are deliberately idling on a
     known external wait you expect to clear on its own (an upstream release, a rate-limit reset):
     firstmate then leaves your idle pane alone and rechecks it on a long cadence instead of
     treating it as a possible wedge. Use `blocked:` when you are stuck and need help.
  5. If you hit the same obstacle twice, append `blocked: {why}` and stop; firstmate will help.
  6. If a decision belongs to a human (product choices, destructive actions),
     append `needs-decision: {summary of options}` and stop. Firstmate will reply with the decision.
     When firstmate replies or a blocker clears and you resume, append `resolved: {how it was decided or unblocked}` (add the same `[key=<slug>]` if you opened it with one) so the decision or blocker is durably closed and does not keep resurfacing.
  7. Never stop, restart, or update the shared `no-mistakes` daemon - it is one instance serving
     every lane/home, so restarting it kills other lanes' in-flight pipeline runs. On ANY no-mistakes
     daemon error, append `blocked: {the daemon error}` and stop; only firstmate manages the daemon.

  # Definition of done
  Write your findings to `/home/hd2admin/kun-agent-workspace/data/reliability-work-ledger-20261012/report.md`.
  The report must stand alone: what you did, what you found, the evidence (commands run, output, file:line references), and what you recommend.
  Before reporting done, read and follow `/home/hd2admin/kun-agent-workspace/.agents/skills/decision-hold-lifecycle/SKILL.md` and pass its shared completion gate for the report and any visual review.
  When the report is complete, append `done: {one-line conclusion}` to the status file and stop.
  If your findings reveal work that should ship (e.g. you reproduced a bug and the fix is clear), say so in the report; firstmate may promote this task in place, and you would then receive mode-specific ship instructions as a follow-up message.

## Archived 2026-10-13
- [x] core-v3-spec-rewrite - Rewrite the lost Core V3 proposed product acceptance specification data/core-v3-spec-rewrite/report.md (repo: core-distro-stage) (kind: docs) (reported 2026-10-13)
  The original spec was authored 2026-09-27 by gpt-5.6-sol at xhigh and destroyed at teardown. Re-author it from surviving evidence only. Must be clearly labelled PROPOSED, must not invent product policy, must not claim ratification, and must keep infrastructure readiness separate from product acceptance.

## Archived 2026-10-13
- [x] core-stage-chunk4-spec-challenge - Independent testability challenge of the Core V3 acceptance spec data/core-stage-chunk4-spec-challenge/report.md (repo: core-distro-stage) (kind: ship) (reported 2026-10-13)
  Perform the independent read-only testability challenge that data/core-v3-product-acceptance-spec-0927/brief.md explicitly reserved for a separate reviewer pass. Judge only whether the proposed acceptance criteria are testable from the local checkout. Do not ratify product policy, do not change app source or tests, do not touch runtime, deployment, credentials, databases, containers or AnythingLLM.

## Archived 2026-10-13
- [x] core-v3-product-acceptance-spec-0927 - Draft and validate standalone Core Distro V3 acceptance spec (repo: core-distro-saas-clean) (kind: ship) (priority: 2) (done 2026-10-13) (hold: Product-owner review is needed before treating proposed V3 acceptance criteria as policy or landing the local-only spec: decide which criteria to ratify or revise, confirm the nine-region list, public-sharing and enrichment scope, reset-token minimum and acceptance authority, and decide whether PA-04 requires addLeads ownership validation. Current code can insert orphaned rows into another user's list. Options are to ratify or adjust the proposed matrix, defer selected items, or retain it as an unratified draft. Evidence: data/core-v3-product-acceptance-minimax-test-0927/report.md; Gemini review is pending.) (hold-kind: captain)
  Captain hold set: 2026-09-27T03:33:38Z

  Delivery mode: local-only; yolo on per the project's registry, with no deviation. GPT-5.6-Sol authors a proposed standalone V3 product acceptance spec from local evidence; MiniMax-M2.7-highspeed then performs the requested read-only testability challenge. No app/runtime changes or production checks.

## Archived 2026-10-13
- [x] core-v3-product-acceptance-minimax-test-0927 - Challenge proposed Core Distro V3 acceptance spec (repo: core-distro-saas-clean) (kind: scout) (done 2026-10-13)

## Archived 2026-10-13
- [x] unlanded-work-guard-fix - Fix teardown guard that discarded an unlanded deliverable (repo: firstmate) (kind: ship) (done 2026-10-13)
  P0 reliability. The Core V3 acceptance spec (core-v3-product-acceptance-spec-0927) was committed 2026-09-27 to branch fm/core-v3-product-acceptance-spec-0927 inside a disposable worktree. Teardown discarded the worktree. The commit is absent from the primary checkout, all refs and the reflog. Diagnose whether the landed-work guard failed, was bypassed, or misapplied, then fix so unlanded work cannot be silently discarded again.

## Archived 2026-10-13
- [x] kun-concurrency-impl - Kun Lane C: implement concurrency config evidence from A+B findings (kind: ship) (done 2026-10-13)

## Archived 2026-10-14
- [x] kun-video-source-study - Kun Lane A: video + public source study for concurrency=50 (kind: scout) (done 2026-10-13)

## Archived 2026-10-14
- [x] scope-kun-lanes-20261013 - Turn Kun Lane placeholders into scoped dispatchable tickets data/scope-kun-lanes-20261013/report.md (repo: firstmate) (kind: scout) (reported 2026-10-13)
  kun-concurrency-impl, kun-config-inventory, kun-video-source-study are one-line placeholders from 2026-10-03 with no bodies or acceptance criteria. Read the actual current Firstmate/Pi/Codex config and source, then write a real scoped ticket for each with provenance, exact file paths, acceptance criteria and hard boundaries. Do NOT implement. Do not invent scope not evidenced in code or config.

## Archived 2026-10-14
- [x] reliability-receipt-20261012 - Verify actual Controller reply receipt acceptance (repo: firstmate) (kind: scout) (done 2026-10-13) (hold: Captain approved closing this agent while preserving unfinished work; consolidated ownership in existing recovery lead; no automatic relaunch) (hold-kind: parked)
  You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

  # Task
  Own ONLY the receipt acceptance scope in `/home/hd2admin/kun-agent-workspace/data/reliability-six-luna-20261012/plan.md`. Read that compact plan for Captain authority, exact outcomes, existing Controller owners and boundaries. Reuse the actual Controller acknowledgment and arming instruction plus known local receipt evidence; return the exact mismatch, current supported receipt path, acceptance matrix and smallest existing-owner delta. Do not implement the Controller-owned pickup repair or register live polling. This is the evidence phase of authorized durable fixes, not permission to duplicate an existing repair.

  Before investigating, prove your git worktree root is NOT `/home/hd2admin/kun-agent-workspace`; stop on failed isolation. Use lean-ctx. Create the required visible five-item extension tracker. Read `diagnostic-reasoning` and `firstmate-coding-guidelines` before relevant evidence. You may launch one bounded read-only Pi subagent on `openai-codex/gpt-6-luna` with fresh self-contained scope to inventory the specific receipt artifacts; use current tool guide, not obsolete workflowScript. Bind its output to an owned durable report path. No child writers or recursive delegation. Never retry permanently denied commands, switch tools to evade denial or invoke Herdr lifecycle commands. Report exact read/test/refusal facts and unresolved source/admission dependencies; do not declare runtime fixes delivered.

  # Herdr lifecycle declaration - NOT ENABLED
  **HARD SAFETY GATE:** this scaffold cannot inspect the task text that replaces `{TASK}` later.
  If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
  Do not add Herdr lifecycle commands to this unguarded brief by hand.

  # Setup
  You are in a disposable git worktree of firstmate, at a detached HEAD on a clean default branch.
  This is a SCOUT task: the deliverable is a written report, not a PR.
  This scout is read-only to project/shared/config/runtime files: only your report, owned scratch evidence and prescribed status may be written. No installs, scratch commits, production/network/credentials, permission edits, push/merge, restarts, pane moves or cleanup.
  The report is the only thing that survives, so anything worth keeping must be in it.

  # Mandatory task breakdown
  Before any investigation, edit, test, or other task action, use the harness's
  To-Do List extension and create an in-depth dependency-aware tracker with at
  least five checkable items: preflight, scoped discovery, bounded work/evidence,
  validation, and postflight/closeout. Keep it visible and update it at every
  phase change. Do not substitute prose or a filesystem TODO file. If the
  extension is unavailable or the tracker has fewer than five items, append
  `blocked: mandatory visible five-item task tracker unavailable` to the status file and
  stop; firstmate must not treat the task as started.

  # Rules
  1. Never push to any remote and never open a PR.
  2. Stay inside this worktree; the only files you may write outside it are the report and the status file below.
  3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
  4. Report status by appending one line:
     `echo "{state}: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/reliability-receipt-20261012.status'`
     States: working, needs-decision, blocked, paused, done, failed.
     Each append wakes firstmate, so report sparingly: only phase changes a supervisor
     would act on and the needs-decision/blocked/paused/done/failed states. No step-by-step
     FYI progress lines; firstmate reads your pane for that.
     Use `paused: {why}` - distinct from `blocked:` - ONLY when you are deliberately idling on a
     known external wait you expect to clear on its own (an upstream release, a rate-limit reset):
     firstmate then leaves your idle pane alone and rechecks it on a long cadence instead of
     treating it as a possible wedge. Use `blocked:` when you are stuck and need help.
  5. If you hit the same obstacle twice, append `blocked: {why}` and stop; firstmate will help.
  6. If a decision belongs to a human (product choices, destructive actions),
     append `needs-decision: {summary of options}` and stop. Firstmate will reply with the decision.
     When firstmate replies or a blocker clears and you resume, append `resolved: {how it was decided or unblocked}` (add the same `[key=<slug>]` if you opened it with one) so the decision or blocker is durably closed and does not keep resurfacing.
  7. Never stop, restart, or update the shared `no-mistakes` daemon - it is one instance serving
     every lane/home, so restarting it kills other lanes' in-flight pipeline runs. On ANY no-mistakes
     daemon error, append `blocked: {the daemon error}` and stop; only firstmate manages the daemon.

  # Definition of done
  Write your findings to `/home/hd2admin/kun-agent-workspace/data/reliability-receipt-20261012/report.md`.
  The report must stand alone: what you did, what you found, the evidence (commands run, output, file:line references), and what you recommend.
  Before reporting done, read and follow `/home/hd2admin/kun-agent-workspace/.agents/skills/decision-hold-lifecycle/SKILL.md` and pass its shared completion gate for the report and any visual review.
  When the report is complete, append `done: {one-line conclusion}` to the status file and stop.
  If your findings reveal work that should ship (e.g. you reproduced a bug and the fix is clear), say so in the report; firstmate may promote this task in place, and you would then receive mode-specific ship instructions as a follow-up message.

## Archived 2026-10-14
- [x] reliability-controls-docs-20261012 - Map authoritative controls and recovery documentation (repo: firstmate) (kind: scout) (done 2026-10-13) (hold: Captain approved closing this agent while preserving unfinished work; consolidated ownership in existing recovery lead; no automatic relaunch) (hold-kind: parked)
  You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

  # Task
  Own ONLY the authoritative controls/documentation map and scoped recovery runbook draft in `/home/hd2admin/kun-agent-workspace/data/reliability-six-luna-20261012/plan.md`. Read `firstmate-coding-guidelines`, doc audience inventory and current relevant script/skill owners. Produce a private report mapping each desired outcome to its existing config, deterministic enforcement, runtime proof and contributor/operator doc owner. Preserve one owner per contract; no new framework, duplicate policy layer or whole-history recap. Reuse known recurring evidence. Record the observed `fm-brief.sh` scaffold warning at line251 (`blocked:: command not found`) and omission of mandatory blocked clause; parent repaired only six private generated briefs, not tracked source. Include exact smallest eligible script/doc correction plus executable test criteria; don't modify source until custody/admission/delivery is resolved. Do not independently review other lanes' implementations.

  Prove isolated git root differs from `/home/hd2admin/kun-agent-workspace`. Use lean-ctx and five-item visible extension tracker. You may launch one bounded fresh-context read-only Pi subagent with `openai-codex/gpt-6-luna` to map doc audiences/owner links; use current guide, bind durable output, no child writers/recursion. No denied helpers, auth reads, shared edits or Herdr lifecycle. Return concise current-behavior runbook draft, reproducible verification entry points and exact unresolved authority/admission questions; never document an unproved mechanism as enforced.

  # Herdr lifecycle declaration - NOT ENABLED
  **HARD SAFETY GATE:** this scaffold cannot inspect the task text that replaces `{TASK}` later.
  If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
  Do not add Herdr lifecycle commands to this unguarded brief by hand.

  # Setup
  You are in a disposable git worktree of firstmate, at a detached HEAD on a clean default branch.
  This is a SCOUT task: the deliverable is a written report, not a PR.
  This scout is read-only to project/shared/config/runtime files: only your report, owned scratch evidence and prescribed status may be written. No installs, scratch commits, production/network/credentials, permission edits, push/merge, restarts, pane moves or cleanup.
  The report is the only thing that survives, so anything worth keeping must be in it.

  # Mandatory task breakdown
  Before any investigation, edit, test, or other task action, use the harness's
  To-Do List extension and create an in-depth dependency-aware tracker with at
  least five checkable items: preflight, scoped discovery, bounded work/evidence,
  validation, and postflight/closeout. Keep it visible and update it at every
  phase change. Do not substitute prose or a filesystem TODO file. If the
  extension is unavailable or the tracker has fewer than five items, append
  `blocked: mandatory visible five-item task tracker unavailable` to the status file and
  stop; firstmate must not treat the task as started.

  # Rules
  1. Never push to any remote and never open a PR.
  2. Stay inside this worktree; the only files you may write outside it are the report and the status file below.
  3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
  4. Report status by appending one line:
     `echo "{state}: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/reliability-controls-docs-20261012.status'`
     States: working, needs-decision, blocked, paused, done, failed.
     Each append wakes firstmate, so report sparingly: only phase changes a supervisor
     would act on and the needs-decision/blocked/paused/done/failed states. No step-by-step
     FYI progress lines; firstmate reads your pane for that.
     Use `paused: {why}` - distinct from `blocked:` - ONLY when you are deliberately idling on a
     known external wait you expect to clear on its own (an upstream release, a rate-limit reset):
     firstmate then leaves your idle pane alone and rechecks it on a long cadence instead of
     treating it as a possible wedge. Use `blocked:` when you are stuck and need help.
  5. If you hit the same obstacle twice, append `blocked: {why}` and stop; firstmate will help.
  6. If a decision belongs to a human (product choices, destructive actions),
     append `needs-decision: {summary of options}` and stop. Firstmate will reply with the decision.
     When firstmate replies or a blocker clears and you resume, append `resolved: {how it was decided or unblocked}` (add the same `[key=<slug>]` if you opened it with one) so the decision or blocker is durably closed and does not keep resurfacing.
  7. Never stop, restart, or update the shared `no-mistakes` daemon - it is one instance serving
     every lane/home, so restarting it kills other lanes' in-flight pipeline runs. On ANY no-mistakes
     daemon error, append `blocked: {the daemon error}` and stop; only firstmate manages the daemon.

  # Definition of done
  Write your findings to `/home/hd2admin/kun-agent-workspace/data/reliability-controls-docs-20261012/report.md`.
  The report must stand alone: what you did, what you found, the evidence (commands run, output, file:line references), and what you recommend.
  Before reporting done, read and follow `/home/hd2admin/kun-agent-workspace/.agents/skills/decision-hold-lifecycle/SKILL.md` and pass its shared completion gate for the report and any visual review.
  When the report is complete, append `done: {one-line conclusion}` to the status file and stop.
  If your findings reveal work that should ship (e.g. you reproduced a bug and the fix is clear), say so in the report; firstmate may promote this task in place, and you would then receive mode-specific ship instructions as a follow-up message.

## Archived 2026-10-14
- [x] scope-reliability-lanes-20261013 - Turn reliability placeholders into scoped tickets against current reality data/scope-reliability-lanes-20261013/report.md (repo: firstmate) (kind: scout) (reported 2026-10-13)
  reliability-permission, reliability-receipt, reliability-reporting, reliability-routing, reliability-controls-docs are placeholders. Re-derive each against CURRENT state (comms now bidirectional; M3.1 registered; domain experts live), state what is already satisfied, what genuinely remains, and what is now moot. Produce scoped tickets with acceptance criteria. Do not implement.

## Archived 2026-10-14
- [x] core-stage-chunk1-test-baseline - Run the Core staging test suite and report real results data/core-stage-chunk1-test-baseline/report.md (repo: core-distro-stage) (kind: ship) (reported 2026-10-13)
  READ-AND-REPORT ONLY. Run the existing suite in /home/hd2admin/campaign/core-distro-stage/tests/ and report actual per-test pass/fail with exact commands and output. No edits to any test or source file, no docker mutations, no container restarts, no credential or form submission, no chatbot activation, no DNS/proxy/firewall/cPanel. Fixed regression tests are not part of this chunk. Masks, skips and unrun tests must be named explicitly, never reported as passing.

## Archived 2026-10-14
- [x] funnel-origin-diagnosis - Diagnose unreachable Funnel origin behind 3 staging test failures data/funnel-origin-diagnosis/report.md (repo: core-distro-stage) (kind: scout) (reported 2026-10-13)
  Read-only root-cause. All 10 staging tests ran: 7 pass, 3 fail. All 3 failures trace to the Funnel origin refusing connections across all 12 routes; private-origin assets all pass. Determine what the Funnel origin is, whether it should be running, and why it is refused. Do NOT fix, do NOT start services, do NOT edit config or the staging tree.

## Archived 2026-10-14
- [x] core-stage-draft-duplicates - Draft 9 seed-owned duplicate page records in Core staging (repo: core-distro-stage) (kind: ship) (done 2026-10-13)
  Independent of the Funnel issue. Test 6 reports 9 published seed-owned duplicates: glass-vials, rubber-stoppers, aluminum-seals with -2/-3/-4 suffixes (IDs 24-26, 35-37, 46-48). Use ONLY the guarded helper already documented at tools/draft-seed-duplicates; no manual SQL, no deletes. Verify record counts before and after. Staging only, no production.

## Archived 2026-10-14
- [x] funnel-assertions-conditional - Make expired Funnel assertions conditional so staging suite goes green data/funnel-assertions-conditional/report.md (repo: core-distro-stage) (kind: ship) (reported 2026-10-13)
  Firstmate decision 2026-10-13, Captain delegated. brandon-compute.tailddbb4d.ts.net was a temporary owner-approved public Tailscale Funnel documented as scheduled to expire; its ECONNREFUSED is correct behaviour. Make the Funnel-specific assertions conditional/retired so routine private-staging validation does not depend on an expired public window. Do NOT authorize or create any new public listener.

## Archived 2026-10-14
- [x] backlog-truth-pass - Reconcile phantom in-flight backlog entries against live reality data/backlog-truth-pass/report.md (repo: firstmate) (kind: scout) (reported 2026-10-13)
  26 entries sit in_flight with no live worker endpoint. Produce a truthful per-entry disposition: HAS LIVE WORKER / UNLANDED WORK EXISTS / OBSOLETE / ALREADY DONE, each with evidence. Do not close or delete anything. Report only; firstmate decides.

## Archived 2026-10-14
- [x] fleet-view-live-actions - Make fleet view show only active work and expose safe steering commands data/fleet-view-live-actions/report.md (repo: firstmate) (kind: ship) (reported 2026-10-14) (hold: Waiting for repository write access after GitHub 403; local branch and validation preserved) (hold-kind: external)
  Goal:visible-parallel-firstmate. In an isolated Firstmate worktree, update only bin/fm-fleet-view.sh and its existing tests. Make the active section include only genuinely in-flight tasks, show current state and endpoint, and render the existing snapshot actions.steer fail-closed command; separate done/held rows clearly and test working, done, held, and missing-endpoint fixtures. Load firstmate-coding-guidelines and tdd-red-green-refactor. Keep the full Pi todo list visible after every update, use lean-ctx, and delegate a bounded read-only review to one subagent if useful; child must not edit this worktree. No board/snapshot/Bearings files, no publish/merge.

## Archived 2026-10-14
- [x] fleet-snapshot-jq-resync - Re-apply the jq argument-limit fix onto the synced base cf2a3db3 data/fleet-snapshot-jq-resync/report.md (repo: firstmate) (kind: ship) (reported 2026-10-14)
  The earlier fix on branch fm/fleet-snapshot-arg-limit (tip 9601685d) was based on the pre-sync base and its file changes were overwritten when the checkout fast-forwarded to cf2a3db3. The defect is LIVE again: /usr/local/bin/jq: Argument list too long at bin/fm-fleet-snapshot.sh line 567, which aborts the snapshot entirely. Re-apply onto the current base. Read data/fleet-snapshot-arg-limit/report.md for the prior diagnosis and approach; cherry-picking the old commit is acceptable if it applies cleanly and its diff is correct.

## Archived 2026-10-14
- [x] clear-infra-20261013 - Infra pass: firstmate tooling entries with a determinable answer data/clear-infra-20261013/report.md (repo: firstmate) (kind: scout) (reported 2026-10-14)
  firstmate tooling entries where the answer is in the code, the CI config, or tonight's landed work. Read the actual source and report what is still true, what is fixed, and what genuinely remains. Do not implement anything. TARGET ENTRIES: controller-watcher-tdd, status-dir-validate, quota-aware-queue-pump, pi-live-todo-default, afk-return-dir-fix, brief-compaction-preserve, calm-worker-version-consistency, controller-inbox-local-repair-20261013

## Archived 2026-10-14
- [x] clear-domain-20261013 - Domain pass: entries belonging to a secondmate expert data/clear-domain-20261013/report.md (repo: firstmate) (kind: scout) (reported 2026-10-14)
  Entries that are domain work rather than firstmate work. For each, name the correct domain expert by scope, state whether that expert's access refusals still apply, and give the exact brief the expert could execute now. Do not dispatch them yourself. TARGET ENTRIES: domain-expertise-20261013, elevate-ops-source-map, overnight-secondmate-progress-20261012, hetz-study-20261005, cbd-g5-source-refresh-0924, context-continuity-audit, kun-config-inventory

## Archived 2026-10-14
- [x] clear-obsolete-20261013 - Obsolete pass: entries superseded by landed work data/clear-obsolete-20261013/report.md (repo: firstmate) (kind: scout) (reported 2026-10-14)
  Entries whose premise was overtaken by work that has since landed. Establish what landed and when, then say whether the entry is obsolete, still needed, or partially done. Cite the landed commit or artifact. TARGET ENTRIES: kun-concurrency-impl, reliability-receipt-20261012, reliability-controls-docs-20261012, graceful-rate-limit-handling, skill-collisions-cleanup-20261013, core-stage-chunk1-test-baseline, funnel-origin-diagnosis, core-stage-chunk4-spec-challenge, funnel-assertions-conditional, core-stage-draft-duplicates

## Archived 2026-10-14
- [x] clear-reliability-20261013 - Reliability pass: remaining narrow reliability entries data/clear-reliability-20261013/report.md (repo: firstmate) (kind: scout) (reported 2026-10-14)
  The reliability entries the scoping pass narrowed to still-remaining work. For each, state the smallest concrete next action, who owns it, and what evidence is already sufficient. Where Controller firstmate owns it, say so plainly. TARGET ENTRIES: reliability-permission-20261012, reliability-reporting-20261012, reliability-routing-20261012, reliability-controls-docs-20261012, per-provider-dispatch-cap, durable-recovery-20261013, brief-worklocation-template-fix

## Archived 2026-10-14
- [x] clear-core-20261013 - Core pass: Core Distro entries and staging state data/clear-core-20261013/report.md (repo: firstmate) (kind: scout) (reported 2026-10-14)
  Core Distro entries plus the staging tree state. Establish what is actually deployed in the staging site now, which Core entries are genuinely open, and what the PA-04 ownership gap means for the acceptance spec. Read only; no writes. TARGET ENTRIES: core-distro-stage-wp-multipage, core-distro-stage-scale-100pct, core-distro-stage-article-drawer-fix-20261012, core-mobile-fix, core-stream-a-checkpoint-0924, core-live-widget-source-0924

## Archived 2026-10-14
- [x] brief-worklocation-local - Land the brief --worklocation template fix via local-only path (repo: firstmate) (kind: ship) (done 2026-10-14)
  Re-dispatch of the verified brief template fix under local-only. Committed as 23f0468e on fm/brief-worklocation-template-fix; its own tests exit 0 and default briefs are byte-identical. Verify the existing commit rather than redoing the work.

## Archived 2026-10-14
- [x] fleet-snapshot-arg-limit-local - Land the jq argument-limit fix via local-only path (repo: firstmate) (kind: ship) (done 2026-10-14)
  Re-dispatch of the verified jq fix under local-only so fm-merge-local.sh can fast-forward it. Original work is committed on branch fm/fleet-snapshot-arg-limit with tests exit 0, shellcheck 0, and behaviour diff clean. Verify the existing commit rather than redoing the work.

## Archived 2026-10-14
- [x] dispatch-guard-idle-lanes - Idle lanes should not consume the concurrency budget (repo: firstmate) (kind: ship) (done 2026-10-14)
  Captain decision 2026-10-13. The dispatch guard counts every live pane as a lane, so seven idle domain experts exceed a cap of 6 and block all dispatch. Implement: only lanes with genuine active work consume budget. SAFETY CRITICAL: idle must mean actual current state, not inactivity timeout, or a wedged worker would free its slot and defeat the cap.

## Archived 2026-10-14
- [x] skill-collision-free-fix - Remove the stray skill backup and duplicate copies causing startup warnings (repo: firstmate) (kind: ship) (done 2026-10-14)
  Five duplicate skill-name warnings at Pi startup. Root causes identified: quota-axi.bak-20261006 is a BACKUP sitting inside a live skills folder so it is discovered as a real skill; no-mistakes, tdd-red-green-refactor and quota-axi each exist twice (project .agents/skills copy and ~/.agents/skills copy). Council-mode and pi-subagents collide with pi-subagents package copies. Remove the collision without deleting anything of value.

## Archived 2026-10-14
- [x] graceful-rate-limit-handling - Handle provider rate limits gracefully rather than avoiding them (repo: firstmate) (kind: ship) (done 2026-10-14)
  Captain: six per provider is the ceiling, beyond that rate limits appear, and the system must HANDLE them gracefully rather than be protected from them by a lower cap. Find where 429 or rate-limit responses surface during dispatch/worker execution and make the handling explicit and recoverable: bounded retry with backoff, clear surfaced state, no silent stall, no infinite retry. local-only delivery.

## Archived 2026-10-15
- [x] per-provider-dispatch-cap - Enforce the concurrency cap PER MODEL PROVIDER, not globally (repo: firstmate) (kind: ship) (done 2026-10-14)
  dispatch-max-lanes is currently a single global ceiling of 6. Captain requires max 6 WORKING agents per model provider, so six Luna plus six M3.1 could run concurrently. Existing global ceiling is correct but insufficient. Implement per-provider counting in the dispatch guard, preserving the global ceiling as a secondary bound. local-only delivery.

## Archived 2026-10-15
- [x] kun-config-inventory-refresh - Refresh stale Firstmate/Codex/Pi config inventory against current files data/scope-kun-lanes-20261013/report.md (repo: firstmate) (kind: scout) (reported 2026-10-14)
  Scoped from scope-kun-lanes-20261013. Read-only. Separate configured/enabled models from catalog entries, policy from enforced behavior, observed settings from historical claims. Reconcile legacy config/parallel-dispatch-cap=6 against current config/dispatch-max-lanes guard and default. Full read scope and 7 acceptance criteria in data/scope-kun-lanes-20261013/report.md section 2. No credentials, no edits.

## Archived 2026-10-15
- [x] hetz-gate-A-20261005 - Hetz Gate A: host/server inventory (kind: scout) (done 2026-10-14)

## Archived 2026-10-15
- [x] elevate-rag-diagnosis-20261005 - Elevate RAG quality diagnosis + fix plan (kind: scout) (done 2026-10-14)

## Archived 2026-10-15
- [x] pi-trust-prompt-fix-20261005 - Brandon pi trust-prompt fatigue fix: pre-seed worktree trust (kind: scout) (done 2026-10-14)

## Archived 2026-10-15
- [x] widget-consent-fix-20261005 - Widget consent-box persistence + frame-reload fix (kind: scout) (done 2026-10-14)

## Archived 2026-10-15
- [x] fleet-snapshot-arg-limit - Fix jq Argument list too long aborting the fleet snapshot (repo: firstmate) (kind: ship) (done 2026-10-14)
  Confirmed reproducible at current backlog size: bin/fm-fleet-snapshot.sh line ~567 main_inventory_json passes --argjson of the whole backlog and tasks JSON, which exceeds the exec argument limit and aborts the snapshot entirely. This is why fleet visibility is dead at 58 items.

## Archived 2026-10-15
- [x] kun-config-inventory - Kun Lane B: current Firstmate/Codex/Pi config + plugin inventory (kind: scout) (done 2026-10-14)

## Archived 2026-10-15
- [x] pi-luna-context-scratch-validation-0927 - Validate gpt-6-luna context override in isolated scratch Pi config (repo: firstmate) (kind: scout) (priority: 2) (done 2026-10-14) (hold: Fresh Codex context test complete; see data/pi-luna-context-window-test-0927/report.md. Pi 0.87.1's openai-codex/gpt-6-luna catalog supplies contextWindow 272000; automatic compaction begins only above 255616 estimated tokens, 93.98 percent, with reserve 16384. The fresh Codex Astra session advertised 258400 runtime tokens and showed no compaction by 37.8 percent usage. The separate 1050000 override is under provider openai and does not apply. The current Luna route already gets the supported 272000 catalog value, so recommendation is no config change. Clarify whether 'change Firstmate over to it' means adding a redundant override or switching the primary to a specified Codex model/runtime; no live setting change or reload until the target is clear.) (hold-kind: captain)
  Captain hold set: 2026-09-27T00:28:15Z

  Validate the suspected provider-key mismatch using an isolated scratch agent directory only; use /tmp/pi-context-window-system-fix-0926/diagnosis.md as prior evidence. No live ~/.pi/agent/models.json edits, no live Pi restart/cutover, no credentials or network. Report to data/pi-luna-context-scratch-validation-0927/report.md.

## Archived 2026-10-15
- [x] hetz-study-20261005 - Hetz surface gap study vs v3 PRD (kind: scout) (done 2026-10-14)

## Archived 2026-10-15
- [x] wl3-20261015 - x (repo: firstmate) (kind: ship) (done 2026-10-15)

## Archived 2026-10-15
- [x] bytecheck2-20261015 - x (repo: firstmate) (kind: ship) (done 2026-10-15)

## Archived 2026-10-15
- [x] bytecheck-20261015 - x (repo: firstmate) (kind: ship) (done 2026-10-15)

## Archived 2026-10-15
- [x] exec-probe-20261015 - Execution probe (repo: firstmate) (kind: scout) (done 2026-10-15)
  PROBE. Do not do any work. Reply with exactly these five lines and nothing else:

  TOOL bash : OK or DENIED
  TOOL read : OK or DENIED
  TOOL edit : OK or DENIED
  TOOL write: OK or DENIED
  SHELL WHICHS: output of `command -v bash; command -v sh` or DENIED

  Then write the single file /home/hd2admin/kun-agent-workspace/data/exec-probe-20261015/answer.txt containing
  those same five lines. Then stop.

  Nothing else. No repository work, no commits, no other files.

## Archived 2026-10-15
- [x] slots-test-20261015 - x (repo: firstmate) (kind: scout) (done 2026-10-15)

## Archived 2026-10-15
- [x] scope-check2-20261015 - x (repo: firstmate) (kind: ship) (done 2026-10-15)

## Archived 2026-10-15
- [x] scope-check-20261015 - x (repo: firstmate) (kind: ship) (done 2026-10-15)

## Archived 2026-10-15
- [x] verify-baseline-20261015 - verify baseline manifest resolves locally (repo: firstmate) (kind: ship) (done 2026-10-15)

## Archived 2026-10-15
- [x] durable-docs-20261015 - Durable docs + config for 2026-10-14/15 decisions (repo: firstmate) (kind: ship) (done 2026-10-15)
  Write the durable configuration and documentation for the decisions made on 2026-10-14/15. Documentation
  and config only. Do NOT change behaviour in bin/, do NOT commit, do NOT push.

  ## Where the decisions already live
  - `data/captain.md` — the Captain's standing rules. READ IT FIRST, in full. It is the source of these rules.
  - `data/learnings.md` — curated dated lessons from earlier tonight.
  - `.agents/skills/` — agent-only skills. Skills already exist for some of this; do not duplicate.

  ## What to produce

  ### 1. `docs/operating-decisions-2026-10-14-15.md`
  A single readable record of the decisions made in this window and WHY, written for a future firstmate who
  has none of this context. Cover at minimum:
  - Dispatch routing: workers on Luna 6 at the LIVE fast/slow setting, never hardcoded; reviews grouped, one
    M3.1 per gate, never one per worker. Include that the fast/slow setting must be read at dispatch time
    because the Captain swaps it frequently.
  - Controller (Crisp-R) may task Hetz directly. Ordinary work from him is pre-authorised and must NOT be
    escalated to the Captain. List the standing boundaries that still escalate: destructive/irreversible,
    deleting or discarding branches or archives, credentials and keys, live production sites, DNS, registrar,
    billing, the Aminolifesciences archive, and merge approval for retained branches.
  - Warehouse is Controller-owned. Hetz reads its mirror, never writes it. Submission is via the outbox.
    Receipt is not acceptance.
  - A `superseded` marking on a Controller message outranks that message's own urgency label.
  - Three retained Core branches stay retained until a NAMED branch is explicitly approved for merge. Keeping
    is not merge approval.
  - Delivery, reading, and substantive acceptance are three separate facts.

  ### 2. `docs/verification-discipline.md`
  How this home decides something is true. Ground it in the actual failures from this window, each with its
  concrete lesson:
  - The agent surface is Herdr, not tmux. Checking tmux and reading an empty result as "nothing running" caused
    the deletion of 20 LIVE work records. Include that a command which swallows its exit status is not a check.
  - File existence is never proof. Load the page, run the test, read the log.
  - `ready in branch` is NOT delivered. Three entries were misreported as done on this basis.
  - A declared pause is not proof of life; a lane reported as a healthy declared pause had no window for ~20h.
  - Reviewing a worker's conclusion means checking the artifact, not the report.
  - Refusing to act on a superseded gate was CORRECT and is now standing policy.

  ### 3. `config/` entries only if a decision actually needs a knob
  Read `docs/configuration.md` first — it owns the config surface. Add a key ONLY where a decision genuinely
  needs to be configurable, with its default matching current behaviour. If every decision above can be
  expressed as a documented rule, add NO config key and say so in your report. Do not invent knobs.

  ## Hard boundaries
  - Do not modify anything in `bin/` or `tests/`. Behaviour changes are separate work with their own tests.
  - Do not touch `projects/`, `warehouse/`, or any secondmate home.
  - Do not run `tasks-axi`. Do not commit. Do not push.
  - Do not restate `AGENTS.md` or `data/captain.md` at length. Those own those rules. Point to them.
  - Every claim needs a source: a file path, a commit, a command result, or a dated message. If you cannot
    source a claim, leave it out or mark it UNSOURCED.

  ## Report
  Report to `/home/hd2admin/kun-agent-workspace/data/durable-docs-20261015/report.md`: what you wrote, what you
  deliberately did NOT write and why, every source you used, and any decision above that you could not source.

## Archived 2026-10-15
- [x] durable-docs-20261015b - Durable docs, sources embedded (repo: firstmate) (kind: ship) (done 2026-10-15)
  Write the durable documentation for the decisions made 2026-10-14/15. Documentation only: do NOT change
  behaviour in bin/, do NOT commit, do NOT push.

  ## THE SOURCES ARE BELOW, IN THIS BRIEF. YOU DO NOT NEED TO READ ANY FILE.

  A previous attempt at this task failed because data/captain.md and data/learnings.md are untracked and do
  not exist in an isolated worktree. That is now handled by --worklocation, and the decision content you need
  is reproduced here. Work from this text.

  ## Decisions to document

  ### Dispatch routing
  - Workers run Luna 6 at the LIVE fast/slow setting. NEVER hardcode it; read it at dispatch time, because the
    Captain swaps fast and slow frequently.
  - Reviews are GROUPED: one M3.1 review per gate, never one review per worker.
  - Either firstmate reviews directly, OR one M3.1 reviews the group. Never both for the same gate.
  - Rationale: conserve review tokens, spend the worker's quota. This is a COST rule, not a quality rule, and
    does not license skipping a review a gate genuinely requires.
  - Observed at 2026-10-15: codex five_hour 100% remaining, weekly 81%.

  ### Controller may task Hetz directly
  - The Captain may be away and speak to Crisp-R directly. Crisp-R may task Hetz. Hetz ACTS on Crisp-R's
    direction without escalating to the Captain.
  - Delivery into the exchange directory is the channel; the Controller-inbox poll picks it up automatically
    and Hetz acknowledges by content hash. No relay through the Captain is needed.
  - STILL ESCALATE TO THE CAPTAIN: destructive, irreversible, or force-overwrite actions; deleting or
    discarding branches, work, or archives; credentials and key transfer; live core-distro.com or
    elevatesci.com, DNS, registrar, billing, permission stores; the Aminolifesciences archive; merge approval
    for retained branches.
  - Crisp-R's own authority does not become Hetz's authority.

  ### Warehouse
  - Warehouse is Controller-owned. Hetz READS its mirror and NEVER writes it. bin/fm-warehouse-guard.sh
    enforces this.
  - Submission is via bin/fm-warehouse-submit.sh, which emits a manifest with source path, sha256, intended
    destination and evidence, then bin/fm-outbound.sh sends it. Controller reviews and mirrors.
  - RECEIPT IS NOT ACCEPTANCE.

  ### Message handling
  - A `superseded` marking on a Controller message OUTRANKS that message's own urgency label. Where a
    superseded message and its replacement disagree, the replacement governs. Seven messages were marked
    superseded. Implementing one of them would have been a fix for a fault that never existed.

  ### Branches
  - Three Core branches are retained: fm/core-stream-a-checkpoint-0924 (4 commits ahead),
    fm/core-mobile-fix (3 ahead), fm/core-v3-product-acceptance-spec-0927 (2 ahead).
  - Retained is NOT merge approval. A merge needs a NAMED branch and explicit approval.
  - Never discard, reset, clean, stash, force-overwrite, or delete their work.

  ### Three separate facts
  Delivery, reading, and substantive acceptance. A file landing is not a reply. A reply is not acceptance.

  ## Produce TWO documents

  ### docs/operating-decisions-2026-10-14-15.md
  Readable to a future firstmate with none of this context: each decision, why it was made, and what it
  constrains. Lead with the constraints, not the narrative.

  ### docs/verification-discipline.md
  How this home decides something is true, grounded in the actual failures:
  - The agent surface is Herdr, not tmux. Checking tmux and reading an empty result as "nothing running"
    caused the deletion of 20 LIVE work records. A command that swallows its exit status is not a check.
  - File existence is never proof. Load the page, run the test, read the log.
  - `ready in branch` is NOT delivered. Three entries were misreported as done on that basis.
  - A declared pause is not proof of life: a lane reported as a healthy declared pause had no window for ~20h.
  - A worker's refusal is evidence, not failure. Four workers correctly refused unbuildable tasks while
    firstmate misdiagnosed them as broken.
  - Worker transcripts live under ~/.pi/agent/sessions/. Reading them answered in one step what four wake
    cycles could not.

  ## Rules
  - No prose padding. Short sections, concrete statements.
  - Every claim traces to something in this brief or a path named in it. Do not invent facts.
  - Do NOT create config keys. These decisions are documented rules, not knobs.
  - Do not touch bin/, tests/, projects/, warehouse/, or any secondmate home. Do not run tasks-axi.

  ## REPORT — this is not optional
  Write `/home/hd2admin/kun-agent-workspace/data/durable-docs-20261015b/report.md` containing what you wrote
  and what you deliberately did not write. YOUR CHAT REPLY IS NOT THE DELIVERABLE. The files are the
  deliverable. If the files do not exist the task is not done, regardless of what you say in this pane.

## Archived 2026-10-15
- [x] durable-docs-20261015c - Durable docs as scout in live home (repo: firstmate) (kind: scout) (done 2026-10-15)
  This is a SCOUT task. The deliverable is two documentation files written into the live home at /home/hd2admin/kun-agent-workspace/docs/, plus your report. You are authorized to write ONLY those two do

## Archived 2026-10-15
- [x] durable-docs-20261015d - Durable docs, clean scout brief (repo: firstmate) (kind: scout) (done 2026-10-15)
  SCOUT TASK. The deliverable is TWO documentation files written into the live home. No branch, no commit,
  no push, no code change.

  ## Exactly what you may write - nothing else is permitted
  1. /home/hd2admin/kun-agent-wor

## Archived 2026-10-15
- [x] durable-docs-20261015e - Durable docs written locally (repo: firstmate) (kind: scout) (done 2026-10-15)
  SCOUT TASK. Write TWO documentation files INTO YOUR OWN WORKTREE. Your parent firstmate will copy them
  into the live home afterwards - you do not need to reach the live home and you must not try.

  ## 

## Archived 2026-10-15
- [x] baseline-scope-tests-20261015 - Update baseline tests to scope-label contract (repo: firstmate) (kind: ship) (done 2026-10-15)
  Update tests/fm-fresh-baseline.test.sh to the accepted scope-label contract. DO NOT run tests - do not
  try. The sandbox denies bash execution; you will fail and waste the task. Write the test file only, commit
  nothing, and report exactly what you changed so firstmate can run it.

  ## Why the tests are wrong, not the code
  Commit d89b84d7 made a fresh-agent baseline report roles with no home-local file as
  `unavailable (no home-local file on this host)`. That was a regression: the policy family genuinely lives in
  a root-owned scope that IS readable from this host, and reporting a readable file as missing discards a real
  contract.

  Controller's accepted remedy is an explicit SCOPE LABEL, not absence. The code in bin/fm-baseline-lib.sh now
  implements it and emits:

  ```
  policy=/home/hd2admin/kun-agent-workspace/AGENT-POLICY.md scope=home sha256:...
  project-policy=/home/hd2admin/agent-work/AGENTS.md scope=account sha256:...
  routing=/root/docs/agent-policy/HERDR_AGENT_ROUTING.md scope=cross-home:root sha256:...
  bounded=/root/docs/agent-policy/HERDR_BOUNDED_EXECUTION.md scope=cross-home:root sha256:...
  lean-ctx=/home/hd2admin/.codex/LEAN-CTX.md scope=account sha256:...
  ```

  Scope values are exactly: `home`, `account`, or `cross-home:<scope-name>`. An absolute path's scope name is
  the first segment after its leading slash.

  ## Current state
  `tests/fm-fresh-baseline.test.sh` gives PASS=40 FAIL=45. Failures are assertions like
  `scout brief policy not resolved from the home` and equivalents for project-policy, routing and bounded -
  they encode the old unavailable-marker contract.

  ## What to change
  1. Read bin/fm-baseline-lib.sh first, especially `fm_baseline_scope_of`, `fm_baseline_role_candidates` and
     `fm_baseline_unavailable_line`. Understand the real contract before editing assertions.
  2. Replace assertions that require every role to resolve inside the home. The correct assertion is that every
     role emits a resolvable path WITH a valid scope label, and that a path whose scope is not `home` is
     genuinely readable.
  3. KEEP every fail-closed test. Missing required files must still refuse, must still print an explicit
     diagnostic, and must still not mutate state. Those tests are passing for the right reason - do not weaken
     them to make the count go up.
  4. ADD a test for the no-readable-file-anywhere case: it must emit the unavailable marker, with no path and
     no digest. Prove the marker cannot be mistaken for a real pointer.
  5. ADD a test that a cross-home scope label names the correct scope, so the empty-label bug
     (`cross-home:` with nothing after it) cannot come back.
  6. Use FM_BASELINE_ROOT_SCOPE in at least one test to point the cross-home scope at a temporary directory.
     That makes the cross-home path testable without depending on /root existing, which is the whole reason
     that override exists.

  ## Boundaries
  Only touch tests/fm-fresh-baseline.test.sh and tests/fm-direct-start-fresh-baseline.test.sh. Do not edit
  anything in bin/ - the implementation is accepted as written. Do not run, commit, or push. Do not touch
  projects/. Do not run tasks-axi.

  Report to /home/hd2admin/kun-agent-workspace/data/baseline-scope-tests-20261015/report.md: the assertions
  you replaced and why each old assertion was wrong, the new assertions you added, and confirmation that no
  fail-closed assertion was weakened.

## Archived 2026-10-15
- [x] durable-docs-final - Durable docs, write into own worktree (repo: firstmate) (kind: scout) (done 2026-10-15)
  SCOUT TASK. Write TWO documentation files INTO YOUR OWN WORKTREE. Your parent firstmate copies them into
  the live home afterwards. Do not attempt to reach the live home: the tool sandbox refuses paths

## Archived 2026-10-15
- [x] evidence-six-20261015 - Evidence for Controller items 1-3 (repo: firstmate) (kind: scout) (done 2026-10-15)
  Gather the EVIDENCE for three items Controller asked from Hetz. Investigation only: change nothing,
  commit nothing, push nothing. Your deliverable is one report with the evidence inline.

  ## Item 1 - outbound hash-ledger self-trigger fix: source revision and test results

  The fix that stopped Brandon's own outbound mail being reported back to it as inbound Controller mail.

  - Source: `bin/fm-outbound.sh` (new) and `state/controller-inbox.check.sh` (filter added).
  - The outbound ledger is `state/.controller-inbox-outbound`, content-hash keyed.
  - Report: the commit that introduced `bin/fm-outbound.sh`; whether the check-side filter was ever committed
    or is still uncommitted working-tree state; exact test results if a test covers it.

  State this precisely. If part of it is UNCOMMITTED, say so plainly - an uncommitted fix is not a landed fix
  and Controller must know which he is getting.

  ## Item 2 - original pre-repair failure evidence

  What the behaviour actually was BEFORE the repair, with evidence.

  Known so far, verify and expand rather than repeat:
  - `state/.controller-inbox.check.sh` exited silently unless `state/.afk` existed, so with the Captain present
    it never reported anything. Check whether git history or the quarantined copy in
    `state/.pr-check-quarantine/` preserves the pre-repair bytes; a quarantined copy is the strongest evidence
    available and you should quote it.
  - The poll originally used a single inbox; the exchange directory is bidirectional.
  - Report the concrete observed symptom of each, and what evidence establishes it.

  ## Item 3 - proof the SCHEDULED WATCHER picks up inbound mail, not direct polling

  This is the item most likely to be over-claimed, so be rigorous. Controller is right to demand it.

  Required distinction: a `check:` wake proves the scheduled watcher; a message read because firstmate happened
  to run the poll proves nothing. Count ONLY the scheduled path.

  Gather:
  1. Which watcher processes serve this home, with their cwd and elapsed time.
     `for p in $(pgrep -f fm-watch); do readlink /proc/$p/cwd; done` plus `ps -o etimes`.
  2. Evidence of actual scheduled pickups in this session. Sources, read-only:
     - `state/.wake-queue` lines with kind `check`
     - the queue/beat records in `state/`
     - agent session transcripts under `~/.pi/agent/sessions/` and their timestamps
  3. The watcher's sweep interval (`FM_CHECK_INTERVAL`, default 300) from `bin/fm-watch.sh`.
  4. Whether the same messages were ALSO seen by direct polling. If both paths saw the same message, say so -
     that weakens the claim and Controller needs to know.

  **If the evidence does not cleanly separate scheduled from direct, say exactly that.** Do not construct a
  story that the scheduled path worked because you believe it should have.

  ## Hard boundaries
  Read-only. Do not run, write, edit, delete or move anything. Do not run tasks-axi. Do not touch projects/,
  warehouse/, or any secondmate home. Do not commit or push. If a claim cannot be evidenced, write UNVERIFIED
  and say what would settle it.

  ## REPORT - this is the deliverable
  Write `/home/hd2admin/kun-agent-workspace/data/evidence-six-20261015/report.md`, one section per item, with
  commands quoted and their real output. YOUR CHAT REPLY IS NOT THE DELIVERABLE. If the report file does not
  exist, the task is not done regardless of what you say in this pane.

## Archived 2026-10-15
- [x] controller-msg-triage-20261015 - Triage 183 unread Controller messages into a decision inventory (repo: firstmate) (kind: scout) (done 2026-10-15)
  Triage 183 unread Controller messages into an actionable decision inventory.

  ## Why this matters
  Automatic Controller reception was repaired on 2026-10-14 and now works. But 183 messages predate that
  repair and were never auto-surfaced. They contain Controller decisions, corrections, approvals and
  blockers that this home may never have processed. Right now they are just files.

  ## The two inbound sources
  - /home/hd2admin/controller-replies
  - /home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/to-brandon-compute

  Read across BOTH. Deduplicate by content hash: the same message can exist in both, and messages may be
  revisions of each other.

  ## Already known - do not re-report these
  - 2026-10-14-controller-current-decisions-and-staging-reply.md (read and acted on 2026-10-14)
  - 2026-10-15-controller-acknowledgement-of-hetz-receipt.md (read and acted on 2026-10-15)
  - Brandon's own outbound messages. You can recognise them: this home wrote them, and anything recorded in
    state/.controller-inbox-outbound by content hash is outbound and must NOT appear as a Controller message.

  ## What to produce
  For each DISTINCT Controller message that carries a decision, correction, approval, permission, denial or
  blocker, record:
  - filename, date, sha256 prefix
  - what it decides or changes
  - whether it appears to have been acted on by this home, with the evidence you checked
  - if unactioned: the single specific action it implies, and whether it is still possible

  Then produce three ranked lists at the top of your report:
  1. **Superseded** - decided something later changed. Name what superseded it.
  2. **Still binding** - still in force, may need action now.
  3. **Needs a decision from Controller** - ambiguous, or you cannot verify current state.

  ## Evidence discipline - this matters more than volume
  - Quote the exact line that carries the decision. No paraphrase of a decision.
  - A message that merely reports state is NOT a decision. Do not inflate it into one.
  - If you cannot verify whether something was acted on, say UNVERIFIED. Do not guess.
  - Do not treat a file's existence as evidence it was read. Read the content.
  - If two messages conflict, surface the conflict rather than picking one.

  ## Hard boundaries
  READ ONLY on all of the above. Never write to /home/hd2admin/controller-replies or the comms directories.
  Never write to the warehouse. Never touch projects/. Never run tasks-axi. Never push, never merge, never
  delete anything. If you cannot read a file, say so and move on rather than retrying.

  Report to /home/hd2admin/kun-agent-workspace/data/controller-msg-triage-20261015/report.md.

## Archived 2026-10-15
- [x] baseline-root-fix-20261015 - Fix fresh-agent baseline pointing at /root instead of Hetz home (repo: firstmate) (kind: ship) (done 2026-10-15)
  Fix the fresh-agent baseline so it points at this home, not the Controller's /root.

  ## The defect, independently verified
  `bin/fm-brief.sh` lines 145-146 and `bin/fm-session-start.sh` lines 238-239 both declare:
  ```
  local policy_file="/root/AGENTS.md"
  local project_policy_file="/root/agent-work/AGENTS.md"
  ```
  plus routing/bounded paths under /root/docs/agent-policy/.

  These are Controller-rooted paths. A fresh agent on Hetz is therefore handed a baseline manifest pointing at
  files it cannot read, on a filesystem it does not have. This is not theoretical: the brief generated for
  task `controller-msg-triage-20261015` carries it verbatim:
  ```
  policy=/root/AGENTS.md sha256:8f8f9b43dd878bdf958b17be0e19b2cbcbc4dc03258173622808a944d48739c7
  project-policy=/root/agent-work/AGENTS.md sha256:7e7eb3b65a6eef87a277fe00dbee4439c18d88f4f77756a7c3ed7b2bd349753d
  ```

  ## The files that actually exist here
  - /home/hd2admin/kun-agent-workspace/AGENTS.md        (66086 bytes)
  - /home/hd2admin/kun-agent-workspace/AGENT-POLICY.md  (24247 bytes)

  ## What to do
  1. Read /home/hd2admin/kun-agent-workspace/.agents/skills/firstmate-coding-guidelines/SKILL.md BEFORE editing.
     This is shared tracked material.
  2. Resolve these paths from the home, using the same convention every other script in bin/ already uses for
     home-relative files. Do not hardcode /home/hd2admin/kun-agent-workspace — the home moves, and FM_HOME
     exists precisely so it can. Find the existing convention and follow it rather than inventing one.
  3. Handle the routing and bounded files too. If a path has no home-local equivalent, do not silently point
     it somewhere fake. Either resolve it correctly or report it as still unavailable, with evidence.
  4. **Default-path behaviour must not change beyond this fix.** Byte-identical output is not achievable here
     because the paths themselves are the fix, but nothing ELSE in the emitted block may shift. Prove what did
     change and show it is only the resolved paths and their digests.
  5. Tests. Add or extend coverage in tests/ proving the emitted baseline resolves to readable, existing files
     on a non-root home. A test that only passes when run as root is worse than no test.
  6. Run the relevant suites and report exact PASS/FAIL counts. If `bash` is denied by the execution allowlist,
     try `/bin/bash <test>`; if that is also denied, report the exact refusal and STOP. Do not commit code you
     could not run tests on, and do not hand-edit a workaround.

  ## Boundaries
  Do not duplicate or interfere with the `provider-cap` or `--worklocation` implementation owners — Controller
  ruled against that explicitly. This is a different, separately-identified defect.
  Never use --force. Never rewrite history. No credentials. Nothing under any project clone.

## Archived 2026-10-15
- [x] provider-cap-20261014 - Add per-provider concurrency accounting to the dispatch guar (repo: firstmate) (kind: ship) (done 2026-10-15)
  Add per-provider concurrency accounting to the dispatch guard.

  `bin/fm-dispatch-guard.sh` currently enforces ONE global ceiling, `config/dispatch-max-lanes=6`, and already
  counts only confirmed idle lanes as free (unknown/unreadable lanes count as working). That part is correct and
  must not regress.

  What is missing: accounting PER PROVIDER. Right now six Codex tasks could saturate a provider while two other
  providers sit idle, and the guard would not notice.

  Do this:
  1. Read /home/hd2admin/kun-agent-workspace/.agents/skills/firstmate-coding-guidelines/SKILL.md BEFORE editing.
     Shared tracked material.
  2. Read bin/fm-dispatch-guard.sh and tests/fm-dispatch-guard-max-lanes.test.sh first. Understand the existing
     idle-detection and fail-closed behaviour before changing anything.
  3. Determine where provider identity actually comes from. Evidence: each task records `harness=` and
     `model=` in state/<id>.meta (e.g. `openai-codex/gpt-6-luna`). Use that. Do NOT invent a new config surface.
     If provider is not derivable from recorded metadata, say so and stop rather than guessing.
  4. Add a per-provider ceiling, defaulting to the global value so existing behaviour is unchanged unless
     configured. Document the config key in docs/configuration.md, which owns that surface.
  5. Fail closed. An unknown or unreadable lane counts as occupying its provider, exactly as it does today
     for the global ceiling. Never treat unknown as free.
  6. Tests: extend tests/fm-dispatch-guard-max-lanes.test.sh. Must cover per-provider saturation with global
     headroom free, unknown-lane counting as occupied, and the existing idle-lane behaviour unchanged.
     The existing 10 tests must still pass.
  7. Run the suite and report exact PASS/FAIL counts. No partial claims.
  8. Commit and push to origin/main. No force.

  Report to /home/hd2admin/kun-agent-workspace/data/provider-cap-20261014/report.md: how provider was derived,
  the config key, the exact test counts, and the commit sha.

## Archived 2026-10-15
- [x] worklocation-reland-20261014 - Land the brief --worklocation fix on the CURRENT base. (repo: firstmate) (kind: ship) (done 2026-10-15)
  Land the brief --worklocation fix on the CURRENT base.

  Commit 23f0468e on branch fm/brief-worklocation-template-fix adds `bin/fm-brief.sh --worklocation <absolute-path>`
  so a brief can point at a live path outside the git worktree. It was built on the pre-sync base and is NOT
  landed. Current main is cf2a3db3 and has moved on.

  Do this:
  1. Read /home/hd2admin/kun-agent-workspace/.agents/skills/firstmate-coding-guidelines/SKILL.md BEFORE editing.
     This task changes shared tracked material (bin/, tests/).
  2. Inspect commit 23f0468e: `git -C /home/hd2admin/kun-agent-workspace show 23f0468e`. Understand it fully.
  3. Port the change onto current main. Do not force, do not rebase destructively, do not drop other commits.
  4. The contract that matters: with NO --worklocation flag, generated briefs must be byte-identical to before.
     Prove it. A default-path regression here silently breaks every task.
  5. Add or update tests in tests/ for the new flag, including: absolute path accepted, path outside the
     worktree rendered correctly, and default output unchanged.
  6. Run the relevant test suite and report exact PASS/FAIL counts. Do not claim green on a partial run.
     A known-failing base suite must be reported as pre-existing, with evidence it fails on clean main too.
  7. Commit, push to origin/main. Never use --force.

  Report to /home/hd2admin/kun-agent-workspace/data/worklocation-reland-20261014/report.md with the commit
  sha, the byte-identity evidence for default briefs, and exact test counts.

## Archived 2026-10-15
- [x] offload-backlog-close-2-20261014 - Offload: close remaining in-flight backlog entries with proof (repo: firstmate) (kind: scout) (done 2026-10-15)
  Close every backlog entry the evidence proves LANDED. Landed means present in the target default branch or on a remote - a branch that exists but is unmerged is NOT landed however the status line reads. Never close PARTIAL. Verify each artifact and status tail yourself before closing; two entries were previously misreported as done. tasks-axi is denied in some sandboxes: if denied, report the exact refusal and stop, do not retry or work around.

## Archived 2026-10-15
- [x] hetz-gate-B-20261005 - Hetz Gate B: Namecheap 4-target classification (kind: scout) (done 2026-10-15)

## Archived 2026-10-15
- [x] hetz-gate-CD-20261005 - Hetz Gates C+D: four-project audit + data classification (kind: scout) (done 2026-10-15)

## Archived 2026-10-15
- [x] hetz-gate-E-20261005 - Hetz Gate E: production isolation/queue/db/file (kind: scout) (done 2026-10-15)

## Archived 2026-10-15
- [x] wake-loop-regression-test - Regression test for the wake drain loop contract (repo: firstmate) (kind: ship) (done 2026-10-15)
  SCOUT. Write ONE test script that proves the wake drain loop contract, into YOUR OWN WORKTREE.

  ## Write exactly this, relative to your current working directory
  `tests/fm-wake-drain-loop.test.sh`

  No

## Archived 2026-10-15
- [x] scope-enforcement-20261015 - SCOUT. Build the enforcement layer for the machine-readabl (repo: firstmate) (done 2026-10-15)
  SCOUT. Build the enforcement layer for the machine-readable scope registry. Read-only plus your own files.

  ## Context
  Controller's plan names `data/agent-scopes.tsv` at
  /home/hd2admin/agent-work/deightonllm-firstmate/data/agent-scopes.tsv as the ROUTING SOURCE OF TRUTH, with
  ticket 0025 to enforce it. I built that file. Controller said: "I will not build a gate that infers
  authorisation from prose", and he is right.

  Tonight's proof that the registry is needed: I routed a WordPress publish to `hetzner-compute`, whose
  `write_domains` excludes `PROJECT.APPLICATION.CODE`. He refused and was CORRECT. The refusal was right and the
  routing was mine. A registry plus a mechanical check would have stopped it at the dispatch boundary instead of
  costing a cycle.

  ## Your job
  Produce a DESIGN plus a WORKING READ-ONLY CHECK for `bin/fm-scope-check.sh`:
  - Reads the TSV (tab-separated: owner, surface, read_domains, write_domains, exclusions, notes).
  - Given an owner and a proposed action domain, answers ALLOW or REFUSE with the reason.
  - Fail closed: an owner absent from the registry is REFUSED, not allowed. An unreadable registry is REFUSED.
  - The check must be READ-ONLY. It refuses out-of-scope dispatches; it never grants.
  - Write it as a runnable script and prove it with a test that covers: in-scope ALLOW, out-of-scope REFUSE,
    cross-domain REFUSE where another domain IS owned, unknown owner REFUSE, unreadable registry REFUSE,
    and an exclusion overriding a matching write_domain.

  ## Read the registry first
  Read the actual TSV before designing. Do not design against my summary of it. If it lacks a column you need,
  say so in the report rather than inventing one.

  ## Where to write
  `bin/fm-scope-check.sh`, `tests/fm-scope-check.test.sh` and
  `data/scope-enforcement-20261015/report.md`, into YOUR OWN WORKTREE. Do NOT modify the registry itself.

  ## Report
  The design rationale, the fail-closed rules, the exact test counts, and anything in the TSV that makes
  enforcement impossible as written. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-15
- [x] full-suite-sweep-20261015 - SCOUT. Establish the REAL full-suite failure count, and wh (repo: firstmate) (done 2026-10-15)
  SCOUT. Establish the REAL full-suite failure count, and whether any are regressions. Read-only except
  for your own report.

  ## Why this exists
  Commit bab949ac's own status said the full suite had 39 failures and repository lint failed, and Controller
  said not to stack further work onto it until compared against a verified pre-change base. I proved ONE case
  (fm-brief.test.sh failed at bab949ac^ and passes now). I have NOT accounted for the other 39 and I will not
  claim they are resolved.

  ## Your job
  1. Run EVERY `tests/*.test.sh` in the CURRENT tree, one at a time, with a per-script timeout so one hang
     cannot stall the sweep. Record for each: pass or fail, exit code, and the count of `FAIL`/`not ok` lines.
  2. Report the TOTAL failing scripts and total failing assertions. Give me the number, not a summary.
  3. For any script that fails, extract the FAILING ASSERTION LINES verbatim.
  4. Then run the SAME sweep at base `bab949ac^` (commit 59c397c61d0b295a2464933ea6e7cdf865d7c1ca) in a
     temporary detached worktree, and produce the same per-script table.
  5. Produce a DIFF: scripts failing NOW that passed at base are REGRESSIONS and must be listed as such.
     Scripts failing at both are pre-existing and must be labelled pre-existing, with the base failure quoted.
     This distinction is the entire point of the task. Do not blur it.

  ## Hard constraints
  - Never touch the live `state/`, the live wake queue, or any secondmate home.
  - Use temporary directories for any worktree and any queue state.
  - If a test hangs, record it as TIMEOUT rather than killing the sweep.
  - Do NOT fix anything. This is measurement only. Do not edit bin/, tests/ or docs/.

  ## Report
  data/full-suite-sweep-20261015/report.md with both tables, the diff, and a plain VERDICT line stating the
  number of regressions caused by bab949ac. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-15
- [x] decision-hold-gate-diagnosis-20261015 - SCOUT. Diagnose why the decision-hold completion gate bloc (repo: firstmate) (done 2026-10-15)
  SCOUT. Diagnose why the decision-hold completion gate blocks delegated worker tasks. Read-only.

  ## The observed pattern
  At least four workers ended `blocked` rather than delivering:
  - `skill-collision-audit-20261015`: `shared decision-hold completion attestation not run because ...`
  - `core-staging-publish-ready`: `required decision-hold completion attestation would write task metadata
    outside the authorized three-file scope`
  - `provider-cap-20261014`: `bash is denied by the execution allowlist`
  - `evidence-items-56-20261015`: `Required account-scoped baseline and report paths are inaccessible`

  Controller has been asked twice and has not yet answered.

  ## Your job
  1. Read the decision-hold machinery. Start with `bin/fm-decision-hold.sh` and whatever it calls, and find
     the code that emits the attestation requirement and the scope check that rejects it.
  2. Identify the EXACT contradiction: which two things conflict. Name the file, the function and the line
     numbers on both sides.
  3. Determine whether the conflict is in the BRIEF CONTRACT or the GATE. Is a brief that authorizes three
     files structurally unable to satisfy an attestation that writes task metadata? Answer with code evidence.
  4. Say what the SMALLEST change would be that removes the contradiction, WITHOUT weakening the gate. If no
     such change exists, say that instead - do not invent one.
  5. Check whether the same gate is what blocked `skill-collision-audit` on a task that explicitly said
     PLAN ONLY, move nothing, delete nothing. If the gate fires on a task with no authorized state change, that
     is a distinct defect and name it separately.

  ## Boundaries
  READ ONLY. Do not edit, do not run tasks-axi, do not change config. No credentials. Quote exact lines with
  file and line number. If you cannot determine something, say so.

  ## Report
  data/decision-hold-gate-diagnosis-20261015/report.md. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-15
- [x] verify-discarded-metastore-20261015 - SCOUT. Audit the worktrees I cleaned tonight and prove not (repo: firstmate) (done 2026-10-15)
  SCOUT. Audit the worktrees I cleaned tonight and prove nothing was lost. Read-only, and this is an
  audit OF ME, so be adversarial.

  ## Context you are auditing
  Tonight I removed 12 treehouse worktrees. My stated evidence for each was: zero commits ahead of
  `origin/main` and zero TRACKED modifications. I then recovered 2 real features from slots I had judged
  empty or superseded, so my check was demonstrably insufficient at least twice.

  ## Your job
  1. Enumerate EVERY worktree registered in git for every project on this host, live or not.
  2. For each removed or present worktree, determine whether any commit, tracked change, or untracked file
     from it survives anywhere: in a branch, in a reflog, in a stash, in a packfile, in another worktree, or on
     a remote.
  3. Specifically probe for these, which I recovered tonight:
     - `50abe4e0` checksum-verified Brandon order delivery -> landed as 973ff553. Confirm.
     - `051cd56d` Recover exact stale watcher child -> preserved, NOT landed. Confirm it still exists.
     - `c020fa22` worklocation -> I claimed it landed as bab949ac. Verify that claim independently.
  4. Answer one question directly: **did removing those 12 worktrees destroy any unlanded work?** If yes, name
     exactly what and whether it is recoverable. If no, say so and show the evidence.
  5. Identify every OTHER unlanded commit anywhere on this host, with its reflog entry if orphaned.

  ## The failure mode to guard against
  I twice concluded "this slot is empty" from tracked-changes and commits-ahead only. **Untracked files and
  orphaned commits are invisible to that check.** Test for them specifically. If a worktree had untracked work
  at removal time and that work is now gone, say so plainly, even though it is my error and not yours.

  ## Boundaries
  READ ONLY. Do not restore, recover, modify, merge or delete anything. Do not run `git gc` or prune. Do not
  run tasks-axi. You may read reflogs, packs and stashes. Quote real command output.

  ## Report
  data/verify-discarded-metastore-20261015/report.md with a clear YES or NO on data loss, and the evidence.
  YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-15
- [x] secondmate-access-20261015 - SCOUT. Determine exactly why the seven secondmates report (repo: firstmate) (done 2026-10-15)
  SCOUT. Determine exactly why the seven secondmates report they cannot read their own files. Read-only.

  ## The reported symptoms, over several days, never root-caused
  - whoosh: `path may escape project root` plus not-found wording, on its OWN data/charter.md
  - elevate, hetzner: warehouse path refused as outside its home root
  - backup-dr: primary `data/domain-expertise-20261013` and `warehouse` refused as outside its home root
  - several: `tasks-axi` permanently denied by shell allowlist
  - several: worklocation-authorized paths still refused by the tool sandbox

  ## Your job
  1. For EACH of the seven secondmate homes under /home/hd2admin/.treehouse/, determine the FM_HOME actually
     in effect, and whether the file they claim cannot read actually exists there. Use the filesystem, not
     their reports.
  2. For each refusal type, find the MECHANISM in code or config that produces it. Name the file and line.
     Candidates worth checking: the tool sandbox root rule, the secondmate home seeding, and any path-escape
     check in the harness.
  3. Separate the causes into distinct classes. "Path outside home root" and "sandbox root" and "shell
     allowlist" are three different problems and must not be merged into one story.
  4. State for each class whether it is a firstmate-lane fix (I can fix it) or a Controller/harness fix (I
     cannot). Be explicit about who owns each.
  5. If any of the seven is actually fine and the refusals were transient or misdiagnosed, say so.

  ## Boundaries
  READ ONLY. Do not write, move or modify anything in any secondmate home. No credentials. Do not run tasks-axi.
  Quote real command output, not inference.

  ## Report
  data/secondmate-access-20261015/report.md with a per-home table, the mechanism per class with file and line,
  and an explicit owner per fix. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-15
- [x] registry-vs-filesystem-20261015 - SCOUT. Determine the TRUE state of the seven secondmates, (repo: firstmate) (done 2026-10-15)
  SCOUT. Determine the TRUE state of the seven secondmates, from the filesystem only. Read-only.

  ## Why
  `data/secondmates.md` registers seven secondmates. An audit found SIX of the seven registered home paths do
  not exist on the filesystem. So the register and the machine disagree, and I need to know which is telling the
  truth before anything is rewritten.

  ## Your job
  1. Enumerate EVERY directory under /home/hd2admin/.treehouse/. For each: its real path, and whether it looks
     like a live firstmate home (has state/, data/, bin/, AGENTS.md) or is a scratch remnant.
  2. For each candidate, read its `data/secondmates.md` and `data/captain.md` if present, and record what the
     home THINKS it is. A home's self-description is evidence, not authority.
  3. Produce a table: registry entry | registered path | exists? | self-described identity | last activity
     (newest mtime) | verdict.
  4. Give a clear per-secondmate verdict: LIVE AND REGISTERED CORRECTLY / LIVE BUT MISREGISTERED / GONE /
     NEVER EXISTED. Say which, from evidence.
  5. State the count of secondmates that are actually usable RIGHT NOW, and what each could be given to do.
  6. If a registered path is absent but a plausible home exists elsewhere, name the candidate path. Do not
     conclude they are the same home - say it is a candidate and what would confirm it.

  ## Boundaries
  READ ONLY. Do not create, move, seed, or repair any home. Do not edit data/secondmates.md. Do not run
  tasks-axi. Do not contact any agent. Quote real command output and real paths.

  ## Report
  data/registry-vs-filesystem-20261015/report.md with the table and the per-secondmate verdict.
  YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-15
- [x] commit-provenance-audit-20261015 - SCOUT. Establish provenance for commits I have been report (repo: firstmate) (done 2026-10-15)
  SCOUT. Establish provenance for commits I have been reporting on, from git alone. Read-only.

  ## The problem
  I reported `9601685d` "fix: stream fleet JSON into jq" as LANDED for much of tonight. An audit found it is NOT
  an ancestor of main. I took that from a status line rather than a merge-base check. I also found
  `c51cf8d9` "Add fm-brandon-queue-push helper and colocated test" which I had never mentioned.

  ## Your job
  For EACH of these commits, in every repo on this host, determine the truth:
  ```
  9601685d  fix: stream fleet JSON into jq
  c51cf8d9  Add fm-brandon-queue-push helper and colocated test
  973ff553  feat: add checksum-verified Brandon order delivery
  50abe4e0  (the original order-delivery commit)
  051cd56d  Recover exact stale watcher child
  c020fa22  Add explicit brief worklocation option
  bab949ac  (the worklocation land)
  f941d893  (the baseline scope-label land)
  ```

  1. Does the object exist? In which repositories?
  2. Is it an ancestor of that repo's default branch, on ANY branch, or orphaned? Use
     `git merge-base --is-ancestor` and `git branch -a --contains`. Never a status line.
  3. If its content is already present in main by a DIFFERENT commit, say so and prove it with a diff or
     tree-hash comparison. "Same content, different sha" is a real and common case and I need it identified,
     because it is the difference between work being lost and work being re-landed.
  4. Produce a table: commit | exists where | ancestor of main? | content-equivalent to which commit? | verdict.
  5. For anything NOT in main, state what it is and whether its work is already present by another route.

  ## Boundaries
  READ ONLY. No checkout, merge, cherry-pick, reset, rebase, gc or prune. No tasks-axi. Quote real git output.

  ## Report
  data/commit-provenance-audit-20261015/report.md. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-15
- [x] unlanded-commit-adjudication-20261015 - SCOUT. Assess two unlanded commits and recommend accept or (repo: firstmate) (done 2026-10-15)
  SCOUT. Assess two unlanded commits and recommend accept or drop, with evidence. READ ONLY - decide nothing.

  ## The two commits
  ```
  9601685d  "fix: stream fleet JSON into jq"
            fm/fleet-snapshot-arg-limit, NOT an ancestor of main
  c51cf8d9  "Add fm-brandon-queue-push helper and colocated test"
            overnight/queue-push-helper, NOT an ancestor of main
  ```

  ## Why they matter
  I reported `9601685d` as landed for much of tonight. It is not. Both have sat unlanded while I reported
  otherwise. They are now with Controller for a decision and I must be able to describe accurately what they
  contain and whether it is still needed.

  ## Your job
  1. For each commit: full diff, the problem it claims to solve, and what it changes.
  2. **Is the work already in main by another route?** Compare against current main with a real diff, not a
     commit message. For `9601685d` specifically, check whether `bin/fm-fleet-snapshot.sh` currently streams JSON
     or still passes bulk JSON on an argument vector. That is the specific defect the commit claims to fix - verify
     the current behaviour directly.
  3. Run the commit's own tests, or the relevant existing tests, against BOTH main and the commit, and report the
     actual results.
  4. State plainly: is this work WANTED, ALREADY PRESENT, or OBSOLETE? Give the evidence for whichever you choose.
  5. Identify any risk in landing it. If it supersedes something now in main, say exactly what.

  ## Boundaries
  READ ONLY. Do not merge, cherry-pick, checkout onto a branch, or modify the working tree. You may create a
  TEMPORARY detached worktree under /tmp for inspection and you must remove it. No tasks-axi. No gc or prune.

  ## Report
  data/unlanded-commit-adjudication-20261015/report.md with a clear per-commit verdict and the evidence.
  YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-15
- [x] docs-index-writeup-20261015 - SCOUT. Write `docs/README-index.md` - a navigation index f (repo: firstmate) (done 2026-10-15)
  SCOUT. Write `docs/README-index.md` - a navigation index for docs/ - into YOUR OWN WORKTREE.

  ## Why
  Over 40 files sit in `docs/` with no index. Two landed tonight are currently unfindable:
  `docs/operating-decisions-2026-10-14-15.md`, `docs/verification-discipline.md`, `docs/wake-drain-loop.md`.
  A worker was asked to do this already and correctly refused to overwrite the existing `docs/README.md`, which is
  a committed warehouse contract from 2026-10-04.

  ## Write exactly this
  `docs/README-index.md` and `data/docs-index-writeup-20261015/report.md`. Nothing else.

  ## Do NOT touch `docs/README.md`
  It is committed, tracked content and a warehouse contract. Leave it completely alone. Your file is the index;
  it is a different document. If you believe a cross-reference belongs in the existing README, put that suggestion
  in YOUR report instead of editing it.

  ## How to build the index
  1. `ls docs/` first. Do not work from memory or from what I told you.
  2. Read the opening of each file to learn what it actually settles. Do not infer contents from filenames - I
     have made that mistake in this session more than once.
  3. Group by audience and urgency, not alphabetically:
     - READ EVERY SESSION: the supervision protocol for the harness in use, watcher continuity, this index
     - READ WHEN DISPATCHING OR BLOCKED: backends (herdr, tmux, orca, cmux, zellij), configuration, calm,
       decision-hold-lifecycle, subagent-guard, arm-pretool-check, cd-guard
     - REFERENCE: audits, studies, dated incident records, warehouse material. NOT for routine reading.
  4. One line per entry on WHAT it settles, so a reader knows whether to open it.
  5. Mark GENERATED files so nobody edits a render. Check each file's header for that.
  6. Flag any file whose name implies it is current but whose content is dated or superseded. Do not edit it.

  ## Rules
  No config keys. No other files. Every claim from reading the actual file.

  ## Report
  data/docs-index-writeup-20261015/report.md: what you indexed, what you excluded and why, every file you
  believe is stale, and your suggestion for the existing docs/README.md.
  YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-15
- [x] outbound-order-review-20261015 - SCOUT. Review the checksum-verified order delivery feature (repo: firstmate) (done 2026-10-15)
  SCOUT. Review the checksum-verified order delivery feature just landed, and find its integration point.

  ## What landed
  `bin/fm-outbound-order.sh` (413 lines) and `tests/fm-outbound-order.test.sh` (218 lines), commit 973ff553.
  It sat unlanded in a treehouse worktree from 3 October and was invisible to every register. It provides
  checksum-verified Brandon order delivery.

  ## Your job
  1. Read `bin/fm-outbound-order.sh` in full. Do not skim.
  2. Answer: is it SAFE to wire into dispatch? Specifically, check for: path traversal in ids, whether a remote
     checksum mismatch can advance state, whether a transport failure can be mistaken for delivery, whether any
     code path can mark an order accepted without a matching acknowledgement, and whether it writes outside its
     own directories.
  3. Check the RELATIONSHIP to the existing `bin/fm-outbound.sh`. Both exist. Do they overlap, conflict, or is
     one meant to replace the other? State which, with evidence from the code.
  4. Identify the missing integration: what would have to change for a dispatch to actually USE this? Name the
     files and the hook point.
  5. List every test case the suite does NOT cover.

  ## Boundaries
  READ ONLY. Do not edit, run against a real remote, or change any file. Do not run tasks-axi. No credentials,
  no network calls to any order system. If you cannot verify something, write UNVERIFIED and say what would
  settle it.

  ## Report
  data/outbound-order-review-20261015/report.md. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-15
- [x] core-branch-inventory-20261015 - SCOUT. Build a complete, verifiable inventory of ALL retai (repo: firstmate) (done 2026-10-15)
  SCOUT. Build a complete, verifiable inventory of ALL retained branches across every project. Read-only.

  ## Why
  Three Core-Distro branches are retained and Captain's rule is: retained is NOT merge approval, and a merge
  needs a NAMED branch and explicit approval. Two more commits were found unlanded in worktrees tonight. Nobody
  can currently answer "what unlanded work exists, everywhere".

  ## Your job
  1. For EVERY git worktree in this home, report: project, branch, commits ahead of its origin default branch,
     tracked modifications, untracked files. Use git commands, not inference.
  2. For every branch found ahead, list the commits with subject and the files each touches.
  3. Classify each: ALREADY LANDED (the commit is reachable from the default branch) vs GENUINELY UNLANDED.
     Verify with `git merge-base --is-ancestor`, never by reading a status line.
  4. For genuinely unlanded work, state what it is, in one line, and whether it has tests.
  5. Flag anything that is a DUPLICATE of work already in main.

  ## Known state, verify it rather than trusting it
  - core-distro-saas-clean retains: fm/core-stream-a-checkpoint-0924 (4 ahead),
    fm/core-mobile-fix (3 ahead), fm/core-v3-product-acceptance-spec-0927 (2 ahead)
  - fm/brief-worklocation-template-fix is captain-held and its work landed as bab949ac
  - 2 commits from 3 October were recovered tonight: 50abe4e0 (landed as 973ff553) and 051cd56d (preserved,
    unlanded, needs Controller)

  ## Boundaries
  READ ONLY. Do not merge, discard, reset, clean, stash or delete anything. No force operations. Do not run
  tasks-axi. Do not touch warehouse/ or any secondmate home.

  ## Report
  data/core-branch-inventory-20261015/report.md with a clear table, the classification, and a final count of
  how much unlanded work exists. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-17
- [x] docs-discoverability-20261015b - SCOUT. Write `docs/README.md` - the index of docs/ - into (repo: firstmate) (done 2026-10-15)
  SCOUT. Write `docs/README.md` - the index of docs/ - into YOUR OWN WORKTREE.

  ## Write exactly this
  `docs/README.md` and `data/docs-discoverability-20261015b/report.md`. Nothing else. No branch, no commit,
  no push. Do not modify any existing doc.

  ## Why
  Over 40 files now sit in `docs/` with no index. A new firstmate cannot tell which to read first, and I have
  been reading them at random for hours. Two landed tonight and are currently unfindable:
  `docs/operating-decisions-2026-10-14-15.md`, `docs/verification-discipline.md`, and `docs/wake-drain-loop.md`.

  ## How to build it
  1. LIST the actual directory first. Do not work from memory or from what I told you.
  2. Read the first lines of each file to know what it actually settles. Do not infer contents from filenames.
  3. Group by AUDIENCE and URGENCY, not alphabetically:
     - READ EVERY SESSION: the supervision protocol for the current harness, watcher continuity, this index
     - READ WHEN DISPATCHING OR BLOCKED: backends (herdr, tmux, orca, cmux, zellij), configuration, calm,
       decision-hold-lifecycle, subagent-guard
     - REFERENCE: audits, studies, historical incident records. These are NOT to be read routinely.
  4. For each entry, ONE line on what it settles, so a reader knows whether to open it.
  5. Mark anything GENERATED rather than authored, so nobody edits a render. Check the file header.
  6. Flag any doc whose name suggests it is current but whose content is dated or superseded. Do not edit it -
     flag it in the report.

  ## Rules
  No config keys. Do not create files other than the two named. Every claim from reading the file.

  ## Report
  data/docs-discoverability-20261015b/report.md: what you indexed, what you left out, and every doc you
  believe is stale. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-17
- [x] stale-default-key-diagnosis-20261015 - SCOUT. Diagnose the stale `default` decision key that has (repo: firstmate) (done 2026-10-15)
  SCOUT. Diagnose the stale `default` decision key that has blocked five scout completions. READ ONLY.

  ## The exact error, reproduced
  ```
  $ fm-decision-hold.sh complete outbound-order-review-20261015 --none
  fm-decision-hold: open structured decision outbound-order-review-20261015/default
    has no captain-held inventory entry
  ```

  Five tasks are blocked this way. Their reports are COMPLETE. `tasks-axi show` returns `hold_reason: -` and
  `hold_kind: -` for all of them, so the captain hold the key refers to no longer exists.

  ## Your job
  1. Read `bin/fm-decision-hold.sh` in full, especially `command_complete()`, `fm_wake`-independent key
     handling, and anything that reads or writes a `default` key.
  2. Find EXACTLY where the `default` key comes from. Is it a default argument, a fallback when no key is
     supplied, or something recorded earlier? Give file and line numbers.
  3. Determine why `--none` does not clear it. Trace the code path with `--none` supplied.
  4. Answer the operational question: **what is the correct, supported way to retire a decision key whose
     captain hold no longer exists?** Find the command if one exists. If the tool provides no supported way,
     say so plainly - that is itself the answer, and it means the tool has a gap.
  5. State whether this is a tool defect, a usage error, or a state-hygiene problem, with evidence. Do not
     soften it to be agreeable.
  6. Explain why `--none` was designed as an explicit semantic attestation if it cannot retire a stale key.

  ## Boundaries
  READ ONLY. Do not run `complete`, `hold`, `resolve` or any mutating subcommand. Do not run tasks-axi writes.
  Do not edit task state or the script. You may read. Quote real output.

  ## Report
  data/stale-default-key-diagnosis-20261015/report.md. If the answer is "the tool has no supported path", say
  that first and plainly. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-17
- [x] docs-discoverability-20261015 - SCOUT. Make the new documentation discoverable. Docs only, (repo: firstmate) (done 2026-10-15)
  SCOUT. Make the new documentation discoverable. Docs only, into YOUR OWN WORKTREE.

  ## Write these, relative to your current working directory
  1. `docs/README.md` — an index of docs/, grouped by audience, that a future firstmate can navigate.
  2. `docs/wake-drain-loop.md` — already written and shipped; do NOT rewrite it, reference it.

  ## Context
  Two new docs landed tonight and are currently unfindable:
  - `docs/operating-decisions-2026-10-14-15.md` — dispatch routing, Controller/Hetz authority, warehouse
    ownership, superseded-message handling, retained branches
  - `docs/verification-discipline.md` — how this home decides something is true
  Plus `docs/wake-drain-loop.md`, added after a Controller message went unread.

  Existing docs/ already holds ~40 files including herdr-backend.md, tmux-backend.md, turnend-guard.md,
  watcher-continuity.md, configuration.md, calm.md, supervision-protocols/. Your index must cover the ones a
  firstmate needs FIRST, and say which are read-once references versus read-every-session.

  ## Rules
  - Group by audience and urgency, not alphabetically.
  - For each entry, one line on WHAT it settles, so a reader knows whether to open it.
  - Mark the owning source for anything that is generated rather than authored, so nobody edits a render.
  - Do NOT create config keys. Do NOT modify any existing doc. `docs/README.md` does not exist yet — create it.
  - Every claim must come from reading the actual file. Do not infer contents from filenames.

  ## Report
  data/docs-discoverability-20261015/report.md: what you indexed, what you deliberately left out and why.
  YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-17
- [x] evidence-items-56-20261015 - SCOUT. Gather evidence for two Controller items. Read-only (repo: firstmate) (done 2026-10-15)
  SCOUT. Gather evidence for two Controller items. Read-only.

  ## Item 5 — the 10 still-binding inbound messages
  An earlier triage of 75 distinct inbound Controller messages classified 7 as SUPERSEDED, 10 as STILL BINDING,
  and 7 as needing Controller. For the 10 still-binding ones, produce a table:
  - filename, date, sha256 prefix
  - the exact quoted line that carries the binding instruction
  - whether it is blocked-on-Controller or blocked-on-Hetz, and the specific condition
  - whether, as far as you can evidence it, it is still in force

  CRITICAL: seven of these were recorded as Crisp-R-DEPENDENT. Mark those `blocked-on-crispr` explicitly rather
  than folding them into `blocked-on-hetz`. Collapsing those two was a mistake I made earlier and want corrected.

  ## Item 6 — the baseline-path fix: changed paths and verification
  Commit bab949ac added `--worklocation` to bin/fm-brief.sh. Later, f941d893 corrected the fresh-agent baseline
  scope labels. For BOTH, report:
  - every file changed, with the exact lines changed
  - the verification actually run, quoting real output, not a summary
  - explicitly: what remains INCOMPLETE. bab949ac amends the brief but does NOT amend the tool sandbox, which
    still refuses paths outside the isolated worktree. That limitation must be stated, not omitted.

  ## Hard boundaries
  Read-only. Do not write, edit, move or delete. No tasks-axi. No git operations. Nothing under projects/,
  warehouse/ or any secondmate home. If you cannot evidence a claim, write UNVERIFIED and say what would settle it.

  ## Report
  data/evidence-items-56-20261015/report.md. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-17
- [x] skill-collision-audit-20261015 - SCOUT. Produce an exact, reversible plan to remove duplica (repo: firstmate) (done 2026-10-15)
  SCOUT. Produce an exact, reversible plan to remove duplicate skill-name startup warnings. PLAN ONLY — move
  nothing, delete nothing.

  ## The problem
  Pi prints duplicate skill-name warnings at startup. Established inventory:
  - project winner + backup: .agents/skills/quota-axi/SKILL.md and
    .agents/skills/quota-axi.bak-20261006/SKILL.md  (the BACKUP is discovered as a skill)
  - project + global duplicates: no-mistakes, tdd-red-green-refactor, quota-axi
  - user/package duplicates: council-mode, pi-subagents
  - prior report: data/skill-collisions-cleanup-20261013/report.md
  - a prior attempt tested `-path` exclusions and RESTORED settings byte-for-byte: the exclusions did NOT
    suppress the auto-scanned root, so the documented remedy failed

  ## Your job
  1. Enumerate EVERY colliding skill name with ALL its locations, and for each, its sha256 and byte size.
  2. For each collision, identify which copy is the WINNER. Evidence for a winner: the one the runtime resolves,
     the one referenced by config or settings, the newest correct one. State the evidence, not a preference.
  3. For each NON-winner, state the exact reversible action: move to a path OUTSIDE every scanned root, or
     rename with an extension the scanner ignores. Say which, and give the exact command.
  4. State what would be LOST by each action and where the content would live afterwards, so nothing is destroyed.
  5. Record the exact bytes of every file BEFORE any action, so the plan is reversible.

  ## Hard boundaries
  PLAN ONLY. Move nothing. Delete nothing. Rename nothing. Never touch node_modules or package contents.
  Never touch the canonical skills/ installer surface. Every action you propose must be reversible and must
  name where the content goes.

  ## Report
  data/skill-collision-audit-20261015/report.md: a table of collisions with locations, hashes, winner and the
  evidence for it, then an ordered action list with exact commands. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-17
- [x] core-staging-publish-ready - Prepare Core staging publish runbook and restore plan (repo: firstmate) (kind: scout) (done 2026-10-15)
  SCOUT TASK. Prepare the Core staging publication so it is ONE COMMAND away from done, without touching the
  staging host. The host route is Controller-side and no key transfer is authorized, so publica

## Archived 2026-10-17
- [x] controller-inbox-local-repair-20261013 - Repair local automatic Controller inbox receipt with rollback proof (kind: ship) (done 2026-10-15)
  Captain-authorized private operational repair only: normalize basenames, actual Controller exchange folder, missing-contract fallback under genuine away flag; delegate MiniMax; focused red/green behavior plus registered runtime receipt and executed rollback/reapply before completion. No shared tracked change, duplicate Controller repair, permission edit or source merge.

## Archived 2026-10-17
- [x] wo0005-1-skill-collision - WO-0005 RESUME the stopped task. The security gate is (repo: firstmate) (kind: scout) (done 2026-10-15)
  RESUME the stopped task. The security gate is CLEARED BY ANSWER, not by a narrower scan.
  The 419 findings are the known 2026-09-28 deliberately quarantined class (IDE conversation
  transcripts and the quarantine dir), already handled. The Controller root scan passes with 191
  paths accepted. Do NOT re-litigate the scan and do NOT stop for it again.

  TASK: plan the duplicate skill-name cleanup. PLAN ONLY unless the plan is trivially safe.

  1. Enumerate every colliding skill name with ALL locations: absolute path, sha256, bytes, mtime.
  2. Identify the WINNER per collision, with runtime- or config-derived evidence. Not 'newest wins'.
  3. For each non-winner, the exact reversible action and command, and where content lives afterwards.
  4. Record sha256 of every file BEFORE any action, so the plan is reversible and verifiable.
  5. Find the ROOT CAUSE of why a `.bak-` directory scans as a skill, and address that in the plan -
     fixing the mechanism prevents recurrence better than moving one directory.

  HARD BOUNDARIES: move nothing outside the plan. Never touch node_modules or package contents.
  Never touch the tracked `skills/` installer surface. Do not modify settings. If you judge an action
  safe and reversible, you may execute it and record the before/after hashes; anything else stays a plan.

  Report: data/wo0005-1-skill-collision/report.md with the table, winners with evidence, root cause, and
  the ordered action list. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-17
- [x] wo0005-2-domain-prds - WO-0005 Produce ONE short PRD and ONE named owner per (repo: firstmate) (kind: scout) (done 2026-10-15)
  Produce ONE short PRD and ONE named owner per client domain. This is client work nobody
  owns yet, and it is the deliverable.

  ## Source of truth
  `/home/hd2admin/agent-work/deightonllm-firstmate/data/agent-scopes.tsv` - the authoritative 7-row
  registry. READ IT FIRST. Do not work from my summary of it.

  ## The seven
  core-ops, whoosh-ops, cbddata-ops, elevate-p0-repair, hetzner-compute, backup-dr, system-ops

  ## Measured live state, 2026-10-15 - use this, it is verified
  ```
  core-distro.com         200  live  'Pharmaceutical Supply Distribution'  Namecheap 66.29.153.174
  elevatesci.com          200  live                                        Hostinger+Cloudflare
  agents.elevatesci.com   200  live  AnythingLLM
  cbd-data.com            200  live  'Automated B2B Lead Generation'
  data.core-distro.com    200  live
  whooshperformance.com   200  PARKED DOMAIN on Hostinger DNS - NOT A SITE
  staging.core-distro.com 000  cert EXPIRED *and* app 500 - two separate faults
  ```

  The WordPress port is healthy on a private origin: Astra 4.14.0 + child theme, suite 10/10, 12 routes
  200. It has never been published. Artifact revision 50ae6849c190, 19/19 checksums, acknowledged as
  reported but NOT independently accepted. Chatbot INACTIVE. No DB/page/menu state in the artifact.

  ## For each domain produce
  - **Owner** (exactly one, from the registry) and why that owner
  - **What done means**, as verifiable statements - a command or an observable fact, never 'working well'
  - **Current measured state** against those statements
  - **The next single action**, named, with who does it
  - **What is explicitly out of that owner's scope**
  - **Blocked-on**, with the exact condition

  ## Constraints
  Evidence only. No deploy, publish, merge or change. No writes to projects/ or any secondmate home.
  Quote the registry rows you relied on. If a domain has no live surface, say so - whoosh is parked, and
  that is the finding, not a failure to work around.

  Report: data/wo0005-2-domain-prds/report.md, one PRD per domain plus the owner assignment table.
  YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-17
- [x] wo0005-4-routing-and-wo0007 - WO-0005 Two items, both mine, both currently unfinishe (repo: firstmate) (kind: scout) (done 2026-10-15)
  Two items, both mine, both currently unfinished.

  ## (a) Put the Controller-routing rule into account-scoped agent instructions
  Ordinary operational decisions, status, dispatch, review, collision resolution, work-order clarification
  and reachability route to the CONTROLLER, not the Captain. The Captain is the fallback when the
  Controller is unavailable, and retains the hard gates: spending, destructive or irreversible actions,
  credentials and key transfer, live production/DNS/registrar, the Aminolifesciences archive, branch merges.

  The Captain has directed that ordinary operational decisions go to Controller FIRST, and that this be
  visible to every agent on this surface. Propose the exact text AND the exact file it belongs in. It is
  account-scoped agent instructions, NOT AGENTS.md and NOT the tracked repo. **Propose; do not install.**
  Justify the placement from the actual file layout, not from assumption.

  ## (b) Finish WO-0007 / ticket 0027 - Hetz capacity and routing, your own P0
  Open items from your capacity work:
  - 13 free treehouse slots currently idle; state how many are safely usable and how the count is derived
  - the five inbound Controller routes and how they are now watched
  - the scope gate and what it refuses
  - the transmission guarantee and what remains unproven
  - any remaining P0, named

  Ground EVERY number in a command you ran. Do not carry a figure forward from an earlier report without
  re-deriving it - that is how the 16/16 slots and the '17 features' errors happened.

  ## Constraints
  Propose, do not install. No edits to shared tracked material. No writes outside data/. No tasks-axi
  mutations. No cleanup, no merge, no deploy.

  Report: data/wo0005-4-routing-and-wo0007/report.md. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-17
- [x] backlog-evidence-closure-20261015 - SCOUT. Determine which of the 14 in-flight backlog entries (repo: firstmate) (done 2026-10-17)
  SCOUT. Determine which of the 14 in-flight backlog entries can be closed, and produce the exact evidence for
  each. REPORT ONLY - do not close anything yourself, and do not run any tasks-axi command.

  ## The 14
  ```
  skill-collision-fix-20261015          brief-worklocation-template-fix
  domain-expertise-20261013             durable-recovery-20261013
  overnight-secondmate-progress-20261012 reliability-routing-20261012
  reliability-reporting-20261012        reliability-permission-20261012
  core-distro-stage-article-drawer-fix-20261012
  core-distro-stage-scale-100pct        elevate-anythingllm-repair
  controller-watcher-tdd               outbox-delivery-tdd
  elevate-ops-source-map
  ```

  ## Known constraints you must respect in your recommendation
  - Controller has said: the six absent secondmate homes and the six phantom backlog rows are **findings held
    for the Captain, not authorisation to close.**
  - Controller has said: **do not re-dispatch** the four reliability blockers.
  - The three retained Core branches are retained; keeping is not merge approval.

  ## Your job
  For EACH of the 14, produce a row: entry | has brief? | has report? | has status? | backlog state | what the
  evidence shows | CLOSABLE / KEEP OPEN / PHANTOM (no artifacts) | the exact evidence.

  Be strict about the distinction: a task with a report may still not be complete. A task with no artifacts at
  all is a phantom, and phantom is a finding, not a closure.

  Then give three lists at the end:
  1. Safely closable NOW, with proof.
  2. Must stay open, with the reason.
  3. Phantoms or findings held for the Captain.

  ## Constraints
  Do NOT run `tasks-axi done`, `block`, `hold`, or any mutating subcommand. Do not edit files. Do not create,
  move or delete anything. Read only.

  ## Report
  data/backlog-evidence-closure-20261015/report.md. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-17
- [x] docs-freshness-audit-20261015 - SCOUT. Audit docs/ for claims that are now FALSE against t (repo: firstmate) (done 2026-10-17)
  SCOUT. Audit docs/ for claims that are now FALSE against the current system. READ ONLY.

  ## Why
  Tonight changed a great deal: 18 commits, five inbound routes instead of two, a scope gate, an atomic
  Controller sender, a corrected wake-drain contract, six secondmates found absent, an unlanded-work audit.
  **Some existing docs almost certainly now describe a system that no longer exists.** Those are worse than
  missing docs, because they are trusted.

  ## Your job
  1. Read `docs/README-index.md` and each doc it lists as current-for-routine-use.
  2. For each, extract the specific factual claims it makes about current behaviour.
  3. Check those claims against the CURRENT system. Verify by reading the actual code, not by trusting the doc.
     Priority claims to check:
     - does any doc describe one or two Controller inbox routes, where there are now five?
     - does any doc describe the wake drain as a single call, or as a loop? (the current contract is ONE call,
       with raw rows authoritative and annotations supplemental)
     - does any doc describe the fresh-agent baseline as pointing at /root without a scope label?
     - does any doc claim the decision-hold gate needs something it does not, or that status lines may be
       unkeyed?
  4. Produce a table: doc | stale claim | what is actually true now | evidence (file and line).
  5. Rank by how badly a reader would be misled. A doc that is merely incomplete is not the same as one that
     asserts the opposite of the truth.
  6. Do NOT edit any doc. Report only.

  ## Constraints
  READ ONLY. No edits, no commits, no pushes, no config changes. No tasks-axi. Quote real code with file and
  line for every claim you check. If you cannot verify a claim, mark it UNVERIFIED.

  ## Report
  data/docs-freshness-audit-20261015/report.md. YOUR CHAT REPLY IS NOT THE DELIVERABLE.

## Archived 2026-10-17
- [x] core-live-audit-20261015 - SCOUT. Establish the TRUE current state of every live clie (repo: firstmate) (done 2026-10-17)
  SCOUT. Establish the TRUE current state of every live client surface, from the network outward. READ ONLY.
  Do not deploy, publish, merge, or change anything. No writes to any project.

  ## Why this exists
  My last domain triage was hours ago and everything in it was reported rather than measured where I could
  measure it. Controller accepted it and then found errors in my own claims. I am not repeating that.

  ## The surfaces
  ```
  core-distro.com        https://core-distro.com
  elevatesci.com         https://elevatesci.com
  agents.elevatesci.com  https://agents.elevatesci.com
  cbd-data.com           https://cbd-data.com
  whooshperformance.com  https://whooshperformance.com
  data.core-distro.com   https://data.core-distro.com
  staging.core-distro.com https://staging.core-distro.com
  ```

  ## For EACH surface, report
  1. **HTTP status and the exact remote IP**, from a real request. Not a cached or inferred value.
  2. **The actual page title and a content fingerprint** - enough to tell whether it is WordPress, a Next.js
     app, a parked domain, or an error page. Quote what you actually saw.
  3. **Server and generator headers** if present.
  4. **Whether a certificate is valid and who issued it.**
  5. For staging specifically: distinguish a connection failure from an HTTP error, and report the raw curl
     outcome rather than a summary.
  6. Any surface that is DOWN, ERRORING, or PARKED - name it plainly.

  ## Constraints
  - GET and HEAD only. Never POST. Never submit a form. Never authenticate.
  - **Do not touch live core-distro.com or elevatesci.com beyond a read-only GET/HEAD.** They are production.
  - No DNS changes, no writes, no deployments.
  - If a request times out or refuses, record the exact error, not "unreachable" as a summary.

  ## Report
  data/core-live-audit-20261015/report.md with one row per surface and a plain VERDICT line: how many of the
  seven are healthy, how many are broken, how many are unreachable.
  YOUR CHAT REPLY IS NOT THE DELIVERABLE.
<!-- archived by fm-backlog-mark-done.sh -->
- [x] core-coverage-data-semantics-decision-20261020 (done 2026-10-20 — Captain decided: an imported lead's pre-scraped cities and states ARE coverage, the import must reflect them, and exports must carry them; PA-11/12/13 ratified as drafted) - Decide the canonical covered relation and what searched means (repo: core-distro-saas-clean) (kind: captain) (priority: 1) (since 2026-10-20)
- [x] core-acceptance-criteria-ratification-20261020 (done 2026-10-20 — the Captain ratified PA-11, PA-12 and PA-13 as drafted, and accepted the ranked order for the 15 second overview, the grouped-aggregate rewrite first and the summary table as the follow-on) - Ratify the missing acceptance criteria for preset correctness, latency and first paint (kind: captain) (priority: 1) (since 2026-10-20)
- [x] core-enrichment-surface-hetzner-ready-20261020 (done 2026-10-20 - readiness proven and written; the go-live itself is blocked only on the Captain's key rotation, tracked as rotate-exposed-provider-keys-20261020) - Get the enrichment surface ready to run on this Hetzner host (repo: core-distro-saas-clean) (kind: ship) (priority: 1) (since 2026-10-20)
- [x] core-spec-record-ratified-criteria-20261020 - Record PA-11, PA-12, PA-13 and the ratified coverage decision in the canonical acceptance spec (repo: core-distro-saas-clean) (kind: ship) (priority: 1) (since 2026-10-20)
- [x] core-doc03-source-binding-20261020 - Bind the deployed bytes of every Core surface to the commit that produced them, so DOC-03 source authority can be closed (repo: kun-agent-workspace) (kind: scout) (priority: 1) (since 2026-10-20)
- [x] core-mcode-401-surface-closeout-20261020 - Close out the MCode /reload Plugin Cloud 401 and record the non-Core surface state (repo: kun-agent-workspace) (kind: ship) (priority: 3) (since 2026-10-20)
- [x] firstmate-pi-runtime-retire-m27-20261020 - Remove the retired MiniMax M2.7 from the Pi runtime enabledModels (repo: kun-agent-workspace) (kind: ship) (since 2026-10-20)
- [x] core-top-cities-preset-truncated-by-state-blind-coverage-20261020 - Fix the Top Cities preset returning 184 cities for a Top 200 preset, caused by a state-blind imported-city coverage re-check on the client (repo: core-distro-saas-clean) (kind: ship) (priority: 1) (since 2026-10-20)
- [x] core-m5-readiness-evidence-20261020 - Produce the operational-readiness evidence for the 32 D2 rows and 38 M5 items, which are 0 of 38 VERIFIED (repo: core-distro-saas-clean) (kind: ship) (priority: 1) (since 2026-10-20)
- [x] controller-report-routing-authorization-0926 (resolved 2026-09-26 — captain confirmed via controller: hd2admin route unchanged, reports address Controller; see brandon-inbox protocol note) - Confirm Controller reporting and SSH route (repo: firstmate) (kind: captain) (since 2026-09-26) (hold: A Dubz inbox message claims a new Captain instruction to send every report only to Controller and gives a root@100.117.47.27 SSH route, replacing the verified hd2admin route for non-secret status. No direct Captain words authorize this security-sensitive route change, and Controller-only reporting conflicts with the current Firstmate captain-facing contract. Option A: retain the verified hd2admin route for any non-secret Controller updates and keep Captain-facing outcomes. Option B: provide a direct instruction naming the new recipient, exact authenticated account and route, and reporting scope. No root connection or status message was sent.) (hold-kind: captain)
- [x] reissued-work-orders-20260930-receipts - Reissue the two 2026-09-30 work orders with receipt-verified delivery and record each receipt with its artifact path (repo: kun-agent-workspace) (kind: ship) (since 2026-10-21)
- [x] core-twin-inventory-20261020 - Establish which Core file pairs are byte-identical twins, whether the diverging ones are a defect, and what the gate actually protects (repo: kun-agent-workspace) (kind: scout) (since 2026-10-20)
- [x] core-m5-owner-readiness-sheet-20261020 - Produce the owner-facing M5 readiness sheet so the unsigned readiness rows are asked, not left unsigned (repo: kun-agent-workspace) (kind: docs) (since 2026-10-20)
- [x] firstmate-main-land-hd2-tips-20261020 - Land HD2's four tips into the firstmate repo's origin/main as the merge lane, and make the P0 green (repo: firstmate) (kind: ship) (since 2026-10-20)
- [x] firstmate-startup-memory-curation-20261020 - Curate the three memory files from 41,224 estimated tokens down to the 7,500 startup budget (repo: kun-agent-workspace) (kind: ship) (since 2026-10-20)
- [x] offload-backlog-phantom-20261014 - Close backlog entries that never existed data/offload-backlog-phantom-20261014/report.md (repo: firstmate) (kind: scout) (reported 2026-10-20)
- [x] offload-backlog-close-20261014 - Close every backlog entry the evidence proves closable data/offload-backlog-close-20261014/report.md (repo: firstmate) (kind: scout) (reported 2026-10-20)
- [x] clear-obsolete-20261013-decision-default - Backlog clearing pass complete, verdicts in report data/clear-obsolete-20261013/report.md (repo: kun-agent-workspace) (kind: captain) (reported 2026-10-20) (hold: Read-only classification pass over backlog entries. Verdicts and per-entry evidence are in data/clear-obsolete-20261013/report.md. The prior pass had already closed the genuinely-done entries live, so most verdicts confirm existing state rather than change it. No task state was mutated by the worker.) (hold-kind: captain)
- [x] clear-domain-20261013-decision-default - Backlog clearing pass complete, verdicts in report data/clear-domain-20261013/report.md (repo: kun-agent-workspace) (kind: captain) (reported 2026-10-20) (hold: Read-only classification pass over backlog entries. Verdicts and per-entry evidence are in data/clear-domain-20261013/report.md. The prior pass had already closed the genuinely-done entries live, so most verdicts confirm existing state rather than change it. No task state was mutated by the worker.) (hold-kind: captain)
- [x] clear-core-20261013-decision-default - Core clearing pass complete, verdicts in report data/clear-core-20261013/report.md (repo: kun-agent-workspace) (kind: captain) (reported 2026-10-20) (hold: Read-only classification of Core Distro backlog entries. Verdicts with file:line evidence are in data/clear-core-20261013/report.md. Two entries verified genuinely done, three still need work with evidence, one not actionable in this home. Worker correctly declined to mutate task state, which is firstmate-owned.) (hold-kind: captain)
- [x] core-v3-spec-rewrite-decision-default - V3 rewrite cancelled - original spec recovered intact data/clear-core-20261013/report.md (repo: kun-agent-workspace) (kind: captain) (reported 2026-10-20) (hold: Original spec exists as commit 538e4c2d3cd8e69bb23e4a12795c7ee7a3d77fdc, 577 lines, dated 2026-09-27, on branch fm/core-v3-product-acceptance-spec-0927 in projects/core-distro-saas-clean. The rewrite was cancelled by firstmate to avoid duplicating and diverging from the real deliverable. Recovered spec remains unlanded pending merge authority.) (hold-kind: captain)
- [x] unlanded-work-guard-fix-decision-default - No guard defect found - existing unlanded-work refusal works data/clear-obsolete-20261013/report.md (repo: kun-agent-workspace) (kind: captain) (reported 2026-10-20) (hold: Worker could evidence no concrete guard or discoverability defect and confirmed the local-only unlanded-work refusal is present and functioning. No speculative fix or reproduction was written. The primary's earlier data-loss claim was wrong on two counts: the work was never lost, and the guard was never defective. Local-only delivery is contractually meant to leave work unlanded pending merge authority.) (hold-kind: captain)
- [x] core-distro-a-z-20261018 - Deliver one consolidated Core Distro PRD for public site, SaaS and dashboard data/core-distro-a-z-20261018/report.md (repo: core-distro-saas-clean) (kind: docs) (reported 2026-10-18)
- [x] brief-worklocation-template-fix - Add a staging-tree worklocation clause to the ship/scout brief scaffold (repo: firstmate) (kind: ship) (done 2026-10-17)
- [x] core-distro-stage-article-drawer-fix-20261012 - Correct hidden article-drawer keyboard focus in private staging (repo: core-distro-stage) (kind: ship) (done 2026-10-17)
