#!/usr/bin/env bash
# fm-next-board-install.sh — install the live-board publisher into the runtime directory.
#
# The publisher and the tracker view wrapper are tracked source in bin/. The systemd
# units run the copies in the runtime directory, so the timer keeps working before this
# branch is merged and after it is. Re-run this after any change to the tracked source.
#
# usage: fm-next-board-install.sh [--repo PATH] [--runtime DIR] [--serve-root DIR]
set -euo pipefail

REPO="${FM_REPO:-/root/agent-work/deightonllm-firstmate}"
RUNTIME=""
SERVE_ROOT="${FM_SERVE_ROOT:-/root/tracker-view}"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --runtime) RUNTIME="$2"; shift 2 ;;
    --serve-root) SERVE_ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[ -n "$RUNTIME" ] || RUNTIME="$REPO/data/next-board-publish"

install_one() {
  local src="$1" dst="$RUNTIME/$2"
  [ -f "$src" ] || { echo "fm-next-board-install: FAIL missing source $src" >&2; exit 2; }
  local tmp
  tmp="$(mktemp "$RUNTIME/.install.XXXXXX")"
  cp "$src" "$tmp"
  chmod 0755 "$tmp"
  mv -f -- "$tmp" "$dst"
  printf 'installed: %s\n' "$dst"
}

mkdir -p "$RUNTIME"
install_one "$HERE/fm-next-board-publish.py" "fm-next-board-publish.py"
install_one "$HERE/fm-tracker-view-serve.py" "fm-tracker-view-serve.py"
# The builder travels with the publisher so a freshly installed publisher uses the
# builder it was installed with, and never a half-merged one.
if [ -f "$HERE/build-next-board.py" ]; then
  install_one "$HERE/build-next-board.py" "build-next-board.py"
fi

# The tracker server already serves this directory. The board is published inside the
# runtime directory and reached through this link, so the served tree never holds a copy
# that can drift from the board.
if [ -d "$SERVE_ROOT" ]; then
  link="$SERVE_ROOT/next-board"
  if [ -L "$link" ]; then
    current="$(readlink -f "$link" 2>/dev/null || true)"
    if [ "$current" != "$(readlink -f "$RUNTIME")" ]; then
      rm -f -- "$link"
      ln -s "$RUNTIME" "$link"
      printf 'relinked: %s -> %s\n' "$link" "$RUNTIME"
    else
      printf 'linked: %s -> %s\n' "$link" "$RUNTIME"
    fi
  elif [ -e "$link" ]; then
    echo "fm-next-board-install: FAIL $link exists and is not a symlink" >&2
    exit 2
  else
    ln -s "$RUNTIME" "$link"
    printf 'linked: %s -> %s\n' "$link" "$RUNTIME"
  fi
else
  echo "fm-next-board-install: WARN serve root not found: $SERVE_ROOT" >&2
fi

echo "fm-next-board-install: runtime=$RUNTIME"
