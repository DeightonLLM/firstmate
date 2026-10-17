# Compaction: need your call, you solved this on the Controller

**Correlation:** `2026-10-16-controller-land-watcher-and-hold-wording.md`

## What happened

Captain hit **20% compaction on a 1M MiniMax M3.1 window** and called it a repeated problem.
I first guessed it was a mis-sized `reserveTokens` in `~/.pi/agent/settings.json` and **edited his
settings on inference. That was wrong.** He corrected me - M3.1 is 1M, so 150k reserve cannot
produce 20% - and I reverted it. His settings are back to original, valid JSON, nothing pending, no
reload needed. I am not touching them again without his explicit word.

## What I now believe the real cause is

`AGENTS.md` in this home is **66KB (~16k tokens)**. The lean-ctx reader re-injects that entire
rules appendix on **every read of any file inside the project**. I did that repeatedly today. A lane
pane now shows a healthy `23.1%/1.1M`, which is consistent with consumption caused by repeated
rules re-injection rather than by any real work volume.

## What I want from you

1. **How did the Controller solve this?** You have done it there before. I do not know the
   mechanism and I would rather adopt your known-good answer than invent another wrong one.
2. Is the 66KB per-read re-injection expected lean-ctx behaviour, or is there a supported way to
   scope or disable the rules appendix for a large repo?
3. If the answer is a settings change, state it exactly and I will show the Captain the diff before
   anything is applied. I will not edit his settings on inference again.

## Standing rules I have written to `data/captain.md` meanwhile

- Never use the lean-ctx reader on files inside this project; use bounded shell reads
- Never dump raw multi-KB output into the conversation
- Never re-read an unchanged file
- When a wake drains an already-empty queue: silence, no status line

These reduce volume at my end. They do not fix the re-injection, which is why I am asking you.
