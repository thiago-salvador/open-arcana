#!/usr/bin/env python3
"""
stale_detector.py — Find notes with status: active but no modification in N days.

Usage:
    python3 stale_detector.py                    # default 30 days
    python3 stale_detector.py --days 14          # custom threshold
    python3 stale_detector.py --apply            # set status to "paused" for stale notes
    python3 stale_detector.py --vault /path/to/vault
"""
import json
import sys
import time
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import validate_vault, read_note, atomic_write, VAULT, should_skip, parse_fm_field

APPLY = "--apply" in sys.argv
DEFAULT_DAYS = 30


def get_threshold_days() -> int:
    for i, arg in enumerate(sys.argv):
        if arg == "--days" and i + 1 < len(sys.argv):
            try:
                return int(sys.argv[i + 1])
            except ValueError:
                pass
    return DEFAULT_DAYS


def update_status(path: Path, text: str) -> bool:
    """Change status: active to status: paused in frontmatter."""
    if not text.startswith("---"):
        return False

    lines = text.split("\n")
    new_lines = []
    in_fm = False
    changed = False

    for i, line in enumerate(lines):
        if i == 0 and line.strip() == "---":
            in_fm = True
            new_lines.append(line)
            continue
        if in_fm and line.strip() == "---":
            in_fm = False
            new_lines.append(line)
            continue
        if in_fm and line.startswith("status:"):
            val = line.split(":", 1)[1].strip().strip('"').strip("'")
            if val == "active":
                new_lines.append("status: paused")
                changed = True
                continue
        new_lines.append(line)

    if changed:
        atomic_write(path, "\n".join(new_lines))
    return changed


def main():
    validate_vault()
    threshold_days = get_threshold_days()
    now = time.time()
    cutoff = now - (threshold_days * 86400)

    total_active = 0
    stale_by_domain = defaultdict(list)

    notes = sorted(p for p in VAULT.rglob("*.md") if not should_skip(p))

    for note in notes:
        rel = str(note.relative_to(VAULT))
        if rel.startswith("Daily-Notes/"):
            continue
        if note.stem == "index":
            continue

        text = read_note(note)
        if not text:
            continue

        status = parse_fm_field(text, "status")
        if status != "active":
            continue

        total_active += 1
        mtime = note.stat().st_mtime

        if mtime < cutoff:
            days_since = int((now - mtime) / 86400)
            title = parse_fm_field(text, "title") or note.stem
            domain = parse_fm_field(text, "domain") or "unset"

            entry = {
                "path": rel,
                "title": title,
                "days_since_edit": days_since,
            }
            stale_by_domain[domain].append(entry)

            if APPLY:
                update_status(note, text)

    for domain in stale_by_domain:
        stale_by_domain[domain].sort(key=lambda e: -e["days_since_edit"])

    stale_count = sum(len(v) for v in stale_by_domain.values())

    result = {
        "threshold_days": threshold_days,
        "total_active": total_active,
        "stale_count": stale_count,
        "stale_by_domain": dict(sorted(stale_by_domain.items())),
    }

    if APPLY:
        result["applied"] = True
        result["action"] = f"Changed {stale_count} notes from status: active to status: paused"

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
