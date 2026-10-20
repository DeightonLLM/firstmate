# Upstream drift

This file owns the repeatable check that our local `docs/` tree still matches the upstream firstmate `docs/` tree.

## What upstream is

The upstream is the public firstmate repository at <https://github.com/kunchenguid/firstmate>.
This repo is a FORK of it.
The configured remotes are `origin` and `deighton`, and both point at `https://github.com/DeightonLLM/firstmate.git`, plus a local bare `no-mistakes` remote used by the delivery pipeline.
There is NO remote for `kunchenguid/firstmate` in this repo, so upstream is not fetchable locally today.
That is why the detector reads the public GitHub API by default instead of a git remote.

Our local `docs/` tree is a MANUAL PORT of upstream `docs/`.
The port is manual today, so it goes stale by default: nothing in the pipeline notices when upstream moves on.
This file and `bin/fm-upstream-drift.sh` make that staleness visible and repeatable.

`BOARD.md` points agents at the live upstream install paths for the OTHER tools, which are local installs rather than GitHub checkouts:
the Pi harness docs under `/home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/docs/`, pi-subagents under `/home/hd2admin/.pi/agent/npm/node_modules/pi-subagents/skills/pi-subagents/`, and the Herdr binary at `/home/hd2admin/.local/bin/herdr`.
Firstmate's own contract lives in THIS repo, not upstream.

## Measured drift (2026-10-20)

Measured with `bin/fm-upstream-drift.sh` against upstream `main`, with our local tree at commit `395f2ab0`, before this file existed.
Upstream `docs/` holds 70 files and our local `docs/` held 146 files.
Only 4 files are byte-identical, 34 are divergent, and 32 upstream files are missing locally.

```
SUMMARY: total=178 identical=4 divergent=34 missing=32 local_only=108 upstream_files=70 local_files=146
VERDICT: DRIFT
```

This file is itself a local-only house addition, so a fresh run against the tree that contains it reports `local_files=147` and `local_only=109`, and the identical, divergent, and missing counts stay exactly the same.

### Divergent files (local bytes, upstream bytes)

Every one of these is behind upstream, and upstream is the larger file in all but one case.

| File | Local | Upstream | Kind |
| --- | --- | --- | --- |
| `architecture.md` | 47014 | 109352 | upstream-newer |
| `arm-pretool-check.md` | 18081 | 19544 | upstream-newer |
| `calm-mode-feasibility.md` | 41037 | 95077 | upstream-newer |
| `calm.md` | 4164 | 20645 | upstream-newer |
| `cd-guard.md` | 15442 | 16277 | upstream-newer |
| `cmux-backend.md` | 8210 | 8767 | upstream-newer |
| `configuration.md` | 84075 | 256722 | upstream-newer |
| `documentation-audiences.json` | 8791 | 15876 | upstream-newer |
| `examples/crew-dispatch.json` | 1232 | 1254 | upstream-newer |
| `fm-test-isolation-proof.json` | 2582 | 2602 | upstream-newer |
| `fm-test-isolation-proof.md` | 3483 | 18477 | upstream-newer |
| `fm-test-portable-shards.md` | 3365 | 14412 | upstream-newer |
| `gitlab-merge-watch.md` | 8313 | 13670 | upstream-newer |
| `herdr-backend.md` | 31582 | 60571 | upstream-newer |
| `orca-backend.md` | 4032 | 5843 | upstream-newer |
| `scripts.md` | 14165 | 24177 | upstream-newer |
| `sessionstart-nudge.md` | 4817 | 23527 | upstream-newer |
| `subagent-guard.md` | 24733 | 26594 | upstream-newer |
| `supervision-protocols/claude.md` | 3009 | 3479 | upstream-newer |
| `supervision-protocols/codex.md` | 1359 | 1603 | upstream-newer |
| `supervision-protocols/grok.md` | 2786 | 3100 | upstream-newer |
| `supervision-protocols/opencode.md` | 1753 | 1998 | upstream-newer |
| `supervision-protocols/pi.md` | 3734 | 7527 | upstream-newer |
| `supervision-protocols/unknown.md` | 846 | 1070 | upstream-newer |
| `tmux-backend.md` | 5512 | 10101 | upstream-newer |
| `turnend-guard.md` | 9717 | 45216 | upstream-newer |
| `verification/dispatch-auth.md` | 9604 | 12363 | upstream-newer |
| `verification/process-event-sources.md` | 14247 | 41886 | upstream-newer |
| `verification/public-followup.md` | 5439 | 17478 | upstream-newer |
| `verification/runtime-backends.md` | 27175 | 208385 | upstream-newer |
| `verification/stow-memory.md` | 14354 | 2591 | upstream-smaller |
| `verification/supervision.md` | 13026 | 66333 | upstream-newer |
| `watcher-continuity.md` | 7045 | 36078 | upstream-newer |
| `zellij-backend.md` | 6339 | 7279 | upstream-newer |

