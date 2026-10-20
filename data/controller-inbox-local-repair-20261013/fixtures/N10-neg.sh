#!/usr/bin/env bash
# N10: Negative control — symlink broken: real file missing, symlink to ghost
# Expectation: no real.md reported; fixture must exit 1 (proving real.md count check works)
set -u
PATCHED="${PATCHED:-$1}"

TD=$(mktemp -d)
trap 'rm -rf "$TD"' EXIT

mkdir -p "$TD/inbox" "$TD/state"
# No real file — symlink to non-existent target
rm -f "$TD/inbox/real.md"
ln -s "$TD/inbox/ghost.md" "$TD/inbox/link.md"
echo "entered_epoch: 1790000000" > "$TD/state/.afk-contract"
echo "1790000000" > "$TD/state/.afk"

cp "$PATCHED" "$TD/check.sh"
python3 -c "
c = open('$TD/check.sh').read()
c = c.replace('INBOX=/home/hd2admin/controller-replies', 'INBOX=$TD/inbox')
open('$TD/check.sh','w').write(c)
"

export FM_HOME="$TD" FM_STATE_OVERRIDE="$TD/state"
OUTPUT=$(bash "$TD/check.sh" 2>&1)

# Explicitly handle no-match case: grep -c on empty stdin returns 0 count
if printf '%s\n' "$OUTPUT" | grep -q 'real.md'; then
  REAL_COUNT=$(printf '%s\n' "$OUTPUT" | grep -c 'real.md')
else
  REAL_COUNT=0
fi

if [ "$REAL_COUNT" -ne 1 ]; then
  echo "EXPECTED FAIL (exit 1): real.md count is $REAL_COUNT (expected 1)"
  echo "Output: $OUTPUT"
  exit 1
else
  echo "UNEXPECTED PASS: real.md appeared despite being absent"
  echo "Output: $OUTPUT"
  exit 1
fi
