---
name: recall
description: "Search previous sessions via FTS5 SQLite with BM25 + date decay. Supports entity filter (person/project) and session-note linking. Requires tools/session_index.py v3."
allowed-tools: "Read,Bash"
---

# /recall -- Cross-Session FTS5 Search (v3)

Semantic search across all past sessions via FTS5 SQLite with v3 schema (entities + session notes). BM25 ranking with date decay (recent sessions get bonus), entity filter, touched-notes listing.

## Procedure

1. **Update index** (incremental):

```bash
python3 {{VAULT_PATH}}/../tools/session_index.py build
```

Incremental by default. Uses `--full` if you suspect something corrupted.

2. **Search:**

```bash
# Simple search
python3 {{VAULT_PATH}}/../tools/session_index.py search "$ARGUMENTS" --limit 10

# With notes touched in each session
python3 {{VAULT_PATH}}/../tools/session_index.py search "$ARGUMENTS" --notes --limit 10

# Filter by person
python3 {{VAULT_PATH}}/../tools/session_index.py search "$ARGUMENTS" --entity "person:Shane"

# Filter by project
python3 {{VAULT_PATH}}/../tools/session_index.py search "$ARGUMENTS" --entity "project:zaaz"

# Combined
python3 {{VAULT_PATH}}/../tools/session_index.py search "$ARGUMENTS" --entity "person:Michael" --notes
```

3. **Special cases without text query:**

```bash
# List all person entities (ranked by #sessions)
python3 {{VAULT_PATH}}/../tools/session_index.py entities person

# Filter by name substring
python3 {{VAULT_PATH}}/../tools/session_index.py entities person Shane

# List projects
python3 {{VAULT_PATH}}/../tools/session_index.py entities project

# See all notes touched in sessions matching path
python3 {{VAULT_PATH}}/../tools/session_index.py notes "70-Pessoas/"
python3 {{VAULT_PATH}}/../tools/session_index.py notes "10-Zaaz/"
```

4. **JSON output for scripting:**

```bash
python3 {{VAULT_PATH}}/../tools/session_index.py search "$ARGUMENTS" --json --limit 5
```

5. **Stats / debug:**

```bash
python3 {{VAULT_PATH}}/../tools/session_index.py stats
```

## Query tips (FTS5)

- **Multiple terms (AND):** `hermes skill manager`
- **Exact phrase:** `"memory nudge"` (quotes)
- **Suffix wildcard:** `distill*`
- **Punctuation stripped** automatically

## Entity filter syntax

Format: `type:name`

- `person:Shane` → case-insensitive substring match in person entity names
- `project:zaaz` → substring match in project tags (configured via PROJECT_PATH_MAP env var)
- Combine with FTS5 query: session must match BOTH criteria

## Environment configuration

The script reads these env vars (set once in your shell rc or setup.sh):

```bash
export VAULT_PATH=/path/to/vault                    # required
export PEOPLE_DIR="$VAULT_PATH/70-Pessoas"          # optional, for person entities
export PROJECT_PATH_MAP="10-Zaaz/=zaaz,20-Mode/=mode"  # optional, for project entities
export DECAY_ALPHA=0.015                             # optional, date decay tuning
export DB_PATH=~/.claude/my-session-index.sqlite    # optional, DB location
```

Empty `PEOPLE_DIR=""` disables person extraction. Empty `PROJECT_PATH_MAP=""` disables project extraction.

## Fallback

If SQLite is corrupted or DB missing:

```bash
grep -i "$ARGUMENTS" {{VAULT_PATH}}/00-Dashboard/session-index.jsonl
```

The legacy JSONL is regenerated on each `build` and serves as grep fallback.

## Schema version

v3 (current):
- Tables: sessions, messages, messages_fts (FTS5 virtual), entities, session_notes
- Migration: automatic drop+rebuild if DB has v<3
- Entities: person (regex from PEOPLE_DIR) + project (from PROJECT_PATH_MAP)
- Note linking: tool_use events extracted for Read/Write/Edit/MultiEdit

## Constraints

- Max 10 results in initial response
- Token budget per recall: ~1-3K tokens
- Do not read raw JSONL unless user asks for specific session details
- `--entity` filter is OR with partial substring match (case-insensitive)
