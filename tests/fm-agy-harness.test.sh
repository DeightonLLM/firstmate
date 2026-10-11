#!/usr/bin/env bash
# AGY (Antigravity CLI) adapter tests for bin/fm-spawn.sh.
#
# These tests extract the real functions out of fm-spawn.sh and exercise them
# directly, so they prove the shipped script's behavior rather than a copy.
# They never launch an agent CLI: every assertion is on the produced launch
# template, the flag functions, and the turn-end hook artifacts.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPAWN="$ROOT/bin/fm-spawn.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-agy-harness.XXXXXX")
trap 'true' EXIT

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }
assert_contains() {
  case "$1" in *"$2"*) ;; *) fail "$3" ;; esac
}
assert_absent() {
  case "$1" in *"$2"*) fail "$3" ;; esac
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
for fn in launch_template model_flag_for_harness effort_flag_for_harness shell_quote real_path_or_raw agy_pretrust_workspace; do
  body=$(extract_fn "$fn")
  [ -n "$body" ] || fail "could not extract $fn from fm-spawn.sh"
  printf '%s\n' "$body" >> "$FUNCS"
done
# shellcheck source=/dev/null
. "$FUNCS"

# --- agy is a known harness -------------------------------------------------
for kind in ship scout secondmate; do
  out=$(launch_template agy "$kind") || fail "launch_template produced no template for agy kind=$kind"
  [ -n "$out" ] || fail "launch_template returned an empty template for agy kind=$kind"
done
pass 'launch_template produces a real template for agy ship, scout, and secondmate'

# Every kind must launch the supervised INTERACTIVE agy TUI, never headless.
for kind in ship scout secondmate; do
  out=$(launch_template agy "$kind")
  assert_contains "$out" 'agy ' "agy $kind template must invoke the agy executable"
  assert_contains "$out" '--prompt-interactive' "agy $kind template must run the interactive TUI"
  assert_absent "$out" '--print' "agy $kind template must never use headless --print"
  assert_absent "$out" '-p ' "agy $kind template must never use the -p one-shot alias"
done
pass 'every agy kind launches the interactive TUI, never a headless one-shot'

# Autonomy: an unattended crewmate cannot answer a permission prompt.
out=$(launch_template agy ship)
assert_contains "$out" '--dangerously-skip-permissions' 'agy template must auto-approve tool permissions'
pass 'agy template auto-approves tool permissions'

# The brief is delivered as a single encoded prompt argument.
out=$(launch_template agy ship)
assert_contains "$out" '__OPINPUT__ encode launch-brief < __BRIEF__' 'agy template must encode the brief as its initial prompt'
assert_absent "$out" '__TURNEND__' 'agy turn-end signal is a hook, not a launch-command placeholder'
pass 'agy template delivers the encoded brief as the interactive initial prompt'

# --- model and effort flags are threaded ------------------------------------
got=$(model_flag_for_harness agy gemini-3.1-pro-high)
assert_contains "$got" '--model' 'agy model flag must use --model'
assert_contains "$got" 'gemini-3.1-pro-high' 'agy model flag must carry the requested model slug'
pass 'model_flag_for_harness threads --model for agy'

for effort in low medium high xhigh max; do
  got=$(effort_flag_for_harness agy "$effort")
  assert_contains "$got" '--effort' "agy effort $effort must use --effort"
  assert_contains "$got" "$effort" "agy effort flag must carry $effort"
done
pass 'effort_flag_for_harness threads --effort for the full agy vocabulary'

# Empty/default axes must emit nothing rather than an empty-valued flag.
[ -z "$(model_flag_for_harness agy '')" ] || fail 'agy empty model must emit no flag'
[ -z "$(model_flag_for_harness agy default)" ] || fail 'agy default model must emit no flag'
[ -z "$(effort_flag_for_harness agy '')" ] || fail 'agy empty effort must emit no flag'
[ -z "$(effort_flag_for_harness agy default)" ] || fail 'agy default effort must emit no flag'
pass 'agy emits no flag for empty or default model/effort axes'

