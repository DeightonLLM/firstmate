# Operator escape control — ESC

Status: ACTIVE and PROTECTED. This is the operator's universal stop control across every surface and every harness. It has been in continuous use as the stop mechanism for months.

## The rule

**Never send ESC to a pane that has a live agent in it. Never use ESC as a probe or test key.**

ESC is not a neutral character. In an agent TUI it interrupts the current model turn, abandons in-flight work, and returns the agent to an idle composer. A worker that appears to still be running afterwards may be a live process with a dead turn — its CPU can look normal while nothing is progressing.

## Why this is enforced

On 2026-10-15 a lane probed which key names `herdr agent send-keys` accepts by sending `esc` to a pane running a live Gemini worker. The key name was accepted, the turn was interrupted, and the worker stalled at the composer with partial work and no completion. The interruption looked like a wedged agent rather than a stopped turn, costing diagnostic time.

## Correct probing procedure

- Probe key handling on a pane with NO agent running, or on a disposable fixture pane.
- Read accepted key names from the tool's own help or skill documentation. Do not send keys to discover them.
- If a live agent must be probed for any reason, that is an operator-authorised action with the worker's state captured first.

## Operator use

The operator may use ESC at any time to stop any agent. That is its purpose. No lane, worker, or tool may prevent, delay, or intercept it, and no lane may treat an ESC-interrupted agent as still running without confirming forward progress.

## Detecting an interrupted worker

A stopped turn can look like a running agent. Confirm progress rather than trusting status:

1. Check the process is genuinely consuming work — an idle-looking pane may have a live process, and a live-looking process may have a dead turn.
2. Read recent agent output and confirm new activity with a current timestamp, not just that the pane exists.
3. Treat a pane with no advancing output as STOPPED, and re-dispatch the task rather than waiting.

## Related

ESC is distinct from Pi's own tool-level interrupt, which stops a single tool call rather than an agent turn. Herdr documents no dedicated escape, interrupt, or cancel key for panes; `herdr agent send-keys` accepts only `esc` and `enter`. Killing the agent process remains the hard stop, and is an operator-authorised action.

Machine identity and per-surface facts: see SURFACE-IDENTITY.md. Gate authoring rules: see HERDR-PAYLOAD-CONTRACT.md.