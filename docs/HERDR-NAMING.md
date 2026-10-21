# Renaming a pane or tab in herdr — what is actually visible, from the CLI help

Written 2026-10-17 after several rounds of renaming panes and finding nothing changed on screen.

## The one fact that caused all of it

**Herdr renders TAB titles in the bar. Pane labels are metadata and do not appear there.**

```sh
herdr tab rename <TAB_ID> <LABEL>...      # what the human SEES
herdr pane rename <PANE_ID> <LABEL>       # metadata only, invisible in the bar
herdr workspace rename <WS_ID> <LABEL>    # the workspace/window title
```

If a rename "doesn't show", you renamed the wrong object. Check the tab id from `herdr tab list`,
not the pane id.

## Finding the right id

```sh
herdr workspace list                 # workspace id + label + pane/tab counts
herdr tab list                       # TAB ids and their labels — the visible ones
herdr tab list --machine hd2stack    # the same on another machine
herdr pane list                      # pane ids and agent status
```

A workspace is `wD3`, its tabs are `wD3:t4B`, `wD3:t4S`, and panes live inside those tabs. **Pane ids
from `pane list` are not tab ids from `tab list`.** They are the same shape and look interchangeable.
They are not.

## Working on a machine other than this one

```sh
herdr --machine <id> tab list
herdr --machine <id> tab rename <TAB_ID> '<label>'
herdr --machine <id> pane rename <PANE_ID> '<label>'
```

Machine ids come from `herdr machine list`. **Renaming on this machine changes nothing on another
machine** — verify with `tab list --machine <id>` rather than `tab list`.

## Verify what you changed

```sh
herdr tab list --machine <id> | python3 -c "
import json,sys
for t in json.load(sys.stdin)['result']['tabs']: print(t['tab_id'],'|',t['label'],'|',t['agent_status'])"
```

Read the label back from the list output. Do not trust that a rename command succeeded to mean the
title renders — confirm the string is what you intended.

## Rules

- **Rename tabs for anything a human must see.** Pane labels are for tooling, not for reading.
- **Check the machine first.** `--machine` is not optional when the surface is not this one.
- **A successful rename is not a visible rename.** Confirm by listing, on the same machine.
- **Never report a rename as done without reading it back from `tab list` on the target machine.**

VERDICT: PASS this reflects the installed CLI's own `--help` output for `tab rename`, `tab list` and
the pane/tab/workspace id shapes; the failure it documents is what happened on 2026-10-17.