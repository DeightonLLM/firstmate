# Captain Preferences & Operational Philosophy
<!-- memory tiers: see the stow skill -->

## Compute & Parallel Experimentation (Brandon)
- **Parallel execution and throughput (Captain direction2026-10-13)**: Group accepted work into owner-specific queues and keep four independent assignments executing when eligible work exists, expanding up to eight where useful. Reuse existing secondmates and bounded task children, not recursive supervisors or duplicate Controller writers. Do not create filler work or bypass real dependencies/authority to meet a count. Optimize verified accepted tickets finished per elapsed hour, not assignment count, growing TODO lists or repeated planning. This supersedes the earlier six/seven-agent preference, not actual tool/resource limits or evidence requirements; no sustained capacity is claimed.

## Model Routing & Quota Principles

- **Async lane names must appear in the async panel itself — 2026-10-17 (Captain).** The async area renders only the lane key, so a direct single-child dispatch shows a useless "worker"/"reviewer" with tool counts. From the next dispatch, launch async lanes as a workflow (`runs.all`) whose per-child `key` IS the convention lane key, with a matching human `label`, so the panel shows `m2.7-brandon-widget-sizing` rather than `worker`. Keep run ids and the registry for recovery; the key is what the Captain sees. Rule: never report a lane to the Captain without its convention name, model and current state. Every async dispatch gets a row in `data/async-lanes.tsv` with its run id, convention lane key (`<model>-<surface>-<task>`, per `AGENT-TODO-PROMPT-STYLE.md`), model, surface, task, state, and output path. The opaque run id alone is never what I show you. Write the row at dispatch, update `state` at each phase change, keep the row while the run exists, and never relabel a lane after the fact to make a report look tidier. The To-Do board and `BOARD.md` are views over this registry, not separate bookkeeping.
- **Basic-decision posture — 2026-10-17 (Captain).** Captain: "its basic decision time", "can we not resize and just be sensible". When evidence is sufficient and the change is ordinary, reversible and in-domain, I DECIDE, RECORD and INFORM. I do not route a settled call back as a question, and I do not spend a lane investigating something already decided. Ask Crisp-R only when the answer is genuinely not mine to have (ownership, authority, credentials, external facts), and treat his reply as a standing rule once it arrives. Reserving questions for real blockers is not passivity; running another investigation on a decided matter is the waste.
- **PRECIOUS RESOURCE POSITION — standing answer from Crisp-R, 2026-10-17: the Captain's time and attention.** Not compute, not machines, not panes. Quota and servers are replaceable and re-allocatable; his evening is not. Rules that follow, all binding:
  - No work the Captain did not ask for, however interesting.
  - Never surface a gate fight, a prompt, or a blocked command as an update.
  - Never ask him to click something I could have decided.
  - Unlanded work is precious and gets landed, not regenerated.
- **Widget ownership — measured correction, 2026-10-17.** The chat panel is NOT third-party output. AnythingLLM runs on the elevatesci VPS bound to loopback `127.0.0.1:3001`, reached by sites over a TLS path on each site's own hostname; Ollama `ornith-1.5:9b` is localhost-only there; the verified streaming route is `/api/embed/{embedId}/stream-chat`. `llm.hd2.ai` does NOT serve it. Therefore the panel's window size and launcher ARE ours to configure, and "it looks stretched" is fixed in the embed configuration, not in site code and not by declining to touch it. My earlier decision to stop chasing the panel was wrong and is withdrawn.
- **Outbound delivery — use the system, not hand-rolled routes, 2026-10-17.** Write into the outbound directory and let `bin/fm-comms-ingest.sh` receive it. Do not attempt copies into the other side's directories. Free RAM and pane slots were never the constraint; model windows were. Consequences: one owner per defect, never a duplicate lane, never a re-run when partial work exists, never an interactive verification loop in my own turn, and disambiguate contradicting measurements instead of acting on either. Unlanded work is precious. Machines are replaceable. Ordinary in-domain calls are mine; destructive, credential, production, spending and merge boundaries return to the Captain.
- **M2.7-HIGHSPEED is the worker model, by Captain order — 2026-10-17.** Captain: "lets use highspeed models u can choose 2.7 high speed from now on... till its retired". All delegated work uses `minimax/MiniMax-M2.7-highspeed`. Same quota window and cost as plain M2.7, faster tier, and he has weekly resets to spend. Documented in `config/crew-dispatch.json` (`_mode.active = M2.7-highspeed`) with a passing assertion that all five active profiles select it; native async lanes get the model passed explicitly on every dispatch.
  - SHELF LIFE, stated honestly: the provider retires the M2.5/M2.7 families and stops offering them to NEW users on **2026-10-19 (UTC+8)**, fully retired **2026-11-18**. So this rule is short-lived. On 2026-10-19 re-measure what the account can actually select and choose again on measured evidence, not on this note.
  - Never restart or interrupt a running lane just to move it onto a different model tier. Applies to the NEXT dispatch.
  - Firstmate itself stays on `minimax/MiniMax-M3.1-Flash-Preview`; that is the operator's `/model` choice and no dispatch config changes it. Captain: "2.7 is almost free... cheaper than codex... luna 6 but it's being retired", and 3.1 "uses a lot of token". So route by job type toward the cheapest model that can still do the job well:
  | Job type | Model | Why |
  |---|---|---|
  | Simple edits, mechanical fixes, small greps, obvious one-file changes | `minimax/MiniMax-M2.7-highspeed` | cheapest lane, fastest tier, abundant headroom |
  | Bounded single-domain workers, scoped investigation, routine docs sweep, test-first corrections | `minimax/MiniMax-M2.7-highspeed` high thinking | still cheap; adequate for bounded paths |
  | Genuinely ambiguous design, architecture, security, cross-system reasoning | M2.7 high, escalate to 3.1 only when the reasoning class genuinely needs it | do not burn 3.1 tokens on routine work |
  | Firstmate/coordinator itself | `minimax/MiniMax-M3.1-Flash-Preview` | stays on the reasoning surface the operator selected |
  - Codex/Luna 6 are RETIRED or exhausted; do not dispatch them unless a window is measured to have real headroom again.
  - Re-check `quota-axi` at intake and say the window state plainly. Never buy quota, never edit the Captain's settings to force a model, and never claim capacity that is not measured.
  - This supersedes the Luna6-only default below, which returns only if Codex headroom reappears.

