# Host-Hardening Security Audit Report (Read-Only)

**Date**: 2026-09-28T22:40:00+01:00  
**Audit Scope**: Controller (`controller` local), Brandon Compute (`brandon-compute`), HD2Stack (`hd2stack`)  
**Lane Mode**: `EXECUTE_BOUNDED_TASK` / `READ_ONLY_AUDIT`  
**Execution Standard**: `hard`-skill baseline  
**Mutation Status**: `NONE — ZERO MUTATIONS PERFORMED` (All recommendations are **NOT APPLIED**)  

---

## 1. Executive Summary & Scope

A read-only host-hardening audit was conducted across the three infrastructure nodes:
1. **Controller** (`controller` / `/root` local): Orchestration node and management control plane.
2. **Brandon Compute** (`brandon-compute` via `ssh brandon-compute`): Heavy compute, AI/agent workloads, and development tooling.
3. **HD2Stack** (`hd2stack` via `ssh hd2stack`): Production hosting node serving live client production sites.

All commands executed were strictly non-mutating inspection probes. No configuration files were altered, no services were reloaded or restarted, no firewall rules were modified, and no package upgrades were initiated.

---

## 2. Per-Host Hardening Baseline Matrix

The following matrix compares live verbatim values obtained from each host against the security hardening baseline.

| Inspection Check | Hardening Baseline Target | Controller (`controller`) | Brandon Compute (`brandon-compute`) | HD2Stack (`hd2stack`) |
| :--- | :--- | :--- | :--- | :--- |
| **(1) SSH: PermitRootLogin** | `no` | `without-password` | `no` | `no` |
| **(1) SSH: PasswordAuthentication** | `no` | `no` | `no` | `no` |
| **(1) SSH: PubkeyAuthentication** | `yes` | `yes` | `yes` | `yes` |
| **(1) SSH: X11Forwarding** | `no` | `yes` ⚠️ | `no` | `no` |
| **(1) SSH: MaxAuthTries** | `3` or `4` | `6` ⚠️ | `4` | `6` ⚠️ |
| **(2) Firewall (UFW) Status** | `active`, default deny in | `active` (Default: deny incoming) | `active` (Default: deny incoming) | `active` (Default: deny incoming) |
| **(2) SSH Firewall Boundary** | Restricted (Tailscale/VPN only) | `22/tcp ALLOW IN Anywhere` ⚠️ | Not open to public (Tailscale only) | `22/tcp ALLOW IN Anywhere` ⚠️ |
| **(3) Fail2Ban Status** | `active` with `sshd` jail | `active` (Jails: `nginx-http-auth`, `sshd`; 182 banned) | `active` (Jails: `sshd`; 0 banned) | `active` (Jails: `sshd`; 0 currently banned, 196 total) |
| **(4) Automatic Updates** | `enabled` (`unattended-upgrades`) | `enabled` (configs present: `20auto-upgrades`, `50unattended-upgrades`) | `enabled` (configs present: `20auto-upgrades`, `50unattended-upgrades`) | `enabled` (configs present: `20auto-upgrades`, `50unattended-upgrades`) |
| **(5) Pending Security Updates** | `0` pending | `0` pending (`apt list --upgradable` count: 1 line header only) | `3` pending (`dracut-install`, `python3-jwt`, `python3-requests`) ⚠️ | `0` security pending (14 general `noble-updates` pending) |
| **(6) Sudo Group Members** | Minimal, explicit admin users | `sudo:x:27:` (empty group) | `sudo:x:27:hd2admin` | `sudo:x:27:hd2admin,deploy` |
| **(7) Listening Surface** | Localhost / VPN bind where possible | Mostly `127.0.0.1` and `100.117.47.27`; public `22, 80, 443, 8443, 14200` | Mostly `127.0.0.1` and `100.106.6.22`; public `22`, `3001` | Public `80, 443, 22, 3102, 8080`; internal `127.0.0.1` (db, api) |

---

## 3. Host-by-Host Live Evidence Citing

### Host 1: Controller (`controller` - Local)

#### (1) Effective SSHD Configuration
Command: `sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication|x11forwarding|maxauthtries'`
```text
maxauthtries 6
permitrootlogin without-password
pubkeyauthentication yes
passwordauthentication no
x11forwarding yes
```

