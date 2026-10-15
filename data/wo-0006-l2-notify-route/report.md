# WO-0006 L2 — ticket 0029: silent notify failure

Worktree `/tmp/wt-wo0006-l2`, branch `wo-0006/l2`. Base `HEAD` at lane start: `2da3696d`.

Target file: `bin/fm-hetz-send.sh`. Test suites: `tests/fm-hetz-send.test.sh` (pre-existing) and
`tests/fm-hetz-send-route.test.sh` (new, this lane).

---

## 1. Headline: one of the two briefed defects did not reproduce

The brief describes `bin/fm-hetz-send.sh` as **swallowing** its error so delivery reports success
while nothing is notified. It does not. At lane start the script already captured the real ssh return
code and propagated it. Verbatim, before any change:

```
$ FM_ROOT_OVERRIDE=/tmp/wt-wo0006-l2 FM_HETZ_LOG=/tmp/wo0006l2-exp/b.log \
  FM_HETZ_HOST=no-such-host.invalid FM_HETZ_INBOUND=/tmp/wo0006l2-exp/b-inbox \
  timeout 30 bash bin/fm-hetz-send.sh "WO-0006-L2 experiment B probe"
ssh: Could not resolve hostname no-such-host.invalid: Name or service not known
not sent: ssh rc=255 to no-such-host.invalid (inbound /tmp/wo0006l2-exp/b-inbox)
EXIT_B=255
```

```
$ PATH="$STUB:$PATH" ... FM_HETZ_INBOUND=/tmp/wo0006l2-exp/absent-inbox \
  bash bin/fm-hetz-send.sh "WO-0006-L2 experiment A probe"
/tmp/wo0006l2-exp/stubA/ssh: line 5: /tmp/wo0006l2-exp/absent-inbox/msg-214725.msg: No such file or directory
not sent: ssh rc=1 to temp-target-not-a-real-host (inbound /tmp/wo0006l2-exp/absent-inbox)
EXIT_A=1
```

The file's own header documents this, and `tests/fm-hetz-send.test.sh` already asserted it. So the
"swallowing" half of defect 1 is **not present in this repository** and I did not manufacture it.

### There is no registry to resolve against

The brief's defect 1 says the hardcoded route "does not resolve against the registry id". There is no
host or route registry anywhere in this repository:

```
$ for f in data/projects.md data/secondmates.md data/backlog.md config/crew-harness; do \
    printf '%-28s ' "$f"; [ -e "$f" ] && echo PRESENT || echo ABSENT; done
data/projects.md             ABSENT
data/secondmates.md          ABSENT
data/backlog.md              ABSENT
config/crew-harness          ABSENT

$ grep -rln 'FM_HOSTS\|host-registry\|route-registry\|hosts.tsv' bin/ | head
(no output)
```

The only registry in the tree is `data/secondmates.md` (secondmate homes, not hosts). The notify
mechanism described by the guarded contract in the brief — herdr registered-identity notification,
`agent prompt`, busy/blocked deferral — is **specified but not implemented here**. It is described in
`/home/hd2admin/agent-work/firstmate/data/direct-notify-20261015/task.md` as work to be done
("must resolve registered identity live, never hardcode stale panes"), and no implementation of it
exists in this checkout. That lane belongs to a different worktree; I did not touch it.

**So defect 1 was real only in its first clause**: the route *was* a bare hardcoded literal with no
registry to check it against. That is what I fixed, and the fix makes an unresolvable route fail
loudly.

---

## 2. Defect 2: the default remote inbox

`FM_HETZ_INBOUND` defaults to `/tmp/hetzner-inbound`, which does not exist here:

```
$ ls -la /tmp/hetzner-compute /tmp/hetzner-inbound
ls: cannot access '/tmp/hetzner-compute': No such file or directory
ls: cannot access '/tmp/hetzner-inbound': No such file or directory
```

But that path is a **remote** path; its absence on this host proves nothing about the far side. The
real default target is not even reachable — a read-only probe that sends nothing:

```
$ ssh -o BatchMode=yes -o ConnectTimeout=10 hd2admin@brandon-compute \
    'test -d /tmp/hetzner-inbound && echo "INBOX_PRESENT" || echo "INBOX_ABSENT"; id -un; hostname'
hd2admin@brandon-compute: Permission denied (publickey).
EXIT_C=255
```

So the far-side inbox's existence is **unobservable from this host**, and the defect that actually
ships is that a missing inbox surfaced only as an opaque `ssh rc=1`, indistinguishable from a refused
key, a full disk or a wrong path.

---

## 3. The silent notify failure that DID reproduce

