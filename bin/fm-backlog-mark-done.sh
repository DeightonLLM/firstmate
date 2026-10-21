#!/usr/bin/env bash
# Close one row in a markdown backlog, without touching any row the caller does
# not own.
#
# Usage: fm-backlog-mark-done.sh <backlog-file> <id> [note] [keep]
#   <backlog-file>  the markdown backlog to update (data/backlog.md)
#   <id>            the item key to close
#   [note]          text appended to the row (usually " - <PR url>")
#   [keep]          how many closed rows the Done section keeps (default 10,
#                   or FM_BACKLOG_DONE_KEEP)
#
# WHAT IT DOES
#   1. Finds the single item row whose key is <id>. A key is the first
#      whitespace-delimited token after the checkbox, with any surrounding "**"
#      stripped, so "- [ ] id - title", " - [ ] id - title" and
#      "- [ ] **id** - title" all match the same key. Leading indentation and
#      a "[X]" checkbox are tolerated.
#   2. Marks that row [x] and appends <note> to it.
#   3. If the row sits under "## In flight" it is MOVED into the "## Done"
#      section, newest first - the order the markdown backlog keeps. If it sits
#      under any other section - a manual-backend home keeps its queue under
#      "## Queued" - it is closed IN PLACE and stays exactly where it is.
#   4. Prunes the "## Done" section to the <keep> most recent CLOSED rows.
#      Open rows are never pruned, rows outside "## Done" are never pruned, and
#      a row whose key cannot be read is never removed. Pruned rows are
#      APPENDED to the archive file; they are never deleted outright.
#
# WHAT IT NEVER DOES
#   It never removes, relocates or rewrites a row other than the one it was
#   asked to close. A backlog it cannot parse is left byte-identical. This is
#   the whole point of the script: the previous inline updater deleted queued
#   rows when the "## In flight" section was empty, because it treated the
#   next real header as the end of that section and then collected every
#   remaining "- [" row in the file as a Done entry.
#
# ARCHIVE
#   Pruned rows go to the archive path: FM_BACKLOG_ARCHIVE when set, otherwise
#   "done-archive.md" beside the backlog file (the repo's own .tasks.toml
#   declares data/done-archive.md for exactly this). If the archive cannot be
#   appended to, the prune is REFUSED and the backlog is left unchanged -
#   history is never dropped silently.
#
# EXIT CODES
#   0  the row was closed
#   2  usage error, unreadable backlog, or a write failure
#   3  no row matched <id>        (the backlog was left byte-identical)
#   4  more than one row matched <id> (the backlog was left byte-identical)
set -eu

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

[ "$#" -ge 2 ] && [ "$#" -le 4 ] || usage
BACKLOG=$1
ID=$2
NOTE=${3:-}
KEEP=${4:-${FM_BACKLOG_DONE_KEEP:-10}}

case "$KEEP" in ''|*[!0-9]*) KEEP=10 ;; esac
[ "$KEEP" -ge 1 ] 2>/dev/null || KEEP=10

[ -e "$BACKLOG" ] || { printf 'error: backlog %s does not exist\n' "$BACKLOG" >&2; exit 2; }
if [ -L "$BACKLOG" ]; then
  printf 'error: backlog %s is a symlink\n' "$BACKLOG" >&2
  exit 2
fi
[ -f "$BACKLOG" ] || { printf 'error: backlog %s is not a regular file\n' "$BACKLOG" >&2; exit 2; }
[ -r "$BACKLOG" ] || { printf 'error: backlog %s is not readable\n' "$BACKLOG" >&2; exit 2; }

BACKLOG_DIR=$(cd "$(dirname "$BACKLOG")" && pwd)
ARCHIVE=${FM_BACKLOG_ARCHIVE:-$BACKLOG_DIR/done-archive.md}

if stat -c '%a' "$BACKLOG" >/dev/null 2>&1; then
  MODE=$(stat -c '%a' "$BACKLOG")
elif stat -f '%Lp' "$BACKLOG" >/dev/null 2>&1; then
  MODE=$(stat -f '%Lp' "$BACKLOG")
else
  MODE=644
fi

TMP_NEW="$BACKLOG.tmp.$$"
TMP_ARC="$BACKLOG.arc.$$"
cleanup() { rm -f -- "$TMP_NEW" "$TMP_ARC"; }
trap cleanup EXIT INT TERM

