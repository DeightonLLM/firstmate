#!/usr/bin/env bash
# minimax-code harness launch template and model flag tests for bin/fm-spawn.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPAWN="$ROOT/bin/fm-spawn.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-mcode-template.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }
assert_contains() {
  case "$1" in *"$2"*) ;; *) fail "$3" ;; esac
}

# Extract a top-level shell function from fm-spawn.sh by name.
extract_fn() {
  awk -v fn="$1" '
    $0 ~ "^" fn "\\(\\) \\{" { inside = 1 }
    inside { print }
    inside && $0 ~ /^}$/ { exit }
  ' "$SPAWN"
}

FUNCS="$TMP_ROOT/fns.sh"
: > "$FUNCS"
for fn in launch_template model_flag_for_harness effort_flag_for_harness shell_quote; do
  body=$(extract_fn "$fn")
  [ -n "$body" ] || fail "could not extract $fn from fm-spawn.sh"
  printf '%s\n' "$body" >> "$FUNCS"
done
# shellcheck source=/dev/null
. "$FUNCS"

# launch_template should resolve for minimax-code across all kinds
#
# The mcode launch carries TWO directories, and they are deliberately different:
#   MCODE_CONFIG_DIR  = the per-task config dir, where permissionMode is set to
#                       bypassPermissions. Per-task, so one lane cannot loosen
#                       another lane's permissions.
#   MINIMAX_DATA_DIR  = the REAL runtime data dir, so the lane's MiniMax
#                       credential and session store resolve. This used to point at
#                       a mirrored copy under the task dir, which made the
#                       credential unresolvable (commit 46b5159).
for kind in ship scout secondmate; do
  out=$(launch_template minimax-code "$kind") || fail "launch_template returned non-zero for minimax-code kind=$kind"
  assert_contains "$out" 'MINIMAX_DATA_DIR=__MINIMAXBASE__' "launch template for $kind must set MINIMAX_DATA_DIR to the real runtime data dir"
  assert_contains "$out" 'MCODE_CONFIG_DIR=__MCODEDIR__' "launch template for $kind must set MCODE_CONFIG_DIR to the per-task config dir"
  assert_contains "$out" 'mcode ' "launch template for $kind must invoke mcode"
  assert_contains "$out" '__MODELFLAG__' "launch template for $kind must include __MODELFLAG__"
  assert_contains "$out" '"$(__OPINPUT__ encode launch-brief < __BRIEF__)"' "launch template for $kind must pass encoded brief as positional argument"
done
pass 'launch_template produces a valid template for minimax-code ship, scout, and secondmate'

# Model flag assertion
mflag=$(model_flag_for_harness minimax-code "minimax/MiniMax-M3.1-Flash")
[ -n "$mflag" ] || fail "model_flag_for_harness returned empty for minimax-code"
assert_contains "$mflag" "--model 'minimax/MiniMax-M3.1-Flash'" 'model flag must format --model correctly'
pass 'model_flag_for_harness threads --model for minimax-code'

# Default or empty model emits nothing
[ -z "$(model_flag_for_harness minimax-code '')" ] || fail 'empty model must emit no flag'
[ -z "$(model_flag_for_harness minimax-code default)" ] || fail 'default model must emit no flag'
pass 'minimax-code emits no model flag when empty or default'

# Effort axis is omitted
[ -z "$(effort_flag_for_harness minimax-code high)" ] || fail 'effort flag must be omitted for minimax-code'
pass 'effort_flag_for_harness omits effort flag for minimax-code'

# Full substitution check: resolve launch command with model, brief, and config dir
BRIEF="/path/to/brief.md"
MCODEDIR="/tmp/fm-test-task/mcode"
# Pin the data dir so the assertion is deterministic whatever the test host's HOME is.
MINIMAXBASE="/root/.minimax"
sq_brief=$(shell_quote "$BRIEF")
sq_mcodedir=$(shell_quote "$MCODEDIR")
sq_minimaxbase=$(shell_quote "$MINIMAXBASE")
sq_opinput=$(shell_quote "$ROOT/bin/fm-operational-input.sh")
MODELFLAG=$(model_flag_for_harness minimax-code "minimax/MiniMax-M3.1-Flash")
LAUNCH=$(launch_template minimax-code ship)
LAUNCH=${LAUNCH//__MODELFLAG__/$MODELFLAG}
LAUNCH=${LAUNCH//__BRIEF__/$sq_brief}
LAUNCH=${LAUNCH//__OPINPUT__/$sq_opinput}
LAUNCH=${LAUNCH//__MCODEDIR__/$sq_mcodedir}
LAUNCH=${LAUNCH//__MINIMAXBASE__/$sq_minimaxbase}

assert_contains "$LAUNCH" "MINIMAX_DATA_DIR='/root/.minimax' MCODE_CONFIG_DIR='/tmp/fm-test-task/mcode' mcode --model 'minimax/MiniMax-M3.1-Flash' " 'resolved launch must contain the real data dir, the isolated config dir, mcode and --model'
# The regression this protects: the two dirs must NOT be the same path. Pointing the
# data dir at the per-task copy is what made the MiniMax credential unresolvable.
case "$LAUNCH" in
  *"MINIMAX_DATA_DIR='$MCODEDIR'"*) fail 'MINIMAX_DATA_DIR must not point at the per-task config dir' ;;
esac
pass 'the data dir and the per-task config dir are distinct, so the credential resolves'
expected_brief_arg="\"\$('$ROOT/bin/fm-operational-input.sh' encode launch-brief < '/path/to/brief.md')\""
assert_contains "$LAUNCH" "$expected_brief_arg" 'resolved launch must contain encoded brief positional argument'

pass "fully resolved minimax-code launch command is well-formed bash with model, config dir, and encoded brief"
echo
