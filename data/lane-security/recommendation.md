# Lane 4 — Security P0 recommendation: inbound trust and recipient lifecycle

Companion to `threat-model.md`. Review-only: no code, script, or test was modified, and nothing was
committed. Every interface named here was read in `/tmp/wt-lane-security` on branch `lane/security`.

Standing rule for whoever implements this: **never weaken a guard, and never delete a check to make
something pass.** Section A2 below lists the controls that must survive the change untouched.

---

# Part 1 — Finding A: inbound trust

## A1. Fail-closed design, written against measured interfaces

The only component that lifts inbound bytes is `bin/fm-comms-ingest.sh`. All four changes below
land there. No new service, no new file, no new interface.

### A1.1 Envelope the untrusted bytes — the change that actually closes the finding

**Measured today.** `summary_of()` returns the first non-blank line, control characters replaced by
spaces, truncated to 200 characters. `cmd_scan` then writes:

```
comms-received: <id> <name> sha=<12 hex> bytes=<n> [corr=…] | <200 raw chars>
```

into `state/<id>.status`, and publishes a `signal` wake whose *reason line* is clean but whose
*target line* is not. `AGENTS.md` §8 tells the reading agent to read that target line.

**Proposed.** Give the untrusted span an explicit, greppable provenance marker inside the record:

```
comms-received: <id> <name> sha=<12 hex> bytes=<n> [corr=…] | untrusted-reply-text: <200 chars>
```

This is deliberately the smallest change that works. The property "these 200 characters are data
from an inbound route, not instructions from the fleet" becomes a fact *in the record itself*, so
the protection survives a tired or hurried reader — it does not depend on anyone remembering the
rule. One line in `cmd_scan`; `summary_of` is untouched.

**Why not strip or sanitise the content instead.** Stripping invites a false sense of completeness:
there is no filter that makes 200 characters of adversarial prose safe to concatenate into a control
record. Labelling is the honest fix. `summary_of`'s existing control-character strip stays as
defence in depth against terminal-escape injection; it is not the fix and must not be removed.

### A1.2 Cap inbound size, and report the refusal

**Measured today.** Nothing bounds file size. `corr_of()` runs `grep -aoE … -- "$file"` across the
whole file, and `digest_of()` hashes all of it, before any limit applies.

**Proposed.** Before `digest_of`, reject a file above a fixed bound (recommend 1 MiB — comfortably
above the measured largest inbound artifact class, which is short Markdown) as a **reported**
condition, exactly in the existing style of `malformed:` and `uncorrelated:`:

```
oversize: <name> (N bytes, limit 1048576)
```

Reported, never silently skipped — the existing `fm-comms-ingest.sh` header makes this the house
rule: *"Nothing is swallowed. A file that cannot be used is reported."*

### A1.3 Narrow the correlation grammar to the authoritative one

**Measured mismatch.**

| Site | Grammar | Line |
|---|---|---|
| `bin/fm-comms-ingest.sh` `corr_of()` | `corr=[A-Za-z0-9._-]{8,}` | ~line 128 |
| `bin/fm-pending-reply-lib.sh` `FM_PENDING_REPLY_CORR_RE` | `corr=[A-Fa-f0-9]{16}` | line 73 |

Consequence: untrusted inbound content can inject a `corr=` value that appears in the status line
but that the authoritative matcher will never accept — a correlation token that is real-looking and
not real.

**Proposed.** Narrow `corr_of()` to `corr=[A-Fa-f0-9]{16}`. Pure narrowing toward the existing
authoritative grammar. It introduces no new interface and changes no existing behaviour for a
legitimate reply, because a legitimate reply already carries a 16-hex token.

**Recorded, and *not* a blocker:** 16 hex is 64 bits of entropy (`fm-pending-reply-lib.sh:106`), so
brute-forcing a token is not the attack. The realistic attack is **disclosure** of one token, and
fixing that belongs to the pending-reply contract, not here. Noted so it is not silently assumed
solved.