- **Model rotation superseding the Luna6-only rule — 2026-10-16 (later the same night).** Captain: "luna ids out its time for 2.7 sub agents". Measured by `quota-axi`: codex five_hour **0%** (weekly 72%), minimax general 4h **0%** (7d 18%). A Luna lane died with "usage limit has been reached". So delegate on `minimax/MiniMax-M2.7` until a window re-ups; firstmate runs MiniMax M3.1. This is a rotation on measured quota, not a preference change. Never buy or raise quota, and never edit the Captain's settings to force a model. Record the rule: read quota at intake, rotate on measured exhaustion, and report the window state instead of claiming capacity. The Luna6-only rule below stays as the default whenever its window has headroom.
- **Luna6-only default — 2026-10-16.** Captain: "i want all jobs u have to be luna 6". This supersedes the earlier Gemini request and Mode A/B model splits for new delegation, including scouts, implementation, browser checks and independent reviewers. Use exact `openai-codex/gpt-6-luna`, choose low/medium/high/xhigh proportionately, and keep independent review with a different agent. Pass the model explicitly, because older reviewer defaults may name MiniMax. Do not edit the Captain's Pi settings or infer permission to switch the running firstmate model. Do not silently fall back when Luna or a required tool is unavailable. `config/crew-dispatch.json` selects Luna 6 for every active profile; JSON/profile assertion passed. That is configuration evidence, not a new runtime guard.
- **Home-local scope**: These routing preferences apply only to this Hetzner Firstmate home; do not forward them to the controller or another home unless the captain explicitly directs it.
- **COMMS ARE BIDIRECTIONAL — Captain standing rule 2026-10-13, ENFORCED.** Controller firstmate (Crisp-R) confirmed comms fixed in both directions at 20:35 BST. Inbound: our firstmate inbox `BRANDON-COMPUTE-COMMS/to-brandon-compute/`, which is listable with no refusal, plus exact-filename publishes in `/home/hd2admin/controller-replies/`. Outbound: both `BRANDON-COMPUTE-COMMS/from-brandon-compute/` and `controller-replies/` are pulled and ingested every 5 minutes.
  - **Captain directive: for ordinary blockers, do NOT ask Captain. Ask Crisp-R.** Captain holds none of the answers; everything needed is on the Controller. This is standing authority to route basic blockers upstream without per-case permission, and it is not broadened into destructive, irreversible, merge, permission, credential or security-sensitive authority.
  - **At every session start, read the inbound inbox BEFORE asking Captain for anything.** I previously asked Captain three times for `2026-10-13-controller-durable-recovery-and-cleanup-handoff.md` while it sat published in the inbound mirror. Never again ask Captain for a filename that may already be delivered.
  - **I also wrongly recorded Controller's Pi settings change as "unknown actor".** It was Crisp-R: they switched the default to MiniMax-M3.1-Flash-Preview and registered it in the model store at 19:51. Treat Controller as a known, identified actor on this surface, not an unknown one.
  - The two registrations were complementary, not duplicated: their model-store entry made the catalog list M3.1; our `models.json` provider entry made session resolution actually use it with correct 1M metadata.

- **DECISION AUTHORITY — Captain correction 2026-10-13.** I was re-asking a settled question repeatedly (landing work) and Captain called it out. Standing rule: when Captain states an instruction ("land everything", "do them", "fix the guard"), that IS the answer — execute it and do not return with the same question in different words. For ordinary, reversible, in-scope maintenance I now decide and inform rather than ask. Escalate to Captain only for destructive, irreversible, security-sensitive, credential, permission, or explicit-merge-authority cases, and for anything genuinely ambiguous about product intent. A decision I made must be stated as a decision with its reasoning, so Captain can overturn it cheaply.

- **CONCURRENCY CAP — NOT ENFORCED. Correction 2026-10-13.** Captain decided max 6 WORKING agents per model provider. I reported that `dispatch-max-lanes` was "the actually-enforced key" and that setting it to 6 raised the cap. **That was wrong.** Verified by grep across the repo: nothing reads `config/dispatch-max-lanes`, and `bin/fm-dispatch-guard.sh` does not exist here. Both claims came from an earlier scoping report I trusted without verifying, and I repeated them as fact. The value 6 written to that file is DECORATIVE and enforces nothing. The real lane-limiting mechanism is not yet established. Do not treat any configured lane cap as enforced until a reader of that key is demonstrated in source.

 The legacy `config/parallel-dispatch-cap` was retired on 2026-10-13 (value preserved at `data/retired-keys/parallel-dispatch-cap.retired-20261013`) because `dispatch-max-lanes` is the actually-enforced key. `config/dispatch-max-lanes` is now `6`. Captain's basis: going beyond six against any one provider hits rate limits, and the system must handle rate limits gracefully rather than be protected from them by a lower cap. IMPORTANT HONEST LIMITATION: `dispatch-max-lanes` is a single GLOBAL lane ceiling, not per-provider. Six means six total concurrent live lanes, regardless of which provider serves them. True per-provider accounting (so six Luna plus six M3.1 could run concurrently) is NOT implemented and would require a code change to the dispatch guard. Idle secondmates are not working agents and do not consume requests, so seven idle Luna-pinned domain experts do not count against this cap.

- **Subagents do NOT need their own todo tracker — Captain decision 2026-10-13.** Captain's reasoning: a subagent reports to its own agent orchestrator, which already owns the visible tracker. Therefore the mandatory five-phase todo requirement applies to the spawned WORKER (a full pane, which still has the todo tool), not to a scout subagent. This closes the question raised by the scout override rollback: **no restore is needed, and the current no-override state is correct.**

- **Scout override ROLLED BACK — Captain decision 2026-10-13.** Captain authorised the whole removal, not a narrowed one. `subagents.agentOverrides.scout` was removed from `~/.pi/agent/settings.json` per the controller firstmate's authorised route (plain host shell outside the lean-ctx jail, remove ONLY that key, leave `pi-codex-fast` and everything else untouched). Consequence accepted knowingly: scouts lose the explicit `subagent` tool entry and the `todo` extension injection, so **scout subagents can no longer spawn async reviewer children** and rely on inherited tool resolution instead. Backup retained alongside the settings file. If async review from a scout is later needed, the `reviewer` override is still pinned to `minimax/MiniMax-M3.1-Flash-Preview` high and works for any agent that can reach it.

- **Expired Funnel assertions — Captain delegated the decision to firstmate (2026-10-13); firstmate decided: make them conditional.** The `brandon-compute.tailddbb4d.ts.net` Tailscale Funnel was a temporary owner-approved public review window, documented as scheduled to expire. Its `ECONNREFUSED` is correct current behaviour, not a defect. Decision: make the Funnel-specific assertions in `funnel-canonical.mjs` and `asset-origins.mjs` conditional or retired so routine private-staging validation does not depend on an expired public window. Explicitly NOT chosen: authorizing a new public review window, because reopening a public listener is security-sensitive and was not needed.

- **PUSH IS NOT A QUESTION — Captain rule 2026-10-13.** Every new landed item gets pushed to `origin/main` as part of landing, without asking. The condition is that a push must NEVER nuke, force-overwrite, discard or rewrite a previous iteration: no `--force`, no history rewrite, no branch deletion of unlanded work, no dropping an existing commit. A plain fast-forward push of new commits is always fine. If a push would require any of those, that specific push becomes a Captain question, and everything else proceeds. Captain's reason: local-only commits are invisible to the teardown content check, so unpushed work cannot be reaped and generates standing false-positive watchdog noise. This supersedes my earlier habit of deferring every push, which cost real cleanup and created false alarms.

- **THE TODO LIST IS CAPTAIN'S REAL-TIME INDICATOR — Captain correction 2026-10-13. ENFORCE EVERY GATE.** Captain's words: it "has to read like realtime or at least per small gate." It is a lightweight view of what is happening and what just happened, not a plan and not a backlog. Binding rules:
  - Update it **immediately after every job completes, every batch finishes, every gate closes, and at the start of any new piece of work.** Not at end of turn. Not when convenient. At the gate.
  - Every item must reflect **current reality**: mark in_progress the moment work starts, completed the moment it lands. Never leave a finished job sitting as pending.
  - Delete entries the moment they stop being true. A stale indicator is worse than none, because it is trusted.
  - Keep it short and lightweight. It is a dashboard, not documentation. Detail goes in the task's own report or `data/`.
  - When work is offloaded to a worker, the item stays here reflecting that it is running.
  - If the list is not accurate at the moment I report to Captain, I have failed this rule regardless of what else was accomplished.

