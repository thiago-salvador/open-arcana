#!/usr/bin/env python3
"""
vault_health.py — Full vault health audit, JSON output.
Replaces 20-30 manual file reads that Claude does during /health.

Usage:
    python3 vault_health.py              # summary only
    python3 vault_health.py --verbose    # includes file-level details
    python3 vault_health.py --vault /path/to/vault
"""
import json
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import (
    validate_vault, read_note, VAULT, SKIP_DIRS, VALID_TYPES, VALID_DOMAINS,
    WIKILINK_RE, parse_frontmatter, collect_notes, norm_stem,
)

VERBOSE = "--verbose" in sys.argv
REQUIRED_FIELDS = {"title", "summary", "type", "domain", "tags", "status", "created"}


def main():
    validate_vault()
    notes = collect_notes()
    # Also collect ALL .md files (including index.md) for link scanning.
    # collect_notes() skips index.md via SKIP_FILES, but we need indexes
    # for orphan detection since they contain wikilinks to notes.
    all_md = [p for p in VAULT.rglob("*.md")
              if not any(part in SKIP_DIRS for part in p.relative_to(VAULT).parts)]
    total = len(notes)

    # 1. Notes by folder
    folder_counts = defaultdict(int)
    for n in notes:
        top_folder = n.relative_to(VAULT).parts[0]
        folder_counts[top_folder] += 1

    # 2. Frontmatter validation
    missing_fm = 0
    missing_fields_total = 0
    fm_issues = []

    for n in notes:
        rel = str(n.relative_to(VAULT))
        if n.stem == "index" or n.stem == "MEMORY":
            continue
        if "/" not in rel and "\\" not in rel:
            continue

        text = read_note(n)
        fm = parse_frontmatter(text)
        if fm is None:
            missing_fm += 1
            if VERBOSE:
                fm_issues.append(f"{rel}: NO FRONTMATTER")
            continue

        if rel.startswith("Daily-Notes/"):
            continue

        for field in REQUIRED_FIELDS:
            if field not in fm:
                missing_fields_total += 1
                if VERBOSE:
                    fm_issues.append(f"{rel}: missing '{field}'")

        t = fm.get("type", "")
        if t and t not in VALID_TYPES:
            if VERBOSE:
                fm_issues.append(f"{rel}: invalid type '{t}'")

        d = fm.get("domain", "")
        if d and d not in VALID_DOMAINS:
            if VERBOSE:
                fm_issues.append(f"{rel}: invalid domain '{d}'")

    # 3. Orphan detection (no incoming wikilinks)
    linked = set()
    for n in all_md:
        text = read_note(n)
        if not text:
            continue
        for m in WIKILINK_RE.finditer(text):
            target = m.group(1).strip()
            linked.add(target)
            linked.add(norm_stem(target))
            if "/" in target:
                base = target.rsplit("/", 1)[-1]
                linked.add(base)
                linked.add(norm_stem(base))

    orphans = []
    for n in notes:
        rel = str(n.relative_to(VAULT))
        if n.stem == "index":
            continue
        if rel.startswith("Daily-Notes/") or rel.startswith("00-Dashboard/") or rel.startswith("MOCs/") or rel.startswith("90-Arquivo/"):
            continue
        if n.stem not in linked and norm_stem(n.stem) not in linked:
            orphans.append(rel)

    # 4. Isolated notes (no outgoing wikilinks)
    isolated = []
    for n in notes:
        rel = str(n.relative_to(VAULT))
        if n.stem == "index" or rel.startswith("Daily-Notes/"):
            continue
        text = read_note(n)
        if not text:
            continue
        if "[[" not in text:
            isolated.append(rel)

    # 5. Index.md coverage
    missing_indexes = []
    for d in VAULT.iterdir():
        if not d.is_dir():
            continue
        if d.name in SKIP_DIRS or d.name in {"90-Arquivo", "Daily-Notes"}:
            continue
        md_files = [f for f in d.glob("*.md") if f.name != "index.md"]
        if not md_files:
            continue
        if not (d / "index.md").exists():
            missing_indexes.append(str(d.relative_to(VAULT)))
        for sd in d.iterdir():
            if not sd.is_dir() or sd.name.startswith("."):
                continue
            sd_md = [f for f in sd.glob("*.md") if f.name != "index.md"]
            if sd_md and not (sd / "index.md").exists():
                missing_indexes.append(str(sd.relative_to(VAULT)))

    # 6. Health score
    score = 100
    fm_pen = min(missing_fm * 2, 20)
    field_pen = min(missing_fields_total // 2, 15)
    orphan_pen = min(len(orphans), 15)
    iso_pen = min(len(isolated), 10)
    idx_pen = min(len(missing_indexes) * 3, 15)
    score = max(0, score - fm_pen - field_pen - orphan_pen - iso_pen - idx_pen)

    result = {
        "health_score": score,
        "total_notes": total,
        "notes_by_folder": dict(sorted(folder_counts.items())),
        "issues": {
            "missing_frontmatter": missing_fm,
            "missing_fields": missing_fields_total,
            "orphan_notes": len(orphans),
            "isolated_notes": len(isolated),
            "folders_without_index": len(missing_indexes),
        },
        "score_breakdown": {
            "frontmatter_penalty": -fm_pen,
            "fields_penalty": -field_pen,
            "orphan_penalty": -orphan_pen,
            "isolated_penalty": -iso_pen,
            "index_penalty": -idx_pen,
        },
    }

    if VERBOSE:
        result["details"] = {
            "frontmatter_issues": fm_issues[:30],
            "orphans": orphans[:30],
            "isolated": isolated[:30],
            "missing_indexes": missing_indexes,
        }

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
