# Learnings
<!-- memory tiers: see the stow skill -->

- 2026-09-24 — Treat Herdr pane titles and aliases as presentation, not identity: use Firstmate task records for assignment and model, and `herdr agent get <pane>` for live process state. Today's check found a pane titled M3 while its Firstmate task record identified MiniMax-M2.7; see `data/pi-herdr-operator-notes.md` for detailed mechanics. <!--a:2026-09-24-->
- 2026-10-12 — Controller's approved bidirectional pickup is `/home/hd2admin/controller-replies/` on this host; publish sanitized notes there and check incoming replies. It is not a shared filesystem or proof of acknowledgment. If direct contact is needed, the verified target is `hd2@100.117.47.27`, not an inferred hostname or `/root` path. Owner: Controller's crossover acknowledgment and assignment handoff in that directory. <!--a:2026-10-12--> <!--f:hd2admin-->
- 2026-10-12 — Local Pi report recovery: use actual returned artifact paths; a missing `outputReference` does not mean an external MCode report is absent. MCode one-shot children cannot be steered/resumed. Native retained reviewers can reuse a previously claimed output path and fail publication despite a preserved final answer; a fresh explicit API output binding recovered the answer without rerunning analysis or overwriting the old report. Consult current subagent tool-reference; see `data/core-distro-compaction-2026-10-12.md` for this task's retained evidence. <!--a:2026-10-12-->

## 2026-10-13 — operational discipline (high value, cost four wrong calls)

These are general to any firstmate operator, not specific to this home's projects. Each one was learned by
getting it wrong first, which is why they are recorded.

- **A gate refusal is the system telling the truth, not an obstacle.** This system is built from a
  blocked-bash standpoint: worktree isolation assertions, `bash` not allowlisted (exit 126), decision-hold
  completion gates, teardown refusing dirty or incomplete tasks, and no `--force` escape hatches are all
  architecture working. Never write "you are authorised to X" into a brief to get past one. See
  `data/captain.md` for the recorded standing rule and `bin/fm-brief.sh --worklocation` for the sanctioned
  mechanism that handles the one legitimate exception (operating on a live, non-version-controlled tree).

- **Authorisation is not capability.** Writing permission into a brief does not grant a tool or lift a sandbox
  restriction; it only teaches workers that gates are advisory. When a command is refused, the correct
  response is to find the *sanctioned* invocation the system already uses, change the design deliberately, or
  report it. A brief cannot override a gate. The repo's own CI is the reference: it invokes
  `/bin/bash tests/<name>.test.sh`, which works where bare `bash` is refused.

- **Read the current checkout, not a stale one.** Four separate wrong claims in one session came from grepping
  a checkout that was 43 commits behind `origin/main`: a guard script reported missing, its test file reported
  missing, a config knob reported unread, and 39 suite failures blamed on the change under test when they were
  pre-existing on the base. Before asserting that something does not exist, check `git ls-tree origin/main` and
  a worktree at current HEAD, not just the working directory.

- **A worker's summary does not survive independent verification.** A classification pass reported four entries
  as done; two were not — the artifact existed but the work had not completed. Verify with the status tail and
  the artifact itself before closing anything. A worker that reports `done` without a file on disk has not
  done the task; that happens, and it must be caught, not relayed.

- **A dispatch decision can invalidate in-flight work.** Fast-forwarding a checkout over branches that were
  built on the old base silently reverted a landed fix, because upstream overwrote the same file. Check what
  in-flight work touches files the sync will change, and sequence sync before or after deliberately, never
  blind.

- **Local-only merges are invisible to the teardown content check.** `fm-teardown.sh` decides "landed" by
  asking whether the worktree's content is already in `origin/<default>` or a merged PR. A fast-forward into
  local `main` that is never pushed therefore leaves tasks permanently unreapable and produces recurring
  false-positive watchdog escalations. Push landed work; do not defer it as a question.

- **Idle capacity must not consume the concurrency budget.** Counting every live pane made seven intentionally
  idle domain experts exceed a cap of six and block all dispatch. The landed fix counts only *working* lanes
  and classifies unknown/unreadable as working, so the cap cannot be defeated by a wedged worker going quiet.
  Preserved in `bin/fm-dispatch-guard.sh`, commit `b12b65a0`, tests `tests/fm-dispatch-guard-max-lanes.test.sh`.

- **A backlog that claims work is in flight while its endpoints are dead stops being a queue.** Entries were
  never closed when their work landed, never created for work that never existed, and never distinguished from
  real unfinished work. Four entries had no report, no status and no task directory at all, yet sat in flight
  beside genuine work. Audit periodically with evidence per entry, and close absent entries as never-existed
  rather than leaving them to imply someone should pick them up.

- **Catalog presence is not runtime resolution.** A model can be listed in the cached catalog and still be
  unresolved at session start, running with fallback metadata (a 204,800-token window instead of its advertised
  1M). Prove model configuration with a real reply from a fresh launch plus its stderr, and prefer an ablation
  (remove the change, observe the failure return) over inference when the question is whether a fix is load-bearing.

