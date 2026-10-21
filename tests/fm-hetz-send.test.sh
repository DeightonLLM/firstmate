#!/usr/bin/env bash
# Behavioral regressions for the outbound Hetz send helper's truthfulness.
#
# The live helper unconditionally echoed "sent" after the ssh call, so a failed
# transfer - ssh_rc=1 - reported success. That false success is worse than a
# visible failure: a caller believes Hetz received a message it never got, and
# an unanswered request stays unanswered while looking answered.
#
# These tests drive the helper's public interface only, with ssh stubbed, and
# never touch the real remote.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SEND="$ROOT/bin/fm-hetz-send.sh"
TMP_ROOT=$(fm_test_tmproot fm-hetz-send)

# A stub ssh that records how it was called and exits with a chosen code.
# It runs the requested remote command locally, so remote semantics are real: a
# missing inbox directory fails the way the far side would fail. The message body
# is captured on the way past, then replayed into that remote command.
make_ssh_stub() {  # <rc> -> echoes "<fakebin>"
  local rc=$1 fakebin
  fakebin=$(fm_fakebin "$TMP_ROOT/ssh-$rc")
  cat >"$fakebin/ssh" <<SH
#!/usr/bin/env bash
printf '%s\n' "\$@" >>"$TMP_ROOT/ssh-$rc/calls.txt"
cat > "$TMP_ROOT/ssh-$rc/stdin.txt"
remote_cmd=\${!#}
eval "\$remote_cmd" < "$TMP_ROOT/ssh-$rc/stdin.txt"
exit $rc
SH
  chmod +x "$fakebin/ssh"
  printf '%s\n' "$fakebin"
}

# The remote inbox this home would write into. It must exist for a transfer to
# be reported as delivered, so the stub's remote command has a real directory.
inbox_for() {  # <rc> -> echoes a fresh, existing inbox path
  local d
  d="$TMP_ROOT/ssh-$1/inbox"
  mkdir -p "$d"
  printf '%s\n' "$d"
}

run_send() {  # <fakebin> <rc> <message...>
  local fakebin=$1 rc=$2
  shift 2
  PATH="$fakebin:$PATH" FM_HETZ_LOG="$TMP_ROOT/outbound.log" \
    FM_HETZ_HOST=temp-target.test FM_HETZ_INBOUND="$(inbox_for "$rc")" \
    "$SEND" "$@" 2>&1
}

# A successful transfer reports sent, and the message actually left.
test_success_reports_sent() {
  local fakebin out code
  fakebin=$(make_ssh_stub 0)
  out=$(run_send "$fakebin" 0 "hello from the controller")
  code=$?
  expect_code 0 "$code" "a successful send must exit 0"
  assert_contains "$out" "sent" "a successful transfer does not report success"
  assert_present "$TMP_ROOT/ssh-0/stdin.txt" "the message never reached ssh"
  pass "a successful transfer reports sent"
}

# The defect: ssh fails, yet the helper still claims success.
test_failure_must_not_report_sent() {
  local fakebin out code
  fakebin=$(make_ssh_stub 1)
  out=$(run_send "$fakebin" 1 "hello from the controller")
  code=$?
  if [ "$code" -eq 0 ]; then
    fail "a failed transfer exited 0, so the caller reads it as delivered"
    # shellcheck disable=SC2317 # Guard clause: fail already exits, so this return is only a readability guard.
    return
  fi
  assert_not_contains "$out" "sent at" \
    "a failed transfer is still reported as sent (the false-success defect)"
  pass "a failed transfer does not report sent"
}

# A refused connection must be as loud as any other failure, and must still
# leave the outbound log honest about what the controller believed it sent.
test_failure_names_the_real_rc() {
  local fakebin out
  fakebin=$(make_ssh_stub 255)
  out=$(run_send "$fakebin" 255 "hello from the controller")
  assert_contains "$out" "255" \
    "the failure does not report the real ssh return code"
  pass "a failed transfer reports the real ssh return code"
}

# An empty message is a usage error, never a silent no-op that still logs.
test_empty_message_is_a_usage_error() {
  local fakebin out code
  fakebin=$(make_ssh_stub 0)
  out=$(FM_HETZ_LOG="$TMP_ROOT/outbound.log" "$SEND" "" 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    fail "an empty message was accepted"
    # shellcheck disable=SC2317 # Guard clause: fail already exits, so this return is only a readability guard.
    return
  fi
  assert_contains "$out" "Usage:" "an empty message does not print usage"
  pass "an empty message is refused as a usage error"
}

# ---------------------------------------------------------------------------
# Ticket 0029 defect 2: the default remote inbox does not exist on Hetz.
#
# RED note: before the fix the default was /tmp/hetzner-inbound and an absent
# inbox surfaced only as a bare ssh error, so neither assertion below held - the
# default pointed at the wrong directory and no remediation was ever printed.
# ---------------------------------------------------------------------------

# The default must be the folder Hetz actually reads, not the stale tmp path.
test_default_inbox_is_the_folder_hetz_reads() {
  local fakebin out
  fakebin=$(make_ssh_stub 3)
  # Stub ssh to 3 = the helper's "remote inbox absent" sentinel, so the message
  # echoes the inbound path the script actually chose.
  out=$(PATH="$fakebin:$PATH" FM_HETZ_LOG="$TMP_ROOT/outbound.log" \
    "$SEND" "hello" 2>&1)
  assert_contains "$out" "/home/hd2admin/controller-replies" \
    "the default inbound is not the directory Hetz reads"
  assert_not_contains "$out" "/tmp/hetzner-inbound" \
    "the default inbound is still the absent /tmp/hetzner-inbound"
  pass "the default inbound is the folder Hetz reads"
}

# An absent inbox must fail closed loudly, with the exact remediation.
test_absent_inbox_fails_closed_with_remediation() {
  local fakebin out code
  fakebin=$(make_ssh_stub 3)
  out=$(PATH="$fakebin:$PATH" FM_HETZ_LOG="$TMP_ROOT/outbound.log" \
    "$SEND" "hello from the controller" 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    fail "an absent remote inbox exited 0, so the caller reads it as delivered"
    # shellcheck disable=SC2317 # Guard clause: fail already exits, so this return is only a readability guard.
    return
  fi
  assert_not_contains "$out" "sent at" \
    "an absent remote inbox is still reported as sent"
  assert_contains "$out" "absent" \
    "an absent remote inbox is not named as absent"
  assert_contains "$out" "remediation" \
    "an absent remote inbox does not print the exact remediation"
  assert_contains "$out" "FM_HETZ_INBOUND" \
    "the remediation does not name the override that fixes it"
  pass "an absent remote inbox fails closed with the exact remediation"
}

# The guard must not swallow a genuine transport failure: a non-sentinel rc is
# still reported verbatim, so this hardening cannot mask the original defect.
test_transport_failure_still_reports_real_rc() {
  local fakebin out
  fakebin=$(make_ssh_stub 1)
  # run_send takes the stub's exit code as its second argument, so the stub and
  # the sender agree on which failure they are exercising.
  out=$(run_send "$fakebin" 1 "hello from the controller")
  assert_contains "$out" "ssh rc=1" \
    "a transport failure no longer reports its real ssh return code"
  assert_not_contains "$out" "absent" \
    "a transport failure is misreported as an absent inbox"
  pass "a transport failure is not misreported as an absent inbox"
}

# A configured override must still win over the corrected default.
test_explicit_override_is_honoured() {
  local fakebin out
  fakebin=$(make_ssh_stub 3)
  out=$(PATH="$fakebin:$PATH" FM_HETZ_LOG="$TMP_ROOT/outbound.log" \
    FM_HETZ_INBOUND=/home/hd2admin/somewhere-else "$SEND" "hello" 2>&1)
  assert_contains "$out" "/home/hd2admin/somewhere-else" \
    "an explicit FM_HETZ_INBOUND override is ignored"
  pass "an explicit FM_HETZ_INBOUND override is honoured"
}

test_success_reports_sent
test_failure_must_not_report_sent
test_failure_names_the_real_rc
test_empty_message_is_a_usage_error
test_default_inbox_is_the_folder_hetz_reads
test_absent_inbox_fails_closed_with_remediation
test_transport_failure_still_reports_real_rc
test_explicit_override_is_honoured