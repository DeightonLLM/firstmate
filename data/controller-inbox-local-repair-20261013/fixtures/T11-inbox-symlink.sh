#!/usr/bin/env bash
# T11: INBOX is symlink — fails safe with error message
# Expectation: poll exits 0 (fail-safe design) with "directory is unavailable"
# Failure: wrong output or missing error → exit 1
set -u
PATCHED="${PATCHED:-$1}"

TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

mkdir -p "$TESTDIR/real-inbox"
echo "g" > "$TESTDIR/real-inbox/g.md"
rm -f "$TESTDIR/inbox-sym"
ln -s "$TESTDIR/real-inbox" "$TESTDIR/inbox-sym"
mkdir -p "$TESTDIR/state"
echo "entered_epoch: 1790000000" > "$TESTDIR/state/.afk-contract"
echo "1790000000" > "$TESTDIR/state/.afk"

cp "$PATCHED" "$TESTDIR/check.sh"
python3 -c "
import sys
c = open('$TESTDIR/check.sh').read()
c = c.replace('INBOX=/home/hd2admin/controller-replies', 'INBOX=$TESTDIR/inbox-sym')
open('$TESTDIR/check.sh','w').write(c)
"

export FM_HOME="$TESTDIR" FM_STATE_OVERRIDE="$TESTDIR/state"
POLL_EXIT=0
OUTPUT=$(bash "$TESTDIR/check.sh" 2>&1) || POLL_EXIT=$?

if ! printf '%s\n' "$OUTPUT" | grep -q 'directory is unavailable'; then
  echo "FAIL: expected 'directory is unavailable' error"
  echo "Got output: $OUTPUT"
  exit 1
fi

echo "PASS: INBOX symlink correctly rejected with safe error"
exit 0
