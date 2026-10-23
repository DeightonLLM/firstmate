#!/usr/bin/env bash
# minimax-code harness launch template and model flag tests for bin/fm-spawn.sh
#
# The minimax-code launch carries TWO directories and they are deliberately
# different paths. The config dir is per-task, so permissionMode can be
# bypassPermissions without touching the shared runtime. The data dir stays the
# real one, because mcode binds its OAuth credential to the literal string of
# the auth home ("<data dir>/auth") and keys the stored record on
# sha256(authHome + "\0" + clientId). A per-task data dir computes a DIFFERENT
# key, the stored token is never found, and every spawned agent comes up asking
# for a login. A test that asserted the two directories were equal would pin
# the defect that makes every minimax-code lane ask for a login.
#
# The model slug asserted here is minimax/MiniMax-M3.1-Flash. The older
# minimax/MiniMax-M3.1-Flash-Preview slug is retired.
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
for kind in ship scout secondmate; do
  out=$(launch_template minimax-code "$kind") || fail "launch_template returned non-zero for minimax-code kind=$kind"
  assert_contains "$out" 'MINIMAX_DATA_DIR=__MCODEDATADIR__' "launch template for $kind must set MINIMAX_DATA_DIR"
  assert_contains "$out" 'MCODE_CONFIG_DIR=__MCODEDIR__' "launch template for $kind must set MCODE_CONFIG_DIR"
  assert_contains "$out" 'mcode ' "launch template for $kind must invoke mcode"
  assert_contains "$out" '__MODELFLAG__' "launch template for $kind must include __MODELFLAG__"
  # shellcheck disable=SC2016  # the single quotes are the literal template text under test
  assert_contains "$out" '"$(__OPINPUT__ encode launch-brief < __BRIEF__)"' "launch template for $kind must pass encoded brief as positional argument"
done
pass 'launch_template produces a valid template for minimax-code ship, scout, and secondmate'

# The two directories must be DIFFERENT placeholders. A template that pointed
# MINIMAX_DATA_DIR at the per-task dir would make every spawned mcode agent ask
# for a login, because the OAuth credential is keyed on the literal auth-home
# path.
out=$(launch_template minimax-code ship)
case "$out" in
  *'MINIMAX_DATA_DIR=__MCODEDIR__'*)
    fail 'launch template must NOT point MINIMAX_DATA_DIR at the per-task dir (mcode keys its OAuth credential on the literal auth-home path)'
    ;;
  *) : ;;
esac
assert_contains "$out" 'MINIMAX_DATA_DIR=__MCODEDATADIR__ MCODE_CONFIG_DIR=__MCODEDIR__' \
  'launch template must keep the data dir and the config dir as separate placeholders'
pass 'launch_template keeps the minimax-code data dir and config dir as separate paths'

# Model flag assertion. The live slug is minimax/MiniMax-M3.1-Flash; the older
# minimax/MiniMax-M3.1-Flash-Preview slug is retired.
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

# Full substitution check: resolve launch command with model, brief, and both dirs.
# The data dir is the REAL one and the config dir is the per-task one, and the
# two must differ.
BRIEF="/path/to/brief.md"
MCODEDIR="/tmp/fm-test-task/mcode"
MCODEDATADIR="/home/agent/.minimax"
sq_brief=$(shell_quote "$BRIEF")
sq_mcodedir=$(shell_quote "$MCODEDIR")
sq_mcodedatadir=$(shell_quote "$MCODEDATADIR")
sq_opinput=$(shell_quote "$ROOT/bin/fm-operational-input.sh")
MODELFLAG=$(model_flag_for_harness minimax-code "minimax/MiniMax-M3.1-Flash")
LAUNCH=$(launch_template minimax-code ship)
LAUNCH=${LAUNCH//__MODELFLAG__/$MODELFLAG}
LAUNCH=${LAUNCH//__BRIEF__/$sq_brief}
LAUNCH=${LAUNCH//__OPINPUT__/$sq_opinput}
LAUNCH=${LAUNCH//__MCODEDIR__/$sq_mcodedir}
LAUNCH=${LAUNCH//__MCODEDATADIR__/$sq_mcodedatadir}

assert_contains "$LAUNCH" "MINIMAX_DATA_DIR='/home/agent/.minimax' MCODE_CONFIG_DIR='/tmp/fm-test-task/mcode' mcode --model 'minimax/MiniMax-M3.1-Flash' " 'resolved launch must carry the real data dir, the per-task config dir, mcode and --model'
case "$LAUNCH" in
  *"MINIMAX_DATA_DIR='/tmp/fm-test-task/mcode'"*)
    fail 'resolved launch must NOT point MINIMAX_DATA_DIR at the per-task dir (mcode keys its OAuth credential on the literal auth-home path)'
    ;;
  *) : ;;
esac
case "$LAUNCH" in
  *"MCODE_CONFIG_DIR='/tmp/fm-test-task/mcode'"*) : ;;
  *) fail 'resolved launch must point MCODE_CONFIG_DIR at the per-task dir' ;;
esac
expected_brief_arg="\"\$('$ROOT/bin/fm-operational-input.sh' encode launch-brief < '/path/to/brief.md')\""
assert_contains "$LAUNCH" "$expected_brief_arg" 'resolved launch must contain encoded brief positional argument'

pass "fully resolved minimax-code launch command is well-formed bash with split data and config dirs, model, and encoded brief"
echo
