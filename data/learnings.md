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
