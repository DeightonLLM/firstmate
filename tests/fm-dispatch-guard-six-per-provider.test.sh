#!/usr/bin/env bash
# tests/fm-dispatch-guard-six-per-provider.test.sh - the per-provider ceiling
# of bin/fm-dispatch-guard.sh, proven by observed behaviour.
#
# Two facts make this ceiling mechanical instead of prose:
#
#   1. The ceiling binds a CREDENTIAL ACCOUNT, not a provider name and not a
#      host. One firstmate's homes on one host hold ONE copy of each
#      credential, so a lane running in a registered second-mate home is a
#      lane on our account. The count therefore walks the registered homes of
#      THIS firstmate, and only those: another firstmate's fleet is never
#      counted and never claimed.
#
#   2. The account attribution folds the spellings of one account onto one
#      key. The same MiniMax credential was counted in three buckets - a
#      minimax/ prefixed model, an unprefixed MiniMax model on the
#      minimax-code adapter, and a MiniMax model on a pi adapter - so a
#      ceiling on that credential bound one bucket and ignored the others.
#
# A lane whose endpoint cannot be resolved is counted as LIVE, which is what
# makes the whole ceiling testable without a terminal multiplexer, and it is
# the guard's own fail-closed rule rather than a test convenience.
#
# The guard legitimately ends in `exit 0`, so it cannot be sourced and then
# called. These extract the shipped function bodies out of the real guard file
# and exercise that exact text - no copy of the logic lives in this test.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

GUARD="$ROOT/bin/fm-dispatch-guard.sh"
TMP_ROOT=$(fm_test_tmproot fm-dispatch-six-per-provider)
LOG="$TMP_ROOT/guard.log"

# The load ceiling is not what this suite is about, so it is taken out of the
# picture with its own logged bypass. The quota ceiling does not apply to the
# minimax-code adapter at all, so nothing has to be bypassed for it.
export FM_DISPATCH_GUARD_LOAD_BYPASS=1
# The lane-ceiling env overrides win over every config source, so an ambient
# value on the host would decide the ceiling instead of the config under test.
unset FM_DISPATCH_GUARD_MAX_LANES
unset FM_DISPATCH_GUARD_MAX_PROVIDER_LANES

# --- guard function extraction ----------------------------------------------
# Pull the real functions out of the shipped guard and make them callable.
ACCOUNT_FNS=""
for fn in fm_dispatch_guard_provider_of_meta \
          fm_dispatch_guard_account_of_prefix \
          fm_dispatch_guard_account_of_model \
          fm_dispatch_guard_account_of_harness \
          fm_dispatch_guard_account_of_meta \
          fm_dispatch_guard_fleet_homes; do
  body=$(awk "/^${fn}\(\)/,/^}/" "$GUARD")
  if [ -z "$body" ]; then
    fail "bin/fm-dispatch-guard.sh does not define ${fn}"
  fi
  ACCOUNT_FNS="$ACCOUNT_FNS
$body"
done
eval "$ACCOUNT_FNS"

# --- fixtures ----------------------------------------------------------------

# new_home <name>: a home with a config dir and a state dir.
new_home() {
  local home="$TMP_ROOT/$1"
  mkdir -p "$home/config" "$home/state"
  printf '%s\n' "$home"
}

# lane <home> <name> <harness> <model>: a recorded lane whose endpoint cannot
# be resolved, so the guard counts it as live (its fail-closed rule).
lane() {
  local home=$1 name=$2 harness=$3 model=$4
  fm_write_meta "$home/state/$name.meta" \
    "endpoint_task_id=$name" "harness=$harness" "model=$model"
}

# register <primary> <secondmate-home>: add a second-mate home to the
# primary's own registry, in the shape data/secondmates.md uses.
register() {
  local primary=$1 sm=$2
  mkdir -p "$primary/data"
  printf -- '- test-secondmate - A registered second mate. (home: %s; scope: a test scope; projects: ; added 2026-10-21)\n' "$sm" \
    >> "$primary/data/secondmates.md"
}

# dispatch <home> [harness] [model]: run the guard against a home. Echoes the
# output and returns the guard's exit code.
dispatch() {
  local home=$1 harness=${2:-minimax-code} model=${3:-minimax/MiniMax-M3.1-Flash}
  env FM_HOME="$home" FM_DISPATCH_GUARD_LOG="$LOG" "$GUARD" "$harness" "$model" 2>&1
}

# assert_refused <name> <home> [harness] [model]
assert_refused() {
  local name=$1 home=$2
  shift 2
  local out rc
  out=$(dispatch "$home" "$@")
  rc=$?
  if [ "$rc" != 64 ]; then
    fail "$name (rc=$rc, want 64): $out"
  fi
  case "$out" in
    *REFUSED*) : ;;
    *) fail "$name (no REFUSED reason on stderr: $out)" ;;
  esac
  pass "$name"
}

