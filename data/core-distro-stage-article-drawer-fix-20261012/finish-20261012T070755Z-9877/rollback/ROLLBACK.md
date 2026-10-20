# Rollback (exact, no data loss)

Targets:
  /home/hd2admin/campaign/core-distro-stage/theme/stage-content-fixes.php
  /home/hd2admin/campaign/core-distro-stage/tests/lighthouse-content-fixes.php

Before-images (byte-identical originals, mode/owner preserved):
  /home/hd2admin/kun-agent-workspace/data/core-distro-stage-article-drawer-fix-20261012/finish-20261012T070755Z-9877/rollback/theme/stage-content-fixes.php    sha256 510cd7ef5d75cf4c8d278dcd6f175e6bac1ed9c805a3573a6f754e7985f7f098
  /home/hd2admin/kun-agent-workspace/data/core-distro-stage-article-drawer-fix-20261012/finish-20261012T070755Z-9877/rollback/tests/lighthouse-content-fixes.php sha256 8bf78a0d0fcb2c8f9f96b524a15fae778a822885b3b27ff38a2dc810dfdde9dc

Procedure (atomic rename, ownership/mode taken from the target):
  for rel in theme/stage-content-fixes.php tests/lighthouse-content-fixes.php; do
    T="/home/hd2admin/campaign/core-distro-stage/$rel"; S="/home/hd2admin/kun-agent-workspace/data/core-distro-stage-article-drawer-fix-20261012/finish-20261012T070755Z-9877/rollback/$rel"
    TMP="$(dirname "$T")/.fm-rollback.$$.$(basename "$T")"
    cat "$S" > "$TMP"; chown --reference="$T" "$TMP"; chmod --reference="$T" "$TMP"
    mv -f "$TMP" "$T"
  done

No service restart, container change, database write, or content seed change is involved:
only these two theme/test files changed.