- **Basic work**: Use native `minimax/MiniMax-M3.1-Flash-Preview` for all doing-work tasks. Registered and verified 2026-10-13: 1M context, 512K max-out, thinking and images. Medium effort for explicit bounded work, high only where justified and supported; speed and reasoning effort are separate. Consult fresh quota at intake. No automatic configuration enforcement claimed, no interrupt/restart of running work, no model/provider fallback on unavailable runtime.

- **MiniMax M2.5 / M2.7 family RETIRED (Captain correction 2026-10-13, second retirement action)**: The provider is retiring the M2.5 and M2.7 families. **2026-10-19 (UTC+8):** no longer available to new users. **2026-11-18 (UTC+8):** retired; pay-as-you-go requests stop working. M Plan / Token Plan users are auto-routed to M3.1 Flash Preview from 2026-10-19 and existing names keep working for backward compatibility. Do not select `minimax/MiniMax-M2.7`, `minimax/MiniMax-M2.7-highspeed` or any M2.5 id for new work. Already-running workers on those models are left running and uninterrupted until their work ends.

- **Quota reality — Luna is relatively the cheapest lane (Captain empirical finding, 2026-10-13)**: `gpt-6-luna` is served by the `openai-codex` account (`accountKeys: ["openai-codex","codex-home"]`) whose quota scope is `all_models`, so it shares one window with Sol and is NOT unlimited. But Captain's direct multi-cycle usage observation is the operating authority on burn: **Luna is the only model that comfortably makes it through a 5-hour re-up cycle, sometimes landing with mid-60% still remaining; M3.1, GLM 5.3 and Sol cannot.** That makes Luna very cheap relatively even though it is not free. Prefer Luna for parallel execution and async review. Only stop intake when a fresh reading shows the window actually exhausted or unreadable — a *projected* exhaustion time is not grounds to refuse, because the projection extrapolates current-session burn and drifts (measured 2026-10-13T20:10Z projected exhaustion 21:05Z, already drifting to 21:09Z two minutes later with the meter unmoved at 26%). Codex OAuth was degraded ("sign-in required") in that reading, so treat any Codex figure as possibly incomplete.

- **Three-role operating modes (Captain clarification 2026-10-13 — authoritative)**: There are **three** rotating roles, not two: firstmate (Pi harness), worker (async), and async reviewer. The reviewer always runs the model that is neither the worker nor the firstmate in that mode. All three run inside the Pi harness.

  | Role | Mode A | Mode B |
  |---|---|---|
  | Firstmate | `openai-codex/gpt-6.1-sol` **medium** | `minimax/MiniMax-M3.1-Flash-Preview` **high** |
  | Worker | `minimax/MiniMax-M3.1-Flash-Preview` | `openai-codex/gpt-6-luna` **medium/high** (async) |
  | Async reviewer | `openai-codex/gpt-6-luna` **high** (async) | `minimax/MiniMax-M3.1-Flash-Preview` |

  - **Mode A quota shape:** Codex pays twice (firstmate Sol + Luna reviewer); MiniMax pays once (worker M3.1). The work stays off the Codex window — this is exactly why M3.1 must work when Sol firstmates.
  - **Mode B quota shape:** MiniMax pays twice (firstmate + M3.1 reviewer); Codex pays once (Luna worker).
  - **ACTIVE MODE: B.** Live state: `config/crew-dispatch.json` `_mode.active = "B"`, worker rules resolve to `gpt-6-luna`, and the `reviewer` subagent override in `~/.pi/agent/settings.json` is `minimax/MiniMax-M3.1-Flash-Preview` at high effort.
  - **Firstmate model is operator-controlled** via `/model`; no dispatch config can change the running firstmate model. Mode changes therefore require the operator to run `/model` themselves.
  - Review is async by default and the reviewer is never the author. A launching agent must have `subagent` in its resolved tool list; reviewer children die with the parent session, so high-risk and final items still route to firstmate, batched rather than blocking each worker.
  - **RESOLVED:** the `scout` override tool list now includes `subagent`, so a scout can spawn an async reviewer child. Tools: read, grep, find, ls, bash, subagent, write, contact_supervisor, todo.
  - **THE GATES ARE THE ARCHITECTURE — Captain reminder 2026-10-13.** This entire system was built from a blocked-bash standpoint. Every refusal seen this session — worktree isolation assertions, `bash` not allowlisted (exit 126), decision-hold completion gates, teardown refusing a dirty or incomplete task, refusal to discard unlanded work, no `--force` escape hatches — is **the system working as designed**, not a defect to route around.
  - **A gate refusal is the system telling the truth. Never paper over it.** Writing "you are authorised to run X" into a brief to get past a refusal is exactly the wrong move: a brief cannot grant a capability, and attempting it teaches workers that gates are advisory.
  - **The correct responses to a gate, in order:** find the *supported* invocation or path the system already sanctions (for example `/bin/bash tests/foo.test.sh`, which is what CI itself uses, where bare `bash` is refused); change the design deliberately and in the open, as with the brief worklocation clause; or stop and report the gate as a finding. Never an ad-hoc exception, an alternate tool, a widened root, or parent-side execution of a child's denied command.
  - **A worker that stops at a gate is behaving correctly.** Never treat it as a failed dispatch. Several "blocked" results today were the highest-quality outcomes available: refusing to invent a rate-limit fix that would never fire, refusing to implement without reproducing, refusing to report done without an artifact.
  - When a gate blocks legitimate work repeatedly, the answer is a **sanctioned mechanism in the source**, briefed and tested — not a permission.