#### (2) Firewall Status
Command: `ufw status verbose`
```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
443/udp                    ALLOW IN    Anywhere                   # 1panel-rule:16a56ecd-a4dd-48f4-b022-c28c6d2a6549
22/tcp                     ALLOW IN    Anywhere                   # 1panel-rule:4429c5a2-ad1e-4b94-8d39-579f2535eb7c
14200/tcp                  ALLOW IN    Anywhere                   # 1panel-rule:6721be5b-fa86-4248-8866-83a64fc98ed7
80/tcp                     ALLOW IN    Anywhere                  
443/tcp                    ALLOW IN    Anywhere                  
8443/tcp                   ALLOW IN    Anywhere                  
8443/udp                   ALLOW IN    Anywhere                  
Anywhere on tailscale0     ALLOW IN    Anywhere                  
10000/udp                  ALLOW IN    Anywhere                  
443/udp (v6)               ALLOW IN    Anywhere (v6)              # 1panel-rule:4c51c280-db54-4d8e-83bf-7a36afadd7bf
22/tcp (v6)                ALLOW IN    Anywhere (v6)              # 1panel-rule:e100a204-07cf-4aa9-a22b-deed5b10ad7d
14200/tcp (v6)             ALLOW IN    Anywhere (v6)              # 1panel-rule:69373ff4-2b3c-4dc6-95f4-825030201273
80/tcp (v6)                ALLOW IN    Anywhere (v6)             
443/tcp (v6)               ALLOW IN    Anywhere (v6)             
8443/tcp (v6)              ALLOW IN    Anywhere (v6)             
8443/udp (v6)              ALLOW IN    Anywhere (v6)             
Anywhere (v6) on tailscale0 ALLOW IN    Anywhere (v6)             
10000/udp (v6)             ALLOW IN    Anywhere (v6)             
```

#### (3) Fail2Ban Status
Command: `fail2ban-client status; fail2ban-client status sshd`
```text
Status
|- Number of jail:	2
`- Jail list:	nginx-http-auth, sshd
Status for the jail: sshd
|- Filter
|  |- Currently failed:	35
|  |- Total failed:	403
|  `- Journal matches:	_SYSTEMD_UNIT=sshd.service + _COMM=sshd
`- Actions
   |- Currently banned:	182
   |- Total banned:	182
   `- Banned IP list:	103.174.102.29 ... [182 IP addresses actively in ban table]
```

#### (4) Automatic Updates
Command: `systemctl is-enabled unattended-upgrades; ls -la /etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/50unattended-upgrades`
```text
enabled
-rw-r--r-- 1 root root   80 Apr 13 22:26 /etc/apt/apt.conf.d/20auto-upgrades
-rw-r--r-- 1 root root 6155 Feb 12  2024 /etc/apt/apt.conf.d/50unattended-upgrades
```

#### (5) Pending Security Updates
Command: `apt list --upgradable 2>/dev/null | wc -l; apt list --upgradable 2>/dev/null | grep -iE 'security|ubuntu.com/security'`
```text
COUNT: 1 (apt header 'Listing...' only)
SECURITY: [0 updates pending]
```

#### (6) Sudo Group Members
Command: `getent group sudo`
```text
sudo:x:27:
```

