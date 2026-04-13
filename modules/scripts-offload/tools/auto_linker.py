#!/usr/bin/env python3
"""
auto_linker.py — Add contextual wikilinks to isolated notes.
Scans notes with zero outgoing [[links]] and adds relevant ones
based on folder context, people mentions, and project references.

Usage:
    python3 auto_linker.py              # dry-run
    python3 auto_linker.py --apply      # apply links
    python3 auto_linker.py --vault /path/to/vault
"""
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import validate_vault, read_note, atomic_write, VAULT, should_skip

APPLY = "--apply" in sys.argv

# MOC mapping by domain path. Override via ARCANA_MOC_MAP env var
# as comma-separated key=value pairs (e.g., "10-Work=Work MOC,60-Research=Research MOC")
_DEFAULT_MOCS = {}

_env_mocs = os.environ.get("ARCANA_MOC_MAP", "")
MOCS = dict(_DEFAULT_MOCS)
if _env_mocs:
    for pair in _env_mocs.split(","):
        if "=" in pair:
            k, v = pair.split("=", 1)
            MOCS[k.strip()] = v.strip()

# Build people index from the vault's people directory.
# Auto-detect common people folder names.
PEOPLE_NAMES = set()

for candidate in ["70-People", "70-Pessoas", "People", "Pessoas"]:
    people_dir = VAULT / candidate
    if people_dir.exists():
        for p in people_dir.glob("*.md"):
            if p.name != "index.md":
                PEOPLE_NAMES.add(p.stem)
        break


def has_wikilinks(text: str) -> bool:
    return "[[" in text


def find_people_mentions(text: str) -> list[str]:
    """Find people mentioned in text. Requires full name match to avoid false positives."""
    found = []
    for name in PEOPLE_NAMES:
        parts = name.split()
        if len(parts) < 2:
            if len(name) >= 4 and re.search(r'\b' + re.escape(name) + r'\b', text, re.IGNORECASE):
                found.append(name)
            continue
        first = parts[0]
        last = parts[-1]
        if len(first) < 2 or len(last) < 2:
            continue
        first_found = re.search(r'\b' + re.escape(first) + r'\b', text, re.IGNORECASE)
        last_found = re.search(r'\b' + re.escape(last) + r'\b', text, re.IGNORECASE)
        if first_found and last_found:
            found.append(name)
    return found


def get_parent_project(path: Path) -> str | None:
    rel = path.relative_to(VAULT)
    parts = rel.parts
    if len(parts) >= 2:
        return parts[-2]
    return None


def get_moc(path: Path) -> str | None:
    rel = str(path.relative_to(VAULT))
    top = rel.split("/")[0]
    return MOCS.get(top)


def build_links_section(links: list[str]) -> str:
    section = "\n\n---\n\n**Links:** "
    section += " | ".join(f"[[{l}]]" for l in links)
    section += "\n"
    return section


def process_note(path: Path) -> dict | None:
    text = read_note(path)
    if not text:
        return None

    if has_wikilinks(text):
        return None

    rel = str(path.relative_to(VAULT))
    links_to_add = []

    parent = get_parent_project(path)
    if parent and parent != path.stem:
        links_to_add.append(f"{parent}/index|{parent}")

    moc = get_moc(path)
    if moc:
        links_to_add.append(moc)

    people = find_people_mentions(text)
    for p in people[:3]:
        links_to_add.append(p)

    if not links_to_add:
        return None

    result = {
        "file": rel,
        "links": links_to_add,
    }

    if APPLY:
        new_text = text.rstrip() + build_links_section(links_to_add)
        atomic_write(path, new_text)

    return result


def main():
    validate_vault()
    results = []

    for p in sorted(VAULT.rglob("*.md")):
        if should_skip(p):
            continue
        if p.stem == "index":
            continue
        rel = str(p.relative_to(VAULT))
        if rel.startswith("Daily-Notes/"):
            continue

        result = process_note(p)
        if result:
            results.append(result)

    output = {
        "mode": "apply" if APPLY else "dry-run",
        "notes_linked": len(results),
        "details": results,
    }
    print(json.dumps(output, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
