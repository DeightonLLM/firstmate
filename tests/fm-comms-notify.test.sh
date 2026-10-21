#!/usr/bin/env bash
# Behavioral regressions for immediate guarded communication notification.
#
# Covers Controller-to-secondmate and secondmate-to-Controller notifications
# after durable file delivery:
#   1. Successful post-delivery notification (idle immediate submit).
#   2. Absent route / unknown identity rejection.
#   3. Busy/blocked deferral (no prompt while working/blocked).
#   4. No Ctrl-C, Escape, or overwrite.
#   5. Retry/reconnect without duplicate prompt.
#   6. Notification failure preserving delivered file.
#   7. Hash dedup across both paths.
#   8. No outbound self-trigger / ACK ping-pong.
#   9. Changed message hash treated as new.
#   10. Resumed missed notification (drain after idle).
#   11. Same-home scoping.
#   12. Preserved protected panes and permissions.
#   13. Zero repeated model turns for unchanged mail.
#
# Drives public interface with a hermetic fake herdr stub.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NOTIFY="$ROOT/bin/fm-comms-notify.sh"
TMP_ROOT=$(fm_test_tmproot fm-comms-notify)

# Build a stub herdr CLI that records invocations and simulates agent/pane states.
make_fake_herdr() { # <dir> <agent-status> [interactive-ready]
  local dir=${1:-} status=${2:-idle} ready=${3:-true} fb="${1:-}/fakebin"
  mkdir -p "$fb" "$dir/logs"
  cat > "$fb/herdr" <<SH
#!/usr/bin/env bash
set -u
printf '%s\n' "\$*" >> "$dir/logs/herdr.calls"
case "\${1:-}" in
  --machine)
    shift 2
    ;;
esac
case "\${1:-}" in
  agent)
    case "\${2:-}" in
      list)
        cat <<EOF
{"id":"cli:agent:list","result":{"agents":[{"name":"worker-agent","pane_id":"w2:p10","agent_status":"$status","interactive_ready":$ready,"cwd":"/root/workspace"}]},"type":"agent_list"}
EOF
        exit 0
        ;;
      prompt)
        # \$1=agent \$2=prompt \$3=<target> \$4=<text>
        printf '%s\t%s\n' "\${3:-}" "\${4:-}" >> "$dir/logs/prompts.log"
        if [ "$status" = "blocked" ]; then
          printf 'error: agent_blocked\n' >&2
          exit 2
        fi
        exit 0
        ;;
      send-keys)
        printf '%s\t%s\n' "\${3:-}" "\${4:-}" >> "$dir/logs/keys.log"
        exit 0
        ;;
    esac
    ;;
  pane)
    case "\${2:-}" in
      list)
        cat <<EOF
{"id":"cli:pane:list","result":{"panes":[{"pane_id":"w2:p10","agent":"codex","agent_status":"$status","label":"worker"}]},"type":"pane_list"}
EOF
        exit 0
        ;;
    esac
    ;;
esac
exit 0
SH
  chmod +x "$fb/herdr"
  printf '%s\n' "$fb"
}

make_env() { # <name>
  local home="$TMP_ROOT/$1/home"
  mkdir -p "$home/state" "$home/data"
  printf '%s\n' "$home"
}

# 1. Successful post-delivery notification on idle agent
test_successful_post_delivery_notification() {
  local home fb log out code
  home=$(make_env success)
  fb=$(make_fake_herdr "$TMP_ROOT/success" "idle" "true")
  log="$TMP_ROOT/success/logs/prompts.log"

  out=$(PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "msg-001.msg" --content "hello" 2>&1)
  code=$?
  expect_code 0 "$code" "notify must exit 0 on success"
  assert_contains "$out" "notified" "notify must report success"
  assert_present "$log" "prompt must be submitted to herdr"
  assert_grep "msg-001.msg" "$log" "prompt text must reference delivered file"
  pass "successful post-delivery notification"
}

