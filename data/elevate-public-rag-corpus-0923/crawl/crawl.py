#!/usr/bin/env python3
"""
Crawl elevatesci.com public pages.
Bounded discovery: sitemap-listed URLs only.
Excludes: agents.elevatesci.com, auth, dashboards, forms, third-party.
"""

import subprocess
import re
import json
import hashlib
import os
import time
from urllib.parse import urljoin

BASE = "https://elevatesci.com"
CRAWL_DIR = os.path.dirname(os.path.abspath(__file__))
CRAWL_DATE = "2026-09-23"
USER_AGENT = "Mozilla/5.0 (compatible; ElevateRAG-Scout/1.0; +https://hd2.ai)"

SITEMAP_URLS = [
    "https://elevatesci.com/",
    "https://elevatesci.com/shop",
    "https://elevatesci.com/about",
    "https://elevatesci.com/quality",
    "https://elevatesci.com/research",
    "https://elevatesci.com/research-notes",
    "https://elevatesci.com/lab-supplies",
    "https://elevatesci.com/faq",
    "https://elevatesci.com/contact",
    "https://elevatesci.com/quote",
    "https://elevatesci.com/wholesale",
    "https://elevatesci.com/blog",
    "https://elevatesci.com/blog/gmp-peptide-manufacturing",
    "https://elevatesci.com/blog/custom-peptide-synthesis-guide",
    "https://elevatesci.com/blog/the-future-of-peptide-research",
    "https://elevatesci.com/product/aod-9604",
    "https://elevatesci.com/product/bpc-157",
    "https://elevatesci.com/product/bpc-157-tb-500",
    "https://elevatesci.com/product/b-12",
    "https://elevatesci.com/product/cjc-1295-ipamorelin-no-dac",
    "https://elevatesci.com/product/cjc-1295-no-dac",
    "https://elevatesci.com/product/epitalon",
    "https://elevatesci.com/product/glow",
    "https://elevatesci.com/product/glutathione",
    "https://elevatesci.com/product/igf-1-lr3",
    "https://elevatesci.com/product/ipamorelin",
    "https://elevatesci.com/product/klow",
    "https://elevatesci.com/product/l-carnitine",
    "https://elevatesci.com/product/mots-c",
    "https://elevatesci.com/product/mt-2",
    "https://elevatesci.com/product/nad-plus",
    "https://elevatesci.com/product/glp-3",
    "https://elevatesci.com/product/selank",
    "https://elevatesci.com/product/tb-500",
    "https://elevatesci.com/product/tesamorelin",
    "https://elevatesci.com/privacy",
    "https://elevatesci.com/terms",
    "https://elevatesci.com/disclaimer",
    "https://elevatesci.com/shipping",
    "https://elevatesci.com/refund-policy",
    "https://elevatesci.com/cookie-policy",
    "https://elevatesci.com/accessibility",
]

def classify(path):
    """Assign page category from URL path."""
    if path == "/" or path == "":
        return "homepage"
    parts = [p for p in path.strip("/").split("/") if p]
    if not parts:
        return "homepage"
    top = parts[0]
    cat_map = {
        "shop": "product-listing",
        "about": "marketing",
        "quality": "marketing",
        "research": "marketing",
        "research-notes": "blog",
        "lab-supplies": "marketing",
        "faq": "support",
        "contact": "marketing",
        "quote": "marketing",
        "wholesale": "marketing",
        "blog": "blog",
        "product": "product",
        "privacy": "legal",
        "terms": "legal",
        "disclaimer": "legal",
        "shipping": "support",
        "refund-policy": "legal",
        "cookie-policy": "legal",
        "accessibility": "legal",
    }
    return cat_map.get(top, "other")

