#!/usr/bin/env bash
# tests/fm-dispatch-one-file.test.sh - the ONE dispatch file.
#
# The Captain's directive (2026-10-21, stated four times) is that dispatch and
# routing live in ONE file, not five. config/dispatch.json owns the crew
# harness, the secondmate harness/model/effort, the lane ceilings, and the
# routing rules. Every legacy file stays supported as a COMPATIBILITY
# FALLBACK, is consulted second, and is never deleted.
#
# Every case here is asserted by observed behaviour, not by reading the code:
#   A) a legacy-only home resolves exactly as it did before (backward compat)
#   B) a dispatch.json-only home resolves everything (the one file is enough)
#   C) dispatch.json wins when both are present
#   D) the routing rules inside dispatch.json drive the resolver and bootstrap
#   E) the legacy routing file still drives the resolver and bootstrap unchanged
#   F) the one file propagates to a secondmate home
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

HARNESS="$ROOT/bin/fm-harness.sh"
BOOTSTRAP="$ROOT/bin/fm-bootstrap.sh"
RESOLVER="$ROOT/bin/fm-dispatch-resolve.sh"
TMP_ROOT=$(fm_test_tmproot fm-dispatch-one-file)
BASE_PATH=${FM_TEST_BASE_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}

# The harness-detection cases fake the environment so "own" is pinned and the
# assertions do not depend on which harness ran this suite.
unset CLAUDECODE PI_CODING_AGENT FM_PI_HARNESS GROK_AGENT ANTIGRAVITY_AGENT

# resolve <config-dir> <mode>: run one fm-harness.sh mode against one config
# dir with "own" pinned to claude, so only the CONFIG can decide the answer.
resolve() {
  local config_dir=$1 mode=$2
  env -u CLAUDECODE -u PI_CODING_AGENT -u GROK_AGENT -u ANTIGRAVITY_AGENT \
    CLAUDECODE=1 FM_CONFIG_OVERRIDE="$config_dir" "$HARNESS" "$mode"
}

# --- fixtures ---------------------------------------------------------------

LEGACY_CONFIG="$TMP_ROOT/legacy/config"
NEW_CONFIG="$TMP_ROOT/new/config"
BOTH_CONFIG="$TMP_ROOT/both/config"
mkdir -p "$LEGACY_CONFIG" "$NEW_CONFIG" "$BOTH_CONFIG"

# The legacy home: the five files that existed before the one file.
printf 'codex\n' > "$LEGACY_CONFIG/crew-harness"
printf 'grok grok-4 xhigh\n' > "$LEGACY_CONFIG/secondmate-harness"
printf '7\n' > "$LEGACY_CONFIG/dispatch-max-lanes"
printf '3\n' > "$LEGACY_CONFIG/dispatch-max-provider-lanes"
printf '%s\n' '{"rules":[{"when":"legacy route rule","use":{"harness":"grok"}}]}' \
  > "$LEGACY_CONFIG/crew-dispatch.json"

# The one-file home: the same five concerns under one key set.
cat > "$NEW_CONFIG/dispatch.json" <<'JSON'
{
  "_comment": "ONE dispatch file.",
  "harness": "minimax-code",
  "model": "minimax/MiniMax-M3.1-Flash",
  "effort": "",
  "secondmate": { "harness": "minimax-code", "model": "minimax/MiniMax-M3.1-Flash", "effort": "" },
  "max_lanes": 12,
  "max_provider_lanes": 6,
  "route": { "rules": [ { "when": "one file route rule", "use": { "harness": "minimax-code", "provider": "minimax" } } ] }
}
JSON

# A home with both: the one file wins, the legacy files stay untouched.
cp "$LEGACY_CONFIG/crew-harness" "$BOTH_CONFIG/crew-harness"
cp "$LEGACY_CONFIG/secondmate-harness" "$BOTH_CONFIG/secondmate-harness"
cp "$LEGACY_CONFIG/dispatch-max-lanes" "$BOTH_CONFIG/dispatch-max-lanes"
cp "$LEGACY_CONFIG/dispatch-max-provider-lanes" "$BOTH_CONFIG/dispatch-max-provider-lanes"
cp "$LEGACY_CONFIG/crew-dispatch.json" "$BOTH_CONFIG/crew-dispatch.json"
cat > "$BOTH_CONFIG/dispatch.json" <<'JSON'
{
  "harness": "minimax-code",
  "model": "minimax/MiniMax-M3.1-Flash",
  "secondmate": { "harness": "minimax-code", "model": "minimax/MiniMax-M3.1-Flash" },
  "max_lanes": 12,
  "max_provider_lanes": 6,
  "route": { "rules": [ { "when": "one file route rule", "use": { "harness": "minimax-code", "provider": "minimax" } } ] }
}
JSON

