#!/usr/bin/env bash
# T08: Dedup — handled ledger prevents re-report
# Expectation: poll exits 0 with empty output (message in handled ledger)
# Failure: non-empty output → exit 1
set -u
PATCHED="${PATCHED:-$1}"

TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

mkdir -p "$TESTDIR/inbox" "$TESTDIR/state"
echo "dedup v1" > "$TESTDIR/inbox/d1.md"
MT=$(stat -c '%Y' "$TESTDIR/inbox/d1.md")
HASH=$(sha256sum "$TESTDIR/inbox/d1.md" | cut -d' ' -f1)
echo "entered_epoch: $((MT - 10))" > "$TESTDIR/state/.afk-contract"
echo "1790000000" > "$TESTDIR/state/.afk"
printf '%s\t%s\n' "$HASH" "d1.md" > "$TESTDIR/state/.controller-inbox-handled"
chmod 0600 "$TESTDIR/state/.controller-inbox-handled"

cp "$PATCHED" "$TESTDIR/check.sh"
python3 -c "
import sys
c = open('$TESTDIR/check.sh').read()
c = c.replace('INBOX=/home/hd2admin/controller-replies', 'INBOX=$TESTDIR/inbox')
open('$TESTDIR/check.sh','w').write(c)
"

export FM_HOME="$TESTDIR" FM_STATE_OVERRIDE="$TESTDIR/state"
SCRIPT_EXIT=0
OUTPUT=$(bash "$TESTDIR/check.sh" 2>&1) || SCRIPT_EXIT=$?

if [ -n "$OUTPUT" ]; then
  echo "FAIL: unexpected output from poll (message should be suppressed by handled ledger)"
  echo "$OUTPUT"
  exit 1
fi

echo "PASS: poll silent — handled ledger correctly suppressed re-report"
exit 0
