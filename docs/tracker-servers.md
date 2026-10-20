# Tracker and dashboard servers (Controller)

The Controller hosts two small static-file HTTP servers that back the Captain's
browser tabs. They are plain `python3 -m http.server` processes, each owned by
its own systemd unit, each bound to a Tailscale address on the Controller.

This page is the operator reference for those two servers: what they are, which
unit owns them, what they cost, and what to check when a tab goes blank. The
unit files remain the authoritative definition of each server; this page points
at them rather than copying them.

## The two servers

| Server | Port | Unit | Serves |
| --- | --- | --- | --- |
| lane-todo dashboard | 4390 | `lane-dash-serve.service` | `/root/agent-work/deightonllm-firstmate/data/end-to-end-20261012` — the root path returns a small redirect page to `LANE-TODO-DASH.html`. |
| tracker-view dashboard | 8477 | `tracker-view-serve.service` | `/root/tracker-view` — a directory holding one symlink, `index.html`, pointing into the live primary checkout at `data/tracker-build-20261017/tracker/candidate-preview.html`. |

Both are reachable on the Controller's Tailscale address (`100.117.47.27`),
which is the address the Captain's tabs use.

The tracker-view symlink is deliberate: the served content follows the live
checkout, so a rebuilt tracker page appears on the next reload without anyone
restarting the server. Do not replace the symlink with a copy.

## Unit files (the authoritative definition)

- `/etc/systemd/system/lane-dash-serve.service` — the lane-todo server.
- `/etc/systemd/system/lane-dash-serve.service.d/10-resource-limits.conf` — the
  resource ceiling for that unit.
- `/etc/systemd/system/tracker-view-serve.service` — the tracker-view server.

Read them with `systemctl cat <unit>`; it shows the unit plus any drop-ins.

## Restart and boot behaviour

Both units set `Restart=always` with `RestartSec=2`, so a crashed server comes
back within about two seconds, and both are `enabled` for `multi-user.target`,
so systemd starts them at boot.

`Restart=always` covers the process dying, but it does not cover the unit
being stopped by an operator (`systemctl stop`), and it does not survive a
reboot on its own — that is what the `enabled` state and the
`WantedBy=multi-user.target` link are for.

To confirm the boot-start wiring without rebooting the host:

```sh
systemctl is-enabled lane-dash-serve.service tracker-view-serve.service
systemctl cat lane-dash-serve.service tracker-view-serve.service
ls -l /etc/systemd/system/multi-user.target.wants/
```

A real reboot was deliberately **not** performed to test this: the Captain's
live fleet runs on the Controller, so the guarantee is established from the
enabled state and the `multi-user.target.wants` symlink rather than from an
observed boot.

## Resource cost and caps

Measured on the Controller (4 cores) on 2026-10-20, with the servers idle and
after a 300-request burst against each:

| Unit | Idle CPU | Idle RSS | Burst CPU | Cap |
| --- | --- | --- | --- | --- |
| `lane-dash-serve.service` | 0.0% of one core | ~20 MB | 2.7% of one core | `MemoryMax=64M`, `CPUQuota=20%` |
| `tracker-view-serve.service` | 0.0% of one core | ~20 MB | 5.1% of one core | `MemoryMax=64M`, `CPUQuota=20%` |

Both units are bounded by a 64 MB memory ceiling and a 20% slice of one core.
That is a small, fixed share of the host: even a pathological request burst
cannot take more than 40% of a single core across both units, and memory cannot
exceed 128 MB in total. Observed use sits far below those ceilings, so a normal
page load is never throttled into failure.

The units serve static files only, which is why the idle cost rounds to zero:
there is no application logic running between requests.

## Checking the servers

The regression check asserts the whole contract in one pass — both units exist,
are enabled, are active, carry a `Restart=` policy and a resource cap, and both
endpoints answer HTTP 200:

```sh
tests/tracker-servers.check.sh
```

It only reads state (`systemctl show`, `systemctl is-enabled`,
`systemctl is-active`, `curl`, `sha256sum`); it never starts, stops, or
restarts anything, so it is safe to run at any time.

It is deliberately named `tests/tracker-servers.check.sh` rather than
`tests/tracker-servers.test.sh`: `bin/fm-test-run.sh --check-coverage` requires
the portable CI shard union to equal the `tests/*.test.sh` inventory exactly,
and these are live assertions about the Controller host that cannot pass on a
GitHub runner. `bin/fm-lint.sh` still lints the file.

Ad-hoc checks:

```sh
systemctl status lane-dash-serve.service tracker-view-serve.service
curl -s -o /dev/null -w '%{http_code}\n' http://100.117.47.27:4390/
curl -s -o /dev/null -w '%{http_code}\n' http://100.117.47.27:8477/
```

## When the Captain's tab is blank

Work down this list; it is ordered from most likely to least.

1. **Is the unit running?** `systemctl is-active lane-dash-serve.service` and
   `systemctl is-active tracker-view-serve.service`. A unit that is `failed`
   has usually just crashed; `systemctl restart <unit>` clears it, and
   `Restart=always` should have cleared it already.
2. **Is the port actually listening?** `ss -ltnp | grep -E ':4390|:8477'`. A
   unit that is `active` but not listening means the bind address is wrong or
   the Tailscale address changed.
3. **Is the Tailscale address still right?** The units bind to
   `100.117.47.27` explicitly. If the Controller's Tailscale address changed,
   the bind fails and the unit will not start; check `tailscale ip -4` and the
   `ExecStart` line in the unit file.
4. **Is the content still there?** For tracker-view, the served file is a
   symlink into the live checkout. If the checkout moved, the symlink dangles
   and the server returns 404 or an error body even though the unit is healthy.
   Check `readlink -f /root/tracker-view/index.html` and that the target
   exists.
5. **Is it the browser's cache?** A hard reload (Ctrl-Shift-R) before
   suspecting the server.

If the unit is `active`, the port is listening, and `curl` from the Controller
returns 200, the server is fine and the problem is on the viewing side.

## Related

- `docs/configuration.md` — operational-home layout and configuration schemas.
- `docs/documentation-audiences.md` — the audience policy this page is
  classified under.