#### (7) Listening Services (Top 25)
Command: `ss -tulpn | head -25`
```text
Netid State  Recv-Q Send-Q               Local Address:Port  Peer Address:PortProcess                                                                                                                                        
udp   UNCONN 0      0                       127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=1766390,fd=16))                                                                                                 
udp   UNCONN 0      0                    127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=1766390,fd=14))                                                                                                 
udp   UNCONN 0      960                        0.0.0.0:41641      0.0.0.0:*    users:(("tailscaled",pid=320764,fd=20))                                                                                                       
udp   UNCONN 0      0                             [::]:41641         [::]:*    users:(("tailscaled",pid=320764,fd=12))                                                                                                       
tcp   LISTEN 0      128                  100.117.47.27:3080       0.0.0.0:*    users:(("ssh",pid=2590831,fd=4))                                                                                                              
tcp   LISTEN 0      4096                     127.0.0.1:49339      0.0.0.0:*    users:(("php",pid=2420084,fd=15))                                                                                                             
tcp   LISTEN 0      1024                     127.0.0.1:4200       0.0.0.0:*    users:(("openfang",pid=2848561,fd=12))                                                                                                        
tcp   LISTEN 0      4096                    127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=1766390,fd=17))                                                                                                 
tcp   LISTEN 0      4096                     127.0.0.1:33199      0.0.0.0:*    users:(("php",pid=2339662,fd=8))                                                                                                              
tcp   LISTEN 0      4096                     127.0.0.1:41319      0.0.0.0:*    users:(("agy",pid=2694825,fd=12))                                                                                                             
tcp   LISTEN 0      4096                     127.0.0.1:33086      0.0.0.0:*    users:(("docker-proxy",pid=104708,fd=7))                                                                                                      
tcp   LISTEN 0      4096                     127.0.0.1:49453      0.0.0.0:*    users:(("php",pid=2419708,fd=15))                                                                                                             
tcp   LISTEN 0      512                      127.0.0.1:37167      0.0.0.0:*    users:(("bun",pid=3942281,fd=12))                                                                                                             
tcp   LISTEN 0      512                      127.0.0.1:45339      0.0.0.0:*    users:(("bun",pid=2129975,fd=12))                                                                                                             
tcp   LISTEN 0      4096                     127.0.0.1:49429      0.0.0.0:*    users:(("php",pid=2419895,fd=15))                                                                                                             
tcp   LISTEN 0      4096                     127.0.0.1:33515      0.0.0.0:*    users:(("php",pid=2636607,fd=15))                                                                                                             
tcp   LISTEN 0      4096                     127.0.0.1:41677      0.0.0.0:*    users:(("php",pid=2638574,fd=15))                                                                                                             
tcp   LISTEN 0      4096                     127.0.0.1:37467      0.0.0.0:*    users:(("php",pid=2419893,fd=15))                                                                                                             
tcp   LISTEN 0      4096                     127.0.0.1:33659      0.0.0.0:*    users:(("php",pid=2420086,fd=15))                                                                                                             
tcp   LISTEN 0      4096                     127.0.0.1:37749      0.0.0.0:*    users:(("agy",pid=2705260,fd=12))                                                                                                             
tcp   LISTEN 0      4096                     127.0.0.1:49969      0.0.0.0:*    users:(("php",pid=2420247,fd=15))                                                                                                             
tcp   LISTEN 0      4096                     127.0.0.1:54027      0.0.0.0:*    users:(("php",pid=2407286,fd=15))                                                                                                             
tcp   LISTEN 0      4096                     127.0.0.1:42165      0.0.0.0:*    users:(("php",pid=2638576,fd=15))                                                                                                             
tcp   LISTEN 0      4096                     127.0.0.1:33917      0.0.0.0:*    users:(("containerd",pid=2848373,fd=35))                                                                                                      
```

---

### Host 2: Brandon Compute (`brandon-compute` via `ssh brandon-compute`)

#### (1) Effective SSHD Configuration
Command: `sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication|x11forwarding|maxauthtries'`
```text
maxauthtries 4
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
x11forwarding no
```

#### (2) Firewall Status
Command: `sudo ufw status verbose`
```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
Anywhere                   REJECT IN   195.178.110.30             # by Fail2Ban after 5 attempts against sshd
100.106.6.22 5672/tcp on tailscale0 ALLOW IN    100.69.211.43              # BR-CBD-LANE-B-GATE003-AMQP-HOSTINGER
100.106.6.22 5672/tcp on tailscale0 DENY IN     Anywhere                   # BR-CBD-LANE-B-GATE003-AMQP-OTHER-TAILSCALE
Anywhere on tailscale0     ALLOW IN    Anywhere                   # Tailscale mesh
8081/tcp on br-bc3443745afb ALLOW IN    Anywhere                  
8081/tcp                   ALLOW IN    172.17.0.0/16              # HD2Stack-AnythingLLM-to-LFM25
Anywhere (v6) on tailscale0 ALLOW IN    Anywhere (v6)              # Tailscale mesh
8081/tcp (v6) on br-bc3443745afb ALLOW IN    Anywhere (v6)             
```

#### (3) Fail2Ban Status
Command: `sudo fail2ban-client status; sudo fail2ban-client status sshd`
```text
Status
|- Number of jail:	1
`- Jail list:	sshd
Status for the jail: sshd
|- Filter
|  |- Currently failed:	0
|  |- Total failed:	0
|  `- Journal matches:	_SYSTEMD_UNIT=sshd.service + _COMM=sshd
`- Actions
   |- Currently banned:	0
   |- Total banned:	0
   `- Banned IP list:	
```

