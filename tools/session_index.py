#!/usr/bin/env python3
"""
Session index v3: FTS5 SQLite + date decay + entity extraction + session notes.

v1 indexed prompts + keywords into JSONL+MD (grep-only search).
v2 added FTS5 with BM25 + date decay ranking.
v3 adds:
  - entities table: people (from configurable source) and projects (from path prefixes)
  - session_notes table: which vault notes were read/written in each session
  - canonical name normalization (case-folding to configured list)

Usage:
  python3 session_index.py build [--full]
  python3 session_index.py search "termo" [--limit N] [--json] [--notes] [--entity type:name]
  python3 session_index.py entities <type> [name-filter]
  python3 session_index.py notes <path-substring>
  python3 session_index.py stats

Environment variables:
  VAULT_PATH          Required. Absolute path to your Obsidian vault.
  PROJECT_DIR         Optional. Override Claude Code projects dir (default: auto-detect).
  PEOPLE_DIR          Optional. Folder with one .md per person (default: {VAULT_PATH}/70-Pessoas).
                      Set to empty string to disable person extraction.
  PROJECT_PATH_MAP    Optional. Comma-separated `prefix=project` pairs for project entity
                      extraction from tool_use paths. Example:
                      "10-Zaaz/=zaaz,20-Mode/=mode,25-Produtora/=produtora"
                      Default: none (no project entities).
  DB_PATH             Optional. Where to store the SQLite index
                      (default: ~/.claude/<vault-slug>-session-index.sqlite).
  DECAY_ALPHA         Optional. Date decay alpha (default: 0.015, ~6%/month).

Outputs:
  {VAULT_PATH}/00-Dashboard/session-index.md     Human-readable table
  {VAULT_PATH}/00-Dashboard/session-index.jsonl  Grepable fallback
  <DB_PATH>                                       SQLite FTS5 index
"""

import argparse
import json
import os
import re
import sqlite3
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

# --- Configuration from environment ---

VAULT_PATH = os.environ.get("VAULT_PATH")
if not VAULT_PATH:
    print("ERROR: VAULT_PATH environment variable is required.")
    print("  export VAULT_PATH=/path/to/your/obsidian/vault")
    sys.exit(1)

VAULT_DIR = Path(VAULT_PATH)
VAULT_ROOT_STR = str(VAULT_DIR).rstrip("/") + "/"
OUTPUT_DIR = VAULT_DIR / "00-Dashboard"
INDEX_MD = OUTPUT_DIR / "session-index.md"
INDEX_JSONL = OUTPUT_DIR / "session-index.jsonl"

# Claude Code projects dir (auto-detect or override)
_projects_base = Path.home() / ".claude" / "projects"
if os.environ.get("PROJECT_DIR"):
    PROJECT_DIR = Path(os.environ["PROJECT_DIR"])
else:
    vault_slug = str(VAULT_DIR).replace("/", "-")
    if not vault_slug.startswith("-"):
        vault_slug = "-" + vault_slug
    PROJECT_DIR = _projects_base / vault_slug

# People source dir (for canonical person entity extraction)
_people_env = os.environ.get("PEOPLE_DIR")
if _people_env is None:
    PEOPLE_DIR = VAULT_DIR / "70-Pessoas"
elif _people_env == "":
    PEOPLE_DIR = None  # disabled
else:
    PEOPLE_DIR = Path(_people_env)

# Project path map (for project entity extraction from tool_use paths)
PROJECT_PATH_MAP = {}
_map_env = os.environ.get("PROJECT_PATH_MAP", "")
if _map_env:
    for pair in _map_env.split(","):
        pair = pair.strip()
        if "=" in pair:
            prefix, project = pair.split("=", 1)
            PROJECT_PATH_MAP[prefix.strip()] = project.strip()

# SQLite DB path
if os.environ.get("DB_PATH"):
    DB_PATH = Path(os.environ["DB_PATH"])
