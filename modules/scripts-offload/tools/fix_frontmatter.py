#!/usr/bin/env python3
"""
fix_frontmatter.py — Batch fix missing frontmatter fields.
Adds missing required fields with safe defaults. Never overwrites existing values.

Usage:
    python3 fix_frontmatter.py              # dry-run
    python3 fix_frontmatter.py --apply      # apply fixes
    python3 fix_frontmatter.py --vault /path/to/vault
"""
import json
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import validate_vault, read_note, atomic_write, VAULT, VALID_TYPES, VALID_DOMAINS, should_skip

APPLY = "--apply" in sys.argv
REQUIRED = ["title", "summary", "type", "domain", "tags", "status", "created"]

# Default domain detection map. Users can extend via ARCANA_DOMAIN_MAP env var.
import os

_DEFAULT_DOMAIN_MAP = {
    "00-Dashboard": "personal",
    "MOCs": "personal",
    "99-Inbox": "personal",
    "90-Arquivo": "personal",
}

_env_map = os.environ.get("ARCANA_DOMAIN_MAP", "")
DOMAIN_MAP = dict(_DEFAULT_DOMAIN_MAP)
if _env_map:
    for pair in _env_map.split(","):
        if "=" in pair:
            k, v = pair.split("=", 1)
            DOMAIN_MAP[k.strip()] = v.strip()

# Type hints based on folder names
TYPE_HINTS = {
    "People": "person", "Pessoas": "person",
    "MOCs": "moc",
    "Errors": "error-solution",
    "Rules": "reference",
    "Research": "reference",
    "Projects": "project",
    "Dashboard": "hub",
    "Meetings": "meeting",
}


def detect_domain(path: Path) -> str:
    rel = str(path.relative_to(VAULT))
    top = rel.split("/")[0]
    return DOMAIN_MAP.get(top, "personal")


def detect_type(path: Path) -> str:
    rel = str(path.relative_to(VAULT))
    parts = rel.split("/")
    for part in parts:
        if part in TYPE_HINTS:
            return TYPE_HINTS[part]
    if rel.startswith("Daily-Notes/"):
        return "daily"
    return "reference"


def parse_frontmatter_detailed(text: str) -> tuple[dict, int, int]:
    """Returns (fields_dict, fm_start_line, fm_end_line). Lines are 0-indexed."""
    if not text.startswith("---"):
        return {}, -1, -1
    lines = text.split("\n")
    fm = {}
    end = -1
    for i, line in enumerate(lines[1:], 1):
        if line.strip() == "---":
            end = i
            break
        if ":" in line:
            key = line.split(":", 1)[0].strip()
            val = line.split(":", 1)[1].strip()
            fm[key] = val
    return fm, 0, end


def fix_file(path: Path) -> list[str]:
    """Returns list of fixes applied (or would apply)."""
    text = read_note(path)
    if not text:
        return []

    rel = str(path.relative_to(VAULT))
    if rel.startswith("Daily-Notes/"):
        return []

    fixes = []
    fm, fm_start, fm_end = parse_frontmatter_detailed(text)
    lines = text.split("\n")

    if fm_start == -1:
        stem = path.stem
        domain = detect_domain(path)
        note_type = detect_type(path)
        created = date.today().isoformat()

        try:
            from datetime import datetime
            mtime = path.stat().st_mtime
            created = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d")
        except Exception:
            pass

        new_fm = [
            "---",
            f'title: "{stem}"',
            f'summary: ""',
            f"type: {note_type}",
            f"domain: {domain}",
            f"tags: []",
            f"status: active",
            f"created: {created}",
            "---",
            "",
        ]
        new_text = "\n".join(new_fm) + text
        fixes.append(f"ADD FRONTMATTER ({note_type}, {domain})")

        if APPLY:
            atomic_write(path, new_text)
        return fixes

    # Has frontmatter: fix missing fields
    insert_lines = []
    domain = detect_domain(path)
    note_type = detect_type(path)

    for field in REQUIRED:
        if field not in fm:
            if field == "title":
                val = f'title: "{path.stem}"'
            elif field == "summary":
                val = 'summary: ""'
            elif field == "type":
                val = f"type: {note_type}"
            elif field == "domain":
                val = f"domain: {domain}"
            elif field == "tags":
                val = "tags: []"
            elif field == "status":
                val = "status: active"
            elif field == "created":
                try:
                    from datetime import datetime
                    mtime = path.stat().st_mtime
                    val = f"created: {datetime.fromtimestamp(mtime).strftime('%Y-%m-%d')}"
                except Exception:
                    val = f"created: {date.today().isoformat()}"
            insert_lines.append(val)
            fixes.append(f"ADD {field}")

    # Fix invalid type
    type_val = fm.get("type", "").strip('"').strip("'")
    if type_val and type_val not in VALID_TYPES:
        correct_type = detect_type(path)
        fixes.append(f"FIX type: '{type_val}' -> '{correct_type}'")
        if APPLY:
            for i in range(fm_start + 1, fm_end):
                if lines[i].startswith("type:"):
                    lines[i] = f"type: {correct_type}"
                    break

    # Fix invalid domain
    domain_val = fm.get("domain", "").strip('"').strip("'")
    if domain_val and domain_val not in VALID_DOMAINS:
        correct_domain = detect_domain(path)
        fixes.append(f"FIX domain: '{domain_val}' -> '{correct_domain}'")
        if APPLY:
            for i in range(fm_start + 1, fm_end):
                if lines[i].startswith("domain:"):
                    lines[i] = f"domain: {correct_domain}"
                    break

    if insert_lines and APPLY:
        for line in reversed(insert_lines):
            lines.insert(fm_end, line)
        atomic_write(path, "\n".join(lines))
    elif fixes and APPLY and not insert_lines:
        atomic_write(path, "\n".join(lines))

    return fixes


def main():
    validate_vault()
    results = []
    total_fixes = 0

    for p in sorted(VAULT.rglob("*.md")):
        if should_skip(p):
            continue
        if p.stem == "index":
            continue

        fixes = fix_file(p)
        if fixes:
            rel = str(p.relative_to(VAULT))
            results.append({"file": rel, "fixes": fixes})
            total_fixes += len(fixes)

    output = {
        "mode": "apply" if APPLY else "dry-run",
        "files_fixed": len(results),
        "total_fixes": total_fixes,
        "details": results,
    }
    print(json.dumps(output, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