# ===========================================================================
# A) A legacy-only home resolves exactly as it did before.
# ===========================================================================
test_legacy_home_is_unchanged() {
  local got
  got=$(resolve "$LEGACY_CONFIG" crew)
  [ "$got" = codex ] || fail "legacy crew harness resolved '$got', expected codex"
  got=$(resolve "$LEGACY_CONFIG" secondmate)
  [ "$got" = grok ] || fail "legacy secondmate harness resolved '$got', expected grok"
  got=$(resolve "$LEGACY_CONFIG" secondmate-model)
  [ "$got" = grok-4 ] || fail "legacy secondmate model resolved '$got', expected grok-4"
  got=$(resolve "$LEGACY_CONFIG" secondmate-effort)
  [ "$got" = xhigh ] || fail "legacy secondmate effort resolved '$got', expected xhigh"
  got=$(resolve "$LEGACY_CONFIG" dispatch-max-lanes)
  [ "$got" = 7 ] || fail "legacy lane cap resolved '$got', expected 7"
  got=$(resolve "$LEGACY_CONFIG" dispatch-max-provider-lanes)
  [ "$got" = 3 ] || fail "legacy provider cap resolved '$got', expected 3"
  got=$(resolve "$LEGACY_CONFIG" dispatch-route-source)
  [ "$got" = "config/crew-dispatch.json" ] \
    || fail "legacy routing source resolved '$got', expected config/crew-dispatch.json"
  # A legacy-only home configures NO route harness of its own beyond the
  # crew file, and the one-file keys resolve to nothing.
  got=$(resolve "$LEGACY_CONFIG" dispatch-model)
  [ -z "$got" ] || fail "legacy home reported a one-file model '$got'"
  got=$(resolve "$LEGACY_CONFIG" dispatch-route-json)
  [ -z "$got" ] || fail "legacy home reported one-file routing rules '$got'"
  pass "A1 a legacy-only home resolves exactly as before (harness, model, effort, caps, routing source)"
}

# ===========================================================================
# B) A dispatch.json-only home resolves everything: the one file is enough.
# ===========================================================================
test_one_file_home_resolves_everything() {
  local got
  got=$(resolve "$NEW_CONFIG" crew)
  [ "$got" = minimax-code ] || fail "one-file crew harness resolved '$got', expected minimax-code"
  got=$(resolve "$NEW_CONFIG" secondmate)
  [ "$got" = minimax-code ] || fail "one-file secondmate harness resolved '$got', expected minimax-code"
  got=$(resolve "$NEW_CONFIG" secondmate-model)
  [ "$got" = minimax/MiniMax-M3.1-Flash ] \
    || fail "one-file secondmate model resolved '$got', expected minimax/MiniMax-M3.1-Flash"
  got=$(resolve "$NEW_CONFIG" secondmate-effort)
  [ -z "$got" ] || fail "one-file secondmate effort resolved '$got', expected empty"
  got=$(resolve "$NEW_CONFIG" dispatch-model)
  [ "$got" = minimax/MiniMax-M3.1-Flash ] \
    || fail "one-file model resolved '$got', expected minimax/MiniMax-M3.1-Flash"
  got=$(resolve "$NEW_CONFIG" dispatch-max-lanes)
  [ "$got" = 12 ] || fail "one-file lane cap resolved '$got', expected 12"
  got=$(resolve "$NEW_CONFIG" dispatch-max-provider-lanes)
  [ "$got" = 6 ] || fail "one-file provider cap resolved '$got', expected 6"
  got=$(resolve "$NEW_CONFIG" dispatch-route-source)
  [ "$got" = "config/dispatch.json" ] \
    || fail "one-file routing source resolved '$got', expected config/dispatch.json"
  got=$(resolve "$NEW_CONFIG" dispatch-route-json)
  case "$got" in
    *'"one file route rule"'*) : ;;
    *) fail "one-file routing rules do not carry the rule: $got" ;;
  esac
  got=$(resolve "$NEW_CONFIG" dispatch-route-harness)
  [ "$got" = minimax-code ] || fail "one-file route harness resolved '$got', expected minimax-code"
  pass "B1 a dispatch.json-only home resolves the harness, the model, the effort, both caps, and the routing rules"
}

