#!/usr/bin/env bash
# tests/fm-install-mcode-herdr-agent.test.sh - the MCode plugin package shape and
# the installer that publishes it.
#
# MCode's native loader reads .minimax-plugin/plugin.json and ignores that
# manifest when the package also carries a root plugin.json: the root manifest
# wins and its loader returns an empty hook list, so the hook never fires.
# The loader also requires the native manifest to name an icon whose path
# matches its own pattern and resolves to a real file in the package.
#
# A local package needs no install step either: mcode plugin add refuses a
# local plugin with LOCAL_PLUGIN_INSTALL_UNSUPPORTED, so the installer must
# refresh the marketplace and enable the discovered package instead.
#
# The suite drives the real installer against a stub mcode, so it asserts the
# published call contract and the package shape rather than the source bytes.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INSTALLER="$ROOT/bin/fm-install-mcode-herdr-agent.sh"
PKG="$ROOT/extensions/mcode-herdr-agent"
NATIVE_MANIFEST="$ROOT/extensions/mcode-herdr-agent/.minimax-plugin/plugin.json"
ROOT_MANIFEST="$ROOT/extensions/mcode-herdr-agent/plugin.json"
HOOKS_DOC="$ROOT/extensions/mcode-herdr-agent/hooks/hooks.json"
ICON_FILE="$ROOT/extensions/mcode-herdr-agent/icon.png"
TMP_ROOT=$(fm_test_tmproot fm-install-mcode-herdr-agent)

# A stub mcode that records every invocation and fails the unsupported local
# install exactly the way the real CLI does.
recording_mcode() {
  local dir=$1
  cat > "$dir/mcode" <<'REC'
#!/usr/bin/env bash
{
  printf 'CALL\n'
  for arg in "$@"; do printf '%s\n' "$arg"; done
  printf 'END\n'
} >> "$FM_FAKE_MCODE_LOG"
case "$1 $2" in
  "plugin add")
    printf 'LOCAL_PLUGIN_INSTALL_UNSUPPORTED\n' >&2
    exit 1
    ;;
esac
exit 0
REC
  chmod +x "$dir/mcode"
}

# Run the installer with the stub mcode on PATH and a private marketplace and
# bin dir. It echoes the installer's combined output.
run_installer() {
  local dir=$1
  : > "$dir/calls.log"
  FM_FAKE_MCODE_LOG="$dir/calls.log" \
  FM_MCODE_MARKETPLACE_DIR="$dir/marketplace" \
  FM_HERDR_AGENT_BIN_DIR="$dir/bin" \
  PATH="$dir:$PATH" \
    bash "$INSTALLER" 2>&1
}

test_root_plugin_json_is_absent() {
  assert_absent "$ROOT_MANIFEST" \
    "the package must not carry a root plugin.json because it shadows the native manifest"
  pass "the package carries no root plugin.json"
}

test_native_manifest_declares_a_resolvable_icon() {
  assert_present "$NATIVE_MANIFEST" "the native manifest must exist"
  local icon
  icon=$(sed -n 's/.*"icon"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$NATIVE_MANIFEST")
  [ -n "$icon" ] || fail "the native manifest must declare an icon path"
  case "$icon" in
    *.png | *.jpg | *.jpeg | *.webp) : ;;
    *) fail "the icon path must end in a supported image extension (got '$icon')" ;;
  esac
  case "$icon" in
    /* | *..*) fail "the icon path must be relative to the package root (got '$icon')" ;;
  esac
  assert_present "$PKG/$icon" "the declared icon must ship in the package"
  assert_present "$ICON_FILE" "the package must ship its icon file"
  pass "the native manifest declares a resolvable package icon"
}

test_declared_icon_is_a_real_image() {
  local icon
  icon=$(sed -n 's/.*"icon"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$NATIVE_MANIFEST")
  local path="$PKG/$icon"
  local size
  size=$(wc -c < "$path")
  [ "$size" -gt 64 ] || fail "the icon must be a real image file, not a stub (got $size bytes)"
  case "$icon" in
    *.png)
      local magic
      magic=$(od -An -tx1 -N8 "$path" | tr -d ' \n')
      assert_equals "89504e470d0a1a0a" "$magic" \
        "the PNG icon must start with the PNG signature"
      ;;
  esac
  pass "the declared icon is a genuine image file"
}

test_hook_document_declares_the_lifecycle_events() {
  assert_present "$HOOKS_DOC" "the package must ship its hook document"
  local event
  for event in SessionStart UserPromptSubmit PermissionRequest Stop SessionEnd; do
    assert_grep "\"$event\"" "$HOOKS_DOC" "the hook document must declare the $event event"
  done
  pass "the hook document declares the five lifecycle events"
}

test_installer_enables_instead_of_adding() {
  local dir="$TMP_ROOT/install"
  mkdir -p "$dir"
  recording_mcode "$dir"
  local out rc=0
  out=$(run_installer "$dir") || rc=$?
  expect_code 0 "$rc" "the installer must exit 0 for a local install"
  assert_no_grep "add" "$dir/calls.log" "the installer must not call the unsupported mcode plugin add"
  assert_grep "marketplace" "$dir/calls.log" "the installer must refresh the marketplace snapshot"
  assert_grep "upgrade" "$dir/calls.log" "the installer must refresh the marketplace snapshot"
  assert_grep "enable" "$dir/calls.log" "the installer must enable the discovered local plugin"
  assert_grep "mcode-herdr-agent@local" "$dir/calls.log" "the installer must enable the local plugin"
  assert_not_contains "$out" "failed" "the installer must not report a failure for a local install"
  assert_contains "$out" "Installed mcode-herdr-agent" "the installer must report a successful install"
  pass "the installer enables the local package instead of adding it"
}

test_installer_publishes_the_package_and_the_shim() {
  local dir="$TMP_ROOT/publish"
  mkdir -p "$dir"
  recording_mcode "$dir"
  run_installer "$dir" >/dev/null
  assert_present "$dir/marketplace/mcode-herdr-agent/.minimax-plugin/plugin.json" \
    "the installer must publish the native manifest into the marketplace"
  assert_absent "$dir/marketplace/mcode-herdr-agent/plugin.json" \
    "the published package must not carry a root plugin.json"
  assert_present "$dir/marketplace/mcode-herdr-agent/hooks/hooks.json" \
    "the installer must publish the hook document"
  assert_present "$dir/bin/fm-herdr-agent-report.sh" \
    "the installer must put the reporter on PATH"
  pass "the installer publishes the package and the publisher shim"
}

test_install_reports_failure_when_enable_fails() {
  local dir="$TMP_ROOT/fail"
  mkdir -p "$dir"
  cat > "$dir/mcode" <<'REC'
#!/usr/bin/env bash
case "$1 $2" in
  "plugin enable")
    printf 'Plugin not found: mcode-herdr-agent@local\n' >&2
    exit 1
    ;;
esac
exit 0
REC
  chmod +x "$dir/mcode"
  local out rc=0
  out=$(run_installer "$dir") || rc=$?
  expect_code 1 "$rc" "the installer must fail when the plugin cannot be enabled"
  assert_contains "$out" "failed" "the installer must report the enable failure"
  pass "the installer reports a real failure when the plugin cannot be enabled"
}

run_tests() {
  test_root_plugin_json_is_absent
  test_native_manifest_declares_a_resolvable_icon
  test_declared_icon_is_a_real_image
  test_hook_document_declares_the_lifecycle_events
  test_installer_enables_instead_of_adding
  test_installer_publishes_the_package_and_the_shim
  test_install_reports_failure_when_enable_fails
}

run_tests
