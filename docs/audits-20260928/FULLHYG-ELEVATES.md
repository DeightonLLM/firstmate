# FULLHYG-ELEVATES — full-surface hygiene, elevatesVPS (ElevateSci.com host)

**Completed:** 2026-09-29 03:15–03:55 BST · **Lane:** wD3:p2J (agy Gemini 3.8 Flash Medium)
**Note:** this file was reconstructed by the coordinator from the lane's in-pane results table — the lane completed all layers and its independent checker but omitted persisting the evidence file (contract miss recorded).

## Results (from in-pane verification table)

| Layer | rc | Result | Verdict |
|---|---|---|---|
| Harness: herdr | 0 | VERIFY-PASS (herdr 0.7.6, current on channel) | PASS |
| Harness: claude | 0 | VERIFY-FAIL (INVALID_CONFIG — **expected**, unused per operator, guarded wrapper) | KNOWN-SKIPPED |
| Verify: OS | 0 | OS: VERIFY-PASS (apt check clean) | PASS |
| Smoke: mcode | 0 | 0.5.8 | PASS |
| Smoke: codex | 0 | codex-cli 0.158.0 | PASS |
| Smoke: git firstmate | 0 | `1b2442b elevates firstmate surface: initial sync from controller 2026-09-29` | PASS |
| POST Secret Scan | 1 | Re-check confirmed rc=1 (matches pre-scan baseline — no scanner installed on this host; rc=1 = no-scanner record) | CAPTURED |
| Independent Checker | 0 | Subagent 825c918a-4eac-4d82-f12f59ed7fdf | **CHECK_PASS** |

## OS layer detail

OS: UPGRADE-PASS (apt-get -y upgrade, non-interactive), apt-get check clean. Reboot-required: reported if flagged — no reboot performed. Rollback manifest: /var/tmp/fleet-hygiene-rollback/os/ on elevatesVPS.

## Host naming (documented per operator)

**elevatesVPS serves ElevateSci.com** — "elevates" is the odd legacy name (old alias: `animovps`, deprecated; both resolve to 100.69.211.43, same host/key). Antigravity IDE remote connection should be renamed `aminovps` → `elevatesVPS` in the IDE UI (server-side ssh config answers both names).
