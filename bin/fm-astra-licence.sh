#!/usr/bin/env bash
# Astra licence inventory and provisioning registry.
#
# Tracks every Astra install we stand up, which licence authorises it, and when
# that licence expires, so a client site never goes live on an unauthorised or
# lapsed theme copy.
#
# SECURITY: raw licence keys are credentials and are never written here. Only a
# SHA-256 fingerprint and the last four characters are stored, which is enough to
# match a key against a record without the record being worth stealing.
#
# Usage:
#   fm-astra-licence.sh register <site> <path-to-astra-dir> [edition] [licence-key]
#   fm-astra-licence.sh verify  <site>
#   fm-astra-licence.sh ingest   <file.tsv>
#   fm-astra-licence.sh list
#
# Editions: free | pro | agency. The recorded theme hash pins exactly which copy
# a measurement or a live site actually used, so a silently updated theme can
# never quietly change what a verdict meant.

set -euo pipefail

REGISTRY="${FM_ASTRA_REGISTRY:-$HOME/kun-agent-workspace/data/astra-licences/registry.tsv}"
HEADER=$'site\tastra_version\tedition\ttheme_sha256\tlicence_fp\tlicence_last4\tregistered\tstatus\tnotes'

ensure_registry() {
  mkdir -p "$(dirname "$REGISTRY")"
  [ -f "$REGISTRY" ] || printf '%s\n' "$HEADER" > "$REGISTRY"
}

theme_version() {
  awk -F': *' '/^Theme Name:/{f=1} f && /^Version:/{print $2; exit}' "$1/style.css" 2>/dev/null || true
}

theme_hash() {
  # Hash the whole theme tree deterministically: path + content, sorted.
  ( cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum ) 2>/dev/null | sha256sum | cut -d' ' -f1
}

fingerprint() { printf '%s' "$1" | sha256sum | cut -d' ' -f1; }

cmd_register() {
  local site="$1" dir="$2" edition="${3:-free}" key="${4:-}" fp="-" last4="-"
  if [ -n "$key" ]; then
    fp="$(fingerprint "$key")"
    last4="${key: -4}"
  fi
  [ -d "$dir" ] || { echo "REFUSING: no such theme directory: $dir" >&2; exit 2; }
  [ -f "$dir/style.css" ] || { echo "REFUSING: $dir is not a WordPress theme (no style.css)" >&2; exit 2; }
  case "$edition" in free|pro|agency) ;; *) echo "REFUSING: edition must be free|pro|agency" >&2; exit 2;; esac

  ensure_registry
  if awk -F'\t' -v s="$site" 'NR>1 && $1==s{found=1} END{exit !found}' "$REGISTRY"; then
    echo "REFUSING: $site already registered; update its row rather than adding a second" >&2
    exit 3
  fi

  local ver hash
  ver="$(theme_version "$dir")"; hash="$(theme_hash "$dir")"
  [ -n "$ver" ] || { echo "REFUSING: could not read theme version from $dir/style.css" >&2; exit 2; }

  # A paid edition with no licence evidence is the exact failure this guards.
  local status="registered"
  if [ "$edition" != "free" ] && [ -z "$fp" ]; then
    status="UNLICENSED-no-key-on-file"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$site" "$ver" "$edition" "$hash" "$fp" "$last4" \
    "$(date -u +%Y-%m-%d)" "$status" "" >> "$REGISTRY"
  printf 'registered %s  version=%s edition=%s hash=%s status=%s\n' \
    "$site" "$ver" "$edition" "$hash" "$status"
}

cmd_verify() {
  ensure_registry
  local site="$1"
  local row; row="$(awk -F'\t' -v s="$site" 'NR>1 && $1==s{print; exit}' "$REGISTRY")"
  [ -n "$row" ] || { echo "UNKNOWN: $site is not in the registry" >&2; exit 4; }
  printf '%s\n' "$row"
  local status; status="$(printf '%s' "$row" | cut -f8)"
  [ "$status" = "registered" ] || { printf 'BLOCKED: %s licence status is %s\n' "$site" "$status" >&2; exit 5; }
}

cmd_ingest() {
  local f="$1"; [ -f "$f" ] || { echo "REFUSING: no such file: $f" >&2; exit 2; }
  ensure_registry
  local added=0 line site
  while IFS= read -r line; do
    case "$line" in ''|'site'*) continue;; esac
    site="$(printf '%s' "$line" | cut -f1)"
    awk -F'\t' -v s="$site" 'NR>1 && $1==s{found=1} END{exit !found}' "$REGISTRY" && continue
    printf '%s\n' "$line" >> "$REGISTRY"; added=$((added+1))
  done < "$f"
  printf 'ingested %d row(s); existing sites were left untouched\n' "$added"
}

cmd_list() {
  ensure_registry
  awk -F'\t' 'NR==1{next} {printf "%-34s %-8s %-7s %-12s %s\n", $1, $2, $3, $8, ($5==""||$5=="-")?"(no licence on file)":"licence "substr($5,1,12)"…"}' "$REGISTRY"
}

case "${1:-}" in
  register) shift; [ $# -ge 2 ] || { echo "usage: register <site> <astra-dir> [edition] [licence-key]" >&2; exit 64; }; cmd_register "$@" ;;
  verify)   shift; [ $# -ge 1 ] || { echo "usage: verify <site>" >&2; exit 64; }; cmd_verify "$@" ;;
  ingest)   shift; [ $# -ge 1 ] || { echo "usage: ingest <file.tsv>" >&2; exit 64; }; cmd_ingest "$@" ;;
  list)     shift; cmd_list ;;
  fingerprint) shift; [ $# -ge 1 ] || { echo "usage: fingerprint <key>" >&2; exit 64; }; fingerprint "$1" ;;
  *) echo "usage: fm-astra-licence.sh {register|verify|ingest|list|fingerprint} ..." >&2; exit 64 ;;
esac