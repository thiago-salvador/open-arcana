---
name: link-check
description: "Cross-linker via Python scripts. Runs broken_links.py for broken link detection and auto_linker.py for isolated note linking. Much faster than manual scanning."
dependencies: "vault-read"
allowed-tools: "Bash,Read"
---

# /link-check

Scans for broken wikilinks and isolated notes using offload scripts.

## Argument

- `$ARGUMENTS` can be:
  - `dry-run` or `preview`: shows what would be done without editing (default)
  - `apply`: actually apply changes
  - `broken`: only check broken links
  - `isolated`: only check isolated notes

## Flow

### 1. Check broken links

```bash
VAULT_PATH="{{VAULT_PATH}}" python3 "{{VAULT_PATH}}/.claude/tools/broken_links.py"
```

Parse JSON output for:
- `total_links_scanned`
- `broken_count`
- `broken_links` (source, target, line number)
- `suggestions` (did-you-mean matches)

### 2. Check isolated notes

```bash
VAULT_PATH="{{VAULT_PATH}}" python3 "{{VAULT_PATH}}/.claude/tools/auto_linker.py"
```

Parse JSON output for:
- `notes_linked` (count of notes that would get links)
- `details` (file + proposed links)

### 3. Report

```
Link Check Report -- YYYY-MM-DD

## Broken Links: N found
| Source | Target | Line | Suggestion |
|--------|--------|------|------------|
| path/to/note.md | [[Missing Note]] | 42 | Did you mean: [[Existing Note]]? |

## Isolated Notes: N found (no outgoing links)
| Note | Proposed Links |
|------|---------------|
| path/to/isolated.md | parent/index, MOC Name, Person Name |

Total links scanned: N
```

### 4. Offer actions

If `apply` was passed or user confirms:

```bash
# Fix isolated notes
VAULT_PATH="{{VAULT_PATH}}" python3 "{{VAULT_PATH}}/.claude/tools/auto_linker.py" --apply
```

For broken links, offer to fix individually (rename, create target, or remove link).

## Rules
- Default to dry-run (read-only)
- Use script JSON output directly, do not re-scan files
- If scripts are not installed, fall back to the manual /link-check flow
- Broken link fixes require user confirmation per link (they may be intentional)
