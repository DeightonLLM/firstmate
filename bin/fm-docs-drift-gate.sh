#!/usr/bin/env bash
# fm-docs-drift-gate.sh — deterministic docs-drift gate.
#
# SINGLE OWNER of drift-gate semantics (other docs point here; do not restate).
#
# Purpose: make "code changed, docs did not" a machine-detected state instead of
# a remembered one. Fail the closeout until docs are updated or the changed paths
# are explicitly waived.
#
# What it compares:
#   1. Repo-internal: files changed in git since the last closeout marker
#      (state/docs-drift-gate.marker) vs docs/ files changed in the same window.
#   2. External roots (default /root/bin, /root/.minimax/config.yaml): files
#      modified since the marker vs docs/ changes in the same window. Covers
#      controller-side tooling that lives outside this repo.
#
# Verdicts (exit codes):
#   0 = PASS  (no drift, or all drifted paths waived)
#   1 = DOCS_DRIFT  (changed paths with no doc change and no waiver)
#   2 = usage/environment error
#
# Waivers: docs/drift-waivers.tsv, one per line: <path-or-prefix>\t<reason>
#   A waiver is a DECISION RECORD — path, reason, date. Review at closeout.
#
# State: state/docs-drift-gate.marker (last pass timestamp, written with --close).
#
# Usage:
#   fm-docs-drift-gate.sh                 # check only; never mutates state
#   fm-docs-drift-gate.sh --close         # check; if PASS (or waived clean) write marker
#   fm-docs-drift-gate.sh --since <iso>   # override window start
#
# Integration: run at closeout in any harness (pi brief, herdr pane, exec).
# Status convention: callers should record the verdict line in state/*.status.
set -uo pipefail
cd -- "$(dirname "$0")/.." || exit 2

MARKER="state/docs-drift-gate.marker"
WAIVERS="docs/drift-waivers.tsv"
DOCS_DIR="docs"
EXTERNAL_ROOTS=("/root/bin" "/root/.minimax/config.yaml")
CLOSE=0
SINCE=""

[ "${1:-}" = "--close" ] && CLOSE=1
SINCE_OVERRIDE=0
[ "${1:-}" = "--since" ] && { SINCE="${2:-}"; SINCE_OVERRIDE=1; [ -z "$SINCE" ] && exit 2; }

# Determine window start: explicit --since > marker > HEAD commit time.
if [ -z "$SINCE" ]; then
  if [ -f "$MARKER" ]; then SINCE="$(head -1 "$MARKER")"
  else SINCE="$(git log -1 --format=%cI 2>/dev/null)"; fi
fi
[ -z "$SINCE" ] && { echo "DOCS_DRIFT_GATE=ERROR no window start (no marker, no git)"; exit 2; }

is_waived() { # is_waived <path> -> 0 if waived
  [ -f "$WAIVERS" ] || return 1
  awk -F'\t' -v p="$1" '{ if (p == $1 || index(p, $1) == 1) exit 0 }' "$WAIVERS" 2>/dev/null
  return $((1 - $?)) # awk exit 0 -> waived
}
# NOTE: keep it simple and correct:
is_waived() {
  [ -f "$WAIVERS" ] || return 1
  awk -F'\t' -v p="$1" 'BEGIN{r=1} { if (p == $1 || index(p, $1) == 1) {r=0; exit} } END{exit r}' "$WAIVERS"
}

# --- collect changed code/config paths (repo-internal) ---
mapfile -t REPO_CHANGED < <(git diff --name-only "@{push}..HEAD" 2>/dev/null; git status --porcelain 2>/dev/null | awk '$1!="??" && $1!="!!" {print $2}')
# --- external roots: files modified since window ---
mapfile -t EXT_CHANGED < <(
  for root in "${EXTERNAL_ROOTS[@]}"; do
    [ -e "$root" ] || continue
    find "$root" -type f -newermt "$SINCE" 2>/dev/null
  done
)

# --- docs changed in the window (repo-internal) ---
docs_changed=0
if [ -n "$SINCE_OVERRIDE" ]; then
  # Explicit --since window: mtime comparison only (git state can't bound it).
  newest_doc=0
  while IFS= read -r -d '' f; do
    m=$(stat -c %Y "$f" 2>/dev/null) || continue
    [ "$m" -gt "$newest_doc" ] && newest_doc=$m
  done < <(find "$DOCS_DIR" -type f -name '*.md' -print0 2>/dev/null)
  since_epoch=$(date -d "$SINCE" +%s 2>/dev/null) || since_epoch=""
  if [ -n "$since_epoch" ] && [ "$newest_doc" -ge "$since_epoch" ]; then docs_changed=1; fi
else
  if [ -n "$(git diff --name-only "@{push}..HEAD" -- "$DOCS_DIR" 2>/dev/null)" ] || \
     [ -n "$(git status --porcelain -- "$DOCS_DIR" 2>/dev/null)" ]; then
    docs_changed=1
  fi
  newest_doc=0
  while IFS= read -r -d '' f; do
    m=$(stat -c %Y "$f" 2>/dev/null) || continue
    [ "$m" -gt "$newest_doc" ] && newest_doc=$m
  done < <(find "$DOCS_DIR" -type f -name '*.md' -print0 2>/dev/null)
  since_epoch=$(date -d "$SINCE" +%s 2>/dev/null || echo 0)
  [ "$newest_doc" -ge "$since_epoch" ] && docs_changed=1
fi

# --- verdict ---
drift=()
for f in "${REPO_CHANGED[@]}" "${EXT_CHANGED[@]}"; do
  [ -z "$f" ] && continue
  case "$f" in
    "$DOCS_DIR"/*|state/*|*.md|*.log|*.status|*.marker) continue ;;
  esac
  is_waived "$f" && continue
  drift+=("$f")
done

if [ "${#drift[@]}" -eq 0 ] || [ "$docs_changed" -eq 1 ]; then
  echo "DOCS_DRIFT_GATE=PASS window_since=$SINCE docs_changed=$docs_changed drifted=${#drift[@]}"
  if [ "${#drift[@]}" -gt 0 ]; then
    echo "INFO: unwaived changed paths (covered only by a generic doc update):"
    printf '  %s\n' "${drift[@]}" | sort -u
  fi
  if [ "$CLOSE" -eq 1 ]; then date -Iseconds > "$MARKER"; echo "marker written: $MARKER"; fi
  exit 0
fi

echo "DOCS_DRIFT_GATE=FAIL docs_changed=$docs_changed (these paths changed with no doc update):"
printf '  %s\n' "${drift[@]}" | sort -u
[ "$CLOSE" -eq 1 ] && echo "marker NOT written: closeout blocked by drift"
exit 1
