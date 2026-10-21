#!/usr/bin/env bash
# Behavior test for the control-plane task-kind capability table.
#
# bin/fm-control-lib.sh owns the per-harness control mechanics, including which
# task kinds an adapter is verified to run.
# Its header states that sourcing the file is free of side effects and that the
# tables are a pure contract, so this test sources the real library and asserts
# the real decision rather than a copy of the table.
#
# The secondmate row is the one that gates a lifecycle transition.
# bin/fm-control.sh asks fm_control_harness_supports_kind BEFORE it stops
# anything, so an incompatible relaunch target is refused while the running
# agent is still alive.
# bin/fm-secondmate-restart-lib.sh reads the same table to decide whether a
# second mate's worker runtime has verified restart mechanics.
#
# The table is cross-checked against the two public interfaces that own the
# underlying facts: bin/fm-harness.sh, which owns the verified adapter set, and
# bin/fm-supervision-instructions.sh, which owns the primary supervision
# protocol an adapter resolves to.
# A second mate runs as a primary in its own home, so the adapter it runs on
# must have a primary supervision protocol and bin/fm-spawn.sh must accept a
# --secondmate launch on it.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CONTROL_LIB="$ROOT/bin/fm-control-lib.sh"
HARNESS_BIN="$ROOT/bin/fm-harness.sh"
SUPERVISION_BIN="$ROOT/bin/fm-supervision-instructions.sh"

TMP_ROOT=$(fm_test_tmproot fm-control-secondmate-kind)

# The control library is a side-effect-free contract owner, so it is sourced
# directly and its real functions are called.
# shellcheck source=/dev/null
. "$CONTROL_LIB"

# Adapters that run a second mate, in the order the table is asserted.
SECONDMATE_CAPABLE='claude codex opencode pi pi-signed grok kimi cursor omp minimax-code'

# Adapters that stay crewmate and scout only.
SECONDMATE_BARRED='muse gemini rovo agy devin'

# An adapter name no table knows.
UNKNOWN_HARNESS='definitely-not-a-harness'

test_minimax_code_runs_a_secondmate() {
  fm_control_harness_supports_kind minimax-code secondmate \
    || fail 'minimax-code must be verified to run a secondmate task'
  pass 'minimax-code is verified to run a secondmate task'
}

test_minimax_code_runs_crew_kinds() {
  local kind
  for kind in ship scout; do
    fm_control_harness_supports_kind minimax-code "$kind" \
      || fail "minimax-code must still be verified to run a $kind task"
  done
  pass 'minimax-code is still verified to run ship and scout tasks'
}

test_barred_adapters_refuse_a_secondmate() {
  local h
  for h in $SECONDMATE_BARRED; do
    fm_control_harness_supports_kind "$h" secondmate \
      && fail "$h must stay refused for a secondmate task"
    fm_control_harness_supports_kind "$h" ship \
      || fail "$h must stay verified for a ship task"
    fm_control_harness_supports_kind "$h" scout \
      || fail "$h must stay verified for a scout task"
  done
  pass 'muse, gemini, rovo, agy, and devin stay refused for a secondmate task'
}

test_secondmate_capable_adapters_stay_allowed() {
  local h
  for h in $SECONDMATE_CAPABLE; do
    fm_control_harness_supports_kind "$h" secondmate \
      || fail "$h must stay verified to run a secondmate task"
  done
  pass 'every secondmate-capable adapter stays verified for a secondmate task'
}

test_unknown_harness_is_refused() {
  local kind
  for kind in ship scout secondmate; do
    fm_control_harness_supports_kind "$UNKNOWN_HARNESS" "$kind" \
      && fail "an unknown harness must be refused for a $kind task"
  done
  pass 'an unknown harness is refused for every task kind'
}

test_minimax_code_is_a_verified_adapter() {
  "$HARNESS_BIN" is-verified minimax-code \
    || fail 'bin/fm-harness.sh must report minimax-code as a verified adapter'
  pass 'bin/fm-harness.sh reports minimax-code as a verified adapter'
}

# The reason a second mate can run on an adapter is that the adapter has a
# primary supervision protocol, so the control table and the supervision
# protocol selection must agree.
# minimax-code must resolve to its own primary supervision protocol.
# Each barred adapter must resolve to the unknown-harness fallback.
# The remaining secondmate-capable adapters are not asserted here, because
# their supervision selection is not what this table decides.
test_supervision_protocol_agrees_with_the_table() {
  local h out mode
  out=$(FM_HOME="$TMP_ROOT" "$SUPERVISION_BIN" --harness minimax-code 2>&1) \
    || fail 'fm-supervision-instructions.sh failed for harness minimax-code'
  mode=$(printf '%s\n' "$out" | grep -m1 'primary harness:' || true)
  case "$mode" in
    *'primary harness: minimax-code'*) : ;;
    *) fail "minimax-code must resolve to its own primary supervision protocol (got: $mode)" ;;
  esac
  for h in $SECONDMATE_BARRED; do
    out=$(FM_HOME="$TMP_ROOT" "$SUPERVISION_BIN" --harness "$h" 2>&1) \
      || fail "fm-supervision-instructions.sh failed for harness $h"
    mode=$(printf '%s\n' "$out" | grep -m1 'primary harness:' || true)
    case "$mode" in
      *'primary harness: unknown'*) : ;;
      *) fail "harness $h has no primary supervision protocol and must resolve to unknown (got: $mode)" ;;
    esac
  done
  pass 'the supervision protocol selection agrees with the control kind table'
}

test_minimax_code_runs_a_secondmate
test_minimax_code_runs_crew_kinds
test_barred_adapters_refuse_a_secondmate
test_secondmate_capable_adapters_stay_allowed
test_unknown_harness_is_refused
test_minimax_code_is_a_verified_adapter
test_supervision_protocol_agrees_with_the_table

echo '1..7'
