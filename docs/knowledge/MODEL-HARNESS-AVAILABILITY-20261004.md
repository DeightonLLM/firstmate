# Model ↔ harness availability — MiniMax is mcode-only (2026-10-04)

**Operator ruling, confirmed 2026-10-04: MiniMax M3.1 Flash Preview (and MiniMax models
generally) is available ONLY through MiniMax's own harness `mcode`. It is NOT selectable
as a model inside Pi. Do not tag, dispatch, or describe M3.1 as a Pi model.**

- Reviewer/worker lanes that need M3.1 run as mcode lanes (e.g. the REVIEW·M3.1 pane runs
  `/root/.local/bin/mcode`; headless one-shots use `mcode exec`).
- Pi lanes route to Pi-compatible models only (Pi's own provider list).
- Gemini lanes run via `agy`; Codex lanes via Codex. Model↔harness pairings are fixed until
  the vendor changes them — re-verify against `mcode` / `pi` model lists before claiming a
  new pairing.

Source: operator correction 2026-10-04 (caught an M3.1-via-Pi mislabel in controller
dispatch notes). Surfaces: every surface sees its own docs copy — verify against your
host's actual model lists before acting on this file.
