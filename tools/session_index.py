#!/usr/bin/env python3
"""
Session index builder for Cross-Session FTS Recall.
Parses Claude Code JSONL sessions, extracts prompts + keywords,
generates a searchable index (markdown table + grepable JSONL).

Usage:
  python3 session_index.py              # Full rebuild
  python3 session_index.py --incremental  # Only new sessions

Environment variables:
  VAULT_PATH  — Path to your Obsidian vault (required)
  PROJECT_DIR — Override the Claude Code projects dir to scan
                (default: auto-detect from VAULT_PATH)

Outputs:
  {VAULT_PATH}/00-Dashboard/session-index.md    — Human-readable table
  {VAULT_PATH}/00-Dashboard/session-index.jsonl — Grepable (one JSON obj per session)
"""

import json
import os
import re
import sys
from pathlib import Path
from collections import Counter
from datetime import datetime

# --- Configuration ---

VAULT_PATH = os.environ.get("VAULT_PATH")
if not VAULT_PATH:
    print("ERROR: VAULT_PATH environment variable is required.")
    print("  export VAULT_PATH=/path/to/your/obsidian/vault")
    sys.exit(1)

VAULT_DIR = Path(VAULT_PATH)
OUTPUT_DIR = VAULT_DIR / "00-Dashboard"
INDEX_MD = OUTPUT_DIR / "session-index.md"
INDEX_JSONL = OUTPUT_DIR / "session-index.jsonl"

# Auto-detect project dir from vault path, or use override
PROJECTS_DIR = Path.home() / ".claude" / "projects"
if os.environ.get("PROJECT_DIR"):
    PROJECT_DIR = Path(os.environ["PROJECT_DIR"])
else:
    # Convert vault path to Claude Code's project dir naming convention
    # e.g., /Users/me/vault -> -Users-me-vault
    vault_slug = str(VAULT_DIR).replace("/", "-")
    if vault_slug.startswith("-"):
        pass  # already starts with dash from leading /
    else:
        vault_slug = "-" + vault_slug
    PROJECT_DIR = PROJECTS_DIR / vault_slug

# Stopwords for keyword extraction (EN + PT mixed, kept minimal)
STOPWORDS = {
    "the", "and", "for", "that", "this", "with", "from", "have", "will",
    "been", "they", "their", "there", "what", "when", "where", "which",
    "about", "would", "could", "should", "into", "than", "then", "them",
    "some", "other", "more", "also", "just", "like", "make", "only",
    "very", "does", "done", "here", "each", "over", "after", "before",
    "being", "most", "your", "were", "these", "those", "such", "well",
    "para", "como", "mais", "isso", "esse", "essa", "esta", "este",
    "pode", "pelo", "pela", "entre", "sobre", "desde", "porque", "quando",
    "todas", "todos", "muito", "fazer", "cada", "ainda", "mesmo", "outra",
    "outro", "suas", "seus", "minha", "nosso", "voce", "dele", "dela",
    "aqui", "onde", "quem", "qual", "quais",
    # Tool/system noise
    "tool", "result", "system", "reminder", "content", "function", "parameter",
    "true", "false", "null", "none", "type", "name", "value", "file",
    "path", "text", "message", "user", "assistant", "human",
}


