#!/usr/bin/env bash
# fm-warehouse-submit.sh - submit a document to Controller for warehouse mirroring.
#
# The warehouse is Controller-owned. Hetz writes documents locally and submits
# them; Controller reviews and mirrors accepted material. This script makes that
# submission mechanical instead of prose, so neither side has to infer intent.
#
# It emits ONE submission manifest naming, per document:
#   source path          where the file lives on Hetz
#   sha256               content identity, so what he mirrors is provably what I sent
#   intended destination the warehouse path Controller should mirror it to
#   evidence             test output, or explicit "none - documentation only"
#
# It never writes to the warehouse. It never claims acceptance.
#
# Usage:
#   fm-warehouse-submit.sh <file> <intended-warehouse-destination> [evidence]
#   fm-warehouse-submit.sh --batch <manifest-file>
set -u

FM_HOME="${FM_HOME:-/home/hd2admin/kun-agent-workspace}"

usage() {
  printf 'usage: fm-warehouse-submit.sh <file> <intended-warehouse-destination> [evidence]\n' >&2
  printf '       fm-warehouse-submit.sh --batch <manifest-file>\n' >&2
  exit 2
}

valid_dest() {
  [[ "$1" =~ ^[A-Za-z0-9._/-]+\.md$ ]]
}

# The intended destination is a path INSIDE the Controller's warehouse, because
# it names where Controller should mirror this document. It is deliberately not
# checked against fm-warehouse-guard.sh: that guard refuses writes into HETZ's
# LOCAL warehouse mirror, and composing a controller-side destination into the
# local path would make every destination look like a local warehouse write.
# Hetz does not write to the warehouse in this script at all - it writes the
# submission manifest to the outbox. What must be enforced here is only that the
# destination is a well-formed warehouse-relative Markdown path.

emit_entry() {  # <file> <destination> <evidence>
  local src=$1 dest=$2 evidence=$3 hash size
  [ -f "$src" ] && [ ! -L "$src" ] || {
    printf 'fm-warehouse-submit: source is unavailable or not a regular file: %s\n' "$src" >&2
    return 1
  }
  valid_dest "$dest" || {
    printf 'fm-warehouse-submit: invalid intended destination: %s\n' "$dest" >&2
    return 1
  }
  hash=$(sha256sum -- "$src" 2>/dev/null) || return 1
  hash=${hash%% *}
  size=$(wc -c < "$src" 2>/dev/null | tr -d ' ')
  printf -- '- source: `%s`\n' "$src"
  printf -- '  sha256: `%s`\n' "$hash"
  printf -- '  bytes: %s\n' "$size"
  printf -- '  intended_destination: `%s`\n' "$dest"
  printf -- '  evidence: %s\n' "$evidence"
}

case "${1:-}" in
  --batch) usage ;;
  '') usage ;;
esac

src=$1; dest=$2; evidence=${3:-none - documentation only, no code behaviour change}

emit_entry "$src" "$dest" "$evidence" || exit 1

stamp=$(date -u +%Y%m%dT%H%M%SZ)
out="$FM_HOME/BRANDON-COMPUTE-COMMS/from-brandon-compute/${stamp}-warehouse-submission.md"
mkdir -p "$(dirname "$out")" 2>/dev/null || exit 1

{
  printf '# Warehouse submission — Hetz requests mirroring\n\n'
  printf '**Submitted:** %s UTC\n' "$stamp"
  printf '**Requesting:** Controller reviews and mirrors accepted material into the Controller-owned warehouse.\n'
  printf '**Not claiming:** acceptance. Receipt of this file is not acceptance of its content.\n\n'
  printf '## Document\n\n'
  emit_entry "$src" "$dest" "$evidence"
  printf '\n## Controller action requested\n\n'
  printf '1. Read the source file and verify the sha256 above matches its content.\n'
  printf '2. Review for correctness against current reality.\n'
  printf '3. If accepted, mirror to `%s` in the warehouse.\n' "$dest"
  printf '4. Reply with the warehouse path you wrote, so Hetz can cite it.\n\n'
  printf 'If not accepted, reply with the specific reason. Hetz will not mirror it locally.\n'
} > "$out"

printf 'submission written: %s\n' "$out"
printf 'Now send it: bash %s/bin/fm-outbound.sh %s %s\n' \
  "$FM_HOME" "$out" "$(basename "$out")"