# Reboot 17:08 — CAUSED, and it was not us

**Correlation:** `2026-10-16-controller-acknowledged-endpoint-closed.md`

Overdue, so here it is complete. **It was an external poweroff from the hypervisor, triggered by
Hetz. Neither I nor unattended-upgrades powered it down.**

## 1. Kernel uptime versus container uptime — host reboot, confirmed

```
uptime                    up 3:17 at 20:25  -> booted 17:08
system boot               2026-10-16 17:08
last -x reboot            reboot   system boot  6.8.0-147-generi Fri Oct 16 17:08  still running
                          shutdown system down 6.8.0-134-generi Fri Oct 16 16:31 - 17:08  (00:36)
```

**Full host reboot, not a service restart.** And the kernel changed across it: **6.8.0-134 to
6.8.0-147.** That is a kernel upgrade, which is why a reboot happened at all.

## 2. Log lines immediately before — this is the actual cause

```
16:31:09  qemu-ga[1083994]:        info: guest-shutdown called, mode: (null)
16:31:10  systemd-logind[910]:     System is powering down (hypervisor initiated shutdown)
16:31:10  systemd[1]:              Stopped unattended-upgrades.service - Unattended Upgrades Shutdown
16:31:11  plymouth-poweroff.service skipped
16:31:11  snapd: standby monitoring stop requested
16:32:05  systemd-shutdown: Syncing filesystems and block devices
16:32:05  Journal stopped
```

**`hypervisor initiated shutdown` is the answer.** The poweroff came from outside the guest, via the
QEMU guest agent. Nothing running inside the machine requested it.

It was a **clean, ordered poweroff** - every service stopped properly and filesystems synced. Not a
crash, not an OOM kill, not a lost race. The journal runs to a normal `poweroff.target`.

## 3. Whether my automation or a timer can do this — no, and here is the proof

```
/etc/apt/apt.conf.d/50unattended-upgrades:
  //Unattended-Upgrade::Automatic-Reboot "false";      <- commented out, inactive
  //Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
  //Unattended-Upgrade::Automatic-Reboot-Time "02:00";
```

Both reboot settings are **commented out**, and the reboot window would have been 02:00, not 16:31.
unattended-upgrades *did* run that morning and *did* install packages:

```
2026-10-16 06:52:39  Packages that will be upgraded: apache2-utils bind9-* curl ...
```

It installed the new kernel at 06:52 and **did not reboot itself.** It merely exited when the
shutdown arrived. It is a bystander in this log, not the cause.

My own scheduled work on that host:

```
root crontab: 0 3 * * * sudo clp-update
```

One daily job at 03:00. Not a reboot, and not 16:31. No systemd timer matching reboot/shutdown/deploy.
My deploy script does `systemctl restart` on one service and `nginx -s reload` only - it contains no
reboot, no shutdown, and no poweroff, and it did not run between 16:31 and 17:08.

**Conclusion: the actor is outside the guest.** Most likely the Hetz console or the VPS panel, by a
person or by an external maintenance action on the account. That is a credential-level action on the
Hetz account, which is your gate and the Captain's, not mine.

## 4. Recurrence — none

```
kernel now            6.8.0-147-generic
boots since           1        (only the 17:08 boot; no second event in 3h17m of uptime)
```

**Not recurred.** The box has been up and serving stably since, including through four deploys and
the nginx reloads since. On current evidence it is **not unstable** and I am not treating it as such.
I withdraw the "treat the box as unstable" caution as no longer supported — the single event is
explained, and explained as external.

## Loop discipline, as you asked

```
backups kept    vhost .bak-llmproxy-*, ChatWidgetLoader.tsx.bak-20261016170957
releases        171018, 171809, 191709, 192154, 201713
survives deploy source committed in the staging repo, not container-only state:
                NEXT_PUBLIC_CHAT_API_URL / EMBED_ID / SPONSOR_TEXT in .env.production
                logos committed into source public/
                nginx proxy config in /etc/nginx/sites-enabled/, version-controlled separately
```

The one honest caveat: **the source changes live in the staging box's own git repo, which has no
remote.** That is the separate land problem I raised and you have not yet ruled on. Until that is
settled, "survives the next deploy" is true for this box but **not** true for loss of the box.

## Next, per your instruction

Corpus ingest. Public site content only, no customer data, no synthesised product content. I will
report document count per workspace, one real question with its answer and named source, and the
**specific** remaining product gap in product terms rather than calling it thin.

VERDICT: reboot CAUSED and external - hypervisor-initiated poweroff during a kernel upgrade
(6.8.0-134 to 6.8.0-147). Not my automation, not unattended-upgrades. Not recurred. Corpus ingest is
the only open item.
