#!/usr/bin/env python3
"""
Fetch and normalize all 42 elevatesci.com public pages.
"""
import urllib.request
import urllib.error
import re
import hashlib
import json
import os
import time
from html.parser import HTMLParser
from datetime import datetime, timezone

PACKAGE_DIR = "/home/hd2admin/kun-agent-workspace/data/elevate-rag-corpus-package-0923"
MANIFEST_PATH = "/home/hd2admin/kun-agent-workspace/data/elevate-public-rag-corpus-0923/crawl/manifest.json"

# Load manifest to get the 42 URLs and categories
with open(MANIFEST_PATH) as f:
    manifest = json.load(f)

pages = manifest["pages"]

class TextExtractor(HTMLParser):
    """Extract visible text from HTML, stripping scripts, styles, nav, footer."""
    def __init__(self):
        super().__init__()
        self.text_parts = []
        self.skip_tags = set()
        self.current_tag = None
        self.in_script = False
        self.in_style = False
        self.in_nav = False
        self.in_footer = False
        self.in_form = False
        self.in_iframe = False
        
    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style', 'noscript'):
            self.skip_tags.add(tag)
        elif tag in ('nav', 'footer', 'form', 'iframe', 'header', 'aside'):
            self.skip_tags.add(tag)
        self.current_tag = tag
    
    def handle_endtag(self, tag):
        if tag in self.skip_tags:
            self.skip_tags.discard(tag)
        if tag == self.current_tag:
            self.current_tag = None
    
    def handle_data(self, data):
        if not self.skip_tags:
            self.text_parts.append(data)
    
    def get_text(self):
        text = " ".join(self.text_parts)
        # Normalize whitespace
        text = re.sub(r'\s+', ' ', text).strip()
        return text

def normalize_text(html):
    """Strip non-content HTML elements, normalize whitespace."""
    # Remove scripts and styles entirely
    html = re.sub(r'(?is)<script[^>]*>.*?</script>', '', html)
    html = re.sub(r'(?is)<style[^>]*>.*?</style>', '', html)
    html = re.sub(r'(?is)<noscript[^>]*>.*?</noscript>', '', html)
    # Remove nav, footer, header, aside, form, iframe
    html = re.sub(r'(?is)</?(nav|footer|header|aside|form|iframe)[^>]*>', ' ', html)
    html = re.sub(r'(?is)</?(button|input|select|textarea)[^>]*>', ' ', html)
    html = re.sub(r'(?is)<!--.*?-->', '', html)
    
    parser = TextExtractor()
    try:
        parser.feed(html)
    except:
        return ""
    text = parser.get_text()
    # Remove excessive spaces
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def classify_from_path(path):
    """Assign page category from URL path."""
    if path in ("/", ""):
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

def fetch_page(url, path):
    """Fetch a single page, return (html, final_url, status)."""
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (compatible; ElevateRAG-Build/1.0; +https://hd2.ai)",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            final_url = resp.geturl()
            # Check if still on elevatesci.com
            if not final_url.startswith("https://elevatesci.com"):
                return None, final_url, -1, "Redirected off-domain"
            html = resp.read().decode("utf-8", errors="replace")
            return html, final_url, resp.status, None
    except urllib.error.HTTPError as e:
        return None, url, e.code, f"HTTP {e.code}"
    except Exception as e:
        return None, url, -1, str(e)

def slug_from_path(path):
    """Create a filename slug from URL path."""
    if path in ("/", ""):
        return "homepage"
    parts = [p for p in path.strip("/").split("/") if p]
    return "-".join(parts)

def main():
    results = []
    success = 0
    failed = 0
    
    print(f"Fetching {len(pages)} pages...")
    print()
    
    for page in pages:
        idx = page["index"]
        requested_url = page["requested_url"]
        path = page["requested_path"]
        category = page["category"]
        manifest_hash = page["content_sha256"]
        
        print(f"[{idx:02d}/42] Fetching {requested_url} ...", end=" ", flush=True)
        
        html, final_url, status, error = fetch_page(requested_url, path)
        
        if error or status != 200:
            print(f"FAILED ({error or status})")
            results.append({
                "index": idx,
                "requested_url": requested_url,
                "category": category,
                "status": "failed",
                "error": error or f"HTTP {status}",
            })
            failed += 1
            continue
        
        # Verify still on elevatesci.com
        if not final_url.startswith("https://elevatesci.com"):
            print(f"REDIRECTED off-domain to {final_url}")
            results.append({
                "index": idx,
                "requested_url": requested_url,
                "final_url": final_url,
                "category": category,
                "status": "redirected_off_domain",
            })
            failed += 1
            continue
        
        # Normalize text
        normalized = normalize_text(html)
        
        # Compute hash
        text_hash = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
        
        # Word count
        word_count = len(normalized.split())
        
        # Save document
        slug = slug_from_path(path)
        cat_dir = os.path.join(PACKAGE_DIR, "corpus", category)
        os.makedirs(cat_dir, exist_ok=True)
        doc_path = os.path.join(cat_dir, f"{idx:02d}-{slug}.txt")
        
        with open(doc_path, "w", encoding="utf-8") as f:
            f.write(f"# Source: {final_url}\n")
            f.write(f"# Fetch Date: {datetime.now(timezone.utc).strftime('%Y-%m-%d')}\n")
            f.write(f"# Category: {category}\n")
            f.write(f"# Title: {page['title']}\n")
            f.write(f"# Content SHA-256: {text_hash}\n")
            f.write(f"# Word Count: {word_count}\n")
            f.write(f"# Original Hash (from manifest): {manifest_hash}\n")
            f.write(f"# Hash Match: {text_hash == manifest_hash}\n")
            f.write("\n")
            f.write(normalized)
        
        match = "✓" if text_hash == manifest_hash else "✗"
        print(f"OK  hash={text_hash[:16]}... words={word_count} {match}")
        
        results.append({
            "index": idx,
            "requested_url": requested_url,
            "final_url": final_url,
            "category": category,
            "title": page["title"],
            "status": "success",
            "text_hash": text_hash,
            "word_count": word_count,
            "manifest_hash": manifest_hash,
            "hash_match": text_hash == manifest_hash,
            "doc_path": doc_path,
        })
        success += 1
        
        time.sleep(0.5)  # Be polite
    
    print()
    print(f"Results: {success} success, {failed} failed")
    
    # Write raw results for verification
    results_path = os.path.join(PACKAGE_DIR, "fetch-results.json")
    with open(results_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"Results written to {results_path}")
    
    # Summary
    print("\nHash match summary:")
    for r in results:
        if r["status"] == "success":
            m = "✓" if r["hash_match"] else "✗ MISMATCH"
            print(f"  [{r['index']:02d}] {m} {r['requested_url']}")

if __name__ == "__main__":
    main()
