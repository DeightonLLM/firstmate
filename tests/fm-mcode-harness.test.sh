#!/usr/bin/env bash
# Behavior tests for the verified MCode (minimax-code) primary adapter.
#
# MCode is the standalone `mcode` CLI, a documented MiniMax fork of pi.dev.
# Its process comm is `minimax-code`. These tests exercise the public
# interfaces only: the shared session-lock ancestry walk, the harness
# self-report, and the supervision protocol selection. They never assert
# implementation-source bytes.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOCK_LIB="$ROOT/bin/fm-session-lock-lib.sh"
HARNESS_BIN="$ROOT/bin/fm-harness.sh"
SUPERVISION_BIN="$ROOT/bin/fm-supervision-instructions.sh"
TMP_ROOT=$(fm_test_tmproot fm-mcode-harness)

cleanup_mcode_harness() { rm -rf "$TMP_ROOT"; }
trap cleanup_mcode_harness EXIT

# Never let a variable in this file reach the scripts under test as a harness
# selector, and never let a foreign identity marker win detection. Both are the
# precedence hazard fm-harness.sh documents: a marker retained by a terminal
# multiplexer silently outranks ancestry, which is how a concurrent suite on a
# busy host can misidentify this harness.
mcode_env() {
  env -u HARNESS -u CLAUDECODE -u PI_CODING_AGENT -u GROK_AGENT -u FM_PI_HARNESS "$@"
}

# A real executable whose comm is exactly `minimax-code`, so the ancestry walk
# is exercised against a genuine process name rather than a source grep.
install_mcode_binary() {
  mkdir -p "$TMP_ROOT/bin"
  cp /bin/bash "$TMP_ROOT/bin/minimax-code" \
    || fail "could not stage a minimax-code executable"
  chmod +x "$TMP_ROOT/bin/minimax-code"
}

test_mcode_resolves_as_a_harness_ancestor() {
  local resolved
  resolved=$(mcode_env "$TMP_ROOT/bin/minimax-code" -c \
    ". '$LOCK_LIB'; fm_harness_ancestry_pid" 2>/dev/null) \
    || fail "session-lock ancestry walk refused a live minimax-code process"
  case "$resolved" in
    ''|*[!0-9]*) fail "session-lock ancestry walk returned '$resolved', expected a numeric pid" ;;
  esac
}

test_mcode_is_detected_as_its_own_harness() {
  local detected
  detected=$(mcode_env "$TMP_ROOT/bin/minimax-code" -c \
    "FM_HOME='$ROOT' FM_CONFIG_OVERRIDE='$ROOT/config' '$HARNESS_BIN'" 2>/dev/null)
  [ "$detected" = "minimax-code" ] \
    || fail "fm-harness.sh self-report was '$detected', expected minimax-code"
}

test_mcode_harness_liveness_recognises_a_mcode_pid() {
  local rc=0
  mcode_env "$TMP_ROOT/bin/minimax-code" -c \
    ". '$LOCK_LIB'; fm_harness_pid_alive \$\$" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 0 ] \
    || fail "fm_harness_pid_alive rejected a live minimax-code pid (rc=$rc)"
}

test_supervision_selects_the_mcode_protocol() {
  local out
  out=$(HARNESS=minimax-code FM_HOME="$ROOT" FM_CONFIG_OVERRIDE="$ROOT/config" \
    "$SUPERVISION_BIN" 2>/dev/null)
  printf '%s' "$out" | grep -q 'primary harness: minimax-code' \
    || fail "supervision did not select the minimax-code protocol: $out"
  if printf '%s' "$out" | grep -q 'Unknown harness fallback'; then
    fail "supervision still emitted the unknown-harness fallback for MCode"
  fi
  return 0
}

install_mcode_binary
test_mcode_resolves_as_a_harness_ancestor
test_mcode_is_detected_as_its_own_harness
test_mcode_harness_liveness_recognises_a_mcode_pid
test_supervision_selects_the_mcode_protocol

pass "MCode primary adapter: lock ancestry, self-report, liveness, supervision"