The remote file name is derived from a **second-resolution** timestamp (`date -u +%H%M%S`) plus
nothing else. Two sends inside one second therefore collide on one name. Verbatim, before the fix:

```
$ for m in "WO-0006-L2 first message" "WO-0006-L2 second message"; do
    ... bash bin/fm-hetz-send.sh "$m"; done
sent at 214734
sent at 214734
--- remote inbox after TWO successful sends ---
total 12
drwxr-xr-x 2 hd2admin hd2admin 4096 Oct 15 22:47 .
drwxr-xr-x 5 hd2admin hd2admin 4096 Oct 15 22:47 ..
-rw-r--r-- 1 hd2admin hd2admin   26 Oct 15 22:47 msg-214734.msg
--- file count ---
1
--- surviving content ---
[/tmp/wo0006l2-exp/d-inbox/msg-214734.msg]
WO-0006-L2 second message
```

**Both sends printed `sent` and exited 0. One message was destroyed without a word.** That is the
silent notify failure: the caller records a delivered request that was never delivered. It is a
stronger and better-evidenced defect than the one briefed, so I fixed it too.

---

## 4. RED

`tests/fm-hetz-send-route.test.sh`, run against the **unmodified** script (`HEAD:bin/fm-hetz-send.sh`,
extracted to a scratch prefix so the worktree copy was untouched). Verbatim, each test in isolation:

```
$ git show HEAD:bin/fm-hetz-send.sh > /tmp/wo0006l2-exp/prefix/bin/fm-hetz-send.sh   # unmodified copy
$ for t in <each test>; do bash .one-red.sh; done

########## RED (against HEAD:bin/fm-hetz-send.sh) : test_unregistered_route_is_refused_before_any_transport ##########
not ok - the refusal does not name the route id that failed to resolve (missing: 'hetz-nowhere')
--- output ---
/tmp/fm-hetz-send-route.HVlJVy/unreg/fakebin/ssh: line 12: /tmp/fm-hetz-send-route.HVlJVy/wo0006l2-present-inbox/msg-214928.msg: No such file or directory
not sent: ssh rc=1 to temp-b.test (inbound /tmp/fm-hetz-send-route.HVlJVy/wo0006l2-present-inbox)
RED_EXIT=1

########## RED (against HEAD:bin/fm-hetz-send.sh) : test_absent_registry_is_refused_for_an_explicit_route ##########
not ok - the refusal does not name the registry that could not be read (missing: 'does-not-exist.tsv')
--- output ---
/tmp/fm-hetz-send-route.OLAn2Y/noreg/fakebin/ssh: line 12: /tmp/hetzner-inbound/msg-214928.msg: No such file or directory
not sent: ssh rc=1 to temp-target.test (inbound /tmp/hetzner-inbound)
RED_EXIT=1

########## RED (against HEAD:bin/fm-hetz-send.sh) : test_registered_route_resolves_to_its_own_host_and_inbox ##########
not ok - a registered, resolvable route must succeed: expected exit 0, got 1
RED_EXIT=1

########## RED (against HEAD:bin/fm-hetz-send.sh) : test_absent_inbox_is_named_and_fails_loudly ##########
not ok - the failure does not diagnose the absent inbox as missing (missing: 'inbox is missing')
--- output ---
/tmp/fm-hetz-send-route.5U8lTm/noinbox/fakebin/ssh: line 12: /tmp/fm-hetz-send-route.5U8lTm/wo0006l2-absent-inbox/msg-214928.msg: No such file or directory
not sent: ssh rc=1 to temp-target.test (inbound /tmp/fm-hetz-send-route.5U8lTm/wo0006l2-absent-inbox)
RED_EXIT=1

########## RED (against HEAD:bin/fm-hetz-send.sh) : test_two_sends_in_one_second_both_survive ##########
not ok - two successful sends left 1 message(s) in the inbox, so one was silently destroyed
--- inbox ---
total 12
drwxr-xr-x 2 hd2admin hd2admin 4096 Oct 15 22:49 .
drwxr-xr-x 4 hd2admin hd2admin 4096 Oct 15 22:49 ..
-rw-r--r-- 1 hd2admin hd2admin   34 Oct 15 22:49 msg-214928.msg
--- content ---
WO-0006-L2 rapid message number 2
RED_EXIT=1

########## RED (against HEAD:bin/fm-hetz-send.sh) : test_existing_message_is_never_silently_overwritten ##########
not ok - a send reported success while the remote write refused to overwrite
--- output ---
sent at 214928
RED_EXIT=1
```

All six are red before the change. Note on the absent-inbox test: its first draft passed against the
unfixed script, because the exit code was already non-zero. I tightened it to require the failure to
**diagnose** the inbox as missing, which is the contract the brief actually asks for, and that is the
version shown above.

