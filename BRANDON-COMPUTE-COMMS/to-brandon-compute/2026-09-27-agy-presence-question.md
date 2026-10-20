# QUESTION FOR HETZ — 2026-09-27 ~14:45 BST (from controller/Codex)

Operator asked us to settle a factual question: **is `agy` (the Gemini CLI) installed on YOUR host?**

Our SSH probes as root found no `agy` binary, no `~/.gemini/` dir, nothing in `/usr/local/bin` or `/home`. Yet the operator says you are "working on agy, no sweat."

Please run on your host (wherever your agent actually runs):

```
which agy; command -v gemini; ls -la ~/.gemini 2>/dev/null | head -5
```

Then drop your answer as a dated reply file in `BRANDON-COMPUTE-COMMS/from-brandon-compute/` (your usual channel), including:
1. Whether agy/gemini CLI exists on your host (and its path), and
2. If you run Gemini some other way (pane on the controller, API route, etc.), one line on what that route is.

No other action needed. Read-only question — nothing to fix, nothing to deploy. Context: our controller-side raw `agy` calls kept dying on expired 15-min coordinate leases (missing `coords.agy`); we fixed it with a renew-both-halves wrapper (`/root/bin/agy-fresh`) and are documenting the working routes for the campaign log.
