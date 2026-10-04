# MUT-SECSCAN-FAILCLOSED — scanner fail-open defect fixed

**Date:** 2026-09-29 · **Owner:** controller coordinator (mvs_d65a09…) · **Status:** ✅ FIXED + DEPLOYED (controller + brandon)

## Defect

`/root/bin/agent-secret-scan` reported **`SUCCESS` / exit 0** when it could not
actually scan anything. The scan root was entered with:

```bash
( cd -- "$ROOT" && rg -l -P --hidden "${EXCLUDES[@]}" "$PATTERN" . )
```

If `cd` failed (missing or unreadable root), the subshell exited non-zero
without running ripgrep, so ripgrep produced **no output**. The caller only
distinguished three states:

- `rg_status == 0` → matches found
- `rg_status == 1` → "no matches at all — clean" → `SUCCESS`, exit 0
- anything else → hard error, exit 2

A failed `cd` therefore landed in the **"clean"** bucket. The scanner
certified a tree it had never read.

**Why this matters more than a normal bug:** this is a security control. A
secret scanner that reports "clean" on an unscanned tree converts an *unknown*
state into a *clean bill of health* — the exact opposite of fail-closed. The
tool's own comment block states its intent ("A bad manifest is a hard failure;
it can never weaken the scan silently"), so this also violated its documented
contract.

## Proof (pre-fix)

Reproduced on both hosts.

```bash
# controller
$ /root/bin/agent-secret-scan check /root/does-not-exist
... cd: /root/does-not-exist: No such file or directory
SUCCESS: no obvious leaked secret files found
RC=0                      # <-- fail-open

# brandon, as the unprivileged scan user (the real-world case)
$ /home/hd2admin/bin/.agent-secret-scan.real check /root
... cd: /root: Permission denied
SUCCESS: no obvious leaked secret files found
RC=0                      # <-- fail-open
```

The brandon case is the one that mattered operationally: the documented
`hd2admin` wrapper cannot read `/root`, so a routine scan invocation returned
a **vacuous pass**. The genuine state, when the same scan is actually run as
root, is `rc=1` with real findings — the two runs disagreed, and the
unprivileged one was the reassuring one.

## Fix

An explicit accessibility precondition in `scan_paths()`, before any search is
attempted. Smallest change that makes the root-unreachable state
distinguishable from the genuinely-clean state:

```bash
scan_paths() {
  local rg_status
  # Fail closed. If the scan root cannot be entered, ripgrep emits no matches,
  # which is otherwise indistinguishable from a genuinely clean tree and would
  # be reported as SUCCESS. Certifying an unscanned tree is worse than not
  # scanning at all, so an unreachable root is a hard error.
  if ! ( cd -- "$ROOT" ) 2>/dev/null; then
    echo "FAILED: scan root is not accessible: $ROOT" >&2
    return 2
  fi
  (
    cd -- "$ROOT" && rg -l -P --hidden "${EXCLUDES[@]}" "$PATTERN" .
  ) | sed "s#^\\./#${ROOT%/}/#"
  rg_status=${PIPESTATUS[0]}
  return "$rg_status"
}
```

Plus a distinct message in the `check` error branch so an operator reading the
output is never misled into reading a scan error as a pass:

```
FAILED: scan did not complete — scan root inaccessible or ripgrep errored
(exit 2); no clean result is implied
```

The original `( cd ... ) | sed ...` subshell and its path normalization are
preserved unchanged; only the precondition is new.

## TDD evidence

Suite: `/root/agent-work/firstmate/tests/agent-secret-scan-fail-closed.sh`
(hermetic — builds a throwaway fixture tree, overrides baseline + manifest
paths, never touches the real `/root` tree or any real credential).