`verification/stow-memory.md` is the one exception: our local copy is the larger one, so a blind port would shrink it.

### Files upstream has and we do not

- `agent-control.md` (24925 bytes upstream)
- `captain-hold-lifecycle.md` (42547 bytes upstream)
- `examples/process-event-extension/file-signal.mjs` (3314 bytes upstream)
- `examples/process-event-extension/firstmate-extension.json` (363 bytes upstream)
- `examples/watched-tools.json` (796 bytes upstream)
- `extension-bindings.md` (21214 bytes upstream)
- `external-review-forge.md` (5247 bytes upstream)
- `fleet-ledger.md` (7070 bytes upstream)
- `forgejo-tea-integration.md` (11705 bytes upstream)
- `gerrit-change-watch.md` (8802 bytes upstream)
- `gerrit-forge-integration.md` (34929 bytes upstream)
- `jev-guards.md` (3343 bytes upstream)
- `pi-supervision-branch-poster.svg` (10214 bytes upstream)
- `pi-supervision-branch.md` (49418 bytes upstream)
- `remote-secondmates.md` (42152 bytes upstream)
- `secondmate-parent-channel.md` (8647 bytes upstream)
- `supervision-host.md` (34278 bytes upstream)
- `supervision-protocols/cursor.md` (3758 bytes upstream)
- `supervision-protocols/omp.md` (4674 bytes upstream)
- `supervision-protocols/supervision-host.md` (7014 bytes upstream)
- `trace-context.md` (13382 bytes upstream)
- `verification/agy.md` (14075 bytes upstream)
- `verification/commandcode.md` (8709 bytes upstream)
- `verification/devin.md` (8890 bytes upstream)
- `verification/dispatch-resolve.md` (12238 bytes upstream)
- `verification/lint-option-a.md` (2892 bytes upstream)
- `verification/muse.md` (13200 bytes upstream)
- `verification/polytoken.md` (6274 bytes upstream)
- `verification/rovo.md` (25820 bytes upstream)
- `verification/secondmate-parent-channel.md` (6367 bytes upstream)
- `verification/trace-context.md` (6262 bytes upstream)
- `voice-relay.md` (19938 bytes upstream)

The 108 local-only files are house additions.
They carry contracts that upstream does not have, so they are reported but never counted as drift.

## How to run the detector

The detector is read-only.
It never writes into `docs/`, never stages or commits anything, and never adds or changes a remote.
A self-guard inside the script refuses to run at all if a mutating version-control subcommand is ever introduced into it.

Against the live upstream, with no remote configured:

```sh
bin/fm-upstream-drift.sh
```

Against an already fetched upstream tree, fully offline:

```sh
bin/fm-upstream-drift.sh --upstream-dir /path/to/upstream/firstmate
```

Against a fixture or a different local tree:

```sh
bin/fm-upstream-drift.sh --local-dir /path/to/local/docs --upstream-dir /path/to/upstream/docs
```

Useful flags:

- `--upstream-dir <path>` compares against a local upstream tree instead of the API.
  The path may be the upstream `docs/` tree itself or a checkout root that contains a `docs/` directory.
- `--local-dir <path>` points at the local docs tree.
  It defaults to the `docs/` directory of the repo the script lives in.
- `--upstream-repo <owner/name>` changes the upstream repository.
  It defaults to `kunchenguid/firstmate`.
- `--upstream-ref <ref>` pins the upstream revision.
  It defaults to the upstream default branch.
- `--max-fetch <n>` caps how many upstream file bodies are read for the difference detail.
  It defaults to 200 and the report says so when the cap is reached.
- `--tracked-only` compares only the files the enclosing work tree tracks, which makes the report repeatable even when scratch files sit in `docs/`.
- `--quiet-summary` prints only the header, the counts, and the verdict.

The detector prefers an authenticated GitHub client when one is available and falls back to the plain public API.
Set `FM_UPSTREAM_DRIFT_NO_GH=1` to force the unauthenticated path.

The colocated test suite runs entirely offline against fixtures:

```sh
bin/fm-upstream-drift.test.sh
```

## Output contract

The report has a fixed shape.
The header names the upstream, the mode, the local directory, and the upstream source.

