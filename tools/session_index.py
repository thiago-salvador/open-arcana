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

# Stopwords for keyword extraction (EN, kept minimal)
STOPWORDS = {
    "the", "and", "for", "that", "this", "with", "from", "have", "will",
    "been", "they", "their", "there", "what", "when", "where", "which",
    "about", "would", "could", "should", "into", "than", "then", "them",
    "some", "other", "more", "also", "just", "like", "make", "only",
    "very", "does", "done", "here", "each", "over", "after", "before",
    "being", "most", "your", "were", "these", "those", "such", "well",
    "every", "much", "still", "same", "many", "need", "want", "know",
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


def build_message_tree(lines):
    """Build a tree from JSONL lines using uuid/parentUuid fields.

    Returns:
        nodes: dict mapping uuid -> {type, parent, children, depth, text, is_human}
        branch_points: list of dicts with branch metadata
        max_depth: int
    """
    nodes = {}
    children_map = {}  # parentUuid -> [child uuids]
    ordered_uuids = []

    for line in lines:
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        uuid = obj.get("uuid")
        if not uuid:
            continue

        parent_uuid = obj.get("parentUuid")
        msg_type = obj.get("type", "")
        is_sidechain = obj.get("isSidechain", False)
        user_type = obj.get("userType", "")

        # Extract human-readable text for labeling
        text = ""
        is_human = False
        if msg_type == "user" and not is_sidechain:
            content = obj.get("message", {}).get("content", "")
            candidate = extract_text_content(content)
            if candidate and is_human_prompt(obj) and user_type != "tool":
                text = candidate
                is_human = True

        nodes[uuid] = {
            "type": msg_type,
            "parent": parent_uuid,
            "children": [],
            "depth": 0,
            "text": text,
            "is_human": is_human,
            "is_sidechain": is_sidechain,
        }
        ordered_uuids.append(uuid)

        if parent_uuid:
            if parent_uuid not in children_map:
                children_map[parent_uuid] = []
            children_map[parent_uuid].append(uuid)

    # Wire children into nodes
    for parent_uuid, child_list in children_map.items():
        if parent_uuid in nodes:
            nodes[parent_uuid]["children"] = child_list

    # Compute depths via BFS from roots
    roots = [u for u in ordered_uuids if not nodes[u]["parent"] or nodes[u]["parent"] not in nodes]
    queue = [(r, 0) for r in roots]
    max_depth = 0
    while queue:
        uid, depth = queue.pop(0)
        nodes[uid]["depth"] = depth
        if depth > max_depth:
            max_depth = depth
        for child in nodes[uid]["children"]:
            if child in nodes:
                queue.append((child, depth + 1))

    # Detect branch points: nodes with >1 child
    branch_points = []
    for uid, node in nodes.items():
        if len(node["children"]) > 1:
            # Find the nearest human prompt text as label
            label = _find_branch_label(uid, nodes)
            branch_points.append({
                "parentId": uid,
                "depth": node["depth"],
                "children_count": len(node["children"]),
                "label": label,
            })

    return nodes, branch_points, max_depth


def _find_branch_label(branch_uuid, nodes):
    """Find the nearest human prompt text near a branch point for labeling.

    Strategy: look at the branch node itself, then walk each child subtree
    for a human prompt, then walk up ancestors. Accepts any node with text
    as a last resort.
    """
    node = nodes.get(branch_uuid, {})

    # Check the branch node itself
    if node.get("is_human") and node.get("text"):
        return node["text"][:100]

    # Walk children (BFS, max 10 nodes) to find first human prompt
    for child_uuid in node.get("children", []):
        queue = [child_uuid]
        visited = set()
        steps = 0
        while queue and steps < 10:
            current = queue.pop(0)
            if current in visited or current not in nodes:
                continue
            visited.add(current)
            steps += 1
            cn = nodes[current]
            if cn.get("is_human") and cn.get("text"):
                return cn["text"][:100]
            for gc in cn.get("children", []):
                queue.append(gc)

    # Walk up ancestors (up to 15 levels) for human prompt
    current = node.get("parent")
    for _ in range(15):
        if not current or current not in nodes:
            break
        pn = nodes[current]
        if pn.get("is_human") and pn.get("text"):
            return pn["text"][:100]
        current = pn.get("parent")

    # Last resort: walk up again accepting any text at all
    current = node.get("parent")
    for _ in range(15):
        if not current or current not in nodes:
            break
        pn = nodes[current]
        if pn.get("text"):
            return pn["text"][:100]
        current = pn.get("parent")

    return ""


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

    # Build message tree for branching detection
    nodes, branch_points, max_depth = build_message_tree(lines)
    branch_count = len(branch_points)

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
        "branch_count": branch_count,
        "max_depth": max_depth,
        "branch_points": branch_points,
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
        "| Date | First Prompt | Keywords | Prompts | Tokens | Branches |",
        "|------|-------------|----------|---------|--------|----------|",
    ]

    for e in all_entries:
        fp = e["first_prompt"][:80].replace("|", "/")
        kw = ", ".join(e["keywords"][:6])
        tokens = f"{e['total_tokens']:,}" if e.get("total_tokens") else "?"
        bc = e.get("branch_count", 0)
        branches_col = str(bc) if bc else "-"
        lines.append(f"| {e['date']} | {fp} | {kw} | {e['prompt_count']} | {tokens} | {branches_col} |")

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