# ===========================================================================
# C) The one file wins when both are present, and the legacy files survive.
# ===========================================================================
test_one_file_wins_over_legacy() {
  local got
  got=$(resolve "$BOTH_CONFIG" crew)
  [ "$got" = minimax-code ] || fail "crew harness resolved '$got', expected the one-file value"
  got=$(resolve "$BOTH_CONFIG" secondmate)
  [ "$got" = minimax-code ] || fail "secondmate harness resolved '$got', expected the one-file value"
  got=$(resolve "$BOTH_CONFIG" secondmate-model)
  [ "$got" = minimax/MiniMax-M3.1-Flash ] \
    || fail "secondmate model resolved '$got', expected the one-file value"
  got=$(resolve "$BOTH_CONFIG" dispatch-max-lanes)
  [ "$got" = 12 ] || fail "lane cap resolved '$got', expected the one-file value 12"
  got=$(resolve "$BOTH_CONFIG" dispatch-route-source)
  [ "$got" = "config/dispatch.json" ] \
    || fail "routing source resolved '$got', expected config/dispatch.json"
  # The legacy files are consulted second, never rewritten, never deleted.
  [ -f "$BOTH_CONFIG/crew-harness" ] || fail "the one file deleted the legacy crew-harness"
  [ -f "$BOTH_CONFIG/crew-dispatch.json" ] || fail "the one file deleted the legacy crew-dispatch.json"
  [ "$(cat "$BOTH_CONFIG/crew-harness")" = codex ] || fail "the one file rewrote the legacy crew-harness"
  pass "C1 the one file wins when both are present, and the legacy files are left intact"
}

# ===========================================================================
# D) The routing rules inside the one file drive the resolver.
# ===========================================================================
make_resolver_fakebin() {
  local dir=$1 fakebin
  fakebin=$(fm_fakebin "$dir")
  cat > "$fakebin/curl" <<'SH'
#!/usr/bin/env bash
# Fake curl: records the request body it read from stdin, then answers with
# the canned response. No network, ever.
set -u
out=''
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    *) shift ;;
  esac
done
cat > "${FAKE_CURL_BODY:?}"
cp "${FAKE_CURL_RESPONSE:?}" "$out"
printf '%s' "${FAKE_CURL_HTTP:-200}"
SH
  chmod +x "$fakebin/curl"
  cat > "$fakebin/quota-axi" <<'SH'
#!/usr/bin/env bash
set -u
[ "${1:-}" = --json ] || exit 2
cat "${QUOTA_AXI_FIXTURE:?}"
SH
  chmod +x "$fakebin/quota-axi"
  printf '%s\n' "$fakebin"
}

