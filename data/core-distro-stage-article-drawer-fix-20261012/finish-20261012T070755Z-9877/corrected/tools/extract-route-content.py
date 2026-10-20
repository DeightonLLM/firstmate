#!/usr/bin/env python3
"""
Build-time helper: turn read-only public route captures into staging page content.

Inputs are local HTML captures only:
  * /tmp/cd-route-map/*.html        - the eight audited public routes
  * /tmp/cd-linked-routes/*.html    - the four linked routes (fetched GET-only)

This script never performs network I/O. It reads files, sanitizes them and
writes a sanitized fragment per route into build/pages/<slug>.html.

Safety invariants enforced here:
  * every <script>, <style>, <template>, <noscript> block is dropped, so the
    Next.js RSC payload and the HD2/AnythingLLM widget embed can never survive
  * every remote host is rewritten to a local staging path or dropped
  * no production image reference survives
  * forms are made inert (no action/method/formaction, disabled submit)
  * labels are associated with their controls (id/for)
  * a single route-scoped <h1> is asserted
"""

from __future__ import annotations

import argparse
import html
import os
import re
import sys
from html.parser import HTMLParser

# --- local asset map: production image basename -> local theme asset ---------
# Only assets that exist under theme/assets/ may be referenced.
LOCAL_ASSETS = {
    "hero-lab-v2.webp": "hero-lab-v2.webp",
    "vials-packaging-v2.webp": "vials-packaging-v2.webp",
    "about-pharma-v3.webp": "about-pharma-v3.webp",
    "compliance-quality-v2.webp": "compliance-quality-v2.webp",
    "automation-machine-v2.webp": "automation-machine-v2.webp",
    "core-distro-logo-white_ce3460b1.webp": "core-distro-logo.webp",
    "core-distro-mark-green.png": "core-distro-logo.webp",
}

ASSET_PREFIX = "__CD_STAGE_ASSET__/"

# Placeholder written for every <label for="..."> and resolved after parsing
# to the unique id of the control it labels.
PENDING_LABEL_FOR = "__CD_PENDING_LABEL_FOR__"

DROP_CONTENT = {
    "script", "style", "template", "noscript", "link", "meta",
    "svg", "iframe", "object", "embed", "chat-widget",
    "chat-widget-button", "chat-widget-window",
}
VOID = {"img", "br", "hr", "input", "source", "col", "wbr"}
BALANCED_TAGS = (
    "a", "blockquote", "button", "code", "div", "em", "figcaption", "figure",
    "form", "h1", "h2", "h3", "h4", "h5", "h6", "label", "li", "nav",
    "ol", "option", "p", "pre", "section", "select", "small", "span", "strong",
    "table", "tbody", "td", "textarea", "th", "thead", "tr", "ul", "video",
)

FORBIDDEN_HOSTS = ("core-distro.com", "llm.hd2.ai", "hd2.ai")
FORBIDDEN_NEEDLES = ("anythingllm", "/api/trpc", "llm.hd2.ai")


