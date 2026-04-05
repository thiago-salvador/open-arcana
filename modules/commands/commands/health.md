---
name: health
description: "Vault health audit -- frontmatter, index, orphans, MOCs. Use when user asks about vault health or as part of /sync-all. Checks: missing summary in frontmatter, orphan notes not in index.md, broken wikilinks in MOCs, isolated notes without backlinks, Daily Note existence. Outputs score /10 and offers corrections."
dependencies: "vault-read"
allowed-tools: "Read,Glob,Grep,Bash"
---

# /health

Checks vault health and reports problems.

## Flow

### 1. Check frontmatter

For each .md note in the vault (excluding Daily-Notes and Templates):
```bash
# Find notes without frontmatter summary
grep -rL "^summary:" --include="*.md" {{VAULT_PATH}}/ \
  | grep -v "Daily-Notes" | grep -v "80-Templates" | grep -v "node_modules" | grep -v ".agents"
```

Report notes missing `summary` in frontmatter (required field).

### 2. Check index.md

For each main folder (all your domain folders):
1. Read the `index.md`
2. List the .md files in the folder
3. Compare: existing notes NOT in the index = "orphans"
4. Links in the index pointing to notes that DO NOT exist = "broken links"

### 3. Check MOCs

For each MOC in `MOCs/`:
1. Extract wikilinks
2. Verify referenced notes exist
3. Report broken links

### 4. Check recent notes without connections

Notes created in the last 7 days that have no wikilink pointing to them (potentially isolated).

### 5. Check Daily Notes

- Does today's Daily Note exist?
- Do the last 3 Daily Notes have a `## Log` section?

### 6. Output

```
Vault Health Report -- YYYY-MM-DD

## Frontmatter
- Notes missing summary: [N] [list]

## Index.md
- Orphan notes (not in index): [N] [list]
- Broken links in index: [N] [list]

## MOCs
- Broken links: [N] [list]

## Connections
- Isolated notes (no backlinks): [N] [list]

## Daily Notes
- Today: yes/no
- Log in last 3: yes/no

## Score: [X/10]
```

### 7. Offer corrections

"Want me to fix the problems found? I can:
- Add missing frontmatter
- Update index.md with orphan notes
- Fix broken links
- Create today's Daily Note"

## Rules
- NEVER auto-correct -- always report and ask
- Limit scan to 3 full file reads per folder (use grep for frontmatter, not Read)
- If more than 20 problems found, prioritize the most critical (frontmatter > index > links)
