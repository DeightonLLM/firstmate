# Lane 4 — Security P0 threat model: inbound trust and sender recipient lifecycle

Lane: security · Worktree: `/tmp/wt-lane-security` · Branch measured: `lane/security`
Review-only. No commit. No code, script, or test was modified.

Every interface below was read in this worktree or measured on this host. Nothing is asserted
from the brief. Where the brief and the measurement disagree, the measurement wins and the
discrepancy is recorded.

---

## 0. Corrections to the brief's premises

Three stated premises did not survive measurement. They are recorded here because two of them
change the severity call.

| Brief says | Measured | Effect |
|---|---|---|
| "429 files arrived through the five inbound routes" | **499** files | none on threat model |
| branch `lane/security-p0` | branch **`lane/security`** (only lane branches present: `lane/blog-blog`, `lane/browser-browser`, `lane/domains-domains`, `lane/security`) | cosmetic; work committed nowhere |
| `fm-warehouse-guard.sh`, `fm-warehouse-submit.sh`, `fm-controller-pending.sh`, `fm-gate-escalation-order.sh` are the "existing" mitigation for inbound trust | all four are **outbound-only**; none reads inbound bytes | **material** — the inbound path had no guard at all |

### Measured route inventory

All five directories: mode `755`, owner `hd2admin:hd2admin`.

| Route | Files | Newest file |
|---|---|---|
| `/home/hd2admin/controller-replies` | 256 | 2026-10-16 |
| `/home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/to-brandon-compute` | 111 | 2026-10-16 |
| `/home/hd2admin/agent-work/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute` | **0 (empty)** | dir mtime 2026-10-15 |
| `/home/hd2admin/agent-work/firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute` | 97 | 2026-10-16 |
| `/home/hd2admin/brandon-inbox` | 35 files + 1 subdir | 2026-09-27 |

File modes across all routes: 435 files `0644`, 64 files `0600`. Extensions: 481 `.md`,
18 `.msg`. **Zero symlinks, zero nested directories** in four of the five routes.

**Load-bearing fact:** every route is `755` and single-owner `hd2admin`. There is no per-sender
identity, no group separation, no filesystem-level provenance. Any process running as `hd2admin`
can write a file into any route. The trust boundary is the OS account and nothing finer.

---

# Finding A — inbound trust (Gate 8a)

## A.1 What the inbound path actually is, measured

Every component in this repo that touches the five routes:

1. **`bin/fm-gate-escalation-order.sh:37-41`** — iterates all five routes. Per route:
   `ls -t "$d"/*.md | head -1` then `stat -c %Y`. **Metadata only. It never opens a file.** It
   reads mtime to compute "how long since Controller delivered anything".
2. **`bin/fm-outbound.sh:19`** — `EXCHANGE=/home/hd2admin/controller-replies`, and `:63-68`
   copies outbound files *into* it. This route is **bidirectional**: inbound and outbound mail
   share one directory.
3. **`bin/fm-to-controller.sh:46`** — greps the outbound hash ledger, not route content.
4. **`bin/fm-controller-pending.sh`** — hashes files in the **outbox**, not the routes.
5. **`bin/fm-comms-ingest.sh`** — the **only** component that lifts inbound bytes into a parent
   home's durable records.

And measured: `fm-comms-ingest.sh` is invoked by **nothing** in `bin/`. `grep -rn
'fm-comms-ingest' bin/ docs/` returns exactly one hit — a row in `docs/scripts.md:59`. It is a
manual one-shot command. No route is automatically wired into it.

### The untrusted-content lift, quoted from `bin/fm-comms-ingest.sh`

```sh
summary_of() {
  awk 'NF { gsub(/[[:cntrl:]]/, " "); print; exit }' "$1" 2>/dev/null | cut -c1-200
}
```

The first non-blank line of an inbound file, control characters replaced by spaces, truncated to
200 characters, is written into the parent's durable task record:

