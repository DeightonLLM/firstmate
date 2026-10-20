# Pi and Herdr operator notes for this Hetzner home

Verified 2026-09-23 against the official docs and the local Firstmate tree.
This is a local operator reference, not a controller policy.

## Pi extensions and Calm

Official references:

- [Pi extensions](https://pi.dev/docs/latest/extensions)
- [Pi configuration and resource locations](https://pi.dev/docs/latest/configuration)
- [Pi slash commands](https://pi.dev/docs/latest/slash-commands)

Pi loads user extensions from `<agent-dir>/extensions` (normally
`~/.pi/agent/extensions`) and project extensions from the current trusted
worktree's `.pi/extensions/`. Project resources load after the project is
trusted. `/reload` reloads extensions and other resources in a running session;
a fresh Pi process discovers them again at startup.

On this host, `fm-calm.ts` is project-local rather than in the Pi user
extension directory. The inspected Calm task worktree contained
`.pi/extensions/fm-calm.ts` and its working-ship module declared
`HD2.ai/Crisp-R`. A normal Pi restart in that same trusted worktree should load
the extension. For another lane, check that lane's worktree contains the
extension and that Pi has trusted the project. The `/` command menu is the
current-session proof that `/calm` was registered; `/reload` is the first
check after a resource change.

Do not infer the active model from a Herdr display label. Check the Pi model
footer and Firstmate task record. A Herdr agent alias is a display name for a
live process, not the model identity.

## Herdr: pane, agent, and layout

Official references:

- [Herdr agent automation](https://herdr.dev/docs/agent-automation/)
- [Herdr agents and state](https://herdr.dev/docs/agents/)

Keep the three Herdr primitives distinct:

- **Layout** (`workspace`, `tab`, `pane`) is where terminals live.
- **Pane** commands operate on a raw terminal, even if it currently contains
  an agent.
- **Agent** commands target a recognized live coding process and its lifecycle
  state (`working`, `blocked`, `done`, `idle`, or `unknown`). A pane can remain
  after its agent exits; an idle/ready agent can remain alive in its pane.

Useful read and control commands:

```sh
herdr agent get <pane-id>
herdr agent explain <pane-id>
herdr agent read <pane-id> --source recent-unwrapped --lines 80
herdr agent wait <pane-id> --until blocked --timeout 120000
```

Use `herdr agent explain` when displayed state disagrees with the pane. Use
`agent prompt` for a submitted agent prompt and `agent send-keys` for a deliberate
UI key. Reserve `pane run` and `pane send-text` for ordinary shell/terminal
work; they do not have agent lifecycle semantics. `herdr agent rename` changes
the current live agent alias and is cleared when that agent exits or is
replaced; it does not rename a pane permanently.

For a Firstmate-owned task, begin with its task ID:

```sh
bin/fm-crew-state.sh <task-id>
bin/fm-peek.sh <task-id>
FM_HOME=/home/hd2admin/kun-agent-workspace bin/fm-control.sh <task-id> exit
```

Firstmate's control plane verifies the lifecycle postcondition and preserves
the pane, worktree, and uncommitted changes. If it refuses because the composer
has pending text, it has sent nothing; do not type `/quit`, clear the draft, or
close the pane through raw Herdr commands. Inspect the draft in the visible UI
and resolve it deliberately before retrying through `fm-control`.

## Context7 and durable memory

Context7 is not connected in this Firstmate tool session. It can be used later
as a documentation retrieval source, but it is not itself durable session
memory. Keep the confirmed mechanics and official URLs in this home-local file
and link to it from `data/learnings.md`.
