#!/usr/bin/env bash
# T09: Changed digest — --ack refuses when file content changed after hash read
# Expectation: --ack exits 1 with "refused: Controller message changed"
# Failure: wrong output or wrong exit code → exit 1
set -u
PATCHED="${PATCHED:-$1}"

TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

mkdir -p "$TESTDIR/inbox" "$TESTDIR/state"
echo "orig" > "$TESTDIR/inbox/d2.md"
OH=$(sha256sum "$TESTDIR/inbox/d2.md" | cut -d' ' -f1)
echo "modd" > "$TESTDIR/inbox/d2.md"

cp "$PATCHED" "$TESTDIR/check.sh"
python3 -c "
import sys
c = open('$TESTDIR/check.sh').read()
c = c.replace('INBOX=/home/hd2admin/controller-replies', 'INBOX=$TESTDIR/inbox')
open('$TESTDIR/check.sh','w').write(c)
"

export FM_HOME="$TESTDIR" FM_STATE_OVERRIDE="$TESTDIR/state"
ACK_EXIT=0
OUTPUT=$(bash "$TESTDIR/check.sh" --ack d2.md "$OH" 2>&1) || ACK_EXIT=$?

EXPECTED="refused: Controller message changed after it was read"

if [ "$ACK_EXIT" -ne 1 ]; then
  echo "FAIL: expected exit 1, got $ACK_EXIT"
  echo "$OUTPUT"
  exit 1
fi

if [ "$OUTPUT" != "$EXPECTED" ]; then
  echo "FAIL: expected output '$EXPECTED'"
  echo "       got output '$OUTPUT'"
  exit 1
fi

echo "PASS: changed-digest correctly refused with exit 1"
exit 0