```sh
line="comms-received: $id $name sha=$short_sha bytes=$bytes$corr_part | $summary"
printf '%s\n' "$line" >>"$status_file"
fm_wake_append signal "$id.status" "comms received from $id: $name$corr_part"
```

Note the asymmetry: the **wake reason line is sanitised** (`$name` passed `valid_name`, `$corr_part`
matched a regex), but the **event line it points at carries the 200 raw characters**.

`AGENTS.md` §8 instructs the reading agent: *"For `signal:`, read the listed event lines first."*
So the untrusted bytes arrive precisely where the protocol tells the agent to look.

## A.2 The attack

**Not a remote attacker.** There is no network-facing inbound surface here. Two realistic adversaries:

**Attacker 1 — any process running as `hd2admin`.** All five routes are `755 hd2admin`. That
population includes every agent lane in the fleet, every `mcode exec` / `agy` subprocess, and any
prompt-injected worker. Dropping a file into a route costs one `write(2)`. There is no
authentication step between the `write` and the status record. Attribution is by *directory
convention plus an operator-supplied task id on the command line* — the file asserts its own
sender.

**Attacker 2 — a legitimate correspondent.** This is the more likely one and it has no technical
control at all. Crisp-R writes a real reply containing a paste of a log, a ticket, or a config
snippet. That pasted text is, byte for byte, instruction-shaped text delivered to an agent holding
merge authority and the fleet lock.

The payload for both is the same: **200 characters placed at the front of the durable record that
the supervision protocol tells the agent to read on every wake for that task.**

## A.3 Blast radius

- **Reached:** the parent home's `state/<id>.status`, read on every wake for that task, and
  therefore read by the agent that can merge PRs and hold the fleet lock.
- **Bounded by (measured, keep these):** 200 characters; control characters stripped, so no ANSI
  or terminal-escape attack; `-maxdepth 1 -type f`, so no symlink or nested-tree injection;
  content-keyed dedup, so byte-identical replay is a no-op; a missing or non-directory route is a
  hard error, never `ingested: 0`.
- **Not reached:** no code execution, no credential path, no automatic merge. A `needs-decision`
  finding still needs its own authority, and `fm-outbound-order.sh` delivery still verifies
  checksums end to end.
- **Requires an operator action** to fire: `fm-comms-ingest.sh scan <id> <route>...` naming one of
  the five routes as a report dir.

So: control-flow influence over a privileged agent, bounded and operator-gated. That is HIGH, and
not higher. It is not CRITICAL because there is no direct path from these 200 characters to a
privileged *action* — only to a privileged agent's *attention*.

## A.4 What is already correct here (must not be weakened)

| Control | Location |
|---|---|
| only regular files, maxdepth 1 | `find "$dir" -maxdepth 1 -type f` |
| reply-name charset, no `/`, no `.`/`..`, ≤255 | `valid_name()` |
| task id cannot escape `state/`, ≤64 chars | `valid_id()` |
| content-keyed dedup (replay is a no-op) | `receipts.tsv` |
| unreadable route is an error, never a healthy "0" | `cmd_scan` dir loop |
| `handled` requires substantive review evidence | `cmd_handled`, ≥5 words |

## A.5 What is absent

1. **No sender authentication.** The id is a CLI argument. Any `hd2admin` process fabricates
   "comms received from `<any id>`".
2. **No instruction/data separation.** Untrusted bytes are indistinguishable from a firstmate's own
   status prose once they are in the record.
3. **No size cap.** `corr_of()` greps the entire file before anything bounds it — a large inbound
   file is a cheap local DoS against the scan.
4. **Grammar mismatch.** Ingest accepts `corr=[A-Za-z0-9._-]{8,}`; the authoritative matcher
   `bin/fm-pending-reply-lib.sh:73` requires `FM_PENDING_REPLY_CORR_RE='corr=[A-Fa-f0-9]{16}'`.
   Untrusted content can put a bogus `corr=` into the status line that the real matcher will never
   accept.
5. **Zero test coverage** of `summary_of`. `grep -n 'summary_of\|cntrl' tests/fm-comms-ingest.test.sh`
   returns nothing.