test_resolver_reads_the_route_from_the_one_file() {
  local fakebin body out code
  fakebin=$(make_resolver_fakebin "$TMP_ROOT/resolver")
  body="$TMP_ROOT/resolver-body.json"
  cat > "$TMP_ROOT/resolver-response.json" <<'JSON'
{ "model": "jev-1.13.0",
  "answers": { "rule": { "type": "choice", "choice": "rule_1", "confidence": 0.9,
    "probabilities": { "rule_1": 0.9, "default": 0.1 } } },
  "usage": { "input_tokens": 10, "output_tokens": 5 } }
JSON
  cat > "$TMP_ROOT/resolver-quota.json" <<'JSON'
{ "generatedAt": "2030-01-01T00:00:00Z", "schemaVersion": 5, "providers": [
  { "provider": "minimax", "state": { "status": "fresh" }, "quotaSemantics": { "status": "known", "effectiveAvailability": [
    { "scope": "all_models", "status": "known", "effectivePercentRemaining": 80, "runway": { "status": "through_reset" }, "selection": { "spendPriority": 0.1 } } ] } } ] }
JSON
  printf '# Task\nDo the thing.\n' > "$TMP_ROOT/resolver-brief.md"

  out=$(PATH="$fakebin:$BASE_PATH" \
    FAKE_CURL_BODY="$body" \
    FAKE_CURL_RESPONSE="$TMP_ROOT/resolver-response.json" \
    QUOTA_AXI_FIXTURE="$TMP_ROOT/resolver-quota.json" \
    FM_HOME="$TMP_ROOT/resolver-home" \
    FM_CONFIG_OVERRIDE="$NEW_CONFIG" \
    TYPESAFE_API_KEY=test-key \
    "$RESOLVER" "$TMP_ROOT/resolver-brief.md" --project pager 2>"$TMP_ROOT/resolver.err")
  code=$?
  [ "$code" = 0 ] || fail "the resolver exited $code: $(cat "$TMP_ROOT/resolver.err")"
  # The request carries the rule text from config/dispatch.json's route subtree.
  if grep -q "one file route rule" "$body" 2>/dev/null; then
    pass "D1 the resolver sends the one file's routing rules to the resolver API"
  else
    fail "the resolver did not send the one file's routing rules: $(cat "$body" 2>/dev/null)"
  fi
  # The legacy rules in the same home must NOT be sent: the one file owns them.
  if grep -q "legacy route rule" "$body" 2>/dev/null; then
    fail "the resolver sent the legacy routing rules alongside the one file's"
  else
    pass "D2 the legacy routing rules are not sent when the one file owns them"
  fi
  unset out
}

test_resolver_still_reads_the_legacy_file() {
  local fakebin body out code
  fakebin=$(make_resolver_fakebin "$TMP_ROOT/resolver-legacy")
  body="$TMP_ROOT/resolver-legacy-body.json"
  cat > "$TMP_ROOT/resolver-legacy-response.json" <<'JSON'
{ "model": "jev-1.13.0",
  "answers": { "rule": { "type": "choice", "choice": "rule_1", "confidence": 0.9,
    "probabilities": { "rule_1": 0.9, "default": 0.1 } } },
  "usage": { "input_tokens": 10, "output_tokens": 5 } }
JSON
  cat > "$TMP_ROOT/resolver-legacy-quota.json" <<'JSON'
{ "generatedAt": "2030-01-01T00:00:00Z", "schemaVersion": 5, "providers": [
  { "provider": "grok", "state": { "status": "fresh" }, "quotaSemantics": { "status": "known", "effectiveAvailability": [
    { "scope": "all_models", "status": "known", "effectivePercentRemaining": 80, "runway": { "status": "through_reset" }, "selection": { "spendPriority": 0.1 } } ] } } ] }
JSON
  out=$(PATH="$fakebin:$BASE_PATH" \
    FAKE_CURL_BODY="$body" \
    FAKE_CURL_RESPONSE="$TMP_ROOT/resolver-legacy-response.json" \
    QUOTA_AXI_FIXTURE="$TMP_ROOT/resolver-legacy-quota.json" \
    FM_HOME="$TMP_ROOT/resolver-legacy-home" \
    FM_CONFIG_OVERRIDE="$LEGACY_CONFIG" \
    TYPESAFE_API_KEY=test-key \
    "$RESOLVER" "$TMP_ROOT/resolver-brief.md" --project pager 2>"$TMP_ROOT/resolver-legacy.err")
  code=$?
  [ "$code" = 0 ] || fail "the resolver exited $code on the legacy file: $(cat "$TMP_ROOT/resolver-legacy.err")"
  if grep -q "legacy route rule" "$body" 2>/dev/null; then
    pass "E1 the legacy routing file still drives the resolver unchanged"
  else
    fail "the resolver did not send the legacy routing rules: $(cat "$body" 2>/dev/null)"
  fi
  unset out
}