AWK_STATUS=0
awk -v id="$ID" -v note="$NOTE" -v keep="$KEEP" -v arcfile="$TMP_ARC" '
function is_item(l)   { return l ~ /^[ \t]*- \[[ xX]\][ \t]+/ }
function is_head(l)   { return l ~ /^##[[:space:]]/ }
function head_name(l,  s) {
  s = l
  sub(/^##[[:space:]]+/, "", s)
  sub(/[[:space:]]+$/, "", s)
  return s
}
function item_key(l,  rest, k) {
  rest = l
  sub(/^[ \t]*- \[[ xX]\][ \t]+/, "", rest)
  k = rest
  sub(/[ \t].*$/, "", k)
  if (k ~ /^\*\*[^*]+\*\*$/) k = substr(k, 3, length(k) - 4)
  return k
}
function item_closed(l) { return l ~ /^[ \t]*- \[[xX]\]/ }
function first_date(l,  s) {
  if (match(l, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) {
    s = substr(l, RSTART, RLENGTH)
    gsub(/-/, "", s)
    return s + 0
  }
  return 0
}
# The body of an item row is the run of blank and indented lines that follows
# it, stopping at the next item row or section heading. Trailing blank lines
# are separators, not body: they stay behind so the section keeps its shape.
function body_end(i,  j, last) {
  j = i + 1
  last = i
  while (j <= n) {
    if (is_item(L[j]) || is_head(L[j])) break
    if (L[j] ~ /^[ \t]*$/) { last = j; j++; continue }
    if (L[j] ~ /^[ \t]/) { last = j; j++; continue }
    break
  }
  while (last > i && L[last] ~ /^[ \t]*$/) last--
  return last
}
{ L[++n] = $0 }
END {
  sec = ""
  last_done = 0
  for (i = 1; i <= n; i++) {
    if (is_head(L[i])) {
      sec = head_name(L[i])
      if (sec == "Done") last_done = i
    }
    SEC[i] = sec
  }

  t = 0
  matches = 0
  for (i = 1; i <= n; i++) {
    if (is_item(L[i]) && item_key(L[i]) == id) {
      matches++
      if (!t) t = i
    }
  }
  if (matches == 0) {
    printf "no backlog row matched %s\n", id > "/dev/stderr"
    exit 3
  }
  if (matches > 1) {
    printf "%s matched more than one backlog row\n", id > "/dev/stderr"
    exit 4
  }

  tb = body_end(t)
  closed = L[t]
  # POSIX awk has no backreferences in sub(), so the checkbox is rewritten from
  # the matched prefix rather than with a capture group.
  if (match(closed, /^[ \t]*- \[[ xX]\]/)) {
    tail = substr(closed, RLENGTH + 1)
    closed = substr(closed, 1, RLENGTH)
    sub(/\[.\]$/, "[x]", closed)
    closed = closed tail
  }
  if (note != "" && index(closed, note) == 0) closed = closed note

  move = (SEC[t] == "In flight")

  # The Done section runs from its last "## Done" header to the next header.
  dstart = 0
  dend = n
  if (last_done > 0) {
    dstart = last_done + 1
    for (i = dstart; i <= n; i++) {
      if (is_head(L[i])) { dend = i - 1; break }
    }
  }

  # Closed rows inside Done are the prune inventory. Open rows never count.
  dc = 0
  if (last_done > 0) {
    for (i = dstart; i <= dend; i++) {
      if (is_item(L[i]) && item_closed(L[i])) {
        dc++
        drow[dc] = i
        ddate[dc] = first_date(L[i])
      }
    }
  }
  # A row moved in now is the newest entry in Done.
  if (move && last_done > 0) {
    dc++
    drow[dc] = t
    ddate[dc] = first_date(closed)
  }

  # Keep the <keep> most recent closed rows: newest date first, and on a tie
  # the one that sits higher in the section, because Done is newest-first.
  for (s = 1; s <= keep; s++) {
    best = 0
    for (k = 1; k <= dc; k++) {
      if (sel[k]) continue
      if (best == 0) { best = k; continue }
      if (ddate[k] > ddate[best] || (ddate[k] == ddate[best] && drow[k] < drow[best])) best = k
    }
    if (best == 0) break
    sel[best] = 1
  }
  for (k = 1; k <= dc; k++) {
    if (sel[k]) continue
    if (drow[k] == t) continue
    prune[drow[k]] = 1
  }
  for (k = 1; k <= dc; k++) {
    if (prune[drow[k]]) pend[drow[k]] = body_end(drow[k])
  }

  arc_n = 0
  skip_to = 0
  for (i = 1; i <= n; i++) {
    if (skip_to >= i) continue
    if (i == t && move) {
      # The row leaves In flight and reappears at the top of Done.
      skip_to = tb
      continue
    }
    if (i == t) {
      print closed
      continue
    }
    if (prune[i]) {
      arc[++arc_n] = L[i]
      for (j = i + 1; j <= pend[i]; j++) arc[++arc_n] = L[j]
      skip_to = pend[i]
      continue
    }
    if (i == last_done && move) {
      print L[i]
      print closed
      for (j = t + 1; j <= tb; j++) print L[j]
      continue
    }
    print L[i]
  }
  if (move && last_done == 0) {
    # No Done section at all: create one at the end of the file.
    print ""
    print "## Done"
    print closed
    for (j = t + 1; j <= tb; j++) print L[j]
  }
  if (arc_n > 0) {
    printf "<!-- archived by fm-backlog-mark-done.sh -->\n" > arcfile
    for (k = 1; k <= arc_n; k++) print arc[k] > arcfile
    close(arcfile)
  }
}
' "$BACKLOG" > "$TMP_NEW" || AWK_STATUS=$?

if [ "$AWK_STATUS" -ne 0 ]; then
  exit "$AWK_STATUS"
fi

# Archive first: if history cannot be preserved, the backlog must not change.
if [ -s "$TMP_ARC" ]; then
  if ! { mkdir -p -- "$(dirname "$ARCHIVE")" && cat -- "$TMP_ARC" >> "$ARCHIVE"; } 2>/dev/null; then
    printf 'error: cannot append to the backlog archive %s; the backlog was left unchanged\n' "$ARCHIVE" >&2
    exit 2
  fi
fi

chmod "$MODE" "$TMP_NEW" 2>/dev/null || true
mv -- "$TMP_NEW" "$BACKLOG"
trap - EXIT INT TERM
rm -f -- "$TMP_ARC"
printf 'Backlog: %s closed in %s\n' "$ID" "$BACKLOG"
