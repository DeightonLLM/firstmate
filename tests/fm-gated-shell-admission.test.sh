#!/usr/bin/env bash
# tests/fm-gated-shell-admission.test.sh - the gated-shell admission contract for
# firstmate script invocations.
#
# A gated coding shell (lean-ctx containment) permanently denies two command
# shapes: an interpreter carrying inline code (`bash -c`, `sh -c`, `python3 -c`,
# `node -e`, `perl -e`), and `eval`/`exec`/`source` or a command-position
# `$(...)`/backtick substitution. The denial is final and must not be retried,
# so an agent that improvises a wake-drain invocation into one of those shapes
# stops instead of handling the queued wake.
#
# The contract therefore has exactly one owner: the supervision block rendered by
# bin/fm-supervision-instructions.sh, which every supported primary harness reads.
# These tests assert that owner carries the contract for each harness, that it
# never carries a bypass, and - when lean-ctx is installed - that the real gate
# admits the script-file form and denies the inline form, using a throwaway
# fixture script so no real firstmate command and no production queue is touched.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

RENDER="$ROOT/bin/fm-supervision-instructions.sh"
HARNESSES="claude codex opencode pi pi-signed grok minimax-code unknown"

[ -x "$RENDER" ] || fail "renderer not executable at $RENDER"

for h in $HARNESSES; do
  block=$(FM_ROOT_OVERRIDE="$ROOT" "$RENDER" --harness "$h" 2>/dev/null)
  [ -n "$block" ] || fail "$h: renderer produced no supervision block"

  assert_contains "$block" "direct script-file command" \
    "$h: rendered block is missing the gated-shell invocation contract"
  assert_contains "$block" "inline interpreter flag" \
    "$h: rendered block does not name the denied inline-interpreter shape"
  assert_contains "$block" "denies" \
    "$h: rendered block does not state that gated shells deny those shapes"
  assert_contains "$block" "instead of retrying" \
    "$h: rendered block does not tell the agent a denial is final"

  # A contract that only weakens protections would be a regression, not a fix.
  assert_not_contains "$block" "ALLOWLIST_WARN_ONLY" \
    "$h: rendered block recommends downgrading the gate to a warning"
  assert_not_contains "$block" "lean-ctx yolo" \
    "$h: rendered block recommends disabling containment"
  assert_not_contains "$block" "shell_allowlist" \
    "$h: rendered block tells agents to edit the shell allowlist"
done
pass "every rendered harness block carries the gated-shell admission contract and no bypass"

# The contract is about invocation FORM, not authority, so a read-only session
# still runs read-only scripts through a gated shell and still hits the same
# permanent denial. It must keep the contract and must keep its real refusal.
ro=$(FM_ROOT_OVERRIDE="$ROOT" "$RENDER" --harness claude --read-only 1 2>/dev/null)
assert_contains "$ro" "direct script-file command" \
  "read-only block lost the gated-shell invocation contract"
assert_contains "$ro" "do not drain, arm, spawn, steer, merge, or repair" \
  "read-only block lost its fleet-state refusal"

repair=$(FM_ROOT_OVERRIDE="$ROOT" "$RENDER" --harness claude --repair-line 2>/dev/null)
assert_contains "$repair" "fm-watch-arm.sh" \
  "repair line lost its harness-specific repair instruction"
assert_not_contains "$repair" "ALLOWLIST_WARN_ONLY" \
  "repair line must not carry bypass guidance"
pass "read-only and repair-line shapes keep their existing behavior and no bypass"

# --- real gate probe -------------------------------------------------------
#
# Characterizes the actual lean-ctx enforcement against a throwaway fixture so
# the contract above is anchored to observed behavior rather than assumption.
# This never invokes a real firstmate script and never touches a wake queue.
LEAN_CTX_BIN=$(command -v lean-ctx 2>/dev/null || true)
if [ -z "$LEAN_CTX_BIN" ]; then
  printf '# live gate probe not run: lean-ctx is not installed on this surface\n'
  printf '1..2\n'
  exit 0
fi

lab=$(fm_test_tmproot gated-shell-probe)
mkdir -p "$lab/bin"
cat > "$lab/bin/fm-probe-fixture.sh" <<'SH'
#!/usr/bin/env bash
printf 'FIXTURE-ADMITTED\n'
SH
chmod +x "$lab/bin/fm-probe-fixture.sh"

admitted=$(cd "$lab" && "$LEAN_CTX_BIN" -c "bin/fm-probe-fixture.sh" 2>&1 || true)
assert_contains "$admitted" "FIXTURE-ADMITTED" \
  "real gate did not admit the canonical script-file invocation form"

denied=$(cd "$lab" && "$LEAN_CTX_BIN" -c "bash -c 'bin/fm-probe-fixture.sh'" 2>&1 || true)
assert_contains "$denied" "BLOCKED" \
  "real gate admitted the inline-interpreter form the contract forbids"
assert_contains "$denied" "DO NOT RETRY" \
  "real gate denial lost its do-not-retry marker"
pass "real gate admits script-file form and permanently denies the inline form"

printf '1..3\n'