# WO-0010 sender hardening report

Branch: `wo-0010/sender-hardening` at `/tmp/wt-wo0010-sender`.
All behavioral sender tests replaced the fixed real recipient path with a temporary directory; no real inbox notification or message was sent.

## HIGH 1 — existing recipient file overwrite

**Status: FIXED.**

- RED: Before the implementation change, `bash tests/fm-to-controller.test.sh` exited 1 with `not ok - different content replaced an existing recipient file`; the original file's contents changed in the isolated recipient fixture.
- GREEN: `bash bin/fm-test-run.sh tests/fm-to-controller.test.sh` passed (1 test script, 0 failures). It verifies changed content is rejected without altering pre-existing bytes and identical-content retry succeeds.
- Implementation: `bin/fm-to-controller.sh` now publishes by creating a same-directory temporary file and linking it to the destination, which is exclusive; an existing regular file is accepted only when its bytes match. This also makes retry after partial delivery safe. No file is replaced.

## HIGH 2 — recipient identity/lifecycle guard

**Status: NOT FIXED — BLOCKED.**

- RED evidence: Current-source inspection confirms `bin/fm-to-controller.sh` still supplies no recipient/task identity and reads no working/blocked/done lifecycle evidence before delivery. This reproduces the reported missing guard statically; the L5 report independently records this same finding.
- GREEN: Not run; no authoritative, current recipient identity/lifecycle interface was found in the authorized source or measured inputs. The sender's fixed file-drop destination is not a lifecycle source. Inventing a status filename, trusting caller-provided state, or treating endpoint liveness as lifecycle would not establish a genuine state and could queue to a done recipient.
- No lifecycle behavior is claimed fixed. A compatible authoritative recipient identity and lifecycle source is required before this guard can safely be implemented. **[blocked=recipient-lifecycle-source]**

## Medium finding — duplicate-body ledger keys

**Status: FIXED.** The ledger key is now SHA-256 plus destination filename, and `fm-controller-pending.sh` matches that composite key. The targeted regression passes for identical bodies under distinct filenames and confirms both are independently recorded and no longer appear pending.

## Validation

- Targeted: `bash bin/fm-test-run.sh tests/fm-to-controller.test.sh` — 1 script, 0 failures.
- Syntax: `bash -n` on both modified scripts and the new test — passed.
- Direct ShellCheck: all three changed shell files — passed.
- `bash bin/fm-lint.sh` — failed on repository-wide existing diagnostics in unrelated files (including `fm-always-four.sh`, `fm-context-preflight.sh`, and numerous tests); no diagnostics referenced the three changed shell files.
- Whitespace: `git diff --check` — passed.
- Full suite: `bash bin/fm-test-run.sh --all` — **144 total, 41 failed, 12 gated skips** (91 passed, 0 not otherwise categorized). This is not green. The supplied baseline was approximately 41 failures / 143 scripts; the current total includes this new test, and this run does not establish per-test baseline equivalence. The run also printed permission-denied attempts by watcher tests against `/root/agent-work/deightonllm-firstmate/state`; those writes did not succeed. One final secret-guard test exited 126. No test intentionally targeted a real recipient.

The only full-suite outcome claimed is the count above. No retention/provenance changes were made; they remain outside this bounded fix.
