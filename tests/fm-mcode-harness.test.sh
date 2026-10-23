#!/usr/bin/env bash
# Behavior tests for the verified MCode (minimax-code) primary adapter.
#
# MCode is the standalone `mcode` CLI, a documented MiniMax fork of pi.dev.
# Its process comm is `minimax-code`. These tests exercise the public
# interfaces only: the shared session-lock ancestry walk, the harness
# self-report, and the supervision protocol selection. They never assert
# implementation-source bytes.
#
# The verified-harness contract is additionally cross-checked against the
# tracked operating contract in AGENTS.md, because bin/fm-harness.sh is the
# single source of truth that every other component defers to, so the two
# must name the same harnesses. AGENTS.md is prose, not implementation
# source, and it is read through its public sentence rather than by
# inspecting any script's bytes. Set FM_TEST_AGENTS_MD to point the
# cross-check at another AGENTS.md, which is how the negative control
# proves the assertion is load-bearing.
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

# The verified-harness names AGENTS.md declares, read from its public
# sentence. Backtick-quoted names are the harness names; the connective
# words around them are prose and are dropped.
agents_harness_list() {
  local file=$1 line
  line=$(grep -m1 'The verified harnesses are' "$file") || return 1
  line=${line%%;*}
  # shellcheck disable=SC2016  # single quotes are deliberate: the backticks are a literal pattern, not a command substitution
  printf '%s\n' "$line" | grep -o '`[^`]*`' | tr -d '`' \
    | grep -vx -e and -e or || return 1
}

# One harness list as sorted whitespace-separated words, so two lists are
# compared by membership rather than by the order each file happens to
# print them in.
harness_words() {
  tr ' ' '\n' | grep -v '^$' | LC_ALL=C sort
}

test_verified_list_agrees_with_agents_md() {
  local agents_md harness_list agents_list h_words a_words
  agents_md=${FM_TEST_AGENTS_MD:-$ROOT/AGENTS.md}
  [ -r "$agents_md" ] || fail "AGENTS.md is not readable at $agents_md"
  harness_list=$("$HARNESS_BIN" verified) \
    || fail "fm-harness.sh verified returned non-zero"
  agents_list=$(agents_harness_list "$agents_md") \
    || fail "AGENTS.md carries no 'The verified harnesses are' sentence naming harness names"
  h_words=$(printf '%s\n' "$harness_list" | harness_words)
  a_words=$(printf '%s\n' "$agents_list" | harness_words)
  [ -n "$h_words" ] || fail "fm-harness.sh verified returned an empty harness list"
  [ -n "$a_words" ] || fail "AGENTS.md yielded an empty verified harness list"
  if [ "$h_words" != "$a_words" ]; then
    fail "verified harness lists disagree: fm-harness.sh has [$(printf '%s' "$h_words" | tr '\n' ' ')] and AGENTS.md has [$(printf '%s' "$a_words" | tr '\n' ' ')]"
  fi
  pass "fm-harness.sh verified and AGENTS.md name the same verified harnesses"
}

test_minimax_code_is_a_verified_harness() {
  "$HARNESS_BIN" is-verified minimax-code \
    || fail "fm-harness.sh is-verified minimax-code did not exit 0"
  "$HARNESS_BIN" verified | harness_words | grep -qx 'minimax-code' \
    || fail "minimax-code is absent from the fm-harness.sh verified list"
  pass "minimax-code is a verified harness"
}

test_verified_json_names_the_same_harnesses() {
  local h_words j_words
  h_words=$("$HARNESS_BIN" verified | harness_words)
  j_words=$("$HARNESS_BIN" verified-json | tr -d '[]"' | tr ',' '\n' \
    | grep -v '^$' | LC_ALL=C sort)
  [ -n "$j_words" ] || fail "fm-harness.sh verified-json returned no harness names"
  [ "$h_words" = "$j_words" ] \
    || fail "fm-harness.sh verified and verified-json disagree: [$(printf '%s' "$h_words" | tr '\n' ' ')] vs [$(printf '%s' "$j_words" | tr '\n' ' ')]"
  pass "fm-harness.sh verified-json names the same harnesses as verified"
}

install_mcode_binary
test_mcode_resolves_as_a_harness_ancestor
test_mcode_is_detected_as_its_own_harness
test_mcode_harness_liveness_recognises_a_mcode_pid
test_supervision_selects_the_mcode_protocol
test_verified_list_agrees_with_agents_md
test_minimax_code_is_a_verified_harness
test_verified_json_names_the_same_harnesses

pass "MCode primary adapter: lock ancestry, self-report, liveness, supervision"
pass "MCode primary adapter: verified harness list agrees with AGENTS.md"