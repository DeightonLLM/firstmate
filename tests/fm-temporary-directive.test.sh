#!/usr/bin/env bash
# Behavior tests for the temporary dispatch directive mechanism.
#
# A temporary directive is a dispatch instruction that carries its own expiry.
# These tests drive the public interfaces of bin/fm-temporary-directive.sh and
# bin/fm-dispatch-resolve.sh and prove:
#   A) Recording. A duration is resolved to an absolute expiry at set time, a
#      reason is required, the store is written atomically, and a second
#      process reads the same absolute expiry (so the directive still expires
#      on time across a restart).
#   B) Honouring. A live directive decides the dispatch profile over the
#      standing rules, and it stops applying the moment it expires.
#   C) Reporting. An expired directive is named and reported wherever it would
#      have applied, and is never applied and never dropped silently.
#   D) Refusing. A malformed store is an actionable error that preserves the
#      broken input, never a silent fallback.
#   E) The standing rules. With no live directive the standing path resolves
#      exactly as it did before the mechanism existed.
#   F) The staleness check. A standing directive whose recorded justification
#      no longer holds is reported against a current reading, and the standing
#      directive is never changed by the check.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TOOL="$ROOT/bin/fm-temporary-directive.sh"
RESOLVER="$ROOT/bin/fm-dispatch-resolve.sh"
TMP_ROOT=$(fm_test_tmproot fm-temporary-directive)

# A fake quota-axi that records every call and answers with a fixed snapshot.
# The recorded calls prove which command actually reads the quota.
make_quota_fake() {
  local dir=$1 snapshot=$2 fakebin
  fakebin=$(fm_fakebin "$dir")
  cat > "$fakebin/quota-axi" <<SH
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$dir/quota-calls.log"
cat "$snapshot"
SH
  chmod +x "$fakebin/quota-axi"
  printf '%s\n' "$fakebin"
}

# A quota snapshot with one provider window, in the shape quota-axi reports.
write_snapshot() {
  local file=$1 provider=$2 window=$3 percent=$4
  cat > "$file" <<JSON
{
  "generatedAt": "2026-10-21T05:00:00.000Z",
  "schemaVersion": 5,
  "providers": [
    {
      "provider": "$provider",
      "windows": [ { "id": "$window", "percentRemaining": $percent } ],
      "state": { "status": "fresh", "stale": false },
      "quotaSemantics": {
        "status": "known",
        "effectiveAvailability": [
          { "scope": "all_models", "status": "known", "effectivePercentRemaining": $percent }
        ]
      }
    }
  ]
}
JSON
}

make_home() {
  local home="$TMP_ROOT/$1"
  mkdir -p "$home/config" "$home/state"
  printf '%s\n' "$home"
}

# A standing dispatch config whose recorded justification names a measured
# window, the shape the staleness check reads.
write_standing_config() {
  local file=$1 active=$2 contract=$3
  cat > "$file" <<JSON
{
  "_mode": { "active": "$active", "contract": "$contract" },
  "rules": [
    {
      "when": "any crewmate dispatch",
      "use": { "harness": "grok", "model": "grok-4", "effort": "high" }
    }
  ],
  "default": { "harness": "grok", "model": "grok-4", "effort": "high" }
}
JSON
}

write_brief() {
  local file=$1
  cat > "$file" <<'BRIEF'
# Task brief

## Captain's intent

Route this dispatch.
BRIEF
}

# ---------------------------------------------------------------------------
# A) Recording
# ---------------------------------------------------------------------------

test_duration_resolves_to_an_absolute_expiry() {
  local home out until first second
  home=$(make_home duration)
  out=$(FM_HOME="$home" "$TOOL" set --id minimax-hold --until 6h \
    --harness pi --model openai-codex/gpt-6-luna --effort high \
    --reason "MiniMax 5h window measured at 6% remaining" --json) \
    || fail "set with a duration failed"
  until=$(jq -r '.until' <<<"$out")
  case "$until" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) fail "a duration did not resolve to an absolute expiry: $until" ;;
  esac
  # The expiry is about six hours out, not six minutes.
  local remaining
  remaining=$(jq -r '.expires_in_seconds' <<<"$out")
  [ "$remaining" -gt 21000 ] && [ "$remaining" -lt 21900 ] \
    || fail "a 6h duration resolved to $remaining seconds"
  # A second process reads the same absolute expiry, so the directive still
  # expires on time across a restart.
  first=$(FM_HOME="$home" "$TOOL" effective --json | jq -r '.live.until')
  second=$(FM_HOME="$home" "$TOOL" list --json | jq -r '.directives[0].until')
  [ "$first" = "$until" ] || fail "a second read saw a different expiry: $first vs $until"
  [ "$second" = "$until" ] || fail "the stored expiry changed between reads: $second vs $until"
  pass "a duration resolves to an absolute expiry that survives a restart"
}

