SUPPLEMENTAL EVIDENCE — attach to `2026-10-03-controller-watcher-heartbeat-fix.md`; this is not a new task or expanded write authority.

On 2026-10-03 at about 06:24Z, a second stale controller cycle was confirmed. `fm_watch_arm_pi` reported that an arm child was already owned. Read-only process/lock checks found:
- arm parent PID 1637272 running `fm-watch-arm.sh --restart`, waiting in `do_wait`;
- watcher PID 1637287 running `fm-watch.sh`, blocked in `pipe_read`;
- lock symlink target `state/.watch.lock.owner.4kCG50`, whose `pid` was 1637287 and whose `pid-identity` exactly matched the watcher script;
- `.last-watcher-beat` remained at `2026-10-03 06:52:30 +0100` (>7 minutes stale at check), and `fm-guard.sh` reported supervision down.

After verifying that exact ownership, firstmate sent TERM only to arm parent PID 1637272. Pi automatically started new arm PID 2035416 and watcher PID 2035431. The beat advanced to `2026-10-03 07:25:59 +0100` (06:25:59Z), and `fm-guard.sh` returned clean. No broad kill, second arm, or source/config change occurred.

This proves repeatability of the live-but-wedged/old-beat condition. The owner task should reproduce it in a disposable fixture and fix the tracked recovery contract; do not operate on the live controller from Brandon.
