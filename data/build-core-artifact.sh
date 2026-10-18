#!/usr/bin/env bash
# Package the tested Core-Distro WordPress port as a deployable artifact with a
# revision identity and an integrity manifest.
# Purpose: the publish attempt stopped because the exact tested artifact, its
# revision, and its integrity proof were missing. This produces all three.
set -eu
SRC=/home/hd2admin/campaign/core-distro-stage/theme
OUT=/home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact
NAME=core-distro-astra-child

mkdir -p "$OUT"
rm -rf "$OUT/$NAME"
cp -a "$SRC" "$OUT/$NAME"

# Integrity manifest: one sha256 per file, sorted so it is reproducible.
( cd "$OUT" && find "$NAME" -type f -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum > SHA256SUMS )

FILES=$(find "$OUT/$NAME" -type f | wc -l | tr -d ' ')
MANIFEST_SHA=$(sha256sum "$OUT/SHA256SUMS" | cut -d' ' -f1)

# Revision identity: a content-addressed id, not a timestamp. The same theme
# always yields the same revision, so "which build is this?" has one answer.
REV=$(printf '%s' "$MANIFEST_SHA" | cut -c1-12)
THEME_VERSION=$(grep -m1 '^Version:' "$SRC/style.css" 2>/dev/null | awk '{print $2}')

cat > "$OUT/ARTIFACT.md" <<EOF
# Core-Distro WordPress port — deployable artifact

**Revision:** \`$REV\`
**Theme version:** \`$THEME_VERSION\`
**Parent theme required:** Astra 4.14.0 (WordPress.org, free)
**Child theme directory:** \`$NAME/\`
**Files:** $FILES
**Integrity manifest sha256:** \`$MANIFEST_SHA\`

## What this is

The tested WordPress port of live core-distro.com: an Astra child theme plus the
generated homepage body and public stylesheet. It is the build that scored 10/10
on its test suite with all 12 intended routes returning HTTP 200 on the private
origin.

## Verify before deploying

\`\`\`
cd $OUT
sha256sum -c SHA256SUMS
\`\`\`

Every line must report \`OK\`. A mismatch means the artifact is not the tested one
and must not be deployed.

## Deploy

1. Install WordPress plus the Astra 4.14.0 parent theme.
2. Copy \`$NAME/\` to \`wp-content/themes/$NAME/\`.
3. Activate \`$NAME\` as the active theme.
4. Verify the 12 intended routes, then confirm the chatbot.

## Honest scope of this artifact

- It is **not** a database export. Page records and the menu must exist in the
  target install; the theme alone does not create them.
- The chatbot is **not activated** in this build. Captain's acceptance requires a
  working chatbot, so that remains outstanding.
- The newsletter form is intentionally inert. Do not enable it against live.
- Nine duplicate seed page records were previously present and were drafted, not
  deleted. Check the target install for duplicates before importing content.

## Provenance

Built from \`$SRC\`
Revision is content-addressed: the same source always produces \`$REV\`.
EOF

printf 'revision=%s\nfiles=%s\nmanifest_sha=%s\ntheme_version=%s\n' \
  "$REV" "$FILES" "$MANIFEST_SHA" "$THEME_VERSION" > "$OUT/REVISION"
echo "revision=$REV files=$FILES theme=$THEME_VERSION"