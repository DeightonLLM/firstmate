# Task
## Captain's intent
Live bug report (captain 2026-10-05): on Android every reply refreshes the entire chat frame AND the 3-tick consent box re-appears. Required:
(1) consent asked ONCE per visit — persist acceptance in localStorage (e.g. elevatesci-chat-consent=1+timestamp), skip flow when present;
(2) find and kill whatever reloads the frame on reply (form submit without preventDefault / widget re-init);
(3) ALSO apply the attached widgetfix-20261005.patch per the .md (mobile send button iPhone+Android, circular logo no distortion).
BACKUP every mutated file (.bak-consentfix-20261005). Verify served assets changed (curl diff) + write the mobile test steps for the captain. Artifact: .../widget-consent-fix-20261005.md + final VERDICT line. To-Do >=5. STOP after.

## Firstmate spec
Bounded fix. Edit host-side bind-mounted asset ONLY. No container internals, no DB writes, no API changes, no config changes, no image changes. Read the prior widgetfix-20261005.md to understand what's already deployed.

# Setup
This is a SCOUT task. Read-only inventory first, then bounded presentation-layer patch on the bind-mounted widget JS.

# Rules
1. Never push or write outside this worktree, the widget asset, the report paths, and the inbox/handled directory.
3. Report status by: `echo "{state} [at=<epoch>]: {one short line}" >> '/home/hd2admin/kun-agent-workspace/state/widget-consent-fix-20261005.status'`
   States: working, needs-decision, blocked, paused, done, failed.
4. If blocked twice, append `blocked [at=<epoch>]: {why}` and stop.
5. Use lean-ctx for all reads, searches, listings, shell output.
6. Use the To-Do List extension with five+ dependency-aware items: preflight+read prior .md, audit consent box logic, audit form-submit handler, write consent-fix patch (parts 1+2), verify + backup + report.
7. The widget is a static asset on the host; never restart the container. Confirm RestartCount stays 0.

# Firstmate instruction inbox
Check '/home/hd2admin/kun-agent-workspace/state/widget-consent-fix-20261005.inbox'/*.msg. Move handled to inbox/handled/.

# Definition of done
Report must include:
- VERDICT: PASS or BLOCKED or PARTIAL
- Parts (1) and (2) change descriptions with code excerpts
- Part (3): confirm pre-existing widgetfix-20261005 patch is still live (md5, byte count, served bytes)
- Backups: list of every .bak-consentfix-20261005 file with sha256 + original size
- Served-asset curl diff (pre vs post, local + public paths, md5 + bytes)
- Mobile test steps for the captain (3-tick consent, send-button on iPhone, circular logo on Android+desktop, frame-reload test on Android)
- Core-Distro disclosure (shared widget, same bind mount, same JS, no Core-specific change)

Write to:
- `/home/hd2admin/kun-agent-workspace/data/widget-consent-fix-20261005/report.md` (full)
- `/home/hd2admin/kun-agent-workspace/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/widget-consent-fix-20261005.md` (captain copy)

Append `done [at=<epoch>]: {one-line conclusion}` to status file.

# Home brief additions
## Pi Worker Defaults
- Create one concise checklist with Pi's `todo` tool at task start.
- Use lean-ctx for shell output; find it at ~/.local/bin/lean-ctx if not on PATH.
- Use Codex GPT-6 Luna medium effort per captain.
- Use MiniMax M3.1 Flash Preview for independent review before final commit (optional but recommended).
- Use git-style backup naming `.bak-consentfix-20261005` on every mutated file.
- If you can't reach the bind-mounted widget via ssh, HTTP fetch is fine — bind-mount path was published as `/home/hd2admin/hd2stack-anythingllm/branding/anythingllm-chat-widget.min.js` (host-side) and `http://100.106.6.22:3001/embed/anythingllm-chat-widget.min.js` (served).