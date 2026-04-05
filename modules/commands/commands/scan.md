---
name: scan
description: "Scans recently modified files outside the vault. Use at session start to detect work done outside Obsidian. Accepts optional argument for days (default 2). Groups by project, cross-references with vault notes, suggests documentation actions."
dependencies: "vault-read"
allowed-tools: "Read,Glob,Grep,Bash"
---

# /scan

Scans files modified in the last N days outside the vault and reports what changed. Useful for keeping the vault in sync with work done in other projects.

## Argument

- `$ARGUMENTS` -- number of days to scan (default: 2)

## Flow

### 1. Scan Documents

Execute:
```bash
find ~/Documents -type f -mtime -${DAYS} \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/Obsidian*" \
  -not -path "*/.next/*" \
  -not -path "*/.svelte-kit/*" \
  -not -path "*/dist/*" \
  -not -path "*/.turbo/*" \
  -not -path "*/.cache/*" \
  -not -path "*/build/*" \
  -not -path "*/out/*" \
  -not -path "*/__pycache__/*" \
  -not -path "*/venv/*" \
  -not -name "*.lock" \
  -not -name "package-lock.json" \
  -not -name ".DS_Store" \
  -not -name "*.log" \
  -not -name "*.png" -not -name "*.jpg" -not -name "*.svg" \
  -not -name "*.mp4" -not -name "*.ttf" -not -name "*.woff*" \
  | sort
```

### 2. Group by project

Group results by root folder. Map each project folder to its vault equivalent. Example:
- `/Documents/ProjectA/` -> {{COMPANY}} notes
- `/Documents/Apps/` -> Development projects
- Others

### 3. Identify new vs. already documented

For each group, check if a corresponding note already exists in the vault.

### 4. Report

For each item NOT documented in the vault, show:
```
NOT DOCUMENTED:
- [path] -- [brief description of what it appears to be]

ALREADY IN VAULT:
- [path] -> [[vault note]]

SUGGESTION:
- Create note for [X] in [vault folder]
- Update [existing note] with [new info]
```

### 5. Ask

"Want me to create/update vault notes for the undocumented items?"

## Rules
- NEVER read files automatically -- only list and classify
- If the list is too large (>30 significant files), group and ask for confirmation before detailing
- Ignore build artifacts, generated configs, and binary files
