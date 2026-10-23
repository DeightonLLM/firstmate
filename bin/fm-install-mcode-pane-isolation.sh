#!/usr/bin/env bash
# fm-install-mcode-pane-isolation.sh - install the MCode pane-isolation plugin.
#
# The worker-pane-isolation rule (docs/audits-20260928/AGENTSEC.md 3.5) lived only as a Pi
# runtime extension, so an MCode agent on this surface had nothing stopping it from splitting
# the operator's coordinator pane. This installer publishes the tracked MCode plugin package
# into the MCode local marketplace, puts the guard on PATH so the plugin can call it by name,
# and enables the plugin for the local marketplace.
#
# Usage: fm-install-mcode-pane-isolation.sh [--uninstall]
set -uo pipefail

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SELF_DIR/.." && pwd)"
PKG_SRC="$REPO_ROOT/extensions/mcode-pane-isolation"
PLUGIN_NAME="mcode-pane-isolation"
MARKETPLACE_DIR="${FM_MCODE_MARKETPLACE_DIR:-$HOME/.minimax/plugins}"
BIN_DIR="${FM_HERDR_AGENT_BIN_DIR:-$HOME/.local/bin}"
SHIM="$BIN_DIR/fm-pane-isolation-guard.sh"

usage() {
  printf 'Usage: %s [--uninstall]\n' "$(basename "$0")"
}

uninstall() {
  if command -v mcode >/dev/null 2>&1; then
    mcode plugin remove "$PLUGIN_NAME@local" >/dev/null 2>&1 || true
  fi
  rm -f "$SHIM"
  rm -rf "${MARKETPLACE_DIR:?}/$PLUGIN_NAME"
  printf 'Removed %s and %s\n' "$SHIM" "$MARKETPLACE_DIR/$PLUGIN_NAME"
}

case "${1:-}" in
  "") ;;
  --uninstall)
    uninstall
    exit 0
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [ ! -d "$PKG_SRC" ]; then
  printf 'Plugin package not found: %s\n' "$PKG_SRC" >&2
  exit 1
fi

if ! command -v mcode >/dev/null 2>&1; then
  printf 'mcode is not on PATH; install the MCode CLI first.\n' >&2
  exit 1
fi

mkdir -p "$MARKETPLACE_DIR" "$BIN_DIR" || exit 1

rm -rf "${MARKETPLACE_DIR:?}/$PLUGIN_NAME"
cp -R "$PKG_SRC" "$MARKETPLACE_DIR/$PLUGIN_NAME" || exit 1

cat > "$SHIM" <<SHIM_EOF
#!/usr/bin/env bash
exec "$REPO_ROOT/bin/fm-pane-isolation-guard.sh" "\$@"
SHIM_EOF
chmod 0755 "$SHIM"

if ! mcode plugin add "$PLUGIN_NAME@local" >/dev/null 2>&1; then
  printf 'Plugin package published to %s, but mcode plugin add failed.\n' "$MARKETPLACE_DIR" >&2
  printf 'Enable it with: mcode plugin enable %s@local\n' "$PLUGIN_NAME" >&2
  exit 1
fi

printf 'Installed %s\n' "$PLUGIN_NAME"
printf 'Publisher on PATH: %s\n' "$SHIM"
printf 'The rule now refuses splitting the coordinator pane and raw dispatch into it.\n'