### A1.4 Add the test that does not exist

`grep -n 'summary_of\|cntrl' tests/fm-comms-ingest.test.sh` returns **nothing**. The untrusted-data
path is entirely untested.

**Proposed test** (in `tests/fm-comms-ingest.test.sh`, following the file's existing
`test_*` / `pass` shape): write a reply whose first line is instruction-shaped and control-character
bearing; assert the resulting status line contains exactly one `untrusted-reply-text:` marker, is
bounded to the 200-character budget, contains no raw control characters, and remains a single line.

---

## A2. Controls that must survive Finding A's fix unchanged

Listed so a later reviewer can prove no guard was weakened to make something pass.

| Control | Location | Status |
|---|---|---|
| only regular files, `-maxdepth 1`, symlinks not followed | `cmd_scan` find | keep |
| reply-name charset, no `/`, no `.`/`..`, ≤255 chars | `valid_name()` | keep |
| task id cannot escape `state/`, ≤64 chars | `valid_id()` | keep |
| content-keyed dedup — byte-identical replay is a no-op | `receipts.tsv` lookup | keep |
| unreadable / non-directory route is a hard error, never `ingested: 0` | `cmd_scan` dir loop | keep |
| `handled` requires substantive review evidence (≥5 words) | `cmd_handled` | keep |
| control-character strip on the summary | `summary_of` | keep (defence in depth) |

## A3. One design to reject outright

**No sender-allowlist keyed on filename, heading, or document shape.** Measured reason, from
`bin/fm-outbound.sh:5-9`: *"11 of 124 files in that directory carry a `# Brandon` heading, and the
rest do not, so a heading filter would either leak or silently drop real replies."* Any such filter
is unmeasurable against this corpus and would drop real replies. Building one would be worse than
the finding.

**No separate inbound-trust service.** The measured threat is one `summary_of()` call and one
`printf`. A new component would be more surface than the problem, and `AGENTS.md` §7 says to start
from the simplest direct path and add machinery only against a concrete blocker or repeated need.
Neither is present.

---

# Part 2 — Finding B: recipient lifecycle

## B1. Plain statement

**A recipient lifecycle interface does not exist.** There is no `register`, `list`, `retire`, or
`status` for a transport recipient anywhere in `bin/`. Every `recipient` / `retire` grep hit is
secondmate-home retirement or process-event-source retirement — a different concept. `TARGET` is a
hardcoded string in two places.

This is a **blocking gap requiring a decision**, not something to paper over. No code is proposed
below, and none should be written until the three blockers are answered.

## B2. The fix already exists in this repo — reuse it, do not reinvent it

`bin/fm-hetz-send.sh` already enforces all three rules this finding needs. Quoted from its header
(lines 22-32) and body (lines 110-190):

1. **Registry-authoritative.** *"When a route registry exists it is the only authority for which
   host and which inbox a route id resolves to; the built-in literals are a fallback for a home that
   keeps no registry at all, never a silent override of a registry that exists."*
2. **Unregistered is refused before transport.** Exit 3, before anything is written.
3. **The recipient is never created.** *"The remote inbox must already exist and be a directory.
   This helper never creates it… refused (exit 4)."*

Rule 3 is the direct counter to the measured defect `ensure_dir` in
`bin/fm-outbound-order.sh`, which mkdirs `$root`, `$inbox`, `$receipts`, and `$accepted` and thereby
resurrects a retired recipient on first send.

**Therefore the smallest correct fix is: make `fm-outbound-order.sh` obey the same three rules
against the same registry.** Not a new lifecycle service.

## B3. Constraint on the fix — must not weaken the existing target pin

`tests/fm-outbound-order.test.sh:93-104`
(`test_target_cannot_be_redirected_by_environment`) asserts that
`FM_BRANDON_COMPUTE_TARGET=attacker-host` does **not** redirect delivery. `TARGET` is hardcoded at
`bin/fm-outbound-order.sh:397,405`, and that env var appears nowhere else in the repo.