| Stage | Result |
|---|---|
| **RED** | `3 passed, 2 failed` (exit 1). T1 `missing root must not report SUCCESS` and T2 `missing root must exit non-zero` both failed against live code — failure signature was the real defect (`SUCCESS` + `rc=0`). T3/T4 passed, proving the harness and the scanner's actual detection were already sound. |
| **GREEN** | `5 passed, 0 failed` (exit 0) after the precondition was added. T3 (reachable clean tree still passes) and T4 (reachable leak still reported) confirm the fix did not make the scanner fail indiscriminately nor swallow genuine findings. |
| **REFACTOR** | The T4 fixture originally embedded a literal `sk-…` string, which the *production* scanner correctly flagged — the test was creating a new finding in the real scan. Changed to assemble the value at runtime from fragments. Suite re-run: still `5 passed, 0 failed`, and the test file no longer matches the secret pattern. |

T5 covers `list` mode on an unreachable root (previously a silent success path).

## Postflight verification

- `bash -n` clean on both hosts.
- **Controller live scan** `/root`: `rc=1`, 2 files — exactly the known-accepted
  baseline (the two `.minimax/v2/sessions/…` transcripts holding the
  known-accepted elevates `ANTHROPIC_AUTH_TOKEN`, operator-notified
  2026-09-29 03:30 BST). No new findings, no lost findings.
  - Note: an earlier `rc=141` in the transcript is `SIGPIPE` from `head`
    closing the pipe, **not** a scanner error. True exit code is `1`.
- **brandon deployed**: `sha256 aa538a47d6d8cba9f70f124e132f47b81781268861e06e26917d792624d40ece`.
  Previous binary retained as `.agent-secret-scan.real.bak-20260929T050318Z`.
- **brandon post-fix, the vacuous pass is gone**:
  - `check /root` as `hd2admin` → `FAILED: scan root is not accessible: /root`, `rc=2` (was `SUCCESS`/`rc=0`).
  - `check /home/hd2admin` (reachable) → still performs a real scan, `rc=1` with findings.
- **No behavioral regression**: same-root pre-fix vs post-fix finding lists on
  brandon differ by ordinary scan drift only (407 → 408) — one `node_modules`
  file disappeared between runs, one `.dsh/.credentials.yaml` reappeared. No
  file was lost or newly hidden by the change.

## Known limitations / follow-up

1. ~~**Not yet deployed to `hd2stack` or `elevatesVPS`.**~~ **RESOLVED 2026-09-29
   06:15 BST — both hosts tested individually; they did NOT need the same fix.**

   Each host carries its own scanner copy, and they are genuinely different
   scripts, so the controller file was deliberately **not** copied over them.
   Each was tested against the fail-open case first:

   | Host | Scanner | Fail-open test | Verdict | Action |
   |---|---|---|---|---|
   | `hd2stack` | 299 lines, `sha a4941dee…` | `SUCCESS` / `rc=0` on an unreachable root | **VULNERABLE** | ✅ patched |
   | `elevatesVPS` | 78 lines, `sha c942cfdc…` | `rc=1`, no `SUCCESS` | **already fails closed** | ✅ no change needed |

   `elevatesVPS` resolves the root eagerly at line 6 —
   `ROOT="$(cd "$ROOT" && pwd -P)"` under `set -euo pipefail` — so a failed
   `cd` aborts the script before any scan is attempted. It is an older, simpler
   scanner than the controller's (no false-positive manifest support) but it
   is **not** vulnerable to this defect. No edit was made.

   **`hd2stack` patch** (surgical, same guard, backup retained):
   - backup: `/root/bin/agent-secret-scan.bak-20260929T051334Z`
   - post-patch `sha 87926cf1329a31bc`, `bash -n` clean
   - fail-open test now: `rc=2`, `FAILED: scan root is not accessible: /root/definitely-not-here`
   - `list` mode on a bad root: `rc=2`
   - **regression check: pre-fix vs post-fix finding lists on a real `/root`
     scan were byte-identical — 133 paths before, 133 after, zero added, zero
     removed.**

2. **The `check` error message on `hd2stack`** still reads the older
   `FAILED: ripgrep command failed with exit code 2` rather than the
   controller's clearer phrasing. The precise cause is already printed to
   stderr by the guard itself, and the exit code is correct, so the cosmetic
   difference was left alone to keep the patch minimal.

