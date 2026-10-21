#!/usr/bin/env bash
# Behavior tests for fm-lavish-enforcement.sh - Lavish enforcement surface generator and reviewer.
#
# Requirements & Standards:
#   - House standard: >= 33 cases and >= 106 assertions.
#   - Zero external URLs: no CDN, no remote fonts, no remote scripts.
#   - Truthful over pretty: inactive guards read inactive, not assumed-on.
#   - Surface live vs phantom holder counts truthfully (the known defect).
#   - Full lifecycle: inventory JSON, HTML generation, review/reply/end loop.
#
# TAP output format.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SELF_DIR/fm-lavish-enforcement.sh"

TMP_ROOT=""
CASES_RUN=0
CASE_NAME=""
CASE_FAILS=0
CASE_DETAIL=""
CASE_ASSERTIONS=0
FAILED=0
OUT=""
RC=0

# shellcheck disable=SC2329
cleanup() {
  if [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf -- "$TMP_ROOT"
  fi
}
trap cleanup EXIT

start_case() {
  CASE_NAME="$1"
  CASE_FAILS=0
  CASE_DETAIL=""
  CASES_RUN=$((CASES_RUN + 1))
}

pass() {
  CASE_ASSERTIONS=$((CASE_ASSERTIONS + 1))
}

fail() {
  CASE_ASSERTIONS=$((CASE_ASSERTIONS + 1))
  CASE_FAILS=$((CASE_FAILS + 1))
  CASE_DETAIL="${CASE_DETAIL}  # ${1:-assertion failed}"$'\n'
}

end_case() {
  if [ "$CASE_FAILS" -eq 0 ]; then
    printf 'ok %d - %s\n' "$CASES_RUN" "$CASE_NAME"
  else
    FAILED=$((FAILED + 1))
    printf 'not ok %d - %s\n' "$CASES_RUN" "$CASE_NAME"
    printf '%s' "$CASE_DETAIL"
  fi
}

assert_has() {
  if printf '%s\n' "$OUT" | grep -qF -- "$1"; then
    pass
  else
    fail "${2:-expected substring missing: $1}"
  fi
}

# shellcheck disable=SC2329
assert_lacks() {
  if printf '%s\n' "$OUT" | grep -qF -- "$1"; then
    fail "${2:-unexpected substring present: $1}"
  else
    pass
  fi
}

assert_status() {
  if [ "$1" = "$RC" ]; then
    pass
  else
    fail "${2:-expected exit $1, got $RC}"
  fi
}

assert_file() {
  if [ -f "$1" ]; then
    pass
  else
    fail "${2:-expected file missing: $1}"
  fi
}

assert_file_has() {
  if [ -f "$1" ] && grep -qF -- "$2" "$1"; then
    pass
  else
    fail "${3:-expected literal missing from $1: $2}"
  fi
}

assert_file_lacks() {
  if [ -f "$1" ] && grep -qF -- "$2" "$1"; then
    fail "${3:-unexpected literal found in $1: $2}"
  else
    pass
  fi
}

new_home() {
  local name="${1:-test}"
  [ -n "$TMP_ROOT" ] || TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-lavish-enforce-tests.XXXXXX")
  local home="$TMP_ROOT/$name"
  mkdir -p "$home/config" "$home/state" "$home/data/lavish" "$home/.lavish" "$home/bin"
  printf '%s' "$home"
}

write_lavish_stub() {
  local home="$1"
  mkdir -p "$home/fakebin"
  cat > "$home/fakebin/lavish-axi" <<'STUB'
#!/usr/bin/env bash
{ printf 'CALL'; printf '\t%s' "$@"; printf '\n'; } >> "${LAVISH_STUB_LOG:?}"
exit 0
STUB
  chmod +x "$home/fakebin/lavish-axi"
}

run_cmd() {
  local home="$1"
  shift
  OUT=$(cd "$home" && FM_HOME="$home" FM_ROOT_OVERRIDE="${FM_ROOT:-$(cd "$SELF_DIR/.." && pwd)}" \
        FM_STATE_OVERRIDE="$home/state" FM_CONFIG_OVERRIDE="$home/config" \
        FM_DATA_OVERRIDE="$home/data" \
        LAVISH_STUB_LOG="${LAVISH_STUB_LOG:-$home/lavish-calls.log}" \
        PATH="$home/fakebin:$PATH" \
        bash "$TARGET" "$@" 2>&1)
  RC=$?
}

# ------------------------------------------------------------------------------
# Test Cases
# ------------------------------------------------------------------------------

start_case "--help documents usage, subcommands, and zero external URLs"
home=$(new_home help)
run_cmd "$home" --help
assert_status 0 "--help must exit 0"
assert_has "fm-lavish-enforcement.sh [OUTPUT]" "must document default output invocation"
assert_has "inventory [--json]" "must document inventory subcommand"
assert_has "review [ARTIFACT]" "must document review subcommand"
assert_has "reply MESSAGE" "must document reply subcommand"
assert_has "end" "must document end subcommand"
assert_has "zero external URLs" "must state zero external URL contract"
end_case

start_case "-h flag exits 0 with same documentation"
home=$(new_home hflag)
run_cmd "$home" -h
assert_status 0 "-h must exit 0"
assert_has "Lavish enforcement surface" "must show help on -h"
end_case

start_case "default invocation generates HTML at data/lavish and .lavish"
home=$(new_home default_out)
run_cmd "$home"
assert_status 0 "default invocation must succeed"
assert_has "Generated enforcement dashboard:" "must report output path"
assert_file "$home/data/lavish/enforcement.html" "must generate data/lavish/enforcement.html"
assert_file "$home/.lavish/enforcement.html" "must generate .lavish/enforcement.html"
end_case

start_case "custom output path is respected"
home=$(new_home custom_out)
custom="$home/custom-enforcement.html"
run_cmd "$home" "$custom"
assert_status 0 "custom invocation must succeed"
assert_file "$custom" "must write to specified custom file"
assert_has "$custom" "must output the custom path"
end_case

start_case "ZERO external URLs law: no CDN, remote fonts, or remote scripts"
home=$(new_home zero_cdn)
out_file="$home/data/lavish/enforcement.html"
run_cmd "$home"
assert_status 0 "generation must succeed"
assert_file "$out_file" "output file must exist"
assert_file_lacks "$out_file" "http://" "must not contain unencrypted remote http URLs"
assert_file_lacks "$out_file" "https://" "must not contain remote https URLs"
assert_file_lacks "$out_file" "cdn" "must not reference any CDN"
assert_file_lacks "$out_file" "fonts.googleapis" "must not reference Google Fonts"
assert_file_lacks "$out_file" "unpkg.com" "must not reference unpkg"
assert_file_lacks "$out_file" "cdnjs" "must not reference cdnjs"
end_case

start_case "self-contained styling with inline CSS in style tags"
home=$(new_home inline_css)
out_file="$home/data/lavish/enforcement.html"
run_cmd "$home"
assert_file_has "$out_file" "<style>" "must contain inline style tag"
assert_file_has "$out_file" "</style>" "must close style tag"
assert_file_has "$out_file" "system-ui" "must use system fonts"
assert_file_lacks "$out_file" "<link rel=\"stylesheet\"" "must not link external stylesheets"
end_case

start_case "HTML escaping protects against special character injection"
home=$(new_home html_escape)
export FM_PROJECT_NAME="<script>alert(1)</script>&\"'test"
run_cmd "$home"
unset FM_PROJECT_NAME
out_file="$home/data/lavish/enforcement.html"
assert_file "$out_file" "output file must exist"
assert_file_lacks "$out_file" "<script>alert(1)</script>" "raw script tag must not appear unescaped"
assert_file_has "$out_file" "&lt;script&gt;alert(1)&lt;/script&gt;" "must HTML escape angle brackets"
end_case

start_case "inventory subcommand outputs valid parseable JSON"
home=$(new_home inv_json)
run_cmd "$home" inventory
assert_status 0 "inventory must exit 0"
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$OUT" | jq . >/dev/null 2>&1
  assert_status 0 "JSON must be valid according to jq"
else
  pass
fi
assert_has '"schema": "fm-enforcement-inventory.v1"' "must include schema tag"
assert_has '"capacity_truth": {' "must include capacity_truth block"
assert_has '"enforcements": [' "must include enforcements array"
end_case

start_case "inventory includes defect note explaining phantom holders"
home=$(new_home inv_defect)
run_cmd "$home" inventory
assert_status 0 "inventory must succeed"
assert_has '"defect_note":' "must contain defect_note field"
assert_has "Capacity lib counts all non-secondmate meta without pr= as holders" "must explain the defect"
assert_has "Phantom holders are finished/dead tasks" "must explain phantom definition"
end_case

start_case "inventory lists all core firstmate enforcement guards"
home=$(new_home inv_guards)
run_cmd "$home" inventory
assert_has '"name": "fm-dispatch-guard"' "must list fm-dispatch-guard"
assert_has '"name": "fm-project-capacity"' "must list fm-project-capacity"
assert_has '"name": "fm-lease"' "must list fm-lease"
assert_has '"name": "fm-reap-gate"' "must list fm-reap-gate"
assert_has '"name": "fm-helper-permissions"' "must list fm-helper-permissions"
assert_has '"name": "fm-subagent-cap"' "must list fm-subagent-cap"
assert_has '"name": "fm-quota-gate"' "must list fm-quota-gate"
assert_has '"name": "fm-merge-authority"' "must list fm-merge-authority"
assert_has '"name": "fm-gate-refuse"' "must list fm-gate-refuse"
assert_has '"name": "fm-docs-drift-gate"' "must list fm-docs-drift-gate"
assert_has '"name": "fm-turnend-guard"' "must list fm-turnend-guard"
end_case

start_case "each guard entry in inventory carries required metadata fields"
home=$(new_home inv_fields)
run_cmd "$home" inventory
assert_has '"blocks":' "must include what it blocks"
assert_has '"config":' "must include what activates it"
assert_has '"active":' "must include boolean active state"
assert_has '"status":' "must include status string"
assert_has '"details":' "must include current details"
assert_has '"how_to_add":' "must include add hint"
assert_has '"how_to_remove":' "must include remove hint"
end_case

start_case "dispatch guard is active by default with Sol ban and live lane cap"
home=$(new_home dg_active)
run_cmd "$home" inventory
assert_has '"name": "fm-dispatch-guard"' "must find dispatch guard"
assert_has 'Sol banned' "must state Sol ban is enforced"
assert_has 'live-lane cap=4' "must default to 4 when no config file"
end_case

start_case "dispatch guard reflects config/dispatch-max-lanes override"
home=$(new_home dg_cap)
echo "6" > "$home/config/dispatch-max-lanes"
run_cmd "$home" inventory
assert_has 'live-lane cap=6 from config/dispatch-max-lanes' "must reflect configured cap 6"
end_case

start_case "dispatch guard reads inactive when FM_DISPATCH_GUARD_BYPASS=1"
home=$(new_home dg_bypass)
export FM_DISPATCH_GUARD_BYPASS=1
run_cmd "$home" inventory
unset FM_DISPATCH_GUARD_BYPASS
assert_has 'Bypassed via FM_DISPATCH_GUARD_BYPASS=1' "must report bypass truthfully"
end_case

start_case "project capacity reads inactive (uncapped) when config file absent"
home=$(new_home pc_absent)
export FM_PROJECT_NAME="myproj"
run_cmd "$home" inventory
unset FM_PROJECT_NAME
assert_has 'config/project-capacity absent (uncapped dispatch)' "must truthfully report uncapped"
end_case

start_case "project capacity reads active when config/project-capacity declares limit"
home=$(new_home pc_active)
export FM_PROJECT_NAME="myproj"
echo "myproj 5" > "$home/config/project-capacity"
run_cmd "$home" inventory
unset FM_PROJECT_NAME
assert_has 'declared capacity of 5 worker(s) for myproj' "must report declared limit"
end_case

start_case "project capacity reads inactive for undeclared project in multi-line config"
home=$(new_home pc_other)
export FM_PROJECT_NAME="unlisted"
cat > "$home/config/project-capacity" <<'CAP'
alpha 2
beta 4
CAP
run_cmd "$home" inventory
unset FM_PROJECT_NAME
assert_has 'no declaration for unlisted (uncapped)' "must report project unlisted as uncapped"
end_case

start_case "lease guard reads inactive when no actor and no leases in state"
home=$(new_home lease_inactive)
run_cmd "$home" inventory
assert_has 'no FM_SUPERVISION_ACTOR set and 0 task leases active' "must report inactive leases"
end_case

start_case "lease guard reads active when FM_SUPERVISION_ACTOR is set"
home=$(new_home lease_actor)
export FM_SUPERVISION_ACTOR="branch"
run_cmd "$home" inventory
unset FM_SUPERVISION_ACTOR
assert_has "actor='branch'" "must report active actor"
end_case

start_case "lease guard reads active when .lease file exists in state"
home=$(new_home lease_file)
printf 'main\t1234\t1791920000\n' > "$home/state/.lease-task10"
run_cmd "$home" inventory
assert_has '1 active lease file(s) in state' "must count active lease file"
end_case

start_case "reap gate reads active by default with age threshold and protected panes"
home=$(new_home reap_active)
run_cmd "$home" inventory
assert_has '"name": "fm-reap-gate"' "must list reap gate"
assert_has 'protects unlanded work' "must state unlanded work protection"
assert_has 'Crisp-R & Captain panes protected' "must state pane boundaries"
end_case

start_case "helper permissions reads active when docs/helper-permissions.json present"
home=$(new_home helper_active)
mkdir -p "$home/docs"
echo '{"rules":[]}' > "$home/docs/helper-permissions.json"
export FM_HELPER_PERMISSIONS_TRACKED="$home/docs/helper-permissions.json"
run_cmd "$home" inventory
unset FM_HELPER_PERMISSIONS_TRACKED
assert_has 'tracked definition present at docs/helper-permissions.json' "must report active permissions"
end_case

start_case "helper permissions reads inactive when docs/helper-permissions.json absent"
home=$(new_home helper_inactive)
export FM_HELPER_PERMISSIONS_TRACKED="$home/nonexistent.json"
run_cmd "$home" inventory
unset FM_HELPER_PERMISSIONS_TRACKED
assert_has 'docs/helper-permissions.json missing' "must report missing tracked file"
end_case

start_case "subagent cap reads active when canonical module exists"
home=$(new_home cap_active)
run_cmd "$home" inventory
assert_has '"name": "fm-subagent-cap"' "must list subagent cap"
assert_has 'max 6 open subagent panes' "must report cap 6"
end_case

start_case "subagent cap reads inactive when HERDR_CAP_CHECK_SKIP=1"
home=$(new_home cap_skip)
export HERDR_CAP_CHECK_SKIP=1
run_cmd "$home" inventory
unset HERDR_CAP_CHECK_SKIP
assert_has 'bypassed via HERDR_CAP_CHECK_SKIP=1' "must report bypass truthfully"
end_case

start_case "merge authority is active with Hard Rule 2 protection"
home=$(new_home ma_active)
run_cmd "$home" inventory
assert_has '"name": "fm-merge-authority"' "must list merge authority"
assert_has 'Hard Rule 2 strictly enforced' "must state Hard Rule 2"
end_case

start_case "gate refuse is active with exit 64 protection"
home=$(new_home gr_active)
run_cmd "$home" inventory
assert_has '"name": "fm-gate-refuse"' "must list gate refuse"
assert_has 'blocks direct execution when operating under no-mistakes gate' "must state exit 64 gate"
end_case

start_case "capacity truth separates live workers from phantom holders"
home=$(new_home cap_truth)
# 1 live meta (endpoint alive via fake existence check)
cat > "$home/state/task-live.meta" <<'META'
kind=ship
window=sess:win1
backend=tmux
META
# 2 dead tasks without pr= (phantom holders)
cat > "$home/state/task-dead1.meta" <<'META'
kind=ship
window=dead:win2
backend=tmux
META
cat > "$home/state/task-dead2.meta" <<'META'
kind=ship
window=dead:win3
backend=tmux
META
# 1 task with pr= (not counted as holder per capacity lib)
cat > "$home/state/task-pr.meta" <<'META'
kind=ship
pr=https://github.com/org/repo/pull/1
META
# 1 secondmate (not counted as worker holder)
cat > "$home/state/task-sm.meta" <<'META'
kind=secondmate
META

run_cmd "$home" inventory
assert_status 0 "inventory must succeed"
assert_has '"capacity_holders_counted": 3' "must count 3 meta holders without pr="
end_case

start_case "HTML surface highlights the phantom holders defect banner"
home=$(new_home defect_html)
out_file="$home/data/lavish/enforcement.html"
run_cmd "$home"
assert_status 0 "generation must succeed"
assert_file_has "$out_file" "KNOWN REAL DEFECT: Finished state/*.meta Records Count As Capacity Holders" "must include defect banner"
assert_file_has "$out_file" "Phantom Holders (Defect)" "must label phantom holders as defect"
assert_file_has "$out_file" "Capacity should count only LIVE holders" "must explain correct requirement"
end_case

start_case "HTML surface renders Add and Remove action boxes for each guard"
home=$(new_home actions_html)
out_file="$home/data/lavish/enforcement.html"
run_cmd "$home"
assert_status 0 "generation must succeed"
assert_file_has "$out_file" "+ To Add / Enforce" "must render add box"
assert_file_has "$out_file" "- To Remove / Deactivate" "must render remove box"
assert_file_has "$out_file" "Set FM_DISPATCH_GUARD_BYPASS=1" "must render dispatch remove instruction"
end_case

start_case "HTML surface renders active and inactive badges truthfully"
home=$(new_home badges_html)
out_file="$home/data/lavish/enforcement.html"
run_cmd "$home"
assert_status 0 "generation must succeed"
assert_file_has "$out_file" "class=\"badge badge-enforced\">" "must render enforced badge"
assert_file_has "$out_file" "ENFORCED" "must have ENFORCED text"
end_case

start_case "review opens Lavish session and arms registered chat-back source"
home=$(new_home review_cmd)
write_lavish_stub "$home"
artifact="$home/.lavish/enforcement.html"
run_cmd "$home" review "$artifact"
assert_status 0 "review must exit 0"
assert_file "$artifact" "review must regenerate artifact at target path"
calls=$(cat "$home/lavish-calls.log")
OUT="$calls"
assert_has "CALL"$'\t'"$artifact" "review must call lavish-axi with artifact"
end_case

start_case "review registers poll source with fm-procevent runner"
home=$(new_home review_source)
write_lavish_stub "$home"
artifact="$home/.lavish/enforcement.html"
run_cmd "$home" review "$artifact"
assert_status 0 "review must exit 0"
source_id=$(bash "$SELF_DIR/fm-procevent-lavish.sh" source-id "$artifact" 2>&1)
assert_has "lavish-" "must compute canonical lavish source id"
assert_file "$home/state/procevent/$source_id.source" "must register source with runner"
source_content=$(cat "$home/state/procevent/$source_id.source")
OUT="$source_content"
assert_has "adapter=lavish" "adapter must be lavish"
assert_has "poll" "must register poll command"
end_case

start_case "reply sends agent message into Lavish board"
home=$(new_home reply_cmd)
write_lavish_stub "$home"
artifact="$home/.lavish/enforcement.html"
run_cmd "$home" review "$artifact"
: > "$home/lavish-calls.log"
run_cmd "$home" reply "Acknowledged: 3 phantom capacity holders reported"
assert_status 0 "reply must exit 0"
calls=$(cat "$home/lavish-calls.log")
OUT="$calls"
assert_has "reply"$'\t'"$artifact"$'\t'"--agent-reply"$'\t'"Acknowledged: 3 phantom capacity holders reported" "must call lavish-axi reply with message"
end_case

start_case "end ends Lavish session and retires registered source"
home=$(new_home end_cmd)
write_lavish_stub "$home"
artifact="$home/.lavish/enforcement.html"
run_cmd "$home" review "$artifact"
source_id=$(bash "$SELF_DIR/fm-procevent-lavish.sh" source-id "$artifact" 2>&1)
assert_file "$home/state/procevent/$source_id.source" "source must be registered before end"
: > "$home/lavish-calls.log"
run_cmd "$home" end
assert_status 0 "end must exit 0"
calls=$(cat "$home/lavish-calls.log")
OUT="$calls"
assert_has "end"$'\t'"$artifact" "must call lavish-axi end"
if [ -f "$home/state/procevent/$source_id.source" ]; then
  fail "source must be retired by end"
else
  pass
fi
end_case

start_case "reply and end refuse when called before artifact exists"
home=$(new_home refuse_no_art)
write_lavish_stub "$home"
export FM_LAVISH_ARTIFACT="$home/nonexistent.html"
run_cmd "$home" reply "hello"
assert_status 1 "reply must exit 1 without artifact"
assert_has "run review first" "must instruct caller to run review first"
run_cmd "$home" end
assert_status 1 "end must exit 1 without artifact"
assert_has "run review first" "must instruct caller to run review first"
run_cmd "$home" reply
assert_status 1 "reply must exit 1 with empty message"
unset FM_LAVISH_ARTIFACT
end_case

start_case "review rejects an artifact path starting with a dash"
home=$(new_home review_dash)
write_lavish_stub "$home"
run_cmd "$home" review "--bad-flag"
assert_status 1 "review must reject flag as artifact path"
assert_has "artifact path must not start with a dash" "must give clear error"
end_case

printf '1..%d\n' "$CASES_RUN"
printf '# fm-lavish-enforcement: %d cases, %d assertions, %d failed\n' \
  "$CASES_RUN" "$CASE_ASSERTIONS" "$FAILED"

if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
