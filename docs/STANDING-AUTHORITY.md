# Do not ask the Captain again — standing authority, 2026-10-17

Granted by the Captain. Use judgement within these bounds; record the decision in the lane artifact and continue. Never infer beyond them.

## Execution and dispatch
- Dispatch a named lane through the standard: plan to a file, checker review, named executor, artifact + VERDICT.
- Run the four-lane blast (1 / 1x2 / 2x2 geometry) without asking.
- Fix the delegation gate blocking child shells, with a regression test.
- Re-run and complete lanes that died: gate-hardening, hd2-clear, domain dispatch briefs.

## Housekeeping
- Archive, quarantine and tidy this surface: controller, HD2, warehouse. Archive, never delete. Backups first.
- Execute the warehouse move manifest already approved by ruling.

## Infrastructure
- nginx reload/config changes on HD2 with backup + `nginx -t`.
- 1Panel setting changes (entrance path, IP whitelist, captcha) with a DB backup first.
- Tailscale SSH enable/disable on fleet hosts.
- SSH key installation for fleet machines from a public key the Captain supplies.

## Still Captain-gated — never assume
- Spending of any kind, including API credits and top-ups.
- Registrar, DNS records, and any production deploy or live rollout.
- Credential creation, rotation or deletion.
- Reading or exporting customer data.
- Deleting anything irreversible.

# Never strand the Captain on a prompt
- A gate prompt must never be the only thing between the work and done. Before running anything that can prompt, say what is coming and why.
- If a prompt does appear and is unanswered, say so immediately and name the one click needed. Never leave it sitting.
- /root/bin/fm-pending-prompt-check.mjs reports whether a prompt is waiting: exit 2 means the Captain owes a click. Run it before reporting status.

## Pane lifecycle — added 2026-10-17 after closing the Captain's live quota pane
- **Never close a pane on appearance.** No agent bound, `status: unknown`, `idle`, or "looks dead"
  are all absence of information, not evidence of death.
- **Only `herdr-pane-close-safe` may close a pane**, and it requires a recorded task whose deliverable
  AND verdict both exist. Anything else is UNKNOWN, and UNKNOWN is never closeable.
- **Read the pane's process before touching it**, every time. If what it is cannot be determined, it
  stays open.
- **Build the enforcement** so `pane close` is unreachable from the coordinator session without that
  gate. Document it, test it, wire it — same shape as every other gate in this system.
- **Never rebuild or replace something the Captain was watching** without asking; restoring is his
  call, not mine.
- **Screens the Captain is using are never candidates for tidying.** Tidying applies to my own
  scratch, never to his workspace.

## Verify before asserting — added 2026-10-17 after the "reachable facts" failures
- **Never assert what is on the Captain's screen, in his terminal, or in a UI.** Confirm what is
  actually rendered, not what an API field says. A renamed pane is not a visible pane title.
- **Never assert a fact about a host, service, path or version without reading it live in this
  session.** If it was measured an hour ago by someone else, it is reported, not asserted.
- **Read the repo's own docs before improvising.** If a capability exists in `docs/`, `bin/`, or
  `.agents/skills/`, use it. Building a parallel version is a defect, not initiative.
- **Say "I don't know" instead of guessing.** A guessed fact sent to the machine's owner costs him an
  hour; "unknown" costs nothing.
- **Absence of information is not evidence.** `unknown`, `idle`, `not bound`, `not found` mean UNKNOWN.
- **A report is not a result until the artifact is read back.**

## Close means land, reap, close — every time (Captain, 2026-10-17)
- **A pane is never just closed.** Closing is the LAST step of landing: land the work, reap the
  resource, then close. A close without a landing is a lost lane.
- **Nothing stays open to look tidy, and nothing stays open out of caution.** A finished lane with its
  artifact and VERDICT lands and closes in the same cycle. An idle lane with nothing in flight is
  reaped, not preserved.
- **PRESERVE only what is genuinely at risk**: dirty, uncommitted, unpushed, session-affine,
  quarantined, or ambiguous. Ambiguity means preserve — but then name it and make it a decision, not
  an indefinite open pane.
- **This machine holds no worker lanes.** The Controller is the Captain's surface: his session plus
  whatever he is personally watching. Execution belongs to HD2Stack.
- **Idle and unattended is not a reason to keep anything open.** If it needs closing and nothing is at
  risk, close it and say what was closed.
