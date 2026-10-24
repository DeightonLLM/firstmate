# Surface naming contract

This document owns the RULE for every name a human sees when they look at the
agent surface. It does not own the current label strings: those are produced by
`bin/fm-surface-name-lib.sh`, which every writer and every checker uses, so a
name and the rule about names cannot drift apart.

The problem this contract exists to solve: on 2026-10-24 the Herdr spaces
sidebar read `firstmate`, `firstmate-afk-daemon-659043-363-1792753227`,
`2ndmate-mcode-runner` and `PROTECTED HETZ PRIMARY - saved session recovery`.
None of those said which surface was running the work, which lane it was, or
whether it was still alive. The Captain asked for the naming to be "SET AND
ENFORCED TO ALL AGENTS". This is the setting; `bin/fm-surface-name-check.sh` is
the enforcement.

## The rule

```
scope            := host "/" home [ "/" role ]
host             := "hetz" | "controller" | "hd2" | "local"
home             := "primary" | "2ndmate-" <secondmate-id>
role             := a lowercase role token, e.g. "afk", "older"

workspace label  := scope " · " summary | scope
summary          := <lane-id>              the container hosts exactly one lane
                 | "<N> lanes"             the container hosts N task tabs
                 | "no lanes"              the container hosts no task tab
                 | "afk-daemon <nonce>"    an away-mode daemon container

projection label := "└ " scope " · " <lane-id> " · p:" <token>

task tab label   := "fm-" <lane-id>
```

The separator is `SPACE U+00B7 MIDDLE DOT SPACE`. The projection marker is
`U+2514 BOX DRAWINGS LIGHT UP AND RIGHT` plus one space.

A fresh workspace may temporarily use the scope-only form while it has no task
lanes. The Herdr adapter adds the summary when the first task lane is created;
once a workspace has a lane, its label always includes the summary.

A **scope** is the machine-matchable half of a workspace label: everything
before the first separator. The Herdr adapter resolves a home's container by
SCOPE, never by the whole label, so a container may say how many lanes it
holds without changing which home owns it.

A **task tab label** is deliberately NOT decorated with the scope. The tab
label is the lane identity, and it is the string recovery, orphan discovery
and teardown match on. The scope lives on the workspace that contains the tab;
the two together are the agent's full name.

### Examples

| container | label |
|---|---|
| the primary home's live container | `hetz/primary · 8 lanes` |
| a primary container hosting one lane | `hetz/primary · mcode-m3.1f-brandon-core-distro-saas` |
| an earlier container of the primary home | `hetz/primary/older · 24 lanes` |
| an away-mode daemon container | `hetz/primary/afk · afk-daemon f962fcac` |
| a secondmate home's container | `hetz/2ndmate-mcode-runner · mcode-runner` |
| a secondmate home's container, several lanes | `hetz/2ndmate-system-ops · 2 lanes` |
| a disposable one-lane presentation space | `└ hetz/primary · m3.1f-firstmate-suite-reds · p:Z3tbQ-EYCLEjuCKEhVO3Zw` |

### Where the host token comes from

`SURFACE-IDENTITY.md` is the single authority for which machine an alias or
hostname names. `fm_surface_name_host` maps the hostname onto that authority:
`brandon-compute*` is `hetz`, `vmi3196300*` is `controller`, `vmi3238503*` is
`hd2`, and anything else is `local`. An unrecognised host is never guessed
into one of the named surfaces. `FM_SURFACE_HOST` overrides the mapping
explicitly for a home that runs somewhere the table does not know.

### Where the home segment comes from

A home that carries the `.fm-secondmate-home` marker is `2ndmate-<id>`; every
other home is `primary`. The marker is what `bin/fm-home-seed.sh` writes, so
the home segment is derived from the home's own durable identity, never from
a name passed down a call chain.

### The role segment

A home may own more than one container. The role names which one:

- (no role) - the home's canonical container, the one a spawn lands in.
- `afk` - the away-mode daemon container.
- `older` - an earlier container of the same home, kept for reference.

## What is enforced

`bin/fm-surface-name-check.sh` reads the live Herdr surface and fails when:

1. a workspace label is not a scope with an optional summary;
2. a projection label does not match the projection grammar;
3. a tab that a lane record names does not carry that lane's `fm-<lane-id>`
   label;
4. a lane of this home sits inside another home's container.

A legacy label (`firstmate`, `2ndmate-<id>`,
`firstmate-afk-daemon-<pid>-<n>-<ts>`) is reported as a violation WITH the
label it should read, because a transitional name is not a conforming name.
The matcher still accepts the legacy form so a fleet that has not been renamed
yet keeps resolving to the same container.

```
bin/fm-surface-name-check.sh                 # check the live surface
bin/fm-surface-name-check.sh --apply         # rename the offending workspaces
bin/fm-surface-name-check.sh --from-file snapshot.tsv   # check a snapshot
```

`--apply` RENAMES workspaces. It never closes a workspace, never closes a
pane, never kills a process, and never touches a state file.

When a workspace's own label does not carry a scope, an operator can say which
scope it belongs to with a scope map: one `<workspace-id> TAB <scope>` line
per workspace, passed with `--scope-map <file>` or left in the home's own
`config/surface-name-scopes`.

## What is NOT renamed, and why

Task tab labels stay `fm-<lane-id>`. Recovery, orphan discovery and teardown
match on that exact string; a decorated tab label would make a live agent
invisible to the tooling that decides whether it is still alive. The scope on
the workspace carries the surface, so the pair still names the agent
completely.

## Seeing the surface

`bin/fm-surface-view.sh` prints, for every recorded lane of this home: the
surface, the workspace, the lane, the tab, the pane, the harness, the model and
the current state, sorted by surface.

```
bin/fm-surface-view.sh
bin/fm-surface-view.sh --json
```

The state column is `LIVE`, `IDLE`, `BLOCKED`, `DONE`, `FAILED`, `GONE` or
`UNKNOWN`. `GONE` means the lane's recorded pane no longer exists: a
finished-but-unclosed agent, which is exactly the case the Captain could not
see before.

## Owners

- the rule: this document
- the exact bytes: `bin/fm-surface-name-lib.sh`
- the live census both tools read: `bin/fm-surface-census-lib.sh`
- the view: `bin/fm-surface-view.sh`
- the enforcement: `bin/fm-surface-name-check.sh`
- the Herdr adapter that writes and resolves names: `bin/backends/herdr.sh`
- the away-mode launcher that names its own container:
  `bin/fm-afk-launch.sh`
