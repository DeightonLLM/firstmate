#!/usr/bin/env python3
"""Build the package manifest from fetch results."""
import json
import os
import re
from datetime import datetime, timezone

PACKAGE_DIR = "/home/hd2admin/kun-agent-workspace/data/elevate-rag-corpus-package-0923"
results_path = os.path.join(PACKAGE_DIR, "fetch-results.json")
manifest_out = os.path.join(PACKAGE_DIR, "corpus", "manifest.json")

with open(results_path) as f:
    results = json.load(f)

manifest = {
    "package_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
    "base_url": "https://elevatesci.com",
    "total_urls": len(results),
    "successful": sum(1 for r in results if r["status"] == "success"),
    "errors": [r for r in results if r["status"] != "success"],
    "pages": []
}

for r in results:
    if r["status"] != "success":
        continue
    
    # Extract title from document
    doc_path = r["doc_path"]
    title = r.get("title", "Unknown")
    with open(doc_path, encoding="utf-8") as f:
        content = f.read()
    
    # Parse metadata from header
    lines = content.split("\n")
    metadata = {}
    body_lines = []
    in_body = False
    for line in lines:
        if line.startswith("# "):
            continue
        elif line.startswith("# "):
            pass
        elif line.startswith("#"):
            m = re.match(r"#\s+(\w+):\s+(.*)", line)
            if m:
                metadata[m.group(1)] = m.group(2).strip()
        elif in_body:
            body_lines.append(line)
        else:
            in_body = True
            body_lines.append(line)
    
    body_text = "\n".join(body_lines)
    
    manifest["pages"].append({
        "index": r["index"],
        "requested_url": r["requested_url"],
        "final_url": r["final_url"],
        "category": r["category"],
        "title": title,
        "content_sha256": r["text_hash"],
        "content_words": r["word_count"],
        "doc_path": r["doc_path"].replace(PACKAGE_DIR + "/", ""),
    })

# Category summary
cat_counts = {}
for p in manifest["pages"]:
    cat_counts[p["category"]] = cat_counts.get(p["category"], 0) + 1

manifest["category_summary"] = cat_counts

with open(manifest_out, "w") as f:
    json.dump(manifest, f, indent=2)

print(f"Manifest written: {manifest_out}")
print(f"Total pages: {manifest['total_urls']}")
print(f"Successful: {manifest['successful']}")
print(f"Categories: {cat_counts}")
