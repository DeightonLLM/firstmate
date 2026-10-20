#!/usr/bin/env bash
# Quota dashboard: bars + pace metrics per provider window
quota-axi --json 2>/dev/null | python3 -c "
import json,sys,datetime
d=json.load(sys.stdin)
print('QUOTA DASHBOARD  generated', d.get('generatedAt','')[:16], 'UTC')
print('='*72)
now=datetime.datetime.utcnow()
for p in d.get('providers',[]):
    ws=p.get('windows',[])
    st=p.get('state',{}).get('status','?')
    if not ws:
        print(f\"{p['provider'].upper():10} — {st}\"); continue
    for w in ws:
        pct=w.get('percentRemaining'); lbl=w.get('label',w.get('id','?'))
        filled=int(round((pct or 0)/100*34)); bar='█'*filled+'░'*(34-filled)
        reset=w.get('resetsAt','')
        eta=''
        if reset:
            try:
                r=datetime.datetime.fromisoformat(reset.replace('Z','+00:00')).replace(tzinfo=None)
                m=int((r-now).total_seconds()//60); eta=f' resets in {m//60}h{m%60:02d}m'
            except Exception: pass
        pace=w.get('pace',{}); ps=pace.get('status','')
        extra=f\" burn x{pace.get('burnMultiple',0):.2f} reserve +{pace.get('reservePercentPoints',0):.1f}pt\" if ps=='behind' else (' pace ok' if ps=='ok' or ps=='ahead' else '')
        warn=' ⚠ LOW' if (pct or 100)<25 else ''
        print(f\"{p['provider'].upper():10} {lbl:8} {bar} {pct:3}%{eta}{warn}\")
        if extra: print(f\"{'':10} {'':8} {extra}\")
print('='*72)
"