- **Bulk JSON on a command line is a hard ceiling.** Passing a growing backlog through `jq --argjson` puts it in
  the exec argument vector, which the kernel bounds; past that limit `jq` never runs and the snapshot silently
  produces nothing. Landed fix moves bulk input to stdin/`--rawfile`; commit `0118dd49`. Never fix this by
  truncating or capping the input, which makes the tool lie rather than fail.FIXED: stale default decision keys were self-inflicted.

Root cause: bin/fm-classify-lib.sh:175-187 maps an UNKEYED status line ("blocked:" or
"needs-decision:") to the key "default". Every unkeyed blocked line I appended tonight
therefore opened a default decision. fm-decision-hold.sh:296-299 then refused, because
"--none" is additive only and will not silently drop a decision that is merely absent from
the current report. The tool is correct to refuse; I created the blocker.

No subcommand removes a status-only stale key. That is a genuine gap worth noting, but it is
not what stopped those five completions - the keys were mine and should not have been opened.

Standing rule from 2026-10-15: every status line that could open or update a decision MUST carry
an explicit [key=<slug>] matching the task decision identity, or must be phrased so it cannot
classify as a decision at all. Never append an unkeyed "blocked:" or "needs-decision:" line.

## 2026-10-15 — STANDING STOP: srv1137994 / animovps / Aminolifesciences

**Controller order, received 23:5x, correlation `controller-no-silent-stop-rule-20261015`.**

`45.90.220.156` = `srv1137994` = `animovps` = Brandon edge/control plane for **Aminolifesciences**.

**Forbidden entirely. Do not touch, probe, resolve, dispatch to, or route work to it.** Not staging,
not a certificate, not a DNS question. Not for any reason.

**KVM1's true identity is UNVERIFIED.** Do not infer it, do not map it to `elevatesVPS` or to any
address seen in conversation. Do not answer host-identity questions from
`/root/docs/agent-policy/SURFACE-IDENTITY.md` — **that file is wrong and is the defect.** The authority
is our committed `docs/system-context/hosts.yaml`, and until a corrected registry is published, the
answer to "which host is it" is **none, until the registry says so.**

If a task seems to need that host or the staging IP, stop and report the exact need to the Controller.

**Staging host remains OPEN and unresolved.** The cert expiry and the HTTP 500 are two separate faults,
and renewing the certificate will not fix the 500.

- 2026-10-19 — Run `quota-axi --json` BEFORE every dispatch/model choice, not after a failure. Dispatched the
  Whoosh full-page acceptance lane to Luna without checking quota; the openai-codex five_hour window was
  already at 0% with `runway: exhausted_now` (resets 05:41Z) and the lane died mid-capture on
  "usage limit reached". Cost: one interrupted run plus a relaunch on M2.7. Standing rule: 0% +
  exhausted_now = do not dispatch to that provider; a mid-run quota death is not retried on the same
  provider, and projected reset times are not runway. Captain flagged this miss directly. <!--a:2026-10-19-->
- 2026-10-19 — A worker looping on `edit` failures with the same "oldText must match exactly" error is reusing stale text, not hitting a
  guard. This happened twice on the same day with different providers (Luna, then MCode M2.7). When the third identical failure appears, the
  productive move is a corrective steer: re-read the current bytes, apply ONE edit with a short unique span, syntax-check immediately, and if
  that fails stop editing and hand back the exact current function text. Do not escalate the file rewrite, do not switch to sed/perl to bypass
  the edit tool, and do not read it as a permission problem. <!--a:2026-10-19-->
- 2026-10-19 — **Before writing any fix, list the branches and read their commits.** I wrote and pushed a
  z-index "fix" for a Core bug that had already been fixed two days earlier on
  `fix/add-leads-modal-nesting` (`f26d4d8`), then spent a verification lane proving what was already known.
  The work was correct; it was **undiscoverable because nobody wrote down which branch held what.** A fix
  for the same symptom on a branch makes that branch the source of truth, not an invitation to write a new
  one. Durable record created: `docs/core-saas-branch-state-map.md`. <!--a:2026-10-19-->
- 2026-10-19 — **Audit the target before trusting any measurement taken against it.** An entire day of Whoosh
  pixel-parity work produced confident, well-formatted numbers measured against a "reference" site that was
  failing **38 of 52 subresources, including 9 fonts.** Nothing in the output looked wrong. Fixing the target
  flipped the verdict's SIGN — the port was not 260px too tall, it was 677px short. A broken target is worse
  than no measurement because it looks like data. Rule 1 of `AGENT-FLEET-KNOWLEDGE.md`. <!--a:2026-10-19-->
- 2026-10-19 — **When a counterfactual overshoots, you have two opposite-signed errors.** Removing the chat
  widget dropped the page 946px when the actual gap was 260px. That overshoot was the signal that the
  candidate was also ~686px MISSING that the reference had; the two errors cancelled in the total. Rank
  section deltas by SIGN, not magnitude — a net number hides both. <!--a:2026-10-19-->
