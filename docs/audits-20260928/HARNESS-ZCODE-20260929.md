# HARNESS-ZCODE-20260929 — ZCode registered as the GLM harness

**Written:** 2026-09-29 16:45 BST · **Status:** ✅ REGISTERED and VERIFY-PASSING

## What was found

ZCode was **already installed and working on `brandon-compute`** — not missing, as
first assumed. It ships **no Linux artifact on GitHub** (release v3.14.3 contains
only `mac-arm64.dmg` and `win-x64.exe`), no npm package under `@zcode/cli`, and
`ZCODE_DIST_BASE_URL` is blank in the repo, so the documented CLI install path is
not publicly resolvable. The only working instance is the one on brandon.

## Verified identity (brandon-compute)

| Property | Value |
|---|---|
| Version | **0.16.9** (CLI is versioned independently of the 3.14.3 desktop app) |
| Platform | `linux/x64` |
| Runtime | **bundles its own Node v22→v24.14.0** — no host Node dependency |
| Model | **`GLM-5.3-Flash`**, `reasoningLevel: max` |
| `zcode doctor` | healthy (`process: zcode-cli`, `default artifact: node-bundle`) |
| Binary | `/home/hd2admin/.local/bin/zcode` (163 B wrapper) |
| Runtime home | `/home/hd2admin/.zcode/` (`cli/`, `v2/`) |
| Credentials | own `v2/credentials.json` + `provider_config.json` |

**Why this matters for routing:** ZCode holds its *own* Z.AI credentials, so it
does **not** consume the throttled `zai` MCP/tool window that showed 0% remaining.
It is a usable GLM route while the MCP path is exhausted.

## Commands it supports

```
tui          open the terminal UI (default with no args)
app-server   ZCode Protocol stdio app server
doctor       inspect runtime and packaging assumptions
login [zai|bigmodel]   browser authorization
plugins      list|install|uninstall|enable|disable|update|validate|marketplace
skills       list local skills
commands     list custom slash commands
version      print CLI version
```

## Registration applied

`/root/bin/fleet-hygiene` CATALOG:

```
zcode||zcode --version
```

The empty update-command field is **deliberate**: ZCode has **no self-update
command**, so the engine is registered **inventory + verify only** and will never
attempt an update. This mirrors the herdr skip-by-design pattern but for a
different reason.

Verified on brandon: `CLI zcode: VERIFY-PASS [0.16.9]`. On the controller it
correctly reports `not-installed` — the instance lives on brandon only.

## Still to do (needs captain approval)

The Firstmate **shared tracked material** — specifically the verified-harness list
in `AGENTS.md` §4 — has **not** been edited. Per that repo's own contract,
shared tracked changes must ship through the no-mistakes pipeline and PR path, not
by hand. ZCode is therefore **not yet a contract-recognised harness**; it is
registered in the ops layer only. Adding it to the contract needs a PR.

Backups: `fleet-hygiene.bak-20260929T1642xx` (controller), and the pre-change copy
on brandon before the sync.