# The shipped template actually contains the model/effort placeholders.
out=$(launch_template agy ship)
assert_contains "$out" '__MODELFLAG__' 'agy template must carry the model flag placeholder'
assert_contains "$out" '__EFFORTFLAG__' 'agy template must carry the effort flag placeholder'
pass 'agy template carries the model and effort placeholders'

# An unknown adapter must still be refused (agy must not weaken the guard).
if launch_template definitely-not-a-harness ship >/dev/null 2>&1; then
  fail 'launch_template must still refuse an unknown harness'
fi
pass 'launch_template still refuses unknown harnesses'

# --- turn-end signal --------------------------------------------------------
# fm-spawn installs agy's Stop hook here; assert the real branch exists and is
# reachable for crew tasks but skipped for secondmates (idle panes are healthy).
turnend_block=$(awk '
  /^    agy\*\)/ { inside = 1 }
  inside { print }
  inside && /^    ;;/ { exit }
' "$SPAWN")
[ -n "$turnend_block" ] || fail 'fm-spawn.sh has no agy turn-end hook installation branch'
assert_contains "$turnend_block" 'Stop' 'agy turn-end hook must register a Stop handler'
assert_contains "$turnend_block" '.fm-agy-turnend' 'agy turn-end hook must use a per-task worktree pointer'
assert_contains "$turnend_block" 'fm-turn-end.d' 'agy turn-end hook must use a firstmate-owned token registry'
assert_contains "$turnend_block" 'hooks.json' 'agy turn-end hook must be written into an agy hooks.json'
pass 'fm-spawn installs a guarded Stop-hook turn-end signal for agy'

# The global hooks file the installer writes must be agy's real global path.
assert_contains "$turnend_block" '.gemini/config/hooks.json' \
  'agy global hook must target agy shared user hooks.json'

