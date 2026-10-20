#!/usr/bin/env bash
# Behavioral regressions for notify-route resolution and inbox validation in the
# outbound Hetz send helper.
#
# WHY THIS EXISTS. A notify helper that reports success while nothing was
# delivered is worse than one that fails loudly: the controller records an
# unanswered request as delivered and nobody ever chases it. This file locks
# three properties of bin/fm-hetz-send.sh:
#
#   1. A route that does not resolve against the registry is refused loudly,
#      before any transport is attempted, so no success line is ever printed.
#   2. A remote inbox that does not exist is named as missing and fails loudly
#      instead of degrading into an opaque transport return code.
#   3. Two sends issued within the same second must both survive. The remote
#      name is derived from a second-resolution timestamp, so two rapid sends
#      once produced ONE file holding only the second message while BOTH sends
#      printed "sent at" and exited 0. That is the silent notify failure.
#
# Every test drives the helper's public interface with ssh stubbed, so no real
# remote is contacted and no real recipient is ever notified.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SEND="$ROOT/bin/fm-hetz-send.sh"
TMP_ROOT=$(fm_test_tmproot fm-hetz-send-route)

# --- fixtures ---------------------------------------------------------------

# A faithful ssh stub: it runs the requested remote command locally, so remote
# semantics (a missing directory fails the redirect) are reproduced exactly,
# and it records every invocation so a test can prove nothing was attempted.
#
# Stub side effects:
#   $TMP_ROOT/<tag>/calls.txt   one line per ssh invocation
#   $TMP_ROOT/<tag>/hosts.txt   the target host of each invocation
make_ssh_stub() {  # <tag> -> echoes "<fakebin>"
  local tag=$1 fakebin
  fakebin=$(fm_fakebin "$TMP_ROOT/$tag")
  cat >"$fakebin/ssh" <<SH
#!/usr/bin/env bash
calls="$TMP_ROOT/$tag/calls.txt"
hosts="$TMP_ROOT/$tag/hosts.txt"
printf '%s\n' "\$*" >>"\$calls"
for a in "\$@"; do
  case "\$a" in
    -o|*.invalid|*.test) : ;;
    *) printf '%s\n' "\$a" >>"\$hosts" ;;
  esac
done
remote_cmd=\${!#}
eval "\$remote_cmd"
SH
  chmod +x "$fakebin/ssh"
  printf '%s\n' "$fakebin"
}

write_registry() {  # <path>; stdin is the registry body
  mkdir -p "$(dirname "$1")"
  cat >"$1"
}

# --- 1. an unresolvable route fails loudly ----------------------------------

