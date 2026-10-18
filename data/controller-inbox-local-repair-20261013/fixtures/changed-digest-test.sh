#!/usr/bin/env bash
# Fixture: changed-digest ack refusal
# File content changes between hash read and ack
set -u
TESTDIR="${TESTDIR:-/tmp/controller-inbox-repair-test-1791907261}"
PATCHED="${PATCHED:-$TESTDIR/controller-inbox.check.sh}"
mkdir -p "$TESTDIR/changed-inbox" "$TESTDIR/changed-state"
echo "original content" > "$TESTDIR/changed-inbox/changed-test.md"
ORIG_HASH=$(sha256sum "$TESTDIR/changed-inbox/changed-test.md" | cut -d' ' -f1)
echo "modified content" > "$TESTDIR/changed-inbox/changed-test.md"
export FM_HOME="$TESTDIR" FM_STATE_OVERRIDE="$TESTDIR/changed-state"
bash "$PATCHED" --ack changed-test.md "$ORIG_HASH" 2>&1
