#!/usr/bin/env bash
# tests/fm-dispatch-one-file-guard.test.sh - the dispatch guard's standing
# rules, and the ONE dispatch file that configures them.
#
# The Captain's standing directive (2026-10-21, stated four times) is that the
# MCode route IS the route. The directive kept being lost because nothing
# enforced it, so this suite proves by observed behaviour that:
#   A) a Pi spawn is REFUSED while the configured route is minimax-code
#   B) the SAME Pi spawn is ALLOWED when the configured route is pi, so the
#      rule is conditional on the configured route and not a blanket Pi ban
#   C) a legitimate minimax-code spawn on the live model is ALLOWED
#   D) the retired slug minimax/MiniMax-M3.1-Flash-Preview is REFUSED with no
#      bypass at all
#   E) the narrow, logged escape hatch is the ONLY way past the route gate,
#      and the global bypass cannot rescue the route gate or the retired slug
#   F) the legacy files still configure the route and the lane ceilings
#
# A rule that never fires is a red test, so every refusal below is proven by
# the guard's own exit code and reason, never by reading the source.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

GUARD="$ROOT/bin/fm-dispatch-guard.sh"
TMP_ROOT=$(fm_test_tmproot fm-dispatch-one-file-guard)
LOG="$TMP_ROOT/guard.log"

# The load ceiling and the quota ceiling are not what these cases are about,
# so both are taken out of the picture with their own logged bypasses.
export FM_DISPATCH_GUARD_LOAD_BYPASS=1
export FM_DISPATCH_GUARD_QUOTA_BYPASS=1
# The lane-ceiling env overrides win over every config source, so an ambient
# value on the host would decide the ceiling instead of the config under test.
unset FM_DISPATCH_GUARD_MAX_LANES
unset FM_DISPATCH_GUARD_MAX_PROVIDER_LANES

# new_home <name>: a home with a config dir and a state dir holding one meta
# whose endpoint cannot be resolved. The guard counts an unresolvable lane as
# live (fail-closed), which is what makes the lane ceiling testable without a
# terminal multiplexer.
new_home() {
  local home="$TMP_ROOT/$1"
  mkdir -p "$home/config" "$home/state"
  printf 'endpoint_task_id=nolane\nharness=agy\n' > "$home/state/nolane.meta"
  printf '%s\n' "$home"
}

# run_guard <want-rc> <name> <home> <harness> <model> [env...]
# Asserts the guard's exit code and, on a refusal, that it printed a reason.
run_guard() {
  local want_rc=$1 name=$2 home=$3 harness=$4 model=$5
  shift 5
  local out rc
  out=$(env FM_HOME="$home" FM_DISPATCH_GUARD_LOG="$LOG" "$@" "$GUARD" "$harness" "$model" 2>&1)
  rc=$?
  if [ "$rc" != "$want_rc" ]; then
    fail "$name (rc=$rc, want $want_rc): $out"
  fi
  if [ "$want_rc" != 0 ]; then
    case "$out" in
      *REFUSED*) : ;;
      *) fail "$name (no REFUSED reason on stderr: $out)" ;;
    esac
  fi
  pass "$name"
}

# --- A/B/C: the configured-route gate ---------------------------------------
test_route_gate_bites_and_is_conditional() {
  local mcode_home pi_home bare_home

  mcode_home=$(new_home route-mcode)
  cat > "$mcode_home/config/dispatch.json" <<'JSON'
{ "harness": "minimax-code", "model": "minimax/MiniMax-M3.1-Flash" }
JSON
  pi_home=$(new_home route-pi)
  printf '%s\n' '{ "harness": "pi" }' > "$pi_home/config/dispatch.json"
  bare_home=$(new_home route-bare)

  # A) the rule bites: a Pi spawn while the route is MCode is refused.
  run_guard 64 "A1 a Pi spawn is refused while the configured route is minimax-code" \
    "$mcode_home" pi minimax/MiniMax-M3.1-Flash

  # B) the same inputs are allowed when the route is legitimately pi.
  run_guard 0 "B1 the same Pi spawn is allowed when the configured route is pi" \
    "$pi_home" pi some-model

  # B) a home that configures no route at all keeps whatever it had.
  run_guard 0 "B2 a Pi spawn is allowed when no route is configured" \
    "$bare_home" pi some-model

  # C) a legitimate MCode spawn on the live model is allowed.
  run_guard 0 "C1 a minimax-code spawn on the live model is allowed" \
    "$mcode_home" minimax-code minimax/MiniMax-M3.1-Flash
}