else:
    vault_slug = str(VAULT_DIR).replace("/", "-").lstrip("-")
    DB_PATH = Path.home() / ".claude" / f"{vault_slug}-session-index.sqlite"

# Date decay alpha (default 0.015 = ~6% penalty per month)
DECAY_ALPHA = float(os.environ.get("DECAY_ALPHA", "0.015"))

# Tool names that touch vault files (for session_notes extraction)
TOOL_NAMES_VAULT = {"Read", "Write", "Edit", "MultiEdit", "NotebookEdit"}

SCHEMA_VERSION = 3

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    file_name TEXT NOT NULL,
    file_mtime REAL NOT NULL,
    started_at TEXT,
    first_prompt TEXT,
    prompt_count INTEGER DEFAULT 0,
    total_tokens INTEGER DEFAULT 0,
    indexed_at REAL NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_sessions_file_mtime ON sessions(file_mtime);

CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    msg_order INTEGER NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    ts TEXT,
    FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id);

CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
    content,
    content='messages',
    content_rowid='id',
    tokenize='porter unicode61 remove_diacritics 1'
);

CREATE TRIGGER IF NOT EXISTS messages_ai AFTER INSERT ON messages BEGIN
    INSERT INTO messages_fts(rowid, content) VALUES (new.id, new.content);
END;

CREATE TRIGGER IF NOT EXISTS messages_ad AFTER DELETE ON messages BEGIN
    INSERT INTO messages_fts(messages_fts, rowid, content) VALUES ('delete', old.id, old.content);
END;

CREATE TRIGGER IF NOT EXISTS messages_au AFTER UPDATE ON messages BEGIN
    INSERT INTO messages_fts(messages_fts, rowid, content) VALUES ('delete', old.id, old.content);
    INSERT INTO messages_fts(rowid, content) VALUES (new.id, new.content);
END;

CREATE TABLE IF NOT EXISTS entities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_name TEXT NOT NULL,
    match_count INTEGER DEFAULT 1,
    FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_entities_type_name ON entities(entity_type, entity_name);
CREATE INDEX IF NOT EXISTS idx_entities_session ON entities(session_id);

CREATE TABLE IF NOT EXISTS session_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    note_path TEXT NOT NULL,
    action TEXT NOT NULL,
    ts TEXT,
    FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_notes_path ON session_notes(note_path);
