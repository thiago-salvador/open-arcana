#!/usr/bin/env python3
"""
broken_links.py — Find all [[wikilinks]] that point to notes that don't exist.

Usage:
    python3 broken_links.py                # find broken links
    python3 broken_links.py --verbose      # include all scanned links in output
    python3 broken_links.py --vault /path/to/vault
"""
import difflib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import validate_vault, read_note, VAULT, SKIP_DIRS, SKIP_FILES, WIKILINK_RE, should_skip, norm_stem

VERBOSE = "--verbose" in sys.argv


def build_basename_set() -> set[str]:
    """Build a set of all existing note basenames (stems), including normalized forms.
    Obsidian resolves links case-insensitively and treats spaces/hyphens as equivalent."""
    basenames = set()
    for p in VAULT.rglob("*.md"):
        if should_skip(p):
            continue
        basenames.add(p.stem)
        basenames.add(norm_stem(p.stem))
    # Include index files (skipped for content scanning but valid link targets)
    for p in VAULT.rglob("index.md"):
        parts = p.relative_to(VAULT).parts
        if not any(part in SKIP_DIRS for part in parts):
            basenames.add("index")
    # Include template files and SKIP_FILES as valid link targets
    for p in VAULT.rglob("*.md"):
        parts = p.relative_to(VAULT).parts
        if "80-Templates" in parts or p.name in SKIP_FILES:
            basenames.add(p.stem)
            basenames.add(norm_stem(p.stem))
    return basenames


def find_closest_match(target: str, basenames: set[str], threshold: float = 0.7) -> str | None:
    """Use SequenceMatcher to find the closest existing note name."""
    best_match = None
    best_ratio = 0.0
    target_lower = target.lower()
    for name in basenames:
        ratio = difflib.SequenceMatcher(None, target_lower, name.lower()).ratio()
        if ratio > best_ratio and ratio >= threshold:
            best_ratio = ratio
            best_match = name
    return best_match


def main():
    validate_vault()
    basenames = build_basename_set()
    total_links = 0
    broken_links = []
    seen_broken = set()

    notes = sorted(p for p in VAULT.rglob("*.md") if not should_skip(p))

    for note in notes:
        rel = str(note.relative_to(VAULT))
        text = read_note(note)
        if not text:
            continue

        lines = text.split("\n")
        for line_num, line in enumerate(lines, start=1):
            for m in WIKILINK_RE.finditer(line):
                total_links += 1
                target = m.group(1).strip()
                target_stem = target.split("/")[-1] if "/" in target else target

                if target_stem not in basenames and norm_stem(target_stem) not in basenames:
                    key = (rel, target)
                    if key not in seen_broken:
                        seen_broken.add(key)
                        broken_links.append({
                            "source": rel,
                            "target": target,
                            "line": line_num,
                        })

    # Generate suggestions for broken links
    suggestions = []
    seen_suggestions = set()
    for bl in broken_links:
        target = bl["target"]
        target_stem = target.split("/")[-1] if "/" in target else target
        if target_stem in seen_suggestions:
            continue
        match = find_closest_match(target_stem, basenames)
        if match and match != target_stem:
            seen_suggestions.add(target_stem)
            suggestions.append({
                "broken": target,
                "did_you_mean": match,
            })

    result = {
        "total_links_scanned": total_links,
        "broken_count": len(broken_links),
        "broken_links": broken_links,
        "suggestions": suggestions,
    }

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