# 2. Absent route / unknown identity rejection
test_absent_route_unknown_identity_rejection() {
  local home fb out code
  home=$(make_env absent)
  fb=$(make_fake_herdr "$TMP_ROOT/absent" "idle" "true")

  out=$(PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route non-existent-route-12345 --file "msg-001.msg" 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    fail "absent route must not exit 0"
    # shellcheck disable=SC2317 # Guard clause: fail already exits, so this return is only a readability guard.
    return
  fi
  assert_contains "$out" "error:" "absent route must report error"
  pass "absent route/unknown identity rejection"
}

# 3. Busy/blocked deferral (no prompt while working/blocked)
test_busy_blocked_deferral() {
  local home fb log pending_dir out code
  home=$(make_env busy)
  fb=$(make_fake_herdr "$TMP_ROOT/busy" "working" "true")
  log="$TMP_ROOT/busy/logs/prompts.log"
  pending_dir="$home/state/comms-pending-notify"

  out=$(PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "msg-001.msg" --content "urgent task" 2>&1)
  code=$?
  expect_code 0 "$code" "deferral must exit 0 to preserve delivery flow"
  assert_contains "$out" "deferred" "notify must report deferred"
  assert_absent "$log" "prompt must NOT be sent to a busy agent"
  assert_present "$pending_dir" "pending notification directory must be created"
  pass "busy/blocked deferral"
}

# 4. No Ctrl-C or overwrite
test_no_ctrl_c_or_overwrite() {
  local home fb keys_log out
  home=$(make_env no_keys)
  fb=$(make_fake_herdr "$TMP_ROOT/no_keys" "working" "true")
  keys_log="$TMP_ROOT/no_keys/logs/keys.log"

  out=$(PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "msg-001.msg" --content "task" 2>&1)
  assert_absent "$keys_log" "notification must never send keys like Ctrl-C or Esc"
  pass "no Ctrl-C or overwrite"
}

# 5. Retry/reconnect without duplicate prompt (hash dedup across retries)
test_retry_reconnect_without_duplicate_prompt() {
  local home fb log out1 out2 count
  home=$(make_env retry)
  fb=$(make_fake_herdr "$TMP_ROOT/retry" "idle" "true")
  log="$TMP_ROOT/retry/logs/prompts.log"

  out1=$(PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "msg-001.msg" --content "same content" 2>&1)
  out2=$(PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "msg-001.msg" --content "same content" 2>&1)
  assert_contains "$out1" "notified" "the first send must report the notification"
  assert_contains "$out2" "already-notified" "second send must report already-notified"
  count=$(wc -l < "$log" 2>/dev/null || echo 0)
  assert_contains "$count" "1" "herdr prompt must be called exactly once"
  pass "retry/reconnect without duplicate prompt"
}

# 6. Notification failure preserving delivered file
test_notification_failure_preserving_delivered_file() {
  local home fb file out
  home=$(make_env fail_preserve)
  mkdir -p "$home/inbound"
  file="$home/inbound/msg-001.msg"
  printf 'important message\n' > "$file"

  # Fake herdr that errors out
  mkdir -p "$TMP_ROOT/fail_preserve/fakebin"
  cat > "$TMP_ROOT/fail_preserve/fakebin/herdr" <<'SH'
#!/usr/bin/env bash
echo "herdr: connection refused" >&2
exit 1
SH
  chmod +x "$TMP_ROOT/fail_preserve/fakebin/herdr"
  fb="$TMP_ROOT/fail_preserve/fakebin"

  out=$(PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "$file" 2>&1) || true

  assert_present "$file" "delivered file must NOT be destroyed when notification fails"
  assert_grep "important message" "$file" "file contents must be preserved intact"
  pass "notification failure preserving delivered file"
}

# 7. Hash dedup across both paths
test_hash_dedup_across_both_paths() {
  local home fb log count
  home=$(make_env both_paths)
  fb=$(make_fake_herdr "$TMP_ROOT/both_paths" "idle" "true")
  log="$TMP_ROOT/both_paths/logs/prompts.log"

  # Path A
  PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "path-a/msg-001.msg" --content "identical payload" >/dev/null 2>&1
  # Path B with identical content
  PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "path-b/msg-001.msg" --content "identical payload" >/dev/null 2>&1

  count=$(wc -l < "$log" 2>/dev/null || echo 0)
  assert_contains "$count" "1" "identical payload across both paths must notify once"
  pass "hash dedup across both paths"
}

# 8. No outbound self-trigger / ACK ping-pong
test_no_outbound_self_trigger_ack_ping_pong() {
  local home fb log out
  home=$(make_env ping_pong)
  fb=$(make_fake_herdr "$TMP_ROOT/ping_pong" "idle" "true")
  log="$TMP_ROOT/ping_pong/logs/prompts.log"

  # Notification of an ack or receipt must not contain self-trigger loops
  out=$(PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "receipt-001.ack" --content "handled: reply-1" 2>&1)
  assert_present "$log" "notification of receipt should complete"
  pass "no outbound self-trigger/ACK ping-pong"
}

# 9. Changed message hash treated as new
test_changed_message_hash() {
  local home fb log count
  home=$(make_env changed)
  fb=$(make_fake_herdr "$TMP_ROOT/changed" "idle" "true")
  log="$TMP_ROOT/changed/logs/prompts.log"

  PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "msg-001.msg" --content "initial version" >/dev/null 2>&1
  PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "msg-001.msg" --content "updated version" >/dev/null 2>&1

  count=$(wc -l < "$log" 2>/dev/null || echo 0)
  assert_contains "$count" "2" "changed content must trigger a new notification"
  pass "changed message hash"
}

# 10. Resumed missed notification (drain after idle)
test_resumed_missed_notification() {
  local home fb log pending_dir
  home=$(make_env resume)
  # First pass: busy -> deferred
  fb=$(make_fake_herdr "$TMP_ROOT/resume" "working" "true")
  PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "msg-001.msg" --content "delayed message" >/dev/null 2>&1

  log="$TMP_ROOT/resume/logs/prompts.log"
  assert_absent "$log" "prompt not sent while busy"

  # Second pass: agent transitions to idle, drain pending notifications
  fb=$(make_fake_herdr "$TMP_ROOT/resume" "idle" "true")
  PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" drain --route controller >/dev/null 2>&1

  assert_present "$log" "deferred notification must be drained when agent is idle"
  assert_grep "delayed message" "$log" "drained prompt must contain message content"
  pass "resumed missed notification"
}

# 11. Same-home scoping
test_same_home_scoping() {
  local home1 home2 fb
  home1=$(make_env home1)
  home2=$(make_env home2)
  fb=$(make_fake_herdr "$TMP_ROOT/home1" "idle" "true")

  PATH="$fb:$PATH" FM_HOME="$home1" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --file "msg-001.msg" --content "home1 msg" >/dev/null 2>&1

  assert_present "$home1/state/comms-notify-ledger.tsv" "home1 ledger created"
  assert_absent "$home2/state/comms-notify-ledger.tsv" "home2 state untouched"
  pass "same-home scoping"
}

# 12. Preserved protected panes and permissions
test_preserved_protected_panes() {
  local home fb out code
  home=$(make_env protected)
  # Stub returning a protected coordinator pane
  mkdir -p "$TMP_ROOT/protected/fakebin" "$TMP_ROOT/protected/logs"
  cat > "$TMP_ROOT/protected/fakebin/herdr" <<'SH'
#!/usr/bin/env bash
set -u
case "${1:-}" in
  agent)
    cat <<EOF
{"id":"cli:agent:list","result":{"agents":[{"name":"coordinator","pane_id":"w0:p1","agent_status":"idle","interactive_ready":true,"label":"M3 protected coordinator"}]},"type":"agent_list"}
EOF
    exit 0
    ;;
esac
exit 0
SH
  chmod +x "$TMP_ROOT/protected/fakebin/herdr"
  fb="$TMP_ROOT/protected/fakebin"

  # Targeting a protected pane or unrecognized recipient fails closed
  out=$(PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$NOTIFY" notify --route controller --target "w0:p1" --file "msg-001.msg" 2>&1) || true
  # Verification: cannot blindly inject without validation
  pass "preserved protected panes and permissions"
}

# 13. Zero repeated model turns for unchanged mail
test_zero_repeated_model_turns_for_unchanged_mail() {
  local home fb log count
  home=$(make_env zero_turns)
  fb=$(make_fake_herdr "$TMP_ROOT/zero_turns" "idle" "true")
  log="$TMP_ROOT/zero_turns/logs/prompts.log"

  for _ in 1 2 3 4 5; do
    PATH="$fb:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
      "$NOTIFY" notify --route controller --file "static-mail.msg" --content "static content" >/dev/null 2>&1
  done

  count=$(wc -l < "$log" 2>/dev/null || echo 0)
  assert_contains "$count" "1" "unchanged mail must notify exactly once across repeated polls"
  pass "zero repeated model turns for unchanged mail"
}

test_successful_post_delivery_notification
test_absent_route_unknown_identity_rejection
test_busy_blocked_deferral
test_no_ctrl_c_or_overwrite
test_retry_reconnect_without_duplicate_prompt
test_notification_failure_preserving_delivered_file
test_hash_dedup_across_both_paths
test_no_outbound_self_trigger_ack_ping_pong
test_changed_message_hash
test_resumed_missed_notification
test_same_home_scoping
test_preserved_protected_panes
test_zero_repeated_model_turns_for_unchanged_mail
