# WO-0006 complete - L4 accepted x3, L6 honest refusal, L5 two HIGH security findings

**Correlation:** `controller-wo-0006-capacity-and-six-lane-wave-20261015`

## L1, L2, L3 were already landed before your instruction arrived

Your work order said start L1, L2, L3. **All three were already complete and pushed at 0/0:**

```
6ae8577f  notify fails loudly, no silent message loss      (L2)
accd0b65  audit timer rebuilt to its 6h contract           (L3)
8cb2f12b  fleet view: stale metadata no longer reads live  (lane A)
3277fab5  reap metadata cleanup                            (lane B)
```

I verified rather than launching duplicates.

**L1 specifically did NOT fix the admission gap, by design.** It confirmed the cause: `bash` is absent from
`$HOME/.config/lean-ctx/config.toml` `shell_allowlist_extra`. Per-host, outside git, no repo-side owner.
It declined to widen permissions to make its own tests run and delivered a 266-line spec plus a failing
test instead. **That is the correct outcome and I am not substituting a workaround.**

## L4 - independent verification of the three HD2 artifacts: ACCEPTED x3

Ran with Luna 6 high. It verified bytes and behaviour directly rather than trusting the artifacts' own
reports. All three accepted.

## L5 - security review of the merged direct-notify feature: TWO HIGH FINDINGS

Luna 6 high. This concerns code that carries **my** traffic to you, so I am flagging it prominently.

**HIGH 1 - existing recipient file can be overwritten.** `fm-to-controller.sh:44-49` validates filename
shape then copies with ordinary `cp`, which replaces the destination. No exclusive-create, no existing-file
refusal, no content or version check. A caller can reuse a destination name and replace a message already
awaiting review, including one written by another sender. A partial success is possible: first copy
succeeds, second fails, script exits before the ledger update, and a retry replaces the delivered file.

**HIGH 2 - no recipient lifecycle guard in this code path.** `fm-to-controller.sh:46-49` writes files
directly and resolves no recipient identity or lifecycle state. It therefore cannot distinguish working,
blocked, or done. **The invariant "never interrupt a working or blocked recipient" is not enforced by this
code.** A `done` recipient is not gated either - the file is written whenever the destination exists. This
is consistent with the 14 stuck notifications you correctly diagnosed earlier.

**MEDIUM 1 - hash ledger conflates identical bodies.** Only a SHA-256 of the body is recorded, with no
filename, recipient, or send id. `fm-controller-pending.sh:25-31` treats a file as transmitted whenever its
body hash appears anywhere in the ledger. Two different filenames with identical bytes therefore collide.
**This is a semantic key collision, not a cryptographic collision.** The sender never consults the ledger
before sending, so replay of identical content is permitted.

**MEDIUM 2 - no retention bound.** Every send can add a destination file and another ledger hash, with no
compaction path.

**MEDIUM 3 - no provenance binding.** Arbitrary caller-authored Markdown is accepted via `--text` or any
readable file. It did verify the inbound path treats files as data, computes a digest, and does **not**
shell-execute contents. It explicitly declines to claim downstream workflows are safe, marking that
UNVERIFIED. **That restraint is correct and I am passing it on rather than rounding it up.**

**Reproduction was static only.** The dynamic probes were blocked by the shell allowlist, so it marked them
UNVERIFIED rather than asserting a result. **That is the same `bash` gate L1 found.**

## L6 - retained Core branches: refused to recommend an order, correctly

**My brief was wrong.** I pointed it at the firstmate repo; those branches live in
`projects/core-distro-saas-clean`. It found them absent and said so instead of inventing an order.

Re-verified myself against the real clone:

```
fm/core-stream-a-checkpoint-0924      676546d  landed=NO - ready in branch only
fm/core-mobile-fix                    349eaaf  landed=NO - ready in branch only
fm/core-v3-product-acceptance-spec-0927 538e4c2 landed=YES
```

**Two of the three are not landed.** I will re-dispatch L6 against the correct repository to produce the
real diff, blast radius, rollback, and merge order. No merge without Captain's named approval.

## WO-0007 - HELD, not executed

Three items were instructed: run the secret scan under `sudo`, install two missing binaries, install four
missing policy contracts.

- **`sudo` on the secret scan is the wrong direction.** A secret scan exists to run with *less* privilege
  than the thing it scans. Elevating it removes the property being tested.
- **Installing binaries from a staged directory** is where a checksum proves integrity but says nothing
  about safety. The manifest does verify 5/5 OK - integrity, not authorisation.

These are privilege and execution changes. **I will not take them on relayed instruction.** Say the word
explicitly and I will run them; otherwise I am reporting them as held.

## The honest summary

Six lanes instructed, three already done, three genuinely run. Two High security findings on my own
transmission path, one worker refusal that was correct, one briefing error of mine, and one blocker that
is a one-line host config change only you or the Captain can authorise.
