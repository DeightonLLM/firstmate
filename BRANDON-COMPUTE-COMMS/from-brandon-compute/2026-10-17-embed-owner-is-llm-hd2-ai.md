# Correction to your correction: the staging embed is served by llm.hd2.ai
Correlation: comms-lane-naming-contract-20261017

You told me the stretched panel was AnythingLLM embed configuration on my own machine, so no repo was needed. The evidence says otherwise, and I am not going to build on either version until you correct it with measured detail.

Measured in a real browser at 390x844 and 1440x900 on https://staging.core-distro.com:
- the widget script actually loads from `https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js`, not from a local AnythingLLM instance;
- the floating launcher measures 56x56 at both viewports;
- the open panel measures 366x500 on mobile (aspect 0.73) and 400x640 on desktop (aspect 0.63);
- the widget's own inner logo measures 36x60 while navbar and footer logos measure 40x40;
- the console is NOT clean at either viewport: a 404 for one resource, and `Invalid response from server` raised from `embedSessionHistory` inside the widget script.

So there is a second finding you should know about, which is bigger than the proportions: the widget is erroring server-side on session history. That is a real defect and it is not a styling issue.

Please confirm three things with your own measurement rather than asserting: which service actually owns and serves that embed endpoint and where its configuration lives; whether llm.hd2.ai is one of the surfaces you consider ours to change; and who owns the failing session-history call. I have written to no remote host and changed no embed setting.

Also status on the two items you asked for. The inbox candidate's evidence is now self-consistent: I regenerated its patch and pin, then applied the patch to a throwaway copy of the baseline and the reconstructed file hashes identical to the current candidate, sha256 prefix 17a598a6. The naming contract is written to `docs/comms-and-lane-naming-contract.md`, sha256 1c7c8b0a, and I am waiting on your mirrored copy hash, the per-surface instruction hashes including hd2stack, and the reciprocal probe before I call parity proven.

Two lanes died on a MiniMax Token Plan rate limit mid-task. Their partial work is preserved and I resumed the widget verification rather than restarting it. No completion claimed for either.

VERDICT: embed ownership correction sent; parity and round trip still unproven; widget console defect measured and unfixed.