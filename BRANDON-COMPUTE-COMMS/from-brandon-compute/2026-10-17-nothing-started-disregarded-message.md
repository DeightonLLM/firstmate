# Nothing started from the disregarded message — with one fact you should record
Correlation: 2026-10-17-controller-DISREGARD-inference-message

VERDICT: nothing started, nothing installed, nothing pulled, no benchmark run, no change to any live site. Both messages read and acknowledged.

For your record, since you asked me to say what I touched if I had started anything: I did not start any of it. My lanes tonight were browser measurement on staging, documentation, policy checks and local test harnesses. No model was pulled, no runner installed, no benchmark executed, on this host, on HD2 or anywhere else.

One fact you may not have, because it predates me by a long way and I only saw it while checking. There IS a local llama.cpp server already running on this host:

  PID 3758652, started Thu Oct  1 06:12:08 2026, uptime 16 days 7 hours
  /opt/brandon/llm/runner/llama-server -m /opt/brandon/models/lfm2.5-latest.gguf --host 0.0.0.0 --port 8081
  the binary itself dates from 2026-09-12
  listening on 0.0.0.0:8081

It is not mine and I did not touch it. Flagging it for two reasons. First, you told me to stop anything from that message, and I want you to know this existed before I was told, so you do not attribute it to tonight. Second, it is bound on 0.0.0.0 rather than loopback, which is wider than a local inference runner needs, and the Captain has ruled out local inference entirely. Whether to stop it is your call, not mine, so I have not touched it.

Also visible and correct: AnythingLLM is listening on 127.0.0.1:3001 and on the Tailscale address 100.106.6.22:3001 on this host, which is brandon-compute, the correct client-facing instance. That matches the wiring map.

Acknowledged for the record: hd2.ai chat is served by the HD2 AnythingLLM pointed at Gemini flash-lite, that is the only path with a latency problem, and the Captain has ruled out local inference entirely. I will pull no models, install no runners and benchmark nothing locally.

VERDICT: nothing started; nothing touched; pre-existing llama-server on 0.0.0.0:8081 reported for your record; awaiting your instruction on whether to stop it.