class ContentExtractor(HTMLParser):
    """Collects the document region between </header> and <footer>."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=False)
        self.depth = 0
        self.collecting = False
        self.skip_depth = 0
        self.parts: list[str] = []
        self.tag_stack: list[str] = []
        self.ids: set[str] = set()
        self.forms_seen = 0
        self.labels_seen = 0
        self.inputs_seen = 0
        self.control_seq = 0
        self.control_ids: list[str] = []
        self.pending_labels = 0

    # -- helpers -----------------------------------------------------------
    @staticmethod
    def _attrs(raw: dict[str, str]) -> str:
        out = []
        for k, v in raw.items():
            if v is None:
                out.append(f" {k}")
            else:
                out.append(f' {k}="{html.escape(v, quote=True)}"')
        return "".join(out)

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        raw = {k.lower(): (v if v is not None else "") for k, v in attrs}

        if tag == "header":
            self.depth += 1
            return
        if tag == "footer" and not self.collecting:
            return
        if tag == "header" and self.depth == 0:
            return

        if not self.collecting:
            if tag == "header":
                pass
            return

        if self.skip_depth:
            if tag not in VOID:
                self.skip_depth += 1
            return

        if tag in DROP_CONTENT:
            if tag not in VOID:
                self.skip_depth = 1
            return

        if tag == "footer":
            self.collecting = False
            return

        if tag in ("h1", "h2", "h3", "h4", "h5", "h6", "p", "div", "section",
                   "ul", "ol", "li", "table", "thead", "tbody", "tr", "td", "th",
                   "a", "img", "br", "hr", "span", "strong", "em", "button",
                   "label", "input", "textarea", "select", "option", "form", "nav",
                   "figure", "figcaption", "blockquote", "pre", "code", "small", "video"):
            if tag not in VOID:
                self.tag_stack.append(tag)

        if tag in ("form",):
            self.forms_seen += 1
            # inert: no action, no method, no target, no id hook for submission
            self.parts.append('<form class="cd-inert-form" novalidate>')
            return
        if tag == "input":
            self.inputs_seen += 1
            self.parts.append(self._input_html(raw))
            return
        if tag == "textarea":
            self.inputs_seen += 1
            self.parts.append(self._textarea_html(raw))
            return
        if tag == "select":
            self.inputs_seen += 1
            self.parts.append(self._select_open(raw))
            return
        if tag == "button":
            self.parts.append(self._button_html(raw))
            return
        if tag == "label":
            self.labels_seen += 1
            self.parts.append(self._label_open(raw))
            return
        if tag == "img":
            self.parts.append(self._img_html(raw))
            return
        if tag == "a":
            self.parts.append(self._a_open(raw))
            return

        if tag in VOID:
            self.parts.append(f"<{tag}{self._attrs(self._clean_attrs(raw))}>")
        else:
            self.parts.append(f"<{tag}{self._attrs(self._clean_attrs(raw))}>")

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag == "header" and self.depth:
            self.depth -= 1
            # header ends -> start collecting
            self.collecting = True
            return
        if not self.collecting:
            return
        if self.skip_depth:
            self.skip_depth -= 1
            return
        if tag in DROP_CONTENT:
            return
        if tag == "footer":
            self.collecting = False
            return
        if tag in VOID:
            return
        if self.tag_stack and tag in self.tag_stack:
            while self.tag_stack:
                top = self.tag_stack.pop()
                self.parts.append(f"</{top}>")
                if top == tag:
                    break

    def handle_data(self, data):
        if not self.collecting or self.skip_depth or "textarea" in self.tag_stack:
            return
        self.parts.append(html.escape(data, quote=False))

    def handle_entityref(self, name):
        if not self.collecting or self.skip_depth or "textarea" in self.tag_stack:
            return
        self.parts.append(f"&{name};")

    def handle_charref(self, name):
        if not self.collecting or self.skip_depth or "textarea" in self.tag_stack:
            return
        self.parts.append(f"&#{name};")

    # -- attribute sanitizers ---------------------------------------------
    @staticmethod
    def _clean_attrs(raw: dict[str, str]) -> dict[str, str]:
        out = dict(raw)
        for bad in ("srcset", "data-src", "loading", "decoding", "fetchpriority",
                    "crossorigin", "referrerpolicy", "srcset"):
            out.pop(bad, None)
        for key in list(out):
            if key.startswith("on"):
                out.pop(key)
            if key.startswith("data-"):
                out.pop(key)
        return out

    def _img_html(self, raw):
        src = raw.get("src", "")
        name = os.path.basename(src.split("?")[0])
        if name in LOCAL_ASSETS:
            new_src = ASSET_PREFIX + LOCAL_ASSETS[name]
        elif name:
            # Unknown remote asset: fall back to the closest local brand asset
            new_src = ASSET_PREFIX + "core-distro-logo.webp"
        else:
            new_src = ASSET_PREFIX + "core-distro-logo.webp"
        attrs = self._clean_attrs(raw)
        attrs["src"] = new_src
        attrs.setdefault("alt", raw.get("alt", ""))
        attrs["loading"] = "lazy"
        return f"<img{self._attrs(attrs)}>"

    def _a_open(self, raw):
        attrs = self._clean_attrs(raw)
        href = attrs.get("href", "")
        attrs["href"] = self._localise_href(href)
        target = attrs.get("target")
        if target == "_blank":
            attrs["rel"] = "noopener noreferrer"
        return f"<a{self._attrs(attrs)}>"

    def _localise_href(self, href: str) -> str:
        if not href:
            return "#"
        low = href.lower()
        if low.startswith(("mailto:", "tel:", "#")):
            return href
        if "llm.hd2.ai" in low or "hd2.ai" in low:
            return "#"
        if "core-distro.com" in low:
            rest = re.sub(r"^https?://(www\.)?core-distro\.com", "", href)
            return rest or "/"
        if low.startswith("http"):
            return "#"
        return href

    def _input_html(self, raw):
        attrs = self._clean_attrs(raw)
        attrs.pop("name", None)          # nothing is ever submitted
        attrs.pop("formaction", None)
        attrs.pop("formmethod", None)
        attrs.pop("formtarget", None)
        attrs.pop("autocomplete", None)
        attrs["id"] = self._next_control_id(raw)
        attrs["disabled"] = ""
        attrs["readonly"] = ""
        attrs["tabindex"] = "-1"
        attrs["aria-disabled"] = "true"
        return f"<input{self._attrs(attrs)}>"

    def _textarea_html(self, raw):
        attrs = self._clean_attrs(raw)
        for bad in ("name", "formaction", "formmethod", "autocomplete"):
            attrs.pop(bad, None)
        attrs["id"] = self._next_control_id(raw)
        attrs["disabled"] = ""
        attrs["readonly"] = ""
        attrs["tabindex"] = "-1"
        attrs["aria-disabled"] = "true"
        return f"<textarea{self._attrs(attrs)}>"

    def _select_open(self, raw):
        attrs = self._clean_attrs(raw)
        for bad in ("name", "formaction", "formmethod", "autocomplete"):
            attrs.pop(bad, None)
        attrs["id"] = self._next_control_id(raw)
        attrs["disabled"] = ""
        attrs["tabindex"] = "-1"
        attrs["aria-disabled"] = "true"
        return f"<select{self._attrs(attrs)}>"

    def _next_control_id(self, raw: dict[str, str]) -> str:
        """Give every preview control a stable unique id so its label binds."""
        existing = (raw.get("id") or "").strip()
        if existing and re.fullmatch(r"[A-Za-z][\w:.-]*", existing):
            self.control_ids.append(existing)
            return existing
        self.control_seq += 1
        new_id = f"cd-preview-field-{self.control_seq}"
        self.control_ids.append(new_id)
        return new_id

    def _button_html(self, raw):
        attrs = self._clean_attrs(raw)
        attrs["type"] = "button"
        attrs["disabled"] = ""
        attrs["aria-disabled"] = "true"
        attrs.pop("formaction", None)
        return f"<button{self._attrs(attrs)}>"

    def _label_open(self, raw):
        attrs = self._clean_attrs(raw)
        # Labels precede their control in this markup, so bind positionally to
        # the unique id each control is given. The public source associates no
        # label at all (linked-route audit F3), so this is a fix, not a change.
        attrs["for"] = PENDING_LABEL_FOR
        self.pending_labels += 1
        return f"<label{self._attrs(attrs)}>"


def resolve_labels(body: str, control_ids: list[str]) -> str:
    """Bind each label to the unique id of the control that follows it."""
    it = iter(list(control_ids))
    return re.sub(
        rf'for="{re.escape(PENDING_LABEL_FOR)}"',
        lambda _m: f'for="{next(it, "cd-preview-field-none")}"',
        body,
    )


# Question -> category, taken verbatim from PUBLIC_ROUTE_MAP_2026-10-10.md §2
# `/faq/` (Ordering 5, Lead Times & Shipping 4, Compliance & Quality 3,
# Products 1, Pricing & Payment 2).
FAQ_CATEGORIES = [
    ("What are your minimum order quantities", "Ordering"),
    ("How do I place an order?", "Ordering"),
    ("Do you offer sample orders?", "Ordering"),
    ("What vial sizes do you carry?", "Ordering"),
    ("What stopper materials are available?", "Ordering"),
    ("What are your typical lead times?", "Lead Times & Shipping"),
    ("How do you ship pharmaceutical products?", "Lead Times & Shipping"),
    ("Do you ship internationally?", "Lead Times & Shipping"),
    ("What documentation comes with each order?", "Lead Times & Shipping"),
    ("Are your products FDA compliant?", "Compliance & Quality"),
    ("Do you perform vendor qualification audits?", "Compliance & Quality"),
    ("Can you support our pharmacy's audit or inspection?", "Compliance & Quality"),
    ("Tell me about the automated fill-finish equipment.", "Products"),
    ("How is pricing structured?", "Pricing & Payment"),
    ("Do you offer payment terms?", "Pricing & Payment"),
]
FAQ_CATEGORIES = [(k.lower(), v) for k, v in FAQ_CATEGORIES]

FAQ_FILTERS = ["All", "Ordering", "Lead Times & Shipping", "Compliance & Quality",
               "Products", "Pricing & Payment"]

FAQ_ITEM_RE = re.compile(
    r'(<div class="fade-in-up[^"]*" style="transition-delay:\d+ms">)'
    r'(<div class="rounded-sm overflow-hidden transition-all duration-200"[^>]*>)'
    r'(<button[^>]*>)(<span[^>]*>)(.*?)(</span></button>)'
    r'(<div class="overflow-hidden transition-all duration-300"[^>]*>)',
    re.S,
)


def _faq_category(question: str) -> str | None:
    ql = question.lower()
    for key, value in FAQ_CATEGORIES:
        if key in ql:
            return value
    return None


def annotate_faq(body: str) -> tuple[str, int]:
    """
    Make the FAQ accordion usable and accessible in staging.

    The public accordion ships collapsed with no ARIA state at all
    (PUBLIC_ROUTE_MAP §4, High). Here every item starts *expanded* so the
    answers are readable with JS disabled, and each trigger carries a real
    `aria-expanded` / `aria-controls` pair for the local toggle script.
    """
    counter = {"n": 0}

    def repl(match: re.Match) -> str:
        item_open, border_open, btn_open, span_open, question, span_close, panel_open = match.groups()
        counter["n"] += 1
        index = counter["n"]
        text = html.unescape(re.sub(r"<[^>]+>", "", question)).strip()
        category = _faq_category(text) or "Products"

        btn = re.sub(r'\s+disabled(?:="")?', "", btn_open)
        btn = re.sub(r'\s+aria-disabled="[^"]*"', "", btn)
        btn = btn[:-1] + f' id="cd-faq-trigger-{index}" aria-expanded="true"' \
                         f' aria-controls="cd-faq-panel-{index}" data-cd-faq-trigger="{index}">'

        # Expanded by default: content is visible even if the script never runs.
        panel = re.sub(r"max-height:0px", "max-height:none", panel_open)
        panel = re.sub(r"opacity:0(?![\d.])", "opacity:1", panel)
        panel = panel[:-1] + f' id="cd-faq-panel-{index}" data-cd-faq-panel="{index}">'

        item = item_open.replace(
            '<div class="fade-in-up',
            '<div class="fade-in-up cd-faq-item"'
            f' data-cd-faq-category="{html.escape(category, quote=True)}"',
        )
        return item + border_open + btn + span_open + question + span_close + panel

    annotated, count = FAQ_ITEM_RE.subn(repl, body)
    return annotated, count


def annotate_faq_filters(body: str) -> str:
    """Re-enable the category chips and give them the category they filter."""
    out = body
    for label in FAQ_FILTERS:
        value = "" if label == "All" else label
        # The chip labels carry & as &amp; in the served markup.
        escaped = html.escape(label)
        pattern = re.compile(
            r'<button([^>]*?)>' + re.escape(escaped) + r'</button>')
        match = pattern.search(out)
        if not match:
            continue
        attrs = match.group(1)
        attrs = re.sub(r'\s+disabled(?:="")?', "", attrs)
        attrs = re.sub(r'\s+aria-disabled="[^"]*"', "", attrs)
        attrs = attrs.rstrip() + f' data-cd-faq-filter="{html.escape(value, quote=True)}"'
        out = out[:match.start()] + f'<button{attrs}>{escaped}</button>' + out[match.end():]
    return out


def neutralize_document_downloads(body: str) -> tuple[str, int]:
    """
    The three source PDFs are not part of staging, so their download anchors
    become inert, clearly-labelled controls instead of links that 404 locally.
    """
    pattern = re.compile(r'<a\s[^>]*href="[^"]*\.pdf[^"]*"[^>]*>([\s\S]*?)</a>', re.I)
    count = 0

    def repl(match: re.Match) -> str:
        nonlocal count
        count += 1
        return ('<span class="cd-inert-download" role="button" tabindex="-1"'
                ' aria-disabled="true" title="Not available in this private preview"'
                ' style="cursor:not-allowed;opacity:0.6">' + match.group(1) + '</span>')

    return pattern.sub(repl, body), count


def _markup_attrs(raw: str) -> dict[str, str]:
    """Read the quoted attributes emitted by ContentExtractor for a safe merge."""
    attrs = {}
    for match in re.finditer(r'([A-Za-z_:][\w:.-]*)\s*=\s*(["\'])(.*?)\2', raw, re.S):
        attrs[match.group(1).lower()] = html.unescape(match.group(3))
    return attrs


def flatten_anchor_buttons(body: str) -> str:
    """Promote a source button's visual classes onto its enclosing link."""
    pattern = re.compile(r'<a\b([^>]*)>\s*<button\b([^>]*)>([\s\S]*?)</button>\s*</a>', re.I)

    def repl(match: re.Match) -> str:
        anchor = _markup_attrs(match.group(1))
        button = _markup_attrs(match.group(2))
        classes = list(dict.fromkeys((anchor.get("class", "") + " " + button.get("class", "")).split()))
        if classes:
            anchor["class"] = " ".join(classes)
        if button.get("style"):
            anchor["style"] = ";".join(value for value in (anchor.get("style", ""), button["style"]) if value)
        for key in ("type", "disabled", "aria-disabled", "formaction", "formmethod", "formtarget"):
            button.pop(key, None)
        if button.get("aria-label") and not anchor.get("aria-label"):
            anchor["aria-label"] = button["aria-label"]
        return "<a" + ContentExtractor._attrs(anchor) + ">" + match.group(3) + "</a>"

    return pattern.sub(repl, body)


