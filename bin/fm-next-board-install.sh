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
# The token-band collector and the board's chat controller travel with the
# publisher too: the runtime directory is what the systemd unit runs from, and a
# runtime copy that is missing its helper would silently publish a degraded
# board. They are optional so an older checkout still installs cleanly.
for optional in fm-token-collect.py fm-next-board-chat.sh fm-next-board-feedback.sh; do
  if [ -f "$HERE/$optional" ]; then
    install_one "$HERE/$optional" "$optional"
  fi
done

# The band on disk was produced by whichever collector was installed when it was
# written. Installing a collector must never leave that band in place looking
# fresh: the publisher would serve a document whose shape the new collector no
# longer writes, and report `band=ok` while doing it. That is exactly how the
# live board kept serving a v1 band after the v2 collector had been installed -
# the band was young enough to skip the refresh, so the collector left it alone
# and the publisher published it as healthy.
#
# So the band is checked against the collector that was just installed. A band
# that matches is left alone. A band that does not match is refreshed now, and
# if that cannot be done it is invalidated, so the next publish recollects it.
# Either way the next publish cannot serve a band from a superseded collector.
PYTHON="${FM_PYTHON:-python3}"

band_schema() {  # <band path> -> the schema the band carries, or nothing
  [ -f "$1" ] || return 0
  "$PYTHON" - "$1" <<'PY' 2>/dev/null || true
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        document = json.load(handle)
except Exception:
    sys.exit(0)
schema = document.get("schema") if isinstance(document, dict) else None
if isinstance(schema, str):
    print(schema)
PY
}

reconcile_band() {
  local collector="$RUNTIME/fm-token-collect.py"
  local band="$RUNTIME/token-band.json"
  local collector_schema band_schema_now

  if [ ! -f "$collector" ]; then
    printf 'band: no collector installed; nothing to reconcile\n'
    return 0
  fi
  if [ ! -f "$band" ]; then
    printf 'band: no band on disk; the next publish collects it\n'
    return 0
  fi

  # The collector is asked what it writes, so there is exactly one copy of the
  # schema in the whole system.
  collector_schema="$("$PYTHON" "$collector" --print-schema 2>/dev/null || true)"
  band_schema_now="$(band_schema "$band")"

  if [ -n "$collector_schema" ] && [ "$collector_schema" = "$band_schema_now" ]; then
    printf 'band: schema %s matches the installed collector; left as is\n' "$collector_schema"
    return 0
  fi

  printf 'band: schema %s was produced by a superseded collector (the installed one writes %s); refreshing\n' \
    "${band_schema_now:-none}" "${collector_schema:-unknown}"

  if "$PYTHON" "$collector" --out "$band" --force >/dev/null 2>&1; then
    band_schema_now="$(band_schema "$band")"
    if [ -n "$collector_schema" ] && [ "$collector_schema" = "$band_schema_now" ]; then
      printf 'band: refreshed by the installed collector; schema %s\n' "$band_schema_now"
      return 0
    fi
  fi

  # The collector could not produce a current band. The band is then left in no
  # state at all rather than in a state that looks fresh: the next publish's
  # collector run recollects it, and until then the board says the band is
  # missing instead of publishing a superseded one.
  if mv -f -- "$band" "$band.superseded" 2>/dev/null || rm -f -- "$band" 2>/dev/null; then
    printf 'band: the collector could not refresh it; invalidated so the next publish recollects it\n'
  else
    printf 'band: WARN the collector could not refresh it and the band could not be invalidated; the publisher will report the mismatch\n' >&2
  fi
}

reconcile_band

# The tracker server already serves this directory. The board is published inside the
# runtime directory and reached through this link, so the served tree never holds a copy
# that can drift from the board.
if [ ! -d "$SERVE_ROOT" ]; then
  mkdir -p "$SERVE_ROOT"
  printf 'serve root: created %s\n' "$SERVE_ROOT"
fi

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

# The served root is the board. It used to serve a stale tracker preview, so the
# Captain followed the live board's own link and landed on an old dashboard he did
# not recognise - and could not tell which of the three boards he was looking at.
# The installer owns the root now, because it is the only thing that can put the
# preview back.
#
# THE RULE, and it is deliberately narrow. The root is taken over ONLY when it
# points at a tracker preview - a candidate-preview or a tracker-build preview -
# because that is the artifact that displaced the live board. A root pointing
# anywhere else is another home's intended root: it is left exactly as it is and
# the installer says so. A root that is a real file is never touched and never
# deleted; the installer refuses it loudly and carries on.
serve_root_index() {
  local root="$SERVE_ROOT/index.html"
  local target="$RUNTIME/index.html"
  local runtime_real current

  if [ -L "$root" ]; then
    current="$(readlink -f "$root" 2>/dev/null || true)"
  elif [ -e "$root" ]; then
    echo "fm-next-board-install: FAIL $root exists and is not a symlink; refusing to replace it and leaving it untouched" >&2
    return 0
  else
    current=""
  fi

  runtime_real="$(readlink -f "$RUNTIME" 2>/dev/null || printf '%s' "$RUNTIME")"

  if [ -n "$current" ]; then
    if [ "$current" = "$runtime_real/index.html" ]; then
      printf 'serve root: %s already serves the live board\n' "$root"
      return 0
    fi
    case "$current" in
      *candidate-preview.html*|*tracker-build-*preview*)
        # A tracker preview holds the root: it is what displaced the live board.
        ;;
      *)
        printf 'serve root: %s points at %s, which is not a tracker preview; left alone\n' \
          "$root" "$current"
        return 0
        ;;
    esac
  fi

  rm -f -- "$root"
  ln -s "$target" "$root"
  if [ -f "$target" ]; then
    printf 'serve root: %s -> %s (the live board is the served root)\n' "$root" "$target"
  else
    printf 'serve root: %s -> %s (the live board is the served root; the publisher has not written it yet)\n' \
      "$root" "$target"
  fi
}

serve_root_index

echo "fm-next-board-install: runtime=$RUNTIME"
