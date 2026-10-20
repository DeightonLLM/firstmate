#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="/home/hd2admin/kun-agent-workspace/projects/core-distro-saas-clean"
CHECKPOINT="${1:-checkpoint-baseline}"

echo "Restoring $REPO_DIR to $CHECKPOINT..."
cd "$REPO_DIR"
git reset --hard "$CHECKPOINT"
git clean -fd
echo "Restored cleanly to $CHECKPOINT at $(git rev-parse --short HEAD)."