# The hook script body must stay a guarded, silent no-op for non-firstmate
# sessions: it must read the workspace from the Stop payload's workspacePaths,
# require the token pointer, and resolve through the private registry.
hook_body=$(awk '
  /<<.AGY_HOOK_EOF./ { inside = 1; next }
  inside && /^AGY_HOOK_EOF$/ { exit }
  inside { print }
' "$SPAWN")
[ -n "$hook_body" ] || fail 'fm-spawn.sh does not define the agy turn-end hook script body'
assert_contains "$hook_body" 'workspacePaths' 'agy hook must read workspacePaths from the Stop payload'
assert_contains "$hook_body" '.fm-agy-turnend' 'agy hook must require the per-task pointer'
assert_contains "$hook_body" 'fm-turn-end.d' 'agy hook must resolve the token through the private registry'
assert_contains "$hook_body" 'exit 0' 'agy hook must stay a silent no-op on every path'
pass 'the agy turn-end hook is a guarded, silent, always-zero no-op'

# The hook must always emit an explicit JSON object; an empty stdout would be
# an invalid Stop result, so the contract "any other value allows the stop" is
# satisfied explicitly rather than by accident.
assert_contains "$hook_body" 'decision' 'agy hook must emit an explicit Stop decision object'
pass 'the agy turn-end hook emits an explicit Stop decision object'

# Secondmates must not install the crew turn-end pointer.
secondmate_skip=$(awk '
  /^    agy\*\)/ { inside = 1 }
  inside { print }
  inside && /^    ;;/ { exit }
' "$SPAWN")
assert_contains "$secondmate_skip" 'KIND' 'agy turn-end branch must branch on KIND'
assert_contains "$secondmate_skip" 'secondmate' 'agy turn-end branch must skip secondmates'
pass 'the agy turn-end hook is skipped for secondmate spawns'

# --- the installed hook artifact is a real, runnable, guarded hook ----------
# Build the registry + pointer the installer creates, run the shipped hook
# body against a realistic Stop payload, and prove it touches only the right
# marker. This exercises the actual heredoc, not a re-typed copy.
install_hook() {
  local fake_home=$1
  mkdir -p "$fake_home/.gemini/config"
  mkdir -p "$fake_home/.gemini/config/fm-turn-end.d"
  # Rewrite the literal home-derived paths in the shipped body to the fake home.
  sed -e "s#\${HOME:-}/.gemini/config#${fake_home}/.gemini/config#g" \
      -e "s#\${HOME:-}#$fake_home#g" <<EOF > "$fake_home/hook.sh"
$hook_body
EOF
  chmod +x "$fake_home/hook.sh"
}

STATE_DIR="$TMP_ROOT/state"
mkdir -p "$STATE_DIR"

FAKE_HOME="$TMP_ROOT/home"
install_hook "$FAKE_HOME"
REG="$FAKE_HOME/.gemini/config/fm-turn-end.d"

# Each case gets its OWN registry token and its OWN marker, so no case can be
# confused by a marker left behind by an earlier one. This also keeps the test
# free of any deletion, because recoverable deletion is unavailable on this host.
WT="$TMP_ROOT/wt"
mkdir -p "$WT"
n=0
new_case() {
  n=$((n + 1))
  MARKER="$STATE_DIR/agy-case-$n.turn-ended"
  case_token=$(mktemp "$REG/fm.XXXXXXXXXXXX")
  printf '%s\n' "$MARKER" > "$case_token"
  printf 'token=%s\n' "${case_token##*/}" > "$WT/.fm-agy-turnend"
}

new_case
payload=$(printf '{"executionNum":1,"terminationReason":"model_stop","fullyIdle":true,"workspacePaths":["%s"],"conversationId":"abc","modelName":"gemini-3.1-pro-high"}' "$WT")

out=$(printf '%s' "$payload" | "$FAKE_HOME/hook.sh" 2>/dev/null)
[ -f "$MARKER" ] || fail 'agy hook did not touch the turn-ended marker for a matching workspace'
assert_contains "$out" '"decision"' 'agy hook must emit a JSON decision object on stdout'
pass 'agy turn-end hook fires and touches the marker for its own workspace'

# Idempotent: a repeat Stop must stay silent and never fail.
out=$(printf '%s' "$payload" | "$FAKE_HOME/hook.sh" 2>/dev/null) || fail 'agy hook exited non-zero on a repeat Stop'
[ -f "$MARKER" ] || fail 'agy hook did not re-touch the marker on a repeat Stop'
pass 'the agy turn-end hook is idempotent and always exits zero'

# A DIFFERENT workspace (no pointer) must not touch anything: the global hook
# is installed once, so it must be inert for every non-firstmate agy session.
new_case
OTHER="$TMP_ROOT/other"
mkdir -p "$OTHER"
other_payload=$(printf '{"executionNum":1,"terminationReason":"model_stop","workspacePaths":["%s"]}' "$OTHER")
out=$(printf '%s' "$other_payload" | "$FAKE_HOME/hook.sh" 2>/dev/null) || fail 'agy hook exited non-zero for a foreign workspace'
[ -f "$MARKER" ] && fail 'agy hook fired for a workspace without a firstmate pointer'
pass 'the agy turn-end hook is inert for a non-firstmate agy workspace'

# A pointer naming a token that is NOT in the registry must not fire.
new_case
printf 'token=fm.doesnotexistxx\n' > "$WT/.fm-agy-turnend"
printf '%s' "$payload" | "$FAKE_HOME/hook.sh" >/dev/null 2>&1 || true
[ -f "$MARKER" ] && fail 'agy hook trusted an unregistered token'
pass 'the agy turn-end hook refuses an unregistered token'

# A malformed pointer must not fire either.
new_case
printf 'garbage\n' > "$WT/.fm-agy-turnend"
printf '%s' "$payload" | "$FAKE_HOME/hook.sh" >/dev/null 2>&1 || true
[ -f "$MARKER" ] && fail 'agy hook trusted a malformed pointer'
pass 'the agy turn-end hook refuses a malformed pointer'

# A registry entry pointing somewhere other than a *.turn-ended marker must
# not be followed: the registry can only ever touch a turn-ended marker.
new_case
evil=$(mktemp "$REG/fm.XXXXXXXXXXXX")
printf '%s\n' "$TMP_ROOT/pwned" > "$evil"
printf 'token=%s\n' "${evil##*/}" > "$WT/.fm-agy-turnend"
printf '%s' "$payload" | "$FAKE_HOME/hook.sh" >/dev/null 2>&1 || true
[ -e "$TMP_ROOT/pwned" ] && fail 'agy hook followed a registry entry that was not a turn-ended marker'
pass 'the agy turn-end hook only ever touches a *.turn-ended marker'

# Missing jq must fail closed and silently: emit the decision, touch nothing.
# The PATH keeps bash/cat/touch (the hook's real dependencies) but omits jq.
new_case
NOJQ_BIN="$TMP_ROOT/nojq-bin"
mkdir -p "$NOJQ_BIN"
for tool in bash cat touch; do
  real=$(command -v "$tool") || fail "could not locate $tool for the no-jq fixture"
  ln -sf "$real" "$NOJQ_BIN/$tool"
done
command -v jq >/dev/null 2>&1 && [ ! -e "$NOJQ_BIN/jq" ] || fail 'no-jq fixture must not contain jq'
out=$(printf '%s' "$payload" | PATH="$NOJQ_BIN" "$FAKE_HOME/hook.sh" 2>/dev/null) || fail 'agy hook must exit zero without jq'
[ -f "$MARKER" ] && fail 'agy hook must not fire without jq available'
assert_contains "$out" '"decision"' 'agy hook must still emit a valid Stop decision without jq'
pass 'the agy turn-end hook fails closed when jq is unavailable'

# An empty payload must still produce a valid Stop decision object, because the
# Stop contract requires a JSON object on stdout.
out=$(printf '' | "$FAKE_HOME/hook.sh" 2>/dev/null) || fail 'agy hook must exit zero on an empty payload'
assert_contains "$out" '"decision":"stop"' 'agy hook must emit decision=stop on an empty payload'
pass 'the agy turn-end hook always emits a valid Stop decision object'

# --- workspace trust pre-seeding ---------------------------------------------
# fm-spawn creates a NEW uniquely-pathed worktree for every spawn, so no static
# trustedWorkspaces list can ever cover them: agy would park on its interactive
# "Do you trust the contents of this project?" prompt. agy_pretrust_workspace
# must add the exact worktree path to the user's AGY trust store before launch.
# Every case below runs against a temp HOME or an explicit path, so the real
# ~/.gemini/antigravity-cli/settings.json on this host is never touched.

# The trust store is $HOME/.gemini/antigravity-cli/settings.json - a DIFFERENT
# subtree from $HOME/.gemini/config/, which only holds the shared-user
# hooks.json. Writing trust into the hooks directory would be a silent no-op.
pretrust_fn=$(extract_fn agy_pretrust_workspace)
assert_contains "$pretrust_fn" 'antigravity-cli/settings.json' \
  'trust must target agy real trust store antigravity-cli/settings.json'

# The store must resolve from the environment, never a hardcoded home: the
# Controller runs as root and Brandon Compute as hd2admin.
case "$pretrust_fn" in
  *'/root/'*) fail 'trust store path must not hardcode /root' ;;
