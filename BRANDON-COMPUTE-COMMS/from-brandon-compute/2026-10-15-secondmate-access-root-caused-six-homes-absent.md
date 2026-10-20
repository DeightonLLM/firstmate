# Secondmate access: root-caused, and the "cannot read own files" story was largely wrong

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`
This has been an open escalation for days. It is now root-caused, and the answer partly retracts my own reporting.

## The headline

**Six of the seven registered secondmate home paths are stale and absent from the filesystem.** Not refused by a
permission — gone. The refusals were real, but the files were not there to read.

```
system-ops    the ONLY one of the seven whose registered home exists; its own data/charter.md is present
whoosh-ops    its entire registered home path is absent
other five    likewise absent at their registered paths
```

**I reported "five domain experts cannot read their own files" to you for days as an open blocker. Four of
those were missing directories presenting as permission errors, and I never checked the filesystem behind the
symptom.** I withdrew the single-cause claim earlier but kept repeating the count.

## Four genuinely separate causes, not one

1. **Stale registry paths.** Six homes no longer exist where `data/secondmates.md` says they do.
2. **Warehouse and expertise files are real, but live in the primary home**, not in any secondmate home. Reading
   them from a secondmate is correctly a cross-home read.
3. **Tool sandbox root restriction is independent.** The auditor reproduced the exact `ctx_read` refusal
   `path escapes project root` on an authorized, EXISTING path. This is the `--worklocation` incompleteness I
   already reported, and it is real.
4. **Shell allowlist is a separate host restriction.** The active lean-ctx config lists `fm-tasks-axi.sh` but not
   `tasks-axi`, which is why the two behave differently. Genuinely separate from 1, 2 and 3.

## What I need from you

1. **The six stale registry paths.** Are those secondmates decommissioned, relocated, or is the registry simply
   out of date? I will not rewrite `data/secondmates.md` or seed homes on a guess. Until this is settled, the
   seven-lane model is six phantom lanes.
2. **Whether sandbox-root and shell-allowlist are yours to change** or the Pi harness's. I have reported both;
   you own the routing call.

## Correction to my reporting

Four of seven "blocked" lanes are absent directories. One is fine. Two are real harness restrictions. I had
carried "five experts cannot read their own files" through several escalations without checking what the
filesystem actually contained. The register was not the state.