# assert_allowed <name> <home> [harness] [model]
assert_allowed() {
  local name=$1 home=$2
  shift 2
  local out rc
  out=$(dispatch "$home" "$@")
  rc=$?
  if [ "$rc" != 0 ]; then
    fail "$name (rc=$rc, want 0): $out"
  fi
  pass "$name"
}

# assert_account <expected> <actual> <label>: assert the account identity and
# say so out loud, so a passing attribution is visible rather than silent.
assert_account() {
  if [ "$1" != "$2" ]; then
    fail "$3 (expected '$1', got '$2')"
  fi
  pass "$3"
}

# --- A: the account attribution ----------------------------------------------
#
# The provider attribution stays the provider attribution; the ACCOUNT is what
# the ceiling binds. Both are asserted, because a change that quietly folded
# the attribution would move a number the documentation pins.

test_account_attribution() {
  local home meta got provider
  home=$(new_home account-attribution)

  meta="$home/a.meta"
  printf 'harness=minimax-code\nmodel=minimax/MiniMax-M3.1-Flash\n' > "$meta"
  provider=$(fm_dispatch_guard_provider_of_meta "$meta")
  got=$(fm_dispatch_guard_account_of_meta "$meta")
  assert_account "minimax" "$got" "a prefixed model names the minimax account"
  assert_account "minimax" "$provider" "the provider attribution is unchanged"

  meta="$home/b.meta"
  printf 'harness=minimax-code\nmodel=MiniMax-M3.1-Flash\n' > "$meta"
  provider=$(fm_dispatch_guard_provider_of_meta "$meta")
  got=$(fm_dispatch_guard_account_of_meta "$meta")
  assert_account "minimax-code" "$provider" "the provider attribution still falls back to the harness"
  assert_account "minimax" "$got" "an unprefixed MiniMax model on the MCode adapter is the minimax account"

  meta="$home/c.meta"
  printf 'harness=pi\nmodel=MiniMax-M2.7\n' > "$meta"
  provider=$(fm_dispatch_guard_provider_of_meta "$meta")
  got=$(fm_dispatch_guard_account_of_meta "$meta")
  assert_account "pi" "$provider" "the provider attribution still falls back to the harness"
  assert_account "minimax" "$got" "a MiniMax model on a pi adapter is the minimax account"

  meta="$home/d.meta"
  printf 'harness=codex\nmodel=openai-codex/gpt-6-luna\n' > "$meta"
  provider=$(fm_dispatch_guard_provider_of_meta "$meta")
  got=$(fm_dispatch_guard_account_of_meta "$meta")
  assert_account "openai-codex" "$provider" "the provider attribution is unchanged"
  assert_account "codex" "$got" "the openai-codex prefix is the codex account"

  meta="$home/e.meta"
  printf 'harness=codex\nmodel=gpt-6-luna\n' > "$meta"
  got=$(fm_dispatch_guard_account_of_meta "$meta")
  assert_account "codex" "$got" "a bare gpt model is the codex account"

  meta="$home/f.meta"
  printf 'harness=agy\nmodel=gemini-3.1-pro-high\n' > "$meta"
  got=$(fm_dispatch_guard_account_of_meta "$meta")
  assert_account "agy" "$got" "a gemini model is the agy account"

  meta="$home/g.meta"
  printf 'harness=some-future-adapter\nmodel=some-future-model\n' > "$meta"
  provider=$(fm_dispatch_guard_provider_of_meta "$meta")
  got=$(fm_dispatch_guard_account_of_meta "$meta")
  assert_account "some-future-adapter" "$provider" "an unknown lane still resolves a provider"
  assert_account "some-future-adapter" "$got" "an unknown lane falls back to its provider, never to empty"
}

# --- B: the per-account ceiling itself ---------------------------------------

test_per_account_cap() {
  local home
  home=$(new_home per-account-cap)
  printf '%s\n' '{ "harness": "minimax-code", "max_lanes": 9, "max_provider_lanes": 2 }' \
    > "$home/config/dispatch.json"

  # The ceiling is the count the account may REACH: the guard runs before the
  # spawn, so one lane on an account whose ceiling is two is allowed (the
  # second fits) and two lanes are refused (the third would not).
  lane "$home" "l1" minimax-code minimax/MiniMax-M3.1-Flash
  assert_allowed "one lane on an account is allowed under the cap of 2" "$home"

  lane "$home" "l2" minimax-code minimax/MiniMax-M3.1-Flash
  local out
  out=$(dispatch "$home")
  case "$out" in
    *minimax*) : ;;
    *) fail "the refusal names the credential account: $out" ;;
  esac
  case "$out" in
    *cap*) : ;;
    *) fail "the refusal names the ceiling: $out" ;;
  esac
  assert_refused "a dispatch is refused once the account holds as many lanes as its ceiling" "$home"

  # A lane on ANOTHER account does not consume this account's slot: the two
  # accounts are counted apart, which is the whole point of attributing a lane
  # to an account rather than to a provider name.
  local other
  other=$(new_home per-account-cap-other)
  printf '%s\n' '{ "harness": "minimax-code", "max_lanes": 9, "max_provider_lanes": 2 }' \
    > "$other/config/dispatch.json"
  lane "$other" "c1" codex openai-codex/gpt-6-luna
  assert_allowed "a lane on another account does not consume this account's slot" "$other"
}