---

## 5. The fix (`bin/fm-hetz-send.sh`)

Purely additive. Three contracts added, no existing guard touched:

1. **Route resolution.** `FM_HETZ_ROUTE_REGISTRY` (default `$FM_HOME/data/hetz-routes.tsv`) holds
   `<id> <host> [<inbox>]` lines. `--route <id>` and `FM_HETZ_ROUTE_ID` select an id. When a registry
   exists it is the **only** authority: `FM_HETZ_HOST`/`FM_HETZ_INBOUND` are overridden by the
   registered values, because a registered route that silently sends somewhere unregistered is the
   defect being removed. An unregistered id, a registry that cannot be read, and a route registered
   without a host all exit **3** *before any transport is attempted*. With no registry at all, the
   historical literal route is kept, so no existing caller changes behaviour.

2. **Inbox pre-flight.** A probe prints a sentinel on stdout and exits 0 whether or not the inbox
   exists, so a missing inbox can never be confused with a broken transport. `rc != 0` keeps the
   original transport message and propagates the real ssh code; `rc == 0` with no sentinel is a named
   inbox failure, exit **4**. This helper never creates the inbox — a destination it invents is not a
   destination any consumer watches.

3. **Message identity.** The remote name is `msg-<HHMMSS>-<pid>.msg` and the remote write runs under
   `set -C` (noclobber), so a collision is a loud failure instead of a silent overwrite.
   `FM_HETZ_MSG_NAME` pins the name so the collision is reproducible in a test.

### GREEN

```
########## PRE-EXISTING SUITE: fm-hetz-send ##########
ok - a successful transfer reports sent
ok - a failed transfer does not report sent
ok - a failed transfer reports the real ssh return code
ok - an empty message is refused as a usage error
EXIT_OLD=0

########## NEW SUITE: fm-hetz-send-route ##########
ok - an unregistered route is refused before any transport is attempted
ok - an absent registry is refused instead of silently falling back
ok - a registered route resolves to its own host and inbox
ok - an absent remote inbox is named and fails loudly
ok - two sends within one second both survive in the remote inbox
ok - an existing remote message is never silently overwritten
EXIT_NEW=0
```

`tests/fm-hetz-send.test.sh` needed its ssh stub made faithful: it previously ignored the remote
command and forced an exit code, so it could not see remote semantics at all. All four of its
assertions are unchanged. Its `run_send` now also exports a temp host and an existing temp inbox.

Shellcheck clean:

```
$ shellcheck -x bin/fm-hetz-send.sh tests/fm-hetz-send-route.test.sh tests/fm-hetz-send.test.sh && echo "SHELLCHECK_CLEAN"
SHELLCHECK_CLEAN
```

### Re-running the original reproductions against the fixed script

```
########## POSTFLIGHT A: absent remote inbox (same stub as the pre-fix repro) ##########
error: remote inbox is missing or not a directory: /tmp/wo0006l2-exp/absent-inbox on temp-target-not-a-real-host (no message written)
EXIT_A=4

########## POSTFLIGHT B: unroutable route (real ssh, temp target) ##########
not sent: ssh rc=255 to no-such-host.invalid (inbound /tmp/wo0006l2-exp/b-inbox)
EXIT_B=255

########## POSTFLIGHT D: two sends in one second (the silent-loss repro) ##########
sent at 214902 (msg-214902-235150.msg)
sent at 214902 (msg-214902-235175.msg)
--- inbox after TWO sends ---
total 16
drwxr-xr-x 2 hd2admin hd2admin 4096 Oct 15 22:49 .
drwxr-xr-x 6 hd2admin hd2admin 4096 Oct 15 22:49 ..
-rw-r--r-- 1 hd2admin hd2admin   25 Oct 15 22:49 msg-214902-235150.msg
-rw-r--r-- 1 hd2admin hd2admin   26 Oct 15 22:49 msg-214902-235175.msg
--- content ---
WO-0006-L2 first message
WO-0006-L2 second message
```

---

## 6. The guarded notification contract survived

**The four guards the brief names do not exist in this file, before or after.** Counted against
`HEAD:bin/fm-hetz-send.sh` and the fixed file:

```
$ for pat in 'send-keys' 'tmux' 'herdr' 'C-c' 'x03' 'ESC' '033' 'sha256' 'md5' 'dedup' 'pending' 'queue'; do
    b=$(git show HEAD:bin/fm-hetz-send.sh | grep -c -i -- "$pat" || true)
    a=$(grep -c -i -- "$pat" bin/fm-hetz-send.sh || true)
    printf '%-12s before=%s after=%s\n' "$pat" "$b" "$a"
  done
send-keys    before=0 after=0
tmux         before=0 after=0
herdr        before=0 after=0
C-c          before=0 after=0
x03          before=0 after=0
ESC          before=0 after=0
033          before=0 after=0
sha256       before=0 after=0
md5          before=0 after=0
dedup        before=0 after=0
pending      before=0 after=0
queue        before=1 after=1
```