# The defect: the helper's route is a hardcoded literal, so a caller cannot name
# a route at all and an unregistered id cannot be rejected - the send either goes
# somewhere the registry does not describe or dies on a transport error that says
# nothing about the route being unknown.
test_unregistered_route_is_refused_before_any_transport() {
  local fakebin reg out code
  fakebin=$(make_ssh_stub unreg)
  reg="$TMP_ROOT/registry.tsv"
  write_registry "$reg" <<'TSV'
# id	host	inbox
hetz-inbound	temp-a.test	/tmp/wo0006l2-present-inbox
TSV
  out=$(PATH="$fakebin:$PATH" FM_ROOT_OVERRIDE="$ROOT" FM_HETZ_LOG="$TMP_ROOT/unreg.log" \
    FM_HETZ_ROUTE_REGISTRY="$reg" FM_HETZ_HOST=temp-b.test \
    FM_HETZ_INBOUND="$TMP_ROOT/wo0006l2-present-inbox" \
    "$SEND" --route hetz-nowhere "WO-0006-L2 unresolvable route probe" 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    fail "an unregistered route id exited 0, so the caller reads it as delivered"$'\n'"--- output ---"$'\n'"$out"
  fi
  assert_not_contains "$out" "sent at" \
    "an unregistered route still reports a successful send"
  assert_contains "$out" "hetz-nowhere" \
    "the refusal does not name the route id that failed to resolve"
  assert_contains "$out" "not registered" \
    "the refusal does not say the route is unregistered"
  if [ -s "$TMP_ROOT/unreg/calls.txt" ]; then
    fail "an unresolvable route still attempted a transport"$'\n'"--- calls ---"$'\n'"$(cat "$TMP_ROOT/unreg/calls.txt")"
  fi
  pass "an unregistered route is refused before any transport is attempted"
}

# A registry that does not exist at all is a missing authority, not a licence to
# fall back to a hardcoded route.
test_absent_registry_is_refused_for_an_explicit_route() {
  local fakebin out code
  fakebin=$(make_ssh_stub noreg)
  out=$(PATH="$fakebin:$PATH" FM_ROOT_OVERRIDE="$ROOT" FM_HETZ_LOG="$TMP_ROOT/noreg.log" \
    FM_HETZ_ROUTE_REGISTRY="$TMP_ROOT/does-not-exist.tsv" FM_HETZ_HOST=temp-target.test \
    "$SEND" --route hetz-inbound "WO-0006-L2 absent registry probe" 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    fail "a missing route registry exited 0"$'\n'"--- output ---"$'\n'"$out"
  fi
  assert_not_contains "$out" "sent at" "a missing route registry still reports success"
  assert_contains "$out" "does-not-exist.tsv" \
    "the refusal does not name the registry that could not be read"
  if [ -s "$TMP_ROOT/noreg/calls.txt" ]; then
    fail "a missing route registry still attempted a transport"
  fi
  pass "an absent registry is refused instead of silently falling back"
}

# A registered id must actually be used: the resolved host and inbox, not the
# literals the caller happened to export, are what receive the message.
test_registered_route_resolves_to_its_own_host_and_inbox() {
  local fakebin reg inbox out code
  fakebin=$(make_ssh_stub reg)
  inbox="$TMP_ROOT/wo0006l2-reg-inbox"
  mkdir -p "$inbox"
  reg="$TMP_ROOT/registry-resolve.tsv"
  write_registry "$reg" <<TSV
hetz-inbound	temp-resolved.test	$inbox
TSV
  out=$(PATH="$fakebin:$PATH" FM_ROOT_OVERRIDE="$ROOT" FM_HETZ_LOG="$TMP_ROOT/reg.log" \
    FM_HETZ_ROUTE_REGISTRY="$reg" FM_HETZ_HOST=temp-wrong.test \
    FM_HETZ_INBOUND=/tmp/wo0006l2-should-not-be-used \
    "$SEND" --route hetz-inbound "WO-0006-L2 resolved route probe" 2>&1)
  code=$?
  expect_code 0 "$code" "a registered, resolvable route must succeed"
  assert_contains "$out" "sent at" "a resolved route does not report a send"
  if [ "$(find "$inbox" -maxdepth 1 -type f | wc -l)" -ne 1 ]; then
    fail "the message did not arrive in the registry's inbox"$'\n'"--- inbox ---"$'\n'"$(ls -la "$inbox")"
  fi
  pass "a registered route resolves to its own host and inbox"
}

# --- 2. an absent inbox fails loudly ---------------------------------------

# The defect: a missing remote inbox surfaces only as an opaque transport return
# code, so the operator sees "ssh rc=1" and cannot tell an absent inbox from a
# refused key, a full disk or a wrong path. It must be named.
test_absent_inbox_is_named_and_fails_loudly() {
  local fakebin out code
  fakebin=$(make_ssh_stub noinbox)
  out=$(PATH="$fakebin:$PATH" FM_ROOT_OVERRIDE="$ROOT" FM_HETZ_LOG="$TMP_ROOT/noinbox.log" \
    FM_HETZ_HOST=temp-target.test FM_HETZ_INBOUND="$TMP_ROOT/wo0006l2-absent-inbox" \
    "$SEND" "WO-0006-L2 absent inbox probe" 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    fail "an absent remote inbox exited 0, so the caller reads it as delivered"$'\n'"--- output ---"$'\n'"$out"
  fi
  assert_not_contains "$out" "sent at" "an absent remote inbox still reports a send"
  assert_contains "$out" "inbox is missing" \
    "the failure does not diagnose the absent inbox as missing"
  assert_contains "$out" "wo0006l2-absent-inbox" \
    "the failure does not name the absent inbox path"
  assert_absent "$TMP_ROOT/wo0006l2-absent-inbox" \
    "a missing inbox was created as a side effect of the failed send"
  pass "an absent remote inbox is named and fails loudly"
}

# --- 3. no silent message loss ---------------------------------------------

# The defect, reproduced: the remote name carries a second-resolution timestamp,
# so two sends inside one second collide. Both reported "sent" and exited 0 while
# the inbox held one file containing only the second message.
test_two_sends_in_one_second_both_survive() {
  local fakebin inbox first_count
  fakebin=$(make_ssh_stub collide)
  inbox="$TMP_ROOT/wo0006l2-collide-inbox"
  mkdir -p "$inbox"
  local i
  for i in 1 2; do
    PATH="$fakebin:$PATH" FM_ROOT_OVERRIDE="$ROOT" FM_HETZ_LOG="$TMP_ROOT/collide.log" \
      FM_HETZ_HOST=temp-target.test FM_HETZ_INBOUND="$inbox" \
      "$SEND" "WO-0006-L2 rapid message number $i" >/dev/null 2>&1 \
      || fail "rapid send $i reported failure against a healthy target"
  done
  first_count=$(find "$inbox" -maxdepth 1 -type f | wc -l)
  if [ "$first_count" -ne 2 ]; then
    fail "two successful sends left $first_count message(s) in the inbox, so one was silently destroyed"$'\n'"--- inbox ---"$'\n'"$(ls -la "$inbox")"$'\n'"--- content ---"$'\n'"$(cat "$inbox"/* 2>/dev/null)"
  fi
  if ! grep -q 'rapid message number 1' "$inbox"/* 2>/dev/null; then
    fail "the first message was silently lost"$'\n'"--- content ---"$'\n'"$(cat "$inbox"/* 2>/dev/null)"
  fi
  if ! grep -q 'rapid message number 2' "$inbox"/* 2>/dev/null; then
    fail "the second message is missing"$'\n'"--- content ---"$'\n'"$(cat "$inbox"/* 2>/dev/null)"
  fi
  pass "two sends within one second both survive in the remote inbox"
}

# The remote write must never silently clobber an existing message: the write
# refuses to overwrite, so a collision is a loud failure instead of data loss.
# FM_HETZ_MSG_NAME pins the remote file name so the collision is reproducible.
test_existing_message_is_never_silently_overwritten() {
  local fakebin inbox out code
  fakebin=$(make_ssh_stub noclobber)
  inbox="$TMP_ROOT/wo0006l2-noclobber-inbox"
  mkdir -p "$inbox"
  printf 'PRE-EXISTING MESSAGE\n' >"$inbox/msg-000000.msg"
  out=$(PATH="$fakebin:$PATH" FM_ROOT_OVERRIDE="$ROOT" FM_HETZ_LOG="$TMP_ROOT/noclobber.log" \
    FM_HETZ_HOST=temp-target.test FM_HETZ_INBOUND="$inbox" FM_HETZ_MSG_NAME=msg-000000.msg \
    "$SEND" "WO-0006-L2 message that must not clobber" 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    fail "a send reported success while the remote write refused to overwrite"$'\n'"--- output ---"$'\n'"$out"
  fi
  assert_not_contains "$out" "sent at" \
    "a refused overwrite still reports a successful send"
  if ! grep -q 'PRE-EXISTING MESSAGE' "$inbox/msg-000000.msg"; then
    fail "an existing remote message was overwritten by a send that reported failure"
  fi
  pass "an existing remote message is never silently overwritten"
}

test_unregistered_route_is_refused_before_any_transport
test_absent_registry_is_refused_for_an_explicit_route
test_registered_route_resolves_to_its_own_host_and_inbox
test_absent_inbox_is_named_and_fails_loudly
test_two_sends_in_one_second_both_survive
test_existing_message_is_never_silently_overwritten