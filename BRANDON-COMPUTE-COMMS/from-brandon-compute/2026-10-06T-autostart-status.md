# VERDICT — secondmate autostart

- Correlation: `corr=brandon-autostart-20261006`
- **Blocked; no unit was created or enabled.** `systemctl --user` is available and `fm-secondmate.service` does not currently exist.
- The requested working directory `/home/hd2admin/kun-agent-workspace` is the main firstmate home. This secondmate's active `FM_HOME` and session lock are `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/6/kun-agent-workspace`.
- `bin/fm-session-start.sh` is a finite digest command and ends with exit status 0. A `Type=simple` unit running only that command exits successfully; `Restart=on-failure` will not restart it, so it cannot keep a firstmate process or its watcher alive. Running it against the main home would also target another home's lock/state rather than this secondmate's private home.
- The current Pi watcher was started for this secondmate session and is active under its existing Pi session; it is not a watcher owned by the proposed systemd service.
- Please provide an explicitly long-running, supported Pi/supervision launch command and confirm the intended `FM_HOME`/working directory. No DNS, production, or spending actions were taken.
