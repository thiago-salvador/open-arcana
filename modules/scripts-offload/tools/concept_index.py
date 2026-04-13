#!/usr/bin/env python3
"""
concept_index.py — Extract title + summary from all notes' frontmatter,
generate a concept index grouped by domain.

Usage:
    python3 concept_index.py              # output JSON
    python3 concept_index.py --apply      # write to 00-Dashboard/concept-index.md
    python3 concept_index.py --vault /path/to/vault
"""
import json
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import validate_vault, read_note, atomic_write, VAULT, should_skip, parse_frontmatter

APPLY = "--apply" in sys.argv
OUTPUT_PATH = VAULT / "00-Dashboard" / "concept-index.md"


def get_existing_created() -> str:
    """Preserve the created date from existing concept-index.md."""
    if not OUTPUT_PATH.exists():
        return ""
    text = read_note(OUTPUT_PATH)
    if not text:
        return ""
    fm = parse_frontmatter(text)
    return fm.get("created", "") if fm else ""


def _today() -> str:
    from datetime import date
    return date.today().isoformat()


def build_markdown(entries: list[dict], created: str) -> str:
    """Generate the concept-index.md content."""
    by_domain = defaultdict(list)
    for e in entries:
        by_domain[e["domain"]].append(e)

    lines = [
        "---",
        'title: "Concept Index"',
        'summary: "Auto-generated index of all vault concepts with title and summary"',
        "type: hub",
        "domain: personal",
        "tags: [index, auto-generated]",
        "status: active",
        f"created: {created}" if created else f"created: {_today()}",
        "---",
        "",
        "# Concept Index",
        "",
        f"> Auto-generated. {len(entries)} concepts across {len(by_domain)} domains.",
        "",
    ]

    for domain in sorted(by_domain.keys()):
        domain_entries = sorted(by_domain[domain], key=lambda e: e["title"].lower())
        lines.append(f"## {domain}")
        lines.append("")
        for e in domain_entries:
            summary_part = f" -- {e['summary']}" if e["summary"] else ""
            lines.append(f"- [[{e['title']}]]{summary_part}")
        lines.append("")

    return "\n".join(lines)


def main():
    validate_vault()
    entries = []
    by_domain = defaultdict(list)

    for p in sorted(VAULT.rglob("*.md")):
        if should_skip(p):
            continue
        if p.stem == "index":
            continue
        rel = str(p.relative_to(VAULT))
        if rel.startswith("Daily-Notes/"):
            continue

        text = read_note(p)
        if not text:
            continue

        fm = parse_frontmatter(text)
        title = fm.get("title", "") if fm else ""
        summary = fm.get("summary", "") if fm else ""
        domain = fm.get("domain", "unset") if fm else "unset"
        note_type = fm.get("type", "unset") if fm else "unset"

        if not title:
            continue

        entry = {
            "title": title,
            "summary": summary,
            "path": rel,
            "domain": domain,
            "type": note_type,
        }
        entries.append(entry)
        by_domain[domain].append(entry)

    by_domain_sorted = {}
    for domain in sorted(by_domain.keys()):
        by_domain_sorted[domain] = sorted(
            [e["title"] for e in by_domain[domain]]
        )

    result = {
        "total_concepts": len(entries),
        "by_domain": by_domain_sorted,
        "entries": entries,
    }

    if APPLY:
        existing_created = get_existing_created()
        md_content = build_markdown(entries, existing_created)
        atomic_write(OUTPUT_PATH, md_content)
        result["applied"] = True
        result["output_path"] = str(OUTPUT_PATH.relative_to(VAULT))

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
