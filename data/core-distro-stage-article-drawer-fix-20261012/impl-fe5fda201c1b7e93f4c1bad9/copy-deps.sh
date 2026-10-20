#!/usr/bin/env bash
# Enumerated, secret-free copy of ONLY the source/test/fixture dependencies
# required to run the offline PHP / Node / Python suites. No recursive copy,
# no symlinks, no secrets, no backups, no vendor, no config.
set -eu

SRC=/home/hd2admin/campaign/core-distro-stage
WS=/home/hd2admin/kun-agent-workspace/data/core-distro-stage-article-drawer-fix-20261012/impl-fe5fda201c1b7e93f4c1bad9

cd "$SRC"

# Explicit enumeration. Each entry is justified by a concrete read in a suite.
FILES=(
  # target suite: tests/lighthouse-content-fixes.php
  theme/stage-content-fixes.php            # line 14: the helper under test
  build/pages/about.html                   # line 80: canonical fixture glob
  build/pages/aluminum-seals.html
  build/pages/blog.html
  build/pages/compliance.html
  build/pages/contact.html
  build/pages/faq.html
  build/pages/glass-vials.html
  build/pages/products.html
  build/pages/register.html
  build/pages/resources.html                # line 71: explicit read
  build/pages/rubber-stoppers.html
  # target suite: tests/lighthouse-remediation.mjs (local-source-only suite)
  theme/public-homepage-body.html           # line 58
  theme/partials/cd-page-footer.php        # line 59
  theme/functions.php                      # line 60
  theme/assets/stage-compat.css            # line 61
  tests/lighthouse-remediation.mjs          # the suite itself
  # target suite: tests/test_extract_lighthouse_fixes.py
  tools/extract-route-content.py            # line 11: module under test
  tests/test_extract_lighthouse_fixes.py    # the suite itself
  # the targeted PHP suite itself
  tests/lighthouse-content-fixes.php
)

mkdir -p "$WS/originals" "$WS/evidence" "$WS/logs"

MANIFEST="$WS/manifest.tsv"
: > "$MANIFEST"
printf 'relpath\tbytes\tsha256\n' >> "$MANIFEST"

for rel in "${FILES[@]}"; do
  if [ ! -f "$SRC/$rel" ]; then echo "MISSING SOURCE: $rel" >&2; exit 1; fi
  if [ -L "$SRC/$rel" ]; then echo "REFUSING SYMLINK: $rel" >&2; exit 1; fi
  case "$rel" in
    .env*|*/.env*|*wp-config*|*compose*|*backups/*|*.bak*|*vendor/*|*.sql|*.sqlite*|*.tar|*.gz|*.zip)
      echo "REFUSING FORBIDDEN CLASS: $rel" >&2; exit 1;;
  esac
  mkdir -p "$WS/$(dirname "$rel")" "$WS/originals/$(dirname "$rel")"
  cp -p "$SRC/$rel" "$WS/$rel"
  cp -p "$SRC/$rel" "$WS/originals/$rel"
  h=$(sha256sum "$SRC/$rel" | cut -d' ' -f1)
  b=$(stat -c %s "$SRC/$rel")
  printf '%s\t%s\t%s\n' "$rel" "$b" "$h" >> "$MANIFEST"
done

echo "COPIED ${#FILES[@]} enumerated files"
echo "--- verify no symlinks anywhere in workspace copy ---"
found=$(find "$WS" -type l | wc -l)
echo "symlink count = $found"
[ "$found" -eq 0 ] || { echo "SYMLINK FOUND" >&2; exit 1; }
echo "--- verify originals match workspace copies byte-for-byte ---"
while IFS=$'\t' read -r rel b h; do
  [ "$rel" = "relpath" ] && continue
  o=$(sha256sum "$WS/originals/$rel" | cut -d' ' -f1)
  w=$(sha256sum "$WS/$rel" | cut -d' ' -f1)
  [ "$o" = "$h" ] || { echo "ORIGINAL MISMATCH: $rel" >&2; exit 1; }
  [ "$w" = "$h" ] || { echo "COPY MISMATCH: $rel" >&2; exit 1; }
done < "$MANIFEST"
echo "ORIGINALS+COPIES VERIFIED against source hashes"
echo "--- manifest ---"
cat "$MANIFEST"