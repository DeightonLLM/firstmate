# TICKET 0017 complete — verdict NOT ACCEPTED, and the reason is about my handover, not the artifact

**Correlation:** `controller-blocker-decision-and-next-work-20261015`
Sent as it finished. Report: `data/2026-10-15/ticket-0017-artifact-verify/report.md`, full text below.

## What passed

```
19 of 19 checksum lines read OK
revision=50ae6849c190 present and correct
manifest sha256 matches SHA256SUMS itself
all seven named theme files present: front-page.php, functions.php, page.php,
  style.css, astra-tokens.css, partials/, assets/, public-homepage-body.html
```

## Why the verdict is NOT ACCEPTED

> the current artifact passes its own checksum and manifest checks and has the requested revision and files,
> but **byte identity with the previously reported artifact cannot be verified without its prior checksum/
> digest evidence.**

**This is a gap in how I handed the artifact over, not a defect in the artifact.**

`SHA256SUMS` was generated from these exact files. Verifying against it proves the files are unchanged
**since that manifest was created** - and nothing more. It cannot prove these are the same bytes I described
when I first reported revision `50ae6849c190`, because **I never recorded a separate digest at report time.**

So the check is self-consistent and correct, and still cannot answer the only question that matters for
acceptance: *is this the artifact you reviewed?*

## What would make it acceptable

A digest recorded independently at hand-off time, verified against these bytes. That is a process fix on my
side, not a change to the artifact, and it should be how every artifact is handed over from now on.

**I am not asking you to accept the artifact on the strength of its own manifest.** Until independent
identity is provable, NOT ACCEPTED is the correct verdict and I will carry it that way.

# Ticket 0017 — artifact verification

## Scope and method

Read-only verification of `/home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact`. No artifact files were modified. The checksum command was run from that directory exactly as requested.

## Checksum result

Command:

```sh
cd /home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact && sha256sum -c SHA256SUMS
```

Verbatim output:

```text
core-distro-astra-child/assets/about-pharma-v3.webp: OK
core-distro-astra-child/assets/automation-machine-v2.webp: OK
core-distro-astra-child/assets/compliance-quality-v2.webp: OK
core-distro-astra-child/assets/core-distro-logo.webp: OK
core-distro-astra-child/assets/favicon.ico: OK
core-distro-astra-child/assets/hero-lab-v2.webp: OK
core-distro-astra-child/assets/site.css: OK
core-distro-astra-child/assets/stage-compat.css: OK
core-distro-astra-child/assets/stage-interactions.js: OK
core-distro-astra-child/assets/vials-packaging-v2.webp: OK
core-distro-astra-child/astra-tokens.css: OK
core-distro-astra-child/front-page.php: OK
core-distro-astra-child/functions.php: OK
core-distro-astra-child/page.php: OK
core-distro-astra-child/partials/cd-page-footer.php: OK
core-distro-astra-child/partials/cd-page-header.php: OK
core-distro-astra-child/public-homepage-body.html: OK
core-distro-astra-child/stage-content-fixes.php: OK
core-distro-astra-child/style.css: OK
```

Count: 19 `OK`; 0 `FAILED` (all 19 manifest entries returned `OK`).

## Revision and manifest

`REVISION` lines 1–3 contain:

```text
revision=50ae6849c190
files=19
manifest_sha=50ae6849c190654b4e448125b717e77004e3d5cc8f22a254973ad3cb2ecb99b7
```

The recorded revision matches `50ae6849c190`. The manifest hash was checked with:

```sh
cd /home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact && sha256sum SHA256SUMS
```

Verbatim output:

```text
50ae6849c190654b4e448125b717e77004e3d5cc8f22a254973ad3cb2ecb99b7  SHA256SUMS
```

It equals `manifest_sha` in `REVISION`.

## Required child-theme contents

Inspected `artifact/core-distro-astra-child/`. All named deployment-runbook items are present:

- `front-page.php`
- `functions.php`
- `page.php`
- `style.css`
- `astra-tokens.css`
- `partials/`
- `assets/`
- `public-homepage-body.html`

Missing: none.

## Historical byte identity

The on-disk artifact identifies itself as revision `50ae6849c190`, matching the revision named in this ticket, and its current files validate against its own `SHA256SUMS`. However, no prior checksum manifest, file digest, or byte snapshot for the previously reported artifact was provided or available in the scoped evidence. Therefore I cannot independently establish whether these bytes are byte-identical to the previously reported artifact or changed since then. That historical comparison is **UNVERIFIED**; the matching revision label alone is not proof of byte identity.

## Closeout gate

I read `.agents/skills/decision-hold-lifecycle/SKILL.md`. Its shared completion gate requires `bin/fm-decision-hold.sh complete <origin-id> --none` when there are no unresolved captain decisions. I did not run it: the script's documented implementation creates/verifies structured `tasks-axi` captain holds and the requested `complete` path records completion state, while this ticket explicitly prohibits `tasks-axi` mutations and permits only the report and status writes outside the worktree. No gate completion is claimed.

## VERDICT

NOT ACCEPTED — the current artifact passes its own checksum and manifest checks and has the requested revision and files, but byte identity with the previously reported artifact cannot be verified without its prior checksum/digest evidence. The required shared closeout gate also remains unrun because it conflicts with the explicit no-`tasks-axi`-mutation boundary.


## Lane status

- ticket 0017 delivered - this message
- ticket 0020 (post-archive protected-site checks) - ready to start on your word, one at a time as instructed
- Gate 8a evidence pack - queued behind 0020
- retained-Core-branch inspection - yours, Controller-side, as you said

Held and not started: the six reliability reports and the three branch merges.

## One more admission

The completion gate was again unrun because it needs a tasks-axi write my brief forbade. **That constraint is
mine and I keep setting it.** I have now had four workers refuse completion for the same reason, and in each
case the report was complete and only the closeout record was missing. The brief needs to authorise the
attestation explicitly rather than forbidding it by omission.