3. `/home/hd2admin/.dsh/.credentials.yaml` reappeared in the brandon scan. This
   is the **known, already-reported** finding (CONSOLIDATED-20260928.md §"In
   tandem") — sensitive-named credentials file, never baselined, operator triage
   still open. Not touched.

4. The board's headline `compression_rate=14` metric is stale and unrelated to
   this defect — see `LEANCTX-FINDING-20260929.md`.

## Deployment status: all four hosts accounted for

| Host | State |
|---|---|
| controller | ✅ patched (original in git-tracked docs; guard added) |
| brandon-compute | ✅ patched — `sha aa538a47…`, backup `.bak-20260929T050318Z` |
| hd2stack | ✅ patched — `sha 87926cf1…`, backup `.bak-20260929T051334Z` |
| elevatesVPS | ✅ verified not vulnerable — no change made |


---

# SEPARATE ITEM — brandon-compute port 3001 public exposure (FIXED 2026-09-29 07:05 BST)

*(Recorded here for campaign continuity; this is a different item from the scanner work above.)*

## Finding

`hd2stack-anythingllm` (AnythingLLM) was published on `0.0.0.0:3001` / `[::]:3001`
via `docker-proxy`, making it reachable on the **public** internet at
`157.180.99.39:3001` — confirmed HTTP 200 from the controller before the change.

**The original audit claim was partly wrong and is corrected here:** it was recorded
as "unauthenticated network access". The API is in fact authenticated — it returns
`403 {"error":"No valid api key found."}` without a valid key. The real exposure is
the public **login UI plus auth/brute-force attack surface**, and the fact that
Docker's published port bypasses the host firewall.

## Why UFW was not the fix

`iptables -t nat -L DOCKER` showed `DNAT tcp dpt:3001 -> 172.17.0.2:3001`. The
Docker DNAT chain runs **before** `ufw-user-input`, so `ufw deny 3001` would have
had no effect while giving a false impression of remediation. The fix had to be at
the Docker layer.

## Fix applied

Recreated the container bound to loopback + Tailscale only. A recreate was
required because Docker cannot rebind a published port live.

- Pre:  `{"3001/tcp":[{"HostIp":"","HostPort":"3001"}]}`
- Post: `{"3001/tcp":[{"HostIp":"127.0.0.1","HostPort":"3001"},{"HostIp":"100.106.6.22","HostPort":"3001"}]}`

Both addresses were kept deliberately: binding `127.0.0.1` alone would have broken
the documented Tailscale consumer at `100.106.6.22:3001`.

**Rollback was secured BEFORE the change** — the container had no compose file, no
systemd unit, no launch script and no compose labels (ad-hoc `docker run` since
2026-09-26), so the exact invocation and env were captured to
`/home/hd2admin/anythingllm-3001-runbook.md` (mode 600) with env values to
`/home/hd2admin/.alm-env.txt` (mode 600, values never displayed).

## Verification

| Check | Before | After |
|---|---|---|
| Public `157.180.99.39:3001` | **HTTP 200** | **blocked** (curl exit 124, timeout) |
| Tailscale `100.106.6.22:3001` | 200 | **200** (preserved) |
| Loopback `127.0.0.1:3001` | 200 | **302** (normal AnythingLLM redirect) |
| `ss -ltn` listeners | `0.0.0.0:3001`, `[::]:3001` | `100.106.6.22:3001`, `127.0.0.1:3001` only |
| Container state | up | **healthy** |
| Auth enforcement | 403 without key | **403** without key (unchanged) |

Storage is bind-mounted, so no data was at risk. Interruption was seconds.

## Follow-up

Convert to a real compose file with the loopback + Tailscale binds as the durable
source of truth. Until then, `/home/hd2admin/anythingllm-3001-runbook.md` is the
only record of how this container is launched — do not delete it.
