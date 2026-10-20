#!/usr/bin/env bash
# Exercise the outbound order delivery CLI against an isolated fake SSH target.
set -eu

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPT="$ROOT/bin/fm-outbound-order.sh"
TEST_TMP_BASE=$(mktemp -d "$ROOT/fm-outbound-order-tests.XXXXXX")
export TMPDIR="$TEST_TMP_BASE"
FM_TEST_CLEANUP_DIRS+=("$TEST_TMP_BASE")
trap fm_test_cleanup EXIT

setup_case() {
  local case_root fakebin
  case_root=$(fm_test_tmproot fm-outbound-order)
  FM_HOME="$case_root/home"
  REMOTE_HOME="$case_root/remote-home"
  mkdir -p "$FM_HOME" "$REMOTE_HOME"
  export FM_HOME REMOTE_HOME FM_TEST_REMOTE_HOME="$REMOTE_HOME"
  unset FM_BRANDON_COMPUTE_TARGET
  unset FM_TEST_SCP_FAIL FM_TEST_SCP_CORRUPT
  fakebin=$(fm_fakebin "$case_root")
  cat > "$fakebin/sha256sum" <<'SH'
#!/usr/bin/env bash
set -eu
shasum -a 256 "$1"
SH
  cat > "$fakebin/ssh" <<'SH'
#!/usr/bin/env bash
set -eu
[ "${1:-}" = -T ] || exit 90
shift
[ "${1:-}" = -o ] || exit 91
[ "${2:-}" = BatchMode=yes ] || exit 92
shift 2
[ "${1:-}" = brandon-compute ] || exit 93
shift
[ "${1:-}" = bash ] || exit 94
shift
HOME="$FM_TEST_REMOTE_HOME" exec bash "$@"
SH
  cat > "$fakebin/scp" <<'SH'
#!/usr/bin/env bash
set -eu
[ "${1:-}" = -B ] || exit 80
shift
[ "${1:-}" = -- ] || exit 81
shift
source=$1
target=$2
case "$target" in
  brandon-compute:~/to-brandon-compute/inbox/*) ;;
  *) exit 82 ;;
esac
if [ "${FM_TEST_SCP_FAIL:-0}" = 1 ]; then
  printf 'simulated SCP transport failure\n' >&2
  exit 83
fi
remote_path=${target#*:~/}
destination="$FM_TEST_REMOTE_HOME/$remote_path"
mkdir -p "$(dirname "$destination")"
if [ "${FM_TEST_SCP_CORRUPT:-0}" = 1 ]; then
  printf 'corrupt payload\n' > "$destination"
else
  cat "$source" > "$destination"
fi
SH
  chmod +x "$fakebin/sha256sum" "$fakebin/ssh" "$fakebin/scp"
  PATH="$fakebin:$PATH"
  export PATH
  ORDER_FILE="$case_root/order.md"
  printf 'A selected work order.\n' > "$ORDER_FILE"
  export ORDER_FILE CASE_ROOT="$case_root"
}

run_cli() {
  "$SCRIPT" "$@"
}

expect_failure() {
  local expected_text=$1 output rc
  shift
  rc=0
  output=$(run_cli "$@" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail "expected command failure: $*"
  assert_contains "$output" "$expected_text" "failure should explain the rejected delivery"
  printf '%s\n' "$output"
}

test_target_cannot_be_redirected_by_environment() {
  local output
  setup_case
  export FM_BRANDON_COMPUTE_TARGET=attacker-host
  output=$(run_cli deliver fixed-target "$ORDER_FILE") \
    || fail "configured target override changed the fixed destination: $output"
  assert_contains "$output" 'state=transferred' "delivery must use the fixed Brandon compute target"
  pass "environment cannot redirect explicitly selected work orders away from Brandon compute"
}

test_absent_destination_is_created_and_remotely_verified() {
  local output digest
  setup_case
  [ ! -e "$REMOTE_HOME/to-brandon-compute" ] || fail "remote destination unexpectedly exists"
  output=$(run_cli deliver elevate-order "$ORDER_FILE") || fail "delivery to an absent inbox failed: $output"
  assert_contains "$output" 'state=transferred' "delivery must report a remotely verified transfer"
  [ -f "$REMOTE_HOME/to-brandon-compute/inbox/elevate-order.order" ] \
    || fail "missing remote inbox order"
  cmp -s "$ORDER_FILE" "$REMOTE_HOME/to-brandon-compute/inbox/elevate-order.order" \
    || fail "remote order bytes differ from the selected source"
  digest=$(sha256sum "$ORDER_FILE" | awk '{print $1}')
  [ "$(cat "$REMOTE_HOME/to-brandon-compute/receipts/elevate-order.sha256")" = "$digest" ] \
    || fail "remote receipt does not bind the delivered order checksum"
  output=$(run_cli verify elevate-order) || fail "remote verification failed: $output"
  assert_contains "$output" 'state=transferred' "verification must distinguish transfer from acceptance"
  pass "an absent remote inbox is safely created and verified by matching remote checksum receipt"
}

test_identical_resend_is_idempotent() {
  local output
  setup_case
  run_cli deliver kun-order "$ORDER_FILE" >/dev/null \
    || fail "initial transfer failed"
  output=$(run_cli deliver kun-order "$ORDER_FILE") \
    || fail "identical resend failed: $output"
  cmp -s "$ORDER_FILE" "$REMOTE_HOME/to-brandon-compute/inbox/kun-order.order" \
    || fail "identical resend changed the remote order bytes"
  assert_contains "$output" 'state=transferred' "idempotent resend must remain transferred"
  pass "identical resend preserves the original remote bytes and checksum receipt"
}

test_mismatch_refuses_without_overwriting_remote_file() {
  local remote output
  setup_case
  mkdir -p "$REMOTE_HOME/to-brandon-compute/inbox"
  remote="$REMOTE_HOME/to-brandon-compute/inbox/conflict.order"
  printf 'operator-owned different order\n' > "$remote"
  expect_failure 'destination checksum mismatch' deliver conflict "$ORDER_FILE" >/dev/null
  [ "$(cat "$remote")" = 'operator-owned different order' ] \
    || fail "mismatching resend overwrote the pre-existing remote order"
  pass "checksum mismatch refuses and leaves the existing remote order unchanged"
}

test_unsafe_order_path_is_rejected_before_transport() {
  local output rc
  setup_case
  rc=0
  output=$(run_cli deliver ../escape "$ORDER_FILE" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail "unsafe order id unexpectedly succeeded"
  assert_contains "$output" 'unsafe order id' "unsafe path must be rejected explicitly"
  [ ! -e "$REMOTE_HOME/to-brandon-compute" ] || fail "unsafe order id contacted or created the remote inbox"
  pass "path traversal in an order id is rejected before remote access"
}

test_transport_failure_leaves_receipt_queued() {
  local output
  setup_case
  export FM_TEST_SCP_FAIL=1
  expect_failure 'transport failed' deliver delayed-order "$ORDER_FILE" >/dev/null
  unset FM_TEST_SCP_FAIL
  output=$(run_cli verify delayed-order) || fail "queued order verification failed: $output"
  assert_contains "$output" 'state=queued' "transport failure must not claim transfer"
  assert_not_contains "$output" 'state=transferred' "transport failure must remain queued"
  pass "transport failure preserves queued state and does not claim delivery"
}

test_remote_checksum_mismatch_is_not_recorded_as_transferred() {
  local output
  setup_case
  export FM_TEST_SCP_CORRUPT=1
  expect_failure 'uploaded checksum mismatch' deliver corrupt-order "$ORDER_FILE" >/dev/null
  unset FM_TEST_SCP_CORRUPT
  output=$(run_cli verify corrupt-order) || fail "queued order verification failed: $output"
  assert_contains "$output" 'state=queued' "checksum mismatch must leave the receipt queued"
  [ ! -e "$REMOTE_HOME/to-brandon-compute/inbox/corrupt-order.order" ] \
    || fail "checksum-mismatched content appeared in the remote inbox"
  pass "remote checksum mismatch is detected before publication or transfer state"
}

test_mismatching_remote_ack_does_not_claim_acceptance() {
  local digest output ack_dir
  setup_case
  run_cli deliver rejected-ack "$ORDER_FILE" >/dev/null \
    || fail "initial transfer failed"
  digest=$(sha256sum "$ORDER_FILE" | awk '{print $1}')
  ack_dir="$REMOTE_HOME/to-brandon-compute/accepted"
  mkdir -p "$ack_dir"
  printf 'order_id=rejected-ack\nsha256=%064d\n' 0 > "$ack_dir/rejected-ack.ack"
  output=$(run_cli verify rejected-ack) || fail "invalid acknowledgement should preserve transferred state: $output"
  assert_contains "$output" 'state=transferred' "invalid acknowledgement must not mark accepted"
  assert_contains "$output" 'warning=invalid-worker-ack' "invalid acknowledgement must be visible"
  assert_contains "$output" "sha256=$digest" "invalid acknowledgement must preserve the verified transfer digest"
  pass "mismatching remote acknowledgement remains transferred and is reported as invalid"
}

test_remote_ack_advances_transferred_to_accepted() {
  local digest output ack_dir
  setup_case
  run_cli deliver accepted-order "$ORDER_FILE" >/dev/null \
    || fail "initial transfer failed"
  digest=$(sha256sum "$ORDER_FILE" | awk '{print $1}')
  ack_dir="$REMOTE_HOME/to-brandon-compute/accepted"
  mkdir -p "$ack_dir"
  printf 'order_id=accepted-order\nsha256=%s\n' "$digest" > "$ack_dir/accepted-order.ack"
  output=$(run_cli verify accepted-order) || fail "acknowledgement verification failed: $output"
  assert_contains "$output" 'state=accepted' "matching remote acknowledgement must mark accepted"
  pass "only a matching remote worker acknowledgement advances transfer to accepted"
}

test_target_cannot_be_redirected_by_environment
test_absent_destination_is_created_and_remotely_verified
test_identical_resend_is_idempotent
test_mismatch_refuses_without_overwriting_remote_file
test_unsafe_order_path_is_rejected_before_transport
test_transport_failure_leaves_receipt_queued
test_remote_checksum_mismatch_is_not_recorded_as_transferred
test_mismatching_remote_ack_does_not_claim_acceptance
test_remote_ack_advances_transferred_to_accepted