#### (4) Automatic Updates
Command: `systemctl is-enabled unattended-upgrades; ls -la /etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/50unattended-upgrades`
```text
enabled
-rw-r--r-- 1 root root   80 Sep 11 19:45 /etc/apt/apt.conf.d/20auto-upgrades
-rw-r--r-- 1 root root 6155 Feb 12  2024 /etc/apt/apt.conf.d/50unattended-upgrades
```

#### (5) Pending Security Updates
Command: `echo 'COUNT:'; apt list --upgradable 2>/dev/null | wc -l; echo 'SECURITY:'; apt list --upgradable 2>/dev/null | grep -iE 'security|ubuntu.com/security'`
```text
COUNT:
23
SECURITY:
dracut-install/noble-updates,noble-security 060+5-1ubuntu3.4 amd64 [upgradable from: 060+5-1ubuntu3.3]
python3-jwt/noble-updates,noble-security 2.7.0-1ubuntu0.2 all [upgradable from: 2.7.0-1ubuntu0.1]
python3-requests/noble-updates,noble-security 2.31.0+dfsg-1ubuntu1.2 all [upgradable from: 2.31.0+dfsg-1ubuntu1.1]
```

#### (6) Sudo Group Members
Command: `getent group sudo`
```text
sudo:x:27:hd2admin
```

#### (7) Listening Services (Top 25)
Command: `sudo ss -tulpn | head -25`
```text
Netid State  Recv-Q Send-Q              Local Address:Port  Peer Address:PortProcess                                                 
udp   UNCONN 0      0                      127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=834,fd=16))              
udp   UNCONN 0      0                   127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=834,fd=14))              
udp   UNCONN 0      0                         0.0.0.0:41641      0.0.0.0:*    users:(("tailscaled",pid=3630231,fd=20))               
udp   UNCONN 0      0                            [::]:41641         [::]:*    users:(("tailscaled",pid=3630231,fd=19))               
tcp   LISTEN 0      511                  100.106.6.22:4387       0.0.0.0:*    users:(("node",pid=778338,fd=23))                      
tcp   LISTEN 0      4096                127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=834,fd=15))              
tcp   LISTEN 0      4096                 100.106.6.22:34099      0.0.0.0:*    users:(("tailscaled",pid=3630231,fd=23))               
tcp   LISTEN 0      511                     127.0.0.1:41169      0.0.0.0:*    users:(("node",pid=3640751,fd=22))                     
tcp   LISTEN 0      511                     127.0.0.1:9292       0.0.0.0:*    users:(("node",pid=105831,fd=22))                      
tcp   LISTEN 0      511                     127.0.0.1:9224       0.0.0.0:*    users:(("node",pid=2583048,fd=22))                     
tcp   LISTEN 0      511                     127.0.0.1:9926       0.0.0.0:*    users:(("node",pid=1797394,fd=22))                     
tcp   LISTEN 0      4096                 100.106.6.22:22654      0.0.0.0:*    users:(("1panel-core",pid=4049862,fd=22))              
tcp   LISTEN 0      511                     127.0.0.1:9993       0.0.0.0:*    users:(("node",pid=316246,fd=22))                      
tcp   LISTEN 0      4096                    127.0.0.1:11434      0.0.0.0:*    users:(("docker-proxy",pid=3630909,fd=8))              
tcp   LISTEN 0      4096                   127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=834,fd=17))              
tcp   LISTEN 0      4096                      0.0.0.0:22         0.0.0.0:*    users:(("sshd",pid=1504,fd=3),("systemd",pid=1,fd=162))
tcp   LISTEN 0      4096                    127.0.0.1:33060      0.0.0.0:*    users:(("docker-proxy",pid=2179095,fd=8))              
tcp   LISTEN 0      4096                    127.0.0.1:33739      0.0.0.0:*    users:(("language_server",pid=2895704,fd=9))           
tcp   LISTEN 0      4096                    127.0.0.1:34007      0.0.0.0:*    users:(("language_server",pid=2895704,fd=34))          
tcp   LISTEN 0      4096                      0.0.0.0:3001       0.0.0.0:*    users:(("docker-proxy",pid=1907546,fd=8))              
tcp   LISTEN 0      4096                    127.0.0.1:35723      0.0.0.0:*    users:(("language_server",pid=2895704,fd=11))          
tcp   LISTEN 0      511                     127.0.0.1:3089       0.0.0.0:*    users:(("node",pid=2609363,fd=21))                     
tcp   LISTEN 0      511                     127.0.0.1:3080       0.0.0.0:*    users:(("node",pid=3042312,fd=21))                     
tcp   LISTEN 0      511                     127.0.0.1:4387       0.0.0.0:*    users:(("node",pid=778338,fd=21))                      
```