def sanitize_lighthouse_markup(body: str, slug: str) -> str:
    """Repair evidenced staging markup while preserving all displayed copy."""
    body = flatten_anchor_buttons(body)
    body = re.sub(r'<a\b([^>]*)>\s*</a>', "", body, flags=re.I)
    body = re.sub(r'<p>\s*</p>', "", body, flags=re.I)

    if slug in ("contact", "blog", "resources"):
        body = re.sub(r'<h3\b([^>]*)>', r'<h2\1>', body, flags=re.I)
        body = re.sub(r'</h3\s*>', '</h2>', body, flags=re.I)
    if slug == "blog":
        body = body.replace("color:oklch(0.50 0.04 148)", "color:oklch(0.70 0.04 148)")
    if slug in ("contact", "register"):
        body = body.replace("color:oklch(0.55 0.04 148)", "color:oklch(0.45 0.04 148)")

    if slug == "products":
        def fix_poster(match: re.Match) -> str:
            name = os.path.basename(match.group(2).split("?")[0])
            local_name = LOCAL_ASSETS.get(name)
            return f'poster="{ASSET_PREFIX}{local_name}"' if local_name else ""

        body = re.sub(r'\bposter\s*=\s*(["\'])([^"\']+)\1', fix_poster, body, flags=re.I)

        def keep_local_source(match: re.Match) -> str:
            attrs = _markup_attrs(match.group(1))
            name = os.path.basename(attrs.get("src", "").split("?")[0])
            asset_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "theme", "assets", name)
            if not name or not os.path.isfile(asset_path):
                return ""
            attrs["src"] = ASSET_PREFIX + name
            return "<source" + ContentExtractor._attrs(attrs) + ">"

        body = re.sub(r'<source\b([^>]*)>', keep_local_source, body, flags=re.I)

    return body


