# RED/GREEN Evidence

## RED: Non-compliant items must fail (exit 1)

Command:
```bash
CHECKER="/root/agent-work/deightonllm-firstmate/bin/fm-todo-prefix-check.sh"
printf '[mcode·M31F think:h @Cont] do the thing\n' | bash "$CHECKER" && echo "FAIL" || echo "PASS: exit $?"
printf '[mcode·M31F @Cont] do the thing\n' | bash "$CHECKER" && echo "FAIL" || echo "PASS: exit $?"
printf '[mcode·M31F q @Cont] do the thing\n' | bash "$CHECKER" && echo "FAIL" || echo "PASS: exit $?"
printf '[bogus·M31F h @Cont] do the thing\n' | bash "$CHECKER" && echo "FAIL" || echo "PASS: exit $?"
printf '[codex·Unknown h @Cont] do the thing\n' | bash "$CHECKER" && echo "FAIL" || echo "PASS: exit $?"
```

Results: ALL non-compliant items cause exit 1 (NON-COMPLIANT line printed to stderr).

## GREEN: Compliant items must pass (exit 0)

Command:
```bash
CHECKER="/root/agent-work/deightonllm-firstmate/bin/fm-todo-prefix-check.sh"
# Valid harness·ModelAbbrev combinations
printf '[mcode·M31F h @Cont] do the thing\n' | bash "$CHECKER" && echo "PASS" || echo "FAIL"
printf '[agy·G38F m @HD2] do the thing\n' | bash "$CHECKER" && echo "PASS" || echo "FAIL"
printf '[pi·M27 l @Cont] do the thing\n' | bash "$CHECKER" && echo "PASS" || echo "FAIL"
printf '[pi-signed·M31 xh @Hetz] do the thing\n' | bash "$CHECKER" && echo "PASS" || echo "FAIL"
printf '[codex·Luna6 h @Cont] do the thing\n' | bash "$CHECKER" && echo "PASS" || echo "FAIL"
printf '[zai·GLM53 x @HD2] do the thing\n' | bash "$CHECKER" && echo "PASS" || echo "FAIL"
printf '[glm·G31P h @Hetz] do the thing\n' | bash "$CHECKER" && echo "PASS" || echo "FAIL"
printf '[opencode·M31F l @Cont] do the thing\n' | bash "$CHECKER" && echo "PASS" || echo "FAIL"
# All 5 effort codes
for effort in h m l xh x; do
  printf '[mcode·M31F %s @Cont] do the thing\n' "$effort" | bash "$CHECKER" && echo "PASS: effort=$effort" || echo "FAIL: effort=$effort"
done
# All 3 hosts
for host in Cont HD2 Hetz; do
  printf '[mcode·M31F h @%s] do the thing\n' "$host" | bash "$CHECKER" && echo "PASS: host=@$host" || echo "FAIL: host=@$host"
done
# Empty list
printf '' | bash "$CHECKER" && echo "PASS: empty tolerated" || echo "FAIL"
# Comment-only
printf '# comment\n' | bash "$CHECKER" && echo "PASS: comment-only tolerated" || echo "FAIL"
```

Results: ALL compliant items cause exit 0.

## Wiring Evidence

The check is wired into fm-spawn.sh after the brief existence check (line 935+):
```
[ -f "$BRIEF" ] || { echo "error: no brief at $BRIEF" >&2; exit 1; }
# Mechanical To-Do prefix format enforcement...
if "$FM_ROOT/bin/fm-todo-prefix-check.sh" "$BRIEF" 2>/dev/null; then :; else
  rc=$?
  if [ "$rc" -eq 1 ]; then
    echo "error: brief $BRIEF contains non-compliant To-Do prefix format; refusing spawn" >&2
    exit 1
  fi
fi
```

Wiring verification test:
- Brief with format text only (no actual items): PASS (exit 0) ✓
- Brief with compliant items: PASS (exit 0) ✓
- Brief with non-compliant think:h item: REJECTED (exit 1) ✓
