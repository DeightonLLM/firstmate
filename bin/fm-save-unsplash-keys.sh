#!/usr/bin/env bash
# Save Unsplash credentials without echoing them to screen or shell history.
set -u

dir="$HOME/.config/unsplash"
file="$dir/credentials"

mkdir -p "$dir"
chmod 700 "$dir"

echo "Enter your Unsplash keys. Nothing will be typed on screen."
echo

read -rs -p "Access Key: " AK
echo
read -rs -p "Secret Key: " SK
echo

if [[ -z "${AK}" || -z "${SK}" ]]; then
  echo "FAILED: a key was empty, nothing written."
  exit 1
fi

umask 077
printf 'UNSPLASH_ACCESS_KEY=%s\nUNSPLASH_SECRET_KEY=%s\n' "$AK" "$SK" > "$file"
chmod 600 "$file"

unset AK SK

echo
echo "SAVED to $file"
echo "Verify with: grep -c UNSPLASH_ $file   (should print 2)"