# --- A2: the route gate covers the CLASS of API-drawn adapters ---------------
#
# The rule used to name the Pi family only, so a codex spawn on the free MCode
# route drew the Codex account's quota while the guard reported the dispatch
# as allowed. Measured on 2026-10-21: codex with openai-codex/gpt-6-luna
# exited 0 while the configured route was minimax-code. The gate is now
# expressed as the class the directive names - every API-drawn adapter - and
# the configured route itself is never in that class.

API_DRAWN_ADAPTERS="claude codex opencode pi pi-signed grok kimi agy"

test_route_gate_covers_every_api_drawn_adapter() {
  local mcode_home adapter
  mcode_home=$(new_home route-api-drawn)
  cat > "$mcode_home/config/dispatch.json" <<'JSON'
{ "harness": "minimax-code", "model": "minimax/MiniMax-M3.1-Flash" }
JSON

  for adapter in $API_DRAWN_ADAPTERS; do
    run_guard 64 "A2 an API-drawn adapter is refused on the free route: $adapter" \
      "$mcode_home" "$adapter" some-legal-model
  done

  # The configured route itself is not API-drawn, so it is not refused.
  run_guard 0 "A2 the configured route itself is allowed on the free route" \
    "$mcode_home" minimax-code minimax/MiniMax-M3.1-Flash

  # An adapter the guard holds no evidence about is not refused by this gate:
  # refusing on a guess would wedge a legal spawn.
  run_guard 0 "A2 an adapter with no evidence of drawing an account is not refused" \
    "$mcode_home" some-future-adapter some-legal-model
}

test_route_gate_refusal_names_the_route_and_the_bypass() {
  local mcode_home out
  mcode_home=$(new_home route-reason)
  cat > "$mcode_home/config/dispatch.json" <<'JSON'
{ "harness": "minimax-code" }
JSON
  out=$(env FM_HOME="$mcode_home" FM_DISPATCH_GUARD_LOG="$LOG" "$GUARD" codex some-legal-model 2>&1)
  case "$out" in
    *minimax-code*) : ;;
    *) fail "the route-gate refusal does not name the configured route: $out" ;;
  esac
  case "$out" in
    *FM_DISPATCH_GUARD_ROUTE_BYPASS*) : ;;
    *) fail "the route-gate refusal does not name the bypass: $out" ;;
  esac
  pass "the route-gate refusal names the configured route and the bypass"
}

test_route_gate_escape_hatch_applies_to_the_whole_class() {
  local mcode_home adapter
  mcode_home=$(new_home route-api-bypass)
  cat > "$mcode_home/config/dispatch.json" <<'JSON'
{ "harness": "minimax-code" }
JSON

  # The narrow bypass is the only way past the gate, and it covers the class.
  for adapter in $API_DRAWN_ADAPTERS; do
    run_guard 0 "A3 the documented route bypass admits an API-drawn adapter: $adapter" \
      "$mcode_home" "$adapter" some-legal-model FM_DISPATCH_GUARD_ROUTE_BYPASS=1
  done

  # The global bypass must not rescue ANY of them.
  for adapter in $API_DRAWN_ADAPTERS; do
    run_guard 64 "A4 the global bypass does not rescue the route gate: $adapter" \
      "$mcode_home" "$adapter" some-legal-model FM_DISPATCH_GUARD_BYPASS=1
  done

  # ...and it does not rescue the retired slug or the Sol ban either, with
  # the narrow bypass set as well.
  run_guard 64 "A5 the route bypass does not rescue the retired slug" \
    "$mcode_home" minimax-code minimax/MiniMax-M3.1-Flash-Preview FM_DISPATCH_GUARD_ROUTE_BYPASS=1
  run_guard 64 "A6 the route bypass does not rescue the Sol ban" \
    "$mcode_home" codex gpt-6.1-sol FM_DISPATCH_GUARD_ROUTE_BYPASS=1
}

# --- D: the retired slug ----------------------------------------------------
test_retired_slug_is_refused() {
  local home
  home=$(new_home retired-slug)
  run_guard 64 "D1 the retired MCode preview slug is refused" \
    "$home" minimax-code minimax/MiniMax-M3.1-Flash-Preview
  run_guard 64 "D2 the retired slug is refused on a Pi spawn too" \
    "$home" pi minimax/MiniMax-M3.1-Flash-Preview
}

