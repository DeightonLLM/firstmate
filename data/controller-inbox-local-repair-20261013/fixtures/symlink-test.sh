#!/usr/bin/env bash
# Fixture: symlink safety — file symlink skipped, INBOX symlink fails safe
set -u
TESTDIR="${TESTDIR:-/tmp/controller-inbox-repair-test-1791907261}"
PATCHED="${PATCHED:-$TESTDIR/controller-inbox.check.sh}"
mkdir -p "$TESTDIR/sym-inbox2" "$TESTDIR/sym-state2"
echo "real content" > "$TESTDIR/sym-inbox2/real.md"
ln -s "$TESTDIR/sym-inbox2/real.md" "$TESTDIR/sym-inbox2/link.md"
echo "entered_epoch: 1790000000" > "$TESTDIR/sym-state2/.afk-contract"
echo "1790000000" > "$TESTDIR/sym-state2/.afk"
cp "$PATCHED" "$TESTDIR/sym2-check.sh"
INBOX_DIR="$TESTDIR/sym-inbox2"
python3 -c "
content = open('$TESTDIR/sym2-check.sh').read()
content = content.replace('INBOX=/home/hd2admin/controller-replies', 'INBOX=$INBOX_DIR')
open('$TESTDIR/sym2-check.sh', 'w').write(content)
"
export FM_HOME="$TESTDIR" FM_STATE_OVERRIDE="$TESTDIR/sym-state2"
bash "$TESTDIR/sym2-check.sh" 2>&1
