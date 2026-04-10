---
name: health
description: "Vault health audit -- frontmatter, index, orphans, MOCs, WIP, memory. Use when user asks about vault health or as part of /sync-all. Checks 7 weighted components. Outputs score 0-100 with breakdown and classification (Excellent/Good/Needs attention/Critical)."
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

### 6. Output -- Health Score (0-100)

Calculate a weighted numeric score:

| Component | Weight | How to calculate |
|---|---|---|
| Frontmatter | 25 pts | `25 * (1 - notes_missing_summary / total_notes)` (floor 0) |
| Index coverage | 20 pts | `20 * (1 - orphan_notes / total_notes)` (floor 0) |
| MOC health | 15 pts | `15 * (1 - broken_moc_links / total_moc_links)` (floor 0) |
| Connections | 15 pts | `15 * (1 - isolated_notes / total_notes)` (floor 0) |
| Daily Notes | 10 pts | 5 pts if today's DN exists + 5 pts if last 3 DNs have `## Log` |
| WIP updated | 5 pts | 5 pts if `00-Dashboard/wip.md` was edited in last 3 days |
| Memory health | 10 pts | `10 * (1 - (stale_refs + orphan_memories) / total_memories)` (floor 0) |

**Total: sum of components, rounded to integer.**

Classification:
- 90-100: Excellent
- 75-89: Good
- 60-74: Needs attention
- <60: Critical

```
Vault Health Report -- YYYY-MM-DD

## Score: [N/100] -- [Classification]

| Component | Score | Details |
|---|---|---|
| Frontmatter | N/25 | N notes missing summary |
| Index coverage | N/20 | N orphan notes |
| MOC health | N/15 | N broken links |
| Connections | N/15 | N isolated notes |
| Daily Notes | N/10 | Today: yes/no, Recent log: yes/no |
| WIP | N/5 | Updated: yes/no |
| Memory health | N/10 | N stale refs, N orphans |

## Issues found
[prioritized list: critical > important > minor]
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