esac
assert_contains "$pretrust_fn" 'HOME' 'trust store path must resolve from the environment'
pass 'the agy trust store resolves from the environment, with no hardcoded home'

# Spawn must call it before the agy launch command is sent to the pane.
pretrust_call_line=$(grep -n '^  agy_pretrust_workspace "\$WT" || {$' "$SPAWN" | head -1 | cut -d: -f1)
[ -n "$pretrust_call_line" ] || fail 'fm-spawn.sh never calls agy_pretrust_workspace unconditionally on its own line'
launch_line=$(grep -n 'spawn_send_literal "\$T" "\$LAUNCH"' "$SPAWN" | head -1 | cut -d: -f1)
[ -n "$launch_line" ] || fail 'could not locate the launch dispatch line in fm-spawn.sh'
[ "$pretrust_call_line" -lt "$launch_line" ] || fail 'trust must be seeded BEFORE the agy launch command is sent'
wt_line=$(grep -n 'WT="\$PROJ_ABS"\|WT="\$p"\|WT=\${rest' "$SPAWN" | tail -1 | cut -d: -f1)
[ -n "$wt_line" ] || fail 'could not locate worktree assignment in fm-spawn.sh'
[ "$pretrust_call_line" -gt "$wt_line" ] || fail 'trust must be seeded only after the worktree path is known'
pass 'fm-spawn seeds agy workspace trust after the worktree exists and before launch'