# ===========================================================================
# Bootstrap validates whichever routing source owns the rules.
# ===========================================================================
make_bootstrap_fakebin() {
  local dir=$1 fakebin real_jq
  fakebin=$(fm_fakebin "$dir")
  fm_fake_exit0 "$fakebin" tmux node gh-axi chrome-devtools-axi lavish-axi quota-axi tasks-axi
  cat > "$fakebin/gh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$fakebin/gh"
  real_jq=$(command -v jq 2>/dev/null) || fail "jq is required for the dispatch config validation tests"
  cat > "$fakebin/jq" <<SH
#!/usr/bin/env bash
exec '$real_jq' "\$@"
SH
  chmod +x "$fakebin/jq"
  printf '%s\n' "$fakebin"
}

run_bootstrap() {  # <config-dir> [extra env assignments...]
  local config_dir=$1
  shift
  local home="$TMP_ROOT/bootstrap-home"
  mkdir -p "$home"
  ( PATH="$BOOTSTRAP_FAKEBIN:$BASE_PATH" \
    FM_HOME="$home" FM_ROOT_OVERRIDE="$home" \
    FM_CONFIG_OVERRIDE="$config_dir" \
    FM_BOOTSTRAP_DETECT_ONLY=1 \
    "$@" \
    "$BOOTSTRAP" 2>&1 )
}

test_bootstrap_validates_the_one_file_route() {
  local out
  BOOTSTRAP_FAKEBIN=$(make_bootstrap_fakebin "$TMP_ROOT/bootstrap")
  out=$(run_bootstrap "$NEW_CONFIG")
  case "$out" in
    *CREW_DISPATCH*|*DISPATCH_CONFIG*) fail "a valid one file was reported as invalid: $out" ;;
  esac
  pass "F1 bootstrap accepts a valid one file"
}

test_bootstrap_reports_a_malformed_one_file_route() {
  local out config_dir="$TMP_ROOT/bad-route/config"
  mkdir -p "$config_dir"
  printf '%s\n' '{"harness":"minimax-code","route":{"rules":[{"when":"x"}]}}' > "$config_dir/dispatch.json"
  out=$(run_bootstrap "$config_dir")
  case "$out" in
    *"CREW_DISPATCH: invalid config/dispatch.json route"*) : ;;
    *) fail "a malformed one-file route was not reported: $out" ;;
  esac
  pass "F2 bootstrap reports a malformed one-file route and names the file"
}

test_a_broken_one_file_is_reported_not_silently_replaced() {
  local out config_dir="$TMP_ROOT/broken-file/config"
  mkdir -p "$config_dir"
  printf '%s\n' '{"harness":"minimax-code",,}' > "$config_dir/dispatch.json"
  # A valid legacy routing file sits next to it: the broken one file must NOT
  # silently hand the routing back to the legacy rules.
  printf '%s\n' '{"rules":[{"when":"legacy rule","use":{"harness":"grok"}}]}' > "$config_dir/crew-dispatch.json"
  out=$(run_bootstrap "$config_dir")
  case "$out" in
    *"DISPATCH_CONFIG: invalid config/dispatch.json - malformed JSON"*) : ;;
    *) fail "a broken one file was not reported: $out" ;;
  esac
  # It is reported once, not once per reader.
  local count
  count=$(printf '%s\n' "$out" | grep -c "dispatch.json")
  [ "$count" = 1 ] || fail "the broken one file was reported $count times: $out"
  # The resolver refuses it instead of routing on the legacy rules.
  local err rc
  err=$(FM_HOME="$TMP_ROOT/broken-file-home" FM_CONFIG_OVERRIDE="$config_dir" \
    TYPESAFE_API_KEY=test-key "$RESOLVER" "$TMP_ROOT/resolver-brief.md" --project pager 2>&1)
  rc=$?
  [ "$rc" = 2 ] || fail "the resolver exited $rc on a broken one file: $err"
  case "$err" in
    *"config/dispatch.json is not valid JSON"*) : ;;
    *) fail "the resolver did not report the broken one file: $err" ;;
  esac
  pass "F5 a broken one file is reported, once, and never silently replaced by the legacy rules"
}

test_bootstrap_reports_an_unverified_one_file_harness() {
  local out config_dir="$TMP_ROOT/bad-harness/config"
  mkdir -p "$config_dir"
  printf '%s\n' '{"harness":"spaceship"}' > "$config_dir/dispatch.json"
  out=$(run_bootstrap "$config_dir")
  case "$out" in
    *"DISPATCH_CONFIG: invalid config/dispatch.json - unverified harness: spaceship"*) : ;;
    *) fail "an unverified one-file harness was not reported: $out" ;;
  esac
  pass "F3 bootstrap reports an unverified one-file harness"
}