# --- E: the escape hatches --------------------------------------------------
test_escape_hatches() {
  local mcode_home
  mcode_home=$(new_home route-bypass)
  cat > "$mcode_home/config/dispatch.json" <<'JSON'
{ "harness": "minimax-code" }
JSON

  # The global bypass must not rescue the route gate.
  run_guard 64 "E1 the global bypass does not rescue the route gate" \
    "$mcode_home" pi some-model FM_DISPATCH_GUARD_BYPASS=1

  # The global bypass must not rescue the retired slug either.
  run_guard 64 "E2 the global bypass does not rescue the retired slug" \
    "$mcode_home" minimax-code minimax/MiniMax-M3.1-Flash-Preview FM_DISPATCH_GUARD_BYPASS=1

  # The narrow, documented escape hatch does let the Pi spawn through.
  run_guard 0 "E3 the documented route bypass allows the Pi spawn" \
    "$mcode_home" pi some-model FM_DISPATCH_GUARD_ROUTE_BYPASS=1

  # ...and it is logged, so it is auditable rather than silent.
  if grep -q BYPASS_ROUTE "$LOG" 2>/dev/null; then
    pass "E4 the route bypass is logged"
  else
    fail "the route bypass was not logged"
  fi

  # The retired slug has no bypass at all, not even the narrow one.
  run_guard 64 "E5 the route bypass does not rescue the retired slug" \
    "$mcode_home" minimax-code minimax/MiniMax-M3.1-Flash-Preview FM_DISPATCH_GUARD_ROUTE_BYPASS=1
}

# --- F: the legacy files still configure the route and the ceilings ---------
test_legacy_files_still_configure() {
  local legacy_home
  legacy_home=$(new_home legacy-route)
  printf 'minimax-code\n' > "$legacy_home/config/crew-harness"
  run_guard 64 "F1 a legacy crew-harness of minimax-code refuses a Pi spawn" \
    "$legacy_home" pi some-model

  # A legacy crew-harness of pi keeps Pi spawns legal.
  local pi_legacy_home
  pi_legacy_home=$(new_home legacy-route-pi)
  printf 'pi\n' > "$pi_legacy_home/config/crew-harness"
  run_guard 0 "F2 a legacy crew-harness of pi allows a Pi spawn" \
    "$pi_legacy_home" pi some-model

  # The lane ceiling resolves from the one file.
  local capped_home
  capped_home=$(new_home cap-dispatch)
  printf '%s\n' '{ "harness": "minimax-code", "max_lanes": 1 }' > "$capped_home/config/dispatch.json"
  run_guard 64 "F3 the one file's max_lanes refuses at the cap" \
    "$capped_home" minimax-code minimax/MiniMax-M3.1-Flash
  printf '%s\n' '{ "harness": "minimax-code", "max_lanes": 2 }' > "$capped_home/config/dispatch.json"
  run_guard 0 "F4 the one file's max_lanes allows under the cap" \
    "$capped_home" minimax-code minimax/MiniMax-M3.1-Flash

  # The per-provider ceiling resolves from the one file too.
  printf '%s\n' '{ "harness": "minimax-code", "max_lanes": 9, "max_provider_lanes": 1 }' \
    > "$capped_home/config/dispatch.json"
  run_guard 64 "F5 the one file's max_provider_lanes refuses at the provider cap" \
    "$capped_home" minimax-code minimax/MiniMax-M3.1-Flash
  printf '%s\n' '{ "harness": "minimax-code", "max_lanes": 9, "max_provider_lanes": 2 }' \
    > "$capped_home/config/dispatch.json"
  run_guard 0 "F6 the one file's max_provider_lanes allows under the provider cap" \
    "$capped_home" minimax-code minimax/MiniMax-M3.1-Flash

  # The legacy ceiling knob still works on its own.
  local legacy_cap_home
  legacy_cap_home=$(new_home cap-legacy)
  printf 'minimax-code\n' > "$legacy_cap_home/config/crew-harness"
  printf '1\n' > "$legacy_cap_home/config/dispatch-max-lanes"
  run_guard 64 "F7 the legacy lane ceiling knob still refuses at the cap" \
    "$legacy_cap_home" minimax-code minimax/MiniMax-M3.1-Flash
}

test_route_gate_bites_and_is_conditional
test_route_gate_covers_every_api_drawn_adapter
test_route_gate_refusal_names_the_route_and_the_bypass
test_route_gate_escape_hatch_applies_to_the_whole_class
test_retired_slug_is_refused
test_escape_hatches
test_legacy_files_still_configure