# --- C: the FLEET-WIDE count over our own registered homes -------------------
#
# This is the gap. Before it, the live-lane inventory walked only THIS home's
# state/*.meta, so a lane in a registered second-mate home never occupied our
# account's slot even though it spends from the same credential.

test_fleet_wide_count() {
  local primary sm
  primary=$(new_home fleet-primary)
  sm=$(new_home fleet-secondmate)

  printf '%s\n' '{ "harness": "minimax-code", "max_lanes": 9, "max_provider_lanes": 1 }' \
    > "$primary/config/dispatch.json"
  register "$primary" "$sm"

  # The registered second-mate home holds one lane on our account.
  lane "$sm" "sm1" minimax-code minimax/MiniMax-M3.1-Flash

  assert_refused "a lane in a REGISTERED second-mate home occupies our account's slot" "$primary"

  # The same lane recorded under a spelling that lands in another bucket is
  # still the same account, so the ceiling still binds.
  local sm2
  sm2=$(new_home fleet-secondmate-unprefixed)
  lane "$sm2" "sm2" pi MiniMax-M2.7
  register "$primary" "$sm2"
  assert_refused "a second-mate lane recorded under another spelling is the same account" "$primary"

  # The live-lane ceiling is HOME-LOCAL, so a second-mate lane does not
  # consume this home's own lane slots. Only the account slot is shared.
  local local_cap
  local_cap=$(new_home fleet-lane-cap)
  printf '%s\n' '{ "harness": "minimax-code", "max_lanes": 1, "max_provider_lanes": 9 }' \
    > "$local_cap/config/dispatch.json"
  register "$local_cap" "$sm"
  assert_allowed "a second-mate lane does not consume this home's live-lane slots" "$local_cap"
}

# --- D: another fleet's work is never counted --------------------------------

test_unregistered_home_is_not_counted() {
  local primary foreign
  primary=$(new_home foreign-primary)
  foreign=$(new_home foreign-home)

  printf '%s\n' '{ "harness": "minimax-code", "max_lanes": 9, "max_provider_lanes": 1 }' \
    > "$primary/config/dispatch.json"
  # The foreign home is NOT registered with us. Its lane is another fleet's
  # work and must never be counted as ours.
  lane "$foreign" "x1" minimax-code minimax/MiniMax-M3.1-Flash

  assert_allowed "an UNREGISTERED home's lane is never counted as ours" "$primary"
}

# --- E: the registry is the only source --------------------------------------

test_registry_is_the_only_source() {
  local primary
  primary=$(new_home registry-source)
  printf '%s\n' '{ "harness": "minimax-code", "max_lanes": 9, "max_provider_lanes": 9 }' \
    > "$primary/config/dispatch.json"

  local homes
  homes=$(FM_HOME="$primary" fm_dispatch_guard_fleet_homes)
  case "$homes" in
    *"$primary"*) : ;;
    *) fail "the home itself is always part of its own fleet" ;;
  esac

  # A home that does not exist is not counted, and a home that is registered
  # twice is counted once.
  local sm dup
  sm=$(new_home registry-secondmate)
  dup=$(new_home registry-duplicate)
  register "$primary" "$sm"
  register "$primary" "$dup"
  register "$primary" "$TMP_ROOT/registry-absent-home"

  homes=$(FM_HOME="$primary" fm_dispatch_guard_fleet_homes)
  assert_equals "3" "$(printf '%s\n' "$homes" | grep -c .)" "the fleet is this home plus its registered homes"
  assert_equals "1" "$(printf '%s\n' "$homes" | grep -cF -- "$sm")" "a registered home is listed once"
  assert_equals "1" "$(printf '%s\n' "$homes" | grep -cF -- "$dup")" "a second registered home is listed once"

  # A home with no registry at all still counts itself.
  local bare
  bare=$(new_home registry-bare)
  assert_equals "1" "$(FM_HOME="$bare" fm_dispatch_guard_fleet_homes | grep -c .)" \
    "a home with no registry is its own fleet"
}

test_account_attribution
test_per_account_cap
test_fleet_wide_count
test_unregistered_home_is_not_counted
test_registry_is_the_only_source