test_set_without_a_reason_is_refused() {
  local home out rc
  home=$(make_home no-reason)
  out=$(FM_HOME="$home" "$TOOL" set --id mystery --until 1h --harness pi 2>&1)
  rc=$?
  [ "$rc" -ne 0 ] || fail "a directive with no reason was accepted"
  assert_contains "$out" "reason" "the refusal does not name the missing reason"
  assert_absent "$home/config/temporary-directives.json" "a refused directive was written anyway"
  pass "a directive with no reason is refused and nothing is written"
}

test_set_replaces_a_directive_with_the_same_id() {
  local home out
  home=$(make_home replace)
  FM_HOME="$home" "$TOOL" set --id hold --until 1h --harness pi --reason "first" >/dev/null
  out=$(FM_HOME="$home" "$TOOL" set --id hold --until 2h --harness codex --reason "second" --json)
  [ "$(jq -r '.replaced' <<<"$out")" = "true" ] || fail "the second set did not report the replacement"
  [ "$(jq -r '.directives | length' <<<"$(FM_HOME="$home" "$TOOL" list --json)")" = "1" ] \
    || fail "the replacement left two directives behind"
  [ "$(jq -r '.directives[0].reason' <<<"$(FM_HOME="$home" "$TOOL" list --json)")" = "second" ] \
    || fail "the replacement did not take effect"
  pass "setting a directive again replaces the one with the same id"
}

# ---------------------------------------------------------------------------
# B) Honouring
# ---------------------------------------------------------------------------

test_live_directive_overrides_the_standing_rules() {
  local home brief out
  home=$(make_home live)
  brief=$(write_brief "$home/brief.md")
  write_standing_config "$home/config/crew-dispatch.json" "Codex-only" "Standing mode."
  FM_HOME="$home" "$TOOL" set --id minimax-hold --until 6h \
    --harness pi --model minimax/MiniMax-M3.1-Flash-Preview --effort medium \
    --reason "MiniMax 5h window measured at 6% remaining" >/dev/null
  out=$(FM_HOME="$home" "$RESOLVER" "$brief" 2>/dev/null)
  assert_contains "$out" "status: clear" "the live directive did not resolve to a clear decision"
  assert_contains "$out" "source: temporary directive minimax-hold" "the resolution does not name the directive"
  assert_contains "$out" "profile: --harness pi --model minimax/MiniMax-M3.1-Flash-Preview --effort medium" \
    "the resolution does not carry the directive's profile"
  assert_not_contains "$out" "grok" "the standing rules were applied under a live directive"
  pass "a live directive overrides the standing rules"
}

test_an_expired_directive_is_not_applied() {
  local home brief out
  home=$(make_home expired)
  brief=$(write_brief "$home/brief.md")
  FM_HOME="$home" "$TOOL" set --id quick --until 1s --harness pi --reason "short lived" >/dev/null
  sleep 2
  out=$(FM_HOME="$home" "$TOOL" effective --json)
  [ "$(jq -r '.live' <<<"$out")" = "null" ] || fail "an expired directive is still live"
  [ "$(jq -r '.expired[0].id' <<<"$out")" = "quick" ] || fail "the expired directive is not reported"
  out=$(FM_HOME="$home" "$RESOLVER" "$brief" 2>/dev/null)
  assert_not_contains "$out" "profile:" "an expired directive produced a dispatch profile"
  pass "an expired directive stops applying"
}

# ---------------------------------------------------------------------------
# C) Reporting
# ---------------------------------------------------------------------------

test_an_expired_directive_is_reported() {
  local home brief out
  home=$(make_home expired-reported)
  brief=$(write_brief "$home/brief.md")
  FM_HOME="$home" "$TOOL" set --id quick --until 1s --harness pi --reason "short lived" >/dev/null
  sleep 2
  out=$(FM_HOME="$home" "$RESOLVER" "$brief" 2>&1)
  assert_contains "$out" "quick" "the expired directive is not named"
  assert_contains "$out" "expired" "the expired directive is not reported as expired"
  out=$(FM_HOME="$home" "$TOOL" status)
  assert_contains "$out" "expired" "the status does not report the expired directive"
  assert_contains "$out" "ignored" "the status does not say the expired directive is ignored"
  pass "an expired directive is reported, not applied and not dropped silently"
}

