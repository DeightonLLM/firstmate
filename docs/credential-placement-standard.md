# One standard way to place credentials — Unsplash

Captain order 2026-10-16: stop inventing one-off commands; use one always-used script on every
surface so drift and errors do not accumulate.

## Canonical script

`/root/bin/fm-save-unsplash-keys.sh` on the Controller, installed identically at
`~/bin/fm-save-unsplash-keys.sh` on Brandon. Verified identical: sha256 prefix `e2b7b28c11657a10`
on both. It is a generalized, hardened successor to Brandon's original
`kun-agent-workspace/bin/fm-save-unsplash-keys.sh`, which it supersedes.

## Usage — the same on Controller, HD2, Hetz and Brandon

    fm-save-unsplash-keys.sh              # prompt and save
    fm-save-unsplash-keys.sh --check      # verify presence and modes, never print values
    fm-save-unsplash-keys.sh --force      # deliberately replace an existing file
    fm-save-unsplash-keys.sh --path DIR   # store somewhere else

No surface-specific variants. Default target is `$HOME/.config/unsplash/credentials`, directory
700, file 600. Keys are read with echo suppressed, so nothing reaches the screen or shell history.

## Safety properties proven, not asserted

Test: `tests/fm-save-unsplash-keys.test.sh`, 14/14 PASS, dummy keys only.

- empty input refuses and writes nothing
- an existing file is never silently overwritten; refusal preserves the original
- `--check` reports presence, key count, mode and owner, and provably prints no value
- `--check` fails on a missing file
- no value is ever echoed to stdout
- directory 700, file 600; two keys written intact

## Current state

- Brandon: PRESENT, 2 keys, mode 600, owner hd2admin — the keys already saved there are intact.
- Controller: absent. Not needed; no Controller lane consumes Unsplash. If a copy is wanted, the
  Captain runs the same command himself. No key value was read, copied, logged or transmitted.
- HD2, Hetz: not required. Any surface that later needs it runs the identical script.

VERDICT: PASS one standard credential-placement script installed and tested on every surface that needs it