def extract_text_content(content):
    """Extract text from message content (string or list)."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict):
                if item.get("type") == "text":
                    parts.append(item.get("text", ""))
            elif isinstance(item, str):
                parts.append(item)
        return "\n".join(parts).strip()
    return ""


def is_human_prompt(msg_obj):
    """Check if this is a human-originated prompt (not tool result)."""
    content = msg_obj.get("message", {}).get("content", "")
    if isinstance(content, list):
        types = [i.get("type") for i in content if isinstance(i, dict)]
        if types and all(t == "tool_result" for t in types):
            return False
    return True


def extract_keywords(texts, min_len=4, min_freq=2, max_keywords=15):
    """Extract meaningful keywords from a list of texts."""
    word_counts = Counter()
    for text in texts:
        words = re.findall(r"[a-zA-Z\u00C0-\u00FF]{4,}", text.lower())
        word_counts.update(w for w in words if w not in STOPWORDS)

    keywords = [w for w, c in word_counts.most_common(max_keywords * 3) if c >= min_freq]
    return keywords[:max_keywords]


def parse_session_for_index(jsonl_path):
    """Parse a JSONL session, return index-ready data."""
    prompts = []
    timestamp_start = None
    session_id = None
    total_tokens = 0

    try:
        with open(jsonl_path) as f:
            lines = f.readlines()
    except Exception:
        return None

    for line in lines:
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg_type = obj.get("type")
        ts = obj.get("timestamp")

        if ts and not timestamp_start:
            timestamp_start = ts
        if not session_id:
            session_id = obj.get("sessionId")

        if msg_type == "assistant":
            usage = obj.get("message", {}).get("usage", {})
            total_tokens += sum(usage.get(k, 0) for k in (
                "input_tokens", "cache_creation_input_tokens",
                "cache_read_input_tokens", "output_tokens"
            ))

        elif msg_type == "user":
            is_sidechain = obj.get("isSidechain", False)
            user_type = obj.get("userType", "")
            content = obj.get("message", {}).get("content", "")
            text = extract_text_content(content)

            if text and not is_sidechain and is_human_prompt(obj) and user_type != "tool":
                prompts.append(text)

    if not prompts:
        return None

    date_str = ""
    if timestamp_start:
        try:
            date_str = timestamp_start[:10]
        except Exception:
            pass

    first_prompt = prompts[0][:200].replace("\n", " ").strip()
    keywords = extract_keywords(prompts)

    return {
        "session_id": session_id or jsonl_path.stem,
        "file": jsonl_path.name,
        "date": date_str,
        "first_prompt": first_prompt,
        "keywords": keywords,
        "prompt_count": len(prompts),
        "total_tokens": total_tokens,
        "all_prompts": [p[:500] for p in prompts],
    }


def load_existing_ids():
    """Load already-indexed session IDs from the JSONL file."""
    ids = set()
    if INDEX_JSONL.exists():
        with open(INDEX_JSONL) as f:
            for line in f:
                try:
                    obj = json.loads(line)
                    ids.add(obj.get("session_id", ""))
                except json.JSONDecodeError:
                    continue
    return ids


def build_index(incremental=False):
    """Build or update the session index."""
    if not PROJECT_DIR.is_dir():
        print(f"Project dir not found: {PROJECT_DIR}")
        print("Check VAULT_PATH or set PROJECT_DIR explicitly.")
        sys.exit(1)

    jsonl_files = sorted(PROJECT_DIR.glob("*.jsonl"))
    print(f"Found {len(jsonl_files)} session files in {PROJECT_DIR}")

    existing_ids = load_existing_ids() if incremental else set()
    existing_entries = []

    if incremental and INDEX_JSONL.exists():
        with open(INDEX_JSONL) as f:
            for line in f:
                try:
                    existing_entries.append(json.loads(line))
                except json.JSONDecodeError:
                    continue

    new_entries = []
    skipped = 0

    for jsonl_file in jsonl_files:
        stem = jsonl_file.stem
        if incremental and any(e.get("file", "").startswith(stem) for e in existing_entries):
            skipped += 1
            continue

        entry = parse_session_for_index(jsonl_file)
        if entry:
            new_entries.append(entry)

    all_entries = existing_entries + new_entries
    all_entries.sort(key=lambda e: e.get("date", ""), reverse=True)

    print(f"Indexed: {len(new_entries)} new, {skipped} skipped, {len(all_entries)} total")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    with open(INDEX_JSONL, "w") as f:
        for entry in all_entries:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    lines = [
        "---",
        'title: "Session Index"',
        'summary: "Searchable index of all Claude Code sessions in this vault project"',
        "type: reference",
        "tags: [session-index, analytics, claude-code]",
        "status: active",
        f"created: {datetime.now().strftime('%Y-%m-%d')}",
        f"updated: {datetime.now().strftime('%Y-%m-%d')}",
        "---",
        "",
        "# Session Index",
        "",
        f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')} | Total: {len(all_entries)} sessions",
        "",
        "| Date | First Prompt | Keywords | Prompts | Tokens |",
        "|------|-------------|----------|---------|--------|",
    ]

    for e in all_entries:
        fp = e["first_prompt"][:80].replace("|", "/")
        kw = ", ".join(e["keywords"][:6])
        tokens = f"{e['total_tokens']:,}" if e.get("total_tokens") else "?"
        lines.append(f"| {e['date']} | {fp} | {kw} | {e['prompt_count']} | {tokens} |")

    lines.append("")
    lines.append("> Use `/recall <term>` to search sessions by keyword or prompt content.")

    with open(INDEX_MD, "w") as f:
        f.write("\n".join(lines))

    print(f"Written: {INDEX_MD}")
    print(f"Written: {INDEX_JSONL}")
    return len(new_entries), len(all_entries)


def main():
    incremental = "--incremental" in sys.argv
    mode = "incremental" if incremental else "full"
    print(f"Session index builder ({mode} mode)")
    new_count, total = build_index(incremental=incremental)
    print(f"Done. {new_count} new sessions indexed, {total} total.")


if __name__ == "__main__":
    main()
