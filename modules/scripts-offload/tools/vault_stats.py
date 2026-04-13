#!/usr/bin/env python3
"""
vault_stats.py — Quick vault statistics, JSON output.
Replaces 10+ greps that Claude does for vault overview.

Usage:
    python3 vault_stats.py
    python3 vault_stats.py --vault /path/to/vault
"""
import json
import sys
import time
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import validate_vault, read_note, VAULT, should_skip, parse_fm_field, parse_tags


def main():
    validate_vault()
    type_counts = Counter()
    domain_counts = Counter()
    status_counts = Counter()
    tag_counts = Counter()
    total_links = 0
    open_action_files = 0

    now = time.time()
    day_ago = now - 86400
    week_ago = now - 7 * 86400
    recent_24h = []
    count_7d = 0

    notes = [p for p in VAULT.rglob("*.md") if not should_skip(p)]

    for n in notes:
        text = read_note(n)
        if not text:
            continue

        mtime = n.stat().st_mtime
        rel = str(n.relative_to(VAULT))

        type_val = parse_fm_field(text, "type") or "unset"
        domain_val = parse_fm_field(text, "domain") or "unset"
        status_val = parse_fm_field(text, "status") or "unset"
        tags = parse_tags(text)

        type_counts[type_val] += 1
        domain_counts[domain_val] += 1
        status_counts[status_val] += 1
        for t in tags:
            tag_counts[t] += 1

        total_links += text.count("[[")

        if "- [ ]" in text:
            open_action_files += 1

        if mtime >= week_ago:
            count_7d += 1
        if mtime >= day_ago:
            recent_24h.append((mtime, rel))

    recent_24h.sort(reverse=True)
    recent_files = []
    for mt, rel in recent_24h[:10]:
        t = time.strftime("%H:%M", time.localtime(mt))
        recent_files.append(f"{t} {rel}")

    result = {
        "total_notes": len(notes),
        "by_type": dict(type_counts.most_common()),
        "by_domain": dict(domain_counts.most_common()),
        "by_status": dict(status_counts.most_common()),
        "top_tags": dict(tag_counts.most_common(20)),
        "activity": {
            "modified_24h": len(recent_24h),
            "modified_7d": count_7d,
            "recent_files": recent_files,
        },
        "open_action_items_files": open_action_files,
        "total_wikilinks": total_links,
    }

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
