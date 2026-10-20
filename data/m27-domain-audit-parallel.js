// One scout per domain: measured state only. No drafting, no fixes.
const domains = [
  {
    key: "m2.7h-brandon-audit-core-distro",
    host: "core-distro.com",
    extra: "staging.core-distro.com and agents.elevatesci.com",
    facts: "Next.js site. Source lives on host 100.69.211.43 at /root/core distro brNDON EDIT/Core Distro Web, deployed as standalone build into /opt/core-distro-staging/releases/ with a current symlink and systemd unit core-distro-staging.service on port 3113. Chatbot is the Hetzner AnythingLLM at 100.106.6.22:3001, UI at agents.elevatesci.com. KNOWN OPEN: the widget stream-chat path returns 'Invalid session ID' 404 both through staging and directly against the upstream instance, so no real assistant reply has ever been observed. Widget was repointed off llm.hd2.ai to https://staging.core-distro.com/llm/chat/api and rebuilt and deployed; sponsor branding now reads 'Powered by Core Distro' linking to core-distro.com. Nginx on that host has a /api/embed/ proxy and a rewrite restoring the embed path segment."
  },
  {
    key: "m2.7h-brandon-audit-hd2-ai",
    host: "hd2.ai",
    extra: "llm.hd2.ai",
    facts: "WordPress site per HD2Stack's inventory, hosted on KVM1 srv797124. Chatbot is a local AnythingLLM on HD2 at 127.0.0.1:3010 served via llm.hd2.ai. Ticket 0037 (hd2.ai chat TTFT) is CLOSED per report data/hd2-takeover/report-q5-hd2ai-ttft.md with bottleneck identified as nginx buffering and AnythingLLM RAG reranking 2.2s-8.3s, model speed ~290 tok/s. llm.hd2.ai is an INTERNAL endpoint and must never serve client traffic."
  },
  {
    key: "m2.7h-brandon-audit-elevatesci",
    host: "elevatesci.com",
    extra: "www.elevatesci.com and agents.elevatesci.com",
    facts: "Client site. Ticket 0033 (sweep aminolifesciences) CLOSED: replaced 314 occurrences across 42 files with elevatesci-vps / ElevateSci. agents.elevatesci.com is the dedicated UI frontend for the Hetzner AnythingLLM at 100.106.6.22:3001. WordPress site source per HD2Stack lives in an HD2-owned directory; do not assume you can reach it."
  },
  {
    key: "m2.7h-brandon-audit-whoosh",
    host: "whooshperformance.com",
    extra: "www, data, lc",
    facts: "Nothing started. Measured by the parent: apex serves a Hostinger PARKED DOMAIN page (title 'Parked Domain name on Hostinger DNS system'), apex and www are byte-identical (md5 f474cd31) meaning no canonical redirect, and data.whooshperformance.com and lc.whooshperformance.com do not resolve at all (curl 000, not a 502). A full PRD v1.0 already exists at data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md and is authoritative - read it, do not contradict it. Read-only measurement only; nothing may be started."
  }
];

const results = await runs.all(domains.map((d) => ({
  key: d.key,
  label: `Audit ${d.host}`,
  agent: "worker",
  model: "minimax/MiniMax-M2.7-highspeed:high",
  cwd: "/home/hd2admin/kun-agent-workspace",
  output: `${d.key}.md`,
  task: `READ-ONLY MEASUREMENT AUDIT. Change nothing. No edits, no deploys, no builds, no DNS changes, no process restarts.\n\nDOMAIN: ${d.host} (also check ${d.extra})\n\nCONTEXT ALREADY ESTABLISHED - do not re-derive, build on it:\n${d.facts}\n\nMEASURE AND RECORD, with exact commands, exit codes and raw output for each:\n1. Reachability and behaviour from here: HTTP status for https and http on each hostname, whether it redirects and where to, certificate subject and expiry, and whether www/apex are canonicalised or serve identical bytes (compare md5 of the bodies).\n2. Content state: page title, approximate page count if discoverable, whether it looks like a finished product or a placeholder, and whether it carries the correct brand on every hostname you checked.\n3. Response headers that matter for the PRD: HSTS, X-Content-Type-Options, X-Frame-Options or CSP frame-ancestors, Referrer-Policy, and server. Record absences explicitly rather than omitting them.\n4. Performance signals available without installing anything: time to first byte and total time, response size, and whether assets are cacheable. Use curl -w only.\n5. SEO surface: robots.txt reachability and contents, sitemap.xml reachability, whether the canonical tag and title look sane on the root page, and whether meta description exists. Record which are MISSING.\n6. For any subdomain or service hostname in scope, record its DNS resolution result and what actually answers. Record a non-resolving host as NOT RESOLVING, never as a 502.\n7. Any evidence of an internal endpoint leaking into a client-facing page: grep the served HTML for llm.hd2.ai, 127.0.0.1, internal IPs, and other domains. This matters because a client site must never point at an internal instance.\n\nThen produce an honest status table with one row per hostname: reachable, canonical correct, HTTPS valid, security headers present, SEO surface complete, brand correct, and a one-line note on what is missing.\n\nDELIVER to /home/hd2admin/kun-agent-workspace/data/${d.key}.md with every command and raw output preserved, the status table, and a VERDICT line per hostname. Be brutally honest: if something is broken, say it is broken and paste the evidence. If you cannot reach something, say NOT REACHABLE and why. Do not infer state you did not measure, and do not report an assumption as a finding. Do not contact the Captain; the parent reports.`
})));

return results.map((r, i) => ({ lane: domains[i].host, ok: r.ok, runId: r.runId, outputReference: r.outputReference, output: r.output }));