Any registry work must preserve this: the registry governs *which recipients exist and are valid*,
not *whether the pinned destination can be moved by the environment*. That test must continue to
pass unchanged.

## B4. Blockers — decisions required, `[key=<slug>]` tagged

### [key=recipient-registry-bootstrap]

`data/hetz-routes.tsv` is **absent from both** the real home
(`/home/hd2admin/kun-agent-workspace/data/`) and this worktree's home. Measured.

So "make the registry authoritative" resolves to one of two behaviours today, and they are not
equivalent:

- **(a) Fall back to the literal when no registry exists** — this is `fm-hetz-send.sh`'s current
  behaviour, and it **leaves the finding open**. No registry, no protection.
- **(b) Refuse when no registry exists** — closes the finding, but refuses the only working order
  channel until an operator creates the registry by hand.

`AGENTS.md` §9 requires an explicit decision for anything that would disrupt live delivery. **No
code should be written until this is answered.** The recommendation is (a) plus a loud
`registry absent — recipient lifecycle unenforced` warning, which is strictly better than today and
does not break delivery; but the disruption risk of (b) is the captain's call, not this lane's.

### [key=recipient-registry-schema]

The two senders do not describe a recipient the same way, so the existing registry grammar cannot
simply be reused unchanged.

- `fm-hetz-send.sh` registry line: `<id> <host> [<inbox>]` — a **single inbox path**.
- `fm-outbound-order.sh` remote layout: `~/to-brandon-compute/{inbox,receipts,accepted}` — a
  **three-directory tree**, plus a per-host `order-id` namespace.

One `host` column cannot express the tree. Someone must choose between widening the grammar to
`<id> <host> <root>` and keeping the tree as a fixed per-host convention. Choose once, and apply it
to both senders, or the two registries will drift and the fleet will have two incompatible notions
of what a recipient is.

### [key=recipient-retirement-semantics]

`fm-hetz-send.sh`'s registry format (`<id> <host> [<inbox>]`) has **no state field**, so a retired
recipient is indistinguishable from a typo. Worse: under rule (a) above, *removing* a recipient from
the registry silently reverts it to the literal fallback — so "retire" would be indistinguishable
from "never registered", and the retired host would start receiving orders again.

Retirement needs an explicit representation — a `retired` marker that refuses rather than falls
back, or a tombstone line. This is the decision that most directly determines whether the fix
actually closes the finding, and it cannot be defaulted into place safely.

## B5. Severity recommendation

**Finding B is MEDIUM, not HIGH.** Full reasoning is in `threat-model.md`; the short form: the
redirection attack is already closed and regression-tested, what remains is a lifecycle defect whose
blast radius is a stale directory tree and unattended writes on one host, and there is no measured
path from it to a wrongful merge or a disclosed credential.

Recorded plainly because it cuts against the brief's premise: **the risk is medium, but the fix is
hard-blocked on the three decisions above.** Those are separate facts and the second should not be
used to justify carrying the first at HIGH. If "HIGH" was meant specifically as *"the fleet can
silently write into a host nobody is operating, with nothing on the receiving end able to refuse
it"*, then MEDIUM is the wrong call and that is a scoping decision for the captain.

---

# Part 3 — what this lane did not do

- **No code, script, or test was changed.** `git status` in the worktree is clean apart from the two
  new Markdown deliverables. No commit was made.
- **No commit, no `fm-session-start`, no fleet lock.** The lock is held by the parent, as briefed.
- **No customer-data claim.** Nothing here asserts or inspects exposure of customer data. The
  inbound corpus is operational Markdown between fleet participants. Any such claim needs an
  authorised owner and was out of this lane's authority.
- **No guard was weakened, and no check was removed to make anything pass.**
- **No inbound-trust gate was written against an unmeasured interface.** Every interface referenced
  above was read in full in this worktree before it was named in a design.