```
UPSTREAM-DRIFT: repo=kunchenguid/firstmate ref=main mode=github-api
LOCAL-DIR: /path/to/docs
UPSTREAM-SOURCE: github tree api for kunchenguid/firstmate@main (70 files)
```

Then four per-file sections, one per outcome.

- `IDENTICAL (n):` the file exists on both sides with the same git blob digest.
- `DIVERGENT (n):` the file exists on both sides with different content.
  Each line carries the local bytes, the upstream bytes, the difference kind, and the content detail.
  The kind is `upstream-newer` when upstream has more bytes, `upstream-smaller` when it has fewer, and `content-divergent` when the byte counts match but the content does not.
- `MISSING-LOCALLY (n):` upstream has the file and we do not.
- `LOCAL-ONLY (n):` we have the file and upstream does not.

Then the machine-readable tail.

```
CONTENT-FETCH: used=34 cap=200 capped_files=0
SUMMARY: total=178 identical=4 divergent=34 missing=32 local_only=108 upstream_files=70 local_files=146
DRIFT-BASIS: divergent+missing; local-only files are house additions and are not counted as drift
VERDICT: DRIFT
```

`total` is the number of distinct paths considered across both trees, so it equals `identical + divergent + missing + local_only`.
A value the detector cannot determine is printed as `unknown`, never as a fabricated number.

### Exit codes

| Code | Meaning |
| --- | --- |
| 0 | No drift. |
| 1 | Drift detected. |
| 2 | Usage error, or the comparison could not be performed. |

A comparison that could not be performed exits 2 and prints `VERDICT: UNKNOWN`, because reporting no drift without having compared anything would be a fabricated answer.

## Recommended port procedure

Porting one upstream doc is a normal tracked change in this repo.
It goes through the normal review and landing path: a branch, a commit, and the usual merge approval.
It is not a special side channel and it never bypasses the delivery pipeline.

### 1. Pick one doc and record the baseline

Run the detector first and save the report, so the change is measured before and after.

```sh
bin/fm-upstream-drift.sh > /tmp/drift-before.txt
```

### 2. Read the upstream copy without touching our local copy

Fetch the upstream file into a scratch path, never over ours.

```sh
mkdir -p /tmp/upstream-port
curl -fsSL -o /tmp/upstream-port/<name>.md \
  https://raw.githubusercontent.com/kunchenguid/firstmate/main/docs/<name>.md
```

### 3. Diff the upstream copy against our local copy

```sh
diff -u docs/<name>.md /tmp/upstream-port/<name>.md
```

Read the whole diff, not only the first hunk.
Upstream files are frequently two or three times the size of ours, so the diff is where the real content lives.

### 4. Review what the diff actually changes

Check every one of these before you take anything:

- Does the upstream text describe a contract that OUR fork must honour, or one that upstream alone owns?
- Does our local copy carry house-specific contracts that upstream does not have, such as our own lane naming, our own routing, our own captain-facing workflow, or our own verification evidence?
- Does the upstream text reference files, scripts, or skills that we do not have?
- Does it rename or move anything that other tracked files point at?
- Is the file a shared owner of a contract that another file in this repo also claims?

### 5. Port deliberately, not by overwrite

A blind overwrite of our local `docs/` is dangerous, and the numbers above show why.
Our local docs carry house-specific contracts that upstream does not have, so an overwrite would silently delete them.
Our local tree also holds 108 files upstream has never heard of, and overwriting the tree would drop all of them.
`verification/stow-memory.md` shows the reverse case: our local copy is larger than upstream's, so a blind port would shrink a file we deliberately extended.
Port one doc at a time, merge the upstream content into our local content, and keep every house-specific clause.

### 6. Re-measure and land

```sh
bin/fm-upstream-drift.sh > /tmp/drift-after.txt
diff -u /tmp/drift-before.txt /tmp/drift-after.txt
bin/fm-upstream-drift.test.sh
bin/fm-lint.sh
```

Then commit the port on a branch with a plain message and land it through the normal review path.

## Landing note for this file

`bin/fm-doc-audience-check.sh` requires every tracked Markdown file to be classified in `docs/documentation-audiences.json`.
This file needs an entry there, with an audience that the inventory allows, and the detector lane does not own that inventory.
That check already fails on this repo before this file lands, because 1174 tracked prose files are unclassified at the time of writing, so adding this file moves the count from 1174 to 1175 rather than turning a passing gate red.

## References

- Upstream repository: <https://github.com/kunchenguid/firstmate>
- Detector: `bin/fm-upstream-drift.sh`
- Detector tests: `bin/fm-upstream-drift.test.sh`
- House navigation for the other upstream tools: `BOARD.md`