---

### Host 3: HD2Stack (`hd2stack` via `ssh hd2stack`)

#### (1) Effective SSHD Configuration
Command: `sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication|x11forwarding|maxauthtries'`
```text
maxauthtries 6
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
x11forwarding no
```

#### (2) Firewall Status
Command: `ufw status verbose`
```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    100.64.0.0/10             
22/tcp                     ALLOW IN    Anywhere                  
80/tcp                     ALLOW IN    100.64.0.0/10             
443/tcp                    ALLOW IN    100.64.0.0/10             
14200/tcp                  ALLOW IN    100.64.0.0/10             
31381/tcp                  ALLOW IN    100.64.0.0/10             
80                         ALLOW IN    173.245.48.0/20           
443                        ALLOW IN    173.245.48.0/20           
80                         ALLOW IN    103.21.244.0/22           
443                        ALLOW IN    103.21.244.0/22           
80                         ALLOW IN    103.22.200.0/22           
443                        ALLOW IN    103.22.200.0/22           
80                         ALLOW IN    103.31.4.0/22             
443                        ALLOW IN    103.31.4.0/22             
80                         ALLOW IN    141.101.64.0/18           
443                        ALLOW IN    141.101.64.0/18           
80                         ALLOW IN    108.162.192.0/18          
443                        ALLOW IN    108.162.192.0/18          
80                         ALLOW IN    190.93.240.0/20           
443                        ALLOW IN    190.93.240.0/20           
80                         ALLOW IN    188.114.96.0/20           
443                        ALLOW IN    188.114.96.0/20           
80                         ALLOW IN    197.234.240.0/22          
443                        ALLOW IN    197.234.240.0/22          
80                         ALLOW IN    198.41.128.0/17           
443                        ALLOW IN    198.41.128.0/17           
80                         ALLOW IN    162.158.0.0/15            
443                        ALLOW IN    162.158.0.0/15            
80                         ALLOW IN    104.16.0.0/13             
443                        ALLOW IN    104.16.0.0/13             
80                         ALLOW IN    104.24.0.0/14             
443                        ALLOW IN    104.24.0.0/14             
80                         ALLOW IN    172.64.0.0/13             
443                        ALLOW IN    172.64.0.0/13             
80                         ALLOW IN    131.0.72.0/22             
443                        ALLOW IN    131.0.72.0/22             
10000/udp                  ALLOW IN    Anywhere                  
80/tcp                     ALLOW IN    Anywhere                  
443/tcp                    ALLOW IN    Anywhere                  
22/tcp (v6)                ALLOW IN    Anywhere (v6)             
80                         ALLOW IN    2400:cb00::/32            
443                        ALLOW IN    2400:cb00::/32            
80                         ALLOW IN    2606:4700::/32            
443                        ALLOW IN    2606:4700::/32            
80                         ALLOW IN    2803:f800::/32            
443                        ALLOW IN    2803:f800::/32            
80                         ALLOW IN    2405:b500::/32            
443                        ALLOW IN    2405:b500::/32            
80                         ALLOW IN    2405:8100::/32            
443                        ALLOW IN    2405:8100::/32            
80                         ALLOW IN    2a06:98c0::/29            
443                        ALLOW IN    2a06:98c0::/29            
80                         ALLOW IN    2c0f:f248::/32            
443                        ALLOW IN    2c0f:f248::/32            
10000/udp (v6)             ALLOW IN    Anywhere (v6)             
80/tcp (v6)                ALLOW IN    Anywhere (v6)             
443/tcp (v6)               ALLOW IN    Anywhere (v6)             
```

#### (3) Fail2Ban Status
Command: `fail2ban-client status; fail2ban-client status sshd`
```text
Status
|- Number of jail:	1
`- Jail list:	sshd
Status for the jail: sshd
|- Filter
|  |- Currently failed:	83
|  |- Total failed:	1178
|  `- Journal matches:	_SYSTEMD_UNIT=sshd.service + _COMM=sshd
`- Actions
   |- Currently banned:	0
   |- Total banned:	196
   `- Banned IP list:	
```

