#!/usr/bin/env python3
"""
rebuild_indexes.py — Regenerate index.md for vault folders.
Replaces 5-15 file reads per folder that Claude does manually.

Usage:
    python3 rebuild_indexes.py              # dry-run: shows what would change
    python3 rebuild_indexes.py --apply      # writes changes
    python3 rebuild_indexes.py 10-Work      # single folder dry-run
    python3 rebuild_indexes.py 10-Work --apply
    python3 rebuild_indexes.py --vault /path/to/vault
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import validate_vault, read_note, atomic_write, VAULT, SKIP_DIRS, parse_fm_field

APPLY = "--apply" in sys.argv
TARGET = None
for arg in sys.argv[1:]:
    if arg not in ("--apply", "--verbose") and not arg.startswith("--vault"):
        # Skip the value after --vault
        prev_idx = sys.argv.index(arg) - 1
        if prev_idx >= 0 and sys.argv[prev_idx] == "--vault":
            continue
        TARGET = arg

# Extend SKIP_DIRS for index rebuilding
_SKIP_DIRS = SKIP_DIRS | {"90-Arquivo", "Daily-Notes"}

# Default domain map. Override by setting ARCANA_DOMAIN_MAP env var
# as comma-separated key=value pairs (e.g., "10-Work=work,20-Research=research")
import os

_DEFAULT_DOMAIN_MAP = {
    "00-Dashboard": "personal",
    "MOCs": "personal",
    "99-Inbox": "personal",
}

_env_map = os.environ.get("ARCANA_DOMAIN_MAP", "")
DOMAIN_MAP = dict(_DEFAULT_DOMAIN_MAP)
if _env_map:
    for pair in _env_map.split(","):
        if "=" in pair:
            k, v = pair.split("=", 1)
            DOMAIN_MAP[k.strip()] = v.strip()


def detect_domain(rel_path: str) -> str:
    top = rel_path.split("/")[0]
    return DOMAIN_MAP.get(top, "personal")


def parse_summary(path: Path) -> str:
    text = read_note(path)
    return parse_fm_field(text, "summary")


def generate_index(directory: Path) -> str | None:
    dir_name = directory.name
    rel = str(directory.relative_to(VAULT))

    md_files = sorted([f for f in directory.glob("*.md") if f.name != "index.md"])
    subdirs = sorted([d for d in directory.iterdir()
                      if d.is_dir() and d.name not in _SKIP_DIRS and not d.name.startswith(".")])

    if not md_files and not subdirs:
        return None

    lines = [
        "---",
        f'title: "{dir_name}"',
        "type: hub",
        f"domain: {detect_domain(rel)}",
        "tags: [index, auto-generated]",
        "status: active",
    ]

    # Preserve original created date if exists
    existing_index = directory / "index.md"
    created = None
    if existing_index.exists():
        text = read_note(existing_index)
        if text:
            created = parse_fm_field(text, "created")

    if created:
        lines.append(f"created: {created}")
    else:
        from datetime import date
        lines.append(f"created: {date.today().isoformat()}")

    lines.extend(["---", "", f"# {dir_name}"])

    if subdirs:
        lines.extend(["", "## Subfolders", ""])
        for sd in subdirs:
            sd_count = len([f for f in sd.rglob("*.md") if f.name != "index.md"])
            if sd_count == 0:
                continue
            sd_rel = str(sd.relative_to(VAULT))
            lines.append(f"- [[{sd_rel}/index|{sd.name}]] ({sd_count} notes)")

    if md_files:
        lines.extend(["", "## Notes", ""])
        for f in md_files:
            f_rel = str(f.relative_to(VAULT)).replace(".md", "")
            summary = parse_summary(f)
            if summary:
                lines.append(f"- [[{f_rel}]] -- {summary}")
            else:
                lines.append(f"- [[{f_rel}]]")

    return "\n".join(lines) + "\n"


def normalize(text: str) -> str:
    """Strip created date and blanks for comparison."""
    return "\n".join(
        l for l in text.split("\n")
        if not l.startswith("created:") and l.strip()
    )


def main():
    validate_vault()
    changes = []
    unchanged = 0

    if TARGET:
        dirs_to_check = [VAULT / TARGET]
    else:
        dirs_to_check = []
        for d in sorted(VAULT.rglob("*")):
            if not d.is_dir():
                continue
            parts = d.relative_to(VAULT).parts
            if any(p in _SKIP_DIRS for p in parts):
                continue
            if d == VAULT:
                continue
            dirs_to_check.append(d)

    for d in dirs_to_check:
        if not d.exists():
            changes.append({"path": str(d.relative_to(VAULT)), "error": "not found"})
            continue

        new_content = generate_index(d)
        if new_content is None:
            continue

        rel = str(d.relative_to(VAULT))
        index_path = d / "index.md"

        if index_path.exists():
            current = read_note(index_path)
            if normalize(new_content) == normalize(current):
                unchanged += 1
                continue

        md_count = len([f for f in d.glob("*.md") if f.name != "index.md"])
        action = "UPDATE" if index_path.exists() else "CREATE"

        if APPLY:
            atomic_write(index_path, new_content)
            changes.append({"path": f"{rel}/index.md", "action": action, "notes": md_count})
        else:
            changes.append({"path": f"{rel}/index.md", "action": f"WOULD {action}", "notes": md_count})

    result = {
        "mode": "apply" if APPLY else "dry-run",
        "changes": changes,
        "changed_count": len(changes),
        "unchanged_count": unchanged,
    }

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