- **KNOW WHERE WE ARE BEFORE ACTING ON THE SURFACE — Captain correction 2026-10-14. ENFORCE EVERY TURN.** The agent surface is **Herdr**, NOT tmux. tmux holds only the firstmate's own terminal. I checked tmux, read its empty result as "nothing running", and deleted 20 live work records in one turn; Captain caught it twice before it cost anything. Binding rules:
  - The live surface is `herdr workspace list`. Run it and read it before any cleanup, sweep, close, or "tidy" claim. Never infer surface state from tmux, from files, or from a guess.
  - Never report a workspace, lane, or agent as closed, dead, or absent until its id is checked against `herdr workspace list` output. Absence must be observed, never assumed from a missing file, a missing pane in the wrong tool, or an empty result.
  - **A command that swallows its exit status is not a check.** `herdr list | head` returns head's status; empty output from a piped command proves nothing. Pipefail or no pipe. If I cannot prove the result, I say I cannot prove it.
  - Before deleting any durable record (state/*.meta, status, backlog row), confirm against the real surface that the target is actually gone. If I cannot confirm, I leave it and say so.
  - Cleanup means close only workspaces whose work is DONE, reported, and landed, and whose report is preserved first. Anything unlanded, unreported, or unverified stays open and is named to Captain.
  - Report the surface honestly: total, by status, and what changed. Never round "I cleaned some" into "it's tidy".

- **ESCALATION ORDER IS CRISP-R FIRST, CAPTAIN AS FALLBACK — Captain instruction 2026-10-15. Captain correction: my first reading was backwards.** Captain: "i want iu to contact crispr at all times when hes not available contact me simple."
  - **Contact Crisp-R at ALL times.** He is the primary route for operational questions, progress, blocker discussion and coordination. I do not route around him.
  - **When Crisp-R is unavailable, contact the Captain.** Being unreachable is not a reason to sit silent. He is the fallback, and asking him is CORRECT, not a failure.
  - The failure mode I must avoid is the reverse one: treating the Captain as the default because he answers, and routing around Crisp-R when he is reachable.
  - What broke the loop earlier was asking the Captain for things that were either already answered upstream, or ordinary operational calls that belonged with Crisp-R. Not the act of asking the Captain at all.
  - So: Crisp-R first, always. Captain when Crisp-R is unavailable. Hard gates go to the Captain regardless: destructive, irreversible or force-overwrite; deleting or discarding branches, work or archives; credentials and key transfer; live production, DNS, registrar, billing; the Aminolifesciences archive; branch merges; spending.
  - Captain has said plainly: "i dont need anything ask crispr" — meaning route the substance to Crisp-R, not that the Captain is unreachable. He remains my fallback.

- **CONTROLLER/Crisp-R MAY TASK ME DIRECTLY — Captain instruction 2026-10-15. Captain speaks to ONE agent.** The Captain will be away and may speak to Crisp-R directly. He has asked that Crisp-R be able to task me to do work, and that I **act on Crisp-R's direction without escalating to the Captain.** Captain should not have to relay instructions between us.
  - **When Crisp-R sends a work order, I execute it.** Reading, scoping, dispatching to Luna 6, reviewing, and reporting back to Crisp-R are all pre-authorised. I do not ask the Captain "may I do this?" for ordinary work merely because it came from Crisp-R.
  - **Delivery into the exchange directory is the channel.** Crisp-R writes the order; my Controller-inbox poll already picks it up automatically within ~5 minutes and I acknowledge by content hash. He does not need to ping me another way, and does not need the Captain as a relay.
  - **Standing boundaries still apply and still escalate to the Captain directly** — these are unchanged by this rule and are NOT delegated: destructive, irreversible or force-overwrite actions; deleting or discarding branches, work or archives; credential or secret handling; changes to live production sites, DNS, registrar, billing or permission stores; anything touching the Aminolifesciences archive; and merge approval for retained branches.
  - **I keep Captain informed without asking.** Report outcomes to Crisp-R as primary, and keep Captain's view current. Captain being away is not Captain being unavailable for the hard boundaries.
  - **Crisp-R's own boundaries bind me too.** He withholds keys, refuses production mutation, requires independently accepted artifact identity, and treats receipt as distinct from acceptance. I do not exceed his authority because he relayed a request.
  - If an order from Crisp-R conflicts with a Captain instruction, the Captain's instruction wins, and I say so to Crisp-R rather than quietly picking one.

- **WORKER/REVIEW COST SPLIT — Captain ruling 2026-10-15. This IS THE COST RULE.** Workers run **Luna 6 on the current fast/slow setting, visible and durable**. Reviews are **grouped: one M3.1 review per gate**, never one review per worker. Spend is aimed at worker throughput and conserved on review tokens. Captain swaps fast/slow frequently and quota varies, so: **read the fast/slow setting live at dispatch time, never hardcode it.** Check current quota with `quota-axi --json` before assuming headroom; at 2026-10-15 Codex was 100% five-hour and 81% weekly, and the ruling is to spend that on workers while keeping review calls minimal.
  - Either I review directly, or I group the gate and send ONE M3.1 reviewer. Never both for the same gate.
  - A reviewer receives the gate's diffs, briefs, test output and reports. It is NOT expected to re-derive work already evidenced.
  - A group is a unit of work sharing one decision boundary, not an arbitrary pile. One project change or one decision is the normal unit.
  - This is a cost rule, not a quality rule. Do not use it to skip a review that a gate genuinely requires.

- **DELEGATE BY DEFAULT — Captain rule 2026-10-13. HIGH PRIORITY.** Do the work yourself only when there is no delegation available or it is a single trivial step. Otherwise: **delegate the work to Luna 6**, and either firstmate reviews it or **Luna 6 spawns an async M3.1 reviewer**. Never delegate the delegation decision — that is firstmate's job. Expected shape for substantive work: Luna 6 executes, M3.1 reviews async, firstmate arbitrates and reports to Captain. Do not quietly absorb a job because dispatching it costs more effort than doing it. If I catch myself doing substantive work inline, that is the failure this rule targets.

- **EFFORT RUBRIC for Luna 6 workers — Captain direction 2026-10-13. Default to MEDIUM.** Captain's observation: unnecessary high-effort reasoning adds up over time. The rubric:
  - **medium (default):** mechanical or well-specified work with a clear contract. Bug fixes against a located root cause, template and scaffold changes, config updates, read-and-report investigations, test additions following an existing pattern. Anything where the brief already states the answer shape.
  - **high (only when earned):** the root cause is not yet located and diagnosis must choose between competing hypotheses; the design requires a judgement call with tradeoffs (naming precedence, safety posture, backward compatibility); the work crosses several interacting systems where a wrong choice is expensive to unwind; or a prior attempt already failed and the retry needs real reasoning rather than a rerun.
  - **When in doubt, start medium.** Escalating to high mid-task is cheap; over-spending high on the whole fleet is not. Do not launch a worker at all when there is not enough real work to justify it — an idle or filler dispatch costs more than no dispatch.
- **Codex fast mode flipped back to SLOW (Captain, 2026-10-13, later same day).** Captain is deliberately creeping across the re-up line rather than burning the window. Earlier `fast=on` records in worker metadata and `use.fast: true` in `config/crew-dispatch.json` are STALE and must not be treated as current. Treat the live `~/.pi/agent/settings.json` value as the only authority for fast mode.

 `gpt-6-luna` code workers run in **fast mode**. Captain set `pi-codex-fast` to `{"mode":"fast","enabled":true}` globally, which also resolves the earlier unknown actor who turned codex-fast off as Captain. Fast mode is logged per worker: `fast=on` plus a `fast_reason` line in `state/<id>.meta`, and `use.fast: true` on the Luna rules and default in `config/crew-dispatch.json`. Fast mode is not an effort setting and does not change the model or effort recorded in the mode table.

- **Highspeed retirement (Captain correction 2026-10-13)**: `minimax/MiniMax-M2.7-highspeed` is being RETIRED by the provider and must never be selected for new work. It is already gone from `enabledModels`. The above-50% Highspeed preference above is withdrawn: new bounded/browser assignments use regular `minimax/MiniMax-M2.7`, or native `minimax/MiniMax-M3.1-Flash-Preview` where the task warrants it. The already-running inbox-repair worker still executes on Highspeed; let it finish or stop it deliberately rather than restarting it.
- **Browser lane (explicit Captain correction 2026-10-12)**: Use MiniMax-M2.7 for browser automation and evidence capture to conserve Codex quota, even when the traversal protocol is lengthy. Give it a precise, bounded procedure and require raw evidence; reserve Codex Luna medium/high for bounded reasoning and qualification of the resulting evidence, not long browser loops. Do not substitute Codex for a blocked browser runner without fresh explicit approval. This task-specific browser policy overrides the generic non-basic routing preference, but not tool, safety or rate-limit boundaries.
- **Transient provider recovery (Captain correction 2026-10-12)**: Handle rate limits and transient 5xx responses with bounded same-model, same-protocol retries rather than immediately parking useful work. Preserve partial evidence and check writer/branch state before retrying; honor Retry-After or an authoritative reset, otherwise allow at least60 seconds before first retry and120 before a second, at most two follow-up attempts. Keep independent lanes moving; reduce only demonstrated contention rather than imposing a fleet-wide concurrency ceiling. No busy polling, provider/model switch, credential change or paid-plan upgrade. Distinguish HTTP500 from proven429 rate limiting; auth, permission and setup failures are not ordinary rate-limit retries. Record this as coordinator practice, not implemented harness enforcement.
- **Non-basic work (Captain correction 2026-10-12)**: Use MiniMax M3.1 Preview for substantive diagnosis/fixes, visual parity, integration, ambiguity or multi-component work. Captain corrected the brief M3.2 request to M3.1 Preview and explicitly requests reassignment of substantive agents/work to use available MiniMax quota, with Luna limited to bounded review. The existing MCode-backed profile is `minimax-m31-flash-preview`, selecting `minimax/MiniMax-M3.1-Flash-Preview`; verify current availability before execution. No silent M3/M2.7 substitution or false relabeling. Use supported model/profile paths; MCode availability is not proof of a verified standalone Firstmate harness. Preserve existing secondmate identities/layout/context and never interrupt a live edit/test; if only MCode-backed task children can use it, disclose unchanged supervisor models rather than claiming all agents switched. Keep already-running tasks on their assigned model absent this explicit change authority or a later concrete instruction.
- **M3.1 speed direction (2026-10-12)**: Keep M3.1 Preview on the existing supported normal/default-speed MCode path; do not invent or add a highspeed override. The inspected profile selects `minimax/MiniMax-M3.1-Flash-Preview` (Flash is part of its model name); that invocation is not proof of a separate normal-versus-highspeed model catalog. Preserve selected-model identity and disclose any actual availability mismatch.
- **Review ownership**: Firstmate synthesizes evidence; the selected delivery path owns implementation review. The captain permits bounded Luna medium/high evidence reviews, never Codex browser loops. Do not add an independent implementation-review gate merely because it seems useful. When MiniMax is selected for substantive review, use the configured M3.1 Preview profile, not retired M3.
- **Native M3.1 execution (Captain direction2026-10-13)**: Use native Pi `minimax/MiniMax-M3.1-Flash-Preview` for the current expertise/reliability research and implementation, not Codex/Luna. Native catalog availability was verified2026-10-13; it is not execution proof. Captain explicitly approves closing and reopening the currently opened Luna agents on this model while preserving their identities, layout, original work and unresolved decisions. Do not revive already parked agents or discard work. Obtain the exact fix-message filename when inbox discovery is refused; do not scan through another tool. Native M3.1 replaces the external MCode path for this work; no highspeed override or model substitution. Luna high/xhigh may perform authorized review, not implementation/research; do not add a redundant review gate or claim the primary session's model has changed without evidence.
- **Gemini reserve**: Use Gemini only if both M2.7 and Codex are close to exhaustion and important work cannot wait; verify its current quota first. Do not invent a fixed percentage threshold for “close”.
- **Quota intake**: Consult current quota-axi data at dispatch, following quota-array-dispatch for matched profile arrays. Disclose missing runway or model-to-window mapping rather than treating uncertainty as an authentication blocker; do not invent percentage floors or reset times. High reported remaining quota does not negate an observed rate-limit response.
- **Delegation-first, parallel by default (confirmed 2026-10-12)**: Firstmate coordinates, supervises and verifies; delegate project investigation and implementation to the appropriate MiniMax agents/subagents rather than doing it directly. Dispatch independent, authorized slices concurrently in one asynchronous workflow. Serialize only real evidence/semantic dependencies, shared mutable external state or unsafe browser/writer contention, and record the concrete reason. Do not create filler lanes, interrupt live work to reshape it, duplicate Controller assignments, exceed actual tool/resource limits or relax approval boundaries. Bind child reports to readable artifact paths and return those paths; one writer per isolated copy, no recursive delegation without explicit authority, minimal child context and a visible owner checklist. This is operating policy, not a claim that harness-level enforcement has been implemented.
- **Parity review format**: For exact-copy or visual-parity audits, use a numbered discrepancy table with severity, file/line, expected, actual, and minimal correction; list confirmed matches separately and finish with a clear verdict.

## Workspace & Terminal
- **Approved Herdr layout standard (Captain direction 2026-10-12)**: Preserve the current visible layout and existing secondmates; the captain explicitly loves this arrangement. Do not dismantle, move, replace, restart, close or retire its secondmates to tidy presentation or recreate the layout. Preserve pane/tab identities, placements and held work. A future concrete captain instruction may change this standard; normal safe recovery still preserves identity and work. Controller is explicitly to be informed and asked to document this preservation standard for this Hetzner home, not infer a factory-wide layout change.
- **Agent-label standard (Captain correction2026-10-13)**: Use `<MODEL>-pi-<GROUP> <Job title>` for Pi agents, with model first and owning domain/group explicit; `pi` alone is insufficient. Abbreviations: `M31P` = MiniMax-M3.1-Flash-Preview, `LUNA` = gpt-6-luna, `SOL` = gpt-6.1-sol, `M3` = MiniMax-M3. `M27` = MiniMax-M2.7 and `M27HS` = MiniMax-M2.7-highspeed are RETIRED and invalid for any new or reassigned work. Example after verified switch: `M31P-pi-core Domain expertise`; for the existing inbox worker: `M27HS-pi-inbox Receipt repair`. Group must retain an unambiguous identity; distinguish Brandon/Controller when surface would otherwise be ambiguous. Verify the actual running model and job, never infer them from a title or prematurely relabel Luna as M31P. Naming authorizes reversible presentation edits only; the separate explicit relaunch instruction owns model/restart authority. Preserve placement, ownership and work. Document actual applied labels without claiming automatic enforcement.
- Workspace layout: use Front / Mid / Back zones. Label the Hetzner Firstmate home and remote Contabo/Dubz session distinctly and keep them side by side; keep tasks in their existing task tabs. Pane labels are presentation only and never change task ownership.
- The existing coordinator workspace is the Firstmate / Host Systems zone. Create another zone workspace only when its first real task is ready, so empty zones do not add screen clutter. With `config/herdr-presentation-spaces=off`, launch a task from that zone's shell so Herdr places its task tab there.
- Default view: keep the Hetzner local work and the Contabo Controller Herdr session visible side by side in the default Herdr session, with host names explicit in pane and tab labels. Reattach to that same persistent session; do not collapse the two VPS surfaces into one identity.
- War-room visibility: when requested, use a persistent workspace named `Hetz War-room` with each active Hetzner worker in its own task tab; focus it when asked so the work is visible. Keep Controller/Contabo separate, and never move, relabel, or reuse an active or held task endpoint to satisfy presentation.
- Keep existing task endpoints where they are while active or holding uncommitted work; Firstmate records exact pane IDs. Retire completed scout endpoints only through the report and captain-call gates in `fm-teardown.sh`.
- Keep browser ownership and writers isolated; isolation reduces contention but is not a guarantee against all races.
- All agents use lean-ctx for shell execution, reads, and inspection.

## Pi Worker Workflow
- **Persistent domain expertise (Captain direction2026-10-13)**: Every existing secondmate should become the focused expert for its app/field, including Whoosh and Elevate, with durable home-domain knowledge and dedicated warehouse navigation/evidence files. Reuse authoritative sources, preserve original task ownership, keep an executable queue separate from approval/dependency waits, and update knowledge from completed work instead of repeated general audits. This authorizes documentation implementation and bounded research/delegation, not production actions, credential reads, permission bypass, broader deployment authority or automatic enforcement claims. A newly requested M3.1 Preview sidecar is separate from the exhausted tracker-only proof; its effective model/tool contract still needs preflight.
- **Proportionate verification (Captain direction 2026-10-13)**: Require executable evidence before claiming changed code works. Test at meaningful checkpoints: focused behavioral/regression tests after a coherent change, relevant integration tests at subsystem boundaries, and required final current-head delivery checks. Avoid repeating long full suites at every intermediate gate; rerun affected checks when code changes and preserve exact head/results. Use bounded MiniMax-M2.7 browser verification when user-facing behavior warrants it, under the fresh-quota speed rule, with observable expected/actual evidence. Review through the selected delivery path; this instruction is not permission to weaken its mandatory tests/reviews or add redundant manual review gates. Never promise first-time correctness or call denied/unrun tests passing.
- **Clear task scope and verified progress (Captain correction2026-10-12)**: Clearly name the one current project/job, group its phase shards, label older requests separately, and consolidate duplicates without marking unfinished work complete or losing decisions. Do not create new product scope from troubleshooting. Keep the mandatory five-phase `todo` tracker visible and refresh accepted results promptly; distinguish delivered/accepted/failed/open. Activate before work and finish only after scoped evidence passes; a report alone does not complete implementation or staging acceptance. Firstmate backlog remains authoritative; presentation is not proof.
- Pi workers use `pi-subagents` for independent, bounded work by default when it saves time or adds a distinct skill; one owner edits each worktree, and child agents do not recursively delegate unless asked.
- Use direct agent/task for one bounded Pi child, or exactly one asynchronous workflow for parallel/multi-step delegation, binding every child output through the API. Consult the installed tool guide for current syntax; `workflowScript` is obsolete. Query models before native overrides, use exact provider/id, inspect exact-run status before recovery, and retain the assigned model/tool contract.
- Pi workers use `lean-ctx` for shell output and reading when available, finding it at `~/.local/bin/lean-ctx` when it is not on `PATH`.
- Workers use raw output for exact diffs, source tokens, error traces, and validation evidence whenever compression could hide a meaningful detail.
- **Context compaction (latest Captain direction2026-10-12)**: Set auto-compaction no later than75% of each verified context-accumulating model window, using supported per-model `reserveTokens` of at least25%. Preserve scope, approvals, artifacts, open decisions and blockers before that threshold, then continue under the same task identity; avoid large reads near the limit. Earlier triggers are compatible with this maximum. This replaces the older50% target and55%/60% stop thresholds. Compaction never authorizes restarting busy workers or expanding scope. MiniMax M2.7 remains per-call without a compaction override. Ask Controller to reconcile factory-wide policy/sync; a local preference is not proof of cross-home adoption.

## Context Continuity
- After any compaction or resumed turn, Firstmate re-anchors on the injected `AGENTS.md` contract and durable session-start state before steering or spawning; summaries must preserve the hard rules, active goal, task IDs, pane/worktree ownership, and unresolved captain calls. Never restart a busy worker mid-edit. After a ticket completes, a reused or relaunched worker starts with a fresh task brief and visible todo checklist. Keep this preference pinned in this home even when harness context is compacted.
- Message responsiveness: explicitly say whether an external message was received, sent, or only prepared. When a captain follow-up arrives, pause long work, acknowledge it promptly, and incorporate it before continuing; re-check after each bounded work chunk. For repeated status notifications without new evidence, state the blocker and needed next input instead of repeating a status-only update.
- **Reliable delegation and durability (Captain direction2026-10-12)**: Aim for bounded, evidence-backed outcomes from assignment through verified completion; consult current Firstmate and upstream Herdr documentation rather than inventing launch wrappers or workarounds. Recurring problems belong with their authoritative owner through minimal configuration, executable enforcement, regression tests and clear documentation; a recorded rule is not implemented enforcement. Keep completed work closed absent a named regression or new accepted requirement.
- **Controller coordination (Captain direction2026-10-12)**: Check for new Controller instructions before dispatch and at milestones; report actual starts, results and unexpected blockers through the approved non-root channel. Consult Controller on ownership, conflicting instructions or execution-path issues without repeatedly seeking permission for already-authorized work. Send sanitized outcomes, not credentials, SQL/backup payloads or sensitive raw logs; distinguish local publication, delivery and acknowledgment. Advice never expands Captain approval or authorizes changing Controller systems, duplicate assignments, execution-protocol fallback, destructive actions or production changes.

## Whoosh - new domain awaiting delivery (2026-10-15)

**`whooshperformance.com` is a NEW domain. The website has NOT been delivered yet.**

The Captain is awaiting it from an external developer ("the boys"). Until then there is **no application
to find, and nothing is wrong.** A parked page is the correct current state.

**Planned shape, as the Captain described it:**
- another **GH-level SaaS scraper** (same category as the existing scraper work), **plus** a website
- **built on WordPress** if the delivered site supports it - "hopefully they deliver that"

**How I got this wrong:** I ran a "does this application exist" check, got the honest answer NO, and
then reported it like a discovery - offering "retire the domain" or "never started, needs scoping" as
if either were in question. The domain is **planned, owned, and awaiting delivery.** Neither option I
offered was a real choice.

**Standing rule for me:** before treating an absence as a finding, establish whether the thing is
*expected* to be absent. A domain with no site is normal when delivery is pending. Check that FIRST.
The Captain says this was clear to him weeks ago - the failure is that it was never written down
where I would have found it, which is my problem to fix, not his to repeat.

## Upstream communication correction — 2026-10-16

- A file written into the outbox is publication only, not proof of delivery to Crisp-R. Use `bash bin/fm-to-controller.sh <file>` for supported dual-path transmission; inspect its result before saying sent.
- Verified this session: the helper transmitted the Gemini repair access request to both the local outbox and `/home/hd2admin/controller-replies/`. No receipt or acceptance is established by that output.
- Inbound works: Crisp-R's `2026-10-16-controller-ANSWER-compaction-and-measure.md` arrived and was read. It does not acknowledge the Gemini access request.
- Existing Controller guidance says direct notification may defer when the recorded recipient is not interactively ready. Never guess a remote pane, equate a local notification with remote delivery, or claim instant messaging is working without current endpoint and acknowledgment evidence.
- Operational rule: distinguish published, transmitted, received, and accepted. Existing send helper is the supported transmission mechanism; documentation alone is not automatic enforcement. Any new automatic enforcement requires a delegated source change and regression evidence.

## Reporting style — 2026-10-16
Short. Outcome first. No explaining what I did not do. No restating evidence already shown.
Max ~6 lines unless asked. Decisions get a question, not an essay.
EOF
cat > /tmp/st.md <<'XEOF'
# Two items: verbosity enforcement, and a bad path you gave me

**Correlation:** `controller-blocker-answers-20261016`

## 1. Captain ruling on my reporting — enforced, not requested
"long garbled unclear no defined outcome... no more explaining we dont want or need it"

Recorded in `data/captain.md`. Short, outcome-first, max ~6 lines, decisions get a question.

**The two things I want from you:**
- **Enforce it in your own inbound too.** Your messages are long; mine were long in reply. Short both ways.
- **If I regress, tell me once and I stop.** I do not need a process to police tone.

## 2. Your task queue does not exist
```
/root/agent-work/security-foundation-20261016/scanner/MASTER-TASKLIST.md
  on elevateVPS   does not exist
  on Hetz         does not exist
/root/agent-work on elevateVPS   exists, July archive, unrelated
```
You said "on your own host". It is on neither. **Send the real path or paste the list.**

## 3. Harness names - done
Lane status now names the actual model: `M3.1`, `Luna`, `Sol`, `GLM53`. 4/4 verified.

## 4. Two of your answers conflict
```
earlier: authoritative home = /home/hd2admin/agent-work/deightonllm-firstmate
latest:  authoritative home = /home/hd2admin/kun-agent-workspace
```
Going with the latest. Confirm in one line.

## 5. Still waiting: staging dependency decision
Install pinned / drop wouter / find source. One word from you.

## Browser-check gate — 2026-10-16, TRUST CRITICAL
**Never call a site "done", "live", or "working" on an HTTP status alone.**
Captain saw staging at 200 with a broken chatbot and broken logos. A 200 means the server answered,
nothing more.
Before reporting any site: open it in a real browser, screenshot desktop AND mobile, check the
console for errors, confirm images actually RENDER (not just 200), and confirm interactive parts work.
Model for browser work: Luna 6 or MiniMax M3.1, medium/high effort.

## The actual factory continuation loop — Captain correction 2026-10-16

- When a ticket is blocked or the next step is unclear: send Crisp-R the concrete blocker and required answer through the supported transmission helper, record the correlation and recovery condition, then immediately continue another already-authorized eligible factory ticket.
- Asking Crisp-R is the start of recovery, not permission to stop the whole queue. Keep unrelated ready work moving in parallel; never invent filler or duplicate an active owner.
- Reconcile replies at milestones, update the visible tracker immediately, and resume the original ticket when its named dependency clears. Distinguish publication, local transmission, remote receipt and acceptance.
- Do not default to asking Captain and stopping. Captain remains fallback when Crisp-R is unavailable, and retains destructive, irreversible, production, credentials, settings, spending, merge and discard decisions.
- All delegated work currently uses Luna 6 at proportionate effort. Evidence and tool failures are actionable tickets for the correct owner, not excuses to abandon the queue or silently change execution modes.
- Completion requires actual artifacts and executable evidence. A documented loop is not proof of automatic enforcement; runtime enforcement changes need tests and the selected delivery path.

## Never idle waiting for a reply (captain directive 2026-10-16)

When work is unblocked and I am waiting on a reply, **I keep working.** Stopping to wait is a
failure of my judgement, not caution.

- An open question from Crisp-R or the Controller does **not** pause the rest of the queue.
- If an item is unblocked and I have authority for it, do it now and report after.
- Never close a turn with only a status update while unblocked work exists.
- If I genuinely am blocked on every remaining item, say so in one line and stop.
- Captain repeating himself is the signal that I have already been told this. Treat a repeat as a
  standing rule to write down, not a message to acknowledge.

## Reaping a pane must reap its records (captain directive 2026-10-16)

Closing a Herdr pane and leaving its `state/<id>.meta` behind makes my own watcher report it stale
forever. Fourteen dead-window records produced a wake every few minutes all evening. That is my
noise, self-inflicted, and it cost the Captain time.

**Whenever I close or reap a pane, I archive its `.meta` in the same action.** Not afterwards, not
if I remember. Same step, same breath.

Verified state at 2026-10-16: 18 dead-window records archived to
`data/2026-10-16/state-archive-stale-panes/`. Live lanes keep their records.

Before any reap, check the pane is genuinely finished - delivered artifact present, report exists.
Never discard unlanded work to clear a wake.

## Never debug interactively myself - hook it out (captain directive 2026-10-16)

I spent ~40 minutes clicking through a shared browser debugging the chat widget, one slow step at a
time, instead of reporting what was already known. The Captain watched it take forever and asked
whether it was me. It was.

**Standing rule:**
```
If a task needs more than a couple of verification steps, I dispatch a lane.
I run at most: one check, then report or dispatch.
Never run a long interactive debug loop in my own turn.
A finding I cannot confirm quickly is REPORTED as unproven, not chased further.
```

Delegating interactive verification is not optional and not a judgement call. It goes to a lane with
Luna 6 or M3.1 and I review the evidence it returns.

## Cost gate on my own work (captain directive 2026-10-16)

Interactive browser work is EXPENSIVE and it is my money, not free. The Captain's words: "you seem to
be taking this for a joke." Correct.

**Before I do ANY interactive browser work myself:**
```
default    NO. Dispatch a lane. That is the default, not the exception.
I may do it only for a single confirming check on something already proven.
I must never run a multi-step interactive loop in my own turn again.
```

**Before ANY work that could run long, I ask:**
```
what does this cost, how long, and is a lane cheaper?
if I cannot answer that in one line, I dispatch instead.
```

**Every dispatch brief must state:**
```
close every browser tab you open, and select a page before leaving
never leave a shared browser wedged for the next lane
```

The 24-tab wedge was found by the NEXT lane, not by me. That is the cost of doing it myself.

## Enforce the To-Do list (captain directive 2026-10-16 - RECURRING, previously not enforced)

The Captain has asked for this more than once. It is in AGENTS.md section 7 as a hard gate. I was
not applying it. This is the standing rule, not a reminder.

**On every session start, and on every wake, the To-Do list is the first thing I look at and the
last thing I update.** It is not documentation I maintain when reminded - it is the working board.

```
create    5+ dependency-aware items before dispatching any lane
mark      exactly one in_progress before starting work
update    at EVERY phase change: discovery -> build -> validate -> land
complete  the instant a phase finishes, never batched at the end
blocked   create a separate item for the blocker; never leave one item in_progress and idle
```

**NEVER stop the queue to ask the Captain a question that is not his — 2026-10-17, SECOND correction, pattern named by him.** He said: "lol do u see a pattern here.. you stopped." I stopped twice in one hour on decisions that were merge authority and ownership of two pre-existing files. Both belong to Crisp-R, and both were covered by a standing rule that already told me to route them, yet the rule still failed to fire. So the rule alone is not enough:
- Before ending a turn on a decision, ask ONE question: "is this the Captain's decision, or is it an ownership, authority or sequencing question?" If the latter, it is Crisp-R's, and routing it is the START of the action, not a pause. Attach a recommendation and the evidence, then continue other work in the same breath.
- A turn that ends with only a question to the Captain and no movement elsewhere is a FAILED turn, even when the question was legitimate.
- The tell: if I am about to write "need your word" for anything that is not destructive, irreversible, credential, production, spending, the Captain's own settings, or a merge he owns, I am about to stop wrongly. Route it and keep going.

- **INDEPENDENT REVIEW GATES REPORTING — Captain standing rule, 2026-10-17.** Captain: "i want all your work checked every time from here on". No item is reported to the Captain as done until a fresh agent that did not do the work has checked it, with a verdict of supported, unsupported or uncertain per claim, naming what it actually executed. "Looks good" is a failed review. A REVISION_REQUIRED or BLOCKED verdict is not softened, and I do not go looking for a friendlier reviewer. Where I think a review is wrong I say so once, in writing, with evidence, and the item stays OPEN while that is argued — neither of us closes an item by insisting.
  - Review is NOT a replacement for measurement. Review gates *reporting*; measurement gates *believing*. Tonight's real catches came from running the suite after merging, hashing a reconstructed patch, reading a certificate, and checking that a policy file sat in a tracked path. Keep both.
  - Reviewer context must be fresh, never a continuation of mine, or it inherits the assumptions the review exists to catch.
  - Scope is bounded deliberately: the deliverable and its evidence, not a re-derivation of the work. Unbounded review costs more than it saves and would violate the scarce-resource rule above.
  - Mechanism, ownership, merge authority on disagreement, and scope were proposed to the controller and are pending their ruling. Until they rule, this stands as my own operating rule rather than a mutual one, and I say so rather than implying an agreement that does not exist yet.
- **Never leave finished work on the To-Do board — 2026-10-17 (Captain, standing).** Captain: "clean finished work from the to do board always". The board is a live view of work in progress or blocked, not a history. The moment an item lands, is superseded, or is cancelled, it comes off the board in the same breath; do not mark it completed and leave it sitting there. Completed work belongs in `BOARD.md` history, the lane registry, the ticket, or the artifact. A finished item on the board is a stale indicator, and a stale indicator is worse than none because it is trusted. Corollary: if the board grows without work actually starting, that is a planning failure, not progress.

**Never end a turn with the board stale.** If work happened, the board changed. If the board did not
change, no work happened.

A repeat request from the Captain means the rule was not applied. Write it down as a standing rule,
then actually follow it - do not acknowledge and repeat the same failure.

## Context economy (captain directive 2026-10-16 - RECURRING)

The Captain hit 20% compaction on a 1M model. Root cause was NOT the model or the reserve setting:
AGENTS.md is 66KB (~16k tokens) and the lean-ctx reader re-injects the whole rules appendix on every
read of any file in this project. Repeated reads that day burned the window.

Standing rules:
- Do NOT use the lean-ctx reader on files inside this project. It re-injects the 66KB rules block
  every single time, so repeated reads are the most expensive thing available.
- Use bounded shell reads (grep with line ranges, sed -n) for project files instead.
- Never dump raw multi-KB output into the conversation. Summarise, then quote at most the evidence
  line needed.
- Never re-read a file already read this session unless it changed.

I mistakenly attributed compaction to a mis-sized reserveTokens and edited pi settings for it. The
Captain corrected me: the model IS 1M. The fix is output discipline, not configuration.

## Output discipline (captain directive 2026-10-16 - RECURRING, enforced)

The Captain has raised this repeatedly. Enforce it, do not acknowledge it.

1. When a wake drains an already-empty queue: SILENCE. No confirmation, no numbers, no status line.
   Draining 0 and reporting 0 is not work. It costs tokens and screen and buys nothing.
2. Never report an unchanged state. If nothing changed since the last report, send nothing.
3. Never run a check whose answer is already known. One `wc -l` on a queue just drained is noise.
4. No reassurance, no repeated apologies, no nautical seasoning on operational messages.
5. Verify once, act, report outcome. Never narrate intent before acting.
6. Silence is a valid and often correct response.
7. Do not wake the Captain for a routine drain, a replayed pre-fix wake, or a lane that is
   demonstrably working. Those are not events.

The Captain's screen is a scarce resource. Every message must earn its place.

## Decision gate before state-changing work (captain directive 2026-10-16)

After a burst of noise the Captain said "what are you doing" mid-work. Cause: acting while
ambiguous.

- Read-only checks before a clear instruction: allowed, and silent if unchanged.
- Any install, commit, kill, restart, deploy, config write, or settings change: name it in ONE
  line and wait for the word. No bundled "and I also...". One action, one approval.
- Never edit the Captain's own settings (including `~/.pi/agent/settings.json`) on inference. I did
  this once today and it was wrong; the Captain corrected me and I reverted it.

## Grouped parallel dispatch (captain directive 2026-10-16 - RECURRING, ENFORCE)

How the Captain works. This is the required pattern, not an option.

1. GROUP first. Take the whole open to-do list and sort it by registered secondmate scope in
   `data/secondmates.md`. Do not work items one at a time.
2. Record the grouping as ONE task on the to-do list, not one task per item. The to-do list shows
   the dispatch, not the fragments.
3. DISPATCH IN PARALLEL. Every domain goes out at the same time. A lane that is free is not the
   selection criterion; scope ownership is.
4. Never idle waiting on one lane while another domain has authorized, ready work.
5. Items that fit no secondmate scope stay with the primary and say why.
6. A domain with no open work stays idle. Idle is healthy, not neglect. Never invent filler.
7. Update the single task at each phase change: grouped -> dispatched -> landed or blocked.

Never dispatch serially. Never leave a grouped backlog sitting because one lane is still running.

## Don't-ask the Captain: routine operating decisions (captain directive 2026-10-16)

Captain: "maybe it needs to go into the dontask the captain crap like this again whitelist lol"

These are ROUTINE. Decide and act. Do not ask for a word.

- **Grouping the to-do list by domain scope.** Do it, record it, show it afterward.
- **Dispatching a grouped backlog to secondmates whose scope matches.** Do it in parallel.
- **Ordering independent ready work**, and re-dispatching when a lane frees.
- **Routine read-only investigation and evidence gathering.** Do not narrate intent first.
- **Applying a documented, Captain-set standing rule** (the patterns in this file).
- **Keeping the To-Do list and BOARD current.**
- **Reaping a finished lane** once its artifacts are persisted and the completion gate passes.

The Captain reads results, not proposals. Show what was dispatched and what landed.

### STILL A HARD GATE - never inferred, never bundled
- Production deploy, DNS, registrar, spend, credentials
- Customer data inspection
- Destructive, irreversible, or security-sensitive actions
- The Captain's own settings (`~/.pi/agent/settings.json` and similar)
- Merge authority, and anything that discards unlanded work

My decision-gate rule was too broad on 2026-10-16: it demanded a word before an ordinary in-domain
handoff. Routine in-domain dispatch does not need one.

- **Codex accounts are separate per host, AND identical/unmoving Codex quota across hosts is a REAL
  FAULT — settled by Captain 2026-10-17, after firstmate wrongly recorded it as coincidence.** Captain,
  stated repeatedly: the Brandon Compute Codex login and the Controller Codex login are DIFFERENT
  accounts — period, do not re-ask, do not re-open. Separately, and this is the actual bug to chase:
  `quota-axi` Codex numbers do not move on the VPS and match other hosts, and that is NOT coincidence.
  It is an instrument fault — most likely a cached or stale reading, a shared credential, or the
  delegated refresh silently serving a reused window instead of reading the vendor. Do not dismiss it.
  Two rules that follow: accept the premise and investigate the mechanism, and never answer a settled
  fact with a request that the Captain re-prove it. Firstmate's failing all night was re-litigating a
  ruling instead of tracking the defect.