# The call must be agy-only: no other harness may be affected.
pretrust_case=$(awk -v n="$pretrust_call_line" 'NR>=n-4 && NR<=n' "$SPAWN")
assert_contains "$pretrust_case" 'agy' 'the trust pre-seed must be gated on the agy harness'
case "$pretrust_case" in
  *claude*|*codex*|*opencode*|*grok*|*kimi*|*pi-signed*) fail 'trust pre-seed must not affect other harnesses' ;;
esac
pass 'the workspace-trust pre-seed is gated to the agy harness only'

assert_eq() {
  [ "$1" = "$2" ] || fail "$3 (expected '$2', got '$1')"
}

# Case 1: an untrusted path gets added, into the real store location, with no
# other keys disturbed.
TRUST_HOME="$TMP_ROOT/trust-home"
SETTINGS="$TRUST_HOME/.gemini/antigravity-cli/settings.json"
WT_NEW="$TMP_ROOT/new-worktree"
mkdir -p "$WT_NEW"
mkdir -p "$(dirname "$SETTINGS")"
printf '%s\n' '{"allowNonWorkspaceAccess":true,"permissions":{"allow":["command(ls)"],"deny":[]}}' > "$SETTINGS"
before_other=$(jq -S '.permissions, .allowNonWorkspaceAccess' "$SETTINGS")
( agy_pretrust_workspace "$WT_NEW" "$TRUST_HOME" ) || fail 'trust pre-seed failed on a well-formed store'
jq -e . "$SETTINGS" >/dev/null 2>&1 || fail 'trust store did not parse after the merge'
got=$(jq -r '.trustedWorkspaces | index("'"$WT_NEW"'") // "missing"' "$SETTINGS")
assert_eq "$got" '0' 'the new worktree must be present in trustedWorkspaces'
pass 'an untrusted worktree path is added to the AGY trust store'

after_other=$(jq -S '.permissions, .allowNonWorkspaceAccess' "$SETTINGS")
assert_eq "$after_other" "$before_other" 'permissions and allowNonWorkspaceAccess must survive byte-identically'
pass 'other top-level keys (permissions, allowNonWorkspaceAccess) survive unchanged'

# Case 2: every pre-existing trusted path is preserved exactly, including
# entries with spaces, quotes, unicode, and JSON metacharacters.
UNI="$TMP_ROOT/uni-home"
mkdir -p "$UNI/.gemini/antigravity-cli"
UNIS="$UNI/.gemini/antigravity-cli/settings.json"
WEIRD=(
  '/home/hd2admin'
  '/home/hd2admin/firstmate baseline'
  '/home/hd2admin/quote"and\backslash'
  "/home/hd2admin/tab	and newline"
  '/home/hd2admin/ünïcode-路径'
  '/home/hd2admin/a[b]{c}*?'
  "$WT_NEW"
)
jq -nc --args '{allowNonWorkspaceAccess:false, trustedWorkspaces:$ARGS.positional}' "${WEIRD[@]}" > "$UNIS"
( agy_pretrust_workspace "$WT_NEW" "$UNI" ) || fail 'trust pre-seed failed on a store with unusual paths'
for w in "${WEIRD[@]}"; do
  jq -e --arg w "$w" '.trustedWorkspaces | index($w) != null' "$UNIS" >/dev/null 2>&1 \
    || fail "pre-existing trusted path was dropped: $w"
done
assert_eq "$(jq -r '.trustedWorkspaces | length' "$UNIS")" "${#WEIRD[@]}" \
  'an already-trusted path must not be duplicated'
pass 'every pre-existing trusted path survives exactly, including unusual characters'

# Case 3: idempotent - running twice must not duplicate the entry.
( agy_pretrust_workspace "$WT_NEW" "$UNI" ) || fail 'trust pre-seed failed on the second run'
assert_eq "$(jq -r '.trustedWorkspaces | length' "$UNIS")" "${#WEIRD[@]}" \
  're-running trust pre-seed must be idempotent'
