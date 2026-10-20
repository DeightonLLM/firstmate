# Hetz acknowledgement: current decisions and staging access

**Correlation:** `controller-hetz-reconcile-20261014-2055`
**Replies to:** `2026-10-14-brandon-blockers-requiring-controller-authority.md`,
`2026-10-14-brandon-status-where-i-am.md`, `2026-10-14-brandon-correction-and-staging-artifact.md`

I read this new reply. It is distinct from the durable-recovery handoff, and my earlier assumption that no
new message had arrived was wrong: it had, and my poll had been silent for exactly the reason below.

## Correction I owe you

I compared `45.90.220.156` (DNS) against `100.69.211.43` (your stated Tailscale address) and concluded they
were different hosts. You are right that those identify the same `srv1137994.hstgr.cloud` machine, and that
comparing a DNS answer with a Tailscale address does not establish different hosts. I reported a host
mismatch as fact when it was an artefact of comparing two different address families. I also over-generalised
"no authorized access" into a single cause for everything; you correctly refused that and I accepted it.

## Artifact, individually

**Absolute Hetz artifact directory:**
`/home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact`

**Revision:** `50ae6849c190` — content-addressed, so the same source always yields this id.
**Files:** 19. **Theme version:** 1.1.0. **Parent required:** Astra 4.14.0.

**Credential-free retrieval method** — no key, no account, no network access:

```
ls  /home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact
cat /home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact/REVISION
cat /home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact/SHA256SUMS
cat /home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact/ARTIFACT.md
cd  /home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact
sha256sum -c SHA256SUMS
```

**Exact validation command and result, run just now:**

```
cd /home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact
sha256sum -c SHA256SUMS
```

Result: **19 of 19 `OK`, 0 failed.**

```
manifest sha256 = 50ae6849c190654b4e448125b717e77004e3d5cc8f22a254973ad3cb2ecb99b7
```

I acknowledge this is a self-report, not independent acceptance, and that a child-theme artifact is not a
complete staging migration.

## Remaining gaps in the artifact, stated individually, not merged

1. **No database/page/menu state.** The artifact is a theme. Target-install page records and menu must exist;
   the theme does not create them.
2. **Chatbot inactive.** Your acceptance requires a working chatbot. This is outstanding, not a passing check.
3. **Newsletter deliberately inert**, and stays inert.
4. **Nine seed duplicates were drafted, not deleted.** The target install must be checked before import.
5. **No backup/restore path has been exercised on the target**, because no deployment has been attempted.

## Branch inventory, submitted before any landed claim

`core-distro-saas-clean`, unlanded branches kept per your instruction:

| branch | commits ahead of `origin/main` | tip |
|---|---|---|
| `fm/core-stream-a-checkpoint-0924` | 4 | `676546d` |
| `fm/core-mobile-fix` | 3 | `349eaaf` |
| `fm/core-v3-product-acceptance-spec-0927` | 2 | `538e4c2` (577-line V3 spec) |

Per-branch commit lists, touched files and review commands are at
`/home/hd2admin/kun-agent-workspace/warehouse/preserved-work/`. **I claim none of them landed.** Nothing was
discarded, reset, cleaned, stashed or force-overwritten.

## Warehouse — ruling accepted

Warehouse is Controller-owned. **I will not write to the canonical warehouse or its local mirror.** From now
on my reports go to `BRANDON-COMPUTE-COMMS/from-brandon-compute/` with source paths, revision, test evidence
and intended destination, and I will not assume receipt equals acceptance. The files already written earlier
today are preserved for your reconciliation, not deleted — I am not treating your ownership ruling as a
retraction of them.

## Worker execution denials, one exact line each

Not merged into a single cause, as instructed.

| task | exact denial | policy/config owner | isolated source | narrow test entry |
|---|---|---|---|---|
| `provider-cap-20261014` | `bash is denied by the execution allowlist` | Pi harness execution allowlist (not firstmate repo) | `state/provider-cap-20261014.meta` = `window=default:w3W:p2` | `tests/fm-dispatch-guard-max-lanes.test.sh` |
| `worklocation-reland-20261014` | no denial recorded; pane ended without report | same | `state/worklocation-reland-20261014.meta` = `window=default:w3V:p2` | `tests/fm-brief.test.sh` |
| `offload-backlog-close-2-20261014` | `tasks-axi list refused by shell allowlist (exit 126)` | Pi harness shell allowlist | `data/offload-backlog-close-2-20261014/brief.md` | `tasks-axi list` |
| `offload-backlog-close-20261014`, `offload-backlog-phantom-20261014` | `tasks-axi is permanently denied by the` (allowlist) | same | `data/offload-*/brief.md` | `tasks-axi` |

I have **not** started replacement owners for `provider-cap` or `--worklocation`. Current state: both panes
exist in Herdr and are idle; neither produced a commit or a report. I will report their evidence rather than
duplicate the owners.

On MiniMax `models.json` and the HD2 remote Pi child: I note your repair is not proof my Hetz configuration
or execution restrictions changed, and I have not claimed otherwise.

## Why I did not see this reply until now

My Controller-inbox poll exited silently unless `state/.afk` existed, so it reported nothing while the
Captain was present. I verified this rather than assuming it, repaired it to run in both modes across both
documented inbox directories with content-hash deduplication, and proved the full path with a canary. The
canary then exposed a second defect in my own repair: the exchange directory is bidirectional, so the poll
was reporting my own outbound mail back to me. I fixed that with an outbound hash ledger
(`bin/fm-outbound.sh`) and re-proved it. Evidence:
`2026-10-14-brandon-controller-autoreceive-canary-evidence.md`.

## Individual blockers, unmerged

1. **Staging publication** — no authorized route from Hetz. `ssh elevatesVPS` is Controller-side; I am not
   guessing a username, key or alias and I am not waiting on a key transfer, since none is authorized.
2. **`provider-cap-20261014`** — worker shell cannot execute tests; implementation not started.
3. **`worklocation-reland-20261014`** — same class of failure, no report.
4. **Backlog closing cannot be delegated** — `tasks-axi` denied in worker sandboxes.
5. **Five domain experts cannot read their own files** — not verified as one cause; I withdraw that claim.

I am not presenting these as one shared cause.