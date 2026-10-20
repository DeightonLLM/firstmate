# Widget root cause found: /llm/chat/ returns 404. Logo fix needs the staging source.
Correlation: comms-lane-naming-contract-20261017

Both earlier measurements were partly wrong and I am not passing either on. Here is what three lanes established with reproducible evidence, and two concrete things only you can unblock.

WIDGET, root cause identified and reproducible:
1. The widget is LAZY-LOADED. It is not in the served HTML and loads only when the visible ASK QUESTIONS button is clicked. Any check that does not click that button will correctly see "no widget", which is why we had two contradicting reports.
2. After clicking, the scripts DO load from `https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js`, a session id registers, and console is clean.
3. The panel then renders at **width 0, height 0** and makes **zero backend API calls**. The widget never reaches its backend.
4. `https://staging.core-distro.com/llm/chat/` returns **404 from nginx**.
That 404 is the break point: the Captain's "Ask Questions does nothing" and the old worker's "loaded the embed but did not open it" are the same defect. Earlier readings of a 366x500 panel and an embedSessionHistory error described a previous, partially working state that no longer reproduces.

Ask: please confirm on your side who owns the llm.hd2.ai embed backend and the `/llm/chat/` route, and whether it is ours to fix. I have changed nothing remotely and will not touch it until that is answered.

LOGOS, cause identified, fix needs the site source I still do not have:
- Source asset `core-distro-mark-green.png` is 1568x940, a wide 1.67:1 image.
- Every logo instance (navbar, footer, mobile header) applies `h-10 w-10` plus `object-contain`, which forces a 40x40 square box. `object-contain` prevents cropping but letterboxes: the visible logo content renders about 24x24 inside that square, which is what reads as "skewed".
- The asset is fine, the HTML width and height attributes are fine, and `object-fit` is already set. The defect is purely the square constraint on a wide asset.
- Minimal fix per location: size by height and let width follow the intrinsic ratio, for example `h-10 w-auto`, applied to the three logo instances. Also noted: there is no `og:image`, so social share cards have no image.

Ask: the repo and host serving `staging.core-distro.com` still have not been supplied, and the only local clone is a PHP project with no Next.js app. Please supply the site source location or an owner for that one-line fix. I will not guess which repository is live.

No production change, no deploy, no credentials, no remote write. VERDICT: widget root cause is a reproducible 404 on /llm/chat/ plus a lazy-load that hides the widget from naive checks; logo cause is a square CSS constraint on a wide asset; both fixes are owned outside this home until you confirm the owners.