test_status_names_the_effective_decision() {
  local home out
  home=$(make_home status)
  write_standing_config "$home/config/crew-dispatch.json" "Codex-only" "Standing mode."
  FM_HOME="$home" "$TOOL" set --id hold --until 6h --harness pi --model minimax/MiniMax-M3.1-Flash-Preview \
    --reason "MiniMax 5h window measured at 6% remaining" >/dev/null
  out=$(FM_HOME="$home" "$TOOL" status)
  assert_contains "$out" "status: live" "the status does not report the live directive"
  assert_contains "$out" "effective: --harness pi --model minimax/MiniMax-M3.1-Flash-Preview" \
    "the status does not carry the effective decision"
  assert_contains "$out" "source: temporary directive hold" "the status does not name the winning directive"
  assert_contains "$out" "Codex-only" "the status does not name the standing mode underneath"
  pass "status names the effective decision and the standing mode underneath"
}

test_status_falls_back_to_the_standing_rules() {
  local home out
  home=$(make_home status-standing)
  write_standing_config "$home/config/crew-dispatch.json" "Codex-only" "Standing mode."
  out=$(FM_HOME="$home" "$TOOL" status)
  assert_contains "$out" "status: standing" "the status does not fall back to the standing rules"
  assert_contains "$out" "Codex-only" "the status does not name the standing mode"
  pass "status falls back to the standing rules when no directive is live"
}

# ---------------------------------------------------------------------------
# D) Refusing
# ---------------------------------------------------------------------------

test_a_malformed_store_is_an_actionable_error() {
  local home brief out rc before after
  home=$(make_home malformed)
  brief=$(write_brief "$home/brief.md")
  printf '{"version":1,"directives":[{"id":"broken","reason":"r","harness":"pi","set_at":"2026-10-21T00:00:00Z"}]}\n' \
    > "$home/config/temporary-directives.json"
  before=$(cat "$home/config/temporary-directives.json")
  out=$(FM_HOME="$home" "$RESOLVER" "$brief" 2>&1)
  rc=$?
  [ "$rc" -eq 2 ] || fail "a malformed store did not stop the resolver with exit 2 (got $rc)"
  assert_contains "$out" "malformed" "the malformed store is not reported as malformed"
  assert_contains "$out" "until" "the malformed store does not name the broken field"
  out=$(FM_HOME="$home" "$TOOL" set --id other --until 1h --harness pi --reason "r" 2>&1)
  rc=$?
  [ "$rc" -eq 2 ] || fail "a set over a malformed store was allowed (got $rc)"
  after=$(cat "$home/config/temporary-directives.json")
  [ "$before" = "$after" ] || fail "the malformed store was rewritten"
  pass "a malformed store is an actionable error and the broken input is preserved"
}

# ---------------------------------------------------------------------------
# E) The standing rules
# ---------------------------------------------------------------------------

test_the_standing_rules_resolve_unchanged() {
  local home brief without with_empty
  home=$(make_home standing)
  brief=$(write_brief "$home/brief.md")
  without=$(FM_HOME="$home" "$RESOLVER" "$brief" 2>&1; printf 'exit=%s\n' "$?")
  printf '{"version":1,"directives":[]}\n' > "$home/config/temporary-directives.json"
  with_empty=$(FM_HOME="$home" "$RESOLVER" "$brief" 2>&1; printf 'exit=%s\n' "$?")
  [ "$without" = "$with_empty" ] \
    || fail "an empty directive store changed the standing resolution:
--- without ---
$without
--- with an empty store ---
$with_empty"
  assert_not_contains "$without" "temporary directive" "the standing resolution mentions a temporary directive"
  pass "the standing rules resolve unchanged when no directive is live"
}

# ---------------------------------------------------------------------------
# F) The staleness check
# ---------------------------------------------------------------------------

test_a_stale_standing_directive_is_reported() {
  local home snapshot fakebin out before after
  home=$(make_home stale)
  snapshot="$home/quota.json"
  write_snapshot "$snapshot" minimax "model:general:5h" 100
  fakebin=$(make_quota_fake "$home/fake" "$snapshot")
  write_standing_config "$home/config/crew-dispatch.json" "Codex-only" \
    "Captain directive 2026-10-18: MiniMax 5h window measured at 6% remaining."
  before=$(cat "$home/config/crew-dispatch.json")
  out=$(PATH="$fakebin:$PATH" FM_HOME="$home" "$TOOL" staleness)
  assert_contains "$out" "dispatch-stale" "the stale standing directive is not reported"
  assert_contains "$out" "Codex-only" "the warning does not name the standing directive"
  assert_contains "$out" "6%" "the warning does not state what the standing directive claimed"
  assert_contains "$out" "100%" "the warning does not state what is true now"
  assert_contains "$out" "re-measure" "the warning does not ask for a re-measurement"
  after=$(cat "$home/config/crew-dispatch.json")
  [ "$before" = "$after" ] || fail "the staleness check changed the standing directive"
  pass "a stale standing directive is reported and never changed"
}

