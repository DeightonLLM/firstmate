#!/usr/bin/env bash
# Warehouse guard — Controller owns the warehouse; Hetz may read its mirror but
# must not write to it.
#
# This is capability without permission. /home/hd2admin/kun-agent-workspace/warehouse
# is owned by hd2admin and is writable, so a future firstmate could write to it
# without any tool refusing. Controller's ruling, 2026-10-14 and reaffirmed
# 2026-10-15:
#
#   Warehouse is Controller-owned. Hetz may read its mirror but must not write to
#   the canonical warehouse or its local mirror. Submit completed reports and
#   source-map updates as named Markdown files through the outbox, with source
#   paths, revision, test evidence and intended warehouse destination. Controller
#   reviews and mirrors accepted material; receipt is not acceptance.
#
# Enforcement is deliberately coarse. A guard that tried to classify every write
# would need to parse intent, which is exactly the "gate that infers
# authorisation from prose" Controller refused to build. This refuses writes
# outright and points at the sanctioned route instead.
#
# Reads are never refused. The mirror exists to be read.
#
# Usage: fm-warehouse-guard.sh <path>
# Exit: 0 allow, 77 refuse
set -u

WAREHOUSE_ROOT="${FM_WAREHOUSE_ROOT:-/home/hd2admin/kun-agent-workspace/warehouse}"

fail() {
  printf 'fm-warehouse-guard: REFUSED - %s\n' "$1" >&2
  printf '  Controller owns the warehouse. Submit through the outbox instead:\n' >&2
  printf '    bash bin/fm-outbound.sh <file> <destination-filename>\n' >&2
  printf '  Include source paths, revision, test evidence and intended warehouse destination.\n' >&2
  printf '  Receipt is not acceptance; Controller reviews and mirrors accepted material.\n' >&2
  exit 77
}

target="${1:-}"
[ -n "$target" ] || {
  printf 'usage: fm-warehouse-guard.sh <path>\n' >&2
  exit 2
}

# Resolve the target without requiring it to exist yet: a guard that only fires
# on existing paths lets the first write of a new file through unexamined.
case "$target" in
  /*) abs=$target ;;
  *) abs="$PWD/$target" ;;
esac

# Normalise away . and .. without resolving symlinks, so a path that does not
# exist yet is still classified.
norm=$(printf '%s' "$abs" | sed -e 's|/\./|/|g' -e 's|/\([^/][^/]*/\)\.\./|/|g' -e 's|/$||')

case "$norm" in
  "$WAREHOUSE_ROOT"|"$WAREHOUSE_ROOT"/*)
    fail "$norm is inside the Controller-owned warehouse"
    ;;
  *)
    printf 'allow\n'
    exit 0
    ;;
esac