CREATE INDEX IF NOT EXISTS idx_notes_session ON session_notes(session_id);
"""


def connect_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH), timeout=30.0)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.row_factory = sqlite3.Row
    return conn


def current_schema_version(conn):
    try:
        row = conn.execute("SELECT version FROM schema_version LIMIT 1").fetchone()
        return row["version"] if row else 0
    except sqlite3.OperationalError:
        return 0


def drop_all_tables(conn):
    for table in ("session_notes", "entities", "messages_fts", "messages", "sessions", "schema_version"):
        try:
            conn.execute(f"DROP TABLE IF EXISTS {table}")
        except sqlite3.OperationalError:
            pass
    conn.commit()


def init_schema(conn):
    version = current_schema_version(conn)
    if 0 < version < SCHEMA_VERSION:
        print(f"Schema migration needed: v{version} -> v{SCHEMA_VERSION}. Dropping and rebuilding.")
        drop_all_tables(conn)
    conn.executescript(SCHEMA_SQL)
    row = conn.execute("SELECT version FROM schema_version LIMIT 1").fetchone()
    if row is None:
        conn.execute("INSERT INTO schema_version(version) VALUES (?)", (SCHEMA_VERSION,))
    elif row["version"] != SCHEMA_VERSION:
        conn.execute("DELETE FROM schema_version")
        conn.execute("INSERT INTO schema_version(version) VALUES (?)", (SCHEMA_VERSION,))
    conn.commit()


def load_people_names():
    """Load canonical person names from PEOPLE_DIR/*.md filenames."""
    if PEOPLE_DIR is None or not PEOPLE_DIR.is_dir():
        return []
    names = []
    for md in PEOPLE_DIR.glob("*.md"):
        if md.name == "index.md":
            continue
        names.append(md.stem)
    return sorted(names, key=len, reverse=True)


def build_people_regex(names):
    """Compile a single alternation regex + canonical map.

    Returns (pattern, canonical_map) where pattern is a compiled regex and
    canonical_map maps lowercase match back to the canonical name. Prevents
    case drift in the entities table (e.g., "JOHN SMITH" normalized to "John Smith").
    """
    if not names:
        return None, {}
    alternation = "|".join(re.escape(n) for n in names)
    pattern = re.compile(r"\b(" + alternation + r")\b", re.IGNORECASE)
    canonical_map = {n.lower(): n for n in names}
    return pattern, canonical_map


def extract_text_content(content):
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
    content = msg_obj.get("message", {}).get("content", "")
    if isinstance(content, list):
        types = [i.get("type") for i in content if isinstance(i, dict)]
        if types and all(t == "tool_result" for t in types):
            return False
    return True


def extract_tool_uses(msg_obj):
    """Return list of (tool_name, file_path) for tool_use events in an assistant message."""
    content = msg_obj.get("message", {}).get("content", [])
    if not isinstance(content, list):
        return []
    uses = []
    for item in content:
        if not isinstance(item, dict):
            continue
        if item.get("type") != "tool_use":
            continue
        tool_name = item.get("name", "")
        if tool_name not in TOOL_NAMES_VAULT:
            continue
        tool_input = item.get("input", {}) or {}
        fp = tool_input.get("file_path") or tool_input.get("notebook_path", "")
        if fp:
            uses.append((tool_name, fp))
    return uses


def project_from_path(rel_path):
    """Map a vault-relative path to a project tag, or None."""
    for prefix, project in PROJECT_PATH_MAP.items():
        if rel_path.startswith(prefix):
            return project
    return None


def parse_jsonl_for_db(jsonl_path, people_regex_tuple):
    """Parse a JSONL session, return session metadata + messages + entities + notes."""
    try:
        with open(jsonl_path) as f:
            lines = f.readlines()
    except OSError:
        return None

    session_id = None
    started_at = None
    total_tokens = 0
    messages = []
    human_prompts = []
    notes = []
    project_tags = set()

    for line in lines:
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        ts = obj.get("timestamp")
        if ts and not started_at:
            started_at = ts
        if not session_id:
            session_id = obj.get("sessionId")

        msg_type = obj.get("type")

        if msg_type == "assistant":
            usage = obj.get("message", {}).get("usage", {})
            total_tokens += sum(usage.get(k, 0) for k in (
                "input_tokens", "cache_creation_input_tokens",
                "cache_read_input_tokens", "output_tokens"
            ))

            # Extract tool_use events for session_notes + project entities
            for tool_name, fp in extract_tool_uses(obj):
                if not fp.startswith(VAULT_ROOT_STR):
                    continue
                rel = fp[len(VAULT_ROOT_STR):]
                action = "read" if tool_name == "Read" else "write"
                notes.append({"path": rel, "action": action, "ts": ts or ""})
                project = project_from_path(rel)
                if project:
                    project_tags.add(project)

        if msg_type in ("user", "assistant"):
            is_sidechain = obj.get("isSidechain", False)
            user_type = obj.get("userType", "")
            content = obj.get("message", {}).get("content", "")
            text = extract_text_content(content)

            if not text or is_sidechain:
                continue

            if msg_type == "user":
                if not is_human_prompt(obj) or user_type == "tool":
                    continue
                human_prompts.append(text)

            messages.append({
                "role": msg_type,
                "content": text[:8000],
                "ts": ts or "",
            })

    if not human_prompts and not messages:
        return None

    first_prompt = (human_prompts[0] if human_prompts else "")[:500].replace("\n", " ").strip()

    # Extract person entities with canonical normalization
    person_counts = Counter()
    if people_regex_tuple is not None:
        pattern, canonical_map = people_regex_tuple
        if pattern is not None:
            combined = "\n".join(m["content"] for m in messages)
            for match in pattern.finditer(combined):
                raw = match.group(1)
                canonical = canonical_map.get(raw.lower(), raw)
                person_counts[canonical] += 1

    entities = []
    for name, count in person_counts.items():
        entities.append(("person", name, count))
    for project in project_tags:
        entities.append(("project", project, 1))

    return {
        "session_id": session_id or jsonl_path.stem,
        "file_name": jsonl_path.name,
        "file_mtime": jsonl_path.stat().st_mtime,
        "started_at": (started_at or "")[:19],
        "first_prompt": first_prompt,
        "prompt_count": len(human_prompts),
        "total_tokens": total_tokens,
        "messages": messages,
        "entities": entities,
        "notes": notes,
    }


def should_reindex(conn, jsonl_path):
    stem = jsonl_path.stem
    row = conn.execute(
        "SELECT file_mtime FROM sessions WHERE session_id = ? OR file_name = ?",
        (stem, jsonl_path.name),
    ).fetchone()
    if row is None:
        return True
    return jsonl_path.stat().st_mtime > row["file_mtime"] + 1


def upsert_session(conn, data):
    session_id = data["session_id"]

    conn.execute("DELETE FROM sessions WHERE session_id = ?", (session_id,))
    conn.execute(
        """
        INSERT INTO sessions
            (session_id, file_name, file_mtime, started_at, first_prompt,
             prompt_count, total_tokens, indexed_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            session_id,
            data["file_name"],
            data["file_mtime"],
            data["started_at"],
            data["first_prompt"],
            data["prompt_count"],
            data["total_tokens"],
            time.time(),
        ),
    )

    for order, msg in enumerate(data["messages"]):
        conn.execute(
            "INSERT INTO messages (session_id, msg_order, role, content, ts) VALUES (?, ?, ?, ?, ?)",
            (session_id, order, msg["role"], msg["content"], msg["ts"]),
        )

    for etype, ename, count in data.get("entities", []):
        conn.execute(
            "INSERT INTO entities (session_id, entity_type, entity_name, match_count) VALUES (?, ?, ?, ?)",
            (session_id, etype, ename, count),
        )

    for note in data.get("notes", []):
        conn.execute(
            "INSERT INTO session_notes (session_id, note_path, action, ts) VALUES (?, ?, ?, ?)",
            (session_id, note["path"], note["action"], note["ts"]),
        )


def build_index(full=False):
    if not PROJECT_DIR.is_dir():
        print(f"Project dir not found: {PROJECT_DIR}")
        print(f"Expected Claude Code project dir for vault: {VAULT_DIR}")
        print("Set PROJECT_DIR env var to override.")
        sys.exit(1)

    jsonl_files = sorted(PROJECT_DIR.glob("*.jsonl"))
    print(f"Found {len(jsonl_files)} session files in {PROJECT_DIR}")

    people_names = load_people_names()
    people_regex_tuple = build_people_regex(people_names)
    if people_names:
        print(f"Loaded {len(people_names)} canonical person names for entity extraction")
    else:
        print("Person extraction disabled (no PEOPLE_DIR or empty)")

    if PROJECT_PATH_MAP:
        print(f"Project extraction: {len(PROJECT_PATH_MAP)} prefix mappings")
    else:
        print("Project extraction disabled (no PROJECT_PATH_MAP)")

    conn = connect_db()
    try:
        init_schema(conn)

        sess_count = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
        if sess_count == 0:
            full = True

        if full:
            conn.execute("DELETE FROM messages")
            conn.execute("DELETE FROM sessions")
            conn.execute("DELETE FROM entities")
            conn.execute("DELETE FROM session_notes")
            conn.execute("INSERT INTO messages_fts(messages_fts) VALUES('rebuild')")
            conn.commit()

        new_count = 0
        skipped = 0
        errors = 0

        for jsonl_file in jsonl_files:
            if not full and not should_reindex(conn, jsonl_file):
                skipped += 1
                continue
            try:
                data = parse_jsonl_for_db(jsonl_file, people_regex_tuple)
            except Exception as exc:
                errors += 1
                print(f"  parse error on {jsonl_file.name}: {exc}")
                continue

            if data is None:
                skipped += 1
                continue

            upsert_session(conn, data)
            new_count += 1

        conn.commit()
        conn.execute("INSERT INTO messages_fts(messages_fts) VALUES('optimize')")
        conn.commit()

        total_sessions = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
        total_messages = conn.execute("SELECT COUNT(*) FROM messages").fetchone()[0]
        total_entities = conn.execute("SELECT COUNT(*) FROM entities").fetchone()[0]
        total_notes = conn.execute("SELECT COUNT(*) FROM session_notes").fetchone()[0]

        print(f"Indexed: {new_count} new/updated, {skipped} skipped, {errors} errors")
        print(f"DB totals: {total_sessions} sessions, {total_messages} messages, "
              f"{total_entities} entities, {total_notes} note-links")

        write_legacy_outputs(conn)
        return new_count, total_sessions
    finally:
        conn.close()


def write_legacy_outputs(conn):
    """Keep session-index.md and .jsonl in sync for grep fallback."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    rows = conn.execute(
        """
        SELECT session_id, file_name, started_at, first_prompt,
               prompt_count, total_tokens
        FROM sessions
        ORDER BY started_at DESC
        """
    ).fetchall()

    with open(INDEX_JSONL, "w") as f:
        for row in rows:
            prompts_rows = conn.execute(
                "SELECT content FROM messages WHERE session_id = ? AND role = 'user' ORDER BY msg_order",
                (row["session_id"],),
            ).fetchall()
            entry = {
                "session_id": row["session_id"],
                "file": row["file_name"],
                "date": (row["started_at"] or "")[:10],
                "first_prompt": (row["first_prompt"] or "")[:200],
                "prompt_count": row["prompt_count"],
                "total_tokens": row["total_tokens"],
                "all_prompts": [p["content"][:500] for p in prompts_rows],
            }
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    today = datetime.now().strftime("%Y-%m-%d %H:%M")
    lines = [
        "---",
        'title: "Session Index"',
        'summary: "FTS5 SQLite v3 with entities + session notes. Query via /recall or session_index.py."',
        "type: reference",
        "domain: personal",
        "tags: [session-index, fts5, claude-code]",
        "status: active",
        f"updated: {datetime.now().strftime('%Y-%m-%d')}",
        "---",
        "",
        "# Session Index (v3 FTS5 + entities)",
        "",
        f"Generated: {today} | Total: {len(rows)} sessions | DB: `{DB_PATH}`",
        "",
        "| Date | First Prompt | Prompts | Tokens |",
        "|------|-------------|---------|--------|",
    ]
    for row in rows:
        fp = (row["first_prompt"] or "")[:80].replace("|", "/")
        tokens = f"{row['total_tokens']:,}" if row["total_tokens"] else "?"
        date = (row["started_at"] or "")[:10]
        lines.append(f"| {date} | {fp} | {row['prompt_count']} | {tokens} |")

    lines.append("")
    lines.append("> Use `/recall <termo>` para buscar via FTS5 com date decay.")
    lines.append("> Filtros: `--entity person:<name>`, `--entity project:<tag>`, `--notes`, `--limit N`.")

    with open(INDEX_MD, "w") as f:
        f.write("\n".join(lines))


FTS5_STRIP = re.compile(r'[^\w\s\u00C0-\u017F*"]+', re.UNICODE)


def sanitize_fts5_query(query):
    cleaned = FTS5_STRIP.sub(" ", query).strip()
    if not cleaned:
        return None
    tokens = [t for t in cleaned.split() if len(t) >= 2]
    if not tokens:
        return None
    quoted = [f'"{t}"' if any(c in t for c in ":-./") else t for t in tokens]
    return " ".join(quoted)


def search_index(query, limit=10, decay_alpha=None, entity_filter=None, include_notes=False):
    """FTS5 search with BM25 + date decay."""
    alpha = DECAY_ALPHA if decay_alpha is None else decay_alpha
    sanitized = sanitize_fts5_query(query)
    if sanitized is None:
        print("Query vazia depois da sanitizacao. Tente outros termos.")
        return []

    conn = connect_db()
    try:
        init_schema(conn)

        if entity_filter is not None:
            etype, ename = entity_filter
            sql = """
            SELECT
                s.session_id, s.file_name, s.started_at, s.first_prompt,
                s.prompt_count, s.total_tokens,
                m.role, m.content, bm25(messages_fts) AS bm25_score
            FROM messages_fts
            JOIN messages m ON m.id = messages_fts.rowid
            JOIN sessions s ON s.session_id = m.session_id
            WHERE messages_fts MATCH ?
              AND s.session_id IN (
                SELECT session_id FROM entities
                WHERE entity_type = ? AND LOWER(entity_name) LIKE LOWER(?)
              )
            ORDER BY bm25_score
            LIMIT ?
            """
            params = (sanitized, etype, f"%{ename}%", limit * 4)
        else:
            sql = """
            SELECT
                s.session_id, s.file_name, s.started_at, s.first_prompt,
                s.prompt_count, s.total_tokens,
                m.role, m.content, bm25(messages_fts) AS bm25_score
            FROM messages_fts
            JOIN messages m ON m.id = messages_fts.rowid
            JOIN sessions s ON s.session_id = m.session_id
            WHERE messages_fts MATCH ?
            ORDER BY bm25_score
            LIMIT ?
            """
            params = (sanitized, limit * 4)

        try:
            rows = conn.execute(sql, params).fetchall()
        except sqlite3.OperationalError as exc:
            print(f"FTS5 query error: {exc}")
            print(f"Sanitized query was: {sanitized!r}")
            return []

        now = datetime.now(timezone.utc)
        scored = []
        seen_sessions = set()

        for row in rows:
            session_id = row["session_id"]
            if session_id in seen_sessions:
                continue
            seen_sessions.add(session_id)

            started = row["started_at"] or ""
            days_since = 0.0
            try:
                if started:
                    dt = datetime.fromisoformat(started.replace("Z", "+00:00"))
                    if dt.tzinfo is None:
                        dt = dt.replace(tzinfo=timezone.utc)
                    days_since = max((now - dt).total_seconds() / 86400.0, 0.0)
            except ValueError:
                pass

            bm25 = row["bm25_score"] or 0.0
            decay = 1.0 / (1.0 + days_since * alpha)
            final = bm25 * decay

            snippet = (row["content"] or "").replace("\n", " ")[:180]

            entry = {
                "session_id": session_id,
                "file": row["file_name"],
                "date": started[:10],
                "first_prompt": (row["first_prompt"] or "")[:160],
                "prompt_count": row["prompt_count"],
                "total_tokens": row["total_tokens"],
                "bm25": bm25,
                "decay": decay,
                "score": final,
                "snippet": snippet,
                "role": row["role"],
            }

            if include_notes:
                note_rows = conn.execute(
                    "SELECT DISTINCT note_path, action FROM session_notes WHERE session_id = ? LIMIT 10",
                    (session_id,),
                ).fetchall()
                entry["notes"] = [{"path": nr["note_path"], "action": nr["action"]} for nr in note_rows]

            scored.append(entry)

        scored.sort(key=lambda r: r["score"])
        return scored[:limit]
    finally:
        conn.close()


def format_search_results(results, query, include_notes=False):
    if not results:
        return f"Nenhum resultado para: {query}\n"

    lines = [f"## Sessoes encontradas para: {query}", ""]
    lines.append("| Score | Date | First Prompt | Match |")
    lines.append("|-------|------|-------------|-------|")
    for r in results:
        fp = r["first_prompt"][:60].replace("|", "/")
        snippet = r["snippet"][:70].replace("|", "/")
        lines.append(f"| {r['score']:.2f} | {r['date']} | {fp} | {snippet} |")

    if include_notes:
        lines.append("")
        lines.append("### Notas tocadas por sessao")
        for r in results:
            notes = r.get("notes") or []
            if not notes:
                continue
            lines.append(f"- **{r['date']}**: " + ", ".join(
                f"{n['path']} ({n['action']})" for n in notes[:5]
            ))

    lines.append("")
    lines.append(f"> Total: {len(results)} | BM25 ajustado por date decay (alpha={DECAY_ALPHA})")
    return "\n".join(lines)


def cmd_entities(etype, name_filter=None, limit=50):
    conn = connect_db()
    try:
        init_schema(conn)
        if name_filter:
            rows = conn.execute(
                """
                SELECT entity_name, COUNT(DISTINCT session_id) as sessions, SUM(match_count) as total_hits
                FROM entities
                WHERE entity_type = ? AND LOWER(entity_name) LIKE LOWER(?)
                GROUP BY entity_name
                ORDER BY sessions DESC, total_hits DESC
                LIMIT ?
                """,
                (etype, f"%{name_filter}%", limit),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT entity_name, COUNT(DISTINCT session_id) as sessions, SUM(match_count) as total_hits
                FROM entities
                WHERE entity_type = ?
                GROUP BY entity_name
                ORDER BY sessions DESC, total_hits DESC
                LIMIT ?
                """,
                (etype, limit),
            ).fetchall()

        if not rows:
            return f"Nenhuma entidade do tipo '{etype}' encontrada.\n"

        out = [f"## Entidades tipo: {etype}" + (f" (filter: {name_filter})" if name_filter else ""), ""]
        out.append("| Name | Sessions | Total Hits |")
        out.append("|------|----------|------------|")
        for row in rows:
            out.append(f"| {row['entity_name']} | {row['sessions']} | {row['total_hits']} |")
        return "\n".join(out) + "\n"
    finally:
        conn.close()


def cmd_notes(path_substring, limit=30):
    conn = connect_db()
    try:
        init_schema(conn)
        rows = conn.execute(
            """
            SELECT sn.note_path, sn.action, s.started_at, s.session_id, s.first_prompt
            FROM session_notes sn
            JOIN sessions s ON s.session_id = sn.session_id
            WHERE LOWER(sn.note_path) LIKE LOWER(?)
            ORDER BY s.started_at DESC
            LIMIT ?
            """,
            (f"%{path_substring}%", limit),
        ).fetchall()

        if not rows:
            return f"Nenhuma nota encontrada com path contendo '{path_substring}'.\n"

        out = [f"## Notas tocadas em sessoes: {path_substring}", ""]
        out.append("| Date | Action | Path | Session |")
        out.append("|------|--------|------|---------|")
        for r in rows:
            date = (r["started_at"] or "")[:10]
            fp = (r["first_prompt"] or "")[:40].replace("|", "/")
            path = r["note_path"].replace("|", "/")
            out.append(f"| {date} | {r['action']} | {path} | {fp} |")
        out.append("")
        return "\n".join(out) + "\n"
    finally:
        conn.close()


def show_stats():
    conn = connect_db()
    try:
        init_schema(conn)
        sess = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
        msgs = conn.execute("SELECT COUNT(*) FROM messages").fetchone()[0]
        ents = conn.execute("SELECT COUNT(*) FROM entities").fetchone()[0]
        notes = conn.execute("SELECT COUNT(*) FROM session_notes").fetchone()[0]
        ent_types = conn.execute("SELECT entity_type, COUNT(*) as c FROM entities GROUP BY entity_type").fetchall()
        first = conn.execute("SELECT MIN(started_at) FROM sessions").fetchone()[0]
        last = conn.execute("SELECT MAX(started_at) FROM sessions").fetchone()[0]
        version = current_schema_version(conn)
        db_size = DB_PATH.stat().st_size if DB_PATH.exists() else 0
        print(f"DB: {DB_PATH}")
        print(f"Schema version: {version}")
        print(f"Size: {db_size / 1024:.1f} KB")
        print(f"Sessions: {sess}")
        print(f"Messages: {msgs}")
        print(f"Entities: {ents}")
        for row in ent_types:
            print(f"  {row['entity_type']}: {row['c']}")
        print(f"Note links: {notes}")
        print(f"Range: {first} to {last}")
    finally:
        conn.close()


def parse_entity_filter(value):
    """Parse 'type:name' into (type, name)."""
    if ":" not in value:
        return None
    etype, name = value.split(":", 1)
    etype = etype.strip().lower()
    name = name.strip()
    if etype not in ("person", "project") or not name:
        return None
    return (etype, name)


def main():
    parser = argparse.ArgumentParser(description="Session index v3 (FTS5 + entities + notes)")
    sub = parser.add_subparsers(dest="cmd")

    p_build = sub.add_parser("build", help="Build or update index")
    p_build.add_argument("--full", action="store_true")

    p_search = sub.add_parser("search", help="Search FTS5 index")
    p_search.add_argument("query")
    p_search.add_argument("--limit", type=int, default=10)
    p_search.add_argument("--json", action="store_true")
    p_search.add_argument("--entity", help="Filter by entity (format: type:name)")
    p_search.add_argument("--notes", action="store_true")

    p_ent = sub.add_parser("entities", help="List entities by type")
    p_ent.add_argument("type", choices=["person", "project"])
    p_ent.add_argument("name", nargs="?", default=None)
    p_ent.add_argument("--limit", type=int, default=50)

    p_notes = sub.add_parser("notes", help="Find sessions that touched matching notes")
    p_notes.add_argument("path")
    p_notes.add_argument("--limit", type=int, default=30)

    sub.add_parser("stats", help="Show DB stats")

    args, _ = parser.parse_known_args()

    if args.cmd is None or "--incremental" in sys.argv:
        full = "--full" in sys.argv
        print(f"Session index v3 ({'full' if full else 'incremental'} build)")
        new_count, total = build_index(full=full)
        print(f"Done. {new_count} updated, {total} total.")
        return

    if args.cmd == "build":
        mode = "full" if args.full else "incremental"
        print(f"Session index v3 ({mode} build)")
        new_count, total = build_index(full=args.full)
        print(f"Done. {new_count} updated, {total} total.")
    elif args.cmd == "search":
        entity_filter = parse_entity_filter(args.entity) if args.entity else None
        if args.entity and entity_filter is None:
            print(f"Invalid --entity format: {args.entity}. Expected 'type:name' where type=person|project.")
            sys.exit(1)
        results = search_index(
            args.query,
            limit=args.limit,
            entity_filter=entity_filter,
            include_notes=args.notes,
        )
        if args.json:
            print(json.dumps(results, ensure_ascii=False, indent=2, default=str))
        else:
            print(format_search_results(results, args.query, include_notes=args.notes))
    elif args.cmd == "entities":
        print(cmd_entities(args.type, args.name, args.limit))
    elif args.cmd == "notes":
        print(cmd_notes(args.path, args.limit))
    elif args.cmd == "stats":
        show_stats()


if __name__ == "__main__":
    main()
