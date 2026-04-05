# Retrieval System Module

4-layer retrieval system inspired by the Engram paper ("Conditional Memory via Scalable Lookup"). Designed to minimize token usage while maximizing recall accuracy for vault-based knowledge management.

## Architecture

The system uses **hierarchical escalation**: start with the cheapest lookup, only escalate when the previous layer fails. This keeps most retrievals at O(1) cost.

### Layer 1: Deterministic Lookup (O(1))

- **concept-index.md** - Hash table mapping concepts to vault notes. Searched first for any query.
- **aliases.md** - Normalizes synonyms, abbreviations, nicknames to canonical terms.

If the concept is found here, retrieval is done. No grep, no semantic search needed.

### Layer 2: Filtered Search (O(n), bounded)

- Triggered when Layer 1 returns nothing.
- Uses `grep` filtered by domain/folder. Max 5 results.
- Domain detection happens via the prefetch hook (file path -> domain mapping).

### Layer 3: Semantic Search (expensive)

- Triggered when Layer 2 returns empty AND the concept is not in the index.
- Uses Smart Connections MCP (embedding-based search). Max 3 results.
- Requires domain gating: define the active domain before searching to filter noise.

### Layer 4: Fallback

- Lists recent files in the active domain folder (`ls -t`).
- Or asks the user for clarification.

## Files

```
retrieval-system/
  rules/
    boot-protocol.md        # Boot sequence + retrieval layer definitions
  hooks/
    prefetch-context.sh     # Domain detection + context injection hook
  dashboard/
    concept-index.md.template   # Template for Layer 1 concept index
    aliases.md.template         # Template for Layer 1 alias resolution
    hot-cache.md.template       # Template for session boot cache
  README.md                 # This file
```

## Setup

1. Copy `rules/boot-protocol.md` to your vault's `.claude/rules/` directory.
2. Copy `hooks/prefetch-context.sh` to your vault's `.claude/hooks/` directory.
3. Copy dashboard templates to `00-Dashboard/` (or your equivalent), remove the `.template` extension, and populate with your vault's content.
4. Configure your vault path in `arcana.config.yaml` or set the `VAULT` environment variable.
5. Register the prefetch hook in your Claude Code settings for the `PreToolUse` event on file reads.

## Configuration

The prefetch hook reads configuration from `arcana.config.yaml` if present. Minimal config:

```yaml
vault_path: /path/to/your/vault
```

Domain mappings are defined in the hook's `case` block. Edit `prefetch-context.sh` to match your vault's folder structure.

## Retrieval Budget

- Max 3 full file reads per query
- Max 20% of context window spent on retrieval, 80% reserved for reasoning
- If a grep returns 20+ results, filter by domain or frontmatter type before reading files