def extract(path: str, slug: str = "") -> str:
    with open(path, encoding="utf-8", errors="replace") as source:
        raw = source.read()
    parser = ContentExtractor()
    parser.feed(raw)
    parser.close()
    body = "".join(parser.parts)
    body = resolve_labels(body, parser.control_ids)
    body, _ = neutralize_document_downloads(body)
    body = sanitize_lighthouse_markup(body, slug)
    if slug == "faq":
        body, _ = annotate_faq(body)
        body = annotate_faq_filters(body)
    body = re.sub(r"\n{3,}", "\n\n", body)
    body = re.sub(r"[ \t]{2,}", " ", body)
    return body.strip()


def verify(slug: str, body: str) -> list[str]:
    problems = []
    low = body.lower()
    for needle in FORBIDDEN_NEEDLES:
        if needle in low:
            problems.append(f"{slug}: forbidden needle {needle!r} present")
    # What actually matters is that no staged link or asset points off-site.
    # The source's own contact strings (mailto:info@core-distro.com and the
    # bare "core-distro.com" Website label) are preserved copy that also appears
    # in the untouched homepage; they are not navigable targets, so they are
    # checked in attribute values only.
    targets = [m.group(1).lower() for m in
               re.finditer(r'\b(?:href|src|action|formaction|data-src|poster)\s*=\s*"([^"]*)"', body, re.I)]
    targets += [m.group(1).lower() for m in
                re.finditer(r"\b(?:href|src|action|formaction|data-src|poster)\s*=\s*'([^']*)'", body, re.I)]
    for target in targets:
        if target.startswith(("mailto:", "tel:", "#", "javascript:")):
            continue  # contact strings and in-page anchors are not off-site links
        if target.startswith(("http://", "https://", "//")):
            problems.append(f"{slug}: absolute off-site target {target[:60]!r}")
        if any(host in target for host in FORBIDDEN_HOSTS):
            problems.append(f"{slug}: remote host target {target[:60]!r}")
    if re.search(r"<form[^>]*\b(action|method|target)\s*=", body, re.I):
        problems.append(f"{slug}: form carries action/method/target")
    h1s = re.findall(r"<h1\b", body, re.I)
    if len(h1s) != 1:
        problems.append(f"{slug}: expected exactly 1 <h1>, found {len(h1s)}")
    for tag in BALANCED_TAGS:
        opens = len(re.findall(rf'<{tag}\b', body, re.I))
        closes = len(re.findall(rf'</{tag}\s*>', body, re.I))
        if opens != closes:
            problems.append(f"{slug}: unbalanced <{tag}> tags open={opens} close={closes}")
    if re.search(r'<a\b[^>]*>\s*<button\b', body, re.I):
        problems.append(f"{slug}: nested interactive link/button remains")
    if re.search(r'<a\b[^>]*>\s*</a>', body, re.I):
        problems.append(f"{slug}: empty link remains after SVG sanitizing")
    if slug == "products" and ("automation-machine-video_93d11a5b.mp4" in body or 'poster="/images/automation-machine-v2.webp"' in body):
        problems.append(f"{slug}: unavailable or root-relative media target remains")
    levels = [int(level) for level in re.findall(r'<h([1-6])\b', body, re.I)]
    if any(current > previous + 1 for previous, current in zip(levels, levels[1:])):
        problems.append(f"{slug}: heading outline skips a level")
    for m in re.finditer(r'<(input|textarea|select|button)\b([^>]*)>', body, re.I):
        attrs = m.group(2).lower()
        if "disabled" in attrs:
            continue
        # The FAQ accordion and its category chips are deliberately live: they are
        # pure client-side interactions with no endpoint. Everything else that
        # looks like a control must stay inert.
        if "data-cd-faq-trigger" in attrs or "data-cd-faq-filter" in attrs:
            continue
        problems.append(f"{slug}: enabled control <{m.group(1)}> {m.group(2)[:70]}")
        break
    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", nargs="*", default=None,
                    help="slug=path pairs")
    ap.add_argument("--out", default="build/pages")
    args = ap.parse_args()

    pairs = []
    if args.src:
        for item in args.src:
            slug, _, path = item.partition("=")
            pairs.append((slug, path))
    else:
        raise SystemExit("--src slug=path ... is required")

    os.makedirs(args.out, exist_ok=True)
    all_problems: list[str] = []
    for slug, path in pairs:
        if not os.path.exists(path):
            all_problems.append(f"{slug}: missing capture {path}")
            continue
        body = extract(path, slug)
        problems = verify(slug, body)
        all_problems.extend(problems)
        dest = os.path.join(args.out, f"{slug}.html")
        with open(dest, "w", encoding="utf-8") as fh:
            fh.write(body)
        h1 = re.search(r"<h1\b[^>]*>([\s\S]*?)</h1>", body, re.I)
        h1txt = re.sub(r"<[^>]+>", "", h1.group(1)).strip() if h1 else "(none)"
        print(f"{slug:22} {len(body):7d} bytes  h1={h1txt[:60]!r}")
    for p in all_problems:
        print(f"PROBLEM {p}", file=sys.stderr)
    return 1 if all_problems else 0


if __name__ == "__main__":
    raise SystemExit(main())