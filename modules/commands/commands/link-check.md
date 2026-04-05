---
name: link-check
description: "Cross-linker: scans recent notes and inserts missing wikilinks automatically. Different from /connections (which discovers semantic connections and suggests), /link-check does exact matching and inserts. Accepts optional argument: number of days (default 7) or 'dry-run' for preview without editing."
dependencies: "vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash"
---

# /link-check

Scans recent notes and inserts missing wikilinks for people, projects, and concepts that exist in the vault.

## Argument

- `$ARGUMENTS` can be:
  - Number of days to scan (default: 7). Ex: `/link-check 14`
  - `dry-run` or `preview`: shows what would be linked without editing
  - Combination: `/link-check 14 dry-run`

## Flow

### 1. Build lookup table

Build a table of linkable terms from 3 sources:

**a) Filenames of vault notes**
```bash
find {{VAULT_PATH}} -name "*.md" \
  -not -path "*/Daily-Notes/*" -not -path "*/.claude/*" -not -path "*/80-Templates/*" \
  -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/MEMORY*" \
  | sed 's|.*/||; s|\.md$||'
```
Each filename becomes a linkable term. Maps to `[[filename]]`.

**b) Aliases (00-Dashboard/aliases.md)**
Read the file and parse each group. Each alias maps to the canonical name. Ex: if "Mike" is an alias for "Mike Smith", then "Mike" -> `[[Mike Smith|Mike]]`.

**c) People (70-People/)**
For each file in 70-People/:
- Full name (filename without .md) -> direct match
- Last name alone -> CONDITIONAL match (only link if the note context mentions first name OR associated company/project)

### 2. Filter terms

Remove from the lookup table:
- Terms with fewer than 4 characters (avoids "AI", "API", "SQL" unless they are exact note titles)
- Common words in your language: "about", "how", "for", "draft", "index", "home", "notes", "todo", "data", "test"
- Terms that are generic folder names

### 3. Find recent notes

```bash
find {{VAULT_PATH}} -name "*.md" -mtime -{DAYS} \
  -not -path "*/Daily-Notes/*" -not -path "*/.claude/*" -not -path "*/80-Templates/*" \
  -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/MOCs/*"
```

### 4. For each recent note, scan and link

For each note:

1. **Read the full content**

2. **Identify protected zones** (DO NOT insert links inside):
   - Frontmatter (between first `---` and second `---`)
   - Code blocks (between ``` or ~~~)
   - Existing wikilinks (`[[...]]`)
   - URLs (`http://...`, `https://...`)
   - H1 titles (`# ...`) - the note title does not need a link
   - Tags (`#tag`)

3. **Search for matches** in remaining text:
   - Case-insensitive
   - Word-boundary aware (do not link "Sprint" inside "sprinting" or "sprinter")
   - For each match, check if the note ALREADY contains a wikilink to the same target (in any format: `[[Note]]`, `[[Note|alias]]`, `[[note]]`)
   - If already linked anywhere in the note: SKIP
   - If not linked: mark for insertion

4. **Insert wikilinks:**
   - Only at the FIRST occurrence in the body (after frontmatter)
   - If matched text == canonical name: insert `[[Canonical Name]]`
   - If matched text != canonical name: insert `[[Canonical Name|original text]]`
   - Preserve the original text's case in the display text
   - Maximum 10 links per note

5. **Self-reference check:** NEVER link a note to itself

### 5. Report

**If normal mode (not dry-run):**
```
Cross-linker Report (last {N} days)

Notes scanned: X
Links inserted: Y

Details:
- [[Note A]]: +3 links (Person A, Project X, Feature Y)
- [[Note B]]: +1 link (Person B)

Notes with no new matches: Z

Want to run /connections to discover semantic links the cross-linker missed?
```

**If dry-run mode:**
```
Cross-linker Preview (last {N} days) -- NO FILES MODIFIED

Notes scanned: X
Links that would be inserted: Y

Details:
- [[Note A]]: would link "Person A" -> [[Person A]], "Project X" -> [[Project X]]
- [[Note B]]: would link "Bob" -> [[Bob Smith|Bob]]

Run without dry-run to apply: /link-check {N}
```

## Conservatism rules

1. **Minimum 4 chars** for match (except exact note titles that are shorter)
2. **Last name alone** only links if context confirms (first name or company in the same note)
3. **Skip common words** even if they are note names
4. **Skip self-reference** (note does not link to itself)
5. **Max 10 links per note** (if more, insert the 10 most relevant and warn)
6. **Never modify Templates, MOCs, Daily Notes**
7. **Ambiguity:** if a term matches 2+ notes, prefer the exact match (filename == term)

## Edge cases

- **Wikilinks with display text:** `[[Note|display]]` counts as a link to "Note". Do not duplicate.
- **Notes with accents:** accented and unaccented versions should be treated as equivalent in matching
- **Markdown bold/italic:** `**Person Name**` should match "Person Name" and generate `**[[Person Name]]**`
- **If Edit fails:** report the note as "could not edit" and continue with the next ones

## When to use (vs other commands)

Exact match and automatic wikilink insertion. Different from /connections (semantic, suggests), /health (detects orphans, does not insert links), and /dump (creates notes, does not link existing ones).