- 2026-10-19 — **A lane that stops to ask about a contradictory instruction is correct behaviour, not
  stalling.** Three separate times a lane caught a brief of mine whose declared write boundary excluded a
  path the same brief required writing to. Each time the fix belonged in the brief, not in telling the lane
  to pick an interpretation. Fix: mandated boundary wording in `config/crew-dispatch.json`, plus
  `bin/fm-brief-preflight.sh` which rejects the contradiction and has executable negative controls. <!--a:2026-10-19-->
- 2026-10-19 — **A hypothesis that closes 0px of a measured gap is refuted — record it and move on.** Two
  plausible theories (a missing WordPress page template, a duplicated chat widget) were each built and each
  measured at 0px. A refuted hypothesis is a real result; do not keep tuning it. <!--a:2026-10-19-->
- 2026-10-19 — **Never route multiple client tenants to one shared origin to make a dashboard "work".** An
  agents-dashboard build would have served Core, Elevate and Whoosh from a single service — crossing client
  confidentiality boundaries, with workspace isolation already recorded as UNRESOLVED. The correct deliverable
  was a gateway that serves the one evidenced tenant and **explicitly refuses** the other two. The refusal is
  the feature. <!--a:2026-10-19-->
- 2026-10-19 — **Long pixel comparison is expected, not a hang.** Full-page PNG decode in pure Python runs
  minutes per invocation. Two lanes in one day looped on a 180s-timeout comparator instead of writing their
  reports from evidence already on disk; one lost its entire run to the 30-minute timeout. Direct the lane to
  write from what it holds — a lane that times out with no report is worth nothing. <!--a:2026-10-19-->
- 2026-10-19 — **Every branch gets a remote, immediately.** Seven branches in Core existed on no remote at
  all, including a mobile fix and a manifest-hardening pass — real work living only on borrowed laptops. All
  seven were pushed to `origin/archive/…` the same day. Unpushed branches are not "in progress", they are
  **lost with the machine**. <!--a:2026-10-19-->
- 2026-10-19 — **`document.fonts.status === 'loaded'` is not proof the intended font loaded.** It is
  compatible with the target face having 404'd and a fallback being used, which changes line wrapping and
  therefore element height. This made a reference's footer 124px untrustworthy as a target. Assert the
  actual `font-family` computed on the element, or verify the font URL's HTTP status. <!--a:2026-10-19-->

- 2026-10-19 — Dispatch panels render a bare agent name for a direct single-child launch. To get a lane name the Captain can see, dispatch as
  a workflow whose child `key` IS the convention lane key and whose `label` is human-readable (`runs.all([{ key, label, agent, task }])`), via
  `subagent({ workflow: "<script path>" })`. A workflow string that is a script PATH works; pasting the fenced ```js block into the workflow
  argument does not and fails with ENOENT. <!--a:2026-10-19-->

## 2026-10-21 — verifying a lane's own claim, and three classes of false signal

These four cost real time this session. Each is general to any firstmate operator.

- **A suite that asserts the ABSENCE of a production artefact measures the environment, not the code.**
  A check of the form "no artefact X exists in the live directory" is only meaningful when the directory
  is one the test owns. Run against a live home, it asserts that production is idle — so it passes when
  nothing is happening and fails exactly when the system is working. The fix that preserves intent is to
  snapshot the artefact NAME set before the run and assert the set did not GROW. Compare names, not
  contents: a live daemon appends to its own log, so a content comparison trades one flaky failure for
  another. Take the "before" snapshot before the work starts, or the check is vacuous. A lane reporting
  "N/N checks green" is not evidence the suite is isolated — reproduce it in the environment it will meet.

- **A verdict that reports failure for a delivery that succeeded is the same class of harm as the
  opposite.** `fm-send.sh` printed "delivery unconfirmed" for a message the pane received, read and acted
  on within seconds. The safe default (fail closed) is right for a genuinely ambiguous send, but a false
  negative teaches the operator that a working lane is unreachable, and re-sends a message that already
  landed. When a send tool reports a verdict, CONFIRM IT AGAINST THE RECEIVER before acting on it. The
  same blind spot appeared twice in one session: a send that could not confirm, and a busy-detection that
  could not confirm. Both were missing evidence, not wrong logic.

- **A liveness detector that reads a registry nobody writes will always report an empty fleet.** The
  safety net counted live lanes from `state/lanes/*.lane`; the last file in that registry is dated
  2026-10-05, because the fleet moved to `state/<id>.meta` and nothing maintained the old format. It
  reported "no-live-lanes" every 30 minutes while two lanes ran. Before trusting a detector, check that
  its INPUT is still written by something — `grep` for the writer, not just the reader.

- **A long primary turn looks like a dead primary.** The heartbeat bound is 1800s, and a status line
  "buys 30 minutes". A primary that did not write one for 16 hours was escalated three times inside a
  77-minute window — each escalation a model turn whose content was "you have been quiet". Write the
  heartbeat line during long turns; it costs no model turn and it removes a self-inflicted escalation.