pass 're-seeding an already-trusted path does not duplicate the entry'

# Case 4: a missing settings.json is created rather than treated as fatal.
FRESH_HOME="$TMP_ROOT/fresh-home"
mkdir -p "$WT_NEW/child"
( agy_pretrust_workspace "$WT_NEW" "$FRESH_HOME" ) || fail 'trust pre-seed must create a missing settings.json'
FRESH_SETTINGS="$FRESH_HOME/.gemini/antigravity-cli/settings.json"
[ -f "$FRESH_SETTINGS" ] || fail "a missing settings.json was not created at $FRESH_SETTINGS"
jq -e . "$FRESH_SETTINGS" >/dev/null 2>&1 || fail 'the created settings.json is not valid JSON'
assert_eq "$(jq -r '.trustedWorkspaces | length' "$FRESH_SETTINGS")" '1' \
  'the created settings.json must contain just the new path'
pass 'a missing settings.json is created containing just trustedWorkspaces'

# Case 5: malformed JSON aborts with a clear message and is NOT overwritten.
BAD_HOME="$TMP_ROOT/bad-home"
mkdir -p "$BAD_HOME/.gemini/antigravity-cli"
BADS="$BAD_HOME/.gemini/antigravity-cli/settings.json"
BROKEN='{"trustedWorkspaces": ["/home/hd2admin",}'
printf '%s\n' "$BROKEN" > "$BADS"
err=$(agy_pretrust_workspace "$WT_NEW" "$BAD_HOME" 2>&1) && fail 'malformed settings.json must abort the trust pre-seed'
assert_contains "$err" 'valid JSON' 'malformed settings.json must produce an actionable error'
assert_contains "$err" "$BADS" 'the error must name the offending file'
assert_eq "$(cat "$BADS")" "$BROKEN" 'malformed settings.json must be left byte-identical'
pass 'malformed JSON aborts with a clear message and does not overwrite the file'

# Case 6: a non-regular (symlinked) store fails closed rather than being followed.
LINK_HOME="$TMP_ROOT/link-home"
mkdir -p "$LINK_HOME/.gemini/antigravity-cli"
REAL_S="$TMP_ROOT/link-target.json"
printf '%s\n' '{"trustedWorkspaces":[]}' > "$REAL_S"
ln -sf "$REAL_S" "$LINK_HOME/.gemini/antigravity-cli/settings.json"
err=$(agy_pretrust_workspace "$WT_NEW" "$LINK_HOME" 2>&1) && fail 'a symlinked trust store must fail closed'
assert_contains "$err" 'regular file' 'a symlinked store must produce an actionable error'
assert_eq "$(cat "$REAL_S")" '{"trustedWorkspaces":[]}' 'the symlink target must be untouched'
pass 'a symlinked trust store fails closed without touching its target'

# Case 7: the written JSON always parses afterwards, and the merge never drops
# the captain's key order-independent values.
final=$(jq -cS . "$UNI/.gemini/antigravity-cli/settings.json") || fail 'final trust store does not parse'
assert_contains "$final" 'allowNonWorkspaceAccess' 'the merged store must keep allowNonWorkspaceAccess'
pass 'the written trust store parses afterwards with every key intact'

# The store path must default to $HOME so a normal spawn needs no override.
home_line=$(printf '%s' "$pretrust_fn" | grep -n 'HOME' | head -1)
[ -n "$home_line" ] || fail 'agy_pretrust_workspace does not consult HOME at all'
DEFAULT_HOME="$TMP_ROOT/default-home"
mkdir -p "$WT_NEW/deep"
( HOME="$DEFAULT_HOME" agy_pretrust_workspace "$WT_NEW" ) || fail 'trust pre-seed must work with no explicit override'
[ -f "$DEFAULT_HOME/.gemini/antigravity-cli/settings.json" ] \
  || fail 'agy_pretrust_workspace did not default to $HOME/.gemini/antigravity-cli/settings.json'
pass 'with no override the store defaults to $HOME, independent of the invoking user'

echo '1..26'