#!/usr/bin/env python3
"""Independent verification of the Elevate RAG corpus package."""
import json
import os
import re

PACKAGE = "/home/hd2admin/kun-agent-workspace/data/elevate-rag-corpus-package-0923"
MANIFEST = os.path.join(PACKAGE, "corpus", "manifest.json")
FETCH_RESULTS = os.path.join(PACKAGE, "fetch-results.json")
AG = os.path.join(PACKAGE, "corpus", "answer-guidance.md")
CN = os.path.join(PACKAGE, "corpus", "core-alignment-note.md")

pkg = json.load(open(MANIFEST))
fr = json.load(open(FETCH_RESULTS))

checks = []
warnings = []

# CHECK 1: URL Coverage
manifest_urls = sorted([p["requested_url"] for p in pkg["pages"]])
fetched_urls = sorted([r["requested_url"] for r in fr if r["status"] == "success"])
checks.append(("URL coverage (42 pages)", manifest_urls == fetched_urls and len(manifest_urls) == 42))
warnings.append(f"Manifest URLs: {len(manifest_urls)}, Fetched: {len(fetched_urls)}")

# CHECK 2: No Off-Domain
off_domain = [r for r in fr if r["status"] == "success" and not r["final_url"].startswith("https://elevatesci.com")]
checks.append(("No off-domain redirects", len(off_domain) == 0))
if off_domain:
    warnings.append(f"Off-domain: {[r['final_url'] for r in off_domain]}")

# CHECK 3: RUO in all docs
categories = ["homepage", "product-listing", "marketing", "blog", "product", "support", "legal"]
missing_ruo = []
for cat in categories:
    cat_dir = os.path.join(PACKAGE, "corpus", cat)
    if not os.path.exists(cat_dir):
        continue
    for fname in os.listdir(cat_dir):
        if not fname.endswith(".txt"):
            continue
        content = open(os.path.join(cat_dir, fname), encoding="utf-8").read()
        if "Research Use Only" not in content and "RUO" not in content:
            missing_ruo.append(f"{cat}/{fname}")
checks.append(("RUO disclaimer in all corpus docs", len(missing_ruo) == 0))
if missing_ruo:
    warnings.append(f"Missing RUO: {missing_ruo}")

# CHECK 4: All docs have metadata header
missing_header = []
for cat in categories:
    cat_dir = os.path.join(PACKAGE, "corpus", cat)
    if not os.path.exists(cat_dir):
        continue
    for fname in os.listdir(cat_dir):
        if not fname.endswith(".txt"):
            continue
        content = open(os.path.join(cat_dir, fname), encoding="utf-8").read()
        if "# Source:" not in content or "# Content SHA-256:" not in content or "# Word Count:" not in content:
            missing_header.append(f"{cat}/{fname}")
checks.append(("All docs have metadata header", len(missing_header) == 0))
if missing_header:
    warnings.append(f"Missing header: {missing_header}")

# CHECK 5: Category summary
checks.append(("Category summary in manifest", bool(pkg.get("category_summary"))))
warnings.append(f"Category distribution: {pkg.get('category_summary')}")

# CHECK 6: Answer guidance exists
checks.append(("answer-guidance.md exists", os.path.exists(AG)))
checks.append(("core-alignment-note.md exists", os.path.exists(CN)))

if os.path.exists(AG):
    ag = open(AG, encoding="utf-8").read()
    verticals = ["Research", "Lab Supplies", "Quality", "Wholesale", "Quote", "Product Catalog"]
    missing_vert = [v for v in verticals if v not in ag]
    checks.append(("answer-guidance has all 6 verticals", len(missing_vert) == 0))
    if missing_vert:
        warnings.append(f"Missing verticals: {missing_vert}")
    checks.append(("answer-guidance has RUO safety constraint", "RUO" in ag and "Not for human use" in ag))
    checks.append(("answer-guidance routes product/quote questions", "official public" in ag or "Redirect" in ag))

if os.path.exists(CN):
    cn = open(CN, encoding="utf-8").read()
    checks.append(("core-alignment-note states config unknown", "Unknown" in cn))
    checks.append(("core-alignment-note prohibits guessing config", "Do not guess" in cn or "do not guess" in cn))

# CHECK 7: No disallowed sources in corpus
disallowed = ["agents.elevatesci.com", "customer records", "authenticated pages", "third-party sites beyond elevatesci.com"]
all_texts = []
for cat in categories:
    cat_dir = os.path.join(PACKAGE, "corpus", cat)
    if not os.path.exists(cat_dir):
        continue
    for fname in os.listdir(cat_dir):
        if fname.endswith(".txt"):
            all_texts.append(open(os.path.join(cat_dir, fname), encoding="utf-8").read())
found_disallowed = [d for d in disallowed if any(d in t for t in all_texts)]
checks.append(("No disallowed source content in corpus", len(found_disallowed) == 0))
if found_disallowed:
    warnings.append(f"Disallowed content found: {found_disallowed}")

# CHECK 8: Hashes valid and unique
hashes = [p["content_sha256"] for p in pkg["pages"]]
valid_hash = all(len(h) == 64 and re.match(r"^[a-f0-9]+$", h) for h in hashes)
checks.append(("All hashes valid SHA-256", valid_hash))
checks.append(("All hashes unique", len(set(hashes)) == len(hashes)))

# CHECK 9: Word counts reasonable
wc = [p["content_words"] for p in pkg["pages"]]
checks.append(("All word counts in range 100-20000", all(100 <= w <= 20000 for w in wc)))
warnings.append(f"Word count: min={min(wc)}, max={max(wc)}, total={sum(wc)}")

# CHECK 10: Source URLs still on elevatesci.com (final_url check)
all_final_ok = all(r.get("final_url", "").startswith("https://elevatesci.com") for r in fr if r["status"] == "success")
checks.append(("All final URLs on elevatesci.com", all_final_ok))

# CHECK 11: All 42 pages have docs
doc_count = sum(len([f for f in os.listdir(os.path.join(PACKAGE, "corpus", c)) if f.endswith(".txt")]) 
                for c in categories if os.path.exists(os.path.join(PACKAGE, "corpus", c)))
checks.append(("42 source documents present", doc_count == 42))

# Print results
passed = sum(1 for _, ok in checks if ok)
failed = sum(1 for _, ok in checks if not ok)
print(f"\n{'='*60}")
print(f"VERIFICATION RESULTS: {passed} passed, {failed} failed")
print(f"{'='*60}")
for name, ok in checks:
    print(f"  {'✓' if ok else '✗'} {name}")
print(f"\nWarnings/Info:")
for w in warnings:
    print(f"  ! {w}")
print(f"{'='*60}")

if failed > 0:
    failed_checks = [n for n, ok in checks if not ok]
    print(f"FAILED: {failed_checks}")
