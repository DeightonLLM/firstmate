#!/usr/bin/env bash
# T10: File symlink — skipped; real file reported exactly once
# Expectation: link.md NOT in output; real.md in output exactly once; exit 0
# Failure: link.md present, real.md absent or duplicated, or non-zero exit → exit 1
set -u
PATCHED="${PATCHED:-$1}"

TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

mkdir -p "$TESTDIR/inbox" "$TESTDIR/state"
echo "real" > "$TESTDIR/inbox/real.md"
rm -f "$TESTDIR/inbox/link.md"
ln -s "$TESTDIR/inbox/real.md" "$TESTDIR/inbox/link.md"
echo "entered_epoch: 1790000000" > "$TESTDIR/state/.afk-contract"
echo "1790000000" > "$TESTDIR/state/.afk"

cp "$PATCHED" "$TESTDIR/check.sh"
python3 -c "
import sys
c = open('$TESTDIR/check.sh').read()
c = c.replace('INBOX=/home/hd2admin/controller-replies', 'INBOX=$TESTDIR/inbox')
open('$TESTDIR/check.sh','w').write(c)
"

export FM_HOME="$TESTDIR" FM_STATE_OVERRIDE="$TESTDIR/state"
POLL_EXIT=0
OUTPUT=$(bash "$TESTDIR/check.sh" 2>&1) || POLL_EXIT=$?

# Count real.md appearances (must be exactly 1)
# Explicitly handle no-match: grep -c on empty stdin returns 0 count
if printf '%s\n' "$OUTPUT" | grep -q 'real.md'; then
  REAL_COUNT=$(printf '%s\n' "$OUTPUT" | grep -c 'real.md')
else
  REAL_COUNT=0
fi

# link.md must not appear
if printf '%s\n' "$OUTPUT" | grep -q 'link.md'; then
  echo "FAIL: link.md should not appear in output"
  echo "$OUTPUT"
  exit 1
fi

# real.md must appear exactly once
if [ "$REAL_COUNT" -ne 1 ]; then
  echo "FAIL: real.md should appear exactly once, got $REAL_COUNT"
  echo "$OUTPUT"
  exit 1
fi

# Poll must exit 0
if [ "$POLL_EXIT" -ne 0 ]; then
  echo "FAIL: poll exited $POLL_EXIT, expected 0"
  echo "$OUTPUT"
  exit 1
fi

echo "PASS: symlink filtered out, real file reported exactly once"
exit 0