def normalize_text(html):
    """Strip scripts, styles, nav, footer, forms; normalize whitespace."""
    html = re.sub(r'(?is)<script[^>]*>.*?</script>', '', html)
    html = re.sub(r'(?is)<style[^>]*>.*?</style>', '', html)
    html = re.sub(r'(?is)<nav[^>]*>.*?</nav>', '', html)
    html = re.sub(r'(?is)<footer[^>]*>.*?</footer>', '', html)
    html = re.sub(r'(?is)<form[^>]*>.*?</form>', '', html)
    html = re.sub(r'(?is)<header[^>]*>.*?</header>', '', html)
    html = re.sub(r'(?is)<noscript[^>]*>.*?</noscript>', '', html)
    html = re.sub(r'<!--.*?-->', '', html, flags=re.DOTALL)
    text = re.sub(r'<[^>]+>', ' ', html)
    text = re.sub(r'&nbsp;', ' ', text)
    text = re.sub(r'&amp;', '&', text)
    text = re.sub(r'&lt;', '<', text)
    text = re.sub(r'&gt;', '>', text)
    text = re.sub(r'&quot;', '"', text)
    text = re.sub(r'&#\d+;', '', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def extract_title(html, fallback_url):
    m = re.search(r'<title[^>]*>([^<]+)</title>', html, re.IGNORECASE)
    if m:
        return m.group(1).strip()
    m = re.search(r'<meta[^>]+property=["\']og:title["\'][^>]+content=["\']([^"\']+)["\']', html, re.IGNORECASE)
    if m:
        return m.group(1).strip()
    return f"[NO TITLE: {fallback_url}]"

def extract_canonical(html, requested_url):
    m = re.search(r'<link[^>]+rel=["\']canonical["\'][^>]+href=["\']([^"\']+)["\']', html, re.IGNORECASE)
    if m:
        return m.group(1).strip()
    return requested_url

def excerpt(text, words=50):
    """Return first N words as excerpt."""
    w = text.split()
    if len(w) <= words:
        return text
    return ' '.join(w[:words]) + " …"

def curl_get(url, timeout=20):
    """Fetch URL with curl, return (status_code, final_url, content, error)."""
    out_file = os.path.join(CRAWL_DIR, "_tmp.html")
    err_file = os.path.join(CRAWL_DIR, "_tmp.err")
    cmd = [
        "curl", "-s", "-L", "-w", "%{http_code}|%{url_effective}",
        "-A", USER_AGENT,
        "-o", out_file,
        "--max-time", str(timeout),
        url
    ]
    try:
        r = subprocess.run(cmd, capture_output=True, timeout=timeout + 5)
        meta = r.stdout.decode("utf-8", errors="replace").strip()
        with open(out_file, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
        if "|" in meta:
            parts = meta.rsplit("|", 1)
            status_code = int(parts[0]) if parts[0].isdigit() else 0
            final_url = parts[1] if len(parts) > 1 else url
        else:
            status_code = 0
            final_url = url
        return status_code, final_url, content, None
    except subprocess.TimeoutExpired:
        return 0, url, "", "TIMEOUT"
    except Exception as e:
        return 0, url, "", str(e)
    finally:
        for f in [out_file, err_file]:
            if os.path.exists(f):
                os.remove(f)

def main():
    manifest = []
    errors = []
    seen_hashes = {}  # hash -> url list
    dupes = []        # (hash, [url list])

    print(f"Crawl date: {CRAWL_DATE}")
    print(f"URLs to crawl: {len(SITEMAP_URLS)}")

    for i, url in enumerate(SITEMAP_URLS, 1):
        rel_path = url.replace(BASE, "") or "/"
        category = classify(rel_path)
        status_code, final_url, html, err = curl_get(url)
        
        if err:
            print(f"  [{i}/{len(SITEMAP_URLS)}] ERROR {url}: {err}")
            errors.append({
                "url": url,
                "requested_path": rel_path,
                "category": category,
                "error": err
            })
            continue

        title = extract_title(html, url)
        canonical = extract_canonical(html, url)
        norm_text = normalize_text(html)
        content_hash = hashlib.sha256(norm_text.encode("utf-8", errors="replace")).hexdigest()
        excerpt_text = excerpt(norm_text, words=60)

        # Detect redirect
        is_redirect = final_url != url and not final_url.startswith(BASE)
        if is_redirect:
            errors.append({
                "url": url,
                "requested_path": rel_path,
                "category": category,
                "error": f"OFF-DOMAIN REDIRECT: {final_url}"
            })

        entry = {
            "index": i,
            "requested_url": url,
            "requested_path": rel_path,
            "canonical_url": canonical,
            "final_url": final_url,
            "http_status": status_code,
            "category": category,
            "title": title,
            "content_sha256": content_hash,
            "content_words": len(norm_text.split()),
            "excerpt": excerpt_text,
            "is_duplicate_of": None,
            "redirect_off_domain": final_url if is_redirect else None,
        }

        # Check for duplicates
        if content_hash in seen_hashes:
            entry["is_duplicate_of"] = seen_hashes[content_hash][0]
            dupes.append((content_hash, [seen_hashes[content_hash][0], url]))
        else:
            seen_hashes[content_hash] = [url]

        manifest.append(entry)
        print(f"  [{i}/{len(SITEMAP_URLS)}] {status_code} {category:20s} {rel_path}")

        # Polite crawl delay
        time.sleep(0.3)

    # Write manifest JSON
    manifest_path = os.path.join(CRAWL_DIR, "manifest.json")
    with open(manifest_path, "w") as f:
        json.dump({
            "crawl_date": CRAWL_DATE,
            "base_url": BASE,
            "total_urls": len(SITEMAP_URLS),
            "successful": sum(1 for e in manifest if e["http_status"] in (200, 301, 302)),
            "errors": errors,
            "duplicates": [{"hash": h, "pages": urls} for h, urls in dupes],
            "pages": manifest
        }, f, indent=2)
    print(f"\nManifest: {manifest_path}")
    print(f"Total pages: {len(manifest)}, Errors: {len(errors)}, Duplicates: {len(dupes)}")

if __name__ == "__main__":
    main()
