#!/usr/bin/env bash
# N09: Negative control — changed-digest broken: file unchanged, ack succeeds
# Expectation: ack exits 0 (file unchanged); fixture must exit 1 (proving fail-path works)
set -u
PATCHED="${PATCHED:-$1}"

TD=$(mktemp -d)
trap 'rm -rf "$TD"' EXIT

mkdir -p "$TD/inbox" "$TD/state"
echo "orig" > "$TD/inbox/d2.md"
OH=$(sha256sum "$TD/inbox/d2.md" | cut -d' ' -f1)
# File unchanged — hash matches, ack should succeed

cp "$PATCHED" "$TD/check.sh"
python3 -c "
c = open('$TD/check.sh').read()
c = c.replace('INBOX=/home/hd2admin/controller-replies', 'INBOX=$TD/inbox')
open('$TD/check.sh','w').write(c)
"

export FM_HOME="$TD" FM_STATE_OVERRIDE="$TD/state"
ACK_EXIT=0
OUTPUT=$(bash "$TD/check.sh" --ack d2.md "$OH" 2>&1) || ACK_EXIT=$?

if [ "$ACK_EXIT" -eq 0 ] && echo "$OUTPUT" | grep -q "acknowledged"; then
  echo "EXPECTED FAIL (exit 1): ack succeeded (file unchanged, hash matched)"
  echo "Output: $OUTPUT"
  exit 1
else
  echo "UNEXPECTED: unexpected ack behavior"
  echo "Output: $OUTPUT, exit: $ACK_EXIT"
  exit 1
fi