#### (4) Automatic Updates
Command: `systemctl is-enabled unattended-upgrades; ls -la /etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/50unattended-upgrades`
```text
enabled
-rw-r--r-- 1 root root   80 Feb 12  2024 /etc/apt/apt.conf.d/20auto-upgrades
-rw-r--r-- 1 root root 6155 Feb 12  2024 /etc/apt/apt.conf.d/50unattended-upgrades
```

#### (5) Pending Security Updates
Command: `echo 'COUNT:'; apt list --upgradable 2>/dev/null | wc -l; echo 'SECURITY:'; apt list --upgradable 2>/dev/null | grep -iE 'security|ubuntu.com/security'`
```text
COUNT:
15
SECURITY:
[0 security updates pending; 14 updates in noble-updates repository]
```

#### (6) Sudo Group Members
Command: `getent group sudo`
```text
sudo:x:27:hd2admin,deploy
```

#### (7) Listening Services (Top 25)
Command: `ss -tulpn | head -25`
```text
Netid State  Recv-Q Send-Q               Local Address:Port  Peer Address:PortProcess                                                                                                                                                                                            
udp   UNCONN 0      0                       127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=1274,fd=16))                                                                                                                                                        
udp   UNCONN 0      0                    127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=1274,fd=14))                                                                                                                                                        
udp   UNCONN 0      0                          0.0.0.0:41641      0.0.0.0:*    users:(("tailscaled",pid=1334,fd=20))                                                                                                                                                             
udp   UNCONN 0      0                             [::]:41641         [::]:*    users:(("tailscaled",pid=1334,fd=19))                                                                                                                                                             
tcp   LISTEN 0      511                        0.0.0.0:80         0.0.0.0:*    users:(("nginx",pid=269092,fd=14),("nginx",pid=269091,fd=14),("nginx",pid=269090,fd=14),("nginx",pid=269089,fd=14),("nginx",pid=269088,fd=14),("nginx",pid=269086,fd=14),("nginx",pid=1440,fd=14))
tcp   LISTEN 0      4096                       0.0.0.0:22         0.0.0.0:*    users:(("sshd",pid=1344,fd=3),("systemd",pid=1,fd=96))                                                                                                                                            
tcp   LISTEN 0      5                        127.0.0.1:7820       0.0.0.0:*    users:(("python3",pid=1304,fd=3))                                                                                                                                                                 
tcp   LISTEN 0      5                        127.0.0.1:7825       0.0.0.0:*    users:(("python3",pid=1339,fd=3))                                                                                                                                                                 
tcp   LISTEN 0      5                        127.0.0.1:7865       0.0.0.0:*    users:(("python3",pid=1337,fd=3))                                                                                                                                                                 
tcp   LISTEN 0      5                        127.0.0.1:7878       0.0.0.0:*    users:(("python3",pid=1338,fd=3))                                                                                                                                                                 
tcp   LISTEN 0      511                        0.0.0.0:443        0.0.0.0:*    users:(("nginx",pid=269092,fd=16),("nginx",pid=269091,fd=16),("nginx",pid=269090,fd=16),("nginx",pid=269089,fd=16),("nginx",pid=269088,fd=16),("nginx",pid=269086,fd=16),("nginx",pid=1440,fd=16))
tcp   LISTEN 0      5                        127.0.0.1:7800       0.0.0.0:*    users:(("python3",pid=1336,fd=3))                                                                                                                                                                 
tcp   LISTEN 0      4096                     127.0.0.1:21434      0.0.0.0:*    users:(("docker-proxy",pid=3255,fd=8))                                                                                                                                                            
tcp   LISTEN 0      511                        0.0.0.0:3102       0.0.0.0:*    users:(("next-server (v1",pid=1295,fd=18))                                                                                                                                                        
tcp   LISTEN 0      4096                     127.0.0.1:13306      0.0.0.0:*    users:(("docker-proxy",pid=3282,fd=8))                                                                                                                                                            
tcp   LISTEN 0      4096                  100.71.95.76:36471      0.0.0.0:*    users:(("tailscaled",pid=1334,fd=22))                                                                                                                                                             
tcp   LISTEN 0      4096                    127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=1274,fd=17))                                                                                                                                                        
tcp   LISTEN 0      4096                     127.0.0.1:5678       0.0.0.0:*    users:(("docker-proxy",pid=3157,fd=8))                                                                                                                                                            
tcp   LISTEN 0      4096                 127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=1274,fd=15))                                                                                                                                                        
tcp   LISTEN 0      4096                     127.0.0.1:3000       0.0.0.0:*    users:(("docker-proxy",pid=3200,fd=8))                                                                                                                                                            
tcp   LISTEN 0      4096                     127.0.0.1:3001       0.0.0.0:*    users:(("docker-proxy",pid=3127,fd=8))                                                                                                                                                            
tcp   LISTEN 0      4096                     127.0.0.1:3010       0.0.0.0:*    users:(("docker-proxy",pid=3335,fd=8))                                                                                                                                                            
tcp   LISTEN 0      4096                       0.0.0.0:8080       0.0.0.0:*    users:(("docker-proxy",pid=3064,fd=8))                                                                                                                                                            
tcp   LISTEN 0      128                   100.71.95.76:8092       0.0.0.0:*    users:(("python3",pid=2359,fd=3))                                                                                                                                                                 
```