test_a_current_standing_directive_is_not_reported() {
  local home snapshot fakebin out
  home=$(make_home current)
  snapshot="$home/quota.json"
  write_snapshot "$snapshot" minimax "model:general:5h" 6
  fakebin=$(make_quota_fake "$home/fake" "$snapshot")
  write_standing_config "$home/config/crew-dispatch.json" "Codex-only" \
    "Captain directive 2026-10-18: MiniMax 5h window measured at 6% remaining."
  out=$(PATH="$fakebin:$PATH" FM_HOME="$home" "$TOOL" staleness)
  assert_not_contains "$out" "dispatch-stale" "a standing directive that still holds was reported as stale"
  assert_contains "$out" "holds" "the check does not report the claim it checked"
  pass "a standing directive whose justification still holds is not reported"
}

test_the_staleness_check_only_runs_where_it_is_needed() {
  local home snapshot fakebin log
  home=$(make_home reading)
  snapshot="$home/quota.json"
  write_snapshot "$snapshot" minimax "model:general:5h" 100
  fakebin=$(make_quota_fake "$home/fake" "$snapshot")
  log="$home/fake/quota-calls.log"
  write_standing_config "$home/config/crew-dispatch.json" "Codex-only" \
    "Captain directive 2026-10-18: MiniMax 5h window measured at 6% remaining."
  PATH="$fakebin:$PATH" FM_HOME="$home" "$TOOL" list >/dev/null
  assert_absent "$log" "reading the quota for a command that dispatches nothing"
  PATH="$fakebin:$PATH" FM_HOME="$home" "$TOOL" staleness >/dev/null
  assert_present "$log" "the staleness check did not read the quota"
  assert_grep "--no-credential-refresh" "$log" "the quota reading could refresh a credential"
  pass "the staleness check reads the quota only where a decision is made"
}

# ---------------------------------------------------------------------------
# G) Clearing
# ---------------------------------------------------------------------------

test_clear_stops_a_directive_and_keeps_it_visible() {
  local home brief out
  home=$(make_home clear)
  brief=$(write_brief "$home/brief.md")
  FM_HOME="$home" "$TOOL" set --id hold --until 6h --harness pi --reason "temporary" >/dev/null
  out=$(FM_HOME="$home" "$TOOL" clear --id hold)
  assert_contains "$out" "cleared" "the clear did not report the cleared directive"
  out=$(FM_HOME="$home" "$TOOL" list)
  assert_contains "$out" "state: cleared" "the cleared directive is not visible in the list"
  out=$(FM_HOME="$home" "$TOOL" effective --json)
  [ "$(jq -r '.live' <<<"$out")" = "null" ] || fail "a cleared directive still applies"
  out=$(FM_HOME="$home" "$RESOLVER" "$brief" 2>&1)
  assert_not_contains "$out" "profile:" "a cleared directive still produced a dispatch profile"
  pass "clear stops a directive and keeps it visible as cleared"
}

test_clear_says_when_there_was_nothing_to_clear() {
  local home out rc
  home=$(make_home clear-missing)
  out=$(FM_HOME="$home" "$TOOL" clear --id absent 2>&1)
  rc=$?
  [ "$rc" -ne 0 ] || fail "clearing an absent directive reported success"
  assert_contains "$out" "absent" "the refusal does not say the directive was not there"
  pass "clear says plainly when there was nothing to clear"
}

# ---------------------------------------------------------------------------

test_duration_resolves_to_an_absolute_expiry
test_set_without_a_reason_is_refused
test_set_replaces_a_directive_with_the_same_id
test_live_directive_overrides_the_standing_rules
test_an_expired_directive_is_not_applied
test_an_expired_directive_is_reported
test_status_names_the_effective_decision
test_status_falls_back_to_the_standing_rules
test_a_malformed_store_is_an_actionable_error
test_the_standing_rules_resolve_unchanged
test_a_stale_standing_directive_is_reported
test_a_current_standing_directive_is_not_reported
test_the_staleness_check_only_runs_where_it_is_needed
test_clear_stops_a_directive_and_keeps_it_visible
test_clear_says_when_there_was_nothing_to_clear

echo "# all fm-temporary-directive tests passed"
