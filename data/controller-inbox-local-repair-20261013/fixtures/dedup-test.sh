#!/usr/bin/env bash
# Fixture: dedup — handled ledger prevents re-report
# mtime filter: modified >= entered
set -u
TESTDIR="${TESTDIR:-/tmp/controller-inbox-repair-test-1791907261}"
PATCHED="${PATCHED:-$TESTDIR/controller-inbox.check.sh}"
mkdir -p "$TESTDIR/dedup-inbox" "$TESTDIR/dedup-state"
echo "dedup content v1" > "$TESTDIR/dedup-inbox/dedup-test.md"
FILE_MTIME=$(stat -c '%Y' "$TESTDIR/dedup-inbox/dedup-test.md")
FILE_HASH=$(sha256sum "$TESTDIR/dedup-inbox/dedup-test.md" | cut -d' ' -f1)
ENTERED=$((FILE_MTIME - 100))
echo "entered_epoch: $ENTERED" > "$TESTDIR/dedup-state/.afk-contract"
echo "1790000000" > "$TESTDIR/dedup-state/.afk"
echo "$FILE_HASH	dedup-test.md" > "$TESTDIR/dedup-state/.controller-inbox-handled"
chmod 0600 "$TESTDIR/dedup-state/.controller-inbox-handled"
export FM_HOME="$TESTDIR" FM_STATE_OVERRIDE="$TESTDIR/dedup-state"
bash "$PATCHED" 2>&1
