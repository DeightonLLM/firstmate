#!/usr/bin/env bash
# Behavior tests for quota-axi discovery and compatibility-floor enforcement.
set -u

# shellcheck source=tests/lib.sh disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-quota-axi-lib-tests)
BASE_PATH=${FM_TEST_BASE_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}

# A quota-axi package may be available through npx when no global executable is
# installed. The fallback must invoke the package with the pinned, non-mutating
# version probe and still enforce the shared minimum version.
test_npx_fallback_honors_version_floor() {
  local case_dir fakebin log
  case_dir="$TMP_ROOT/npx-fallback"
  fakebin=$(fm_fakebin "$case_dir")
  log="$case_dir/npx.log"
  cat > "$fakebin/npx" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FM_FAKE_NPX_LOG"
if [ "$*" = "-y quota-axi --version" ]; then
  printf '%s\n' 'quota-axi 0.1.44'
  exit 0
fi
exit 1
SH
  chmod +x "$fakebin/npx"

  if ! PATH="$fakebin:$BASE_PATH" FM_QUOTA_AXI_ALLOW_NPX=1 \
    FM_FAKE_NPX_LOG="$log" fm_quota_axi_compatible 5; then
    fail "npx fallback should accept quota-axi 0.1.44"
  fi
  [ "$(<"$log")" = '-y quota-axi --version' ] \
    || fail "npx fallback used an unexpected command: $(<"$log")"
  pass "quota-axi npx fallback enforces the version floor"
}

test_npx_fallback_can_be_disabled() {
  local case_dir fakebin log
  case_dir="$TMP_ROOT/npx-disabled"
  fakebin=$(fm_fakebin "$case_dir")
  log="$case_dir/npx.log"
  cat > "$fakebin/npx" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FM_FAKE_NPX_LOG"
printf '%s\n' 'quota-axi 0.1.44'
SH
  chmod +x "$fakebin/npx"

  if PATH="$fakebin:$BASE_PATH" FM_QUOTA_AXI_ALLOW_NPX=0 \
    FM_FAKE_NPX_LOG="$log" fm_quota_axi_compatible 5; then
    fail "disabled npx fallback must not report compatibility"
  fi
  [ ! -s "$log" ] || fail "disabled npx fallback must not invoke npx"
  pass "quota-axi npx fallback can be disabled"
}

. "$ROOT/bin/fm-quota-axi-lib.sh"
test_npx_fallback_honors_version_floor
test_npx_fallback_can_be_disabled
printf '%s\n' 'PASS: quota-axi discovery and compatibility cases'