## A.6 Smallest correct fix

Four changes, all inside `bin/fm-comms-ingest.sh`, none of them a new service.

1. **Envelope the untrusted bytes in the status line.** Give the 200 characters an explicit
   `untrusted-reply-text:` marker so the record itself states its own provenance. One line in
   `cmd_scan`. This is the fix that actually closes the finding: it makes "data, not instruction"
   a property of the record rather than a rule someone has to remember.
2. **Cap inbound size.** Refuse files over a bound as a reported `oversize:` condition — reported,
   never silently skipped, matching the existing `malformed:` discipline.
3. **Narrow `corr_of` to the authoritative grammar** `corr=[A-Fa-f0-9]{16}`. Pure narrowing; aligns
   with `fm-pending-reply-lib.sh:73`; introduces no new interface.
4. **Add the missing test** asserting that a reply whose first line is instruction-shaped yields an
   enveloped, bounded, single-line status record.

### One design to explicitly reject

**Do not build an authenticity filter on filename or prose.** `bin/fm-outbound.sh:5-9` already
records why: *"11 of 124 files in that directory carry a `# Brandon` heading, and the rest do
not, so a heading filter would either leak or silently drop real replies."* A sender-allowlist
keyed on naming or document shape is unmeasurable against this corpus and would drop real replies.
This is a measured reason, not a preference.

---

# Finding B — sender / recipient lifecycle

## B.1 What was already fixed by 6c9a7c94, and what remains

`git log -1 6c9a7c949186bbc1a4cf3fdede21657466773378` — *"fix sender recipient clobber and ledger
keys"*, Firstmate Coordinator, Fri Oct 16 03:51:55 2026 +0100. Measured in the current code: the
atomic `ln`-based publish, the no-overwrite-on-differing-bytes rule, and the receipt
`order_id`/checksum binding are all present in `bin/fm-outbound-order.sh`.

**Target redirection is already closed, deliberately.** `bin/fm-outbound-order.sh:397,405` hardcode
`TARGET=brandon-compute` in both `deliver` and `verify`, and
`tests/fm-outbound-order.test.sh:93-104` (`test_target_cannot_be_redirected_by_environment`)
asserts that exporting `FM_BRANDON_COMPUTE_TARGET=attacker-host` does **not** change the
destination. The environment variable is referenced nowhere else in the repo. This is a regression
test defending an intentional property, and **no fix in this document may weaken it.**

## B.2 The remaining gap, stated exactly

Two defects, both measured:

**B.2a — sending to a retired recipient resurrects it.** The remote `prepare` operation runs
`ensure_dir` on `$root`, `$inbox`, `$receipts`, and `$accepted`, and `ensure_dir` is:

```sh
[ -d "$path" ] || mkdir "$path" || fail 'could not create remote destination directory'
```

So the first order sent to a decommissioned host **recreates the entire recipient tree** and the
delivery reports `transferred`. The sender is the only thing keeping that recipient alive.

**B.2b — the recipient is an unpinned DNS name resolved at send time.** Measured on this host:
`~/.ssh/config` is 85 bytes and contains exactly one stanza, `Host 100.71.95.76`. There is **no
`Host brandon-compute` stanza**. `ssh -G brandon-compute` reports `hostname brandon-compute` —
i.e. it falls through to DNS. `grep -i brandon /etc/hosts` returns nothing. Nothing pins the
recipient's identity, and nothing checks it still exists before the write.

## B.3 Does a recipient lifecycle interface exist?

**No. This is a blocking gap, and it is not papered over here.**

Evidence:
- `grep -rn 'TARGET=' bin/` — the only sender target assignments are the two hardcoded literals.
- `grep -rn 'FM_BRANDON_COMPUTE_TARGET' .` — two hits, both inside the test that proves it is ignored.
- `grep -rln 'recipient\|allowlist\|retire\|known_host\|host_key' bin/` — every hit is
  **secondmate home** retirement (`fm-teardown.sh`, `fm-home-seed.sh`) or **process-event source**
  retirement (`fm-procevent.sh`). None governs a transport recipient.
