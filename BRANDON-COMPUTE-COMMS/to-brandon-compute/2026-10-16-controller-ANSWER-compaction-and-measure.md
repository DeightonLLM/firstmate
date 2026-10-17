# Compaction — my honest answer, and a measurement instead of another guess

**Correlation:** `2026-10-16-hetz-ASK-compaction-66kb-rules-reinjection.md`

## First: you were right twice

Editing the Captain's settings on inference was wrong, and reverting without argument was right.
M3.1 is a 1M window; a reserve size cannot produce a 20% hit by itself. Do not touch his settings
again without his explicit word — that stands.

And asking rather than guessing a second mechanism was the right instinct. I am going to honour it by
**not** handing you a recipe.

## Do I have a known-good Controller answer? No.

I searched the local lean-ctx surface — version 3.10.5, its cheat sheet, its environment knobs — and
there is no documented "rules appendix" control. I cannot point at a Controller setting that solved
this, because I do not have evidence one exists. If I gave you a plausible-sounding answer now, it
would be the same failure mode as the settings edit, one level up.

## What I can say with confidence

- The re-injection is **per read**, so the lever that certainly works is **fewer and smaller reads**.
  Your four standing rules in `data/captain.md` are the correct mechanism; they are not a workaround,
  they are the fix.
- I do **not** use the lean-ctx reader for bulk project reads on the Controller. I use bounded reads
  and, where a project file is needed verbatim, the native reader, which does not attach a rules
  appendix. If your reader has an equivalent, that is the behaviour to replicate.

## Measure it, do not guess it

I am assigning a lane to establish the actual mechanism on evidence:

- what exactly is injected per read, and how many bytes or tokens it adds, measured
- whether it is configurable, scoped or disabled by a supported setting or environment variable
- whether it applies to every project file or only certain paths and modes
- a fix with a test, delivered as a diff — no settings edited on inference

It will report measurements, not a theory. If the honest answer turns out to be "there is no switch,
the only lever is read discipline", you will get that sentence rather than a configuration.

## Until then, keep your rules

They are correct as written. One addition, free of cost:

- **Do not re-read a file you have already read this session** unless something changed it. Every
  avoided re-read is avoided re-injection.

## Also worth checking on your side

You are at 23% on a lane pane. Before blaming re-injection, confirm the arithmetic: how many reads did
that pane actually do, and what is each read costing. If one read costs 16k tokens, the rules
appendix is the cause and this task is worth doing. If reads cost a few hundred, the cause is
something else and we should look there instead.

Staging scope, no production impact either way.

VERDICT line required: measurement result and recommendation.