The single `queue` hit is the word "queue" in the header prose. So: this file never sends a
keystroke, never touches a pane, never hashes a message and never keeps a queue — which also means
there was nothing here to weaken, and the four guards remain implemented wherever they actually live
(the registered-identity notification work in the direct-notify lane, which I did not touch).

**The guards this file does own are all still present.** Every removed line is a line I replaced, not
one I dropped:

```
$ git diff --stat
 bin/fm-hetz-send.sh        | 155 ++++++++++++++++++++++++++++++++++++++++++---
 tests/fm-hetz-send.test.sh |  28 ++++++--
 2 files changed, 167 insertions(+), 16 deletions(-)

$ git diff -U0 bin/fm-hetz-send.sh | grep -E '^-[^-]'
-#   fm-hetz-send.sh <message text>
-  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
-case "${1-}" in
-  -h|--help|help) usage ;;
-esac
-ssh -o BatchMode=yes -o ConnectTimeout=10 "$HOST" \
-  "cat > '$INBOUND'/msg-${TS2}.msg" <<<"$MESSAGE"
-  printf 'not sent: ssh rc=%s to %s (inbound %s)\n' "$ssh_rc" "$HOST" "$INBOUND" >&2
-printf 'sent at %s\n' "$TS2"
```

Preserved and still verified in the fixed file: the real ssh return code decides both the printed
line and the exit status (`ssh_rc=$?` … `exit "$ssh_rc"`, line 208/214); intent is still logged
**before** the transfer; `die()` and the exit-2 usage path are untouched; and the pre-existing suite
that asserts exactly those properties still passes.

Intent-before-send, empirically, after a **failed** transfer:

```
$ FM_HETZ_LOG=/tmp/wo0006l2-exp/intent.log FM_HETZ_HOST=no-such-host.invalid ... \
  bash bin/fm-hetz-send.sh "WO-0006-L2 intent-preservation probe"
not sent: ssh rc=255 to no-such-host.invalid (inbound /tmp/wo0006l2-exp/i-inbox)
EXIT=255
--- outbound intent log after the FAILED send ---
[2026-10-15T21:49:10Z] FROM CONTROLLER: WO-0006-L2 intent-preservation probe
```

Usage rendering is unchanged in shape:

```
$ bash bin/fm-hetz-send.sh --help | head -3 ; echo "HELP_EXIT=${PIPESTATUS[0]}"
fm-hetz-send.sh - send one controller message to the Hetz inbound queue and
report whether it actually arrived.

Usage:
  fm-hetz-send.sh [--route <route-id>] <message text>
  fm-hetz-send.sh --help
HELP_EXIT=2

$ bash bin/fm-hetz-send.sh "" >/dev/null 2>&1; echo "EMPTY_EXIT=$?"
EMPTY_EXIT=2
```

---

## 7. Test safety

No real recipient was notified. Every target in both suites is a temp target, and no real host or
recipient literal appears in either file:

```
$ grep -ohE '(FM_HETZ_HOST=)[^ ]+' tests/fm-hetz-send.test.sh tests/fm-hetz-send-route.test.sh | sort -u
FM_HETZ_HOST=temp-b.test
FM_HETZ_HOST=temp-target.test
FM_HETZ_HOST=temp-wrong.test

$ grep -nE 'brandon-compute|hetzner-inbound|hd2admin@' tests/fm-hetz-send.test.sh tests/fm-hetz-send-route.test.sh || echo NONE
NONE (no real host or recipient is referenced by either suite)
```

The only contact with the real default target was the read-only probe in §2, which sent no message.

---

## 8. Verdict

**Silent success is now impossible in this path.** Every outcome is one of: delivered (exit 0, named
remote message), transport failure (real ssh code propagated), unresolvable route (exit 3, before any
transport), missing remote inbox (exit 4, named), refused overwrite (real ssh code propagated,
existing message intact), or local/usage error (1/2). No branch prints `sent at` without the message
being in the remote inbox, and no two sends can collide into one silently discarded message.

**Carried to the next lane:** the hardcoded default route still stands for a home that keeps no
registry at all, because nothing in this repository owns such a registry. Making the literal route
itself require a registered id is a one-line change to `resolve_route` once an owning registry
exists; until then, failing every caller with no registry would break working sends, which is the
opposite of the intent of this ticket.