---

## 4. Prioritized List of RECOMMENDED Changes (NOT APPLIED)

The following changes are strictly recommendations for operator review. None of these changes have been applied.

### Priority 1: High Risk (Exposure Reduction)

1. **[NOT APPLIED] Remove `22/tcp ALLOW IN Anywhere` from HD2Stack UFW firewall.**  
   *Risk Rationale:* HD2Stack is a live production environment with 1,178 failed SSH authentication attempts logged; having port 22 exposed globally defeats the intended Tailscale (`100.64.0.0/10`) access rule and exposes the SSH daemon to constant credential stuffing and zero-day vulnerabilities.

2. **[NOT APPLIED] Apply pending security updates on Brandon Compute (`dracut-install`, `python3-jwt`, `python3-requests`).**  
   *Risk Rationale:* Unpatched security updates in core Python communication and authentication packages (`python3-jwt` and `python3-requests`) expose local applications to known token forgery and HTTP handling vulnerabilities.

3. **[NOT APPLIED] Restrict public SSH on Controller to Tailscale / VPN management interfaces.**  
   *Risk Rationale:* Controller is the primary orchestration node with 182 active fail2ban IP blocks; opening port 22 to the public internet attracts persistent brute-force attacks and increases exposure risk.

### Priority 2: Medium Risk (Daemon Hardening)

4. **[NOT APPLIED] Disable SSH X11 Forwarding on Controller (`X11Forwarding no`).**  
   *Risk Rationale:* Controller is a headless server with no graphical display requirement; leaving X11 forwarding enabled exposes users to potential display snooping and credential theft if an attacker accesses an X11 client socket.

5. **[NOT APPLIED] Reduce `MaxAuthTries` from `6` to `3` or `4` on Controller and HD2Stack.**  
   *Risk Rationale:* A high `MaxAuthTries` value allows attackers more trial attempts per SSH connection before disconnection, reducing the efficiency of fail2ban threshold triggers.

6. **[NOT APPLIED] Enforce Tailscale or localhost binding for public Docker / Node ports on Brandon Compute (e.g. port `3001`).**  
   *Risk Rationale:* Port `3001` is bound to `0.0.0.0:3001` via `docker-proxy`, potentially bypassing UFW depending on iptables configuration and allowing unauthenticated network access.

### Priority 3: Low Risk / Defense in Depth

7. **[NOT APPLIED] Enable `fail2ban` recidive / increment jail on HD2Stack.**  
   *Risk Rationale:* HD2Stack currently has 0 active bans despite 196 historical bans because standard ban duration has expired, allowing repeat offending IPs to resume probing after the cool-down window.

8. **[NOT APPLIED] Migrate Controller SSH authentication from `PermitRootLogin without-password` to dedicated non-root admin accounts (`PermitRootLogin no`).**  
   *Risk Rationale:* Direct root login, even with keys, provides no per-operator audit trail and allows total system takeover if a single SSH key is compromised.

---

## 5. Audit Closeout & Verification

- **Target Boundary**: Read-only commands only; zero modifications made across `controller`, `brandon-compute`, and `hd2stack`.
- **Write Boundary**: Strictly limited to `/root/agent-work/firstmate/docs/audits-20260928/HARDEN.md`.
- **Operator Review**: All findings documented verbatim from live system commands.