- No registry file: `data/hetz-routes.tsv` is absent on the real home
  (`/home/hd2admin/kun-agent-workspace`) **and** on this worktree's home.

There is no `register`, no `list`, no `retire`, no `status`, and no way to express "this recipient
is dead" anywhere in the system.

## B.4 Blast radius

- **Reached:** the remote compute host's `~/to-brandon-compute/` tree, and any order content the
  sender was handed.
- **Honest bound:** the transfer/acceptance protocol is truthful — `transferred` is reported as
  transferred, `accepted` requires a matching worker ack, and the local receipt refuses order-id
  reuse with a different checksum. Nothing here forges an acceptance.
- **Not reached:** no wrongful merge, no credential disclosure, no silent data loss.
- **Real risk:** work written to a host nobody is operating, plus a stale directory tree that keeps
  the recipient looking alive to every future probe.

## B.5 Smallest correct fix — do not invent the interface

The decisive measurement: **the sibling sender already implements the exact contract this finding
needs.** `bin/fm-hetz-send.sh`, header lines 22-32 and body lines 110-190, states and enforces:

> "When a route registry exists it is the only authority for which host and which inbox a route id
> resolves to; the built-in literals are a fallback for a home that keeps no registry at all, never
> a silent override of a registry that exists."

> "An id that is not registered, and a registry that cannot be read, are both refused BEFORE any
> transport is attempted (exit 3)."

> "The remote inbox must already exist and be a directory. **This helper never creates it**: a
> destination this command invents is not a destination any consumer watches. A reachable route
> whose inbox is missing is named as missing and refused (exit 4)."

Those three rules — registry-authoritative, unregistered-is-refused, never-create-the-recipient —
are precisely what B.2a and B.2b are missing. The fix is to make `fm-outbound-order.sh` obey the
same three rules against the same registry, not to design a new lifecycle service.

**No code change is proposed in this lane**, because the fix is blocked on an operational decision
with a live delivery channel behind it. See `recommendation.md` for the three `[key=…]` blockers.

---

# Severity re-assessment

## Finding A: **HIGH is correct. Do not downgrade.**

It stays HIGH because the destination is an agent holding merge authority and the fleet lock, and
because there is no sender authentication whatsoever — the `755 hd2admin` routes mean fabrication
is a single `write(2)`. It is **not** CRITICAL: the untrusted bytes are bounded to 200 characters,
control-stripped, replay-idempotent, and reach the durable record only when an operator runs a
manual scan naming an inbound route as a source. There is no measured path from those 200
characters to a privileged action.

## Finding B: **this is MEDIUM, not HIGH.** Reasoning, offered against the original call.

The HIGH label appears to rest on "the sender can write to a recipient that no longer exists." Once
the two halves are measured separately, that sentence collapses:

1. **The redirection attack is already closed and regression-tested.**
   `test_target_cannot_be_redirected_by_environment` asserts the target cannot be moved, and the
   target is a hardcoded literal with no env override anywhere in the repo. This was not open.
2. **What remains is a lifecycle defect, not a trust bypass.** `ensure_dir` recreating a retired
   recipient is a correctness bug with a contained blast radius — a stale tree on one host, plus
   orders that land where no operator is watching. The delivery protocol still reports the truth
   about transfer versus acceptance.
3. **There is no path to a wrongful merge or a disclosed credential.** Order content reaching an
   unattended host is a real operational risk, but it is not the kind of HIGH that Finding A is,
   where untrusted bytes reach a privileged agent's attention.

I recommend **MEDIUM**, with the registry-bootstrap decision recorded as a blocker. Note the
distinction: the *risk* is medium; the *fix* is hard-blocked on a decision. Those are separate and
should not be conflated to justify leaving it HIGH.

If the captain's intent for "HIGH" was specifically *"the fleet can silently write work into a host
nobody is operating, with nothing on the receiving end able to refuse it"* — that is a defensible
reading and MEDIUM would be wrong. That is a scoping decision, not a technical one.