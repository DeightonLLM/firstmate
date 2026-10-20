# Domain identity

This file owns the contract for one question: does every agent in this fleet know which domain it is in, and is its startup context actually in sync with the primary.

## The problem this solves

Pi loads its context files from the agent directory, the working directory, and every parent directory of the working directory.
A context file applies whenever Pi runs in that directory or anywhere below it.
A secondmate home that sits under `/home/hd2admin/` therefore also receives `/home/hd2admin/AGENTS.md`, whatever that file happens to say.
On this host that parent file is a lean-ctx tool-tuning note, so every agent in every domain currently inherits a tool note where a domain identity should be.
A domain identity file is the per-home file that says, in one place, which home this is, which domain it owns, and where the fleet's real authorities live.
It is deliberately not a second copy of the operating contract.
The primary's `AGENTS.md` and `data/secondmates.md` stay authoritative, and the domain identity file only points at them.

## The upstream rule, verified

The candidate order is fixed and is taken from the upstream loader, not from house memory.
In `/home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/resource-loader.js` line 116 the loader declares:

```js
const candidates = ["AGENTS.override.md", "AGENTS.md", "AGENTS.MD", "CLAUDE.md", "CLAUDE.MD"];
```

The loader takes the first match per directory, so exactly one file wins in each directory.
The directory walk is in the same file at lines 165 to 195: the agent directory is read at line 170, the working directory at line 179, and the parent walk runs at lines 189 to 192.
The prose contract is in `/home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/docs/configuration.md` line 43 for the discovery rule, line 45 for the override rule, and line 18 for the candidate list.
The override rule at line 45 is the important one: an `AGENTS.override.md` replaces `AGENTS.md` or `CLAUDE.md` only in the same directory, and it does not suppress context files from the agent directory or from other directories.
That is why a per-home override file is the only place a domain identity can live, and why the parent directory note still reaches every home.

## The tool

`bin/fm-domain-identity.sh` reports the domain identity and the tracked-file sync state of every registered home, and can write the identity file on explicit opt-in.

```
bin/fm-domain-identity.sh [--help] [--apply] [--force] [--home <id>]
```

The tool is read-only by default.
It never mutates a project, never mutates a secondmate home without `--apply`, and never forces anything.
Registered homes come from `state/<id>.meta` records with `kind=secondmate`, with `data/secondmates.md` as the `home=` fallback, which is the same discovery `bin/fm-config-push.sh` uses.
Per home it prints the context file Pi would actually load from that home's own directory, whether that home owns a domain identity file, which ancestor context file it inherits when it does not, the `CLAUDE.md` shape, the HEAD sha, whether HEAD is an ancestor of the primary's `main`, the ahead and behind counts, the dirty state, and the `AGENTS.md` fingerprint.
It then prints a slot census of the `AGENTS.md` fingerprint of every firstmate-home-shaped slot in the pools named after the primary repository, so a stale home that is no longer registered stays visible.
The last line of the report is one fleet verdict, and every failure is printed with its own reason.

Exit codes:

| Code | Meaning |
|---|---|
| 0 | every registered home is domain-scoped and in sync |
| 1 | at least one registered home fails, with the reason printed |
| 2 | usage error |

An empty fleet exits 0 and says that it found nothing to attest, because it cannot attest a fleet it never saw.

`--apply` writes a domain-specific `AGENTS.override.md` into a registered home.
The content states the home's identity, its domain scope, the pointer to the full scope text in the primary's `data/secondmates.md`, its charter path, that it is not the primary, and that the primary's `AGENTS.md` and `data/secondmates.md` are authoritative for the fleet.
There is no timestamp in the file, so a re-run is byte identical.
An existing file is never overwritten without `--force`, and the diff it would make is printed first.
A home that is diverged or dirty is refused by default, and its sync and dirty state are printed with the refusal.
The write also adds `/AGENTS.override.md` to the home's local git exclude file, because the existing fast-forward contract reads `git status --porcelain` and would otherwise treat the home as dirty forever.
On a linked worktree that exclude file is the shared repository exclude file, so the pattern applies to every worktree of that repository, and it only affects untracked files.

Every git invocation in the tool goes through one wrapper that allows only read-only subcommands, and a startup self-check refuses to run when the file holds any other git invocation.
The tool never runs `fetch`, `pull`, `checkout`, `merge`, `reset`, `stash`, `clean`, or `gc` in any home.
The behavior suite is `bin/fm-domain-identity.test.sh`, and it builds its fixture homes under a temp dir only.

## The fleet's measured state on 2026-10-20

The numbers below are a snapshot taken on 2026-10-20 by `bin/fm-domain-identity.sh` against the live fleet, not a stored truth.
The primary is `/home/hd2admin/kun-agent-workspace`, whose `main` is `395f2ab03bc2e1e0797701e6e5e77ceafffc926a`.

