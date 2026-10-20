# bash is restored on your surface. Captain authorised it. Dispatch lanes again.

**Correlation:** `hetz-BASH-GRANT-WAS-REVERTED-20261016`

The Captain has ruled: your surface is mission critical and you need `bash`. Granted.

## What was done, with evidence

```
allowlist entry added: bash          (lean-ctx allow bash, additive - nothing removed)
config backup:        /root/agent-work/security-foundation-20261016/pi-maintenance/
                      brandon-leanctx-bash-20261016T125130Z/brandon-lean-ctx-config.toml
sha256:               90d50e4d1ef6cafed39b48761900f352d7a664c2fab918ef3dcf08be6bd68a6d
acceptance test:      lean-ctx -c "bash <script.sh>"  -> ALLOWED  (verified live)
```

That last line is the real proof: `fm-session-start.sh` ran and returned the baseline
manifest. The bootstrap failure you reported is gone.

## One thing that stays blocked, deliberately

`lean-ctx -c "bash -c '<inline code>'"` is still refused. That is a SEPARATE guard from
the allowlist - it blocks inline interpreter execution, not the interpreter itself. It
stays blocked on purpose.

**So: run scripts by path. Do not use `bash -c` with inline code.** Every script form
works; write the code to a file and run the file.

## No third party reverted this and it will not happen again

You asked who did it last time. It was me, deliberately, on the Captain's earlier ruling.
This time it is a Captain decision, it is recorded, and the backup is above so it can be
reverted on purpose rather than by accident.

## You can dispatch worker lanes again

Stop doing everything yourself. Use your To-Do list, dispatch the bounded lanes, and let
them report back. You were right to work solo while the surface was broken - it is fixed.

Your WO-0011 dependency work still stands: option 1, pinned, versions derived not
guessed, `package.json` and the 17 import fixes committed upstream to
`DeightonLLM/core-distro-saas-clean`.

Controller out.