test_bootstrap_still_validates_the_legacy_file() {
  local out
  out=$(run_bootstrap "$LEGACY_CONFIG")
  case "$out" in
    *CREW_DISPATCH*|*DISPATCH_CONFIG*) fail "a valid legacy config was reported as invalid: $out" ;;
  esac
  # The legacy file's own diagnostic text must be unchanged.
  local bad_config="$TMP_ROOT/bad-legacy/config"
  mkdir -p "$bad_config"
  printf '%s\n' '{"rules":[{"when":"x","use":{"harness":"spaceship"}}]}' > "$bad_config/crew-dispatch.json"
  out=$(run_bootstrap "$bad_config")
  case "$out" in
    *"CREW_DISPATCH: invalid config/crew-dispatch.json - unverified harness: spaceship"*) : ;;
    *) fail "the legacy diagnostic text changed: $out" ;;
  esac
  pass "F4 bootstrap still validates the legacy routing file with unchanged diagnostics"
}

# ===========================================================================
# The one file propagates to a secondmate home.
# ===========================================================================
test_one_file_is_inherited() {
  local src dest home
  # shellcheck source=/dev/null
  . "$ROOT/bin/fm-config-inherit-lib.sh"
  src="$TMP_ROOT/inherit-src"
  dest="$TMP_ROOT/inherit-home/config"
  home="$TMP_ROOT/inherit-home"
  mkdir -p "$src" "$dest" "$home/state"
  printf '%s\n' '{"harness":"minimax-code","max_lanes":12}' > "$src/dispatch.json"
  propagate_inheritable_config "$src" "$dest" >/dev/null 2>&1 \
    || fail "propagation of the one file failed"
  [ -f "$dest/dispatch.json" ] || fail "the one file was not propagated to the secondmate home"
  [ "$(cat "$dest/dispatch.json")" = '{"harness":"minimax-code","max_lanes":12}' ] \
    || fail "the propagated one file has the wrong content"
  # A cleared primary value is mirrored downstream as absence.
  rm -f "$src/dispatch.json"
  propagate_inheritable_config "$src" "$dest" >/dev/null 2>&1 \
    || fail "propagation of the cleared one file failed"
  [ -e "$dest/dispatch.json" ] && fail "the cleared one file was not mirrored downstream"
  pass "G1 the one file propagates to a secondmate home and its absence mirrors downstream"
}

test_legacy_home_inheritance_is_unchanged() {
  local src dest home
  # shellcheck source=/dev/null
  . "$ROOT/bin/fm-config-inherit-lib.sh"
  src="$TMP_ROOT/inherit-legacy-src"
  dest="$TMP_ROOT/inherit-legacy-home/config"
  home="$TMP_ROOT/inherit-legacy-home"
  mkdir -p "$src" "$dest" "$home/state"
  printf '%s\n' '{"default":{"harness":"codex"}}' > "$src/crew-dispatch.json"
  printf 'codex\n' > "$src/crew-harness"
  propagate_inheritable_config "$src" "$dest" >/dev/null 2>&1 \
    || fail "legacy propagation failed"
  [ "$(cat "$dest/crew-dispatch.json")" = '{"default":{"harness":"codex"}}' ] \
    || fail "the legacy routing file was not propagated"
  [ "$(cat "$dest/crew-harness")" = codex ] || fail "the legacy crew-harness was not propagated"
  pass "G2 a legacy home still propagates its legacy files unchanged"
}

test_legacy_home_is_unchanged
test_one_file_home_resolves_everything
test_one_file_wins_over_legacy
test_resolver_reads_the_route_from_the_one_file
test_resolver_still_reads_the_legacy_file
test_bootstrap_validates_the_one_file_route
test_bootstrap_reports_a_malformed_one_file_route
test_a_broken_one_file_is_reported_not_silently_replaced
test_bootstrap_reports_an_unverified_one_file_harness
test_bootstrap_still_validates_the_legacy_file
test_one_file_is_inherited
test_legacy_home_inheritance_is_unchanged