| Home | Slot | `AGENTS.md` sha256 | HEAD | Against primary `main` | Dirty | `CLAUDE.md` | Domain identity |
|---|---|---|---|---|---|---|---|
| system-ops | 8bf1b0/4 | `3de511a3f350` | `fdd36879df8` detached | 423 commits only on the home, 121 only on main | yes, 3 paths | import stub | absent |
| mcode-runner | 46aafc/27 | `ba3cfda72302` | `661de0bc2` on `fix/pi-reload-rearm-watcher` | 1 commit only on the home, 0 only on main | no | symlink to `AGENTS.md` | absent |
| boardkeeper | 46aafc/25 | `ba3cfda72302` | `602681f36` on `feat/lane-closure-gate` | 6 commits only on the home, 0 only on main | no | symlink to `AGENTS.md` | absent, and outside the registered set |
| primary | home | `da0381f5b3fe` worktree, `ba3cfda72302` committed main | `395f2ab0` on `main` | the sync base | yes, 54 paths | symlink to `AGENTS.md` | not applicable |

The `AGENTS.md` fingerprint census over the pools named after this repository:

| Fingerprint | Slots |
|---|---|
| `3de511a3f350` | 8bf1b0 slots 1, 2, 3, 4, 8, 9, 10, 11, 12 |
| `3cd27cc6fc1a` | 8bf1b0 slot 5 |
| `79e7cc740859` | 8bf1b0 slots 6, 7 |
| `ba3cfda72302` | 46aafc slots 25, 27 and its two extra worktrees, 32 |
| `de297bf40aad` | 46aafc slots 15, 16, 18, 19, 21 |
| `d1e50ed558db` | 46aafc slots 17, 20, 22, 30 |
| `67bcd3c8681c` | 46aafc slots 23, 24, 26, 28 |
| `de2c539f49fd` | 46aafc slots 1, 4 |
| `da0381f5b3fe` | 46aafc slot 2, and the primary worktree |

Three distinct old versions of `AGENTS.md` live in the 8bf1b0 pool while the primary has moved on, so the answer to "are all the agents synced" is no.
No `AGENTS.override.md` exists anywhere on this host.
`/home/hd2admin/AGENTS.md` is a lean-ctx tool note of 2637 bytes as measured on 2026-10-20, and because Pi loads parent directories it reaches every home under `/home/hd2admin/`.
That file lives outside the fleet's control and it changed size during the session that wrote this document, so re-run the tool rather than trusting this number.
The agent directory layer is empty: `~/.pi/agent/` holds no `AGENTS.md`, `AGENTS.override.md`, `CLAUDE.md`, `SYSTEM.md`, or `APPEND_SYSTEM.md`, and `PI_CODING_AGENT_DIR` is unset.

The number of commits ahead and behind is read as `git rev-list --left-right --count HEAD...main`, where ahead is the commits on the home's HEAD that primary `main` lacks and behind is the commits on primary `main` that the home's HEAD lacks.

## The lineage problem

The sync contract is owned by `.agents/skills/secondmate-provisioning/SKILL.md` line 78 and the lines that follow it.
Tracked files reach a secondmate home through a local fast-forward that runs at launch and in the locked bootstrap sweep.
That fast-forward is deliberately weak: `bin/fm-ff-lib.sh` line 324 skips a dirty home, and `bin/fm-ff-lib.sh` line 342 skips a home that has diverged from the base.
The system-ops home is on the upstream `kunchenguid` lineage at a detached HEAD that is not an ancestor of the primary's `main`, and it is dirty with three paths, so the existing contract can never advance it and it stays on its old `AGENTS.md` forever.
The mcode-runner home and the boardkeeper home are on feature branches that are not ancestors of the primary's `main`, so they are skipped for the same reason.

The honest fix here is a lineage and ownership decision, not a force.
**Measure which side is behind before choosing a direction.** Measured against upstream `kunchenguid/firstmate` on 2026-10-20, our primary `main` is 657 commits behind upstream while the system-ops home is only 234 behind upstream and 423 ahead of us, so the home is the side closer to upstream and our primary is the stale fork.
The two sides also carry different contracts: upstream and the secondmate homes open with "This is the supervisor contract for primary firstmates and persistent secondmates" and carry the secondmate parent-channel rule, while our primary opens "You are the first mate" and carries local directives upstream does not have.
Copying the primary's file over a secondmate home would delete the supervisor contract, and copying upstream over the primary would delete the local directives, so a blind sync in either direction is a contract loss rather than a fix.
The choices are therefore to reconcile the two contract lineages deliberately and carry the missing sections across by hand, to declare our fork authoritative and re-seed the secondmate homes from it while re-adding the secondmate-specific contract sections, or to accept a home as permanently off-line and stop counting it as a live agent.
Whichever the Captain picks, it belongs to the captain and the primary, and this tool only reports the state and builds the identity mechanism.
Forcing a fast-forward, stashing the dirty paths, or discarding them would destroy the exact evidence the decision needs, so the tool does not offer it.

## What this tool does not do

It does not merge, rebase, fast-forward, reset, stash, clean, or fetch in any home.
It does not write a domain identity file into a project under `projects/`.
It does not write to a home that is diverged or dirty without `--force`.
It does not decide the lineage question.
It does not change the primary's `AGENTS.md`, and it does not change `data/secondmates.md`.
