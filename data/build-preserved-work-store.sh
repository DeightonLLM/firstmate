#!/usr/bin/env bash
# Build one readable record per unlanded Core-Distro branch.
# Preserved work stays visible instead of being lost in an unmerged branch.
set -u
REPO=/home/hd2admin/kun-agent-workspace/projects/core-distro-saas-clean
OUT=/home/hd2admin/kun-agent-workspace/warehouse/preserved-work
mkdir -p "$OUT"
for b in fm/core-stream-a-checkpoint-0924 fm/core-mobile-fix fm/core-v3-product-acceptance-spec-0927; do
  f="$OUT/$(basename "$b").md"
  {
    echo "# Preserved work: \`$b\`"
    echo
    echo "**Project:** core-distro-saas-clean"
    echo "**Status:** NOT LANDED. Kept on Captain's instruction, 2026-10-14."
    echo "**Commits ahead of origin/main:** $(git -C "$REPO" rev-list --count origin/main.."$b")"
    echo "**Tip:** \`$(git -C "$REPO" rev-parse --short "$b")\`"
    echo
    echo "## What is in it"
    echo '```'
    git -C "$REPO" log --oneline origin/main.."$b" | sed 's/^/  /'
    echo '```'
    echo
    echo "## Files it touches"
    echo '```'
    git -C "$REPO" diff --stat origin/main..."$b" | head -25
    echo '```'
    echo
    echo "## How to review it"
    echo '```'
    echo "  git -C $REPO log -p origin/main..$b"
    echo "  git -C $REPO diff origin/main...$b"
    echo '```'
    echo
    echo "## Why it is not landed"
    echo
    echo "The work is complete on its branch but was never merged into the default branch."
    echo "A status line reading \`ready in branch\` means finished-but-waiting, NOT delivered."
    echo "Two entries were previously misreported as done on exactly this basis."
    echo "Preserved here so the work is visible rather than lost."
  } > "$f"
  echo "wrote $(basename "$f")"
done